#!/usr/bin/env bash
#
# CindrixCraft smoke test.
#
# Starts a real CindrixCraft server (the engine, the game and every mod in this repo),
# joins it with a headless test player, runs the chat commands from our own mods, lets the
# world run for a few seconds and shuts everything down again. Fails if anything crashed
# or if one of our commands threw an error.
#
# Usage:  tests/smoke/run.sh [path/to/cindrixcraft]
#
# The path defaults to engine/luanti/bin/cindrixcraft, where the Linux build puts it.
# Everything the test creates goes into .smoke-test/ (deleted at the start of every run).
#
# Optional settings, as environment variables:
#   SMOKE_PORT            server port (default 30411)
#   SMOKE_SKIP_COMMANDS   commands the test should not run, comma separated (default "rtp")
#   SMOKE_START_TIMEOUT   seconds the server may take to load all mods (default 120)
#   SMOKE_JOIN_TIMEOUT    seconds for the player to join and the checks to finish (default 300)
#   SMOKE_STOP_TIMEOUT    seconds the server may take to stop afterwards (default 60)
#   SMOKE_WORKDIR         where to put the test files (default .smoke-test in the repo)

set -u

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)

exe=${1:-$repo/engine/luanti/bin/cindrixcraft}
port=${SMOKE_PORT:-30411}
skip_commands=${SMOKE_SKIP_COMMANDS:-rtp}
start_timeout=${SMOKE_START_TIMEOUT:-120}
join_timeout=${SMOKE_JOIN_TIMEOUT:-300}
stop_timeout=${SMOKE_STOP_TIMEOUT:-60}
work=${SMOKE_WORKDIR:-$repo/.smoke-test}

if [ ! -f "$exe" ]; then
	echo "Cannot find the game program: $exe"
	echo "Build the engine first (see tests/README.md), or pass the path as the first argument."
	exit 2
fi
exe=$(cd "$(dirname "$exe")" && pwd)/$(basename "$exe")

world=$work/world
server_pid=""
client_pid=""

cleanup() {
	for pid in "$client_pid" "$server_pid"; do
		if [ -n "$pid" ]; then
			kill "$pid" 2>/dev/null
		fi
	done
}
trap cleanup EXIT

# Prints the end of the logs, so a failed run explains itself.
show_logs() {
	if [ -f "$world/test_failure" ]; then
		echo
		echo "---- Problems found by the checks ----"
		cat "$world/test_failure"
	fi
	if [ -f "$work/server.log" ]; then
		echo
		echo "---- End of the server log ($work/server.log) ----"
		tail -n 100 "$work/server.log"
	fi
	if [ -f "$work/client.log" ]; then
		echo
		echo "---- End of the test player's log ($work/client.log) ----"
		tail -n 40 "$work/client.log"
	fi
}

fail() {
	echo
	echo "SMOKE TEST FAILED: $1"
	show_logs
	exit 1
}

# wait_for <file> <pid> <seconds>
# Returns 0 when the file exists, 1 on timeout, 2 when the process ended without making it.
wait_for() {
	local file=$1 pid=$2 tries=$(($3 * 2))
	while [ "$tries" -gt 0 ]; do
		if [ -f "$file" ]; then
			return 0
		fi
		if ! kill -0 "$pid" 2>/dev/null; then
			[ -f "$file" ] && return 0
			return 2
		fi
		sleep 0.5
		tries=$((tries - 1))
	done
	return 1
}

# ---------------------------------------------------------------------------------------
# Set up a clean world with the game, our test helper and any extra mods from mods/
# ---------------------------------------------------------------------------------------

rm -rf "$work"
mkdir -p "$work/server-user" "$work/client-user" "$world/worldmods"

cp -a "$here/ci_helper" "$world/worldmods/ci_helper"

# Extra mods kept in mods/ (for example from ContentDB) are loaded too.
for dir in "$repo"/mods/*/; do
	[ -d "$dir" ] || continue
	if [ -f "$dir/mod.conf" ] || [ -f "$dir/modpack.conf" ] || [ -f "$dir/init.lua" ]; then
		cp -a "$dir" "$world/worldmods/$(basename "$dir")"
	fi
done

# The mods we expect the game to load: every folder in CINDRIX/ that has a mod.conf.
expected=""
for dir in "$repo"/games/cindrixcraft/mods/CINDRIX/*/; do
	if [ -f "$dir/mod.conf" ]; then
		expected="$expected,$(basename "$dir")"
	fi
done
expected=${expected#,}

cat >"$work/server.conf" <<EOF
server_announce = false
ipv6_server = false
bind_address = 127.0.0.1
port = $port
enable_damage = false
max_block_send_distance = 1
active_block_range = 1
ci_smoke_test = true
ci_expected_mods = $expected
ci_skip_commands = $skip_commands
EOF

cat >"$work/client.conf" <<EOF
video_driver = null
name = ci_player
viewing_range = 20
fps_max = 30
enable_sound = false
enable_minimap = false
enable_post_processing = false
EOF

# ---------------------------------------------------------------------------------------
# Run it
# ---------------------------------------------------------------------------------------

# LUANTI_GAME_PATH: a folder that contains game folders. Our game is games/cindrixcraft.
# (LUANTI_USER_PATH is ignored by "run in place" builds such as the one CI makes; those keep
# their data next to the program instead, which is fine for a throwaway test.)
echo "Starting the server (this loads the whole game)..."
LUANTI_GAME_PATH="$repo/games" LUANTI_USER_PATH="$work/server-user" \
	"$exe" --server --config "$work/server.conf" --world "$world" --gameid cindrixcraft \
	>"$work/server.log" 2>&1 &
server_pid=$!

wait_for "$world/startup" "$server_pid" "$start_timeout"
case $? in
	0) echo "Server is up and every mod loaded." ;;
	1) fail "the server did not finish loading within ${start_timeout} seconds" ;;
	*) fail "the server stopped while loading (a mod most likely has an error)" ;;
esac

echo "Joining with a headless test player..."
LUANTI_USER_PATH="$work/client-user" ALSOFT_DRIVERS=null \
	"$exe" --config "$work/client.conf" --go --address 127.0.0.1 --port "$port" \
	>"$work/client.log" 2>&1 &
client_pid=$!

echo "Waiting for the checks to run (a short while: the player downloads the game first)..."
wait_for "$world/done" "$server_pid" "$join_timeout"
case $? in
	0) ;;
	1) fail "the checks did not finish within ${join_timeout} seconds (did the player manage to join?)" ;;
	*) fail "the server stopped before the checks finished (it most likely crashed)" ;;
esac

# The helper has asked the server to stop; give it a moment.
tries=$((stop_timeout * 2))
while kill -0 "$server_pid" 2>/dev/null && [ "$tries" -gt 0 ]; do
	sleep 0.5
	tries=$((tries - 1))
done
if kill -0 "$server_pid" 2>/dev/null; then
	fail "the server did not stop after the checks finished"
fi
wait "$server_pid"
server_rc=$?
server_pid=""

# The test player leaves when the server goes away; stop it if it lingers.
tries=40
while kill -0 "$client_pid" 2>/dev/null && [ "$tries" -gt 0 ]; do
	sleep 0.5
	tries=$((tries - 1))
done
if kill -0 "$client_pid" 2>/dev/null; then
	kill "$client_pid" 2>/dev/null
	echo "(the test player was still running after the server stopped; closed it)"
fi
wait "$client_pid" 2>/dev/null
client_pid=""

# ---------------------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------------------

if ! grep -q 'gameid="cindrixcraft"' "$work/server.log"; then
	fail "the server did not run the CindrixCraft game (see the first lines of the server log)"
fi
if [ -f "$world/test_failure" ]; then
	fail "one or more of our commands or mods had a problem"
fi
if [ "$server_rc" -ne 0 ]; then
	fail "the server stopped with error code $server_rc"
fi

echo
echo "What the checks did:"
grep -F "[ci_helper]" "$work/server.log" | sed 's/^/  /'

errors=$(grep -c "ERROR\[" "$work/server.log")
if [ "$errors" -gt 0 ]; then
	echo
	echo "Note: the server log contains $errors ERROR line(s) that did not stop the game."
	echo "These are the first few:"
	grep "ERROR\[" "$work/server.log" | head -n 10 | sed 's/^/  /'
fi

echo
echo "SMOKE TEST PASSED"

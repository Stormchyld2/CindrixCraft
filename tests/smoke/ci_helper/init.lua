-- ci_helper: runs inside the test server started by tests/smoke/run.sh.
-- It does nothing unless that script switched it on, so it is harmless anywhere else.
--
-- What it does:
--   1. When every mod has loaded, checks that each CindrixCraft mod really is loaded,
--      then writes the file "startup" into the world folder.
--   2. When the test player joins, waits a moment, then runs every chat command that
--      our own cindrix_* mods registered, as that player, once with no argument and
--      once with the player's own name. A command that throws a Lua error is a failure.
--      Replies like "usage: ..." or "you don't have permission" are fine.
--   3. Lets the world run a few more seconds (mapgen, mobs, timers), writes "done"
--      (plus "test_failure" listing every problem, if there were any), and stops the server.
--
-- A crash anywhere else in the game (for example in a join handler) stops the server with
-- an error, which run.sh also reports as a failure.

if not core.settings:get_bool("ci_smoke_test", false) then
	return
end

local worldpath = core.get_worldpath()
local failures = {}

local function say(text)
	print("[ci_helper] " .. text)
end

local function fail(text)
	failures[#failures + 1] = text
	say("FAIL: " .. text)
end

-- Makes a small marker file in the world folder. run.sh watches for these.
local function marker(filename, contents)
	local file, err = io.open(worldpath .. "/" .. filename, "w")
	if not file then
		error("ci_helper cannot write " .. filename .. ": " .. tostring(err))
	end
	file:write(contents or "")
	file:close()
end

-- Splits a comma separated setting such as "a,b,c" into a list.
local function words(setting)
	local list = {}
	for word in (core.settings:get(setting) or ""):gmatch("[^,%s]+") do
		list[#list + 1] = word
	end
	return list
end

core.register_on_mods_loaded(function()
	for _, modname in ipairs(words("ci_expected_mods")) do
		if not core.get_modpath(modname) then
			fail("mod is not loaded: " .. modname)
		end
	end
	say(#core.get_modnames() .. " mods loaded")
	marker("startup", "mods loaded\n")
end)

local function run_commands(player_name)
	local skip = {}
	for _, cmd in ipairs(words("ci_skip_commands")) do
		skip[cmd] = true
	end

	-- Only our own commands: the ones registered by a mod whose name starts with cindrix_
	local commands = {}
	for cmd, def in pairs(core.registered_chatcommands) do
		if (def.mod_origin or ""):find("^cindrix_") and not skip[cmd] then
			commands[#commands + 1] = cmd
		end
	end
	table.sort(commands)

	if #commands == 0 then
		fail("no chat commands from the cindrix_* mods were found")
		return
	end

	local runs = 0
	for _, cmd in ipairs(commands) do
		local func = core.registered_chatcommands[cmd].func
		for _, param in ipairs({"", player_name}) do
			runs = runs + 1
			local ok, err = pcall(func, player_name, param)
			if not ok then
				fail(string.format("/%s %s: %s", cmd, param, tostring(err)))
			end
		end
	end
	say(string.format("ran %d commands (%d different) from the CindrixCraft mods",
		runs, #commands))
end

local function finish()
	if #failures > 0 then
		marker("test_failure", table.concat(failures, "\n") .. "\n")
	end
	marker("done", "")
	say(string.format("finished with %d failure(s), stopping the server", #failures))
	core.request_shutdown("smoke test finished", false, 2)
end

local started = false

core.register_on_joinplayer(function(player)
	if started then
		return
	end
	started = true

	local name = player:get_player_name()
	say("test player joined: " .. name)

	core.after(3, function()
		local ok, err = pcall(run_commands, name)
		if not ok then
			fail("the command check itself crashed: " .. tostring(err))
		end
	end)
	core.after(15, finish)
end)

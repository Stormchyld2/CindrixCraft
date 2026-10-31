# tests/

Automatic checks for CindrixCraft's own mods. GitHub runs them for you on every push
(workflow `.github/workflows/test-mods.yml`, shown under the **Actions** tab). A green tick
means both checks passed; a red cross means something needs fixing.

## What gets checked

**1. Lua lint (luacheck).** Reads our mods in `games/cindrixcraft/mods/CINDRIX/` and catches
typos, misspelled variable names and unused or undefined variables, without running the game.
The rules are in `.luacheckrc` at the top of the repo.

**2. Run the game.** Builds the real engine for Linux, starts a server with the CindrixCraft
game and every mod, and joins it with a headless test player (no screen needed). Then it:

- checks that every mod in `CINDRIX/` really loaded,
- runs every chat command our `cindrix_*` mods registered (`/home`, `/whitelist`, `/perms` ...),
  once with no argument and once with the player's name, and fails if one throws a Lua error,
- lets the world run for about 15 seconds (terrain generation, mobs, timers),
- stops the server and fails if it crashed or exited with an error.

Extra mods placed in `mods/` are loaded into the test world as well.

The first run compiles the whole engine, which usually takes somewhere between 10 and 20
minutes. Later runs reuse the compiled parts and are much quicker.

## What it cannot check

It proves that nothing crashes and that commands do not throw errors. It cannot tell whether a
command does the *right* thing (a teleport that lands in the wrong place, a recipe that gives
the wrong item) or whether something looks right. Try new features on the LAN server too.
Commands that need a second player (`/tpa`, `/tpaccept`) are only run with the test player's
own name.

## When a run fails

Open the run in the **Actions** tab. The step "Start the game and join it" prints what went
wrong and the end of the server log. The full logs are attached to the run as
**smoke-test-logs** (download from the bottom of the run's page).

## Running it yourself (Linux)

Build the engine once (see `engine/luanti/README.md` for the packages it needs), then:

```
tests/smoke/run.sh                         # uses engine/luanti/bin/cindrixcraft
tests/smoke/run.sh /path/to/cindrixcraft   # or point at another build
```

Files from the run are in `.smoke-test/` (ignored by git). Settings you can change are listed at
the top of `tests/smoke/run.sh`. Lint locally with `luacheck --config .luacheckrc games/cindrixcraft/mods/CINDRIX tests`.

## Layout

| Path | What it is |
| --- | --- |
| `smoke/run.sh` | Starts the server and the test player, decides pass or fail |
| `smoke/ci_helper/` | A tiny mod used only by the test. It runs the commands and writes the result |

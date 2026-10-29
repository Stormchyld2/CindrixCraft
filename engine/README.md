# Engine: CindrixCraft's fork of Luanti

`luanti/` is a copy of the Luanti source, used as the engine for CindrixCraft.

| | |
| --- | --- |
| Upstream | https://github.com/luanti-org/luanti |
| Baseline | tag `5.17.0`, commit `c0e6812b1a4260bb25a1f606f70f55f4962bb97d` |
| License | LGPL-2.1+ (see `luanti/LICENSE.txt` and `luanti/COPYING.LESSER`) |

## Rules

- Commit `f4b5b96` is the untouched baseline (the Luanti 5.17.0 source exactly as released). Everything we change comes after it, so a diff against that commit limited to `engine/luanti` always shows exactly what we changed.
- Keep changes small and focused (branding first). Do not reformat or reorganise upstream files.
- Keep every upstream license and copyright notice. Our changes are shared under the same licenses.
- To update to a new Luanti release, diff the new tag against the baseline above and reapply our changes.

## Changes so far

- Executable and project name: `cindrixcraft` / `cindrixcraftserver`, shown as "CindrixCraft" in window titles, logs and the Windows file properties (`CMakeLists.txt`, `src/CMakeLists.txt`, `misc/winresource.rc`).
- User data folders: `%APPDATA%\CindrixCraft` on Windows, `~/.cindrixcraft` on Linux and macOS (`src/porting.cpp`), so it never mixes with a normal Luanti install. The portable build still keeps data next to the program.
- Icons and menu logos replaced with the CindrixCraft cube and header (`misc/luanti-icon.*`, `misc/luanti.svg`, `textures/base/pack/logo.png`, `menu_header.png`). The file names still say luanti on purpose, to keep the patch small.
- The internal translation domain stays `luanti`, so upstream translations keep working (`src/gettext.cpp`, `src/CMakeLists.txt`, `cmake/Modules/FindGettextLib.cmake`).
- Windows build: `.github/workflows/windows-engine.yml` at the repo root builds a 64-bit zip on GitHub (this environment has no cross-compiler).

- Main menu (`builtin/mainmenu/`): CindrixCraft is always the selected game, the game picker bar is hidden when only one game is installed, the tabs are named Play and Multiplayer, and the About tab and the "no game found" message mention CindrixCraft, Luanti and Mineclonia.
- The Windows build now bundles `games/cindrixcraft` and removes the `devtest` test game, so the zip runs with no setup.

## Planned changes

1. Remaining menu text that still says Luanti (some dialogs and translated strings).
2. Android: own app ID, name, icon and signing key.
3. Optional: start straight into the CindrixCraft game.

# CindrixCraft game notice

This game is a modified version of **Mineclonia 0.124.1**
(https://codeberg.org/mineclonia/mineclonia), distributed under the same licenses as the original:
code under GPLv3 or later (see `LICENSE.txt`), media under CC BY-SA 4.0 (see `LEGAL.md` and `CREDITS.md`).
All original license, copyright and credit files are kept unchanged.

Changes made for CindrixCraft:

- `game.conf`: title and description, plus `aliases = mineclonia` so worlds made with stock Mineclonia open as CindrixCraft worlds.
- `menu/header.png`, `menu/icon.png`: replaced with the CindrixCraft logo.
- `mods/CINDRIX/`: new modpack with CindrixCraft's own mods (`cindrix_core`, `cindrix_commands`, `cindrix_players`, `cindrix_perms`).
- `minetest.conf`: `default_privs` also gives new players the `cindrix_commands` privilege.
- `mods/MISC/mcl_commands/version.lua`: the `/version` command says CindrixCraft.

The game keeps its internal `mcl_*` mod names so that mods written for Mineclonia keep working.
Mineclonia is a fan game, not developed or endorsed by Mojang AB.

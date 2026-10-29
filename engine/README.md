# Engine: CindrixCraft's fork of Luanti

`luanti/` is a copy of the Luanti source, used as the engine for CindrixCraft.

| | |
| --- | --- |
| Upstream | https://github.com/luanti-org/luanti |
| Baseline | tag `5.17.0`, commit `c0e6812b1a4260bb25a1f606f70f55f4962bb97d` |
| License | LGPL-2.1+ (see `luanti/LICENSE.txt` and `luanti/COPYING.LESSER`) |

## Rules

- The commit titled "Add Luanti 5.17.0 source" is the untouched baseline. Everything we change comes after it, so a diff against that commit limited to `engine/luanti` always shows exactly what we changed.
- Keep changes small and focused (branding first). Do not reformat or reorganise upstream files.
- Keep every upstream license and copyright notice. Our changes are shared under the same licenses.
- To update to a new Luanti release, diff the new tag against the baseline above and reapply our changes.

## Planned changes

1. Branding: executable name, icon, window title, menu and about text.
2. Separate user data folder name, so it never mixes with a normal Luanti install.
3. Android: own app ID, name, icon and signing key.
4. Optional: start straight into the CindrixCraft game.

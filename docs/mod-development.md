# Writing mods

Mods for CindrixCraft are Lua. This is a short working guide; the full reference is Luanti's API docs at https://api.luanti.org.

## Mod layout

```
mods/cindrix_example/
  mod.conf      name, description, dependencies
  init.lua      entry point, run when the mod loads
  textures/     images
  models/       3D models
  sounds/       audio
```

See `mods/cindrix_core` for a minimal working example.

## Conventions

- Our mods are named `cindrix_<something>`.
- Depend on `cindrix_core` for shared helpers.
- Keep Mineclonia-specific calls in one place per mod, so a mod is easier to adjust if Mineclonia changes.
- Use the `core.` namespace (as `cindrix_core` does).

## Trying a mod

1. Copy the mod folder into the user data `mods/` folder (see `platforms.md` for where that is on each platform).
2. Enable it for your world: **Configure** on the world screen, or add `load_mod_<modname> = mods/<modname>` to the world's `world.mt`.
3. Start the world or server and watch the log for errors. "Unknown node" or "unknown item" warnings usually mean a name from another game needs mapping (see `porting-mods.md`).
4. Mods in the main `mods/` folder can be toggled per world. Mods placed in a world's own `worldmods/` folder apply only to that world and can't be toggled.

## Servers

Mods only need to be installed on the server for server-side features. Clients don't need them unless the mod ships client-side parts.

## Licensing

Check every third-party mod's license before bundling it, and add it to `CREDITS.md`.

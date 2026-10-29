# Porting a mod to CindrixCraft

CindrixCraft runs on Mineclonia, so a mod written for a different Luanti game usually needs small changes before it works here. Mods are plain Lua, so everything below is editing text files.

This is a working guide written from general knowledge of the Luanti API. Check item names and helper APIs against Mineclonia's source before relying on them, and fix this guide as we learn.

## Anatomy of a mod

```
mods/my_mod/
  mod.conf      name, description, depends
  init.lua      entry point
  textures/     images
  models/       3D models
  sounds/       audio
```

## Porting steps

1. **Check the license.** Make sure we can bundle it, and add it to `CREDITS.md`.
2. **Read `mod.conf`.** The `depends` line lists the mods and game APIs it needs. Anything from the original game (for example `default`) has no equivalent here and must be replaced.
3. **Map item and node names.** Mods refer to the original game's blocks by name, such as `default:stone`. Find the Mineclonia equivalent (names use the `mcl_` prefix, for example `mcl_core:stone`) and replace every reference, including craft recipes and drop tables.
4. **Replace game-specific helpers.** If the mod calls the original game's own APIs (sounds, mob helpers, inventory tweaks), switch to Mineclonia's equivalents or write small shims in `cindrix_core`.
5. **Test on a throwaway world.** Watch the server log for "unknown node" or "unknown item" warnings and missing-dependency errors.

## Easy versus hard

- **Easy:** mods that add new blocks, items, decor or commands, and that mostly use core Luanti calls (`core.register_node`, `core.register_craftitem`, `core.register_chatcommand`).
- **Harder:** mods that hook deeply into another game's systems (farming, mobs, inventory, armor). These need real rewriting.

## Our own mods

Prefix folder names with `cindrix_` and depend on `cindrix_core` for shared helpers.

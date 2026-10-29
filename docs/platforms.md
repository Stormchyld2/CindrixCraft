# Platforms: Windows and Android

Luanti and Mineclonia are the same on every platform. You can build and test on Windows, then copy the game, mods and worlds to an Android device. Nothing needs to be ported.

Facts below were checked against Luanti's docs and F-Droid on 2026-10-29. Items marked **unconfirmed** weren't covered by the sources we found.

## What every device needs

- **Luanti**, version 5.9 or later (Mineclonia's minimum).
- **Mineclonia** placed in the `games/` folder. Luanti has shipped without a default game since 5.8.0, so the game has to come from ContentDB.
- **Our mods** from `mods/`.
- The **same versions** on the server and on every client. Record them (see `offline-server.md`).

## Windows

1. Get Luanti from the official site (https://www.luanti.org/). Windows has portable builds that run from their own folder.
2. Find the user data directory: open Luanti, go to the **About** tab, and press **Open User Data Directory**.
3. In that folder, use `games/` for Mineclonia, `mods/` for mods (create it if missing), and `worlds/` for worlds. Create a new world and pick Mineclonia as its game.
4. New mods are disabled by default. Enable them per world with **Configure** on the world screen, or by adding a line like `load_mod_cindrix_core = mods/cindrix_core` to that world's `world.mt`. (Before Luanti 5.6.0 this setting was a plain true/false.)

## Android

1. Install Luanti only from an official source: the Luanti website, Google Play or F-Droid. Luanti's docs warn against unofficial builds. When we checked, F-Droid listed version 5.17.0, which needs Android 5.0 or newer; re-check before relying on this.
2. Luanti 5.4.2 and later keep user data here:
   `/storage/emulated/0/Android/data/net.minetest.minetest/files/Minetest/`
   Worlds go in `worlds/` and mods in `mods/` inside it. The old `/storage/emulated/0/Minetest/` location is no longer used.
3. The `games/` location on Android is **unconfirmed**; the docs we read don't name it. After the first launch, look inside the data folder, or install Mineclonia through the in-app content downloader on a connected device and see where it lands.
4. Android restricts access to that folder. Luanti's docs describe two ways in:
   - **Total Commander** (works on Android 12 and below): open Internal shared storage, then Android, then data, then "Installed apps", grant access, and choose "Use this folder" without entering a subfolder.
   - **ADB** from a computer: enable USB debugging, then `adb push` and `adb pull` using the full path above. Windows may need the phone maker's ADB drivers.
   Docs page: https://docs.luanti.org/mobile/accessing-android-data-directory
5. The in-app content downloader needs the internet. For offline setups, copy files over with one of the methods above instead.

## Performance on phones

We found no published performance numbers for Mineclonia on phones. **Unconfirmed**, so test early on the real device with a small world, a short view range and few mods before committing to it.

## Hosting from a phone

The Luanti docs we read don't cover running a LAN server from an Android device. Plan on the server being a Pi or PC, with phones as clients, until we've tested otherwise.

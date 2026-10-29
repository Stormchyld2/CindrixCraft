# CindrixCraft

An offline-first, moddable voxel survival game for playing with friends and family on a local network, with no internet connection required.

CindrixCraft is built on [Luanti](https://www.luanti.org/) (formerly Minetest), using a Minecraft-style base game (VoxeLibre or Mineclonia) and the Luanti mod ecosystem. The goal is a game that feels like Minecraft with Essentials-style LAN play, runs fully off-grid, and can be extended with our own mods.

## Goals

- Play Minecraft-style survival with no internet connection
- Host a world on a small always-on machine (Raspberry Pi or old PC) over WiFi/LAN
- Full mod support, including mods from Luanti's ContentDB
- Easy LAN discovery so players can find the server without typing an IP
- Our own custom mods and content, added over time

## Layout

| Folder | Purpose |
| --- | --- |
| `games/` | Base games (VoxeLibre or Mineclonia). One per world. |
| `mods/` | ContentDB mods and our own custom mods |
| `server/` | Off-grid server config and setup scripts |
| `launcher/` | LAN discovery tool (planned) |

## Status

Early setup. Nothing here runs yet; this repo is the skeleton.

## Roadmap

1. Choose the base game (VoxeLibre or Mineclonia)
2. Vendor Luanti, the base game, and a starter set of mods for fully offline install
3. Server config and setup script for the always-on machine
4. LAN discovery launcher
5. Custom CindrixCraft mods

## Offline install (draft)

1. On a machine with internet, download Luanti, the base game, and the mods.
2. Copy them onto the server and each client (USB drive works fine).
3. Start the server with the config in `server/`.
4. Connect clients to the server's static IP on UDP port 30000.

## License

Not chosen yet. Luanti's engine is LGPL, and VoxeLibre and Mineclonia are GPL, so whatever we bundle with them has to stay GPL-compatible. See `CREDITS.md` for everything we pull in.

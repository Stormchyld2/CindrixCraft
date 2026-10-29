# LAN discovery (design notes)

**Status:** not started. This describes options for finding the CindrixCraft server on the local network without typing an IP, similar to "Open to LAN" with Essentials in Minecraft.

## What works today

Give the server a static IP and save it as a favorite in each client. This needs no extra software and works on Windows and Android.

## Options for automatic discovery

1. **Local hostname (mDNS), for example `cindrix.local`.** Easy to set up on the server. Whether every client OS resolves it reliably, especially Android, is **unconfirmed** and needs testing.
2. **Companion beacon and launcher.** The server broadcasts a small UDP message; a launcher on the client listens, shows the server, and starts Luanti pointed at it. We believe Luanti's in-game Lua can't send network broadcasts itself, which is why this would live outside the game. Whether the Luanti command line can connect straight to an address (and which flags it uses) is **unconfirmed** and needs checking against the Luanti version we ship.
3. **A launcher per platform.** A Windows launcher is straightforward. An Android one means a separate app and is a much bigger job, so on Android we'd keep using the saved favorite at first.

## Suggested order

1. Static IP and saved favorites (now).
2. Test mDNS on our actual devices.
3. Windows companion launcher if mDNS isn't good enough.
4. Revisit Android only if there's a real need.

Code for this will go in `launcher/`.

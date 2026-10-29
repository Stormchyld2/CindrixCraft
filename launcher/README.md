# launcher/

Planned: a small tool that finds the CindrixCraft server on the local network so players don't need to type an IP, similar to "Open to LAN" in Minecraft with Essentials.

Luanti's client-side Lua can't send network broadcasts, so this will be a separate launcher or script that scans the LAN (or resolves a local name such as `cindrix.local` via mDNS) and then starts Luanti pointed at the server it found.

Not started yet.

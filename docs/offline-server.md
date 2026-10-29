# Offline server

How to run CindrixCraft on an always-on machine (a Raspberry Pi or old PC) with no internet connection.

Command-line facts come from Luanti's server docs (https://docs.luanti.org/for-server-hosts/setup/linux/). Anything marked **our advice** is general practice, not something the docs state.

## 1. Prepare the machine (needs internet, once)

Download everything while you have a connection:

- Luanti (server build or the regular build, which also works with `--server`)
- Mineclonia
- Every mod we use
- Windows and Android Luanti installers for clients

Keep these in one folder on the server (for example `offline-media/`) with a `VERSIONS.md` listing each file and its version. Clients on the same network can then be set up without internet, for example with `python3 -m http.server` run in that folder, or any file share. **Our advice.**

## 2. Install the game and mods

- Put Mineclonia in the server's `games/` folder. The game id is the folder name.
- Put mods in `mods/`.
- Create the world once, in a desktop Luanti client (new world, game Mineclonia), then copy its folder to the server's `worlds/` directory.

## 3. Run it

```
luantiserver --gameid mineclonia --worldname cindrixcraft --config server/luanti.conf
```

The regular `luanti` binary with `--server` works the same way. The game has to be given on the command line; Luanti no longer reads it from the config file.

Our `server/luanti.conf` turns off `server_announce` so the server never tries to list itself publicly. The log is `debug.txt` in the Luanti folder.

## 4. Keep it running

Luanti's docs suggest a simple restart loop inside `screen`:

```
while true; do
  ./bin/luantiserver --gameid mineclonia --worldname cindrixcraft --config server/luanti.conf --terminal
  sleep 2
done
```

Run it with `screen -S luanti ./run_server.sh`, detach with Ctrl+A then Ctrl+D, and reattach with `screen -r`.

On Debian-based systems the `luanti-server` package also provides a systemd service (config in `/etc/luanti/`, data under `/var/lib/luanti/`, game chosen through an `.env` file). Worth considering later; the screen loop is simpler to start with.

## 5. Networking

- Luanti uses **UDP port 30000** by default.
- Give the server a **static IP** on your router or access point. Players connect to that IP and port, and can save it as a favorite.
- Allow UDP 30000 through the server's own firewall. Router port forwarding is for reaching a server from the internet and shouldn't be needed for LAN-only play. **Our advice.**

## 6. Backups and power loss (our advice)

The Luanti docs we checked don't cover this, so treat it as general practice:

- Copy the world folder on a schedule and keep several dated copies. Stopping the server first gives the safest backup.
- A sudden power cut can corrupt a world. A small UPS or battery, plus regular backups, is cheap insurance.
- Watch free disk space; worlds grow as players explore.

## 7. Version discipline

Without internet you can't re-download anything later. Record the exact Luanti, Mineclonia and mod versions in `VERSIONS.md`, keep the installers, and update server and clients together.

| Item | Version | File | Date added |
| --- | --- | --- | --- |
| Luanti | | | |
| Mineclonia | | | |

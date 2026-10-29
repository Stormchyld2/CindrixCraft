# server/

Setup for the off-grid server: a small always-on machine on your router or a standalone WiFi access point, with no internet connection.

## Running it

```
luanti --server --config server/luanti.conf --gameid mineclonia
```

The game id is the folder name under `games/`; confirm it once the game is added. Clients connect to the machine's IP on UDP port 30000. Give the server a static IP and save it as a favorite in each client.

## Files

- `luanti.conf`: server settings with offline defaults. Edit the name and message of the day to taste.

Keep machine-specific overrides in `local.conf` (ignored by git).

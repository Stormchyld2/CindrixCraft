# CindrixCraft command cheatsheet

Type commands in chat (press **T**, or **/**). Anything in `<angle brackets>` is required, `[square brackets]` is optional.

Who can use what is decided by **permissions**. The host and singleplayer players can use everything. Open the permissions menu with `/perms` (see below).

## Added by CindrixCraft

These need the `cindrix_commands` permission, which new players get by default.

| Command | What it does |
| --- | --- |
| `/fly` | Turn flying on or off. Press **K** to start or stop flying, **J** for fast mode |
| `/heal [player]` | Fill your health. Healing someone else needs the `server` permission |
| `/eat` | Fill your hunger bar |
| `/god` | Turn invulnerability on or off (resets when you leave) |
| `/sethome [name]` | Save where you stand as a home (up to 5; no name means `home`) |
| `/home [name]` | Go to a saved home |
| `/delhome <name>` | Remove a saved home |
| `/homes` | List your homes |
| `/spawn` | Go to your spawn point (your bed, or the world spawn) |
| `/back` | Return to where you were before your last teleport or death |
| `/tpa <player>` | Ask to teleport to another player |
| `/tpaccept` / `/tpdeny` | Accept or refuse a teleport request (it expires after 60 seconds) |
| `/day` / `/night` | Set the time to morning or to midnight |

Anyone can use these:

| Command | What it does |
| --- | --- |
| `/who` | Who is online. When two or more people are playing, the names also show at the top of the screen |
| `/list` | Who is logged on (from Mineclonia) |
| `/seen <player>` | When a player was last online, and where |

## Permissions menu (like LuckPerms)

Needs the `privs` permission. The host always has it.

| Command | What it does |
| --- | --- |
| `/perms` | Open the permissions menu |
| `/op <player>` | Make a player an operator (the Admin role). Only the host or another operator can do this |
| `/deop <player>` | Take operator status away (back to the default role) |
| `/roles` | List the roles and how many players have each |
| `/role <player>` | Show a player's role |
| `/role <player> <role>` | Give a player a role |

In the menu:

- **Players tab:** pick a player, choose their role from the drop-down, and tick or untick individual permissions. A `*` marks something changed for that player only. "Remove this player's custom changes" puts them back to exactly what their role says.
- **Roles tab:** pick a role and tick what it may do. Add a new role (it starts as a copy of Member) or delete one. Changing a role updates everyone who has it straight away.
- Permissions are found automatically from the game and every mod, so a new mod's permissions show up with no setup. Hover over a permission to read what it does.
- Default roles: **Visitor** (look and chat), **Member** (plus the commands above), **Builder** (plus flying and time), **Moderator** (plus teleport, kick and ban), **Admin** (everything, including future mods).
- New players start as Member. Players who were already in the world before this menu existed are left exactly as they are until you give them a role.
- You can't take the `privs` permission away from yourself by accident.

## Already in the game (from Mineclonia)

Permission needed is shown in the last column; a dash means anyone.

| Command | What it does | Permission |
| --- | --- | --- |
| `/gamemode [survival\|creative] [player]` | Change game mode | server |
| `/kill [name]` | Kill a player or yourself | server |
| `/xp [[player] <xp>]` | Give XP | server |
| `/set_xp <xp>` | Set your XP | debug |
| `/effect <effect> ...` | Add a status effect to yourself (`/effect list` shows them) | server |
| `/enchant <player> <enchantment> [level]` | Enchant the held item | give |
| `/forceenchant <player> <enchantment> [level]` | Enchant with no limits | give |
| `/setblock <x>,<y>,<z> <node>` | Place a block | give, interact |
| `/weather clear\|rain\|thunder [seconds]` | Change the weather | weather_manager |
| `/toggledownfall` | Switch between clear weather and downfall | weather_manager |
| `/difficulty [level]` | Show or set the difficulty | server |
| `/clearmobs [all\|nametagged\|tamed] [range]` | Remove mobs | maphack |
| `/lightning [x y z \| player]` | Strike lightning | maphack |
| `/summon <entity>` | Spawn a mob or other entity at your position | give, interact |
| `/spawn_mob <mob>` | Spawn a mob (developer version with extra options) | debug |
| `/findbiome <biome>` | Teleport to a biome | debug, teleport |
| `/listbiomes` | List all biomes | debug |
| `/tick ...` | Freeze or speed up redstone | server |
| `/say <message>` | Message everyone | announce |
| `/seed` | Show the world seed | - |
| `/version` | Show the CindrixCraft version | - |
| `/whereami <0\|1>` | Show your coordinates on screen | - |
| `/debug <0-4>` | Show coordinates and biome on screen | debug |
| `/awards`, `/awd <id>` | Your advancements | - |
| `/skin` | Open the skin screen | - |
| `/helpform` | Open the in-game help | - |
| `/endcredits` | Show the credits | - |
| `/bonus_chest` | Give a bonus chest | server |

There are also a few developer commands for debugging (`/title`, `/subtitle`, `/actionbar`, `/mobstats`, `/spawnstruct`, `/dumpportals`, `/event_start`, `/color_leather`).

## Built into Luanti

These are part of the engine, so they work in any game. Type `/help` in the game for the full list for your permissions, and `/help <command>` for details.

| Command | What it does | Permission |
| --- | --- | --- |
| `/help [command]` | List commands or explain one | - |
| `/msg <player> <message>` | Private message | - |
| `/me <action>` | Say something about yourself | - |
| `/status` | Server status and who is online | - |
| `/privs [player]` | Show permissions | - |
| `/grant <player> <permission>` / `/revoke ...` | Give or take a permission | privs |
| `/teleport <x,y,z \| player>` | Teleport yourself | teleport |
| `/bring <player>` | Bring a player to you | bring |
| `/give <player> <item> [count]` | Give an item | give |
| `/time <0-23:59 or 0-24000>` | Set the time of day | settime |
| `/kick <player> [reason]` | Remove a player | kick |
| `/ban <player>`, `/unban <player or ip>` | Ban or unban | ban |
| `/shutdown` | Stop the server | server |

## Default keys

| Key | Action |
| --- | --- |
| **K** | Toggle flying (needs the `fly` permission, or `/fly`) |
| **J** | Toggle fast mode |
| **H** | Toggle noclip |
| **T** or **/** | Open chat |

Keys can be changed in Settings.

## Keeping this up to date

The "added by CindrixCraft" part is written by hand, so update it whenever a command is added. The Mineclonia list was generated from the game files for version 0.124.1 (command descriptions shortened); `/help` in the game is always the final word on what your permissions allow.

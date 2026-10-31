-- Luacheck settings for CindrixCraft's own mods (games/cindrixcraft/mods/CINDRIX).
--
-- Run it from the repo root:
--   luacheck --config .luacheckrc games/cindrixcraft/mods/CINDRIX
--
-- The Mineclonia mods and the engine have their own style and are NOT checked here;
-- only the code we write ourselves is.

std = "lua51"        -- Luanti runs LuaJIT / Lua 5.1
max_line_length = false
unused_args = false  -- callbacks often ignore arguments (player, name, ...)

ignore = {
	"212",           -- unused argument (same reason as above)
	"213",           -- unused loop variable ("for _, x in ...")
	"431", "432",    -- shadowing an upvalue / upvalue argument (common and harmless)
	"211/say",       -- small chat helper that a couple of mods keep for later use
	"422/player",    -- loop variable named like the callback argument (cindrix_perms)
}

-- Things the engine provides. We may read these but never assign to them.
read_globals = {
	"core", "minetest",
	"vector", "ItemStack", "Settings", "dump", "dump2",
	"VoxelArea", "VoxelManip", "PseudoRandom", "PcgRandom", "SecureRandom",
	"PerlinNoise", "PerlinNoiseMap",
	"DIR_DELIM", "INIT",

	string = { fields = { "split", "trim" } },
	table  = { fields = { "copy", "copy_with_metatables", "indexof", "keyof",
	                      "insert_all", "shuffle", "key_value_swap" } },
	math   = { fields = { "hypot", "round", "sign", "isfinite", "factorial" } },

	-- Mineclonia mods we optionally depend on (see optional_depends in mod.conf).
	-- Every use must be guarded, e.g. `if core.get_modpath("mcl_hunger") then`.
	"mcl_hunger", "mcl_spawn", "mcl_player", "mcl_util", "mcl_vars", "mcl_death_messages",
}

-- Each of our mods publishes one table with its own name for the others to use.
globals = {
	"cindrix",       -- shared table made by cindrix_core
	"cindrix_core", "cindrix_access", "cindrix_commands",
	"cindrix_names", "cindrix_perms", "cindrix_players",
}

-- cindrix_names wraps the chat formatter on purpose (adds role tags and nicknames).
files["games/cindrixcraft/mods/CINDRIX/cindrix_names/init.lua"] = {
	ignore = { "122" },
}

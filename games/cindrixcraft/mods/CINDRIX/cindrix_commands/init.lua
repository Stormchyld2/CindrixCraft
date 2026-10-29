-- CindrixCraft: convenience commands, in the spirit of EssentialsX.
-- Everything here uses only the standard Luanti API, so it works on any game.

local modname = core.get_current_modname()
local mod_hunger = core.get_modpath("mcl_hunger") ~= nil
local mod_spawn = core.get_modpath("mcl_spawn") ~= nil

-- Players with this privilege can use the commands below.
-- New players get it by default (see default_privs in the game's minetest.conf);
-- the host and singleplayer always have it. Revoke with /revoke <name> cindrix_commands.
core.register_privilege("cindrix_commands", {
	description = "Can use the CindrixCraft convenience commands (/fly, /heal, /eat, /god, /home, /tpa ...)",
	give_to_singleplayer = true,
	give_to_admin = true,
})

local PRIV = {cindrix_commands = true}

local function say(name, text)
	core.chat_send_player(name, core.colorize("#F2A541", text))
end

local function find_player(name)
	return core.get_player_by_name(name)
end

local function max_hp(player)
	local props = player:get_properties()
	return (props and props.hp_max) or 20
end

--------------------------------------------------------------------------------
-- Teleport helper that remembers where you were, for /back
--------------------------------------------------------------------------------

local last_pos = {}

local function remember(name)
	local player = find_player(name)
	if player then
		last_pos[name] = player:get_pos()
	end
end

local function teleport(name, pos)
	local player = find_player(name)
	if not player then return false end
	remember(name)
	player:set_pos(pos)
	return true
end

core.register_on_dieplayer(function(player)
	last_pos[player:get_player_name()] = player:get_pos()
end)

--------------------------------------------------------------------------------
-- /fly
--------------------------------------------------------------------------------

core.register_chatcommand("fly", {
	description = "Turn flying on or off. Press K to start or stop flying, and J for fast mode",
	privs = PRIV,
	func = function(name)
		local privs = core.get_player_privs(name)
		if privs.fly then
			privs.fly = nil
			privs.fast = nil
			core.set_player_privs(name, privs)
			return true, "Flying disabled."
		end
		privs.fly = true
		privs.fast = true
		core.set_player_privs(name, privs)
		return true, "Flying enabled. Press K to start or stop flying (J for fast mode)."
	end,
})

--------------------------------------------------------------------------------
-- /heal and /eat
--------------------------------------------------------------------------------

core.register_chatcommand("heal", {
	params = "[player]",
	description = "Restore your health (or another player's, if you have the server privilege)",
	privs = PRIV,
	func = function(name, param)
		local target = name
		param = param:trim()
		if param ~= "" and param ~= name then
			if not core.check_player_privs(name, {server = true}) then
				return false, "Only the host can heal other players."
			end
			target = param
		end
		local player = find_player(target)
		if not player then
			return false, "Player not found: " .. target
		end
		player:set_hp(max_hp(player))
		if target ~= name then
			say(target, "You were healed by " .. name .. ".")
		end
		return true, target == name and "Healed." or ("Healed " .. target .. ".")
	end,
})

core.register_chatcommand("eat", {
	description = "Fill your hunger bar",
	privs = PRIV,
	func = function(name)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		if mod_hunger and mcl_hunger and mcl_hunger.active and mcl_hunger.set_hunger then
			mcl_hunger.set_hunger(player, 20)
			if mcl_hunger.set_saturation then
				mcl_hunger.set_saturation(player, 20)
			end
			return true, "Your hunger is full."
		end
		return false, "Hunger is not active in this world."
	end,
})

--------------------------------------------------------------------------------
-- /god: no damage while on. Reset when you leave.
--------------------------------------------------------------------------------

local god = {}

core.register_on_player_hpchange(function(player, hp_change)
	if hp_change < 0 and god[player:get_player_name()] then
		return 0
	end
	return hp_change
end, true)

core.register_chatcommand("god", {
	description = "Turn invulnerability on or off",
	privs = PRIV,
	func = function(name)
		if god[name] then
			god[name] = nil
			return true, "God mode off."
		end
		god[name] = true
		return true, "God mode on. You take no damage."
	end,
})

core.register_on_leaveplayer(function(player)
	god[player:get_player_name()] = nil
end)

--------------------------------------------------------------------------------
-- Homes: /sethome [name], /home [name], /delhome <name>, /homes
--------------------------------------------------------------------------------

local MAX_HOMES = 5
local META_KEY = "cindrix_homes"

local function get_homes(player)
	local raw = player:get_meta():get_string(META_KEY)
	if raw == "" then return {} end
	return core.parse_json(raw) or {}
end

local function save_homes(player, homes)
	player:get_meta():set_string(META_KEY, core.write_json(homes))
end

local function home_name(param)
	param = param:trim()
	if param == "" then return "home" end
	return param:sub(1, 24)
end

core.register_chatcommand("sethome", {
	params = "[name]",
	description = "Save your current position as a home",
	privs = PRIV,
	func = function(name, param)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		local homes = get_homes(player)
		local hn = home_name(param)
		local count = 0
		for _ in pairs(homes) do count = count + 1 end
		if not homes[hn] and count >= MAX_HOMES then
			return false, "You can only have " .. MAX_HOMES .. " homes. Remove one with /delhome <name>."
		end
		local pos = vector.round(player:get_pos())
		homes[hn] = {x = pos.x, y = pos.y, z = pos.z}
		save_homes(player, homes)
		return true, "Home '" .. hn .. "' saved."
	end,
})

core.register_chatcommand("home", {
	params = "[name]",
	description = "Go to a saved home",
	privs = PRIV,
	func = function(name, param)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		local homes = get_homes(player)
		local hn = home_name(param)
		local h = homes[hn]
		if not h then
			return false, "No home called '" .. hn .. "'. Use /sethome first."
		end
		teleport(name, vector.new(h.x, h.y, h.z))
		return true, "Welcome home."
	end,
})

core.register_chatcommand("delhome", {
	params = "<name>",
	description = "Remove a saved home",
	privs = PRIV,
	func = function(name, param)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		local homes = get_homes(player)
		local hn = home_name(param)
		if not homes[hn] then
			return false, "No home called '" .. hn .. "'."
		end
		homes[hn] = nil
		save_homes(player, homes)
		return true, "Home '" .. hn .. "' removed."
	end,
})

core.register_chatcommand("homes", {
	description = "List your saved homes",
	privs = PRIV,
	func = function(name)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		local names = {}
		for hn in pairs(get_homes(player)) do
			names[#names + 1] = hn
		end
		table.sort(names)
		if #names == 0 then
			return true, "You have no homes. Use /sethome to save one."
		end
		return true, "Homes: " .. table.concat(names, ", ")
	end,
})

--------------------------------------------------------------------------------
-- /spawn and /back
--------------------------------------------------------------------------------

core.register_chatcommand("spawn", {
	description = "Go to your spawn point",
	privs = PRIV,
	func = function(name)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		local pos
		if mod_spawn and mcl_spawn then
			if mcl_spawn.get_player_spawn_pos then
				pos = mcl_spawn.get_player_spawn_pos(player)
			end
			if not pos and mcl_spawn.get_world_spawn_pos then
				pos = mcl_spawn.get_world_spawn_pos(player)
			end
		end
		if not pos then
			pos = core.setting_get_pos("static_spawnpoint")
		end
		if not pos then
			return false, "No spawn point is set."
		end
		teleport(name, pos)
		return true, "Teleported to spawn."
	end,
})

core.register_chatcommand("back", {
	description = "Return to where you were before your last teleport or death",
	privs = PRIV,
	func = function(name)
		local pos = last_pos[name]
		if not pos then
			return false, "There is nowhere to go back to."
		end
		teleport(name, pos)
		return true, "Teleported back."
	end,
})

--------------------------------------------------------------------------------
-- Teleport requests: /tpa <player>, /tpaccept, /tpdeny
--------------------------------------------------------------------------------

local REQUEST_SECONDS = 60
local requests = {} -- requests[target] = {from = name, time = os.time()}

core.register_chatcommand("tpa", {
	params = "<player>",
	description = "Ask another player if you can teleport to them",
	privs = PRIV,
	func = function(name, param)
		local target = param:trim()
		if target == "" then
			return false, "Usage: /tpa <player>"
		end
		if target == name then
			return false, "You are already there."
		end
		if not find_player(target) then
			return false, "Player not found: " .. target
		end
		requests[target] = {from = name, time = os.time()}
		say(target, name .. " wants to teleport to you. Type /tpaccept to allow it or /tpdeny to refuse.")
		return true, "Request sent to " .. target .. "."
	end,
})

local function take_request(name)
	local r = requests[name]
	requests[name] = nil
	if not r then
		return nil, "You have no teleport requests."
	end
	if os.time() - r.time > REQUEST_SECONDS then
		return nil, "That request has expired."
	end
	return r
end

core.register_chatcommand("tpaccept", {
	description = "Accept a teleport request",
	privs = PRIV,
	func = function(name)
		local r, err = take_request(name)
		if not r then return false, err end
		local dest = find_player(name)
		if not dest or not find_player(r.from) then
			return false, "That player is no longer online."
		end
		teleport(r.from, dest:get_pos())
		say(r.from, "Teleporting to " .. name .. ".")
		return true, r.from .. " teleported to you."
	end,
})

core.register_chatcommand("tpdeny", {
	description = "Refuse a teleport request",
	privs = PRIV,
	func = function(name)
		local r, err = take_request(name)
		if not r then return false, err end
		say(r.from, name .. " refused your teleport request.")
		return true, "Request refused."
	end,
})

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	requests[name] = nil
	last_pos[name] = nil
end)

--------------------------------------------------------------------------------
-- /day and /night
--------------------------------------------------------------------------------

core.register_chatcommand("day", {
	description = "Set the time to morning",
	privs = PRIV,
	func = function(name)
		core.set_timeofday(0.25)
		return true, "It is morning."
	end,
})

core.register_chatcommand("night", {
	description = "Set the time to midnight",
	privs = PRIV,
	func = function(name)
		core.set_timeofday(0.0)
		return true, "It is night."
	end,
})

--------------------------------------------------------------------------------
-- Who is online: a list at the top of the screen when more than one person is
-- playing, plus /who (this game already has /list).
--------------------------------------------------------------------------------

local list_huds = {}

local function online_names(exclude)
	local names = {}
	for _, p in ipairs(core.get_connected_players()) do
		local n = p:get_player_name()
		if n ~= exclude then
			names[#names + 1] = n
		end
	end
	table.sort(names)
	return names
end

local function refresh_player_list(exclude)
	local names = online_names(exclude)
	local text = ""
	if #names > 1 then
		text = "Online (" .. #names .. "): " .. table.concat(names, ", ")
	end
	for _, p in ipairs(core.get_connected_players()) do
		local n = p:get_player_name()
		if n ~= exclude then
			if list_huds[n] then
				p:hud_change(list_huds[n], "text", text)
			else
				list_huds[n] = p:hud_add({
					type = "text",
					position = {x = 0.5, y = 0},
					offset = {x = 0, y = 6},
					alignment = {x = 0, y = 1},
					text = text,
					number = 0xFFFFFF,
					z_index = 100,
				})
			end
		end
	end
end

core.register_on_joinplayer(function(player)
	list_huds[player:get_player_name()] = nil
	core.after(0.5, refresh_player_list)
end)

core.register_on_leaveplayer(function(player)
	local n = player:get_player_name()
	list_huds[n] = nil
	refresh_player_list(n)
end)

core.register_chatcommand("who", {
	description = "Show who is online",
	func = function(name)
		local names = online_names()
		return true, "Online (" .. #names .. "): " .. table.concat(names, ", ")
	end,
})

--------------------------------------------------------------------------------
-- /feed (same as /eat) and /repair
--------------------------------------------------------------------------------

core.register_chatcommand("feed", {
	description = "Fill your hunger bar (same as /eat)",
	privs = PRIV,
	func = core.registered_chatcommands["eat"].func,
})

core.register_chatcommand("repair", {
	description = "Repair the item in your hand",
	privs = PRIV,
	func = function(name)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		local stack = player:get_wielded_item()
		if stack:is_empty() then
			return false, "Hold the item you want to repair."
		end
		if stack:get_wear() == 0 then
			return false, "That item is not damaged."
		end
		stack:set_wear(0)
		player:set_wielded_item(stack)
		return true, "Repaired."
	end,
})

--------------------------------------------------------------------------------
-- /tp and /tphere
--------------------------------------------------------------------------------

local function parse_pos(a, b, c)
	local x, y, z = tonumber(a), tonumber(b), tonumber(c)
	if x and y and z then
		return vector.new(x, y, z)
	end
end

local TP_USAGE = "Usage: /tp <player> | /tp <x> <y> <z> | /tp <player> <to player> | /tp <player> <x> <y> <z>"

core.register_chatcommand("tp", {
	params = "<player> | <x> <y> <z> | <player> <to player> | <player> <x> <y> <z>",
	description = "Teleport to a player or to coordinates. Moving other players needs the bring permission",
	privs = {teleport = true},
	func = function(name, param)
		local args = {}
		for word in param:gmatch("%S+") do
			args[#args + 1] = word
		end
		local mover, dest
		if #args == 1 then
			mover = name
			local t = find_player(args[1])
			if not t then return false, "Player not found: " .. args[1] end
			dest = t:get_pos()
		elseif #args == 2 then
			mover = args[1]
			local t = find_player(args[2])
			if not t then return false, "Player not found: " .. args[2] end
			dest = t:get_pos()
		elseif #args == 3 then
			mover = name
			dest = parse_pos(args[1], args[2], args[3])
		elseif #args == 4 then
			mover = args[1]
			dest = parse_pos(args[2], args[3], args[4])
		end
		if not dest then
			return false, TP_USAGE
		end
		if mover ~= name and not core.check_player_privs(name, {bring = true}) then
			return false, "Moving other players needs the 'bring' permission."
		end
		if not find_player(mover) then
			return false, "Player not found: " .. mover
		end
		teleport(mover, dest)
		return true, "Teleported."
	end,
})

core.register_chatcommand("tphere", {
	params = "<player>",
	description = "Bring a player to where you are",
	privs = {teleport = true, bring = true},
	func = function(name, param)
		local target = param:trim()
		if target == "" then
			return false, "Usage: /tphere <player>"
		end
		local me = find_player(name)
		if not me then return false, "Player not found." end
		if not find_player(target) then
			return false, "Player not found: " .. target
		end
		teleport(target, me:get_pos())
		say(target, name .. " brought you here.")
		return true, "Brought " .. target .. " to you."
	end,
})

--------------------------------------------------------------------------------
-- /rtp: random teleport to a safe spot on the surface of the overworld
--
-- Settings (minetest.conf):
--   cindrix_rtp_min       closest distance from the world centre, default 300
--   cindrix_rtp_max       farthest distance from the world centre, default 3000
--   cindrix_rtp_cooldown  seconds between uses per player, default 30
--------------------------------------------------------------------------------

local rtp_ready_at = {}
local RTP_ATTEMPTS = 8

local function setting_number(key, default)
	return tonumber(core.settings:get(key)) or default
end

local function overworld_limits()
	local vars = rawget(_G, "mcl_vars")
	local ymin = (vars and vars.mg_overworld_min) or -128
	local ymax = (vars and vars.mg_overworld_max_official) or 256
	return ymin, ymax
end

local function in_overworld(pos)
	local worlds = rawget(_G, "mcl_worlds")
	if worlds and worlds.pos_to_dimension then
		local ok, dim = pcall(worlds.pos_to_dimension, pos)
		if ok and dim then
			return dim == "overworld"
		end
	end
	return true
end

local function is_liquid(def)
	return def and def.liquidtype and def.liquidtype ~= "none"
end

-- Looks down from the sky at one column. Returns the y of solid ground that is
-- safe to stand on, or nil, reason.
local function find_surface(x, z, ymin, ymax)
	local ground
	for y = ymax, ymin, -1 do
		local node = core.get_node({x = x, y = y, z = z})
		if node.name == "ignore" then
			return nil, "not loaded"
		end
		local def = core.registered_nodes[node.name]
		if def and is_liquid(def) then
			return nil, "water"
		end
		if def and def.walkable then
			-- skip over tree tops
			local tree = core.get_item_group(node.name, "leaves")
				+ core.get_item_group(node.name, "tree")
				+ core.get_item_group(node.name, "leafdecay")
			if tree == 0 then
				if (def.damage_per_second or 0) > 0 then
					return nil, "dangerous"
				end
				ground = y
				break
			end
		end
	end
	if not ground then
		return nil, "no ground"
	end
	for dy = 1, 2 do
		local node = core.get_node({x = x, y = ground + dy, z = z})
		local def = core.registered_nodes[node.name]
		if node.name == "ignore" or not def or def.walkable or is_liquid(def)
				or (def.damage_per_second or 0) > 0 then
			return nil, "no room"
		end
	end
	return ground
end

local function rtp_attempt(name, attempt, ymin, ymax)
	if not find_player(name) then return end
	if attempt > RTP_ATTEMPTS then
		say(name, "Couldn't find a safe spot this time. Try /rtp again.")
		rtp_ready_at[name] = nil
		return
	end
	local rmin = setting_number("cindrix_rtp_min", 300)
	local rmax = math.max(rmin + 1, setting_number("cindrix_rtp_max", 3000))
	local angle = math.random() * 2 * math.pi
	local dist = rmin + math.random() * (rmax - rmin)
	local x = math.floor(math.cos(angle) * dist)
	local z = math.floor(math.sin(angle) * dist)

	core.emerge_area({x = x, y = ymin, z = z}, {x = x, y = ymax, z = z},
		function(_, _, calls_remaining)
			if calls_remaining > 0 then return end
			if not find_player(name) then return end
			local ground = find_surface(x, z, ymin, ymax)
			if not ground then
				rtp_attempt(name, attempt + 1, ymin, ymax)
				return
			end
			teleport(name, vector.new(x + 0.5, ground + 1, z + 0.5))
			say(name, string.format("Teleported to (%d, %d, %d).", x, ground + 1, z))
		end)
end

core.register_chatcommand("rtp", {
	description = "Teleport to a random safe spot in the overworld",
	privs = PRIV,
	func = function(name)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		if not in_overworld(player:get_pos()) then
			return false, "Random teleport only works in the overworld."
		end
		local now = os.time()
		local wait = (rtp_ready_at[name] or 0) - now
		if wait > 0 then
			return false, "Please wait " .. wait .. " more seconds before using /rtp again."
		end
		rtp_ready_at[name] = now + setting_number("cindrix_rtp_cooldown", 30)
		local ymin, ymax = overworld_limits()
		rtp_attempt(name, 1, ymin, ymax)
		return true, "Looking for a safe spot. This can take a few seconds the first time..."
	end,
})

core.register_on_leaveplayer(function(player)
	rtp_ready_at[player:get_player_name()] = nil
end)

--------------------------------------------------------------------------------
-- Warps: shared teleport spots. /warp <name>, /warps, /setwarp <name>, /delwarp <name>
--------------------------------------------------------------------------------

local storage = core.get_mod_storage()

local function get_warps()
	local raw = storage:get_string("warps")
	if raw == "" then return {} end
	return core.parse_json(raw) or {}
end

local function warp_name(param)
	return (param:trim():gsub("[^%w_%-]", "")):sub(1, 24)
end

core.register_chatcommand("warp", {
	params = "[name]",
	description = "Go to a warp (without a name, lists the warps)",
	privs = PRIV,
	func = function(name, param)
		local warps = get_warps()
		local wn = warp_name(param)
		if wn == "" then
			local names = {}
			for n in pairs(warps) do names[#names + 1] = n end
			table.sort(names)
			if #names == 0 then
				return true, "There are no warps yet. Someone with the teleport permission can add one with /setwarp <name>."
			end
			return true, "Warps: " .. table.concat(names, ", ")
		end
		local w = warps[wn]
		if not w then
			return false, "No warp called '" .. wn .. "'. Use /warp to see the list."
		end
		teleport(name, vector.new(w.x, w.y, w.z))
		return true, "Warped to " .. wn .. "."
	end,
})

core.register_chatcommand("warps", {
	description = "List the warps",
	privs = PRIV,
	func = function(name)
		return core.registered_chatcommands["warp"].func(name, "")
	end,
})

core.register_chatcommand("setwarp", {
	params = "<name>",
	description = "Create a warp at your position",
	privs = {teleport = true},
	func = function(name, param)
		local player = find_player(name)
		if not player then return false, "Player not found." end
		local wn = warp_name(param)
		if wn == "" then
			return false, "Usage: /setwarp <name>"
		end
		local warps = get_warps()
		local pos = vector.round(player:get_pos())
		warps[wn] = {x = pos.x, y = pos.y, z = pos.z}
		storage:set_string("warps", core.write_json(warps))
		return true, "Warp '" .. wn .. "' saved."
	end,
})

core.register_chatcommand("delwarp", {
	params = "<name>",
	description = "Remove a warp",
	privs = {teleport = true},
	func = function(name, param)
		local warps = get_warps()
		local wn = warp_name(param)
		if not warps[wn] then
			return false, "No warp called '" .. wn .. "'."
		end
		warps[wn] = nil
		storage:set_string("warps", core.write_json(warps))
		return true, "Warp '" .. wn .. "' removed."
	end,
})

core.log("action", "[" .. modname .. "] loaded")

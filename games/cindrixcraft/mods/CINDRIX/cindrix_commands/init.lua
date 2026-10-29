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

core.log("action", "[" .. modname .. "] loaded")

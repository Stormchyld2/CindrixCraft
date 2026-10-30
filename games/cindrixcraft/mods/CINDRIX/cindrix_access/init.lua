-- CindrixCraft: accounts and the whitelist.
--
-- /adduser <name> [password] [role]   create an account before the person joins
-- /whitelist on|off|add|remove|list   only approved names can join
-- /users                              everyone who has an account
--
-- The host (and singleplayer) are never blocked by the whitelist.

local modname = core.get_current_modname()
local storage = core.get_mod_storage()

local function say(name, text)
	core.chat_send_player(name, core.colorize("#F2A541", text))
end

--------------------------------------------------------------------------------
-- Whitelist storage
--------------------------------------------------------------------------------

local whitelist = {}   -- whitelist[lowercase name] = real name as typed
local enabled = false
local seeded = false   -- existing players were added when the whitelist was first turned on

do
	local raw = storage:get_string("whitelist")
	if raw ~= "" then
		local data = core.parse_json(raw) or {}
		whitelist = data.names or {}
		enabled = data.enabled == true
		seeded = data.seeded == true
	end
end

local function save()
	storage:set_string("whitelist", core.write_json({
		names = whitelist, enabled = enabled, seeded = seeded,
	}))
end

local function is_host(name)
	return name == core.settings:get("name") or core.is_singleplayer()
end

local function allowed(name)
	return not enabled or is_host(name) or whitelist[name:lower()] ~= nil
end

local function valid_name(name)
	return #name >= 1 and #name <= 20 and name:match("^[%w_%-]+$") ~= nil
end

local function account_exists(name)
	return core.player_exists(name)
end

local function known_names()
	local have = rawget(_G, "cindrix_players")
	if have and have.known then
		return have.known()
	end
	local list = {}
	for _, p in ipairs(core.get_connected_players()) do
		list[#list + 1] = p:get_player_name()
	end
	return list
end

local function sorted_whitelist()
	local list = {}
	for _, real in pairs(whitelist) do
		list[#list + 1] = real
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

core.register_on_prejoinplayer(function(name, ip)
	if not allowed(name) then
		return "You are not on this server's whitelist. Ask the host to add your name."
	end
end)

--------------------------------------------------------------------------------
-- /whitelist
--------------------------------------------------------------------------------

local USAGE = "Usage: /whitelist on | off | add <name> | remove <name> | list"

core.register_chatcommand("whitelist", {
	params = "on | off | add <name> | remove <name> | list",
	description = "Choose who may join: only names on the whitelist can connect when it is on",
	privs = {ban = true},
	func = function(name, param)
		local cmd, arg = param:match("^(%S+)%s*(.-)%s*$")
		cmd = cmd and cmd:lower()

		if not cmd or cmd == "status" then
			return true, "The whitelist is " .. (enabled and "ON" or "OFF") .. " with "
				.. #sorted_whitelist() .. " name(s). " .. USAGE
		end

		if cmd == "on" then
			if not seeded then
				-- First time: let everyone who already has an account keep playing
				for _, real in ipairs(known_names()) do
					whitelist[real:lower()] = real
				end
				seeded = true
			end
			enabled = true
			save()
			return true, "The whitelist is ON. Only these names can join: "
				.. table.concat(sorted_whitelist(), ", ")

		elseif cmd == "off" then
			enabled = false
			save()
			return true, "The whitelist is OFF. Anyone who can reach the server can join."

		elseif cmd == "add" then
			if not valid_name(arg) then
				return false, "Give a name with letters, numbers, _ or - (up to 20 characters)."
			end
			local real = arg
			local names = rawget(_G, "cindrix_names")
			if names and names.resolve and not core.player_exists(arg) then
				real = names.resolve(arg)
			end
			whitelist[real:lower()] = real
			save()
			return true, real .. " is on the whitelist."

		elseif cmd == "remove" or cmd == "del" then
			local real = arg
			local names = rawget(_G, "cindrix_names")
			if names and names.resolve then real = names.resolve(arg) end
			local key = real:lower()
			if not whitelist[key] then
				return false, real .. " is not on the whitelist."
			end
			if is_host(real) then
				return false, "The host can't be removed."
			end
			whitelist[key] = nil
			save()
			if enabled and core.get_player_by_name(real) then
				core.kick_player(real, "You were removed from the whitelist.")
			end
			return true, real .. " was removed from the whitelist."

		elseif cmd == "list" then
			local list = sorted_whitelist()
			if #list == 0 then
				return true, "The whitelist is empty."
			end
			return true, "Whitelist (" .. (enabled and "ON" or "OFF") .. "): " .. table.concat(list, ", ")
		end

		return false, USAGE
	end,
})

--------------------------------------------------------------------------------
-- /adduser
--------------------------------------------------------------------------------

local function random_password()
	local chars = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	local bytes
	local ctor = rawget(_G, "SecureRandom")
	if ctor then
		local ok, sr = pcall(ctor)
		if ok and sr then
			local ok2, b = pcall(sr.next_bytes, sr, 10)
			if ok2 then bytes = b end
		end
	end
	local out = {}
	for i = 1, 10 do
		local n = bytes and bytes:byte(i) or math.random(0, 255)
		local idx = n % #chars + 1
		out[#out + 1] = chars:sub(idx, idx)
	end
	return table.concat(out)
end

core.register_chatcommand("adduser", {
	params = "<name> [password] [role]",
	description = "Create an account for someone before they join. Without a password, one is made up and shown only to you",
	privs = {server = true},
	func = function(name, param)
		local args = {}
		for word in param:gmatch("%S+") do
			args[#args + 1] = word
		end
		if #args < 1 or #args > 3 then
			return false, "Usage: /adduser <name> [password] [role]"
		end
		local who = args[1]
		if not valid_name(who) then
			return false, "A name can use letters, numbers, _ and - (up to 20 characters)."
		end
		if account_exists(who) then
			return false, who .. " already has an account."
		end
		local lower = who:lower()
		for _, real in ipairs(known_names()) do
			if real:lower() == lower then
				return false, "That is too close to the existing name " .. real .. "."
			end
		end

		local password = args[2]
		local generated = false
		if not password then
			password = random_password()
			generated = true
		end
		local role = args[3]
		local perms = rawget(_G, "cindrix_perms")
		if role and perms and perms.has_role and not perms.has_role(role) then
			return false, "No role called " .. role .. ". See /roles."
		end

		local handler = core.get_auth_handler()
		handler.create_auth(who, core.get_password_hash(who, password))
		if not account_exists(who) then
			return false, "The account could not be created."
		end

		whitelist[lower] = who
		save()

		local msg = "Created the account " .. who .. "."
		if perms and perms.set_role then
			local ok, err = perms.set_role(who, role)
			if ok then
				msg = msg .. " Role: " .. (role or perms.default_role()) .. "."
			elseif err then
				msg = msg .. " (Role not set: " .. err .. ")"
			end
		end
		if generated then
			msg = msg .. "\nPassword: " .. password
				.. "\nShare it with them. They can change it from the pause menu."
		else
			msg = msg .. "\nNote: a password typed into a command can show up in the server log, "
				.. "so next time you can leave it out and one will be made up for you."
		end
		return true, msg
	end,
})

--------------------------------------------------------------------------------
-- /users
--------------------------------------------------------------------------------

core.register_chatcommand("users", {
	description = "List everyone who has an account, with role, online status and whitelist",
	privs = {ban = true},
	func = function(name)
		local perms = rawget(_G, "cindrix_perms")
		local list = known_names()
		if #list == 0 then
			return true, "No accounts yet."
		end
		local lines = {}
		for _, real in ipairs(list) do
			local bits = {}
			if core.get_player_by_name(real) then bits[#bits + 1] = "online" end
			local role = perms and perms.get_role and perms.get_role(real)
			if role then bits[#bits + 1] = role end
			if enabled and not (whitelist[real:lower()] or is_host(real)) then
				bits[#bits + 1] = "NOT whitelisted"
			end
			lines[#lines + 1] = real .. (#bits > 0 and (" (" .. table.concat(bits, ", ") .. ")") or "")
		end
		return true, #list .. " account(s):\n" .. table.concat(lines, "\n")
	end,
})

core.log("action", "[" .. modname .. "] loaded")

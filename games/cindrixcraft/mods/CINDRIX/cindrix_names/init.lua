-- CindrixCraft: nicknames and chat names.
--
-- * /nick <name> sets a display name shown above your head, in chat and in the
--   online list. Your real account name never changes and is what the game
--   uses to save your inventory, position and permissions.
-- * Operators and moderators get a coloured tag in chat.
-- * Commands from cindrix_commands accept a nickname wherever they accept a
--   player name.

cindrix_names = {}

local modname = core.get_current_modname()
local storage = core.get_mod_storage()

local nicks = {} -- nicks[real name] = nickname
do
	local raw = storage:get_string("nicks")
	if raw ~= "" then
		nicks = core.parse_json(raw) or {}
	end
end

local function save()
	storage:set_string("nicks", core.write_json(nicks))
end

local function max_length()
	return math.max(3, math.min(32, tonumber(core.settings:get("cindrix_nick_max_length")) or 16))
end

local function say(name, text)
	core.chat_send_player(name, core.colorize("#F2A541", text))
end

local function known_real_names()
	local list = {}
	local have = rawget(_G, "cindrix_players")
	if have and have.known then
		list = have.known()
	else
		for _, p in ipairs(core.get_connected_players()) do
			list[#list + 1] = p:get_player_name()
		end
	end
	return list
end

--------------------------------------------------------------------------------
-- Public API (also used by the other CindrixCraft mods)
--------------------------------------------------------------------------------

function cindrix_names.get_nick(name)
	return nicks[name]
end

function cindrix_names.display_name(name)
	return nicks[name] or name
end

-- Accepts a real name or a nickname (any capitalisation) and returns the real
-- name. If nothing matches, the input is returned unchanged.
function cindrix_names.resolve(input)
	input = (input or ""):trim()
	if input == "" then return input end
	if core.player_exists(input) then
		return input
	end
	local lower = input:lower()
	for real, nick in pairs(nicks) do
		if nick:lower() == lower then
			return real
		end
	end
	for _, real in ipairs(known_real_names()) do
		if real:lower() == lower then
			return real
		end
	end
	return input
end

--------------------------------------------------------------------------------
-- Nametags
--------------------------------------------------------------------------------

local function apply_nametag(player)
	local name = player:get_player_name()
	player:set_nametag_attributes({text = nicks[name] or name})
end

core.register_on_joinplayer(function(player)
	apply_nametag(player)
end)

-- Some effects (for example ending invisibility) put the real name back on
-- the nametag. Fix that, but never touch a nametag that was hidden on purpose.
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 5 then return end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local nick = nicks[name]
		if nick then
			local attrs = player:get_nametag_attributes()
			if attrs and attrs.text == name then
				player:set_nametag_attributes({text = nick})
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- /nick and /realname
--------------------------------------------------------------------------------

local function check_nick(requester, target, nick)
	if #nick < 3 then
		return false, "A nickname needs at least 3 characters."
	end
	if #nick > max_length() then
		return false, "A nickname can be at most " .. max_length() .. " characters."
	end
	if not nick:match("^[%w_%-]+$") then
		return false, "Use only letters, numbers, _ and - in a nickname."
	end
	local lower = nick:lower()
	for _, real in ipairs(known_real_names()) do
		if real:lower() == lower and real ~= target then
			return false, "That is another player's name."
		end
	end
	for real, other in pairs(nicks) do
		if other:lower() == lower and real ~= target then
			return false, "Someone else already uses that nickname."
		end
	end
	return true
end

core.register_chatcommand("nick", {
	params = "<nickname> | off | <player> <nickname|off>",
	description = "Choose a display name (shown above your head and in chat). Use 'off' to go back to your real name",
	privs = {cindrix_commands = true},
	func = function(name, param)
		local args = {}
		for word in param:gmatch("%S+") do
			args[#args + 1] = word
		end
		if #args == 0 or #args > 2 then
			return false, "Usage: /nick <nickname>, /nick off, or /nick <player> <nickname|off>"
		end

		local target, nick = name, args[1]
		if #args == 2 then
			if not core.check_player_privs(name, {server = true}) then
				return false, "Only the host can change other players' nicknames."
			end
			target = cindrix_names.resolve(args[1])
			nick = args[2]
			if not core.player_exists(target) then
				return false, "Unknown player: " .. args[1]
			end
		end

		if nick:lower() == "off" then
			nicks[target] = nil
			save()
			local p = core.get_player_by_name(target)
			if p then apply_nametag(p) end
			return true, target == name and "Your nickname is removed." or ("Removed the nickname of " .. target .. ".")
		end

		local ok, err = check_nick(name, target, nick)
		if not ok then
			return false, err
		end
		nicks[target] = nick
		save()
		local p = core.get_player_by_name(target)
		if p then apply_nametag(p) end
		return true, target == name and ("You are now called " .. nick .. ".")
			or (target .. " is now called " .. nick .. ".")
	end,
})

core.register_chatcommand("realname", {
	params = "<nickname>",
	description = "Show the real account name behind a nickname",
	func = function(name, param)
		local input = param:trim()
		if input == "" then
			return false, "Usage: /realname <nickname>"
		end
		local real = cindrix_names.resolve(input)
		if not core.player_exists(real) then
			return false, "Nobody is called " .. input .. "."
		end
		if real == input then
			return true, input .. " is a real account name."
		end
		return true, input .. " is " .. real .. "."
	end,
})

--------------------------------------------------------------------------------
-- Chat: nickname, plus a tag for operators and moderators
--------------------------------------------------------------------------------

local TAGS = {
	Admin = {text = "[Admin] ", color = "#F2A541"},
	Moderator = {text = "[Mod] ", color = "#88CCFF"},
}

local function chat_tag(name)
	if core.is_singleplayer() then return "" end
	if core.settings:get("cindrix_chat_tags") == "false" then return "" end
	local role
	local perms = rawget(_G, "cindrix_perms")
	if perms and perms.get_role then
		role = perms.get_role(name)
	elseif name == core.settings:get("name") then
		role = "Admin"
	end
	local tag = role and TAGS[role]
	if not tag then return "" end
	return core.colorize(tag.color, tag.text)
end

local original_format = core.format_chat_message
core.format_chat_message = function(name, message)
	return chat_tag(name) .. original_format(cindrix_names.display_name(name), message)
end

core.log("action", "[" .. modname .. "] loaded")

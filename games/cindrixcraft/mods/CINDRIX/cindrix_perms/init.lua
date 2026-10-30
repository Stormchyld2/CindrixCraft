-- CindrixCraft: permissions menu, in the spirit of LuckPerms.
--
-- * Permissions (Luanti calls them privileges) are discovered automatically
--   from the game and every installed mod, so new mods show up with no setup.
-- * Roles are named bundles of permissions. Each player has one role, plus
--   optional per-player changes on top of it.
-- * Open the menu with /perms (needs the "privs" permission).
--
-- Players without a role are left exactly as they are ("unmanaged"), so
-- adding this mod to an existing world changes nothing until you assign roles.

local modname = core.get_current_modname()
local storage = core.get_mod_storage()
local have_players = core.get_modpath("cindrix_players") ~= nil

local FORM = "cindrix_perms:main"
local DEFAULT_ROLE_SETTING = "cindrix_default_role"

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------

local function load(key, default)
	local raw = storage:get_string(key)
	if raw == "" then return default end
	local v = core.parse_json(raw)
	if v == nil then return default end
	return v
end

local function save(key, value)
	storage:set_string(key, core.write_json(value))
end

local roles = load("roles", nil)         -- roles[name] = {all = bool, privs = {priv = true}}
local assignments = load("assignments", {}) -- assignments[player] = role name
local overrides = load("overrides", {})  -- overrides[player][priv] = true | false

local function save_all()
	save("roles", roles)
	save("assignments", assignments)
	save("overrides", overrides)
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function registered(priv)
	return core.registered_privileges[priv] ~= nil
end

local function all_privs()
	local list = {}
	for name in pairs(core.registered_privileges) do
		list[#list + 1] = name
	end
	table.sort(list)
	return list
end

local function is_admin(name)
	return name == core.settings:get("name") or core.is_singleplayer()
end

-- Small API for the other CindrixCraft mods (chat tags, nicknames)
cindrix_perms = {}

function cindrix_perms.get_role(name)
	if name == core.settings:get("name") then
		return "Admin"
	end
	return assignments[name]
end

local function role_names()
	local list = {}
	for name in pairs(roles) do
		list[#list + 1] = name
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

-- The permissions a role gives (only ones that exist right now)
local function role_privs(role_name)
	local role = roles[role_name]
	local set = {}
	if not role then return set end
	if role.all then
		for _, p in ipairs(all_privs()) do
			set[p] = true
		end
		return set
	end
	for p, on in pairs(role.privs or {}) do
		if on and registered(p) then
			set[p] = true
		end
	end
	return set
end

local function copy(set)
	local out = {}
	for k, v in pairs(set) do out[k] = v end
	return out
end

-- What a managed player should have: the role plus their own changes
local function effective(name)
	local role_name = assignments[name]
	if not role_name then return nil end
	local set = copy(role_privs(role_name))
	for p, on in pairs(overrides[name] or {}) do
		if registered(p) then
			set[p] = on or nil
		end
	end
	return set
end

local function apply(name)
	if is_admin(name) then return end
	local set = effective(name)
	if not set then return end -- unmanaged
	core.set_player_privs(name, set)
end

local function apply_role_members(role_name)
	for player, r in pairs(assignments) do
		if r == role_name then
			apply(player)
		end
	end
end

local function known_players()
	local set = {}
	if have_players then
		for _, n in ipairs(cindrix_players.known()) do set[n] = true end
	end
	for _, p in ipairs(core.get_connected_players()) do
		set[p:get_player_name()] = true
	end
	for n in pairs(assignments) do set[n] = true end
	local list = {}
	for n in pairs(set) do list[#list + 1] = n end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

local function clean_role_name(text)
	text = (text or ""):gsub("[^%w_ %-]", ""):trim()
	return text:sub(1, 20)
end

--------------------------------------------------------------------------------
-- Default roles, built once from whatever permissions exist after all mods load
--------------------------------------------------------------------------------

local function make_default_roles()
	local function pick(list)
		local privs = {}
		for _, p in ipairs(list) do
			if registered(p) then privs[p] = true end
		end
		return privs
	end
	local member = {"interact", "shout", "cindrix_commands"}
	local builder = {"interact", "shout", "cindrix_commands", "fly", "fast", "noclip", "settime"}
	local moderator = {"interact", "shout", "cindrix_commands", "fly", "fast", "noclip", "settime",
		"teleport", "bring", "kick", "ban", "basic_privs"}
	return {
		Visitor = {all = false, privs = pick({"interact", "shout"})},
		Member = {all = false, privs = pick(member)},
		Builder = {all = false, privs = pick(builder)},
		Moderator = {all = false, privs = pick(moderator)},
		Admin = {all = true, privs = {}},
	}
end

core.register_on_mods_loaded(function()
	if not roles then
		roles = make_default_roles()
		save_all()
	end
end)

local function default_role()
	local r = core.settings:get(DEFAULT_ROLE_SETTING) or "Member"
	if roles and roles[r] then return r end
	return "Member"
end

core.register_on_newplayer(function(player)
	local name = player:get_player_name()
	if roles and not assignments[name] then
		assignments[name] = default_role()
		save("assignments", assignments)
		apply(name)
	end
end)

core.register_on_joinplayer(function(player)
	apply(player:get_player_name())
end)

--------------------------------------------------------------------------------
-- The menu
--------------------------------------------------------------------------------

local ui = {} -- ui[name] = {tab = 1|2, player = name, role = name, scroll = number}

local function state(name)
	local st = ui[name]
	if not st then
		st = {tab = 1, scroll = 0}
		ui[name] = st
	end
	return st
end

local function esc(text)
	return core.formspec_escape(text)
end

local function index_of(list, value)
	for i, v in ipairs(list) do
		if v == value then return i end
	end
	return nil
end

-- A scrolling list of permission checkboxes. `current` is the set that is on.
-- Returns the formspec text.
local function privilege_list(x, y, w, h, st, current, marks, locked)
	local privs = all_privs()
	local row_h = 0.55
	local content_h = math.max(#privs * row_h + 0.2, h)
	local max = math.max(0, math.floor((content_h - h) / 0.1))
	local fs = {}
	fs[#fs + 1] = string.format("scroll_container[%g,%g;%g,%g;scr;vertical;0.1]", x, y, w - 0.45, h)
	for i, p in ipairs(privs) do
		local label = p
		if marks and marks[p] then label = label .. " *" end
		local py = (i - 1) * row_h + 0.2
		if locked then
			fs[#fs + 1] = string.format("label[0.2,%g;%s %s]", py + 0.15,
				current[p] and "[x]" or "[ ]", esc(label))
		else
			fs[#fs + 1] = string.format("checkbox[0.1,%g;f_%s;%s;%s]", py + 0.15, p,
				esc(label), current[p] and "true" or "false")
		end
		local desc = core.registered_privileges[p].description or ""
		if desc ~= "" then
			fs[#fs + 1] = string.format("tooltip[0.1,%g;%g,%g;%s]", py, w - 0.8, row_h, esc(desc))
		end
	end
	fs[#fs + 1] = "scroll_container_end[]"
	fs[#fs + 1] = string.format("scrollbaroptions[min=0;max=%d;smallstep=10;largestep=40]", max)
	fs[#fs + 1] = string.format("scrollbar[%g,%g;0.35,%g;vertical;scr;%d]", x + w - 0.4, y, h,
		math.min(st.scroll or 0, max))
	return table.concat(fs)
end

local HEAD = table.concat({
	"formspec_version[6]",
	"size[17,11]",
	"bgcolor[#14110FF2;both;#2A2420]",
	"listcolors[#2A2420;#3A2F28;#D9501F;#F2A541;#FFE3B0]",
	"style_type[label;textcolor=#F2A541]",
	"style_type[button;bgcolor=#8F2F12;textcolor=#FFE3B0]",
	"style_type[button:hovered;bgcolor=#D9501F]",
	"style_type[checkbox;textcolor=#E9E2D8]",
	"style_type[field;textcolor=#FFE3B0]",
}, "")

local function build(name)
	local st = state(name)
	if not roles then return HEAD .. "label[1,1;Still loading, try again in a moment.]" end
	local fs = {HEAD}
	fs[#fs + 1] = "label[0.4,0.45;CINDRIXCRAFT  PERMISSIONS]"
	fs[#fs + 1] = "tabheader[0,0;tab;Players,Roles;" .. st.tab .. ";false;true]"

	if st.tab == 1 then
		local players = known_players()
		if not st.player or not index_of(players, st.player) then
			st.player = players[1]
		end
		local items = {}
		for _, n in ipairs(players) do
			local online = core.get_player_by_name(n) ~= nil
			items[#items + 1] = (online and "#88FF88" or "#B8AFA3") .. esc(n)
		end
		fs[#fs + 1] = "label[0.4,1.2;Players  (green = online)]"
		fs[#fs + 1] = string.format("textlist[0.4,1.5;4.8,8.4;plist;%s;%d;false]",
			table.concat(items, ","), index_of(players, st.player) or 0)

		if st.player then
			local p = st.player
			local role_name = assignments[p]
			fs[#fs + 1] = string.format("label[5.6,1.2;%s]", esc(p))
			fs[#fs + 1] = "label[5.6,1.9;Role]"
			local names = role_names()
			local items2 = {"(unmanaged)"}
			for _, r in ipairs(names) do items2[#items2 + 1] = esc(r) end
			local sel = 1
			if role_name then sel = (index_of(names, role_name) or 0) + 1 end
			fs[#fs + 1] = string.format("dropdown[6.6,1.6;4,0.7;role_dd;%s;%d;false]",
				table.concat(items2, ","), sel)
			fs[#fs + 1] = "button[11,1.6;5.4,0.7;reset_ov;Remove this player's custom changes]"

			local current, marks
			if role_name then
				current = effective(p) or {}
				marks = {}
				for pr in pairs(overrides[p] or {}) do marks[pr] = true end
				fs[#fs + 1] = "label[5.6,2.7;Permissions   (* = changed for this player only)]"
			else
				current = core.get_player_privs(p)
				fs[#fs + 1] = "label[5.6,2.7;Permissions   (no role: changes apply directly)]"
			end
			if is_admin(p) then
				fs[#fs + 1] = "label[11,2.7;The host always has every permission.]"
			end
			fs[#fs + 1] = privilege_list(5.6, 3.1, 11, 6.8, st, current, marks, is_admin(p))
		end
	else
		local names = role_names()
		if not st.role or not roles[st.role] then st.role = names[1] end
		fs[#fs + 1] = "label[0.4,1.2;Roles]"
		local role_items = {}
		for _, r in ipairs(names) do role_items[#role_items + 1] = esc(r) end
		fs[#fs + 1] = string.format("textlist[0.4,1.5;4.8,6.4;rlist;%s;%d;false]",
			table.concat(role_items, ","), index_of(names, st.role) or 0)
		fs[#fs + 1] = "field[0.4,8.4;3.2,0.7;new_role;New role name;]"
		fs[#fs + 1] = "button[3.7,8.4;1.5,0.7;add_role;Add]"
		fs[#fs + 1] = "button[0.4,9.4;4.8,0.6;del_role;Delete selected role]"

		local role = roles[st.role]
		if role then
			local count = 0
			for _, r in pairs(assignments) do
				if r == st.role then count = count + 1 end
			end
			fs[#fs + 1] = string.format("label[5.6,1.2;%s   (%d player%s)]",
				esc(st.role), count, count == 1 and "" or "s")
			if role.all then
				fs[#fs + 1] = "label[5.6,1.9;This role always has every permission,\nincluding ones that mods add later.]"
				fs[#fs + 1] = privilege_list(5.6, 3.1, 11, 6.8, st, role_privs(st.role), nil, true)
			else
				fs[#fs + 1] = "label[5.6,1.9;Tick what this role is allowed to do.]"
				fs[#fs + 1] = privilege_list(5.6, 3.1, 11, 6.8, st, role_privs(st.role), nil, false)
			end
		end
	end

	fs[#fs + 1] = "label[0.4,10.55;Changes apply immediately. New players start as: " ..
		esc(default_role()) .. "]"
	fs[#fs + 1] = "button_exit[14.4,10.1;2.2,0.7;close;Close]"
	return table.concat(fs)
end

local function show(name)
	core.show_formspec(name, FORM, build(name))
end

local function can_edit(name)
	return core.check_player_privs(name, {privs = true})
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= FORM then return end
	local name = player:get_player_name()
	if not can_edit(name) then return end
	if fields.quit or fields.close then return end
	if not roles then return end
	local st = state(name)
	local changed = false
	-- Set when the event changed what the menu shows (role picked, role added...).
	-- Checkbox values in that same event belong to the old view, so they are ignored.
	local structural = false

	-- scroll position, so toggling a box does not jump back to the top
	if fields.scr then
		local num = tonumber(fields.scr:match(":(%-?%d+)"))
		if num then st.scroll = num end
	end

	-- tabs
	if fields.tab then
		local t = tonumber(fields.tab)
		if t and t ~= st.tab and (t == 1 or t == 2) then
			st.tab = t
			st.scroll = 0
			show(name)
			return
		end
	end

	if st.tab == 1 then
		local players = known_players()
		if fields.plist then
			local ev = core.explode_textlist_event(fields.plist)
			if (ev.type == "CHG" or ev.type == "DCL") and players[ev.index] then
				if st.player ~= players[ev.index] then st.scroll = 0 end
				st.player = players[ev.index]
				show(name)
				return
			end
		end
		local target = st.player
		if target and not is_admin(target) then
			-- role dropdown
			if fields.role_dd then
				local want = fields.role_dd
				if want == "(unmanaged)" then want = nil end
				local have = assignments[target]
				if want ~= have then
					if want and not roles[want] then want = have end
					-- do not let someone lock themselves out of this menu
					local ok = true
					if target == name and want then
						local probe = copy(role_privs(want))
						if not probe.privs then ok = false end
					end
					if ok then
						assignments[target] = want
						overrides[target] = nil
						if want then apply(target) end
						changed = true
						structural = true
					else
						core.chat_send_player(name, "You can't pick a role without the 'privs' permission for yourself.")
					end
				end
			end
			if fields.reset_ov then
				overrides[target] = nil
				apply(target)
				changed = true
				structural = true
			end
			-- checkboxes: compare each with what the player has now
			local current = assignments[target] and (effective(target) or {}) or core.get_player_privs(target)
			for _, p in ipairs(all_privs()) do
				local v = fields["f_" .. p]
				if v ~= nil and not structural then
					local want = (v == "true")
					if want ~= (current[p] == true) then
						if p == "privs" and target == name and not want then
							core.chat_send_player(name, "You can't remove your own 'privs' permission.")
						elseif assignments[target] then
							local base = role_privs(assignments[target])[p] == true
							overrides[target] = overrides[target] or {}
							if want == base then
								overrides[target][p] = nil
								if next(overrides[target]) == nil then overrides[target] = nil end
							else
								overrides[target][p] = want
							end
							apply(target)
							changed = true
						else
							local privs = core.get_player_privs(target)
							privs[p] = want or nil
							core.set_player_privs(target, privs)
							changed = true
						end
					end
				end
			end
		end
	else
		if fields.rlist then
			local names = role_names()
			local ev = core.explode_textlist_event(fields.rlist)
			if (ev.type == "CHG" or ev.type == "DCL") and names[ev.index] then
				if st.role ~= names[ev.index] then st.scroll = 0 end
				st.role = names[ev.index]
				show(name)
				return
			end
		end
		if fields.add_role then
			local rn = clean_role_name(fields.new_role)
			if rn == "" then
				core.chat_send_player(name, "Type a name for the new role first.")
			elseif roles[rn] then
				core.chat_send_player(name, "There is already a role called " .. rn .. ".")
			else
				roles[rn] = {all = false, privs = copy(role_privs("Member"))}
				st.role = rn
				changed = true
				structural = true
			end
		end
		if fields.del_role and st.role then
			if st.role == "Admin" or st.role == default_role() then
				core.chat_send_player(name, "The Admin role and the default role can't be deleted.")
			else
				local fallback = default_role()
				local gone = st.role
				roles[gone] = nil
				for player, r in pairs(assignments) do
					if r == gone then
						assignments[player] = fallback
						overrides[player] = nil
						apply(player)
					end
				end
				st.role = nil
				changed = true
				structural = true
			end
		end
		local role = st.role and roles[st.role]
		if role and not role.all and not structural then
			local current = role_privs(st.role)
			for _, p in ipairs(all_privs()) do
				local v = fields["f_" .. p]
				if v ~= nil then
					local want = (v == "true")
					if want ~= (current[p] == true) then
						role.privs[p] = want or nil
						changed = true
					end
				end
			end
			if changed then apply_role_members(st.role) end
		end
	end

	if changed then
		save_all()
	end
	show(name)
end)

--------------------------------------------------------------------------------
-- Chat commands
--------------------------------------------------------------------------------

core.register_chatcommand("perms", {
	description = "Open the permissions menu",
	privs = {privs = true},
	func = function(name)
		show(name)
		return true
	end,
})

core.register_chatcommand("roles", {
	description = "List the roles and how many players have each",
	privs = {privs = true},
	func = function(name)
		if not roles then return false, "Roles are not ready yet." end
		local lines = {}
		for _, r in ipairs(role_names()) do
			local count = 0
			for _, a in pairs(assignments) do
				if a == r then count = count + 1 end
			end
			lines[#lines + 1] = r .. " (" .. count .. ")"
		end
		return true, "Roles: " .. table.concat(lines, ", ")
	end,
})

core.register_chatcommand("role", {
	params = "<player> [role]",
	description = "Show a player's role, or give them one",
	privs = {privs = true},
	func = function(name, param)
		local who, role_name = param:match("^(%S+)%s*(.*)$")
		if not who then
			return false, "Usage: /role <player> [role]"
		end
		role_name = role_name:trim()
		if role_name == "" then
			return true, who .. " has the role: " .. (assignments[who] or "(none, left as it is)")
		end
		if not roles or not roles[role_name] then
			return false, "No role called " .. role_name .. ". See /roles."
		end
		if is_admin(who) then
			return false, "The host always has every permission."
		end
		if not core.get_auth_handler().get_auth(who) then
			return false, "Unknown player: " .. who
		end
		if who == name and not role_privs(role_name).privs then
			return false, "That role would remove your own 'privs' permission."
		end
		assignments[who] = role_name
		overrides[who] = nil
		apply(who)
		save_all()
		return true, who .. " is now " .. role_name .. "."
	end,
})

-- /op and /deop: quick way to make someone an operator (the Admin role)
local function can_op(name)
	return is_admin(name) or assignments[name] == "Admin"
end

core.register_chatcommand("op", {
	params = "<player>",
	description = "Make a player an operator (gives them the Admin role)",
	func = function(name, param)
		if not can_op(name) then
			return false, "Only the host or another operator can do this."
		end
		local who = param:trim()
		if who == "" then
			return false, "Usage: /op <player>"
		end
		if not roles or not roles.Admin then
			return false, "Roles are not ready yet."
		end
		if is_admin(who) then
			return true, who .. " is the host and already has every permission."
		end
		if not core.get_auth_handler().get_auth(who) then
			return false, "Unknown player: " .. who .. ". They need to join once first."
		end
		assignments[who] = "Admin"
		overrides[who] = nil
		apply(who)
		save_all()
		if core.get_player_by_name(who) then
			core.chat_send_player(who, "You are now an operator.")
		end
		return true, who .. " is now an operator."
	end,
})

core.register_chatcommand("deop", {
	params = "<player>",
	description = "Take operator status away (back to the default role)",
	func = function(name, param)
		if not can_op(name) then
			return false, "Only the host or another operator can do this."
		end
		local who = param:trim()
		if who == "" then
			return false, "Usage: /deop <player>"
		end
		if is_admin(who) then
			return false, "The host can't be removed as an operator."
		end
		if who == name then
			return false, "You can't remove yourself. Ask the host."
		end
		if assignments[who] ~= "Admin" then
			return false, who .. " is not an operator."
		end
		assignments[who] = default_role()
		overrides[who] = nil
		apply(who)
		save_all()
		if core.get_player_by_name(who) then
			core.chat_send_player(who, "You are no longer an operator.")
		end
		return true, who .. " is no longer an operator."
	end,
})

-- API used by cindrix_access (/adduser)
function cindrix_perms.has_role(role_name)
	return roles ~= nil and roles[role_name] ~= nil
end

function cindrix_perms.default_role()
	return default_role()
end

-- Gives a player a role (their own custom changes are cleared). nil = default role.
function cindrix_perms.set_role(who, role_name)
	if not roles then return false, "roles are not ready yet" end
	role_name = role_name or default_role()
	if not roles[role_name] then return false, "no role called " .. role_name end
	if is_admin(who) then return false, "the host always has every permission" end
	assignments[who] = role_name
	overrides[who] = nil
	apply(who)
	save_all()
	return true
end

core.log("action", "[" .. modname .. "] loaded")

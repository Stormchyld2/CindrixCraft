-- CindrixCraft: a small record of everyone who has played in this world.
--
-- Luanti itself already saves each player's position, inventory, health and
-- privileges inside the world, so players pick up where they left off. This
-- mod adds a list of names with first-join and last-seen times, so commands
-- and menus can talk about players who are offline too.

cindrix_players = {}

local storage = core.get_mod_storage()
local data = {}

do
	local raw = storage:get_string("players")
	if raw ~= "" then
		data = core.parse_json(raw) or {}
	end
end

local function save()
	storage:set_string("players", core.write_json(data))
end

local function touch(player, joined)
	local name = player:get_player_name()
	local now = os.time()
	local rec = data[name] or {first_join = now, joins = 0}
	if joined then
		rec.joins = (rec.joins or 0) + 1
	end
	rec.last_seen = now
	local pos = player:get_pos()
	rec.last_pos = {x = math.floor(pos.x + 0.5), y = math.floor(pos.y + 0.5), z = math.floor(pos.z + 0.5)}
	data[name] = rec
end

-- All players we know of: recorded, online, and anyone in the world's login database.
function cindrix_players.known()
	local set = {}
	for name in pairs(data) do
		set[name] = true
	end
	for _, p in ipairs(core.get_connected_players()) do
		set[p:get_player_name()] = true
	end
	local ok, handler = pcall(core.get_auth_handler)
	if ok and handler and handler.iterate then
		pcall(function()
			for name in handler.iterate() do
				set[name] = true
			end
		end)
	end
	local list = {}
	for name in pairs(set) do
		list[#list + 1] = name
	end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

function cindrix_players.is_online(name)
	return core.get_player_by_name(name) ~= nil
end

function cindrix_players.get(name)
	return data[name]
end

core.register_on_joinplayer(function(player)
	touch(player, true)
	save()
end)

core.register_on_leaveplayer(function(player)
	touch(player, false)
	save()
end)

core.register_on_shutdown(function()
	for _, p in ipairs(core.get_connected_players()) do
		touch(p, false)
	end
	save()
end)

-- Keep last positions fresh in case the game stops suddenly
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 120 then return end
	timer = 0
	for _, p in ipairs(core.get_connected_players()) do
		touch(p, false)
	end
	save()
end)

local function ago(seconds)
	if seconds < 90 then return "a moment ago" end
	local minutes = math.floor(seconds / 60)
	if minutes < 90 then return minutes .. " minutes ago" end
	local hours = math.floor(minutes / 60)
	if hours < 48 then return hours .. " hours ago" end
	return math.floor(hours / 24) .. " days ago"
end

core.register_chatcommand("seen", {
	params = "<player>",
	description = "Show when a player was last online and where",
	func = function(name, param)
		local target = param:trim()
		if target == "" then
			return false, "Usage: /seen <player>"
		end
		if core.get_player_by_name(target) then
			return true, target .. " is online now."
		end
		local rec = data[target]
		if not rec then
			return false, "Never seen " .. target .. " in this world."
		end
		local p = rec.last_pos or {x = 0, y = 0, z = 0}
		return true, string.format("%s was last seen %s at (%d, %d, %d).",
			target, ago(os.time() - (rec.last_seen or 0)), p.x, p.y, p.z)
	end,
})

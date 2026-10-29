-- cindrix_core: shared helpers and server tweaks for CindrixCraft.
-- Other cindrix_* mods can depend on this one and use the `cindrix` table.

cindrix = {}
cindrix.modname = core.get_current_modname()
cindrix.modpath = core.get_modpath(cindrix.modname)

-- Greet players when they join
core.register_on_joinplayer(function(player)
	core.chat_send_player(player:get_player_name(), "Welcome to CindrixCraft!")
end)

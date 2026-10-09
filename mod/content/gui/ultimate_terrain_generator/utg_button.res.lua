-- Registers the Ultimate Terrain Generator button in the game's mod button area (the "mods" strip of the
-- game button ridge). The resource type names the base game's extension point
-- (base: gui/main/main_mod_button_area.tl registers "MainModButtonAreaExtension" under the base mod id "",
-- hence "::MainModButtonAreaExtension"); filePath points to the exported plugin recipe of our script.
function data()
	return {
		type = "react-plugin ::MainModButtonAreaExtension",
		data = {
			filePath = "ultimate_terrain_generator::/gui/ultimate_terrain_generator/utg_studio.script@UtgModButtonPlugin",
			order = 110,
		}
	}
end

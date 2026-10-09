--[[
climate.lua - climate profiles as data (pure Lua 5.2): what each of the game's four climates needs from the terrain.

WHY (2026-10-08, framework for climates beyond Temperate; facts from the game's climate files)
  The game paints snow, rock, sand, beaches and forests from ABSOLUTE heights, with different lines per climate
  (Temperate snow from ~330-430 m, Subarctic 210-250 m, Tropical rock 210-250 m, Dry none), and each climate suits
  different landscapes (fjords, mesas, volcanic islands). This table collects those facts in one place so the Studio
  (and later the generator itself) can read them. Only Temperate is finished and tested in game; the other profiles
  are first values from the game files and change only after their in-game probe.

  STATUS: data only. pipeline.lua does NOT read it yet, so every map is generated exactly as before (offline regression test).
  Planned uses: the Studio lists the map types that fit the climate first; per-climate presets scale rivers and lakes;
  a Relief floor so Subarctic and Tropical heights reach their snow and rock lines; the finishing-pass builder
  (the climate's finishing-pass generator) and these numbers stay in step.

USE
  local climate = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/climate.lua"
  local p = climate.profile(api.res.getBaseConfig().climate)   -- never nil (unknown climates get Temperate's)
  p.key, p.label, p.finished, p.snowLine, p.rockLine, p.fits (map type ids), p.newTypes (planned climate types)
]]

local M = {}

-- heights in metres above sea level (0 m); lines are where the climate tree's ramps start (approximate)
M.PROFILES = {
	temperate = {
		key = "temperate", label = "Temperate", finished = true,
		snowLine = 330, rockLine = 280,
		fits = { "great_river_valley", "delta_lowlands", "mountain_passes", "rolling_plains", "lake_district",
			"large_bays", "peninsulas", "island_chain", "coastal_region", "highland_plateau" },
		newTypes = {},
		rivers = 1, lakes = 1,
	},
	subarctic = {
		key = "subarctic", label = "Subarctic", finished = false,
		snowLine = 210, rockLine = 130,                -- subarctic_clima.tree.lua: snow 210 -> 250 m, rock 130 -> 160 m
		fits = { "lake_district", "peninsulas", "large_bays", "island_chain", "coastal_region", "highland_plateau",
			"mountain_passes" },
		newTypes = { "fjord_coast" },
		rivers = 1, lakes = 1.75,                      -- finger lakes; vanilla Subarctic has no rivers layer
	},
	tropical = {
		key = "tropical", label = "Tropical", finished = false,
		snowLine = nil, rockLine = 210,                -- tropical_clima.tree.lua: rock 210 -> 250 m; beach -0.6 -> 0.3 m
		fits = { "island_chain", "delta_lowlands", "large_bays", "coastal_region", "peninsulas", "great_river_valley",
			"mountain_passes" },
		newTypes = { "volcanic_islands" },
		rivers = 1.3, lakes = 1,
	},
	dry = {
		key = "dry", label = "Dry", finished = false,
		snowLine = nil, rockLine = nil,                -- dry_clima.tree.lua: no snow ramp; bands at 16-17, 29-30 m
		fits = { "great_river_valley", "highland_plateau", "rolling_plains", "mountain_passes", "delta_lowlands",
			"coastal_region" },
		newTypes = { "mesa_country" },
		rivers = 0.4, lakes = 0.5,                     -- vanilla Dry river order 2 vs 6; terminal lakes only
	},
}

-- "::/climates/dry/dry.clima" (or "dry.clima", "dry") -> the profile; unknown or nil -> Temperate
function M.profile(climateRes)
	local s = tostring(climateRes or "")
	local key = s:match("([%a_]+)%.clima$") or s:match("^([%a_]+)$")
	return M.PROFILES[key or ""] or M.PROFILES.temperate
end

-- true when the map type is one of the climate's good fits
function M.fits(profile, mapType)
	for _, id in ipairs(profile.fits) do
		if id == mapType then return true end
	end
	return false
end

return M

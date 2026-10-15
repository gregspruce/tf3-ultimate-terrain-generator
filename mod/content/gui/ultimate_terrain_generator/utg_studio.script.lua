--[[
Ultimate Terrain Generator - Studio window (map editor only).

WHAT IT DOES
  A "UTG" button in the mod button area opens the Studio:
    tabs   Settings (map type, relief, water, ship rivers, side, Great River Valley's sea, seed; Lower tree density
           for the finishing pass) / Terrain parameters (one slider per pipeline.TUNE entry) / Report (the map
           report). Run 5: four sparse tabs meant too much switching; run 6: the sliders on their own tab, fields
           side by side, more spacing, a window sized to the screen with the preview pane always beside the
           settings, and "Larger window" (a second size; windows cannot be dragged to any size)
    Generate  runs the terrain core (scripts/ultimate_terrain_generator/core/pipeline.lua) spread over frames
              (react.onStep + pipeline.job with a time budget per frame), so the editor stays responsive
    Preview   generates (if the settings changed) and runs the finishing pass of this climate (an import-style
              generator that keeps our heights and adds biomes, forests, rock, river trees and the data maps) on the
              generated heights, in this window, through the map editor's Import biomes mode
    Apply     replaces the world terrain with the finished preview (or with the bare heights where this climate has
              no finishing pass); when the settings changed since that preview, or there is none, it first runs
              what Preview runs and applies the new map when it is ready (owner 2026-10-13, run 9)
    Undo      puts back the terrain from before the last Apply (trees are not restored)
    Test set  (debug) generates a fixed list of cases (TEST_SET: map types, Relief, Water; one seed) on this map size
              and exports each one's heights, without touching the world: standard data for comparing builds.
    Run test  (debug) one button for an in-game check: previews, applies, exports the finished map (with its biome
              masks) and the world, saves the log (see "Debug: Run test" below)
    Save log  (debug) writes this session's [UTG] lines (with times) into the editor's heightmap folder as
              utg_log_<id>.lua, next to the exports (stdout.txt is cleared when the game restarts); the test set
              saves its log by itself when it ends
    Export    (debug) writes the world's heightmap as a 16-bit PNG with the editor's own exporter
              (app.writeHeightmap, as gui/map_editor/map_editor.tl does). The file name carries the Generate id,
              map type, relief and seed, and an "[UTG] Export" line repeats the full settings and the height
              range (the PNG is normalised to the map's own min..max), so every export matches its log lines.
  Every step is logged to stdout.txt with the prefix "[UTG]".
  The window wraps the game's own Window recipe even when another mod replaced builtin.Window (which made the game
  crash when the window opened, 2026-10-13); if that is impossible the mod button says why ("The window recipe" below).

VERIFIED IN GAME (diagnostic test runs 1-4, 2026-10-06)
  - GameMap.heightmap returns a copy on every read: heights are written by assigning the whole table.
  - makeWorldReplaceTerrainCmd(map, baseConfig.terrain, seed, world, keepAssets) applies a map.
  - builtin.MapPreviewComp in a mod window previews a generator with our inputs, only when its inputs change.
  - An import-style generator with keepHeightmap kept our heights (without keepHeightmap it crashes the game) and
    its Apply created all 9 data maps. Since the game update of 2026-10-08 that route gets no usable heights (no
    trees, default textures, run 10); the Import biomes mode does (run 12): see "The finishing pass" below.
  - Run 5: react.onStep(fn) runs fn every frame, coroutine and os.clock exist in the GUI Lua, a Lua-built map is a
    valid MapPreviewComp input, and Apply / Undo work (16 km map).
FROM THE GAME'S FILES, NOT YET SEEN IN THIS WINDOW
  - builtin.Slider (integer min/max/step/value, onValueChange; base/tealdef/scripts/builtin.d.tl SliderParam).

Plain Lua 5.2 (the engine's version).
]]

local react = require "::/gui/main/react.lua"
local builtin = require "::/gui/main/builtin.lua"
local game_react_globals = require "::/gui/main/game_react_globals.tl"
local main_mod_button_area = require "::/gui/main/main_mod_button_area.tl"

local CORE = "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/"
local pipeline = require(CORE .. "pipeline.lua")
local report = require(CORE .. "report.lua")
local shapes = require(CORE .. "shapes.lua")
local climates = require(CORE .. "climate.lua")
-- the game's own generators and the steps around Apply (engine-facing; not part of the terrain core)
local eg = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/studio/engine_generators.lua"

local PREFIX = "[UTG] "
local FRAME_BUDGET = 0.025 -- seconds of terrain work per frame while generating
local FINISH_TAG = "utg_finish_" -- our finishing-pass generators: content/climates/<climate>/utg_finish_<climate>.gen.lua
-- the finishing pass's tree density parameter (declared in its gen.lua by tools/build_finish_tree.py, TREE_KEY there;
-- the key is kept from the Forests setting it replaced)
local TREES_KEY = "utg_forests"
local HEIGHT_MIN, HEIGHT_MAX = -99, 3170 -- inside the engine's valid range (-100 .. 3176.75 m, probe run 2)

-- ------------------------------------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------------------------------------
-- Every [UTG] line of this game session, with its UTC time, for "Save log" (stdout.txt is cleared when the game
-- restarts; the owner asked for a button that puts the UTG lines next to the exports, run 6)
-- Mod setting "Debug tools" (mod.json utg_debug_tools; Off by default, owner 2026-10-09): the window's Debug row
-- (Export, Test set, Run test, Save log) is shown only when it is On. Mod settings are fixed while a map is open
-- (chosen before loading), so it is read once. getModParams values are 1-based: 1 = Off, 2 = On.
local debugToolsOn = nil
local function debugTools()
	if debugToolsOn == nil then
		local ok, all = pcall(function() return api.engine.config.getModParams() end)
		local own = ok and type(all) == "table" and all["ultimate_terrain_generator"] or nil
		debugToolsOn = type(own) == "table" and tonumber(own.utg_debug_tools) == 2
	end
	return debugToolsOn
end

local LOG_LINES = {}
local LOG_MAX = 20000

local function out(line)
	if log ~= nil and log.message ~= nil then
		log.message(PREFIX .. line)
	else
		print(PREFIX .. line)
	end
	local okT, stamp = pcall(function() return os.date("!%Y-%m-%d %H:%M:%SZ") end)
	if #LOG_LINES >= LOG_MAX then table.remove(LOG_LINES, 1) end
	LOG_LINES[#LOG_LINES + 1] = (okT and type(stamp) == "string" and ("[" .. stamp .. "] ") or "") .. PREFIX .. line
end

local clock = (os ~= nil and os.clock) or function() return 0 end

-- Window text goes through the game's translation function (keys and English text in strings.json). Base GUI code
-- calls the global _(); if a mod script does not see it, the English text is shown.
local function T(s)
	if type(_) == "function" then
		local ok, translated = pcall(_, s)
		if ok and type(translated) == "string" then return translated end
	end
	return s
end

local function vbox(children)
	return builtin.BoxLayout{ orientation = builtin.type.Orientation.Vertical, children = children }
end

local function hbox(children)
	return builtin.BoxLayout{ orientation = builtin.type.Orientation.Horizontal, children = children }
end

local function text(s)
	return builtin.TextView{ text = T(s) }
end

-- kind: "primary" (filled: main actions) or "secondary" (outlined); enabled = false greys the button out. The game's
-- plain Button has an invisible background and border (base main/builtin.css.lua:140-160), which players read as text
-- ("the buttons don't look like buttons", 2026-10-08); base windows use these classes (main/default.css.lua:77-120)
-- and meta.enabled (gui/map_editor/map_editor.tl:733).
-- tip: tooltip (translated text), e.g. why a button is greyed out
local function button(label, onClick, kind, enabled, tip)
	return builtin.Button{
		meta = { class = (kind or "secondary") .. ", utg-button", enabled = enabled ~= false, tooltip = tip },
		content = builtin.TextView{ meta = { class = "font-scale-body" }, text = T(label) },
		onClick = onClick,
	}
end

-- Runs a handler in pcall so a failing engine call is logged and shown instead of breaking the window.
local function guarded(label, fn, setStatus)
	local ok, err = pcall(fn)
	if not ok then
		out(label .. " FAILED: " .. tostring(err))
		if setStatus then setStatus(label .. " failed: " .. tostring(err)) end
	end
end

local function mapBounds()
	local box = api.engine.terrain.getBoundingBox()
	return box.min.x, box.min.y, box.max.x, box.max.y
end

-- Heightmap grid of a GameMap: (size / 4 m + 1)^2 samples, index j * W + i + 1 from the map's min corner.
local function gridOf(map)
	local step = (map.resolution and map.resolution.x) or 4
	return map.numTilesX * 256 / step + 1, map.numTilesY * 256 / step + 1, step
end

local function newSeed()
	local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	local s = {}
	for i = 1, 10 do
		local r = math.random(1, #chars)
		s[i] = chars:sub(r, r)
	end
	return table.concat(s)
end

-- Id of a Generate: date and time (unique across sessions, sortable), or a counter if os.date is missing.
local idCounter = 0
local function newId()
	idCounter = idCounter + 1
	local ok, t = pcall(function() return os.date("%Y%m%d_%H%M%S") end)
	if ok and type(t) == "string" then return t end
	return string.format("run%03d", idCounter)
end

local function sendReplaceTerrain(map, keepAssets, label, seed, onDone)
	pcall(function() api.gui.map.reloadMaterialIndexManagerPipeline() end)
	local t0 = clock()
	api.cmd.sendCommand(api.cmd.makeWorldReplaceTerrainCmd(map, api.res.getBaseConfig().terrain, seed or "",
		api.engine.util.getWorld(), keepAssets), function(_data, success)
			out(string.format("%s: terrain replaced, success=%s after %.2f s", label, tostring(success), clock() - t0))
			if onDone ~= nil then
				local ok, err = pcall(onDone, success)
				if not ok then out(label .. " after-apply step FAILED: " .. tostring(err)) end
			end
		end)
end

-- The finishing-pass generator of the current climate (editor only), or nil; second value: whether that pass declares
-- the tree density parameter. Only a pass built to thin its trees declares it (tools/build_finish_tree.py: Temperate's;
-- the Subarctic, Tropical and Dry passes of revision 4 have none, so their climates get no box that does nothing). The
-- declared parameters are read as the base editor reads them (gui/map_editor/map_editor.tl addMissingGeneratorParams).
local function finishingGenerator()
	local climate = api.res.getBaseConfig().climate
	for k, _ in pairs(app.res.terrainGeneratorRep.getAll()) do
		local gen = app.res.terrainGeneratorRep.get(k)
		local name = tostring(app.res.terrainGeneratorRep.getName(k))
		if gen.climate == climate and gen.isImportGenerator and name:find(FINISH_TAG, 1, true) then
			local trees = false
			for _, p in ipairs(gen.params or {}) do
				if p.key == TREES_KEY then trees = true end
			end
			return name, trees
		end
	end
	return nil, false
end

-- The climate of this map and the finishing pass used, for the Run test and Apply log lines (revision 4: the passes of
-- four climates; Subarctic's, Tropical's and Dry's climate strings had never been seen in a log), so run material shows
-- which climate and pass it came from. pass: the pass's name, "none" (the bare heights), or nil for a game generator's
-- map (no pass involved). Kept out of settingsText: export_check parses that, and the stale-preview note compares it.
local function climateText(pass)
	local okC, climate = pcall(function() return api.res.getBaseConfig().climate end)
	local s = "climate " .. tostring(okC and climate or "?")
	if pass ~= nil then s = s .. ", finishing pass " .. tostring(pass) end
	return s
end

-- After every Apply: what the game's data maps say (TERRAIN.dataMaps, 32 m cells, values 0..1; industries research
-- doc T5). For each map: its share of the map (cells above 0.5) and the mean ground height there. If the finishing
-- pass sees our real heights, biome0 is the water (below 0 m), biome4 (in Temperate) the high ground and forest_mask
-- covers land; if its height input arrives wrong (flat, zero), the bands do not follow the terrain. Which maps exist and
-- what each band means is the climate's (Dry has no forest_mask and orders its bands 0-2-1-4-3; the keys are listed as
-- found).
local function logDataMaps(label)
	local ok, err = pcall(function()
		local terrain = api.engine.getComponent(api.engine.util.getWorld(), api.type.ComponentType.TERRAIN)
		local maps = terrain and terrain.dataMaps
		if maps == nil then out(label .. ": no data maps") return end
		local minX, minY = mapBounds()
		local names = {}
		for k, _ in pairs(maps) do names[#names + 1] = tostring(k) end
		table.sort(names)
		if #names == 0 then out(label .. ": no data maps") return end
		for _, k in ipairs(names) do
			local m = maps[k]
			local sz = m:getSize()
			local nx = type(sz) == "number" and sz or (sz.x or sz[1])
			local ny = type(sz) == "number" and sz or (sz.y or sz[2])
			local stride = math.max(1, math.floor(math.max(nx, ny) / 96))
			local cells, hits, hsum = 0, 0, 0
			for y = 1, ny - 2, stride do
				for x = 1, nx - 2, stride do
					cells = cells + 1
					if m:at(x, y) > 0.5 then
						hits = hits + 1
						hsum = hsum + api.engine.terrain.getBaseHeightAt(api.type.Vec2f.new(minX + 32 * (x + 0.5),
							minY + 32 * (y + 0.5)))
					end
				end
			end
			out(string.format("%s: data map %s: %.0f %% of the map, mean height there %s", label, k,
				100 * hits / math.max(1, cells), hits > 0 and string.format("%.0f m", hsum / hits) or "-"))
		end
	end)
	if not ok then out(label .. ": reading the data maps FAILED: " .. tostring(err)) end
end

-- ------------------------------------------------------------------------------------------------
-- Studio state (module level: survives closing the window; large data stays out of react state)
-- ------------------------------------------------------------------------------------------------
local MAP_TYPES = {} -- from the core, in its order
for i, id in ipairs(shapes.ORDER) do MAP_TYPES[i] = { id = id, label = shapes.TYPES[id].label or id } end
-- from the core (pipeline.RELIEF; run 6: Flat dropped, Moderate and Rugged added); the box opens at
-- pipeline.DEFAULT_RELIEF (Hilly, the middle step; owner 2026-10-12, REVIEW B1)
local RELIEF = {}
for i, r in ipairs(pipeline.RELIEF) do RELIEF[i] = r.label end
local WATER = { "Dry", "Normal", "Wet" }
-- Lower tree density (owner 2026-10-13, run 9: "change the forest drop down to a checkbox that is 'Lower Tree Density'";
-- it replaced the Forests box Few / Normal / Many of REVIEW B7): a setting of the finishing pass, not of the terrain
-- core. Unticked = Normal (index 1, the pass as approved in runs 4-6, 9 and 12-13), ticked = Lower (index 2: the pass
-- places half the trees; where forests grow, forest_mask and every other data map stay the same). It stays out of
-- settingsText (heights, their logs and the baselines do not depend on it), so a change alone re-runs only the
-- finishing pass, not Generate. Log text per index (log lines are not translated):
local TREES_LOG = { "trees normal", "trees lower" }
local SHIPS = { "Map type default", "None", "One", "Several" } -- index 1 = nil (default), else index - 2
-- feature side (owner 2026-10-08): index 1 = from the seed, 2..5 = shapes.SIDES north, east, south, west; 6 = None (no
-- sea, owner 2026-10-11), offered only on the map types that allow it (shapes.TYPES[id].side.none). A type with its own
-- choices (side.choices: Sea Strait's direction, owner 2026-10-12) lists Random and those (values 1..4 to the core)
local SIDES = { "Random", "North", "East", "South", "West" }
local SIDE_NONE_INDEX = shapes.SIDE_NONE + 1
local function sideChoices(info)
	if info.side and info.side.choices then
		local t = { SIDES[1] }
		for i, l in ipairs(info.side.choices) do t[i + 1] = l end
		return t
	end
	if not (info.side and info.side.none) then return SIDES end
	local t = {}
	for i, l in ipairs(SIDES) do t[i] = l end
	t[SIDE_NONE_INDEX] = "None"
	return t
end

-- The side box's choice a map type pre-selects (window index): its side.default (shapes.lua; Alpine None, owner
-- 2026-10-13, REVIEW C5), else Random.
local function defaultSide(id)
	local sd = shapes.TYPES[id].side
	return ((sd and sd.default) or 0) + 1
end

-- S.settings.side is the player's choice, or nil while they have not chosen one: then the box shows, and the core gets,
-- the map type's pre-selected side (so the window can start on any type, and coming back to Alpine shows None again).
local function sideIndex(st)
	return st.side or defaultSide(MAP_TYPES[st.mapType].id)
end

-- Owner 2026-10-11: after a map type change every control must show what will be used. An edge the player chose (North,
-- East, South, West or None) stays when it names the same edge on the new type (same label and edge, e.g. Sea side on
-- both) and the new type offers it (None only where allowed). Otherwise nil: the new type's pre-selected side, which
-- the side box then shows. Random is not carried (it names no edge), nor a type's pre-selection (Alpine's None does not
-- follow the player to Mountain Range; REVIEW C5, 2026-10-13).
local function sideAfterTypeChange(oldId, newId, side)
	if side == nil or side == 1 then return nil end
	local a, b = shapes.TYPES[oldId].side, shapes.TYPES[newId].side
	if not (a and b and a.label == b.label and a.edge == b.edge) then return nil end
	if side > #sideChoices(shapes.TYPES[newId]) then return nil end
	return side
end

-- Sea (owner 2026-10-12, REVIEW B8): a map type whose side box names where its river comes from and whose sea is a
-- setting of its own (shapes.TYPES[id].side.seaChoice: Great River Valley) gets its own box under the side box:
-- index 1 = the sea where the river ends, 2 = None (no sea: the river leaves the map there). Every map type change
-- resets it (only this type has it, so it is never revived on coming back, like the side after Island Chain).
local SEA = { "At the river mouth", "None" }
-- the core's `sea` setting for a window choice on a map type: false = no sea, nil = the sea (an explicit if: the
-- idiom "cond and false or nil" can never give false)
local function seaSetting(id, choice)
	local sd = shapes.TYPES[id].side
	if choice == 2 and sd and sd.seaChoice then return false end
	return nil
end

-- Ship rivers choices; the first names the map type's own default, so the box shows what "default" will give
local function shipChoices(info)
	local t = {}
	for i, l in ipairs(SHIPS) do t[i] = l end
	local def = info.preset and info.preset.ships
	if def ~= nil and SHIPS[def + 2] ~= nil then
		t[1] = { text = T("Map type default") .. " (" .. T(SHIPS[def + 2]) .. ")" }
	end
	return t
end
-- Advanced sliders: percent of the designed value (100 = as designed), one per pipeline.TUNE entry
local TUNE_LABELS = {
	height = "Overall height", hills = "Hill country", hillHeight = "Hill height", detail = "Surface detail",
	coast = "Coast roughness", rivers = "Rivers", lakes = "Lakes", meander = "River bends", valley = "Valley width",
	gullies = "Erosion",
}
-- What each slider does on the map, in plain words for players new to terrain generation (owner 2026-10-13, REVIEW B2:
-- "'Hill Country' and 'Hill Height' need at least a tooltip explaining what they do"). Each text follows the core's
-- real use of the multiplier (pipeline.TUNE): height = the Terrain step's height target (landform target; the hills and
-- raised ground scale with it); hills = the share of the land in hill-country patches (landform HILL_COVER; 50-60 % at
-- 100 %, all of it at 200 %); hillHeight = how high those hills rise (HILL_AMP), not where they are; detail = metre-scale
-- roughness on hill country and steep ground (detail.DETAIL_AMP; none on plains, floodplains, beaches and pass floors);
-- gullies = spurs and gullies down
-- the slopes, deeper on steeper ground (gullies.lua), 0 = off; coast = the ragged noise on the coastline
-- (shapes.COAST_RAG), none without sea; rivers = divides the drained area a river needs (smaller valleys get rivers);
-- lakes = the lakes wanted on the rivers (natural basins only; oxbow lakes are not counted); meander = how strongly
-- rivers wind (0: only the valley's gentle curve is left); valley = the width of the floodplains and valley sides.
-- Overall height's tooltip depends on the climate (HEIGHT_TIPS below), so it is not in this table.
local TUNE_TIPS = {
	hills = "How much of the land is hill country: patches of hills a few kilometres across, with lower, open land between them. Lower it for more open land for towns and railways; raise it for more hills (at 200 % nearly all the land). How tall the hills are is Hill height.",
	hillHeight = "How tall the hills in the hill country are. Lower it for low, gentle hills that roads and railways cross easily; raise it for tall, steep hills. Where the hills are and how much land they cover stays the same (that is Hill country).",
	detail = "Small bumps a few metres high on hills and slopes, so they look natural rather than smooth. Plains, valley floors and beaches get none, so they stay easy to build on. Lower it for smoother hills, raise it for rougher, rockier ground.",
	gullies = "Ridges and gullies running down the slopes, as if carved by rain over a long time; the steeper the slope, the deeper they are. Flat land gets none. 0 % turns them off for smooth slopes; raise it for rugged hillsides.",
	coast = "How ragged the coastline is: coves, headlands and small bays. Lower it for a smoother, straighter coast; raise it for a more jagged one. No effect on maps without sea.",
	rivers = "How many rivers and streams the map gets. Above 100 % smaller valleys get their own streams, so there are more rivers reaching further up into the hills; below 100 % only the larger rivers are left. The Water setting sets the starting amount.",
	lakes = "How many lakes form along the rivers (up to 300 %). Lakes need natural hollows, so above 100 % a map may have no room for more; the Report then says so. 0 % gives no lakes apart from small oxbow lakes beside river bends.",
	meander = "How much the rivers wind. 0 % gives almost straight rivers that follow the valley's gentle curve, easy to run a railway beside; raise it for wide, looping bends.",
	valley = "How wide the flat valley floors along the rivers are. Wider valleys give more flat land beside the rivers for towns, stations and railways; at 0 % the valleys are narrow with steep sides.",
}
-- The Terrain box's tooltip per climate (core/climate.lua profile key; a climate it does not know gets Temperate's, as
-- profile() does). The map types and their heights are Temperate's in every climate (revision 4), but each climate paints
-- snow and bare rock from its own heights (climate trees; climate.lua snowLine, rockLine): Temperate rock from ~280 m,
-- snow from ~330 m; Subarctic rock from ~130 m, snow from ~210 m; Tropical no snow, bare rock from ~210 m; Dry neither.
-- Which Terrain steps reach 210 m (2026-10-14: the core baseline's maps at Gentle, Hilly and Mountainous plus a scratch
-- run at Moderate and Rugged with its generator; 11 km, seeds 1 and 2, sliders 100 %). Two measures, named in the text:
-- "reach it" = the map's P99 height is at or above 210 m (a band of snow or rock, not a lone summit); "only a few peaks"
-- and "hardly ever" = only the highest point is. Alpine (P99 305-345 m), Mountain Range (224-243 m) and Highland
-- Plateau (~220 m) reach it at Gentle; most other map types from Moderate (P99 232-302 m; at Gentle their P99 is
-- 166-197 m); Island Chain and Rolling Plains only a few peaks from Rugged (highest point 211-269 m; one Island Chain
-- map has a single 233 m top at Hilly); Delta Lowlands hardly ever (at most a spot at Mountainous: highest point
-- 192 / 252 m, P99 156-161 m). Temperate's text is unchanged (DESIGN 18, 2026-10-12).
local TERRAIN_TIPS = {
	temperate = "Hilly is the middle step. Gentle gives the most flat land, higher is steeper. Snow from about 330 m: Alpine's peaks reach it from Gentle, the highest hills of most other map types from Hilly.",
	subarctic = "Hilly is the middle step. Gentle gives the most flat land, higher is steeper. Snow from about 210 m: Alpine, Mountain Range and Highland Plateau reach it from Gentle, most other map types from Moderate; Island Chain and Rolling Plains only a few peaks from Rugged; Delta Lowlands hardly ever (at most a spot at Mountainous).",
	tropical = "Hilly is the middle step. Gentle gives the most flat land, higher is steeper. No snow. Bare rock from about 210 m: Alpine, Mountain Range and Highland Plateau reach it from Gentle, most other map types from Moderate; Island Chain and Rolling Plains only a few peaks from Rugged; Delta Lowlands hardly ever (at most a spot at Mountainous).",
	dry = "Hilly is the middle step. Gentle gives the most flat land, higher is steeper. No snow.",
}
-- The Overall height slider's tooltip per climate (revision 4, review 2026-10-14): what higher land brings on the peaks
-- is the climate's, as in TERRAIN_TIPS: snow in Temperate and Subarctic, bare rock in Tropical, neither in Dry; a
-- climate climate.lua does not know gets Temperate's. Temperate's and Subarctic's text is the one all climates had before.
local HEIGHT_TIPS = {
	temperate = "How high the whole land rises: hills, mountains and plateaus together. Lower it for flatter land that is easier for railways and roads; raise it for higher, steeper land with more snow on the peaks. 0 % gives almost flat land.",
	tropical = "How high the whole land rises: hills, mountains and plateaus together. Lower it for flatter land that is easier for railways and roads; raise it for higher, steeper land with more bare rock on the peaks. 0 % gives almost flat land.",
	dry = "How high the whole land rises: hills, mountains and plateaus together. Lower it for flatter land that is easier for railways and roads; raise it for higher, steeper land. 0 % gives almost flat land.",
}
HEIGHT_TIPS.subarctic = HEIGHT_TIPS.temperate
-- This map's climate profile (core/climate.lua, data only: name, fitting map types, whether the map types are its own)
-- and whether climate.lua knows the climate at all. profile() gives a climate it does not know (one another mod adds)
-- Temperate's profile, so the climate note must not use it there: it would name Temperate and Temperate's map types
-- (review 2026-10-14). The key is read from the climate's resource name the way profile() reads it
-- ("::/climates/dry/dry.clima" -> "dry"); the core stays unchanged.
local function climateProfile()
	local res = tostring(api.res.getBaseConfig().climate or "")
	local key = res:match("([%a_]+)%.clima$") or res:match("^([%a_]+)$")
	return climates.profile(res), key ~= nil and climates.PROFILES[key] ~= nil
end
local function defaultTune()
	local t = {}
	for _, e in ipairs(pipeline.TUNE) do t[e.key] = 100 end
	return t
end

local S = {
	-- side = nil: none chosen yet, the map type's pre-selected side (sideIndex)
	settings = { mapType = 1, relief = pipeline.DEFAULT_RELIEF, water = 2, ships = 1, side = nil, sea = 1, seed = nil,
		trees = 1, -- the finishing pass's tree density: 1 = Normal, 2 = Lower (the Lower tree density box ticked)
		tune = defaultTune(),
		-- on Apply, like the game's own generator window: towns and industries are removed unless kept
		keepTowns = false, keepIndustries = false },
	-- the generator the window runs: "utg" (this mod's core) or a game generator's name (studio/engine_generators.lua)
	source = "utg",
	engine = { params = {}, seed = nil, list = nil }, -- per generator name: { key = value }; the list is cached
	requestKind = nil, -- "utg" or "engine": what the current preview request came from
	requestText = nil, -- the settings the current preview request was made with (stale-preview note)
	requestTrees = nil, -- the tree density of the last finishing-pass request (stale-preview note, Apply log); kept
	                    -- when closing the window clears S.request, as S.ready is; nil when the pass has no such parameter
	requestPass = nil, -- the finishing pass of that request (Apply log: the pass the ready map was finished with); kept
	                   -- like requestTrees
	measure = nil,     -- numbers of a finished engine preview (Report tab): { text, for }
	job = nil,        -- running pipeline.job
	jobT0 = 0,
	result = nil,     -- finished pipeline result (heights, report, ...)
	resultSeed = nil,
	heightsMap = nil, -- a GameMap copy carrying the generated heights (preview input / bare Apply)
	request = nil,    -- MapPreviewComp inputs; replaced only by Preview
	ready = nil,      -- finished preview map
	undoMap = nil,    -- the world terrain before the last Apply
	genId = nil,      -- id of the running / last Generate (printed in its log lines and in export names)
	resultId = nil,   -- id of the finished result
	resultRange = nil, -- { lo, hi } heights of the result in metres (after clamping)
	applied = nil,    -- what the world holds after our last Apply: { id, settings, text, range }
	undoApplied = nil, -- the same for the terrain Undo puts back (nil: not one of ours)
	batch = nil,      -- running test set: { id, i, caseId, t0, exported, failed, sizeX, sizeY }
	busy = false,     -- a terrain replacement is in flight
	applyAfter = nil, -- Apply to map waits for the preview of these settings: { text (currentSettingsLine), since }
	applyCancelled = false, -- a settings change cancelled the waiting Apply: the note line says so until the next Preview
	                        -- or Apply click (the status line is soon overwritten by Generate's progress, run 9 review)
}

local seeded = false
local function ensureSeed()
	if not seeded then
		seeded = true
		pcall(function() math.randomseed(os.time()) end)
	end
	if S.settings.seed == nil or S.settings.seed == "" then S.settings.seed = newSeed() end
	return S.settings.seed
end

local function coreSettings()
	local st = S.settings
	return {
		mapType = MAP_TYPES[st.mapType].id,
		relief = st.relief,
		water = st.water,
		ships = st.ships > 1 and (st.ships - 2) or nil,
		side = sideIndex(st) - 1, -- 0 = from the seed
		sea = seaSetting(MAP_TYPES[st.mapType].id, st.sea), -- false = no sea (Great River Valley's Sea None), nil = sea
		seed = ensureSeed(),
		tune = (function()
			local t = {}
			for k, v in pairs(st.tune) do t[k] = v / 100 end
			return t
		end)(),
	}
end

-- shown = true: the Report's "For:" line, which names the step by the box's label, "terrain Hilly" (REVIEW B12); the
-- log lines keep "relief Hilly" (export_check parses them, and older logs read the same)
local function settingsText(cs, shown)
	-- the feature side appears only when chosen, so logs of maps made without it read as before (export_check parses it);
	-- shapes.sideName: north .. west, none, or a type's own names (Sea Strait: ew, ns, swne, nwse)
	local side = (cs.side and cs.side > 0) and (", side " .. (shapes.sideName(cs.mapType, cs.side) or "none")) or ""
	-- Sea None on Great River Valley, only then (logs of every other map read as before; export_check parses it). The
	-- text must change with the box: the stale-preview note compares these texts
	if cs.sea == false then side = side .. ", sea none" end
	-- like the rest of this line (map type id, "water", "ship rivers"), the word is not a translated window text
	local stepWord = "relief"
	if shown then stepWord = "terrain" end
	local txt = string.format("%s, %s %s, water %s, ship rivers %s%s, seed %s", cs.mapType, stepWord, RELIEF[cs.relief],
		WATER[cs.water], cs.ships == nil and "default" or tostring(cs.ships), side, tostring(cs.seed))
	-- Advanced settings that differ from the design (percent)
	local parts = {}
	for _, e in ipairs(pipeline.TUNE) do
		local v = cs.tune and cs.tune[e.key]
		if v ~= nil and math.abs(v - 1) > 1e-6 then parts[#parts + 1] = string.format("%s %d %%", e.key, math.floor(v * 100 + 0.5)) end
	end
	if #parts > 0 then txt = txt .. ", advanced: " .. table.concat(parts, ", ") end
	return txt
end

-- ------------------------------------------------------------------------------------------------
-- Generate, Preview, Apply, Undo
-- ------------------------------------------------------------------------------------------------
local function finishGenerate(result, seconds)
	S.result, S.job = result, nil
	S.resultSeed = result.settings.seed
	S.request, S.ready, S.heightsMap, S.resultRange = nil, nil, nil, nil
	local parts = {}
	for _, t in ipairs(result.timings) do parts[#parts + 1] = string.format("%s %.2f s", t[1], t[2]) end
	S.resultId = S.genId
	out(string.format("Generate %s done in %.1f s (%s)", tostring(S.genId), seconds, table.concat(parts, ", ")))
	for line in report.format(result.report):gmatch("[^\n]+") do out("report: " .. line) end
end

local function startGenerate(setStatus)
	-- buttons cannot be disabled (ButtonParam has only content and onClick), so every refusal says why
	if S.batch ~= nil then setStatus("The test set is running (Stop test set first).") return end
	if S.job ~= nil then setStatus("Already generating: wait for it to finish.") return end
	if S.busy then setStatus("Still applying...") return end
	local minX, minY, maxX, maxY = mapBounds()
	local cs = coreSettings()
	S.genId = newId()
	out("Generate " .. S.genId .. ": " .. settingsText(cs) .. string.format(", map %.0f x %.0f m", maxX - minX, maxY - minY))
	-- a finishing pass still due for the result being replaced is dropped (the Preview behind this Generate starts the
	-- new result's own; without coroutines it would otherwise run once more on the next frame)
	S.result, S.request, S.ready, S.heightsMap, S.autoPreviewNext = nil, nil, nil, nil, false
	if type(coroutine) ~= "table" then
		-- no coroutines in this Lua: run in one go (the editor pauses for a few seconds)
		out("coroutine library missing: generating in one go")
		local t0 = clock()
		finishGenerate(pipeline.run(cs, { sizeX = maxX - minX, sizeY = maxY - minY }), clock() - t0)
		setStatus("Generated. Press Preview.")
		return
	end
	S.job = pipeline.job(cs, { sizeX = maxX - minX, sizeY = maxY - minY })
	S.jobT0 = clock()
	setStatus("Generating...")
end

-- Called every frame: advances the running job by one time slice. Returns a status text when it changes.
local function stepGenerate()
	local job = S.job
	if job == nil then return nil end
	local done = job:step(FRAME_BUDGET)
	if not done then
		return string.format(T("Generating... %s (%.0f s)"), job.stage and (T("after") .. " " .. job.stage) or T("starting"),
			clock() - S.jobT0)
	end
	if job.error then
		S.job = nil
		out("Generate FAILED: " .. tostring(job.error))
		return T("Generate failed:") .. " " .. tostring(job.error)
	end
	finishGenerate(job.result, clock() - S.jobT0)
	return "Generated."
end

-- A copy of the world map carrying the generated heights (the engine's grid must match the core's). Without the world's
-- towns and industries, as the base Import biomes tab builds its input (gui/map_editor/map_editor.tl 1224): the import
-- pass hands input towns on to its result, and a terrain map that lists towns crashes the game on Apply
-- ("terrain_util::ReplaceTerrain: Assertion 'map.towns.empty()' failed", run 7). Kept towns stay in the world anyway.
local function buildHeightsMap()
	local base = api.engine.terrain.makeMapFromGame(true, false, false, false)
	base.waterLevel = 0
	local copy = api.type.Map.new(base)
	local w, h = gridOf(copy)
	local res = S.result
	if res.w ~= w or res.h ~= h then
		error(string.format("grid mismatch: map %dx%d, generated %dx%d", w, h, res.w, res.h))
	end
	-- clamp in place: on a 28.7 km map the table has 51 M entries (about 800 MB in Lua), so no second copy
	local values = res.heights
	local lo, hi = math.huge, -math.huge
	for k = 1, w * h do
		local v = values[k]
		if v < HEIGHT_MIN then v = HEIGHT_MIN; values[k] = v elseif v > HEIGHT_MAX then v = HEIGHT_MAX; values[k] = v end
		if v < lo then lo = v end
		if v > hi then hi = v end
	end
	S.resultRange = { lo, hi } -- an export of this map spans exactly this range (PNG 0 .. 65535)
	copy.heightmap = values -- whole-table assignment (element writes are lost, probe run 1)
	-- the engine map now holds the heights; free the Lua table (the report stays)
	res.heights = nil
	pcall(collectgarbage, "collect")
	return copy
end

-- The game generator chosen in the window (nil while the window runs this mod's own generator). The list is read once
-- per session (generators do not change while the editor runs).
local function engineGen()
	if S.source == "utg" then return nil end
	S.engine.list = S.engine.list or eg.list()
	for _, g in ipairs(S.engine.list) do
		if g.name == S.source then return g end
	end
	return nil
end

local function engineParams(g)
	local p = S.engine.params[g.name]
	if p == nil then
		p = eg.defaults(g)
		S.engine.params[g.name] = p
	end
	return p
end

-- the settings of a game-generator preview as one line (log, Report, stale-preview note)
local function engineSettingsText(g)
	local parts = {}
	for k, v in pairs(engineParams(g)) do parts[#parts + 1] = k .. " " .. tostring(v) end
	table.sort(parts)
	return string.format("generator %s%s, seed %s", g.name, #parts > 0 and (", " .. table.concat(parts, ", ")) or "",
		tostring(ensureSeed()))
end

-- ------------------------------------------------------------------------------------------------
-- The finishing pass runs through the map editor's "Import biomes" mode (2026-10-08). Since that day's game update an
-- import-style pass run as HeighmapGenerationMode + keepHeightmap gets no usable heights (run 10: every data map 0
-- after Apply, so no trees and default textures; the game's original release shows the same to players). The Import
-- biomes mode still hands an import tree the input map's heights (run 11; run 12: our pass placed trees, the data maps
-- follow the terrain). The mode is ImportBiomesMode { terrainGenerator (an import generator), biomeMap, layerMaps }
-- with files from the userdata "biomes" folder (app.getAllBiomes; base gui/map_editor/map_editor.tl 1153-1330).
-- Our pass computes biomes, rivers and mountains from the heights and writes the biome raster itself (output_biomes),
-- so the mode's biome file only has to exist. The mode colours the preview by that raster: without output_biomes it was
-- the placeholder's (all biome 0, a blue preview, run 12); with it the preview shows our biomes (run 13).
-- app.writeHeightmap refuses paths ("../biomes/x": "Forbidden file name", run 10), but with biomesData = true it writes
-- <name>_biomes / _mountains / _rivers into the biomes folder by itself. The placeholder is written once (from any
-- map: its content is not used) and kept for later sessions.
-- ------------------------------------------------------------------------------------------------
local PLACEHOLDER = "utg_placeholder"

local function listed(fn, part)
	local ok, all = pcall(fn)
	if not ok or all == nil then return nil end
	for _, v in ipairs(all) do
		if tostring(v):find(part, 1, true) then return tostring(v) end
	end
	return nil
end

-- the biome file <name>_biomes from the biomes folder; written from map first if it is not there (or fresh = true)
local function biomeFile(name, map, fresh)
	local f = (not fresh) and listed(app.getAllBiomes, name .. "_biomes") or nil
	if f ~= nil then return f end
	local okW, written = pcall(app.writeHeightmap, map, name, false, true, true)
	out(string.format("Biome file %s_biomes written (%s)", name, okW and tostring(written) or ("FAILED: " .. tostring(written))))
	return listed(app.getAllBiomes, name .. "_biomes")
end

-- the tree density as log text after sep ("; trees lower"), or "" for nil: the pass in use declares no tree density
-- parameter, so no choice reached it
local function treesText(i, sep)
	if i == nil then return "" end
	return sep .. tostring(TREES_LOG[i] or ("trees " .. tostring(i)))
end

-- withTrees: the pass declares the tree density parameter (finishingGenerator's second value)
local function finishRequest(gen, biomes, withTrees)
	local mode = api.type.ImportBiomesMode.new()
	mode.terrainGenerator = gen
	mode.biomeMap = biomes
	mode.layerMaps = {}
	-- params: the pass's declared parameters as 1-based choice indices, as the base editor passes a generator's
	-- parameters to its preview (gui/map_editor/map_editor.tl addMissingGeneratorParams; its Import biomes tab too,
	-- 1194-1202 and 2675-2678). The engine hands the pass the choice normalised, not as a raw index (seen in game with
	-- the three Forests choices, run 9); by the design rule (index - 1) / (count - 1) that is 0 for Normal and 1 for
	-- Lower (inferred), and the pass gives Normal the factor 1 under index / count too. Nothing is sent to a pass that
	-- does not declare it.
	local trees = nil
	if withTrees then trees = S.settings.trees end
	-- a fresh copy per request: the native preview only runs again when its inputs change
	return { mode = mode, inputMap = api.type.Map.new(S.heightsMap), params = { [TREES_KEY] = trees },
		seed = S.resultSeed, generator = gen, trees = trees }
end

local function startPreview(setStatus)
	if S.batch ~= nil then setStatus("The test set is running (Stop test set first).") return end
	if S.job ~= nil then setStatus("Still generating.") return end
	if S.source ~= "utg" then
		-- a game generator: the preview IS the generation (base map editor: keepHeightmap off, its own params)
		local g = engineGen()
		if g == nil then setStatus("This generator is not available for this climate: choose another.") return end
		S.ready, S.measure, S.measureJob = nil, nil, nil -- an older measuring must not overwrite the new report
		S.request = eg.makeRequest(g.name, engineParams(g), ensureSeed())
		S.requestKind, S.requestText = "engine", engineSettingsText(g)
		out("Preview: " .. S.requestText)
		setStatus("Making the preview...")
		return
	end
	if S.result == nil then setStatus("Generate first.") return end
	local gen, withTrees = finishingGenerator()
	if gen == nil then
		-- every climate of the game has a pass since revision 4: this is a pass that failed to load, or a climate another
		-- mod adds
		setStatus("This climate has no finishing pass: Apply sets the heights only.")
		return
	end
	S.heightsMap = S.heightsMap or buildHeightsMap()
	local biomes = biomeFile(PLACEHOLDER, S.heightsMap)
	if biomes == nil then
		setStatus("The game wrote no biome file for the finishing pass (see the log).")
		return
	end
	S.ready = nil
	S.request = finishRequest(gen, biomes, withTrees)
	S.requestKind, S.requestText, S.requestTrees, S.requestPass = "utg", settingsText(S.result.settings), S.request.trees,
		gen
	out(string.format("Preview: finishing pass %s (Import biomes mode)%s", tostring(gen), treesText(S.request.trees, ", ")))
	-- the preview picture shows the land only; the pass computes forests and biomes for Apply (owner: the old text
	-- "adding forests ... in the preview" promised something the preview cannot show)
	setStatus("Finishing the map for the preview...")
end

-- Preview button. For this mod's generator one click does it all (owner 2026-10-08): when there is no map for the
-- current settings yet, it generates first and the window starts the finishing pass when the map is done
-- (S.autoPreview, handled in the window's step function); otherwise it previews the map in hand. Lower tree density is
-- not a core setting (not in settingsText), so after a change of it alone only the finishing pass runs again.
local function previewClicked(setStatus)
	S.applyCancelled = false -- a new click: the note about the cancelled Apply has been read
	-- the button is greyed out while Apply waits; the handler refuses as well, as Undo's, Test set's and Run test's do
	-- (a pass started now would be the one the wait applies)
	if S.applyAfter ~= nil then setStatus("Wait for the current work to finish.") return end
	if S.source == "utg" and S.batch == nil then
		if S.job ~= nil then setStatus("Still generating.") return end
		local current = false
		if S.result ~= nil then
			local okS, now = pcall(function() return settingsText(pipeline.normalise(coreSettings())) end)
			current = okS and now == settingsText(S.result.settings)
		end
		if not current then
			S.autoPreview = true
			startGenerate(setStatus)
			if S.job == nil and S.result ~= nil then -- no coroutines: generated in one go
				S.autoPreview = false
				startPreview(function(t) setStatus(T("Generated.") .. " " .. T(t)) end)
			end
			return
		end
	end
	startPreview(setStatus)
end

-- Whether the settings changed since the map in hand was made (the stale-preview note; Apply then makes a new preview
-- first). This mod's generator: the terrain settings against the generated result, and the tree density against the
-- finishing pass in hand (it is not in settingsText: heights do not depend on it; a request or a ready map exists only
-- after a finishing-pass Preview of this result, since Generate clears both; requestTrees nil: the pass declares no tree
-- density parameter, so the box cannot matter). A game generator: its settings against the last preview request's.
-- Nothing in hand (or a Generate running) is not "changed": Apply then sees that no map is ready.
local function settingsChanged()
	if S.source == "utg" then
		if S.result == nil or S.job ~= nil then return false end
		local okS, now = pcall(function() return settingsText(pipeline.normalise(coreSettings())) end)
		if okS and now ~= settingsText(S.result.settings) then return true end
		return S.requestKind == "utg" and (S.request ~= nil or S.ready ~= nil) and S.requestTrees ~= nil
			and S.requestTrees ~= S.settings.trees
	end
	if S.requestKind ~= "engine" then return false end
	local g = engineGen()
	if g == nil then return false end
	local okS, now = pcall(engineSettingsText, g)
	return okS and now ~= S.requestText
end

-- The window's current settings as one line, what a Preview now would be made with (a waiting Apply compares it every
-- frame: any change after the click cancels the Apply, even during a Generate, when settingsChanged cannot tell yet). The
-- tree density only where this climate's pass declares it (revision 4: the Subarctic, Tropical and Dry passes do not,
-- and the waiting Apply's log line must not name a density the pass never gets; nor can it change there: no box).
local function currentSettingsLine()
	if S.source ~= "utg" then
		local g = engineGen()
		return g and engineSettingsText(g) or ("generator " .. tostring(S.source))
	end
	local _, withTrees = finishingGenerator()
	return settingsText(pipeline.normalise(coreSettings())) .. treesText(withTrees and S.settings.trees or nil, "; ")
end

-- Whether Apply can put in, right now, a map made with the current settings (no side effects; called on every render
-- for the button's look). Before 2026-10-13 a ready preview was applied whatever the settings had become since, so a
-- change followed by Apply changed nothing (owner, run 9).
local function applyReadyNow()
	if settingsChanged() then return false end
	if S.source ~= "utg" then return S.requestKind == "engine" and S.ready ~= nil end
	if S.result == nil or S.job ~= nil then return false end
	if S.ready ~= nil and S.requestKind == "utg" then return true end
	local ok, gen = pcall(finishingGenerator)
	return ok and gen == nil -- no finishing pass for this climate: the bare heights can be applied
end

-- Whether a preview for the current settings is being made, so a waiting Apply only has to wait for it: this mod's
-- Generate (started by Preview; a change during it is caught by currentSettingsLine), the finishing pass about to start
-- (the frame after Generate) or running, or a game generator's preview running. The pass about to start is for the
-- result just generated, so it counts only when the settings still match it (run 9 review: Apply clicked in that one
-- frame after a change during Generate would otherwise wait for the older map and cancel itself).
local function previewRunning()
	local kind = "engine" -- what the request must have come from (S.requestKind)
	if S.source == "utg" then
		if S.batch ~= nil then return false end
		if S.job ~= nil then return true end
		if S.autoPreviewNext then return not settingsChanged() end
		kind = "utg"
	end
	return S.request ~= nil and S.ready == nil and S.requestKind == kind and not settingsChanged()
end

-- What Apply would put into the world now, or nil and the reason. pass: the finishing pass for the log (climateText).
local function applyTarget()
	if S.source ~= "utg" then
		if S.requestKind ~= "engine" or S.ready == nil then return nil, "Press Preview and wait for the finished preview first." end
		return { map = S.ready, what = "game generator " .. tostring(S.request and S.request.generator or S.requestText),
			seed = S.request and S.request.seed or ensureSeed(),
			pending = { id = newId(), engine = S.request and S.request.generator or "generator", text = S.requestText } }
	end
	if S.result == nil then return nil, "Generate first." end
	-- the record of what Apply puts in the world; built after the heights map, which sets the height range
	local function pending()
		return { id = S.resultId, settings = S.result.settings, text = settingsText(S.result.settings), range = S.resultRange }
	end
	if S.ready ~= nil and S.requestKind == "utg" then
		-- the tree density the ready map was finished with, not the box's current one (run material ties screenshots
		-- to it)
		return { map = S.ready, what = "finished map" .. treesText(S.requestTrees, ", "), seed = S.resultSeed,
			pass = S.requestPass, pending = pending() }
	end
	if finishingGenerator() == nil then
		S.heightsMap = S.heightsMap or buildHeightsMap()
		return { map = S.heightsMap, what = "heights only (no finishing pass for this climate)", seed = S.resultSeed,
			pass = "none", pending = pending() }
	end
	return nil, "Press Preview and wait for the finished preview first."
end

-- A terrain replacement (Apply, Undo) is in flight. The watchdog in the window's step function frees the buttons if no
-- callback has come after BUSY_TIMEOUT seconds (a command that never answers must not lock the window for good).
local BUSY_TIMEOUT = 90
local wallClock = (os ~= nil and os.time) or function() return 0 end
local function setBusy(on)
	S.busy = on
	S.busySince = on and wallClock() or nil
end

-- Apply to map when the map in hand is not the one for the current settings, or there is none yet (owner 2026-10-13,
-- run 9: "Should 'Apply to map' button also run the preview button task silently?" - yes): it runs what Preview runs
-- (Generate if the terrain settings changed, else only the finishing pass; a game generator's preview), unless a
-- preview of these settings is already being made, and S.applyAfter makes the window's step function apply that map
-- as soon as it is ready (stepApplyAfter). An older map is never applied: a settings change while it waits cancels it.
-- The window counts a waiting Apply as busy (the buttons wait, as during Run test).
local function startApplyAfterPreview(setStatus)
	local said = nil
	if not previewRunning() then previewClicked(function(t) said = t end) end
	if not (previewRunning() or applyReadyNow()) then
		-- Preview refused (it says why, e.g. a generator not available); nothing waits
		out("Apply: the preview could not be started: " .. tostring(said))
		setStatus(said or "Nothing applied.")
		return
	end
	S.applyAfter = { text = currentSettingsLine(), since = wallClock() }
	out("Apply: making the preview for the current settings first: " .. S.applyAfter.text)
	setStatus("Making the preview, then applying...")
end

-- noRefresh (Run test): apply only the map in hand; when it is not the one for the current settings, refuse.
-- Returns true when the map is on its way in.
local function apply(setStatus, noRefresh)
	S.applyCancelled = false -- a new click (or the waiting Apply going ahead): the cancel note has done its job
	if S.batch ~= nil then setStatus("The test set is running (Stop test set first).") return end
	if S.job ~= nil then setStatus("Still generating.") return end
	if S.busy then setStatus("Still applying...") return end
	if S.applyAfter ~= nil then setStatus("Making the preview, then applying...") return end -- a second click
	if not applyReadyNow() then
		if noRefresh then
			out("Apply refused: the map in hand was not made with the current settings")
			setStatus("Settings changed since the last Preview: nothing applied.")
			return
		end
		startApplyAfterPreview(setStatus)
		return
	end
	local target, why = applyTarget()
	if target == nil then setStatus(why) return end
	local st = S.settings
	local map = api.type.Map.new(target.map)
	-- terrain only: Undo replaces the terrain, and a map listing towns would crash it (see buildHeightsMap)
	local undoMap = api.engine.terrain.makeMapFromGame(true, false, false, false)
	setBusy(true)
	pcall(function() api.gui.map.setMapSeedText(target.seed) end)
	out(string.format("Apply: %s (keep towns %s, keep industries %s); %s", target.what, tostring(st.keepTowns),
		tostring(st.keepIndustries), climateText(target.pass)))
	setStatus("Applying...")
	local removing = not (st.keepTowns and st.keepIndustries)
	-- base order: towns, then industries, then the terrain, each step in the previous step's callback
	local function replace(removedOk)
		if not removedOk then out("Apply: removing towns or industries reported a failure; replacing the terrain anyway") end
		local okR, err = pcall(sendReplaceTerrain, map, false, "Apply", target.seed, function(success)
			setBusy(false)
			if success then
				S.undoMap = undoMap
				S.undoApplied, S.applied = S.applied, target.pending
				logDataMaps("Apply (" .. tostring(target.what) .. ")")
			end
			if not success then
				setStatus("Apply failed (see the log).")
			elseif not removedOk then
				setStatus("Applied, but removing towns or industries failed (see the log).")
			elseif removing then
				setStatus("Applied. Undo restores the terrain, not removed towns or industries.")
			else
				setStatus("Applied. Undo restores the terrain.")
			end
		end)
		if not okR then
			setBusy(false)
			out("Apply FAILED: " .. tostring(err))
			setStatus(T("Apply failed:") .. " " .. tostring(err))
		end
	end
	local okRm, errRm = pcall(eg.removeTownsAndIndustries, st.keepTowns, st.keepIndustries,
		function(ok) replace(ok ~= false) end, out)
	if not okRm then
		-- nothing was replaced; the towns or industries removed so far stay removed
		setBusy(false)
		out("Apply FAILED while removing towns or industries: " .. tostring(errRm))
		setStatus(T("Apply failed while removing towns or industries:") .. " " .. tostring(errRm))
	end
	return true
end

-- A waiting Apply, every frame (window step function): cancelled when any setting changed since the click (the map that
-- is coming is then outdated); applied through apply() as soon as the map for the settings is ready, so its guards, the
-- Undo snapshot of the world as it is then, and Keep towns / Keep industries as ticked then all hold; cancelled when
-- nothing is making that map any more (Generate or the preview failed: oldStatus says why), or after APPLY_WAIT_TIMEOUT
-- seconds without the preview (Generate not counted: it reports its own progress), so the buttons never stay locked.
local APPLY_WAIT_TIMEOUT = 180
local function stepApplyAfter(setStatus, oldStatus)
	local pa = S.applyAfter
	local generating = S.job ~= nil or S.autoPreviewNext == true
	if generating then pa.since = wallClock() end
	local okL, line = pcall(currentSettingsLine)
	if not okL or line ~= pa.text or settingsChanged() then
		S.applyAfter = nil
		S.applyCancelled = true -- the note line keeps saying so (Generate's progress and the preview overwrite the status)
		out("Apply cancelled: the settings changed while the preview was being made")
		setStatus("Settings changed while the preview was being made: nothing applied. Press Apply to map again.")
		return
	end
	if generating then return end
	if applyReadyNow() then
		S.applyAfter = nil
		out("Apply: the preview for the current settings is ready")
		apply(setStatus)
		return
	end
	if not previewRunning() then
		S.applyAfter = nil
		out("Apply cancelled: the preview was not made")
		setStatus(T("Nothing applied.") .. " " .. T(oldStatus or ""))
		return
	end
	if wallClock() - pa.since > APPLY_WAIT_TIMEOUT then
		S.applyAfter = nil
		out(string.format("Apply cancelled: no preview after %d s", APPLY_WAIT_TIMEOUT))
		setStatus("The preview did not finish (see the log): nothing applied. The buttons work again.")
	end
end

local function undo(setStatus)
	if S.batch ~= nil then setStatus("The test set is running (Stop test set first).") return end
	if S.applyAfter ~= nil then setStatus("Wait for the current work to finish.") return end -- an Apply is on its way
	if S.undoMap == nil then setStatus("Nothing to undo.") return end
	if S.busy then setStatus("Still applying...") return end
	local map = S.undoMap
	setBusy(true)
	out("Undo: restoring the terrain from before the last Apply")
	setStatus("Restoring...")
	local okU, errU = pcall(sendReplaceTerrain, map, false, "Undo", "", function(success)
		setBusy(false)
		if success then
			S.undoMap = nil -- only after it worked, so a failed Undo can be tried again
			S.applied, S.undoApplied = S.undoApplied, nil
		end
		setStatus(success and "Previous terrain restored (not its trees, nor removed towns or industries)."
			or "Undo failed (see the log).")
	end)
	if not okU then
		setBusy(false)
		out("Undo FAILED: " .. tostring(errU))
		setStatus(T("Undo failed:") .. " " .. tostring(errU))
	end
end

-- Debug: export the world's heightmap (what Apply put there) as a 16-bit PNG, named and logged so the file can
-- be matched to its "[UTG] Generate <id>" lines. The editor's exporter writes into its usual heightmap folder.
local function exportMap(setStatus)
	if S.batch ~= nil then setStatus("The test set is running (Stop test set first).") return end
	if S.busy then setStatus("Still applying...") return end
	local a = S.applied
	local name
	if a ~= nil and a.engine then
		-- a game generator's map: named after the generator (its settings are in the log line)
		name = string.format("utg_%s_engine_%s", a.id, (tostring(a.engine):gsub("[^%w]", "_")):sub(1, 40))
	elseif a ~= nil then
		local seed = (tostring(a.settings.seed):gsub("[^%w]", ""))
		name = string.format("utg_%s_%s_%s_%s", a.id, a.settings.mapType, RELIEF[a.settings.relief]:lower(), seed)
	else
		name = "utg_" .. newId() .. "_world"
	end
	local map = api.engine.terrain.makeMapFromGame(true, false, false, false)
	local ok = app.writeHeightmap(map, name, false, true, false)
	if a ~= nil then
		local range = a.range and string.format("heights %.2f .. %.2f m = PNG 0 .. 65535", a.range[1], a.range[2])
			or "height range not recorded"
		out(string.format("Export %s.png (Generate %s): %s; %s; written=%s", name, tostring(a.id), a.text, range, tostring(ok)))
	else
		out(string.format("Export %s.png: the world terrain, not a UTG Apply (none yet, or undone); written=%s", name,
			tostring(ok)))
	end
	if ok == false then
		setStatus("Export failed (see the log).")
	else
		setStatus(T("Exported") .. " " .. name .. ".png " .. T("(see the [UTG] Export line in stdout.txt)."))
	end
end

-- Debug: write this session's [UTG] lines into the heightmap folder, next to the exports (app.saveUserdata, as the
-- base map editor saves its town and industry lists: userdata/<folder>/<name>.lua). The file is a Lua table
-- { lines = { "[time] [UTG] ...", ... } }; an offline tool reads it like stdout.txt.
local LOG_FOLDER = "heightmaps"
local function saveLog(setStatus, name)
	name = name or ("utg_log_" .. newId())
	out(string.format("Log saved as %s/%s.lua (%d lines before this one)", LOG_FOLDER, name, #LOG_LINES))
	local ok, err = pcall(function() app.saveUserdata(LOG_FOLDER, name, { lines = LOG_LINES }) end)
	if not ok then
		out("Save log FAILED: " .. tostring(err))
		if setStatus then setStatus(T("Save log failed:") .. " " .. tostring(err)) end
		return
	end
	if setStatus then setStatus(T("Log saved to the heightmaps folder:") .. " " .. name .. ".lua") end
end

-- ------------------------------------------------------------------------------------------------
-- Debug: Run test (owner 2026-10-08: "1 button in the window runs the tests, start to finish, and exports relevant
-- logs/heightmaps"). On the current settings, one after another: 1 Preview (generating first if needed); the finished
-- map is written with its biome data as utg_test_<id> (heightmap in "heightmaps", masks in "biomes"; tools/collect_run.py
-- copies them and says whether the biome raster follows the terrain or is a uniform placeholder's); 2 Apply (Keep towns
-- / Keep industries as ticked; the data maps are logged); 3 Export of the world; 4 the log saved as
-- utg_log_test_<id>.lua. Stages advance from the preview's onReady and the window's step function; a stage without an
-- answer for AUTO_TEST_TIMEOUT seconds ends the test (log saved). Run 13 (in game 2026-10-08): done in 22 s on 14 km.
-- ------------------------------------------------------------------------------------------------
local AUTO_TEST_TIMEOUT = 180

local function autoTestStage(stage)
	S.autoTest.stage = stage
	S.autoTest.since = wallClock()
	out(string.format("Run test %s: %s", S.autoTest.id, stage))
end

local function autoTestEnd(result)
	local at = S.autoTest
	S.autoTest, S.autoTestNext = nil, false
	out(string.format("Run test %s %s", at.id, result))
	saveLog(nil, "utg_log_test_" .. at.id)
end

local function startAutoTest(setStatus)
	if S.source ~= "utg" then setStatus("Run test works with this mod's generator.") return end
	if S.job ~= nil or S.batch ~= nil or S.busy or S.autoTest ~= nil or S.applyAfter ~= nil then
		setStatus("Wait for the current work to finish.")
		return
	end
	local gen, withTrees = finishingGenerator()
	if gen == nil then setStatus("Run test needs this climate's finishing pass.") return end
	S.autoTest = { id = newId() }
	out(string.format("Run test %s: %s%s; keep towns %s, keep industries %s; %s", S.autoTest.id,
		settingsText(pipeline.normalise(coreSettings())), treesText(withTrees and S.settings.trees or nil, "; "),
		tostring(S.settings.keepTowns), tostring(S.settings.keepIndustries), climateText(gen)))
	autoTestStage("preview")
	previewClicked(setStatus)
end

-- the finished preview during the test; returns the status text
local function autoTestReady(map)
	biomeFile("utg_test_" .. S.autoTest.id, map, true)
	S.autoTestNext = true -- Apply starts on the next frame
	autoTestStage("apply")
	return "Run test: applying the map..."
end

-- Debug: the standard test set. A fixed list of cases with a fixed seed, generated one after another on the current
-- map size and each exported straight from its generated heights (no Preview, no Apply: the world is not touched).
-- Exports and log lines carry the set version, the batch id and the case number, so runs from different builds can
-- be compared case by case (an offline tool reads the exports and log lines). Change the list
-- only together with the version.
-- T2 (run 6): the five Relief levels (Flat dropped), Several ship rivers once. T1 (run 6) used relief 1-4 =
-- Flat, Gentle, Hilly, Mountainous; its cases 1-10 match T2's 1-10 in settings.
local TEST_SET = {
	version = "T2",
	seed = "oeyrx62dl8", -- the run 5 seed: comparable with that run's vanilla Temperate export
	cases = { -- { map type, relief 1-5, water 1-3 [, ship rivers 0-2] }; Advanced settings stay at 100 %
		{ "great_river_valley", 1, 2 }, { "delta_lowlands", 1, 2 }, { "mountain_passes", 1, 2 },
		{ "rolling_plains", 1, 2 }, { "lake_district", 1, 2 }, { "large_bays", 1, 2 }, { "peninsulas", 1, 2 },
		{ "island_chain", 1, 2 }, { "coastal_region", 1, 2 }, { "highland_plateau", 1, 2 },
		{ "great_river_valley", 2, 2 }, { "great_river_valley", 3, 2 }, { "great_river_valley", 4, 2 },
		{ "great_river_valley", 5, 2 }, { "mountain_passes", 3, 2 }, { "mountain_passes", 5, 2 },
		{ "great_river_valley", 1, 1 }, { "great_river_valley", 1, 3 }, { "great_river_valley", 3, 2, 2 },
	},
}

local function testCaseText(b)
	return string.format("test set %s %s case %d/%d", TEST_SET.version, b.id, b.i, #TEST_SET.cases)
end

-- Starts the next case, or ends the set. Returns the status text.
local function nextTestCase(b)
	b.i = b.i + 1
	if b.i > #TEST_SET.cases then
		S.batch = nil
		out(string.format("Test set %s %s done in %.0f s: %d exported, %d failed", TEST_SET.version, b.id,
			clock() - b.t0, b.exported, b.failed))
		saveLog(nil, "utg_log_" .. b.id) -- the set's log lines go next to its exports
		return string.format("%s %s: %d %s (see the [UTG] lines in stdout.txt).", T("Test set done"), b.id, b.exported,
			T("heightmaps exported"))
	end
	local c = TEST_SET.cases[b.i]
	local cs = { mapType = c[1], relief = c[2], water = c[3], ships = c[4], seed = TEST_SET.seed }
	S.genId = string.format("%s_%02d", b.id, b.i)
	b.caseId = S.genId
	out("Generate " .. S.genId .. ": " .. settingsText(pipeline.normalise(cs)) .. string.format(", map %.0f x %.0f m (%s)",
		b.sizeX, b.sizeY, testCaseText(b)))
	S.result, S.request, S.ready, S.heightsMap = nil, nil, nil, nil
	S.job = pipeline.job(cs, { sizeX = b.sizeX, sizeY = b.sizeY })
	S.jobT0 = clock()
	return string.format("%s %d/%d: %s", T("Test set"), b.i, #TEST_SET.cases, c[1])
end

-- Called every frame while a test set runs.
local function stepTestSet()
	local b = S.batch
	if S.job ~= nil then
		local msg = stepGenerate()
		if S.job ~= nil then
			return string.format("%s %d/%d: %s", T("Test set"), b.i, #TEST_SET.cases, msg or "")
		end
		if S.result ~= nil and S.resultId == b.caseId then
			-- export this case from its generated heights (the engine map built for Preview; the world is untouched)
			local st = S.result.settings
			local map = buildHeightsMap()
			S.heightsMap = map -- the last case stays ready for Preview / Apply
			local name = string.format("utg_%s_%s_%s_%s_%s", b.caseId, st.mapType, RELIEF[st.relief]:lower(),
				WATER[st.water]:lower(), (tostring(st.seed):gsub("[^%w]", "")))
			local ok = app.writeHeightmap(map, name, false, true, false)
			local r = S.resultRange
			out(string.format("Export %s.png (Generate %s, %s): %s; heights %.2f .. %.2f m = PNG 0 .. 65535; written=%s",
				name, b.caseId, testCaseText(b), settingsText(st), r[1], r[2], tostring(ok)))
			if ok == false then b.failed = b.failed + 1 else b.exported = b.exported + 1 end
		else
			b.failed = b.failed + 1
			out("Test set case " .. tostring(b.caseId) .. " FAILED (see the Generate line above)")
		end
		pcall(collectgarbage, "collect")
	end
	return nextTestCase(b)
end

local function toggleTestSet(setStatus)
	if S.batch ~= nil then
		out(string.format("Test set %s %s stopped at case %d", TEST_SET.version, S.batch.id, S.batch.i))
		S.batch, S.job = nil, nil
		setStatus("Test set stopped.")
		return
	end
	if S.job ~= nil then setStatus("Still generating.") return end
	-- the set replaces the result and the preview an Apply waits for
	if S.applyAfter ~= nil then setStatus("Wait for the current work to finish.") return end
	if type(coroutine) ~= "table" then setStatus("The test set needs coroutines, which this game's Lua lacks.") return end
	local minX, minY, maxX, maxY = mapBounds()
	local b = { id = newId(), i = 0, t0 = clock(), exported = 0, failed = 0, sizeX = maxX - minX, sizeY = maxY - minY }
	S.batch = b
	out(string.format("Test set %s %s: %d cases, seed %s, map %.0f x %.0f m; exports go to the editor's heightmap folder",
		TEST_SET.version, b.id, #TEST_SET.cases, TEST_SET.seed, b.sizeX, b.sizeY))
	setStatus(nextTestCase(b))
end

-- ------------------------------------------------------------------------------------------------
-- Window
-- ------------------------------------------------------------------------------------------------
--[[ Layout (2026-10-08 review; follows the base map editor's generator window, gui/map_editor/map_editor.tl
  TabAndPreview + map_editor.css.lua):
    left   a settings column of FIXED pixel width (wide enough for two label + field pairs side by side), per
           text-size setting (!font-small/medium/large); its tab pages scroll on their own, with the tab headers
           staying put; under the tabs: a note when the settings changed since Generate, the status (two lines
           reserved, so the buttons do not jump), the action buttons and the debug tools
    right  the preview pane FILLS the rest of the window (the native preview keeps its aspect inside it), with
           "Larger window" at its top
  No API tells a mod the screen size or the UI scale (base GUI: px and vw/vh only), so the window takes screen shares
  and the column takes pixels, as the base windows do. Classes and sizes: utg_studio.css.lua. ]]
-- class: "utg-combo" (default) or "utg-combo-wide" (long entries, e.g. generator names)
-- labels: window texts (translated here), or { text = "..." } for a text already made from translated parts
-- key: a node key (meta.localKey, react.lua) for boxes whose choices depend on the map type. A new key makes the engine
-- build a new box showing `value`, as the base game keys its parameter widgets by what they stand for
-- (construction.tl: uiType + name), so a box can never keep a choice from the previous map type on screen.
local function combo(labels, value, onChange, class, key)
	local items = {}
	for i, l in ipairs(labels) do
		local content = type(l) == "table" and builtin.TextView{ text = l.text } or text(l) -- text() translates
		items[#items + 1] = builtin.ComboBoxItem{ value = i, content = content }
	end
	return builtin.ComboBox{ meta = { class = class or "utg-combo", localKey = key }, value = value, items = items,
		onValueChange = onChange }
end

local function styled(class, orientation, children)
	return builtin.BoxLayout{ meta = { class = class }, orientation = orientation, children = children }
end

-- text classes: our size/wrap class plus the base text-size class (follows the game's text-size setting); tip: tooltip
-- (translated text)
local function label(s, class, tip)
	return builtin.TextView{ meta = { class = (class or "utg-label") .. ", font-scale-body", tooltip = tip }, text = T(s) }
end

local function help(s, class)
	return builtin.TextView{ meta = { class = (class or "utg-help") .. ", font-scale-body" },
		text = (s ~= nil and s ~= "") and T(s) or "" }
end

-- one labelled field: "Label   [widget]"
-- labelClass: "utg-label" (default) or "utg-label-wide" for long labels ("Rivers flow towards")
local function field(name, widget, tooltip, labelClass)
	local l = builtin.TextView{ meta = { class = (labelClass or "utg-label") .. ", font-scale-body", tooltip = tooltip },
		text = T(name) }
	return styled("utg-field", builtin.type.Orientation.Horizontal, { l, widget })
end

-- fields side by side (e.g. Water and Ship rivers)
local function fieldRow(fields)
	return styled("utg-row", builtin.type.Orientation.Horizontal, fields)
end

local function page(children)
	return styled("utg-page", builtin.type.Orientation.Vertical, children)
end

-- A tab's item must not be a layout ("TabWidgetChild item must not be a Layout", in game 2026-10-06, run 5); the
-- base game passes recipe components. Each page is a small recipe returning its own scroll area (base map editor:
-- settings-scroll-area > Component > settings-layout), so the tab headers never scroll away and each tab keeps its
-- own scroll position.
local TabPage = react.RegisterRecipe("UtgTabPage", function(params)
	return builtin.BoxLayout{
		meta = { class = "utg-tab-page" },
		orientation = builtin.type.Orientation.Vertical,
		children = {
			builtin.ScrollArea{
				meta = { class = "utg-scroll" },
				horizontalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
				verticalPolicy = builtin.type.ScrollBarPolicy.AsNeeded,
				content = builtin.Component{ layout = params.build() },
			},
		},
	}
end)

local function tab(key, label_, build)
	return builtin.TabWidgetChild{ localKey = key, value = key,
		indicator = builtin.TextView{ meta = { class = "font-scale-tab-widget-indicator" }, text = T(label_) },
		item = TabPage{ build = build } }
end

-- the map size of the editor map (km), or nil
local function mapSizeKm()
	local ok, a, b, c, d = pcall(mapBounds)
	if not ok then return nil end
	return (c - a) / 1000, (d - b) / 1000
end

local SMALL_MAP_KM = 6 -- offline settings test (2026-10-08): below about 6 km most map types have no or few rivers

-- A game generator's parameter as a widget. First choice: the base game's own builder (gui/main/script_param_util.tl
-- buildScriptParamComp, as the map editor's generator window uses: label + combo / slider / buttons by uiType, values
-- as the base passes them). If that module cannot be loaded from a mod script, a combo box over the parameter's
-- values (value = its number if it lists numbers, else the index: engine_generators.valueOf).
local spu = nil -- nil = not tried yet, false = not available
local function paramWidget(p, value, onChange)
	if spu == nil then
		local ok, m = pcall(require, "::/gui/main/script_param_util.tl")
		spu = (ok and type(m) == "table" and m.buildScriptParamComp) and m or false
		if not spu then out("base parameter widgets not available: using combo boxes") end
	end
	if spu then
		local ok, w = pcall(spu.buildScriptParamComp, p, value, onChange)
		if ok and w ~= nil then return w end
	end
	local labels = {}
	for i = 1, #p.values do labels[i] = tostring(p.values[i]) end
	return field(tostring(p.name or p.key), builtin.ComboBox{ meta = { class = "utg-combo" }, value = eg.indexOf(p, value),
		items = (function()
			local items = {}
			for i, l in ipairs(labels) do items[i] = builtin.ComboBoxItem{ value = i, content = builtin.TextView{ text = l } } end
			return items
		end)(),
		onValueChange = function(i) onChange(eg.valueOf(p, i)) end })
end

-- the measuring of a finished game-generator preview runs over frames (it reads every height once)
local function startMeasure(map, text)
	if type(coroutine) ~= "table" then
		local okM, r = pcall(eg.measure, map)
		S.measure = okM and { text = text, lines = eg.formatMeasure(r) } or nil
		return
	end
	local deadline = 0
	local co = coroutine.create(function()
		return eg.measure(map, function() if clock() > deadline then coroutine.yield() end end)
	end)
	S.measureJob = { co = co, text = text, step = function(budget)
		deadline = clock() + budget
		return coroutine.resume(co)
	end }
end

local StudioPanel = react.RegisterRecipe("UtgStudioPanel", function(params)
	-- hooks first
	local tabState = react.useState("settings")
	local statusState = react.useState("Choose the settings and press Preview.")
	local revision = react.useState(0) -- bumped to re-render after settings change
	local function setStatus(s) statusState:set(s) end
	local function changed() revision:set(revision:old() + 1) end

	react.onStep(function()
		if S.job ~= nil or S.batch ~= nil then
			local okStep, msg = pcall(S.batch ~= nil and stepTestSet or stepGenerate)
			if not okStep then
				S.job, S.batch = nil, nil
				out("Generate FAILED: " .. tostring(msg))
				msg = T("Generate failed:") .. " " .. tostring(msg)
			end
			if S.autoPreview and S.job == nil and S.batch == nil then
				-- one click (owner 2026-10-08: "why Generate and then Preview?"): the Preview that started the Generate
				-- starts the finishing pass on the NEXT frame (building the preview's heights map is a long step of its
				-- own; this frame already finished the generation)
				S.autoPreview = false
				if S.result ~= nil then
					S.autoPreviewNext = true
					msg = T("Generated.") .. " " .. T("Preparing the preview...")
				end
			end
			if msg ~= nil and msg ~= statusState:old() then statusState:set(msg) end
		elseif S.autoTestNext and S.autoTest ~= nil then
			S.autoTestNext = false
			local at = S.autoTest
			local okA, errA = pcall(function()
				if at.stage == "apply" then
					-- only the map this test previewed (a setting changed during the test: stop, never a new preview)
					if apply(function() end, true) then
						at.applying = true
					else
						autoTestEnd("stopped")
						statusState:set("Run test stopped: the settings changed during the test (see the saved log).")
					end
				end
			end)
			if not okA then
				out("Run test FAILED: " .. tostring(errA))
				autoTestEnd("stopped")
				statusState:set(T("Run test failed (see the saved log).") .. " " .. tostring(errA))
			end
		elseif S.autoPreviewNext then
			S.autoPreviewNext = false
			local msg
			local okP, errP = pcall(startPreview, function(t) msg = t end)
			if not okP then
				out("Preview FAILED: " .. tostring(errP))
				msg = T("Preview failed:") .. " " .. tostring(errP)
			end
			statusState:set(T("Generated.") .. " " .. T(msg or "Preview"))
		end
		-- Apply to map waiting for its preview (owner 2026-10-13, run 9): after the steps above, so the frame that starts
		-- the finishing pass, or finds there is none (heights only), is the one that checks
		if S.applyAfter ~= nil then
			local okW, errW = pcall(stepApplyAfter, function(t) statusState:set(t) end, statusState:old())
			if not okW then
				S.applyAfter = nil
				out("Apply FAILED: " .. tostring(errW))
				statusState:set(T("Apply failed:") .. " " .. tostring(errW))
			end
		end
		if S.autoTest ~= nil and S.autoTest.applying and not S.busy then
			-- Apply answered (or refused): export the world and end
			local okE, errE = pcall(exportMap, function() end)
			if not okE then out("Run test: Export FAILED: " .. tostring(errE)) end
			local id = S.autoTest.id
			autoTestEnd("done")
			statusState:set(T("Run test done. Files:") .. " utg_test_" .. id .. "_*, utg_log_test_" .. id .. ".lua")
		elseif S.autoTest ~= nil and S.autoTest.since ~= nil and wallClock() - S.autoTest.since > AUTO_TEST_TIMEOUT then
			out(string.format("Run test: no answer after %d s in stage %s", AUTO_TEST_TIMEOUT, tostring(S.autoTest.stage)))
			autoTestEnd("stopped")
			statusState:set("Run test stopped: no answer from the game (see the saved log).")
		end
		if S.busy and S.busySince ~= nil and wallClock() - S.busySince > BUSY_TIMEOUT then
			setBusy(false)
			out(string.format("Apply/Undo: no answer from the game after %d s; buttons released", BUSY_TIMEOUT))
			statusState:set("Apply or Undo got no answer from the game (see the log). The buttons work again.")
		end
		if S.measureJob ~= nil then
			local mj = S.measureJob
			local ok, r = mj.step(FRAME_BUDGET)
			if not ok then
				S.measureJob = nil
				out("Measuring the preview FAILED: " .. tostring(r))
				S.measure = { text = mj.text, lines = T("Measuring the map failed (see the log).") }
				changed()
			elseif coroutine.status(mj.co) == "dead" then
				S.measureJob = nil
				S.measure = { text = mj.text, lines = eg.formatMeasure(r) }
				for line in S.measure.lines:gmatch("[^\n]+") do out("report: " .. line) end
				changed()
			end
		end
	end)

	local st = S.settings
	ensureSeed()
	local H, V = builtin.type.Orientation.Horizontal, builtin.type.Orientation.Vertical
	local isUtg = S.source == "utg"
	local g = engineGen()
	if not isUtg and g == nil then S.source, isUtg = "utg", true end -- generator gone: back to this mod's own
	local mapType = MAP_TYPES[st.mapType]
	local typeInfo = shapes.TYPES[mapType.id] or {}
	-- (an Apply waiting for its preview counts: the buttons wait, as during Run test)
	local busy = S.job ~= nil or S.batch ~= nil or S.busy or S.autoTest ~= nil or S.applyAfter ~= nil
	-- this climate has a finishing pass (Apply's next step, Run test), and it declares the tree density parameter (box)
	local okF, finishGen, finishTrees = pcall(finishingGenerator)
	local hasFinish = okF and finishGen ~= nil
	local hasTrees = hasFinish and finishTrees == true
	-- the climate's profile (Temperate's for a climate climate.lua does not know) and whether it knows the climate: the
	-- Terrain and Overall height tooltips (climateKey) and the climate note
	local okP, prof, known = pcall(climateProfile)
	if not okP then prof, known = nil, false end
	local climateKey = prof and prof.key or "temperate"

	-- Generator choice: this mod's own first, then the game's generators of this climate (vanilla and mods)
	local function generatorRow()
		if S.engine.list == nil then
			local okL, list = pcall(eg.list)
			if not okL then out("Reading the game's generator list FAILED: " .. tostring(list)) end
			S.engine.list = okL and list or {}
		end
		local labels, current = { T("Ultimate Terrain Generator (this mod)") }, 1
		for i, e in ipairs(S.engine.list) do
			labels[#labels + 1] = e.label
			if e.name == S.source then current = i + 1 end
		end
		return field("Generator", combo(labels, current, function(v)
			local src = v == 1 and "utg" or (S.engine.list[v - 1] and S.engine.list[v - 1].name) or "utg"
			if src ~= S.source then
				S.source = src
				S.request, S.ready, S.measure, S.measureJob, S.requestKind, S.requestText = nil, nil, nil, nil, nil, nil
				if S.job ~= nil and S.batch == nil then
					S.job = nil -- a running Generate belongs to this mod's generator
					out("Generate stopped: generator switched")
				end
				if S.applyAfter ~= nil then
					S.applyAfter = nil -- its preview was the other generator's
					out("Apply cancelled: generator switched")
				end
				out("Generator: " .. (src == "utg" and "Ultimate Terrain Generator" or src))
				setStatus(src == "utg" and "Press Preview."
					or "Press Preview.")
			end
			changed()
		end, "utg-combo-wide"), T("This mod's generator, or another one for this climate."))
	end

	local function seedRow()
		return field("Seed", styled("utg-field", H, {
			builtin.TextInputField{
				meta = { class = "utg-seed, font-scale-body" },
				value = st.seed,
				placeholderText = T("Seed"),
				onValueChange = function(v) st.seed = v; changed() end,
				acceptOnFocusLoss = true,
			},
			button("New seed", function() st.seed = newSeed(); changed() end, "secondary"),
		}), T("Same settings and same seed give the same map."))
	end

	-- like the game's own generator window: towns and industries are removed before the new terrain, unless kept
	local function keepRow()
		local row = styled("utg-row", H, {
			label("When applying", "utg-label"),
			builtin.CheckBox{ meta = { class = "utg-check", tooltip = T("Leave the towns where they are. Not ticked: Apply removes them (Undo does not bring them back).") },
				label = T("Keep towns"), value = st.keepTowns and 1 or 0,
				onValueChange = function(v) st.keepTowns = (v == 1); changed() end },
			builtin.CheckBox{ meta = { class = "utg-check", tooltip = T("Leave the industries and their roads where they are. Not ticked: Apply removes them (Undo does not bring them back).") },
				label = T("Keep industries"), value = st.keepIndustries and 1 or 0,
				onValueChange = function(v) st.keepIndustries = (v == 1); changed() end },
		})
		return row -- what an unticked box means is in the check boxes' tooltips
	end

	local function settingsTab()
		local items = { generatorRow() }
		if isUtg then
			local mapLabels = {}
			for i, m in ipairs(MAP_TYPES) do mapLabels[i] = m.label end
			items[#items + 1] = fieldRow({
				field("Map type", combo(mapLabels, st.mapType, function(v)
					-- an edge the player chose stays where it means the same edge (sideAfterTypeChange), else the new type's
					-- pre-selected side (None on Alpine); the Sea box (one type only) goes back to the sea
					if v ~= st.mapType then
						st.side = sideAfterTypeChange(MAP_TYPES[st.mapType].id, MAP_TYPES[v].id, st.side)
						st.sea = 1
					end
					st.mapType = v
					changed()
				end)),
				-- labelled "Terrain" since 2026-10-12 (owner, REVIEW B12: the game's own heading for these settings);
				-- internally still relief (settings key, pipeline.RELIEF, the settings line in the log; the Report shows it
				-- as "terrain", settingsText); its tooltip names this climate's snow or rock line (TERRAIN_TIPS)
				field("Terrain", combo(RELIEF, st.relief, function(v) st.relief = v; changed() end),
					T(TERRAIN_TIPS[climateKey] or TERRAIN_TIPS.temperate)),
			})
			items[#items + 1] = help(typeInfo.description or "", "utg-desc")
			items[#items + 1] = fieldRow({
				field("Water", combo(WATER, st.water, function(v) st.water = v; changed() end),
					T("How many rivers and lakes.")),
				-- keyed by map type: its first choice names this type's default
				field("Ship rivers", combo(shipChoices(typeInfo), st.ships, function(v) st.ships = v; changed() end, nil,
					"utg-ships-" .. mapType.id),
					T("Rivers wide and deep enough for ships; the default depends on the map type.")),
			})
			if typeInfo.side then
				-- which map edge gets the map type's defining feature (Random: the seed decides, as before; the type's
				-- pre-selection until the player chooses, sideIndex); keyed by map type, since its label, meaning, choices
				-- (None) and pre-selection depend on it
				local choices = sideChoices(typeInfo)
				if (st.side or 1) > #choices then st.side = nil end -- (never shown or used: a choice this type lacks)
				local sideTip = T("Where the map type's main feature goes. Random: the seed decides.")
				if typeInfo.side.none then
					sideTip = T("Where the map type's main feature goes. Random: the seed decides. None: no sea.")
				elseif typeInfo.side.edge == "axis" then
					sideTip = T("Which way the strait runs. East-West: from the west edge to the east edge, with land to the north and south. North-South: with land to the west and east. Diagonal: from near one corner to near the opposite one, along the long side (on a map three or more times as long as wide, or under about 3 km across, it runs nearly straight: only a few degrees off the long side). Random: the seed decides.")
				end
				items[#items + 1] = field(typeInfo.side.label, combo(choices, sideIndex(st), function(v) st.side = v; changed() end,
					nil, "utg-side-" .. mapType.id), sideTip, "utg-label-wide")
				if typeInfo.side.seaChoice then
					-- its own box (Great River Valley): the side box keeps naming where the river comes from; keyed by map
					-- type like the side box; wide label, so its box lines up with the side box above
					items[#items + 1] = field("Sea", combo(SEA, st.sea or 1, function(v) st.sea = v; changed() end, nil,
						"utg-sea-" .. mapType.id),
						T("Where the big river ends: in the sea, on the edge opposite where it comes from. None: no sea; the river leaves the map there."),
						"utg-label-wide")
				end
				if sideIndex(st) == SIDE_NONE_INDEX or seaSetting(mapType.id, st.sea) == false then
					items[#items + 1] = help("No sea: the land goes on where the sea would be, and the rivers leave the map there.",
						"utg-note")
				end
			end
			if hasTrees then
				-- Lower tree density (owner 2026-10-13, run 9): the finishing pass's own setting, so only where this
				-- climate's pass declares it; a check box (CheckBox value 0/1 = the pass's index 1/2) in a labelled row like
				-- the other fields; keyed like the boxes (the key only names it for checks). The tooltip says in plain words
				-- what the owner asked for: the forest areas stay, only the number of trees drops.
				local tip = T("Fewer tree models for lower-spec computers (about half). Where forests grow stays the same; only how many trees are placed changes.")
				items[#items + 1] = field("Trees", builtin.CheckBox{
					meta = { class = "utg-check", tooltip = tip, localKey = "utg-lower-trees" },
					label = T("Lower tree density"), value = st.trees == 2 and 1 or 0,
					onValueChange = function(v) st.trees = (v == 1) and 2 or 1; changed() end }, tip)
			end
			items[#items + 1] = seedRow()
			items[#items + 1] = keepRow()
			-- The climate note follows the finishing pass, not climate.lua's `finished` (revision 4, owner 2026-10-14): no
			-- pass (one that failed to load, or a climate another mod adds): Apply gives the terrain shape only; a pass on a
			-- climate whose map types are not its own yet (`finished` false: Subarctic, Tropical, Dry): the map types are
			-- Temperate's; Temperate with its pass: no note. Either note names the climate and the map types that suit
			-- (climate.lua fits), so only for a climate climate.lua knows; one it does not know (another mod's) has no name
			-- or fits there, and without a pass it gets the plain note (review 2026-10-14; also when the profile could not
			-- be read: the plain note needs none).
			if not known and not hasFinish then
				items[#items + 1] = help("This climate gets the terrain shape only (no forests or biomes).", "utg-note")
			elseif prof and known and (not hasFinish or not prof.finished) then
				local fit = {}
				for _, id in ipairs(prof.fits) do
					if shapes.TYPES[id] then fit[#fit + 1] = T(shapes.TYPES[id].label or id) end
				end
				local body = T("Gets the terrain shape only (no forests or biomes). Best map types:")
				if hasFinish then
					body = T("The map types are made for Temperate; map types for this climate come later. Suits best:")
				end
				items[#items + 1] = help(string.format("%s %s. %s %s", T("Climate:"), T(prof.label), body,
					table.concat(fit, ", ")), "utg-note")
			end
		else
			items[#items + 1] = help("Preview shows this generator's map; your map changes only on Apply.", "utg-desc")
			local p = engineParams(g)
			for i = 1, #g.params do
				local prm = g.params[i]
				local key = prm.key
				items[#items + 1] = paramWidget(prm, p[key], function(v) p[key] = v; changed() end)
			end
			if #g.params == 0 then items[#items + 1] = help("This generator has no settings.") end
			items[#items + 1] = seedRow()
			items[#items + 1] = keepRow()
		end
		local wKm, hKm = mapSizeKm()
		if wKm ~= nil then
			items[#items + 1] = help(string.format("%s %.1f x %.1f km", T("Map size:"), wKm, hKm))
			if isUtg and math.min(wKm, hKm) < SMALL_MAP_KM then
				items[#items + 1] = help("Small map: few or no rivers below about 6 km.", "utg-note")
			end
		end
		return page(items)
	end
	local function parametersTab()
		local items = { help("100 % = as designed for the map type and the Terrain setting.") }
		-- sliders without effect here (core data, shapes.inactiveFor): the map type's own (shapes.TYPES[id].inactive) and
		-- those its side makes idle (no sea: no coast to roughen); each note names its own cause, since Coast roughness
		-- does work on these types when they have a sea
		local inactive, typeNames, sideNames, own = {}, {}, {}, {}
		for _, key in ipairs(typeInfo.inactive or {}) do own[key] = true end
		for _, key in ipairs(shapes.inactiveFor(mapType.id, sideIndex(st) - 1, seaSetting(mapType.id, st.sea))) do
			inactive[key] = true
			local list = own[key] and typeNames or sideNames
			list[#list + 1] = T(TUNE_LABELS[key] or key)
		end
		if #typeNames > 0 then
			items[#items + 1] = help(string.format("%s %s", T("No effect on this map type:"), table.concat(typeNames, ", ")),
				"utg-note")
		end
		if #sideNames > 0 then
			items[#items + 1] = help(string.format("%s %s", T("No effect without sea:"), table.concat(sideNames, ", ")),
				"utg-note")
		end
		for _, e in ipairs(pipeline.TUNE) do
			local key = e.key
			local maxPct = math.floor(e.max * 100)
			-- the slider's tooltip on its name and on the slider itself (REVIEW B2; the base game puts tooltips on sliders
			-- too: gui/music_player/music_player.tl)
			-- (Overall height's depends on the climate: HEIGHT_TIPS)
			local tipText = TUNE_TIPS[key]
			if key == "height" then tipText = HEIGHT_TIPS[climateKey] or HEIGHT_TIPS.temperate end
			local tip = tipText and T(tipText) or nil
			items[#items + 1] = styled("utg-field", H, {
				label(TUNE_LABELS[key] or key, "utg-label-wide", tip),
				builtin.Slider{ meta = { class = "utg-slider", tooltip = tip }, min = 0, max = maxPct, step = 5, pageStep = 25,
					value = st.tune[key], onValueChange = function(v) st.tune[key] = v; changed() end },
				builtin.TextView{ meta = { class = "utg-value, font-scale-body" },
					text = inactive[key] and "-" or string.format("%d %%", st.tune[key]) },
			})
		end
		items[#items + 1] = help("Lakes need natural basins: above 100 % there may be no more.")
		items[#items + 1] = styled("utg-buttons", H, {
			button("Reset all to 100 %", function() st.tune = defaultTune(); changed() end, "secondary"),
		})
		return page(items)
	end
	local function reportTab()
		local lines = {}
		if not isUtg then
			if S.measure ~= nil then
				lines[#lines + 1] = help(T("For:") .. " " .. S.measure.text)
				for line in S.measure.lines:gmatch("[^\n]+") do lines[#lines + 1] = help(line) end
				lines[#lines + 1] = help("Rivers, lakes and passes are counted only for this mod's own maps.")
			elseif S.measureJob ~= nil then
				lines[1] = help("Measuring the preview...")
			else
				lines[1] = help("Press Preview for the map and its numbers.")
			end
		elseif S.result ~= nil then
			lines[#lines + 1] = help(T("For:") .. " " .. settingsText(S.result.settings, true))
			for line in report.format(S.result.report):gmatch("[^\n]+") do
				lines[#lines + 1] = help(line, line:find("^note:") and "utg-note" or nil)
			end
		else
			lines[1] = help("Press Preview to see the report.")
		end
		return page(lines)
	end

	-- settings changed since the map in hand was made (settingsChanged): Preview and Apply make a new one; while an Apply
	-- waits for its preview the same line says so, and after a settings change cancelled it, that (until the next Preview
	-- or Apply click: the status line shows Generate's progress and "Preview ready" meanwhile, run 9 review)
	local stale = nil
	if S.applyCancelled then
		stale = T("Settings changed while the preview was being made: nothing applied. Press Apply to map again.")
	elseif settingsChanged() then
		stale = T("Settings changed since the last Preview.")
	elseif S.applyAfter ~= nil then
		stale = T("Apply to map waits for this preview, then applies it.")
	end

	local tabs = { tab("settings", "Settings", settingsTab) }
	if isUtg then tabs[#tabs + 1] = tab("parameters", "Terrain parameters", parametersTab) end
	tabs[#tabs + 1] = tab("report", "Report", reportTab)
	local tabValue = tabState:old()
	if not isUtg and tabValue == "parameters" then tabValue = "settings" end

	-- buttons (2026-10-08, players: "the buttons don't look like buttons"): the game's plain Button has an invisible
	-- background and border; base windows mark main actions "primary" (filled) and others "secondary" (outlined), and
	-- disable buttons that cannot act (meta.enabled; base gui/map_editor/map_editor.tl:733, main/default.css.lua:77-120)
	local canPreview = not busy
	-- Apply works whenever Preview does (owner 2026-10-13, run 9): without a map for the current settings it makes the
	-- preview first (startApplyAfterPreview)
	local canApply = canPreview
	local applyNow = canApply and applyReadyNow()
	-- the next step is the one filled ("primary") button: Preview -> Apply (Preview again when the settings changed)
	local nextStep = applyNow and "apply" or "preview"
	local function kind(step) return nextStep == step and "primary" or "secondary" end
	local applyTip = T("Wait for the current work to finish.")
	if applyNow and isUtg and not hasFinish then
		applyTip = T("Puts the generated heights on your map (this climate gets no forests or biomes).")
	elseif applyNow then
		applyTip = T("Puts the previewed map on your map. Forests and biomes are added now; the preview shows the land only.")
	elseif canApply then
		applyTip = T("Makes the preview for the current settings first (as Preview does), then puts that map on your map.")
	end
	local actions = {}
	actions[#actions + 1] = button("Preview", function()
		guarded("Preview", function() previewClicked(setStatus) end, setStatus)
	end, kind("preview"), canPreview, (not canPreview) and T("Wait for the current work to finish.") or nil)
	actions[#actions + 1] = button("Apply to map", function()
		guarded("Apply", function() apply(setStatus) end, setStatus)
	end, kind("apply"), canApply, applyTip)
	actions[#actions + 1] = button("Undo", function()
		guarded("Undo", function() undo(setStatus) end, setStatus)
	end, "secondary", (not busy) and S.undoMap ~= nil)

	-- debug tools (built as a list: a nil inside a table constructor would cut off the buttons after it); the test set
	-- is this mod's generator's own standard, so it is not offered for a game generator
	local debugRow = {
		label("Debug", "utg-label-small"),
		button("Export", function() guarded("Export", function() exportMap(setStatus) end, setStatus) end,
			"secondary", not S.busy and S.batch == nil),
	}
	if isUtg then
		debugRow[#debugRow + 1] = button(S.batch ~= nil and "Stop test set" or "Test set", function()
			guarded("Test set", function() toggleTestSet(setStatus) end, setStatus)
		end, "secondary", S.batch ~= nil or not busy)
	end
	if isUtg and hasFinish then
		debugRow[#debugRow + 1] = button("Run test", function()
			guarded("Run test", function() startAutoTest(setStatus) end, setStatus)
		end, "secondary", not busy,
			T("Previews, applies, exports the finished map and the world, and saves the log, all by itself."))
	end
	debugRow[#debugRow + 1] = button("Save log", function()
		guarded("Save log", function() saveLog(setStatus) end, setStatus)
	end, "secondary")

	local left = styled("utg-left", V, {
		builtin.TabWidget{
			meta = { class = "utg-tabs" },
			value = tabValue,
			onValueChange = function(v) if v ~= nil then tabState:set(v) end end,
			tabs = tabs,
		},
		help(stale or "", "utg-note"),
		help(statusState:old(), "utg-status"),
		styled("utg-buttons", H, actions),
		debugTools() and styled("utg-buttons", H, debugRow) or hbox({}),
	})

	-- the preview pane fills the rest of the window; the map appears in it on Preview
	local preview
	local request = S.request
	if request ~= nil and request.n == nil then
		S.requestSeq = (S.requestSeq or 0) + 1 -- numbers each request once (its preview component's key)
		request.n = S.requestSeq
	end
	if request ~= nil then
		local okColoring, coloring = pcall(function()
			return api.res.climateRep.get(api.res.climateRep.find(api.res.getBaseConfig().climate)).mapColoring
		end)
		preview = builtin.MapPreviewComp{
			-- one component per request (localKey, as base map_editor.tl:2884 keys its TabAndPreview): every Preview press
			-- runs the generator, even when the inputs equal the last ones
			meta = { class = "utg-studio-preview", localKey = "utg-preview-" .. tostring(request.n) },
			mapColoring = okColoring and coloring or nil,
			showMapSize = true,
			showTownAndIndustryCount = false,
			showBiomesColors = false,
			mode = request.mode,
			inputMap = request.inputMap,
			economy = api.res.getBaseConfig().economyId,
			params = request.params,
			seed = request.seed,
			locationsConfig = api.res.getBaseConfig().locations,
			onStart = function()
				request.t0 = clock()
				out("Preview started")
			end,
			onReady = function(map, _feedback)
				if S.request ~= request then return end -- an older preview finished late
				S.ready = map
				out(string.format("Preview ready after %.1f s (%s)", clock() - (request.t0 or clock()),
					tostring(request.generator)))
				if S.requestKind == "engine" then startMeasure(map, S.requestText) end
				local keepsAll = S.settings.keepTowns and S.settings.keepIndustries
				if S.applyAfter ~= nil then
					statusState:set("Applying...") -- the waiting Apply puts it in on the next frame (stepApplyAfter)
				else
					statusState:set(keepsAll and "Preview ready. Apply to map replaces the terrain."
						or "Preview ready. Apply to map also removes towns and industries not kept.")
				end
				if S.autoTest ~= nil and S.requestKind == "utg" then
					local okT, msgT = pcall(autoTestReady, map)
					if not okT then
						out("Run test FAILED: " .. tostring(msgT))
						autoTestEnd("stopped")
						msgT = "Run test failed (see the saved log)."
					end
					statusState:set(T(msgT))
				end
			end,
		}
	else
		-- after the window was closed, the finished preview is kept for Apply but not run again until Preview
		preview = help(S.ready ~= nil and "The previewed map is still ready for Apply. Press Preview to see it again."
			or "The map appears here after Preview.", "utg-preview-empty")
	end
	local right = styled("utg-right", V, {
		styled("utg-pane-head", H, {
			button(params.expanded and "Smaller window" or "Larger window", function()
				if params.setExpanded then params.setExpanded(not params.expanded) end
			end, "secondary"),
		}),
		preview,
	})
	return styled("utg-studio", H, { left, right })
end)

-- Window width from the screen (owner 2026-10-08, 5120 x 1440: the window took 84 % of the width). The game update of
-- 2026-10-08 added api.util.getGraphicsPresetParam().screenExtent = { width, height }; it was not readable when the
-- stylesheet loads (run 8), so it is read here when the window opens. Width = settings column + a SQUARE preview
-- (window height minus title, pane head and padding) + spacing, as a share of the screen width rounded down to an
-- even number, between 30 and the 16:9 share (84 / Larger 96); the stylesheet has a rule per share ("utg-wNN",
-- "utg-xNN"). Logged once per session; nil when the screen size cannot be read (then the stylesheet's default).
local windowClass = nil -- false = tried and not readable
local function windowWidthClass()
	if windowClass ~= nil then return windowClass or nil end
	windowClass = false
	local ok, w, h = pcall(function()
		local ext = api.util.getGraphicsPresetParam().screenExtent
		local a, b = ext[1], ext[2]
		if a == nil and ext.x ~= nil then a, b = ext.x, ext.y end
		return a, b
	end)
	if ok and type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
		local function share(heightShare, maxShare)
			local want = 720 + 16 + (h * heightShare / 100 - 110) + 40
			local s = math.floor(want / w * 100 / 2 + 0.5) * 2 -- nearest even share (a rule per even share)
			return math.min(maxShare, math.max(30, s))
		end
		local n, x = share(80, 84), share(88, 96)
		windowClass = string.format("utg-w%d, utg-x%d", n, x)
		out(string.format("Screen %d x %d: window %d %% of the width (Larger window %d %%)", w, h, n, x))
	else
		out("Screen size not readable (" .. tostring(w) .. "): default window size")
	end
	return windowClass or nil
end

-- ------------------------------------------------------------------------------------------------
-- The window recipe: a wrapper of the game's own Window, whatever other mods did to builtin.Window
-- ------------------------------------------------------------------------------------------------
-- A window recipe must wrap the game's Window component: the engine's window container finds the window node through
-- _react.recipeMetas[<window recipe id>].innerRecipeId (base gui/main/react.lua RegisterRecipeInner, lines 248-261;
-- the engine reads both names). react.RegisterWrapperRecipe(name, builtin.Window, fn) finds that id from the FUNCTION
-- it is given (react.lua's recipeFnToRecipeId, which knows only registered recipe functions). A mod that replaces
-- builtin.Window with a function of its own before this script loads therefore makes the wrapper "a wrapper around
-- nil", and opening the window kills the game (NodeStorage.cpp:51 assertion; seen 2026-10-13). The game keeps its own
-- Window recipe in the global tables of base/init.lua: its id in _react.builtin.Window (the id builtin.lua declares it
-- with) and its node constructor in _react.originalRecipeFn[id]. So:
--   react reports builtin.Window as the game's Window (react.GetRecipeId gives that id): the normal wrapper, and the
--     window node built by that function, captured now (a mod that replaces builtin.Window later cannot change this
--     window either). Then the record RegisterWrapperRecipe wrote is checked, not assumed: a mod can also replace
--     react's own functions (GetRecipeId, RegisterWrapperRecipe), and a lookup that names the game's Window while the
--     registration records nothing would bring the crash back. A record that does not name the game's Window is
--     repaired as below;
--   builtin.Window replaced (or the record wrong): the same registration by id: react.RegisterRecipe (or the recipe
--     just registered), then recipeMetas[our id] = { innerRecipeId = the game's id } (exactly what
--     RegisterWrapperRecipe writes for a wrapper of the game's Window), and the node built as the game's registered
--     function builds it (an official recipe replacement first, then the constructor; react.lua 380-388). react's
--     per-render check of a wrapper's child (checkRecipeMatch) only logs a verbose line on a mismatch, and the child
--     is the game's Window by construction;
--   neither possible (the game's tables not as expected): no window at all; the mod button says why (never a crash).
-- Returns the recipe (nil when unavailable), the Window constructor for its body, and the problem text (nil if none).
local function recipeIdOf(fn)
	local ok, id = pcall(react.GetRecipeId, fn)
	return ok and id or nil
end

local function registerWindowRecipe(name, fn)
	local R = type(_react) == "table" and _react or {}
	local windowId = type(R.builtin) == "table" and R.builtin.Window or nil
	local current = recipeIdOf(builtin.Window)
	local recipe, why
	if current ~= nil and (windowId == nil or current == windowId) then
		local window = builtin.Window
		recipe = react.RegisterWrapperRecipe(name, window, fn)
		-- nothing to check against when the game's tables are not as expected: the normal wrapper as before
		if windowId == nil or type(R.recipeMetas) ~= "table" then return recipe, window, nil end
		local meta = R.recipeMetas[recipeIdOf(recipe)]
		if type(meta) == "table" and meta.innerRecipeId == windowId then return recipe, window, nil end
		why = "react did not record the game's Window for the Studio window"
	else
		why = current == nil and "builtin.Window is a function react does not know"
			or string.format("builtin.Window is now recipe id %s", tostring(current))
	end
	local construct = windowId ~= nil and type(R.originalRecipeFn) == "table" and R.originalRecipeFn[windowId] or nil
	if type(construct) ~= "function" or type(R.recipeMetas) ~= "table" then
		return nil, nil, string.format("%s, and the game's Window recipe was not found (id %s)", why, tostring(windowId))
	end
	recipe = recipe or react.RegisterRecipe(name, fn)
	local id = recipeIdOf(recipe)
	if id == nil then return nil, nil, "the window recipe got no id" end
	R.recipeMetas[id] = { innerRecipeId = windowId }
	out(string.format("Another mod replaced the game's window component (%s): the Studio window wraps the game's own "
		.. "Window recipe (id %s) instead", why, tostring(windowId)))
	local function window(...)
		local replacement = type(R.recipeReplace) == "table" and R.recipeReplace[windowId] or nil
		if replacement then return replacement(...) end
		return construct(...)
	end
	return recipe, window, nil
end

-- what the mod button says when the window cannot open (translated when the button is drawn)
local function windowUnavailableText()
	return T("The Studio window cannot open safely: another mod replaced the game's window component and the game's own one was not found. Disable mods that change game windows, then load the map again.")
end

local StudioWindow, gameWindow, windowProblem -- gameWindow: the Window constructor the window body uses
StudioWindow, gameWindow, windowProblem = registerWindowRecipe("UtgStudioWindow", function(params)
	-- two sizes, as the base Statistics window: windows cannot be dragged to any size (WindowParam has no resize),
	-- but `expanded` switches to the second size set in utg_studio.css.lua
	local expandedState = react.useState(false)
	local okW, wclass = pcall(windowWidthClass)
	return gameWindow{
		meta = { class = okW and wclass or nil },
		id = "utg.studio.window",
		title = T("Ultimate Terrain Generator"),
		closable = true,
		onClose = params.onClose,
		-- movable (owner, run 7: "Studio window no longer movable"), placed like the base's movable windows by shares of
		-- the free space (entity windows: initialX = 1, initialY = 0, gui/entity_window/view_manager.tl 310; dialogs 0.5 =
		-- centred). The stylesheet only sizes the window: a stylesheet gravity pins it (base Statistics, not movable).
		-- (2026-10-08 initialX = 0.5 opened at the left edge, but the window then ignored its width caps and filled
		-- almost the whole screen, so there was no free space to share; the width now comes from the screen.)
		movable = true,
		initialX = 0.5,
		initialY = 0.5,
		expanded = expandedState:old(),
		content = StudioPanel{
			expanded = expandedState:old(),
			setExpanded = function(v) expandedState:set(v) end,
		},
	}
end)
if windowProblem ~= nil then out("Studio window unavailable: " .. windowProblem) end

local function isMapEditor()
	local ok, value = pcall(function() return api.gui.game.isMapEditor() end)
	return ok and value == true
end

local UtgModButtonPlugin = react.RegisterPluginRecipe(main_mod_button_area.MainModButtonAreaExtension, "UtgModButton",
	function()
		local openState = react.useState(false) -- hooks first, before any early return
		if not isMapEditor() then
			return hbox({})
		end
		if StudioWindow == nil then
			-- the window cannot open safely (registerWindowRecipe): the button stays, says why and opens nothing. A plain
			-- Button, not the toggle: it has no on/off state that a refused click could leave pressed.
			return hbox({
				builtin.Button{
					content = builtin.TextView{ text = "UTG", meta = { tooltip = windowUnavailableText() } },
					onClick = function() out("Studio window not opened: " .. tostring(windowProblem)) end,
				},
			})
		end
		local function closeWindow()
			S.request = nil -- keep S.ready for Apply; Preview shows the map again
			if S.applyAfter ~= nil then
				-- its preview stops with the window, and a closed window must not change the map later
				S.applyAfter = nil
				out("Apply cancelled: the window was closed")
			end
			local windowApi = game_react_globals.getDefaultWindowApi()
			if windowApi then windowApi.removeAllWindows(StudioWindow) end
			openState:set(false)
		end
		local function openWindow()
			local windowApi = game_react_globals.getDefaultWindowApi()
			openState:set(true)
			if windowApi then
				-- the close button only calls onClose; the callback removes the window itself
				windowApi.addSingletonWindow(StudioWindow, { onClose = closeWindow })
			end
		end
		return hbox({
			builtin.ToggleButton{
				content = builtin.TextView{ text = "UTG", meta = { tooltip = T("Ultimate Terrain Generator") } },
				value = openState:old() and 1 or 0,
				onValueChange = function(value)
					if value == 1 then openWindow() else closeWindow() end
				end,
			},
		})
	end)

-- The game's script loader requires every .script file to define data() returning its exports.
function data()
	return {
		UtgModButtonPlugin = UtgModButtonPlugin,
	}
end

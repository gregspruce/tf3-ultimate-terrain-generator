--[[
pipeline.lua - runs the whole terrain generation: settings in, full-resolution heightmap and report out
(pure Lua 5.2; the same code runs in the game and in a standalone Lua 5.2 for testing).

USE
  local pipeline = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/pipeline.lua"
  local result = pipeline.run(settings, map [, hooks])
    settings = { mapType = "great_river_valley" | "delta_lowlands" | "mountain_passes",
                 relief = 1..5 (M.RELIEF: Gentle, Moderate, Hilly, Rugged, Mountainous), water = 1..3 (Dry, Normal, Wet),
                 ships = nil (map type default) | 0 (None) | 1 (One) | 2 (Several), seed = number or string,
                 side = 0 (from the seed) | 1..4 (feature side north, east, south, west; shapes.TYPES[id].side),
                 tune = { key = multiplier } (optional; Advanced settings, 1 = as designed; M.TUNE lists them) }
    map      = { sizeX, sizeY }  map size in metres (the heightmap has sizeX / 4 + 1 nodes per row)
    hooks    = { tick = function() end (called often; may yield), stage = function(name) end }
  result = { heights (flat array, index j * w + i + 1, metres, as GameMap.heightmap), w, h,
             report (report.lua), paths (river courses), lakes, corridors (pass routes, passes.lua),
             coarse = { g, h, kind, A, B, U },
             timings = { {stage, seconds}... }, settings (normalised) }

  For the editor window (M2) the work must not freeze the game: pipeline.job(settings, map) returns a job;
  call job:step(seconds) once per frame until it returns true, then read job.result (or job.error).

STAGES
  shape (shapes.lua) -> drainage (hydrology.lua) -> rivers (rivers.lua) -> landform (landform.lua, passes.lua)
  -> detail + carve (detail.lua) -> report (report.lua)
]]

local P = "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/"
local shapes = require(P .. "shapes.lua")
local hydrology = require(P .. "hydrology.lua")
local rivers = require(P .. "rivers.lua")
local landform = require(P .. "landform.lua")
local detail = require(P .. "detail.lua")
local report = require(P .. "report.lua")

local M = {}

local clock = (os ~= nil and os.clock) or function() return 0 end
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

M.MAP_TYPES = shapes.ORDER
-- Relief levels as data (index = settings.relief), so a host window can list them. Run 6: Flat dropped (the owner:
-- too uninteresting; Gentle is easy enough), Moderate and Rugged added between Gentle, Hilly and Mountainous.
M.RELIEF = {
	{ key = "gentle", label = "Gentle" },
	{ key = "moderate", label = "Moderate" },
	{ key = "hilly", label = "Hilly" },
	{ key = "rugged", label = "Rugged" },
	{ key = "mountainous", label = "Mountainous" },
}
M.A_WATER = { 30e6, 12e6, 5e6 } -- m^2 drained before a channel holds water: Dry, Normal, Wet (11 km map)
M.MIN_RIVER = 1500              -- m: shorter leaf rivers are dropped (a map type may set preset.minRiver, e.g. islands)
M.MAX_COARSE = 300000           -- coarse nodes: the cell is the smallest of 16, 32, 64 m within this
M.PIT_DEPTH = 0.5               -- organisation-field units: shallower pits are not lake sites
-- Advanced settings (run 5: the owner asked for more control than presets): multipliers on the designed values,
-- 1 = as designed, clamped to 0 .. max. Order = Studio order.
M.TUNE = {
	{ key = "height", max = 2 },     -- overall height: the Relief target (landform.RELIEF_P99), hills included
	{ key = "hills", max = 2 },      -- share of the land that is hill country (landform.HILL_COVER)
	{ key = "hillHeight", max = 2 }, -- height of the hills (landform.HILL_AMP)
	{ key = "detail", max = 2 },     -- surface detail on hills and slopes (detail.DETAIL_AMP)
	{ key = "gullies", max = 2 },    -- erosion: spurs and gullies down the slopes (gullies.K1, K2)
	{ key = "coast", max = 2 },      -- coast roughness (shapes.COAST_RAG)
	{ key = "rivers", max = 2 },     -- number of rivers (divides the drained area a river needs)
	{ key = "lakes", max = 3 },      -- number of lakes (landform.LAKES_PER_WATER)
	{ key = "meander", max = 2 },    -- how strongly rivers wind
	{ key = "valley", max = 2 },     -- width of river valleys and floodplains
}

function M.normalise(settings)
	local s = {}
	for k, v in pairs(settings or {}) do s[k] = v end
	s.mapType = shapes.TYPES[s.mapType or ""] and s.mapType or "great_river_valley"
	s.relief = min(#M.RELIEF, max(1, floor(s.relief or 1)))
	s.water = min(3, max(1, floor(s.water or 2)))
	-- feature side (0 = from the seed; 1..4 = shapes.SIDES north, east, south, west); types without one ignore it
	s.side = shapes.TYPES[s.mapType].side and min(4, max(0, floor(tonumber(s.side) or 0))) or 0
	if s.ships == nil then s.ships = shapes.TYPES[s.mapType].preset.ships end
	s.ships = min(2, max(0, floor(s.ships)))
	if s.seed == nil then s.seed = 1 end
	local tune = {}
	for _, t in ipairs(M.TUNE) do
		local v = tonumber(settings and settings.tune and settings.tune[t.key]) or 1
		tune[t.key] = min(t.max, max(0, v))
	end
	s.tune = tune
	return s
end

function M.coarseGrid(sizeX, sizeY)
	local Wf, Hf = floor(sizeX / 4 + 0.5) + 1, floor(sizeY / 4 + 0.5) + 1
	local cell = 64
	for _, c in ipairs({ 16, 32, 64 }) do
		if (sizeX / c + 1) * (sizeY / c + 1) <= M.MAX_COARSE then cell = c break end
	end
	local R = cell / 4
	return { w = ceil((Wf - 1) / R) + 1, h = ceil((Hf - 1) / R) + 1, cell = cell }, Wf, Hf
end

function M.run(settings, map, hooks)
	hooks = hooks or {}
	local ctx = { tick = hooks.tick or function() end }
	local s = M.normalise(settings)
	local g, Wf, Hf = M.coarseGrid(map.sizeX, map.sizeY)
	local timings = {}
	local t0 = clock()
	local function stage(name)
		local t = clock()
		timings[#timings + 1] = { name, t - t0 }
		t0 = t
		if hooks.stage then hooks.stage(name) end
	end

	local shape = shapes.build(s.mapType, g, s.seed, ctx, s.tune, s.side)
	stage("shape")

	local f = hydrology.flood(shape.B, g, shape.sea, shape.outlets, ctx)
	local A = hydrology.accumulate(f, g, shape.inflows)
	local deps = hydrology.depressions(f, shape.B, g, M.PIT_DEPTH)
	-- the water threshold follows the map area (11 km map = 1), so small maps still get a river network
	local areaScale = min(1.5, max(0.35, map.sizeX * map.sizeY / (11264 * 11264)))
	local aWater = M.A_WATER[s.water] * shape.preset.rivers * areaScale / max(0.1, s.tune.rivers)
	local rv, water = hydrology.rivers(f, A, g, aWater, shape.preset.minRiver or M.MIN_RIVER)
	stage("drainage")

	local paths, shipTo, fpNode = rivers.build({ f = f, A = A, rivers = rv, aWater = aWater }, g, shape,
		{ ships = s.ships, meander = shape.preset.meander * s.tune.meander, seed = s.seed }, ctx)
	stage("rivers")

	local lf = landform.build(shape, { f = f, A = A, water = water, depressions = deps }, paths, fpNode, g, s, ctx)
	-- ship channels run on to water as deep as themselves; oxbow lakes need the final floodplains (both carved later)
	rivers.extendMouths(paths, lf.h, lf.kind, g, detail.SHIP_BED)
	for _, p in ipairs(rivers.oxbows(paths, lf.h, lf.kind, g, s)) do paths[#paths + 1] = p end
	stage("landform")

	local H = detail.upsample(lf.h, g, Wf, Hf, lf.kind, s, shape.preset, s.seed, ctx, lf.rough)
	stage("detail")
	detail.carve(H, Wf, Hf, paths, ctx)
	stage("carve")

	local rep = report.build(H, Wf, Hf, paths, lf.lakes, ctx, lf.corridors, { g = g, kind = lf.kind })
	-- what the settings asked for, so the report can say when the map could not give it (offline settings test 2026-10-08:
	-- Ship rivers One/Several on maps with no large river, Lakes above 100 % with no more lake sites)
	rep.shipsAsked, rep.lakesWanted = s.ships, lf.lakesWanted
	stage("report")

	return {
		heights = H, w = Wf, h = Hf, report = rep, paths = paths, lakes = lf.lakes, corridors = lf.corridors,
		timings = timings, settings = s,
		coarse = { g = g, h = lf.h, kind = lf.kind, A = A, B = shape.B, U = shape.U, water = water,
			orientation = shape.orientation },
	}
end

-- Frame-budget runner: the pipeline runs in a coroutine that yields whenever its time slice is used up.
function M.job(settings, map, hooks)
	hooks = hooks or {}
	local deadline = 0
	local job = { done = false }
	local co = coroutine.create(function()
		return M.run(settings, map, {
			stage = function(name)
				job.stage = name
				if hooks.stage then hooks.stage(name) end
			end,
			tick = function()
				if clock() > deadline then coroutine.yield() end
			end,
		})
	end)
	function job.step(self, seconds)
		if self.done then return true end
		deadline = clock() + (seconds or 0.02)
		local ok, res = coroutine.resume(co)
		if not ok then
			self.done, self.error = true, tostring(res)
		elseif coroutine.status(co) == "dead" then
			self.done, self.result = true, res
		end
		return self.done
	end
	return job
end

return M

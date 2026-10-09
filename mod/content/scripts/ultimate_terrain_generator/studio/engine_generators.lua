--[[
engine_generators.lua - the game's own terrain generators (vanilla and mods) for the Studio window, and the map
editor steps around Apply (plain Lua 5.2; engine-facing, used only by the Studio window, not by the terrain core).

WHY (owner 2026-10-08: "implement the ability to select any vanilla or mod generator"; keep towns / industries like
the vanilla window)
  The Studio can run any terrain generator of the current climate with its own parameters, and preview it only when
  the player presses Preview (the game's own window recomputes on every change). Everything here follows the base
  game's map editor (gui/map_editor/map_editor.tl: generator list, parameter defaults, preview inputs, the order of
  commands on Generate), so a generator behaves as it does there.

USE
  local eg = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/studio/engine_generators.lua"
  eg.list()                         -> { { name, label, params, order }... } this climate, visible, not import-style
  eg.defaults(gen)                  -> { key = value } (value = numbers[i] if the parameter lists numbers, else index i)
  eg.valueOf(param, i), eg.indexOf(param, value)
  eg.makeRequest(name, params, seed) -> preview request { mode, inputMap, params, seed, generator }
  eg.removeTownsAndIndustries(keepTowns, keepIndustries, done, log)   done(ok) after the last command
  eg.measure(map, tick)             -> numbers of a finished map (land, slopes, heights), as the UTG report counts them
]]

local M = {}

-- ----------------------------------------------------------------------------------------------------------
-- generators and their parameters
-- ----------------------------------------------------------------------------------------------------------
-- base: map_editor.tl getPossibleGenerators (climate match, visible) + the generate tab's "not import" filter
function M.list()
	local climate = api.res.getBaseConfig().climate
	local out = {}
	for k, _ in pairs(app.res.terrainGeneratorRep.getAll()) do
		local gen = app.res.terrainGeneratorRep.get(k)
		local name = tostring(app.res.terrainGeneratorRep.getName(k))
		-- never this mod's own finishing passes (a test variant may be a normal generator)
		if gen and gen.climate == climate and gen.visible and not gen.isImportGenerator
				and not name:find("utg_finish_", 1, true) then
			local label = gen.desc and gen.desc.name or name
			out[#out + 1] = { name = name, label = tostring(label), params = gen.params or {}, order = gen.order or 0 }
		end
	end
	table.sort(out, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.label < b.label
	end)
	return out
end

local function count(t)
	if t == nil then return 0 end
	return #t
end

-- value of choice i (1-based): the parameter's number when it lists them, else the index (base: getValueOfIndex1)
function M.valueOf(param, i)
	local nums = param.numbers
	if count(nums) > 0 and count(nums) == count(param.values) and nums[i] ~= nil then return nums[i] end
	return i
end

-- choice index of a value (base: getIndex1OfValue)
function M.indexOf(param, value)
	local nums = param.numbers
	if count(nums) > 0 and count(nums) == count(param.values) then
		local best, bd = 1, math.huge
		for i = 1, count(nums) do
			local d = math.abs(nums[i] - value)
			if d < bd then best, bd = i, d end
		end
		return best
	end
	local n = math.floor((tonumber(value) or 1) + 0.5)
	return math.max(1, math.min(math.max(1, count(param.values)), n))
end

-- default value (base: getScriptParamDefaultValueIndex = round(getScriptParamDefaultValue): numbers[defaultIndex] when
-- there are more numbers, else the index; rounded, as the base map editor passes it to the preview)
function M.defaultValue(param)
	local di = param.defaultIndex or 1
	local nums = param.numbers
	local v = di
	if count(nums) > di then v = nums[di] end
	return math.floor(v + 0.5)
end

function M.defaults(gen)
	local out = {}
	for i = 1, count(gen.params) do
		local p = gen.params[i]
		out[p.key] = M.defaultValue(p)
	end
	return out
end

-- preview inputs as the base generate tab builds them (computeMode, makeMap), keepHeightmap off: the generator makes
-- the heights. Import-style generators are never listed (they need keepHeightmap on, or the game crashes).
function M.makeRequest(name, params, seed)
	local mode = api.type.HeighmapGenerationMode.new()
	mode.terrainGenerator = name
	mode.generateTowns = false
	mode.generateIndustries = false
	mode.generateAssets = true
	mode.keepHeightmap = false
	mode.keepBiomes = false
	local map = api.engine.terrain.makeMapFromGame(true, true, true, false)
	map.waterLevel = 0
	local p = {}
	for k, v in pairs(params or {}) do p[k] = v end
	return { mode = mode, inputMap = map, params = p, seed = tostring(seed or ""), generator = name }
end

-- ----------------------------------------------------------------------------------------------------------
-- Apply: remove towns and industries first unless kept (base map_editor.tl Generate button: towns, then industries,
-- then the terrain, each step in the previous step's callback)
-- ----------------------------------------------------------------------------------------------------------
local function removeTowns(done, log)
	local towns = {}
	api.engine.forEachEntityWithComponent(function(e) towns[#towns + 1] = e end, api.type.ComponentType.TOWN)
	if log then log(string.format("Apply: removing %d town(s)", #towns)) end
	if #towns == 0 then return done(true) end
	for i, e in ipairs(towns) do
		api.cmd.sendCommand(api.cmd.makeTownDestroyCmd(e), i == #towns and function(_, ok) done(ok ~= false) end or nil)
	end
end

-- industries with their roads, as base industry_util.removeIndustries does, but counting the constructions actually
-- found (the base compares the loop index with the industry count, so an industry without a construction would leave
-- its callback unsent). The proposals are not player-initiated (4th argument false: no cost, no reputation).
local function removeIndustries(done, log)
	local map = api.engine.terrain.makeMapFromGame(false, false, true, false)
	local constructions, segments, seenSeg = {}, {}, {}
	for _, ind in ipairs(map.industries or {}) do
		local e = ind.existing
		if e ~= nil and e >= 0 then
			local c = api.engine.system.streetConnectorSystem.getConstructionEntityForSubconstruction(e)
			if c ~= nil and c >= 0 then
				constructions[#constructions + 1] = c
				for _, s in ipairs(api.engine.util.construction.findSegmentsToDelete(c) or {}) do
					if not seenSeg[s] then seenSeg[s] = true; segments[#segments + 1] = s end
				end
			end
		end
	end
	if log then log(string.format("Apply: removing %d industr%s and %d road segment(s)", #constructions,
		#constructions == 1 and "y" or "ies", #segments)) end
	if #constructions == 0 then return done(true) end
	local function afterIndustries(_, ok)
		if #segments == 0 then return done(ok ~= false) end
		local proposal = api.engine.util.proposal.makeSegmentsRemoveProposal(segments)
		api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, nil, true, false, false),
			function(_, ok2) done(ok2 ~= false) end)
	end
	for i, c in ipairs(constructions) do
		local context = api.type.Context.new()
		local proposal = api.engine.util.proposal.createProposalRemove(c, context)
		api.cmd.sendCommand(api.cmd.makeWorldBuildProposalCmd(proposal, context, true, false, false),
			i == #constructions and afterIndustries or nil)
	end
end

function M.removeTownsAndIndustries(keepTowns, keepIndustries, done, log)
	local function industries()
		if keepIndustries then return done(true) end
		removeIndustries(done, log)
	end
	if keepTowns then return industries() end
	removeTowns(function() industries() end, log)
end

-- ----------------------------------------------------------------------------------------------------------
-- numbers of a finished map (any generator), counted as the UTG report counts them (report.lua: slope on an 8 m grid
-- from 4 m neighbours, classes < 3 %, 3-8.5 %, 8.5-25 %, steeper; heights of land)
-- ----------------------------------------------------------------------------------------------------------
function M.measure(map, tick)
	local H = map.heightmap -- one copy of the whole table
	local step = (map.resolution and map.resolution.x) or 4
	local W = map.numTilesX * 256 / step + 1
	local Hh = map.numTilesY * 256 / step + 1
	local wl = map.waterLevel or 0
	local SS = W > 3200 and 4 or 2
	local land, water, c3, c85, c25, cSteep = 0, 0, 0, 0, 0, 0
	local heights = {}
	for j = SS, Hh - 1 - SS, SS do
		local row = j * W + 1
		for i = SS, W - 1 - SS, SS do
			local k = row + i
			local v = H[k]
			if v < wl then
				water = water + 1
			else
				land = land + 1
				if i % 8 == 0 and j % 8 == 0 then heights[#heights + 1] = v - wl end
				local gx = (H[k + 1] - H[k - 1]) / (2 * step)
				local gy = (H[k + W] - H[k - W]) / (2 * step)
				local s = math.sqrt(gx * gx + gy * gy)
				if s < 0.03 then c3 = c3 + 1 elseif s < 0.085 then c85 = c85 + 1
				elseif s < 0.25 then c25 = c25 + 1 else cSteep = cSteep + 1 end
			end
		end
		if tick then tick() end
	end
	table.sort(heights)
	local function q(p)
		if #heights == 0 then return 0 end
		return heights[math.max(1, math.min(#heights, math.floor(p * #heights + 0.5)))]
	end
	local total, L = math.max(1, land + water), math.max(1, land)
	return {
		landShare = land / total, waterShare = water / total,
		flat = c3 / L, railable = c85 / L, steep = c25 / L, verySteep = cSteep / L,
		heightMedian = q(0.5), heightP99 = q(0.99), heightMax = heights[#heights] or 0,
		sizeKm = { (W - 1) * step / 1000, (Hh - 1) * step / 1000 },
	}
end

function M.formatMeasure(r)
	return table.concat({
		string.format("land %.0f %%, water %.0f %%", 100 * r.landShare, 100 * r.waterShare),
		string.format("land slope: flat (<3 %%) %.0f %%, rail (3-8.5 %%) %.0f %%, steep (8.5-25 %%) %.0f %%, very steep %.0f %%",
			100 * r.flat, 100 * r.railable, 100 * r.steep, 100 * r.verySteep),
		string.format("land height: median %.0f m, 99 %% %.0f m, max %.0f m", r.heightMedian, r.heightP99, r.heightMax),
	}, "\n")
end

return M

--[[
landform.lua - coarse heights built around the drainage network (pure Lua 5.2).

HOW THE LAND IS MADE (the "inevitable" model for a map whose water sits at 0 m)
  1. Channels (stream power). Where enough land drains (CHANNEL_AREA, by Relief: few broad valleys on gentle
     land, many in mountains) the slope of the flow path falls with the area it drains: slope = U * A^-m
     (m ~ 0.45). Walking the flow tree from the sea upwards, each channel node is its receiver's height plus that
     slope times the step: big rivers nearly flat, headwaters steep, no pits. Water nodes sit on their
     floodplain level.
  2. Hillslopes. Every other node rises from its nearest channel (or the coast): the lower envelope of those
     slopes forms ridges between valleys. On gentle map types the profile is concave (steep near the valley,
     flattening towards broad tops: buildable uplands); mountain types keep straight slopes. (Per-node stream
     power on tiny areas showed the 8 flow directions as streaks; this does not.)
  3. Relief scaling to the Relief setting (99th percentile of the land: Gentle 140 m .. Mountainous 420 m, times the
     map type's factor), a slope limit, and smoothing that rounds ridges.
  4. Lakes. Natural pits of the organisation field that lie on a river become basins below 0 (largest pits keep
     their deepest part, fragments are dropped); the river flows in and out of them.
  2c. Hill country (game scale): patches of hills added on top (HILL_COVER, HILL_AMP), the main source of
     relief at the scale of a few hundred metres; also the "roughness" that tells detail.lua where rock texture goes.
  5. Valleys. Along every river's centreline the land is lowered to a floodplain wide enough for the meander
     belt (0 .. +0.7 m of gentle undulation on top), then rises with one side profile per map (steepening
     smoothly). Playable lowland corridors follow every river.
     Trunk rivers reaching the sea end in an estuary: a trumpet of water where the valley axis sinks below sea
     level (drowned river mouth).
  6. Sea. Depth grows with distance from the coast (gentle shelf by map type), so harbours have shallow
     approaches.
  7. Shores. A band of 2 cells either side of every shore is smoothed, so coasts and lake shores are curves,
     not the coarse cell staircase.

  8. Passes (map types with corridors, passes.lua): each pass axis gets a floor graded for railways, and the
     hillsides rise from it like from any valley, so the pass is two valleys meeting at a broad col.

OUTPUT: { h = coarse heights, kind = {0 land, 1 sea, 2 lake, 3 estuary}, lakes = list, corridors = pass profiles,
          rough = detail factor per node 0..1 (hill country and steep ground; 0 on pass floors), sLimit = slope limit }
]]

local grid = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/grid.lua"
local hydrology = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/hydrology.lua"
local noise = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/noise.lua"
local passes = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/passes.lua"

local M = {}

local sqrt, floor, max, min, exp, log = math.sqrt, math.floor, math.max, math.min, math.exp, math.log

-- Per Relief setting (1 Gentle, 2 Moderate, 3 Hilly, 4 Rugged, 5 Mountainous; pipeline.RELIEF). Run 6: Flat was
-- dropped (the owner: too uninteresting, Gentle is easy enough) and two steps added; Gentle, Hilly and Mountainous
-- keep their values, Moderate and Rugged lie halfway (CHANNEL_AREA geometrically).
-- metres above the floodplains (99th percentile of the land, before the hill country). Run 5: Mountainous 750 m
-- (x 1.8 on Mountain Range = 1.4 km peaks) read as far too big for the game; vanilla peaks reach ~470 m.
M.RELIEF_P99 = { 140, 210, 280, 350, 420 }
M.SLOPE_LIMIT = { 0.25, 0.375, 0.50, 0.675, 0.85 } -- steepest slope between neighbouring nodes (m/m)
M.SIDE_SLOPE = { 0.022, 0.0335, 0.045, 0.0625, 0.08 } -- valley sides next to the floodplain (m/m)
M.M_EXP = 0.45
-- m^2 drained where a (dry) valley starts: few broad valleys on gentle land, many small ones in mountains
M.CHANNEL_AREA = { 0.5e6, 0.32e6, 0.2e6, 0.13e6, 0.08e6 }
M.HILL = 2.0            -- hillslopes are this many times steeper than a channel head
-- Hillslope profile exponent p per Relief: height ~ distance^p from the channel, so p < 1 is steep near the valley
-- and flattens towards broad, buildable tops (gentle country); 1 = straight slopes. Scaled by preset.uplands.
-- Measured (11 km, Gentle, seeds 1-3): Great River Valley flat land 29 % at p = 1, 36-41 % at 0.5.
M.HILL_SHAPE = { 0.5, 0.6, 0.7, 0.775, 0.85 }
M.HILL_D0 = 250         -- metres: distance at which the curved profile meets the straight one
M.LAKE_MAX_AREA = 1.8e6 -- m^2: larger pits keep only their deepest part as lake
M.BEACH = 1.0       -- land next to the sea starts here
M.LAND_MIN = 0.6    -- no land node below this (no puddles)
M.FP_LAKE = 1.5     -- level of the flat ring around a lake
M.ESTUARY_DEPTH = 2.5 -- metres below sea level of the drowned valley floor at the river mouth (meets the shelf)
M.SIDE_ZONE = 700     -- metres: width of the valley-side zone (times the map type's valley factor)
-- metres above the floodplain of valley-side benches (older floodplains), e.g. { 0, 4, 10, 18 }. Empty since run 5:
-- the same benches around every lake and stream read as ripple rings, not as landform history.
M.TERRACES = {}
M.LAKE_MIN_AREA = 0.12e6 -- m^2
M.LAKE_SEA_GAP = 400     -- m: lakes keep this far from the sea (else they merge with the river mouth)
M.LAKES_PER_WATER = { 1, 3, 5 } -- Dry, Normal, Wet (times the map type's factor)
M.LAND_SLOPE = { 0.05, 0.075, 0.1, 0.14, 0.18 } -- relief cap per Relief: mean slope from the coast inland (small land)
M.LIFT = 0.7       -- raised ground (plateaus) at lift 1, as a share of the Relief target height
M.PASS_FLOOR = 140 -- metres: flat floor of a pass corridor (room for a road and a double track)
M.PASS_CALM = 120  -- metres beyond the pass floor over which the fine detail returns
-- Hill country ("game scale", run 5): the drainage model alone gives smooth slopes kilometres long, which read as
-- "real-life true" but empty at the game's scale. Vanilla Temperate gets its look from a patchwork of flat plains
-- and hill country with 500 m noise in the hills (vanilla_temperate_heightmap.md 2.3-2.5). We add the same idea on
-- top of the drainage landform, before the valleys are cut (so floodplains stay flat and valley sides cut the hills):
-- patches of hill country (PATCH_WL), covering HILL_COVER of the land, filled with hills of about HILL_WL.
M.HILL_COVER = { 0.5, 0.55, 0.6, 0.6, 0.6 } -- share of the land that is hill country, per Relief
M.HILL_AMP = { 85, 100, 115, 122.5, 130 } -- metres: hill height in the hill country, per Relief (times preset.hills)
M.HILL_WL = 800                         -- metres: hill size (largest wavelength of the hill noise)
M.PATCH_WL = 3500                       -- metres: size of the hill-country patches
M.PATCH_EDGE = 0.08                     -- width of the patch edge in noise units (soft but distinct borders)
M.HILL_BLOCK = 0.45                     -- share of the hill height that raises the whole patch (upland block)

local function smoothstep(a, b, x)
	local t = (x - a) / (b - a)
	if t <= 0 then return 0 elseif t >= 1 then return 1 end
	return t * t * (3 - 2 * t)
end

local function terrace(r)
	local L = M.TERRACES
	if #L < 2 or r <= 0 or r >= L[#L] then return r end
	for i = 1, #L - 1 do
		local a, b = L[i], L[i + 1]
		if r < b then
			local t = (r - a) / (b - a)
			return a + (b - a) * t * t * t -- flat bench after a, steep riser before b
		end
	end
	return r
end

--[[ Valley profile at e metres beyond the floodplain edge: flat floodplain, side zone of width z whose slope
  steepens smoothly from ss to the limit slope (terraces at +4 and +10 m: older floodplains), then the limit
  slope, so the lowering never ends in a step. The profile is the same for every valley of a map: only the
  floodplain width (inside e) differs between rivers, so where two valleys meet the surface stays continuous. ]]
local function valleyTarget(e, fp, z, ss, sLimit)
	if e <= 0 then return fp end
	-- no side zone (Valley width 0 %): the limit slope starts at the floodplain edge. Without this, k = 1/0 and
	-- k * e * e with e >= z gave NaN, which silently skipped every valley side (offline settings test, 2026-10-08)
	if z <= 0 then return fp + sLimit * e end
	local k = (sLimit - ss) / (2 * z)
	if e < z then
		return fp + terrace(ss * e + k * e * e)
	end
	return fp + terrace(ss * z + k * z * z) + sLimit * (e - z)
end

function M.build(shape, hydro, paths, fpNode, g, settings, ctx)
	local w, h, cell = g.w, g.h, g.cell
	local n = w * h
	local f, water, A = hydro.f, hydro.water, hydro.A
	local U, sea = shape.U, shape.sea
	local relief = settings.relief
	local preset = shape.preset
	local mExp = M.M_EXP

	-- 1a. channels: stream-power profile along the drainage tree wherever A >= CHANNEL_AREA. Every channel node
	--     (and every land node on the coast) becomes a seed for the hillslopes.
	local raw, base, channel = {}, {}, {}
	for k = 1, n do raw[k], base[k], channel[k] = 0, M.BEACH, false end
	local seeds = { n = 0, x = {}, y = {}, off = {}, node = {}, sh = {}, raw = {}, base = {} }
	local aChannel = M.CHANNEL_AREA[relief] * (preset.channels or 1)
	local headSlope = exp(-mExp * log(aChannel / 1e4)) -- U-free slope of a channel head (A in hectares)
	local function seedAt(k, rv, b)
		local sh = M.HILL * U[k] * headSlope
		local id = seeds.n + 1
		seeds.n = id
		seeds.x[id], seeds.y[id], seeds.node[id] = ((k - 1) % w) * cell, floor((k - 1) / w) * cell, k
		seeds.sh[id], seeds.raw[id], seeds.base[id], seeds.off[id] = sh, rv, b, -rv / sh
	end
	local order, recv = f.order, f.recv
	for idx = 1, #order do
		local c = order[idx]
		if A[c] >= aChannel or water[c] then
			local r = recv[c]
			channel[c] = true
			if water[c] then
				raw[c], base[c] = 0, fpNode[c] or M.BEACH
			else
				local slope = U[c] * exp(-mExp * log(A[c] / 1e4))
				local step = hydrology.stepLength(f, g, c)
				if r > 0 then
					raw[c], base[c] = raw[r] + slope * step, base[r]
				else
					raw[c], base[c] = slope * step, M.BEACH
				end
			end
			seedAt(c, raw[c], base[c])
		end
	end
	for j = 0, h - 1 do
		if ctx then ctx.tick() end
		for i = 0, w - 1 do
			local k = j * w + i + 1
			if not sea[k] and not channel[k] and ((i > 0 and sea[k - 1]) or (i < w - 1 and sea[k + 1])
					or (j > 0 and sea[k - w]) or (j < h - 1 and sea[k + w])) then
				seedAt(k, 0, M.BEACH)
			end
		end
	end
	if ctx then ctx.tick() end

	-- 1b. hillslopes: the lower envelope of straight slopes rising from the nearest channel or coast. Ridges form
	--     where two slopes meet; hillsides are smooth (heights built per node from tiny drainage areas would
	--     show the 8 flow directions as streaks).
	local best, cost = grid.nearestSeed(w, h, cell, seeds, nil, ctx)
	local hillShape = 1 - (1 - M.HILL_SHAPE[relief]) * (preset.uplands or 1)
	for k = 1, n do
		if ctx and k % 8192 == 0 then ctx.tick() end
		if not sea[k] and not channel[k] then
			local sId = best[k]
			if sId > 0 then
				-- steepness from the node's own uplift (smooth field), so slopes do not jump where the nearest
				-- channel changes
				local dist = cost[k] + seeds.off[sId]
				if hillShape ~= 1 and dist > 0 then dist = M.HILL_D0 * exp(hillShape * log(dist / M.HILL_D0)) end
				raw[k], base[k] = seeds.raw[sId] + M.HILL * U[k] * headSlope * dist, seeds.base[sId]
			end
		end
	end
	if ctx then ctx.tick() end

	-- 2. relief scaling
	local tune = settings.tune or {}
	local target = M.RELIEF_P99[relief] * preset.relief * (tune.height or 1)
	-- small land (islands, narrow peninsulas) cannot carry the full relief: the target is capped at a mean slope
	-- from the coast to the most inland ground (99th percentile of the distance to the sea)
	if shape.coastDist then
		local cd = shape.coastDist
		local reach = grid.percentile(cd, w, h, 0.99, function(k) return not sea[k] and cd[k] < math.huge end)
		target = min(target, M.LAND_SLOPE[relief] * reach)
	end
	local p99 = grid.percentile(raw, w, h, 0.99, function(k) return not sea[k] and not water[k] end)
	local s = target / max(p99, 1e-9)
	local H = {}
	for k = 1, n do
		if ctx and k % 8192 == 0 then ctx.tick() end
		if sea[k] then H[k] = 0 else H[k] = base[k] + s * raw[k] end
	end

	-- 2b. raised ground (plateaus, shapes.lua lift): added as a block, scaled to the Relief target. Rivers are not
	--     raised (all water is at 0 m), so the slope limit below cuts gorges down to them through the raised land.
	if shape.lift then
		local amp = M.LIFT * target * (preset.lift or 1)
		for k, l in pairs(shape.lift) do
			if not sea[k] and not water[k] then H[k] = H[k] + amp * l end
		end
	end

	-- 3. slope limit (lowers only; water and sea nodes are fixed)
	local sLimit = min(1.0, M.SLOPE_LIMIT[relief] * (preset.relief > 1 and 1.15 or 1))
	local dO, dD = sLimit * cell, sLimit * cell * 1.41421356
	local function slopeLimit(sweeps)
		for _ = 1, sweeps do
			for j = 0, h - 1 do
				if ctx then ctx.tick() end
				for i = 0, w - 1 do
					local k = j * w + i + 1
					if not sea[k] and not water[k] then
						local v = H[k]
						if i > 0 then v = min(v, H[k - 1] + dO) end
						if j > 0 then
							v = min(v, H[k - w] + dO)
							if i > 0 then v = min(v, H[k - w - 1] + dD) end
							if i < w - 1 then v = min(v, H[k - w + 1] + dD) end
						end
						H[k] = v
					end
				end
			end
			for j = h - 1, 0, -1 do
				if ctx then ctx.tick() end
				for i = w - 1, 0, -1 do
					local k = j * w + i + 1
					if not sea[k] and not water[k] then
						local v = H[k]
						if i < w - 1 then v = min(v, H[k + 1] + dO) end
						if j < h - 1 then
							v = min(v, H[k + w] + dO)
							if i < w - 1 then v = min(v, H[k + w + 1] + dD) end
							if i > 0 then v = min(v, H[k + w - 1] + dD) end
						end
						H[k] = v
					end
				end
			end
			if ctx then ctx.tick() end
		end
	end
	slopeLimit(2)
	-- round the ridges and the creases between neighbouring channel points (sea and river nodes stay put)
	for _ = 1, 2 do
		grid.blur(H, w, h, 2, function(k) return sea[k] or water[k] end, ctx)
	end
	if ctx then ctx.tick() end

	-- 3b. hill country, after the rounding blur (which would erase hills of a few hundred metres) and with its own
	--     slope limit: patches (a share HILL_COVER of the land, chosen by a slow noise and its percentile, so the
	--     share holds on every seed) with soft but distinct edges, filled with hills of about HILL_WL. The hills are
	--     scaled down with the relief cap of small land (islands). rough = where detail.lua puts rock texture: the
	--     hill country, plus steep ground (filled in after the slope limit).
	local rough = {}
	do
		local amp = M.HILL_AMP[relief] * (preset.hills or 1) * (tune.hillHeight or 1) * target
			/ (M.RELIEF_P99[relief] * preset.relief)
		local pn = noise.perlin(noise.derive(settings.seed, "hillpatch"))
		local hn = noise.perlin(noise.derive(settings.seed, "hills"))
		local patch = {}
		for k = 1, n do
			if ctx and k % 2048 == 0 then ctx.tick() end
			local x, y = ((k - 1) % w) * cell, floor((k - 1) / w) * cell
			patch[k] = noise.fbm(pn, x / M.PATCH_WL, y / M.PATCH_WL, 3, 0.5)
		end
		local cover = M.HILL_COVER[relief] * (preset.hillCover or 1) * (tune.hills or 1)
		local thr = grid.percentile(patch, w, h, max(0, min(1, 1 - cover)), function(k) return not sea[k] end)
		for k = 1, n do
			if ctx and k % 2048 == 0 then ctx.tick() end
			rough[k] = 0
			if not sea[k] and not water[k] then
				local m = cover > 0.001 and smoothstep(thr - M.PATCH_EDGE, thr + M.PATCH_EDGE, patch[k]) or 0
				if m > 0 then
					local x, y = ((k - 1) % w) * cell, floor((k - 1) / w) * cell
					-- 4 octaves: the finest (HILL_WL / 8) still spans 2+ coarse cells; finer texture is detail.lua's job
					local hv = noise.fbm(hn, x / M.HILL_WL, y / M.HILL_WL, 4, 0.5)
					-- a raised block (the patch edge is the hillside) with hills on top: coherent hill country rising
					-- from the plains, as in vanilla, not lumpy noise
					H[k] = H[k] + amp * m * (M.HILL_BLOCK + (1 - M.HILL_BLOCK) * max(0, min(1, 0.5 + 1.1 * hv)))
					rough[k] = m
				end
			end
		end
	end
	slopeLimit(1)

	-- 4. lakes on the river network
	local kind = {}
	for k = 1, n do kind[k] = sea[k] and 1 or 0 end
	local want = floor(M.LAKES_PER_WATER[settings.water] * preset.lakes * (tune.lakes or 1) + 0.5)
	-- no lakes on ship rivers: the wide channel runs straight through and the lake reads as a blob on the river
	-- (run 5, Delta Lowlands); lakes sit on the smaller rivers
	local nearShip = {}
	for _, p in ipairs(paths) do
		if p.ship then
			local stride = max(1, floor(cell / 8))
			for q = 1, #p.x, stride do
				if p.ship[q] then
					local i0, j0 = floor(p.x[q] / cell + 0.5), floor(p.y[q] / cell + 0.5)
					for jj = max(0, j0 - 3), min(h - 1, j0 + 3) do
						for ii = max(0, i0 - 3), min(w - 1, i0 + 3) do nearShip[jj * w + ii + 1] = true end
					end
				end
			end
		end
	end
	local cands = {}
	for _, d in ipairs(hydro.depressions) do
		if d.area >= M.LAKE_MIN_AREA then
			local onRiver = d.spill > 0 and water[d.spill]
			if not onRiver then
				for _, k in ipairs(d.nodes) do
					if water[k] then onRiver = true break end
				end
			end
			-- a pit next to the coast would merge with the river mouth or the sea into one shapeless water body
			if onRiver then
				local rc = math.ceil(M.LAKE_SEA_GAP / cell)
				for _, k in ipairs(d.nodes) do
					local i, j = (k - 1) % w, floor((k - 1) / w)
					for jj = max(0, j - rc), min(h - 1, j + rc), 2 do
						for ii = max(0, i - rc), min(w - 1, i + rc), 2 do
							if sea[jj * w + ii + 1] then onRiver = false break end
						end
						if not onRiver then break end
					end
					if not onRiver then break end
				end
			end
			if onRiver then
				for _, k in ipairs(d.nodes) do
					if nearShip[k] then onRiver = false break end
				end
			end
			if onRiver then cands[#cands + 1] = d end
		end
	end
	table.sort(cands, function(a, b) return a.area > b.area end)
	local lakes = {}
	local filled, B = f.filled, shape.B
	for idx = 1, min(want, #cands) do
		local d = cands[idx]
		-- keep the deepest part of a large pit: a lake, not a flooded plain
		local maxNodes = floor(M.LAKE_MAX_AREA / (cell * cell))
		if #d.nodes > maxNodes then
			local byDepth = {}
			for q, k in ipairs(d.nodes) do byDepth[q] = k end
			table.sort(byDepth, function(a, b) return filled[a] - B[a] > filled[b] - B[b] end)
			local thr = filled[byDepth[maxNodes]] - B[byDepth[maxNodes]]
			local core = {}
			for _, k in ipairs(d.nodes) do
				if filled[k] - B[k] >= thr then core[#core + 1] = k end
			end
			d = { nodes = core, area = #core * cell * cell }
		end
		-- drop fragments smaller than a lake (they would read as puddles)
		local inLake = {}
		do
			local member, piece = {}, {}
			for _, k in ipairs(d.nodes) do member[k] = true end
			local kept = {}
			local minNodes = M.LAKE_MIN_AREA / (cell * cell)
			for _, start in ipairs(d.nodes) do
				if piece[start] == nil then
					local comp, stack = {}, { start }
					piece[start] = true
					while #stack > 0 do
						local c = stack[#stack]
						stack[#stack] = nil
						comp[#comp + 1] = c
						for _, nb in ipairs({ c - 1, c + 1, c - w, c + w }) do
							if member[nb] and piece[nb] == nil then
								piece[nb] = true
								stack[#stack + 1] = nb
							end
						end
					end
					if #comp >= minNodes then
						for _, c in ipairs(comp) do kept[#kept + 1] = c end
					end
				end
			end
			d = { nodes = kept, area = #kept * cell * cell }
		end
		for _, k in ipairs(d.nodes) do inLake[k] = true end
		-- depth from the distance to the shore (breadth-first, in cells)
		local dist, queue = {}, {}
		for _, k in ipairs(d.nodes) do
			local i, j = (k - 1) % w, floor((k - 1) / w)
			local edge = i == 0 or j == 0 or i == w - 1 or j == h - 1
			if not edge then
				for _, nb in ipairs({ k - 1, k + 1, k - w, k + w }) do
					if not inLake[nb] then edge = true break end
				end
			end
			if edge then dist[k] = 1; queue[#queue + 1] = k end
		end
		local qi = 1
		while qi <= #queue do
			local k = queue[qi]
			qi = qi + 1
			for _, nb in ipairs({ k - 1, k + 1, k - w, k + w }) do
				if inLake[nb] and dist[nb] == nil then
					dist[nb] = dist[k] + 1
					queue[#queue + 1] = nb
				end
			end
		end
		local maxDepth = 0
		for _, k in ipairs(d.nodes) do
			local depth = min(14, 0.8 + 0.045 * (dist[k] or 1) * cell)
			H[k] = -depth
			kind[k] = 2
			maxDepth = max(maxDepth, depth)
		end
		if #d.nodes > 0 then lakes[#lakes + 1] = { nodes = d.nodes, area = d.area, depth = maxDepth } end
	end

	-- 5. valleys around the final courses and the lakes
	local function newSeeds() return { n = 0, x = {}, y = {}, off = {}, node = {}, fp = {} } end
	local seeds, estSeeds = newSeeds(), newSeeds()
	estSeeds.half = {}
	local ss = M.SIDE_SLOPE[relief]
	local function addTo(t, x, y, off, fp)
		local i = floor(x / cell + 0.5)
		local j = floor(y / cell + 0.5)
		if i < 0 or j < 0 or i >= w or j >= h then return end
		local s_ = t.n + 1
		t.n = s_
		t.x[s_], t.y[s_], t.off[s_], t.node[s_], t.fp[s_] = x, y, off, j * w + i + 1, fp
	end
	local function addSeed(x, y, off, fp) addTo(seeds, x, y, off, fp) end
	-- slow noise varies the floodplain and side-zone widths along the rivers, so valley edges are not regular
	local vary = noise.perlin(noise.derive(settings.seed, "valleys"))
	local every = max(1, floor(cell * 0.5 / 8))
	local vw = (preset.valley or 1) * (tune.valley or 1) -- map type (and setting): how broad river valleys are
	for _, p in ipairs(paths) do
		-- the valley floor follows the river's centreline, wide enough for its whole meander belt (valley walls
		-- do not follow every bend)...
		local c = p.centre
		local function floodHalf(x, y, wd)
			return (p.belt + wd * 0.5 + 40 + vw * 1.5 * wd) * (1 + 0.25 * vary(x / 1500, y / 1500))
		end
		for i = 1, #c.x, every do
			local x, y = c.x[i], c.y[i]
			addSeed(x, y, floodHalf(x, y, c.w[i]), c.fp[i])
		end
		-- estuary: over its last estL metres the trunk sinks below sea level (a drowned river mouth). The water
		-- widens towards the sea like a trumpet around the river's own course (which has stopped meandering
		-- there), with ragged banks. Seeds carry their width and level; the pass below uses plain distance to the
		-- course, so the banks are smooth curves.
		local estL = (p.kind == "trunk" and p.mouth == "sea") and (preset.estuary or 0) or 0
		if estL > 0 then
			local s = 0
			for i = 1, #p.x do
				if i > 1 then
					local dx, dy = p.x[i] - p.x[i - 1], p.y[i] - p.y[i - 1]
					s = s + sqrt(dx * dx + dy * dy)
				end
				if s >= estL then break end
				local wd, x, y = p.w[i], p.x[i], p.y[i]
				local t = 1 - s / estL
				local half = wd * 0.5 + 0.45 * floodHalf(x, y, wd) * t * t * (1 + 0.35 * vary(x / 400 + 20, y / 400))
				addTo(estSeeds, x, y, 0, p.fp[i] - (p.fp[i] + M.ESTUARY_DEPTH) * t)
				estSeeds.half[estSeeds.n] = half
			end
		end
		-- ...and the channel itself always lies on flat ground
		for i = 1, #p.x, every do
			local wd = p.w[i]
			addSeed(p.x[i], p.y[i], wd * 0.5 + 30, p.fp[i])
		end
	end
	for _, l in ipairs(lakes) do
		for _, k in ipairs(l.nodes) do
			local x, y = ((k - 1) % w) * cell, floor((k - 1) / w) * cell
			addSeed(x, y, 40 + 60 * (1 + vary(x / 1200, y / 1200 + 80)), M.FP_LAKE)
		end
	end
	if seeds.n > 0 then
		local zone = M.SIDE_ZONE * vw
		local best, cost = grid.nearestSeed(w, h, cell, seeds, nil, ctx)
		for k = 1, n do
			if ctx and k % 8192 == 0 then ctx.tick() end
			local sId = best[k]
			if sId > 0 and kind[k] == 0 then
				local t = valleyTarget(cost[k], seeds.fp[sId], zone, ss, sLimit)
				if t > 0 then
					-- floodplains are not machine-flat: old channels and levees, 0 .. +0.7 m (never lower)
					local x, y = ((k - 1) % w) * cell, floor((k - 1) / w) * cell
					t = t + 0.35 * (1 + vary(x / 350 + 7, y / 350 - 3))
				end
				if t < H[k] then
					H[k] = t
					if t < 0 then kind[k] = 3 end -- estuary water
				end
			end
		end
	end
	-- estuaries: their own pass (the nearest-valley choice above picks the widest floodplain, not the lowest
	-- target); the water only lowers the land
	if estSeeds.n > 0 then
		local maxHalf = 0
		for q = 1, estSeeds.n do maxHalf = max(maxHalf, estSeeds.half[q]) end
		local hMax = 0
		for k = 1, n do if H[k] > hMax then hMax = H[k] end end
		local zone = M.SIDE_ZONE * vw
		-- reach: where the side profile has climbed above any land, so the lowering never ends in a step (run 5:
		-- a fixed 600 m left dark cliffs beside river mouths)
		local best, cost = grid.nearestSeed(w, h, cell, estSeeds, maxHalf + zone + hMax / sLimit, ctx)
		for k = 1, n do
			if ctx and k % 8192 == 0 then ctx.tick() end
			local sId = best[k]
			if sId > 0 and kind[k] == 0 then
				local e = cost[k] - estSeeds.half[sId]
				local t = valleyTarget(e, estSeeds.fp[sId], zone, ss, sLimit)
				if t < H[k] then
					H[k] = t
					if t < 0 then kind[k] = 3 end
				end
			end
		end
	end
	if ctx then ctx.tick() end

	-- 5b. passes (map types with corridors): each pass axis gets a floor graded to passes.TARGET (passes.lua) and
	--     the hillsides rise from it like from any valley (beyond a flat floor of PASS_FLOOR m), lowering the land
	--     only where that gives a lower surface. It comes after the river valleys, so the floor also descends
	--     gently into the valleys it crosses, and after the smoothing, which would lift the floor. The relief scale
	--     s is the one measured in step 2, so the grade holds in metres.
	local corridors = passes.build(H, g, shape.corridors, relief, M.BEACH)
	local calm -- pass-floor factor per node (0 on the floor, 1 away from it), only where passes exist
	if #corridors > 0 then
		-- seeds on the axis; each node takes the floor height of its nearest axis point (plain distance, as for the
		-- river valleys: the distance propagation is exact for that; the floor rises so slowly that the nearest
		-- point is also the lowest surface). The floor width varies slowly along the pass.
		local ps = { n = 0, x = {}, y = {}, off = {}, node = {}, raw = {} }
		for _, c in ipairs(corridors) do
			for q = 1, #c.x do
				local i, j = floor(c.x[q] / cell + 0.5), floor(c.y[q] / cell + 0.5)
				if i >= 0 and j >= 0 and i < w and j < h then
					local id = ps.n + 1
					ps.n = id
					ps.x[id], ps.y[id], ps.node[id] = c.x[q], c.y[q], j * w + i + 1
					ps.raw[id] = max(0, (c.z[q] - M.BEACH) / s)
					ps.off[id] = M.PASS_FLOOR * 0.5 * (1 + 0.35 * vary(c.x[q] / 900 + 40, c.y[q] / 900))
				end
			end
		end
		local pBest, pCost = grid.nearestSeed(w, h, cell, ps, nil, ctx)
		local lowered = {}
		calm = {}
		for k = 1, n do
			if ctx and k % 8192 == 0 then ctx.tick() end
			calm[k] = 1
			local sId = pBest[k]
			if sId > 0 and kind[k] == 0 and not water[k] then
				local beyond = max(0, pCost[k])
				local dist = beyond
				if hillShape ~= 1 and dist > 0 then dist = M.HILL_D0 * exp(hillShape * log(dist / M.HILL_D0)) end
				local t = M.BEACH + s * (ps.raw[sId] + M.HILL * U[k] * headSlope * dist)
				-- the floor stays smooth for tracks and stations; rock detail returns on the slopes
				local c = min(1, beyond / M.PASS_CALM)
				calm[k] = c * c * (3 - 2 * c)
				if t < H[k] then
					H[k] = t
					if c >= 0.3 then lowered[k] = true end
				end
			end
		end
		-- round the creases where the pass slopes meet the land around them (the floor stays as graded)
		grid.blur(H, w, h, 1, function(k) return not lowered[k] end, ctx)
		if ctx then ctx.tick() end
	end

	-- 6. sea shelf: depth grows with distance from the coast
	local coast = { n = 0, x = {}, y = {}, off = {}, node = {} }
	for j = 0, h - 1 do
		if ctx then ctx.tick() end
		for i = 0, w - 1 do
			local k = j * w + i + 1
			if kind[k] ~= 1 then
				local nearSea = (i > 0 and sea[k - 1]) or (i < w - 1 and sea[k + 1]) or (j > 0 and sea[k - w])
					or (j < h - 1 and sea[k + w])
				if nearSea then
					local c = coast.n + 1
					coast.n = c
					coast.x[c], coast.y[c], coast.off[c], coast.node[c] = i * cell, j * cell, 0, k
				end
			end
		end
	end
	local shelf = preset.shelf
	if coast.n > 0 then
		local _, dist = grid.nearestSeed(w, h, cell, coast, nil, ctx)
		for k = 1, n do
			if ctx and k % 8192 == 0 then ctx.tick() end
			if kind[k] == 1 then
				local d = dist[k] < math.huge and dist[k] or 1e5
				H[k] = -min(shelf.max, 1.0 + shelf.slope * d)
			end
		end
	else
		for k = 1, n do
			if ctx and k % 8192 == 0 then ctx.tick() end
			if kind[k] == 1 then H[k] = -shelf.max end
		end
	end

	-- 7. shores: lake and sea outlines are made of coarse cells; smoothing a band of 2 cells either side of every
	--    shore turns the staircase into natural curves
	local zone = {}
	for j = 0, h - 1 do
		if ctx then ctx.tick() end
		for i = 0, w - 1 do
			local k = j * w + i + 1
			-- shores, and seams where two water bodies of different depth meet (lake / estuary / sea)
			local kk = kind[k]
			if (i > 0 and kind[k - 1] ~= kk) or (i < w - 1 and kind[k + 1] ~= kk)
					or (j > 0 and kind[k - w] ~= kk) or (j < h - 1 and kind[k + w] ~= kk) then
				zone[k] = true
			end
		end
	end
	for _ = 1, 2 do
		local grow = {}
		for k in pairs(zone) do
			local i, j = (k - 1) % w, floor((k - 1) / w)
			for dj = -1, 1 do
				for di = -1, 1 do
					local ii, jj = i + di, j + dj
					if ii >= 0 and jj >= 0 and ii < w and jj < h then grow[jj * w + ii + 1] = true end
				end
			end
		end
		zone = grow
	end
	for _ = 1, 2 do
		grid.blur(H, w, h, 1, function(k) return not zone[k] end, ctx)
	end
	if ctx then ctx.tick() end

	-- intent: away from the shores, land stays above the puddle line and water below it
	for k = 1, n do
		if ctx and k % 8192 == 0 then ctx.tick() end
		if not zone[k] then
			if kind[k] == 0 then
				if H[k] < M.LAND_MIN then H[k] = M.LAND_MIN end
			elseif H[k] > -0.5 then
				H[k] = -0.5
			end
		end
	end
	-- roughness for detail.lua: hill country, steep ground (valley sides, mountains), never on pass floors
	for j = 0, h - 1 do
		if ctx then ctx.tick() end
		for i = 0, w - 1 do
			local k = j * w + i + 1
			if kind[k] == 0 then
				local gx = (H[k + (i < w - 1 and 1 or 0)] - H[k - (i > 0 and 1 or 0)]) / cell
				local gy = (H[k + (j < h - 1 and w or 0)] - H[k - (j > 0 and w or 0)]) / cell
				local sl = sqrt(gx * gx + gy * gy) * 0.5
				local r = max(rough[k], smoothstep(0.04, 0.2, sl))
				if calm then r = r * calm[k] end
				rough[k] = r
			else
				rough[k] = 0
			end
		end
	end
	return { h = H, kind = kind, lakes = lakes, corridors = corridors, rough = rough, sLimit = sLimit, reliefScale = s,
		lakesWanted = want }
end

return M

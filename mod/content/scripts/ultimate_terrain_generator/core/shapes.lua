--[[
shapes.lua - map types: the large-scale layout of a map before any river exists (pure Lua 5.2).

WHAT A MAP TYPE PROVIDES (on the coarse grid)
  sea the type's coastline (each eval returns B, U and whether the point is sea).
  B   "organisation" field on land: only its ORDER matters. Drainage follows B downhill (hydrology.flood), so B
      decides where valleys, divides and the trunk river run, and its pits are the lake sites. Its values never
      become heights directly.
  U   uplift (> 0): how fast the land rises away from the rivers. Heights come from the stream-power profile
      slope = U * A^-m along the channels and from hillslopes rising from them (landform.lua), so high U makes
      mountains and low U plains.
  outlets  edge nodes where rivers may leave the map (besides the sea).
  inflows  edge nodes where a river enters the map, with the catchment area it already drains (m^2).
  corridors  crossings the type promises (mountain passes): the valley axis of each, a polyline from the foot
           on one side to the foot on the other; landform.lua grades it (passes.lua) and builds the valley.
  preset   per-type numbers used later (relief factor, default ship rivers, shelf, lake and river density, delta;
           uplands 1 = hillsides flatten towards broad tops (landform.HILL_SHAPE), 0 = straight slopes to sharp
           ridges, as in mountains, whose flat land is in the valleys; uplands > 0 also lets the middle Relief steps
           lower the plains between the hill-country patches, landform.PLAINS_RELIEF; flatKeep (default 1) scales
           the middle steps' plains factor and height curve, landform.RELIEF_BEND, for this type).

HOW TYPES ARE WRITTEN
  Each type works in a canonical frame: X across (0 .. cw), Y from the sea or the "south" side (0 .. ch),
  in metres. The pipeline picks one of 8 orientations from the seed (rotate/mirror), so the sea is not always
  at the same edge. Values only depend on (X, Y), the seed and the settings.

FIRST THREE TYPES
  great_river_valley   one big river crosses the map in a broad lowland valley between uplands, entering at
                       the far edge and reaching the sea through an estuary (drowned valley, landform.lua); with
                       Sea None (2026-10-12) there is no sea: the valley goes on to that edge and the river leaves
                       the map there
  delta_lowlands       wide coastal lowland; a big river splits into several channels over a land lobe that
                       bulges into a shallow sea; lakes and lagoons; low hills only far inland
  mountain_passes      a mountain belt across the map with two lower passes; foothills and valleys on both
                       sides; the sea along the south side, rivers leaving the map anywhere along the north side
MORE TYPES (added 2026-10-06, map editor)
  rolling_plains       inland plain, no sea; a big river crosses the map edge to edge (a ship river by default)
  lake_district        ice-scoured hills; long narrow lakes on the rivers (basins stretched along the ice flow)
  large_bays           a coast cut by two or three deep bays (sheltered harbours); rivers end at the bay heads
  (2026-10-06/08: peninsulas, island_chain, coastal_region, highland_plateau; 2026-10-11: alpine, distinct snow-capped
  massifs over hill country, a loose chain of them forming the main divide with two graded passes; 2026-10-12:
  sea_strait, a sea strait from edge to edge with sounds and narrows, in a direction the player picks)
Each type also has a display label (Studio window).
]]

local noise = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/noise.lua"
local grid = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/grid.lua"

local M = {}

local exp, abs, sin, pi, floor, max, min = math.exp, math.abs, math.sin, math.pi, math.floor, math.max, math.min

local function smoothstep(a, b, x)
	local t = (x - a) / (b - a)
	if t <= 0 then return 0 elseif t >= 1 then return 1 end
	return t * t * (3 - 2 * t)
end

-- 1D noise memoised per metre: coastlines and valley axes depend on one coordinate only.
local function curve(f, wavelength, octaves)
	local cache = {}
	return function(t)
		local key = floor(t)
		local v = cache[key]
		if v == nil then
			v = noise.fbm(f, t / wavelength, 0.5, octaves, 0.5)
			cache[key] = v
		end
		return v
	end
end

-- Ragged coasts (run 5: "coasts too smooth"): every coastline gets the same fractal edge, 6 octaves from 1.2 km
-- down to ~40 m with a high gain (0.62), so coves, headlands and the odd islet show at the game's scale. Vanilla
-- does the same with a shore noise whose gain is above 1 (vanilla_temperate_heightmap.md 2.4). Metres of shift.
M.COAST_RAG = 900 -- (normalised fBm is mostly within +-0.3, so typical shifts are +-250 m)
local function rag(s, X, Y)
	-- (scale 0: Coast roughness 0 %, or a map without sea, where the coast is only a line the land keeps falling past)
	if s.ragScale == 0 then return 0 end
	return M.COAST_RAG * s.ragScale * noise.fbm(s.edge, X / 1200 + 50, Y / 1200, 6, 0.62)
end

M.TYPES = {}

M.TYPES.great_river_valley = {
	preset = { relief = 1.0, ships = 1, shelf = { slope = 0.012, max = 35 }, lakes = 1.0, rivers = 1.0, meander = 1.0,
		valley = 2.2, estuary = 2200, channels = 1.0, uplands = 1.0 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.ax = curve(noise.perlin(noise.derive(seed, "axis")), 4000, 3)
		s.cs = curve(noise.perlin(noise.derive(seed, "coast")), 2500, 4)
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.phase = r:range(0, 2 * pi)
		s.bend = r:range(0.08, 0.16)
		s.axisAt = function(Y)
			return cw * (0.5 + s.bend * sin(2 * pi * 0.8 * Y / ch + s.phase) + 0.07 * s.ax(Y))
		end
		-- trunk enters at the far edge with a catchment twice the map area: a big river from the first metre
		s.inflows = { { X = s.axisAt(ch), Y = ch, area = 2.0 * cw * ch } }
		s.outlets = {}
		return s
	end,
	eval = function(s, X, Y, cw, ch)
		local coast = ch * (0.065 + 0.045 * s.cs(X)) + rag(s, X, Y)
		-- without sea (Sea None, owner 2026-10-12, REVIEW B8) the sea's strip is more valley: B below keeps falling to
		-- the low edge (no term depends on the coast), where every node is an outlet and the trunk leaves the map
		if Y < coast and not s.noSea then return -10, 1, true end
		local dv = abs(X - s.axisAt(Y)) / cw
		local n = noise.fbm(s.n, X / 2600, Y / 2600, 5, 0.5)
		local B = 40 * Y / ch + 220 * smoothstep(0.02, 0.38, dv) + 70 * n
		local U = 0.25 + 1.1 * smoothstep(0.03, 0.40, dv) + 0.35 * (n + 0.5)
		return B, max(U, 0.08), false
	end,
}

M.TYPES.delta_lowlands = {
	preset = { relief = 0.35, hills = 0.25, ships = 2, shelf = { slope = 0.004, max = 14 }, lakes = 1.6, rivers = 0.7, meander = 1.2,
		valley = 1.4, estuary = 0, channels = 1.0, uplands = 1.0, delta = { channels = 3, reach = 0.24 } },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.ax = curve(noise.perlin(noise.derive(seed, "axis")), 3000, 3)
		s.cs = curve(noise.perlin(noise.derive(seed, "coast")), 1800, 4)
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.h = noise.perlin(noise.derive(seed, "hills"))
		s.mouthX = cw * r:range(0.4, 0.6)
		s.lobeW = cw * r:range(0.16, 0.24)
		s.axisAt = function(Y) return s.mouthX + cw * 0.06 * s.ax(Y) end
		s.inflows = { { X = s.axisAt(ch), Y = ch, area = 3.0 * cw * ch } }
		s.outlets = {}
		return s
	end,
	eval = function(s, X, Y, cw, ch)
		-- the delta lobe pushes the coast seaward around the mouth
		local lobe = exp(-((X - s.mouthX) / s.lobeW) ^ 2)
		local coast = ch * (0.30 + 0.03 * s.cs(X)) - 0.17 * ch * lobe + 0.5 * rag(s, X, Y)
		if Y < coast then return -10, 1, true end
		local dv = abs(X - s.axisAt(Y)) / cw
		local n = noise.fbm(s.n, X / 1800, Y / 1800, 5, 0.5)
		local hills = smoothstep(0.72, 1.0, Y / ch) * (0.6 + 0.4 * noise.fbm(s.h, X / 3000, Y / 3000, 3, 0.5))
		local B = 14 * Y / ch + 6 * smoothstep(0.0, 0.25, dv) + 9 * n + 160 * hills
		local U = 0.10 + 1.0 * hills + 0.06 * (n + 0.5)
		return B, max(U, 0.05), false
	end,
}

M.TYPES.mountain_passes = {
	preset = { relief = 1.5, ships = 0, shelf = { slope = 0.025, max = 60 }, lakes = 0.6, rivers = 0.8, meander = 0.8,
		valley = 0.8, estuary = 900, channels = 0.3, uplands = 0 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.rg = curve(noise.perlin(noise.derive(seed, "range")), 3500, 3)
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.cs = curve(noise.perlin(noise.derive(seed, "coast")), 2500, 4)
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.phase = r:range(0, 2 * pi)
		s.rangeAt = function(X)
			return ch * (0.56 + 0.07 * sin(2 * pi * 0.7 * X / cw + s.phase) + 0.05 * s.rg(X))
		end
		-- two passes: each a winding valley axis across the range (the notch in B follows it, so the drainage runs
		-- along it from the col down both sides), from the foot on the sea side to the foot on the far side
		s.passes = {}
		s.corridors = {}
		for idx, px in ipairs({ cw * r:range(0.22, 0.40), cw * r:range(0.60, 0.80) }) do
			local wig = curve(noise.perlin(noise.derive(seed, "pass" .. idx)), 2400, 3)
			local at = function(Y) return px + 0.05 * cw * wig(Y) end
			s.passes[idx] = at
			local yr = s.rangeAt(px)
			local coast = ch * (0.06 + 0.045 * s.cs(px))
			local Y0, Y1 = max(coast + 0.04 * ch, yr - 0.27 * ch), min(0.97 * ch, yr + 0.27 * ch)
			local line = {}
			for q = 0, 64 do
				local Y = Y0 + (Y1 - Y0) * q / 64
				line[#line + 1] = { X = at(Y), Y = Y }
			end
			s.corridors[idx] = line
		end
		s.inflows = {}
		-- rivers beyond the range leave the map wherever they reach the far edge (shapes.build makes every node of it an
		-- outlet), as on Alpine (owner 2026-10-13, run 9, REVIEW B9). Two outlet points made the rivers run along the
		-- edge to them. (The two draws they took were the last of setup, so the rest of the layout is unchanged.)
		s.outlets, s.farOutlets = {}, true
		return s
	end,
	eval = function(s, X, Y, cw, ch)
		local coast = ch * (0.06 + 0.045 * s.cs(X)) + rag(s, X, Y)
		-- without sea (Sea side None) the sea's strip is foreland that keeps falling towards the low edge (side < 0)
		if Y < coast and not s.noSea then return -10, 1, true end
		local yr = s.rangeAt(X)
		local db = abs(Y - yr) / ch
		local belt = 1 - smoothstep(0.0, 0.22, db)
		local notch = 0
		for _, at in ipairs(s.passes) do
			notch = max(notch, exp(-((X - at(Y)) / (0.05 * cw)) ^ 2))
		end
		local n = noise.fbm(s.n, X / 2200, Y / 2200, 5, 0.5)
		-- both sides fall away from the range: south to the sea, north to the north edge
		local side = Y < yr and 60 * (Y - coast) / max(yr - coast, 1) or 60 * (1 - (Y - yr) / max(ch - yr, 1))
		local B = 900 * belt * (1 - 0.7 * notch) + side + 90 * n
		local U = 0.25 + 1.6 * belt * (1 - 0.6 * notch) + 0.3 * (n + 0.5)
		return B, max(U, 0.08), false
	end,
}

-- Alpine massifs (setup helper): how many (by map area, about 11 on a 16 km map), how big (2-5 km across, smaller on
-- small maps), where (a share along the main divide, the rest scattered inland, never in the coastal strip), apart from
-- each other and off the pass axes: a massif that would reach a pass is shrunk to fit beside it, so every pass runs
-- through a gap between massifs. Its own random stream: setup's shared draws keep Mountain Range's order.
local function alpineMassifs(s, cw, ch, seed)
	local r = noise.rng(noise.derive(seed, "massifs"))
	local want = max(2, floor(cw * ch / 24e6 + 0.5))
	local chain = max(1, floor(want * 0.45 + 0.5))
	local cap = min(cw, ch) / 6
	-- clearance from a pass axis: 600 m, less on maps under 7.5 km across (a fixed 600 m left no room for any massif
	-- between and beside the passes on maps under ~3 km across: no peaks, no snow)
	local gap = min(600, 0.08 * cw)
	local list = {}
	for t = 1, 40 * want do
		if #list >= want then break end
		local onDivide = #list < chain and t <= 25 * chain
		local X = cw * r:range(0.03, 0.97)
		local Y = onDivide and s.rangeAt(X) + ch * r:range(-0.035, 0.035) or ch * r:range(0.3, 0.97)
		local a = min(cap, r:range(1000, 2200))
		local b = a * r:range(0.5, 0.85)
		-- chain massifs lie along the divide (it runs across, along X); the others at any angle
		local rot = onDivide and r:range(-0.4, 0.4) or r:range(0, pi)
		local k = r:range(0.75, 1.15)
		for _, at in ipairs(s.passes) do a = min(a, abs(X - at(Y)) - gap) end
		local ok = a >= 0.6 * min(cap, 1100)
		for _, m in ipairs(list) do
			if not ok then break end
			local dx, dy = X - m.X, Y - m.Y
			ok = dx * dx + dy * dy >= (0.85 * (a + m.a) + 500) ^ 2
		end
		if ok then
			b = min(b, a)
			list[#list + 1] = { X = X, Y = Y, a = a, b = b, c = math.cos(rot), sn = sin(rot), k = k, reach = 2.2 * a + 900 }
		end
	end
	return list
end

-- Smooth 2D warp (two fBm fields of `amp` metres per unit, wavelength wl) sampled on a lattice of `step` metres and
-- interpolated: the warp has no detail below a few hundred metres, and six noise calls per node doubled the shape stage.
local function latticeWarp(f, amp, wl, step)
	local cx, cy = {}, {}
	local function node(i, j)
		local key = j * 65536 + i
		local x = cx[key]
		if x == nil then
			x = amp * noise.fbm(f, i * step / wl, j * step / wl, 3, 0.5)
			cx[key], cy[key] = x, amp * noise.fbm(f, i * step / wl + 23.7, j * step / wl - 41.1, 3, 0.5)
		end
		return x, cy[key]
	end
	return function(X, Y)
		local fx, fy = X / step, Y / step
		local i, j = floor(fx), floor(fy)
		local tx, ty = fx - i, fy - j
		local x00, y00 = node(i, j)
		local x10, y10 = node(i + 1, j)
		local x01, y01 = node(i, j + 1)
		local x11, y11 = node(i + 1, j + 1)
		local a, b = x00 + tx * (x10 - x00), x01 + tx * (x11 - x01)
		local c, d = y00 + tx * (y10 - y00), y01 + tx * (y11 - y01)
		return a + ty * (b - a), c + ty * (d - c)
	end
end

-- Alpine (owner 2026-10-09; built 2026-10-11): vanilla Temperate's alpine regions. Most of the land is
-- hill country and plains; distinct massifs (irregular, noise-warped outlines 2-5 km across) carry the snow-capped peaks
-- and stand on raised upland. A loose chain of massifs forms the main divide across the map (sea on the low edge, or
-- none; rivers beyond the divide leave anywhere along the far edge); the two graded passes cross it through gaps between
-- massifs, as on Mountain Range. Each massif is a cone in B (its drainage radiates from the peak) with high uplift, so
-- stream power carves radiating ridges and valleys; lift raises the massifs' bases and the upland around them as a block,
-- which the rivers cut down. (Chosen from three designs tuned against vanilla's measured slopes and heights.)
M.TYPES.alpine = {
	label = "Alpine",
	-- heights per Relief step (with the lift and the hills on top the 99th percentile is ~335 m at Gentle, vanilla's, with
	-- snow on the peaks, and ~540 m at Mountainous); slope 2.1: about twice the base slope limit, for the steep massif
	-- flanks (capped at 1.0 from Hilly up, so the higher steps gain less); dense channels 0.18 dissect massifs and hills;
	-- rivers 0.6: more valley floors; (the pass floors are graded on the lowest ground across their width, passes.lua,
	-- else a side valley beside the axis left the floor on its rim: up to 4 % at Gentle, 9 % at Mountainous on some
	-- seeds; Alpine's preset.passFloorMin until 2026-10-13, now every pass's rule, REVIEW B9)
	-- middle steps 232 / 255 / 300 and flatKeep 0.6 (2026-10-12, REVIEW B13): the 99th-percentile height and the flat land
	-- step evenly (240 / 280 / 310 put the height at 0.37 / 0.70 / 0.90 of the way); Alpine's lowlands flatten easily
	-- under the curved height scale (landform.RELIEF_BEND), so it takes 0.6 of it
	preset = { relief = 1.5, reliefP99 = { 200, 232, 255, 300, 330 }, lift = 0.9, slope = 2.1, hills = 1.0, hillCover = 1.0,
		ships = 0, shelf = { slope = 0.025, max = 60 }, lakes = 0.6, rivers = 0.6, meander = 0.8, valley = 0.9, estuary = 900,
		channels = 0.18, uplands = 0, flatKeep = 0.6 },
	setup = function(cw, ch, r, seed, ragScale)
		local s = {}
		s.rg = curve(noise.perlin(noise.derive(seed, "range")), 3500, 3)
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.cs = curve(noise.perlin(noise.derive(seed, "coast")), 2500, 4)
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.ragScale = ragScale or 1 -- (the coast roughness; shapes.build passes it and sets it again after setup)
		-- massif outlines are warped (typical shifts +-400 m): no plain ellipses
		s.warpAt = latticeWarp(noise.perlin(noise.derive(seed, "massifwarp")), 1500, 1600, 128)
		s.phase = r:range(0, 2 * pi)
		-- the main divide, a wavy line across the map
		s.rangeAt = function(X)
			return ch * (0.56 + 0.07 * sin(2 * pi * 0.7 * X / cw + s.phase) + 0.05 * s.rg(X))
		end
		-- two passes across the divide, as on Mountain Range (the notch in B follows each axis), from the coastal plain to
		-- the far edge: massifs and hill country fill the forelands here, and a route that ended among them dipped where
		-- the land beyond its end fell away (3.4 % at Gentle) or ended in a dead-end cutting through an upland; the far
		-- edge has no land beyond it. (Not into the sea: the shore smoothing made the first metres inland too steep.) Such
		-- long routes keep the coast and the hinterland in one rail network; they bend like valleys (bends of ~4 km, up
		-- to a tenth of the map width), since a 15 km route wandering only +-250 m read as a ruler-straight line.
		s.passes = {}
		s.corridors = {}
		for idx, px in ipairs({ cw * r:range(0.22, 0.40), cw * r:range(0.60, 0.80) }) do
			local wig = curve(noise.perlin(noise.derive(seed, "pass" .. idx)), 4000, 3)
			local at = function(Y) return px + 0.1 * cw * wig(Y) end
			s.passes[idx] = at
			-- the foot stays clear of the ragged shore: the last sea point on the axis (the eval's own sea test, within
			-- the reach of the roughness) at least 200 m below it; a foot in the sea graded its first 100 m over the
			-- shore's smoothing (2.7-3.0 % at Gentle on small maps and at high roughness)
			local shore = -math.huge
			for Y = ch * 0.01, ch * 0.105 + M.COAST_RAG * s.ragScale, 8 do
				local X = at(Y)
				if Y < ch * (0.06 + 0.045 * s.cs(X)) + rag(s, X, Y) then shore = Y end
			end
			local Y0, Y1 = max(ch * (0.10 + 0.045 * s.cs(px)), shore + 200), ch
			local line = {}
			for q = 0, 64 do
				local Y = Y0 + (Y1 - Y0) * q / 64
				line[#line + 1] = { X = at(Y), Y = Y }
			end
			s.corridors[idx] = line
		end
		s.inflows = {}
		-- rivers beyond the divide leave the map wherever they reach the far edge (shapes.build makes every node
		-- of it an outlet), instead of running along it to a few points
		s.outlets, s.farOutlets = {}, true
		s.massifs = alpineMassifs(s, cw, ch, seed)
		return s
	end,
	eval = function(s, X, Y, cw, ch)
		-- the ragged coast only near the shore (|rag| stays below COAST_RAG x roughness); the land's fall uses the
		-- smooth coastline, so B has no seam where the rag stops
		local coast = ch * (0.06 + 0.045 * s.cs(X))
		-- without sea (Sea side None) the sea's strip is foreland that keeps falling towards the low edge
		if not s.noSea and Y < coast + M.COAST_RAG * s.ragScale and Y < coast + rag(s, X, Y) then return -10, 1, true end
		local yr = s.rangeAt(X)
		local db = abs(Y - yr) / ch
		local notch = 0
		for _, at in ipairs(s.passes) do
			notch = max(notch, exp(-((X - at(Y)) / (0.05 * cw)) ^ 2))
		end
		local n = noise.fbm(s.n, X / 2200, Y / 2200, 5, 0.5)
		-- massifs: elliptic distance d on warped coordinates (0 at the peak, 1 on the outline)
		local ox, oy = s.warpAt(X, Y)
		local wx, wy = X + ox, Y + oy
		local cone, core, halo = 0, 0, 0
		for _, m in ipairs(s.massifs) do
			local dx, dy = wx - m.X, wy - m.Y
			if abs(dx) < m.reach and abs(dy) < m.reach then
				local u, v = (dx * m.c + dy * m.sn) / m.a, (dy * m.c - dx * m.sn) / m.b
				local d = math.sqrt(u * u + v * v)
				if d < 1 then cone = max(cone, m.k * (1 - d)) end
				core = max(core, m.k * smoothstep(1.05, 0.0, d))
				halo = max(halo, smoothstep(1.6, 0.85, d))
			end
		end
		local open = 1 - notch -- the pass gaps stay clear of massifs and upland
		-- the main divide between the massifs: a rugged ridge of hills, so the passes are needed to cross it
		local ridge = 1 - smoothstep(0.0, 0.12, db)
		local crest = (1 - smoothstep(0.0, 0.08, db)) * (1 - 0.8 * notch)
		local side = Y < yr and 60 * (Y - coast) / max(yr - coast, 1) or 60 * (1 - (Y - yr) / max(ch - yr, 1))
		local B = side + 260 * ridge * (1 - 0.7 * notch) + 700 * cone * open + 80 * n
		-- upland: the crest of the divide and an apron around each massif, raised as a block (lift); the massif cores
		-- stand higher still, and their own uplift (core) carves them
		local up = max(0.45 * crest, 0.6 * halo * (1 - 0.8 * notch))
		local U = 0.4 + 0.3 * up + 0.6 * crest + 2.0 * core * open + 0.2 * (n + 0.5)
		local lift = min(1, (up + 0.35 * cone * open) * (0.85 + 0.3 * (n + 0.5)))
		return B, max(U, 0.08), false, lift
	end,
}

-- Inland plain: a big river crosses the map from the far edge to the near edge; broad low swells; no sea.
M.TYPES.rolling_plains = {
	label = "Rolling Plains",
	preset = { relief = 0.45, hills = 0.45, ships = 1, shelf = { slope = 0.01, max = 20 }, lakes = 1.0, rivers = 1.0, meander = 1.1,
		valley = 1.6, estuary = 0, channels = 1.0, uplands = 1.0 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.ax = curve(noise.perlin(noise.derive(seed, "axis")), 3500, 3)
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.m = noise.perlin(noise.derive(seed, "swells"))
		s.x0 = cw * r:range(0.3, 0.7)
		s.axisAt = function(Y) return s.x0 + cw * 0.12 * s.ax(Y) end
		s.inflows = { { X = s.axisAt(ch), Y = ch, area = 1.2 * cw * ch } }
		-- the trunk leaves at the near edge; side streams may leave at the side edges
		s.outlets = { { X = s.axisAt(0), Y = 0 }, { X = 0, Y = ch * r:range(0.15, 0.5) },
			{ X = cw, Y = ch * r:range(0.15, 0.5) } }
		return s
	end,
	eval = function(s, X, Y, cw, ch)
		local dv = abs(X - s.axisAt(Y)) / cw
		local n = noise.fbm(s.n, X / 2400, Y / 2400, 5, 0.5)
		local swell = noise.fbm(s.m, X / 6000, Y / 6000, 2, 0.5)
		local B = 30 * Y / ch + 60 * smoothstep(0.0, 0.45, dv) + 40 * n + 25 * swell
		local U = 0.18 + 0.25 * smoothstep(0.05, 0.5, dv) + 0.15 * (n + 0.5)
		return B, max(U, 0.06), false
	end,
}

-- Ice-scoured hill country: hollows drawn out along the old ice flow (at a seed angle) hold long, narrow lakes on the
-- rivers; the land drains to the near edge.
M.TYPES.lake_district = {
	label = "Lake District",
	preset = { relief = 0.9, ships = 0, shelf = { slope = 0.015, max = 30 }, lakes = 3.0, rivers = 0.75, meander = 0.8,
		valley = 1.0, estuary = 0, channels = 1.0, uplands = 0.6 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.b = noise.perlin(noise.derive(seed, "basins"))
		-- the old ice flowed roughly down the map, at an angle of its own per seed (run 5: hollows stretched exactly
		-- along a map axis read as an artificial "stretched" texture)
		s.ca, s.sa = math.cos(r:range(-0.7, 0.7)), sin(r:range(-0.7, 0.7))
		s.inflows = {}
		s.outlets = { { X = cw * r:range(0.2, 0.45), Y = 0 }, { X = cw * r:range(0.55, 0.85), Y = 0 } }
		return s
	end,
	eval = function(s, X, Y, cw, ch)
		local n = noise.fbm(s.n, X / 2000, Y / 2000, 5, 0.5)
		-- hollows: noise stretched along the ice flow (Y), so the basins are long and narrow (ribbon lakes)
		local u, v = X * s.ca - Y * s.sa, X * s.sa + Y * s.ca
		local b = noise.fbm(s.b, u / 1100, v / 1900, 3, 0.5)
		local fells = smoothstep(0.55, 1.0, Y / ch)
		local B = 70 * Y / ch + 55 * n + 70 * b + 60 * fells
		local U = 0.35 + 0.35 * (n + 0.5) + 0.35 * fells
		return B, max(U, 0.1), false
	end,
}

-- Coast with two or three deep bays: sheltered water and natural harbours; rivers end at the bay heads.
M.TYPES.large_bays = {
	label = "Large Bays",
	-- the bays are the ship water; its rivers are short, so no ship river by default
	preset = { relief = 1.0, ships = 0, shelf = { slope = 0.01, max = 40 }, lakes = 0.8, rivers = 1.0, meander = 1.0,
		valley = 1.6, estuary = 1200, channels = 1.0, uplands = 1.0 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.cs = curve(noise.perlin(noise.derive(seed, "coast")), 1400, 5)
		s.bw = curve(noise.perlin(noise.derive(seed, "baywidth")), 2200, 3)
		s.warp = noise.perlin(noise.derive(seed, "warp"))
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.n = noise.perlin(noise.derive(seed, "land"))
		local nb = r:int(2, 3)
		s.bays = {}
		for b = 1, nb do
			-- each side of a bay has its own width, so no bay is symmetric
			s.bays[b] = { X = cw * ((b - 0.5) / nb + r:range(-0.07, 0.07)), depth = ch * r:range(0.24, 0.42),
				wL = cw * r:range(0.08, 0.15), wR = cw * r:range(0.08, 0.15), shape = r:range(1.8, 3.0),
				lean = r:range(-0.35, 0.35) }
		end
		s.inflows, s.outlets = {}, {}
		return s
	end,
	eval = function(s, X, Y, cw, ch)
		-- outlines warped by slow 2D noise: no straight or mirror-image shores
		local Xw = X + 0.09 * cw * noise.fbm(s.warp, X / 1800, Y / 1800, 3, 0.5)
		local bay, valley = 0, 0
		for _, b in ipairs(s.bays) do
			local dx = Xw - b.X
			-- the bay axis bends inland (lean grows with depth) and the bay swells and narrows (no straight wedges)
			dx = dx - b.lean * Y
			local d = abs(dx) / ((dx < 0 and b.wL or b.wR) * (1 + 0.5 * s.bw(Y + 7000 * b.X / cw)))
			if d < 1 then
				-- rounded head, sides steepening towards the headlands (a U, not a V)
				bay = max(bay, b.depth * (1 - d ^ b.shape) ^ 0.7)
			end
			-- the bay's valley runs on inland, so the main rivers end at the bay heads
			valley = max(valley, exp(-(dx / (0.05 * cw)) ^ 2))
		end
		local coast = ch * (0.08 + 0.045 * s.cs(X)) + bay + rag(s, X, Y)
		if Y < coast then return -10, 1, true end
		local inland = (Y - coast) / ch
		local n = noise.fbm(s.n, X / 2600, Y / 2600, 5, 0.5)
		local B = 120 * inland + 50 * n - 45 * valley * (1 - smoothstep(0.3, 0.8, inland))
		local U = 0.3 + 0.9 * smoothstep(0.05, 0.5, inland) + 0.3 * (n + 0.5)
		return B, max(U, 0.08), false
	end,
}

-- TWO-PASS TYPES: sea(s, X, Y, cw, ch) -> true for sea; land(s, X, Y, cw, ch, dist) -> B, U [, lift], where dist
-- is the true distance to the open sea in metres (1e9 on maps without sea; with Sea side None the sea's place is land
-- with dist <= 0, minus its distance from where the coast would be) and lift (0..1, optional) raises ground as a block
-- (a plateau: stream power alone cannot hold a high flat surface, since big rivers climb gently). One-pass types may
-- return a lift as eval's 4th value. Sea patches that do not reach the map edge are turned into land (openSeaOnly).

-- Mainland along the far side with two or three long peninsulas reaching into the sea; a low ridge runs down each.
M.TYPES.peninsulas = {
	label = "Peninsulas",
	-- flatKeep 0.85 (2026-10-12, REVIEW B13): the flat land of the narrow peninsulas answers more strongly to the middle
	-- steps' plains factor and height curve (landform.PLAINS_RELIEF, RELIEF_BEND) than other types'
	preset = { relief = 1.0, ships = 0, shelf = { slope = 0.012, max = 40 }, lakes = 0.6, rivers = 0.6, minRiver = 1000, meander = 0.9,
		valley = 1.4, estuary = 900, channels = 1.0, uplands = 1.0, flatKeep = 0.85 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.cs = curve(noise.perlin(noise.derive(seed, "coast")), 1600, 5)
		s.bw = curve(noise.perlin(noise.derive(seed, "width")), 1800, 3)
		s.wig = curve(noise.perlin(noise.derive(seed, "axis")), 2600, 3)
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.base = r:range(0.58, 0.68)
		local np = r:int(2, 3)
		s.pen = {}
		for p = 1, np do
			s.pen[p] = { X = cw * ((p - 0.5) / np + r:range(-0.06, 0.06)), len = ch * r:range(0.32, 0.5),
				w = cw * r:range(0.05, 0.10), lean = r:range(-0.45, 0.45), tip = r:range(2.5, 5.0) }
		end
		s.inflows, s.outlets = {}, {}
		return s
	end,
	sea = function(s, X, Y, cw, ch)
		local coast = ch * (s.base + 0.06 * s.cs(X))
		-- ragged shores: 2D noise on every outline (the mainland coast included, so it is never a straight line)
		local rg = rag(s, X, Y)
		if Y >= coast - rg then return false end
		for _, p in ipairs(s.pen) do
			local t = (coast - Y) / p.len -- 0 at the root, 1 at the tip
			if t >= 0 and t <= 1.05 then
				-- the axis bends (lean grows along it) and wanders; the width swells and narrows; the root flares
				-- into the mainland; the tip is rounded
				local L = coast - Y
				local ax = p.X + p.lean * L * (0.6 + 0.8 * t) + 0.07 * cw * s.wig(Y + 3000 * p.X / cw)
				local tt = min(1, t)
				local half = p.w * (1 + 0.35 * s.bw(Y + 5000 * p.X / cw)) * (1 - tt ^ p.tip) ^ 0.35 * (1 - 0.25 * tt)
					* (1 + 1.2 * (1 - tt) ^ 6)
				if abs(X - ax) < half + rg then return false end
			end
		end
		return true
	end,
	land = function(s, X, Y, cw, ch, dist)
		local d = min(dist, 0.5 * ch) / ch
		local n = noise.fbm(s.n, X / 2400, Y / 2400, 5, 0.5)
		local B = 130 * d + 45 * n
		local U = 0.28 + 0.9 * smoothstep(0.02, 0.25, d) + 0.3 * (n + 0.5)
		return B, max(U, 0.08)
	end,
}

-- A chain of islands of different sizes along a curve; sounds between them; each island has its own hills and
-- short rivers.
M.TYPES.island_chain = {
	label = "Island Chain",
	-- islands drain small areas: a low water threshold (rivers 0.12) still gives the big islands their streams;
	-- low hills (relief 0.6), since the relief target would otherwise pile the whole range onto small islands
	preset = { relief = 0.6, hills = 0.8, ships = 0, shelf = { slope = 0.02, max = 50 }, lakes = 0.4, rivers = 0.12, minRiver = 600, meander = 0.9,
		valley = 1.2, estuary = 600, channels = 1.0, uplands = 1.0 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.phase = r:range(0, 2 * pi)
		local n = r:int(4, 7)
		s.lobes = {}
		local big = r:int(1, n)
		for q = 1, n do
			local X = cw * (0.08 + 0.84 * (q - 0.5) / n + r:range(-0.04, 0.04))
			local Y = ch * (0.5 + 0.18 * sin(2 * pi * 0.8 * X / cw + s.phase) + r:range(-0.07, 0.07))
			local R = cw * (q == big and r:range(0.12, 0.15) or r:range(0.035, 0.085))
			-- every island is two to four overlapping lobes of different sizes: no plain ovals
			for _ = 1, r:int(2, 4) do
				local f = r:range(0.45, 0.85)
				s.lobes[#s.lobes + 1] = { X = X + R * r:range(-0.7, 0.7), Y = Y + R * r:range(-0.7, 0.7),
					a = R * f * r:range(0.9, 1.6), b = R * f * r:range(0.5, 1.0), rot = r:range(0, pi) }
			end
		end
		s.inflows, s.outlets = {}, {}
		return s
	end,
	sea = function(s, X, Y, cw, ch)
		local f = -1
		for _, q in ipairs(s.lobes) do
			local dx, dy = X - q.X, Y - q.Y
			local c, sn = math.cos(q.rot), sin(q.rot)
			local u, v = (dx * c + dy * sn) / q.a, (-dx * sn + dy * c) / q.b
			f = max(f, 1 - (u * u + v * v))
		end
		-- noise on the outline: bays, capes and the odd islet
		f = f + 0.45 * noise.fbm(s.edge, X / 1100, Y / 1100, 4, 0.55)
		return f + rag(s, X + 9000, Y) / 1500 <= 0
	end,
	land = function(s, X, Y, cw, ch, dist)
		local d = min(dist, 0.3 * ch) / ch
		local n = noise.fbm(s.n, X / 2000, Y / 2000, 5, 0.5)
		local B = 140 * d + 40 * n
		-- a coastal fringe of low land, hills in the island cores
		local U = 0.18 + 0.75 * smoothstep(0.02, 0.15, d) + 0.25 * (n + 0.5)
		return B, max(U, 0.06)
	end,
}

-- A general coast: irregular shore with headlands, coves and the odd islet, a coastal plain, hills inland; a larger
-- river comes in from the hinterland.
M.TYPES.coastal_region = {
	label = "Coastal Region",
	preset = { relief = 1.0, ships = 1, shelf = { slope = 0.012, max = 40 }, lakes = 0.8, rivers = 1.0, meander = 1.0,
		valley = 1.6, estuary = 1500, channels = 1.0, uplands = 1.0 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.cs = curve(noise.perlin(noise.derive(seed, "coast")), 3000, 3)
		s.cs2 = curve(noise.perlin(noise.derive(seed, "coast2")), 900, 4)
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.base = r:range(0.16, 0.24)
		s.inflows = { { X = cw * r:range(0.25, 0.75), Y = ch, area = 0.8 * cw * ch } }
		s.outlets = {}
		return s
	end,
	sea = function(s, X, Y, cw, ch)
		local coast = ch * (s.base + 0.07 * s.cs(X) + 0.03 * s.cs2(X))
		return Y < coast + 0.03 * ch * noise.fbm(s.edge, X / 2500, Y / 2500, 3, 0.5) + rag(s, X + 4000, Y)
	end,
	land = function(s, X, Y, cw, ch, dist)
		local d = min(dist, 0.6 * ch) / ch
		local n = noise.fbm(s.n, X / 2600, Y / 2600, 5, 0.5)
		local B = 120 * d + 50 * n + 30 * Y / ch
		local U = 0.25 + 0.8 * smoothstep(0.03, 0.4, d) + 0.35 * (n + 0.5)
		return B, max(U, 0.08)
	end,
}

-- Lowland by the sea, a wavy escarpment, and a high, flat plateau behind it. Plateau rivers cross the escarpment in
-- gorges. (Stream power does this by itself: low uplift on the lowland and the plateau, high uplift in the
-- escarpment band, so channels climb steeply there and run gently above.)
M.TYPES.highland_plateau = {
	label = "Highland Plateau",
	preset = { relief = 0.6, hills = 0.7, lift = 2.0, ships = 0, shelf = { slope = 0.015, max = 40 }, lakes = 1.0, rivers = 0.9, meander = 0.9,
		valley = 1.0, estuary = 800, channels = 0.7, uplands = 1.0 },
	setup = function(cw, ch, r, seed)
		local s = {}
		s.cs = curve(noise.perlin(noise.derive(seed, "coast")), 2500, 4)
		s.es = curve(noise.perlin(noise.derive(seed, "scarp")), 2000, 4)
		s.edge = noise.perlin(noise.derive(seed, "edge"))
		s.n = noise.perlin(noise.derive(seed, "land"))
		s.base = r:range(0.08, 0.14)
		s.scarp = r:range(0.28, 0.38)
		s.inflows, s.outlets = {}, {}
		return s
	end,
	sea = function(s, X, Y, cw, ch)
		return Y < ch * (s.base + 0.04 * s.cs(X)) + rag(s, X, Y)
	end,
	land = function(s, X, Y, cw, ch, dist)
		local d = min(dist, ch) / ch
		local e = s.scarp + 0.07 * s.es(X)
		local n = noise.fbm(s.n, X / 2200, Y / 2200, 5, 0.5)
		local band = exp(-((d - e) / 0.03) ^ 2)
		local B = 100 * d + 60 * smoothstep(e - 0.03, e + 0.03, d) + 40 * n
		-- low uplift on the lowland and the plateau top (both gentle), rougher in the escarpment
		local U = 0.14 + 0.6 * band + 0.12 * (n + 0.5)
		-- the plateau stands as a block behind the escarpment; the slope limit shapes the scarp and the gorges
		local lift = smoothstep(e - 0.012, e + 0.012, d) * (0.85 + 0.15 * (n + 0.5))
		return B, max(U, 0.06), lift
	end,
}

--[[ Sea Strait (owner 2026-10-12, REVIEW B10; DESIGN 23): a sea strait splits the map from edge to edge, open sea at
  both ends, so the two banks face each other across it.
  FRAME  u runs along the strait's axis (0 at the map's centre point), v across it. The axis lies along the canonical X
         (East-West and North-South: shapes.build puts the chosen direction on X) or, for the diagonals, runs along the
         long side from the low part of one short edge to the high part of the other (build puts the long side on X and
         picks the mirror for SW-NE or NW-SE). The sounds are drawn through a smooth warp (straitFrame).
  WATER  sounds about 0.2 x the cross distance D wide (700 .. 4800 m; 0.25 x on maps up to 4 km across; 1.2 x that on
         a diagonal; on a short crossing at most 0.4 x the strait's length), each shore swelling on its own (+60 % at
         most, -15 %; towards a narrows at most +10 %: a funnel 1.3 x its walls long), 1.4 x wider at both ends (open
         sea); big bends (8-12 % of D, wavelength 10-14 sound widths, 0.6 .. 2 x the strait's length; half on a
         diagonal), centred so both banks' median rooms are equal. The water takes at most 0.24-0.34 of the room on
         either side of the axis (each bank keeps 2 x 0.33 of its side, raised by a slow wander of its own, held at its
         value inside a funnel: on a straight strait 0.33-0.38 of D), the half-widths capped softly at it. One narrows
         per ~7 km of the strait's middle 76 % (1-4, at least 1.5 sound widths apart): a broad headland from one bank
         (65-82 % of the closing, 59-70 % on a diagonal; the banks alternate, so the water winds round the capes) meets
         a gentler bulge of the other shore at a short channel of 355-390 m across its course (at least 5 coarse cells),
         cut at that width by the lane. Each wall is a plain smoothstep from the channel's core (a rounded tip: radius
         about 200 m or more), bowed out a little and wandering along its flank; the headland's flanks are about as long
         as it reaches out, up to 62 % of the way to the next narrows; on a diagonal a wall rising towards the channel
         lies no steeper than 64 degrees to the map's x axis (never flatter than 34 degrees to the strait). The coast
         roughness and a shore noise of the type's own (stronger below Coast roughness 100 %) act across the shore (on a
         headland's flank too), not around a narrows' channel (within 0.65-1.15 km of its centre for coves, 0.35-0.7 km
         for capes; further the more the shore moves), and close a sound by at most a quarter of its half-width (at
         least 200 m where it is narrow on maps up to 4.5 km across, at most 45 %); the water never gets narrower than a
         channel plus a coarse cell across its course. The middle half of the strait is always water: it can never
         close. Islands only in wide sounds, their ends 1.5 km from a narrows' channel, with both channels at least
         300 m wide (never a cheaper crossing than a narrows); any other land the water cuts off becomes water, and so
         do land slivers one cell wide (M.removeLandSlivers, M.dropStrayLand).
  LAND   the coast-distance field of the two-pass types (B rises inland, so every river drains to the strait); a bump in
         B around each narrows sends the streams to the sounds beside it (a bridge site needs no river mouth); one river
         per bank comes from beyond its far edge; a bump along the two edges the strait meets keeps the rivers' mouths
         off them. land() also returns the shore plain width (a flat belt of 400-1200 m
         along the sounds, none near the narrows) and the bluff weight (1 within 1.55 km of a narrows' channel):
         landform.lua shapes both. On a short crossing (a strait under 6 km long) both zones shrink along the strait,
         so its shores keep room for harbours.
  OUT    out.strait = the axis in local metres (every 25 m: half-width, narrows weight; narrows indices; D, L, sound
         width) for the report and the tools; out.lanes = the shipping lane, carved where the strait is narrow
         (pipeline.lua), so ships always pass end to end. ]]
M.STRAIT = {
	width = 0.2, widthMin = 700, widthMax = 4800, -- sound width: share of the cross distance D, clamped (m)
	widthSmall = 0.25, -- ... on maps up to 4 km across (blended to width by 7 km)
	widthDiag = 1.2,   -- ... x this on a diagonal (sounds of 0.13-0.15 D on 16 km diagonals, whose flanks are long)
	shortHb = 0.2,   -- the sound's half-width at most this share of the strait's length (a short crossing)
	swellMin = 0.85, swellMax = 1.6, -- each shore's swell: -15 % to +60 % of the design (-25 % drew sounds of 0.14-0.15 D
	                                 -- on some 16 km diagonals)
	swellS = 7,      -- ... a logistic curve of its noise (about +-0.6), this steep: no bound held for long (round 3; the
	                 -- clamp of 1 + 1.5 x the noise held the -15 % bound over a third of the strait; 4 varied too little)
	ends = 1.4, endsDiag = 1.15,                   -- wider at both ends (the diagonals less: their corner wedges)
	soundMin = 350,  -- m: least half-width of a sound (where the map is wide enough), so only the narrows read as narrows
	ragIn = 0.25,    -- coast roughness closes a sound by at most about this share of its half-width per shore (smoothly)
	ragInMin = 200, ragInSmall = 0.45, -- m: ... and at least this much where the sound is narrow (at most this share), on
	                 -- maps up to 4.5 km across (none from 5 km: there it drew unplanned narrows under 600 m at 200 %)
	bankMin = 0.33,  -- each bank keeps this share of the cross distance at every section (outline before roughness;
	                 -- on a diagonal: 2 x this share of the room on its side of the axis)
	bankWander = 0.15, -- the bank limit wanders up to this share above bankMin (slowly along the strait)
	bendAmp = { 0.08, 0.12 }, bendWl = { 10, 14 }, -- bend amplitude (share of D), wavelength (sound widths)
	bendSlope = 0.06, -- bend amplitude at most this share of its wavelength
	bendDiag = 0.5,   -- the diagonals' bends: this share of the amplitude
	every = 7000, maxNarrows = 4, endZone = 0.12, gap = 4000, -- narrows: metres of strait per narrows, count, ends, spacing
	basinMin = 1.5,  -- narrows at least this many sound widths apart (fewer narrows where the sounds are wide)
	basinShare = 0.42, swellIn = { 0.85, 1.15 }, -- an inner sound (between two narrows): its design width at most this
	                 -- share of the way between their channels, its swell within this, so it is about twice as long as
	                 -- its widest (review round 3: inner sounds as wide as long read as round ponds joined by canals)
	basinBlend = 600, -- m: the inner sound's limits fade out over this either side of a narrows
	wallMax = math.rad(58), -- no wall steeper than this to the strait (a wall across it ran along a map edge: boxy basins)
	-- the narrows' channel width (m) at the water line: the lane cuts it at the full resolution (the coarse water there
	-- is that wide too, but its edge moves by up to a cell with the grid and the shore smoothing: 14-58 m narrower);
	-- never under 5 coarse cells
	throat = { 355, 390 }, throatCells = 5,
	channel = { 60, 120 }, coreCells = 1.5, -- m: half-length of the channel at its full narrowness (at least 1.5 cells)
	asymDiag = 0.6,                         -- the diagonals' asym: this share of it (at least asymMin)
	asym = { 0.3, 0.65 }, asymMin = 0.2,    -- the main headland's share of the closing beyond half (65-82 %; 60 % at least)
	flank = { 1.4, 1.9 }, tipRadius = 200, tipE = 0.35, -- the walls (wallF): length / reach (they leave the tip at
	                                        -- 2 x reach / length: 46-55 degrees), the tip's radius (m) and at most this
	                                        -- share of the wall rounded
	flankMapMax = math.rad(64), flankRelMin = math.rad(34), -- a diagonal: a rising wall on average at most this steep
	                                        -- to the map's x axis, but never asked to be flatter than flankRelMin to the
	flankMapLim = math.rad(72),             -- strait; and nowhere steeper than flankMapLim (the walls' slope limit)
	oppLen = { 0.9, 1.2 },                  -- the opposite shore's bulge: its length / the headland's flank
	wob = { 0.05, 0.08 }, wobN = { 1.2, 2.2 },  -- each wall's wander: amplitude (x the headland's reach), waves per flank
	                                        -- (round 3: 0.035-0.06 left the new walls, smooth by the channel, straight over 1.5-1.8 km)
	wobFloor = 1200, wobWl = 700,           -- m: the reach the wander is measured by at least; its shortest wavelength
	wobLong = 1800,                         -- m: its longest wavelength (a diagonal's lengthened wall, 4-5 km, ran straight)
	bowM = { 0.02, 0.07 }, bowO = { 0.02, 0.05 }, -- each wall bows out by this share of its reach (x sin^2): a little
	                                        -- (round 3: 0.06-0.2, set for the smoothstep's straight middle, cancelled the
	                                        -- new wall's own curve and drew flanks within 40 m of a line over 1.5 km)
	funnelK = 1.1, funnelFlank = 1.3,       -- the funnel: swell at most this; its length x the longer wall's
	room = 0.45, roomMain = 0.62,           -- share of the way to the next narrows: the funnel and the other shore's
	                                        -- bulge; the main headland's flanks (the next main headland is on the other bank)
	capeR = { 300, 600 },                   -- m from a channel's centre: no capes (the shore moving out) within, all
	                                        -- beyond (one beside the channel became the narrowest crossing)
	coveR = { 550, 1000 },                  -- m from a channel's centre: no coves within, all beyond (coves there made thin
	                                        -- spits and fingers of the landings). Round 3: 350-700 and 650-1150 m held
	                                        -- the narrows' flanks smooth for 1.3-2.3 km (look review), and the walls,
	                                        -- now broad wedges from a rounded tip, keep their landings whole closer in
	shoreMin = 250,                         -- m: the shore noise's amplitude at least (on maps 2-5 km across hb is 300-700 m)
	shoreAmp = { 0.35, 0.7 }, shoreWl = 0.6, -- the type's own shore noise: x hb (fBm about +-0.3) at Coast roughness 100 %+
	                                        -- and at 0 % (the roughness's own 1.2 km octave shapes the shores otherwise),
	                                        -- its wavelength x hb (at least 800 m)
	warp = 0.25, warpSide = 0.1, warpWl = 1.0, -- outline warp: amplitude along and across the strait (x the sound
	                                        -- half-width), wavelength (sound widths)
	warpCore = 600, warpReach = 1600,       -- m from a narrows' channel centre: no warp within, the full warp beyond
	warpHw = 300,                           -- the warp returns over this many metres of half-width above laneHw
	warpFade = 1000,                        -- m: and fades out over this beyond the furthest the water can reach
	wedge = 1500,                           -- m: least land wedge in the corners a diagonal enters and leaves by
	cornerWander = 0.15,                    -- the corner wedge's limit on the water wanders down by up to this share
	laneHw = 600, laneW = { 160, 520 }, laneDepth = 6, -- the lane: where the half-width is under laneHw; width, depth
	laneFull = { 150, 300 }, -- m beyond the channel's core: the lane has the channel's full width within, a fairway beyond
	laneBank = 24,   -- m: the lane's banks rise 1:4 to this height (above the bank top: no step where it trims land)
	laneShare = 0.7, laneOpen = 200, -- outside the channels the lane is at most 200 m and 70 % of the strait wide
	plain = { 400, 1200 }, plainBank = 0.4, -- shore plain width (m), at most this share of its bank
	bluffTop = { 18, 23 },                  -- m: bank top at the narrows (landform.STRAIT_BLUFF_AT from the water)
	bluffCore = 1550, bluffReach = 2300,    -- m from a narrows' channel centre: graded banks within (the 1 km approach behind
	                                        -- the bluff on both banks), none beyond
	plainCore = 1700, plainReach = 3000,    -- m from a narrows' channel centre: no shore plain within, the full plain beyond
	shortL = 6000,                          -- m: on a shorter strait the bluff and plain zones shrink along it (x L / shortL)
	bluffBlendMin = 600,                    -- m: ... but the bluff zone fades over at least this along it
	bumpCore = 1000, bumpReach = 3000, bump = 150, -- the drainage bump: full within, none beyond (m from a narrows'
	                                        -- channel centre); its height in B (the land rises by at most ~60 in B)
	edgeBump = 40, edgeReach = 1500,        -- the bump along the two edges the strait meets: height in B, reach (m) (at
	edgeShare = 0.2,                        -- most this share of the strait's length: on a 2 km crossing it covered
	                                        -- both banks whole, review round 3)
	riverInset = 150,                       -- m: the rivers' meanders stay this far inside those two edges
	islandEvery = 5000, islandSound = 1400, islandGap = 1500, islandChannel = 300, islandRag = 120,
}

-- distance from (px, py) along (dx, dy) to the edge of the canonical rectangle
local function rayExit(px, py, dx, dy, cw, ch)
	local t = math.huge
	if dx > 1e-9 then t = min(t, (cw - px) / dx) elseif dx < -1e-9 then t = min(t, -px / dx) end
	if dy > 1e-9 then t = min(t, (ch - py) / dy) elseif dy < -1e-9 then t = min(t, -py / dy) end
	return max(0, t)
end

-- smooth min / max (k: width of the knee), so the bend clamp leaves no straight runs along the limit
local function smax(a, b, k) return 0.5 * (a + b + math.sqrt((a - b) * (a - b) + k * k)) end
local function smin(a, b, k) return 0.5 * (a + b - math.sqrt((a - b) * (a - b) + k * k)) end

-- weight 1 within `core` metres of the nearest narrows' channel centre (canonical X, Y), 0 beyond `reach`
local function nearThroat(r, core, reach) return 1 - smoothstep(core, reach, r) end

-- distance from (X, Y) to the nearest narrows' channel centre; with ku < 1 (a short crossing) the distance along the
-- strait counts 1 / ku times (the land zones shrink along it, not across)
local function throatDist(s, X, Y, ku)
	local r = math.huge
	local nrs = s.narrows
	if ku and ku < 1 then
		local ca, sa = s.ca, s.sa
		for q = 1, #nrs do
			local nr = nrs[q]
			local dx, dy = X - nr.X, Y - nr.Y
			local a, b = (dx * ca + dy * sa) / ku, -dx * sa + dy * ca
			local e = a * a + b * b
			if e < r then r = e end
		end
	else
		for q = 1, #nrs do
			local nr = nrs[q]
			local dx, dy = X - nr.X, Y - nr.Y
			local e = dx * dx + dy * dy
			if e < r then r = e end
		end
	end
	return math.sqrt(r)
end

-- a short crossing's graded banks (straitLand): full within bluffCore across the strait and bluffCore x ku along it,
-- fading over 750 m across and over 750 m x ku but at least bluffBlendMin along (shrunk with the zone, the fade along
-- the strait drew a plateau with a scarp rim beside a 2 km crossing's narrows, 30-70 % over 100 m, review round 3)
local function bluffShort(s, X, Y)
	local C = M.STRAIT
	local ca, sa, ku = s.ca, s.sa, s.ku
	local coreA = C.bluffCore * ku
	local reachA = coreA + max((C.bluffReach - C.bluffCore) * ku, C.bluffBlendMin)
	local wb = 0
	for q = 1, #s.narrows do
		local nr = s.narrows[q]
		local dx, dy = X - nr.X, Y - nr.Y
		local a, b = abs(dx * ca + dy * sa), abs(-dx * sa + dy * ca)
		if a < reachA and b < C.bluffReach then
			wb = max(wb, (1 - smoothstep(C.bluffCore, C.bluffReach, b)) * (1 - smoothstep(coreA, reachA, a)))
		end
	end
	return wb
end

-- the same with two scalings at once (straitLand: the land zones' ku and the drainage bump's kb)
local function throatDist2(s, X, Y, k1, k2)
	local r1, r2 = math.huge, math.huge
	local ca, sa = s.ca, s.sa
	for _, nr in ipairs(s.narrows) do
		local dx, dy = X - nr.X, Y - nr.Y
		local a, b = dx * ca + dy * sa, -dx * sa + dy * ca
		local a1, a2 = a / k1, a / k2
		b = b * b
		r1, r2 = min(r1, a1 * a1 + b), min(r2, a2 * a2 + b)
	end
	return math.sqrt(r1), math.sqrt(r2)
end

-- M.straitAt, the slopes of both shores along u and the coast roughness damping as a table along u (every 8 m, linear
-- in between): the shape stage reads them several times per node (straitAt alone made the stage 2.4 x Coastal Region's)
local TABLE_STEP = 8
local function straitTable(s)
	local C = M.STRAIT
	local t = { vc = {}, hw = {}, wq = {}, Dl = {}, Du = {}, dl = {}, du = {}, dc = {}, sl = {}, su = {} }
	local u0, u1 = s.u0 - s.ext, s.u1 + s.ext -- (beyond both ends: the diagonals' corners)
	local n = math.ceil((u1 - u0) / TABLE_STEP) + 1
	for i = 0, n do
		local u = min(u1, u0 + i * TABLE_STEP)
		local vc, hw, wq, Dl, Du = M.straitAt(s, u)
		-- the roughness damping per u: beside an island only the capes, which could narrow its outer channel under 300 m;
		-- coves only widen it (both damped, as first built, the shores ran straight for 2-4 km beside an island on 1:3
		-- strips). Around each narrows' channel straitSea damps coves and capes by the distance to it.
		local dl, dh, dc = 0, 0, 0
		for _, isl in ipairs(s.islands) do
			dc = max(dc, 0.8 * (1 - smoothstep(isl.a, isl.a + 600, abs(u - isl.u))))
		end
		t.vc[i], t.hw[i], t.wq[i], t.Dl[i], t.Du[i], t.dl[i], t.du[i], t.dc[i] = vc, hw, wq, Dl, Du, dl, dh, dc
	end
	-- each shore's slope dv/du (central differences over 16 m): the roughness acts across the shore, not across the strait
	for i = 0, n do
		local a, b = max(0, i - 1), min(n, i + 1)
		local du = max(1, (b - a) * TABLE_STEP)
		t.sl[i] = ((t.vc[b] - t.hw[b]) - (t.vc[a] - t.hw[a])) / du
		t.su[i] = ((t.vc[b] + t.hw[b]) - (t.vc[a] + t.hw[a])) / du
	end
	t.n = n
	-- the furthest the water can reach from the axis line (v, unwarped) around each u, for straitSea's quick test: the
	-- outline plus the most the coast roughness and the shore noise can move it (both noises stay within +-1, times the
	-- shore's stretch), over the outline warp's reach along the strait, plus its reach across and two cells
	local env = { lo = {}, hi = {} }
	do
		local amp = 1.02 * (M.COAST_RAG * s.ragScale + s.shoreA)
		local lo, hi = {}, {}
		for i = 0, n do
			local sl, su = t.sl[i], t.su[i]
			local reach = amp * min(3, math.sqrt(1 + max(sl * sl, su * su)))
			lo[i], hi[i] = t.vc[i] - t.hw[i] - reach, t.vc[i] + t.hw[i] + reach
		end
		local W = math.ceil(C.warp * s.hb / TABLE_STEP) + 1
		local pad = C.warpSide * s.hb + 2 * s.cell
		for i = 0, n do
			local a, b = lo[i], hi[i]
			for j = max(0, i - W), min(n, i + W) do
				if lo[j] < a then a = lo[j] end
				if hi[j] > b then b = hi[j] end
			end
			env.lo[i], env.hi[i] = a - pad, b + pad
		end
	end
	-- s.at(u): vc, hw, wq, Dl, Du; s.at2(u): vc, hw; s.hwAt(u): hw; s.atShore(u): both shores' slopes and the damping
	-- (coves lower and upper shore, capes), read only for nodes near the shore; s.env(u): the water's reach (lo, hi)
	local function at(u)
		local f = (min(u1, max(u0, u)) - u0) / TABLE_STEP
		local i = min(n - 1, floor(f))
		local a = f - i
		local b = 1 - a
		return b * t.vc[i] + a * t.vc[i + 1], b * t.hw[i] + a * t.hw[i + 1], b * t.wq[i] + a * t.wq[i + 1],
			b * t.Dl[i] + a * t.Dl[i + 1], b * t.Du[i] + a * t.Du[i + 1]
	end
	local function at2(u)
		local f = (min(u1, max(u0, u)) - u0) / TABLE_STEP
		local i = min(n - 1, floor(f))
		local a = f - i
		local b = 1 - a
		return b * t.vc[i] + a * t.vc[i + 1], b * t.hw[i] + a * t.hw[i + 1]
	end
	local function hwAt(u)
		local f = (min(u1, max(u0, u)) - u0) / TABLE_STEP
		local i = min(n - 1, floor(f))
		local a = f - i
		return (1 - a) * t.hw[i] + a * t.hw[i + 1]
	end
	local function envAt(u)
		local i = min(n - 1, floor((min(u1, max(u0, u)) - u0) / TABLE_STEP))
		return min(env.lo[i], env.lo[i + 1]), max(env.hi[i], env.hi[i + 1])
	end
	local function atShore(u)
		local f = (min(u1, max(u0, u)) - u0) / TABLE_STEP
		local i = min(n - 1, floor(f))
		local a = f - i
		local b = 1 - a
		return b * t.sl[i] + a * t.sl[i + 1], b * t.su[i] + a * t.su[i + 1], b * t.dl[i] + a * t.dl[i + 1],
			b * t.du[i] + a * t.du[i + 1], b * t.dc[i] + a * t.dc[i + 1]
	end
	return at, atShore, at2, hwAt, envAt
end

-- the sounds' outline at u (before the narrows): centre offset vc, half-width hw, room Dl, Du. Beyond the strait's
-- ends (a diagonal's corners lie there) the room, the end widening and the bends keep their end values, but each shore
-- still swells: held at its end values, a shore ran on dead straight into the corner
local function soundAt(s, u, design)
	local C = M.STRAIT
	local uc = min(s.u1, max(s.u0, u))
	local Dl, Du = s.room(uc)
	local D = Dl + Du
	local e = abs(2 * (uc - s.u0) / s.L - 1) -- 0 at the middle, 1 at the ends
	-- each shore swells on its own (about +-50 %), so a sound is no mirror image about its middle; wider at both ends;
	-- at least soundMin (or 0.85 x the design where the map is narrow); each half no wider than its bank's limit (a soft
	-- cap, so a swollen shore bends onto the limit instead of meeting it at a corner)
	local ends = 1 + (s.ends - 1) * smoothstep(0.82, 1.0, e)
	local floorA, cornerA, cornerW = min(0.85 * s.hb, C.soundMin), math.huge, 0
	if s.diag then -- the corner wedges (the limit wanders by up to cornerWander of hwEnd, never wider: shore())
		cornerA = s.hwEnd + 1e5 * (1 - smoothstep(0.6, 0.9, e))
		cornerW = C.cornerWander * s.hwEnd
	end
	-- towards a narrows the sound swells no wider than its design (a funnel), so the headland need not reach across a
	-- swollen sound (a symmetric pinch with steep flanks where the room along the strait is short)
	local fw, fu = 0, u
	for _, fn in ipairs(s.funnels) do
		local a = abs(u - fn.u)
		local len = u < fn.u and fn.len[1] or fn.len[2]
		local w = 1 - smoothstep(0.3 * len, len, a)
		if w > fw then fw, fu = w, fn.u end
	end
	-- each bank's limit: the water takes at most (1 - keep) of the room on its side of the axis, keep = 2 bankMin raised
	-- by a slow wander of its own per bank (up to bankWander): on a straight strait (Dl = Du = D / 2) each bank keeps
	-- bankMin of the cross distance and up to (1 + bankWander) x that. Relative to each side's own room, not to the cross
	-- distance: on a diagonal the room either side changes along the strait, and a limit of bankMin x D measured from the
	-- map edge drew the shore parallel to that edge (square basins with north-south and east-west walls, look review
	-- 2026-10-12); the wander keeps a shore held at its limit from running straight (a fixed limit ran straight for 2-4 km
	-- along the sounds of 1:3 and 1:5 strips)
	-- (inside a narrows' funnel the wander holds its value at the narrows: wandering there, a bank limit held by a bend
	-- set the sounds either side at different heights, and the channel between them ran obliquely to the strait)
	local keep = 2 * C.bankMin
	local uw = u + (fu - u) * fw - s.u0
	-- (the wander as a logistic curve of its noise, never held at a bound: clamped, it sat at 0 or 1 wherever the noise
	-- ran past +-0.31, and a shore held by its bank's limit ran straight for 2 km beside a diagonal's corner, review
	-- round 3)
	local limL = (1 - keep * (1 + C.bankWander / (1 + exp(-4 * s.bankL(uw + 70000))))) * Dl
	local limU = (1 - keep * (1 + C.bankWander / (1 + exp(-4 * s.bankU(uw + 90000))))) * Du
	-- an inner sound (between two narrows) is at most basinShare of the way between their channels wide (its design) and
	-- swells at most swellIn, so it is at least twice as long as wide (review 2026-10-13, round 3: inner sounds as wide
	-- as long, 4.5-5.5 km between narrows 6-7 km apart, read as round ponds joined by canals); the limits fade out over
	-- basinBlend either side of a narrows, so an outer sound keeps the design (it opens to the sea)
	local hbU, swMax, swMin = s.hb, C.swellMax, C.swellMin
	if #s.basins > 0 and not design then
		local inv, wIn = 0, 0
		for _, bs in ipairs(s.basins) do
			local w = smoothstep(bs.a - C.basinBlend, bs.a + C.basinBlend, u) * (1 - smoothstep(bs.b - C.basinBlend,
				bs.b + C.basinBlend, u))
			if w > 0 then inv, wIn = inv + w / bs.cap, max(wIn, w) end
		end
		if inv > 0 then hbU = smin(s.hb, 1 / inv, 0.1 * s.hb) end
		swMax = swMax - (swMax - C.swellIn[2]) * wIn
		swMin = swMin + (C.swellIn[1] - swMin) * wIn
	end
	-- (the swell spreads over its range as a logistic curve, kMin + (kMax - kMin) / (1 + exp(-(swellS f + b))), b so
	-- that f = 0 gives the design: the noise stays within about +-0.6, so neither bound is held for long. A hard clamp
	-- held a shore at its bound wherever the noise ran past it (the -15 % bound wherever f < -0.1: a third of the
	-- strait), and in an inner sound, whose bounds are close, that drew straight shores, 11.5 % of a 16 km diagonal's
	-- shore within 40 m of a line over 1.5 km, review round 3; a tanh bound, tried, still held it near the -15 % bound
	-- for f < -0.15, and a gentler curve (swellS 4) varied a third as much near the design: straight shores on long
	-- strips. The corner wedge's limit on a diagonal wanders too, so the shore held by it does not run straight into
	-- the corner)
	local function tanh(x) local e2 = exp(2 * x); return (e2 - 1) / (e2 + 1) end
	local function shore(f, lim, hbX, kMax, kMin)
		local p0 = (1 - kMin) / (kMax - kMin)
		local k = kMin + (kMax - kMin) / (1 + exp(-(C.swellS * f + math.log(p0 / (1 - p0)))))
		k = k - (k - min(k, C.funnelK)) * fw
		local cap = min(lim, cornerA - (1 - C.cornerWander * (0.5 + 0.5 * tanh(3 * f))) * cornerW)
		return min(cap, max(floorA, smin(hbX * ends * k, cap, 0.1 * cap)))
	end
	local fL, fU = s.swellL(u - s.u0 + 30000), s.swellU(u - s.u0 + 50000)
	local aL, aU = shore(fL, limL, s.hb, C.swellMax, C.swellMin), shore(fU, limU, s.hb, C.swellMax, C.swellMin)
	-- bends: one or two big ones plus slow noise (the diagonals keep their ends on the designed entry points),
	-- clamped softly to the banks' limits (by the design's shores, so the bend runs on unchanged through a narrows
	-- into an inner sound: by the inner sound's narrower shores the clamp let its centre jump 1 km sideways within
	-- 600 m, and the channel turned across the strait)
	local raw = s.bendA * (sin(2 * pi * uc / s.bendWl + s.phase) + 0.9 * s.bendC(uc + 20000)) - s.bendMean
	if s.diag then raw = raw * (1 - smoothstep(0.45, 1.0, e)) end
	local cLo, cHi = aL - limL, limU - aU
	local k = 0.25 * max(1, cHi - cLo)
	local c = smin(smax(raw, cLo, k), cHi, k)
	c = min(cHi, max(cLo, c))
	-- (an inner sound: each shore closer to the bend line; within the bank limits, as the design's shores are)
	if hbU < s.hb or swMax < C.swellMax then
		aL, aU = shore(fL, limL, hbU, swMax, swMin), shore(fU, limU, hbU, swMax, swMin)
	end
	-- (5th and 6th values, for the tools only: whether each shore lies at its bank's limit, within 3 %)
	return c + 0.5 * (aU - aL), 0.5 * (aL + aU), Dl, Du, aL - c >= 0.97 * limL, c + aU >= 0.97 * limU
end

-- a wall's closing over its length (x = 0 at the channel's core, 1 where it meets the sound's shore): (1 - xs)^2 with
-- xs a soft |x| (sqrt(x^2 + e^2) - e, scaled to 1 at x = 1): a rounded tip (radius e x len^2 / (2 x reach)), the wall
-- leaving it at 2 x reach / len and curving into the sound's shore. (Review 2026-10-13, round 3: the smoothstep drawn
-- before is flat at the tip, so the channel ran on at nearly its full narrowness for 1.2-2.4 km, a canal)
local function wallF(x, e)
	if x >= 1 then return 0 end
	local r = 1 - (math.sqrt(x * x + e * e) - e) / (math.sqrt(1 + e * e) - e)
	return r * r
end

--[[ The strait at u: centre offset vc (v of the axis of the water), half-width hw, narrows weight wq (1 in a channel,
  0 in the sounds), and the room Dl, Du from the axis line to the map edge below and above (cross distance Dl + Du). ]]
function M.straitAt(s, u)
	local C = M.STRAIT
	local uc = u -- (beyond its ends the narrows' flanks run on: on a short crossing they meet the map edge)
	local vc, hw, Dl, Du = soundAt(s, u)
	-- narrows: the main headland (from bank nr.side: -1 the lower shore, 1 the upper) closes the sound to a channel of
	-- 2 t together with a gentler bulge of the other shore. Each wall keeps its full reach over the channel's core, then
	-- falls back to the sound's shore over its own length on either side (wallF: a rounded tip of about tipRadius,
	-- flanks curving into the sound, no square corner). (Tried in review round 2 and dropped: a hyperbolic wall with a set
	-- tip radius under ~280 m and flanks 0.7-1.05 x the reach: a crossing at the tip, oblique to the strait, met the
	-- headland's other flank within 400-800 m. The flanks now leave the tip at 46-55 degrees to the strait)
	-- (the channel's place and width come from the design's sound, without the inner sounds' limits: by the limited
	-- sound, which narrows across a narrows, the channel ran obliquely and came out 1.7 x as wide)
	local vcD, hwD = vc, hw
	if #s.basins > 0 then vcD, hwD = soundAt(s, u, true) end
	local wq = 0
	local lo, hi = vc - hw, vc + hw
	for _, nr in ipairs(s.narrows) do
		local du = uc - nr.u
		local a = abs(du)
		local sd = du < 0 and 1 or 2
		-- (each wall bows out over its length: + bow x sin^2, so no flank is the curve of a formula alone)
		local xM = min(1, max(0, (a - nr.core) / nr.lenM[sd]))
		local xO = min(1, max(0, (a - nr.core) / nr.lenO[sd]))
		local sM, sO = xM < 1 and sin(pi * xM) or 0, xO < 1 and sin(pi * xO) or 0
		local wM = wallF(xM, nr.eM[sd]) + nr.bowM[sd] * sM * sM
		local wO = wallF(xO, nr.eO[sd]) + nr.bowO[sd] * sO * sO
		if wM > 0 or wO > 0 then
			local half = hwD
			-- the channel lies away from the main headland's bank by asym x the closing; where it runs obliquely to the
			-- frame (the sound's centre or width changes along it), its half-width in v is t / cos of its course, so it
			-- is 2 t wide across its course (a channel 370 m wide in v came out 288 m across on an 8 km diagonal)
			local function centre(u2)
				local v2, h2 = soundAt(s, u2, true)
				return v2 - nr.side * nr.asym * (h2 - min(nr.t, h2))
			end
			local slope = (centre(uc + 8) - centre(uc - 8)) / 16
			local tN = min(nr.t * math.sqrt(1 + slope * slope), half)
			local ct = vcD - nr.side * nr.asym * (half - tN)
			local wLo, wHi = wM, wO
			if nr.side > 0 then wLo, wHi = wO, wM end
			lo = lo + (ct - tN - lo) * wLo
			hi = hi + (ct + tN - hi) * wHi
			-- each wall wanders along its flank (1-2 waves of a few per cent of the headland's reach, nothing at the
			-- channel: x sin^2): a flank drawn by a formula alone ran straight for 2-3 km at any Coast roughness
			-- (waves no shorter than wobWl and no higher than a tenth of the flank: on a small headland's short flank the
			-- waves made a narrow cove beside the landing)
			local P = max(nr.P, C.wobFloor)
			local lM, lO = nr.lenM[sd], nr.lenO[sd]
			local gM = min(nr.wob[sd] * P, 0.1 * lM) * sM * sM
				* sin(2 * pi * min(max(nr.wobN[sd], lM / C.wobLong), lM / C.wobWl) * xM + nr.wobPh[sd])
			local gO = min(nr.wob[sd + 2] * P, 0.1 * lO) * sO * sO
				* sin(2 * pi * min(max(nr.wobN[sd + 2], lO / C.wobLong), lO / C.wobWl) * xO + nr.wobPh[sd + 2])
			if nr.side < 0 then lo, hi = lo + gM, hi - gO else lo, hi = lo + gO, hi - gM end
			wq = max(wq, min(wLo, wHi))
		end
	end
	-- the walls' slope limit (straitSetup, s.lim: only ever more land, never past the channel)
	local Lm = s.lim
	if Lm and u >= Lm.u0 and u <= Lm.u1 then
		local f = (u - Lm.u0) / TABLE_STEP
		local i = min(Lm.n - 1, floor(f))
		local a = f - i
		lo = max(lo, (1 - a) * Lm.lo[i] + a * Lm.lo[i + 1])
		hi = min(hi, (1 - a) * Lm.hi[i] + a * Lm.hi[i + 1])
	end
	return 0.5 * (lo + hi), 0.5 * (hi - lo), wq, Dl, Du
end

--[[ (u, v) of a map point in the strait's design frame, and its distance r to the nearest narrows' channel centre. The
  sounds are drawn through a smooth warp (along the strait up to warp x the sound's half-width, across warpSide x it,
  wavelength about one sound width), so the sounds' outlines are curves, not mirror images. No warp near a narrows'
  channel nor where the strait is narrow enough for the lane: the channel keeps its designed width and the lane always
  runs in the water. ]]
local function straitFrame(s, X, Y)
	local C = M.STRAIT
	local dx, dy = X - s.cx, Y - s.cy
	local u, v = dx * s.ca + dy * s.sa, -dx * s.sa + dy * s.ca
	local r = throatDist(s, X, Y)
	local g = smoothstep(C.warpCore, C.warpReach, r)
	-- (beyond the furthest the water can reach the warp fades out over warpFade: it shapes only the outline, and the
	-- land's frame far from it costs less without it, review round 3: generation time)
	if g > 0 and s.env then
		local eLo, eHi = s.env(u)
		local beyond = max(eLo - v, v - eHi)
		if beyond > 0 then g = g * (1 - smoothstep(0, C.warpFade, beyond)) end
	end
	if g > 0 then
		g = g * smoothstep(C.laneHw, C.laneHw + C.warpHw, s.hwAt(u))
		if g > 0 then
			local wx, wy = s.warp(X, Y)
			u = u + C.warp * s.hb * g * min(1, max(-1, wx))
			v = v + C.warpSide * s.hb * g * min(1, max(-1, wy))
		end
	end
	return u, v, r
end

local function straitSetup(cw, ch, r, seed, ragScale, variant, cell)
	local C = M.STRAIT
	local s = {}
	local q = noise.rng(noise.derive(seed, "strait"))
	s.edge = noise.perlin(noise.derive(seed, "edge"))
	s.n = noise.perlin(noise.derive(seed, "land"))
	s.ragScale = ragScale or 1
	s.diag = variant ~= nil and variant.diagonal == true
	cell = cell or 32
	s.cell = cell
	s.narrows, s.islands, s.funnels, s.basins = {}, {}, {}, {}
	-- the sound half-width for a cross distance D
	local function halfWidth(D)
		-- (on maps under ~2.5 km across the 700 m least width would leave each bank under 35 %: 0.28 D of water there;
		-- under 7 km across the share grows to widthSmall by 4 km: sounds of 0.2 D, 700-900 m there, were barely twice a
		-- narrows wide, so the strait read as an even river with straight shores, review 2026-10-12, round 2)
		local share = C.width + (C.widthSmall - C.width) * (1 - smoothstep(4000, 7000, D))
		return min(0.5 * min(C.widthMax, max(C.widthMin, share * D)), 0.14 * D)
	end
	s.cx = 0.5 * cw
	local th = 0
	if s.diag then
		-- enter at 15-20 % of the west edge, or higher where the land wedge in the corner would stay under C.wedge (the
		-- water there is endsDiag x the sound wide); leave at the mirror point of the east edge
		s.cy = 0.5 * ch
		local a = q:range(0.15, 0.2) * ch
		local wedge = min(C.wedge, 0.3 * ch)
		local Y0 = a
		for _ = 1, 4 do
			th = math.atan2(ch - 2 * Y0, cw)
			local hb = halfWidth(ch / math.cos(th))
			Y0 = min(0.5 * ch, max(a, wedge + C.endsDiag * hb / math.cos(th)))
		end
		th = math.atan2(ch - 2 * Y0, cw)
		s.hwEnd = max(0, (Y0 - wedge) * math.cos(th))
		s.ends = C.endsDiag
	else
		-- centred, so the banks share the map evenly (an offset of +-3 % cost each bank 0.03 of its median share)
		s.cy = 0.5 * ch
		q:next() -- (the offset's draw, kept so the numbers drawn after it stay those the type was tuned with)
		s.ends = C.ends
	end
	s.ca, s.sa = math.cos(th), sin(th)
	s.u0, s.u1 = -s.cx / s.ca, (cw - s.cx) / s.ca
	s.L = s.u1 - s.u0
	-- room across: constant for a straight strait; for a diagonal measured at its middle 70 % (its ends lie in the
	-- corners, whose wedges the entry point keeps)
	local function roomAt(u)
		local px, py = s.cx + u * s.ca, s.cy + u * s.sa
		return rayExit(px, py, s.sa, -s.ca, cw, ch), rayExit(px, py, -s.sa, s.ca, cw, ch)
	end
	if s.diag then
		local a, b = s.u0 + 0.15 * s.L, s.u1 - 0.15 * s.L
		s.room = function(u) return roomAt(min(b, max(a, u))) end
	else
		local Dl, Du = roomAt(0)
		s.room = function() return Dl, Du end
	end
	local Dl0, Du0 = roomAt(0)
	s.D = Dl0 + Du0
	-- (on a short crossing, a strait across the short side of a strip, the sounds are at most shortHb x its length wide
	-- on either side: 4.8 km sounds on an 8.2 km strait left it all hourglass, its channel a straight canal 3 km long)
	s.hb = min(halfWidth(s.D), max(0.5 * C.widthMin, C.shortHb * s.L))
	-- (a diagonal's headland flanks are longer, so less of each sound keeps its full width: widthDiag x the design)
	if s.diag then s.hb = s.hb * C.widthDiag end
	-- each shore's own swell (wavelength about 3 sound half-widths, at least 2.2 km)
	local swl = max(2200, 3 * s.hb)
	s.swellL = curve(noise.perlin(noise.derive(seed, "straitwidth")), swl, 3)
	s.swellU = curve(noise.perlin(noise.derive(seed, "straitwidth2")), swl, 3)
	-- each bank limit's wander (soundAt; wavelength about 4 sound half-widths, at least 2.5 km)
	s.bankL = curve(noise.perlin(noise.derive(seed, "straitbank1")), max(2500, 4 * s.hb), 2)
	s.bankU = curve(noise.perlin(noise.derive(seed, "straitbank2")), max(2500, 4 * s.hb), 2)
	-- bends (wavelength in sound widths, at least 0.6 and at most 2 x the strait's length)
	s.bendA = q:range(C.bendAmp[1], C.bendAmp[2]) * s.D
	s.bendWl = min(2 * s.L, max(0.6 * s.L, q:range(C.bendWl[1], C.bendWl[2]) * 2 * s.hb))
	-- no steeper than the bends of a square map: on a short crossing (a strait shorter than the map is wide) a tenth of
	-- the cross distance over half a wavelength turned the whole strait sideways
	s.bendA = min(s.bendA, C.bendSlope * s.bendWl)
	-- a diagonal already runs at 25-35 degrees to the map edges: its full bends turned stretches of it north-south or
	-- east-west (a 28.7 km diagonal swung 2.4 km across over 2.1 km along)
	if s.diag then s.bendA = s.bendA * C.bendDiag end
	s.phase = q:range(0, 2 * pi)
	s.bendC = curve(noise.perlin(noise.derive(seed, "straitbend")), 0.35 * s.bendWl, 3)
	-- narrows: one per ~7 km of the strait's middle (1-4; counted over all but endZone at either end), and no closer
	-- than basinMin sound widths; their places first: the room either side (a share of the way to the neighbouring
	-- narrows; beyond the outer ones the flanks may run on past the strait's end: on a short crossing the shores converge
	-- from the map edges) sets each one's funnel and its flanks. (Counted over the whole length, as first built, a 16 km
	-- diagonal got 3 narrows 4.7-5.1 km apart: basins as long as wide, read as a chain of ponds; 4 narrows 6.1 km apart
	-- on a 28.7 km diagonal, whose sounds are 4.8 km wide, drew square basins.) Spread evenly over the whole strait,
	-- each outer sound half as long as an inner one (review 2026-10-13, round 3: spread over the middle 76 %, the inner
	-- sounds were 6.2 km long on 16 km squares, too short to be twice as long as wide at 0.15 x the cross distance), at
	-- most +-5 % off (+-20 % drew inner sounds 4.5 km long, +-10 % a 16 km diagonal's inner sound of 0.139 D)
	local span = (1 - 2 * C.endZone) * s.L
	local nN = min(C.maxNarrows, max(1, floor(span / C.every + 0.5)), max(1, floor(span / (C.basinMin * 2 * s.hb))))
	local step = s.L / nN
	local jit = max(0, min(0.05 * step, 0.5 * (step - C.gap)))
	local us, room = {}, {}
	for k = 1, nN do us[k] = s.u0 + step * (k - 0.5) + q:range(-jit, jit) end
	s.funnels = {}
	for k = 1, nN do
		-- (the way to the next narrows on either side; beyond the outer ones to the strait's end and a sound's half-width on)
		room[k] = { k > 1 and us[k] - us[k - 1] or (us[k] - s.u0 + s.hb) / C.room,
			k < nN and us[k + 1] - us[k] or (s.u1 - us[k] + s.hb) / C.room }
		s.funnels[k] = { u = us[k], len = { C.room * room[k][1], C.room * room[k][2] } }
	end
	-- the inner sounds' limits (soundAt): between narrows k and k + 1 at most basinShare x the way between them wide
	for k = 1, nN - 1 do s.basins[k] = { a = us[k], b = us[k + 1], cap = 0.5 * C.basinShare * (us[k + 1] - us[k]) } end
	s.bendMean = 0 -- (centred below, once the funnels are final; the narrows here read only half-widths)
	-- the narrows themselves; the main headland alternates between the banks (the first from the seed)
	local side = (q:next() < 0.5) and -1 or 1
	local narrows = {}
	for k = 1, nN do
		local nr = { u = us[k], t = max(0.5 * q:range(C.throat[1], C.throat[2]), 0.5 * C.throatCells * cell),
			core = max(q:range(C.channel[1], C.channel[2]), C.coreCells * cell), side = side,
			asym = q:range(C.asym[1], C.asym[2]) }
		side = -side
		-- (a diagonal: less off-centre, since the water swings towards the channel and back, and at 25-35 degrees to
		-- the map edges a full swing turned a stretch of it north-south)
		if s.diag then nr.asym = max(C.asymMin, nr.asym * C.asymDiag) end
		-- the main headland's flanks may reach most of the way to the next narrows (whose main headland stands on the
		-- other bank), the other shore's bulge less than half of it
		local avail = { max(200, C.roomMain * room[k][1] - nr.core), max(200, C.roomMain * room[k][2] - nr.core) }
		local availO = { max(200, C.room * room[k][1] - nr.core), max(200, C.room * room[k][2] - nr.core) }
		-- the closing on either side: the sound's half-width just beyond the inner sounds' fade (review round 3: an inner
		-- sound is narrower than an outer one, and walls as long as the wider side's left a longer channel on its side)
		local openS = {}
		for sd = 1, 2 do
			local _, hwS = M.straitAt(s, nr.u + (sd == 1 and -1 or 1) * min(C.basinBlend, 0.5 * room[k][sd]))
			openS[sd] = max(0, hwS - nr.t)
		end
		local open = max(openS[1], openS[2])
		-- the headland's flank: 1.4-1.9 x as long as it reaches out (wallF leaves the tip at 2 x reach / length), long
		-- enough for its rounded tip (at most tipE of the wall); where the room is short the main headland does less of
		-- the closing (down to an even hourglass), so its flanks stay no steeper
		local fk = q:range(C.flank[1], C.flank[2])
		local function flankFor(P) return max(fk * P, math.sqrt(2 * C.tipRadius * P / C.tipE)) end
		for sd = 1, 2 do
			if flankFor((1 + nr.asym) * openS[sd]) > avail[sd] then
				local fit = min(avail[sd] / fk, avail[sd] * avail[sd] * C.tipE / (2 * C.tipRadius))
				nr.asym = max(C.asymMin, min(nr.asym, fit / max(1, openS[sd]) - 1))
			end
		end
		nr.lenM, nr.lenO, nr.bowM, nr.bowO, nr.eM, nr.eO = {}, {}, {}, {}, {}, {}
		nr.P = (1 + nr.asym) * open
		nr.wob, nr.wobN, nr.wobPh = {}, {}, {}
		for w = 1, 4 do
			nr.wob[w], nr.wobN[w], nr.wobPh[w] = q:range(C.wob[1], C.wob[2]), q:range(C.wobN[1], C.wobN[2]), q:range(0, 2 * pi)
		end
		for sd = 1, 2 do
			local open = openS[sd]
			local base = flankFor((1 + nr.asym) * open) * q:range(0.85, 1.15)
			nr.lenM[sd] = min(avail[sd], base)
			nr.lenO[sd] = min(availO[sd], base * q:range(C.oppLen[1], C.oppLen[2]))
			nr.bowM[sd] = q:range(C.bowM[1], C.bowM[2])
			nr.bowO[sd] = q:range(C.bowO[1], C.bowO[2])
			-- on a diagonal (axis th above the map's x axis) a wall that rises towards the channel (dv/du > 0: the lower one
			-- before the narrows, the upper one after it) lies at th + its own angle to the map's x axis: 51-68 degrees steep,
			-- it ran north-south on a square map (with the falling one east-west: square basins). That wall is made longer,
			-- so it lies no steeper than flankMapMax (as far as the room allows); the falling one keeps its length, so the
			-- water still opens quickly beyond the channel (both long drew 1.2 km wedge-shaped canals)
			if s.diag then
				local amax = max(C.flankRelMin, C.flankMapMax - th)
				if (nr.side < 0) == (sd == 1) then
					nr.lenM[sd] = min(avail[sd], max(nr.lenM[sd], (1 + nr.asym) * open / math.tan(amax)))
				else
					nr.lenO[sd] = min(availO[sd], max(nr.lenO[sd], (1 - nr.asym) * open / math.tan(amax)))
				end
			end
			-- each wall's tip rounding (wallF): radius tipRadius, at most tipE of the wall
			nr.eM[sd] = min(C.tipE, 2 * C.tipRadius * (1 + nr.asym) * open / (nr.lenM[sd] * nr.lenM[sd]))
			nr.eO[sd] = min(C.tipE, 2 * C.tipRadius * max(1, (1 - nr.asym) * open) / (nr.lenO[sd] * nr.lenO[sd]))
		end
		narrows[k] = nr
	end
	-- each funnel reaches 1.3 x the longer wall on its side, at most the share of the way to the next narrows set above
	-- (review 2026-10-12, round 2: funnels over 45 % of the way between narrows 4.7-7 km apart held the sounds at their
	-- design width almost everywhere, so a narrower swell drew sounds of 0.13-0.15 D on 16 km diagonals); the narrows'
	-- own half-width does not depend on it (the funnel is full at the narrows either way)
	for k, nr in ipairs(narrows) do
		local fn = s.funnels[k]
		for sd = 1, 2 do
			fn.len[sd] = min(fn.len[sd], C.funnelFlank * max(nr.lenM[sd], nr.lenO[sd]))
		end
	end
	-- the bends are centred so that each bank's median room (from its shore to the map edge, over 200 sections) is the
	-- same: neither bank is the smaller one along most of the strait (centring the mean left the smaller bank's median
	-- share at 0.34 on some 8 km maps; half a wavelength over a square map put the whole strait off-centre)
	s.bendMean = 0
	for _ = 1, 3 do
		local lowR, upR = {}, {}
		for i = 0, 199 do
			local u = s.u0 + s.L * (i + 0.5) / 200
			local vc, hw, _, Dl, Du = M.straitAt(s, u)
			lowR[i + 1], upR[i + 1] = Dl + vc - hw, Du - vc - hw
		end
		table.sort(lowR)
		table.sort(upR)
		s.bendMean = s.bendMean + 0.5 * (0.5 * (lowR[100] + lowR[101]) - 0.5 * (upR[100] + upR[101]))
	end
	s.narrows = narrows
	s.hwFloor = math.huge -- the narrowest designed channel: the coast roughness never makes the strait narrower
	for _, nr in ipairs(narrows) do
		s.hwFloor = min(s.hwFloor, nr.t)
		local vc = M.straitAt(s, nr.u)
		nr.X, nr.Y = s.cx + nr.u * s.ca - vc * s.sa, s.cy + nr.u * s.sa + vc * s.ca
	end
	-- how far the map reaches beyond the strait's ends along it (a diagonal's corners; the warp)
	s.ext = 200 + 0.5 * s.D * abs(s.sa) + 1.5 * C.warp * s.hb
	-- the walls' slope limit (review 2026-10-13, round 3): no shore of the outline steeper than wallMax to the strait,
	-- and on a diagonal no wall rising towards the map's y axis steeper than flankMapLim to its x axis (the rising walls
	-- were lengthened only as far as the room allowed, and the sounds' own swell and the other shore's bulge rose too:
	-- a basin's walls ran north-south for 1-1.6 km). Each shore becomes the nearest outline within those slopes that
	-- holds at least as much land (a cone envelope, two passes over 8 m steps), so the limit only ever narrows the water;
	-- never under the narrowest channel plus 40 m where it was wider (M.straitAt reads it)
	do
		local sF = math.tan(C.wallMax)
		local sR = sF
		if s.diag then sR = min(sR, math.tan(max(C.flankRelMin, C.flankMapLim - th))) end
		local u0 = s.u0 - s.ext
		local n = math.ceil((s.u1 + s.ext - u0) / TABLE_STEP)
		local lo, hi, Lo, Hi = {}, {}, {}, {}
		for i = 0, n do
			local vc, hw = M.straitAt(s, u0 + i * TABLE_STEP)
			lo[i], hi[i] = vc - hw, vc + hw
			Lo[i], Hi[i] = lo[i], hi[i]
		end
		local dF, dR = sF * TABLE_STEP, sR * TABLE_STEP
		for i = 1, n do
			Lo[i] = max(Lo[i], Lo[i - 1] - dF) -- (the lower shore falls at most sF along u)
			Hi[i] = min(Hi[i], Hi[i - 1] + dR) -- (the upper shore rises at most sR)
		end
		for i = n - 1, 0, -1 do
			Lo[i] = max(Lo[i], Lo[i + 1] - dR) -- (the lower shore rises at most sR)
			Hi[i] = min(Hi[i], Hi[i + 1] + dF) -- (the upper shore falls at most sF)
		end
		-- (across the water's course: where both shores move the same way the water runs obliquely to the frame, and
		-- the limit on one shore alone left a 224 m crossing beside a channel; three rounds, the course from the result)
		local least = 2 * s.hwFloor + 40
		for _ = 1, 3 do
			for i = 0, n do
				local a, b = max(0, i - 3), min(n, i + 3)
				local m = ((Lo[b] + Hi[b]) - (Lo[a] + Hi[a])) / (2 * max(1, b - a) * TABLE_STEP)
				local w0 = min(hi[i] - lo[i], least * math.sqrt(1 + m * m))
				if Hi[i] - Lo[i] < w0 then
					local dl, dh = Lo[i] - lo[i], hi[i] - Hi[i]
					local k = max(0, (hi[i] - lo[i]) - w0) / max(1e-9, dl + dh)
					Lo[i], Hi[i] = lo[i] + dl * k, hi[i] - dh * k
				end
			end
		end
		s.lim = { u0 = u0, u1 = u0 + n * TABLE_STEP, n = n, lo = Lo, hi = Hi }
	end
	-- islands (1.8-3.5 x as long as wide: the proposal's 2.5-5 x drew thin fingers): at most one per islandEvery metres,
	-- in sounds at least islandSound wide over the island's length, its
	-- ends at least islandGap beyond a narrows' channel; off the axis (the lane passes on the inner side), the outer
	-- channel at least islandChannel wide plus an allowance for the coast roughness, which is damped beside the island
	local qi = noise.rng(noise.derive(seed, "straitislands"))
	for _ = 1, floor(s.L / C.islandEvery) do
		local u = s.u0 + s.L * qi:range(0.1, 0.9)
		local sideI = (qi:next() < 0.5) and -1 or 1
		local _, hw = M.straitAt(s, u)
		local off = hw * qi:range(0.35, 0.5)
		local b = min(hw * qi:range(0.1, 0.22), hw - off - C.islandChannel - C.islandRag)
		local a = b * qi:range(1.8, 3.5)
		local ok = b >= 75
		for _, nr in ipairs(narrows) do ok = ok and abs(u - nr.u) - a >= C.islandGap + nr.core end
		for _, isl in ipairs(s.islands) do ok = ok and abs(u - isl.u) >= C.islandEvery end
		if ok then
			for f = -1, 1, 0.25 do
				local _, hwf, wqf = M.straitAt(s, u + f * a)
				ok = ok and wqf < 0.05 and 2 * hwf >= C.islandSound and hwf - off - b >= C.islandChannel + C.islandRag
			end
		end
		if ok then s.islands[#s.islands + 1] = { u = u, side = sideI, off = off, a = a, b = b } end
	end
	-- one river per bank from beyond its far edge (catchment outside the map), its mouth in a sound away from the
	-- narrows where possible, and away from the strait's ends (an estuary beside the strait's mouth would reach the
	-- map edge on its own)
	s.inflows, s.outlets = {}, {}
	for _, bank in ipairs({ -1, 1 }) do
		local best
		for _ = 1, 8 do
			local X = cw * (s.diag and (bank < 0 and q:range(0.5, 0.85) or q:range(0.15, 0.5)) or q:range(0.25, 0.75))
			local Y = bank < 0 and 0 or ch
			local u = (X - s.cx) * s.ca + (Y - s.cy) * s.sa
			local clear = math.huge
			for _, nr in ipairs(narrows) do clear = min(clear, abs(u - nr.u)) end
			if best == nil or (best.clear < 2500 and clear > best.clear) then best = { X = X, Y = Y, clear = clear } end
		end
		s.inflows[#s.inflows + 1] = { X = best.X, Y = best.Y, area = 0.3 * cw * ch }
	end
	-- the outline warp (straitFrame): two fBm fields normalised to about +-1
	local wl = max(1500, C.warpWl * 2 * s.hb)
	s.warp = latticeWarp(noise.perlin(noise.derive(seed, "straitwarp")), 1 / 0.45, wl, max(64, wl / 12))
	-- the shore noise (straitSea): stronger as the Coast roughness falls below 100 %, so the shores keep their large-scale
	-- shape (at 0 % the headlands' flanks ran straight for 1.5-2 km)
	s.shoreN = noise.perlin(noise.derive(seed, "straitshore"))
	s.shoreA = max(C.shoreMin, s.hb * (C.shoreAmp[1] + (C.shoreAmp[2] - C.shoreAmp[1]) * max(0, 1 - s.ragScale)))
	s.shoreWl = max(800, C.shoreWl * s.hb)
	s.closeMin = C.ragInMin * (1 - smoothstep(4500, 5000, s.D))
	-- plain width per bank along the strait; bank top at the narrows; the land zones on a short crossing
	s.plainLo = curve(noise.perlin(noise.derive(seed, "straitplain1")), 3000, 3)
	s.plainHi = curve(noise.perlin(noise.derive(seed, "straitplain2")), 3000, 3)
	s.bluffTop = q:range(C.bluffTop[1], C.bluffTop[2])
	s.ku = min(1, s.L / C.shortL)
	-- (the drainage bump around a narrows reaches at most 70 % of the way to the strait's end along it: on a 2 km
	-- crossing it reached the map edge, so the rivers ran into the strait's mouth along the edge, review round 3)
	s.kb = min(s.ku, 0.7 * s.L / (2 * C.bumpReach))
	s.edgeR = min(C.edgeReach, C.edgeShare * s.L) -- (the edge bump's reach)
	-- the roughness damping's distances grow with how far the shore can move (the coast roughness and the shore noise
	-- together, against Coast roughness 100 %); never shorter than designed
	s.fadeK = max(1, (M.COAST_RAG * s.ragScale + s.shoreA) / (M.COAST_RAG + max(C.shoreMin, s.hb * C.shoreAmp[1])))
	s.at, s.atShore, s.at2, s.hwAt, s.env = straitTable(s)
	-- the design frame of each node from the sea pass, for the land pass (straitSea, straitLand; by node index)
	s.fu, s.fv, s.fr = {}, {}, {}
	-- the nodes of the designed islands (straitSea); any other land the water surrounds becomes water (build: the coast
	-- roughness cut off stray islets and a block 222 m off a bank, which a bridge could use as a stepping stone)
	s.islandNode, s.dropStrayLand, s.mainSeaOnly = {}, true, true
	-- the axis (canonical metres, every 25 m, beyond both map edges: on a diagonal the centre offset moves its end
	-- along the edge too) with its half-width, narrows weight and lane weight (1 in a channel's core: the lane has the
	-- channel's width there; 0 where it is a fairway); the narrows' indices
	s.axis = { X = {}, Y = {}, hw = {}, wq = {}, lw = {}, narrows = {}, hold = {} }
	local A = s.axis
	local ext = s.ext
	for u = s.u0 - ext, s.u1 + ext, 25 do
		local vc, hw, wq = M.straitAt(s, u)
		local lw = 0
		for _, nr in ipairs(narrows) do
			lw = max(lw, 1 - smoothstep(nr.core + C.laneFull[1], nr.core + C.laneFull[2], abs(u - nr.u)))
		end
		-- (and wherever the strait is within a coarse cell of the narrowest channel's half-width: there the coarse water's
		-- edge, a cell off, set a crossing of 314 m 375 m beyond a narrows' core on 64 m cells, review round 3)
		lw = max(lw, 1 - smoothstep(s.hwFloor + s.cell, s.hwFloor + 2 * s.cell, hw))
		local q_ = #A.X + 1
		-- the map point whose design coordinates are (u, vc): the outline warp moves the water, so the axis (the report's
		-- sections) follows it; a few fixed-point steps (the warp's slope is well under 1)
		local X, Y = s.cx + u * s.ca - vc * s.sa, s.cy + u * s.sa + vc * s.ca
		for _ = 1, 6 do
			local u2, v2 = straitFrame(s, X, Y)
			local eu, ev = u - u2, vc - v2
			if eu * eu + ev * ev < 1 then break end
			X, Y = X + eu * s.ca - ev * s.sa, Y + eu * s.sa + ev * s.ca
		end
		A.X[q_], A.Y[q_], A.hw[q_], A.wq[q_], A.lw[q_] = X, Y, hw, wq, lw
		-- (where a sound's shore lies at its bank's limit: 1 lower, 2 upper, 3 both; strait_check reports the share)
		local _, _, _, _, hL, hU = soundAt(s, u)
		A.hold[q_] = (hL and 1 or 0) + (hU and 2 or 0)
	end
	for k, nr in ipairs(narrows) do A.narrows[k] = floor((nr.u - (s.u0 - ext)) / 25 + 0.5) + 1 end
	return s
end

local function straitSea(s, X, Y, cw, ch, k)
	local C = M.STRAIT
	-- (quick test on the unwarped frame: beyond the furthest the water can reach around this u the node is land; its
	-- frame is then computed by the land pass. The same map, a faster shape stage: review 2026-10-12, 1.17-1.33 x
	-- Coastal Region's time)
	local dx, dy = X - s.cx, Y - s.cy
	local v0 = -dx * s.sa + dy * s.ca
	local eLo, eHi = s.env(dx * s.ca + dy * s.sa)
	if v0 < eLo or v0 > eHi then return false end
	local u, v, r = straitFrame(s, X, Y)
	if k then s.fu[k], s.fv[k], s.fr[k] = u, v, r end
	local vc, hw = s.at2(u)
	local d = abs(v - vc)
	-- islands: ellipses that follow the strait's bends; their shore is moved across it by a share of the coast
	-- roughness and a noise of their own, at most islandRag metres (the channels keep their 300 m), so an island is no
	-- smooth finger
	for _, isl in ipairs(s.islands) do
		local du = (u - isl.u) / isl.a
		if abs(du) < 1.3 then
			local dv = (v - vc - isl.side * isl.off) / isl.b
			local e = (math.sqrt(du * du + dv * dv) - 1) * isl.b -- about the distance from the outline (m)
			if e < C.islandRag then
				local m = 0.5 * rag(s, X + 7000, Y) + 0.35 * isl.b * noise.fbm(s.edge, X / 600 + 300, Y / 600, 4, 0.55)
				if e < min(C.islandRag, max(-C.islandRag, m)) then
					if k then s.islandNode[k] = true end -- (a designed island: build keeps it, M.dropStrayLand)
					return false
				end
			end
		end
	end
	if d < 0.5 * hw then return true end -- the middle half is always water: the strait can never close
	-- the coast roughness and the shore noise: none in the narrows' channels, damped beside the islands; across the
	-- shore (a shift in v alone slides along a headland's flank, which runs nearly across the strait: x the flank's
	-- stretch, at most 3); closing a sound by at most about ragIn of its half-width (a smooth limit), and the water
	-- never narrower than the narrowest channel plus a coarse cell (the grid and the shore smoothing take up to a cell
	-- off each shore where the lane is only a fairway) ACROSS ITS COURSE: past a headland's tip the water runs
	-- obliquely to the frame, so that floor in v is divided by the cosine of its course (a floor in v alone left 256-296 m
	-- crossings on 64 m cells)
	-- (normalised fBm stays within +-1: beyond the furthest the noises can move the shore the point is land, and nothing
	-- more need be computed; the same map, a faster shape stage)
	if d > hw + 3 * (M.COAST_RAG * s.ragScale + s.shoreA) then return false end
	local sl, su, dampLo, dampHi, dampOut = s.atShore(u)
	local slope, damp = sl, dampLo
	if v >= vc then slope, damp = su, dampHi end
	-- around each narrows' channel (by the distance r to its centre, x s.fadeK: the stronger the shore moves, the
	-- further) coves and capes are held off, so the landings stay whole: a cove beside a headland's tip made a thin
	-- finger of it, a cape beside the channel the narrowest crossing (review 2026-10-12, rounds 1 and 2). By distance,
	-- not by the place along the strait as first built, so a headland's flank is rough beyond the tip's surroundings
	-- (held smooth for its whole height, a steep flank ran straight)
	local fk = s.fadeK
	damp = max(damp, 1 - smoothstep(C.coveR[1] * fk, C.coveR[2] * fk, r))
	dampOut = max(dampOut, 1 - smoothstep(C.capeR[1] * fk, C.capeR[2] * fk, r))
	local stretch = min(3, math.sqrt(1 + slope * slope))
	local rg = (rag(s, X, Y) + s.shoreA * noise.fbm(s.shoreN, X / s.shoreWl, Y / s.shoreWl, 3, 0.5)) * stretch
	rg = rg * (1 - (rg > 0 and damp or dampOut))
	if rg < 0 then
		-- (a smooth limit of a quarter of the half-width, but at least ragInMin metres (up to ragInSmall of the half-width)
		-- where the sound is narrow: a quarter saturated on sounds 600-900 m wide (maps 3.5-5 km across), so wherever the
		-- noise ran negative the shore lay within 60 m of a line for 2-5 km, review 2026-10-12, round 2. The floor below
		-- still keeps the water wider than a channel)
		local cap = max(C.ragIn * hw, min(C.ragInSmall * hw, s.closeMin)) * stretch
		local e2 = math.exp(-2 * rg / cap)
		rg = -cap * (e2 - 1) / (e2 + 1) -- -cap * tanh(-rg / cap)
	end
	local course = 0.5 * (sl + su)
	local hwEff = max(hw + rg, min(hw, (s.hwFloor + 10 + s.cell) * math.sqrt(1 + course * course)))
	return d < hwEff
end

local function straitLand(s, X, Y, cw, ch, dist, k)
	local C = M.STRAIT
	local u, v, r
	if k and s.fu[k] then u, v, r = s.fu[k], s.fv[k], s.fr[k] else u, v, r = straitFrame(s, X, Y) end
	local vc, hw, _, Dl, Du = s.at(u)
	-- (a short crossing: the land zones shrink along the strait; the drainage bump by kb)
	local rB = r
	if s.kb < 1 then r, rB = throatDist2(s, X, Y, s.ku, s.kb) end
	local D = s.D
	local d = min(dist, 0.5 * D) / D
	local n = noise.fbm(s.n, X / 2600, Y / 2600, 5, 0.5)
	-- B rises inland (every river drains to the strait); a bump around each narrows sends the streams to the sounds, and
	-- one along the two edges the strait meets keeps the rivers' mouths off them (a river ran along the edge into the
	-- strait's mouth on 25 of 72 maps, review 2026-10-12)
	-- (the zones' terms are skipped beyond their reach: most nodes, a faster shape stage)
	local B = 120 * d + 50 * n
	if rB < C.bumpReach then B = B + C.bump * nearThroat(rB, C.bumpCore, C.bumpReach) end
	local xe = min(X, cw - X)
	if xe < s.edgeR then B = B + C.edgeBump * (1 - smoothstep(0, s.edgeR, xe)) end
	local U = 0.25 + 0.8 * smoothstep(0.03, 0.3, d) + 0.35 * (n + 0.5)
	-- shore plain width: per bank, none near the narrows, at most plainBank of the bank (islands: the narrowest plain)
	local wp
	local plainOff = r < C.plainReach and nearThroat(r, C.plainCore, C.plainReach) or 0
	if plainOff >= 1 then
		wp = 0 -- (no plain this close to a narrows)
	elseif abs(v - vc) < hw then
		wp = C.plain[1]
	else
		local up = v > vc
		local c = (up and s.plainHi or s.plainLo)(u + 40000)
		wp = C.plain[1] + (C.plain[2] - C.plain[1]) * min(1, max(0, 0.5 + 1.5 * c))
		local bank = up and (Du - vc - hw) or (Dl + vc - hw)
		wp = min(wp, C.plainBank * max(0, bank))
	end
	wp = wp * (1 - plainOff)
	-- graded banks around each narrows' channel (landform.lua: the bluff, then the pass grade)
	local bluff
	if s.ku < 1 then bluff = bluffShort(s, X, Y)
	else bluff = r < C.bluffReach and nearThroat(r, C.bluffCore, C.bluffReach) or 0 end
	return B, max(U, 0.08), nil, wp, bluff
end

M.TYPES.sea_strait = {
	label = "Sea Strait",
	-- the strait is the ship water (as on Large Bays): no ship river by default; a steeper shelf than Coastal Region's,
	-- made steeper again after the shore smoothing (shelf.steep, landform.lua: harbour depth close to the shore);
	-- lakeOpen: no lake tails; lakeInland: no lake on the map border (landform.lua)
	preset = { relief = 1.0, ships = 0, shelf = { slope = 0.06, max = 40, steep = 3 }, lakeOpen = true, lakeInland = true,
		lakes = 0.8,
		rivers = 1.0, meander = 1.0, valley = 1.5, estuary = 1200, channels = 1.0, uplands = 1.0 },
	setup = straitSetup,
	sea = straitSea,
	land = straitLand,
}

M.TYPES.great_river_valley.label = "Great River Valley"
M.TYPES.delta_lowlands.label = "Delta Lowlands"
M.TYPES.mountain_passes.label = "Mountain Range with Passes"

-- One-line descriptions (shown under the Map type field) and the Terrain parameters a map type has nothing for
-- (`inactive`: the window says so next to the slider). Text only: no effect on the terrain. The inactive lists come
-- from the offline settings test (2026-10-08: the slider at 0 % and at its maximum gave the identical map at 11 km).
local INFO = {
	great_river_valley = { "One big river crosses the map in a broad valley between uplands and reaches the sea (or, with Sea None, leaves the map)." },
	delta_lowlands = { "A wide, flat coastal plain; the river splits into several channels across a delta." },
	mountain_passes = { "One continuous mountain belt (snow from Hilly up) with two graded passes and foothills; sea on one side or none." },
	alpine = { "Snow-capped massifs scattered over high ground, valleys between them and two graded passes; sea on one side or none." },
	rolling_plains = { "Inland, no sea: gentle swells and a big navigable river crossing the map.", { "coast" } },
	lake_district = { "Inland hill country with long, narrow lakes strung along the rivers.", { "coast" } },
	large_bays = { "A coast cut by two or three deep, sheltered bays with rivers at their heads." },
	peninsulas = { "A mainland with two or three long peninsulas reaching into the sea." },
	island_chain = { "Islands of different sizes across the sea, with sounds between them; rivers are rare.",
		{ "rivers", "lakes", "meander", "valley" } },
	coastal_region = { "A ragged coast with headlands and coves, a coastal plain and hills inland." },
	highland_plateau = { "A lowland (by the sea or inland), an escarpment and a high, flat plateau cut by river gorges." },
	sea_strait = { "A sea strait splits the map from edge to edge: wide sounds for ships and ferries, a few narrows for bridges, flat shores on both sides." },
}
for id, info in pairs(INFO) do
	M.TYPES[id].description = info[1]
	M.TYPES[id].inactive = info[2] or {}
end

--[[ Feature side (owner 2026-10-08): the player may choose the map edge that gets a map type's defining feature.
  Every type is written in a canonical frame whose low edge (Y = 0) is the sea or the "near" side; `side.edge` says
  which canonical edge the setting names ("low": the sea, or where the rivers go; "high": where the big river comes
  from), `side.label` is the window's label for the choice. Island Chain has no such side. M.SIDES order = the
  setting's values 1..4 (0 or nil = from the seed, as before).
  Sea side None (owner 2026-10-11, value M.SIDE_NONE = 5) on the types with `side.none`, whose sea is a setting rather
  than the feature itself (a delta, bays, peninsulas or a coast need their sea): the map has no sea. The sea's strip
  becomes land that keeps the type's fall towards that edge, every node of the edge is an outlet, so the rivers leave the
  map there as they would reach the sea. The layout (range, massifs, passes, plateau and escarpment) is the one with a
  sea, since setup draws the same numbers; the rivers, valleys and heights can differ, as the new land drains to the
  edge and joins the relief scaling (a little on Mountain Range and Alpine, much more on Highland Plateau, whose land is
  shaped by the distance to the sea). The edge itself comes from the seed (there is no sea to place).
  Sea None on Great River Valley (owner 2026-10-12, REVIEW B8; `side.seaChoice`): its side names where the river COMES
  FROM, so "None" there would read as "no river" and would lose the direction. Its sea is a setting of its own instead
  (pipeline setting `sea` = false; M.noSea / M.inactiveFor / M.build take it): the side keeps its meaning, the sea's
  strip becomes valley as above and the trunk leaves the map at the edge opposite its source.
  `side.default` (a setting value, 0..5; nil = 0, from the seed) is what a host window pre-selects on this type when the
  player has not chosen an edge that carries over: Alpine None (owner 2026-10-13, REVIEW C5: "Sea-side option should
  default to 'None' when Alpine is chosen"; its massifs and passes stand on their own). Only the Studio reads it:
  pipeline.normalise does not, so a request without a side still means "from the seed" and every map made so far is
  unchanged.
  strip becomes valley as above and the trunk leaves the map at the edge opposite its source.
  Strait direction (owner 2026-10-12, REVIEW B10; edge = "axis"): on Sea Strait the box names which way the water runs,
  not an edge: `choices` (values 1..4) and `names` (the settings text, M.sideName); 0 = from the seed. East-West = from
  the west edge to the east edge, land north and south. There is no None: the sea is the feature (as on Coastal Region). ]]
M.SIDES = { "north", "east", "south", "west" }
M.SIDE_NONE = 5
M.AXIS_CHOICES = { "East-West", "North-South", "Diagonal SW-NE", "Diagonal NW-SE" }
M.AXIS_NAMES = { "ew", "ns", "swne", "nwse" }
local SIDE = {
	great_river_valley = { label = "River comes from", edge = "high", seaChoice = true },
	delta_lowlands = { label = "Sea side", edge = "low" },
	mountain_passes = { label = "Sea side", edge = "low", none = true },
	alpine = { label = "Sea side", edge = "low", none = true, default = M.SIDE_NONE },
	rolling_plains = { label = "River comes from", edge = "high" },
	lake_district = { label = "Rivers flow towards", edge = "low" },
	large_bays = { label = "Sea side", edge = "low" },
	peninsulas = { label = "Sea side", edge = "low" },
	coastal_region = { label = "Sea side", edge = "low" },
	highland_plateau = { label = "Sea side", edge = "low", none = true },
	sea_strait = { label = "Strait runs", edge = "axis", choices = M.AXIS_CHOICES, names = M.AXIS_NAMES },
}
for id, sd in pairs(SIDE) do M.TYPES[id].side = sd end

-- The side as the settings text names it (Studio logs, export_check): "north" .. "west", "none" (Sea side None), or the
-- type's own names (Sea Strait: "ew", "ns", "swne", "nwse"); nil for 0 (from the seed)
function M.sideName(typeName, side)
	local T = M.TYPES[typeName]
	local sd = T and T.side
	if sd and sd.names then return sd.names[side] end
	return M.SIDES[side] or (side == M.SIDE_NONE and "none" or nil)
end

-- true when the map has no sea: Sea side None on a type that offers it, or sea = false on a type whose sea is a
-- setting of its own (side.seaChoice: Great River Valley; its side 5 means nothing, normalise never sends it)
function M.noSea(typeName, side, sea)
	local T = M.TYPES[typeName]
	local sd = T and T.side
	if sd == nil then return false end
	if sd.seaChoice then return sea == false end
	return side == M.SIDE_NONE and sd.none == true
end

-- The Terrain parameters without effect on this map type with this side and sea setting (the window shows "-" and names
-- them): the type's own list, plus Coast roughness on a map without sea (no coast to roughen).
function M.inactiveFor(typeName, side, sea)
	local T = M.TYPES[typeName]
	local list = {}
	for _, key in ipairs(T and T.inactive or {}) do list[#list + 1] = key end
	if M.noSea(typeName, side, sea) then
		local has = false
		for _, key in ipairs(list) do has = has or key == "coast" end
		if not has then list[#list + 1] = "coast" end
	end
	return list
end

-- (swap, flipY) that put the canonical low edge on each map side. Local x grows east, y grows north; toLocal flips
-- first, then swaps: low edge -> south (no swap, no flip), north (flipY), west (swap), east (swap + flipY). The high
-- edge lies opposite, so it uses the entry of the opposite side.
local LOW_EDGE_AT = { north = { false, true }, east = { true, true }, south = { false, false }, west = { true, false } }
local OPPOSITE = { north = "south", south = "north", east = "west", west = "east" }

-- orientation 0..7 for a chosen side; the mirror along the feature edge (flipX) stays the seed's, so different seeds
-- still differ
function M.orientationFor(typeName, sideIndex, rolled)
	local T = M.TYPES[typeName]
	local name = M.SIDES[sideIndex or 0]
	if not (T and T.side and name) or T.side.edge == "axis" then return rolled end
	if T.side.edge == "high" then name = OPPOSITE[name] end
	local sf = LOW_EDGE_AT[name]
	return (sf[1] and 4 or 0) + (sf[2] and 2 or 0) + rolled % 2
end

--[[ Orientation of a strait (side.edge "axis") and its variant: 1 East-West (the axis on local x: no swap), 2 North-South
  (swap), 3 / 4 the diagonals SW-NE / NW-SE, along the long side (swap on a tall map). The canonical diagonal rises from
  low Y at X = 0 to high Y at X = cw, so it runs SW-NE exactly when flipX and flipY agree: the seed keeps flipX, flipY
  follows from the choice. 0 = from the seed, with its own draw. The straight choices keep both mirrors of the seed. ]]
function M.axisOrientation(side, rolled, seed, sizeX, sizeY)
	local pick = side or 0
	if pick < 1 or pick > 4 then pick = noise.rng(noise.derive(seed, "straitkind")):int(1, 4) end
	if pick <= 2 then return (pick == 2 and 4 or 0) + rolled % 4, { diagonal = false, pick = pick } end
	local flipX = rolled % 2 == 1
	local flipY = (pick == 4) ~= flipX
	return (sizeY > sizeX and 4 or 0) + (flipY and 2 or 0) + (flipX and 1 or 0), { diagonal = true, pick = pick }
end

-- (new map types go at the END, so the others keep their place in the window's Map type box)
M.ORDER = { "great_river_valley", "delta_lowlands", "mountain_passes", "alpine", "rolling_plains", "lake_district",
	"large_bays", "peninsulas", "island_chain", "coastal_region", "highland_plateau", "sea_strait" }

-- Sea slivers one cell wide (ragged outlines) become land: after smoothing and upsampling they leave sub-zero
-- specks along the shore that no open water reaches (seen 2026-10-06, Peninsulas, Wet). Morphological opening:
-- erode the sea by one cell, then grow it back.
function M.removeSeaSlivers(sea, w, h)
	local core = {}
	for j = 0, h - 1 do
		for i = 0, w - 1 do
			local k = j * w + i + 1
			core[k] = sea[k] and (i == 0 or sea[k - 1]) and (i == w - 1 or sea[k + 1])
				and (j == 0 or sea[k - w]) and (j == h - 1 or sea[k + w])
		end
	end
	for j = 0, h - 1 do
		for i = 0, w - 1 do
			local k = j * w + i + 1
			sea[k] = core[k] or (i > 0 and core[k - 1]) or (i < w - 1 and core[k + 1])
				or (j > 0 and core[k - w]) or (j < h - 1 and core[k + w]) or false
		end
	end
end

-- Land slivers one cell wide (a cape's thin tip) become sea: the shore smoothing lowered them below the water and left
-- islets 100-200 m off the shore (Sea Strait at Coast roughness 200 %, review 2026-10-12, round 2; opt-in with
-- s.dropStrayLand). Morphological opening of the land: erode it by one cell, then grow it back; the map border counts
-- as land, so no edge node is lost.
function M.removeLandSlivers(sea, w, h)
	local core = {}
	for j = 0, h - 1 do
		for i = 0, w - 1 do
			local k = j * w + i + 1
			core[k] = not sea[k] and (i == 0 or not sea[k - 1]) and (i == w - 1 or not sea[k + 1])
				and (j == 0 or not sea[k - w]) and (j == h - 1 or not sea[k + w])
		end
	end
	for j = 0, h - 1 do
		for i = 0, w - 1 do
			local k = j * w + i + 1
			if not sea[k] and not (core[k] or (i > 0 and core[k - 1]) or (i < w - 1 and core[k + 1])
					or (j > 0 and core[k - w]) or (j < h - 1 and core[k + w])) then
				sea[k] = true
			end
		end
	end
end

-- Sea patches that do not reach the map edge become land: an inland "sea" would capture the rivers (seen in M1)
-- and would read as a puddle-like lake at 0 m.
function M.openSeaOnly(sea, w, h)
	local open, stack = {}, {}
	for i = 0, w - 1 do
		for _, k in ipairs({ i + 1, (h - 1) * w + i + 1 }) do
			if sea[k] and not open[k] then open[k] = true; stack[#stack + 1] = k end
		end
	end
	for j = 0, h - 1 do
		for _, k in ipairs({ j * w + 1, j * w + w }) do
			if sea[k] and not open[k] then open[k] = true; stack[#stack + 1] = k end
		end
	end
	while #stack > 0 do
		local k = stack[#stack]
		stack[#stack] = nil
		local i, j = (k - 1) % w, floor((k - 1) / w)
		if i > 0 and sea[k - 1] and not open[k - 1] then open[k - 1] = true; stack[#stack + 1] = k - 1 end
		if i < w - 1 and sea[k + 1] and not open[k + 1] then open[k + 1] = true; stack[#stack + 1] = k + 1 end
		if j > 0 and sea[k - w] and not open[k - w] then open[k - w] = true; stack[#stack + 1] = k - w end
		if j < h - 1 and sea[k + w] and not open[k + w] then open[k + w] = true; stack[#stack + 1] = k + w end
	end
	for k = 1, w * h do
		if sea[k] and not open[k] then sea[k] = false end
	end
end

-- Only the largest sea body stays sea (opt-in, s.mainSeaOnly: Sea Strait, whose strait is one body from edge to edge):
-- the shore noise beside a strait's mouth cut small pockets of water off it at the map edge, which openSeaOnly keeps as
-- open sea (touching the edge) and the report counts as no puddle (review 2026-10-13, round 3: 60 of 380 maps had one,
-- up to 2800 m2). 4 neighbours, as the sea is drawn.
function M.keepMainSea(sea, w, h)
	local comp, best, bestN, id = {}, 0, 0, 0
	for k0 = 1, w * h do
		if sea[k0] and not comp[k0] then
			id = id + 1
			local stack, nC = { k0 }, 0
			comp[k0] = id
			while #stack > 0 do
				local k = stack[#stack]
				stack[#stack] = nil
				nC = nC + 1
				local i, j = (k - 1) % w, floor((k - 1) / w)
				if i > 0 and sea[k - 1] and not comp[k - 1] then comp[k - 1] = id; stack[#stack + 1] = k - 1 end
				if i < w - 1 and sea[k + 1] and not comp[k + 1] then comp[k + 1] = id; stack[#stack + 1] = k + 1 end
				if j > 0 and sea[k - w] and not comp[k - w] then comp[k - w] = id; stack[#stack + 1] = k - w end
				if j < h - 1 and sea[k + w] and not comp[k + w] then comp[k + w] = id; stack[#stack + 1] = k + w end
			end
			if nC > bestN then best, bestN = id, nC end
		end
	end
	for k = 1, w * h do
		if sea[k] and comp[k] ~= best then sea[k] = false end
	end
end

-- Land the sea surrounds (4 neighbours: land touching another piece only diagonally is cut off from it once the coarse
-- grid is upsampled, review 2026-10-12, round 2) becomes sea unless it holds a node of
-- `keep` (opt-in, s.dropStrayLand: Sea Strait, whose designed islands are its only islands; review 2026-10-12). Each
-- piece of land on the shore is flooded until it reaches the map border, land already known to do so, or `cap` nodes
-- (bigger pieces count as mainland): the whole land is never flooded (that cost 0.3 s on an 8 km map)
function M.dropStrayLand(sea, w, h, keep, cap)
	local main, seen = {}, {}
	for k0 = 1, w * h do
		local i0, j0 = (k0 - 1) % w, floor((k0 - 1) / w)
		if not sea[k0] and not main[k0] and not seen[k0]
				and ((i0 > 0 and sea[k0 - 1]) or (i0 < w - 1 and sea[k0 + 1]) or (j0 > 0 and sea[k0 - w])
					or (j0 < h - 1 and sea[k0 + w])) then
			local comp, stack, isMain, kept = { k0 }, { k0 }, false, false
			seen[k0] = true
			while #stack > 0 and not isMain do
				local k = stack[#stack]
				stack[#stack] = nil
				kept = kept or keep[k] == true
				local i, j = (k - 1) % w, floor((k - 1) / w)
				if i == 0 or j == 0 or i == w - 1 or j == h - 1 or #comp > cap then isMain = true break end
				for _, q in ipairs({ k - 1, k + 1, k - w, k + w }) do
					if not sea[q] then
						if main[q] then isMain = true
						elseif not seen[q] then seen[q] = true; comp[#comp + 1] = q; stack[#stack + 1] = q end
					end
				end
			end
			if isMain or kept then
				for _, k in ipairs(comp) do main[k] = true end
			else
				for _, k in ipairs(comp) do sea[k] = true end
			end
		end
	end
end

--[[ Build the fields on the coarse grid g = { w, h, cell, sizeX, sizeY }.
  Returns { B, U, sea, outlets = {node...}, inflows = {{node, area}...}, corridors = {{x, y}...}, preset,
  orientation, type, canon }; side and sea as in pipeline.normalise (sea = false: no sea, only on side.seaChoice).
  Sea Strait also returns plain, bluff (per node, landform.lua), bluffTop, strait (its axis in local metres) and lanes
  (the shipping lane, carved by pipeline.lua). ]]
function M.build(typeName, g, seed, ctx, tune, side, sea)
	local T = M.TYPES[typeName]
	assert(T, "unknown map type " .. tostring(typeName))
	local r = noise.rng(noise.derive(seed, "shape"))
	local w, h, cell = g.w, g.h, g.cell
	local sizeX, sizeY = (w - 1) * cell, (h - 1) * cell
	-- the roll is always drawn, so every later random number (and so the whole map) is the same as before when no
	-- side is chosen; a chosen side only replaces the rotation
	local rolled = r:int(0, 7)
	local o, variant = M.orientationFor(typeName, side, rolled), nil
	-- a strait's direction (Sea Strait): the axis orientation, and whether it is a diagonal (setup's 6th argument)
	if T.side and T.side.edge == "axis" then o, variant = M.axisOrientation(side, rolled, seed, sizeX, sizeY) end
	local swap, flipX, flipY = o >= 4, o % 2 == 1, floor(o / 2) % 2 == 1
	local cw, ch = sizeX, sizeY
	if swap then cw, ch = sizeY, sizeX end
	-- no sea (Sea side None, or Great River Valley's Sea None): setup draws the same numbers as with a sea, so the layout
	-- (range, massifs, passes, plateau, the valley's course) stays; the rivers and heights can still differ, since the
	-- sea's strip is land that drains to the edge
	local noSea = M.noSea(typeName, side, sea)
	-- the Advanced setting "coast roughness" (0 without sea); setup gets it too, so a type can keep features clear of
	-- the ragged shore (Alpine's pass feet); the other types ignore it. Sea Strait also gets its variant (diagonal or
	-- not) and the coarse cell (its narrows stay at least 5 cells wide); the other types ignore both.
	local ragScale = noSea and 0 or (tune and tune.coast or 1)
	local s = T.setup(cw, ch, r, seed, ragScale, variant, cell)
	s.noSea = noSea
	s.ragScale = ragScale
	-- edges where every node is an outlet: the sea's edge on a map without sea (rivers leave the map anywhere along
	-- it, as they would have reached the sea) and the far edge of a type that asks for it (s.farOutlets: rivers
	-- leave wherever they reach it, instead of running along it to a few outlet points)
	local function edgeOutlets(Y)
		local n = math.max(1, floor(cw / cell + 0.5))
		for q = 0, n do s.outlets[#s.outlets + 1] = { X = cw * q / n, Y = Y } end
	end
	if noSea then edgeOutlets(0) end
	if s.farOutlets then edgeOutlets(ch) end

	local function toCanon(x, y)
		local a, b = x / sizeX, y / sizeY
		if swap then a, b = b, a end
		if flipX then a = 1 - a end
		if flipY then b = 1 - b end
		return a * cw, b * ch
	end
	local function toLocal(X, Y)
		local a, b = X / cw, Y / ch
		if flipX then a = 1 - a end
		if flipY then b = 1 - b end
		if swap then a, b = b, a end
		return a * sizeX, b * sizeY
	end
	local function toNode(X, Y)
		local x, y = toLocal(X, Y)
		local i = min(w - 1, max(0, floor(x / cell + 0.5)))
		local j = min(h - 1, max(0, floor(y / cell + 0.5)))
		return j * w + i + 1
	end

	local B, U, sea = {}, {}, {}
	local lift -- optional raised ground (0..1 per node; landform.lua adds it), from any type that returns it
	local coastDist -- distance to the open sea per node (two-pass types; landform.lua sizes the relief by it)
	-- (Sea Strait) per-node shore plain width (m) and bluff weight (0..1): the land function's 4th and 5th values,
	-- shaped by landform.lua; nil for every other type
	local plain, bluff
	if T.eval then
		for j = 0, h - 1 do
			for i = 0, w - 1 do
				local k = j * w + i + 1
				local X, Y = toCanon(i * cell, j * cell)
				local b, u, isSea, l = T.eval(s, X, Y, cw, ch)
				B[k], U[k], sea[k] = b, u, isSea
				if l ~= nil and l > 0 and not isSea then
					lift = lift or {}
					lift[k] = l
				end
			end
			if ctx then ctx.tick() end
		end
		-- ragged coasts leave slivers and enclosed sea specks: they become low coastal land (B just above the
		-- lowest land around, low uplift), as for the two-pass types
		local was = {}
		for k = 1, w * h do was[k] = sea[k] end
		M.removeSeaSlivers(sea, w, h)
		M.openSeaOnly(sea, w, h)
		for k = 1, w * h do
			if was[k] and not sea[k] then
				local i, j = (k - 1) % w, floor((k - 1) / w)
				local low = math.huge
				for _, nb in ipairs({ i > 0 and k - 1, i < w - 1 and k + 1, j > 0 and k - w, j < h - 1 and k + w }) do
					if nb and not was[nb] and B[nb] < low then low = B[nb] end
				end
				B[k], U[k] = (low < math.huge and low or 0) + 0.01, 0.1
			end
		end
	else
		-- two passes: the type draws the sea, then shapes the land from the true distance to it (peninsulas and
		-- islands, where "distance inland" is not one coordinate)
		-- (the node index is passed on: a type may keep per-node values from the sea pass for the land pass; the
		-- others ignore it)
		for j = 0, h - 1 do
			for i = 0, w - 1 do
				local X, Y = toCanon(i * cell, j * cell)
				local k = j * w + i + 1
				sea[k] = T.sea(s, X, Y, cw, ch, k)
			end
			if ctx then ctx.tick() end
		end
		M.removeSeaSlivers(sea, w, h)
		M.openSeaOnly(sea, w, h)
		if s.mainSeaOnly then M.keepMainSea(sea, w, h) end
		if s.dropStrayLand then
			M.removeLandSlivers(sea, w, h)
			M.dropStrayLand(sea, w, h, s.islandNode, floor(1.5e6 / (cell * cell)))
		end
		local seeds = { n = 0, x = {}, y = {}, off = {}, node = {} }
		for j = 0, h - 1 do
			for i = 0, w - 1 do
				local k = j * w + i + 1
				if sea[k] and ((i > 0 and not sea[k - 1]) or (i < w - 1 and not sea[k + 1])
						or (j > 0 and not sea[k - w]) or (j < h - 1 and not sea[k + w])) then
					local q = seeds.n + 1
					seeds.n = q
					seeds.x[q], seeds.y[q], seeds.off[q], seeds.node[q] = i * cell, j * cell, 0, k
				end
			end
		end
		local dist
		lift = nil
		if seeds.n > 0 then
			local _
			_, dist = grid.nearestSeed(w, h, cell, seeds, nil, ctx)
			if not noSea then coastDist = dist end -- a map without sea has no coast to size the relief by
		end
		for j = 0, h - 1 do
			for i = 0, w - 1 do
				local k = j * w + i + 1
				if sea[k] and not noSea then
					B[k], U[k] = -10, 1
				else
					local X, Y = toCanon(i * cell, j * cell)
					local d = dist and dist[k] or math.huge
					-- no sea: the sea's place is land at minus its distance from where the coast would be, so the
					-- type's land keeps falling towards that edge
					if sea[k] then d, sea[k] = (d < math.huge) and -d or 0, false end
					local l, pl, bl
					B[k], U[k], l, pl, bl = T.land(s, X, Y, cw, ch, d < math.huge and d or 1e9, k)
					if l ~= nil and l > 0 then
						lift = lift or {}
						lift[k] = l
					end
					if pl ~= nil and pl > 0 then
						plain = plain or {}
						plain[k] = pl
					end
					if bl ~= nil and bl > 0 then
						bluff = bluff or {}
						bluff[k] = bl
					end
				end
			end
			if ctx then ctx.tick() end
		end
	end

	local out = { B = B, U = U, sea = sea, lift = lift, coastDist = coastDist, outlets = {}, inflows = {},
		preset = T.preset, orientation = o,
		type = typeName, canon = { toCanon = toCanon, toNode = toNode, cw = cw, ch = ch } }
	for _, p in ipairs(s.outlets) do
		local k = toNode(p.X, p.Y)
		if not sea[k] then out.outlets[#out.outlets + 1] = k end
	end
	for _, p in ipairs(s.inflows) do
		local k = toNode(p.X, p.Y)
		if not sea[k] then out.inflows[#out.inflows + 1] = { node = k, area = p.area } end
	end
	-- corridors as polylines in local metres
	out.corridors = {}
	for _, line in ipairs(s.corridors or {}) do
		local x, y = {}, {}
		for q, p in ipairs(line) do x[q], y[q] = toLocal(p.X, p.Y) end
		out.corridors[#out.corridors + 1] = { x = x, y = y }
	end
	-- Sea Strait: the bank shaping for landform.lua, the axis for the report and the shipping lane for the carve
	if s.axis then
		local C = M.STRAIT
		out.plain, out.bluff, out.bluffTop = plain, bluff, s.bluffTop
		-- (the rivers' meanders stay riverInset inside the two edges the strait meets (canonical X = 0 and cw; the inflows
		-- enter by the other two), within a cell of the map elsewhere, rivers.lua)
		local a, b = C.riverInset, -cell
		if swap then a, b = b, a end
		out.riverBounds = { a, b, sizeX - a, sizeY - b }
		local A, x, y = s.axis, {}, {}
		for q = 1, #A.X do x[q], y[q] = toLocal(A.X[q], A.Y[q]) end
		local narrows = {}
		for k, idx in ipairs(A.narrows) do narrows[k] = idx end
		-- (D, L, sound: the design's cross distance, length and sound width, for the tools)
		out.strait = { x = x, y = y, hw = A.hw, wq = A.wq, narrows = narrows, step = 25, D = s.D, L = s.L, sound = 2 * s.hb,
			hold = A.hold }
		-- the lane: every stretch where the strait is narrower than 2 x laneHw (plus 300 m on either side, so it runs on
		-- into deep water), 6 m deep, its banks rising 1:4 to laneBank; detail.carve only lowers and follows deeper water
		out.lanes = {}
		local n, ext = #x, floor(300 / 25)
		local q = 1
		while q <= n do
			if A.hw[q] < C.laneHw then
				local a = q
				while q < n and A.hw[q + 1] < C.laneHw do q = q + 1 end
				-- (step: carved in chords of up to 120 m and 0.6 x its width (detail.carve), the lane being gently curved and
				-- 160-520 m wide)
				local p = { x = {}, y = {}, w = {}, d = {}, fp = {}, ship = {}, kind = "lane", length = 0, step = 120 }
				for i = max(1, a - ext), min(n, q + ext) do
					local j = #p.x + 1
					p.x[j], p.y[j] = x[i], y[i]
					-- (the design's half-width is across the strait's frame; where the water runs obliquely to it, past a
					-- headland's tip, the lane is narrower by the cosine of that angle, so it never cuts beyond the shore)
					local i0, i1 = max(1, i - 2), min(n, i + 2)
					local dX, dY = A.X[i1] - A.X[i0], A.Y[i1] - A.Y[i0]
					local cosA = abs(dX * s.ca + dY * s.sa) / max(1e-9, math.sqrt(dX * dX + dY * dY))
					-- (in a channel's core and 150 m on the full width: the lane, at the 4 m resolution, is what sets its
					-- water line; beyond 300 m a 200 m fairway, inside whatever the coast roughness leaves, so the lane
					-- never cuts a cape straight)
					local open = min(C.laneOpen, 2 * C.laneShare * A.hw[i])
					p.w[j] = min(C.laneW[2], max(C.laneW[1], 2 * A.hw[i] * cosA * A.lw[i] + open * (1 - A.lw[i])))
					p.d[j], p.fp[j], p.ship[j] = C.laneDepth, C.laneBank, true
					if j > 1 then p.length = p.length + math.sqrt((x[i] - x[i - 1]) ^ 2 + (y[i] - y[i - 1]) ^ 2) end
				end
				out.lanes[#out.lanes + 1] = p
			end
			q = q + 1
		end
	end
	return out
end

return M

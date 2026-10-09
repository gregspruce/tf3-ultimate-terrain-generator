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
           ridges, as in mountains, whose flat land is in the valleys).

HOW TYPES ARE WRITTEN
  Each type works in a canonical frame: X across (0 .. cw), Y from the sea or the "south" side (0 .. ch),
  in metres. The pipeline picks one of 8 orientations from the seed (rotate/mirror), so the sea is not always
  at the same edge. Values only depend on (X, Y), the seed and the settings.

FIRST THREE TYPES
  great_river_valley   one big river crosses the map in a broad lowland valley between uplands, entering at
                       the far edge and reaching the sea through an estuary (drowned valley, landform.lua)
  delta_lowlands       wide coastal lowland; a big river splits into several channels over a land lobe that
                       bulges into a shallow sea; lakes and lagoons; low hills only far inland
  mountain_passes      a mountain belt across the map with two lower passes; foothills and valleys on both
                       sides; the sea along the south side, rivers leaving the map on the north side
MORE TYPES (added 2026-10-06, map editor)
  rolling_plains       inland plain, no sea; a big river crosses the map edge to edge (a ship river by default)
  lake_district        ice-scoured hills; long narrow lakes on the rivers (basins stretched along the ice flow)
  large_bays           a coast cut by two or three deep bays (sheltered harbours); rivers end at the bay heads
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
		if Y < coast then return -10, 1, true end
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
		-- rivers north of the range leave the map at two points of the north edge
		s.outlets = { { X = cw * r:range(0.2, 0.4), Y = ch }, { X = cw * r:range(0.6, 0.85), Y = ch } }
		return s
	end,
	eval = function(s, X, Y, cw, ch)
		local coast = ch * (0.06 + 0.045 * s.cs(X)) + rag(s, X, Y)
		if Y < coast then return -10, 1, true end
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
-- is the true distance to the open sea in metres (1e9 on maps without sea) and lift (0..1, optional) raises ground
-- as a block (a plateau: stream power alone cannot hold a high flat surface, since big rivers climb gently). Sea patches that do not reach the map edge
-- are turned into land (openSeaOnly).

-- Mainland along the far side with two or three long peninsulas reaching into the sea; a low ridge runs down each.
M.TYPES.peninsulas = {
	label = "Peninsulas",
	preset = { relief = 1.0, ships = 0, shelf = { slope = 0.012, max = 40 }, lakes = 0.6, rivers = 0.6, minRiver = 1000, meander = 0.9,
		valley = 1.4, estuary = 900, channels = 1.0, uplands = 1.0 },
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

M.TYPES.great_river_valley.label = "Great River Valley"
M.TYPES.delta_lowlands.label = "Delta Lowlands"
M.TYPES.mountain_passes.label = "Mountain Range with Passes"

-- One-line descriptions (shown under the Map type field) and the Terrain parameters a map type has nothing for
-- (`inactive`: the window says so next to the slider). Text only: no effect on the terrain. The inactive lists come
-- from the offline settings test (2026-10-08: the slider at 0 % and at its maximum gave the identical map at 11 km).
local INFO = {
	great_river_valley = { "One big river crosses the map in a broad valley between uplands and reaches the sea." },
	delta_lowlands = { "A wide, flat coastal plain; the river splits into several channels across a delta." },
	mountain_passes = { "The most alpine type: a mountain belt (snow from Hilly up) with two graded passes, foothills, sea on one side." },
	rolling_plains = { "Inland, no sea: gentle swells and a big navigable river crossing the map.", { "coast" } },
	lake_district = { "Inland hill country with long, narrow lakes strung along the rivers.", { "coast" } },
	large_bays = { "A coast cut by two or three deep, sheltered bays with rivers at their heads." },
	peninsulas = { "A mainland with two or three long peninsulas reaching into the sea." },
	island_chain = { "Islands of different sizes across the sea, with sounds between them; rivers are rare.",
		{ "rivers", "lakes", "meander", "valley" } },
	coastal_region = { "A ragged coast with headlands and coves, a coastal plain and hills inland." },
	highland_plateau = { "A lowland by the sea, an escarpment and a high, flat plateau cut by river gorges." },
}
for id, info in pairs(INFO) do
	M.TYPES[id].description = info[1]
	M.TYPES[id].inactive = info[2] or {}
end

--[[ Feature side (owner 2026-10-08): the player may choose the map edge that gets a map type's defining feature.
  Every type is written in a canonical frame whose low edge (Y = 0) is the sea or the "near" side; `side.edge` says
  which canonical edge the setting names ("low": the sea, or where the rivers go; "high": where the big river comes
  from), `side.label` is the window's label for the choice. Island Chain has no such side. M.SIDES order = the
  setting's values 1..4 (0 or nil = from the seed, as before). ]]
M.SIDES = { "north", "east", "south", "west" }
local SIDE = {
	great_river_valley = { label = "River comes from", edge = "high" },
	delta_lowlands = { label = "Sea side", edge = "low" },
	mountain_passes = { label = "Sea side", edge = "low" },
	rolling_plains = { label = "River comes from", edge = "high" },
	lake_district = { label = "Rivers flow towards", edge = "low" },
	large_bays = { label = "Sea side", edge = "low" },
	peninsulas = { label = "Sea side", edge = "low" },
	coastal_region = { label = "Sea side", edge = "low" },
	highland_plateau = { label = "Sea side", edge = "low" },
}
for id, sd in pairs(SIDE) do M.TYPES[id].side = sd end

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
	if not (T and T.side and name) then return rolled end
	if T.side.edge == "high" then name = OPPOSITE[name] end
	local sf = LOW_EDGE_AT[name]
	return (sf[1] and 4 or 0) + (sf[2] and 2 or 0) + rolled % 2
end

M.ORDER = { "great_river_valley", "delta_lowlands", "mountain_passes", "rolling_plains", "lake_district", "large_bays",
	"peninsulas", "island_chain", "coastal_region", "highland_plateau" }

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

--[[ Build the fields on the coarse grid g = { w, h, cell, sizeX, sizeY }.
  Returns { B, U, sea, outlets = {node...}, inflows = {{node, area}...}, corridors = {{x, y}...}, preset,
  orientation, type, canon } ]]
function M.build(typeName, g, seed, ctx, tune, side)
	local T = M.TYPES[typeName]
	assert(T, "unknown map type " .. tostring(typeName))
	local r = noise.rng(noise.derive(seed, "shape"))
	-- the roll is always drawn, so every later random number (and so the whole map) is the same as before when no
	-- side is chosen; a chosen side only replaces the rotation
	local o = M.orientationFor(typeName, side, r:int(0, 7))
	local swap, flipX, flipY = o >= 4, o % 2 == 1, floor(o / 2) % 2 == 1
	local w, h, cell = g.w, g.h, g.cell
	local sizeX, sizeY = (w - 1) * cell, (h - 1) * cell
	local cw, ch = sizeX, sizeY
	if swap then cw, ch = sizeY, sizeX end
	local s = T.setup(cw, ch, r, seed)
	s.ragScale = tune and tune.coast or 1 -- Advanced setting "coast roughness"

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
	local lift -- optional raised ground (0..1 per node; landform.lua adds it), from two-pass types
	local coastDist -- distance to the open sea per node (two-pass types; landform.lua sizes the relief by it)
	if T.eval then
		for j = 0, h - 1 do
			for i = 0, w - 1 do
				local k = j * w + i + 1
				local X, Y = toCanon(i * cell, j * cell)
				local b, u, isSea = T.eval(s, X, Y, cw, ch)
				B[k], U[k], sea[k] = b, u, isSea
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
		for j = 0, h - 1 do
			for i = 0, w - 1 do
				local X, Y = toCanon(i * cell, j * cell)
				sea[j * w + i + 1] = T.sea(s, X, Y, cw, ch)
			end
			if ctx then ctx.tick() end
		end
		M.removeSeaSlivers(sea, w, h)
		M.openSeaOnly(sea, w, h)
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
			coastDist = dist
		end
		for j = 0, h - 1 do
			for i = 0, w - 1 do
				local k = j * w + i + 1
				if sea[k] then
					B[k], U[k] = -10, 1
				else
					local X, Y = toCanon(i * cell, j * cell)
					local d = dist and dist[k] or math.huge
					local l
					B[k], U[k], l = T.land(s, X, Y, cw, ch, d < math.huge and d or 1e9)
					if l ~= nil and l > 0 then
						lift = lift or {}
						lift[k] = l
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
	return out
end

return M

--[[
rivers.lua - turns the coarse water network (hydrology.rivers) into the final river courses: smooth meandering
paths with width, depth and floodplain level at every point, ship rivers, and delta channels (pure Lua 5.2).

RULES (from in-game navigability tests)
  - All water is at 0 m. A river is a channel carved below 0 inside a flat floodplain at +1 .. +2.8 m, rising
    slowly upstream (0.12 m per km), so its surroundings never flood into puddles.
  - Ship rivers ("Ship rivers" setting, default per map type) are 120-180 m wide at the water line and 5 m
    deep: ships need about 100 m with 1:4 banks (probe E5b). Every other river stays under 60 m (18-58 m,
    2-3.5 m deep), growing with the area it drains, so players can bridge them easily.
  - Meanders scale with the river (bend wavelength about 11 times the width) but are deliberately irregular:
    every half-bend has its own length and swing, bends lean (skew) and flatten like real ones, and some
    reaches run almost straight while others nearly cut off (see meander()). Regular, periodic bends look
    artificial. The swing fades out at the junction or mouth, so tributaries meet their parent cleanly.
  - Tributaries start on the FINAL course of their parent (parents are shaped first).
  - Deltas (delta_lowlands): the trunk splits a few km before the coast into 2-4 channels that spread over the
    land lobe and each reach the sea.

OUTPUT (one table per course, all arrays per point, positions in local metres from the map's min corner)
  { x, y, w (water-line width m), d (depth below 0 m), fp (floodplain level m), ship (bool), river (index of
    the hydrology river or 0 for delta channels), kind ("trunk" | "tributary" | "delta"), length (m) }
]]

local noise = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/noise.lua"
local hydrology = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/hydrology.lua"
local grid = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/grid.lua"

local M = {}

local sqrt, floor, max, min, sin, cos, pi, log, exp = math.sqrt, math.floor, math.max, math.min, math.sin,
	math.cos, math.pi, math.log, math.exp

M.FP_MOUTH, M.FP_GRAD, M.FP_MAX = 1.0, 0.00012, 2.8
M.SHIP_W_MOUTH, M.SHIP_W_UP, M.SHIP_DEPTH = 180, 120, 5.0
M.SHIP_MIN_LEN = 4000 -- m: with "Several", the extra ship rivers are navigable at least this far (if they are that long)
M.SMALL_W_MIN, M.SMALL_W_MAX = 18, 58
M.STEP = 8 -- metres between points of the final courses
M.MEANDER_MIN = 625 -- m: shorter courses keep their smoothed drainage line (2.5 x the smallest fade-in, 250 m)

local chaikin, resample = grid.chaikin, grid.resample

local function nodeXY(g, k)
	return ((k - 1) % g.w) * g.cell, floor((k - 1) / g.w) * g.cell
end

local function lerpAttr(a, t)
	local i = floor(t)
	if i >= #a then return a[#a] end
	local f = t - i
	return a[i] + (a[i + 1] - a[i]) * f
end

-- Moving average with a window that shrinks at the ends, so both endpoints stay exactly in place.
local function centreline(x, y, radius)
	local n = #x
	local cx, cy = {}, {}
	local sx, sy = { [0] = 0 }, { [0] = 0 }
	for i = 1, n do sx[i] = sx[i - 1] + x[i]; sy[i] = sy[i - 1] + y[i] end
	for i = 1, n do
		local r = min(radius, i - 1, n - i)
		cx[i] = (sx[i + r] - sx[i - r - 1]) / (2 * r + 1)
		cy[i] = (sy[i + r] - sy[i - r - 1]) / (2 * r + 1)
	end
	return cx, cy
end

--[[ Valley wander: real valley axes are not straight lines between their ends. The smoothed drainage path is
  displaced sideways by two octaves of smooth noise along its length (wavelengths lam and 0.37 lam, swing 10 % of
  each), faded to zero over the first and last stretch so junctions and mouths stay exactly in place. Run before
  meander(): the bends then sit on a curving axis, which breaks the "same bend, repeated" look of a straight belt.
  noiseFn(x, y) is smooth noise in -1..1; key separates rivers. ]]
local function wander(cx, cy, step, lam, noiseFn, key)
	local n = #cx
	if n < 4 then return cx, cy end
	local total = (n - 1) * step
	local lam2 = 0.37 * lam
	local fadeL = min(lam2, total * 0.25)
	local ox, oy = {}, {}
	for i = 1, n do
		local s = (i - 1) * step
		local a, b = cx[max(1, i - 1)], cy[max(1, i - 1)]
		local c, d = cx[min(n, i + 1)], cy[min(n, i + 1)]
		local tx, ty = c - a, d - b
		local tl = sqrt(tx * tx + ty * ty)
		if tl < 1e-9 then tx, ty, tl = 1, 0, 1 end
		local fade = min(1, s / max(fadeL, 1), (total - s) / max(fadeL, 1))
		fade = fade * fade * (3 - 2 * fade)
		local off = 0.1 * lam * noiseFn(s / lam, key) + 0.1 * lam2 * noiseFn(s / lam2 + 31.7, key + 11.3)
		off = off * fade
		ox[i], oy[i] = cx[i] - ty / tl * off, cy[i] + tx / tl * off
	end
	return ox, oy
end

--[[ Meander around a centreline (uniformly spaced at `step`), built so that no two bends are alike.
  Real meanders are not a sine wave: bend lengths scatter widely, some bends are tight and nearly cut off, some
  reaches are almost straight, and bends lean downstream or upstream (skew) and have flattened or sharp apexes.
  The direction angle follows the Kinoshita form theta = omega * (sin phase + js * cos 3 phase - jf * sin 3 phase),
  and EVERY half-bend draws its own length factor (0.45 .. 2.2, log-normal like), swing (from almost straight to
  tight), skew js and flatness jf, blended smoothly from the previous half-bend so the course stays continuous.
  (Run 5: one skew per river made every bend lean the same way, which read as a repeated pattern.) A little
  curvature noise (noiseFn) bends the reaches between apexes, and a gentle pull towards the centreline keeps the
  belt inside the valley floor.
  wl(t), om(t): base wavelength (m) and base swing (rad) at fractional index t. The swing fades in over fadeIn
  metres and out over fadeOut metres. Returns x, y, the fractional centreline index of every point, and the
  belt half-width (largest distance from the centreline, m). ]]
local function meander(cx, cy, step, wl, om, fadeIn, fadeOut, bounds, r, noiseFn, key)
	local n = #cx
	local total = (n - 1) * step
	local ox, oy, ot = {}, {}, {}
	local function gauss() return (r:next() + r:next() + r:next() - 1.5) * 2 end -- about N(0, 1)
	local function drawLength() return min(2.2, max(0.45, exp(0.45 * gauss()))) end
	local function drawSwing()
		local q = r:next()
		if q < 0.15 then return r:range(0.1, 0.4) end -- nearly straight reach
		if q > 0.85 then return r:range(1.2, 1.45) end -- tight bend, close to a cut-off
		return r:range(0.55, 1.15)
	end
	local function drawSkew() return r:range(-0.3, 0.3) end
	local function drawFlat() return r:range(0.0, 0.15) end
	local lenFrom, lenTo = drawLength(), drawLength()
	local swFrom, swTo = drawSwing(), drawSwing()
	local jsFrom, jsTo = drawSkew(), drawSkew()
	local jfFrom, jfTo = drawFlat(), drawFlat()
	local u, d, belt = 0, 0, 0
	local phase = r:range(0, pi) -- start anywhere in a bend
	local halfIdx = floor(phase / pi)
	local ds = step
	local guard = 0
	while u <= total and guard < 400000 do
		guard = guard + 1
		local t = 1 + u / step
		local i = min(n - 1, floor(t))
		local f = t - i
		local px = cx[i] + (cx[i + 1] - cx[i]) * f
		local py = cy[i] + (cy[i + 1] - cy[i]) * f
		local tx, ty = cx[i + 1] - cx[i], cy[i + 1] - cy[i]
		local tl = sqrt(tx * tx + ty * ty)
		if tl < 1e-9 then tx, ty, tl = 1, 0, 1 end
		local qx, qy = px - ty / tl * d, py + tx / tl * d
		ox[#ox + 1] = min(max(qx, bounds[1]), bounds[3])
		oy[#oy + 1] = min(max(qy, bounds[2]), bounds[4])
		ot[#ot + 1] = t

		-- a new half-bend: draw its own length and swing
		local hi = floor(phase / pi)
		if hi ~= halfIdx then
			halfIdx = hi
			lenFrom, swFrom, jsFrom, jfFrom = lenTo, swTo, jsTo, jfTo
			lenTo, swTo, jsTo, jfTo = drawLength(), drawSwing(), drawSkew(), drawFlat()
		end
		local a = phase / pi - hi
		a = a * a * (3 - 2 * a)
		local lenF = lenFrom + (lenTo - lenFrom) * a
		local swing = swFrom + (swTo - swFrom) * a
		local js = jsFrom + (jsTo - jsFrom) * a
		local jf = jfFrom + (jfTo - jfFrom) * a
		local lam = wl(t) * lenF

		local fade = min(1, u / max(fadeIn, 1), (total - u) / max(fadeOut, 1))
		if fade < 0 then fade = 0 end
		fade = fade * fade * (3 - 2 * fade)
		local theta = om(t) * fade * (swing * (sin(phase) + js * cos(3 * phase) - jf * sin(3 * phase))
			+ 0.3 * noiseFn(u / (0.4 * wl(t)), key))
		theta = theta - 0.9 * d / lam -- pull back towards the centreline (keeps the belt in the valley)
		if theta > 1.45 then theta = 1.45 elseif theta < -1.45 then theta = -1.45 end
		phase = phase + 2 * pi * ds / lam
		u = u + cos(theta) * ds
		d = d + sin(theta) * ds
		if fade < 1 then
			d = d * (0.3 + 0.7 * fade) ^ (ds / max(fadeOut, 1)) -- settle onto the centreline where the swing fades
		end
		if d > belt then belt = d elseif -d > belt then belt = -d end
	end
	-- end exactly at the centreline end
	ox[#ox + 1], oy[#oy + 1], ot[#ot + 1] = cx[n], cy[n], n
	return ox, oy, ot, belt
end

local function nearestOnPath(path, x, y)
	local best, bi = math.huge, 1
	for i = 1, #path.x do
		local dx, dy = path.x[i] - x, path.y[i] - y
		local d2 = dx * dx + dy * dy
		if d2 < best then best, bi = d2, i end
	end
	return bi, sqrt(best)
end

local function smallWidth(A, aWater)
	local r = max(1, A / aWater)
	local l2 = log(r) / log(2)
	return min(M.SMALL_W_MAX, M.SMALL_W_MIN + 13 * l2), min(3.5, 2.0 + 0.4 * l2)
end

--[[ Choose ship reaches. Returns shipTo[riverIndex] = number of nodes from the mouth that are ship-sized. ]]
local function chooseShips(rivers, count, aWater, f, g)
	local shipTo = {}
	if count <= 0 then return shipTo end
	local roots = {}
	-- rivers reaching the sea, or leaving the map at an edge (inland maps: a navigable river crossing the map)
	for id, rv in ipairs(rivers) do
		if rv.parent == nil and (rv.mouth == "sea" or rv.mouth == "edge") then roots[#roots + 1] = id end
	end
	table.sort(roots, function(a, b) return rivers[a].a[1] > rivers[b].a[1] end)
	if #roots == 0 then return shipTo end
	local function reach(id, minA)
		local rv = rivers[id]
		local m = 0
		for i = 1, #rv.nodes do
			if rv.a[i] >= minA then m = i else break end
		end
		return m
	end
	local first = roots[1]
	local aMouth = rivers[first].a[1]
	shipTo[first] = reach(first, max(3 * aWater, 0.35 * aMouth))
	if count >= 2 then
		-- "Several" (run 6: the owner got one ship river on a Great River Valley, whose trunk drains nearly all the
		-- land, so no other river passed a size test relative to it). Now the two largest other rivers always become
		-- ship rivers, however small (the player asked for ships): other rivers reaching the sea or an edge, and the trunk's tributaries,
		-- wherever they join (the trunk's ship reach is extended up to the junction, so the network stays connected).
		local cands = {}
		for idx = 2, #roots do
			local id = roots[idx]
			cands[#cands + 1] = { id = id, a = rivers[id].a[1] }
		end
		for _, c in ipairs(rivers[first].children) do
			cands[#cands + 1] = { id = c, a = rivers[c].a[1], child = true }
		end
		table.sort(cands, function(a, b) return a.a > b.a end)
		local taken = 0
		for _, c in ipairs(cands) do
			if taken >= 2 then break end
			local rv = rivers[c.id]
			-- at least SHIP_MIN_LEN of ship water (or the river up to its last few nodes), however small it is
			local n = #rv.nodes
			local minNodes, len = 0, 0
			while minNodes < n - 6 and len < M.SHIP_MIN_LEN do
				minNodes = minNodes + 1
				len = len + hydrology.stepLength(f, g, rv.nodes[minNodes])
			end
			local m = max(reach(c.id, max(3 * aWater, 0.5 * c.a)), minNodes)
			if m >= 4 then
				shipTo[c.id] = m
				if c.child and rv.junction > shipTo[first] then shipTo[first] = rv.junction end
				taken = taken + 1
			end
		end
	end
	for id, m in pairs(shipTo) do
		if m < 4 then shipTo[id] = nil end -- a few hundred metres of wide water is not a ship river
	end
	return shipTo
end

--[[ Build the final courses.
  hydro = { f, A, rivers (hydrology.rivers), aWater }, g = coarse grid, shape = shapes.build result,
  opts = { ships = 0 | 1 | 2, meander = factor, seed } ]]
function M.build(hydro, g, shape, opts, ctx)
	local rivers, f, aWater = hydro.rivers, hydro.f, hydro.aWater
	local r = noise.rng(noise.derive(opts.seed, "rivers"))
	local wobble = noise.perlin(noise.derive(opts.seed, "meander"))
	local sizeX, sizeY = (g.w - 1) * g.cell, (g.h - 1) * g.cell
	-- (the meandered courses stay within a cell of the map; a type may keep them further in along some edges:
	-- shape.riverBounds, Sea Strait along the two edges its strait meets, where a river ran along and beyond the edge into
	-- the strait's mouth, review 2026-10-13)
	local bounds = shape.riverBounds or { -g.cell, -g.cell, sizeX + g.cell, sizeY + g.cell }
	local shipTo = chooseShips(rivers, opts.ships, aWater, f, g)
	local paths = {}
	local finalOf = {}
	local sDist = {} -- distance from the river system's mouth at each node, for the floodplain level
	local fpNode = {} -- floodplain level of every water node (landform.lua builds the valleys from it)

	for id, rv in ipairs(rivers) do
		local nodes = rv.nodes
		local n = #nodes
		-- attributes per node
		local s0 = 0
		if rv.parent then s0 = sDist[rv.parent][rv.junction] end
		local sd = {}
		local acc = s0
		for i = 1, n do
			sd[i] = acc
			acc = acc + hydrology.stepLength(f, g, nodes[i])
		end
		sDist[id] = sd
		local W, D, FP, SH = {}, {}, {}, {}
		local m = shipTo[id] or 0
		for i = 1, n do
			local w, d = smallWidth(rv.a[i], aWater)
			local ship = false
			if i <= m then
				local t = (m > 1) and (i - 1) / (m - 1) or 0
				w, d, ship = M.SHIP_W_MOUTH + (M.SHIP_W_UP - M.SHIP_W_MOUTH) * t, M.SHIP_DEPTH, true
			elseif m > 0 and i <= m + 6 then
				-- narrow from ship size to the natural width over ~6 cells
				local t = (i - m) / 7
				w = M.SHIP_W_UP + (w - M.SHIP_W_UP) * t
				d = M.SHIP_DEPTH + (d - M.SHIP_DEPTH) * t
			end
			if i > n - 3 and n > 4 then
				local k = n - i + 1 -- 3, 2, 1 at the source
				w = max(14, w * (0.35 + 0.2 * k)) -- at least ~3 nodes of water, so the stream stays continuous
				d = max(1.5, d * (0.55 + 0.15 * k))
			end
			W[i], D[i], FP[i], SH[i] = w, d, min(M.FP_MAX, M.FP_MOUTH + M.FP_GRAD * sd[i]), ship
			fpNode[nodes[i]] = FP[i]
		end

		-- base polyline, downstream first
		local bx, by = {}, {}
		local pre = 0
		if rv.parent then
			local parent = finalOf[rv.parent]
			local jx, jy = nodeXY(g, rivers[rv.parent].nodes[rv.junction])
			local pi_ = nearestOnPath(parent, jx, jy)
			bx[1], by[1] = parent.x[pi_], parent.y[pi_]
			pre = 1
		elseif rv.mouth == "sea" then
			-- continue two cells into the sea so the channel opens into open water
			local x1, y1 = nodeXY(g, nodes[1])
			local sx, sy = nodeXY(g, rv.seaNode)
			local dx, dy = sx - x1, sy - y1
			bx[1], by[1] = sx + 2 * dx, sy + 2 * dy
			bx[2], by[2] = sx, sy
			pre = 2
		else
			local x1, y1 = nodeXY(g, nodes[1])
			local ex = (x1 <= 0 and -g.cell) or (x1 >= sizeX and sizeX + g.cell) or x1
			local ey = (y1 <= 0 and -g.cell) or (y1 >= sizeY and sizeY + g.cell) or y1
			bx[1], by[1] = ex, ey
			pre = 1
		end
		for i = 1, n do
			bx[pre + i], by[pre + i] = nodeXY(g, nodes[i])
		end
		-- attribute arrays aligned with the base polyline (prefix points copy the first node)
		local aW, aD, aF, aS = {}, {}, {}, {}
		for i = 1, pre + n do
			local src = max(1, i - pre)
			aW[i], aD[i], aF[i], aS[i] = W[src], D[src], FP[src], SH[src] and 1 or 0
		end

		local sx, sy = chaikin(bx, by, 3)
		-- Chaikin keeps index fractions only approximately; map back by relative position along the polyline
		local rx, ry = resample(sx, sy, M.STEP)
		local nb = #bx
		local nr = #rx
		local function baseIndex(t) -- fractional index into the resampled centre -> into the base attributes
			return 1 + (nb - 1) * (t - 1) / max(1, nr - 1)
		end
		local wMean = 0
		for i = 1, n do wMean = wMean + W[i] end
		wMean = wMean / max(1, n)
		local cx, cy = centreline(rx, ry, max(2, floor(1.2 * 11 * wMean / M.STEP)))
		-- the valley axis wanders on scales larger than the bends (big rivers swing wider)
		cx, cy = wander(cx, cy, M.STEP, min(5000, max(1500, 30 * wMean, (nr - 1) * M.STEP * 0.25)), wobble, id * 7.9 + 100)
		local amp = opts.meander * r:range(0.85, 1.15)
		local function wl(t)
			local bi = baseIndex(t)
			return max(160, 11 * lerpAttr(aW, bi)) * (1 + 0.15 * wobble(bi * 0.07, id * 3.1))
		end
		local function om(t)
			-- slow change of meander strength along the river (whole reaches more or less sinuous)
			-- small streams swing less (at map scale their tight bends would read as zig-zag)
			local bi = baseIndex(t)
			local small = 0.6 + 0.4 * min(1, lerpAttr(aW, bi) / 60)
			-- (0.5 .. 1.2: whole reaches clearly calmer or wilder, not a uniform chain of bends)
			return amp * small * (0.85 + 0.35 * wobble(bi * 0.03 + 40, id * 1.7))
		end
		local fadeIn = max(250, 11 * aW[1])
		local fadeOut = max(200, 8 * aW[#aW])
		local total = (nr - 1) * M.STEP
		local mx, my, mt, belt
		if total > 2.5 * fadeIn then
			mx, my, mt, belt = meander(cx, cy, M.STEP, wl, om, fadeIn, fadeOut, bounds, r, wobble,
				id * 5.3 + 200)
		elseif total > M.MEANDER_MIN then
			-- a course shorter than 2.5 fade-ins (a short ship river: fade-in 11 x 180 m) bends too, its fades shrunk to
			-- 40 % of the course each. Its own random stream, so the other rivers keep their bends (run 7: a 4.8 km ship
			-- river from "Several" kept the straight 45-degree legs of the drainage grid).
			mx, my, mt, belt = meander(cx, cy, M.STEP, wl, om, total / 2.5, min(fadeOut, total / 2.5), bounds,
				noise.rng(noise.derive(opts.seed, "short-meander/" .. id)), wobble, id * 5.3 + 200)
		else
			mx, my, mt, belt = rx, ry, {}, 0
			for i = 1, nr do mt[i] = i end
			cx, cy = rx, ry
		end
		-- the centreline (valley axis) with its attributes: landform.lua builds the valley floor along it
		local centre = { x = cx, y = cy, w = {}, fp = {} }
		for i = 1, #cx do
			local bi = baseIndex(i)
			centre.w[i], centre.fp[i] = lerpAttr(aW, bi), lerpAttr(aF, bi)
		end
		local path = { x = mx, y = my, w = {}, d = {}, fp = {}, ship = {}, river = id, centre = centre, belt = belt,
			kind = rv.parent and "tributary" or "trunk", mouth = rv.mouth }
		local L = 0
		for i = 1, #mx do
			local bi = baseIndex(mt[i])
			path.w[i] = lerpAttr(aW, bi)
			path.d[i] = lerpAttr(aD, bi)
			path.fp[i] = lerpAttr(aF, bi)
			path.ship[i] = lerpAttr(aS, bi) >= 0.5
			if i > 1 then
				local dx, dy = mx[i] - mx[i - 1], my[i] - my[i - 1]
				L = L + sqrt(dx * dx + dy * dy)
			end
		end
		path.length = L
		paths[#paths + 1] = path
		finalOf[id] = path
		if ctx then ctx.tick() end
	end

	if shape.preset.delta and #paths > 0 then
		M.addDelta(paths, rivers, g, shape, opts, r)
	end
	return paths, shipTo, fpNode
end

--[[ Delta: split the largest sea-mouthed trunk `reach` x map size upstream of its mouth into `channels`
  courses. The extra channels run to points along the coast on both sides of the main mouth. ]]
function M.addDelta(paths, rivers, g, shape, opts, r)
	local cfg = shape.preset.delta
	local trunk
	for _, p in ipairs(paths) do
		if p.kind == "trunk" and p.mouth == "sea" and (trunk == nil or rivers[p.river].a[1] > rivers[trunk.river].a[1]) then
			trunk = p
		end
	end
	if not trunk then return end
	local sizeX, sizeY = (g.w - 1) * g.cell, (g.h - 1) * g.cell
	local Ld = cfg.reach * min(sizeX, sizeY)
	-- the trunk's first points lie in the sea; find the coast point (first point on land) and the split point
	local function isSea(x, y)
		local i = min(g.w - 1, max(0, floor(x / g.cell + 0.5)))
		local j = min(g.h - 1, max(0, floor(y / g.cell + 0.5)))
		return shape.sea[j * g.w + i + 1]
	end
	local coastI = 1
	while coastI < #trunk.x and isSea(trunk.x[coastI], trunk.y[coastI]) do coastI = coastI + 1 end
	local acc, splitI = 0, coastI
	for i = coastI + 1, #trunk.x do
		local dx, dy = trunk.x[i] - trunk.x[i - 1], trunk.y[i] - trunk.y[i - 1]
		acc = acc + sqrt(dx * dx + dy * dy)
		splitI = i
		if acc >= Ld then break end
	end
	if acc < 0.5 * Ld then return end
	local Sx, Sy = trunk.x[splitI], trunk.y[splitI]
	local Mx, My = trunk.x[coastI], trunk.y[coastI]
	local tx, ty = Mx - Sx, My - Sy
	local tl = sqrt(tx * tx + ty * ty)
	tx, ty = tx / tl, ty / tl
	local nx, ny = -ty, tx
	local ship = trunk.ship[splitI] and opts.ships >= 2
	local extra = cfg.channels - 1
	local sides = { 1, -1, 1, -1 }
	for c = 1, extra do
		local side = sides[c]
		local off = side * Ld * (0.55 + 0.35 * floor((c - 1) / 2)) * r:range(0.85, 1.15)
		local Tx, Ty = Mx + nx * off - tx * Ld * 0.15, My + ny * off - ty * Ld * 0.15
		-- move the end seaward until it is in the sea
		local steps = 0
		while not isSea(Tx, Ty) and steps < 200 do
			Tx, Ty = Tx + tx * g.cell * 0.5, Ty + ty * g.cell * 0.5
			steps = steps + 1
		end
		Tx, Ty = Tx + tx * g.cell * 2, Ty + ty * g.cell * 2
		local Cx, Cy = Sx + tx * Ld * 0.35 + nx * off * 0.2, Sy + ty * Ld * 0.35 + ny * off * 0.2
		local bx, by = {}, {}
		for q = 0, 40 do
			local t = q / 40
			local a, b, cc = (1 - t) ^ 2, 2 * (1 - t) * t, t * t
			bx[#bx + 1] = a * Sx + b * Cx + cc * Tx
			by[#by + 1] = a * Sy + b * Cy + cc * Ty
		end
		local rx, ry = resample(bx, by, M.STEP)
		local w = ship and r:range(115, 130) or r:range(32, 48)
		local d = ship and M.SHIP_DEPTH or 2.5
		local cx, cy = centreline(rx, ry, 4)
		local bounds = { -g.cell, -g.cell, sizeX + g.cell, sizeY + g.cell }
		local mx, my, _, belt = meander(cx, cy, M.STEP, function() return max(160, 11 * w) end,
			function() return 0.7 * opts.meander end, 11 * w, 3 * w, bounds, r, noise.perlin(noise.derive(opts.seed,
			"delta" .. c)), c * 3.7)
		local fp = trunk.fp[splitI]
		local centre = { x = cx, y = cy, w = {}, fp = {} }
		for i = 1, #cx do centre.w[i], centre.fp[i] = w, fp end
		local path = { x = mx, y = my, w = {}, d = {}, fp = {}, ship = {}, river = 0, kind = "delta", mouth = "sea",
			centre = centre, belt = belt }
		local L = 0
		for i = 1, #mx do
			path.w[i], path.d[i], path.fp[i], path.ship[i] = w, d, fp, ship
			if i > 1 then
				local dx, dy = mx[i] - mx[i - 1], my[i] - my[i - 1]
				L = L + sqrt(dx * dx + dy * dy)
			end
		end
		path.length = L
		paths[#paths + 1] = path
	end
end

--[[ Mouths of ship channels: a channel deeper than the shallow shelf it ends in would stop as a dark, round-ended
  trench. Ship channels are continued straight out to sea (along their last direction) until the shelf is as deep as
  the channel, widening over the last stretch, so they fade into open water. Other courses need nothing: their bed
  follows the existing bottom (detail.carve). Run after landform.lua (needs the final coarse heights). ]]
M.MOUTH_MAX = 1500 -- m: longest extension
function M.extendMouths(paths, hc, kind, g, needDepth)
	local w, h, cell = g.w, g.h, g.cell
	local function seaDepth(x, y)
		local i = min(w - 1, max(0, floor(x / cell + 0.5)))
		local j = min(h - 1, max(0, floor(y / cell + 0.5)))
		if kind[j * w + i + 1] ~= 1 then return nil end
		return -grid.sample(hc, w, h, cell, x, y)
	end
	for _, p in ipairs(paths) do
		local n = #p.x
		if n > 3 and p.ship then
			-- which end lies in the sea: delta channels end there, trunks start there
			local atEnd = p.ship[n] and seaDepth(p.x[n], p.y[n]) ~= nil
			local atStart = p.ship[1] and seaDepth(p.x[1], p.y[1]) ~= nil
			if atEnd or atStart then
				-- trim the points already out at sea (smoothing curls them into a hook), keeping the first one
				local arrays = { p.x, p.y, p.w, p.d, p.fp, p.ship }
				if atEnd then
					while n > 14 and seaDepth(p.x[n - 1], p.y[n - 1]) do
						for _, a in ipairs(arrays) do a[n] = nil end
						n = n - 1
					end
				else
					while #p.x > 14 and seaDepth(p.x[2], p.y[2]) do
						for _, a in ipairs(arrays) do table.remove(a, 1) end
					end
					n = #p.x
				end
				-- continue along the direction of the last ~80 m of the course
				local e, e2 = atEnd and n or 1, atEnd and n - 10 or 11
				local dx, dy = p.x[e] - p.x[e2], p.y[e] - p.y[e2]
				local l = sqrt(dx * dx + dy * dy)
				dx, dy = dx / l, dy / l
				local ext = {}
				local x, y = p.x[e], p.y[e]
				for s = M.STEP, M.MOUTH_MAX, M.STEP do
					x, y = x + dx * M.STEP, y + dy * M.STEP
					local dd = seaDepth(x, y)
					if dd == nil then break end
					ext[#ext + 1] = { x, y }
					if dd >= needDepth then break end
				end
				local m = #ext
				local W0, D0, F0 = p.w[e], p.d[e], p.fp[e]
				for q = 1, m do
					local flare = 1 + 0.6 * (q / m) ^ 2
					local px, py = ext[q][1], ext[q][2]
					if atEnd then
						local k = n + q
						p.x[k], p.y[k], p.w[k], p.d[k], p.fp[k], p.ship[k] = px, py, W0 * flare, D0, F0, true
					else
						table.insert(p.x, 1, px); table.insert(p.y, 1, py); table.insert(p.w, 1, W0 * flare)
						table.insert(p.d, 1, D0); table.insert(p.fp, 1, F0); table.insert(p.ship, 1, true)
					end
				end
			end
		end
	end
end

M.OX_MIN_W = 30           -- m: rivers narrower than this get no oxbow lakes (theirs would read as puddles)
M.OX_TURN = 2.0            -- rad: a half-bend must turn at least this much to have cut off a loop
M.OX_ABOVE = 4.0           -- m: lakes may lie on lowland up to this much above the river's floodplain level
M.OX_PER_WATER = { 1, 3, 5 } -- most oxbow lakes per map: Dry, Normal, Wet

--[[ Oxbow lakes (a cue of how the valley evolved). Where a river once looped further and cut through the neck, the
  abandoned loop stays beside the channel as a horseshoe lake. At the tightest bends (half-bends turning at least
  OX_TURN) of rivers at least OX_MIN_W wide, a horseshoe opens towards the channel just outside the bend: an
  uneven ring (radius and width vary along it, random span, silted ends narrower and shallower). It is kept only
  where the whole lake and its banks lie on lowland (coarse land between +0.3 m and OX_ABOVE over the river's
  floodplain level) clear of all other water; where the loop does not fit, smaller loops are tried. Its banks rise
  1:4 to the local ground (the carve reach follows the ground height kept in fp). Runs after landform.lua (needs the final coarse heights); the lakes are
  courses of kind "oxbow", carved like rivers by detail.carve. ]]
function M.oxbows(paths, hc, kind, g, settings)
	local r = noise.rng(noise.derive(settings.seed, "oxbows"))
	local w, h, cell = g.w, g.h, g.cell
	local sizeX, sizeY = (w - 1) * cell, (h - 1) * cell
	local atan2, abs = math.atan2, math.abs
	-- spatial hash of all water courses (and accepted lakes) for the clearance test
	local HC = 64
	local hash = {}
	local function addPoint(x, y, half)
		local key = floor(x / HC) * 65536 + floor(y / HC)
		local b = hash[key]
		if not b then b = {}; hash[key] = b end
		b[#b + 1] = x; b[#b + 1] = y; b[#b + 1] = half
	end
	for _, p in ipairs(paths) do
		for i = 1, #p.x do addPoint(p.x[i], p.y[i], p.w[i] * 0.5) end
	end
	local function clear(x, y, half)
		local cx, cy = floor(x / HC), floor(y / HC)
		for dx = -3, 3 do
			for dy = -3, 3 do
				local b = hash[(cx + dx) * 65536 + cy + dy]
				if b then
					for q = 1, #b, 3 do
						local ex, ey = b[q] - x, b[q + 1] - y
						local need = b[q + 2] + half + 15
						if ex * ex + ey * ey < need * need then return false end
					end
				end
			end
		end
		return true
	end
	-- ground height at (x, y) if it is lowland the lake may lie on, else nil
	local function lowland(x, y, fp)
		if x < cell or y < cell or x > sizeX - cell or y > sizeY - cell then return nil end
		local i, j = floor(x / cell + 0.5), floor(y / cell + 0.5)
		if kind[j * w + i + 1] ~= 0 then return nil end
		local v = grid.sample(hc, w, h, cell, x, y)
		if v >= 0.3 and v <= fp + M.OX_ABOVE then return v end
		return nil
	end

	-- candidate bends of every river wide enough
	local cands = {}
	for pi_, p in ipairs(paths) do
		local n = #p.x
		if (p.kind == "trunk" or p.kind == "tributary") and n > 40 then
			local hd = {}
			for i = 1, n - 1 do hd[i] = atan2(p.y[i + 1] - p.y[i], p.x[i + 1] - p.x[i]) end
			for i = 2, n - 1 do -- unwrap
				while hd[i] - hd[i - 1] > pi do hd[i] = hd[i] - 2 * pi end
				while hd[i] - hd[i - 1] < -pi do hd[i] = hd[i] + 2 * pi end
			end
			local k = {}
			for i = 1, n - 1 do
				local a, b = max(1, i - 4), min(n - 1, i + 4)
				k[i] = (hd[b] - hd[a]) / max(1, (b - a) * M.STEP)
			end
			local a = 1
			for i = 2, n - 1 do
				if (k[i] > 0) ~= (k[a] > 0) or i == n - 1 then
					-- half-bend a .. i-1
					local turn = abs(hd[i - 1] - hd[a])
					if turn >= M.OX_TURN then
						local apex, km = a, 0
						for q = a, i - 1 do
							if abs(k[q]) > km then apex, km = q, abs(k[q]) end
						end
						if p.w[apex] >= M.OX_MIN_W and apex > 2 and apex < n - 2 then
							cands[#cands + 1] = { p = pi_, i = apex, k = k[apex], turn = turn }
						end
					end
					a = i
				end
			end
		end
	end
	table.sort(cands, function(x, y) return x.turn > y.turn end)

	local out = {}
	local stats = { candidates = #cands, floodplain = 0, water = 0, small = 0 } -- why bends were rejected (tuning aid)
	local want = M.OX_PER_WATER[settings.water] or 3
	-- one horseshoe at bend c with loop radius scaled by `scale`; returns the lake or nil and the reason
	local function place(c, scale)
		local p = paths[c.p]
		local i = c.i
		local rw = p.w[i]
		local tx, ty = p.x[i + 1] - p.x[i - 1], p.y[i + 1] - p.y[i - 1]
		local tl = sqrt(tx * tx + ty * ty)
		tx, ty = tx / tl, ty / tl
		local s = c.k > 0 and 1 or -1 -- the centre of curvature lies on the left (s = 1) or right
		local nx, ny = ty * s, -tx * s -- away from the centre of curvature: the outer side of the bend
		local lw = rw * r:range(0.6, 0.9)
		-- loop radius ~ 2-3 channel widths, like real bends (radius of curvature / width ~ 2-3)
		local R = min(700, max(60, rw * r:range(1.8, 3.0)) * scale)
		if R < max(1.2 * rw, 50) then return nil, "small" end
		local gap = 0.5 * rw + 0.5 * lw + max(25, 0.6 * rw)
		local ccx, ccy = p.x[i] + nx * (gap + R), p.y[i] + ny * (gap + R)
		local span = r:range(3.6, 5.0)
		local p1, p2 = r:range(0, 2 * pi), r:range(0, 2 * pi)
		local aspect = r:range(1.0, 1.4) -- loops are often drawn out along the valley
		local depth = min(3, 0.6 * p.d[i] + 0.5)
		local fp = p.fp[i]
		local m = max(12, floor(R * aspect * span / M.STEP))
		local lake = { x = {}, y = {}, w = {}, d = {}, fp = {}, ship = {}, river = 0, kind = "oxbow" }
		for q = 0, m do
			local t = q / m
			local phi = -span * 0.5 + span * t
			local rr = R * (1 + 0.16 * sin(2 * phi + p1) + 0.08 * sin(3 * phi + p2))
			local ux, uy = cos(phi) * nx + sin(phi) * tx, cos(phi) * ny + sin(phi) * ty
			local x = ccx + rr * (cos(phi) * nx + aspect * sin(phi) * tx)
			local y = ccy + rr * (cos(phi) * ny + aspect * sin(phi) * ty)
			local taper = sin(pi * t) ^ 0.35
			local lwq = max(12, lw * taper)
			local half = lwq * 0.5 + 12
			local v0 = lowland(x, y, fp)
			local v1 = v0 and lowland(x + ux * half, y + uy * half, fp)
			local v2 = v1 and lowland(x - ux * half, y - uy * half, fp)
			if not v2 then return nil, "floodplain" end
			if not clear(x, y, lwq * 0.5) then return nil, "water" end
			local id = q + 1
			lake.x[id], lake.y[id], lake.w[id] = x, y, lwq
			lake.d[id], lake.fp[id], lake.ship[id] = max(0.8, depth * sqrt(taper)), max(v0, v1, v2), false
		end
		local L = 0
		for q = 2, #lake.x do
			local dx, dy = lake.x[q] - lake.x[q - 1], lake.y[q] - lake.y[q - 1]
			L = L + sqrt(dx * dx + dy * dy)
		end
		lake.length = L
		return lake
	end
	for _, c in ipairs(cands) do
		if #out >= want then break end
		local lake, why
		for _, scale in ipairs({ 1, 0.75, 0.55 }) do
			lake, why = place(c, scale)
			if lake or why == "small" then break end
		end
		if lake then
			out[#out + 1] = lake
			for q = 1, #lake.x do addPoint(lake.x[q], lake.y[q], lake.w[q] * 0.5) end
		elseif why then
			stats[why] = (stats[why] or 0) + 1
		end
	end
	return out, stats
end

return M

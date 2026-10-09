--[[
detail.lua - from the coarse landform to the full 4 m heightmap the game uses (pure Lua 5.2).

DESIGN RULE: coarse internal processing is fine as long as the final map has full detail. So:
  M.upsample  Catmull-Rom (cubic) interpolation of the coarse heights to every 4 m node, separable (rows, then
              columns), so curves stay smooth without the creases of bilinear interpolation. Then detail from two
              tileable fractal textures (different scales, so the repeat is not visible), faded in from +3 m
              upwards and scaled by Relief: floodplains and beaches stay perfectly flat for building, hills
              and mountains get rock-scale texture where landform marks the ground rough (hill country, steep
              ground; never on pass floors). Land squares whose four coarse corners are all land are
              kept above +0.4 m: interpolation never leaves a puddle on a floodplain.
  Erosion texture (gullies.lua): spurs and gullies running downhill, depth from the local slope, added with the
              same height fade (and never cutting more than half the height above it).
  M.carve     every river course is cut at full resolution: water-line width w, flat bed at -d, banks of
              1:4 up to 0 m at w / 2 and on up to the floodplain (the cross-section ships use, probe E5b).
              Only lowers terrain, so junctions and mouths merge by themselves.

COST (11 km map, 2817^2 = 7.9 M nodes): one pass over all nodes with ~10 operations each, plus the river
corridors.
]]

local noise = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/noise.lua"
local gullies = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/gullies.lua"

local M = {}

local floor, ceil, max, min, sqrt = math.floor, math.ceil, math.max, math.min, math.sqrt

-- metres, per Relief (Gentle .. Mountainous), times landform's roughness (hill country, steep ground). Run 5: 1.4 m at
-- Gentle everywhere above 3 m read as smooth plastic; vanilla hills carry ~3 m RMS at 16-48 m wavelengths.
M.DETAIL_AMP = { 5.0, 5.75, 6.5, 7.25, 8.0 }
M.DETAIL_FROM, M.DETAIL_FULL = 3, 18  -- detail fades in between these heights (m)
M.GUARD = 0.4                          -- minimum height of land squares (m)
M.DETAIL_FLOOR = 0.5                   -- m: detail and gullies never take land that was above +3 m below this
M.TILE = 256
M.SHIP_BED = 2.6 -- metres: least depth of a ship channel where it runs on into shallow water

local function catmull(t)
	local t2, t3 = t * t, t * t * t
	return (-t3 + 2 * t2 - t) * 0.5, (3 * t3 - 5 * t2 + 2) * 0.5, (-3 * t3 + 4 * t2 + t) * 0.5, (t3 - t2) * 0.5
end

-- rough: coarse detail factor 0..1 (landform.lua: hill country and steep ground; 0 on plains and pass floors)
function M.upsample(hc, g, Wf, Hf, kind, settings, preset, seed, ctx, rough)
	local R = floor(g.cell / 4 + 0.5)
	local wc, hcN = g.w, g.h
	local W0, W1, W2, W3 = {}, {}, {}, {}
	for ph = 0, R - 1 do
		W0[ph], W1[ph], W2[ph], W3[ph] = catmull(ph / R)
	end
	local col0, colPh = {}, {}
	for i = 0, Wf - 1 do
		col0[i], colPh[i] = floor(i / R), i % R
	end

	-- pass 1: every coarse row at full x resolution
	local function rows(src)
		local out = {}
		for jc = 0, hcN - 1 do
			local row = jc * wc
			local base = jc * Wf + 1
			for i = 0, Wf - 1 do
				local ic, ph = col0[i], colPh[i]
				local a = src[row + (ic > 0 and ic - 1 or 0) + 1]
				local b = src[row + ic + 1]
				local c = src[row + (ic + 1 < wc and ic + 1 or wc - 1) + 1]
				local d = src[row + (ic + 2 < wc and ic + 2 or wc - 1) + 1]
				out[base + i] = W0[ph] * a + W1[ph] * b + W2[ph] * c + W3[ph] * d
			end
			if ctx then ctx.tick() end
		end
		return out
	end
	local tmp = rows(hc)
	local tmpC = rows(rough)
	-- coarse rows whose cubic reads any roughness; rows of plain, floodplain or sea get no detail and are skipped
	local roughRow = {}
	for jc = 0, hcN - 1 do
		local any = false
		for jj = max(0, jc - 1), min(hcN - 1, jc + 2) do
			for ic = 0, wc - 1 do
				if rough[jj * wc + ic + 1] > 0 then any = true break end
			end
			if any then break end
		end
		roughRow[jc] = any
	end

	-- guarded squares: all 16 coarse nodes the cubic reads are land. Squares near a shore are left alone, so
	-- shorelines follow the smooth interpolation instead of the coarse cell edges.
	local landSq = {}
	for jc = 0, hcN - 2 do
		for ic = 0, wc - 2 do
			local all = true
			for jj = max(0, jc - 1), min(hcN - 1, jc + 2) do
				for ii = max(0, ic - 1), min(wc - 1, ic + 2) do
					if kind[jj * wc + ii + 1] ~= 0 then all = false break end
				end
				if not all then break end
			end
			landSq[jc * wc + ic + 1] = all
		end
		if ctx then ctx.tick() end
	end

	local T = M.TILE
	local t1 = noise.tile(noise.derive(seed, "detail1"), T, 64, 5, 0.55, ctx)
	local t2 = noise.tile(noise.derive(seed, "detail2"), T, 32, 4, 0.5, ctx)
	local i1, i2, sqCol = {}, {}, {}
	for i = 0, Wf - 1 do
		i1[i] = i % T + 1
		i2[i] = floor(i * 0.75) % T + 1 -- second texture at 4/3 scale: combined repeat ~4 km
		sqCol[i] = min(col0[i], wc - 2) + 1
	end
	local amp = M.DETAIL_AMP[settings.relief] * min(1.5, preset.relief) * (settings.tune and settings.tune.detail or 1)
	local from, span = M.DETAIL_FROM, M.DETAIL_FULL - M.DETAIL_FROM
	local guard = M.GUARD

	-- erosion texture (gullies.lua) on its own 16 m grid, read with the same cubic weights per 4 m node
	local gf = gullies.new(hc, rough, g, settings, seed, Wf, Hf, ctx)
	local RT, GW0, GW1, GW2, GW3, gcol0, gcolPh, gcol = 1, {}, {}, {}, {}, {}, {}, {}
	if gf then
		RT = gf.RT
		for ph = 0, RT - 1 do
			GW0[ph], GW1[ph], GW2[ph], GW3[ph] = catmull(ph / RT)
		end
		for i = 0, Wf - 1 do
			gcol0[i], gcolPh[i] = floor(i / RT), i % RT
		end
	end
	local gw = gf and gf.w or 0

	-- pass 2: columns, detail, puddle guard
	local H = {}
	for j = 0, Hf - 1 do
		local jc, ph = floor(j / R), j % R
		local r0 = (jc > 0 and jc - 1 or 0) * Wf + 1
		local r1 = jc * Wf + 1
		local r2 = (jc + 1 < hcN and jc + 1 or hcN - 1) * Wf + 1
		local r3 = (jc + 2 < hcN and jc + 2 or hcN - 1) * Wf + 1
		local w0, w1, w2, w3 = W0[ph], W1[ph], W2[ph], W3[ph]
		local tj1 = (j % T) * T
		local tj2 = (floor(j * 0.75) % T) * T
		local sqRow = (jc < hcN - 1 and jc or hcN - 2) * wc
		local out = j * Wf + 1
		local useC = roughRow[jc]
		-- this row's erosion texture, interpolated along y at the texture's x spacing (cubic in x per node below)
		local useG = false
		if gf and useC then
			local jt, pt = floor(j / RT), j % RT
			local ra, rb = gf:row(jt > 0 and jt - 1 or 0), gf:row(jt)
			local rc, rd = gf:row(jt + 1), gf:row(jt + 2)
			local a0, a1, a2, a3 = GW0[pt], GW1[pt], GW2[pt], GW3[pt]
			for it = 1, gw do
				local gv = a0 * ra[it] + a1 * rb[it] + a2 * rc[it] + a3 * rd[it]
				gcol[it - 1] = gv
				if gv ~= 0 then useG = true end
			end
		end
		for i = 0, Wf - 1 do
			local v = w0 * tmp[r0 + i] + w1 * tmp[r1 + i] + w2 * tmp[r2 + i] + w3 * tmp[r3 + i]
			if v > from then
				if useC then
					local c = w0 * tmpC[r0 + i] + w1 * tmpC[r1 + i] + w2 * tmpC[r2 + i] + w3 * tmpC[r3 + i]
					if c > 0.01 then
						local a = v - from
						local ramp = (a < span) and a / span or 1
						local dv = amp * ramp * c * (t1[tj1 + i1[i]] + 0.5 * t2[tj2 + i2[i]])
						if useG then
							local it, px = gcol0[i], gcolPh[i]
							local gv = ramp * (GW0[px] * gcol[it > 0 and it - 1 or 0] + GW1[px] * gcol[it]
								+ GW2[px] * gcol[it + 1] + GW3[px] * gcol[it + 2])
							-- gullies never cut low ground down towards the water line (no puddles on valley sides)
							if gv < -0.5 * a then gv = -0.5 * a end
							dv = dv + gv
						end
						v = v + dv
						-- land above +3 m stays land: with Surface detail and Erosion at 200 % on Mountainous the detail
						-- reached -36 m and dug sea-level puddles into 15-25 m lowland (offline settings test, 2026-10-08). A
						-- floor rather than a proportional limit, so designed maps (which never get this low) stay
						-- identical (offline regression test)
						if v < M.DETAIL_FLOOR then v = M.DETAIL_FLOOR end
					end
				end
			elseif v < guard and landSq[sqRow + sqCol[i]] then
				v = guard
			end
			H[out + i] = v
		end
		if ctx then ctx.tick() end
	end
	return H
end

-- Carve the river courses. Points closer than a width-dependent step are skipped (the chord error of the
-- meander curves stays under a metre), so wide rivers cost little.
function M.carve(H, Wf, Hf, paths, ctx)
	for _, p in ipairs(paths) do
		local x, y, wd, fp = p.x, p.y, p.w, p.fp
		local n = #x
		-- where the course runs on into water that is already there (the sea shelf, a lake, an estuary), its bed
		-- follows that bottom instead of cutting a trench into it; ship reaches keep at least SHIP_BED metres
		local dp = {}
		for i = 1, n do
			local ii = min(Wf - 1, max(0, floor(x[i] / 4 + 0.5)))
			local jj = min(Hf - 1, max(0, floor(y[i] / 4 + 0.5)))
			local h0 = H[jj * Wf + ii + 1]
			local d = p.d[i]
			if h0 < 0 then d = min(d, max(-h0 + 0.3, (p.ship and p.ship[i]) and M.SHIP_BED or 1.2)) end
			dp[i] = d
		end
		local sel = { 1 }
		local acc = 0
		for i = 2, n do
			local dx, dy = x[i] - x[i - 1], y[i] - y[i - 1]
			acc = acc + sqrt(dx * dx + dy * dy)
			if acc >= max(8, min(40, wd[i] * 0.25)) or i == n then
				sel[#sel + 1] = i
				acc = 0
			end
		end
		for s = 1, #sel - 1 do
			if ctx and s % 64 == 0 then ctx.tick() end
			local a, b = sel[s], sel[s + 1]
			local ax, ay, bx, by = x[a], y[a], x[b], y[b]
			local wa, wb, da, db = wd[a], wd[b], dp[a], dp[b]
			local reach = max(wa, wb) * 0.5 + 4 * (max(fp[a], fp[b]) + 0.5)
			local i0 = max(0, floor((min(ax, bx) - reach) / 4))
			local i1 = min(Wf - 1, ceil((max(ax, bx) + reach) / 4))
			local j0 = max(0, floor((min(ay, by) - reach) / 4))
			local j1 = min(Hf - 1, ceil((max(ay, by) + reach) / 4))
			local vx, vy = bx - ax, by - ay
			local L2 = vx * vx + vy * vy
			if L2 < 1e-9 then L2 = 1e-9 end
			for j = j0, j1 do
				local py = j * 4
				local row = j * Wf + 1
				for i = i0, i1 do
					local px = i * 4
					local t = ((px - ax) * vx + (py - ay) * vy) / L2
					if t < 0 then t = 0 elseif t > 1 then t = 1 end
					local qx, qy = ax + t * vx - px, ay + t * vy - py
					local dist = sqrt(qx * qx + qy * qy)
					if dist < reach then
						local half = (wa + (wb - wa) * t) * 0.5
						local prof = (dist - half) * 0.25
						local depth = da + (db - da) * t
						if prof < -depth then prof = -depth end
						local k = row + i
						if prof < H[k] then H[k] = prof end
					end
				end
			end
		end
		if ctx then ctx.tick() end
	end
end

return M

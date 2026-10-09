--[[
gullies.lua - erosion-like texture: spurs and gullies that run downhill on every slope (pure Lua 5.2).

WHY (run 6, 2026-10-07)
  After the run 5 rework our relief per wavelength band matched vanilla Temperate, yet the owner still saw hills and
  mountains as "too smooth / blended". Close-up hillshades showed why: vanilla mountains are cut by ridges and
  gullies that run straight down the slopes and branch (the look of water erosion); ours had smooth slopes with an
  isotropic noise "orange peel" on top. Measured on the run 6 exports (hill land, |curvature| p90 at 8 m / 32 m):
  vanilla 15.5 / 5.9, ours 4-9 / 2-5. Real erosion is far too slow in Lua at 4 m on a 16 km map, so this module
  draws its result directly.

HOW (Gabor stripes aligned with the slope)
  Each point sums cosine stripes from the 3 x 3 nearest cells of a jittered lattice (cell = one wavelength); the
  stripes' crests run along the local downhill direction, and every cell's stripes are shifted by its jittered centre
  and flipped by its own random sign. Where neighbouring cells agree the stripes are clear spurs and gullies; where
  they disagree they fade, merge or end, which reads as branching. The sign (phase 0 or pi) rather than a free phase
  keeps each cell's stripes symmetric in the slope direction: across a ridge or valley line the downhill direction
  flips, and a free phase drew a dotted seam along every crest (seen in the first previews, 2026-10-07). Two octaves: the second follows the slope of the land plus the first octave, so small side gullies
  run down the flanks of the big spurs (the herringbone pattern of eroded hills).
  Depth = K x local slope x wavelength: steep mountainsides are deeply dissected, gentle slopes barely, flat land
  (towns, stations, floodplains, pass floors) not at all. That keeps the playability rules: the texture never adds
  relief to buildable flat ground.

COST
  Computed on a TEXTURE grid of T metres (16 m: >= 7 samples per wavelength), only where the land is rough, row
  by row on demand, so memory stays at a few rows; detail.lua interpolates it to 4 m (Catmull-Rom). Measured in
  Lua 5.2: ~0.8 s per million texture nodes per octave (16 km map: about 1 M nodes, most of them skipped on plains).

USE (from detail.lua)
  local f = gullies.new(hc, rough, g, settings, seed, Wf, Hf, ctx)   -- nil when no texture is wanted
  f.T, f.RT, f.w, f.h                                   -- texture cell (m), 4 m nodes per cell, grid size
  local row = f:row(jt)                                 -- array (index it + 1) of metres to add, cached
]]

local noise = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/noise.lua"

local M = {}

local floor, sqrt, cos, sin, min, max = math.floor, math.sqrt, math.cos, math.sin, math.min, math.max
local PI2 = 2 * math.pi

M.T = 16          -- metres: texture grid cell
M.LAMBDA1 = 300   -- metres: spacing of the main spurs and gullies (vanilla mountains: ~150-300 m)
M.LAMBDA2 = 115   -- metres: side gullies on the spurs
M.K1 = 0.11       -- depth of the main gullies per (slope x wavelength): slope 0.4 -> 13 m
M.K2 = 0.065      -- depth of the side gullies per (slope x wavelength)
M.BEND = 1.0      -- how strongly side gullies follow the main spurs' flanks
M.JITTER = 0.25   -- lattice jitter (cells): breaks the lattice regularity
M.RADIUS2 = 1.44  -- squared reach of one cell's stripes (cells)
M.LATTICE = 256   -- random-table period (cells): 77 km at LAMBDA1, never visible

-- Per-seed lattice tables: jitter x, y and phase per cell
local function lattice(seed, ctx)
	local r = noise.rng(noise.derive(seed, "gullies"))
	local N = M.LATTICE
	local jx, jy, ph = {}, {}, {}
	for k = 0, N * N - 1 do
		if ctx and k % 4096 == 0 then ctx.tick() end
		jx[k] = 0.5 + (r:next() - 0.5) * 2 * M.JITTER
		jy[k] = 0.5 + (r:next() - 0.5) * 2 * M.JITTER
		ph[k] = r:next() < 0.5 and 0 or PI2 * 0.5 -- a sign, not a free phase (header: seams on ridges)
	end
	return jx, jy, ph
end

--[[ Stripes at lattice position (u, v) (cells); (qx, qy) = unit vector ACROSS the slope, so the phase changes
  across the slope and the crests run downhill. Returns the value (about -1 .. 1) and d(value)/d(phase), from
  which the caller gets the gradient of the stripes (per cell: times 2 pi along q). ]]
local function gabor(u, v, qx, qy, jx, jy, ph)
	local N = M.LATTICE
	local iu, iv = floor(u), floor(v)
	local acc, dacc, w2 = 0, 0, 0
	local r2, inv = M.RADIUS2, 1 / M.RADIUS2
	for cj = iv - 1, iv + 1 do
		local rj = (cj % N) * N
		for ci = iu - 1, iu + 1 do
			local k = rj + ci % N
			local ex, ey = u - ci - jx[k], v - cj - jy[k]
			local d2 = ex * ex + ey * ey
			if d2 < r2 then
				local w = 1 - d2 * inv
				w = w * w
				local s = PI2 * (ex * qx + ey * qy) + ph[k]
				acc = acc + w * cos(s)
				dacc = dacc - w * sin(s)
				w2 = w2 + w * w
			end
		end
	end
	if w2 <= 0 then return 0, 0 end
	local norm = 1 / sqrt(w2) -- keeps the variance steady where few cells overlap
	return acc * norm, dacc * norm
end

-- The same stripes without the derivative (the last octave needs no direction for a further one)
local function gaborValue(u, v, qx, qy, jx, jy, ph)
	local N = M.LATTICE
	local iu, iv = floor(u), floor(v)
	local acc, w2 = 0, 0
	local r2, inv = M.RADIUS2, 1 / M.RADIUS2
	for cj = iv - 1, iv + 1 do
		local rj = (cj % N) * N
		for ci = iu - 1, iu + 1 do
			local k = rj + ci % N
			local ex, ey = u - ci - jx[k], v - cj - jy[k]
			local d2 = ex * ex + ey * ey
			if d2 < r2 then
				local w = 1 - d2 * inv
				w = w * w
				acc = acc + w * cos(PI2 * (ex * qx + ey * qy) + ph[k])
				w2 = w2 + w * w
			end
		end
	end
	if w2 <= 0 then return 0 end
	return acc / sqrt(w2)
end

-- hc = coarse heights, rough = coarse roughness 0..1 (landform.lua), g = coarse grid { w, h, cell }
-- ctx (optional): ticked while the tables are built, so a frame-budget runner can pause (pipeline.job)
function M.new(hc, rough, g, settings, seed, Wf, Hf, ctx)
	local strength = (settings.tune and settings.tune.gullies) or 1
	if strength <= 0 then return nil end
	local wc, hcN, cell = g.w, g.h, g.cell
	-- coarse gradient (central differences), read bilinearly per texture node
	local GX, GY = {}, {}
	for j = 0, hcN - 1 do
		if ctx then ctx.tick() end
		for i = 0, wc - 1 do
			local k = j * wc + i + 1
			local il, ir = i > 0 and k - 1 or k, i < wc - 1 and k + 1 or k
			local jd, ju = j > 0 and k - wc or k, j < hcN - 1 and k + wc or k
			GX[k] = (hc[ir] - hc[il]) / (cell * ((il ~= k and ir ~= k) and 2 or 1))
			GY[k] = (hc[ju] - hc[jd]) / (cell * ((jd ~= k and ju ~= k) and 2 or 1))
		end
	end
	-- coarse rows with any roughness (texture rows elsewhere are zero)
	local roughRow = {}
	for j = 0, hcN - 1 do
		local any = false
		for i = 0, wc - 1 do
			if rough[j * wc + i + 1] > 0 then any = true break end
		end
		roughRow[j] = any
	end
	local jx, jy, ph = lattice(seed, ctx)
	local T = M.T
	local RT = floor(T / 4 + 0.5)
	-- one spare node past each far edge: the cubic reads up to two cells beyond the last 4 m node
	local f = { T = T, RT = RT, w = floor((Wf - 1) / RT) + 3, h = floor((Hf - 1) / RT) + 3 }
	local zero = {}
	for it = 1, f.w do zero[it] = 0 end
	local cache = {}
	local l1, l2 = M.LAMBDA1, M.LAMBDA2
	local k1, k2 = M.K1 * strength, M.K2 * strength
	local c1 = PI2 / l1
	local bend = M.BEND
	local s2 = 37.17 -- octave offset (cells) so the two octaves do not share lattice points

	local function compute(jt)
		local y = jt * T
		local fy = y / cell
		local jc = min(floor(fy), hcN - 2)
		local ty = min(1, fy - jc) -- the spare rows past the far edge repeat the last one
		if not (roughRow[jc] or roughRow[jc + 1]) then return zero end
		local out = {}
		local r0, r1 = jc * wc, (jc + 1) * wc
		for it = 0, f.w - 1 do
			local x = it * T
			local fx = x / cell
			local ic = min(floor(fx), wc - 2)
			local tx = min(1, fx - ic)
			local a, b, c, d = r0 + ic + 1, r0 + ic + 2, r1 + ic + 1, r1 + ic + 2
			local w00, w10, w01, w11 = (1 - tx) * (1 - ty), tx * (1 - ty), (1 - tx) * ty, tx * ty
			local r = w00 * rough[a] + w10 * rough[b] + w01 * rough[c] + w11 * rough[d]
			local val = 0
			if r > 0.01 then
				local gx = w00 * GX[a] + w10 * GX[b] + w01 * GX[c] + w11 * GX[d]
				local gy = w00 * GY[a] + w10 * GY[b] + w01 * GY[c] + w11 * GY[d]
				local sl = sqrt(gx * gx + gy * gy)
				if sl > 1e-4 then
					-- main spurs: crests along the downhill direction
					local qx, qy = gy / sl, -gx / sl
					local v1, dv1 = gabor(x / l1, y / l1, qx, qy, jx, jy, ph)
					local a1 = k1 * sl * l1 * r
					-- side gullies follow the slope of land + main spurs
					local tx2, ty2 = gx + bend * a1 * dv1 * c1 * qx, gy + bend * a1 * dv1 * c1 * qy
					local st = sqrt(tx2 * tx2 + ty2 * ty2)
					local v2 = 0
					if st > 1e-4 then
						v2 = gaborValue(x / l2 + s2, y / l2 - s2, ty2 / st, -tx2 / st, jx, jy, ph)
					end
					val = a1 * v1 + k2 * min(st, 1) * l2 * r * v2
				end
			end
			out[it + 1] = val
		end
		return out
	end

	function f.row(self, jt)
		local row = cache[jt]
		if row == nil then
			row = compute(min(jt, self.h - 1))
			cache[jt] = row
			cache[jt - 4] = nil -- rows are read in order: keep a few
		end
		return row
	end
	return f
end

return M

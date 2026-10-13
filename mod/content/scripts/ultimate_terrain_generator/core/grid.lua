--[[
grid.lua - flat-array grid helpers shared by the core modules (pure Lua 5.2).

LAYOUT (the same as the engine's GameMap.heightmap)
  A grid of w x h nodes is a plain Lua array; node (i, j), 0-based, is a[j * w + i + 1]; i (x) runs fastest.
  Node (i, j) sits at local position (i * cell, j * cell) metres from the map's min corner. Hot loops in the
  other modules index arrays directly instead of calling helpers, because a function call per node costs more
  than the work itself in Lua.

ctx (optional) = { tick = function() end }: called once per row in the long helpers, so a frame-budget runner can
pause the work (pipeline.job).

WHAT IS HERE
  M.new(n, value)                       array of n copies of value
  M.blur(a, w, h, radius, keep, ctx)    separable box blur in place; keep(k) -> true leaves node k unchanged
  M.percentile(a, w, h, p, include)     p-quantile (0..1) of the nodes where include(k) is true
  M.sample(a, w, h, cell, x, y)         bilinear value at local position (x, y) metres, clamped to the grid
  M.nearestSeed(w, h, cell, seeds, maxCost, ctx)
                                        for every node, the seed with the lowest cost = distance - seed.off
                                        (vector-propagation distance transform, two sweeps per round); used for
                                        distance to the coast and for valley floors around rivers of any width
  M.chaikin(x, y, iterations)           polyline corner cutting (endpoints fixed)
  M.resample(x, y, step)                polyline at uniform spacing (+ fractional input index per point)
]]

local M = {}

local sqrt, floor, min, max = math.sqrt, math.floor, math.min, math.max

function M.new(n, value)
	local a = {}
	for k = 1, n do a[k] = value end
	return a
end

-- Box blur of radius r (window 2r + 1) along x, then along y; edges use the nodes that exist.
function M.blur(a, w, h, r, keep, ctx)
	local tmp = {}
	for j = 0, h - 1 do
		local row = j * w
		for i = 0, w - 1 do
			local s, c = 0, 0
			for d = max(0, i - r), min(w - 1, i + r) do
				s = s + a[row + d + 1]
				c = c + 1
			end
			tmp[row + i + 1] = s / c
		end
		if ctx then ctx.tick() end
	end
	for j = 0, h - 1 do
		for i = 0, w - 1 do
			local k = j * w + i + 1
			if not (keep and keep(k)) then
				local s, c = 0, 0
				for d = max(0, j - r), min(h - 1, j + r) do
					s = s + tmp[d * w + i + 1]
					c = c + 1
				end
				a[k] = s / c
			end
		end
		if ctx then ctx.tick() end
	end
end

function M.percentile(a, w, h, p, include)
	local v = {}
	for k = 1, w * h do
		if include == nil or include(k) then v[#v + 1] = a[k] end
	end
	if #v == 0 then return 0 end
	table.sort(v)
	return v[max(1, min(#v, floor(p * (#v - 1)) + 1))]
end

function M.sample(a, w, h, cell, x, y)
	local fx = min(max(x / cell, 0), w - 1.000001)
	local fy = min(max(y / cell, 0), h - 1.000001)
	local i, j = floor(fx), floor(fy)
	local tx, ty = fx - i, fy - j
	local k = j * w + i + 1
	local v0 = a[k] + tx * (a[k + 1] - a[k])
	local v1 = a[k + w] + tx * (a[k + w + 1] - a[k + w])
	return v0 + ty * (v1 - v0)
end

--[[ seeds = { n = count, x = {}, y = {}, off = {}, node = {} } (positions in local metres, node = 1-based grid
  index the seed starts from; several seeds may share a node, the cheapest wins). Returns best (array of seed
  ids, 0 = none) and cost (array of distance - off, math.huge where no seed is within maxCost). Two rounds of a
  forward and a backward sweep; each node tries the seeds of its already-swept neighbours. The result is exact
  for single points and within a fraction of a cell for lines, which is all the terrain needs. ]]
function M.nearestSeed(w, h, cell, seeds, maxCost, ctx)
	local n = w * h
	local best, cost = {}, {}
	local huge = math.huge
	for k = 1, n do best[k] = 0; cost[k] = huge end
	if ctx then ctx.tick() end
	local sx, sy, soff = seeds.x, seeds.y, seeds.off
	for s = 1, seeds.n do
		local k = seeds.node[s]
		local i, j = (k - 1) % w, floor((k - 1) / w)
		local dx, dy = i * cell - sx[s], j * cell - sy[s]
		local c = sqrt(dx * dx + dy * dy) - soff[s]
		if c < cost[k] then cost[k] = c; best[k] = s end
	end
	local limit = maxCost or huge
	local function try(k, x, y, nb)
		local s = best[nb]
		if s > 0 then
			local dx, dy = x - sx[s], y - sy[s]
			local c = sqrt(dx * dx + dy * dy) - soff[s]
			if c < cost[k] and c <= limit then cost[k] = c; best[k] = s end
		end
	end
	for _ = 1, 2 do
		for j = 0, h - 1 do -- forward: W, NW, N, NE (rows of smaller j are done)
			local y = j * cell
			for i = 0, w - 1 do
				local k = j * w + i + 1
				local x = i * cell
				if i > 0 then try(k, x, y, k - 1) end
				if j > 0 then
					try(k, x, y, k - w)
					if i > 0 then try(k, x, y, k - w - 1) end
					if i < w - 1 then try(k, x, y, k - w + 1) end
				end
			end
			if ctx then ctx.tick() end
		end
		for j = h - 1, 0, -1 do -- backward: E, SE, S, SW
			local y = j * cell
			for i = w - 1, 0, -1 do
				local k = j * w + i + 1
				local x = i * cell
				if i < w - 1 then try(k, x, y, k + 1) end
				if j < h - 1 then
					try(k, x, y, k + w)
					if i < w - 1 then try(k, x, y, k + w + 1) end
					if i > 0 then try(k, x, y, k + w - 1) end
				end
			end
			if ctx then ctx.tick() end
		end
	end
	return best, cost
end

-- Chaikin corner cutting, endpoints fixed.
function M.chaikin(x, y, iterations)
	for _ = 1, iterations do
		local n = #x
		if n < 3 then return x, y end
		local nx, ny = { x[1] }, { y[1] }
		for i = 1, n - 1 do
			nx[#nx + 1] = 0.75 * x[i] + 0.25 * x[i + 1]
			ny[#ny + 1] = 0.75 * y[i] + 0.25 * y[i + 1]
			nx[#nx + 1] = 0.25 * x[i] + 0.75 * x[i + 1]
			ny[#ny + 1] = 0.25 * y[i] + 0.75 * y[i + 1]
		end
		nx[#nx + 1], ny[#ny + 1] = x[n], y[n]
		x, y = nx, ny
	end
	return x, y
end

-- Resample a polyline at uniform spacing; returns x, y and, for every new point, the fractional index into the
-- input (used to carry attributes along).
function M.resample(x, y, step)
	local ox, oy, ot = { x[1] }, { y[1] }, { 1 }
	local carry = 0
	for i = 1, #x - 1 do
		local dx, dy = x[i + 1] - x[i], y[i + 1] - y[i]
		local len = sqrt(dx * dx + dy * dy)
		local pos = step - carry
		while pos <= len do
			local t = pos / len
			ox[#ox + 1], oy[#oy + 1], ot[#ot + 1] = x[i] + dx * t, y[i] + dy * t, i + t
			pos = pos + step
		end
		carry = len - (pos - step)
	end
	if carry > step * 0.25 then
		ox[#ox + 1], oy[#oy + 1], ot[#ot + 1] = x[#x], y[#y], #x
	end
	return ox, oy, ot
end

return M

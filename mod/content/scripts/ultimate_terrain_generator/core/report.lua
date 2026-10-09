--[[
report.lua - the map report: the playability numbers (soft targets), measured on the final heightmap
(pure Lua 5.2). These are soft targets (owner decision 9a.4): the report shows them, nothing is "fixed".

MEASURED (on every 2nd node, i.e. an 8 m grid; slopes by central differences)
  land / water shares; land slope classes: < 3 % (towns and stations), 3 - 8.5 % (rail can be built),
  8.5 - 25 %, > 25 %; land height median, 99th percentile and maximum; rivers: count, total length, ship
  rivers, ship length and the share of ship-course points that really lie in water at least 2 m deep; lakes; oxbow lakes; puddles
  (water patches under 3200 m^2 that no river, lake or sea explains, which should be 0).
  corridors (mountain passes, passes.lua): along each route on the final heights, the summit height and the
  steepest grade over any 100 m (about a train length; bridges over water count as level).
]]

local M = {}

local floor, max, min, sqrt, abs = math.floor, math.max, math.min, math.sqrt, math.abs
local DI4, DJ4 = { -1, 1, 0, 0 }, { 0, 0, -1, 1 }

-- Water at full-resolution node (i, j) belongs to a large body (more than LIMIT nodes, or touching the edge)?
local LIMIT = 4000
local function connectsAtFullRes(H, Wf, Hf, i, j)
	local seen, stack, count = {}, { j * Wf + i + 1 }, 0
	seen[stack[1]] = true
	while #stack > 0 do
		local k = stack[#stack]
		stack[#stack] = nil
		count = count + 1
		if count > LIMIT then return true end
		local ci, cj = (k - 1) % Wf, floor((k - 1) / Wf)
		if ci == 0 or cj == 0 or ci == Wf - 1 or cj == Hf - 1 then return true end
		for d = 1, 4 do
			local nk = (cj + DJ4[d]) * Wf + ci + DI4[d] + 1
			if not seen[nk] and H[nk] < 0 then
				seen[nk] = true
				stack[#stack + 1] = nk
			end
		end
	end
	return false
end

-- Height of the final map at local (x, y) metres, bilinear.
local function heightAt(H, Wf, Hf, x, y)
	local fx = min(max(x / 4, 0), Wf - 1.000001)
	local fy = min(max(y / 4, 0), Hf - 1.000001)
	local i, j = floor(fx), floor(fy)
	local tx, ty = fx - i, fy - j
	local k = j * Wf + i + 1
	local v0 = H[k] + tx * (H[k + 1] - H[k])
	local v1 = H[k + Wf] + tx * (H[k + Wf + 1] - H[k + Wf])
	return v0 + ty * (v1 - v0)
end

-- Summit and steepest 100 m grade of a corridor route; water points are bridged (level between dry banks).
local function corridorStats(H, Wf, Hf, c)
	local n = #c.x
	local s, hs, dry = { 0 }, {}, {}
	for q = 1, n do
		if q > 1 then
			local dx, dy = c.x[q] - c.x[q - 1], c.y[q] - c.y[q - 1]
			s[q] = s[q - 1] + sqrt(dx * dx + dy * dy)
		end
		hs[q] = heightAt(H, Wf, Hf, c.x[q], c.y[q])
		dry[q] = hs[q] >= 0.3
	end
	-- bridges: replace wet stretches by the line between the dry ends
	local q = 1
	while q <= n do
		if not dry[q] then
			local a = q - 1
			local b = q
			while b <= n and not dry[b] do b = b + 1 end
			for r = q, b - 1 do
				if a >= 1 and b <= n then
					hs[r] = hs[a] + (hs[b] - hs[a]) * (s[r] - s[a]) / max(1e-6, s[b] - s[a])
				else
					hs[r] = (a >= 1) and hs[a] or (b <= n and hs[b] or 0)
				end
			end
			q = b
		else
			q = q + 1
		end
	end
	local summit, steep, b = -math.huge, 0, 1
	for a = 1, n do
		if hs[a] > summit then summit = hs[a] end
		while b < n and s[b] - s[a] < 100 do b = b + 1 end
		if s[b] - s[a] >= 100 then steep = max(steep, abs(hs[b] - hs[a]) / (s[b] - s[a])) end
	end
	return { summit = summit, grade = steep, length = s[n], target = c.target }
end

-- coarse = { g, kind } (optional): open-sea cells are known big water, so the puddle flood skips the sea
function M.build(H, Wf, Hf, paths, lakes, ctx, corridors, coarse)
	local S = 2
	-- slope statistics: every 8 m up to ~12 km maps, every 16 m above (same measure, fewer samples)
	local SS = Wf > 3200 and 4 or 2
	local land, water = 0, 0
	local c3, c85, c25, cSteep = 0, 0, 0, 0
	local HB, HLO = 4, -100 -- histogram bins per metre, lowest height
	local hist, nh, hmax = {}, 0, -math.huge
	for j = SS, Hf - 1 - SS, SS do
		local row = j * Wf + 1
		for i = SS, Wf - 1 - SS, SS do
			local k = row + i
			local v = H[k]
			if v < 0 then
				water = water + 1
			else
				land = land + 1
				if (i % 8 == 0) and (j % 8 == 0) then
					local b = floor((v - HLO) * HB)
					hist[b] = (hist[b] or 0) + 1
					nh = nh + 1
					if v > hmax then hmax = v end
				end
				local sx = (H[k + 1] - H[k - 1]) / 8
				local sy = (H[k + Wf] - H[k - Wf]) / 8
				local s = sqrt(sx * sx + sy * sy)
				if s < 0.03 then c3 = c3 + 1
				elseif s < 0.085 then c85 = c85 + 1
				elseif s < 0.25 then c25 = c25 + 1
				else cSteep = cSteep + 1 end
			end
		end
		if ctx then ctx.tick() end
	end
	local function q(p) -- height below which a share p of the land samples lies (to 0.25 m)
		if nh == 0 then return 0 end
		local want, acc = max(1, floor(p * nh)), 0
		for b = 0, floor((hmax - HLO) * HB) + 1 do
			acc = acc + (hist[b] or 0)
			if acc >= want then return HLO + (b + 0.5) / HB end
		end
		return hmax
	end
	local total = max(1, land + water)
	local L = max(1, land)

	-- rivers
	local nRiv, len, shipLen, shipPts, shipWet, deltas, oxbows, nShip = 0, 0, 0, 0, 0, 0, 0, 0
	for _, p in ipairs(paths) do
		if p.kind == "oxbow" then oxbows = oxbows + 1
		elseif p.kind == "delta" then deltas = deltas + 1 else nRiv = nRiv + 1 end
		if p.kind ~= "oxbow" then len = len + p.length end
		-- rivers with ship water (a delta channel is part of its river)
		if p.kind ~= "delta" and p.ship then
			for i = 1, #p.x do
				if p.ship[i] then nShip = nShip + 1 break end
			end
		end
		for i = 2, #p.x do
			if p.ship[i] then
				local dx, dy = p.x[i] - p.x[i - 1], p.y[i] - p.y[i - 1]
				shipLen = shipLen + sqrt(dx * dx + dy * dy)
				local ii, jj = floor(p.x[i] / 4 + 0.5), floor(p.y[i] / 4 + 0.5)
				if ii >= 0 and jj >= 0 and ii < Wf and jj < Hf then
					shipPts = shipPts + 1
					if H[jj * Wf + ii + 1] <= -2 then shipWet = shipWet + 1 end
				end
			end
		end
	end
	local lakeArea = 0
	for _, l in ipairs(lakes) do lakeArea = lakeArea + l.area end

	-- puddles: small water components on the 8 m grid
	local gw, gh = floor((Wf - 1) / S) + 1, floor((Hf - 1) / S) + 1
	-- a sample inside a coarse cell whose four corners are open sea is big water: never flood the whole sea
	local seaCore = function() return false end
	if coarse and coarse.kind then
		local cw_, ch_, kind = coarse.g.w, coarse.g.h, coarse.kind
		local R = coarse.g.cell / 4
		seaCore = function(gi, gj)
			local ic, jc = floor(gi * S / R), floor(gj * S / R)
			if ic >= cw_ - 1 or jc >= ch_ - 1 then return false end
			local k = jc * cw_ + ic + 1
			return kind[k] == 1 and kind[k + 1] == 1 and kind[k + cw_] == 1 and kind[k + cw_ + 1] == 1
		end
	end
	local seen = {}
	local puddles, puddleAt = 0, {}
	local MAX_SMALL = 50 -- samples of 64 m^2
	for gj = 0, gh - 1 do
		for gi = 0, gw - 1 do
			local gk = gj * gw + gi + 1
			if not seen[gk] and H[gj * S * Wf + gi * S + 1] < 0 and not seaCore(gi, gj) then
				local stack, count = { gk }, 0
				seen[gk] = true
				local big = false
				while #stack > 0 do
					local c = stack[#stack]
					stack[#stack] = nil
					count = count + 1
					if ctx and count % 8192 == 0 then ctx.tick() end -- the sea is one huge component
					if count > MAX_SMALL then big = true end
					local ci, cj = (c - 1) % gw, floor((c - 1) / gw)
					if ci == 0 or cj == 0 or ci == gw - 1 or cj == gh - 1 then
						big = true -- touches the map edge: sea or a river leaving the map
					end
					for d = 1, 4 do
						local ni, nj = ci + DI4[d], cj + DJ4[d]
						if ni >= 0 and nj >= 0 and ni < gw and nj < gh then
							local nk = nj * gw + ni + 1
							if not seen[nk] and H[nj * S * Wf + ni * S + 1] < 0 then
								seen[nk] = true
								if seaCore(ni, nj) then big = true else stack[#stack + 1] = nk end
							end
						end
					end
				end
				-- a small patch on the 8 m grid may be the thin end of a stream: confirm at full resolution
				if not big and connectsAtFullRes(H, Wf, Hf, gi * S, gj * S) then big = true end
				if not big then
					puddles = puddles + 1
					if #puddleAt < 10 then puddleAt[#puddleAt + 1] = { gi * S * 4, gj * S * 4, count } end
				end
			end
		end
		if ctx then ctx.tick() end
	end

	local corr = {}
	for _, c in ipairs(corridors or {}) do corr[#corr + 1] = corridorStats(H, Wf, Hf, c) end

	return {
		landShare = land / total, waterShare = water / total,
		flat = c3 / L, railable = c85 / L, steep = c25 / L, verySteep = cSteep / L,
		heightMedian = q(0.5), heightP99 = q(0.99), heightMax = nh > 0 and hmax or 0,
		rivers = nRiv, deltaChannels = deltas, riverLength = len, shipRivers = nShip, shipLength = shipLen,
		shipWet = shipPts > 0 and shipWet / shipPts or 1,
		lakes = #lakes, lakeArea = lakeArea, oxbows = oxbows, puddles = puddles, puddleAt = puddleAt,
		corridors = corr,
	}
end

function M.format(r)
	local lines = {
		string.format("land %.0f %%, water %.0f %%", 100 * r.landShare, 100 * r.waterShare),
		string.format("land slope: flat (<3 %%) %.0f %%, rail (3-8.5 %%) %.0f %%, steep (8.5-25 %%) %.0f %%, very steep %.0f %%",
			100 * r.flat, 100 * r.railable, 100 * r.steep, 100 * r.verySteep),
		string.format("land height: median %.0f m, 99 %% %.0f m, max %.0f m", r.heightMedian, r.heightP99, r.heightMax),
		string.format("rivers %d (+%d delta channels), %.1f km; ship rivers %d, %.1f km (%.0f %% of their course >= 2 m deep)",
			r.rivers, r.deltaChannels, r.riverLength / 1000, r.shipRivers, r.shipLength / 1000, 100 * r.shipWet),
		string.format("lakes %d (%.2f km2), oxbow lakes %d; puddles %d", r.lakes, r.lakeArea / 1e6, r.oxbows, r.puddles),
	}
	if r.corridors and #r.corridors > 0 then
		local parts = {}
		for _, c in ipairs(r.corridors) do
			parts[#parts + 1] = string.format("%.1f km, summit %.0f m, steepest 100 m %.1f %% (target %.1f %%)",
				c.length / 1000, c.summit, 100 * c.grade, 100 * c.target)
		end
		lines[#lines + 1] = "passes: " .. table.concat(parts, "; ")
	end
	-- settings the map could not satisfy (pipeline sets shipsAsked and lakesWanted)
	local asked = r.shipsAsked
	if asked ~= nil and asked > 0 and r.shipRivers < asked then
		lines[#lines + 1] = string.format("note: Ship rivers asked for %s, this map has %d: it has too few large rivers "
			.. "(try Water Wet, Rivers above 100 %%, another seed or a larger map)", asked == 1 and "One" or "Several",
			r.shipRivers)
	end
	if r.lakesWanted ~= nil and r.lakes < r.lakesWanted then
		lines[#lines + 1] = string.format("note: %d lakes wanted, %d made: the rivers offer no more lake sites "
			.. "(lakes form only in natural basins on a river)", r.lakesWanted, r.lakes)
	end
	return table.concat(lines, "\n")
end

return M

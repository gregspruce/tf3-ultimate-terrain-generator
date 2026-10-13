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
  strait (Sea Strait, 2026-10-12): the width of each narrows and the narrowest crossing at the water line, and whether
  ships pass end to end (straitStats). The strait is neither a river nor a ship river.
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

--[[ Sea Strait: a section every 25 m along the strait's axis (shapes.lua out.strait; it follows the water) on the final
  heights. Across each section (nearest node, 4 m steps, at most WALK m each side): the water-line width and the
  navigable width (>= 2 m deep) of the water run through the axis point. A walk that leaves the map in water is open
  sea (the strait's ends; no crossing there). Each narrows is the narrowest section within 1 km of the designed one,
  refined by oblique lines (+-30 degrees, +-200 m along the axis, 2 m steps on interpolated heights: a section across a
  curving channel overstated it by up to 9 m). Returns the narrows, the narrowest crossing anywhere, and whether ships
  pass end to end: every section's axis point in water >= 2 m deep with at least SHIP_W metres of such water around it. ]]
local WALK, SHIP_W = 1200, 100
local function straitStats(H, Wf, Hf, st, ctx)
	local x, y, n = st.x, st.y, #st.x
	local W, Hm = (Wf - 1) * 4, (Hf - 1) * 4
	local function at(px, py)
		if px < 0 or py < 0 or px > W or py > Hm then return nil end
		return H[floor(py / 4 + 0.5) * Wf + floor(px / 4 + 0.5) + 1]
	end
	local width, sections, bad, minNav = {}, 0, 0, math.huge
	for q = 1, n do
		local px, py = x[q], y[q]
		local h0 = at(px, py)
		if h0 ~= nil then
			sections = sections + 1
			local a, b = max(1, q - 8), min(n, q + 8) -- (the direction over +-200 m: the headlands bend the axis)
			local tx, ty = x[b] - x[a], y[b] - y[a]
			local tl = max(1e-9, sqrt(tx * tx + ty * ty))
			local nx, ny = -ty / tl, tx / tl
			local wl, nav, open = 0, 0, false
			for sg = -1, 1, 2 do
				local s, navRun = 0, h0 <= -2
				while s < WALK do
					s = s + 4
					local h = at(px + sg * nx * s, py + sg * ny * s)
					if h == nil then open = true break end
					if navRun and h > -2 then navRun = false; nav = nav + s - 4 end
					if h >= 0 then break end
				end
				if navRun then nav = nav + s end
				wl = wl + s
			end
			if h0 >= 0 then wl = 0 end
			width[q] = (open or wl >= 2 * WALK) and math.huge or wl
			if h0 > -2 or nav < SHIP_W then bad = bad + 1 end
			if nav < minNav then minNav = nav end
			if ctx and q % 64 == 0 then ctx.tick() end
		end
	end
	local narrowest = math.huge
	for q = 1, n do if width[q] and width[q] < narrowest then narrowest = width[q] end end
	-- the water-line width of the line through (px, py) along +-(dx, dy) (heights interpolated, the water line between
	-- two samples); nil when the point is land or the line leaves the map or the walk in water
	local function hAt(px, py)
		if px < 0 or py < 0 or px > W or py > Hm then return nil end
		local fx, fy = px / 4, py / 4
		local i, j = min(Wf - 2, floor(fx)), min(Hf - 2, floor(fy))
		local a, b = fx - i, fy - j
		local k = j * Wf + i + 1
		return (H[k] * (1 - a) + H[k + 1] * a) * (1 - b) + (H[k + Wf] * (1 - a) + H[k + Wf + 1] * a) * b
	end
	local function crossing(px, py, dx, dy)
		local h0 = hAt(px, py)
		if h0 == nil or h0 >= 0 then return nil end
		local w = 0
		for sg = -1, 1, 2 do
			local s, prev = 0, h0
			while true do
				s = s + 2
				if s > WALK then return nil end
				local h = hAt(px + sg * dx * s, py + sg * dy * s)
				if h == nil then return nil end
				if h >= 0 then w = w + s - 2 + 2 * prev / (prev - h); break end
				prev = h
			end
		end
		return w
	end
	local narrows = {}
	local r = floor(1000 / (st.step or 25) + 0.5)
	for k, idx in ipairs(st.narrows or {}) do
		local m, qm = math.huge, nil
		for q = max(1, idx - r), min(n, idx + r) do if width[q] and width[q] < m then m, qm = width[q], q end end
		if qm then
			local a, b = max(1, qm - 8), min(n, qm + 8)
			local tx, ty = x[b] - x[a], y[b] - y[a]
			local base = math.atan2(tx, -ty) -- the section's normal
			for q = max(1, qm - 8), min(n, qm + 8) do
				for da = -30, 30, 5 do
					local an = base + math.rad(da)
					local c = crossing(x[q], y[q], math.cos(an), math.sin(an))
					if c and c < m then m = c end
				end
			end
			if ctx then ctx.tick() end
		end
		narrows[k] = m
		if m < narrowest then narrowest = m end
	end
	return { narrows = narrows, narrowest = narrowest, pass = sections > 0 and bad == 0, badSections = bad,
		sections = sections, minNav = minNav }
end

-- coarse = { g, kind [, strait] } (optional): open-sea cells are known big water, so the puddle flood skips the sea;
-- strait: the Sea Strait's axis (shapes.lua out.strait), measured by straitStats
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
	local strait = (coarse and coarse.strait) and straitStats(H, Wf, Hf, coarse.strait, ctx) or nil

	return {
		strait = strait,
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
	-- Sea Strait (not a river: its water counts in neither rivers nor ship rivers)
	local st = r.strait
	if st then
		local ws = {}
		for k, v in ipairs(st.narrows) do ws[k] = v < math.huge and string.format("%.0f m", v) or "open" end
		local narrowest = st.narrowest < math.huge and string.format("%.0f m", st.narrowest) or "over 2.4 km"
		lines[#lines + 1] = string.format("strait: %d narrows (%s across at the water line), narrowest crossing %s; "
			.. "ships pass end to end: %s", #st.narrows, table.concat(ws, ", "), narrowest,
			st.pass and "yes" or string.format("no (%d of %d sections under 100 m wide at 2 m deep)", st.badSections,
				st.sections))
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

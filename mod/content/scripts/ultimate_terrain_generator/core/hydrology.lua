--[[
hydrology.lua - drainage on the coarse grid: where water flows, how much, which channels hold water, and
where lakes sit (pure Lua 5.2).

WHY THIS ORDER ("hydrology first")
  The map has one water level (0 m), so a river can only show water where its valley floor is near 0 m. We
  therefore decide the drainage network FIRST and build the land around it (landform.lua): every valley then
  belongs to a river, rivers never run uphill, and lakes are fed and drained by rivers.

WHAT IS HERE
  M.flood(B, g, sea, outlets)   priority flood from the sea and the outlet nodes over the organisation field B.
                                Gives every land node a receiver (the next node downstream; 8 neighbours), a
                                topological order (outlets first) and the filled surface (B with every pit filled
                                to its spill level). One pass, no pits left, flats drain too.
  M.accumulate(f, g, inflows)   drainage area A (m^2) of every node, plus the area entering from off the map
  M.depressions(f, B, g, minDepth)
                                pits of B (filled - B > minDepth) as connected regions: natural lake sites
  M.rivers(f, A, g, aWater, minLength)
                                the channels that hold water (A >= aWater) as a tree of rivers, mouth to source:
                                main stem = the larger branch at every junction, other branches are tributaries
  M.strahler(f, A, g, water)    Strahler order of every water node (for the report and widths)

DATA
  f = { recv = {}, order = {}, filled = {} }. recv[k] > 0: receiver node; 0: sea node; -1: leaves the map
  (outlet) or flows straight into the sea (recvSea[k] = that sea node).
]]

local M = {}

local sqrt, floor, max, min = math.sqrt, math.floor, math.max, math.min

local DI = { -1, 0, 1, -1, 1, -1, 0, 1 }
local DJ = { -1, -1, -1, 0, 0, 1, 1, 1 }

function M.flood(B, g, sea, outlets, ctx)
	local w, h = g.w, g.h
	local n = w * h
	local recv, recvSea, filled, done = {}, {}, {}, {}
	local order = {}
	-- binary min-heap of node ids keyed by filled height; ties by insertion number for determinism
	local hk, hp, hn, size, counter = {}, {}, {}, 0, 0
	local function push(k, p)
		counter = counter + 1
		size = size + 1
		local c = size
		while c > 1 do
			local parent = floor(c / 2)
			local pp = hp[parent]
			if pp < p or (pp == p and hn[parent] < counter) then break end
			hk[c], hp[c], hn[c] = hk[parent], pp, hn[parent]
			c = parent
		end
		hk[c], hp[c], hn[c] = k, p, counter
	end
	local function pop()
		local top = hk[1]
		local lk, lp, ln = hk[size], hp[size], hn[size]
		hk[size], hp[size], hn[size] = nil, nil, nil
		size = size - 1
		if size > 0 then
			local c = 1
			while true do
				local l = 2 * c
				if l > size then break end
				local r = l + 1
				if r <= size and (hp[r] < hp[l] or (hp[r] == hp[l] and hn[r] < hn[l])) then l = r end
				if lp < hp[l] or (lp == hp[l] and ln < hn[l]) then break end
				hk[c], hp[c], hn[c] = hk[l], hp[l], hn[l]
				c = l
			end
			hk[c], hp[c], hn[c] = lk, lp, ln
		end
		return top
	end

	for k = 1, n do
		recv[k] = 0
		done[k] = sea[k]
		filled[k] = B[k]
	end
	-- seeds: land next to the sea drains into its lowest sea neighbour
	for j = 0, h - 1 do
		for i = 0, w - 1 do
			local k = j * w + i + 1
			if not sea[k] then
				local bestSea, bestB = nil, math.huge
				for d = 1, 8 do
					local ii, jj = i + DI[d], j + DJ[d]
					if ii >= 0 and ii < w and jj >= 0 and jj < h then
						local nb = jj * w + ii + 1
						if sea[nb] and B[nb] < bestB then bestSea, bestB = nb, B[nb] end
					end
				end
				if bestSea then
					recv[k], recvSea[k], done[k] = -1, bestSea, true
					push(k, B[k])
				end
			end
		end
	end
	for _, k in ipairs(outlets) do
		if not done[k] then
			recv[k], done[k] = -1, true
			push(k, B[k])
		end
	end
	if size == 0 then
		-- no sea and no outlet: drain through the lowest edge node so every map has an exit
		local bestK, bestB = nil, math.huge
		for k = 1, n do
			local i, j = (k - 1) % w, floor((k - 1) / w)
			if (i == 0 or j == 0 or i == w - 1 or j == h - 1) and B[k] < bestB then bestK, bestB = k, B[k] end
		end
		recv[bestK], done[bestK] = -1, true
		push(bestK, B[bestK])
	end

	local popped = 0
	while size > 0 do
		local c = pop()
		order[#order + 1] = c
		local fc = filled[c]
		local i, j = (c - 1) % w, floor((c - 1) / w)
		for d = 1, 8 do
			local ii, jj = i + DI[d], j + DJ[d]
			if ii >= 0 and ii < w and jj >= 0 and jj < h then
				local nb = jj * w + ii + 1
				if not done[nb] then
					done[nb] = true
					recv[nb] = c
					-- a pit is raised to its spill level plus a hair, so its nodes keep a strict order
					local fb = B[nb]
					if fb <= fc then fb = fc + 1e-6 end
					filled[nb] = fb
					push(nb, fb)
				end
			end
		end
		popped = popped + 1
		if ctx and popped % 4096 == 0 then ctx.tick() end
	end
	return { recv = recv, recvSea = recvSea, order = order, filled = filled }
end

-- Distance from node k to its receiver (or half a cell to the sea / map edge).
function M.stepLength(f, g, k)
	local r = f.recv[k]
	if r <= 0 then return g.cell * 0.5 end
	local w = g.w
	local di = (k - 1) % w - (r - 1) % w
	local dj = floor((k - 1) / w) - floor((r - 1) / w)
	return (di ~= 0 and dj ~= 0) and g.cell * 1.41421356 or g.cell
end

function M.accumulate(f, g, inflows)
	local A = {}
	local cellArea = g.cell * g.cell
	local order, recv = f.order, f.recv
	for idx = 1, #order do A[order[idx]] = cellArea end
	for _, p in ipairs(inflows) do
		if A[p.node] then A[p.node] = A[p.node] + p.area end
	end
	for idx = #order, 1, -1 do
		local c = order[idx]
		local r = recv[c]
		if r > 0 then A[r] = A[r] + A[c] end
	end
	return A
end

--[[ Pits of B: connected regions (8 neighbours) where the filled surface is above B by more than minDepth.
  Returns a list of { nodes = {...}, area (m^2), depth (max m in B units), spill = node the region drains to } ]]
function M.depressions(f, B, g, minDepth)
	local w, h = g.w, g.h
	local filled, recv = f.filled, f.recv
	local region = {}
	local list = {}
	for _, start in ipairs(f.order) do
		if region[start] == nil and filled[start] - B[start] > minDepth then
			local id = #list + 1
			local nodes, depth = {}, 0
			local stack = { start }
			region[start] = id
			while #stack > 0 do
				local c = stack[#stack]
				stack[#stack] = nil
				nodes[#nodes + 1] = c
				depth = max(depth, filled[c] - B[c])
				local i, j = (c - 1) % w, floor((c - 1) / w)
				for d = 1, 8 do
					local ii, jj = i + DI[d], j + DJ[d]
					if ii >= 0 and ii < w and jj >= 0 and jj < h then
						local nb = jj * w + ii + 1
						if region[nb] == nil and filled[nb] and filled[nb] - B[nb] > minDepth then
							region[nb] = id
							stack[#stack + 1] = nb
						end
					end
				end
			end
			-- the first node flooded (start, in flood order) entered the region from its spill point
			list[id] = { nodes = nodes, area = #nodes * g.cell * g.cell, depth = depth, spill = recv[start], id = id }
		end
	end
	return list, region
end

--[[ Water network as rivers. Each river = {
    nodes = {...} mouth (downstream) first, a = {A per node}, parent = river index or nil,
    junction = index into the parent's nodes where it joins, mouth = "sea" | "edge" | "junction",
    seaNode = sea node it flows into (mouth == "sea") }
  Leaf rivers shorter than minLength metres are dropped (repeatedly), so the map has no water stubs. ]]
function M.rivers(f, A, g, aWater, minLength)
	local recv, order = f.recv, f.order
	local water = {}
	for idx = 1, #order do
		local k = order[idx]
		water[k] = A[k] >= aWater
	end
	local kids = {}
	local roots = {}
	for idx = 1, #order do
		local c = order[idx]
		if water[c] then
			local r = recv[c]
			if r > 0 and water[r] then
				local l = kids[r]
				if not l then l = {}; kids[r] = l end
				l[#l + 1] = c
			else
				roots[#roots + 1] = c
			end
		end
	end

	local rivers = {}
	local queue = {}
	for _, k in ipairs(roots) do
		queue[#queue + 1] = { start = k, parent = nil, junction = nil }
	end
	local qi = 1
	while qi <= #queue do
		local q = queue[qi]
		qi = qi + 1
		local id = #rivers + 1
		local nodes, a = {}, {}
		local cur = q.start
		while cur do
			nodes[#nodes + 1] = cur
			a[#a + 1] = A[cur]
			local l = kids[cur]
			local nextNode = nil
			if l then
				local bestA = -1
				for _, c in ipairs(l) do
					if A[c] > bestA then bestA, nextNode = A[c], c end
				end
				for _, c in ipairs(l) do
					if c ~= nextNode then
						queue[#queue + 1] = { start = c, parent = id, junction = #nodes }
					end
				end
			end
			cur = nextNode
		end
		local mouth = "junction"
		if q.parent == nil then mouth = f.recvSea[q.start] and "sea" or "edge" end
		rivers[id] = { nodes = nodes, a = a, parent = q.parent, junction = q.junction, mouth = mouth,
			seaNode = f.recvSea[q.start], children = {} }
		if q.parent then
			local p = rivers[q.parent].children
			p[#p + 1] = id
		end
	end

	-- drop short leaf rivers until none is left (a parent may become a short leaf in turn)
	local function length(rv)
		local L = 0
		for idx = 1, #rv.nodes do L = L + M.stepLength(f, g, rv.nodes[idx]) end
		return L
	end
	local alive = {}
	for id = 1, #rivers do alive[id] = true end
	local changed = true
	while changed do
		changed = false
		for id = #rivers, 1, -1 do
			local rv = rivers[id]
			if alive[id] then
				local hasKid = false
				for _, c in ipairs(rv.children) do
					if alive[c] then hasKid = true break end
				end
				if not hasKid and length(rv) < minLength then
					alive[id] = false
					changed = true
				end
			end
		end
	end
	-- renumber the survivors, keeping parents before children
	local newId, kept = {}, {}
	for id = 1, #rivers do
		if alive[id] then
			kept[#kept + 1] = rivers[id]
			newId[id] = #kept
		end
	end
	for _, rv in ipairs(kept) do
		rv.parent = rv.parent and newId[rv.parent]
		local ch = {}
		for _, c in ipairs(rv.children) do
			if newId[c] then ch[#ch + 1] = newId[c] end
		end
		rv.children = ch
	end
	local keptWater = {}
	for _, rv in ipairs(kept) do
		for _, k in ipairs(rv.nodes) do keptWater[k] = true end
	end
	return kept, keptWater
end

function M.strahler(f, A, g, water)
	local recv, order = f.recv, f.order
	local s, maxKid, nMax = {}, {}, {}
	for idx = #order, 1, -1 do
		local c = order[idx]
		if water[c] then
			local m = maxKid[c] or 0
			local v = (m == 0) and 1 or ((nMax[c] or 0) >= 2 and m + 1 or m)
			s[c] = v
			local r = recv[c]
			if r > 0 and water[r] then
				if v > (maxKid[r] or 0) then maxKid[r], nMax[r] = v, 1
				elseif v == maxKid[r] then nMax[r] = nMax[r] + 1 end
			end
		end
	end
	return s
end

return M

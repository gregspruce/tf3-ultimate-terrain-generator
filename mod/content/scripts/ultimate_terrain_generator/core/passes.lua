--[[
passes.lua - graded profiles for the corridors a map type promises (mountain passes) (pure Lua 5.2).

WHY
  A map type that promises passes must deliver crossings a railway can climb (playability target: at Gentle
  relief usually under about 2.5 %; steeper on hard maps, which are allowed). A lower notch in the uplift
  alone is not enough: stream-power valleys are steep near their heads, so the crest stays a wall.

HOW
  The map type draws each pass as a winding valley axis from the foot of the range on one side to the foot on the
  other (shapes.lua; its drainage notch follows the same axis). M.profile samples the terrain along the axis (the
  lowest ground across the floor's width) and limits it to grade G in both directions: the lower envelope
  z(s) = min over s' of h(s') + G * |s - s'|. That
  only lowers, so the axis becomes a valley floor rising gently from both feet to a col. landform.lua then lets
  the hillsides rise from this floor exactly as from any valley (no cut, no walls), so the pass reads as two
  valleys meeting at a broad saddle.
  TARGET[relief]: gentle maps get railway grades, mountainous maps steeper ones (difficult maps are allowed).
]]

local grid = require "ultimate_terrain_generator::/scripts/ultimate_terrain_generator/core/grid.lua"

local M = {}

local sqrt, max, min = math.sqrt, math.max, math.min

M.TARGET = { 0.025, 0.0325, 0.04, 0.05, 0.06 } -- target grade per Relief (Gentle .. Mountainous), checked by report.lua
-- The floor is graded with a margin: on the final 4 m map the floor has about +-0.5 m of roughness
-- (interpolation, streams crossing it), which measured 15-20 % steeper over 100 m (seeds 1-4, every Relief).
M.MARGIN = 0.85

-- Axis (x, y in local metres) resampled every `step` metres, with terrain heights h and the graded floor z <= h.
-- Water on the axis (a lake, a river) counts as bridged at `low` metres, so the floor does not dive into it.
-- window (metres, the floor's half-width; landform passes PASS_FLOOR / 2): h is the lowest ground across the axis within
-- +-window, not the ground on the axis. A side valley running beside the axis inside the floor's width otherwise stayed
-- below a floor graded on the axis, and the floor ran on its rim (steepest 100 m up to 4.5 % on the final map; Alpine
-- and Mountain Range, 16 km, 2026-10-11). Every pass since 2026-10-13 (owner, run 9, REVIEW B9: Mountain Range at Gentle
-- and Mountainous too; before, an opt-in per map type, Alpine, and the curved middle steps).
function M.profile(H, g, axis, G, step, low, window)
	local x, y = grid.resample(axis.x, axis.y, step)
	local n = #x
	local hs, z, ds = {}, {}, { 0 }
	for q = 1, n do
		local v = grid.sample(H, g.w, g.h, g.cell, x[q], y[q])
		local a, b = max(1, q - 1), min(n, q + 1)
		local dx, dy = x[b] - x[a], y[b] - y[a]
		local len = sqrt(dx * dx + dy * dy)
		if len > 0 then
			local nx, ny = -dy / len, dx / len
			for _, f in ipairs({ -1, -0.5, 0.5, 1 }) do
				v = min(v, grid.sample(H, g.w, g.h, g.cell, x[q] + nx * f * window, y[q] + ny * f * window))
			end
		end
		hs[q] = max(low, v)
		z[q] = hs[q]
		if q > 1 then
			local dx, dy = x[q] - x[q - 1], y[q] - y[q - 1]
			ds[q] = sqrt(dx * dx + dy * dy)
		end
	end
	for q = 2, n do z[q] = min(z[q], z[q - 1] + G * ds[q]) end
	for q = n - 1, 1, -1 do z[q] = min(z[q], z[q + 1] + G * ds[q + 1]) end
	local length = 0
	for q = 2, n do length = length + ds[q] end
	return { x = x, y = y, h = hs, z = z, grade = G, length = length }
end

-- Profiles of all corridors of a shape (window: the floor's half-width, see M.profile).
function M.build(H, g, corridors, relief, low, window)
	local out = {}
	for _, axis in ipairs(corridors or {}) do
		if #axis.x > 1 then
			local p = M.profile(H, g, axis, M.TARGET[relief] * M.MARGIN, max(8, g.cell * 0.5), low, window)
			p.target = M.TARGET[relief]
			out[#out + 1] = p
		end
	end
	return out
end

return M

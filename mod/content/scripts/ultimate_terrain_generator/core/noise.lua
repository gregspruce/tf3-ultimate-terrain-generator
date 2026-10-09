--[[
noise.lua - seeded random numbers and coherent noise (pure Lua 5.2, deterministic on every machine).

WHY OUR OWN GENERATOR
  math.random is shared with the game and its sequence depends on the Lua build, so the same seed would not
  give the same map twice. Park-Miller ("minimal standard", s = 16807 * s mod (2^31 - 1)) is exact in doubles
  (every product stays below 2^46), needs no bit operations and gives the same sequence everywhere.

WHAT IS HERE
  M.seedFrom(value)            number or string -> integer seed 1 .. 2^31 - 2
  M.derive(seed, tag)          independent seed for one purpose ("shape", "rivers", ...), so adding a random
                               draw in one stage never changes the others
  M.rng(seed)                  generator object: r:next() in (0, 1), r:range(a, b), r:int(a, b), r:pick(list)
  M.perlin(seed [, period])    2D gradient noise f(x, y) in about -1 .. 1 (lattice spacing 1). With `period`
                               (a divisor of 256) it repeats every `period` units, for tileable textures
  M.fbm(f, x, y, octaves, gain) fractal sum of octaves of f (frequency doubles each octave), about -1 .. 1
  M.tile(seed, size, wavelength, octaves, gain)
                               size x size tileable fractal texture (flat array, index j * size + i + 1),
                               values about -1 .. 1; used for full-resolution detail at almost no cost
]]

local M = {}

local MOD = 2147483647 -- 2^31 - 1 (prime)
local floor = math.floor

function M.seedFrom(value)
	if type(value) == "number" then
		return floor(math.abs(value)) % (MOD - 1) + 1
	end
	local h = 7
	local s = tostring(value)
	for i = 1, #s do
		h = (h * 31 + s:byte(i)) % (MOD - 1)
	end
	return h + 1
end

function M.derive(seed, tag)
	return M.seedFrom(tostring(M.seedFrom(seed)) .. "/" .. tag)
end

local Rng = {}
Rng.__index = Rng

function M.rng(seed)
	local r = setmetatable({ s = M.seedFrom(seed) }, Rng)
	-- Small seeds give small first values; a few warm-up draws spread them out.
	for _ = 1, 3 do r:next() end
	return r
end

function Rng:next()
	self.s = (self.s * 16807) % MOD
	return self.s / MOD
end

function Rng:range(a, b)
	return a + (b - a) * self:next()
end

function Rng:int(a, b)
	return a + floor(self:next() * (b - a + 1))
end

function Rng:pick(list)
	return list[self:int(1, #list)]
end

-- Gradient ("Perlin") noise with one random unit gradient per permutation entry and the quintic fade.
function M.perlin(seed, period)
	local r = M.rng(seed)
	local p = {}
	for i = 0, 255 do p[i] = i end
	for i = 255, 1, -1 do
		local j = floor(r:next() * (i + 1))
		p[i], p[j] = p[j], p[i]
	end
	for i = 0, 255 do p[i + 256] = p[i] end
	local gx, gy = {}, {}
	for i = 0, 511 do
		local a = r:next() * 2 * math.pi
		gx[i], gy[i] = math.cos(a), math.sin(a)
	end
	local per = period or 256
	return function(x, y)
		local xf, yf = floor(x), floor(y)
		local fx, fy = x - xf, y - yf
		local x0, y0 = xf % per, yf % per
		local x1, y1 = (x0 + 1) % per, (y0 + 1) % per
		local a, b = p[x0], p[x1]
		local h00, h01, h10, h11 = p[a + y0], p[a + y1], p[b + y0], p[b + y1]
		local u = fx * fx * fx * (fx * (fx * 6 - 15) + 10)
		local v = fy * fy * fy * (fy * (fy * 6 - 15) + 10)
		local n00 = gx[h00] * fx + gy[h00] * fy
		local n10 = gx[h10] * (fx - 1) + gy[h10] * fy
		local n01 = gx[h01] * fx + gy[h01] * (fy - 1)
		local n11 = gx[h11] * (fx - 1) + gy[h11] * (fy - 1)
		local nx0 = n00 + u * (n10 - n00)
		local nx1 = n01 + u * (n11 - n01)
		return (nx0 + v * (nx1 - nx0)) * 1.4
	end
end

function M.fbm(f, x, y, octaves, gain)
	local sum, amp, freq, norm = 0, 1, 1, 0
	for o = 1, octaves do
		-- per-octave offsets decorrelate the octaves (they share one lattice)
		sum = sum + amp * f(x * freq + o * 17.31, y * freq - o * 9.73)
		norm = norm + amp
		amp = amp * gain
		freq = freq * 2
	end
	return sum / norm
end

-- Tileable fractal texture. wavelength = size of the largest features in texels; it and size must be powers
-- of two with wavelength <= size, so every octave's lattice period divides 256. ctx (optional): ticked per row.
function M.tile(seed, size, wavelength, octaves, gain, ctx)
	local t = {}
	local layers = {}
	local amp, norm = 1, 0
	for o = 0, octaves - 1 do
		local wl = wavelength / 2 ^ o
		if wl < 2 then break end
		layers[#layers + 1] = { f = M.perlin(M.derive(seed, "tile" .. o), size / wl), wl = wl, amp = amp }
		norm = norm + amp
		amp = amp * gain
	end
	for j = 0, size - 1 do
		for i = 0, size - 1 do
			local v = 0
			for _, l in ipairs(layers) do
				v = v + l.amp * l.f(i / l.wl, j / l.wl)
			end
			t[j * size + i + 1] = v / norm
		end
		if ctx then ctx.tick() end
	end
	return t
end

return M

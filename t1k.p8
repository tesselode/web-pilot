pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

local function p3d(x, y, z, hx, hy)
	hx = hx or 64
	hy = hy or 64
	x += (hx - 64) * .67
	y += (hy - 64) * .67
	return hx + (x - hx) * z * z,
	       hy + (y - hy) * z * z
end

local function line3d(x1, y1, z1, x2, y2, z2, hx, hy, col)
	local x1, y1 = p3d(x1, y1, z1, hx, hy)
	local x2, y2 = p3d(x2, y2, z2, hx, hy)
	line(x1, y1, x2, y2, col)
end

local function circfill3d(x, y, z, hx, hy, r, col)
	r *= z
	r /= 1 + sqrt(sqrt((x - 64) * (x - 64) + (y - 64) * (y - 64)))
	local x, y = p3d(x, y, z, hx, hy)
	circfill(x, y, r * z, col)
end

local hx, hy = 64, 64
local cx = 0
local uptime = 0
local circles = {}

function _update60()
	if btn(0) then hx -= 1 end
	if btn(1) then hx += 1 end
	if btn(2) then hy -= 1 end
	if btn(3) then hy += 1 end

	cx += .1
	uptime += 1
	if uptime % 5 == 0 then
		add(circles, {
			x = 0,
			y = rnd(128),
			z = .33,
		})
		add(circles, {
			x = 128,
			y = rnd(128),
			z = .33,
		})
	end
	for circle in all(circles) do
		circle.z += 1/60
		if circle.z > 2 then
			del(circles, circle)
		end
	end
end

function _draw()
	cls()
	for x = 0, 128, 128/5 do
		line3d(x, 0, .5, x, 0, 2, hx, hy, 14)
		line3d(x, 128, .5, x, 128, 2, hx, hy, 14)
	end
	line3d(0, 0, .5, 128, 0, .5, hx, hy, 14)
	line3d(0, 128, .5, 128, 128, .5, hx, hy, 14)
	for circle in all(circles) do
		circfill3d(circle.x, circle.y, circle.z, hx, hy, 32, 2)
	end
	print('cpu: ' .. flr(stat(1) * 200), 0, 0, 7)
	print('mem: ' .. flr(stat(0) / 1024), 0, 8, 7)
end

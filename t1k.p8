pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

local p3d = {hx = 64, hy = 64}

function p3d:to2d(x, y, z)
	x += (self.hx - 64) * .67
	y += (self.hy - 64) * .67
	return self.hx + (x - self.hx) * z * z,
	       self.hy + (y - self.hy) * z * z
end

function p3d:line(x1, y1, z1, x2, y2, z2, col)
	local x1, y1 = self:to2d(x1, y1, z1)
	local x2, y2 = self:to2d(x2, y2, z2)
	line(x1, y1, x2, y2, col)
end

function p3d:circfill(x, y, z, r, col)
	r *= z
	r /= 1 + sqrt(sqrt((x - 64) * (x - 64) + (y - 64) * (y - 64)))
	local x, y = self:to2d(x, y, z)
	circfill(x, y, r * z, col)
end

local cx = 0
local uptime = 0
local circles = {}

function _update60()
	if btn(0) then p3d.hx -= 1 end
	if btn(1) then p3d.hx += 1 end
	if btn(2) then p3d.hy -= 1 end
	if btn(3) then p3d.hy += 1 end

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
		p3d:line(x, 0, .5, x, 0, 2, 14)
		p3d:line(x, 128, .5, x, 128, 2, 14)
	end
	p3d:line(0, 0, .5, 128, 0, .5, 14)
	p3d:line(0, 128, .5, 128, 128, .5, 14)
	for circle in all(circles) do
		p3d:circfill(circle.x, circle.y, circle.z, 32, 2)
	end
	print('cpu: ' .. flr(stat(1) * 200), 0, 0, 7)
	print('mem: ' .. flr(stat(0) / 1024), 0, 8, 7)
end

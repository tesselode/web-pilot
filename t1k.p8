pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- pseudo 3d drawing

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

-->8
-- main loop

local player_x = 1

function _update60()
	if btnp(0) and player_x > 1 then player_x -= 1 end
	if btnp(1) and player_x < 5 then player_x += 1 end

	p3d.hx += (64 + (2.5 - player_x) * 8 - p3d.hx) * .1
end

local function draw_web()
	for x = 0, 128, 128/5 do
		p3d:line(x, 0, .5, x, 0, 2, 14)
		p3d:line(x, 128, .5, x, 128, 2, 14)
	end
	p3d:line(0, 0, .5, 128, 0, .5, 14)
	p3d:line(0, 128, .5, 128, 128, .5, 14)
end

function _draw()
	cls()
	draw_web()
	p3d:circfill(128/10 + 128/5 * (player_x - 1), 128, .9, 64, 7)
	print('cpu: ' .. flr(stat(1) * 200), 0, 0, 7)
	print('mem: ' .. flr(stat(0) / 1024), 0, 8, 7)
end

pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- resources

local constant = {
	web = {
		width = 160,
		spaces = 6,
	}
}

local sprite = {
	player_bullet = 3,
}

-->8
-- utility

local function web2screen(x)
	local left = 64 - constant.web.width/2
	return left + (constant.web.width / constant.web.spaces) * (x - .5)
end

local screen_shake = {
	table = {
		{-2, -2},
		{-2, -2},
		{2, -2},
		{2, -2},
		{1, 2},
		{1, 2},
		{-1, -1},
		{-1, -1},
		{-1, -1},
		{1, 0},
		{1, 0},
		{1, 0},
		{-1, 1},
		{-1, 1},
		{-1, 1},
		{0, 0}
	},
}
screen_shake.position = #screen_shake.table

function screen_shake:start(position)
	self.position = position
end

function screen_shake:update()
	if self.position < #self.table then
		self.position += 1
	end
end

function screen_shake:get()
	return self.table[self.position][1], self.table[self.position][2]
end

-->8
-- pseudo 3d drawing

local p3d = {hx = 64, hy = 64, min_z = .25, max_z = .9}

function p3d:to2d(x, y, z)
	z = self.min_z + (self.max_z - self.min_z) * z
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
	local x, y = self:to2d(x, y, z)
	circfill(x, y, r * z, col)
end

function p3d:rectfill(x1, y1, x2, y2, z, col)
	local x1, y1 = self:to2d(x1, y1, z)
	local x2, y2 = self:to2d(x2, y2, z)
	rectfill(x1, y1, x2, y2, col)
end

function p3d:sprite(sx, sy, sw, sh, cx, cy, z)
	local cx, cy = self:to2d(cx, cy, z)
	local dx = cx - sw/2 * z
	local dy = cy - sh/2 * z
	local dw = sw * z
	local dh = sh * z
	sspr(sx, sy, sw, sh, dx, dy, dw, dh)
end

-->8
-- classes

local class = {}

class.player = {}
class.player.__index = class.player

function class.player:new(entities)
	self.entities = entities
	self.x = 1
	self.y = 0
	self.z = 1
	self.vy = 0
	self.display_x = web2screen(self.x)
	self.smooth_display_x = self.display_x
end

function class.player:update()
	if self.y == 0 or self.y == 128 then
		if btnp(0) and self.x > 1 then self.x -= 1 end
		if btnp(1) and self.x < constant.web.spaces then self.x += 1 end
		if btnp(4) then
			if self.y == 0 then self.vy = 10 end
			if self.y == 128 then self.vy = -10 end
		end
		if btnp(5) then
			add(self.entities, class.player_bullet(self.x, self.y, self.z))
		end
	end

	self.y += self.vy
	if self.y > 128 then
		self.y = 128
		self.vy = 0
		screen_shake:start(7)
	end
	if self.y < 0 then
		self.y = 0
		self.vy = 0
		screen_shake:start(7)
	end

	self.display_x = web2screen(self.x)
	self.smooth_display_x += (self.display_x - self.smooth_display_x) * .5
	p3d.hx += (64 + (2.5 - self.x) * 8 - p3d.hx) * .1
	p3d.hy += (64 + (self.y - 64) * 1/8 - p3d.hy) * .1
end

function class.player:draw_front()
	p3d:sprite(8, 0, 16, 16, self.smooth_display_x, 128 - self.y, self.z)
end

setmetatable(class.player, {
	__call = function(_, ...)
		local player = setmetatable({}, class.player)
		player:new(...)
		return player
	end
})

class.player_bullet = {
	speed = .02,
}
class.player_bullet.__index = class.player_bullet

function class.player_bullet:new(x, y, z)
	self.x = x
	self.y = y
	self.z = z
	self.display_x = web2screen(self.x)
end

function class.player_bullet:update()
	self.z -= self.speed
	if self.z < 0 then
		self.dead = true
	end
end

function class.player_bullet:draw()
	p3d:sprite(24, 0, 8, 8, self.display_x, 128 - self.y, self.z)
end

setmetatable(class.player_bullet, {
	__call = function(_, ...)
		local player_Bullet = setmetatable({}, class.player_bullet)
		player_Bullet:new(...)
		return player_Bullet
	end
})

-->8
-- main loop

local entities = {}
add(entities, class.player(entities))

function _update60()
	for entity in all(entities) do
		if entity.update then entity:update() end
		if entity.dead then
			del(entities, entity)
		end
	end

	screen_shake:update()
end

local function draw_web()
	for x = 64 - constant.web.width/2, 64 + constant.web.width/2, constant.web.width / constant.web.spaces do
		p3d:line(x, 0, 0, x, 0, 2, 14)
		p3d:line(x, 128, 0, x, 128, 2, 14)
	end
	p3d:line(64 - constant.web.width/2, 0, 0, 64 + constant.web.width/2, 0, 0, 14)
	p3d:line(64 - constant.web.width/2, 128, 0, 64 + constant.web.width/2, 128, 0, 14)
end

function _draw()
	cls()
	camera(screen_shake:get())
	draw_web()
	for entity in all(entities) do
		if entity.draw then entity:draw() end
	end
	for entity in all(entities) do
		if entity.draw_front then entity:draw_front() end
	end
	camera()
	print('cpu: ' .. flr(stat(1) * 200), 0, 0, 7)
	print('mem: ' .. flr(stat(0) / 1024), 0, 8, 7)
end
__gfx__
00000000000007777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000077cccccc7700000088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700007cc00ee00cc70000888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700007c0000ee0000c70088aa880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700007c000eeee000c70088aa880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007007c000ee00ee000c700888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007c00ee0000ee00c700088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007ceee000000eeec700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007ceee000000eeec700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007c00ee0000ee00c700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000007c000ee00ee000c700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000007c000eeee000c7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000007c0000ee0000c7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007cc00ee00cc70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000077cccccc7700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000007777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- pseudo 3d drawing

local p3d = {hx = 64, hy = 48}

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
-- classes

local Class = {}

Class.Player = {
	jumpPower = 5,
	gravity = 1/3,
}
Class.Player.__index = Class.Player

function Class.Player:new(entities)
	self.entities = entities
	self.x = 1
	self.y = 0
	self.z = .9
	self.vy = 0
end

function Class.Player:update()
	if btnp(0) and self.x > 1 then self.x -= 1 end
	if btnp(1) and self.x < 5 then self.x += 1 end

	if self.y == 0 and btnp(4) then
		self.vy = self.jumpPower
	end

	if btnp(5) then
		add(self.entities, Class.PlayerBullet(self.x, self.y, self.z))
	end

	self.vy -= self.gravity
	self.y += self.vy
	if self.y <= 0 then
		self.y = 0
		self.vy = 0
	end

	p3d.hx += (64 + (2.5 - self.x) * 8 - p3d.hx) * .1
end

function Class.Player:draw()
	p3d:circfill(128/10 + 128/5 * (self.x - 1), 128 - self.y, self.z, 64, 7)
end

setmetatable(Class.Player, {
	__call = function(_, ...)
		local player = setmetatable({}, Class.Player)
		player:new(...)
		return player
	end
})

Class.PlayerBullet = {
	speed = .01,
}
Class.PlayerBullet.__index = Class.PlayerBullet

function Class.PlayerBullet:new(x, y, z)
	self.x = x
	self.y = y
	self.z = z
end

function Class.PlayerBullet:update()
	self.z -= self.speed
	if self.z < .4 then
		self.dead = true
	end
end

function Class.PlayerBullet:draw()
	p3d:circfill(128/10 + 128/5 * (self.x - 1), 128 - self.y, self.z, 24, 7)
end

setmetatable(Class.PlayerBullet, {
	__call = function(_, ...)
		local playerBullet = setmetatable({}, Class.PlayerBullet)
		playerBullet:new(...)
		return playerBullet
	end
})

-->8
-- main loop

local entities = {}
add(entities, Class.Player(entities))

function _update60()
	for entity in all(entities) do
		if entity.update then entity:update() end
		if entity.dead then
			del(entities, entity)
		end
	end
end

local function draw_web()
	for x = 0, 128, 128/5 do
		p3d:line(x, 0, .4, x, 0, 2, 14)
		p3d:line(x, 128, .4, x, 128, 2, 14)
	end
	p3d:line(0, 0, .4, 128, 0, .4, 14)
	p3d:line(0, 128, .4, 128, 128, .4, 14)
end

function _draw()
	cls()
	draw_web()
	for entity in all(entities) do
		if entity.draw then entity:draw() end
	end
	print('cpu: ' .. flr(stat(1) * 200), 0, 0, 7)
	print('mem: ' .. flr(stat(0) / 1024), 0, 8, 7)
end

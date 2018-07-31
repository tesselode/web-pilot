pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- resources

local state = {}
local class = {}

-->8
-- utilities

local state_manager = {}

function state_manager:call(event, ...)
	if self.current_state and self.current_state[event] then
		self.current_state[event](self.current_state, ...)
	end
end

function state_manager:switch(state, ...)
	self:call 'leave'
	self.current_state = state
	self:call('enter', ...)
end

--
-- classic
--
-- Copyright (c) 2014, rxi
--
-- This module is free software; you can redistribute it and/or modify it under
-- the terms of the MIT license. See LICENSE for details.
--

local object = {}
object.__index = object

function object:new() end

function object:extend()
	local cls = {}
	for k, v in pairs(self) do
		if sub(k, 1, 2) == '__' then
			cls[k] = v
		end
	end
	cls.__index = cls
	cls.super = self
	setmetatable(cls, self)
	return cls
end

function object:implement(...)
	for _, cls in pairs({...}) do
		for k, v in pairs(cls) do
			if self[k] == nil and type(v) == "function" then
				self[k] = v
			end
		end
	end
end

function object:is(T)
	local mt = getmetatable(self)
	while mt do
		if mt == T then
			return true
		end
		mt = getmetatable(mt)
	end
	return false
end

function object:__tostring()
	return "object"
end

function object:__call(...)
	local obj = setmetatable({}, self)
	obj:new(...)
	return obj
end

-->8
-- pseudo-3d drawing

class.p3d = object:extend()

function class.p3d:new()
	self.hx = 64
	self.hy = 64
	self.oz = 0
end

function class.p3d:to2d(x, y, z)
	x -= (self.hx - 64) / 3
	y -= (self.hy - 64) / 3
	z += self.oz
	for i = 1, 4 do z *= z end
	return self.hx + (x - self.hx) * z,
	       self.hy + (y - self.hy) * z
end

function class.p3d:get_color(color, z)
	if color == 14 then
		if z < .95 then color = 13 end
		if z < .925 then color = 2 end
	end
	return color
end

function class.p3d:line(x1, y1, z1, x2, y2, z2, col)
	local x1, y1 = self:to2d(x1, y1, z1)
	local x2, y2 = self:to2d(x2, y2, z2)
	line(x1, y1, x2, y2, col)
end

function class.p3d:circfill(x, y, z, r, col)
	local x, y = self:to2d(x, y, z)
	circfill(x, y, r * z * z, col)
end

-->8
-- classes

class.model = object:extend()

function class.model:new(points)
	self.points = points
end

function class.model:draw(p3d, x, y, z, r, sx, sy, sz, col)
	local c, s = cos(r), sin(r)
	for i = 1, #self.points - 1 do
		local a = self.points[i]
		local b = self.points[i+1]
		local ax, ay, az = a.x, a.y, a.z
		ax, ay = c * ax - s * ay, s * ax + c * ay
		ax *= sx
		ay *= sy
		az *= sz
		ax += x
		ay += y
		az += z
		local bx, by, bz = b.x, b.y, b.z
		bx, by = c * bx - s * by, s * bx + c * by
		bx *= sx
		by *= sy
		bz *= sz
		bx += x
		by += y
		bz += z
		local x1, y1 = p3d:to2d(ax, ay, az)
		local x2, y2 = p3d:to2d(bx, by, bz)
		line(x1, y1, x2, y2, col)
	end
end

local model = {
	player = class.model {
		{x = -1, y = 0, z = 1/72},
		{x = 0, y = -1, z = 1/72},
		{x = 1, y = 0, z = 1/72},
		{x = 0, y = 1, z = 1/72},
		{x = -1, y = 0, z = 1/72},
		{x = 0, y = 0, z = -1/72},
		{x = 1, y = 0, z = 1/72},
		{x = 0, y = 1, z = 1/72},
		{x = 0, y = 0, z = -1/72},
		{x = 0, y = -1, z = 1/72},
	},
	flipper = class.model {
		{x = -1, y = -1, z = 0},
		{x = 1, y = 1, z = 0},
		{x = 1, y = -1, z = 0},
		{x = -1, y = 1, z = 0},
		{x = -1, y = -1, z = 0},
	},
}

class.web = object:extend()

class.web.min_z = .9
class.web.max_z = 1.01

function class.web:new()
	self.points = {}
	self.closed = true
end

function class.web:add_point(x, y)
	add(self.points, {x = x + 64, y = y + 64})
end

function class.web:get_position(position)
	position += .5
	position %= #self.points
	if position == 0 then position = #self.points end
	local a = flr(position)
	if a == 0 then a = #self.points end
	local b = ceil(position)
	a, b = self.points[a], self.points[b]
	local fraction = position % 1
	return a.x + (b.x - a.x) * fraction,
	       a.y + (b.y - a.y) * fraction
end

function class.web:draw(p3d)
	for i = 1, #self.points do
		local a = self.points[i]
		if self.closed or i < #self.points then
			local b = i == #self.points and self.points[1] or self.points[i + 1]
			p3d:line(a.x, a.y, self.min_z, b.x, b.y, self.min_z, 1)
			p3d:line(a.x, a.y, self.max_z, b.x, b.y, self.max_z, 12)
		end
		p3d:line(a.x, a.y, self.min_z, a.x, a.y, self.max_z, 12)
	end
end

class.physical = object:extend()

class.player = class.physical:extend()

class.player.reload_time = 6
class.player.jump_power = .003
class.player.gravity = .0001

function class.player:new(web, entities, position)
	self.web = web
	self.entities = entities
	self.target_position = position
	self.position = self.target_position
	self.z = 1
	self.vz = 0
	self.jumping = false
	self.reload_timer = 0
end

function class.player:update()
	-- movement
	if btnp(0) then self.target_position -= 1 end
	if btnp(1) then self.target_position += 1 end
	self.position += (self.target_position - self.position) * .33

	-- jumping
	if not self.jumping and btnp(5) then
		self.jumping = true
		self.vz = self.jump_power
	end
	if self.jumping then
		self.vz -= self.gravity
		self.z += self.vz
		if self.z <= 1 then
			self.z = 1
			self.jumping = false
		end
	end

	-- shooting
	self.reload_timer -= 1
	if self.reload_timer <= 0 and btn(4) then
		self.reload_timer = self.reload_time
		add(self.entities, class.player_bullet(self.web, self.position, self.z))
	end
end

function class.player:draw(p3d)
	local r = atan2(self.x - 64, self.y - 64)
	model.player:draw(p3d, self.x, self.y, self.z, r, 8, 8, 1, 10)
end

class.player_bullet = class.physical:extend()

class.player_bullet.speed = .0025

function class.player_bullet:new(web, position, z)
	self.web = web
	self.position = position
	self.z = z
end

function class.player_bullet:update()
	self.z -= self.speed
	if self.z <= self.web.min_z then
		self.dead = true
	end
end

function class.player_bullet:collide(other)
	if other:is(class.flipper) then self.dead = true end
end

function class.player_bullet:draw(p3d)
	p3d:circfill(self.x, self.y, self.z, 2, 10)
end

class.flipper = class.physical:extend()

class.flipper.speed = .0005
class.flipper.flip_interval = 45
class.flipper.flip_speed = 1/30

function class.flipper:new(web, entities, position, z)
	self.web = web
	self.entities = entities
	self.position = position
	self.z = z
	self.flip_timer = self.flip_interval
	self.flip_direction = 0
	self.flip_progress = 0

	-- cosmetic
	self.r = 0
end

function class.flipper:update()
	if self.z < 1 then
		self.z += self.speed
		if self.z > 1 then self.z = 1 end
	end
	if self.flip_direction == 0 and self.z > self.web.min_z then
		self.flip_timer -= 1
		if self.flip_timer == 0 then
			self.flip_timer += self.flip_interval
			self.flip_direction = rnd(1) > .5 and 1 or -1
			self.flip_progress = 0
		end
	end
	if self.flip_direction ~= 0 then
		self.flip_progress += self.flip_speed
		self.position += self.flip_speed * self.flip_direction
		self.r += self.flip_speed * self.flip_direction / 2
		if self.flip_progress >= 1 then
			self.flip_direction = 0
		end
	end
end

function class.flipper:collide(other)
	if other:is(class.player_bullet) then
		for i = 1, 5 do
			add(self.entities, class.particle(self.x, self.y, self.z, 14))
		end
		self.dead = true
	end
end

function class.flipper:draw(p3d)
	model.flipper:draw(p3d, self.x, self.y, self.z, self.r, 6, 6, 1, 14)
end

class.particle = object:extend()

function class.particle:new(x, y, z, color)
	self.x = x
	self.y = y
	self.z = z
	self.color = color
	self.r = 2
	self.direction = rnd(1)
	self.speed = 2 + rnd(2)
	self.life = 30
end

function class.particle:update()
	self.life -= 1
	if self.life == 0 then
		self.dead = true
	end
	self.speed -= .05
	self.r -= .1
	self.x += self.speed * cos(self.direction)
	self.y += self.speed * sin(self.direction)
end

function class.particle:draw(p3d)
	p3d:circfill(self.x, self.y, self.z, self.r, self.color)
end

class.star = object:extend()

function class.star:new()
	local angle = rnd(1)
	self.x = 64 + 64 * cos(angle)
	self.y = 64 + 64 * sin(angle)
	self.z = .8 + rnd(.4)
end

function class.star:update(speed)
	self.z += .001 * speed
	if self.z >= 1.2 then
		local angle = rnd(1)
		self.x = 64 + 64 * cos(angle)
		self.y = 64 + 64 * sin(angle)
		self.z = .8
	end
end

function class.star:draw(p3d)
	p3d:circfill(self.x, self.y, self.z, 1, 1)
end

-->8
-- gameplay state

state.gameplay = {}

function state.gameplay:enter()
	self.p3d = class.p3d()
	self.web = class.web()
	for angle = 0, 1 - 1/15, 1/15 do
		self.web:add_point(
			50 * cos(angle),
			50 * sin(angle)
		)
	end
	self.stars = {}
	for i = 1, 20 do
		add(self.stars, class.star())
	end
	self.entities = {}
	self.player = add(self.entities, class.player(self.web, self.entities, 1))
	self.spawn_timer = 1
end

function state.gameplay:update()
	self.spawn_timer -= 1/60
	while self.spawn_timer <= 0 do
		self.spawn_timer += 1
		add(self.entities, class.flipper(self.web, self.entities, flr(rnd(#self.web.points)), 0.75))
	end
	for entity in all(self.entities) do
		entity:update()
		if entity:is(class.physical) then
			entity.x, entity.y = self.web:get_position(entity.position)
		end
	end
	for i = 1, #self.entities - 1 do
		local entity = self.entities[i]
		if entity:is(class.physical) then
			for j = i + 1, #self.entities do
				local other = self.entities[j]
				if other:is(class.physical) then
					local colliding = abs(other.x - entity.x) < 8
								and abs(other.y - entity.y) < 8
								and abs(other.z - entity.z) < .01
					if colliding then
						if entity.collide then entity:collide(other) end
						if other.collide then other:collide(entity) end
					end
				end
			end
		end
	end
	for entity in all(self.entities) do
		if entity.dead then del(self.entities, entity) end
	end

	-- cosmetic
	for star in all(self.stars) do star:update(1) end
	local target_hx = 64 + (self.player.x - 64) * 1/6
	local target_hy = 64 + (self.player.y - 64) * 1/6
	self.p3d.hx += (target_hx - self.p3d.hx) * .1
	self.p3d.hy += (target_hy - self.p3d.hy) * .1
	self.p3d.oz = -(self.player.z - 1) / 3
end

function state.gameplay:draw()
	for star in all(self.stars) do star:draw(self.p3d) end
	self.web:draw(self.p3d)
	for entity in all(self.entities) do
		entity:draw(self.p3d)
	end
end

function _init()
	state_manager:switch(state.gameplay)
end

function _update60()
	state_manager:call 'update'
end

function _draw()
	cls()
	state_manager:call 'draw'
	print('cpu: ' .. flr(stat(1) * 200) .. '%', 0, 0, 7)
end

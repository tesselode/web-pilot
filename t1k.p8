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
end

function class.p3d:to2d(x, y, z)
	x -= (self.hx - 64) / 3
	y -= (self.hy - 64) / 3
	z *= z
	return self.hx + (x - self.hx) * z,
	       self.hy + (y - self.hy) * z
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
		{x = -1, y = 0, z = 1/12},
		{x = 0, y = -1, z = 1/12},
		{x = 1, y = 0, z = 1/12},
		{x = 0, y = 1, z = 1/12},
		{x = -1, y = 0, z = 1/12},
		{x = 0, y = 0, z = -1/12},
		{x = 1, y = 0, z = 1/12},
		{x = 0, y = 1, z = 1/12},
		{x = 0, y = 0, z = -1/12},
		{x = 0, y = -1, z = 1/12},
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

class.web.min_z = .5
class.web.max_z = 1.05

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
			p3d:line(a.x, a.y, self.min_z, b.x, b.y, self.min_z, 12)
			p3d:line(a.x, a.y, self.max_z, b.x, b.y, self.max_z, 12)
		end
		p3d:line(a.x, a.y, self.min_z, a.x, a.y, self.max_z, 12)
	end
end

class.player = object:extend()

class.player.reload_time = 6

function class.player:new(web, entities, position)
	self.web = web
	self.entities = entities
	self.target_position = position
	self.position = self.target_position
	self.z = 1
	self.reload_timer = 0
end

function class.player:update()
	if btnp(0) then self.target_position -= 1 end
	if btnp(1) then self.target_position += 1 end
	self.position += (self.target_position - self.position) * .33

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

class.player_bullet = object:extend()

class.player_bullet.speed = .01

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

class.flipper = object:extend()

function class.flipper:new(web, position, z)
	self.web = web
	self.position = position
	self.z = z
	self.r = 0
end

function class.flipper:update()
	if self.z < 1 then
		self.z += .003
	end
	self.r += .002
end

function class.flipper:collide(other)
	if other:is(class.player_bullet) then self.dead = true end
end

function class.flipper:draw(p3d)
	model.flipper:draw(p3d, self.x, self.y, self.z, self.r, 6, 6, 1, 14)
end

-->8
-- gameplay state

state.gameplay = {}

function state.gameplay:enter()
	self.p3d = class.p3d()
	self.web = class.web()
	for angle = 0, 1 - 1/15, 1/15 do
		self.web:add_point(
			50 * cos(angle - .5),
			-25 * (sin(angle) + sin(sqrt(angle)) + sin(angle * angle))
		)
	end
	self.entities = {}
	self.player = add(self.entities, class.player(self.web, self.entities, 1))
	self.spawn_timer = 1
end

function state.gameplay:update()
	self.spawn_timer -= 1/60
	while self.spawn_timer <= 0 do
		self.spawn_timer += 1
		add(self.entities, class.flipper(self.web, flr(rnd(#self.web.points)), 0))
	end
	for entity in all(self.entities) do
		entity:update()
		entity.x, entity.y = self.web:get_position(entity.position)
	end
	for i = 1, #self.entities - 1 do
		local entity = self.entities[i]
		for j = i + 1, #self.entities do
			local other = self.entities[j]
			local colliding = abs(other.x - entity.x) < 8
						  and abs(other.y - entity.y) < 8
						  and abs(other.z - entity.z) < .1
			if colliding then
				if entity.collide then entity:collide(other) end
				if other.collide then other:collide(entity) end
			end
		end
	end
	for entity in all(self.entities) do
		if entity.dead then del(self.entities, entity) end
	end

	local target_hx = 64 + (self.player.x - 64) * 1/6
	local target_hy = 64 + (self.player.y - 64) * 1/6
	self.p3d.hx += (target_hx - self.p3d.hx) * .1
	self.p3d.hy += (target_hy - self.p3d.hy) * .1
end

function state.gameplay:draw()
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

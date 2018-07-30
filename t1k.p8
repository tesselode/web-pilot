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
	circfill(x, y, r, col)
end

-->8
-- classes

class.web = object:extend()

class.web.min_z = .25
class.web.max_z = 1.25

function class.web:new()
	self.points = {}
	self.closed = true
end

function class.web:add_point(x, y)
	add(self.points, {x = x + 64, y = y + 64})
end

function class.web:get_position(position)
	position %= #self.points
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
			p3d:line(a.x, a.y, self.min_z, b.x, b.y, self.min_z, 7)
			p3d:line(a.x, a.y, self.max_z, b.x, b.y, self.max_z, 7)
		end
		p3d:line(a.x, a.y, self.min_z, a.x, a.y, self.max_z, 7)
	end
end

-->8
-- gameplay state

state.gameplay = {}

function state.gameplay:enter()
	self.p3d = class.p3d()
	self.web = class.web()
	for angle = 0, 1 - 1/15, 1/15 do
		self.web:add_point(
			40 * cos(angle),
			40 * sin(angle * sqrt(angle))
		)
	end
	self.test = 0
end

function state.gameplay:update()
	self.test -= 1/10
	local x, y = self.web:get_position(self.test)
	self.p3d.hx = 64 + (x - 64) * -.25
	self.p3d.hy = 64 + (y - 64) * -.25
end

function state.gameplay:draw()
	self.web:draw(self.p3d)
	local x, y = self.web:get_position(self.test)
	self.p3d:circfill(x, y, 1, 8, 7)
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
end

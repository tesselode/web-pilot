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
	x += (self.hx - 64) / 3
	y += (self.hy - 64) / 3
	return self.hx + (x - self.hx) * z,
	       self.hy + (y - self.hy) * z
end

function class.p3d:line(x1, y1, z1, x2, y2, z2, col)
	local x1, y1 = self:to2d(x1, y1, z1)
	local x2, y2 = self:to2d(x2, y2, z2)
	line(x1, y1, x2, y2, col)
end

-->8
-- gameplay state

state.gameplay = {}

function state.gameplay:enter()
	self.p3d = class.p3d()
end

function state.gameplay:update()
	if btn(0) then self.p3d.hx -= 1 end
	if btn(1) then self.p3d.hx += 1 end
	if btn(2) then self.p3d.hy -= 1 end
	if btn(3) then self.p3d.hy += 1 end
end

function state.gameplay:draw()
	for x = 0, 128, 128/5 do
		self.p3d:line(x, 128, 0, x, 128, 1, 7)
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
end

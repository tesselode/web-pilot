pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
local state_manager = {}

function state_manager:call(event, ...)
	if self.current_state and self.current_state[event] then
		self.current_state[event](current_state, ...)
	end
end

function state_manager:switch(state, ...)
	self:call 'leave'
	self.current_state = state
	self:call('enter', ...)
end

local state = {}

state.gameplay = {}

function state.gameplay:draw()
	print 'hi'
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

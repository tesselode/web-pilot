pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- resources

local uptime = 0
local state = {}
local class = {}
local sound = {
	shoot = 8,
	jump = 9,
	hit = 10,
	flip_big = 11,
	flip_small = 12,
	caught = 13,
	spawn = 14,
	recharge = 15,
	bonus = 16,
	thwomp_arrived = 17,
	thwomp_stomped = 18,
	thwomp_hit = 19,
	rim_kill = 20,
	zapper = 21,
	phantom_arrived = 22,
	phantom_hit = 23,
	phantom_killed = 24,
	phantom_spit = 25,
}
local freeze_frames = 0
local screen_shake = {
	{0, 0},
	{-1, -1},
	{1, 1},
	{-1, 1},
	{1, -1},
	{-2, -2},
	{2, 2},
	{-2, 2},
	{2, -2},
}
local screen_shake_frame = 1
local compliments = {
	'cool and good!',
	'admirable!',
	'excellent!',
	'nice one!',
	'good one!',
	'good job!',
	'nice catch!',
	'choice!',
	'awesome!',
	'fantastic!',
	'wonderful!',
	'alright!',
	'watch me now!',
	'rad!',
	'respect!',
	'you got this!',
	'proud of you!',
	'talk of the town!',
	'all due respect!',
	'solid!',
	'props!',
	'i believe in you!',
}
local threats = {
	"gotcha~.",
	"caught you~",
	"you're mine now~",
	"i've got you now~",
	"come with me~",
	"join us~",
	"you're coming with me~",
	"farewell~",
	"any last words~?",
	"i'm taking this~",
	"see ya~",
	"goodbye~",
	"so long~",
	"it's the end for you~",
	"nice ship~",
	"i like your ship~",
	"mind if i borrow this~?",
	"he he he~",
}

-->8
-- utilities

local function printo(text, x, y, col, outline_col)
	outline_col = outline_col or 0
	print(text, x - 1, y - 1, outline_col)
	print(text, x, y - 1, outline_col)
	print(text, x + 1, y - 1, outline_col)
	print(text, x + 1, y, outline_col)
	print(text, x + 1, y + 1, outline_col)
	print(text, x, y + 1, outline_col)
	print(text, x - 1, y + 1, outline_col)
	print(text, x - 1, y, outline_col)
	print(text, x, y, col)
end

local function printc(text, x, y, col)
	x -= #text * 2
	print(text, x, y, col)
end

local function printoc(text, x, y, col, outline_col)
	x -= #text * 2
	printo(text, x, y, col)
end

local function printr(text, x, y, col)
	x -= #text * 4
	print(text, x, y, col)
end

local function wrap(x, limit)
	while x <= 0 do x += limit end
	x %= limit
	return x
end

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

local conversation = {_listeners = {}}

function conversation:listen(message, f)
	local listener = {message = message, f = f}
	self._listeners[listener] = true
	return listener
end

function conversation:say(message, ...)
	for listener, _ in pairs(self._listeners) do
		if listener.message == message then
			listener.f(...)
		end
	end
end

function conversation:deafen(listener)
	self._listeners[listener] = nil
end

--
-- classic
--
-- copyright (c) 2014, rxi
--
-- this module is free software; you can redistribute it and/or modify it under
-- the terms of the mit license. see license for details.
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

function object:is(t)
	local mt = getmetatable(self)
	while mt do
		if mt == t then
			return true
		end
		mt = getmetatable(mt)
	end
	return false
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

function class.p3d:line(x1, y1, z1, x2, y2, z2, col)
	local x1, y1 = self:to2d(x1, y1, z1)
	local x2, y2 = self:to2d(x2, y2, z2)
	line(x1, y1, x2, y2, col)
end

function class.p3d:circfill(x, y, z, r, col)
	local x, y = self:to2d(x, y, z)
	for i = 1, 4 do z *= z end
	circfill(x, y, r * z * z, col)
end

function class.p3d:sspr(sx, sy, sw, sh, x, y, z, scale)
	scale = scale or 1
	x, y = self:to2d(x, y, z)
	for i = 1, 4 do z *= z end
	local w, h = sw * z * scale, sh * z * scale
	x -= w/2
	y -= h/2
	sspr(sx, sy, sw, sh, x, y, w, h)
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
	thwomp = class.model {
		{x = -1, y = 1, z = 0},
		{x = 1, y = 1, z = 0},
		{x = 2/3, y = -1, z = 0},
		{x = -2/3, y = -1, z = 0},
		{x = -1, y = 1, z = 0},
		{x = 2/3, y = -1, z = 0},
		{x = -2/3, y = -1, z = 0},
		{x = 1, y = 1, z = 0},
	}
}

class.web = object:extend()

class.web.min_z = .9
class.web.max_z = 1.01
class.web.zap_speed = .002

function class.web:new()
	self.points = {}
	self.closed = true
	self.zapping = false
end

function class.web:add_point(x, y)
	add(self.points, {x = x + 64, y = y + 64})
end

function class.web:get_position(position, height)
	height = height or 0
	position += .5
	position %= #self.points
	if position == 0 then position = #self.points end
	local a = flr(position)
	if a == 0 then a = #self.points end
	local b = ceil(position)
	a, b = self.points[a], self.points[b]
	local fraction = position % 1
	local x, y = a.x + (b.x - a.x) * fraction, a.y + (b.y - a.y) * fraction
	return x + (64 - x) * height, y + (64 - y) * height
end

function class.web:zap()
	self.zapping = self.max_z
end

function class.web:update()
	if self.zapping then
		self.zapping -= self.zap_speed
		if self.zapping < self.min_z then
			self.zapping = false
		end
	end
end

function class.web:draw(p3d, color)
	for i = 1, #self.points do
		local a = self.points[i]
		if self.closed or i < #self.points then
			local b = i == #self.points and self.points[1] or self.points[i + 1]
			p3d:line(a.x, a.y, self.min_z, b.x, b.y, self.min_z, color)
			p3d:line(a.x, a.y, self.max_z, b.x, b.y, self.max_z, color)
			if self.zapping then
				p3d:line(a.x, a.y, self.zapping, b.x, b.y, self.zapping, 7)
			end
		end
		p3d:line(a.x, a.y, self.min_z, a.x, a.y, self.max_z, color)
	end
end

class.physical = object:extend()

class.player = class.physical:extend()

class.player.radius = 8
class.player.acceleration = .01
class.player.friction = .05
class.player.reload_time = 5
class.player.shot_heat = 1/5
class.player.shot_cooldown_speed = 1/20
class.player.jump_power = .003
class.player.gravity = .0001
class.player.stun_time = 90

function class.player:new(web, position)
	self.web = web
	self.position = position
	self.velocity = 0
	self.z = 1
	self.vz = 0
	self.jumping = false
	self.reload_timer = 0
	self.heat = 0
	self.overheat = false
	self.caught = false
	self.stun_timer = 0
end

function class.player:jump()
	if not self.caught and not self.jumping and self.stun_timer <= 0 then
		self.jumping = true
		self.vz = self.jump_power
		sfx(sound.jump, 1)
	end
end

function class.player:stun()
	if not self.jumping and not self.caught then
		self.stun_timer = self.stun_time
	end
end

function class.player:update()
	if self.caught then
		self.z = self.caught.z
		if self.z < self.web.min_z then
			return false
		end
	elseif self.z < 1 then
		self.z += (1 - self.z) * .1
	end

	-- movement
	if self.stun_timer == 0 then
		local acceleration = self.acceleration
		if self.caught then acceleration /= 3 end
		if btn(0) then self.velocity -= acceleration end
		if btn(1) then self.velocity += acceleration end
		self.velocity -= self.velocity * self.friction
		self.position += self.velocity

		-- jumping
		if self.jumping then
			self.vz -= self.gravity
			self.z += self.vz
			if self.z <= 1 then
				self.z = 1
				self.jumping = false
			end
		end
	else
		self.stun_timer -= 1
	end

	-- shooting
	self.reload_timer -= 1
	if self.reload_timer <= 0 then
		self.heat -= self.shot_cooldown_speed
		if self.heat <= 0 then
			self.heat = 0
			self.overheat = false
		end
	end
	if self.reload_timer <= 0 and not self.overheat and btn(4) then
		self.reload_timer = self.reload_time
		self.heat += self.shot_heat
		if self.heat > 1 then
			self.overheat = true
		end
		conversation:say('player shot', self.position, self.z)
	end
end

function class.player:collide(other)
	if other:is(class.powerup) then
		other.dead = true
		conversation:say('powerup collected', self.x, self.y, self.z)
	end
end

function class.player:draw(p3d)
	local z = self.z
	if self.stun_timer > 0 then
		z += .004 * (self.stun_timer / self.stun_time) * sin(uptime * .2)
	end
	local r = atan2(self.x - 64, self.y - 64) + self.velocity * (2/3)
	color = self.stun_timer > 0 and 13 or 10
	model.player:draw(p3d, self.x, self.y, z, r, 8, 8, 1, color)
end

class.player_bullet = class.physical:extend()

class.player_bullet.radius = 1
class.player_bullet.speed = .0067

function class.player_bullet:new(web, position, z)
	self.web = web
	self.position = flr(position) + .5
	self.z = z
end

function class.player_bullet:update()
	self.z -= self.speed
	if self.z <= self.web.min_z then
		self.dead = true
	end
end

function class.player_bullet:collide(other)
	if other:is(class.enemy) and not other.dragging then self.dead = true end
end

function class.player_bullet:draw(p3d)
	p3d:line(self.x, self.y, self.z, self.x, self.y, self.z + .01, 10)
end

class.enemy = class.physical:extend()

class.flipper = class.enemy:extend()

class.flipper.base_speed = .0005
class.flipper.flip_interval = 45
class.flipper.flip_speed = 1/20
class.flipper.drag_speed = .00025

function class.flipper:new(p3d, web, player, game_state, difficulty, small, position, z)
	self.p3d = p3d
	self.web = web
	self.player = player
	self.game_state = game_state
	self.difficulty = difficulty
	self.small = small
	self.position = position or flr(rnd(#self.web.points)) + .5
	self.z = z or .75
	self.radius = small and 3 or 6
	self.speed = self.base_speed * self.difficulty * (.25 + rnd(.75))
	self.flip_timer = self.flip_interval
	self.flip_direction = 0
	self.flip_progress = 0
	self.dragging = false
	self.point_value = self.small and 2 or 1
	self.color = self.small and 15 or 14

	-- cosmetic
	self.r = 0
end

function class.flipper:get_shortest_path_to_player()
	local pos = flr(wrap(self.position, #self.web.points))
	local player_pos = flr(wrap(self.player.position, #self.web.points))
	local negative_dist, positive_dist = 0, 0
	local test_pos = pos
	while test_pos ~= player_pos do
		test_pos = wrap(test_pos - 1, #self.web.points)
		negative_dist += 1
	end
	test_pos = pos
	while test_pos ~= player_pos do
		test_pos = wrap(test_pos + 1, #self.web.points)
		positive_dist += 1
	end
	return negative_dist < positive_dist and -1 or 1
end

function class.flipper:update()
	if self.dragging then
		self.position = self.dragging.position
		self.z -= self.drag_speed
		return
	end
	if self.z < self.web.min_z then
		self.z += self.base_speed * 3
	elseif self.z < 1 then
		self.z += self.speed
		if self.z > 1 then self.z = 1 end
	end
	if self.flip_direction == 0 and self.z > self.web.min_z then
		if self.z == 1 then
			self.flip_timer -= (self.small and 4 or 2) * self.difficulty
		else
			self.flip_timer -= (self.small and 2 or 1) * self.difficulty
		end
		if self.flip_timer <= 0 then
			self.flip_timer += self.flip_interval
			if self.z == 1 then
				self.flip_direction = self:get_shortest_path_to_player()
			else
				self.flip_direction = rnd(1) > .5 and 1 or -1
			end
			self.flip_progress = 0
		end
	end
	if self.flip_direction ~= 0 then
		self.flip_progress += self.flip_speed
		self.position += self.flip_speed * self.flip_direction * (self.small and .5 or 1)
		self.r += self.flip_speed * self.flip_direction / 2 * (self.small and 2 or 1)
		if self.flip_progress >= 1 then
			self.flip_direction = 0
			sfx(self.small and sound.flip_small or sound.flip_big, 2)
		end
	end
end

function class.flipper:die()
	self.dead = true
	if self.dragging then self.dragging.caught = false end
	conversation:say('enemy killed', self)
end

function class.flipper:collide(other)
	if other:is(class.player) and (not other.caught) and self.z == 1 and self.flip_direction == 0 then
		other.caught = self
		self.dragging = other
		conversation:say('player caught')
	end
	if other:is(class.player_bullet) and not self.dragging then
		self:die()
	end
end

function class.flipper:draw(p3d)
	local scale = self.small and 3 or 6
	model.flipper:draw(p3d, self.x, self.y, self.z, self.r, scale, scale, 1, self.color)
end

class.thwomp = class.enemy:extend()

class.thwomp.radius = 16
class.thwomp.min_jump_interval = 150
class.thwomp.max_jump_interval = 300
class.thwomp.jump_power = .1
class.thwomp.gravity = .005
class.thwomp.starting_health = 12
class.thwomp.point_value = 10
class.thwomp.color = 8

function class.thwomp:new(web, difficulty)
	self.web = web
	self.difficulty = difficulty
	self.position = flr(rnd(#self.web.points)) + .5
	self.h = 0
	self.z = .75
	self.jump_timer = self.min_jump_interval + rnd(self.max_jump_interval - self.min_jump_interval)
	self.jumping = false
	self.vp = 0
	self.vh = 0
	self.vz = 0
	self.health = self.starting_health
	self.flash_timer = 0
end

function class.thwomp:update()
	if self.z < self.web.min_z then
		self.z += .001
		if self.z >= self.web.min_z then
			sfx(sound.thwomp_arrived, 2)
		end
		return
	end
	if self.jumping then
		self.vh -= self.gravity
		self.h += self.vh
		self.position += self.vp
		self.z += self.vz
		if self.h < 0 then
			self.h = 0
			self.jumping = false
			freeze_frames += 2
			screen_shake_frame += 2
			conversation:say 'thwomp landed'
		end
	else
		self.jump_timer -= self.difficulty / 2
		if self.jump_timer <= 0 then
			self.jump_timer += self.min_jump_interval + rnd(self.max_jump_interval - self.min_jump_interval)
			self.jumping = true
			self.vh = self.jump_power
			self.vp = -.1 + rnd(.2)
			if self.z < self.web.min_z + .01 then
				self.vz = .0002
			elseif self.z > .99 then
				self.vz = -.0002
			else
				self.vz = -.0002 + rnd(.0002)
			end
			sfx(sound.jump, 2)
		end
	end
	self.flash_timer -= 1
end

function class.thwomp:die()
	self.dead = true
	conversation:say('enemy killed', self)
	sfx(sound.thwomp_stomped, 2)
end

function class.thwomp:collide(other)
	if other:is(class.player_bullet) then
		self.health -= 1
		if self.health == 0 then
			self:die()
		else
			self.flash_timer = 4
			sfx(sound.thwomp_hit, 0)
		end
	end
end

function class.thwomp:draw(p3d)
	local x, y = self.web:get_position(self.position)
	local r = atan2(x - 64, y - 64)
	local color = self.flash_timer > 0 and 7 or self.color
	model.thwomp:draw(p3d, self.x, self.y, self.z, r + .25, self.radius, self.radius, 1, color)
end

class.phantom = class.enemy:extend()

class.phantom.radius = 24
class.phantom.color = 7
class.phantom.point_value = 50
class.phantom.push_back = .01

function class.phantom:new(web, difficulty)
	self.web = web
	self.difficulty = difficulty
	self.uptime = 0
	self.position = rnd(#self.web.points)
	self.z = self.web.min_z - .25
	self.h = 0
	self.movement_speed = 1
	self.spawn_timer = 30
	self.flash_timer = 0
	self.announced_entrance = false
end

function class.phantom:update()
	self.uptime += 1
	self.movement_speed += (1 - self.movement_speed) * .01
	self.position += .01 * sin(self.uptime / 190) * self.movement_speed
	self.h += .01 * cos(self.uptime / 170)
	self.z += (.975 - self.z) * .01
	self.z += .0002 * sin(self.uptime / 200)
	if self.z > .98 then self.z = .98 end
	if self.z > .96 then
		self.spawn_timer -= self.difficulty / 3
		while self.spawn_timer <= 0 do
			self.spawn_timer += 30
			conversation:say('phantom spawned enemy', self.position, self.z)
		end
	end

	-- cosmetic
	if not self.announced_entrance and self.z > self.web.min_z then
		sfx(sound.phantom_arrived, 2)
		self.announced_entrance = true
	end
	if self.flash_timer > 0 then self.flash_timer -= 1 end
end

function class.phantom:die()
	self.dead = true
	conversation:say('enemy killed', self)
	sfx(sound.phantom_killed, 2)
	freeze_frames += 4
	screen_shake_frame += 4
end

function class.phantom:collide(other)
	if other:is(class.player_bullet) then
		self.movement_speed += 2 * sgn(self.movement_speed)
		self.movement_speed *= -1
		self.z -= self.push_back
		if self.z < self.web.min_z then
			self:die()
		else
			self.flash_timer = 4
			sfx(sound.phantom_hit, 2)
		end
	end
end

function class.phantom:draw(p3d)
	p3d:sspr(40, 16, 16, 16, self.x, self.y, self.z + (self.web.min_z - self.z) * .99, 2)
	p3d:sspr(40, 16, 16, 16, self.x, self.y, self.z + (self.web.min_z - self.z) * .5, 2)
	p3d:sspr(40, 16, 16, 16, self.x, self.y, self.z + (self.web.min_z - self.z) * .25, 2)
	if self.flash_timer > 0 then pal(9, 7) end
	p3d:sspr(40, 0, 16, 16, self.x, self.y, self.z, 2)
	pal()
end

class.powerup = class.physical:extend()

class.powerup.speed = .0005
class.powerup.radius = 8

function class.powerup:new(x, y, z)
	self.x = x
	self.y = y
	self.z = z
end

function class.powerup:update()
	self.z += self.speed
	if self.z > 1.1 then self.dead = true end
end

function class.powerup:draw(p3d)
	p3d:sspr(8, 0, 16, 16, self.x, self.y, self.z)
end

class.particle = object:extend()

function class.particle:new(x, y, z, color)
	self.x = x
	self.y = y
	self.z = z
	self.color = color
	self.r = 4
	self.direction = rnd(1)
	self.speed = 2 + rnd(2)
	self.life = 30
end

function class.particle:update()
	self.life -= 1
	if self.life == 0 then
		self.dead = true
	end
	self.speed -= .1
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

class.score_popup = object:extend()

function class.score_popup:new(text, x, y)
	self.text = text
	self.x = x
	self.y = y
	self.life = 40
	self.vy = .5
end

function class.score_popup:update()
	self.vy -= .01
	self.y -= self.vy
	self.life -= 1
	if self.life <= 0 then
		self.dead = true
	end
end

function class.score_popup:draw()
	local color = self.life / 15 % 1 < .5 and 12 or 7
	printc(self.text, self.x, self.y, color)
end

-->8
-- gameplay state

state.gameplay = {}

state.gameplay.entity_limit = 30

function state.gameplay:init_web()
	self.web = class.web()
	for angle = 0, 1 - 1/16, 1/16 do
		self.web:add_point(
			48 * cos(angle),
			48 * sin(angle)
		)
	end
end

function state.gameplay:init_stars()
	self.stars = {}
	for i = 1, 20 do
		add(self.stars, class.star())
	end
end

function state.gameplay:init_listeners()
	self.listeners = {
		conversation:listen('player shot', function(position, z)
			add(self.entities, class.player_bullet(self.web, position, z))
			sfx(sound.shoot, 0)
		end),
		conversation:listen('powerup collected', function(x, y, z)
			for i = 1, 10 do
				add(self.entities, class.particle(x, y, z, 12))
			end
			if not self.zapper_online then
				self.zapper_online = true
				self:show_message 'superzapper recharge'
				sfx(sound.recharge, 1)
			else
				self.powerup_streak += 1
				self.score += self.powerup_streak * 10
				add(self.entities, class.score_popup(self.powerup_streak .. '000', self.p3d:to2d(x, y, z)))
				local message = compliments[ceil(rnd(#compliments))]
				message = message .. ' +' .. self.powerup_streak .. '000'
				self:show_message(message)
				sfx(sound.bonus, 1)
			end
		end),
		conversation:listen('enemy killed', function(enemy)
			if not self.web.zapping then
				self.to_next_powerup -= 1
				if self.to_next_powerup == 0 then
					self.to_next_powerup = 7 + self.powerup_streak + flr(self.difficulty) * flr(self.difficulty)
					add(self.entities, class.powerup(enemy.x, enemy.y, enemy.z))
				end
			end
			if not self.player.jumping and not self.web.zapping then
				local point_value = enemy.point_value
				if enemy.z == 1 then
					point_value *= 3
					sfx(sound.rim_kill, 1)
				end
				self.score += point_value
				add(self.entities, class.score_popup(point_value .. '00', self.p3d:to2d(enemy.x, enemy.y, enemy.z)))
			end
			if enemy:is(class.thwomp) then self.difficulty += .1 end
			if enemy:is(class.phantom) then self.difficulty += 1/3 end
			for i = 1, 5 do
				add(self.entities, class.particle(enemy.x, enemy.y, enemy.z, enemy.color))
			end
			freeze_frames += 4
			screen_shake_frame += 3
			sfx(sound.hit, 0)
		end),
		conversation:listen('player caught', function()
			self:show_message(threats[ceil(rnd(#threats))], 8)
			sfx(sound.caught, 1)
		end),
		conversation:listen('thwomp landed', function()
			self.player:stun()
			sfx(sound.thwomp_stomped, 2)
		end),
		conversation:listen('phantom spawned enemy', function(position, z)
			if #self.entities < self.entity_limit then
				add(self.entities, class.flipper(self.p3d, self.web, self.player, self, self.difficulty, rnd(1) > .5, position, z))
				sfx(sound.phantom_spit, 2)
			end
		end)
	}
end

function state.gameplay:enter()
	self.p3d = class.p3d()
	self:init_web()
	self.entities = {}
	self.player = add(self.entities, class.player(self.web, 1))
	self:init_stars()
	self.score = 0
	self.zapper_online = false
	self.difficulty = 1
	self.timer = {
		flipper = 60 + rnd(60),
		small_flipper = 3200 + rnd(800),
		thwomp = 6000 + rnd(1000),
		phantom = 8200 + rnd(2000),
	}
	if rnd(1) > .9 then self.timer.phantom -= 5400 end
	self.spawn_timer = 1
	self.to_next_powerup = 3
	self.powerup_streak = 0

	-- cosmetic
	self.message = ''
	self.message_timer = 0
	self.message_y = 64
	self.message_color = 12
	self.rolling_score = self.score

	self:init_listeners()
end

function state.gameplay:is_colliding(a, b)
	if not (a:is(class.physical) and b:is(class.physical)) then return false end
	local distance = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)
	return distance < (b.radius + a.radius) * (b.radius + a.radius)
	   and abs(b.z - a.z) < .01
end

function state.gameplay:show_message(message, color)
	self.message = message
	self.message_timer = 120
	self.message_y = 80
	self.message_color = color or 12
end

function state.gameplay:update()
	-- game feel
	if freeze_frames > 6 then freeze_frames = 6 end
	if freeze_frames > 0 then
		freeze_frames -= 1
		return
	end
	if screen_shake_frame > 1 then
		screen_shake_frame -= 1
	end

	-- spawn enemies
	self.difficulty += .0002
	if self.player.z > self.web.min_z and #self.entities < self.entity_limit then
		self.timer.flipper -= self.difficulty
		while self.timer.flipper <= 0 do
			self.timer.flipper += 90 + rnd(60)
			add(self.entities, class.flipper(self.p3d, self.web, self.player, self, self.difficulty))
			if self.difficulty > 1.5 and rnd(1) > .95 then
				for i = 1, flr(self.difficulty * 2) do
					add(self.entities, class.flipper(self.p3d, self.web, self.player, self, self.difficulty))
				end
				self.difficulty -= .05
			end
			sfx(sound.spawn, 3)
		end
		self.timer.small_flipper -= self.difficulty
		while self.timer.small_flipper <= 0 do
			self.timer.small_flipper += 400 + rnd(400)
			add(self.entities, class.flipper(self.p3d, self.web, self.player, self, self.difficulty, true))
			if rnd(1) > .95 then
				for i = 1, flr(self.difficulty * 2) do
					add(self.entities, class.flipper(self.p3d, self.web, self.player, self, self.difficulty, true))
				end
				self.difficulty -= .05
			end
			sfx(sound.spawn, 3)
		end
		self.timer.thwomp -= self.difficulty
		while self.timer.thwomp <= 0 do
			self.timer.thwomp += 1600 + rnd(700)
			add(self.entities, class.thwomp(self.web, self.difficulty))
			self.difficulty -= .1
			if rnd(1) > .9 then
				for i = 1, flr(self.difficulty) do
					add(self.entities, class.thwomp(self.web, self.difficulty))
				end
			end
			sfx(sound.spawn, 3)
		end
		self.timer.phantom -= sqrt(self.difficulty)
		while self.timer.phantom <= 0 do
			self.timer.phantom += 2000 + rnd(1000)
			add(self.entities, class.phantom(self.web, self.difficulty))
			self.difficulty -= 1/3
			sfx(sound.spawn, 3)
		end
	end

	-- input
	if btnp(5) then self.player:jump() end
	if btnp(5) and self.player.caught and self.zapper_online then
		self.web:zap()
		self.zapper_online = false
		self.difficulty -= .1
		if self.difficulty < 1 then self.difficulty = 1 end
		self.powerup_streak = 0
		self:show_message 'eat electric death!'
		sfx(sound.zapper, 1)
	end

	-- update web and entities
	self.web:update()
	for entity in all(self.entities) do
		entity:update()
		if entity:is(class.physical) and entity.position then
			entity.x, entity.y = self.web:get_position(entity.position, entity.h)
		end
	end

	-- zapper
	if self.web.zapping then
		for entity in all(self.entities) do
			if entity:is(class.enemy) and abs(entity.z - self.web.zapping) < .01 and not entity.jumping then
				entity:die()
			end
		end
	end

	-- call collision events
	for i = 1, #self.entities - 1 do
		local entity = self.entities[i]
		if entity:is(class.physical) then
			for j = i + 1, #self.entities do
				local other = self.entities[j]
				local colliding = self:is_colliding(entity, other)
				if colliding then
					if entity.collide then entity:collide(other) end
					if other.collide then other:collide(entity) end
				end
			end
		end
	end

	-- remove entities
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

	-- message
	if self.message_timer > 0 then
		self.message_timer -= 1
		self.message_y += (64 - self.message_y) * .1
	end

	-- rolling score
	if self.rolling_score < self.score - .1 then
		self.rolling_score += (self.score - self.rolling_score) * .1
	else
		self.rolling_score = self.score
	end
end

function state.gameplay:draw_score()
	local y = 1 + 2 * (self.score - self.rolling_score)
	if y > 5 then y = 5 end
	if self.score == 0 then
		printoc('0', 64, y, 11)
	elseif self.rolling_score % 1 == 0 then
		printoc(self.rolling_score .. '00', 64, y, 11)
	else
		local score_string = ''
		if self.rolling_score > 1 then
			score_string = score_string .. flr(self.rolling_score)
		end
		score_string = score_string .. sub(tostr(self.rolling_score % 1), 3, 4)
		printoc(score_string, 64, y, 11)
	end
end

function state.gameplay:draw()
	local shake = screen_shake[min(screen_shake_frame, #screen_shake)]
	camera(shake[1], shake[2])
	for star in all(self.stars) do star:draw(self.p3d) end
	self.web:draw(self.p3d, self.player.caught and 8 or 3)
	for entity in all(self.entities) do
		entity:draw(self.p3d)
	end
	camera()
	if self.zapper_online then
		local sprite = 3
		if self.player.caught and (uptime / 30) % 1 > .5 then
			sprite = 4
		end
		spr(sprite, 120, 120)
	end
	if self.message_timer > 0 then
		local color = self.message_color
		if (uptime / 30) % 1 > .5 then
			color = 7
		end
		printoc(self.message, 64, self.message_y, color)
	end
	self:draw_score()
	--print(#self.entities, 0, 0, 6)
end

local function apply_audio_effects()
	poke(0x5f40, 0b1000) -- slowdown (channel 3)
	poke(0x5f41, 0b1100) -- delay (channel 2, 3)
	poke(0x5f43, 0b1000) -- distortion (channel 0)
end

function _init()
	apply_audio_effects()
	state_manager:switch(state.gameplay)
	--music(0)
end

function _update60()
	uptime += 1
	state_manager:call 'update'
end

function _draw()
	cls()
	state_manager:call 'draw'
	--print(flr(stat(1) * 200), 0, 0, 7)
end
__gfx__
0000000000000cccccc00000000ea000000f70000000099999900000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000c000000c000000ea000000f700000009900000099000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000c00000000c0000ea220000f7880000090000000000900000000000000000000000000000000000000000000000000000000000000000000000000
0007700000c0000000000c0000eaaa0000f777000900000000000090000000000000000000000000000000000000000000000000000000000000000000000000
000770000c000007700000c000222ea000888f700900900000090090000000000000000000000000000000000000000000000000000000000000000000000000
00700700c00000e77e00000c0002ea000008f7009000090000900009000000000000000000000000000000000000000000000000000000000000000000000000
00000000c0000ee77ee0000c000ea000000f70009000000990000009000000000000000000000000000000000000000000000000000000000000000000000000
00000000c00077777777000c00000000000000009000009009000009000000000000000000000000000000000000000000000000000000000000000000000000
00000000c00077777777000c00000000000000009000009009000009000000000000000000000000000000000000000000000000000000000000000000000000
00000000c0000ee77ee0000c00000000000000009000000990000009000000000000000000000000000000000000000000000000000000000000000000000000
00000000c00000e77e00000c00000000000000009000090000900009000000000000000000000000000000000000000000000000000000000000000000000000
000000000c000007700000c000000000000000000900900000090090000000000000000000000000000000000000000000000000000000000000000000000000
0000000000c0000000000c0000000000000000000900000000000090000000000000000000000000000000000000000000000000000000000000000000000000
00000000000c00000000c00000000000000000000090000000000900000000000000000000000000000000000000000000000000000000000000000000000000
000000000000c000000c000000000000000000000009900000099000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000cccccc0000000000000000000000000099999900000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000022222200000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000002200000022000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000020000000000200000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000200000000000020000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000200000000000020000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000002000000000000002000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000002000000000000002000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000002000000000000002000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000002000000000000002000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000002000000000000002000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000002000000000000002000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000200000000000020000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000200000000000020000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000020000000000200000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000002200000022000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000022222200000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010200001817018160181501814018130181201811018140181401814018130181301812018110181201812018120181201811018110181101810018100181000010000100001000010000100001000010000100
010618200c2120c2120c3120c3220c4220c4220c3320c3320c2320c2420c3420c3420c4520c4520c3520c3620c2620c2620c3720c3720c4720c4620c3620c3620c2520c2520c3520c3520c4520c4520c3520c352
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000034350323502e3502c350293502735024350213501d3501b35000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000e05010050110501305015050180501b0501e000210002100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000336502a650236501c65015650106500c65007650046500165000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200003105025050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000361302a130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400002d0503c351300503b3512e05037351260502e351210502e351230502f3512205028351170502135116050253511905024351150501e3510e050173510a05000300003010030100301003000040000400
010800000c173001730c17300173170002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f0002f000
010400001247016470174701e46022460234601245016450174501e44022440234401243016430174301e42022420234201241016410174100040000400004000040000400004000040000400004000040000400
010400002047024470274702046024460274602045024450274502044024440274402043024430274302042024420274202041024410274100240002400024000240002400024000240002400024000240002400
010b00000301203022031320314203252032520336203362034720347203362033620325203252031420313203022030120000200002000020000200002000020000200002000020000200002000000000000000
014000000c17300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010900003f33200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0105000036045380453d0451800018000180001800018000180001800018000180001800018000180001800018000180001800018000180001800018000180001800018000180001800018000180001800000000
01040000244710047123471004712246100461214610046120451004511f451004511e441004411d441004411d431004311c431004311b431004311a421004211942100421184210042117411004111641100411
010600001b4311c4411d4511f461224713a4713a47139461394613846136461354513445134451324513244131441304412f4412e4312c4312b4312a4312842126421254212342122421204111f4111d4111a411
010600003c1723b1713a1713917100100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
010500003c4723c4723c4723947439472394623646436462364623346433452334522f4542f4522f4422b4442b4422b4422744427432274322443424432244322042420422204221c4241c4221c4121941419412
01060000202521f2411e1311d1210d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d1000d100
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
014000202c870258702a870298702787023870228702a8702c870258702a870298702787023870208702c8702f8702a8702e870258702c870238702a870218702a8702d8702c8702987027870228702487027870
018000000d9300d9300d9300d930179301793012930129300d9300d9300d9300d9301793017930149301493020930209301e9301e9301c9301c9301a9301a9301293012930119301193012930129301493014930
01800000006100161002610036100461005610066100761008610096100a6100b6100c6100d6100e6100f6100f6100f6100e6100d6100c6100b6100a610096100861007610066100561004610036100261001610
__music__
03 22216020

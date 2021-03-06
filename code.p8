pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- utilities

function get_text_width(text)
	local width = 0
	for i = 1, #text do
		width += (sub(text, i, i) >= '█' and 8 or 4)
	end
	return width
end

function printf(text, x, y, align, color, outline_color)
	x -= get_text_width(text) * align
	if outline_color then
		for xx = x - 1, x + 1 do
			for yy = y - 1, y + 1 do
				print(text, xx, yy, outline_color)
			end
		end
	end
	print(text, x, y, color)
end

function to_padded_score(score)
	return score == 0 and '0'
	    or score % 1 == 0 and score .. '00'
		or score > 1 and flr(score) .. sub(tostr(score % 1), 3, 4)
		or sub(tostr(score % 1), 3, 4)
end

function switch_state(state, ...)
	if (current_state and current_state.leave) current_state:leave()
	current_state = state
	if (current_state.enter) current_state:enter(...)
end

function new_class(t, parent)
	t = t or {}
	function t:is(c)
		local parent = getmetatable(self).__index
		if (not parent) return false
		return parent == c or parent:is(c)
	end
	return setmetatable(t, {
		__index = parent,
		__call = function(self, ...)
			local instance = setmetatable({}, {__index = self})
			if instance.new then instance:new(...) end
			return instance
		end,
	})
end

class = {}

-->8
-- pseudo-3d drawing

class.p3d = new_class()

function class.p3d:new()
	self.hx = 64
	self.hy = 64
	self.oz = 0
end

function class.p3d:to2d(x, y, z)
	x -= (self.hx - 64) / 3
	y -= (self.hy - 64) / 3
	z += self.oz
	z = max(0, z)
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
	z += self.oz
	z = max(0, z)
	for i = 1, 4 do z *= z end
	r = r * z * z
	if r < 1 then
		pset(x, y, col)
	else
		circfill(x, y, r, col)
	end
end

function class.p3d:sspr(sx, sy, sw, sh, x, y, z, scale)
	scale = scale or 1
	x, y = self:to2d(x, y, z)
	z += self.oz
	z = max(0, z)
	for i = 1, 4 do z *= z end
	local w, h = sw * z * scale, sh * z * scale
	x -= w/2
	y -= h/2
	sspr(sx, sy, sw, sh, x, y, w, h)
end

class.model = new_class()

function class.model:new(line_data)
	self.lines = {}
	for line_string in all(line_data) do
		local line = {}
		local substring_start = 1
		for i = 1, #line_string do
			if sub(line_string, i, i) == ',' then
				add(line, tonum(sub(line_string, substring_start, i - 1)))
				substring_start = i + 1
			end
		end
		add(self.lines, line)
	end
end

function class.model:draw(p3d, x, y, z, r, sx, sy, sz, col)
	local c, s = cos(r), sin(r)
	for l in all(self.lines) do
		local ax, ay, az, bx, by, bz = l[1], l[2], l[3], l[4], l[5], l[6]
		ax, ay = c * ax - s * ay, s * ax + c * ay
		bx, by = c * bx - s * by, s * bx + c * by
		local x1, y1 = p3d:to2d(ax * sx + x, ay * sy + y, az * sz + z)
		local x2, y2 = p3d:to2d(bx * sx + x, by * sy + y, bz * sz + z)
		line(x1, y1, x2, y2, col)
	end
end

-->8
-- resources

cartdata 'tesselode_web_pilot'
uptime = 0
state = {}
model = {
	player = class.model {
		'-1,0,.01389,0,-1,.01389,',
		'0,-1,.01389,1,0,.01389,',
		'1,0,.01389,0,1,.01389,',
		'0,1,.01389,-1,0,.01389,',
		'-1,0,.01389,0,0,-.01389,',
		'0,0,-.01389,1,0,.01389,',
		'0,1,.01389,0,0,-.01389,',
		'0,0,-.01389,0,-1,.01389,',
	},
	flipper = class.model {
		'-1,-1,0,1,1,0,',
		'1,1,0,1,-1,0,',
		'1,-1,0,-1,1,0,',
		'-1,1,0,-1,-1,0,',
	},
	thwomp = class.model {
		'-1,1,0,1,1,0,',
		'1,1,0,.66667,-1,0,',
		'.66667,-1,0,-.66667,-1,0,',
		'-.66667,-1,0,-1,1,0,',
		'-1,1,0,.66667,-1,0,',
		'-.66667,-1,0,1,1,0,',
	}
}
save_data_id = {
	high_score = 0,
	control_direction = 32,
}
freeze_frames = 0
screen_shake = {
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
screen_shake_frame = 1
compliments = {
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
	'splendid!',
}
threats = {
	"gotcha~",
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
-- gameplay classes

class.web = new_class({
	min_z = .9,
	max_z = 1.01,
	zap_speed = .002,
})

function class.web:generate(seed)
	local entropy = rnd()
	self.seed = seed or flr(rnd(0xffff.ffff))
	self.name = sub(tostr(self.seed, true), 3, 6)
	self.name = sub(self.name, 1, 2) .. '-' .. sub(self.name, 3, 4)
	srand(self.seed)
	self.points = {}
	local lane_size = 16
	local radius = 32 + rnd(24)
	local angle = 0
	local tilt_x = rnd(1/12)
	local tilt_y = rnd(1/12)
	local y = radius * sin(angle)
	local x = radius * cos(angle)
	local start_x = x
	local start_y = y
	while true do
		add(self.points, {x = x + 64, y = y + 64})
		local new_x = radius * cos(angle + rnd(1/8) + tilt_x)
		local new_y = radius * sin(angle + rnd(1/8) + tilt_y)
		local dx = new_x - x
		local dy = new_y - y
		local len = sqrt(dx * dx + dy * dy)
		dx /= len
		dy /= len
		dx *= lane_size
		dy *= lane_size
		x += dx
		y += dy
		local new_angle = atan2(x, y)
		if angle > new_angle then break end
		angle = new_angle
	end
	srand(entropy)
	-- regenerate if the last lane is too wide or narrow
	if not seed then
		local a = self.points[1]
		local b = self.points[#self.points]
		local dist = sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
		if dist > lane_size or dist < lane_size * .9 then
			self:generate()
		end
	end
end

function class.web:new(seed)
	self:generate(seed)
	self.zapping = false
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
		local b = i == #self.points and self.points[1] or self.points[i + 1]
		if color > 1 then
			p3d:line(a.x, a.y, self.max_z, a.x, a.y, 1.2, 1)
		end
		p3d:line(a.x, a.y, self.min_z, b.x, b.y, self.min_z, color)
		p3d:line(a.x, a.y, self.max_z, b.x, b.y, self.max_z, color)
		if self.zapping then
			p3d:line(a.x, a.y, self.zapping, b.x, b.y, self.zapping, 7)
		end
		p3d:line(a.x, a.y, self.min_z, a.x, a.y, self.max_z, color)
	end
end

class.physical = new_class()

class.player = new_class({
	radius = 6,
	acceleration = .01,
	friction = .05,
	reload_time = 5,
	shot_heat = .2,
	shot_cooldown_speed = .05,
	jump_power = .003,
	gravity = .0001,
	stun_time = 90,
}, class.physical)

function class.player:new(state, web, position)
	self.state = state
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

function class.player:shoot()
	self.reload_timer = self.reload_time
	self.heat += self.shot_heat
	if self.heat > 1 then
		self.overheat = true
	end
	self.state:on_player_shot(self.position, self.z)
end

function class.player:jump()
	if not self.caught and not self.jumping and self.stun_timer <= 0 then
		self.jumping = true
		self.vz = self.jump_power
		sfx(9, 1)
	end
end

function class.player:stun()
	if not self.jumping and not self.caught then
		self.stun_timer = self.stun_time
		self.velocity = 0
	end
end

function class.player:update()
	if self.caught and self.caught.dead then self.caught = false end -- bandaid fix for rare state bug
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
		if dget(save_data_id.control_direction) == 1 then acceleration *= -1 end
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
	if self.reload_timer <= 0 and not self.overheat and btn(4) and not state.gameplay.intro then
		self:shoot()
	end
end

function class.player:collide(other)
	if other:is(class.powerup) then
		other.dead = true
		self.state:on_powerup_collected(self.x, self.y, self.z)
	end
end

function class.player:draw(p3d)
	local z = self.z
	if self.stun_timer > 0 then
		z += .004 * (self.stun_timer / self.stun_time) * sin(uptime * .2)
	end
	assert(not state.gameplay.wait_for_update, "this shouldn't happen. if you see this error, let me know on twitter @tesselode")
	assert(self.position, "huh????")
	local r = atan2(self.x - 64, self.y - 64) + self.velocity * (2/3)
	color = self.stun_timer > 0 and 13 or 10
	model.player:draw(p3d, self.x, self.y, z, r, 8, 8, 1, color)
end

class.player_bullet = new_class({
	radius = 1,
	speed = .0067,
}, class.physical)

function class.player_bullet:new(web, position, z)
	self.web = web
	self.position = position
	self.z = z
	self.first_frame = true
end

function class.player_bullet:update()
	if not self.first_frame then
		self.position += (flr(self.position) + .5 - self.position) / 3
	end
	self.z -= self.speed
	if self.z <= self.web.min_z then
		self.dead = true
	end
	self.first_frame = false
end

function class.player_bullet:collide(other)
	if other:is(class.enemy) and not other.dragging then self.dead = true end
end

function class.player_bullet:draw(p3d)
	local x, y, z = self.x, self.y, self.z
	p3d:line(x - 1, y, z, x, y, z + .01, 10)
	p3d:line(x, y, z, x, y, z + .01, 10)
	p3d:line(x + 1, y, z, x, y, z + .01, 10)
end

class.enemy = new_class({}, class.physical)

class.flipper = new_class({
	base_speed = .0005,
	flip_interval = 30,
	flip_speed = .03333,
	drag_speed = .00025,
}, class.enemy)

function class.flipper:new(state, p3d, web, player, difficulty, small, position, z)
	self.state = state
	self.p3d = p3d
	self.web = web
	self.player = player
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
	local pos = flr(self.position % #self.web.points)
	local player_pos = flr(self.player.position % #self.web.points)
	local negative_dist, positive_dist = 0, 0
	local test_pos = pos
	while test_pos ~= player_pos do
		test_pos = (test_pos - 1) % #self.web.points
		negative_dist += 1
	end
	test_pos = pos
	while test_pos ~= player_pos do
		test_pos = (test_pos + 1) % #self.web.points
		positive_dist += 1
	end
	return negative_dist < positive_dist and -1 or 1
end

function class.flipper:flip()
	self.flip_timer += self.flip_interval
	self.flip_direction = self.z == 1 and self:get_shortest_path_to_player() or (rnd(1) > .5 and 1 or -1)
	self.flip_progress = 0
end

function class.flipper:update()
	if self.dragging then
		self.position = self.dragging.position
		self.z -= self.drag_speed
		return
	end
	if self.z < 1 then
		self.z += (self.z < self.web.min_z and self.base_speed * 3 or self.speed)
		self.z = min(self.z, 1)
	end
	if self.flip_direction == 0 and self.z > self.web.min_z then
		local timer_speed = 1
		if self.z == 1 then timer_speed *= 2 end
		if self.small then timer_speed *= 2 end
		self.flip_timer -= timer_speed * self.difficulty
		if self.flip_timer <= 0 then self:flip() end
	end
	if self.flip_direction ~= 0 then
		self.flip_progress += self.flip_speed
		self.position += self.flip_speed * self.flip_direction * (self.small and .5 or 1)
		self.r += self.flip_speed * self.flip_direction / 2 * (self.small and 2 or 1)
		if self.flip_progress >= 1 then
			self.flip_direction = 0
			sfx(self.small and 12 or 11, 2)
		end
	end
end

function class.flipper:die()
	self.dead = true
	if self.dragging then self.dragging.caught = false end
	self.state:on_enemy_killed(self)
end

function class.flipper:collide(other)
	if other:is(class.player) and (not other.caught) and self.z == 1 and self.flip_direction == 0 then
		other.caught = self
		self.dragging = other
		self.state:on_player_caught()
	end
	if other:is(class.player_bullet) and not self.dragging then
		self:die()
	end
end

function class.flipper:draw(p3d)
	local scale = self.small and 3 or 6
	model.flipper:draw(p3d, self.x, self.y, self.z, self.r, scale, scale, 1, self.color)
end

class.thwomp = new_class({
	radius = 16,
	min_jump_interval = 150,
	max_jump_interval = 300,
	jump_power = .1,
	gravity = .005,
	starting_health = 12,
	point_value = 5,
	color = 8,
}, class.enemy)

function class.thwomp:new(state, web, difficulty)
	self.state = state
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

function class.thwomp:jump()
	self.jump_timer += self.min_jump_interval + rnd(self.max_jump_interval - self.min_jump_interval)
	self.jumping = true
	self.vh = self.jump_power
	self.vp = -.1 + rnd(.2)
	self.vz = self.z < self.web.min_z + .01 and .0002
		or self.z > .99 and .0002
		or -.0002 + rnd(.0002)
	sfx(9, 2)
end

function class.thwomp:update()
	if self.z < self.web.min_z then
		self.z += .001
		if self.z >= self.web.min_z then
			music '9'
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
			self.state:on_thwomp_landed()
		end
	else
		self.jump_timer -= self.difficulty / 2
		if self.jump_timer <= 0 then self:jump() end
	end

	-- cosmetic
	self.flash_timer -= 1
end

function class.thwomp:die()
	self.dead = true
	self.state:on_enemy_killed(self)
	sfx(18, 2)
end

function class.thwomp:collide(other)
	if other:is(class.player_bullet) then
		self.health -= 1
		if self.health == 0 then
			self:die()
		else
			self.flash_timer = 4
			sfx(19, 0)
		end
	end
end

function class.thwomp:draw(p3d)
	local x, y = self.web:get_position(self.position)
	local r = atan2(x - 64, y - 64)
	local color = self.flash_timer > 0 and 7 or self.color
	model.thwomp:draw(p3d, self.x, self.y, self.z, r + .25, self.radius, self.radius, 1, color)
end

class.phantom = new_class({
	radius = 24,
	color = 7,
	point_value = 20,
	push_back = .025,
	segment_z_multipliers = {.99, .5, .25},
}, class.enemy)

function class.phantom:new(state, web, difficulty)
	self.state = state
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
	self.z = min(self.z, .98)
	if self.z > .96 then
		self.spawn_timer -= self.difficulty / 3
		while self.spawn_timer <= 0 do
			self.spawn_timer += 30
			self.state:on_phantom_spawned_enemy(self.position, self.z)
		end
	end

	-- cosmetic
	if not self.announced_entrance and self.z > self.web.min_z then
		music '11'
		self.announced_entrance = true
	end
	if self.flash_timer > 0 then self.flash_timer -= 1 end
end

function class.phantom:die()
	self.dead = true
	self.state:on_enemy_killed(self)
	music '12'
	freeze_frames += 4
	screen_shake_frame += 4
end

function class.phantom:collide(other)
	if other:is(class.player_bullet) then
		self.movement_speed += 2 * sgn(self.movement_speed)
		self.movement_speed *= -1
		self.z -= self.push_back / self.difficulty
		if self.z < self.web.min_z then
			self:die()
		else
			self.flash_timer = 4
			sfx(23, 2)
		end
	end
end

function class.phantom:draw(p3d)
	for z in all(self.segment_z_multipliers) do
		p3d:sspr(40, 16, 16, 16, self.x, self.y, self.z + (self.web.min_z - self.z) * z, 2)
	end
	if self.flash_timer > 0 then pal(9, 7) end
	p3d:sspr(40, 0, 16, 16, self.x, self.y, self.z, 2)
	pal()
end

class.powerup = new_class({
	speed = .0005,
	radius = 8,
}, class.physical)

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

class.particle = new_class()

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
	if self.life == 0 then self.dead = true end
	self.speed -= .1
	self.r -= .1
	self.x += self.speed * cos(self.direction)
	self.y += self.speed * sin(self.direction)
end

function class.particle:draw(p3d)
	p3d:circfill(self.x, self.y, self.z, self.r, self.color)
end

class.star = new_class()

function class.star:new()
	local angle = rnd(1)
	self.x = 64 + 128 * cos(angle)
	self.y = 64 + 128 * sin(angle)
	self.z = .8 + rnd(.4)
end

function class.star:update(speed)
	self.z += .0002 * speed
	if self.z >= 1.2 then
		local angle = rnd(1)
		self.x = 64 + 128 * cos(angle)
		self.y = 64 + 128 * sin(angle)
		self.z = .8
	end
end

function class.star:draw(p3d)
	local x, y = p3d:to2d(self.x, self.y, self.z)
	pset(x, y, 1)
end

class.score_popup = new_class()

function class.score_popup:new(text, x, y, color)
	self.text = text
	self.x = x
	self.y = y
	self.color = color
	self.life = 40
	self.vy = .5
end

function class.score_popup:update()
	self.vy -= .01
	self.y -= self.vy
	self.life -= 1
	if self.life <= 0 then self.dead = true end
end

function class.score_popup:draw()
	local color = self.life / 15 % 1 < .5 and self.color or 7
	printf(self.text, self.x, self.y, .5, color)
end

-->8
-- gameplay state

state.gameplay = {
	entity_limit = 30,
	game_over_time = 240,
}

function state.gameplay:init_stars()
	self.stars = {}
	for i = 1, 20 do
		add(self.stars, class.star())
	end
end

function state.gameplay:init_timers()
	self.timer = {
		flipper = 60 + rnd(60),
		small_flipper = 3200 + rnd(800),
		thwomp = 6000 + rnd(1000),
		phantom = 10000 + rnd(3000),
	}
end

function state.gameplay:on_player_shot(position, z)
	self:queue_entity(class.player_bullet(self.web, position, z))
	sfx(8, 0)
end

function state.gameplay:on_powerup_collected(x, y, z)
	for i = 1, 10 do
		self:queue_entity(class.particle(x, y, z, 12))
	end
	if not self.zapper_online then
		self.zapper_online = true
		self:show_message 'superzapper recharge'
		sfx(15, 1)
	else
		if (not self.player.jumping) or self.powerup_streak == 0 then
			self.powerup_streak += 1
			self.powerup_streak_display_timer = 1
		end
		self.score += self.powerup_streak * 10
		self:queue_entity(class.score_popup(self.powerup_streak .. '000', self.p3d:to2d(x, y, z)))
		local message = compliments[ceil(rnd(#compliments))]
		message = message .. ' +' .. self.powerup_streak .. '000'
		self:show_message(message)
		sfx(16, 1)
	end
end

function state.gameplay:on_enemy_killed(enemy)
	if not self.web.zapping then
		self.to_next_powerup -= 1
		if self.to_next_powerup == 0 then
			self.to_next_powerup = 7 + self.powerup_streak + flr(self.difficulty) * flr(self.difficulty)
			self:queue_entity(class.powerup(enemy.x, enemy.y, enemy.z))
		end
	end
	if not self.player.jumping and not self.web.zapping then
		local point_value = enemy.point_value
		local color = 12
		if enemy:is(class.flipper) then
			if enemy.z < self.web.min_z + (1 - self.web.min_z) / 3 then
				point_value *= 2
				color = 14
			elseif enemy.z == 1 then
				point_value *= 3
				sfx(20, 1)
				color = 11
			end
		end
		self.score += point_value
		local x, y = self.p3d:to2d(enemy.x, enemy.y, enemy.z)
		self:queue_entity(class.score_popup(point_value .. '00', x, y, color))
	end
	if enemy:is(class.thwomp) then self.difficulty += .1 end
	if enemy:is(class.phantom) then self.difficulty += 1/3 end
	for i = 1, 5 do
		self:queue_entity(class.particle(enemy.x, enemy.y, enemy.z, enemy.color))
	end
	freeze_frames += 4
	screen_shake_frame += 3
	sfx(10, 0)
end

function state.gameplay:on_player_caught()
	self:show_message(threats[ceil(rnd(#threats))], 8)
	music '8'
end

function state.gameplay:on_thwomp_landed()
	self.player:stun()
	sfx(18, 2)
end

function state.gameplay:on_phantom_spawned_enemy(position, z)
	if #self.entities < self.entity_limit then
		self:queue_entity(class.flipper(self, self.p3d, self.web, self.player, self.difficulty, rnd(1) > .5, position, z))
		sfx(25, 2)
	end
end

function state.gameplay:init_menu_items()
	menuitem(1, 'retry (same web)', function()
		switch_state(state.gameplay, state.gameplay.web)
	end)
	menuitem(2, 'back to menu', function()
		switch_state(state.title, true)
	end)
	menuitem(3, 'invert controls', function()
		dset(save_data_id.control_direction, dget(save_data_id.control_direction) == 0 and 1 or 0)
	end)
end

function state.gameplay:enter(web)
	self.p3d = class.p3d()
	self.p3d.oz = -2/3
	self.web = web
	self.queue = {}
	self.entities = {}
	self.player = add(self.entities, class.player(self, self.web, 1))
	self:init_stars()
	self.score = 0
	self.zapper_online = false
	self.difficulty = 1
	self:init_timers()
	if rnd(1) > .9 then self.timer.phantom -= 5400 end
	self.spawn_timer = 1
	self.to_next_powerup = 3
	self.powerup_streak = 0
	self.game_over_timer = 0
	self.intro = true
	self.wait_for_update = true

	-- cosmetic
	self.message = ''
	self.message_timer = 0
	self.message_y = 64
	self.message_color = 12
	self.powerup_streak_display_timer = 0
	self.powerup_streak_display_oy = 16
	self.rolling_score = self.score
	self.doomed = false
	music(-1)
	sfx(30, 2)
	self:show_message('arriving at web ' .. self.web.name, 11)

	self:init_menu_items()
end

function state.gameplay:queue_entity(entity)
	add(self.queue, entity)
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

function state.gameplay:zap()
	self.web:zap()
	self.player.caught:die()
	self.zapper_online = false
	self.difficulty -= .1
	self.difficulty = max(self.difficulty, 1)
	self.powerup_streak = 0
	self:show_message 'eat electric death!'
	self.powerup_streak_display_timer = 1
	music '10'
end

function state.gameplay:update()
	self.wait_for_update = false

	-- input
	if not self.intro then
		if btnp(5) then
			if self.player.caught then
				if self.zapper_online and self.player.z > self.web.min_z then
					self:zap()
				end
			else
				self.player:jump()
			end
		end
	end

	-- game feel
	freeze_frames = min(freeze_frames, 6)
	if freeze_frames > 0 then
		freeze_frames -= 1
		return
	end
	if screen_shake_frame > 1 then
		screen_shake_frame -= 1
	end

	-- intro sequence
	if self.intro then
		self.p3d.oz += .0025
		self.player.z = 1 - self.p3d.oz + 1/5 * (self.p3d.oz * self.p3d.oz)
		if self.p3d.oz >= 0 then
			self.p3d.oz = 0
			self.player.z = 1
			self.intro = false
			sfx(-1, 2)
			sfx(31, 3)
		end
	end

	-- spawn enemies
	if not self.intro then
		self.difficulty += .0002
		if self.player.z > self.web.min_z and #self.entities < self.entity_limit then
			self.timer.flipper -= self.difficulty
			while self.timer.flipper <= 0 do
				self.timer.flipper += 90 + rnd(60)
				self:queue_entity(class.flipper(self, self.p3d, self.web, self.player, self.difficulty))
				if self.difficulty > 1.5 and rnd(1) > .95 then
					for i = 1, flr(self.difficulty * 2) do
						self:queue_entity(class.flipper(self, self.p3d, self.web, self.player, self.difficulty))
					end
					self.difficulty -= .05
				end
				sfx(14, 3)
			end
			self.timer.small_flipper -= self.difficulty
			while self.timer.small_flipper <= 0 do
				self.timer.small_flipper += 400 + rnd(400)
				self:queue_entity(class.flipper(self, self.p3d, self.web, self.player, self.difficulty, true))
				if rnd(1) > .95 then
					for i = 1, flr(self.difficulty * 2) do
						self:queue_entity(class.flipper(self, self.p3d, self.web, self.player, self.difficulty, true))
					end
					self.difficulty -= .05
				end
				sfx(14, 3)
			end
			self.timer.thwomp -= self.difficulty
			while self.timer.thwomp <= 0 do
				self.timer.thwomp += 1600 + rnd(700)
				self:queue_entity(class.thwomp(self, self.web, self.difficulty))
				self.difficulty -= .1
				if rnd(1) > .9 then
					for i = 1, flr(self.difficulty) do
						self:queue_entity(class.thwomp(self, self.web, self.difficulty))
					end
				end
				sfx(14, 3)
			end
			self.timer.phantom -= self.difficulty
			while self.timer.phantom <= 0 do
				self.timer.phantom += 2000 + rnd(1000)
				self:queue_entity(class.phantom(self, self.web, self.difficulty))
				self.difficulty -= 1/3
				sfx(14, 3)
			end
		end
	end

	-- update web and entities
	self.web:update()
	for i = #self.entities, 1, -1 do
		local entity = self.entities[i]
		if entity.dead then del(self.entities, entity) end
	end
	for entity in all(self.queue) do
		add(self.entities, entity)
		del(self.queue, entity)
	end
	for i = 1, #self.entities do
		local entity = self.entities[i]
		entity:update()
		if entity:is(class.physical) and entity.position then
			entity.x, entity.y = self.web:get_position(entity.position, entity.h)
		end
	end

	-- zapper
	if self.web.zapping then
		for i = 1, #self.entities do
			local entity = self.entities[i]
			if entity:is(class.enemy) and not entity:is(class.phantom) and abs(entity.z - self.web.zapping) < .01 and not entity.jumping then
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

	-- game over
	if self.player.z < self.web.min_z then
		if not self.doomed then
			self.doomed = true
			music '2'
		end
		self.game_over_timer += 1
		if self.game_over_timer >= self.game_over_time then
			switch_state(state.game_over)
		end
	end

	-- cosmetic
	for i = 1, #self.stars do self.stars[i]:update(1) end
	local target_hx = 64 + (self.player.x - 64) * 1/6
	local target_hy = 64 + (self.player.y - 64) * 1/6
	if not self.intro then
		self.p3d.hx += (target_hx - self.p3d.hx) * .1
		self.p3d.hy += (target_hy - self.p3d.hy) * .1
		self.p3d.oz = -(self.player.z - 1) / 3
	end

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

	-- powerup streak display animation
	self.powerup_streak_display_timer -= 1/180
	local target_oy = self.powerup_streak_display_timer > 0 and 0 or 16
	self.powerup_streak_display_oy += (target_oy - self.powerup_streak_display_oy) * .1
end

function state.gameplay:leave()
	menuitem(1)
	menuitem(2)
	menuitem(3)
end

function state.gameplay:draw_world()
	local shake = screen_shake[min(screen_shake_frame, #screen_shake)]
	camera(shake[1], shake[2])
	for i = 1, #self.stars do self.stars[i]:draw(self.p3d) end
	self.web:draw(self.p3d, self.player.caught and 8 or 3)
	for i = 1, #self.entities do self.entities[i]:draw(self.p3d) end
	camera()
end

function state.gameplay:draw_zapper_display()
	if self.zapper_online then
		local sprite = 3
		if self.player.caught and (uptime / 30) % 1 > .5 and not self.doomed then
			sprite = 4
		end
		spr(sprite, 120, 120)
		if self.player.caught and not self.doomed then
			local color = (uptime / 30) % 1 > .5 and 7 or 9
			printf("press ❎ to use ", 120, 121, 1, color, 0)
		end
	end
end

function state.gameplay:draw_powerup_streak()
	local sprite = self.powerup_streak > 0 and 20 or 19
	local color = self.powerup_streak > 0 and 12 or 13
	spr(sprite, 0, 120 + self.powerup_streak_display_oy)
	printf(self.powerup_streak .. 'x', 10, 121 + self.powerup_streak_display_oy, 0, color, 0)
end

function state.gameplay:draw_message()
	if self.message_timer > 0 then
		local color = (uptime / 30) % 1 > .5 and 7 or self.message_color
		printf(self.message, 64, self.message_y, .5, color, 0)
	end
end

function state.gameplay:draw_score()
	local y = 2 + 2 * (self.score - self.rolling_score)
	if y > 6 then y = 6 end
	printf(to_padded_score(self.rolling_score), 64, y, .5, 11, 0)
end

function state.gameplay:draw()
	if self.wait_for_update then return end
	self:draw_world()
	self:draw_zapper_display()
	self:draw_powerup_streak()
	self:draw_message()
	self:draw_score()
end

-->8
-- other states

state.title = {}

function state.title:enter(quick)
	music '0'
	self.p3d = class.p3d()
	self.p3d.oz = quick and -1/6 or -2/3
	self.web = class.web()
	self.stars = {}
	for i = 1, 50 do add(self.stars, class.star()) end
	self.title_z = 0
	self.web_alpha = 1
	self.title_uptime = 0

	self.state = quick and 1 or 0
	self.title_oy = 0
	self.option_selected = 1
	self.changing_web = false
end

function state.title:update()
	if self.state == 0 then
		if btnp(4) then
			self.state = 1
			sfx(29, 1)
		end
	elseif self.state == 1 then
		if btnp(2) then
			if self.option_selected > 1 then
				self.option_selected -= 1
				sfx(26, 1)
			end
		end
		if btnp(3) then
			if self.option_selected < 3 then
				self.option_selected += 1
				sfx(26, 1)
			end
		end
		if btnp(4) then
			if self.option_selected == 1 then
				music(-1)
				sfx(28, 1)
				self.state = 2
			end
			if self.option_selected == 2 and not self.changing_web then
				sfx(29, 1)
				self.changing_web = true
			end
			if self.option_selected == 3 then
				sfx(29, 1)
				dset(save_data_id.control_direction, dget(save_data_id.control_direction) == 0 and 1 or 0)
			end
		end
		if btnp(5) then
			self.state = 0
			sfx(27, 1)
			self.title_uptime = 0
		end
	elseif self.state == 2 then
		self.p3d.oz -= 1/60
		if self.p3d.oz < -1 then
			switch_state(state.gameplay, self.web)
		end
	end

	-- cosmetic
	local target_title_oy = self.state == 1 and -40 or 0
	self.title_oy += (target_title_oy - self.title_oy) * .1
	for i = 1, #self.stars do self.stars[i]:update(1) end
	if self.state == 0 and self.title_z == 1 then
		self.title_uptime += 1
	end
	if self.state == 2 then
		self.p3d.hx += (64 - self.p3d.hx) * .5
		self.p3d.hy += (64 - self.p3d.hy) * .5
	else
		self.p3d.hx = 64 + 4 * sin(uptime / 240)
		self.p3d.hy = 64 + 4 * cos(uptime / 300)
	end
	if self.state ~= 2 then
		self.p3d.oz -= self.p3d.oz * .025
	end
	if self.p3d.oz > -.001 then self.p3d.oz = 0 end
	if self.p3d.oz > -.025 then
		self.title_z += (1 - self.title_z) * 2/30
		if self.title_z > .999 then self.title_z = 1 end
	end

	-- change web
	if self.changing_web then
		self.web_alpha -= self.web_alpha * .1
		if self.web_alpha < 1/4 then
			self.web = class.web()
			self.changing_web = false
		end
	else
		self.web_alpha += (1 - self.web_alpha) * .1
	end
end

function state.title:draw()
	for i = 1, #self.stars do self.stars[i]:draw(self.p3d) end
	self.web:draw(self.p3d, self.web_alpha < 1/2 and 0 or self.web_alpha < 2/3 and 1 or 3)

	local x = 64 + 3.99 * sin(uptime / 480)
	local y = 64 + self.title_oy
	pal(7, 1)
	self.p3d:sspr(0, 32, 33, 14, x, y, self.web.min_z + (self.title_z - self.web.min_z) * .98, 2)
	pal(7, 13)
	self.p3d:sspr(0, 32, 33, 14, x, y, self.web.min_z + (self.title_z - self.web.min_z) * .99, 2)
	pal()
	self.p3d:sspr(0, 32, 33, 14, x, y, self.title_z, 2)

	if self.state == 0 and self.title_z == 1 then
		if (self.title_uptime / 1250) % 1 < 1/3 then
			printf('mmxviii tesselode', 64, 88, .5, 6, 0)
			printf('press 🅾️ to start', 64, 96, .5, 11, 0)
		elseif (self.title_uptime / 1250) % 1 < 2/3 then
			printf('a remix of the tempest games', 64, 88, .5, 6, 0)
			printf('by dave theurer and jeff minter', 64, 96, .5, 6, 0)
		else
			printf('⬅️➡️ move', 64, 88, .5, 6, 0)
			printf('🅾️ shoot    ❎ jump / zap', 64, 96, .5, 6, 0)
		end
	end
	if self.state == 1 then
		local color = self.option_selected == 1 and 11 or 5
		printf('play', 64, 104, .5, color, 0)
		color = self.option_selected == 2 and 11 or 5
		printf('change destination', 64, 112, .5, color, 0)
		color = self.option_selected == 3 and 11 or 5
		if dget(save_data_id.control_direction) == 0 then
			printf('controls: normal', 64, 120, .5, color, 0)
		end
		if dget(save_data_id.control_direction) == 1 then
			printf('controls: inverted', 64, 120, .5, color, 0)
		end
		printf('hi score: ' .. to_padded_score(dget(save_data_id.high_score)), 64, 2, .5, 12, 0)
	end
	
end

state.game_over = {}

function state.game_over:enter()
	sfx(-1, 0)
	sfx(-1, 1)
	sfx(-1, 2)
	sfx(-1, 3)
	music '1'
	self.timer = 240
end

function state.game_over:update()
	self.timer -= 1
	if self.timer == 0 then
		switch_state(state.results)
	end
end

function state.game_over:draw()
	print("we have you now...\n\nand we're never\nletting you go~!", 8, 33 + 2 * sin(uptime / 45), 1)
	print("we have you now...\n\nand we're never\nletting you go~!", 8, 32 + 2 * sin(uptime / 45), 8)
end

state.results = {}

function state.results:enter()
	self.score = state.gameplay.score
	self.high_score = false
	if self.score > dget(save_data_id.high_score) then
		self.high_score = true
		dset(save_data_id.high_score, self.score)
	end
	self.score_roll_timer = 40
	self.menu_timer = 40
	self.rolling_score = 0
end

function state.results:update()
	self.score_roll_timer -= 1
	if self.score_roll_timer <= 0 and self.rolling_score < self.score then
		self.rolling_score += (self.score - self.rolling_score) * .1
		sfx(48, 1)
		if self.rolling_score > self.score - .1 then
			self.rolling_score = self.score
		end
	end
	if self.rolling_score == self.score and self.menu_timer > 0 then
		self.menu_timer -= 1
		if self.menu_timer == 0 then
			if self.high_score then music '3' end
		end
	end
	if self.menu_timer == 0 then
		if btnp(4) then switch_state(state.gameplay, state.gameplay.web) end
		if btnp(5) then switch_state(state.title, true) end
	end
end

function state.results:draw()
	printf('your score:', 64, 49, .5, 1)
	printf('your score:', 64, 48, .5, 12)
	printf(to_padded_score(self.rolling_score), 64, 57, .5, 5)
	printf(to_padded_score(self.rolling_score), 64, 56, .5, 7)
	if self.high_score and self.menu_timer == 0 then
		local y = 72 + 2.99 * sin(uptime / 100)
		printf('new high score!', 64, y + 1, .5, 2)
		printf('new high score!', 64, y, .5, 14)
	end
	if self.menu_timer == 0 then
		printf('🅾️ retry same web', 64, 97, .5, 5)
		printf('🅾️ retry same web', 64, 96, .5, 7)
		printf('❎ back to menu', 64, 105, .5, 5)
		printf('❎ back to menu', 64, 104, .5, 7)
	end
end

-->8
-- main loop

function apply_audio_effects()
	poke(0x5f40, 0b1000) -- slowdown (channel 3)
	poke(0x5f41, 0b1100) -- delay (channel 2, 3)
	poke(0x5f43, 0b1000) -- distortion (channel 0)
end

function _init()
	apply_audio_effects()
	switch_state(state.title)
end

function _update60()
	uptime += 1
	current_state:update()
end

function _draw()
	cls()
	current_state:draw()
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

--!native
--!optimize 2
--!strict

local Spring_Vector3 = require("./vector3")

export type Spring = {
	type: "CFrame",
	position: Spring_Vector3.Spring,
	rotation: Spring_Rotation,
	d: number,
	f: number,
	g: CFrame,
	p: CFrame
}

type Spring_Rotation = {
	d: number,
	f: number,
	g: CFrame,
	p: CFrame,
	v: Vector3
}

-- evaluate dot products in high precision
local function dot(v0: Vector3, v1: Vector3)
	return v0.X*v1.X + v0.Y*v1.Y + v0.Z*v1.Z
end

local function angleDiff(c0: CFrame, c1: CFrame)
	local x = dot(c0.XVector, c1.XVector)
	local y = dot(c0.YVector, c1.YVector)
	local z = dot(c0.ZVector, c1.ZVector)
	local w = x + y + z - 1
	return math.atan2(math.sqrt(math.max(0, 1 - w*w*0.25)), w*0.5)
end

-- gives approx. 21% accuracy improvement over CFrame.fromAxisAngle near poles
local function fromAxisAngle(axis: Vector3, angle: number)
	local c = math.cos(angle)
	local s = math.sin(angle)
	local x, y, z = axis.X, axis.Y, axis.Z

	local mxy = x*y*(1 - c)
	local myz = y*z*(1 - c)
	local mzx = z*x*(1 - c)

	local rx = Vector3.new(x*x*(1 - c) + c, mxy + z*s, mzx - y*s)
	local ry = Vector3.new(mxy - z*s, y*y*(1 - c) + c, myz + x*s)
	local rz = Vector3.new(mzx + y*s, myz - x*s, z*z*(1 - c) + c)

	return CFrame.fromMatrix(Vector3.zero, rx, ry, rz):Orthonormalize()
end

local function rotateAxis(r0: Vector3, c1: CFrame)
	local c0 = CFrame.identity
	local mag = r0.Magnitude
	if mag > 1e-6 then
		c0 = fromAxisAngle(r0.Unit, mag)
	end
	return c0 * c1
end

-- axis*angle difference between two cframes
local function axisAngleDiff(c0: CFrame, c1: CFrame)
	-- use native axis (stable enough)
	local axis = (c0*c1:Inverse()):ToAxisAngle()

	-- use full-precision angle calculation to minimize truncation
	local angle = angleDiff(c0, c1)
	return axis.Unit*angle
end

local function rotation_step(spring: Spring_Rotation, dt: number): CFrame
	debug.profilebegin("rotation")
	local d = spring.d
	local f = spring.f*(2*math.pi)
	local g = spring.g
	local p0 = spring.p
	local v0 = spring.v

	local offset = axisAngleDiff(p0, g)
	local decay = math.exp(-d*f*dt)

	local pt: CFrame
	local vt: Vector3

	if d == 1 then -- critically damped
		pt = rotateAxis((offset*(1 + f*dt) + v0*dt)*decay, g)
		vt = (v0*(1 - dt*f) - offset*(dt*f*f))*decay

	elseif d < 1 then -- underdamped
		local c = math.sqrt(1 - d*d)

		local i = math.cos(dt*f*c)
		local j = math.sin(dt*f*c)

		local y = j/(f*c)
		local z = j/c

		pt = rotateAxis((offset*(i + z*d) + v0*y)*decay, g)
		vt = (v0*(i - z*d) - offset*(z*f))*decay
	else -- overdamped
		local c = math.sqrt(d*d - 1)

		local r1 = -f*(d + c)
		local r2 = -f*(d - c)

		local co2 = (v0 - offset*r1)/(2*f*c)
		local co1 = offset - co2

		local e1 = co1*math.exp(r1*dt)
		local e2 = co2*math.exp(r2*dt)

		pt = rotateAxis(e1 + e2, g)
		vt = e1*r1 + e2*r2
	end

	spring.p = pt
	spring.v = vt

	debug.profileend()

	return pt
end

local SLEEP_ROTATION_DIFF = math.rad(0.01) -- rad
local SLEEP_ROTATION_VELOCITY = math.rad(0.1) -- rad/s

local function areRotationsClose(c0: CFrame, c1: CFrame)
	local rx = dot(c0.XVector, c1.XVector)
	local ry = dot(c0.YVector, c1.YVector)
	local rz = dot(c0.ZVector, c1.ZVector)
	local trace = rx + ry + rz
	return trace > 1 + 2*math.cos(SLEEP_ROTATION_DIFF)
end

local function rotation_can_sleep(spring: Spring_Rotation): boolean
	local sleepP = areRotationsClose(spring.p, spring.g)
	local sleepV = spring.v.Magnitude < SLEEP_ROTATION_VELOCITY
	return sleepP and sleepV
end

-- Very important to remember that the origo and the goal's Rotation are
-- orthonormalized!
local function create(d: number, f: number, origo: CFrame, goal: CFrame): Spring
	return {
		type = "CFrame",
		position = {
			type = "Vector3",
			d = d,
			f = f,
			g = goal.Position,
			p = origo.Position,
			v = Vector3.zero,
		},
		rotation = {
			d = d,
			f = f,
			g = goal.Rotation:Orthonormalize(),
			p = origo.Rotation:Orthonormalize(),
			v = Vector3.zero
		},
		d = d,
		f = f,
		p = origo,
		g = goal
	}
end

local function step(spring: Spring, dt: number): CFrame
	local p = Spring_Vector3.step(spring.position, dt)
	local r = rotation_step(spring.rotation, dt)
	local cframe = r + p
	spring.p = cframe
	return cframe
end

local function can_sleep(spring: Spring)
	return Spring_Vector3.can_sleep(spring.position) and rotation_can_sleep(spring.rotation)
end

return {
	create = create,
	step = step,
	can_sleep = can_sleep
}

--!native
--!optimize 2
--!strict

export type Spring = {
	type: "number",
	d: number,
	f: number,
	g: number,
	p: number,
	v: number
}

local EPS = 1e-5 -- epsilon for stability checks around pathological frequency/damping values

local function create(d: number, f: number, origo: number, goal: number): Spring
	return {
		type = "number",
		d = d,
		f = f,
		g = goal,
		p = origo,
		v = 0,
	}
end

local function step(spring: Spring, dt: number): number
	debug.profilebegin("Vector3 Linear Spring")

	local f = spring.f
	local d = spring.d
	local g = spring.g
	local v = spring.v
	local p = spring.p

	if d == 1 then -- critically damped
		local q = math.exp(-f*dt)
		local w = dt*q

		local c0 = q + w*f
		local c2 = q - w*f
		local c3 = w*f*f

		local o = p - g

		p = o*c0+v*w+g
		v = v * c2-o*c3
	elseif d < 1 then -- underdamped
		local q = math.exp(-d*f*dt)
		local c = math.sqrt(1 - d*d)

		local i = math.cos(dt*f*c)
		local j = math.sin(dt*f*c)

		-- Damping ratios approaching 1 can cause division by very small numbers.
		-- To mitigate that, group terms around z=j/c and find an approximation for z.
		-- Start with the definition of z:
		--    z = sin(dt*f*c)/c
		-- Substitute a=dt*f:
		--    z = sin(a*c)/c
		-- Take the Maclaurin expansion of z with respect to c:
		--    z = a - (a^3*c^2)/6 + (a^5*c^4)/120 + O(c^6)
		--    z ≈ a - (a^3*c^2)/6 + (a^5*c^4)/120
		-- Rewrite in Horner form:
		--    z ≈ a + ((a*a)*(c*c)*(c*c)/20 - c*c)*(a*a*a)/6

		local z
		if c > EPS then
			z = j/c
		else
			local a = dt*f
			z = a + ((a*a)*(c*c)*(c*c)/20 - c*c)*(a*a*a)/6
		end

		-- Frequencies approaching 0 present a similar problem.
		-- We want an approximation for y as f approaches 0, where:
		--    y = sin(dt*f*c)/(f*c)
		-- Substitute b=dt*c:
		--    y = sin(b*c)/b
		-- Now reapply the process from z.

		local y
		if f*c > EPS then
			y = j/(f*c)
		else
			local b = f*c
			y = dt + ((dt*dt)*(b*b)*(b*b)/20 - b*b)*(dt*dt*dt)/6
		end

		local o = p - g

		p = o*(i+z*d)+v*y+g
		v = (v*(i-z*d)-o*(z*f))*q

	else -- overdamped
		local c = math.sqrt(d*d - 1)

		local r1 = -f*(d + c)
		local r2 = -f*(d - c)

		local ec1 = math.exp(r1*dt)
		local ec2 = math.exp(r2*dt)

		local o = p - g
		local co2 = (v - o*r1)/(2*f*c)
		local co1 = ec1*(o - co2)
		p = co1 + co2*ec2 + g
		v = co1*r1+co2*ec2*r2
	end

	spring.p = p
	spring.v = v
	debug.profileend()
	return p
end

local SLEEP_OFFSET_SQ_LIMIT = (1/3840)^2 -- square of the offset sleep limit
local SLEEP_VELOCITY_SQ_LIMIT = 1e-2^2 -- square of the velocity sleep limit

local function can_sleep(spring: Spring): boolean
	if spring.v^2 > SLEEP_VELOCITY_SQ_LIMIT then
		return false
	end

	if (spring.p - spring.g)^2 > SLEEP_OFFSET_SQ_LIMIT then
		return false
	end

	return true
end

return {
	create = create,
	step = step,
	can_sleep = can_sleep,
}

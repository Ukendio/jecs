--!native
--!optimize 2
--!strict

local Spring_Vector3 = require("./vector3")

export type Spring = {
	type: "Vector2",
	d: number,
	f: number,
	g: Vector2,
	p: Vector3,
	v: Vector3
}

local EPS = 1e-5 -- epsilon for stability checks around pathological frequency/damping values

local function create(d: number, f: number, origo: Vector2, goal: Vector2): Spring
	return {
		type = "Vector2",
		d = d,
		f = f,
		g = goal,
		p = Vector3.new(origo.X, origo.Y, 0),
		v = Vector3.zero,
	}
end

local function step(spring: Spring, dt: number): Vector3
	debug.profilebegin("Vector2 Linear Spring")

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

		local ox = p.X - g.X
		local oy = p.Y - g.Y

		p = Vector3.new(
			ox*c0+v.X*w+g.X,
			oy*c0+v.Y*w+g.Y
		)
		v = Vector3.new(
			v.X*c2-ox*c3,
			v.Y*c2-oy*c3
		)
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

		local ox = p.X - g.X
		local oy = p.Y - g.Y

		p = Vector3.new(
			(ox*(i + z*d) + v.X*y)*q + g.X,
			(oy*(i + z*d) + v.Y*y)*q + g.Y
		)
		v = Vector3.new(
			(v.X*(i - z*d) - ox*(z*f))*q,
			(v.Y*(i - z*d) - oy*(z*f))*q
		)

	else -- overdamped
		local c = math.sqrt(d*d - 1)

		local r1 = -f*(d + c)
		local r2 = -f*(d - c)

		local ec1 = math.exp(r1*dt)
		local ec2 = math.exp(r2*dt)

		local ox = p.X - g.X
		local oy = p.Y - g.Y

		local co2x = (v.X - ox*r1)/(2*f*c)
		local co2y = (v.Y - oy*r1)/(2*f*c)

		local co1x = ec1*(ox - co2x)
		local co1y = ec1*(oy - co2y)

		p = Vector3.new(
			co1x + co2x*ec2 + g.X,
			co1y + co2y*ec2 + g.Y
		)
		v = Vector3.new(
			co1x*r1 + co2x*ec2*r2,
			co1y*r1 + co2y*ec2*r2
		)
	end

	spring.p = p
	spring.v = v
	debug.profileend()
	return p
end

return {
	create = create,
	step = step,
	can_sleep = Vector3_Spring.can_sleep,
}

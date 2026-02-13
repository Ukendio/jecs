local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

-- Phase 1: Collect raw inputs from Roblox APIs. Here we are using UserInputService but you could use the other APIs.
local rawInput = {
	space = false,
	w = false,
	a = false,
	s = false,
	d = false,
	buttonA = false,
	mouseDelta = Vector2.zero,
	leftThumbstickDelta = Vector2.zero,
	rightThumbstickDelta = Vector2.zero,
}

UserInputService.InputBegan:Connect(function(input, sink)
	if sink then
		return
	end

	if input.KeyCode == Enum.KeyCode.W then
		rawInput.w = true
	elseif input.KeyCode == Enum.KeyCode.A then
		rawInput.a = true
	elseif input.KeyCode == Enum.KeyCode.S then
		rawInput.s = true
	elseif input.KeyCode == Enum.KeyCode.D then
		rawInput.d = true
	elseif input.KeyCode == Enum.KeyCode.Space then
		rawInput.space = true
	elseif input.KeyCode == Enum.KeyCode.ButtonA then
		rawInput.buttonA = true
	end
end)

UserInputService.InputChanged:Connect(function(input, sink)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		rawInput.mouseDelta = Vector2.new(input.Delta.X, -input.Delta.Y)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
		rawInput.leftThumbstickDelta = Vector2.new(input.Position.X, input.Position.Y)
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		rawInput.rightThumbstickDelta = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input, sink)
	if input.KeyCode == Enum.KeyCode.W then
		rawInput.w = false
	elseif input.KeyCode == Enum.KeyCode.A then
		rawInput.a = false
	elseif input.KeyCode == Enum.KeyCode.S then
		rawInput.s = false
	elseif input.KeyCode == Enum.KeyCode.D then
		rawInput.d = false
	elseif input.KeyCode == Enum.KeyCode.Space then
		rawInput.space = false
	elseif input.KeyCode == Enum.KeyCode.ButtonA then
		rawInput.buttonA = false
	end
end)

-- Phase 2: Derive action state from raw inputs.

local SENSITIVITY_MOUSE = Vector2.new(1, 0.77) * math.rad(0.5)
local SENSITIVITY_GAMEPAD = Vector2.new(1, 0.77) * math.rad(4) * 60

local function virtualVector2(up: boolean, down: boolean, left: boolean, right: boolean): Vector2
	local x = 0
	local y = 0
	if up then
		y += 1
	end
	if down then
		y -= 1
	end
	if left then
		x -= 1
	end
	if right then
		x += 1
	end

	return Vector2.new(x, y)
end

local function scaledDeadZone(value: number, lowerThreshold: number): number
	local lowerBound = math.max(math.abs(value) - lowerThreshold, 0)
	local scaledValue = lowerBound / (1 - lowerThreshold)

	return math.min(scaledValue, 1) * math.sign(value)
end

local function radialDeadZone(value: Vector2, threshold: number): Vector2
	local magnitude = value.Magnitude
	if magnitude == 0 then
		return Vector2.zero
	else
		return value.Unit * scaledDeadZone(magnitude, threshold)
	end
end

-- Convert raw inputs into action state. This function will apply modifiers like dead zones or sensitivity multipliers.
local function deriveActionState(deltaTime: number)
	local keyboardMove = virtualVector2(rawInput.w, rawInput.s, rawInput.a, rawInput.d)
	local gamepadMove = radialDeadZone(rawInput.leftThumbstickDelta, 0.2)

	local mouseLook = rawInput.mouseDelta * SENSITIVITY_MOUSE
	local gamepadLook = radialDeadZone(rawInput.rightThumbstickDelta, 0.2)
		* UserGameSettings.GamepadCameraSensitivity
		* SENSITIVITY_GAMEPAD
		* deltaTime

	return {
		boolean = {
			jump = rawInput.space or rawInput.buttonA,
		},
		value2d = {
			move = keyboardMove + gamepadMove,
			look = mouseLook + gamepadLook,
		},
	}
end

-- UserGameSettings.GamepadCameraSensitivity is only updated if this is called.
UserGameSettings:SetGamepadCameraSensitivityVisible()

-- 3. The API
local ACTIONS_BOOLEAN = {
	jump = true,
}

local ACTIONS_2D = {
	move = true,
	look = true,
}

local DEFAULT_PHASE_STATE = {
	boolean = {},
	justPressedCounts = {} :: { [string]: number },
	justReleasedCounts = {} :: { [string]: number },
	value2d = {},
}
for action in ACTIONS_BOOLEAN :: any do
	DEFAULT_PHASE_STATE.boolean[action] = false
end
for action in ACTIONS_2D :: any do
	DEFAULT_PHASE_STATE.value2d[action] = Vector2.zero
end

local function copyDeep<T>(value: T): T
	if typeof(value) == "table" then
		local clone = table.clone(value) :: any

		for key, value in clone do
			clone[key] = copyDeep(value)
		end

		return clone
	else
		return value
	end
end

local lastInputState = deriveActionState(0)
local currentPhase = DEFAULT_PHASE_STATE
local phases = {}

local Input = {}

function Input.justPressed(action: keyof<typeof(ACTIONS_BOOLEAN)>): boolean
	return currentPhase.justPressedCounts[action] ~= nil
end

function Input.justReleased(action: keyof<typeof(ACTIONS_BOOLEAN)>): boolean
	return currentPhase.justReleasedCounts[action] ~= nil
end

function Input.pressed(action: keyof<typeof(ACTIONS_BOOLEAN)>): boolean
	return currentPhase.boolean[action]
end

function Input.released(action: keyof<typeof(ACTIONS_BOOLEAN)>): boolean
	return not currentPhase.boolean[action]
end

function Input.value2d(action: keyof<typeof(ACTIONS_2D)>): Vector2
	return currentPhase.value2d[action]
end

function Input.unit2d(action: keyof<typeof(ACTIONS_2D)>): Vector2
	local value = currentPhase.value2d[action]
	if value.Magnitude > 0 then
		return value.Unit
	end

	return value
end

function Input.clamped2d(action: keyof<typeof(ACTIONS_2D)>): Vector2
	local value = currentPhase.value2d[action]
	if value.Magnitude > 1 then
		return value.Unit
	end

	return value
end

function Input.runPhase(name: string, callback: () -> ())
	if not phases[name] then
		phases[name] = copyDeep(DEFAULT_PHASE_STATE)
	end

	currentPhase = phases[name]

	callback()

	table.clear(currentPhase.justPressedCounts)
	table.clear(currentPhase.justReleasedCounts)

	for action in currentPhase.boolean do
		currentPhase.boolean[action] = false
	end

	for action in currentPhase.value2d do
		currentPhase.value2d[action] = Vector2.zero
	end

	currentPhase = DEFAULT_PHASE_STATE
end

function Input.update(deltaTime: number)
	local inputState = deriveActionState(deltaTime)

	local presses = {}
	local releases = {}
	for action, value in inputState.boolean do
		if value and not lastInputState.boolean[action] then
			table.insert(presses, action)
		elseif not value and lastInputState.boolean[action] then
			table.insert(releases, action)
		end
	end

	for _, phase in phases do
		for _, action in presses do
			phase.justPressedCounts[action] = (phase.justPressedCounts[action] or 0) + 1
		end

		for _, action in releases do
			phase.justReleasedCounts[action] = (phase.justReleasedCounts[action] or 0) + 1
		end

		for action, value in inputState.boolean do
			phase.boolean[action] = phase.boolean[action] or value
		end

		for action, value in inputState.value2d do
			phase.value2d[action] += value
		end
	end

	lastInputState = inputState

	-- Reset the mouse delta.
	rawInput.mouseDelta = Vector2.zero
end

return Input

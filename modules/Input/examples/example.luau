local RunService = game:GetService("RunService")

local Input = require("@modules/Input/module")

local function cameraSystem()
	local look = Input.value2d("look")

	-- rotate camera with look
end

local function characterMovement()
	local move = Input.clamped2d("move")

	-- humanoid:Move(move)

	if Input.justPressed("jump") then
		-- humanoid.Jump = true
	end
end

RunService.RenderStepped:Connect(function(deltaTime)
	Input.update(deltaTime)

	Input.runPhase("RenderStepped", function()
		cameraSystem()
	end)
end)

RunService.PreSimulation:Connect(function(deltaTime)
	Input.update(deltaTime)

	Input.runPhase("PreSimulation", function()
		characterMovement()
	end)
end)

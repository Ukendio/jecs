local ReplicatedStorage = require("@game/ReplicatedStorage")
local RunService = require("@game/RunService")
local UI_Context = require(ReplicatedStorage.UI_Context)
local GetRect = require("@modules/GetRect/module")

RunService.RenderStepped:Connect(function(dt) 
	local pressed, button_state, released = GetRect.button(UI_Context.button.shop)
	
	local my_window = UI_Context.window.shop
	local state = UI_Context.state
	if released then 
		my_window.Visible = not my_window.Visible
		state.pop_effect_t = 0
		state.pop_duration += dt
	end
	
	state.pop_effect_t = GetRect.animate(state.pop_effect_t, my_window.Visible, dt, 10, 8)
	local base = 0.6
	local blend_factor = math.sin(math.pi*2*state.pop_duration * 0.5)
	blend_factor += 1
	blend_factor *= 0.5
	state.pop_factor = 0.6 + state.pop_effect_t * blend_factor
	
	local color3 = my_window.Title.TextColor3
	local r, g, b = color3.R, color3.G, color3.B
	r = math.lerp(r, UI_Context.theme.text_color_pop, state.pop_factor)
	g = math.lerp(g, UI_Context.theme.text_color_pop, state.pop_factor)
	b = math.lerp(b, UI_Context.theme.text_color_pop, state.pop_factor)
	
	my_window.UIScale = state.pop_effect_t
	my_window.Title.TextColor3 = Color3.new(r, g, b)
end)
local state_table = {} :: {[GuiObject]: Active_Widget }
type Active_Widget = {
	last_update_time: number,
	is_on_state_stack: boolean,
	last_getrect_frame: number,
	instance: GuiObject,
	parent: Instance
} 


local function orphan<T>(template: T): T
	 -- NOTE(marcus): Right now this does nothing...
	local instance = template :: Instance
	if instance then 
		return template
	end
	instance.Parent = nil
	return instance:Clone() :: T
end

local function find_or_create_state<T>(rect: GuiObject): (T, boolean)
	local state = state_table[rect]
	if state then 
		return state, false
	end
	
	state = {
		last_getrect_frame = -1,
		last_update_time = -1,
		is_on_state_stack = false,
		instance = orphan(rect) -- NOTE(marcus): In the future we could just as easily treat rect as a theme and then just clone the instance by orphaning it
	} :: Active_Widget
	state_table[rect] = state

	return state, true
end

type Button_State = {
	pressed: boolean?,
	prev: boolean?,
	down: boolean?,
	released: boolean?,
	status: Enum.GuiState,
} & Active_Widget

local function button(rect: GuiObject): (boolean, Button_State, boolean)
	
	local state = find_or_create_state(rect) :: Button_State
	local status = state.instance.GuiState
	state.status = status
	
	local released = false
	local result = false
	
	if state.pressed then 
		if not (status == Enum.GuiState.Press) then 
			released = true
			state.pressed = false
		end
	else
		if status == Enum.GuiState.Press then 
			state.pressed = true
			result = true
		end
	end
	
	if state.pressed then 
		state.status = Enum.GuiState.Hover
	end
	
	return result, state, released
end

local function move_toward(a: number, b: number, amount_increasing: number, amount_decreasing: number?)
	amount_decreasing = amount_decreasing or -1
	if a > b then
		if amount_decreasing == -1 then
			amount_decreasing = amount_increasing
		end
		a -= amount_decreasing
		if a < b then
			a = b
		end
	else
		a += amount_increasing
		if a > b then
			a = b
		end
	end
	return a
end

local function animate(f: number, condition: boolean, dt: number, up_rate: number, down_rate: number)
	if condition then
		return move_toward(f, 1, dt * up_rate)
	else
		return move_toward(f, 0, dt * down_rate)
	end
end

local GetRect = {
	button = button,
	move_toward = move_toward,
	animate = animate,
	orphan = orphan
}

return GetRect
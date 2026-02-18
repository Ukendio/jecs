local Players = game:GetService("Players")
--[[

a utility library to handle checking traffic and determining if the sender is
permitted to send the given data.

]]

local signal = require(script.Parent.signal)

local traffic_check = {}

local whitelist_player_to = {}

local on_fail, fire = signal()

--- A function that needs to be overwritten by the user.
--- This function is used to find out what permissions a user may have.
traffic_check.can_use_jabby = function(player: Player)
	local is_studio = game:GetService("RunService"):IsStudio()

	return is_studio --is_owner or is_studio
end

--- Runs a callback defined by the developer to determine if a player is allowed
--- to use a given function
local function communication_is_allowed(from: "server" | Player, to: "server" | Player, dont_whitelist: boolean?)
	if from == "server" then return true end
	
	whitelist_player_to[from] = whitelist_player_to[from] or {}
	whitelist_player_to[to] = whitelist_player_to[to] or {}

	if traffic_check.can_use_jabby(from) or whitelist_player_to[from][to] then
		if dont_whitelist then return true end
		whitelist_player_to[to][from] = from
		return true
	else
		return false
	end
end

--- Runs the given check and fires the on_fail signal if the player fails the
--- check.
local function check(from: "server" | Player, to: "server" | Player, dont_whitelist: boolean?)
	if communication_is_allowed(from, to, dont_whitelist) then
		return true
	else
		fire(from)
		return false
	end
end

local function check_no_wl(from: "server" | Player)
	if from == "server" then return true end
	if traffic_check.can_use_jabby(from) then
		return true
	else
		-- print(from, "cant use jabby")
		fire(from)
		return false
	end
end

local function _whitelist(from: "server" | Player, to: "server" | Player)
	whitelist_player_to[from] = whitelist_player_to[from] or {}
	whitelist_player_to[to] = whitelist_player_to[to] or {}
	whitelist_player_to[from][to] = from
end

traffic_check.communication_is_allowed = communication_is_allowed
traffic_check.check_no_wl = check_no_wl
traffic_check.check = check

traffic_check._whitelist = _whitelist

traffic_check.on_fail = on_fail

Players.PlayerRemoving:Connect(function(player)
	whitelist_player_to[player] = nil
end)

return traffic_check
--[[
	Creates a UserInputService connection that triggers callback when all
	keys of a macro are being pressed.

	Changelog:
	12/10/23
	- Added types and ClassName
]]

local UserInputService = game:GetService("UserInputService")

local Macro = {}
Macro.__index = Macro
Macro.ClassName = "Macro"

export type Macro = {
	Connect: (self: Macro, callback: () -> ()) -> RBXScriptConnection,
}

function Macro.new(... : Enum.KeyCode): Macro
	local keys = {...}
	assert(typeof(keys) == "table", "Bad keys")
	
	local self = setmetatable({}, Macro)
	self._keys = keys
	
	self._keySet = {}
	for _, key in self._keys do
		self._keySet[key] = true
	end
	
	return self
end

function Macro:Connect(callback: () -> ()): RBXScriptConnection
	assert(typeof(callback) == "function", "Bad callback")
	
	return UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent or input.KeyCode == nil or not self._keySet[input.KeyCode] then
			return
		end
		
		for _, key in self._keys do
			if not UserInputService:IsKeyDown(key) then
				return
			end
		end
	
		callback()
	end)
end

return Macro
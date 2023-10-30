local Maid = require(script.Parent.Maid)

local BaseObject = {}
BaseObject.__index = BaseObject

function BaseObject.new(obj: any)
	local self = setmetatable({},	BaseObject)

	self._obj = obj
	self._maid = Maid.new()

	return self
end

function BaseObject:Destroy()
	self._maid:DoCleaning()
	-- Make it impossible to destroy twice (will cause erro)
	setmetatable(self, nil)
end

return BaseObject
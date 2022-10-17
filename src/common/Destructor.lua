-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local Destructor = {}
Destructor.__index = Destructor

local finalizers = setmetatable({
	["function"] = function(item)
		return item()
	end,
	["Instance"] = game.Destroy,
	["table"] = function(item) item:Destroy() end,
	["RBXScriptConnection"] = function(connection) connection:Disconnect() end,
}, {
	__index = function(self, className)
		error(("Cannot destruct item of type '%s' (no finalizer is defined)"):format(className), 3)
	end
})

function Destructor.new()
	return setmetatable({}, Destructor)
end

function Destructor:Add(item)
	self[item] = finalizers[typeof(item)]
	return item
end

function Destructor:Destroy()
	for item, finalizer in pairs(self) do
		finalizer(item)
	end
	table.clear(self)
end

return Destructor
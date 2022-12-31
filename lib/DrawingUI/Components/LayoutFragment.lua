-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Imports
local root = script.Parent.Parent.Parent
local Roact: Roact = require(root.Parent.Roact)
local e = Roact.createElement

--[[
	Converts this:
	{ {"keyA", fA}, {"keyB", fB}, ... }
	to this:
	{
		["keyA"] = fA(1),
		["keyB"] = fB(2),
		...
	}

	Use case: the f's can be functions which assign to the LayoutOrder prop of
	a component. Then the elements of the input array can be permuted to
	automatically permute their LayoutOrders.

--]]
return function(props)
	local orderedLayoutElements = props.OrderedLayoutElements
	local elements = {}

	for i, layoutElement in ipairs(orderedLayoutElements) do
		elements[layoutElement[1]] = layoutElement[2](i)
	end
	
	return Roact.createFragment(elements)
end
-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)
	local orderedLayoutElements = props.OrderedLayoutElements
	local elements = {}

	for i, layoutElement in ipairs(orderedLayoutElements) do
		elements[layoutElement[1]] = layoutElement[2](i)
	end
	
	return Roact.createFragment(elements)
end
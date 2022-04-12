-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

return function(props)
  local namedComponents = props.NamedComponents
  local elements = {}

  for i, namedComp in ipairs(namedComponents) do
    elements[namedComp[1]] = e(namedComp[2], {LayoutOrder = i})
  end
  return Roact.createFragment(elements)
end
return function(target)
  local Roact = require(game:GetService("ReplicatedStorage").MetaBoardCommon.Packages.Roact)
  local e = Roact.createElement

  local ColorButton = require(script.Parent.ColorButton)

  local comp = Roact.Component:extend("comp")

  function comp:init()
    self:setState({
      Selected = false,
    })
  end

  function comp:render()
    local selected = self.state.Selected

    return e(ColorButton, {
      Color = Color3.new(0,0,1),
      Selected = selected,
      Size = UDim2.fromOffset(50,50),
      OnClick = function()
        self:setState({
          Selected = not self.state.Selected,
        })
      end
    })
  end

  local handle = Roact.mount(e(comp, {}), target)

  return function()
    Roact.unmount(handle)
  end
end
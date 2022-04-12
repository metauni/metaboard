return function(target)
  local Roact = require(game:GetService("ReplicatedStorage").MetaBoardCommon.Packages.Roact)
  local e = Roact.createElement

  local strokeButton = require(script.Parent.StrokeButton)

  local comp = Roact.Component:extend("comp")

  function comp:init()
    self:setState({
      Selected = false,
    })
  end

  function comp:render()
    
    local stroke = {
      ThicknessPixels = 10,
      ShadedColor = {
        BaseName = "Red",
        Color = Color3.new(1,0,0),
        BaseColor = Color3.new(1,0,0),
      }
    }

    return e(strokeButton, {
      Stroke = stroke,
      Size = UDim2.fromOffset(50,50),
      LayoutOrder = 1,
      Selected = self.state.Selected,
      OnClick = function()
        self:setState({
          selected = true,
        })
      end
    })
  end

  local handle = Roact.mount(e(comp), target)

  return function()
    Roact.unmount(handle)
  end
end
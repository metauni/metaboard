return function(target)
  local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
  local Roact = require(Common.Packages.Roact)
  local e = Roact.createElement

  local Slider = require(script.Parent.Slider)

  local Llama = require(Common.Packages.Llama)
  local Dictionary = Llama.Dictionary

  local comp = Roact.Component:extend("comp")

  function comp:init()
    self:setState({
      SliderState = Roact.None,
      Alpha = 0,
    })
  end

  function comp:render()

    local alpha = self.state.Alpha

    return e(Slider, {
      -- Size = UDim2.fromOffset(200,50),
      -- RailThicknessOffset = 10,
      -- KnobSizeOffset = 20,
      KnobLabelText = tostring(math.round(100*alpha)),
      KnobAlpha = alpha,
      OnKnobPositionUpdate = function(newAlpha)
        self:setState({
          Alpha = newAlpha,
        })
      end,
      State = self.state.SliderState,
      SetState = function(state)
        self:setState({
          SliderState = Dictionary.merge(self.state.SliderState or {}, state)
        })
      end
    })
  end

  local handle = Roact.mount(e(comp, {}), target)

  return function()
    Roact.unmount(handle)
  end
end
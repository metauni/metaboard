-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local StarterGui = game:GetService("StarterGui")

-- Imports
local Roact = require(Common.Packages.Roact)
local e = Roact.createElement

local Pen = require(Common.DrawingTool.Pen)
local Eraser = require(Common.DrawingTool.Eraser)
local StraightEdge = require(Common.DrawingTool.StraightEdge)
local Config = require(Common.Config)
local Assets = require(Common.Assets)
local Llama = require(Common.Packages.Llama)
local Dictionary = Llama.Dictionary




-- Components
local Components = script.Parent.Components
local CanvasViewport = require(Components.CanvasViewport)
local Palette = require(Components.Palette)
local StrokeButton = require(Components.StrokeButton)
local CloseButton = require(Components.CloseButton)
local UndoRedoButton = require(Components.UndoRedoButton)
local EraserChoices = require(Components.EraserChoices)
local ShadedColorSubMenu = require(Components.ShadedColorSubMenu)
local StrokeWidthSubMenu = require(Components.StrokeWidthSubMenu)
local ToolMenu = require(Components.ToolMenu)
local LayoutFragment = require(Components.LayoutFragment)
local Cursor = require(Components.Cursor)


local App = Roact.Component:extend("App")
App.defaultProps = {
  IgnoreGuiInset = true,
  CanvasRegionPosition = UDim2.new(0, 50 , 0, 150),
  CanvasRegionSize = UDim2.new(1,-100,1,-200),

  ToolMenuSize = UDim2.new(0, 260, 0, 80),
  ToolConfigSize = UDim2.new(0, 360, 0, 80),
  UndoRedoSize = UDim2.new(0,180, 0, 80),

  InitialToolState = {
    EraserSizeName = "Small",
    StrokeWidths = {
      Small = Config.Drawing.Defaults.SmallStrokeWidth,
      Medium = Config.Drawing.Defaults.MediumStrokeWidth,
      Large = Config.Drawing.Defaults.LargeStrokeWidth,
    },
    SelectedStrokeWidthName = "Small",
    ColorWells = {
      {
        BaseName = "White",
        BaseColor = Color3.fromHex("FCFCFC"),
        Color = Color3.fromHex("FCFCFC"),
      },
      {
        BaseName = "Black",
        BaseColor = Color3.fromHex("000000"),
        Color = Color3.fromHex("000000"),
      },
      {
        BaseName = "Blue",
        BaseColor = Color3.fromHex("007AFF"),
        Color = Color3.fromHex("007AFF"),
      },
      {
        BaseName = "Green",
        BaseColor = Color3.fromHex("7EC636"),
        Color = Color3.fromHex("7EC636"),
      },
      {
        BaseName = "Red",
        BaseColor = Color3.fromHex("D20000"),
        Color = Color3.fromHex("D20000"),
      },
    },
    SelectedColorWellIndex = 1,
  },

  ButtonDimOffset = 80,
  ToolbarHeightOffset = 80,
  ToolbarPosition = UDim2.new(0.5, 0, 0, 60),
  PaletteSpacing = UDim.new(0,10),
  ToolbarSpacing = UDim.new(0,20),
}

function App:didMount()
  self._uisConnection = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
      or input.UserInputType == Enum.UserInputType.Touch
    then
      self:ToolLift()
    end
  end)

  local board = self.props.Board
  self._historyChangedConnection = board.LocalHistoryChangedSignal:Connect(function(canUndo, canRedo)
    self:setState({
      CanUndo = canUndo,
      CanRedo = canRedo,
    })
  end)

	StarterGui:SetCoreGuiEnabled("All", false)
	StarterGui:SetCoreGuiEnabled("Chat", true)
end

function App:willUnmount()
  self._uisConnection:Disconnect()
  self._historyChangedConnection:Disconnect()
  StarterGui:SetCoreGuiEnabled("All", true)
end

function App:init()
  local initialToolState = self.props.InitialToolState
  local board = self.props.Board
  local history = board.PlayerHistory[Players.LocalPlayer]

  self:setState(Dictionary.merge(initialToolState, {
    ToolHeld = false,
    CanUndo = history and history:CountPast() > 0,
    CanRedo = history and history:CountFuture() > 0,
    SubMenu = Roact.None,
    EquippedToolName = "Pen",
  }))

  self.canvasButtonRef = Roact.createRef()

  
end

function App:render()

  return e("ScreenGui", {
    DisplayOrder = 1,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = true,
    [Roact.Children] = {
      Toolbar = self:renderToolbar(),
      CanvasUI = self:renderCanvas(),
      Cursor = self.state.ToolPos and self.state.SubMenu == nil and self:renderCursor() or nil
    }
  })
end

function App:renderCursor()
  local toolPos = self.state.ToolPos

  local cursorWidth, cursorColor do
    if self.state.EquippedToolName == "Eraser" then
      cursorWidth = Eraser.new(self.state.EraserSizeName).Width
      cursorColor = Config.UITheme.Highlight
    else
      cursorWidth = self.state.StrokeWidths[self.state.SelectedStrokeWidthName]
      cursorColor = self.state.ColorWells[self.state.SelectedColorWellIndex].Color
    end
  end

  return e(Cursor, {
    Size = UDim2.fromOffset(cursorWidth, cursorWidth),
    Position = UDim2.fromOffset(self.state.ToolPos.X, self.state.ToolPos.Y),
    Color = cursorColor
  })
end

function App:renderCanvas()
  local ignoreGuiInset = self.props.IgnoreGuiInset
  local fov = self.props.FieldOfView
  local canvasSizeStuds = self.props.CanvasSizeStuds
  local canvasCFrame = self.props.CanvasCFrame
  local canvasRegionPosition = self.props.CanvasRegionPosition
  local canvasRegionSize = self.props.CanvasRegionSize
  local mountBoard = self.props.MountBoard
  local unmountBoard = self.props.UnmountBoard

  local canvasButton = e("TextButton", {
    Text = "",
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = UDim2.fromScale(0.5,0.5),
    Size = UDim2.fromScale(1,1),
    BackgroundTransparency = 1,
    [Roact.Ref] = self.canvasButtonRef,
    [Roact.Event.MouseButton1Down] = function(...)
      self:ToolDown(...)
    end,
    [Roact.Event.MouseMoved] = function(rbx, x, y)
      self:setState({
        ToolPos = Vector2.new(x, y)
      })
      self:ToolMoved(rbx, x, y)
    end,
    [Roact.Event.MouseLeave] = function(...)
      self:setState({
        ToolPos = Roact.None
      })
      self:ToolLift()
    end,
    [Roact.Event.MouseButton1Up] = function(...)
      self:ToolLift()
    end,
    [Roact.Children] = {
      UIAspectRatioConstraint = e("UIAspectRatioConstraint", {
        AspectType = Enum.AspectType.FitWithinMaxSize,
        AspectRatio = canvasSizeStuds.X / canvasSizeStuds.Y
      })
    }
  })

  local regionFrame = e("Frame", {
    Position = canvasRegionPosition,
    Size = canvasRegionSize,
    BackgroundTransparency = 1,
    ZIndex = 1,
    [Roact.Children] = {
      canvasButton = canvasButton
    }
  })

  local canvasViewport = e(CanvasViewport, {
    CanvasButtonRef = self.canvasButtonRef,
    ZIndex = 0,
    FieldOfView = fov,
    CanvasHeightStuds = canvasSizeStuds.Y,
    CanvasCFrame = canvasCFrame,
    MountBoard = mountBoard,
    UnmountBoard = unmountBoard,
  })

  return e("ScreenGui", {
    IgnoreGuiInset = ignoreGuiInset,
    DisplayOrder = 0,
    [Roact.Children] = {
      RegionFrame = regionFrame,
      CanvasViewport = canvasViewport
    }
  })
end

function App:ToYScalePos(canvasRbx, x, y)
  local ignoreGuiInset = self.props.IgnoreGuiInset
  local canvasPixelPosition = (canvasRbx.AbsolutePosition + (ignoreGuiInset and Vector2.new(0,36) or Vector2.new(0,0)))
  return (Vector2.new(x,y) - canvasPixelPosition) / canvasRbx.AbsoluteSize.Y
end

function App:ToolDown(canvasRbx, x, y)

  local equippedToolName = self.state.EquippedToolName
  local board = self.props.Board

  local equippedTool do
    if equippedToolName == "Pen" then
      equippedTool = Pen.new({
        Width = math.round(self.state.StrokeWidths[self.state.SelectedStrokeWidthName]),
        ShadedColor = self.state.ColorWells[self.state.SelectedColorWellIndex]
      })
    elseif equippedToolName == "StraightEdge" then
      equippedTool = StraightEdge.new({
        Width = math.round(self.state.StrokeWidths[self.state.SelectedStrokeWidthName]),
        ShadedColor = self.state.ColorWells[self.state.SelectedColorWellIndex]
      })
    else
      equippedTool = Eraser.new(self.state.EraserSizeName)
    end

  end
  -- if not DrawingUI._withinBounds(x, y, DrawingUI.ToolState.Equipped.ThicknessPixels) then return end

  -- -- If the board is persistent and full, no new drawing tasks can be
  -- -- initiated by interacting with the board, but you can finish the
  -- -- current task in progress (i.e. we allow ToolMoved, ToolLift)
  -- if board.PersistId and board.IsFull then return end

  -- drawingUI._updateCursor(drawingUI._cursor, drawingUI.ToolState.Equipped, x, y)
  -- drawingUI._cursor.Visible = true

  local drawingTask = equippedTool:NewDrawingTask(board, canvasRbx.AbsoluteSize.Y)

  self:setState({
    ToolPixelPos = Vector2.new(x,y),
    ToolHeld = true,
    DrawingTask = drawingTask,
    SubMenu = Roact.None
  })

  board:ToolDown(drawingTask, self:ToYScalePos(canvasRbx, x, y))
end

function App:ToolMoved(canvasRbx, x, y)
  local toolHeld = self.state.ToolHeld
  local drawingTask = self.state.DrawingTask
  local board = self.props.Board

  if toolHeld then
    if drawingTask == nil then
      print("Why did this happen? Investigate pls")
      self:setState({
        ToolHeld = false,
      })
    end

    -- if not drawingUI._withinBounds(x, y, drawingUI.ToolState.Equipped.ThicknessPixels) then return end

    -- -- Simple palm rejection
    -- if UserInputService.TouchEnabled then
    --   local diff = Vector2.new(x,y) - drawingUI.MousePixelPos
    --   if diff.Magnitude > Config.Drawing.MaxLineLengthTouch then return end
    -- end

    board:ToolMoved(drawingTask, self:ToYScalePos(canvasRbx, x, y))
  end

  self:setState({
    ToolPixelPos = Vector2.new(x,y),
  })

  -- drawingUI._updateCursor(drawingUI._cursor, drawingUI.ToolState.Equipped, x, y)
end

function App:ToolLift()
  local toolHeld = self.state.ToolHeld
  local drawingTask = self.state.DrawingTask

  local board = self.props.Board

  if toolHeld then
    if drawingTask == nil then
      print("Why did this happen? Investigate pls")
      self:setState({
        ToolHeld = false,
      })
      return
    end
    board:ToolLift(drawingTask)

    self:setState({
      ToolHeld = false,
      DrawingTask = Roact.None,
    })
  end
end





function App:renderToolbar()
  local buttonDimOffset = self.props.ButtonDimOffset
  local buttonSize = UDim2.fromOffset(buttonDimOffset, buttonDimOffset)
  local toolbarHeightOffset = self.props.ToolbarHeightOffset
  local toolbarPosition = self.props.ToolbarPosition
  local toolbarSpacing = self.props.ToolbarSpacing
  local toolMenuSize = self.props.ToolMenuSize
  local toolConfigSize = self.props.ToolConfigSize
  local undoRedoSize = self.props.UndoRedoSize
  local board = self.props.Board

  local toolMenu = function(props)
    return e(ToolMenu, {
      LayoutOrder = props.LayoutOrder,
      Size = toolMenuSize,
      EquippedToolName = self.state.EquippedToolName,
      EquipTool = function(toolName)
        self:setState({
          EquippedToolName = toolName,
          SubMenu = Roact.None,
        })
      end
    })
  end

  local toolConfig = function(props)
    local hasStroke = self.state.EquippedToolName ~= "Eraser"

    if hasStroke then
      return e(self:strokeMenu(), {
        LayoutOrder = props.LayoutOrder,
      })
    else

      return e(EraserChoices,{
        Height = UDim.new(0, buttonDimOffset),
        Size = toolConfigSize,
        LayoutOrder = props.LayoutOrder,
        OnSmallClick = function()
          self:setState({
            EraserSizeName = "Small",
            SubMenu = Roact.None,
          })
        end,
        OnMediumClick = function()
          self:setState({
            EraserSizeName = "Medium",
            SubMenu = Roact.None,
          })
        end,
        OnLargeClick = function()
          self:setState({
            EraserSizeName = "Large",
            SubMenu = Roact.None,
          })
        end,
        SelectedEraserSizeName = self.state.EraserSizeName
      })
    end
  end



  local historyButtons = function(props)
    local undoButton = e(UndoRedoButton, {
        Size = UDim2.fromOffset(80,80),
        LayoutOrder = 1,
        Icon = Assets.undo,
        OnClick = self.state.CanUndo and function()
          board.Remotes.Undo:FireServer()
          self:setState({
            SubMenu = Roact.None
          })
        end or nil,
        Clickable = self.state.CanUndo
      })

    local redoButton = e(UndoRedoButton, {
        Size = UDim2.fromOffset(80,80),
        Icon = Assets.redo,
        LayoutOrder = 2,
        OnClick = self.state.CanRedo and function()
          board.Remotes.Redo:FireServer()
          self:setState({
            SubMenu = Roact.None
          })
        end or nil,
        Clickable = self.state.CanRedo
      })

    return e("Frame", {
      BackgroundTransparency = 1,
      Size = undoRedoSize,
      LayoutOrder = props.LayoutOrder,

      [Roact.Children] = {
        UIListLayout = e("UIListLayout", {
          Padding = UDim.new(0,0),
          FillDirection = Enum.FillDirection.Horizontal,
          HorizontalAlignment = Enum.HorizontalAlignment.Center,
          VerticalAlignment = Enum.VerticalAlignment.Center,
          SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        Undo = undoButton,
        Redo = redoButton,
      }
    })
  end


  local divider = function(props)
    return e("Frame", {
     Size = UDim2.fromOffset(3, 50),
     BackgroundColor3 = Config.UITheme.Highlight,
     BackgroundTransparency = 0.5,
     BorderSizePixel = 0,
     LayoutOrder = props.LayoutOrder,
   })
  end

  local toolbarLength = toolMenuSize.X.Offset + toolConfigSize.X.Offset + undoRedoSize.X.Offset + 6

  local mainToolbar = e("Frame", {
    LayoutOrder = 1,
    Size = UDim2.fromScale(1,1),
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = UDim2.fromScale(0.5,0.5),
    BackgroundTransparency = 0,
    BackgroundColor3 = Config.UITheme.Background,
    BorderSizePixel = 0,

    [Roact.Children] = {
      UICorner = e("UICorner", { CornerRadius = UDim.new(0,5) }),

      UIListLayout = e("UIListLayout", {
        Padding = UDim.new(0,0),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
      }),

      LayoutFragment = e(LayoutFragment, {
        NamedComponents = {
          {"ToolMenu", toolMenu},
          {"ToolConfigLeftDivider", divider},
          {"ToolConfig", toolConfig},
          {"ToolConfigRightDivider", divider},
          {"HistoryButtons", historyButtons},
        }
      }),
    }
  })

  return e("Frame", {
    Size = UDim2.new(UDim.new(0,toolbarLength), UDim.new(0,toolbarHeightOffset)),
    AnchorPoint = Vector2.new(0.5,0.5),
    Position = toolbarPosition,
    BackgroundTransparency = 1,

    [Roact.Children] = {
      MainToolbar = mainToolbar,
      CloseButton = e(CloseButton, {
        OnClick = self.props.OnClose,
        Size = UDim2.fromOffset(55,55),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(1, 25, 0.5, 0)
      }),
    }
  })

end

function App:ToolbarLength()
  local toolMenuSize = self.props.ToolMenuSize
  local toolConfigSize = self.props.ToolConfigSize
  local buttonDimOffset = self.props.ButtonDimOffset

  return toolMenuSize.X.Offset + toolConfigSize.X.Offset + 2 * buttonDimOffset + 6
end

function App:strokeMenu()
  local buttonDimOffset = self.props.ButtonDimOffset
  local buttonSize = UDim2.fromOffset(buttonDimOffset, buttonDimOffset)
  local paletteSpacing = self.props.PaletteSpacing
  local toolbarHeightOffset = self.props.ToolbarHeightOffset
  local toolbarSpacing = self.props.ToolbarSpacing
  local toolConfigSize = self.props.ToolConfigSize


  local shadedColorSubMenu = e(ShadedColorSubMenu, {
    AnchorPoint = Vector2.new(0.5,0),
    Position = UDim2.new(0.5, 0, 0, 80),
    SelectedShadedColor = self.state.ColorWells[self.state.SelectedColorWellIndex],
    OnShadedColorSelect = function(shadedColor)
      self:setState({
        ColorWells = Dictionary.merge(self.state.ColorWells, {
          [self.state.SelectedColorWellIndex] = shadedColor
        })
      })
    end,
  })

  local palette = function(props)
    return e(Palette, {
      Height = UDim.new(0, buttonDimOffset),
      ButtonDim = UDim.new(0,buttonDimOffset),
      LayoutOrder = props.LayoutOrder,
      ColorWells = self.state.ColorWells,
      SelectedColorWellIndex = self.state.SelectedColorWellIndex,
      OnColorWellClick = function(index)
        local subMenu = self.state.SubMenu
        if index == self.state.SelectedColorWellIndex then
          self:setState({
            SubMenu = "ShadedColor"
          })
        else
          if subMenu ~= nil and subMenu ~= "ShadedColor" then
            self:setState({
              SubMenu = Roact.None
            })
          end

          self:setState({
            SelectedColorWellIndex = index
          })
        end
      end,
      SubMenu = self.state.SubMenu == "ShadedColor" and shadedColorSubMenu or nil,
    })
  end

  local strokeWidthSubMenu = e(StrokeWidthSubMenu, {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 90),
    StrokeWidths = self.state.StrokeWidths,
    SelectedStrokeWidthName = self.state.SelectedStrokeWidthName,
    SelectStrokeWidth = function(strokeWidthName)
      self:setState({
        SelectedStrokeWidthName = strokeWidthName
      })
    end,
    UpdateStrokeWidth = function(strokeWidth)
      self:setState({
        StrokeWidths = Dictionary.merge(self.state.StrokeWidths,{
          [self.state.SelectedStrokeWidthName] = strokeWidth
        })
      })
    end,
    Color = self.state.ColorWells[self.state.SelectedColorWellIndex].Color,
    SliderState = self.state.StrokeWidthSliderState,
    SetSliderState = function(state)
      self:setState({
        StrokeWidthSliderState = Dictionary.merge(self.state.StrokeWidthSliderState or {}, state)
      })
    end
  })

  local strokeButton = function(props)
    return e(StrokeButton, {
      Size = buttonSize,
      Width = self.state.StrokeWidths[self.state.SelectedStrokeWidthName],
      Color = self.state.ColorWells[self.state.SelectedColorWellIndex].Color,
      LayoutOrder = props.LayoutOrder,
      OnClick = function()
        self:setState({
          SubMenu = "StrokeWidth"
        })
      end,
      SubMenu = self.state.SubMenu == "StrokeWidth" and strokeWidthSubMenu or nil
    })
  end

  return function(props)
    return e("Frame", {
      Size = toolConfigSize,
      AnchorPoint = Vector2.new(0.5,0.5),
      Position = UDim2.fromScale(0.5,0.5),
      BackgroundTransparency = 1,
      LayoutOrder = props.LayoutOrder,

      [Roact.Children] = {

        UIListLayout = e("UIListLayout", {
          Padding = UDim.new(0,0),
          FillDirection = Enum.FillDirection.Horizontal,
          HorizontalAlignment = Enum.HorizontalAlignment.Center,
          VerticalAlignment = Enum.VerticalAlignment.Center,
          SortOrder = Enum.SortOrder.LayoutOrder,
        }),

        LayoutFragment = e(LayoutFragment, {
          NamedComponents = {
            {"StrokeButton", strokeButton},
            {"Palette", palette}
          }
        }),
      }
    })
  end

end


return App
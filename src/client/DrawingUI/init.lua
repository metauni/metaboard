-- Services
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

-- Imports
local Roact = require(Common.Packages.Roact)
local App = require(script.App)

local function open(board, onClose)
  local handle
  handle = Roact.mount(Roact.createElement(App, {
    CanvasCFrame = board.Canvas:GetCFrame(),
    CanvasSizeStuds = board.Canvas:Size(),
    FieldOfView = workspace.CurrentCamera.FieldOfView,
    MountBoard = function(vpfInstance)
      board.Canvas._instance.Parent = vpfInstance
      board._instanceClone = board._instance:Clone()
      board._instanceClone.Parent = vpfInstance

      board._provisionalCanvas._instance.Parent = vpfInstance
    end,
    UnmountBoard = function()
      board.Canvas._instance.Parent = board._instance
      board._instanceClone:Destroy()
      -- make sure no more provisionalJobQueue stuff happens after this
    end,
    Board = board,
    OnClose = function()
      Roact.unmount(handle)
      onClose()
    end,
  }), Players.LocalPlayer.PlayerGui, "DrawingUI")
end

return {
  Open = open
}

local Players = game:GetService("Players")
local BoardGui = Players.LocalPlayer.PlayerGui:WaitForChild("BoardGui")
local CursorsGui = Players.LocalPlayer.PlayerGui:WaitForChild("CursorsGui")

local CanvasState = require(script.Parent.CanvasState)
local Buttons = require(script.Parent.Buttons)
local Drawing = require(script.Parent.Drawing)
local ClientDrawingTasks = require(script.Parent.ClientDrawingTasks)
local PersonalBoardTool = require(script.Parent.PersonalBoardTool)

CanvasState.Init(BoardGui, CursorsGui)
Drawing.Init(BoardGui)
Buttons.Init(BoardGui.Toolbar)
ClientDrawingTasks.Init(BoardGui.Curves)

local localCharacter = Players.LocalPlayer.Character

if localCharacter then
	PersonalBoardTool.Init(localCharacter)
end

Players.LocalPlayer.CharacterAdded:Connect(function(character)
	PersonalBoardTool.Init(character)
end)
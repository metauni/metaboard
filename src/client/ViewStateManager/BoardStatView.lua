-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon

-- Imports
local Config = require(Common.Config)
local Roact: Roact = require(Common.Packages.Roact)
local e = Roact.createElement
local Sift = require(Common.Packages.Sift)
local Array, Set, Dictionary = Sift.Array, Sift.Set, Sift.Dictionary
local DrawingTask = require(Common.DrawingTask)


local FORMAT = [[Total Lines: %d
Figures: %d
Drawing Tasks: %d
  - FreeHand: %d
  - StraightLine: %d
  - Erase: %d
Unverified Drawing Tasks: %d
NextFigureZIndex: %d]]

local function compute(props)
	local lineCount = 0

	for figureId, figure in pairs(props.Figures) do
		if figure.Type == "Curve" then
			lineCount += #figure.Points-1
		else
			lineCount += 1
		end
	end

	for taskId, drawingTask in pairs(props.UnverifiedDrawingTasks) do

		if drawingTask.Type == "Erase" then
			local figureIdToFigureMask = DrawingTask.Render(drawingTask)
			for figureId, figureMask in pairs(figureIdToFigureMask) do
				if type(figureMask) == "table" then
					lineCount -= Dictionary.count(figureMask)
				end
			end
		else
			local figure = DrawingTask.Render(drawingTask)

				if figure.Type == "Curve" then
					lineCount += #figure.Points-1
				else
					lineCount += 1
				end
		end
	end

	for taskId, drawingTask in pairs(props.DrawingTasks) do

		if props.UnverifiedDrawingTasks[taskId] then
			continue
		end

		if drawingTask.Type == "Erase" then
			local figureIdToFigureMask = DrawingTask.Render(drawingTask)
			for figureId, figureMask in pairs(figureIdToFigureMask) do
				if type(figureMask) == "table" then
					lineCount -= Dictionary.count(figureMask)
				elseif figureMask then
					lineCount -= 1
				end
			end
		else
			local figure = DrawingTask.Render(drawingTask)

				if figure.Type == "Curve" then
					lineCount += #figure.Points-1
				else
					lineCount += 1
				end
		end
	end

	return lineCount
end

return function(props)

	local textLabel = e("TextLabel", {

		Text = string.format(FORMAT,
			compute(props),
			Dictionary.count(props.Figures),
			Dictionary.count(props.DrawingTasks),
			Dictionary.count(props.DrawingTasks, function(drawingTask)
				return drawingTask.Type == "FreeHand"
			end),
			Dictionary.count(props.DrawingTasks, function(drawingTask)
				return drawingTask.Type == "StraightLine"
			end),
			Dictionary.count(props.DrawingTasks, function(drawingTask)
				return drawingTask.Type == "Erase"
			end),
			Dictionary.count(props.UnverifiedDrawingTasks),
			props.Board.NextFigureZIndex
		),

		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.new(1,1,1),

		Size = UDim2.fromScale(1,1),

		BackgroundColor3 = Color3.new(0,0,0),
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,


	})

	return e("BillboardGui", {

		Adornee = props.Board._surfacePart,

		Size = UDim2.fromOffset(200,100),

		AlwaysOnTop = true,

		[Roact.Children] = {
			TextLabel = textLabel,
		}

	})

end
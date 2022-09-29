-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

-- Services
local Common = game:GetService("ReplicatedStorage").metaboardCommon
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")

-- Imports
local Config = require(Common.Config)
local BoardClient = require(script.BoardClient)
local BoardService = require(Common.BoardService)
local Assets = require(Common.Assets)
local ViewStateManager = require(script.ViewStateManager)
local Roact: Roact = require(Common.Packages.Roact)

--[[
	We use a fork of Roact so that Instances can have customised default
	properties, without blowing up the size of large roact trees.
--]]
Roact.setGlobalConfig({
	defaultHostProps = {
		["Part"] = {
			Material = Enum.Material.SmoothPlastic,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Anchored = true,
			CanCollide = false,
			CastShadow = false,
			CanTouch = false, -- Do not trigger Touch events
			CanQuery = false, -- Does not take part in e.g. GetPartsInPart
		},
	},
})

--------------------------------------------------------------------------------

--[[
	Preload all of the assets (so that they are shown immediately when needed)
	TODO: this doesn't work and seems to be a known bug.
	Explore subtle workarounds?
	Like showing the assets on screen at 95% transparency and very small?
--]]
do
	local assetList = {}
	for _, asset in pairs(Assets) do
		table.insert(assetList, asset)
	end

	task.spawn(function()
		ContentProvider:PreloadAsync(assetList)
	end)
end

--------------------------------------------------------------------------------

local function bindInstanceAsync(instance)

	if not instance:IsDescendantOf(workspace) then
		
		return
	end

	-- Ignore if already seen this board
	if BoardService.Boards[instance] then
		return
	end

	if not instance:GetAttribute("BoardServerInitialised") then
		
		instance:GetAttributeChangedSignal("BoardServerInitialised"):Wait()
	end

	local board = BoardClient.new(instance)
	
	local data = board.Remotes.GetBoardData:InvokeServer()
	
	board:ConnectRemotes()

	board:LoadData(data)

	BoardService.Boards[instance] = board
end

for _, instance in ipairs(CollectionService:GetTagged(Config.BoardTag)) do
	
	task.spawn(bindInstanceAsync, instance)
end

CollectionService:GetInstanceAddedSignal(Config.BoardTag):Connect(bindInstanceAsync)

-- TODO: Think about GetInstanceRemovedSignal (destroying metaboards)

--------------------------------------------------------------------------------

local viewStateManager = ViewStateManager.new()

task.spawn(function()
	while true do

		viewStateManager:UpdateWithAllActive(BoardService.Boards)
		task.wait(0.5)
	end
end)

-- Services
local CollectionService = game:GetService("CollectionService")

-- Imports
local Common = require(script.Parent)
local Config = require(Common.Config)
local Canvas = require(Common.Canvas)
local BoardRemotes = require(Common.BoardRemotes)

-- Board
local Board = {}
Board.__index = Board

function Board.new(instance: Model | Part, boardRemotes, canvas)
	local self = setmetatable({
		_instance = instance,
		Remotes = boardRemotes,
		PlayerHistory = {},
		Queue = {},
		Canvas = canvas,
	}, Board)

	return self
end

return Board

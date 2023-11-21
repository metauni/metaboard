-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local DrawingTask = require(script.DrawingTask)
local PartCanvas = require(script.PartCanvas)
local FrameCanvas = require(script.FrameCanvas)
local Config = require(script.Config)
local BoardState = require(script.BoardState)
local BoardUtils = require(script.BoardUtils)
local Persistence = require(script.Persistence)
local Figure = require(script.Figure)
local Server = require(script.Server)
local Client = require(script.Client)
local Remotes = script.Remotes

local BoardServer = require(script.Server.BoardServer)
local BoardClient = require(script.Client.BoardClient)

export type DrawingTask = DrawingTask.DrawingTask
export type BoardState = BoardState.BoardState
export type DrawingTaskDict = BoardState.DrawingTaskDict
export type FigureDict = BoardState.FigureDict
export type FigureMaskDict = BoardState.FigureMaskDict
export type AnyFigure = Figure.AnyFigure
export type Curve = Figure.Curve
export type Line = Figure.Line
export type AnyMask = Figure.AnyMask
export type CurveMask = Figure.CurveMask
export type LineMask = Figure.LineMask
export type BoardServer = BoardServer.BoardServer
export type BoardClient = BoardClient.BoardClient

return {
	DrawingTask = DrawingTask,
	PartCanvas = PartCanvas,
	FrameCanvas = FrameCanvas,
	Config = Config,
	BoardState = BoardState,
	BoardUtils = BoardUtils,
	Persistence = Persistence,
	Figure = Figure,
	Server = Server,
	Client = Client,
	Remotes = Remotes,
}
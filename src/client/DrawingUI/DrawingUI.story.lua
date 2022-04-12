local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local BoardClient = require(script.Parent.Parent.BoardClient)
local PartCanvas = require(Common.Canvas.PartCanvas)
local BoardRemotes = require(Common.BoardRemotes)

local boardInstance = Common.Boards.BlackBoardMini:Clone()

return function(target)
  local Roact = require(Common.Packages.Roact)

  Roact.setGlobalConfig({
    elementTracing = true
})

  local DrawingUI = require(script.Parent)

  local board = BoardClient.new(boardInstance, BoardRemotes.new(boardInstance))

	local canvas = PartCanvas.new(board)
	board:SetCanvas(canvas)
	canvas._instance.Parent = board._instance

  local handle
  handle = Roact.mount(Roact.createElement(DrawingUI, {
    CanvasCFrame = board.Canvas:GetCFrame(),
    CanvasSizeStuds = board.Canvas:Size(),
    FieldOfView = 70,
    MountBoard = function(vpfInstance)
      board.Canvas._instance.Parent = vpfInstance
      board._instanceClone = board._instance:Clone()
      board._instanceClone.Parent = vpfInstance
    end,
    UnmountBoard = function()
      board.Canvas._instance.Parent = board._instance
      board._instanceClone:Destroy()
    end,
    Board = board,
    OnClose = function()
      Roact.unmount(handle)
    end
  }), target)

  return function()
    Roact.unmount(handle)
    boardInstance:Destroy()
    canvas._instance:Destroy()
  end
end
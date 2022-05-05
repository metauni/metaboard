-- Services
local Common = game:GetService("ReplicatedStorage").MetaBoardCommon
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

-- Imports
local Config = require(Common.Config)

local function store(board, boardKey)
	print('Getting datastore')
	print("board key", boardKey)
	local DataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

	if not DataStore then
		print("[Persistence] DataStore not loaded")
		return
	end

	local startTime = tick()

	local boardData = board:Serialise()

	print(boardData)

	local boardJSON = HttpService:JSONEncode(boardData)

	if not boardJSON then
		print("[Persistence] Board JSON encoding failed")
		return
	end

	-- TODO pre-empt "value too big" error
	-- print("Persistence: Board JSON length is " .. string.len(boardJSON))
	
	local success, errormessage = pcall(function()
		return DataStore:SetAsync(boardKey, boardJSON)
	end)
	if not success then
		print("[Persistence] SetAsync fail for " .. boardKey .. " with " .. string.len(boardJSON) .. " bytes ".. errormessage)
		return
	end

	local _elapsedTime = math.floor(100 * (tick() - startTime))/100

	print("[Persistence] Stored " .. boardKey .. " " .. string.len(boardJSON) .. " bytes in ".. _elapsedTime .."s.")
end

-- Restores an empty board to the contents stored in the DataStore
-- with the given persistence ID string. Optionally, it restores the
-- contents to all subscribers of the given board
local function restore(board, boardKey)
	local DataStore = DataStoreService:GetDataStore(Config.DataStoreTag)

	if not DataStore then
		print("[Persistence] DataStore not loaded")
		return
	end

	-- Get the value stored for the given persistId. Note that this may not
	-- have been set, which is fine
	local success, boardJSON = pcall(function()
		return DataStore:GetAsync(boardKey)
	end)
	if not success then
		print("[Persistence] GetAsync fail for " .. boardKey .. " " .. boardJSON)
		return
	end

	if boardJSON == nil then
		print("boardJSON empty")
		return
	end

	local boardData = HttpService:JSONDecode(boardJSON)

	if not boardData then
		print("[Persistence] Failed to decode JSON")
		return
	end

	print(boardKey, boardData)

	return boardData
end

return {
	Store = store,
	Restore = restore,
}
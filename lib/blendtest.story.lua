local Blend = require(script.Parent.Util.Blend)

return function(target)

	local maid = Blend.mount(workspace, {
		Blend.New "Frame" {
		Size = UDim2.fromOffset(300, 300),
		-- Blend.New "TextButton" {
		-- 	Size = UDim2.fromOffset(200, 200),
		-- 	BackgroundColor3 = Color3.new(1,0,0),
		-- 	[Blend.OnEvent "Activated"] = function()
		-- 		print("click")
		-- 	end
		-- }
	}})

	return function()
		maid:Destroy()
	end
end

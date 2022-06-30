--[[
	A roact Tree looks like this
	
	{
		[RoactType] = Symbol(RoactVirtualTree),
		[Symbol(InternalData)] = {
			["rootNode"] ={
				["hostObject"] = <Instance>,
				...
				...
			},
			...
			...
		}
	}

	Note that the keys at the top level are not strings, they are special values
	created inside roact.
	So we just iterate over them to get the internal data one.
--]]

return function (tree)
	for key, value in pairs(tree) do
		local success, rootNode = pcall(function()
			return value.rootNode
		end)
		if success and rootNode then
			local node = rootNode
			while node.hostObject == nil do
				local _, child = next(node.children)

				if child == nil then
					return nil
				else
					node = child
				end
			end

			return node.hostObject
		end
	end
end
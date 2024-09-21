local U = require(script.Parent.U)
local Stream = require(script.Parent.Stream)

local function mapTidyEach<K,V>(lifeStream: U.LifeStream<K>, fn: (K) -> (V & U.CleanupTask)): U.Stream<V>
	return function(listener)
		return Stream.listenTidyEach(lifeStream, function(value: K)
			local mapped = fn(value)
			listener(mapped)
			return mapped
		end)
	end
end

local function ThingList(
	props: {
		Things: U.LifeStream<Instance>
	}
)

	return U.new "Frame" {
		Name = "ThingList",

		Position = UDim2.fromScale(1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = "Y",

		BackgroundTransparency = 0.5,
		BackgroundColor3 = Color3.new(0, 0, 0),

		U.new "UICorner" {
			CornerRadius = UDim.new(0, 8)
		},

		U.new "UIListLayout" {
			SortOrder = "Name",
			FillDirection = "Vertical"
		},

		mapTidyEach(props.Things, function(thing)
			local Name = Stream.propertyOf(thing, "Name")
			local Text = U.concat {"Thing: ", Name}
		
			return U.new "TextLabel" {
				Name = Name,
		
				Size = UDim2.new(1, 0, 0, 25),
				BackgroundTransparency = 1,
		
				Text = Text,
				TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.GothamMedium,
				TextSize = 16,
				TextXAlignment = "Right",
				TextTruncate = "AtEnd",
		
				U.new "UIPadding" {
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10)
				}
			}

		end)
	}
end

return function(target)
	local cleanup = U.mount(target, {
		ThingList {
			Things = Stream.eachChildOf(workspace),
		}
	})
	
	return function()
		U.clean(cleanup)
	end
end

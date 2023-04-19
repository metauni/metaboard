-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

return {

	CircleLine = function(centre, radius, p0, p1, width)
		-- True iff the circle, defined by centre and radius, intersects the line,
		-- defined by p0, p1, width (with rounded ends).
		-- See diagram here:
		-- https://cdn.discordapp.com/attachments/916413265733636166/931115440409829376/image.png

		-- Vector from the start of the line to the centre of the circle
		local u = centre - p0
		-- Vector from the start of the line to the end of the line
		local v = p1 - p0

		-- the magnitude (with sign) of the projection of u onto v
		local m = u:Dot(v.Unit)

		if m <= 0 or p0 == p1 then
			-- The closest point on the line to centre is p0
			return u.Magnitude <= radius + width/2
		elseif m >= v.Magnitude then
			-- The closest point on the line to centre is p1
			return (centre - p1).Magnitude <= radius + width/2
		else
			-- The vector from centre to it's closest point on the line makes a perpendicular with the line
			return math.abs(u:Cross(v.Unit)) <= radius + width/2
		end
	end

}
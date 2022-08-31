-- --[[
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
-- --]]

local function hslToRgb(h, s, l)
	local r, g, b

	if s == 0 then
		r = l
		g = l
		b = l
	else
		local hue2rgb = function(p, q, t)
			if t < 0 then t += 1 end
			if t > 1 then t -= 1 end
			if t < 1/6 then
				return p + (q - p) * 6 * t
			elseif t < 1/2 then
				return q
			elseif t < 2/3 then
				return p + (q - p) * (2/3 - t) * 6
			else
				return p
			end
		end

		local q = if l < 0.5 then l * (1 + s) else l + s - l * s
		local p = 2 * l - q
		r = hue2rgb(p, q, h + 1/3);
		g = hue2rgb(p, q, h);
		b = hue2rgb(p, q, h - 1/3);
	end

	return r, g, b
end

local function rgbToHsl(r, g, b)
	local max = math.max(r, g, b)
	local min = math.min(r, g, b)
	local h, s, l
	l = (max + min) / 2

	if max == min then
		h = 0
		s = 0
	else
		local d = max - min
		s = if l > 0.5 then d / (2 - max - min) else d / (max + min)
		if max == r then
			h = (g - b) / d + (if g < b then 6 else 0)
		elseif max == g then
			h = (b - r) / d + 2
		elseif max == b then
			h = (r - g) / d + 4
		else
			error("one of these should have been equal to max")
		end
		h /= 6
	end

	return h, s, l
end

local colorData = {
	White  = { Index = 1, BaseColor = Color3.fromHex("FCFCFC"), ShadeAlphas = {-4/10, -3/10, -2/10, 1/10, 0} },
	Black  = { Index = 2, BaseColor = Color3.fromHex("000000"), ShadeAlphas = {0, 1/10, 2/10, 3/10, 4/10}    },
	Blue   = { Index = 3, BaseColor = Color3.fromHex("007AFF"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}      },
	Green  = { Index = 4, BaseColor = Color3.fromHex("7EC636"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}      },
	Red    = { Index = 5, BaseColor = Color3.fromHex("D20000"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}      },
	Orange = { Index = 6, BaseColor = Color3.fromHex("F59A23"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}      },
	Purple = { Index = 7, BaseColor = Color3.fromHex("82218B"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}      },
	Pink   = { Index = 8, BaseColor = Color3.fromHex("FF58C4"), ShadeAlphas = {-2/3, -1/3, 0, 1/3, 2/3}      },
}

local colorPalette = {}

for baseName, colorTable in pairs(colorData) do

	local shades = table.create(#colorTable.ShadeAlphas)

	local h, s, l = rgbToHsl(colorTable.BaseColor.R, colorTable.BaseColor.G, colorTable.BaseColor.B)
	for i, shadeAlpha in ipairs(colorTable.ShadeAlphas) do
		if shadeAlpha >= 0 then
			local shadeLum = shadeAlpha * (1-l) + l
			shades[i] = Color3.new(hslToRgb(h,s,shadeLum))
		else
			local shadeLum = l - -shadeAlpha * l
			shades[i] = Color3.new(hslToRgb(h,s,shadeLum))
		end
	end

	colorPalette[baseName] = {

		BaseColor = colorTable.BaseColor,
		Index = colorTable.Index,
		Shades = shades

	}
end

return colorPalette
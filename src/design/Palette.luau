--!strict
-- Basalt / design / Palette
-- Contrast is measured here and asserted in tests/specs/tokens.spec.luau.
-- The test is the claim. A number in a README is not.

export type Pair = { fg: string, bg: string }

export type Result = {
	fg: string,
	bg: string,
	ratio: number,
}

export type Audit = {
	ok: boolean,
	results: { Result },
	failures: { Result },
}

-- Every pair below is text on a surface. Decorative seams are not audited:
-- WCAG 1.4.11 covers meaningful boundaries, and the seam is not one.
local PAIRS: { Pair } = {
	{ fg = "ink", bg = "well" },
	{ fg = "ink", bg = "frame" },
	{ fg = "ink", bg = "raised" },
	{ fg = "muted", bg = "well" },
	{ fg = "muted", bg = "raised" },
	{ fg = "faint", bg = "well" },
	{ fg = "accent", bg = "well" },
	{ fg = "accentInk", bg = "accent" },
	{ fg = "danger", bg = "well" },
	{ fg = "success", bg = "well" },
	{ fg = "ink", bg = "selected" },
}

local MIN_RATIO = 4.5

local Palette = {}

function Palette.Channels(color: Color3): (number, number, number)
	return color.R, color.G, color.B
end

function Palette.Luminance(color: Color3): number
	local function linear(channel: number): number
		if channel <= 0.04045 then
			return channel / 12.92
		end
		return math.pow((channel + 0.055) / 1.055, 2.4)
	end

	local r, g, b = Palette.Channels(color)
	return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end

function Palette.Contrast(a: Color3, b: Color3): number
	local first = Palette.Luminance(a)
	local second = Palette.Luminance(b)

	if first < second then
		first, second = second, first
	end

	return (first + 0.05) / (second + 0.05)
end

function Palette.ContrastHex(a: string, b: string): number
	return Palette.Contrast(Color3.fromHex(a), Color3.fromHex(b))
end

function Palette.Audit(theme: { name: string?, colors: { [string]: string } }): Audit
	local results: { Result } = {}
	local failures: { Result } = {}

	for _, pair in ipairs(PAIRS) do
		local fg = theme.colors[pair.fg]
		local bg = theme.colors[pair.bg]

		if type(fg) ~= "string" or type(bg) ~= "string" then
			local missing: Result = { fg = pair.fg, bg = pair.bg, ratio = 0 }
			table.insert(results, missing)
			table.insert(failures, missing)
			continue
		end

		local ratio = Palette.ContrastHex(fg, bg)
		local result: Result = { fg = pair.fg, bg = pair.bg, ratio = ratio }
		table.insert(results, result)

		if ratio < MIN_RATIO then
			table.insert(failures, result)
		end
	end

	return {
		ok = #failures == 0,
		results = results,
		failures = failures,
	}
end

function Palette.Round(ratio: number): number
	return math.floor(ratio * 100 + 0.5) / 100
end

return Palette

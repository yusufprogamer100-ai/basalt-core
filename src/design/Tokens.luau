--!strict
-- Basalt / design / Tokens
-- A theme is a contract, not a color swap. If a required color is missing the
-- theme is rejected and the reason is printed. Silent fallbacks hide bugs.
--
-- Modernization rationale (R-31):
-- * radiusSmall/Medium/Large replace the single 2-3px control radius.
--   Sharp 2px corners read as default Roblox; rounded 6-14px corners read as
--   a deliberate surface. Max 3 radii keeps the system consistent (R-11).
-- * surfaceElevated / surfaceOverlay add depth without glass or glow.
--   Elevation is a shadow-only signal (R-12, R-13): no blur, no neon.
-- * shadow config drives UIShadow on pop-out surfaces only.

export type Density = "compact" | "comfortable"

export type Validation = {
	ok: boolean,
	missing: { string },
}

local Tokens = {}

Tokens.RequiredColors = {
	"frame",
	"well",
	"raised",
	"seam",
	"seamStrong",
	"ink",
	"muted",
	"faint",
	"accent",
	"accentInk",
	"danger",
	"success",
	"focus",
	"scrim",
	"selected",
	"surfaceElevated",
	"surfaceOverlay",
}

-- 4px rhythm. Every value below is a multiple of 2 so half-pixel seams stay
-- crisp at any UIScale.
Tokens.Space = {
	xxs = 2,
	xs = 4,
	sm = 6,
	md = 8,
	lg = 12,
	xl = 16,
	xxl = 24,
}

Tokens.Size = {
	header = { compact = 44, comfortable = 48 },
	row = { compact = 32, comfortable = 44 },
	rail = { compact = 148, comfortable = 160 },
	gap = { compact = 8, comfortable = 10 },
	pad = { compact = 12, comfortable = 14 },
	-- Radius tokens: max 3 values, tokenized for consistency (R-11).
	radiusSmall = 6,
	radiusMedium = 10,
	radiusLarge = 14,
	seam = 1,
	toggleWidth = 30,
	toggleHeight = 16,
	toggleKnob = 12,
	sliderTrack = 4,
	sliderKnob = 12,
	badge = 16,
}

-- Shadow config: UIShadow on elevated surfaces only. Not applied to every
-- card (R-12); reserved for pop-outs and overlays.
Tokens.Shadow = {
	blur = 12,
	spread = 0,
	offset = 4,
	color = "#000000",
	transparency = 0.6,
}

Tokens.Text = {
	title = 15,
	body = 13,
	small = 11,
	micro = 10,
	mono = 11,
}

function Tokens.Validate(theme: { name: string?, colors: { [string]: string } }): Validation
	local missing: { string } = {}

	if type(theme) ~= "table" then
		return { ok = false, missing = { "theme" } }
	end

	if type(theme.name) ~= "string" then
		table.insert(missing, "name")
	end

	if type(theme.colors) ~= "table" then
		return { ok = false, missing = { "colors" } }
	end

	for _, key in ipairs(Tokens.RequiredColors) do
		local value = theme.colors[key]
		if type(value) ~= "string" or not string.match(value, "^#%x%x%x%x%x%x$") then
			table.insert(missing, key)
		end
	end

	return { ok = #missing == 0, missing = missing }
end

function Tokens.Row(density: Density): number
	return Tokens.Size.row[density]
end

function Tokens.Rail(density: Density): number
	return Tokens.Size.rail[density]
end

function Tokens.Gap(density: Density): number
	return Tokens.Size.gap[density]
end

function Tokens.Pad(density: Density): number
	return Tokens.Size.pad[density]
end

function Tokens.Header(density: Density): number
	return Tokens.Size.header[density]
end

function Tokens.Radius(size: string): number
	local value = Tokens.Size[size]
	if type(value) ~= "number" then
		error(string.format("Basalt: no radius token '%s'", tostring(size)), 2)
	end
	return value
end

return Tokens

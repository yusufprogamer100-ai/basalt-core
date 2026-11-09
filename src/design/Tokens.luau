--!strict
-- Basalt / design / Tokens
-- A theme is a contract, not a color swap. If a required color is missing the
-- theme is rejected and the reason is printed. Silent fallbacks hide bugs.
--
-- Modernization rationale (v0.4.0, R-31):
-- * Depth tokens: surfaceElevated1/2/3 for layered elevation without glass.
--   Each layer gets a distinct shadow blur spread so users read hierarchy.
-- * Type scale: caption/body/bodyLg/h3/h2/h1 for deliberate hierarchy.
--   Text sizes are not magic numbers chosen per component (R-31).
-- * Radius tokens: max 3 values, tokenized for consistency (R-11).
-- * Shadow config: UIShadow on elevated surfaces only (R-12, R-13).
-- * Variant colors: primary uses accent as background (R-15 specific CTA).

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
	"surfaceElevated1",
	"surfaceElevated2",
	"surfaceElevated3",
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

-- Shadow config: UIShadow on pop-out surfaces only. Not applied to every
-- card (R-12); reserved for pop-outs and overlays.
Tokens.Shadow = {
	elevated1 = { blur = 8, spread = 0, offset = 2, transparency = 0.35 },
	elevated2 = { blur = 14, spread = 0, offset = 4, transparency = 0.5 },
	elevated3 = { blur = 20, spread = 0, offset = 6, transparency = 0.6 },
	color = "#000000",
}

-- Type scale: deliberate hierarchy, not arbitrary per-component sizes.
Tokens.Text = {
	caption = 10,
	body = 12,
	bodyLg = 14,
	h3 = 18,
	h2 = 24,
	h1 = 32,
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

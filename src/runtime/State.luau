--!strict
-- Basalt / runtime / State
-- One variant table, resolved in one place. A control does not decide what
-- "hover" looks like; it reports what happened and receives the same seven
-- answers as every other control. If a role misses a variant, the module
-- refuses to load instead of shipping a state that renders as a dead control.

local Tokens = require(script.Parent.Parent.design.Tokens)

export type Variant =
	"default"
	| "hover"
	| "pressed"
	| "focused"
	| "disabled"
	| "selected"
	| "invalid"

export type Role = "button" | "primary" | "ghost" | "field" | "row"

export type Flags = {
	enabled: boolean?,
	hovered: boolean?,
	pressed: boolean?,
	focused: boolean?,
	selected: boolean?,
	invalid: boolean?,
}

export type Style = {
	background: string?,
	text: string,
	stroke: string?,
}

local State = {}

State.Variants = {
	"default",
	"hover",
	"pressed",
	"focused",
	"disabled",
	"selected",
	"invalid",
}

-- `nil` background means transparent. That is a deliberate value, not a
-- missing one: ghost controls sit on whatever surface owns them.
local STYLES: { [Role]: { [Variant]: Style } } = {
	button = {
		default = { background = "raised", text = "ink", stroke = nil },
		hover = { background = "selected", text = "ink", stroke = nil },
		pressed = { background = "seamStrong", text = "ink", stroke = nil },
		focused = { background = "raised", text = "ink", stroke = "focus" },
		selected = { background = "selected", text = "accent", stroke = "seamStrong" },
		disabled = { background = "raised", text = "faint", stroke = nil },
		invalid = { background = "raised", text = "danger", stroke = "danger" },
	},
	primary = {
		default = { background = "accent", text = "accentInk", stroke = nil },
		hover = { background = "accent", text = "accentInk", stroke = "focus" },
		pressed = { background = "accent", text = "accentInk", stroke = "seamStrong" },
		focused = { background = "accent", text = "accentInk", stroke = "focus" },
		selected = { background = "well", text = "accent", stroke = "accent" },
		disabled = { background = "raised", text = "faint", stroke = nil },
		invalid = { background = "danger", text = "accentInk", stroke = "danger" },
	},
	ghost = {
		default = { background = nil, text = "muted", stroke = nil },
		hover = { background = "selected", text = "ink", stroke = nil },
		pressed = { background = "seamStrong", text = "ink", stroke = nil },
		focused = { background = nil, text = "ink", stroke = "focus" },
		selected = { background = "selected", text = "accent", stroke = nil },
		disabled = { background = nil, text = "faint", stroke = nil },
		invalid = { background = nil, text = "danger", stroke = "danger" },
	},
	field = {
		default = { background = "well", text = "ink", stroke = "seam" },
		hover = { background = "well", text = "ink", stroke = "seamStrong" },
		pressed = { background = "well", text = "ink", stroke = "focus" },
		focused = { background = "well", text = "ink", stroke = "focus" },
		selected = { background = "well", text = "ink", stroke = "accent" },
		disabled = { background = "well", text = "faint", stroke = "seam" },
		invalid = { background = "well", text = "danger", stroke = "danger" },
	},
	row = {
		default = { background = nil, text = "ink", stroke = nil },
		hover = { background = "selected", text = "ink", stroke = nil },
		pressed = { background = "seamStrong", text = "ink", stroke = nil },
		focused = { background = "selected", text = "ink", stroke = "focus" },
		selected = { background = "selected", text = "accent", stroke = nil },
		disabled = { background = nil, text = "faint", stroke = nil },
		invalid = { background = nil, text = "danger", stroke = "danger" },
	},
}

-- Validate at load. A missing variant or a typo in a token name must fail
-- before any window is built, and the message must name the offender.
local function validate()
	for role, variants in pairs(STYLES) do
		for _, variant in ipairs(State.Variants) do
			local style = (variants :: any)[variant]

			if type(style) ~= "table" then
				error(
					string.format("Basalt: style role '%s' is missing variant '%s'", role, variant),
					0
				)
			end

			if
				style.background ~= nil
				and table.find(Tokens.RequiredColors, style.background) == nil
			then
				error(
					string.format(
						"Basalt: style '%s/%s' uses unknown background token '%s'",
						role,
						variant,
						tostring(style.background)
					),
					0
				)
			end

			if table.find(Tokens.RequiredColors, style.text) == nil then
				error(
					string.format(
						"Basalt: style '%s/%s' uses unknown text token '%s'",
						role,
						variant,
						tostring(style.text)
					),
					0
				)
			end

			if style.stroke ~= nil and table.find(Tokens.RequiredColors, style.stroke) == nil then
				error(
					string.format(
						"Basalt: style '%s/%s' uses unknown stroke token '%s'",
						role,
						variant,
						tostring(style.stroke)
					),
					0
				)
			end
		end
	end
end

validate()

-- Precedence is part of the contract. A disabled control must not look
-- hovered, and an invalid field must show the error even while focused.
function State.Variant(flags: Flags?): Variant
	local value = flags or {}

	if value.enabled == false then
		return "disabled"
	end
	if value.invalid then
		return "invalid"
	end
	if value.pressed then
		return "pressed"
	end
	if value.focused then
		return "focused"
	end
	if value.selected then
		return "selected"
	end
	if value.hovered then
		return "hover"
	end

	return "default"
end

function State.Resolve(role: Role, flags: Flags?): Style
	local variants = STYLES[role]

	if not variants then
		error(string.format("Basalt: unknown style role '%s'", tostring(role)), 2)
	end

	return variants[State.Variant(flags)]
end

function State.Style(role: Role, variant: Variant): Style
	local variants = STYLES[role]

	if not variants then
		error(string.format("Basalt: unknown style role '%s'", tostring(role)), 2)
	end

	local style = variants[variant]

	if not style then
		error(string.format("Basalt: role '%s' has no variant '%s'", role, tostring(variant)), 2)
	end

	return style
end

return State

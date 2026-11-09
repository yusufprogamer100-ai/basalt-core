--!strict
-- Basalt / design / Themes
-- Themes are a registry, not a switch statement. Every theme is validated once
-- at load time. A theme that misses a token stops the load with the token names
-- attached, because a silent fallback would ship a wrong color to a user.

local Tokens = require(script.Parent.Parent.Tokens)
local graphite = require(script.Parent.graphite)
local bone = require(script.Parent.bone)
local signal = require(script.Parent.signal)

local Themes = {}

Themes.Names = { "graphite", "bone", "signal" }

local registry: { [string]: { name: string, colors: { [string]: string } } } = {
	graphite = graphite,
	bone = bone,
	signal = signal,
}

for _, name in ipairs(Themes.Names) do
	local theme = registry[name]
	local check = Tokens.Validate(theme)

	if not check.ok then
		error(
			string.format(
				"Basalt: theme '%s' is missing or invalid: %s",
				name,
				table.concat(check.missing, ", ")
			),
			0
		)
	end
end

function Themes.Has(name: string): boolean
	return registry[name] ~= nil
end

function Themes.Get(name: string): { name: string, colors: { [string]: string } }
	local theme = registry[name]

	if not theme then
		error(
			string.format(
				"Basalt: unknown theme '%s'. Available: %s",
				tostring(name),
				table.concat(Themes.Names, ", ")
			),
			2
		)
	end

	return theme
end

return Themes

--!strict
-- Basalt / components / Spacer
-- Explicit vertical rhythm. A spacer is cheaper and more predictable than
-- padding rules layered on every neighbour.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Surface = require(script.Parent.Parent.runtime.Surface)

export type Config = {
	height: number?,
}

export type Spacer = {
	surface: Surface.Surface,
	instance: Instance,
	destroyed: boolean,
	SetVisible: (self: Spacer, value: boolean) -> (),
	SetEnabled: (self: Spacer, value: boolean) -> (),
	Destroy: (self: Spacer) -> (),
}

local Spacer = {}
Spacer.__index = Spacer

function Spacer.new(surface: Surface.Surface, config: Config?): Spacer
	local settings = config or {}

	local instance = surface:Frame({
		Name = "Spacer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, settings.height or Tokens.Space.md),
	})

	local spacer = setmetatable({
		surface = surface,
		instance = instance,
		destroyed = false,
	}, Spacer)

	surface.scope:Add(spacer)

	return spacer
end

function Spacer:SetVisible(value: boolean)
	(self.instance :: any).Visible = value
end

function Spacer:SetEnabled(value: boolean)
	(self.instance :: any).Visible = value
end

function Spacer:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Spacer

--!strict
-- Basalt / components / Divider
-- A seam, not a card. Dividers exist to break a long column into scannable
-- groups; they never add a shadow or a second background.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Surface = require(script.Parent.Parent.runtime.Surface)

export type Config = {
	inset: boolean?,
	strong: boolean?,
}

export type Divider = {
	surface: Surface.Surface,
	instance: Instance,
	destroyed: boolean,
	SetVisible: (self: Divider, value: boolean) -> (),
	SetEnabled: (self: Divider, value: boolean) -> (),
	Destroy: (self: Divider) -> (),
}

local Divider = {}
Divider.__index = Divider

function Divider.new(surface: Surface.Surface, config: Config?): Divider
	local settings = config or {}
	local inset = if settings.inset == false then 0 else Tokens.Space.lg

	local instance = surface:Create("Frame", {
		Name = "Divider",
		BackgroundColor3 = surface:Color(if settings.strong then "seamStrong" else "seam"),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -inset * 2, 0, Tokens.Size.seam),
		Position = UDim2.new(0, inset, 0, 0),
	})

	local divider = setmetatable({
		surface = surface,
		instance = instance,
		destroyed = false,
	}, Divider)

	surface.scope:Add(divider)

	return divider
end

function Divider:SetVisible(value: boolean)
	(self.instance :: any).Visible = value
end

function Divider:SetEnabled(value: boolean)
	(self.instance :: any).Visible = value
end

function Divider:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Divider

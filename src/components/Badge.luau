--!strict
-- Basalt / components / Badge
-- Small status text. Width is measured from the character count instead of a
-- text-bounds call, because text bounds are not available headless and a badge
-- that waits for layout would flicker on the first frame.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Surface = require(script.Parent.Parent.runtime.Surface)

export type Tone = "ink" | "muted" | "accent" | "danger" | "success"

export type Config = {
	text: string?,
	tone: Tone?,
}

export type Badge = {
	surface: Surface.Surface,
	instance: Instance,
	destroyed: boolean,
	SetText: (self: Badge, text: string) -> (),
	SetVisible: (self: Badge, value: boolean) -> (),
	SetEnabled: (self: Badge, value: boolean) -> (),
	Destroy: (self: Badge) -> (),
}

local Badge = {}
Badge.__index = Badge

local CHAR_WIDTH = 6
local PADDING = 12

local function widthFor(text: string): number
	return math.max(Tokens.Size.badge + PADDING, #text * CHAR_WIDTH + PADDING)
end

function Badge.new(surface: Surface.Surface, config: Config?): Badge
	local settings = config or {}
	local text = settings.text or ""
	local tone = settings.tone or "muted"

	local instance = surface:Create("TextLabel", {
		Name = "Badge",
		BackgroundColor3 = surface:Color("raised"),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = surface:Color(tone),
		TextSize = surface:Text("micro"),
		Font = surface:Font("mono"),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromOffset(widthFor(text), Tokens.Size.badge),
	})

	local badge = setmetatable({
		surface = surface,
		instance = instance,
		destroyed = false,
	}, Badge)

	surface:Corner(instance, Tokens.Size.radiusControl)
	surface.scope:Add(badge)

	return badge
end

local function setText(badge: Badge, text: string)
	local target = badge.instance :: any
	target.Text = text
	target.Size = UDim2.fromOffset(widthFor(text), Tokens.Size.badge)
end

function Badge:SetText(text: string)
	if self.destroyed then
		return
	end

	setText(self, text)
end

function Badge:SetVisible(value: boolean)
	(self.instance :: any).Visible = value
end

function Badge:SetEnabled(value: boolean)
	(self.instance :: any).Visible = value
end

function Badge:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Badge

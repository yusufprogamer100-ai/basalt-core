--!strict
-- Basalt / components / Label
-- Text without a control. Tone is a token name, not a hex value, so a label
-- inherits every theme without knowing any of them.

local Surface = require(script.Parent.Parent.runtime.Surface)

export type Tone = "ink" | "muted" | "faint" | "accent" | "danger" | "success"

export type Config = {
	text: string?,
	tone: Tone?,
	size: "title" | "body" | "small" | "mono"?,
	wrap: boolean?,
}

export type Label = {
	surface: Surface.Surface,
	instance: Instance,
	destroyed: boolean,
	SetText: (self: Label, text: string) -> (),
	GetValue: (self: Label) -> string,
	SetValue: (self: Label, value: any) -> (),
	SetTone: (self: Label, tone: Tone) -> (),
	SetVisible: (self: Label, value: boolean) -> (),
	SetEnabled: (self: Label, value: boolean) -> (),
	Destroy: (self: Label) -> (),
}

local Label = {}
Label.__index = Label

function Label.new(surface: Surface.Surface, config: Config?): Label
	local settings = config or {}
	local role = settings.size or "body"
	local tone = settings.tone or "ink"

	local instance = surface:Label({
		Name = "Label",
		Text = settings.text or "",
		Font = surface:Font(role),
		TextSize = surface:Text(role),
		TextColor3 = surface:Color(tone),
		TextWrapped = settings.wrap == true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	})

	local label = setmetatable({
		surface = surface,
		instance = instance,
		destroyed = false,
	}, Label)

	surface.scope:Add(label)

	return label
end

function Label:SetText(text: string)
	if self.destroyed then
		return
	end

	(self.instance :: any).Text = text
end

function Label:GetValue(): string
	return (self.instance :: any).Text
end

function Label:SetValue(value: any)
	self:SetText(tostring(value))
end

function Label:SetTone(tone: Tone)
	if self.destroyed then
		return
	end

	(self.instance :: any).TextColor3 = self.surface:Color(tone)
end

function Label:SetVisible(value: boolean)
	if self.destroyed then
		return
	end

	(self.instance :: any).Visible = value
end

function Label:SetEnabled(value: boolean)
	self:SetTone(if value then "ink" else "faint")
end

function Label:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Label

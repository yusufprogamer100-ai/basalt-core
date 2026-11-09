--!strict
-- Basalt / components / Button
-- The smallest complete control. It exercises the whole contract: seven
-- variants, pointer states, disabled swallowing the click, and one cleanup
-- scope. Once this shape is right, every other control copies it.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local State = require(script.Parent.Parent.runtime.State)

export type Variant = "default" | "primary" | "ghost"

export type Config = {
	text: string?,
	variant: Variant?,
	width: number?,
	height: number?,
	enabled: boolean?,
	selected: boolean?,
	onClick: (() -> ())?,
}

export type Button = {
	surface: Surface.Surface,
	instance: Instance,
	role: State.Role,
	enabled: boolean,
	selected: boolean,
	hovered: boolean,
	pressed: boolean,
	focused: boolean,
	destroyed: boolean,
	onClick: (() -> ())?,
	_scope: Scope.Scope,
	_stroke: Instance,

	Render: (self: Button) -> (),
	SetEnabled: (self: Button, value: boolean) -> (),
	SetVisible: (self: Button, value: boolean) -> (),
	SetValue: (self: Button, value: any) -> (),
	GetValue: (self: Button) -> any,
	SetSelected: (self: Button, value: boolean) -> (),
	SetFocus: (self: Button, value: boolean) -> (),
	Focus: (self: Button) -> (),
	Blur: (self: Button) -> (),
	Activate: (self: Button) -> (),
	Destroy: (self: Button) -> (),
}

local Button = {}
Button.__index = Button

local ROLE: { [Variant]: State.Role } = {
	default = "button",
	primary = "primary",
	ghost = "ghost",
}

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

function Button.new(surface: Surface.Surface, config: Config?): Button
	local settings = config or {}
	local variant = settings.variant or "default"
	local role = ROLE[variant]

	if not role then
		error(string.format("Basalt: unknown button variant '%s'", tostring(variant)), 2)
	end

	local height = settings.height or Tokens.Row(surface.density)

	local instance = surface:Button({
		Name = "Button",
		Text = settings.text or "",
		Size = UDim2.new(0, settings.width or 0, 0, height),
		AutomaticSize = if settings.width then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local button = setmetatable({
		surface = surface,
		instance = instance,
		role = role,
		enabled = settings.enabled ~= false,
		selected = settings.selected == true,
		hovered = false,
		pressed = false,
		focused = false,
		destroyed = false,
		onClick = settings.onClick,
		_scope = Scope.new(),
		_stroke = surface:Stroke(instance, "focus", Tokens.Size.seam),
	}, Button)

	button:Render()

	button._scope:AddConnection((instance :: any).MouseEnter:Connect(function()
		button.hovered = true
		button:Render()
	end))

	button._scope:AddConnection((instance :: any).MouseLeave:Connect(function()
		button.hovered = false
		button.pressed = false
		button:Render()
	end))

	button._scope:AddConnection((instance :: any).MouseButton1Down:Connect(function()
		if not button.enabled then
			return
		end
		button.pressed = true
		button:Render()
	end))

	button._scope:AddConnection((instance :: any).MouseButton1Up:Connect(function()
		button.pressed = false
		button:Render()
	end))

	button._scope:AddConnection((instance :: any).MouseButton1Click:Connect(function()
		button:Activate()
	end))

	surface.scope:Add(button)

	return button
end

function Button:Render()
	if self.destroyed then
		return
	end

	local style = State.Resolve(self.role, {
		enabled = self.enabled,
		hovered = self.hovered,
		pressed = self.pressed,
		focused = self.focused,
		selected = self.selected,
	})

	if style.background then
		set(self.instance, "BackgroundTransparency", 0)
		set(self.instance, "BackgroundColor3", self.surface:Color(style.background))
	else
		set(self.instance, "BackgroundTransparency", 1)
	end

	set(self.instance, "TextColor3", self.surface:Color(style.text))

	-- The stroke instance is reused instead of destroyed per state change.
	-- Hovering a button must not allocate eight instances a second.
	if style.stroke then
		set(self._stroke, "Color", self.surface:Color(style.stroke))
		set(self._stroke, "Transparency", 0)
	else
		set(self._stroke, "Transparency", 1)
	end
end

function Button:SetEnabled(value: boolean)
	if self.destroyed then
		return
	end

	self.enabled = value

	if not value then
		self.pressed = false
		self.hovered = false
	end

	self:Render()
end

function Button:SetVisible(value: boolean)
	if self.destroyed then
		return
	end

	set(self.instance, "Visible", value)
end

function Button:SetValue(value: any)
	self:SetSelected(value == true)
end

function Button:GetValue(): any
	return self.selected
end

function Button:SetSelected(value: boolean)
	if self.destroyed then
		return
	end

	self.selected = value
	self:Render()
end

function Button:SetFocus(value: boolean)
	if self.destroyed then
		return
	end

	if value and not self.enabled then
		return
	end

	self.focused = value
	self:Render()
end

function Button:Focus()
	self:SetFocus(true)
end

function Button:Blur()
	self:SetFocus(false)
end

function Button:Activate()
	if not self.enabled or self.destroyed then
		return
	end

	if self.onClick then
		self.onClick()
	end
end

function Button:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Button

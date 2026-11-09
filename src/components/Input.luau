--!strict
-- Basalt / components / Input
-- A label and a real TextBox. The field uses the `field` role, so focus,
-- invalid and disabled states come from the same table as every other control
-- instead of being re-invented here.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local State = require(script.Parent.Parent.runtime.State)

export type Config = {
	text: string?,
	placeholder: string?,
	value: string?,
	enabled: boolean?,
	onSubmit: ((value: string) -> ())?,
}

export type Input = {
	surface: Surface.Surface,
	instance: Instance,
	box: Instance,
	value: string,
	enabled: boolean,
	focused: boolean,
	hovered: boolean,
	invalid: boolean,
	destroyed: boolean,
	onSubmit: ((value: string) -> ())?,
	_scope: Scope.Scope,
	_label: Instance,
	_stroke: Instance,

	Render: (self: Input) -> (),
	SetValue: (self: Input, value: string) -> (),
	GetValue: (self: Input) -> string,
	SetInvalid: (self: Input, value: boolean) -> (),
	SetEnabled: (self: Input, value: boolean) -> (),
	SetVisible: (self: Input, value: boolean) -> (),
	SetFocus: (self: Input, value: boolean) -> (),
	Focus: (self: Input) -> (),
	Blur: (self: Input) -> (),
	Capture: (self: Input) -> (),
	Activate: (self: Input) -> (),
	Destroy: (self: Input) -> (),
}

local Input = {}
Input.__index = Input

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

function Input.new(surface: Surface.Surface, config: Config?): Input
	local settings = config or {}
	local rowHeight = Tokens.Row(surface.density)
	local fieldWidth = 180

	local instance = surface:Raised({
		Name = "Input",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, rowHeight),
	})

	local label = surface:Label({
		Name = "Text",
		Text = settings.text or "",
		TextColor3 = surface:Color("ink"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -(fieldWidth + Tokens.Space.lg), 1, 0),
	})

	set(label, "Parent", instance)

	local box = surface:Create("TextBox", {
		Name = "Field",
		Text = settings.value or "",
		PlaceholderText = settings.placeholder or "",
		PlaceholderColor3 = surface:Color("faint"),
		TextColor3 = surface:Color("ink"),
		TextSize = surface:Text("body"),
		Font = surface:Font("body"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundColor3 = surface:Color("well"),
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		TextEditable = settings.enabled ~= false,
		Size = UDim2.new(0, fieldWidth, 0, rowHeight - Tokens.Space.md),
		Position = UDim2.new(1, -fieldWidth, 0.5, -(rowHeight - Tokens.Space.md) / 2),
	})

	set(box, "Parent", instance)
	surface:Pad(box, Tokens.Space.xs + 2)

	local stroke = surface:Stroke(box, "seam", Tokens.Size.seam)

	local input = setmetatable({
		surface = surface,
		instance = instance,
		box = box,
		value = settings.value or "",
		enabled = settings.enabled ~= false,
		focused = false,
		hovered = false,
		invalid = false,
		destroyed = false,
		onSubmit = settings.onSubmit,
		_scope = Scope.new(),
		_label = label,
		_stroke = stroke,
	}, Input)

	input:Render()

	input._scope:AddConnection((instance :: any).MouseEnter:Connect(function()
		input.hovered = true
		input:Render()
	end))

	input._scope:AddConnection((instance :: any).MouseLeave:Connect(function()
		input.hovered = false
		input:Render()
	end))

	input._scope:AddConnection((box :: any).Focused:Connect(function()
		input.focused = true
		input:Render()
	end))

	input._scope:AddConnection((box :: any).FocusLost:Connect(function(enterPressed: any)
		input.focused = false
		input.value = (box :: any).Text
		input:Render()

		if input.onSubmit then
			input.onSubmit(input.value, enterPressed)
		end
	end))

	surface.scope:Add(input)

	return input
end

function Input:Render()
	if self.destroyed then
		return
	end

	local style = State.Resolve("field", {
		enabled = self.enabled,
		hovered = self.hovered,
		focused = self.focused,
		invalid = self.invalid,
	})

	if style.background then
		set(self.box, "BackgroundTransparency", 0)
		set(self.box, "BackgroundColor3", self.surface:Color(style.background))
	end

	set(self.box, "TextColor3", self.surface:Color(style.text))
	set(self._label, "TextColor3", self.surface:Color(if self.enabled then "ink" else "faint"))

	if style.stroke then
		set(self._stroke, "Color", self.surface:Color(style.stroke))
		set(self._stroke, "Transparency", 0)
	else
		set(self._stroke, "Transparency", 1)
	end
end

function Input:SetValue(value: string)
	if self.destroyed then
		return
	end

	self.value = value
	set(self.box, "Text", value)
end

function Input:GetValue(): string
	return (self.box :: any).Text
end

function Input:SetInvalid(value: boolean)
	self.invalid = value
	self:Render()
end

function Input:SetEnabled(value: boolean)
	if self.destroyed then
		return
	end

	self.enabled = value
	set(self.box, "TextEditable", value)
	self:Render()
end

function Input:SetVisible(value: boolean)
	set(self.instance, "Visible", value)
end

function Input:SetFocus(value: boolean)
	if self.destroyed then
		return
	end

	if value and not self.enabled then
		return
	end

	self.focused = value
	self:Render()
end

function Input:Focus()
	self:SetFocus(true)
end

function Input:Blur()
	self:SetFocus(false)
end

-- Capturing is the moment text entry begins. The focus manager can hold the
-- ring on a field without stealing the keyboard, and activation calls this.
function Input:Capture()
	if self.destroyed or not self.enabled then
		return
	end

	pcall(function()
		(self.box :: any):CaptureFocus()
	end)
end

function Input:Activate()
	self:Capture()
end

function Input:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Input

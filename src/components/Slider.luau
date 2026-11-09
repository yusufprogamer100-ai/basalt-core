--!strict
-- Basalt / components / Slider
-- Pointer to value is pure math, kept outside the Instance code so it can be
-- tested without a viewport. The component only reads absolute track geometry,
-- which is the one measurement that has to come from the engine.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local State = require(script.Parent.Parent.runtime.State)

export type Config = {
	text: string?,
	min: number?,
	max: number?,
	step: number?,
	value: number?,
	suffix: string?,
	enabled: boolean?,
	onChange: ((value: number) -> ())?,
}

export type Slider = {
	surface: Surface.Surface,
	instance: Instance,
	value: number,
	min: number,
	max: number,
	step: number,
	suffix: string,
	enabled: boolean,
	hovered: boolean,
	focused: boolean,
	dragging: boolean,
	destroyed: boolean,
	onChange: ((value: number) -> ())?,
	_scope: Scope.Scope,
	_track: Instance,
	_fill: Instance,
	_knob: Instance,
	_label: Instance,
	_valueLabel: Instance,
	_stroke: Instance,

	Render: (self: Slider) -> (),
	SetValue: (self: Slider, value: number) -> (),
	GetValue: (self: Slider) -> number,
	Step: (self: Slider, direction: number) -> (),
	SetEnabled: (self: Slider, value: boolean) -> (),
	SetVisible: (self: Slider, value: boolean) -> (),
	SetFocus: (self: Slider, value: boolean) -> (),
	Focus: (self: Slider) -> (),
	Blur: (self: Slider) -> (),
	Nudge: (self: Slider, direction: number) -> (),
	Destroy: (self: Slider) -> (),
}

local Slider = {}
Slider.__index = Slider

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local function round(value: number): number
	return math.floor(value * 1000000 + 0.5) / 1000000
end

function Slider.Ratio(value: number, minimum: number, maximum: number): number
	if maximum <= minimum then
		return 0
	end

	return math.clamp((value - minimum) / (maximum - minimum), 0, 1)
end

function Slider.Snap(value: number, minimum: number, maximum: number, step: number?): number
	local low = math.min(minimum, maximum)
	local high = math.max(minimum, maximum)
	local clamped = math.clamp(value, low, high)

	if step and step > 0 then
		clamped = low + math.floor((clamped - low) / step + 0.5) * step
		clamped = math.clamp(clamped, low, high)
	end

	return round(clamped)
end

function Slider.FromPointer(
	pointerX: number,
	trackStart: number,
	trackWidth: number,
	minimum: number,
	maximum: number,
	step: number?
): number
	if trackWidth <= 0 then
		return minimum
	end

	local ratio = math.clamp((pointerX - trackStart) / trackWidth, 0, 1)
	return Slider.Snap(minimum + ratio * (maximum - minimum), minimum, maximum, step)
end

local function formatNumber(value: number, step: number, suffix: string): string
	local text = if step >= 1 then tostring(math.floor(value + 0.5)) else tostring(value)
	return text .. suffix
end

local function formatValue(self: Slider): string
	return formatNumber(self.value, self.step, self.suffix)
end

function Slider.new(surface: Surface.Surface, config: Config?): Slider
	local settings = config or {}
	local minimum = settings.min or 0
	local maximum = settings.max or 100

	if maximum <= minimum then
		error(
			string.format(
				"Basalt: slider max (%s) must be greater than min (%s)",
				tostring(maximum),
				tostring(minimum)
			),
			2
		)
	end

	local step = settings.step or 1
	local value = Slider.Snap(settings.value or minimum, minimum, maximum, step)
	local rowHeight = Tokens.Row(surface.density)
	local trackWidth = 120

	local instance = surface:Create("TextButton", {
		Name = "Slider",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = surface:Color("well"),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, rowHeight),
	})

	local label = surface:Label({
		Name = "Text",
		Text = settings.text or "",
		TextColor3 = surface:Color("ink"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -(trackWidth + 72), 1, 0),
	})

	set(label, "Parent", instance)

	local valueLabel = surface:Label({
		Name = "Value",
		Text = formatNumber(value, step, settings.suffix or ""),
		Font = surface:Font("mono"),
		TextSize = surface:Text("mono"),
		TextColor3 = surface:Color("muted"),
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(0, 48, 1, 0),
		Position = UDim2.new(1, -48, 0, 0),
	})

	set(valueLabel, "Parent", instance)

	local track = surface:Create("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(trackWidth, Tokens.Size.sliderTrack),
		Position = UDim2.new(1, -(trackWidth + 56), 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = surface:Color("seam"),
		BorderSizePixel = 0,
		Active = true,
	})

	set(track, "Parent", instance)

	local fill = surface:Create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = surface:Color("accent"),
		BorderSizePixel = 0,
	})

	set(fill, "Parent", track)

	local knob = surface:Create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(Tokens.Size.sliderKnob, Tokens.Size.sliderKnob),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = surface:Color("accent"),
		BorderSizePixel = 0,
	})

	set(knob, "Parent", track)
	surface:Corner(knob, Tokens.Size.sliderKnob / 2)

	local stroke = surface:Stroke(instance, "focus", Tokens.Size.seam)
	set(stroke, "Transparency", 1)

	local slider = setmetatable({
		surface = surface,
		instance = instance,
		value = value,
		min = minimum,
		max = maximum,
		step = step,
		suffix = settings.suffix or "",
		enabled = settings.enabled ~= false,
		hovered = false,
		focused = false,
		dragging = false,
		destroyed = false,
		onChange = settings.onChange,
		_scope = Scope.new(),
		_track = track,
		_fill = fill,
		_knob = knob,
		_label = label,
		_valueLabel = valueLabel,
		_stroke = stroke,
	}, Slider)

	slider:Render()

	slider._scope:AddConnection((instance :: any).MouseEnter:Connect(function()
		slider.hovered = true
		slider:Render()
	end))

	slider._scope:AddConnection((instance :: any).MouseLeave:Connect(function()
		slider.hovered = false
		slider:Render()
	end))

	local function update(input: any)
		local absolute = (track :: any).AbsolutePosition
		local size = (track :: any).AbsoluteSize

		local nextValue = Slider.FromPointer(
			input.Position.X,
			absolute.X,
			size.X,
			slider.min,
			slider.max,
			slider.step
		)

		if nextValue ~= slider.value then
			slider.value = nextValue
			slider:Render()

			if slider.onChange then
				slider.onChange(nextValue)
			end
		end
	end

	slider._scope:AddConnection((track :: any).InputBegan:Connect(function(input: any)
		if not slider.enabled then
			return
		end

		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			slider.dragging = true
			update(input)
		end
	end))

	slider._scope:AddConnection(
		game:GetService("UserInputService").InputChanged:Connect(function(input: any)
			if not slider.dragging or not slider.enabled then
				return
			end

			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
				update(input)
			end
		end)
	)

	slider._scope:AddConnection(
		game:GetService("UserInputService").InputEnded:Connect(function(input: any)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				slider.dragging = false
			end
		end)
	)

	surface.scope:Add(slider)

	return slider
end

function Slider:Render()
	if self.destroyed then
		return
	end

	local row = State.Resolve("row", {
		enabled = self.enabled,
		hovered = self.hovered,
		focused = self.focused,
	})

	if row.background then
		set(self.instance, "BackgroundTransparency", 0)
		set(self.instance, "BackgroundColor3", self.surface:Color(row.background))
	else
		set(self.instance, "BackgroundTransparency", 1)
	end

	if row.stroke then
		set(self._stroke, "Color", self.surface:Color(row.stroke))
		set(self._stroke, "Transparency", 0)
	else
		set(self._stroke, "Transparency", 1)
	end

	local ratio = Slider.Ratio(self.value, self.min, self.max)
	set(self._fill, "Size", UDim2.new(ratio, 0, 1, 0))
	set(self._knob, "Position", UDim2.new(ratio, 0, 0.5, 0))

	local activeToken = if self.enabled then "accent" else "seamStrong"
	set(self._fill, "BackgroundColor3", self.surface:Color(activeToken))
	set(self._knob, "BackgroundColor3", self.surface:Color(activeToken))
	set(self._label, "TextColor3", self.surface:Color(if self.enabled then "ink" else "faint"))
	set(
		self._valueLabel,
		"TextColor3",
		self.surface:Color(if self.enabled then "muted" else "faint")
	)
	set(self._valueLabel, "Text", formatValue(self))
end

function Slider:SetValue(value: number)
	if self.destroyed then
		return
	end

	self.value = Slider.Snap(value, self.min, self.max, self.step)
	self:Render()
end

function Slider:GetValue(): number
	return self.value
end

function Slider:Step(direction: number)
	if self.destroyed or not self.enabled then
		return
	end

	local nextValue = Slider.Snap(self.value + self.step * direction, self.min, self.max, self.step)

	if nextValue ~= self.value then
		self.value = nextValue
		self:Render()

		if self.onChange then
			self.onChange(nextValue)
		end
	end
end

function Slider:SetEnabled(value: boolean)
	self.enabled = value
	self:Render()
end

function Slider:SetVisible(value: boolean)
	set(self.instance, "Visible", value)
end

function Slider:SetFocus(value: boolean)
	if self.destroyed then
		return
	end

	if value and not self.enabled then
		return
	end

	self.focused = value
	self:Render()
end

function Slider:Focus()
	self:SetFocus(true)
end

function Slider:Blur()
	self:SetFocus(false)
end

-- Arrow keys are the keyboard equivalent of dragging one notch. It is the same
-- snapped Step the pointer path uses, so both inputs reach identical values.
function Slider:Nudge(direction: number)
	self:Step(direction)
end

function Slider:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Slider

--!strict
-- Basalt / components / ColorPicker
-- Three HSV sliders in an inline panel, not a floating square. The panel lives
-- in the page flow, so it works the same on touch, on a gamepad and under a
-- screen reader, and the keyboard can reach every slider without an overlay
-- owning the arrow keys.
--
-- The conversion below is plain arithmetic instead of Color3.fromHSV/ToHSV, so
-- the same numbers are produced in a headless test and in the engine.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local State = require(script.Parent.Parent.runtime.State)
local Layout = require(script.Parent.Parent.runtime.Layout)
local Focus = require(script.Parent.Parent.runtime.Focus)

local Slider = require(script.Parent.Slider)

export type Config = {
	text: string?,
	value: Color3?,
	enabled: boolean?,
	onChange: ((value: Color3) -> ())?,
}

export type ColorPicker = {
	surface: Surface.Surface,
	instance: Instance,
	value: Color3,
	hue: number,
	saturation: number,
	brightness: number,
	open: boolean,
	enabled: boolean,
	hovered: boolean,
	focused: boolean,
	destroyed: boolean,
	onChange: ((value: Color3) -> ())?,
	_scope: Scope.Scope,
	_row: Instance,
	_label: Instance,
	_chip: Instance,
	_stroke: Instance,
	_swatch: Instance,
	_hex: Instance,
	_panel: Instance,
	_preview: Instance,
	_hue: Slider.Slider,
	_sat: Slider.Slider,
	_val: Slider.Slider,
	_focus: Focus.Focus?,

	Render: (self: ColorPicker) -> (),
	Open: (self: ColorPicker) -> (),
	Close: (self: ColorPicker) -> (),
	Toggle: (self: ColorPicker) -> (),
	IsOpen: (self: ColorPicker) -> boolean,
	GetValue: (self: ColorPicker) -> Color3,
	SetValue: (self: ColorPicker, value: Color3) -> (),
	SetEnabled: (self: ColorPicker, value: boolean) -> (),
	SetVisible: (self: ColorPicker, value: boolean) -> (),
	SetFocus: (self: ColorPicker, value: boolean) -> (),
	Focus: (self: ColorPicker) -> (),
	Blur: (self: ColorPicker) -> (),
	Activate: (self: ColorPicker) -> (),
	Destroy: (self: ColorPicker) -> (),
}

local ColorPicker = {}
ColorPicker.__index = ColorPicker

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

-- h in [0, 360), s and v in [0, 1].
function ColorPicker.ToColor(h: number, s: number, v: number): Color3
	local hue = (h % 360) / 60
	local saturation = clamp01(s)
	local brightness = clamp01(v)
	local chroma = brightness * saturation
	local x = chroma * (1 - math.abs(hue % 2 - 1))
	local m = brightness - chroma
	local r, g, b = 0, 0, 0

	if hue < 1 then
		r, g = chroma, x
	elseif hue < 2 then
		r, g = x, chroma
	elseif hue < 3 then
		g, b = chroma, x
	elseif hue < 4 then
		g, b = x, chroma
	elseif hue < 5 then
		r, b = x, chroma
	else
		r, b = chroma, x
	end

	return Color3.fromRGB(
		math.floor((r + m) * 255 + 0.5),
		math.floor((g + m) * 255 + 0.5),
		math.floor((b + m) * 255 + 0.5)
	)
end

function ColorPicker.ToHSV(color: Color3): (number, number, number)
	local r, g, b = color.R, color.G, color.B
	local maximum = math.max(r, g, b)
	local minimum = math.min(r, g, b)
	local delta = maximum - minimum
	local hue = 0

	if delta > 0 then
		if maximum == r then
			hue = 60 * (((g - b) / delta) % 6)
		elseif maximum == g then
			hue = 60 * ((b - r) / delta + 2)
		else
			hue = 60 * ((r - g) / delta + 4)
		end
	end

	local saturation = if maximum == 0 then 0 else delta / maximum

	return hue % 360, saturation, maximum
end

local function hex(color: Color3): string
	return color:ToHex()
end

function ColorPicker.new(
	surface: Surface.Surface,
	config: Config?,
	focus: Focus.Focus?
): ColorPicker
	local settings = config or {}
	local value = settings.value or surface:Color("accent")
	local h, s, v = ColorPicker.ToHSV(value)
	local rowHeight = Tokens.Row(surface.density)
	local chipWidth = 104

	local instance = surface:Frame({
		Name = "ColorPicker",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, rowHeight),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	local row = surface:Create("TextButton", {
		Name = "Row",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = surface:Color("well"),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, rowHeight),
	})

	set(row, "Parent", instance)

	local label = surface:Label({
		Name = "Text",
		Text = settings.text or "",
		TextColor3 = surface:Color("ink"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -(chipWidth + Tokens.Space.xxl), 1, 0),
	})

	set(label, "Parent", row)

	local chip = surface:Raised({
		Name = "Chip",
		Size = UDim2.fromOffset(chipWidth, rowHeight - 12),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Tokens.Space.lg, 0.5, 0),
	})

	set(chip, "Parent", row)
	surface:Corner(chip, Tokens.Size.radiusControl)

	local stroke = surface:Stroke(chip, "seam")
	local swatch = surface:Frame({
		Name = "Swatch",
		BackgroundColor3 = value,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0, Tokens.Space.sm, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
	})

	set(swatch, "Parent", chip)
	surface:Corner(swatch, Tokens.Size.radiusControl)

	local hexLabel = surface:Label({
		Name = "Hex",
		Text = hex(value),
		Font = surface:Font("mono"),
		TextSize = surface:Text("mono"),
		TextColor3 = surface:Color("muted"),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -(Tokens.Space.xxl + Tokens.Space.sm), 1, 0),
		Position = UDim2.new(0, Tokens.Space.xxl, 0, 0),
	})

	set(hexLabel, "Parent", chip)

	local panel = surface:Frame({
		Name = "Panel",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, rowHeight),
		Visible = false,
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	set(panel, "Parent", instance)
	Layout.List(surface, panel, { padding = Tokens.Space.sm })

	local preview = surface:Frame({
		Name = "Preview",
		BackgroundColor3 = value,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
	})

	set(preview, "Parent", panel)
	surface:Corner(preview, Tokens.Size.radiusControl)
	surface:Stroke(preview, "seam")

	local hue = Slider.new(surface, {
		text = "Hue",
		min = 0,
		max = 360,
		step = 1,
		value = h,
		suffix = "\u{00B0}",
	})

	local saturation = Slider.new(surface, {
		text = "Saturation",
		min = 0,
		max = 100,
		step = 1,
		value = s * 100,
		suffix = "%",
	})

	local brightness = Slider.new(surface, {
		text = "Brightness",
		min = 0,
		max = 100,
		step = 1,
		value = v * 100,
		suffix = "%",
	})

	local picker: ColorPicker

	local function changed(): ()
		picker.hue = picker._hue:GetValue()
		picker.saturation = picker._sat:GetValue() / 100
		picker.brightness = picker._val:GetValue() / 100
		picker.value = ColorPicker.ToColor(picker.hue, picker.saturation, picker.brightness)
		picker:Render()

		if picker.onChange then
			picker.onChange(picker.value)
		end
	end

	picker = setmetatable({
		surface = surface,
		instance = instance,
		value = ColorPicker.ToColor(h, s, v),
		hue = h,
		saturation = s,
		brightness = v,
		open = false,
		enabled = settings.enabled ~= false,
		hovered = false,
		focused = false,
		destroyed = false,
		onChange = settings.onChange,
		_scope = Scope.new(),
		_row = row,
		_label = label,
		_chip = chip,
		_stroke = stroke,
		_swatch = swatch,
		_hex = hexLabel,
		_panel = panel,
		_preview = preview,
		_hue = hue,
		_sat = saturation,
		_val = brightness,
		_focus = focus,
	}, ColorPicker)

	hue.onChange = function()
		changed()
	end

	saturation.onChange = function()
		changed()
	end

	brightness.onChange = function()
		changed()
	end

	for index, slider in ipairs({ hue, saturation, brightness }) do
		slider.instance.LayoutOrder = index + 1
		set(slider.instance, "Parent", panel)
		picker._scope:Add(slider)

		if focus then
			focus:Track(slider, { group = "page" })
		end
	end

	-- Slider snaps its initial value to the step; the stored HSV follows the
	-- sliders, but the color itself is preserved exactly as configured. A saved
	-- #66AACC must not become #66ABCC because a slider rounds to whole percent.
	picker.hue = hue:GetValue()
	picker.saturation = saturation:GetValue() / 100
	picker.brightness = brightness:GetValue() / 100
	picker.value = value

	picker._scope:AddConnection((row :: any).MouseEnter:Connect(function()
		picker.hovered = true
		picker:Render()
	end))

	picker._scope:AddConnection((row :: any).MouseLeave:Connect(function()
		picker.hovered = false
		picker:Render()
	end))

	picker._scope:AddConnection((row :: any).MouseButton1Click:Connect(function()
		picker:Activate()
	end))

	picker:Render()
	surface.scope:Add(picker)

	return picker
end

function ColorPicker:Render()
	if self.destroyed then
		return
	end

	local row = State.Resolve("row", {
		enabled = self.enabled,
		hovered = self.hovered,
		focused = self.focused,
		selected = self.open,
	})

	if row.background then
		set(self._row, "BackgroundTransparency", 0)
		set(self._row, "BackgroundColor3", self.surface:Color(row.background))
	else
		set(self._row, "BackgroundTransparency", 1)
	end

	set(self._swatch, "BackgroundColor3", self.value)
	set(self._preview, "BackgroundColor3", self.value)
	set(self._hex, "Text", hex(self.value))
	set(self._label, "TextColor3", self.surface:Color(if self.enabled then "ink" else "faint"))
	set(self._hex, "TextColor3", self.surface:Color(if self.enabled then "muted" else "faint"))
	set(self._panel, "Visible", self.open)

	local strokeColor = "seam"

	if self.open or self.focused then
		strokeColor = "focus"
	elseif not self.enabled then
		strokeColor = "seam"
	end

	set(self._stroke, "Color", self.surface:Color(strokeColor))
end

function ColorPicker:Open()
	if self.destroyed or not self.enabled or self.open then
		return
	end

	self.open = true
	self:Render()
end

function ColorPicker:Close()
	if self.destroyed or not self.open then
		return
	end

	self.open = false

	local current = if self._focus then self._focus:Current() else nil

	if current == self._hue or current == self._sat or current == self._val then
		self._focus:Set(self)
	end

	self:Render()
end

function ColorPicker:Toggle()
	if self.open then
		self:Close()
	else
		self:Open()
	end
end

function ColorPicker:IsOpen(): boolean
	return self.open
end

function ColorPicker:GetValue(): Color3
	return self.value
end

-- Programmatic values never fire onChange, so loading a saved palette does not
-- call the user's callback for every picker on the page.
function ColorPicker:SetValue(value: Color3)
	if self.destroyed then
		return
	end

	local h, s, v = ColorPicker.ToHSV(value)

	self.hue = h
	self.saturation = s
	self.brightness = v
	self.value = value

	self._hue:SetValue(h)
	self._sat:SetValue(s * 100)
	self._val:SetValue(v * 100)

	self.hue = self._hue:GetValue()
	self.saturation = self._sat:GetValue() / 100
	self.brightness = self._val:GetValue() / 100
	self.value = value
	self:Render()
end

function ColorPicker:SetEnabled(value: boolean)
	if self.destroyed then
		return
	end

	self.enabled = value

	if not value then
		self.open = false
	end

	self:Render()
end

function ColorPicker:SetVisible(value: boolean)
	if not value then
		self.open = false
	end

	set(self.instance, "Visible", value)
end

function ColorPicker:SetFocus(value: boolean)
	if self.destroyed then
		return
	end

	if value and not self.enabled then
		return
	end

	self.focused = value
	self:Render()
end

function ColorPicker:Focus()
	self:SetFocus(true)
end

function ColorPicker:Blur()
	self:SetFocus(false)
end

function ColorPicker:Activate()
	if not self.enabled or self.destroyed then
		return
	end

	self:Toggle()
end

function ColorPicker:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true

	if self._focus then
		self._focus:Untrack(self._hue)
		self._focus:Untrack(self._sat)
		self._focus:Untrack(self._val)
	end

	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return ColorPicker

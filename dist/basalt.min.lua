



local __defs = {}
local __cache = {}

local function __require(id)
	local cached = __cache[id]
	if cached ~= nil then
		return cached
	end

	local definition = __defs[id]
	if not definition then
		error("Basalt: missing module '" .. tostring(id) .. "'", 2)
	end

	local result = definition()
	__cache[id] = result
	return result
end

__defs["init"] = function()







local Themes = __require("design.Themes.init")
local Palette = __require("design.Palette")
local Surface = __require("runtime.Surface")
local Window = __require("components.Window")

local VERSION = "0.2.0"

export type Config = {
	theme: string?,
	density: "auto" | Surface.Density?,
	motion: "full" | "reduced"?,
	toggleKey: Enum.KeyCode?,
	displayOrder: number?,
}

export type App = {
	version: string,
	theme: string,
	density: Surface.Density,
	motion: "full" | "reduced",
	toggleKey: Enum.KeyCode?,
	surface: Surface.Surface,
	displayOrder: number,
	_window: Window.Window?,
	window: (self: App, config: Window.Config?) -> Window.Window,
	Destroy: (self: App) -> (),
}

local App = {}
App.__index = App

local function theme(name: string)
	return Themes.Get(name)
end

local function themeNames(): { string }
	return table.clone(Themes.Names)
end

local function audit(name: string)
	return Palette.Audit(Themes.Get(name))
end





local function resolveDensity(requested: string?): Surface.Density
	if requested == "compact" or requested == "comfortable" then
		return requested
	end

	if requested ~= nil and requested ~= "auto" then
		error(
			string.format(
				"Basalt: unknown density '%s'. Available: auto, compact, comfortable",
				tostring(requested)
			),
			3
		)
	end

	local ok, comfortable = pcall(function()
		local service = game:GetService("UserInputService")

		if type(service.GetLastInputType) == "function" then
			local last = service:GetLastInputType()

			if last == Enum.UserInputType.Touch or last == Enum.UserInputType.Gamepad1 then
				return true
			end

			if
				last == Enum.UserInputType.Keyboard
				or last == Enum.UserInputType.MouseButton1
				or last == Enum.UserInputType.MouseMovement
			then
				return false
			end
		end

		return service.TouchEnabled == true and service.KeyboardEnabled ~= true
	end)

	if ok and comfortable == true then
		return "comfortable"
	end

	return "compact"
end

local function new(config: Config?): App
	local settings = config or {}
	local themeName = settings.theme or "graphite"

	if not Themes.Has(themeName) then
		error(
			string.format(
				"Basalt: unknown theme '%s'. Available: %s",
				tostring(themeName),
				table.concat(Themes.Names, ", ")
			),
			2
		)
	end

	local density = resolveDensity(settings.density)
	local motion = settings.motion or "full"

	local surface = Surface.new({
		theme = Themes.Get(themeName),
		density = density,
		motion = motion,
	})

	local app = setmetatable({
		version = VERSION,
		theme = themeName,
		density = density,
		motion = motion,
		toggleKey = settings.toggleKey,
		surface = surface,
		_window = nil :: Window.Window?,
		displayOrder = settings.displayOrder or 0,
	}, App)

	return app
end

function App:window(config: Window.Config?): Window.Window
	if self._window and not self._window.destroyed then
		self._window:Destroy()
	end

	local window = Window.new(self.surface, {
		title = (config and config.title) or nil,
		subtitle = (config and config.subtitle) or nil,
		width = (config and config.width) or nil,
		height = (config and config.height) or nil,
		resizable = (config and config.resizable),
		minimizable = (config and config.minimizable),
		closable = (config and config.closable),
		displayOrder = self.displayOrder,
		position = (config and config.position) or nil,
		toggleKey = (config and config.toggleKey) or self.toggleKey,
	})

	self._window = window

	return window
end

function App:Destroy()
	if self._window then
		self._window:Destroy()
		self._window = nil
	end

	self.surface:Destroy()
end

local Basalt = {
	version = VERSION,
	new = new,
	theme = theme,
	themeNames = themeNames,
	audit = audit,
}

return Basalt
end

__defs["components.Badge"] = function()






local Tokens = __require("design.Tokens")
local Surface = __require("runtime.Surface")

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
end

__defs["components.Button"] = function()






local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local State = __require("runtime.State")

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
end

__defs["components.ColorPicker"] = function()










local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local State = __require("runtime.State")
local Layout = __require("runtime.Layout")
local Focus = __require("runtime.Focus")

local Slider = __require("components.Slider")

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
end

__defs["components.Console"] = function()










local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local VirtualList = __require("runtime.VirtualList")

export type Level = "info" | "warn" | "error" | "success"

export type Entry = {
	text: string,
	level: Level,
	stamp: string?,
}

export type Config = {
	title: string?,
	height: number?,
	rowHeight: number?,
	maxLines: number?,
	timestamps: boolean?,
	follow: boolean?,
	emptyText: string?,
}

export type Console = {
	surface: Surface.Surface,
	instance: Instance,
	entries: { Entry },
	maxLines: number,
	timestamps: boolean,
	follow: boolean,
	destroyed: boolean,
	_scope: Scope.Scope,
	_title: Instance?,
	_empty: Instance,
	_list: VirtualList.VirtualList,

	Render: (self: Console) -> (),
	Log: (self: Console, text: string, level: Level?) -> (),
	Clear: (self: Console) -> (),
	GetCount: (self: Console) -> number,
	GetEntries: (self: Console) -> { Entry },
	SetVisible: (self: Console, value: boolean) -> (),
	Destroy: (self: Console) -> (),
}

local Console = {}
Console.__index = Console

local HEADER_HEIGHT = 22

local TONE: { [string]: string } = {
	info = "muted",
	warn = "accent",
	error = "danger",
	success = "success",
}

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local function stamp(): string
	local ok, value = pcall(function()
		return os.date("%H:%M:%S")
	end)

	return if ok and type(value) == "string" then string.format("[%s] ", value) else ""
end

function Console.new(surface: Surface.Surface, config: Config?): Console
	local settings = config or {}
	local rowHeight = settings.rowHeight or Tokens.Row(surface.density)
	local height = settings.height or rowHeight * 5
	local maxLines = math.max(1, math.floor(settings.maxLines or 200))

	local instance = surface:Frame({
		Name = "Console",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + Tokens.Size.seam + height),
	})

	local header = surface:Frame({
		Name = "Header",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
	})

	set(header, "Parent", instance)

	local title: Instance? = nil

	if settings.title then
		local label = surface:Label({
			Name = "Title",
			Text = settings.title,
			Font = surface:Font("small"),
			TextSize = surface:Text("small"),
			TextColor3 = surface:Color("muted"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 2,
		})

		set(label, "Parent", header)
		title = label
	end

	local seam = surface:Frame({
		Name = "Seam",
		BackgroundColor3 = surface:Color("seam"),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, Tokens.Size.seam),
		Position = UDim2.new(0, 0, 1, -Tokens.Size.seam),
	})

	set(seam, "Parent", header)

	local empty = surface:Label({
		Name = "Empty",
		Text = settings.emptyText or "No logs",
		Font = surface:Font("body"),
		TextSize = surface:Text("small"),
		TextColor3 = surface:Color("muted"),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + Tokens.Size.seam),
	})

	set(empty, "Parent", instance)

	local list = VirtualList.new(surface, instance, {
		rowHeight = rowHeight,
		height = height,
		count = 0,
		zIndex = 2,
	})

	set(list.frame, "Position", UDim2.new(0, 0, 0, HEADER_HEIGHT + Tokens.Size.seam))

	local console = setmetatable({
		surface = surface,
		instance = instance,
		entries = {},
		maxLines = maxLines,
		timestamps = settings.timestamps ~= false,
		follow = settings.follow ~= false,
		destroyed = false,
		_scope = Scope.new(),
		_title = title,
		_empty = empty,
		_list = list,
	}, Console)

	console._scope:Add(list)

	
	
	list:SetRender(function(index: number, row: Instance)
		local label = (row :: any):FindFirstChild("Line")

		if not label then
			label = surface:Label({
				Name = "Line",
				Text = "",
				Font = surface:Font("mono"),
				TextSize = surface:Text("mono"),
				TextColor3 = surface:Color("muted"),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Size = UDim2.new(1, -Tokens.Space.sm, 1, 0),
				Position = UDim2.new(0, Tokens.Space.xs, 0, 0),
				ZIndex = 4,
			})

			set(label, "Parent", row)
		end

		local entry = console.entries[index]

		if entry then
			local prefix = if console.timestamps then entry.stamp or "" else ""
			set(label, "Text", prefix .. entry.text)
			set(label, "TextColor3", surface:Color(TONE[entry.level]))
		end
	end)

	console:Render()
	surface.scope:Add(console)

	return console
end

function Console:Render()
	if self.destroyed then
		return
	end

	local count = #self.entries

	set(self._empty, "Visible", count == 0)
	set(self._list.frame, "Visible", count > 0)
	self._list:SetCount(count)
end

function Console:Log(text: string, level: Level?)
	if self.destroyed then
		return
	end

	local entry: Entry = {
		text = tostring(text),
		level = level or "info",
		stamp = if self.timestamps then stamp() else nil,
	}

	if not TONE[entry.level] then
		entry.level = "info"
	end

	
	
	
	local wasAtBottom = true

	if #self.entries > 0 then
		local bottom = math.max(0, #self.entries * self._list.rowHeight - self._list.height)
		wasAtBottom = (self._list.frame :: any).CanvasPosition.Y >= bottom - self._list.rowHeight
	end

	table.insert(self.entries, entry)

	while #self.entries > self.maxLines do
		table.remove(self.entries, 1)
	end

	self:Render()

	if self.follow and wasAtBottom then
		self._list:ScrollToIndex(#self.entries)
	end
end

function Console:Clear()
	if self.destroyed then
		return
	end

	table.clear(self.entries)
	self._list:SetCount(0)
	self:Render()
end

function Console:GetCount(): number
	return #self.entries
end

function Console:GetEntries(): { Entry }
	return table.clone(self.entries)
end

function Console:SetVisible(value: boolean)
	set(self.instance, "Visible", value)
end

function Console:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Console
end

__defs["components.Divider"] = function()





local Tokens = __require("design.Tokens")
local Surface = __require("runtime.Surface")

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
end

__defs["components.Dropdown"] = function()










local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local State = __require("runtime.State")
local VirtualList = __require("runtime.VirtualList")

export type Option = string | {
	text: string?,
	value: any?,
	disabled: boolean?,
}

export type Config = {
	text: string?,
	note: string?,
	options: { Option }?,
	value: any?,
	multi: boolean?,
	placeholder: string?,
	enabled: boolean?,
	maxRows: number?,
	onChange: ((value: any) -> ())?,
}

type Normalized = {
	text: string,
	value: any,
	disabled: boolean,
}

type RowView = {
	button: Instance,
	label: Instance,
	check: Instance,
	bar: Instance,
}

export type Dropdown = {
	surface: Surface.Surface,
	instance: Instance,
	field: Instance,
	value: any,
	enabled: boolean,
	hovered: boolean,
	focused: boolean,
	open: boolean,
	destroyed: boolean,
	onChange: ((value: any) -> ())?,
	multi: boolean,
	placeholder: string,
	_maxRows: number,
	_options: { Normalized },
	_views: { [Instance]: RowView },
	_rowIndex: { [Instance]: number },
	_scope: Scope.Scope,
	_stroke: Instance,
	_label: Instance,
	_valueLabel: Instance,
	_popup: Instance,
	_empty: Instance,
	_list: VirtualList.VirtualList,
	_layer: any,
	_highlight: number,
	_hoverIndex: number?,
	_values: { any },

	Render: (self: Dropdown) -> (),
	Open: (self: Dropdown) -> boolean,
	Close: (self: Dropdown) -> (),
	Toggle: (self: Dropdown) -> (),
	IsOpen: (self: Dropdown) -> boolean,
	SetOptions: (self: Dropdown, options: { Option }) -> (),
	SetValue: (self: Dropdown, value: any) -> (),
	GetValue: (self: Dropdown) -> any,
	SetEnabled: (self: Dropdown, value: boolean) -> (),
	SetVisible: (self: Dropdown, value: boolean) -> (),
	Activate: (self: Dropdown) -> (),
	HandleAction: (self: Dropdown, action: string) -> boolean,
	Dismiss: (self: Dropdown, input: any) -> boolean,
	SetFocus: (self: Dropdown, value: boolean) -> (),
	Focus: (self: Dropdown) -> (),
	Blur: (self: Dropdown) -> (),
	Destroy: (self: Dropdown) -> (),
}

local Dropdown = {}
Dropdown.__index = Dropdown

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local function normalize(options: { Option }?): { Normalized }
	local result: { Normalized } = {}

	for _, option in ipairs(options or {}) do
		if type(option) == "string" then
			table.insert(result, { text = option, value = option, disabled = false })
		elseif type(option) == "table" then
			local text = option.text or tostring(option.value)

			table.insert(result, {
				text = text,
				value = if option.value ~= nil then option.value else text,
				disabled = option.disabled == true,
			})
		else
			error("Basalt: dropdown option must be a string or a table with text", 3)
		end
	end

	return result
end

local function sameList(left: { any }, right: { any }): boolean
	if #left ~= #right then
		return false
	end

	for index = 1, #left do
		if left[index] ~= right[index] then
			return false
		end
	end

	return true
end



local function pointOf(value: any): Vector2
	return Vector2.new(value.X, value.Y)
end

function Dropdown.new(surface: Surface.Surface, config: Config?, layer: any): Dropdown
	if not layer then
		error(
			"Basalt: a Dropdown needs the window overlay layer; add it through Section:Dropdown",
			2
		)
	end

	local settings = config or {}
	local density = surface.density
	local rowHeight = Tokens.Row(density)
	local noteText = settings.note
	local outerHeight = rowHeight + (if noteText then 18 else 0)

	local instance = surface:Frame({
		Name = "Dropdown",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, outerHeight),
	})

	local field = surface:Create("TextButton", {
		Name = "Field",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = surface:Color("well"),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, rowHeight),
	})

	set(field, "Parent", instance)
	surface:Corner(field, Tokens.Size.radiusControl)

	local stroke = surface:Stroke(field, "seam")

	local hasText = settings.text ~= nil and settings.text ~= ""

	local label = surface:Label({
		Name = "Text",
		Text = settings.text or "",
		TextColor3 = surface:Color("ink"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = if hasText then UDim2.new(0.5, -20, 1, 0) else UDim2.new(0, 0, 1, 0),
		Position = UDim2.fromOffset(Tokens.Space.md, 0),
	})

	set(label, "Parent", field)

	local valueLabel = surface:Label({
		Name = "Value",
		Text = settings.placeholder or "Select",
		TextColor3 = surface:Color("muted"),
		TextXAlignment = if hasText then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = if hasText then UDim2.new(0.5, -12, 1, 0) else UDim2.new(1, -16, 1, 0),
		Position = if hasText
			then UDim2.new(0.5, 4, 0, 0)
			else UDim2.fromOffset(Tokens.Space.md, 0),
	})

	set(valueLabel, "Parent", field)

	if noteText then
		local note = surface:Label({
			Name = "Note",
			Text = noteText,
			Font = surface:Font("small"),
			TextSize = surface:Text("small"),
			TextColor3 = surface:Color("muted"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.fromOffset(0, rowHeight + 2),
		})

		set(note, "Parent", instance)
	end

	local maxRows = math.max(1, settings.maxRows or 6)
	local listHeight = maxRows * rowHeight

	local popup = surface:Raised({
		Name = "DropdownPopup",
		Size = UDim2.fromOffset(240, listHeight + Tokens.Space.md),
		Visible = false,
		ZIndex = 60,
		ClipsDescendants = true,
	})

	surface:Corner(popup, Tokens.Size.radiusPanel)
	surface:Stroke(popup, "seamStrong")

	if layer then
		set(popup, "Parent", layer.frame)
	end

	local holder = surface:Frame({
		Name = "Holder",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -Tokens.Space.md, 1, -Tokens.Space.md),
		Position = UDim2.fromOffset(Tokens.Space.xs, Tokens.Space.xs),
		ZIndex = 61,
	})

	set(holder, "Parent", popup)

	local list = VirtualList.new(surface, holder, {
		rowHeight = rowHeight,
		height = listHeight,
		zIndex = 62,
	})

	local empty = surface:Label({
		Name = "Empty",
		Text = "No options",
		Font = surface:Font("small"),
		TextSize = surface:Text("small"),
		TextColor3 = surface:Color("faint"),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -Tokens.Space.md, 0, rowHeight),
		Position = UDim2.fromOffset(Tokens.Space.sm, 0),
		Visible = false,
		ZIndex = 62,
	})

	set(empty, "Parent", popup)

	local dropdown = setmetatable({
		surface = surface,
		instance = instance,
		field = field,
		value = settings.value,
		enabled = settings.enabled ~= false,
		hovered = false,
		focused = false,
		open = false,
		destroyed = false,
		onChange = settings.onChange,
		multi = settings.multi == true,
		placeholder = settings.placeholder or "Select",
		_maxRows = maxRows,
		_options = normalize(settings.options),
		_views = {},
		_rowIndex = {},
		_scope = Scope.new(),
		_stroke = stroke,
		_label = label,
		_valueLabel = valueLabel,
		_popup = popup,
		_empty = empty,
		_list = list,
		_layer = layer,
		_highlight = 0,
		_hoverIndex = nil,
		_values = {},
	}, Dropdown)

	
	
	if dropdown.multi and type(settings.value) == "table" then
		for _, value in ipairs(settings.value) do
			if table.find(dropdown._values, value) == nil then
				table.insert(dropdown._values, value)
			end
		end
	end

	list:SetRender(function(index: number, row: Instance)
		dropdown:_renderRow(index, row)
	end)

	dropdown._scope:AddConnection((field :: any).MouseEnter:Connect(function()
		dropdown.hovered = true
		dropdown:Render()
	end))

	dropdown._scope:AddConnection((field :: any).MouseLeave:Connect(function()
		dropdown.hovered = false
		dropdown:Render()
	end))

	dropdown._scope:AddConnection((field :: any).MouseButton1Click:Connect(function()
		dropdown:Toggle()
	end))

	dropdown:Render()

	return dropdown
end

function Dropdown:_find(value: any): number?
	for index, option in ipairs(self._options) do
		if option.value == value then
			return index
		end
	end

	return nil
end

function Dropdown:GetValue(): any
	if self.multi then
		return table.clone(self._values)
	end

	return self.value
end

function Dropdown:_selected(value: any): boolean
	if self.multi then
		return table.find(self._values, value) ~= nil
	end

	return self.value == value
end

function Dropdown:_display(): (string, boolean)
	if self.multi then
		local texts = {}

		for _, value in ipairs(self._values) do
			local index = self:_find(value)

			if index then
				table.insert(texts, self._options[index].text)
			end
		end

		if #texts == 0 then
			return self.placeholder, false
		end

		if #texts == 1 then
			return texts[1], true
		end

		return string.format("%d selected", #texts), true
	end

	if self.value == nil then
		return self.placeholder, false
	end

	local index = self:_find(self.value)

	if index then
		return self._options[index].text, true
	end

	
	
	return tostring(self.value), true
end

function Dropdown:Render()
	if self.destroyed then
		return
	end

	local style = State.Resolve("field", {
		enabled = self.enabled,
		hovered = self.hovered,
		focused = self.focused,
		selected = self.open,
	})

	set(self.field, "BackgroundColor3", self.surface:Color(style.background or "well"))
	set(self._stroke, "Color", self.surface:Color(style.stroke or "seam"))
	set(self._stroke, "Transparency", if style.stroke then 0 else 1)

	local text, hasValue = self:_display()
	set(self._valueLabel, "Text", text)
	set(
		self._valueLabel,
		"TextColor3",
		self.surface:Color(if not self.enabled then "faint" elseif hasValue then "ink" else "muted")
	)
	set(self._label, "TextColor3", self.surface:Color(if self.enabled then "ink" else "faint"))

	local empty = #self._options == 0
	set(self._empty, "Visible", self.open and empty)
	set(self._list.frame, "Visible", not empty)

	if self.open then
		self._list:Refresh(true)
	end
end

function Dropdown:SetOptions(options: { Option })
	if self.destroyed then
		return
	end

	self._options = normalize(options)
	self._highlight = 0
	self._hoverIndex = nil
	self._list:SetCount(#self._options)

	if self.open then
		self._highlight = self:_firstEnabled()
		self:_layout()
		self._list:ScrollToIndex(math.max(1, self._highlight))
	end

	self:Render()
end

function Dropdown:_firstEnabled(): number
	for index, option in ipairs(self._options) do
		if not option.disabled then
			return index
		end
	end

	return 0
end

function Dropdown:_visibleRows(): number
	return math.min(#self._options, self._maxRows)
end



function Dropdown:_layout()
	if not self._layer then
		return
	end

	local layerWidth = self._layer:Pixels((self._layer.frame :: any).AbsoluteSize.X)
	local layerHeight = self._layer:Pixels((self._layer.frame :: any).AbsoluteSize.Y)
	local point = self._layer:ToLocal((self.field :: any).AbsolutePosition)
	local fieldSize = (self.field :: any).AbsoluteSize
	local fieldWidth = self._layer:Pixels(fieldSize.X)
	local fieldHeight = self._layer:Pixels(fieldSize.Y)

	local rows = math.max(1, self:_visibleRows())
	local height = math.min(rows * self._list.rowHeight + Tokens.Space.md, layerHeight)
	local width = math.max(0, math.min(math.max(fieldWidth, 180), layerWidth))
	local x = math.clamp(point.X, 0, math.max(0, layerWidth - width))

	local below = point.Y + fieldHeight + Tokens.Space.xs
	local above = point.Y - height - Tokens.Space.xs

	if below + height > layerHeight and above >= 0 then
		below = above
	elseif below + height > layerHeight then
		below = math.max(0, layerHeight - height)
	end

	set(self._popup, "Position", UDim2.fromOffset(x, below))
	set(self._popup, "Size", UDim2.fromOffset(width, height))
	self._list:SetSize(math.max(self._list.rowHeight, height - Tokens.Space.md))
end

function Dropdown:Open(): boolean
	if self.destroyed or not self.enabled or self.open or not self._layer then
		return false
	end

	self.open = true
	self._highlight = self:_firstEnabled()

	if self.multi then
		for _, value in ipairs(self._values) do
			local index = self:_find(value)

			if index and self._highlight == 0 then
				self._highlight = index
			end
		end
	elseif self.value ~= nil then
		local index = self:_find(self.value)

		if index then
			self._highlight = index
		end
	end

	if self._layer then
		set(self._popup, "Parent", self._layer.frame)
		set(self._popup, "Visible", true)
		self._list:SetCount(#self._options)
		self._layer:Push(self)
	end

	self:_layout()
	self._list:ScrollToIndex(math.max(1, self._highlight))
	self:Render()

	return true
end

function Dropdown:Close()
	if not self.open then
		return
	end

	self.open = false
	set(self._popup, "Visible", false)
	self._hoverIndex = nil

	if self._layer then
		self._layer:Pop(self)
	end

	self:Render()
end

function Dropdown:Toggle()
	if self.open then
		self:Close()
	else
		self:Open()
	end
end

function Dropdown:IsOpen(): boolean
	return self.open
end

function Dropdown:_buildRow(row: Instance): RowView
	local button = self.surface:Create("TextButton", {
		Name = "Option",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 64,
	})

	set(button, "Parent", row)

	local bar = self.surface:Frame({
		Name = "Bar",
		BackgroundColor3 = self.surface:Color("accent"),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 1, 0),
		Visible = false,
		ZIndex = 65,
	})

	set(bar, "Parent", button)

	local check = self.surface:Frame({
		Name = "Check",
		BackgroundColor3 = self.surface:Color("accent"),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.new(0, Tokens.Space.md, 0.5, -6),
		Visible = self.multi,
		ZIndex = 65,
	})

	set(check, "Parent", button)
	self.surface:Corner(check, 1)
	self.surface:Stroke(check, "seamStrong")

	local label = self.surface:Label({
		Name = "Text",
		Text = "",
		TextColor3 = self.surface:Color("ink"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -(if self.multi then 40 else 20), 1, 0),
		Position = UDim2.fromOffset(if self.multi then 32 else Tokens.Space.sm, 0),
		ZIndex = 65,
	})

	set(label, "Parent", button)

	local view = { button = button, label = label, check = check, bar = bar }
	self._views[row] = view

	local target = button :: any

	target.MouseEnter:Connect(function()
		self._hoverIndex = self._rowIndex[row]
		self:_paintRow(row, self._rowIndex[row], true)
	end)

	target.MouseLeave:Connect(function()
		if self._hoverIndex == self._rowIndex[row] then
			self._hoverIndex = nil
		end

		self:_paintRow(row, self._rowIndex[row], false)
	end)

	target.MouseButton1Click:Connect(function()
		local index = self._rowIndex[row]

		if index then
			self:_choose(index)
		end
	end)

	return view
end

function Dropdown:_renderRow(index: number, row: Instance)
	local view = self._views[row]

	if not view then
		view = self:_buildRow(row)
	end

	local option = self._options[index]

	if not option then
		set(view.button, "Visible", false)
		return
	end

	set(view.button, "Visible", true)
	self._rowIndex[row] = index

	local selected = self:_selected(option.value)
	local highlighted = index == self._highlight
	local hovered = self._hoverIndex == index

	set(view.label, "Text", option.text)
	set(
		view.label,
		"TextColor3",
		self.surface:Color(
			if option.disabled
				then "faint"
				elseif selected then "accent"
				elseif highlighted or hovered then "ink"
				else "muted"
		)
	)
	set(view.bar, "Visible", highlighted and not option.disabled)
	set(view.bar, "BackgroundColor3", self.surface:Color("accent"))
	set(view.button, "BackgroundTransparency", if highlighted or hovered or selected then 0 else 1)
	set(
		view.button,
		"BackgroundColor3",
		self.surface:Color(if highlighted or hovered or selected then "selected" else "well")
	)

	if self.multi then
		set(view.check, "Visible", true)
		set(view.check, "BackgroundTransparency", if selected then 0 else 1)
		set(
			view.check,
			"BackgroundColor3",
			self.surface:Color(if selected then "accent" else "well")
		)
	end
end

function Dropdown:_paintRow(row: Instance, index: number?, hovered: boolean)
	local view = self._views[row]

	if not view or not index then
		return
	end

	local option = self._options[index]

	if not option then
		return
	end

	local selected = self:_selected(option.value)
	local highlighted = index == self._highlight

	set(view.button, "BackgroundTransparency", if highlighted or hovered or selected then 0 else 1)
	set(
		view.button,
		"BackgroundColor3",
		self.surface:Color(if highlighted or hovered or selected then "selected" else "well")
	)
end

function Dropdown:_moveHighlight(delta: number)
	local count = #self._options

	if count == 0 then
		return
	end

	local index = self._highlight

	for _ = 1, count do
		index = ((index - 1 + delta) % count) + 1

		if not self._options[index].disabled then
			self._highlight = index
			self._list:ScrollToIndex(index)
			self:Render()

			return
		end
	end
end

function Dropdown:_choose(index: number)
	local option = self._options[index]

	if not option or option.disabled then
		return
	end

	if self.multi then
		local position = table.find(self._values, option.value)
		local nextValues = table.clone(self._values)

		if position then
			table.remove(nextValues, position)
		else
			table.insert(nextValues, option.value)
		end

		if sameList(nextValues, self._values) then
			return
		end

		self._values = nextValues
		self._highlight = index
		self:Render()
		self:_layout()
		self._list:ScrollToIndex(index)

		if self.onChange then
			self.onChange(table.clone(self._values))
		end

		return
	end

	local changed = self.value ~= option.value
	self.value = option.value
	self:Render()
	self:Close()

	if changed and self.onChange then
		self.onChange(option.value)
	end
end

function Dropdown:Activate()
	if not self.enabled or self.destroyed then
		return
	end

	if self.open then
		if self._highlight > 0 then
			self:_choose(self._highlight)
		end
	else
		self:Open()
	end
end



function Dropdown:HandleAction(action: string): boolean
	if not self.open then
		if action == "activate" then
			self:Activate()
			return true
		end

		return false
	end

	if action == "up" then
		self:_moveHighlight(-1)
		return true
	end

	if action == "down" then
		self:_moveHighlight(1)
		return true
	end

	if action == "activate" then
		if self._highlight > 0 then
			self:_choose(self._highlight)
		end

		return true
	end

	if action == "escape" then
		self:Close()
		return true
	end

	
	
	if action == "left" or action == "right" then
		return true
	end

	return false
end

function Dropdown:Dismiss(input: any): boolean
	if not self.open then
		return false
	end

	local position = input and input.Position

	if not position then
		return true
	end

	local point = pointOf(position)
	local fieldPoint = pointOf((self.field :: any).AbsolutePosition)
	local fieldSize = (self.field :: any).AbsoluteSize
	local popupPoint = pointOf((self._popup :: any).AbsolutePosition)
	local popupSize = (self._popup :: any).AbsoluteSize

	local inField = point.X >= fieldPoint.X
		and point.X <= fieldPoint.X + fieldSize.X
		and point.Y >= fieldPoint.Y
		and point.Y <= fieldPoint.Y + fieldSize.Y
	local inPopup = point.X >= popupPoint.X
		and point.X <= popupPoint.X + popupSize.X
		and point.Y >= popupPoint.Y
		and point.Y <= popupPoint.Y + popupSize.Y

	return not (inField or inPopup)
end

function Dropdown:SetValue(value: any)
	if self.destroyed then
		return
	end

	if self.multi then
		local values: { any } = {}

		if type(value) == "table" then
			for _, item in ipairs(value) do
				if table.find(values, item) == nil then
					table.insert(values, item)
				end
			end
		end

		self._values = values
	else
		self.value = value
	end

	self:Render()
end

function Dropdown:SetEnabled(value: boolean)
	if self.destroyed then
		return
	end

	self.enabled = value

	if not value then
		self:Close()
	end

	self:Render()
end

function Dropdown:SetVisible(value: boolean)
	if not value then
		self:Close()
	end

	set(self.instance, "Visible", value)
end

function Dropdown:SetFocus(value: boolean)
	if self.destroyed then
		return
	end

	if value and not self.enabled then
		return
	end

	self.focused = value
	self:Render()
end

function Dropdown:Focus()
	self:SetFocus(true)
end

function Dropdown:Blur()
	self:SetFocus(false)
end

function Dropdown:Destroy()
	if self.destroyed then
		return
	end

	self:Close()
	self.destroyed = true
	self._scope:Destroy()
	self._list:Destroy()

	pcall(function()
		(self._popup :: any):Destroy()
	end)

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Dropdown
end

__defs["components.Input"] = function()






local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local State = __require("runtime.State")

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
end

__defs["components.Keybind"] = function()












local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local State = __require("runtime.State")

export type Config = {
	text: string?,
	note: string?,
	value: Enum.KeyCode?,
	enabled: boolean?,
	onChange: ((value: Enum.KeyCode?) -> ())?,
}

export type Keybind = {
	surface: Surface.Surface,
	instance: Instance,
	value: Enum.KeyCode?,
	enabled: boolean,
	hovered: boolean,
	focused: boolean,
	capturing: boolean,
	destroyed: boolean,
	conflict: string?,
	onChange: ((value: Enum.KeyCode?) -> ())?,
	_scope: Scope.Scope,
	_label: Instance,
	_chip: Instance,
	_chipLabel: Instance,
	_chipStroke: Instance,
	_note: Instance?,
	_labelText: string,
	_token: any,

	Render: (self: Keybind) -> (),
	GetValue: (self: Keybind) -> Enum.KeyCode?,
	SetValue: (self: Keybind, value: Enum.KeyCode?) -> (),
	SetEnabled: (self: Keybind, value: boolean) -> (),
	SetVisible: (self: Keybind, value: boolean) -> (),
	Activate: (self: Keybind) -> (),
	Capture: (self: Keybind) -> (),
	Cancel: (self: Keybind) -> (),
	IsCapturing: (self: Keybind) -> boolean,
	CaptureKey: (self: Keybind, input: any) -> boolean,
	SetFocus: (self: Keybind, value: boolean) -> (),
	Focus: (self: Keybind) -> (),
	Blur: (self: Keybind) -> (),
	Destroy: (self: Keybind) -> (),
}

local Keybind = {}
Keybind.__index = Keybind

local REGISTRY_KEY = "__BASALT_KEYBIND_KEYS"

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end



local function registry(): { [string]: any }?
	local ok, environment = pcall(getfenv, 0)

	if not ok or type(environment) ~= "table" then
		return nil
	end

	local writable = pcall(function()
		environment.__BASALT_BIND_PROBE = true
	end)

	environment.__BASALT_BIND_PROBE = nil

	if not writable then
		return nil
	end

	local map = environment[REGISTRY_KEY]

	if type(map) ~= "table" then
		map = {}
		environment[REGISTRY_KEY] = map
	end

	return map
end

local function keyName(key: Enum.KeyCode?): string
	if key == nil then
		return "None"
	end

	local name = (key :: any).Name

	if type(name) ~= "string" or name == "" then
		return tostring(key)
	end

	return name
end

function Keybind.new(surface: Surface.Surface, config: Config?): Keybind
	local settings = config or {}
	local noteText = settings.note
	local rowHeight = Tokens.Row(surface.density) + (if noteText then Tokens.Space.md else 0)
	local chipWidth = 104

	local instance = surface:Create("TextButton", {
		Name = "Keybind",
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
		Size = UDim2.new(1, -(chipWidth + Tokens.Space.xxl), 0, if noteText then 16 else rowHeight),
		Position = UDim2.new(0, 0, 0, if noteText then Tokens.Space.xs else 0),
	})

	set(label, "Parent", instance)

	local note: Instance? = nil
	if noteText then
		local noteLabel = surface:Label({
			Name = "Note",
			Text = noteText,
			Font = surface:Font("small"),
			TextSize = surface:Text("small"),
			TextColor3 = surface:Color("muted"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -(chipWidth + Tokens.Space.xxl), 0, 14),
			Position = UDim2.new(0, 0, 0, rowHeight - 18),
		})

		set(noteLabel, "Parent", instance)
		note = noteLabel
	end

	local chip = surface:Raised({
		Name = "Chip",
		Size = UDim2.fromOffset(chipWidth, Tokens.Row(surface.density) - 12),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Tokens.Space.lg, 0.5, 0),
	})

	set(chip, "Parent", instance)
	surface:Corner(chip, Tokens.Size.radiusControl)

	local chipStroke = surface:Stroke(chip, "seam")

	local chipLabel = surface:Label({
		Name = "Value",
		Text = "None",
		Font = surface:Font("mono"),
		TextSize = surface:Text("small"),
		TextColor3 = surface:Color("muted"),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -Tokens.Space.sm, 1, 0),
	})

	set(chipLabel, "Parent", chip)

	local keybind = setmetatable({
		surface = surface,
		instance = instance,
		value = settings.value,
		enabled = settings.enabled ~= false,
		hovered = false,
		focused = false,
		capturing = false,
		destroyed = false,
		conflict = nil,
		onChange = settings.onChange,
		_scope = Scope.new(),
		_label = label,
		_chip = chip,
		_chipLabel = chipLabel,
		_chipStroke = chipStroke,
		_note = note,
		_labelText = settings.text or "Unnamed keybind",
		_token = {},
	}, Keybind)

	
	
	
	keybind:_claim(keybind.value)
	keybind:Render()

	keybind._scope:AddConnection((instance :: any).MouseEnter:Connect(function()
		keybind.hovered = true
		keybind:Render()
	end))

	keybind._scope:AddConnection((instance :: any).MouseLeave:Connect(function()
		keybind.hovered = false
		keybind:Render()
	end))

	keybind._scope:AddConnection((instance :: any).MouseButton1Click:Connect(function()
		keybind:Activate()
	end))

	surface.scope:Add(keybind)

	return keybind
end

local function otherEntry(map: { [string]: any }, name: string, token: any): any?
	local list = map[name]

	if type(list) ~= "table" then
		return nil
	end

	for _, entry in ipairs(list) do
		if entry.token ~= token and entry.active == true then
			return entry
		end
	end

	return nil
end

function Keybind:_conflictFor(key: Enum.KeyCode?): string?
	if key == nil then
		return nil
	end

	local map = registry()

	if not map then
		return nil
	end

	local other = otherEntry(map, keyName(key), self._token)

	return if other then tostring(other.label) else nil
end

function Keybind:_claim(key: Enum.KeyCode?)
	local map = registry()

	if not map then
		self.conflict = nil
		self:_release()
		return
	end

	
	self:_release()
	self.conflict = nil

	if key == nil then
		return
	end

	local name = keyName(key)
	local other = otherEntry(map, name, self._token)

	if other then
		self.conflict = tostring(other.label)
		warn(
			string.format(
				"Basalt: keybind '%s' is already bound to '%s'; both are bound to the same key",
				name,
				self.conflict
			)
		)
	end

	local list = map[name]

	if type(list) ~= "table" then
		list = {}
		map[name] = list
	end

	table.insert(list, {
		active = true,
		label = self._labelText,
		token = self._token,
	})
end

function Keybind:_release()
	local map = registry()

	if not map then
		return
	end

	for name, list in pairs(map) do
		if type(list) == "table" then
			for index = #list, 1, -1 do
				if list[index].token == self._token then
					table.remove(list, index)
				end
			end

			if #list == 0 then
				map[name] = nil
			end
		end
	end
end

function Keybind:Render()
	if self.destroyed then
		return
	end

	local row = State.Resolve("row", {
		enabled = self.enabled,
		hovered = self.hovered,
		focused = self.focused,
		selected = self.capturing,
	})

	if row.background then
		set(self.instance, "BackgroundTransparency", 0)
		set(self.instance, "BackgroundColor3", self.surface:Color(row.background))
	else
		set(self.instance, "BackgroundTransparency", 1)
	end

	local tone = "ink"

	if self.capturing then
		tone = "focus"
	elseif not self.enabled then
		tone = "faint"
	elseif self.conflict then
		tone = "danger"
	elseif self.value == nil then
		tone = "muted"
	end

	set(self._label, "TextColor3", self.surface:Color(if self.enabled then "ink" else "faint"))
	set(self._chipLabel, "Text", if self.capturing then "Press a key" else keyName(self.value))
	set(self._chipLabel, "TextColor3", self.surface:Color(tone))
	set(
		self._chip,
		"BackgroundColor3",
		self.surface:Color(if self.capturing then "selected" else "well")
	)

	local strokeToken = "seam"

	if self.capturing or self.focused then
		strokeToken = "focus"
	elseif self.conflict then
		strokeToken = "danger"
	elseif self.value == nil then
		strokeToken = "seamStrong"
	end

	set(self._chipStroke, "Color", self.surface:Color(strokeToken))

	if self._note then
		set(self._note, "TextColor3", self.surface:Color(if self.enabled then "muted" else "faint"))
	end
end

function Keybind:_assign(value: Enum.KeyCode?, fire: boolean)
	if self.destroyed then
		return
	end

	local changed = self.value ~= value
	self.value = value
	self.capturing = false
	self:_claim(value)
	self:Render()

	if changed and fire and self.onChange then
		self.onChange(value)
	end
end

function Keybind:GetValue(): Enum.KeyCode?
	return self.value
end

function Keybind:SetValue(value: Enum.KeyCode?)
	self:_assign(value, false)
end

function Keybind:SetEnabled(value: boolean)
	if self.destroyed then
		return
	end

	self.enabled = value

	if not value then
		self.capturing = false
	end

	self:Render()
end

function Keybind:SetVisible(value: boolean)
	
	
	if not value then
		self:Cancel()
	end

	(self.instance :: any).Visible = value
end

function Keybind:Capture()
	if self.destroyed or not self.enabled or self.capturing then
		return
	end

	self.capturing = true
	self:Render()
end

function Keybind:Cancel()
	if not self.capturing then
		return
	end

	self.capturing = false
	self:Render()
end

function Keybind:IsCapturing(): boolean
	return self.capturing
end



function Keybind:CaptureKey(input: any): boolean
	if self.destroyed or not self.capturing then
		return false
	end

	if type(input) ~= "table" or input.UserInputType ~= Enum.UserInputType.Keyboard then
		
		
		self:Cancel()
		return true
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		self:Cancel()
		return true
	end

	self:_assign(input.KeyCode, true)
	return true
end

function Keybind:Activate()
	if not self.enabled or self.destroyed then
		return
	end

	if self.capturing then
		self:Cancel()
	else
		self:Capture()
	end
end

function Keybind:SetFocus(value: boolean)
	if self.destroyed then
		return
	end

	if value and not self.enabled then
		return
	end

	self.focused = value

	
	
	if not value then
		self.capturing = false
	end

	self.conflict = self:_conflictFor(self.value)
	self:Render()
end

function Keybind:Focus()
	self:SetFocus(true)
end

function Keybind:Blur()
	self:SetFocus(false)
end

function Keybind:Destroy()
	if self.destroyed then
		return
	end

	self:_release()
	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Keybind
end

__defs["components.Label"] = function()





local Surface = __require("runtime.Surface")

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
end

__defs["components.Progress"] = function()










local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")

export type Tone = "accent" | "success" | "danger" | "muted"

export type Config = {
	text: string?,
	value: number?,
	min: number?,
	max: number?,
	suffix: string?,
	showValue: boolean?,
	tone: Tone?,
}

export type Progress = {
	surface: Surface.Surface,
	instance: Instance,
	value: number,
	min: number,
	max: number,
	suffix: string,
	tone: Tone,
	showValue: boolean,
	destroyed: boolean,
	_scope: Scope.Scope,
	_track: Instance,
	_fill: Instance,
	_label: Instance?,
	_valueLabel: Instance?,

	Render: (self: Progress) -> (),
	SetValue: (self: Progress, value: number) -> (),
	GetValue: (self: Progress) -> number,
	GetRatio: (self: Progress) -> number,
	SetText: (self: Progress, text: string) -> (),
	SetTone: (self: Progress, tone: Tone) -> (),
	SetVisible: (self: Progress, value: boolean) -> (),
	Destroy: (self: Progress) -> (),
}

local Progress = {}
Progress.__index = Progress

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local TONES: { [string]: boolean } = {
	accent = true,
	success = true,
	danger = true,
	muted = true,
}

function Progress.Ratio(value: number, minimum: number, maximum: number): number
	if maximum <= minimum then
		return 0
	end

	return math.clamp((value - minimum) / (maximum - minimum), 0, 1)
end

local function formatValue(value: number, suffix: string): string
	local rounded = math.floor(value * 100 + 0.5) / 100
	local text = if rounded == math.floor(rounded)
		then tostring(math.floor(rounded))
		else tostring(rounded)

	return text .. suffix
end

function Progress.new(surface: Surface.Surface, config: Config?): Progress
	local settings = config or {}
	local minimum = settings.min or 0
	local maximum = settings.max or 100

	if maximum <= minimum then
		error(
			string.format(
				"Basalt: progress max (%s) must be greater than min (%s)",
				tostring(maximum),
				tostring(minimum)
			),
			2
		)
	end

	local tone = settings.tone or "accent"

	if not TONES[tone] then
		error(string.format("Basalt: progress has no tone '%s'", tostring(tone)), 2)
	end

	local hasText = settings.text ~= nil
	local showValue = settings.showValue ~= false
	local height = if hasText then Tokens.Row(surface.density) else Tokens.Space.md
	local value = math.clamp(settings.value or minimum, minimum, maximum)

	local instance = surface:Frame({
		Name = "Progress",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
	})

	local label: Instance? = nil
	local valueLabel: Instance? = nil

	if hasText then
		local textLabel = surface:Label({
			Name = "Text",
			Text = settings.text or "",
			TextColor3 = surface:Color("ink"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -(if showValue then Tokens.Space.xxl * 2 else 0), 0, 16),
			Position = UDim2.new(0, 0, 0, 0),
		})

		set(textLabel, "Parent", instance)
		label = textLabel

		if showValue then
			local readout = surface:Label({
				Name = "Value",
				Text = formatValue(value, settings.suffix or ""),
				Font = surface:Font("mono"),
				TextSize = surface:Text("mono"),
				TextColor3 = surface:Color("muted"),
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.new(0, Tokens.Space.xxl * 2, 0, 16),
				Position = UDim2.new(1, -Tokens.Space.xxl * 2, 0, 0),
			})

			set(readout, "Parent", instance)
			valueLabel = readout
		end
	end

	local track = surface:Frame({
		Name = "Track",
		BackgroundColor3 = surface:Color("seam"),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, Tokens.Space.xs),
		Position = if hasText
			then UDim2.new(0, 0, 1, -Tokens.Space.xs)
			else UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = if hasText then Vector2.new(0, 1) else Vector2.new(0, 0.5),
	})

	set(track, "Parent", instance)
	surface:Corner(track, Tokens.Size.radiusControl)

	local fill = surface:Frame({
		Name = "Fill",
		BackgroundColor3 = surface:Color(tone),
		BorderSizePixel = 0,
		Size = UDim2.new(Progress.Ratio(value, minimum, maximum), 0, 1, 0),
	})

	set(fill, "Parent", track)
	surface:Corner(fill, Tokens.Size.radiusControl)

	local progress = setmetatable({
		surface = surface,
		instance = instance,
		value = value,
		min = minimum,
		max = maximum,
		suffix = settings.suffix or "",
		tone = tone,
		showValue = showValue,
		destroyed = false,
		_scope = Scope.new(),
		_track = track,
		_fill = fill,
		_label = label,
		_valueLabel = valueLabel,
	}, Progress)

	progress:Render()
	surface.scope:Add(progress)

	return progress
end

function Progress:Render()
	if self.destroyed then
		return
	end

	local ratio = Progress.Ratio(self.value, self.min, self.max)

	set(self._fill, "Size", UDim2.new(ratio, 0, 1, 0))
	set(self._fill, "BackgroundColor3", self.surface:Color(self.tone))

	if self._valueLabel then
		set(self._valueLabel, "Text", formatValue(self.value, self.suffix))
	end
end

function Progress:SetValue(value: number)
	if self.destroyed then
		return
	end

	self.value = math.clamp(value, self.min, self.max)
	self:Render()
end

function Progress:GetValue(): number
	return self.value
end

function Progress:GetRatio(): number
	return Progress.Ratio(self.value, self.min, self.max)
end

function Progress:SetText(text: string)
	if self.destroyed or not self._label then
		return
	end

	set(self._label, "Text", text)
end

function Progress:SetTone(tone: Tone)
	if self.destroyed then
		return
	end

	if not TONES[tone] then
		error(string.format("Basalt: progress has no tone '%s'", tostring(tone)), 2)
	end

	self.tone = tone
	self:Render()
end

function Progress:SetVisible(value: boolean)
	set(self.instance, "Visible", value)
end

function Progress:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Progress
end

__defs["components.Section"] = function()





local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local Layout = __require("runtime.Layout")
local Focus = __require("runtime.Focus")

local Button = __require("components.Button")
local Toggle = __require("components.Toggle")
local Slider = __require("components.Slider")
local Input = __require("components.Input")
local Dropdown = __require("components.Dropdown")
local Keybind = __require("components.Keybind")
local Progress = __require("components.Progress")
local Table = __require("components.Table")
local Console = __require("components.Console")
local ColorPicker = __require("components.ColorPicker")
local Label = __require("components.Label")
local Divider = __require("components.Divider")
local Badge = __require("components.Badge")
local Spacer = __require("components.Spacer")

export type Config = {
	title: string?,
	note: string?,
}

export type Section = {
	surface: Surface.Surface,
	instance: Instance,
	content: Instance,
	title: Instance?,
	destroyed: boolean,
	_scope: Scope.Scope,
	_focus: Focus.Focus?,
	_layer: any,
	_order: number,

	Add: (self: Section, instance: Instance) -> Instance,
	Button: (self: Section, config: Button.Config?) -> Button.Button,
	Toggle: (self: Section, config: Toggle.Config?) -> Toggle.Toggle,
	Slider: (self: Section, config: Slider.Config?) -> Slider.Slider,
	Input: (self: Section, config: Input.Config?) -> Input.Input,
	Dropdown: (self: Section, config: Dropdown.Config?) -> Dropdown.Dropdown,
	MultiDropdown: (self: Section, config: Dropdown.Config?) -> Dropdown.Dropdown,
	Keybind: (self: Section, config: Keybind.Config?) -> Keybind.Keybind,
	Progress: (self: Section, config: Progress.Config?) -> Progress.Progress,
	Table: (self: Section, config: Table.Config?) -> Table.Table,
	Console: (self: Section, config: Console.Config?) -> Console.Console,
	ColorPicker: (self: Section, config: ColorPicker.Config?) -> ColorPicker.ColorPicker,
	Label: (self: Section, config: Label.Config?) -> Label.Label,
	Divider: (self: Section, config: Divider.Config?) -> Divider.Divider,
	Badge: (self: Section, config: Badge.Config?) -> Badge.Badge,
	Spacer: (self: Section, config: Spacer.Config?) -> Spacer.Spacer,
	Destroy: (self: Section) -> (),
}

local Section = {}
Section.__index = Section

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

function Section.new(
	surface: Surface.Surface,
	parent: Instance,
	config: Config?,
	focus: Focus.Focus?,
	layer: any
): Section
	local settings = config or {}

	local instance = surface:Frame({
		Name = "Section",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	set(instance, "Parent", parent)

	local order = 1

	local title: Instance? = nil
	if settings.title then
		local label = surface:Label({
			Name = "Title",
			Text = settings.title,
			Font = surface:Font("title"),
			TextSize = surface:Text("title"),
			TextColor3 = surface:Color("ink"),
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 20),
		})

		set(label, "Parent", instance)
		title = label
		order += 1
	end

	if settings.note then
		local note = surface:Label({
			Name = "Note",
			Text = settings.note,
			Font = surface:Font("small"),
			TextSize = surface:Text("small"),
			TextColor3 = surface:Color("muted"),
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 14),
		})

		set(note, "Parent", instance)
		order += 1
	end

	local content = surface:Frame({
		Name = "Content",
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	set(content, "Parent", instance)
	Layout.List(surface, content, { padding = Tokens.Space.sm })

	Layout.List(surface, instance, { padding = Tokens.Space.xs })

	local section = setmetatable({
		surface = surface,
		instance = instance,
		content = content,
		title = title,
		destroyed = false,
		_scope = Scope.new(),
		_focus = focus,
		_layer = layer,
		_order = 1,
	}, Section)

	surface.scope:Add(section)

	return section
end

function Section:Add(instance: Instance): Instance
	if self.destroyed then
		instance:Destroy()
		return instance
	end

	set(instance, "LayoutOrder", self._order)
	self._order += 1
	set(instance, "Parent", self.content)
	self._scope:Add(instance)

	return instance
end

local function attach(section: Section, component: any): any
	section:Add(component.instance)
	section._scope:Add(component)

	if section._focus and type(component.SetFocus) == "function" then
		section._focus:Track(component, { group = "page" })
	end

	return component
end

function Section:Button(config: Button.Config?): Button.Button
	return attach(self, Button.new(self.surface, config))
end

function Section:Toggle(config: Toggle.Config?): Toggle.Toggle
	return attach(self, Toggle.new(self.surface, config))
end

function Section:Slider(config: Slider.Config?): Slider.Slider
	return attach(self, Slider.new(self.surface, config))
end

function Section:Input(config: Input.Config?): Input.Input
	return attach(self, Input.new(self.surface, config))
end

function Section:Dropdown(config: Dropdown.Config?): Dropdown.Dropdown
	return attach(self, Dropdown.new(self.surface, config, self._layer))
end



function Section:MultiDropdown(config: Dropdown.Config?): Dropdown.Dropdown
	local merged = table.clone(config or {})
	merged.multi = true

	return self:Dropdown(merged)
end

function Section:Keybind(config: Keybind.Config?): Keybind.Keybind
	return attach(self, Keybind.new(self.surface, config))
end

function Section:Progress(config: Progress.Config?): Progress.Progress
	return attach(self, Progress.new(self.surface, config))
end

function Section:Table(config: Table.Config?): Table.Table
	return attach(self, Table.new(self.surface, config))
end

function Section:Console(config: Console.Config?): Console.Console
	return attach(self, Console.new(self.surface, config))
end

function Section:ColorPicker(config: ColorPicker.Config?): ColorPicker.ColorPicker
	return attach(self, ColorPicker.new(self.surface, config, self._focus))
end

function Section:Label(config: Label.Config?): Label.Label
	return attach(self, Label.new(self.surface, config))
end

function Section:Divider(config: Divider.Config?): Divider.Divider
	return attach(self, Divider.new(self.surface, config))
end

function Section:Badge(config: Badge.Config?): Badge.Badge
	return attach(self, Badge.new(self.surface, config))
end

function Section:Spacer(config: Spacer.Config?): Spacer.Spacer
	return attach(self, Spacer.new(self.surface, config))
end

function Section:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Section
end

__defs["components.Slider"] = function()






local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local State = __require("runtime.State")

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
end

__defs["components.Spacer"] = function()





local Tokens = __require("design.Tokens")
local Surface = __require("runtime.Surface")

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
end

__defs["components.Tab"] = function()






local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local Layout = __require("runtime.Layout")

local Section = __require("components.Section")
local Button = __require("components.Button")

export type Config = {
	name: string?,
	hint: string?,
}

export type Tab = {
	surface: Surface.Surface,
	name: string,
	hint: string?,
	button: Button.Button,
	page: Instance,
	active: boolean,
	destroyed: boolean,
	_scope: Scope.Scope,
	_sections: { Section.Section },
	_window: any,

	Activate: (self: Tab) -> (),
	Deactivate: (self: Tab) -> (),
	Show: (self: Tab) -> (),
	section: (self: Tab, config: Section.Config?) -> Section.Section,
	Destroy: (self: Tab) -> (),
}

local Tab = {}
Tab.__index = Tab

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

function Tab.new(
	surface: Surface.Surface,
	window: any,
	rail: Instance,
	pages: Instance,
	railWidth: number,
	config: Config?
): Tab
	local settings = config or {}
	local name = settings.name or "Tab"

	local page = surface:Create("ScrollingFrame", {
		Name = "Page",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = surface:Color("seamStrong"),
		Visible = false,
	})

	set(page, "Parent", pages)
	Layout.List(surface, page, { padding = Tokens.Space.md })
	Layout.Padding(surface, page, Tokens.Pad(surface.density))

	local button = Button.new(surface, {
		text = name,
		variant = "ghost",
		width = railWidth - Tokens.Space.md,
		height = Tokens.Row(surface.density),
	})

	set(button.instance, "Parent", rail)
	set(button.instance, "LayoutOrder", #rail:GetChildren() + 1)

	if window and window._focus then
		window._focus:Track(button, { group = "rail" })
	end

	if settings.hint then
		local hint = surface:Label({
			Name = "Hint",
			Text = settings.hint,
			Font = surface:Font("mono"),
			TextSize = surface:Text("mono"),
			TextColor3 = surface:Color("faint"),
			TextXAlignment = Enum.TextXAlignment.Right,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 18, 1, 0),
			Position = UDim2.new(1, -18, 0, 0),
		})

		set(hint, "Parent", button.instance)
	end

	local tab = setmetatable({
		surface = surface,
		name = name,
		hint = settings.hint,
		button = button,
		page = page,
		active = false,
		destroyed = false,
		_scope = Scope.new(),
		_sections = {},
		_window = window,
	}, Tab)

	button.onClick = function()
		tab:Show()
	end

	surface.scope:Add(tab)

	return tab
end

function Tab:Activate()
	if self.destroyed then
		return
	end

	self.active = true
	set(self.page, "Visible", true)
	self.button:SetSelected(true)
end

function Tab:Deactivate()
	if self.destroyed then
		return
	end

	self.active = false
	set(self.page, "Visible", false)
	self.button:SetSelected(false)
end

function Tab:Show()
	if self.destroyed then
		return
	end

	if self._window then
		self._window:SelectTab(self)
	end
end

function Tab:section(config: Section.Config?): Section.Section
	if self.destroyed then
		error("Basalt: cannot add a section to a destroyed tab", 2)
	end

	local section = Section.new(
		self.surface,
		self.page,
		config,
		if self._window then self._window._focus else nil,
		if self._window then self._window._layer else nil
	)
	table.insert(self._sections, section)
	self._scope:Add(section)

	return section
end

function Tab:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()
	self.button:Destroy()

	pcall(function()
		(self.page :: any):Destroy()
	end)
end

return Tab
end

__defs["components.Table"] = function()









local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local VirtualList = __require("runtime.VirtualList")

export type Column = {
	text: string?,
	key: any?,
	weight: number?,
	align: string?,
	mono: boolean?,
}

export type Config = {
	columns: { Column }?,
	rows: { any }?,
	height: number?,
	rowHeight: number?,
	selected: number?,
	emptyText: string?,
	onSelect: ((row: any, index: number) -> ())?,
}

export type Table = {
	surface: Surface.Surface,
	instance: Instance,
	rows: { any },
	columns: { Column },
	selected: number?,
	hovered: number?,
	rowHeight: number,
	destroyed: boolean,
	focused: boolean,
	onSelect: ((row: any, index: number) -> ())?,
	_scope: Scope.Scope,
	_header: Instance,
	_empty: Instance,
	_hits: { [Instance]: Instance },
	_cells: { [Instance]: { Instance } },
	_stroke: Instance,
	_list: VirtualList.VirtualList,

	Render: (self: Table) -> (),
	SetRows: (self: Table, rows: { any }) -> (),
	GetRows: (self: Table) -> { any },
	SetSelected: (self: Table, index: number?) -> (),
	GetSelected: (self: Table) -> number?,
	GetSelectedRow: (self: Table) -> any?,
	ScrollToIndex: (self: Table, index: number) -> (),
	SetVisible: (self: Table, value: boolean) -> (),
	SetFocus: (self: Table, value: boolean) -> (),
	Focus: (self: Table) -> (),
	Blur: (self: Table) -> (),
	HandleArrow: (self: Table, direction: string) -> boolean,
	Activate: (self: Table) -> (),
	Destroy: (self: Table) -> (),
}

local Table = {}
Table.__index = Table

local ALIGNMENTS: { [string]: Enum.TextXAlignment } = {
	left = Enum.TextXAlignment.Left,
	center = Enum.TextXAlignment.Center,
	right = Enum.TextXAlignment.Right,
}

local HEADER_HEIGHT = 22

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local function normalizeColumns(columns: { Column }): ({ Column }, number)
	if type(columns) ~= "table" or #columns == 0 then
		error("Basalt: a Table needs at least one column", 3)
	end

	local normalized = {}
	local total = 0

	for index, column in ipairs(columns) do
		if type(column) ~= "table" then
			error(string.format("Basalt: table column %d is not a table", index), 3)
		end

		local weight = column.weight or 1

		if weight <= 0 then
			error(
				string.format(
					"Basalt: table column %d has weight %s; use a positive number",
					index,
					tostring(weight)
				),
				3
			)
		end

		if column.align and not ALIGNMENTS[column.align] then
			error(
				string.format(
					"Basalt: table column %d has no align '%s'",
					index,
					tostring(column.align)
				),
				3
			)
		end

		normalized[index] = {
			text = column.text,
			key = column.key or index,
			weight = weight,
			align = column.align or "left",
			mono = column.mono == true,
		}

		total += weight
	end

	return normalized, total
end

local function cellText(value: any): string
	if value == nil then
		return ""
	end

	return tostring(value)
end

function Table.new(surface: Surface.Surface, config: Config?): Table
	local settings = config or {}
	local columns, totalWeight = normalizeColumns(settings.columns or {})
	local rowHeight = settings.rowHeight or Tokens.Row(surface.density)
	local height = settings.height or rowHeight * 6
	local rows = settings.rows or {}

	local instance = surface:Frame({
		Name = "Table",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT + Tokens.Size.seam + height),
	})

	local stroke = surface:Stroke(instance, "focus", Tokens.Size.seam)
	set(stroke, "Transparency", 1)

	local header = surface:Frame({
		Name = "Header",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
	})

	set(header, "Parent", instance)

	local seam = surface:Frame({
		Name = "Seam",
		BackgroundColor3 = surface:Color("seam"),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, Tokens.Size.seam),
		Position = UDim2.new(0, 0, 1, -Tokens.Size.seam),
	})

	set(seam, "Parent", header)

	
	
	local positions = {}
	local offset = 0
	for index, column in ipairs(columns) do
		local width = column.weight / totalWeight
		positions[index] = offset

		local headerCell = surface:Label({
			Name = "Column" .. index,
			Text = column.text or "",
			Font = surface:Font("small"),
			TextSize = surface:Text("small"),
			TextColor3 = surface:Color("muted"),
			TextXAlignment = ALIGNMENTS[column.align],
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(width, 0, 1, 0),
			Position = UDim2.new(offset, 0, 0, 0),
			ZIndex = 2,
		})

		set(headerCell, "Parent", header)
		offset += width
	end

	local empty = surface:Label({
		Name = "Empty",
		Text = settings.emptyText or "No rows",
		Font = surface:Font("body"),
		TextSize = surface:Text("small"),
		TextColor3 = surface:Color("muted"),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, height),
		Position = UDim2.new(0, 0, 0, HEADER_HEIGHT + Tokens.Size.seam),
		Visible = false,
	})

	set(empty, "Parent", instance)

	local list = VirtualList.new(surface, instance, {
		rowHeight = rowHeight,
		height = height,
		count = #rows,
		zIndex = 2,
	})

	set(list.frame, "Position", UDim2.new(0, 0, 0, HEADER_HEIGHT + Tokens.Size.seam))

	local table = setmetatable({
		surface = surface,
		instance = instance,
		rows = rows,
		columns = columns,
		selected = settings.selected,
		hovered = nil,
		rowHeight = rowHeight,
		destroyed = false,
		focused = false,
		onSelect = settings.onSelect,
		_scope = Scope.new(),
		_header = header,
		_empty = empty,
		_hits = {},
		_cells = {},
		_stroke = stroke,
		_list = list,
	}, Table)

	table._scope:Add(list)
	table._scope:AddConnection((instance :: any).InputBegan:Connect(function(input: any)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			table:Focus()
		end
	end))

	
	
	
	list:SetRender(function(index: number, row: Instance)
		local cells = table._cells[row]

		if not cells then
			cells = {}
			table._cells[row] = cells

			for position, column in ipairs(columns) do
				local cell = surface:Label({
					Name = "Cell" .. position,
					Text = "",
					Font = surface:Font(if column.mono then "mono" else "body"),
					TextSize = surface:Text(if column.mono then "mono" else "small"),
					TextColor3 = surface:Color("ink"),
					TextXAlignment = ALIGNMENTS[column.align],
					TextTruncate = Enum.TextTruncate.AtEnd,
					BackgroundTransparency = 1,
					Size = UDim2.new(column.weight / totalWeight, 0, 1, 0),
					Position = UDim2.new(positions[position], 0, 0, 0),
					ZIndex = 4,
				})

				set(cell, "Parent", row)
				cells[position] = cell
			end

			local divider = surface:Frame({
				Name = "Divider",
				BackgroundColor3 = surface:Color("seam"),
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, Tokens.Size.seam),
				Position = UDim2.new(0, 0, 1, -Tokens.Size.seam),
				ZIndex = 3,
			})

			set(divider, "Parent", row)

			local hit = surface:Create("TextButton", {
				Name = "Hit",
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 3,
			})

			set(hit, "Parent", row)
			table._hits[row] = hit

			table._scope:AddConnection((hit :: any).MouseEnter:Connect(function()
				table.hovered = list:IndexFor(row)

				if table.hovered and table.hovered ~= table.selected then
					set(row, "BackgroundTransparency", 0)
					set(row, "BackgroundColor3", surface:Color("raised"))
				end
			end))

			table._scope:AddConnection((hit :: any).MouseLeave:Connect(function()
				if table.hovered == list:IndexFor(row) then
					table.hovered = nil
				end

				table:Render()
			end))

			table._scope:AddConnection((hit :: any).MouseButton1Click:Connect(function()
				local selected = list:IndexFor(row)

				if selected then
					table:Focus()
					table:Select(selected, true)
				end
			end))
		end

		local data = table.rows[index]

		for position, column in ipairs(columns) do
			set(cells[position], "Text", cellText((data :: any)[column.key]))
		end
	end)

	table:Render()
	surface.scope:Add(table)

	return table
end

function Table:Render()
	if self.destroyed then
		return
	end

	local count = #self.rows
	local selected = self.selected

	if selected and (selected < 1 or selected > count) then
		selected = nil
		self.selected = nil
	end

	set(self._empty, "Visible", count == 0)
	set(self._list.frame, "Visible", count > 0)
	set(self._stroke, "Transparency", if self.focused then 0 else 1)

	self._list:Refresh(true)

	for slot, row in ipairs(self._list.rows) do
		local index = self._list:IndexFor(row)

		if index then
			local isSelected = index == self.selected
			set(row, "BackgroundTransparency", if isSelected then 0 else 1)

			if isSelected then
				set(row, "BackgroundColor3", self.surface:Color("selected"))
			end
		end
	end
end

function Table:SetRows(rows: { any })
	if self.destroyed then
		return
	end

	self.rows = rows or {}
	self._list:SetCount(#self.rows)

	if self.selected and self.selected > #self.rows then
		self.selected = if #self.rows > 0 then #self.rows else nil
	end

	self:Render()
end

function Table:GetRows(): { any }
	return self.rows
end

function Table:SetSelected(index: number?)
	if self.destroyed then
		return
	end

	if index == nil then
		self.selected = nil
	else
		self.selected = math.clamp(math.floor(index), 1, math.max(1, #self.rows))

		if #self.rows == 0 then
			self.selected = nil
		end
	end

	if self.selected then
		self._list:ScrollToIndex(self.selected)
	end

	self:Render()
end

function Table:GetSelected(): number?
	return self.selected
end

function Table:GetSelectedRow(): any?
	if self.selected then
		return self.rows[self.selected]
	end

	return nil
end

function Table:ScrollToIndex(index: number)
	self._list:ScrollToIndex(index)
end

function Table:Select(index: number, fire: boolean)
	self:SetSelected(index)

	if fire and self.onSelect and self.selected then
		self.onSelect(self.rows[self.selected], self.selected)
	end
end

function Table:SetVisible(value: boolean)
	set(self.instance, "Visible", value)
end

function Table:SetFocus(value: boolean)
	if self.destroyed then
		return
	end

	self.focused = value
	self:Render()
end

function Table:Focus()
	self:SetFocus(true)
end

function Table:Blur()
	self:SetFocus(false)
end




function Table:HandleArrow(direction: string): boolean
	if self.destroyed or #self.rows == 0 then
		return false
	end

	if direction ~= "up" and direction ~= "down" then
		return false
	end

	local step = if direction == "down" then 1 else -1

	if not self.selected then
		self.selected = if step > 0 then 1 else #self.rows
	else
		self.selected = math.clamp(self.selected + step, 1, #self.rows)
	end

	self:ScrollToIndex(self.selected)
	self:Render()

	return true
end

function Table:Activate()
	if self.destroyed or not self.selected or not self.onSelect then
		return
	end

	self.onSelect(self.rows[self.selected], self.selected)
end

function Table:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Table
end

__defs["components.Toggle"] = function()







local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local State = __require("runtime.State")

export type Config = {
	text: string?,
	note: string?,
	value: boolean?,
	enabled: boolean?,
	onChange: ((value: boolean) -> ())?,
}

export type Toggle = {
	surface: Surface.Surface,
	instance: Instance,
	value: boolean,
	enabled: boolean,
	hovered: boolean,
	focused: boolean,
	destroyed: boolean,
	onChange: ((value: boolean) -> ())?,
	_scope: Scope.Scope,
	_track: Instance,
	_knob: Instance,
	_label: Instance,
	_note: Instance?,

	Render: (self: Toggle) -> (),
	SetValue: (self: Toggle, value: boolean) -> (),
	GetValue: (self: Toggle) -> boolean,
	SetEnabled: (self: Toggle, value: boolean) -> (),
	SetVisible: (self: Toggle, value: boolean) -> (),
	Activate: (self: Toggle) -> (),
	SetFocus: (self: Toggle, value: boolean) -> (),
	Focus: (self: Toggle) -> (),
	Blur: (self: Toggle) -> (),
	Destroy: (self: Toggle) -> (),
}

local Toggle = {}
Toggle.__index = Toggle

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

function Toggle.new(surface: Surface.Surface, config: Config?): Toggle
	local settings = config or {}
	local noteText = settings.note
	local rowHeight = Tokens.Row(surface.density) + (if noteText then Tokens.Space.md else 0)
	local textWidth = Tokens.Size.toggleWidth + Tokens.Space.xxl

	local instance = surface:Create("TextButton", {
		Name = "Toggle",
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
		Size = UDim2.new(1, -textWidth, 0, if noteText then 16 else rowHeight),
		Position = UDim2.new(0, 0, 0, if noteText then Tokens.Space.xs else 0),
	})

	set(label, "Parent", instance)

	local note: Instance? = nil
	if noteText then
		local noteLabel = surface:Label({
			Name = "Note",
			Text = noteText,
			Font = surface:Font("small"),
			TextSize = surface:Text("small"),
			TextColor3 = surface:Color("muted"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, -textWidth, 0, 14),
			Position = UDim2.new(0, 0, 0, rowHeight - 18),
		})

		set(noteLabel, "Parent", instance)
		note = noteLabel
	end

	local track = surface:Raised({
		Name = "Track",
		Size = UDim2.fromOffset(Tokens.Size.toggleWidth, Tokens.Size.toggleHeight),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Tokens.Space.lg, 0.5, 0),
	})

	set(track, "Parent", instance)
	surface:Corner(track, Tokens.Size.toggleHeight / 2)

	local knob = surface:Create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(Tokens.Size.toggleKnob, Tokens.Size.toggleKnob),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Tokens.Space.xxs, 0.5, 0),
		BackgroundColor3 = surface:Color("faint"),
		BorderSizePixel = 0,
	})

	set(knob, "Parent", track)
	surface:Corner(knob, Tokens.Size.toggleKnob / 2)

	local toggle = setmetatable({
		surface = surface,
		instance = instance,
		value = settings.value == true,
		enabled = settings.enabled ~= false,
		hovered = false,
		focused = false,
		destroyed = false,
		onChange = settings.onChange,
		_scope = Scope.new(),
		_track = track,
		_knob = knob,
		_label = label,
		_note = note,
	}, Toggle)

	toggle:Render()

	toggle._scope:AddConnection((instance :: any).MouseEnter:Connect(function()
		toggle.hovered = true
		toggle:Render()
	end))

	toggle._scope:AddConnection((instance :: any).MouseLeave:Connect(function()
		toggle.hovered = false
		toggle:Render()
	end))

	toggle._scope:AddConnection((instance :: any).MouseButton1Click:Connect(function()
		toggle:Activate()
	end))

	surface.scope:Add(toggle)

	return toggle
end

function Toggle:Render()
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

	local on = self.value
	local trackToken = if on then "accent" else "raised"
	local knobToken = if on then "accentInk" else "faint"

	if not self.enabled then
		trackToken = "raised"
		knobToken = "faint"
	end

	set(self._track, "BackgroundColor3", self.surface:Color(trackToken))
	set(self._knob, "BackgroundColor3", self.surface:Color(knobToken))
	set(
		self._knob,
		"Position",
		UDim2.new(
			0,
			if on
				then Tokens.Size.toggleWidth - Tokens.Size.toggleKnob - Tokens.Space.xxs
				else Tokens.Space.xxs,
			0.5,
			0
		)
	)
	set(self._label, "TextColor3", self.surface:Color(if self.enabled then "ink" else "faint"))

	if self._note then
		set(self._note, "TextColor3", self.surface:Color(if self.enabled then "muted" else "faint"))
	end
end

local function assign(self: Toggle, value: boolean, fire: boolean)
	if self.destroyed then
		return
	end

	local changed = self.value ~= value
	self.value = value
	self:Render()

	if changed and fire and self.onChange then
		self.onChange(value)
	end
end

function Toggle:SetValue(value: boolean)
	assign(self, value, false)
end

function Toggle:GetValue(): boolean
	return self.value
end

function Toggle:SetEnabled(value: boolean)
	if self.destroyed then
		return
	end

	self.enabled = value
	self:Render()
end

function Toggle:SetVisible(value: boolean)
	(self.instance :: any).Visible = value
end

function Toggle:Activate()
	if not self.enabled or self.destroyed then
		return
	end

	assign(self, not self.value, true)
end

function Toggle:SetFocus(value: boolean)
	if self.destroyed then
		return
	end

	if value and not self.enabled then
		return
	end

	self.focused = value
	self:Render()
end

function Toggle:Focus()
	self:SetFocus(true)
end

function Toggle:Blur()
	self:SetFocus(false)
end

function Toggle:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Toggle
end

__defs["components.Window"] = function()







local Tokens = __require("design.Tokens")
local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")
local Drag = __require("runtime.Drag")
local Layout = __require("runtime.Layout")
local Focus = __require("runtime.Focus")
local Input = __require("runtime.Input")
local Layer = __require("runtime.Layer")
local Button = __require("components.Button")
local Tab = __require("components.Tab")

export type Config = {
	title: string?,
	subtitle: string?,
	width: number?,
	height: number?,
	resizable: boolean?,
	minimizable: boolean?,
	closable: boolean?,
	displayOrder: number?,
	position: UDim2?,
	toggleKey: Enum.KeyCode?,
}

export type Window = {
	surface: Surface.Surface,
	gui: Instance,
	root: Instance,
	header: Instance,
	body: Instance,
	content: Instance,
	rail: Instance,
	title: Instance,
	subtitle: Instance,
	closeButton: Instance?,
	minimizeButton: Instance?,
	grip: Instance?,
	uiScale: Instance,
	layerScale: Instance,
	headerHeight: number,
	minimized: boolean,
	destroyed: boolean,
	toggleKey: Enum.KeyCode?,
	_scope: Scope.Scope,
	_focus: Focus.Focus,
	_toggleClaim: Input.Claim?,
	_search: any?,
	_layer: Layer.Layer,
	_fullHeight: UDim2,
	_tabs: { Tab.Tab },
	_activeTab: Tab.Tab?,

	GetGui: (self: Window) -> Instance,
	GetRoot: (self: Window) -> Instance,
	GetLayer: (self: Window) -> Layer.Layer,
	GetContent: (self: Window) -> Instance,
	IsVisible: (self: Window) -> boolean,
	IsTyping: (self: Window) -> boolean,
	Show: (self: Window) -> (),
	Hide: (self: Window) -> (),
	ToggleVisible: (self: Window) -> (),
	SetTitle: (self: Window, text: string) -> (),
	SetSubtitle: (self: Window, text: string) -> (),
	SetScale: (self: Window, scale: number) -> (),
	GetToggleKey: (self: Window) -> Enum.KeyCode?,
	SetSearch: (self: Window, target: any) -> (),
	FocusFirst: (self: Window) -> (),
	FocusTab: (self: Window, index: number) -> (),
	HandleInput: (self: Window, input: any, gameProcessed: boolean?) -> boolean,
	Minimize: (self: Window) -> (),
	Restore: (self: Window) -> (),
	tab: (self: Window, config: Tab.Config?) -> Tab.Tab,
	SelectTab: (self: Window, tab: Tab.Tab) -> (),
	Destroy: (self: Window) -> (),
}

local Window = {}
Window.__index = Window

local function prop(instance: Instance, key: string): any
	return (instance :: any)[key]
end

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local function rootPosition(width: number, height: number): UDim2
	return UDim2.new(0.5, -width / 2, 0.5, -height / 2)
end

local function keyDown(keyCode: Enum.KeyCode): boolean
	local ok, value = pcall(function()
		return game:GetService("UserInputService"):IsKeyDown(keyCode)
	end)

	return ok and value == true
end

local function focusedBox(): any?
	local ok, value = pcall(function()
		return game:GetService("UserInputService"):GetFocusedTextBox()
	end)

	if ok and value ~= nil then
		return value
	end

	return nil
end

function Window.new(surface: Surface.Surface, config: Config?): Window
	local settings = config or {}
	local density = surface.density

	local width = settings.width or 560
	local height = settings.height or 420
	local headerHeight = Tokens.Header(density)
	local buttonSize = Tokens.Row(density)
	local fullSize = UDim2.fromOffset(width, height)

	
	
	local toggleClaim =
		Input.Claim(if settings.toggleKey then { settings.toggleKey } else Input.ToggleCandidates)

	if not toggleClaim then
		warn(
			"Basalt: every toggle key candidate is already claimed; this window has no toggle shortcut"
		)
	end

	local window = setmetatable({
		surface = surface,
		gui = nil :: any,
		root = nil :: any,
		header = nil :: any,
		body = nil :: any,
		content = nil :: any,
		rail = nil :: any,
		title = nil :: any,
		subtitle = nil :: any,
		closeButton = nil :: any,
		minimizeButton = nil :: any,
		grip = nil :: any,
		uiScale = nil :: any,
		layerScale = nil :: any,
		headerHeight = headerHeight,
		minimized = false,
		destroyed = false,
		toggleKey = if toggleClaim then toggleClaim.key else nil,
		_scope = Scope.new(),
		_focus = Focus.new(),
		_toggleClaim = toggleClaim,
		_search = nil,
		_layer = nil :: any,
		_fullHeight = fullSize,
		_tabs = {} :: { Tab.Tab },
		_activeTab = nil :: Tab.Tab?,
	}, Window)

	local gui = surface:ScreenGui("Basalt", settings.displayOrder)
	set(gui, "Parent", surface:Parent())

	local root = surface:Frame({
		Name = "Root",
		Size = fullSize,
		Position = settings.position or rootPosition(width, height),
		ClipsDescendants = true,
	})

	set(root, "Parent", gui)

	local uiScale = surface:Scale(root, 1)

	
	
	
	
	local layerFrame = surface:Frame({
		Name = "Overlay",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 55,
		ClipsDescendants = false,
	})

	set(layerFrame, "Parent", gui)

	local layerScale = surface:Scale(layerFrame, 1)
	local layer = Layer.new(layerFrame, function(): number
		return prop(layerScale, "Scale")
	end)

	local header = surface:Well({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerHeight),
	})

	set(header, "Parent", root)

	local title = surface:Label({
		Name = "Title",
		Text = settings.title or "Basalt",
		Font = surface:Font("title"),
		TextSize = surface:Text("title"),
		TextColor3 = surface:Color("ink"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 6),
	})

	set(title, "Parent", header)

	local subtitle = surface:Label({
		Name = "Subtitle",
		Text = settings.subtitle or "",
		Font = surface:Font("small"),
		TextSize = surface:Text("small"),
		TextColor3 = surface:Color("muted"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 24),
	})

	set(subtitle, "Parent", header)

	local buttonY = (headerHeight - buttonSize) / 2

	local closeButton: Instance? = nil
	if settings.closable ~= false then
		local button = Button.new(surface, {
			text = "x",
			variant = "ghost",
			width = buttonSize,
			height = buttonSize,
			onClick = function()
				window:Destroy()
			end,
		})

		set(button.instance, "Name", "Close")
		set(button.instance, "Position", UDim2.new(1, -buttonSize - 4, 0, buttonY))
		set(button.instance, "Parent", header)

		window._scope:Add(button)
		window._focus:Track(button, { group = "header" })

		closeButton = button.instance
	end

	local minimizeButton: Instance? = nil
	if settings.minimizable ~= false then
		local button = Button.new(surface, {
			text = "-",
			variant = "ghost",
			width = buttonSize,
			height = buttonSize,
			onClick = function()
				if window.minimized then
					window:Restore()
				else
					window:Minimize()
				end
			end,
		})

		set(button.instance, "Name", "Minimize")
		set(button.instance, "Position", UDim2.new(1, -buttonSize * 2 - 8, 0, buttonY))
		set(button.instance, "Parent", header)

		window._scope:Add(button)
		window._focus:Track(button, { group = "header" })

		minimizeButton = button.instance
	end

	local seam = surface:Seam({
		Name = "Seam",
		Size = UDim2.new(1, 0, 0, Tokens.Size.seam),
		Position = UDim2.new(0, 0, 0, headerHeight),
	})

	set(seam, "Parent", root)

	local body = surface:Well({
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -(headerHeight + Tokens.Size.seam)),
		Position = UDim2.new(0, 0, 0, headerHeight + Tokens.Size.seam),
	})

	set(body, "Parent", root)

	local railWidth = Tokens.Rail(density)

	local rail = surface:Frame({
		Name = "Rail",
		Size = UDim2.new(0, railWidth, 1, 0),
	})

	set(rail, "Parent", body)
	Layout.List(surface, rail, {
		padding = Tokens.Space.xs,
		horizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	local railSeam = surface:Seam({
		Name = "RailSeam",
		Size = UDim2.new(0, Tokens.Size.seam, 1, 0),
		Position = UDim2.new(0, railWidth, 0, 0),
	})

	set(railSeam, "Parent", body)

	local content = surface:Frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(railWidth + Tokens.Size.seam), 1, 0),
		Position = UDim2.new(0, railWidth + Tokens.Size.seam, 0, 0),
	})

	set(content, "Parent", body)

	local grip: Instance? = nil
	if settings.resizable ~= false then
		local handle = surface:Seam({
			Name = "Grip",
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.new(1, -12, 1, -12),
			Active = true,
		})

		set(handle, "Parent", root)
		grip = handle
	end

	local scale = function(): number
		return prop(uiScale, "Scale")
	end

	window._scope:Add(Drag.Bind(header, root, {
		mode = "move",
		scale = scale,
	}))

	if grip then
		window._scope:Add(Drag.Bind(grip, root, {
			mode = "resize",
			scale = scale,
			minSize = Vector2.new(280, 180),
		}))
	end

	
	
	window._scope:AddConnection((header :: any).InputBegan:Connect(function(input: any)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			layer:Clear()
		end
	end))

	window.gui = gui
	window.root = root
	window.header = header
	window.body = body
	window.content = content
	window.rail = rail
	window.title = title
	window.subtitle = subtitle
	window.closeButton = closeButton
	window.minimizeButton = minimizeButton
	window.grip = grip
	window.uiScale = uiScale
	window.layerScale = layerScale
	window._layer = layer

	local inputService = game:GetService("UserInputService")

	window._scope:AddConnection(
		inputService.InputBegan:Connect(function(input: any, gameProcessed: boolean?)
			window:HandleInput(input, gameProcessed)
		end)
	)

	surface.scope:Add(window)

	return window
end

function Window:GetGui(): Instance
	return self.gui
end

function Window:GetRoot(): Instance
	return self.root
end

function Window:GetContent(): Instance
	return self.content
end

function Window:GetLayer(): Layer.Layer
	return self._layer
end

function Window:IsVisible(): boolean
	return prop(self.gui, "Enabled") == true
end

function Window:Show()
	if self.destroyed then
		return
	end

	set(self.gui, "Enabled", true)
end

function Window:Hide()
	if self.destroyed then
		return
	end

	self._layer:Clear()
	self._focus:Clear()
	set(self.gui, "Enabled", false)
end

function Window:ToggleVisible()
	if self:IsVisible() then
		self:Hide()
	else
		self:Show()
	end
end

function Window:IsTyping(): boolean
	return focusedBox() ~= nil
end

function Window:GetToggleKey(): Enum.KeyCode?
	return self.toggleKey
end

function Window:SetSearch(target: any)
	self._search = target
end

function Window:FocusFirst()
	if self.destroyed then
		return
	end

	self._focus:Next(1)
end

function Window:FocusTab(index: number)
	local tab = self._tabs[index]

	if not tab or tab.destroyed then
		return
	end

	self:SelectTab(tab)
	self._focus:Set(tab.button)
end



function Window:HandleInput(input: any, gameProcessed: boolean?): boolean
	if self.destroyed or gameProcessed == true then
		return false
	end

	local box = focusedBox()

	
	
	
	local capturing = self._focus:Current()

	if
		not box
		and capturing
		and type(capturing.CaptureKey) == "function"
		and capturing:CaptureKey(input)
	then
		return true
	end

	if
		self.toggleKey
		and input.UserInputType == Enum.UserInputType.Keyboard
		and input.KeyCode == self.toggleKey
	then
		if not box then
			self:ToggleVisible()
		end
		return true
	end

	if not self:IsVisible() then
		return false
	end

	
	
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		if self._layer:Dismiss(input) then
			return true
		end
	end

	local action = Input.ActionFor(input, keyDown)

	
	
	if box then
		if action == "escape" then
			pcall(function()
				box:ReleaseFocus(false)
			end)
			self._focus:Clear()
			return true
		end

		if action == "next" or action == "previous" then
			pcall(function()
				box:ReleaseFocus(false)
			end)
			self._focus:Next(if action == "previous" then -1 else 1)
			return true
		end

		if action == "activate" then
			pcall(function()
				box:ReleaseFocus(true)
			end)
			return true
		end

		return false
	end

	
	
	
	local overlay = self._layer:Top()

	if overlay and type(overlay.HandleAction) == "function" then
		local ok, handled = pcall(overlay.HandleAction, overlay, action)

		if ok and handled == true then
			return true
		end
	end

	if action == "next" or action == "previous" then
		
		self._layer:CloseTop()
		self._focus:Next(if action == "previous" then -1 else 1)
		return true
	end

	if action == "left" or action == "right" then
		local current = self._focus:Current()

		if current and type(current.Nudge) == "function" then
			current:Nudge(if action == "left" then -1 else 1)
			return true
		end

		self._focus:Move(action)
		return true
	end

	if action == "up" or action == "down" then
		local current = self._focus:Current()

		
		
		if current and type(current.HandleArrow) == "function" then
			local ok, handled = pcall(current.HandleArrow, current, action)

			if ok and handled == true then
				return true
			end
		end

		self._focus:Move(action)
		return true
	end

	if action == "activate" then
		local current = self._focus:Current()

		if current and type(current.Activate) == "function" then
			current:Activate()
		end
		return true
	end

	if action == "escape" then
		if self._layer:CloseTop() then
			return true
		end

		self._focus:Clear()
		return true
	end

	if action == "search" then
		if self._search then
			self._focus:Set(self._search)

			if type(self._search.Capture) == "function" then
				self._search:Capture()
			end

			return true
		end

		return false
	end

	if action == "nudgeUp" or action == "nudgeDown" then
		local current = self._focus:Current()

		if current and type(current.Nudge) == "function" then
			current:Nudge(if action == "nudgeDown" then -1 else 1)
			return true
		end

		return false
	end

	local number = Input.Number(input, keyDown)

	if number then
		self:FocusTab(number)
		return true
	end

	return false
end

function Window:SetTitle(text: string)
	set(self.title, "Text", text)
end

function Window:SetSubtitle(text: string)
	set(self.subtitle, "Text", text)
end

function Window:SetScale(value: number)
	local scale = math.clamp(value, 0.5, 2)

	
	if scale ~= prop(self.uiScale, "Scale") then
		self._layer:Clear()
	end

	set(self.uiScale, "Scale", scale)
	set(self.layerScale, "Scale", scale)
end

function Window:Minimize()
	if self.destroyed or self.minimized then
		return
	end

	self._layer:Clear()
	self._fullHeight = prop(self.root, "Size")
	self.minimized = true

	set(self.body, "Visible", false)
	set(self.grip, "Visible", false)

	local full = self._fullHeight :: UDim2
	self.surface:Tween(self.root, {
		Size = UDim2.new(full.X.Scale, full.X.Offset, 0, self.headerHeight),
	}, "fast")

	
	self._focus:Refresh()
end

function Window:Restore()
	if self.destroyed or not self.minimized then
		return
	end

	self.minimized = false

	set(self.body, "Visible", true)
	set(self.grip, "Visible", true)
	self.surface:Tween(self.root, { Size = self._fullHeight }, "fast")
end

function Window:tab(config: Tab.Config?): Tab.Tab
	if self.destroyed then
		error("Basalt: cannot add a tab to a destroyed window", 2)
	end

	local tab = Tab.new(
		self.surface,
		self,
		self.rail,
		self.content,
		Tokens.Rail(self.surface.density),
		config
	)

	table.insert(self._tabs, tab)

	if #self._tabs == 1 then
		self:SelectTab(tab)
	end

	return tab
end

function Window:SelectTab(tab: Tab.Tab)
	if self.destroyed or tab.destroyed then
		return
	end

	
	
	self._layer:Clear()

	for _, other in ipairs(self._tabs) do
		if other ~= tab then
			other:Deactivate()
		end
	end

	tab:Activate()
	self._activeTab = tab
	self._focus:Refresh()
end

function Window:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true

	for index = #self._tabs, 1, -1 do
		self._tabs[index]:Destroy()
	end

	table.clear(self._tabs)
	self._activeTab = nil

	if self._toggleClaim then
		self._toggleClaim.release()
		self._toggleClaim = nil
	end

	self._layer:Destroy()
	self._focus:Destroy()

	self._scope:Destroy()

	pcall(function()
		(self.gui :: any):Destroy()
	end)
end

return Window
end

__defs["core.Registry"] = function()





export type Registry = {
	Track: (self: Registry, instance: Instance) -> Instance,
	Untrack: (self: Registry, instance: Instance) -> (),
	Count: (self: Registry) -> number,
	ByClass: (self: Registry) -> { [string]: number },
	Destroy: (self: Registry) -> (),
}

local Registry = {}

function Registry.new(): Registry
	local items: { Instance } = {}
	local destroyed = false
	local registry = {} :: any

	function registry:Track(instance: Instance): Instance
		if destroyed then
			instance:Destroy()
			return instance
		end

		table.insert(items, instance)
		return instance
	end

	function registry:Untrack(instance: Instance)
		local index = table.find(items, instance)
		if index then
			table.remove(items, index)
		end
	end

	function registry:Count(): number
		
		
		local total = 0
		for _, instance in ipairs(items) do
			if instance.Parent ~= nil then
				total += 1
			end
		end
		return total
	end

	function registry:ByClass(): { [string]: number }
		local histogram: { [string]: number } = {}
		for _, instance in ipairs(items) do
			if instance.Parent ~= nil then
				local class = instance.ClassName
				histogram[class] = (histogram[class] or 0) + 1
			end
		end
		return histogram
	end

	function registry:Destroy()
		if destroyed then
			return
		end
		destroyed = true

		for index = #items, 1, -1 do
			local instance = items[index]
			if instance.Parent ~= nil then
				pcall(function()
					instance:Destroy()
				end)
			end
		end

		table.clear(items)
	end

	return registry
end

return Registry
end

__defs["core.Scope"] = function()





export type Scope = {
	Add: (self: Scope, item: any) -> any,
	AddFn: (self: Scope, fn: () -> ()) -> (),
	AddConnection: (self: Scope, connection: any) -> any,
	Count: (self: Scope) -> number,
	IsDestroyed: (self: Scope) -> boolean,
	Destroy: (self: Scope) -> (),
}

local function release(item: any)
	if item == nil then
		return
	end

	local kind = type(item)

	if kind == "function" then
		item()
		return
	end

	if kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
			return
		end
		if type(item.Disconnect) == "function" then
			item:Disconnect()
			return
		end
		if type(item.destroy) == "function" then
			item:destroy()
			return
		end
	end

	if typeof(item) == "Instance" then
		item:Destroy()
	end
end

local Scope = {}

function Scope.new(onError: ((err: any) -> ())?): Scope
	local items: { any } = {}
	local destroyed = false
	local scope = {} :: any

	function scope:Add(item: any): any
		if item == nil then
			return item
		end

		if destroyed then
			
			local ok, err = pcall(release, item)
			if not ok and onError then
				onError(err)
			end
			return item
		end

		table.insert(items, item)
		return item
	end

	function scope:AddFn(fn: () -> ())
		self:Add(fn)
	end

	function scope:AddConnection(connection: any): any
		return self:Add(connection)
	end

	function scope:Count(): number
		return #items
	end

	function scope:IsDestroyed(): boolean
		return destroyed
	end

	function scope:Destroy()
		if destroyed then
			return
		end
		destroyed = true

		
		for index = #items, 1, -1 do
			local ok, err = pcall(release, items[index])
			if not ok and onError then
				onError(err)
			end
		end

		table.clear(items)
	end

	return scope
end

return Scope
end

__defs["design.Motion"] = function()





export type Mode = "full" | "reduced"

export type Token = "instant" | "fast" | "base" | "slow"

local DURATION: { [Token]: number } = {
	instant = 0,
	fast = 0.12,
	base = 0.18,
	slow = 0.24,
}

local EASING: { [string]: Enum.EasingStyle } = {
	out = Enum.EasingStyle.Quad,
	outStrong = Enum.EasingStyle.Quart,
	inOut = Enum.EasingStyle.Sine,
	linear = Enum.EasingStyle.Linear,
}



local DIRECTION: { [string]: Enum.EasingDirection } = {
	["in"] = Enum.EasingDirection.In,
	out = Enum.EasingDirection.Out,
	inOut = Enum.EasingDirection.InOut,
}

local Motion = {}

function Motion.Duration(token: Token, mode: Mode): number
	if mode == "reduced" then
		return 0
	end
	return DURATION[token]
end

function Motion.Easing(style: string, direction: string): (Enum.EasingStyle, Enum.EasingDirection)
	local easing = EASING[style]
	if not easing then
		error("Basalt: unknown easing '" .. tostring(style) .. "'", 2)
	end

	local dir = DIRECTION[direction]
	if not dir then
		error("Basalt: unknown easing direction '" .. tostring(direction) .. "'", 2)
	end

	return easing, dir
end

function Motion.Info(token: Token, mode: Mode, style: string?, direction: string?): TweenInfo
	local easing, dir = Motion.Easing(style or "out", direction or "out")
	return TweenInfo.new(Motion.Duration(token, mode), easing, dir)
end

function Motion.IsInstant(token: Token, mode: Mode): boolean
	return Motion.Duration(token, mode) == 0
end

return Motion
end

__defs["design.Palette"] = function()





export type Pair = { fg: string, bg: string }

export type Result = {
	fg: string,
	bg: string,
	ratio: number,
}

export type Audit = {
	ok: boolean,
	results: { Result },
	failures: { Result },
}



local PAIRS: { Pair } = {
	{ fg = "ink", bg = "well" },
	{ fg = "ink", bg = "frame" },
	{ fg = "ink", bg = "raised" },
	{ fg = "muted", bg = "well" },
	{ fg = "muted", bg = "raised" },
	{ fg = "faint", bg = "well" },
	{ fg = "accent", bg = "well" },
	{ fg = "accentInk", bg = "accent" },
	{ fg = "danger", bg = "well" },
	{ fg = "success", bg = "well" },
	{ fg = "ink", bg = "selected" },
}

local MIN_RATIO = 4.5

local Palette = {}

function Palette.Channels(color: Color3): (number, number, number)
	return color.R, color.G, color.B
end

function Palette.Luminance(color: Color3): number
	local function linear(channel: number): number
		if channel <= 0.04045 then
			return channel / 12.92
		end
		return math.pow((channel + 0.055) / 1.055, 2.4)
	end

	local r, g, b = Palette.Channels(color)
	return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
end

function Palette.Contrast(a: Color3, b: Color3): number
	local first = Palette.Luminance(a)
	local second = Palette.Luminance(b)

	if first < second then
		first, second = second, first
	end

	return (first + 0.05) / (second + 0.05)
end

function Palette.ContrastHex(a: string, b: string): number
	return Palette.Contrast(Color3.fromHex(a), Color3.fromHex(b))
end

function Palette.Audit(theme: { name: string?, colors: { [string]: string } }): Audit
	local results: { Result } = {}
	local failures: { Result } = {}

	for _, pair in ipairs(PAIRS) do
		local fg = theme.colors[pair.fg]
		local bg = theme.colors[pair.bg]

		if type(fg) ~= "string" or type(bg) ~= "string" then
			local missing: Result = { fg = pair.fg, bg = pair.bg, ratio = 0 }
			table.insert(results, missing)
			table.insert(failures, missing)
			continue
		end

		local ratio = Palette.ContrastHex(fg, bg)
		local result: Result = { fg = pair.fg, bg = pair.bg, ratio = ratio }
		table.insert(results, result)

		if ratio < MIN_RATIO then
			table.insert(failures, result)
		end
	end

	return {
		ok = #failures == 0,
		results = results,
		failures = failures,
	}
end

function Palette.Round(ratio: number): number
	return math.floor(ratio * 100 + 0.5) / 100
end

return Palette
end

__defs["design.Themes.bone"] = function()








local theme = {
	name = "bone",
	colors = {
		frame = "#E7E1D6",
		well = "#F5F1E8",
		raised = "#FBF8F1",
		seam = "#CFC7B8",
		seamStrong = "#B8AE9C",
		ink = "#1D1B18",
		muted = "#5C564C",
		faint = "#6E685C",
		accent = "#8A5310",
		accentInk = "#FFF8E9",
		danger = "#A8322A",
		success = "#2F6B4A",
		focus = "#8A5310",
		scrim = "#1D1B18",
		selected = "#E9E0CF",
	},
}

return theme
end

__defs["design.Themes.graphite"] = function()








local theme = {
	name = "graphite",
	colors = {
		frame = "#171614",
		well = "#1D1B18",
		raised = "#26231F",
		seam = "#2E2A25",
		seamStrong = "#3D3830",
		ink = "#EDE7DD",
		muted = "#B5ADA1",
		faint = "#8A8277",
		accent = "#E3A63C",
		accentInk = "#1D1B18",
		danger = "#E4675C",
		success = "#6FB08A",
		focus = "#E3A63C",
		scrim = "#0B0A09",
		selected = "#2E2820",
	},
}

return theme
end

__defs["design.Themes.init"] = function()






local Tokens = __require("design.Tokens")
local graphite = __require("design.Themes.graphite")
local bone = __require("design.Themes.bone")
local signal = __require("design.Themes.signal")

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
end

__defs["design.Themes.signal"] = function()






local theme = {
	name = "signal",
	colors = {
		frame = "#000000",
		well = "#0B0B0B",
		raised = "#171717",
		seam = "#2A2A2A",
		seamStrong = "#3D3D3D",
		ink = "#FFFFFF",
		muted = "#D0D0D0",
		faint = "#A8A8A8",
		accent = "#FFC24B",
		accentInk = "#000000",
		danger = "#FF8A80",
		success = "#7FE0A6",
		focus = "#FFC24B",
		scrim = "#000000",
		selected = "#1F1A0E",
	},
}

return theme
end

__defs["design.Tokens"] = function()





export type Density = "compact" | "comfortable"

export type Validation = {
	ok: boolean,
	missing: { string },
}

local Tokens = {}

Tokens.RequiredColors = {
	"frame",
	"well",
	"raised",
	"seam",
	"seamStrong",
	"ink",
	"muted",
	"faint",
	"accent",
	"accentInk",
	"danger",
	"success",
	"focus",
	"scrim",
	"selected",
}



Tokens.Space = {
	xxs = 2,
	xs = 4,
	sm = 6,
	md = 8,
	lg = 12,
	xl = 16,
	xxl = 24,
}

Tokens.Size = {
	header = { compact = 44, comfortable = 48 },
	row = { compact = 32, comfortable = 44 },
	rail = { compact = 148, comfortable = 160 },
	gap = { compact = 8, comfortable = 10 },
	pad = { compact = 12, comfortable = 14 },
	radiusPanel = 3,
	radiusControl = 2,
	seam = 1,
	toggleWidth = 30,
	toggleHeight = 16,
	toggleKnob = 12,
	sliderTrack = 4,
	sliderKnob = 12,
	badge = 16,
}

Tokens.Text = {
	title = 15,
	body = 13,
	small = 11,
	micro = 10,
	mono = 11,
}

function Tokens.Validate(theme: { name: string?, colors: { [string]: string } }): Validation
	local missing: { string } = {}

	if type(theme) ~= "table" then
		return { ok = false, missing = { "theme" } }
	end

	if type(theme.name) ~= "string" then
		table.insert(missing, "name")
	end

	if type(theme.colors) ~= "table" then
		return { ok = false, missing = { "colors" } }
	end

	for _, key in ipairs(Tokens.RequiredColors) do
		local value = theme.colors[key]
		if type(value) ~= "string" or not string.match(value, "^#%x%x%x%x%x%x$") then
			table.insert(missing, key)
		end
	end

	return { ok = #missing == 0, missing = missing }
end

function Tokens.Row(density: Density): number
	return Tokens.Size.row[density]
end

function Tokens.Rail(density: Density): number
	return Tokens.Size.rail[density]
end

function Tokens.Gap(density: Density): number
	return Tokens.Size.gap[density]
end

function Tokens.Pad(density: Density): number
	return Tokens.Size.pad[density]
end

function Tokens.Header(density: Density): number
	return Tokens.Size.header[density]
end

return Tokens
end

__defs["design.Typography"] = function()






export type Role = "title" | "body" | "small" | "mono"

local SANS = { "BuilderSans", "Montserrat", "SourceSans" }
local MONO = { "BuilderMono", "RobotoMono" }

local WEIGHTS = {
	title = Enum.FontWeight.Bold,
	body = Enum.FontWeight.Regular,
	small = Enum.FontWeight.Medium,
	mono = Enum.FontWeight.Regular,
}

local FALLBACK_ENUM = {
	title = Enum.Font.BuilderSansBold,
	body = Enum.Font.BuilderSans,
	small = Enum.Font.BuilderSansMedium,
	mono = Enum.Font.RobotoMono,
}

local cache: { [string]: Font } = {}

local Typography = {}

local function tryFromName(name: string, weight: Enum.FontWeight): Font?
	local ok, face = pcall(function()
		return Font.fromName(name, weight, Enum.FontStyle.Normal)
	end)
	if ok and face then
		return face
	end
	return nil
end

function Typography.Resolve(role: Role): Font
	local cached = cache[role]
	if cached then
		return cached
	end

	local families = if role == "mono" then MONO else SANS
	local weight = WEIGHTS[role]

	for _, name in ipairs(families) do
		local face = tryFromName(name, weight)
		if face then
			cache[role] = face
			return face
		end
	end

	
	local enumFace = FALLBACK_ENUM[role]
	local ok, face = pcall(function()
		return Font.fromEnum(enumFace)
	end)
	if ok and face then
		cache[role] = face
		return face
	end

	error("Basalt: no usable font for role '" .. role .. "'", 2)
end

function Typography.Reset()
	table.clear(cache)
end

return Typography
end

__defs["runtime.Drag"] = function()






local Scope = __require("core.Scope")

export type Mode = "move" | "resize"

export type BindOptions = {
	scale: number | (() -> number)?,
	mode: Mode?,
	minSize: Vector2?,
	onUpdate: ((position: UDim2, size: UDim2) -> ())?,
}

local Drag = {}

local MIN_SCALE = 0.0001

local function resolveScale(value: number | (() -> number)?): number
	local scale = value

	if type(scale) == "function" then
		scale = scale()
	end

	if type(scale) ~= "number" or scale < MIN_SCALE then
		return 1
	end

	return scale
end




function Drag.Delta(from: Vector2, to: Vector2, scale: number?): Vector2
	local factor = scale or 1

	
	
	if type(factor) ~= "number" or factor < MIN_SCALE then
		factor = 1
	end

	return Vector2.new((to.X - from.X) / factor, (to.Y - from.Y) / factor)
end

function Drag.Move(start: UDim2, delta: Vector2): UDim2
	return UDim2.new(
		start.X.Scale,
		start.X.Offset + delta.X,
		start.Y.Scale,
		start.Y.Offset + delta.Y
	)
end

function Drag.Resize(start: UDim2, delta: Vector2, minimum: Vector2?): UDim2
	local min = minimum or Vector2.new(0, 0)

	local width = math.max(min.X, start.X.Offset + delta.X)
	local height = math.max(min.Y, start.Y.Offset + delta.Y)

	return UDim2.new(start.X.Scale, width, start.Y.Scale, height)
end




function Drag.Clamp(position: UDim2, size: Vector2, viewport: Vector2): UDim2
	local maxX = math.max(0, viewport.X - size.X)
	local maxY = math.max(0, viewport.Y - size.Y)

	local x = math.clamp(position.X.Offset, 0, maxX)
	local y = math.clamp(position.Y.Offset, 0, maxY)

	return UDim2.new(position.X.Scale, x, position.Y.Scale, y)
end

local function isDragStart(input: any): boolean
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

local function isDragMove(input: any): boolean
	local kind = input.UserInputType

	if kind == Enum.UserInputType.Touch then
		return true
	end

	
	return kind == Enum.UserInputType.MouseMovement
end

function Drag.Bind(handle: Instance, target: Instance, options: BindOptions?): Scope.Scope
	local settings = options or {}
	local scope = Scope.new()
	local mode = settings.mode or "move"
	local minimum = settings.minSize or Vector2.new(180, 120)

	local dragging = false
	local startPointer = Vector2.new(0, 0)
	local startPosition: UDim2 = (target :: any).Position
	local startSize: UDim2 = (target :: any).Size

	local function pointerOf(input: any): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end

	scope:AddConnection((handle :: any).InputBegan:Connect(function(input: any)
		if not isDragStart(input) then
			return
		end

		dragging = true
		startPointer = pointerOf(input)
		startPosition = (target :: any).Position
		startSize = (target :: any).Size
	end))

	local inputService = game:GetService("UserInputService")

	scope:AddConnection(inputService.InputChanged:Connect(function(input: any)
		if not dragging or not isDragMove(input) then
			return
		end

		local delta = Drag.Delta(startPointer, pointerOf(input), resolveScale(settings.scale))

		if mode == "resize" then
			(target :: any).Size = Drag.Resize(startSize, delta, minimum)
		else
			(target :: any).Position = Drag.Move(startPosition, delta)
		end

		if settings.onUpdate then
			settings.onUpdate((target :: any).Position, (target :: any).Size)
		end
	end))

	scope:AddConnection(inputService.InputEnded:Connect(function(input: any)
		if not isDragStart(input) then
			return
		end

		dragging = false
	end))

	return scope
end

return Drag
end

__defs["runtime.Focus"] = function()











export type Focusable = {
	instance: Instance,
	enabled: boolean?,
	destroyed: boolean?,
	SetFocus: (self: any, value: boolean) -> (),
	Activate: ((self: any) -> ())?,
	Nudge: ((self: any, direction: number) -> ())?,
	HandleArrow: ((self: any, direction: string) -> boolean)?,
	Capture: ((self: any) -> ())?,
}

export type Options = {
	group: string?,
}

export type Entry = {
	control: any,
	group: string,
	order: number,
}

export type Focus = {
	entries: { Entry },
	current: Entry?,
	destroyed: boolean,
	_nextOrder: number,

	Track: (self: Focus, control: any, options: Options?) -> Entry,
	Untrack: (self: Focus, control: any) -> (),
	Set: (self: Focus, target: any) -> (),
	Clear: (self: Focus) -> (),
	Current: (self: Focus) -> any?,
	CurrentEntry: (self: Focus) -> Entry?,
	Next: (self: Focus, delta: number) -> (),
	Move: (self: Focus, direction: string) -> boolean,
	Refresh: (self: Focus) -> (),
	Destroy: (self: Focus) -> (),
}

local Focus = {}
Focus.__index = Focus

local function isVisible(instance: Instance): boolean
	local node: any = instance

	while node do
		local ok, value = pcall(function()
			return node.Visible
		end)

		if ok and value == false then
			return false
		end

		node = node.Parent
	end

	return true
end

local function alive(entry: Entry): boolean
	local control = entry.control

	if type(control) ~= "table" then
		return false
	end
	if control.destroyed == true then
		return false
	end
	if control.enabled == false then
		return false
	end

	local instance = control.instance

	if instance == nil or (instance :: any).Parent == nil then
		return false
	end

	return isVisible(instance)
end

local function center(entry: Entry): Vector2
	local instance = entry.control.instance :: any
	local position = instance.AbsolutePosition
	local size = instance.AbsoluteSize

	return position + size * 0.5
end

function Focus.new(): Focus
	return setmetatable({
		entries = {},
		current = nil,
		destroyed = false,
		_nextOrder = 1,
	}, Focus)
end

function Focus:Track(control: any, options: Options?): Entry
	local settings = options or {}
	local entry: Entry = {
		control = control,
		group = settings.group or "default",
		order = self._nextOrder,
	}

	self._nextOrder += 1
	table.insert(self.entries, entry)

	return entry
end

function Focus:Untrack(control: any)
	for index = #self.entries, 1, -1 do
		local entry = self.entries[index]

		if entry.control == control then
			if self.current == entry then
				self.current = nil
			end
			table.remove(self.entries, index)
		end
	end
end

function Focus:Current(): any?
	return if self.current then self.current.control else nil
end

function Focus:CurrentEntry(): Entry?
	return self.current
end

local function blur(entry: Entry?)
	if not entry then
		return
	end

	local control = entry.control

	if
		type(control) == "table"
		and type(control.SetFocus) == "function"
		and control.destroyed ~= true
	then
		pcall(control.SetFocus, control, false)
	end
end

function Focus:Set(target: any)
	if self.destroyed then
		return
	end

	local entry: Entry? = nil

	if type(target) == "table" and target.control ~= nil and target.order ~= nil then
		entry = target
	else
		for _, candidate in ipairs(self.entries) do
			if candidate.control == target then
				entry = candidate
				break
			end
		end
	end

	if entry and not alive(entry) then
		return
	end

	if self.current == entry then
		return
	end

	local previous = self.current
	self.current = entry
	blur(previous)

	if entry then
		local control = entry.control

		if type(control.SetFocus) == "function" then
			pcall(control.SetFocus, control, true)
		end
	end
end

function Focus:Clear()
	if self.destroyed then
		return
	end

	local previous = self.current
	self.current = nil
	blur(previous)
end

local function reachable(self: Focus): { Entry }
	local list = {}

	for _, entry in ipairs(self.entries) do
		if alive(entry) then
			table.insert(list, entry)
		end
	end

	table.sort(list, function(left, right)
		return left.order < right.order
	end)

	return list
end

function Focus:Next(delta: number)
	if self.destroyed then
		return
	end

	local list = reachable(self)

	if #list == 0 then
		self:Clear()
		return
	end

	local index = nil

	if self.current then
		index = table.find(list, self.current)
	end

	if not index then
		self:Set(if delta < 0 then list[#list] else list[1])
		return
	end

	local nextIndex = ((index - 1 + delta) % #list) + 1
	self:Set(list[nextIndex])
end

function Focus:Move(direction: string): boolean
	if self.destroyed then
		return false
	end

	local list = reachable(self)

	if #list == 0 then
		self:Clear()
		return false
	end

	if not self.current then
		self:Set(list[1])
		return true
	end

	local group = self.current.group
	local candidates = {}

	for _, entry in ipairs(list) do
		if entry.group == group and entry ~= self.current then
			table.insert(candidates, entry)
		end
	end

	if #candidates == 0 then
		return false
	end

	local origin = center(self.current)
	local best: Entry? = nil
	local bestScore = math.huge
	local anyGeometry = false

	for _, entry in ipairs(candidates) do
		local point = center(entry)
		local dx = point.X - origin.X
		local dy = point.Y - origin.Y

		if dx ~= 0 or dy ~= 0 then
			anyGeometry = true
		end

		local primary, secondary = 0, 0

		if direction == "right" then
			primary, secondary = dx, math.abs(dy)
		elseif direction == "left" then
			primary, secondary = -dx, math.abs(dy)
		elseif direction == "down" then
			primary, secondary = dy, math.abs(dx)
		elseif direction == "up" then
			primary, secondary = -dy, math.abs(dx)
		else
			return false
		end

		if primary > 0.5 then
			local score = primary + secondary * 2

			if score < bestScore then
				bestScore = score
				best = entry
			end
		end
	end

	if best then
		self:Set(best)
		return true
	end

	
	
	if not anyGeometry then
		if direction == "down" or direction == "right" then
			self:Next(1)
		else
			self:Next(-1)
		end
		return true
	end

	return false
end

function Focus:Refresh()
	if self.destroyed then
		return
	end

	if self.current and not alive(self.current) then
		self:Clear()
	end
end

function Focus:Destroy()
	if self.destroyed then
		return
	end

	self:Clear()
	self.destroyed = true
	table.clear(self.entries)
end

return Focus
end

__defs["runtime.Input"] = function()










export type Action =
	"next"
	| "previous"
	| "up"
	| "down"
	| "left"
	| "right"
	| "activate"
	| "escape"
	| "search"
	| "nudgeUp"
	| "nudgeDown"

export type Binding = {
	key: Enum.KeyCode,
	shift: boolean?,
}

export type Claim = {
	key: Enum.KeyCode,
	release: () -> (),
}

local Input = {}

Input.Actions = {
	next = { key = Enum.KeyCode.Tab },
	previous = { key = Enum.KeyCode.Tab, shift = true },
	up = { key = Enum.KeyCode.Up },
	down = { key = Enum.KeyCode.Down },
	left = { key = Enum.KeyCode.Left },
	right = { key = Enum.KeyCode.Right },
	activate = { key = Enum.KeyCode.Return },
	escape = { key = Enum.KeyCode.Escape },
	search = { key = Enum.KeyCode.Slash },
	nudgeUp = { key = Enum.KeyCode.Equals },
	nudgeDown = { key = Enum.KeyCode.Minus },
} :: { [string]: Binding }

Input.ToggleCandidates = {
	Enum.KeyCode.RightShift,
	Enum.KeyCode.RightControl,
	Enum.KeyCode.Insert,
}

local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

local function globalStore(): { [string]: any }?
	local ok, environment = pcall(getfenv, 0)

	if not ok or type(environment) ~= "table" then
		return nil
	end

	local writable = pcall(function()
		environment.__BASALT_PROBE = true
	end)

	environment.__BASALT_PROBE = nil

	if not writable then
		return nil
	end

	local claims = environment.__BASALT_KEY_CLAIMS

	if type(claims) ~= "table" then
		claims = {}
		environment.__BASALT_KEY_CLAIMS = claims
	end

	return claims
end

local function shiftHeld(isDown: ((Enum.KeyCode) -> boolean)?): boolean
	if not isDown then
		return false
	end

	local ok, value = pcall(function()
		return isDown(Enum.KeyCode.LeftShift) == true or isDown(Enum.KeyCode.RightShift) == true
	end)

	return ok and value == true
end

function Input.ActionFor(input: any, isDown: ((Enum.KeyCode) -> boolean)?): Action?
	if type(input) ~= "table" or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return nil
	end

	local key = input.KeyCode

	if key == Enum.KeyCode.Tab then
		return if shiftHeld(isDown) then "previous" else "next"
	end

	
	if key == Enum.KeyCode.Space then
		return "activate"
	end

	for action, binding in pairs(Input.Actions) do
		if binding.key == key and not binding.shift then
			return action :: Action
		end
	end

	return nil
end




function Input.Number(input: any, isDown: ((Enum.KeyCode) -> boolean)?): number?
	if type(input) ~= "table" or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return nil
	end

	if shiftHeld(isDown) then
		return nil
	end

	local index = table.find(NUMBER_KEYS, input.KeyCode)

	if index then
		return index
	end

	return nil
end




function Input.Claim(candidates: { Enum.KeyCode }): Claim
	local list = if #candidates > 0 then candidates else Input.ToggleCandidates
	local claims = globalStore()

	if not claims then
		return {
			key = list[1],
			release = function() end,
		}
	end

	for _, key in ipairs(list) do
		if claims[key.Name] ~= true then
			claims[key.Name] = true

			return {
				key = key,
				release = function()
					claims[key.Name] = nil
				end,
			}
		end
	end

	
	
	return nil :: any
end

return Input
end

__defs["runtime.Layer"] = function()











export type Overlay = {
	Close: (self: any) -> (),
	Dismiss: ((self: any, input: any) -> boolean)?,
}

export type Layer = {
	frame: Instance,
	stack: { any },
	destroyed: boolean,
	_scaleOf: (() -> number)?,

	Push: (self: Layer, overlay: any) -> (),
	Pop: (self: Layer, overlay: any) -> (),
	Top: (self: Layer) -> any?,
	CloseTop: (self: Layer) -> boolean,
	Dismiss: (self: Layer, input: any) -> boolean,
	Clear: (self: Layer) -> (),
	ToLocal: (self: Layer, screen: Vector2) -> Vector2,
	Pixels: (self: Layer, value: number) -> number,
	Destroy: (self: Layer) -> (),
}

local Layer = {}
Layer.__index = Layer

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

function Layer.new(frame: Instance, scaleOf: (() -> number)?): Layer
	return setmetatable({
		frame = frame,
		stack = {},
		destroyed = false,
		_scaleOf = scaleOf,
	}, Layer)
end

local function scaleOf(layer: Layer): number
	if not layer._scaleOf then
		return 1
	end

	local ok, value = pcall(layer._scaleOf)

	if not ok or type(value) ~= "number" or value <= 0 then
		return 1
	end

	return value
end

function Layer:Push(overlay: any)
	if self.destroyed then
		return
	end

	self:Pop(overlay)
	table.insert(self.stack, overlay)
end

function Layer:Pop(overlay: any)
	for index = #self.stack, 1, -1 do
		if self.stack[index] == overlay then
			table.remove(self.stack, index)
		end
	end
end

function Layer:Top(): any?
	return self.stack[#self.stack]
end

local function close(overlay: any)
	if type(overlay) ~= "table" or type(overlay.Close) ~= "function" then
		return
	end

	pcall(overlay.Close, overlay)
end

function Layer:CloseTop(): boolean
	local overlay = self:Top()

	if not overlay then
		return false
	end

	self:Pop(overlay)
	close(overlay)

	return true
end

function Layer:Dismiss(input: any): boolean
	local overlay = self:Top()

	if not overlay then
		return false
	end

	
	
	if type(overlay.Dismiss) == "function" then
		local ok, allowed = pcall(overlay.Dismiss, overlay, input)

		if not ok or allowed ~= true then
			return false
		end
	end

	self:Pop(overlay)
	close(overlay)

	return true
end

function Layer:Clear()
	for index = #self.stack, 1, -1 do
		local overlay = self.stack[index]
		table.remove(self.stack, index)
		close(overlay)
	end
end



function Layer:ToLocal(screen: Vector2): Vector2
	local origin = (self.frame :: any).AbsolutePosition
	local factor = scaleOf(self)

	return Vector2.new((screen.X - origin.X) / factor, (screen.Y - origin.Y) / factor)
end

function Layer:Pixels(value: number): number
	return value / scaleOf(self)
end

function Layer:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self:Clear()

	pcall(function()
		(self.frame :: any):Destroy()
	end)
end

return Layer
end

__defs["runtime.Layout"] = function()






local Tokens = __require("design.Tokens")
local Surface = __require("runtime.Surface")

export type Density = "compact" | "comfortable"

export type ListOptions = {
	padding: number?,
	direction: "horizontal" | "vertical"?,
	horizontalAlignment: Enum.HorizontalAlignment?,
	verticalAlignment: Enum.VerticalAlignment?,
}

local Layout = {}

function Layout.Offset(x: number?, y: number?): UDim2
	return UDim2.fromOffset(x or 0, y or 0)
end

function Layout.Scale(x: number?, y: number?): UDim2
	return UDim2.fromScale(x or 0, y or 0)
end

function Layout.Fill(width: number?, height: number?): UDim2
	return UDim2.fromScale(width or 1, height or 1)
end

function Layout.Row(density: Density): UDim2
	return UDim2.new(1, 0, 0, Tokens.Row(density))
end




function Layout.List(surface: Surface.Surface, parent: Instance, options: ListOptions?): Instance
	local settings = options or {}

	local layout = surface:Create("UIListLayout", {
		Padding = UDim.new(0, settings.padding or Tokens.Space.sm),
		FillDirection = if settings.direction == "horizontal"
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical,
		HorizontalAlignment = settings.horizontalAlignment or Enum.HorizontalAlignment.Left,
		VerticalAlignment = settings.verticalAlignment or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local target = layout :: any
	target.Parent = parent
	return layout
end

function Layout.Padding(surface: Surface.Surface, parent: Instance, padding: number): Instance
	local pad = surface:Create("UIPadding", {
		PaddingTop = UDim.new(0, padding),
		PaddingBottom = UDim.new(0, padding),
		PaddingLeft = UDim.new(0, padding),
		PaddingRight = UDim.new(0, padding),
	})
	local target = pad :: any
	target.Parent = parent
	return pad
end

return Layout
end

__defs["runtime.State"] = function()







local Tokens = __require("design.Tokens")

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
end

__defs["runtime.Surface"] = function()










local Registry = __require("core.Registry")
local Scope = __require("core.Scope")
local Typography = __require("design.Typography")
local Tokens = __require("design.Tokens")
local Motion = __require("design.Motion")

export type Theme = {
	name: string,
	colors: { [string]: string },
}

export type Density = "compact" | "comfortable"

export type Resolver = {
	hidden: () -> Instance?,
	coreGui: () -> Instance?,
	playerGui: () -> Instance?,
}

export type Config = {
	theme: Theme,
	density: Density?,
	motion: Motion.Mode?,
	registry: Registry.Registry?,
	scope: Scope.Scope?,
	resolver: Resolver?,
}

export type Props = { [string]: any }

export type Surface = {
	theme: Theme,
	density: Density,
	motion: Motion.Mode,
	registry: Registry.Registry,
	scope: Scope.Scope,
	resolver: Resolver,
	_colors: { [string]: Color3 },
	_fonts: { [string]: Font },
	_destroyed: boolean,

	Color: (self: Surface, name: string) -> Color3,
	Text: (self: Surface, role: string) -> number,
	Font: (self: Surface, role: string) -> Font,
	Parent: (self: Surface) -> Instance,
	Create: (self: Surface, className: string, props: Props?, parent: Instance?) -> Instance,
	Apply: (self: Surface, instance: Instance, props: Props) -> Instance,
	Frame: (self: Surface, props: Props?) -> Instance,
	Well: (self: Surface, props: Props?) -> Instance,
	Raised: (self: Surface, props: Props?) -> Instance,
	Label: (self: Surface, props: Props?) -> Instance,
	Button: (self: Surface, props: Props?) -> Instance,
	Seam: (self: Surface, props: Props?) -> Instance,
	ScreenGui: (self: Surface, name: string, displayOrder: number?) -> Instance,
	Corner: (self: Surface, instance: Instance, radius: number?) -> Instance,
	Stroke: (self: Surface, instance: Instance, colorName: string, thickness: number?) -> Instance,
	Scale: (self: Surface, instance: Instance, scale: number?) -> Instance,
	Pad: (self: Surface, instance: Instance, padding: number?) -> Instance,
	Tween: (self: Surface, instance: Instance, goal: Props, token: string, style: string?) -> any,
	Destroy: (self: Surface) -> (),
}

local Surface = {}
Surface.__index = Surface








local function globalFunction(name: string): (() -> any)?
	local ok, environment = pcall(getfenv, 0)

	if ok and type(environment) == "table" then
		local value = environment[name]
		if type(value) == "function" then
			return value
		end
	end

	return nil
end

local function callOptional(fn: (() -> any)?): any
	if not fn then
		return nil
	end

	local ok, value = pcall(fn)
	if ok then
		return value
	end

	return nil
end

local DEFAULT_RESOLVER: Resolver = {
	hidden = function()
		return callOptional(globalFunction("gethui"))
	end,
	coreGui = function()
		local ok, service = pcall(function()
			return game:GetService("CoreGui")
		end)
		if ok then
			return service
		end
		return nil
	end,
	playerGui = function()
		local ok, gui = pcall(function()
			local players = game:GetService("Players")
			return players.LocalPlayer:WaitForChild("PlayerGui")
		end)
		if ok then
			return gui
		end
		return nil
	end,
}





function Surface.new(config: Config): Surface
	local surface = setmetatable({
		theme = config.theme,
		density = config.density or "compact",
		motion = config.motion or "full",
		registry = config.registry or Registry.new(),
		scope = config.scope or Scope.new(),
		resolver = config.resolver or DEFAULT_RESOLVER,
		_colors = {} :: { [string]: Color3 },
		_fonts = {} :: { [string]: Font },
		_destroyed = false,
	}, Surface)

	return surface
end

function Surface:Color(name: string): Color3
	local cached = self._colors[name]

	if cached then
		return cached
	end

	local hex = self.theme.colors[name]

	if type(hex) ~= "string" then
		error(string.format("Basalt: theme '%s' has no color token '%s'", self.theme.name, name), 2)
	end

	local color = Color3.fromHex(hex)
	self._colors[name] = color

	return color
end



function Surface:Text(role: string): number
	local size = (Tokens.Text :: any)[role]

	if type(size) ~= "number" then
		error(string.format("Basalt: no text size for role '%s'", role), 2)
	end

	return size
end

function Surface:Font(role: string): Font
	local cached = self._fonts[role]

	if cached then
		return cached
	end

	local face = Typography.Resolve(role :: any)
	self._fonts[role] = face

	return face
end

function Surface:Parent(): Instance
	
	
	
	local hidden = self.resolver.hidden()
	if hidden then
		return hidden
	end

	local core = self.resolver.coreGui()
	if core then
		return core
	end

	local player = self.resolver.playerGui()
	if player then
		return player
	end

	error("Basalt: no usable GUI parent (gethui, CoreGui and PlayerGui all failed)", 2)
end

function Surface:Apply(instance: Instance, props: Props): Instance
	local target = instance :: any

	for key, value in pairs(props) do
		target[key] = value
	end

	return instance
end

function Surface:Create(className: string, props: Props?, parent: Instance?): Instance
	local instance = Instance.new(className)

	if props then
		self:Apply(instance, props)
	end

	self.registry:Track(instance)

	if parent then
		(instance :: any).Parent = parent
	end

	return instance
end

function Surface:Frame(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("frame"),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("Frame", merged)
end

function Surface:Well(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("well"),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("Frame", merged)
end

function Surface:Raised(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("raised"),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("Frame", merged)
end

function Surface:Label(props: Props?): Instance
	local merged: Props = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = self:Font("body"),
		TextColor3 = self:Color("ink"),
		TextSize = self:Text("body"),
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("TextLabel", merged)
end

function Surface:Button(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("raised"),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = self:Font("body"),
		TextColor3 = self:Color("ink"),
		TextSize = self:Text("body"),
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("TextButton", merged)
end

function Surface:Seam(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("seam"),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("Frame", merged)
end

function Surface:ScreenGui(name: string, displayOrder: number?): Instance
	local gui = self:Create("ScreenGui", {
		Name = name,
		DisplayOrder = displayOrder or 0,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local protect = globalFunction("protect_gui")
	if protect then
		pcall(protect, gui)
	end

	return gui
end

function Surface:Corner(instance: Instance, radius: number?): Instance
	local corner = self:Create("UICorner", {
		CornerRadius = UDim.new(0, radius or Tokens.Size.radiusControl),
	})
	local target = corner :: any
	target.Parent = instance
	return corner
end

function Surface:Stroke(instance: Instance, colorName: string, thickness: number?): Instance
	local stroke = self:Create("UIStroke", {
		Color = self:Color(colorName),
		Thickness = thickness or Tokens.Size.seam,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local target = stroke :: any
	target.Parent = instance
	return stroke
end

function Surface:Scale(instance: Instance, scale: number?): Instance
	local uiScale = self:Create("UIScale", {
		Scale = scale or 1,
	})
	local target = uiScale :: any
	target.Parent = instance
	return uiScale
end

function Surface:Pad(instance: Instance, padding: number?): Instance
	local value = padding or Tokens.Pad(self.density)

	local pad = self:Create("UIPadding", {
		PaddingTop = UDim.new(0, value),
		PaddingBottom = UDim.new(0, value),
		PaddingLeft = UDim.new(0, value),
		PaddingRight = UDim.new(0, value),
	})
	local target = pad :: any
	target.Parent = instance
	return pad
end





function Surface:Tween(instance: Instance, goal: Props, token: string, style: string?): any
	local duration = Motion.Duration(token :: any, self.motion)

	if duration <= 0 then
		self:Apply(instance, goal)
		return nil
	end

	local ok, tween = pcall(function()
		local service = game:GetService("TweenService")
		local created =
			service:Create(instance, Motion.Info(token :: any, self.motion, style, "out"), goal)
		created:Play()
		return created
	end)

	if not ok then
		self:Apply(instance, goal)
		return nil
	end

	return tween
end

function Surface:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self.scope:Destroy()
	self.registry:Destroy()
end

return Surface
end

__defs["runtime.VirtualList"] = function()










local Scope = __require("core.Scope")
local Surface = __require("runtime.Surface")

export type Render = (index: number, row: Instance) -> ()

export type Config = {
	rowHeight: number,
	height: number,
	count: number?,
	render: Render?,
	zIndex: number?,
}

export type VirtualList = {
	surface: Surface.Surface,
	frame: Instance,
	rows: { Instance },
	scope: Scope.Scope,
	rowHeight: number,
	height: number,
	visible: number,
	count: number,
	render: Render?,
	_indices: { [Instance]: number },
	_start: number,
	destroyed: boolean,
	_zIndex: number,

	SetCount: (self: VirtualList, count: number) -> (),
	SetSize: (self: VirtualList, height: number) -> (),
	GetCount: (self: VirtualList) -> number,
	SetRender: (self: VirtualList, render: Render) -> (),
	Refresh: (self: VirtualList, force: boolean?) -> (),
	ScrollToIndex: (self: VirtualList, index: number) -> (),
	RowFor: (self: VirtualList, index: number) -> Instance?,
	IndexFor: (self: VirtualList, row: Instance) -> number?,
	VisibleRange: (self: VirtualList) -> (number, number),
	Destroy: (self: VirtualList) -> (),
	_grow: (self: VirtualList, poolSize: number) -> (),
}

local VirtualList = {}
VirtualList.__index = VirtualList

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local function watched(scope: Scope.Scope, instance: Instance, property: string, fn: () -> ())
	local signal = (instance :: any):GetPropertyChangedSignal(property)
	scope:AddConnection(signal:Connect(fn))
end

function VirtualList.new(surface: Surface.Surface, parent: Instance, config: Config): VirtualList
	local rowHeight = config.rowHeight
	local height = config.height
	local visible = math.max(1, math.ceil(height / rowHeight))
	local poolSize = visible + 2
	local zIndex = config.zIndex or 2

	local frame = surface:Create("ScrollingFrame", {
		Name = "VirtualList",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = surface:Color("seamStrong"),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true,
		ZIndex = zIndex,
	})

	set(frame, "Parent", parent)

	local list = setmetatable({
		surface = surface,
		frame = frame,
		rows = {},
		scope = Scope.new(),
		rowHeight = rowHeight,
		height = height,
		visible = visible,
		count = 0,
		render = config.render,
		_indices = {},
		_start = -1,
		destroyed = false,
		_zIndex = zIndex,
	}, VirtualList)

	list:_grow(poolSize)

	watched(list.scope, frame, "CanvasPosition", function()
		list:Refresh()
	end)

	if config.count then
		list:SetCount(config.count)
	end

	return list
end

function VirtualList:_grow(poolSize: number)
	for index = #self.rows + 1, poolSize do
		local row = self.surface:Frame({
			Name = "Row" .. index,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -2, 0, self.rowHeight),
			Visible = false,
			ZIndex = self._zIndex + 1,
		})

		set(row, "Parent", self.frame)
		table.insert(self.rows, row)
	end
end

function VirtualList:SetSize(height: number)
	local nextHeight = math.max(self.rowHeight, height)

	if nextHeight == self.height then
		return
	end

	self.height = nextHeight
	self.visible = math.max(1, math.ceil(nextHeight / self.rowHeight))

	set(self.frame, "Size", UDim2.new(1, 0, 0, nextHeight))
	self:_grow(self.visible + 2)
	self:Refresh(true)
end

function VirtualList:SetCount(count: number)
	local nextCount = math.max(0, math.floor(count))

	if nextCount == self.count then
		return
	end

	self.count = nextCount
	set(self.frame, "CanvasSize", UDim2.new(0, 0, 0, nextCount * self.rowHeight))
	self:Refresh(true)
end

function VirtualList:GetCount(): number
	return self.count
end

function VirtualList:SetRender(render: Render)
	self.render = render
	self:Refresh(true)
end

function VirtualList:Refresh(force: boolean?)
	if self.destroyed or self.count == 0 then
		self._start = -1

		for _, row in ipairs(self.rows) do
			set(row, "Visible", false)
		end

		return
	end

	local maxStart = math.max(1, self.count - self.visible + 1)
	local offset = (self.frame :: any).CanvasPosition.Y
	local start = math.clamp(math.floor(offset / self.rowHeight) + 1, 1, maxStart)

	if start == self._start and not force then
		return
	end

	self._start = start

	for slot, row in ipairs(self.rows) do
		local index = start + slot - 1

		if index <= self.count then
			self._indices[row] = index
			set(row, "Visible", true)
			set(row, "Position", UDim2.new(0, 0, 0, (index - 1) * self.rowHeight))

			if self.render then
				self.render(index, row)
			end
		else
			self._indices[row] = nil
			set(row, "Visible", false)
		end
	end
end

function VirtualList:ScrollToIndex(index: number)
	local target = math.clamp(index, 1, math.max(1, self.count))
	local maxOffset = math.max(0, self.count * self.rowHeight - self.height)
	local offset = math.clamp((target - 1) * self.rowHeight, 0, maxOffset)

	set(self.frame, "CanvasPosition", Vector2.new(0, offset))
	self:Refresh(true)
end

function VirtualList:RowFor(index: number): Instance?
	for _, row in ipairs(self.rows) do
		if self._indices[row] == index and (row :: any).Visible == true then
			return row
		end
	end

	return nil
end

function VirtualList:IndexFor(row: Instance): number?
	return self._indices[row]
end

function VirtualList:VisibleRange(): (number, number)
	if self.count == 0 then
		return 0, 0
	end

	return self._start, math.min(self.count, self._start + #self.rows - 1)
end

function VirtualList:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self.scope:Destroy()

	pcall(function()
		(self.frame :: any):Destroy()
	end)
end

return VirtualList
end

return __require("init")

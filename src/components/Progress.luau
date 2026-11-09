--!strict
-- Basalt / components / Progress
-- A read-only bar. It is not a Slider with a disabled flag: it has no pointer
-- handlers, no focus, and no onChange, so a status bar cannot be dragged by a
-- user who missed the row above it.
--
-- With text the control is two lines: the label and value sit on top, the bar
-- sits on the bottom edge. Without text it is a bare 8px bar, which is what a
-- header or a table row actually needs.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)

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
	surface:Corner(track, "radiusSmall")

	local fill = surface:Frame({
		Name = "Fill",
		BackgroundColor3 = surface:Color(tone),
		BorderSizePixel = 0,
		Size = UDim2.new(Progress.Ratio(value, minimum, maximum), 0, 1, 0),
	})

	set(fill, "Parent", track)
	surface:Corner(fill, "radiusSmall")

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

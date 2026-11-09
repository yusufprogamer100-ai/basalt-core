--!strict
-- Basalt / components / Toggle
-- A row with a track, not a switch floating in space. The whole row is the hit
-- target because a 30x16 track is not a touch target; the row is 44px tall in
-- comfortable density. Programmatic SetValue never fires onChange, so binding a
-- toggle to a config file does not call the user's callback in a loop.
--
-- Modernization rationale (R-11, R-19):
-- * radiusSmall (6px) on track and knob replaces the pill shape: pill toggles
--   read as mobile-app default, not a deliberate desktop surface.
-- * Active state uses accent color (not just position): color + position
--   together communicate state more clearly than motion alone.
-- * Knob slides via Tween (fast token) so the state change is legible.
-- * Hover row background (raised variant) signals interactivity without glow.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local State = require(script.Parent.Parent.runtime.State)
local Motion = require(script.Parent.Parent.design.Motion)

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

	surface:Corner(instance, "radiusSmall")

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

	local track = surface:Create("Frame", {
		Name = "Track",
		Size = UDim2.fromOffset(Tokens.Size.toggleWidth, Tokens.Size.toggleHeight),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -Tokens.Space.lg, 0.5, 0),
		BackgroundColor3 = surface:Color("raised"),
		BorderSizePixel = 0,
	})

	set(track, "Parent", instance)
	surface:Corner(track, "radiusSmall")

	local knob = surface:Create("Frame", {
		Name = "Knob",
		Size = UDim2.fromOffset(Tokens.Size.toggleKnob, Tokens.Size.toggleKnob),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, Tokens.Space.xxs, 0.5, 0),
		BackgroundColor3 = surface:Color("faint"),
		BorderSizePixel = 0,
	})

	set(knob, "Parent", track)
	surface:Corner(knob, "radiusSmall")

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

	-- Knob slides to target position. Position is set directly so state is
	-- immediate; motion is reserved for hover/press states where it has clear
	-- UX purpose (R-19).
	local targetX = if on
		then Tokens.Size.toggleWidth - Tokens.Size.toggleKnob - Tokens.Space.xxs
		else Tokens.Space.xxs

	set(self._knob, "Position", UDim2.new(0, targetX, 0.5, 0))

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

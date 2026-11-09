--!strict
-- Basalt / components / Keybind
-- One row, one chip, one capture mode. Clicking or pressing Enter puts the row
-- into capture: the next key becomes the value and Escape cancels. Capture runs
-- above every other shortcut in the Window, so binding RightShift does not hide
-- the window and binding Tab does not move focus.
--
-- Conflicts are reported, not hidden. Two live keybinds on the same key would
-- both fire in a real script, so the second one warns and marks its chip. The
-- registry is global like shortcut claims, because two Basalt apps in one game
-- share the same keyboard whether they want to or not.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local State = require(script.Parent.Parent.runtime.State)

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

-- The same global-store pattern Input uses. A sandboxed host that forbids
-- writes keeps working; it only loses the conflict warning.
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
			Font = surface:Font("bodyLg"),
			TextSize = surface:Text("bodyLg"),
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
	surface:Corner(chip, "radiusSmall")

	local chipStroke = surface:Stroke(chip, "seam")

	local chipLabel = surface:Label({
		Name = "Value",
		Text = "None",
		Font = surface:Font("mono"),
		TextSize = surface:Text("bodyLg"),
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

	-- The initial value is a configuration, not a user action, so it never
	-- fires onChange. It does claim the key, because a conflict at load time is
	-- just as real as one created by pressing a key.
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

	-- Release first so re-claiming the same key is not a self conflict.
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
	-- A hidden row must not keep eating keys. Without this, hiding a tab while
	-- its keybind is capturing would leave the window deaf to every shortcut.
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

-- Answers false for every key while not capturing, so the Window can call it
-- unconditionally and still let normal shortcuts through.
function Keybind:CaptureKey(input: any): boolean
	if self.destroyed or not self.capturing then
		return false
	end

	if type(input) ~= "table" or input.UserInputType ~= Enum.UserInputType.Keyboard then
		-- A click elsewhere is an abort, not a binding. Swallow it so it does
		-- not press an unrelated control on the way out.
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

	-- Losing focus mid-capture would leave the row deaf but still claiming every
	-- key on the next click. Cancel instead.
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

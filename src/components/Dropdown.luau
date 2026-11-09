--!strict
-- Basalt / components / Dropdown
-- A value field, not a menu bar. The closed state is one row with a seam; the
-- open state is a raised list in the window overlay. Five hundred options are
-- a number on a canvas, not five hundred instances: the list recycles rows.
--
-- Keyboard belongs to the field. Up and Down move a highlight inside the list,
-- Enter selects, Escape closes. The Window routes those actions; this component
-- never listens for a key on its own.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local State = require(script.Parent.Parent.runtime.State)
local VirtualList = require(script.Parent.Parent.runtime.VirtualList)

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

-- Input positions arrive as Vector3 from UserInputService and as Vector2 from
-- layout math. Both answer X and Y; this is the one conversion point.
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
	surface:Corner(field, "radiusSmall")

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
			Font = surface:Font("bodyLg"),
			TextSize = surface:Text("bodyLg"),
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

	local popup = surface:Elevated(2, {
		Name = "DropdownPopup",
		Size = UDim2.fromOffset(240, listHeight + Tokens.Space.md),
		Visible = false,
		ZIndex = 60,
		ClipsDescendants = true,
	})

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
		Font = surface:Font("bodyLg"),
		TextSize = surface:Text("bodyLg"),
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

	-- Multi starts from a copy, never from the caller's table. A caller mutating
	-- its own array after construction must not silently change the field.
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

	-- A value with no matching option is a caller bug, but hiding it would make
	-- the field look unset. Show the raw value so the mistake is visible.
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

-- The popup is positioned in GUI pixels, not screen pixels. Layer:ToLocal and
-- Layer:Pixels are the only places that know about UIScale.
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

-- Returning true means the Window stops processing this action. An open
-- dropdown owns the arrows, Enter and Escape; a closed one owns only Enter.
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

	-- Left and Right do nothing here, but they must not move focus out from
	-- under an open list. Consume them so the list stays anchored.
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

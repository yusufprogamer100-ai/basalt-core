--!strict
-- Basalt / components / Table
-- A data table, not a grid of controls. The header is fixed, the body is one
-- VirtualList: a thousand rows are a canvas height and visible+2 row instances.
--
-- Column widths are weights, not pixels. Weight math needs no layout pass, so
-- it behaves the same in a real viewport and in a headless test. A single
-- column with weight 1 fills the width; three equal weights split it in thirds.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local VirtualList = require(script.Parent.Parent.runtime.VirtualList)

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

	-- Column geometry is computed once: offset in scale space plus a weight.
	-- There is no measurement here, so a hidden table still lays out correctly.
	local positions = {}
	local offset = 0
	for index, column in ipairs(columns) do
		local width = column.weight / totalWeight
		positions[index] = offset

		local headerCell = surface:Label({
			Name = "Column" .. index,
			Text = column.text or "",
			Font = surface:Font("bodyLg"),
			TextSize = surface:Text("bodyLg"),
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
		TextSize = surface:Text("bodyLg"),
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

	-- The pool renders index, slot. Cells and one hit area are built once per
	-- slot and rewritten on every scroll, so instance count never tracks row
	-- count.
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
					TextSize = surface:Text(if column.mono then "mono" else "bodyLg"),
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

-- Up and Down move the selection while the table owns focus, instead of
-- throwing focus to the next control. The Window asks first and falls back to
-- spatial navigation when this returns false.
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

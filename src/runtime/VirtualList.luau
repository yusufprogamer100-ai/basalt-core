--!strict
-- Basalt / runtime / VirtualList
-- A scrolling list that keeps a fixed pool of rows. Five hundred dropdown
-- options must not mean five hundred instances, so the list owns the geometry
-- and hands rows back to the renderer by index. Row identity is not stable:
-- index 7 is whatever visible slot happens to cover it after a scroll.
--
-- This is the same machinery the table component will use, which is why it is a
-- runtime module instead of a dropdown detail.

local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Surface)

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

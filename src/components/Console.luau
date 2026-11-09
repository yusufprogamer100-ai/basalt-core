--!strict
-- Basalt / components / Console
-- A log viewer, not a text box. Entries live in a ring buffer and render through
-- the same VirtualList the table uses: a thousand lines cost the same eight row
-- instances as eight lines.
--
-- Follow mode is the useful default: new lines keep the view at the bottom, but
-- only when the user was already there. Scrolling up to read does not get yanked
-- back by the next log line.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local VirtualList = require(script.Parent.Parent.runtime.VirtualList)

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
			Font = surface:Font("bodyLg"),
			TextSize = surface:Text("bodyLg"),
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
		TextSize = surface:Text("bodyLg"),
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
	surface:Corner(list.frame, "radiusSmall")

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

	-- One label per slot, created on first render and rewritten afterwards. The
	-- font is mono because log lines are read by column, not by sentence.
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

	-- Were we at the bottom before this line arrived? Only then is following
	-- helpful; otherwise the user is reading and the next line must not yank
	-- the viewport away.
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

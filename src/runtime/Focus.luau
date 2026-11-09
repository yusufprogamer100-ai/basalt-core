--!strict
-- Basalt / runtime / Focus
-- One focus, one ring, one order. Controls do not know about each other; the
-- manager owns the list, decides who is reachable, and calls SetFocus on the
-- old and new control. Reachability is measured, not assumed: a control inside
-- a hidden page is not focusable even when its own Visible flag is still true.
--
-- Arrow navigation uses absolute geometry because that is the only arrangement
-- the engine actually renders. When geometry is unavailable (headless tests,
-- zero sized nodes) it falls back to registration order instead of guessing.

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

	-- No layout geometry: ordered controls still need arrow keys to do
	-- something. Down/right continue forward, up/left go back.
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

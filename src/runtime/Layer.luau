--!strict
-- Basalt / runtime / Layer
-- A single overlay surface above the window body, plus the stack of things
-- currently using it. The stack exists so Escape and a click outside have one
-- answer: close the top overlay, not every overlay at once.
--
-- Components never listen to the keyboard. The Window routes Escape here, and
-- pointer dismissal is offered to the top overlay because only it knows its own
-- bounds. A click inside a dropdown must not close that dropdown before the row
-- receives the click.

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

	-- Dismiss only answers "may I close?". The layer performs the pop and the
	-- close, so an overlay cannot end up half closed by forgetting one of them.
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

-- Screen coordinates are scaled by UIScale but GUI offsets are not. Every
-- popup position has to make that conversion in exactly one place.
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

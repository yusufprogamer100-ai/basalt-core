--!strict
-- Basalt / core / Signal
-- A single-direction event. Handlers are stored, not chained, so Connect and
-- Disconnect stay O(1) and Fire never mutates the list it is iterating.
-- Errors inside a handler are routed to the owner. They are never swallowed.

export type Handler = (...any) -> ()

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, fn: Handler) -> Connection,
	Once: (self: Signal, fn: Handler) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	Count: (self: Signal) -> number,
	Destroy: (self: Signal) -> (),
}

type Entry = {
	fn: Handler,
	active: boolean,
}

local function makeConnection(entries: { Entry }, entry: Entry): Connection
	local connection = {} :: any
	connection.Connected = true

	function connection:Disconnect()
		if not entry.active then
			return
		end

		entry.active = false
		self.Connected = false

		local index = table.find(entries, entry)
		if index then
			table.remove(entries, index)
		end
	end

	return connection
end

local Signal = {}

function Signal.new(onError: ((err: any) -> ())?): Signal
	local entries: { Entry } = {}
	local destroyed = false
	local signal = {} :: any

	function signal:Connect(fn: Handler): Connection
		if type(fn) ~= "function" then
			error("Signal:Connect expects a function, got " .. type(fn), 2)
		end

		if destroyed then
			local dead = {} :: any
			dead.Connected = false
			dead.Disconnect = function() end
			return dead
		end

		local entry: Entry = { fn = fn, active = true }
		table.insert(entries, entry)
		return makeConnection(entries, entry)
	end

	function signal:Once(fn: Handler): Connection
		local connection: Connection

		local function wrapped(...: any)
			connection:Disconnect()
			fn(...)
		end

		connection = signal:Connect(wrapped)
		return connection
	end

	function signal:Fire(...: any)
		if destroyed then
			return
		end

		-- Snapshot so a handler can disconnect itself or another handler safely.
		local snapshot = table.clone(entries)
		for _, entry in ipairs(snapshot) do
			if entry.active then
				local ok, err = pcall(entry.fn, ...)
				if not ok and onError then
					onError(err)
				end
			end
		end
	end

	function signal:Count(): number
		return #entries
	end

	function signal:Destroy()
		destroyed = true
		for _, entry in ipairs(entries) do
			entry.active = false
		end
		table.clear(entries)
	end

	return signal
end

return Signal

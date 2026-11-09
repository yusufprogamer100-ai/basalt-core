--!strict
-- Basalt / core / Scheduler
-- State changes are collected and applied once per frame. Fifty writes in one
-- frame produce one render pass instead of fifty.

export type Scheduler = {
	Push: (self: Scheduler, fn: () -> ()) -> (),
	Flush: (self: Scheduler) -> number,
	Pending: (self: Scheduler) -> number,
	SetPump: (self: Scheduler, pump: ((fn: () -> ()) -> ())?) -> (),
	Destroy: (self: Scheduler) -> (),
}

type Options = {
	pump: ((fn: () -> ()) -> ())?,
	onError: ((err: any) -> ())?,
}

local function defaultPump(fn: () -> ())
	task.defer(fn)
end

local Scheduler = {}

function Scheduler.new(options: Options?): Scheduler
	local config = options or {}
	local queue: { () -> () } = {}
	local scheduled = false
	local destroyed = false
	local pump = config.pump or defaultPump
	local scheduler = {} :: any

	local function flush()
		scheduled = false
		if destroyed then
			return
		end

		-- Take the current queue. Pushes during flush land in the next frame,
		-- which keeps a runaway push from locking the frame.
		local batch = queue
		queue = {}

		for _, fn in ipairs(batch) do
			local ok, err = pcall(fn)
			if not ok and config.onError then
				config.onError(err)
			end
		end

		if #queue > 0 and not scheduled then
			scheduled = true
			pump(flush)
		end
	end

	function scheduler:Push(fn: () -> ())
		if destroyed then
			return
		end

		if type(fn) ~= "function" then
			error("Scheduler:Push expects a function, got " .. type(fn), 2)
		end

		table.insert(queue, fn)

		if not scheduled then
			scheduled = true
			pump(flush)
		end
	end

	function scheduler:Flush(): number
		if destroyed then
			return 0
		end

		local count = #queue
		local batch = queue
		queue = {}

		for _, fn in ipairs(batch) do
			local ok, err = pcall(fn)
			if not ok and config.onError then
				config.onError(err)
			end
		end

		return count
	end

	function scheduler:Pending(): number
		return #queue
	end

	function scheduler:SetPump(nextPump: ((fn: () -> ()) -> ())?)
		pump = nextPump or defaultPump
	end

	function scheduler:Destroy()
		destroyed = true
		table.clear(queue)
	end

	return scheduler
end

return Scheduler

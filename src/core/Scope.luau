--!strict
-- Basalt / core / Scope
-- One owner per object tree. Everything that must be released is registered
-- here, so Destroy is a single pass instead of a scavenger hunt.

export type Scope = {
	Add: (self: Scope, item: any) -> any,
	AddFn: (self: Scope, fn: () -> ()) -> (),
	AddConnection: (self: Scope, connection: any) -> any,
	Count: (self: Scope) -> number,
	IsDestroyed: (self: Scope) -> boolean,
	Destroy: (self: Scope) -> (),
}

local function release(item: any)
	if item == nil then
		return
	end

	local kind = type(item)

	if kind == "function" then
		item()
		return
	end

	if kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
			return
		end
		if type(item.Disconnect) == "function" then
			item:Disconnect()
			return
		end
		if type(item.destroy) == "function" then
			item:destroy()
			return
		end
	end

	if typeof(item) == "Instance" then
		item:Destroy()
	end
end

local Scope = {}

function Scope.new(onError: ((err: any) -> ())?): Scope
	local items: { any } = {}
	local destroyed = false
	local scope = {} :: any

	function scope:Add(item: any): any
		if item == nil then
			return item
		end

		if destroyed then
			-- The owner is gone. Release immediately instead of leaking.
			local ok, err = pcall(release, item)
			if not ok and onError then
				onError(err)
			end
			return item
		end

		table.insert(items, item)
		return item
	end

	function scope:AddFn(fn: () -> ())
		self:Add(fn)
	end

	function scope:AddConnection(connection: any): any
		return self:Add(connection)
	end

	function scope:Count(): number
		return #items
	end

	function scope:IsDestroyed(): boolean
		return destroyed
	end

	function scope:Destroy()
		if destroyed then
			return
		end
		destroyed = true

		-- Reverse release order: children before parents.
		for index = #items, 1, -1 do
			local ok, err = pcall(release, items[index])
			if not ok and onError then
				onError(err)
			end
		end

		table.clear(items)
	end

	return scope
end

return Scope

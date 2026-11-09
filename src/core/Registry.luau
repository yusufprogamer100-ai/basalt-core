--!strict
-- Basalt / core / Registry
-- Tracks every Instance the library creates. Two jobs: bulk cleanup and an
-- honest instance count for the devtools overlay and the tests.

export type Registry = {
	Track: (self: Registry, instance: Instance) -> Instance,
	Untrack: (self: Registry, instance: Instance) -> (),
	Count: (self: Registry) -> number,
	ByClass: (self: Registry) -> { [string]: number },
	Destroy: (self: Registry) -> (),
}

local Registry = {}

function Registry.new(): Registry
	local items: { Instance } = {}
	local destroyed = false
	local registry = {} :: any

	function registry:Track(instance: Instance): Instance
		if destroyed then
			instance:Destroy()
			return instance
		end

		table.insert(items, instance)
		return instance
	end

	function registry:Untrack(instance: Instance)
		local index = table.find(items, instance)
		if index then
			table.remove(items, index)
		end
	end

	function registry:Count(): number
		-- Destroyed instances may still sit in the list for a frame. Count only
		-- what still has a parent, so the number reported is the real one.
		local total = 0
		for _, instance in ipairs(items) do
			if instance.Parent ~= nil then
				total += 1
			end
		end
		return total
	end

	function registry:ByClass(): { [string]: number }
		local histogram: { [string]: number } = {}
		for _, instance in ipairs(items) do
			if instance.Parent ~= nil then
				local class = instance.ClassName
				histogram[class] = (histogram[class] or 0) + 1
			end
		end
		return histogram
	end

	function registry:Destroy()
		if destroyed then
			return
		end
		destroyed = true

		for index = #items, 1, -1 do
			local instance = items[index]
			if instance.Parent ~= nil then
				pcall(function()
					instance:Destroy()
				end)
			end
		end

		table.clear(items)
	end

	return registry
end

return Registry

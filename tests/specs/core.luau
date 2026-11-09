-- Basalt / tests / specs / core
-- Behavior first. These tests exist because each of these primitives already
-- has a known failure mode: a handler mutating the list mid-fire, a scope that
-- leaks when it is destroyed twice, a scheduler that drops work pushed during a
-- flush, a registry that counts corpses.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Signal = Fixture.Signal
local Scope = Fixture.Scope
local Scheduler = Fixture.Scheduler
local Registry = Fixture.Registry
local Error = Fixture.Error

return function(h)
	h:describe("Signal", function()
		h:it("delivers arguments in order to every handler", function()
			local signal = Signal.new()
			local seen = {}

			signal:Connect(function(a, b)
				table.insert(seen, { a, b })
			end)

			signal:Connect(function(a, b)
				table.insert(seen, { b, a })
			end)

			signal:Fire("x", 2)

			h:expect(#seen).ToBe(2)
			h:expect(seen[1]).ToEqual({ "x", 2 })
			h:expect(seen[2]).ToEqual({ 2, "x" })

			signal:Destroy()
		end)

		h:it("stops after Disconnect and updates Connected", function()
			local signal = Signal.new()
			local count = 0

			local connection = signal:Connect(function()
				count += 1
			end)

			connection:Disconnect()
			connection:Disconnect()

			signal:Fire()
			h:expect(count).ToBe(0)
			h:expect(connection.Connected).ToBeFalsy()

			signal:Destroy()
		end)

		h:it("runs a Once handler exactly once", function()
			local signal = Signal.new()
			local count = 0

			signal:Once(function()
				count += 1
			end)

			signal:Fire()
			signal:Fire()

			h:expect(count).ToBe(1)
			h:expect(signal:Count()).ToBe(0)

			signal:Destroy()
		end)

		h:it("routes handler errors to onError and keeps firing", function()
			local errors = {}
			local count = 0

			local signal = Signal.new(function(err)
				table.insert(errors, tostring(err))
			end)

			signal:Connect(function()
				error("boom")
			end)

			signal:Connect(function()
				count += 1
			end)

			signal:Fire()

			h:expect(#errors).ToBe(1)
			h:expect(string.find(errors[1], "boom", 1, true) ~= nil).ToBeTruthy()
			h:expect(count).ToBe(1)

			signal:Destroy()
		end)

		h:it("allows a handler to disconnect itself mid-fire", function()
			local signal = Signal.new()
			local count = 0
			local connection

			connection = signal:Connect(function()
				count += 1
				connection:Disconnect()
			end)

			signal:Fire()
			signal:Fire()

			h:expect(count).ToBe(1)

			signal:Destroy()
		end)

		h:it("returns a dead connection after Destroy", function()
			local signal = Signal.new()
			signal:Destroy()

			local fired = false
			local connection = signal:Connect(function()
				fired = true
			end)

			signal:Fire()

			h:expect(connection.Connected).ToBeFalsy()
			h:expect(fired).ToBeFalsy()
			h:expect(signal:Count()).ToBe(0)
		end)
	end)

	h:describe("Scope", function()
		h:it("releases in reverse order", function()
			local order = {}

			local scope = Scope.new()
			scope:Add(function()
				table.insert(order, "first")
			end)
			scope:Add(function()
				table.insert(order, "second")
			end)
			scope:AddConnection({
				Disconnect = function()
					table.insert(order, "connection")
				end,
			})

			scope:Destroy()

			h:expect(order).ToEqual({ "connection", "second", "first" })
			h:expect(scope:IsDestroyed()).ToBeTruthy()
			h:expect(scope:Count()).ToBe(0)
		end)

		h:it("releases immediately when added after Destroy", function()
			local scope = Scope.new()
			local released = false

			scope:Destroy()
			scope:Add(function()
				released = true
			end)

			h:expect(released).ToBeTruthy()
		end)

		h:it("is idempotent", function()
			local scope = Scope.new()
			local count = 0

			scope:Add(function()
				count += 1
			end)

			scope:Destroy()
			scope:Destroy()

			h:expect(count).ToBe(1)
		end)

		h:it("keeps working when one release throws", function()
			local errors = {}
			local released = false

			local scope = Scope.new(function(err)
				table.insert(errors, tostring(err))
			end)

			scope:Add(function()
				error("release failed")
			end)
			scope:Add(function()
				released = true
			end)

			scope:Destroy()

			h:expect(#errors).ToBe(1)
			h:expect(released).ToBeTruthy()
		end)
	end)

	h:describe("Scheduler", function()
		h:it("batches pushes into one pump call", function()
			local pumped = {}
			local log = {}

			local scheduler = Scheduler.new({
				pump = function(fn)
					table.insert(pumped, fn)
				end,
			})

			scheduler:Push(function()
				table.insert(log, 1)
			end)
			scheduler:Push(function()
				table.insert(log, 2)
			end)

			h:expect(scheduler:Pending()).ToBe(2)
			h:expect(#pumped).ToBe(1)

			pumped[1]()

			h:expect(log).ToEqual({ 1, 2 })
			h:expect(scheduler:Pending()).ToBe(0)
		end)

		h:it("defers work pushed during a flush to the next pump", function()
			local pumped = {}
			local log = {}

			local scheduler = Scheduler.new({
				pump = function(fn)
					table.insert(pumped, fn)
				end,
			})

			scheduler:Push(function()
				table.insert(log, 1)
				scheduler:Push(function()
					table.insert(log, 2)
				end)
			end)

			pumped[1]()

			h:expect(log).ToEqual({ 1 })
			h:expect(#pumped).ToBe(2)

			pumped[2]()

			h:expect(log).ToEqual({ 1, 2 })
		end)

		h:it("Flush returns the number it ran and drops work after Destroy", function()
			local scheduler = Scheduler.new({
				pump = function() end,
			})

			scheduler:Push(function() end)
			scheduler:Push(function() end)

			h:expect(scheduler:Flush()).ToBe(2)

			scheduler:Push(function() end)
			scheduler:Destroy()

			h:expect(scheduler:Pending()).ToBe(0)
			h:expect(scheduler:Flush()).ToBe(0)
		end)
	end)

	h:describe("Registry", function()
		h:it("counts only instances that still have a parent", function()
			local root = Mock.Instance("Folder", "Root")

			local frame = Mock.Instance("Frame", "A")
			frame.Parent = root

			local label = Mock.Instance("TextLabel", "B")
			label.Parent = root

			local registry = Registry.new()
			registry:Track(frame)
			registry:Track(label)

			h:expect(registry:Count()).ToBe(2)
			h:expect(registry:ByClass().Frame).ToBe(1)
			h:expect(registry:ByClass().TextLabel).ToBe(1)

			frame:Destroy()

			h:expect(registry:Count()).ToBe(1)

			registry:Destroy()

			h:expect(label.Parent).ToBeNil()
			h:expect(registry:Count()).ToBe(0)

			root:Destroy()
		end)

		h:it("untracks a single instance", function()
			local root = Mock.Instance("Folder", "Root")

			local frame = Mock.Instance("Frame", "A")
			frame.Parent = root

			local registry = Registry.new()
			registry:Track(frame)
			registry:Untrack(frame)
			registry:Untrack(frame)

			h:expect(registry:Count()).ToBe(0)

			registry:Destroy()
			root:Destroy()
		end)
	end)

	h:describe("Error", function()
		h:it("reports the first failure and counts repeats quietly", function()
			Error.Reset()
			Mock.ClearWarnings()

			Error.Report("test", "boom")
			Error.Report("test", "boom")

			local warnings = Mock.Warnings()

			h:expect(#warnings).ToBe(1)
			h:expect(string.find(warnings[1], "boom", 1, true) ~= nil).ToBeTruthy()
			h:expect(Error.Count()).ToBe(2)
			h:expect(#Error.History()).ToBe(2)

			Error.Reset()
		end)

		h:it("captures table errors with a message field", function()
			Error.Reset()
			Mock.ClearWarnings()

			Error.Report("table", { message = "structured" })

			local warnings = Mock.Warnings()

			h:expect(string.find(warnings[1], "structured", 1, true) ~= nil).ToBeTruthy()

			Error.Reset()
		end)

		h:it("survives a throwing handler and still warns", function()
			Error.Reset()
			Mock.ClearWarnings()

			Error.SetHandler(function()
				error("handler failed")
			end)

			Error.Report("handler", "original")

			local warnings = Mock.Warnings()

			h:expect(#warnings).ToBeGreaterThan(0)
			h:expect(Error.Count()).ToBe(1)

			Error.SetHandler(nil)
			Error.Reset()
		end)
	end)
end

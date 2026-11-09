--!strict
-- Basalt / tests / harness
-- Small, boring, and strict. A test that cannot fail is not a test, so every
-- matcher raises on failure and the runner reports the exact name.
--
-- Matchers are closures bound to the value, not methods on a metatable. That
-- keeps `h:expect(x).ToBe(y)` honest: no accidental `self` argument can turn
-- an assertion into an index error.

export type Failure = {
	name: string,
	message: string,
}

local Harness = {}
Harness.__index = Harness

local function format(value: any, depth: number?): string
	local level = depth or 0

	if type(value) == "string" then
		return string.format("%q", value)
	end

	if type(value) ~= "table" or level > 2 then
		return tostring(value)
	end

	local parts = {}
	for key, item in pairs(value) do
		table.insert(parts, tostring(key) .. "=" .. format(item, level + 1))
	end

	return "{" .. table.concat(parts, ", ") .. "}"
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end

	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	for key, value in pairs(a) do
		if not deepEqual(value, b[key]) then
			return false
		end
	end

	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end

	return true
end

local function describe(actual: any, expected: any): string
	return string.format("expected %s, got %s", format(expected), format(actual))
end

local function makeExpect(value: any)
	local expect = {}

	function expect.ToBe(expected: any)
		if value ~= expected then
			error(describe(value, expected), 3)
		end
	end

	function expect.ToEqual(expected: any)
		if not deepEqual(value, expected) then
			error(describe(value, expected), 3)
		end
	end

	function expect.ToBeNil()
		if value ~= nil then
			error(string.format("expected nil, got %s", format(value)), 3)
		end
	end

	function expect.ToBeTruthy()
		if not value then
			error(string.format("expected a truthy value, got %s", format(value)), 3)
		end
	end

	function expect.ToBeFalsy()
		if value then
			error(string.format("expected a falsy value, got %s", format(value)), 3)
		end
	end

	function expect.ToBeCloseTo(expected: number, tolerance: number?)
		local margin = tolerance or 0.0001

		if type(value) ~= "number" or math.abs(value - expected) > margin then
			error(
				string.format(
					"expected %s within %s of %s",
					format(value),
					tostring(margin),
					format(expected)
				),
				3
			)
		end
	end

	function expect.ToBeGreaterThan(expected: number)
		if not (type(value) == "number" and value > expected) then
			error(
				string.format(
					"expected a number greater than %s, got %s",
					format(expected),
					format(value)
				),
				3
			)
		end
	end

	function expect.ToThrow(fragment: string?)
		local ok, err = pcall(value)

		if ok then
			error("expected the function to throw, it returned normally", 3)
		end

		local message = tostring(err)
		if fragment and not string.find(message, fragment, 1, true) then
			error(string.format("expected the error to contain %q, got %q", fragment, message), 3)
		end
	end

	return expect
end

function Harness.new()
	return setmetatable({
		suite = nil,
		passed = 0,
		failed = 0,
		failures = {} :: { Failure },
	}, Harness)
end

function Harness:describe(name: string, fn: () -> ())
	local previous = self.suite
	self.suite = if previous then previous .. " / " .. name else name

	local ok, err = pcall(fn)
	self.suite = previous

	if not ok then
		table.insert(self.failures, {
			name = name,
			message = "suite crashed: " .. tostring(err),
		})
		self.failed += 1
	end
end

function Harness:it(name: string, fn: () -> ())
	local full = if self.suite then self.suite .. " > " .. name else name
	local ok, err = pcall(fn)

	if ok then
		self.passed += 1
		print("  ok   " .. full)
		return
	end

	self.failed += 1
	table.insert(self.failures, { name = full, message = tostring(err) })
	print("  FAIL " .. full)
end

function Harness:expect(value: any)
	return makeExpect(value)
end

function Harness:run(): boolean
	print("")
	print("Basalt tests")
	print(string.rep("-", 48))

	for _, failure in ipairs(self.failures) do
		print("FAIL " .. failure.name)
		print("     " .. failure.message)
	end

	print(string.rep("-", 48))
	print(string.format("%d passed, %d failed", self.passed, self.failed))

	return self.failed == 0
end

return Harness

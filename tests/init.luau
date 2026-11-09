--!nocheck
-- Basalt / tests / init
-- The headless entry point. The bundler compiles src and tests into one chunk,
-- injects the mock as upvalues, then runs this module.

local Mock = require(script.Parent.mock.roblox)
local Harness = require(script.Parent.harness)

local h = Harness.new()

require(script.Parent.specs.core)(h)
require(script.Parent.specs.tokens)(h)
require(script.Parent.specs.runtime)(h)
require(script.Parent.specs.window)(h)
require(script.Parent.specs.controls)(h)
require(script.Parent.specs.components)(h)
require(script.Parent.specs.keyboard)(h)
require(script.Parent.specs.layer)(h)
require(script.Parent.specs.dropdown)(h)
require(script.Parent.specs.keybind)(h)

local ok = h:run()

Mock.Reset()

if not ok then
	error("Basalt: tests failed", 0)
end

-- Basalt / tests / specs / layer
-- Overlay order and virtualization are both invariants that fail silently when
-- wrong: the second dropdown closes instead of the first, or 500 options quietly
-- become 500 instances. These tests count and order, they do not eyeball.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Layer = Fixture.Layer
local VirtualList = Fixture.VirtualList
local Themes = Fixture.Themes
local Surface = Fixture.Surface

local function makeSurface()
	return Surface.new({ theme = Themes.Get("graphite") })
end

local function overlay(name: string, log: { string })
	return {
		name = name,
		Close = function(self: any)
			table.insert(log, self.name)
		end,
	}
end

return function(h)
	h:describe("Layer", function()
		h:it("closes only the top overlay", function()
			Mock.Reset()
			local parent = Mock.Instance("Frame", "Root")
			local frame = Mock.Instance("Frame", "Layer")
			frame.Parent = parent
			local layer = Layer.new(frame)
			local log = {}

			layer:Push(overlay("first", log))
			layer:Push(overlay("second", log))

			h:expect(layer:Top().name).ToBe("second")
			h:expect(layer:CloseTop()).ToBe(true)
			h:expect(log).ToEqual({ "second" })
			h:expect(layer:Top().name).ToBe("first")

			layer:CloseTop()
			h:expect(layer:Top()).ToBeNil()
			h:expect(layer:CloseTop()).ToBe(false)

			layer:Destroy()
		end)

		h:it("dismisses the top overlay and respects an inside click", function()
			Mock.Reset()
			local frame = Mock.Instance("Frame", "Layer")
			local layer = Layer.new(frame)
			local closed = 0

			layer:Push({
				Close = function()
					closed += 1
				end,
				Dismiss = function()
					return false
				end,
			})

			h:expect(layer:Dismiss(Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil)))
				.ToBe(false)
			h:expect(closed).ToBe(0)

			layer:Pop(layer:Top())
			layer:Push({
				Close = function()
					closed += 1
				end,
				Dismiss = function()
					return true
				end,
			})

			h:expect(layer:Dismiss(Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil)))
				.ToBe(true)
			h:expect(closed).ToBe(1)
			h:expect(layer:Top()).ToBeNil()

			layer:Destroy()
		end)

		h:it("converts screen coordinates through UIScale in one place", function()
			Mock.Reset()
			local frame = Mock.Instance("Frame", "Layer")
			frame.AbsolutePosition = Mock.Vector2.new(100, 50)
			local layer = Layer.new(frame, function()
				return 2
			end)

			local point = layer:ToLocal(Mock.Vector2.new(140, 90))
			h:expect(point.X).ToBe(20)
			h:expect(point.Y).ToBe(20)
			h:expect(layer:Pixels(44)).ToBe(22)

			layer:Destroy()
		end)

		h:it("closes everything when destroyed", function()
			Mock.Reset()
			local frame = Mock.Instance("Frame", "Layer")
			local layer = Layer.new(frame)
			local log = {}

			layer:Push(overlay("one", log))
			layer:Push(overlay("two", log))
			layer:Destroy()

			h:expect(log).ToEqual({ "two", "one" })
			h:expect(layer.destroyed).ToBe(true)
			h:expect(frame.Parent).ToBeNil()
		end)
	end)

	h:describe("VirtualList", function()
		h:it("keeps a fixed row pool for 500 options", function()
			Mock.Reset()
			local surface = makeSurface()
			local parent = Mock.Instance("Frame", "Parent")

			local list = VirtualList.new(surface, parent, {
				rowHeight = 44,
				height = 220,
				count = 500,
			})

			h:expect(#list.rows <= 8).ToBeTruthy()
			h:expect(#list.rows < 500).ToBeTruthy()
			h:expect(list.frame.CanvasSize.Y.Offset).ToBe(22000)
			h:expect(list:VisibleRange()).ToBe(1, list.visible)

			list:Destroy()
			surface:Destroy()
		end)

		h:it("recycles the same rows when scrolled to the end", function()
			Mock.Reset()
			local surface = makeSurface()
			local parent = Mock.Instance("Frame", "Parent")
			local rendered = {}

			local list = VirtualList.new(surface, parent, {
				rowHeight = 40,
				height = 200,
				count = 500,
				render = function(index)
					table.insert(rendered, index)
				end,
			})

			local pool = #list.rows
			table.clear(rendered)

			list:ScrollToIndex(500)

			h:expect(#list.rows).ToBe(pool)
			h:expect(list:RowFor(500)).ToBeTruthy()
			h:expect(list:RowFor(1)).ToBeNil()
			h:expect(rendered[#rendered]).ToBe(500)

			list:Destroy()
			surface:Destroy()
		end)

		h:it("hides every row when the count drops to zero", function()
			Mock.Reset()
			local surface = makeSurface()
			local parent = Mock.Instance("Frame", "Parent")
			local list =
				VirtualList.new(surface, parent, { rowHeight = 32, height = 160, count = 10 })

			h:expect(list:RowFor(1)).ToBeTruthy()

			list:SetCount(0)

			for _, row in ipairs(list.rows) do
				h:expect(row.Visible).ToBe(false)
			end

			h:expect(list:VisibleRange()).ToBe(0, 0)

			list:Destroy()
			surface:Destroy()
		end)
	end)
end

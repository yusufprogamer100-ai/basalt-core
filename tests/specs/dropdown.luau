-- Basalt / tests / specs / dropdown
-- A dropdown has three ways to fail that are easy to miss: it builds an
-- instance per option, it closes when the user clicks inside it, or it keeps
-- claiming the keyboard after Escape. These tests exercise the real Window
-- routing, not the component in isolation.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Surface = Fixture.Surface
local Themes = Fixture.Themes
local Window = Fixture.Window

local function makeSurface()
	return Surface.new({
		theme = Themes.Get("graphite"),
		density = "comfortable",
	})
end

local function build(config: any)
	local surface = makeSurface()
	local window = Window.new(surface, { width = 560, height = 420 })
	local tab = window:tab({ name = "Main" })
	local section = tab:section({ title = "Data" })
	local dropdown = section:Dropdown(config)

	local layer = window:GetLayer()
	layer.frame.AbsoluteSize = Mock.Vector2.new(1280, 720)
	layer.frame.AbsolutePosition = Mock.Vector2.new(0, 0)

	-- The mock does not compute layout, so the field reports the geometry the
	-- window would have placed it at: 300 wide, one row tall, at 100,200.
	dropdown.field.AbsolutePosition = Mock.Vector2.new(100, 200)
	dropdown.field.AbsoluteSize = Mock.Vector2.new(300, 44)

	return surface, window, dropdown
end

local function key(code: any)
	return Mock.Keyboard(code)
end

local function click(x: number, y: number)
	return Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil, Mock.Vector3.new(x, y, 0))
end

return function(h)
	h:describe("Dropdown", function()
		h:it("opens 500 options with a bounded row pool", function()
			Mock.Reset()

			local options = {}
			for index = 1, 500 do
				options[index] = "Option " .. index
			end

			local surface, window, dropdown = build({
				text = "Pick",
				options = options,
				maxRows = 6,
			})

			local before = #window:GetGui():GetDescendants()

			h:expect(dropdown:Open()).ToBe(true)
			h:expect(dropdown:IsOpen()).ToBe(true)
			h:expect(dropdown._popup.Visible).ToBe(true)
			h:expect(dropdown._popup.Parent).ToBe(window:GetLayer().frame)
			h:expect(#dropdown._list.rows).ToBe(8)
			h:expect(#dropdown._list.rows < 500).ToBeTruthy()

			-- Opening reuses the pool; the only new instances are the six objects
			-- each pooled row builds on first render (button, bar, check, label,
			-- corner, stroke). 500 rows never materialise.
			h:expect(#window:GetGui():GetDescendants() - before <= #dropdown._list.rows * 6 + 4)
				.ToBe(true)
			h:expect(dropdown._popup.Size.Y.Offset).ToBe(6 * 44 + 8)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("opens 500 options inside the 16ms frame budget", function()
			Mock.Reset()

			local options = {}
			for index = 1, 500 do
				options[index] = "Option " .. index
			end

			local surface, window, dropdown = build({ options = options, maxRows = 6 })

			local started = os.clock()
			dropdown:Open()
			local elapsed = (os.clock() - started) * 1000

			-- CPU time, not wall time: this measures the work Basalt does, which
			-- is what a frame budget can actually spend.
			h:expect(elapsed < 16).ToBe(true)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("selects one value from the keyboard and closes", function()
			Mock.Reset()

			local changes = {}
			local surface, window, dropdown = build({
				options = { "Alpha", "Beta", "Gamma" },
				onChange = function(value: any)
					table.insert(changes, value)
				end,
			})

			window._focus:Set(dropdown)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Return), false)).ToBe(true)
			h:expect(dropdown:IsOpen()).ToBe(true)
			h:expect(dropdown._highlight).ToBe(1)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Down), false)).ToBe(true)
			h:expect(dropdown._highlight).ToBe(2)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Return), false)).ToBe(true)
			h:expect(dropdown:IsOpen()).ToBe(false)
			h:expect(dropdown:GetValue()).ToBe("Beta")
			h:expect(dropdown._valueLabel.Text).ToBe("Beta")
			h:expect(changes).ToEqual({ "Beta" })
			h:expect(window:GetLayer():Top()).ToBeNil()

			window:Destroy()
			surface:Destroy()
		end)

		h:it("toggles multiple values and stays open", function()
			Mock.Reset()

			local changes = {}
			local surface, window, dropdown = build({
				options = { "Alpha", "Beta" },
				multi = true,
				onChange = function(value: any)
					table.insert(changes, value)
				end,
			})

			dropdown:Open()
			dropdown:HandleAction("down")
			dropdown:HandleAction("activate")

			h:expect(dropdown:IsOpen()).ToBe(true)
			h:expect(dropdown:GetValue()).ToEqual({ "Beta" })
			h:expect(dropdown._valueLabel.Text).ToBe("Beta")
			h:expect(changes).ToEqual({ { "Beta" } })

			dropdown:HandleAction("activate")

			h:expect(dropdown:GetValue()).ToEqual({})
			h:expect(dropdown._valueLabel.Text).ToBe("Select")

			dropdown:Close()
			window:Destroy()
			surface:Destroy()
		end)

		h:it("skips disabled options instead of highlighting them", function()
			Mock.Reset()

			local surface, window, dropdown = build({
				options = {
					"A",
					{ text = "B", disabled = true },
					"C",
				},
			})

			dropdown:Open()
			h:expect(dropdown._highlight).ToBe(1)

			dropdown:HandleAction("down")
			h:expect(dropdown._highlight).ToBe(3)

			dropdown:HandleAction("down")
			h:expect(dropdown._highlight).ToBe(1)

			dropdown:HandleAction("up")
			h:expect(dropdown._highlight).ToBe(3)

			dropdown:HandleAction("activate")
			h:expect(dropdown:GetValue()).ToBe("C")

			window:Destroy()
			surface:Destroy()
		end)

		h:it("closes on Escape and returns the keyboard to the window", function()
			Mock.Reset()

			local surface, window, dropdown = build({ options = { "A", "B" } })

			window._focus:Set(dropdown)
			window:HandleInput(key(Mock.Enum.KeyCode.Return), false)

			h:expect(dropdown:IsOpen()).ToBe(true)
			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Escape), false)).ToBe(true)
			h:expect(dropdown:IsOpen()).ToBe(false)
			h:expect(window:GetLayer():Top()).ToBeNil()

			-- The next Escape now clears focus, which proves the overlay released
			-- it rather than swallowing the key forever.
			window:HandleInput(key(Mock.Enum.KeyCode.Escape), false)
			h:expect(window._focus:Current()).ToBeNil()

			window:Destroy()
			surface:Destroy()
		end)

		h:it("keeps an inside click open and closes on an outside click", function()
			Mock.Reset()

			local surface, window, dropdown = build({ options = { "A", "B" } })

			dropdown:Open()
			dropdown._popup.AbsolutePosition = Mock.Vector2.new(100, 252)
			dropdown._popup.AbsoluteSize = Mock.Vector2.new(180, 140)

			h:expect(window:HandleInput(click(150, 220), false)).ToBe(false)
			h:expect(dropdown:IsOpen()).ToBe(true)

			h:expect(window:HandleInput(click(120, 260), false)).ToBe(false)
			h:expect(dropdown:IsOpen()).ToBe(true)

			h:expect(window:HandleInput(click(20, 20), false)).ToBe(true)
			h:expect(dropdown:IsOpen()).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("converts through UIScale when placing the popup", function()
			Mock.Reset()

			local surface, window, dropdown = build({ options = { "A", "B", "C" } })

			window:SetScale(2)

			local layer = window:GetLayer()
			layer.frame.AbsolutePosition = Mock.Vector2.new(0, 0)
			layer.frame.AbsoluteSize = Mock.Vector2.new(2560, 1440)

			-- 200,400 on screen is 100,200 inside the scaled layer.
			dropdown.field.AbsolutePosition = Mock.Vector2.new(200, 400)
			dropdown.field.AbsoluteSize = Mock.Vector2.new(300, 88)

			dropdown:Open()

			h:expect(layer:Pixels(dropdown.field.AbsoluteSize.X)).ToBe(150)
			h:expect(dropdown._popup.Position.X.Offset).ToBe(100)
			h:expect(dropdown._popup.Position.Y.Offset).ToBe(200 + 44 + 4)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("closes the overlay when the window hides or minimizes", function()
			Mock.Reset()

			local surface, window, dropdown = build({ options = { "A" } })

			dropdown:Open()
			window:Hide()

			h:expect(dropdown:IsOpen()).ToBe(false)
			h:expect(window:GetLayer():Top()).ToBeNil()

			window:Show()
			dropdown:Open()
			window:Minimize()

			h:expect(dropdown:IsOpen()).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("draws an empty state instead of an empty popup", function()
			Mock.Reset()

			local surface, window, dropdown = build({ options = {} })

			dropdown:Open()

			h:expect(dropdown._empty.Visible).ToBe(true)
			h:expect(dropdown._list.frame.Visible).ToBe(false)
			h:expect(dropdown:HandleAction("down")).ToBe(true)
			h:expect(dropdown._highlight).ToBe(0)

			dropdown:Close()
			window:Destroy()
			surface:Destroy()
		end)

		h:it("exposes multi select through the section alias", function()
			Mock.Reset()

			local surface = makeSurface()
			local window = Window.new(surface, {})
			local section = window:tab({ name = "Main" }):section({})
			local multi = section:MultiDropdown({ options = { "A", "B" } })

			h:expect(multi.multi).ToBe(true)
			h:expect(multi.instance.Parent).ToBe(section.content)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("refuses to build without an overlay layer", function()
			Mock.Reset()

			local surface = makeSurface()

			h:expect(function()
				Fixture.Dropdown.new(surface, { options = { "A" } }, nil)
			end).ToThrow("overlay layer")

			surface:Destroy()
		end)
	end)
end

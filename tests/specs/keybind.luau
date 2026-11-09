-- Basalt / tests / specs / keybind
-- A keybind that loses a key to the window toggle, swallows Escape, or reports
-- no conflict is worse than no keybind. These tests press real keys through the
-- Window so the capture path is the one users get.

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

local function build(config: any, windowConfig: any)
	local surface = makeSurface()
	local window = Window.new(surface, windowConfig or {})
	local section = window:tab({ name = "Main" }):section({ title = "Input" })
	local keybind = section:Keybind(config)

	return surface, window, keybind, section
end

local function key(code: any)
	return Mock.Keyboard(code)
end

return function(h)
	h:describe("Keybind", function()
		h:it("captures the next key above the window toggle", function()
			Mock.Reset()

			local changes = {}
			local surface, window, keybind = build({
				text = "Aim",
				value = Mock.Enum.KeyCode.One,
				onChange = function(value: any)
					table.insert(changes, value)
				end,
			}, { toggleKey = Mock.Enum.KeyCode.RightControl })

			window._focus:Set(keybind)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Return), false)).ToBe(true)
			h:expect(keybind:IsCapturing()).ToBe(true)
			h:expect(keybind._chipLabel.Text).ToBe("Press a key")

			-- RightControl is this window's show/hide key. While capturing it
			-- must become the value instead of hiding the window.
			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.RightControl), false)).ToBe(true)
			h:expect(keybind:GetValue()).ToBe(Mock.Enum.KeyCode.RightControl)
			h:expect(keybind:IsCapturing()).ToBe(false)
			h:expect(keybind._chipLabel.Text).ToBe("RightControl")
			h:expect(window:IsVisible()).ToBe(true)
			h:expect(#changes).ToBe(1)
			h:expect(changes[1].Name).ToBe("RightControl")

			window:Destroy()
			surface:Destroy()
		end)

		h:it("binds Tab without moving focus", function()
			Mock.Reset()

			local surface, window, keybind =
				build({ text = "Cycle", value = Mock.Enum.KeyCode.One })
			window._focus:Set(keybind)

			window:HandleInput(key(Mock.Enum.KeyCode.Return), false)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Tab), false)).ToBe(true)
			h:expect(keybind:GetValue()).ToBe(Mock.Enum.KeyCode.Tab)
			h:expect(window._focus:Current()).ToBe(keybind)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("cancels on Escape without changing the value", function()
			Mock.Reset()

			local changes = {}
			local surface, window, keybind = build({
				text = "Aim",
				value = Mock.Enum.KeyCode.One,
				onChange = function()
					table.insert(changes, true)
				end,
			})

			window._focus:Set(keybind)
			window:HandleInput(key(Mock.Enum.KeyCode.Return), false)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Escape), false)).ToBe(true)
			h:expect(keybind:IsCapturing()).ToBe(false)
			h:expect(keybind:GetValue()).ToBe(Mock.Enum.KeyCode.One)
			h:expect(#changes).ToBe(0)
			h:expect(window:IsVisible()).ToBe(true)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("cancels on a click elsewhere instead of pressing another control", function()
			Mock.Reset()

			local surface, window, keybind = build({ text = "Aim", value = Mock.Enum.KeyCode.One })
			window._focus:Set(keybind)
			window:HandleInput(key(Mock.Enum.KeyCode.Return), false)

			local click =
				Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil, Mock.Vector3.new(10, 10, 0))

			h:expect(window:HandleInput(click, false)).ToBe(true)
			h:expect(keybind:IsCapturing()).ToBe(false)
			h:expect(keybind:GetValue()).ToBe(Mock.Enum.KeyCode.One)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("warns when two live keybinds claim the same key", function()
			Mock.Reset()

			local surface, window, first = build({ text = "First", value = Mock.Enum.KeyCode.One })

			local second = window:tab({ name = "Second" }):section({}):Keybind({
				text = "Second",
				value = Mock.Enum.KeyCode.Two,
			})

			local warnings = Mock.Warnings()
			local before = #warnings

			second:SetValue(Mock.Enum.KeyCode.One)

			h:expect(second.conflict).ToBe("First")

			local after = Mock.Warnings()
			h:expect(#after > before).ToBeTruthy()

			local found = false
			for index = before + 1, #after do
				if string.find(after[index], "already bound to 'First'", 1, true) then
					found = true
				end
			end

			h:expect(found).ToBe(true)
			h:expect(second._chipStroke.Color:ToHex()).ToBe(surface:Color("danger"):ToHex())

			-- The first bind moves away, so the second is no longer in conflict.
			first:SetValue(Mock.Enum.KeyCode.Three)
			second:SetFocus(true)

			h:expect(second.conflict).ToBeNil()

			window:Destroy()
			surface:Destroy()
		end)

		h:it("does not fire onChange for programmatic values", function()
			Mock.Reset()

			local changes = {}
			local surface, window, keybind = build({
				text = "Aim",
				value = Mock.Enum.KeyCode.One,
				onChange = function(value: any)
					table.insert(changes, value)
				end,
			})

			keybind:SetValue(Mock.Enum.KeyCode.Two)

			h:expect(keybind:GetValue()).ToBe(Mock.Enum.KeyCode.Two)
			h:expect(#changes).ToBe(0)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("releases its key when destroyed", function()
			Mock.Reset()

			local surface, window, first = build({ text = "First", value = Mock.Enum.KeyCode.One })

			first:Destroy()
			Mock.ClearWarnings()

			local second = window:tab({ name = "Second" }):section({}):Keybind({
				text = "Second",
				value = Mock.Enum.KeyCode.One,
			})

			h:expect(second.conflict).ToBeNil()
			h:expect(#Mock.Warnings()).ToBe(0)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("refuses capture and focus while disabled", function()
			Mock.Reset()

			local surface, window, keybind = build({
				text = "Aim",
				enabled = false,
				value = Mock.Enum.KeyCode.One,
			})

			keybind:Activate()
			h:expect(keybind:IsCapturing()).ToBe(false)

			keybind:SetFocus(true)
			h:expect(keybind.focused).ToBe(false)

			keybind:SetEnabled(true)
			keybind:Capture()
			h:expect(keybind:IsCapturing()).ToBe(true)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("drops out of capture when the row is hidden", function()
			Mock.Reset()

			local surface, window, keybind = build({ text = "Aim", value = Mock.Enum.KeyCode.One })
			window._focus:Set(keybind)

			window:HandleInput(key(Mock.Enum.KeyCode.Return), false)
			h:expect(keybind:IsCapturing()).ToBe(true)

			keybind:SetVisible(false)

			h:expect(keybind:IsCapturing()).ToBe(false)
			h:expect(keybind.instance.Visible).ToBe(false)

			-- The window is no longer deaf: its own toggle still works.
			window:HandleInput(key(Mock.Enum.KeyCode.RightShift), false)
			h:expect(window:IsVisible()).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)
	end)
end

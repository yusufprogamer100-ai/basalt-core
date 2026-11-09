-- Basalt / tests / specs / keyboard
-- Focus is a contract, not a decoration. These tests cover the three ways it
-- breaks in real use: order drifting, unreachable controls still taking focus,
-- and the ring being invisible on the control the user is actually on.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Focus = Fixture.Focus
local Input = Fixture.Keys
local Surface = Fixture.Surface
local Themes = Fixture.Themes
local Window = Fixture.Window
local Tokens = Fixture.Tokens

local function makeSurface(density: string?)
	return Surface.new({
		theme = Themes.Get("graphite"),
		density = density or "comfortable",
	})
end

local function key(code: any)
	Mock.Fire(Mock.Services.UserInputService, "InputBegan", Mock.Keyboard(code))
end

local function fakeControl(name: string, parent: any): any
	local instance = Mock.Instance("Frame", name)
	instance.Parent = parent
	instance.Size = UDim2.fromOffset(40, 20)

	return {
		instance = instance,
		enabled = true,
		destroyed = false,
		focused = false,
		SetFocus = function(self: any, value: boolean)
			self.focused = value
		end,
	}
end

return function(h)
	h:describe("Focus", function()
		h:it("walks registration order and wraps in both directions", function()
			Mock.Reset()
			local root = Mock.Instance("Folder", "Root")
			local manager = Focus.new()
			local first = fakeControl("One", root)
			local second = fakeControl("Two", root)
			local third = fakeControl("Three", root)

			manager:Track(first)
			manager:Track(second)
			manager:Track(third)

			manager:Next(1)
			h:expect(manager:Current()).ToBe(first)
			manager:Next(1)
			h:expect(manager:Current()).ToBe(second)
			manager:Next(-1)
			h:expect(manager:Current()).ToBe(first)
			manager:Next(-1)
			h:expect(manager:Current()).ToBe(third)

			h:expect(first.focused).ToBe(false)
			h:expect(third.focused).ToBe(true)

			manager:Destroy()
		end)

		h:it("skips disabled controls and controls inside a hidden page", function()
			Mock.Reset()
			local root = Mock.Instance("Folder", "Root")
			local manager = Focus.new()
			local first = fakeControl("One", root)
			local disabled = fakeControl("Two", root)
			local hiddenPage = Mock.Instance("Frame", "Page")
			hiddenPage.Parent = root
			hiddenPage.Visible = false
			local hidden = fakeControl("Three", hiddenPage)
			local last = fakeControl("Four", root)

			disabled.enabled = false

			manager:Track(first)
			manager:Track(disabled)
			manager:Track(hidden)
			manager:Track(last)

			manager:Next(1)
			h:expect(manager:Current()).ToBe(first)

			manager:Next(1)
			h:expect(manager:Current()).ToBe(last)

			manager:Next(1)
			h:expect(manager:Current()).ToBe(first)

			h:expect(disabled.focused).ToBe(false)
			h:expect(hidden.focused).ToBe(false)

			manager:Destroy()
		end)

		h:it("moves by geometry inside a group", function()
			Mock.Reset()
			local root = Mock.Instance("Folder", "Root")
			local manager = Focus.new()

			local topLeft = fakeControl("TopLeft", root)
			local topRight = fakeControl("TopRight", root)
			local bottomLeft = fakeControl("BottomLeft", root)

			topLeft.instance.AbsolutePosition = Mock.Vector2.new(0, 0)
			topRight.instance.AbsolutePosition = Mock.Vector2.new(200, 0)
			bottomLeft.instance.AbsolutePosition = Mock.Vector2.new(0, 200)

			manager:Track(topLeft, { group = "grid" })
			manager:Track(topRight, { group = "grid" })
			manager:Track(bottomLeft, { group = "grid" })

			manager:Set(topLeft)
			h:expect(manager:Move("right")).ToBe(true)
			h:expect(manager:Current()).ToBe(topRight)

			manager:Set(topLeft)
			h:expect(manager:Move("down")).ToBe(true)
			h:expect(manager:Current()).ToBe(bottomLeft)

			manager:Set(bottomLeft)
			h:expect(manager:Move("right")).ToBe(true)
			h:expect(manager:Current()).ToBe(topRight)

			manager:Set(topRight)
			h:expect(manager:Move("right")).ToBe(false)
			h:expect(manager:Current()).ToBe(topRight)

			manager:Destroy()
		end)

		h:it("clears when the current control is destroyed or hidden", function()
			Mock.Reset()
			local root = Mock.Instance("Folder", "Root")
			local manager = Focus.new()
			local control = fakeControl("One", root)

			manager:Track(control)
			manager:Set(control)
			h:expect(manager:Current()).ToBe(control)

			control.destroyed = true
			manager:Refresh()

			h:expect(manager:Current()).ToBeNil()

			manager:Destroy()
			h:expect(manager.destroyed).ToBe(true)
		end)

		h:it("untracks one control without touching the rest", function()
			Mock.Reset()
			local root = Mock.Instance("Folder", "Root")
			local manager = Focus.new()
			local first = fakeControl("One", root)
			local second = fakeControl("Two", root)

			manager:Track(first)
			manager:Track(second)
			manager:Set(first)
			manager:Untrack(first)

			h:expect(manager:Current()).ToBeNil()

			manager:Next(1)
			h:expect(manager:Current()).ToBe(second)

			manager:Destroy()
		end)
	end)

	h:describe("Input", function()
		h:it("maps Tab and Shift+Tab through one table", function()
			h:expect(Input.ActionFor(Mock.Keyboard(Mock.Enum.KeyCode.Tab))).ToBe("next")

			Mock.HoldKey(Mock.Enum.KeyCode.LeftShift)
			h:expect(Input.ActionFor(Mock.Keyboard(Mock.Enum.KeyCode.Tab), function(code)
				return code == Mock.Enum.KeyCode.LeftShift
			end)).ToBe("previous")
			Mock.ReleaseKey(Mock.Enum.KeyCode.LeftShift)

			h:expect(Input.ActionFor(Mock.Keyboard(Mock.Enum.KeyCode.Return))).ToBe("activate")
			h:expect(Input.ActionFor(Mock.Keyboard(Mock.Enum.KeyCode.Space))).ToBe("activate")
			h:expect(Input.ActionFor(Mock.Keyboard(Mock.Enum.KeyCode.Escape))).ToBe("escape")
			h:expect(Input.ActionFor(Mock.Keyboard(Mock.Enum.KeyCode.Slash))).ToBe("search")
			h:expect(Input.ActionFor(Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil)))
				.ToBeNil()
		end)

		h:it("maps 1..9 to tab indexes and refuses modified numbers", function()
			h:expect(Input.Number(Mock.Keyboard(Mock.Enum.KeyCode.One))).ToBe(1)

			local nine = Mock.Keyboard(Mock.Enum.KeyCode.Nine)
			h:expect(Input.Number(nine)).ToBe(9)

			h:expect(Input.Number(Mock.Keyboard(Mock.Enum.KeyCode.One), function(code)
				return code == Mock.Enum.KeyCode.LeftShift
			end)).ToBeNil()

			h:expect(Input.Number(Mock.Keyboard(Mock.Enum.KeyCode.Tab))).ToBeNil()
		end)

		h:it("claims a free toggle key and falls back when it is taken", function()
			Mock.Reset()

			local first = Input.Claim(Input.ToggleCandidates)
			h:expect(first.key).ToBe(Mock.Enum.KeyCode.RightShift)

			local second = Input.Claim(Input.ToggleCandidates)
			h:expect(second.key).ToBe(Mock.Enum.KeyCode.RightControl)

			first.release()
			local third = Input.Claim(Input.ToggleCandidates)
			h:expect(third.key).ToBe(Mock.Enum.KeyCode.RightShift)

			second.release()
			third.release()
		end)
	end)

	h:describe("Window keyboard", function()
		local function build()
			local surface = makeSurface()
			local window = Window.new(surface, { width = 560, height = 420 })
			local combat = window:tab({ name = "Combat", hint = "1" })
			local visuals = window:tab({ name = "Visuals", hint = "2" })
			local section = combat:section({ title = "Aim" })

			local toggle = section:Toggle({ text = "Aimbot", value = false })
			local slider =
				section:Slider({ text = "Range", min = 0, max = 100, step = 5, value = 50 })
			local input = section:Input({ text = "Webhook", placeholder = "https://" })
			local button = section:Button({ text = "Apply", variant = "primary" })

			return surface, window, combat, visuals, toggle, slider, input, button
		end

		h:it("orders focus: header, rail, then the active page", function()
			Mock.Reset()
			local surface, window, combat, visuals, toggle, _, _, _ = build()

			window:FocusFirst()
			h:expect(window._focus:Current().instance.Name).ToBe("Close")

			window._focus:Next(1)
			h:expect(window._focus:Current().instance.Name).ToBe("Minimize")

			window._focus:Next(1)
			h:expect(window._focus:Current()).ToBe(combat.button)

			window._focus:Next(1)
			h:expect(window._focus:Current()).ToBe(visuals.button)

			window._focus:Next(1)
			h:expect(window._focus:Current()).ToBe(toggle)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("shows the focus ring and never focuses a disabled control", function()
			Mock.Reset()
			local surface, window, _, _, toggle, _, _, button = build()

			window._focus:Set(button)
			h:expect(button.focused).ToBe(true)
			h:expect(button._stroke.Transparency).ToBe(0)
			h:expect(button._stroke.Color:ToHex()).ToBe("#E3A63C")

			toggle:SetEnabled(false)
			window._focus:Set(toggle)
			h:expect(window._focus:Current()).ToBe(button)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("activates the focused control with Enter and Space", function()
			Mock.Reset()
			local surface, window, _, _, toggle, _, _, _ = build()

			window._focus:Set(toggle)
			key(Mock.Enum.KeyCode.Return)
			h:expect(toggle:GetValue()).ToBe(true)

			key(Mock.Enum.KeyCode.Space)
			h:expect(toggle:GetValue()).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("nudges a focused slider with left and right", function()
			Mock.Reset()
			local surface, window, _, _, _, slider, _, _ = build()

			window._focus:Set(slider)
			key(Mock.Enum.KeyCode.Right)
			h:expect(slider:GetValue()).ToBe(55)

			key(Mock.Enum.KeyCode.Left)
			key(Mock.Enum.KeyCode.Left)
			h:expect(slider:GetValue()).ToBe(45)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("switches tabs from 1..9 and skips focus on hidden pages", function()
			Mock.Reset()
			local surface, window, combat, visuals, toggle, _, _, _ = build()

			window._focus:Set(toggle)
			key(Mock.Enum.KeyCode.Two)

			h:expect(visuals.active).ToBe(true)
			h:expect(combat.active).ToBe(false)
			h:expect(window._focus:Current()).ToBe(visuals.button)

			-- The Combat page is hidden now, so its toggle must not be reachable.
			local guard = 0
			repeat
				window._focus:Next(1)
				guard += 1
			until window._focus:Current() == combat.button or guard > 20

			h:expect(window._focus:Current()).ToBe(combat.button)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("routes / to the search field and Escape back out", function()
			Mock.Reset()
			local surface, window, _, _, _, _, input, _ = build()

			window:SetSearch(input)
			key(Mock.Enum.KeyCode.Slash)

			h:expect(window._focus:Current()).ToBe(input)
			h:expect(input.focused).ToBe(true)
			h:expect(input.box:IsFocused()).ToBe(true)

			key(Mock.Enum.KeyCode.Escape)

			h:expect(window._focus:Current()).ToBeNil()
			h:expect(input.box:IsFocused()).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("keeps letters out of navigation while a TextBox is typing", function()
			Mock.Reset()
			local surface, window, combat, visuals, _, _, input, _ = build()

			input:Capture()
			key(Mock.Enum.KeyCode.Two)

			h:expect(visuals.active).ToBe(false)
			h:expect(combat.active).ToBe(true)

			key(Mock.Enum.KeyCode.Escape)
			h:expect(input.box:IsFocused()).ToBe(false)

			key(Mock.Enum.KeyCode.Two)
			h:expect(visuals.active).ToBe(true)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("hides and shows with the claimed toggle key", function()
			Mock.Reset()
			local surface, window, _, _, _, _, _, _ = build()

			h:expect(window:GetToggleKey()).ToBe(Mock.Enum.KeyCode.RightShift)
			h:expect(window:IsVisible()).ToBe(true)

			key(Mock.Enum.KeyCode.RightShift)
			h:expect(window:IsVisible()).ToBe(false)

			key(Mock.Enum.KeyCode.RightShift)
			h:expect(window:IsVisible()).ToBe(true)

			local second = Window.new(surface, {})
			h:expect(second:GetToggleKey()).ToBe(Mock.Enum.KeyCode.RightControl)

			window:Destroy()

			local third = Window.new(surface, {})
			h:expect(third:GetToggleKey()).ToBe(Mock.Enum.KeyCode.RightShift)

			third:Destroy()
			second:Destroy()
			surface:Destroy()
		end)

		h:it("keeps UIScale untouched during keyboard navigation", function()
			Mock.Reset()
			local surface, window, _, _, _, _, _, button = build()

			window:SetScale(2)
			window._focus:Set(button)
			key(Mock.Enum.KeyCode.Return)

			h:expect(window.uiScale.Scale).ToBe(2)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("gives every comfortable control a 44px touch target", function()
			Mock.Reset()
			local surface, window, _, _, _, _, _, _ = build()

			h:expect(Tokens.Row("comfortable")).ToBe(44)
			h:expect(window.headerHeight).ToBe(48)
			h:expect(window.closeButton.Size.Y.Offset).ToBe(44)

			for _, entry in ipairs(window._focus.entries) do
				local control = entry.control
				local height = control.instance.Size.Y.Offset

				h:expect(height >= 44).ToBeTruthy()
			end

			window:Destroy()
			surface:Destroy()
		end)
	end)
end

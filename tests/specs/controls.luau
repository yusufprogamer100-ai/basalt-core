-- Basalt / tests / specs / controls
-- The control contract starts here. State owns the seven variants, Button is
-- the first control that must fill all of them, and App is the only supported
-- way to build a Window without wiring a Surface by hand.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local State = Fixture.State
local Button = Fixture.Button
local Surface = Fixture.Surface
local Themes = Fixture.Themes
local Basalt = Fixture.Basalt

local ROLES = { "button", "primary", "ghost", "field", "row" }

local function makeSurface()
	return Surface.new({ theme = Themes.Get("graphite") })
end

return function(h)
	h:describe("State", function()
		h:it("declares the seven variants", function()
			h:expect(#State.Variants).ToBe(7)
			h:expect(State.Variants).ToEqual({
				"default",
				"hover",
				"pressed",
				"focused",
				"disabled",
				"selected",
				"invalid",
			})
		end)

		h:it("fills every variant for every role with real tokens", function()
			local tokens = Fixture.Tokens.RequiredColors

			for _, role in ipairs(ROLES) do
				for _, variant in ipairs(State.Variants) do
					local style = State.Style(role :: any, variant :: any)

					h:expect(style.text ~= nil).ToBeTruthy()
					h:expect(table.find(tokens, style.text) ~= nil).ToBeTruthy()

					if style.background then
						h:expect(table.find(tokens, style.background) ~= nil).ToBeTruthy()
					end

					if style.stroke then
						h:expect(table.find(tokens, style.stroke) ~= nil).ToBeTruthy()
					end
				end
			end
		end)

		h:it("resolves precedence: disabled, invalid, pressed, focused, selected, hover", function()
			h:expect(State.Variant({
				enabled = false,
				invalid = true,
				pressed = true,
				hovered = true,
			})).ToBe("disabled")

			h:expect(State.Variant({ invalid = true, pressed = true, hovered = true }))
				.ToBe("invalid")
			h:expect(State.Variant({ pressed = true, focused = true, selected = true }))
				.ToBe("pressed")
			h:expect(State.Variant({ focused = true, selected = true, hovered = true }))
				.ToBe("focused")
			h:expect(State.Variant({ selected = true, hovered = true })).ToBe("selected")
			h:expect(State.Variant({ hovered = true })).ToBe("hover")
			h:expect(State.Variant({})).ToBe("default")
		end)

		h:it("rejects an unknown role instead of returning nil", function()
			h:expect(function()
				State.Resolve("nope" :: any, {})
			end).ToThrow("unknown style role")
		end)
	end)

	h:describe("Button", function()
		h:it("paints the default variant from tokens", function()
			Mock.Reset()
			local surface = makeSurface()
			local button = Button.new(surface, { text = "Apply" })

			h:expect(button.instance.BackgroundColor3:ToHex()).ToBe("#26231F")
			h:expect(button.instance.TextColor3:ToHex()).ToBe("#EDE7DD")
			h:expect(button.instance.Text).ToBe("Apply")
			h:expect(button.instance.Size.Y.Offset).ToBe(32)
			h:expect(button._stroke.Transparency).ToBe(1)

			button:Destroy()
			surface:Destroy()
		end)

		h:it("paints the primary variant and shows the focus stroke on hover", function()
			Mock.Reset()
			local surface = makeSurface()
			local button = Button.new(surface, { text = "Run", variant = "primary" })

			h:expect(button.instance.BackgroundColor3:ToHex()).ToBe("#E3A63C")
			h:expect(button.instance.TextColor3:ToHex()).ToBe("#1D1B18")

			Mock.Fire(button.instance, "MouseEnter")

			h:expect(button.hovered).ToBeTruthy()
			h:expect(button._stroke.Transparency).ToBe(0)
			h:expect(button._stroke.Color:ToHex()).ToBe("#E3A63C")

			Mock.Fire(button.instance, "MouseLeave")
			h:expect(button._stroke.Transparency).ToBe(1)

			button:Destroy()
			surface:Destroy()
		end)

		h:it("activates once per click and swallows clicks while disabled", function()
			Mock.Reset()
			local surface = makeSurface()
			local count = 0

			local button = Button.new(surface, {
				text = "Apply",
				onClick = function()
					count += 1
				end,
			})

			Mock.Fire(button.instance, "MouseButton1Click")
			h:expect(count).ToBe(1)

			button:SetEnabled(false)
			Mock.Fire(button.instance, "MouseButton1Click")

			h:expect(count).ToBe(1)
			h:expect(button.instance.BackgroundColor3:ToHex()).ToBe("#26231F")
			h:expect(button.instance.TextColor3:ToHex()).ToBe("#8A8277")

			button:SetEnabled(true)
			Mock.Fire(button.instance, "MouseButton1Click")
			h:expect(count).ToBe(2)

			button:Destroy()
			surface:Destroy()
		end)

		h:it("carries a selected value and a visible selected variant", function()
			Mock.Reset()
			local surface = makeSurface()
			local button = Button.new(surface, { text = "Lock" })

			h:expect(button:GetValue()).ToBe(false)

			button:SetValue(true)

			h:expect(button:GetValue()).ToBe(true)
			h:expect(button.instance.BackgroundColor3:ToHex()).ToBe("#2E2820")
			h:expect(button.instance.TextColor3:ToHex()).ToBe("#E3A63C")

			button:SetValue(false)
			h:expect(button:GetValue()).ToBe(false)

			button:Destroy()
			surface:Destroy()
		end)

		h:it("hides without destroying and stops rendering after destroy", function()
			Mock.Reset()
			local surface = makeSurface()
			local button = Button.new(surface, { text = "Apply" })

			button:SetVisible(false)
			h:expect(button.instance.Visible).ToBeFalsy()

			button:SetVisible(true)
			h:expect(button.instance.Visible).ToBeTruthy()

			button:Destroy()
			button:SetEnabled(false)

			h:expect(button.destroyed).ToBeTruthy()
			h:expect(button.instance.Parent).ToBeNil()

			surface:Destroy()
		end)

		h:it("rejects an unknown variant loudly", function()
			Mock.Reset()
			local surface = makeSurface()

			h:expect(function()
				Button.new(surface, { variant = "neon" :: any })
			end).ToThrow("unknown button variant")

			surface:Destroy()
		end)
	end)

	h:describe("App", function()
		h:it("resolves the requested theme and density once", function()
			Mock.Reset()

			local app = Basalt.new({ theme = "bone", density = "comfortable", motion = "reduced" })

			h:expect(app.theme).ToBe("bone")
			h:expect(app.motion).ToBe("reduced")
			h:expect(app.surface.theme.name).ToBe("bone")
			h:expect(app.surface.density).ToBe("comfortable")
			h:expect(app.surface.motion).ToBe("reduced")
			h:expect(app.surface:Color("well"):ToHex()).ToBe("#F5F1E8")

			app:Destroy()
		end)

		h:it("builds a window and replaces the previous one", function()
			Mock.Reset()
			local app = Basalt.new({ theme = "signal" })

			local first = app:window({ title = "One" })
			h:expect(first.gui.Parent).ToBe(Mock.Services.CoreGui)

			local second = app:window({ title = "Two" })

			h:expect(first.destroyed).ToBeTruthy()
			h:expect(second.destroyed).ToBeFalsy()
			h:expect(app._window).ToBe(second)

			app:Destroy()
			h:expect(second.gui.Parent).ToBeNil()
		end)

		h:it("rejects an unknown theme before building anything", function()
			Mock.Reset()

			h:expect(function()
				Basalt.new({ theme = "neon" })
			end).ToThrow("unknown theme 'neon'")
		end)

		h:it("resolves auto density from the last input type", function()
			Mock.Reset()
			Mock.SetInputMode("touch")

			local touch = Basalt.new({ density = "auto" })
			h:expect(touch.density).ToBe("comfortable")
			touch:Destroy()

			Mock.SetInputMode("gamepad")

			local pad = Basalt.new({ density = "auto" })
			h:expect(pad.density).ToBe("comfortable")
			pad:Destroy()

			Mock.SetInputMode("keyboard")

			local desktop = Basalt.new({ density = "auto" })
			h:expect(desktop.density).ToBe("compact")
			h:expect(desktop.surface.density).ToBe("compact")
			desktop:Destroy()

			-- No density at all is the same measurement, not a hardcoded default.
			local implied = Basalt.new({})
			h:expect(implied.density).ToBe("compact")
			implied:Destroy()
		end)

		h:it("rejects an unknown density instead of silently shrinking", function()
			Mock.Reset()

			h:expect(function()
				Basalt.new({ density = "huge" })
			end).ToThrow("unknown density 'huge'")
		end)

		h:it("passes the app toggle key into the window, window overrides it", function()
			Mock.Reset()
			local app = Basalt.new({ toggleKey = Mock.Enum.KeyCode.Insert })

			local window = app:window({})
			h:expect(window:GetToggleKey()).ToBe(Mock.Enum.KeyCode.Insert)

			local override = app:window({ toggleKey = Mock.Enum.KeyCode.RightControl })
			h:expect(override:GetToggleKey()).ToBe(Mock.Enum.KeyCode.RightControl)

			app:Destroy()
		end)
	end)
end

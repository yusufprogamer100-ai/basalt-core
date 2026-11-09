-- Basalt / tests / specs / components
-- Leaf controls and the two containers that hold them. These tests care about
-- behavior and structure: what a click changes, what a disabled control
-- refuses, and whether a section actually owns its children.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Surface = Fixture.Surface
local Themes = Fixture.Themes
local Toggle = Fixture.Toggle
local Slider = Fixture.Slider
local Input = Fixture.Input
local Label = Fixture.Label
local Divider = Fixture.Divider
local Badge = Fixture.Badge
local Spacer = Fixture.Spacer
local Section = Fixture.Section
local Window = Fixture.Window

local function makeSurface()
	return Surface.new({ theme = Themes.Get("graphite") })
end

return function(h)
	h:describe("Label", function()
		h:it("sets text, tone and value in one place", function()
			Mock.Reset()
			local surface = makeSurface()
			local label = Label.new(surface, { text = "Ready", tone = "success", size = "small" })

			h:expect(label:GetValue()).ToBe("Ready")
			h:expect(label.instance.TextColor3:ToHex()).ToBe("#6FB08A")
			h:expect(label.instance.TextSize).ToBe(11)
			h:expect(label.instance.AutomaticSize).ToBe(Mock.Enum.AutomaticSize.Y)

			label:SetText("Changed")
			label:SetTone("danger")

			h:expect(label:GetValue()).ToBe("Changed")
			h:expect(label.instance.TextColor3:ToHex()).ToBe("#E4675C")

			label:Destroy()
			surface:Destroy()
		end)
	end)

	h:describe("Divider", function()
		h:it("is a one pixel seam that can strengthen", function()
			Mock.Reset()
			local surface = makeSurface()

			local normal = Divider.new(surface, {})
			local strong = Divider.new(surface, { strong = true, inset = false })

			h:expect(normal.instance.Size.Y.Offset).ToBe(1)
			h:expect(normal.instance.BackgroundColor3:ToHex()).ToBe("#2E2A25")
			h:expect(normal.instance.Position.X.Offset).ToBe(12)
			h:expect(strong.instance.BackgroundColor3:ToHex()).ToBe("#3D3830")
			h:expect(strong.instance.Size.X.Offset).ToBe(0)

			normal:Destroy()
			strong:Destroy()
			surface:Destroy()
		end)
	end)

	h:describe("Badge", function()
		h:it("measures its own width and carries a tone", function()
			Mock.Reset()
			local surface = makeSurface()
			local badge = Badge.new(surface, { text = "OK", tone = "success" })

			h:expect(badge.instance.Text).ToBe("OK")
			h:expect(badge.instance.TextColor3:ToHex()).ToBe("#6FB08A")
			h:expect(badge.instance.Size.Y.Offset).ToBe(16)
			h:expect(badge.instance.Size.X.Offset).ToBe(28)

			badge:SetText("BLOCKED")
			h:expect(badge.instance.Size.X.Offset).ToBe(54)

			badge:Destroy()
			surface:Destroy()
		end)
	end)

	h:describe("Spacer", function()
		h:it("holds a fixed vertical gap", function()
			Mock.Reset()
			local surface = makeSurface()
			local spacer = Spacer.new(surface, { height = 12 })

			h:expect(spacer.instance.Size.Y.Offset).ToBe(12)
			h:expect(spacer.instance.BackgroundTransparency).ToBe(1)

			spacer:Destroy()
			surface:Destroy()
		end)
	end)

	h:describe("Toggle", function()
		h:it("toggles from the row and fires onChange only on user action", function()
			Mock.Reset()
			local surface = makeSurface()
			local changes = {}

			local toggle = Toggle.new(surface, {
				text = "Aimbot",
				value = false,
				onChange = function(value)
					table.insert(changes, value)
				end,
			})

			h:expect(toggle:GetValue()).ToBe(false)
			h:expect(toggle._track.BackgroundColor3:ToHex()).ToBe("#26231F")

			Mock.Fire(toggle.instance, "MouseButton1Click")

			h:expect(toggle:GetValue()).ToBe(true)
			h:expect(toggle._track.BackgroundColor3:ToHex()).ToBe("#E3A63C")
			h:expect(changes).ToEqual({ true })

			toggle:SetValue(false)

			h:expect(toggle:GetValue()).ToBe(false)
			h:expect(#changes).ToBe(1)

			toggle:Destroy()
			surface:Destroy()
		end)

		h:it("refuses clicks and hides its note when disabled", function()
			Mock.Reset()
			local surface = makeSurface()
			local changes = 0

			local toggle = Toggle.new(surface, {
				text = "Aimbot",
				note = "Nearest target",
				onChange = function()
					changes += 1
				end,
			})

			h:expect(toggle.instance:FindFirstChild("Note") ~= nil).ToBeTruthy()
			h:expect(toggle.instance.Size.Y.Offset).ToBe(40)

			toggle:SetEnabled(false)
			Mock.Fire(toggle.instance, "MouseButton1Click")

			h:expect(toggle:GetValue()).ToBe(false)
			h:expect(changes).ToBe(0)
			h:expect(toggle._label.TextColor3:ToHex()).ToBe("#8A8277")

			toggle:Destroy()
			surface:Destroy()
		end)
	end)

	h:describe("Slider", function()
		h:it("snaps and clamps pure values", function()
			h:expect(Slider.Snap(43, 0, 100, 7)).ToBe(42)
			h:expect(Slider.Snap(-10, 0, 100, 5)).ToBe(0)
			h:expect(Slider.Snap(140, 0, 100, 5)).ToBe(100)
			h:expect(Slider.Ratio(50, 0, 100)).ToBe(0.5)
			h:expect(Slider.Ratio(50, 100, 100)).ToBe(0)
		end)

		h:it("maps a pointer position onto the track", function()
			h:expect(Slider.FromPointer(160, 100, 120, 0, 100, 5)).ToBe(50)
			h:expect(Slider.FromPointer(100, 100, 120, 0, 100, 5)).ToBe(0)
			h:expect(Slider.FromPointer(220, 100, 120, 0, 100, 5)).ToBe(100)
			h:expect(Slider.FromPointer(300, 100, 120, 0, 100, 5)).ToBe(100)
			h:expect(Slider.FromPointer(10, 100, 0, 20, 80, 5)).ToBe(20)
		end)

		h:it("rejects an empty range loudly", function()
			Mock.Reset()
			local surface = makeSurface()

			h:expect(function()
				Slider.new(surface, { min = 10, max = 10 })
			end).ToThrow("must be greater than")

			surface:Destroy()
		end)

		h:it("renders fill, steps with the keyboard and follows the pointer", function()
			Mock.Reset()
			local surface = makeSurface()
			local changes = {}

			local slider = Slider.new(surface, {
				text = "Range",
				min = 0,
				max = 100,
				step = 5,
				value = 50,
				suffix = " stud",
				onChange = function(value)
					table.insert(changes, value)
				end,
			})

			h:expect(slider:GetValue()).ToBe(50)
			h:expect(slider._fill.Size.X.Scale).ToBe(0.5)
			h:expect(slider._valueLabel.Text).ToBe("50 stud")

			slider:Step(1)
			h:expect(slider:GetValue()).ToBe(55)
			h:expect(changes).ToEqual({ 55 })

			slider._track.AbsolutePosition = Mock.Vector2.new(100, 0)
			slider._track.AbsoluteSize = Mock.Vector2.new(120, 4)

			Mock.Fire(
				slider._track,
				"InputBegan",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil, Mock.Vector3.new(160, 0, 0))
			)

			h:expect(slider:GetValue()).ToBe(50)

			Mock.Fire(
				Mock.Services.UserInputService,
				"InputChanged",
				Mock.Input(Mock.Enum.UserInputType.MouseMovement, nil, Mock.Vector3.new(220, 0, 0))
			)

			h:expect(slider:GetValue()).ToBe(100)
			h:expect(changes).ToEqual({ 55, 50, 100 })

			Mock.Fire(
				Mock.Services.UserInputService,
				"InputEnded",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1)
			)

			slider:Destroy()
			surface:Destroy()
		end)
	end)

	h:describe("Input", function()
		h:it("submits on focus lost and shows invalid state", function()
			Mock.Reset()
			local surface = makeSurface()
			local submitted = {}

			local input = Input.new(surface, {
				text = "Webhook",
				placeholder = "https://",
				value = "old",
				onSubmit = function(value)
					table.insert(submitted, value)
				end,
			})

			h:expect(input:GetValue()).ToBe("old")
			h:expect(input.box.PlaceholderText).ToBe("https://")

			Mock.Fire(input.box, "Focused")
			h:expect(input.focused).ToBeTruthy()
			h:expect(input._stroke.Color:ToHex()).ToBe("#E3A63C")

			input.box.Text = "new"
			Mock.Fire(input.box, "FocusLost", true)

			h:expect(input.focused).ToBeFalsy()
			h:expect(input:GetValue()).ToBe("new")
			h:expect(submitted).ToEqual({ "new" })

			input:SetInvalid(true)
			h:expect(input._stroke.Color:ToHex()).ToBe("#E4675C")

			input:SetEnabled(false)
			h:expect(input.box.TextEditable).ToBeFalsy()

			input:Destroy()
			surface:Destroy()
		end)
	end)

	h:describe("Section", function()
		h:it("orders its children and delegates every control factory", function()
			Mock.Reset()
			local surface = makeSurface()
			local page = Mock.Instance("Frame", "Page")

			local section =
				Section.new(surface, page, { title = "Targeting", note = "Nearest wins" })

			h:expect(section.instance.Parent).ToBe(page)
			h:expect(section.instance:FindFirstChild("Title") ~= nil).ToBeTruthy()
			h:expect(section.instance:FindFirstChild("Note") ~= nil).ToBeTruthy()

			local toggle = section:Toggle({ text = "Aimbot" })
			local slider = section:Slider({ text = "Range", step = 5 })
			local button = section:Button({ text = "Apply", variant = "primary" })
			local divider = section:Divider({})
			local badge = section:Badge({ text = "NEW" })
			local spacer = section:Spacer({ height = 6 })
			local label = section:Label({ text = "Hint" })
			local input = section:Input({ text = "Name" })

			h:expect(toggle.instance.Parent).ToBe(section.content)
			h:expect(toggle.instance.LayoutOrder).ToBe(1)
			h:expect(slider.instance.LayoutOrder).ToBe(2)
			h:expect(button.instance.LayoutOrder).ToBe(3)
			h:expect(divider.instance.LayoutOrder).ToBe(4)
			h:expect(badge.instance.LayoutOrder).ToBe(5)
			h:expect(spacer.instance.LayoutOrder).ToBe(6)
			h:expect(label.instance.LayoutOrder).ToBe(7)
			h:expect(input.instance.LayoutOrder).ToBe(8)

			local raw = Mock.Instance("Frame", "Raw")
			section:Add(raw)
			h:expect(raw.Parent).ToBe(section.content)
			h:expect(raw.LayoutOrder).ToBe(9)

			section:Destroy()
			h:expect(raw.Parent).ToBeNil()
			h:expect(toggle.destroyed).ToBeTruthy()

			page:Destroy()
			surface:Destroy()
		end)
	end)

	h:describe("Tab", function()
		h:it("starts the first tab and switches pages on demand", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, { width = 560, height = 420 })

			local combat = window:tab({ name = "Combat", hint = "1" })
			local visual = window:tab({ name = "Visuals", hint = "2" })

			h:expect(combat.active).ToBeTruthy()
			h:expect(combat.page.Visible).ToBeTruthy()
			h:expect(visual.active).ToBeFalsy()
			h:expect(visual.page.Visible).ToBeFalsy()
			h:expect(combat.button.instance.Parent).ToBe(window.rail)
			h:expect(combat.page.Parent).ToBe(window.content)
			h:expect(combat.button.instance:FindFirstChild("Hint") ~= nil).ToBeTruthy()

			visual:Show()

			h:expect(combat.active).ToBeFalsy()
			h:expect(visual.active).ToBeTruthy()
			h:expect(visual.page.Visible).ToBeTruthy()

			Mock.Fire(combat.button.instance, "MouseButton1Click")
			h:expect(combat.active).ToBeTruthy()

			local section = combat:section({ title = "Aim" })
			h:expect(section.instance.Parent).ToBe(combat.page)

			window:Destroy()

			h:expect(combat.destroyed).ToBeTruthy()
			h:expect(visual.destroyed).ToBeTruthy()

			surface:Destroy()
		end)
	end)
end

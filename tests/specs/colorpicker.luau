-- Basalt / tests / specs / colorpicker
-- The color math is the part that silently drifts: a picker that shows
-- #FF0000 while writing a slightly different color is worse than no picker.
-- The panel needs to stay out of the tab order while closed and let Escape-free
-- arrow nudging work while open.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Surface = Fixture.Surface
local Themes = Fixture.Themes
local Window = Fixture.Window
local ColorPicker = Fixture.ColorPicker

local function makeSurface()
	return Surface.new({
		theme = Themes.Get("graphite"),
		density = "comfortable",
	})
end

local function build(config: any)
	local surface = makeSurface()
	local window = Window.new(surface, {})
	local section = window:tab({ name = "Main" }):section({})
	local picker = section:ColorPicker(config)

	return surface, window, picker
end

local function press(x: number, y: number)
	return Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil, Mock.Vector3.new(x, y, 0))
end

return function(h)
	h:describe("ColorPicker", function()
		h:it("converts between HSV and Color3 without drifting", function()
			Mock.Reset()

			h:expect(ColorPicker.ToColor(0, 1, 1):ToHex()).ToBe("#FF0000")
			h:expect(ColorPicker.ToColor(120, 1, 1):ToHex()).ToBe("#00FF00")
			h:expect(ColorPicker.ToColor(240, 1, 1):ToHex()).ToBe("#0000FF")
			h:expect(ColorPicker.ToColor(0, 0, 1):ToHex()).ToBe("#FFFFFF")
			h:expect(ColorPicker.ToColor(0, 0, 0):ToHex()).ToBe("#000000")

			local hue, saturation, value = ColorPicker.ToHSV(Color3.fromRGB(255, 0, 0))
			h:expect(hue).ToBe(0)
			h:expect(saturation).ToBe(1)
			h:expect(value).ToBe(1)

			local grayHue, graySaturation = ColorPicker.ToHSV(Color3.fromRGB(128, 128, 128))
			h:expect(grayHue).ToBe(0)
			h:expect(graySaturation).ToBe(0)

			local source = ColorPicker.ToColor(210, 0.4, 0.7)
			local backHue, backSaturation, backValue = ColorPicker.ToHSV(source)
			h:expect(backHue).ToBeCloseTo(210, 1)
			h:expect(backSaturation).ToBeCloseTo(0.4, 0.01)
			h:expect(backValue).ToBeCloseTo(0.7, 0.01)
		end)

		h:it("opens and closes from the row, showing the panel only when open", function()
			Mock.Reset()

			local surface, window, picker = build({ text = "Accent" })

			h:expect(picker:IsOpen()).ToBe(false)
			h:expect(picker._panel.Visible).ToBe(false)

			picker:Activate()

			h:expect(picker:IsOpen()).ToBe(true)
			h:expect(picker._panel.Visible).ToBe(true)

			picker:Activate()

			h:expect(picker:IsOpen()).ToBe(false)
			h:expect(picker._panel.Visible).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("rewrites the value when a slider moves", function()
			Mock.Reset()

			local changes = {}
			local surface, window, picker = build({
				text = "Accent",
				value = Color3.fromRGB(255, 0, 0),
				onChange = function(color: any)
					table.insert(changes, color)
				end,
			})

			picker:Open()

			-- Hue track is 36px wide; 12px from the left is one third, 120deg.
			picker._hue._track.AbsolutePosition = Mock.Vector2.new(0, 0)
			picker._hue._track.AbsoluteSize = Mock.Vector2.new(36, 4)
			Mock.Fire(picker._hue._track, "InputBegan", press(12, 0))

			h:expect(picker.hue).ToBe(120)
			h:expect(picker:GetValue():ToHex()).ToBe("#00FF00")
			h:expect(picker._swatch.BackgroundColor3:ToHex()).ToBe("#00FF00")
			h:expect(picker._preview.BackgroundColor3:ToHex()).ToBe("#00FF00")
			h:expect(picker._hex.Text).ToBe("#00FF00")
			h:expect(#changes).ToBe(1)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("accepts a programmatic color without firing onChange", function()
			Mock.Reset()

			local changes = {}
			local surface, window, picker = build({
				value = Color3.fromRGB(255, 0, 0),
				onChange = function(color: any)
					table.insert(changes, color)
				end,
			})

			picker:SetValue(Color3.fromRGB(0, 128, 255))

			h:expect(picker:GetValue():ToHex()).ToBe("#0080FF")
			h:expect(picker._hex.Text).ToBe("#0080FF")
			h:expect(picker._sat:GetValue()).ToBe(100)
			h:expect(#changes).ToBe(0)

			-- A color the sliders cannot express exactly survives both paths.
			picker:SetValue(Color3.fromRGB(102, 170, 204))
			h:expect(picker:GetValue():ToHex()).ToBe("#66AACC")

			window:Destroy()
			surface:Destroy()
		end)

		h:it("keeps the closed panel out of the tab order", function()
			Mock.Reset()

			local surface, window, picker = build({ text = "Accent" })

			window._focus:Set(picker)
			h:expect(window._focus:Current()).ToBe(picker)

			window._focus:Set(picker._hue)
			h:expect(window._focus:Current()).ToBe(picker)

			picker:Open()
			window._focus:Set(picker._hue)
			h:expect(window._focus:Current()).ToBe(picker._hue)

			picker:Close()
			h:expect(picker._panel.Visible).ToBe(false)
			h:expect(window._focus:Current()).ToBe(picker)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("refuses to open or focus while disabled", function()
			Mock.Reset()

			local surface, window, picker = build({ text = "Accent", enabled = false })

			picker:Activate()
			h:expect(picker:IsOpen()).ToBe(false)

			picker:SetFocus(true)
			h:expect(picker.focused).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("closes when disabled or hidden", function()
			Mock.Reset()

			local surface, window, picker = build({ text = "Accent" })

			picker:Open()
			picker:SetEnabled(false)
			h:expect(picker:IsOpen()).ToBe(false)

			picker:SetEnabled(true)
			picker:Open()
			picker:SetVisible(false)
			h:expect(picker:IsOpen()).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("removes its sliders from focus when destroyed", function()
			Mock.Reset()

			local surface, window, picker = build({ text = "Accent" })

			picker:Open()
			window._focus:Set(picker._hue)
			h:expect(window._focus:Current()).ToBe(picker._hue)

			picker:Destroy()

			h:expect(window._focus:Current()).ToBeNil()

			for _, entry in ipairs(window._focus.entries) do
				h:expect(entry.control == picker._hue or entry.control == picker._sat).ToBe(false)
			end

			window:Destroy()
			surface:Destroy()
		end)
	end)
end

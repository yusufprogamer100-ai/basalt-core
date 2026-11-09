-- Basalt / tests / specs / progress
-- A progress bar is easy to fake: draw a rectangle, divide, done. These tests
-- check the parts that actually break: clamping, the readout format, and the
-- fact that a status bar never becomes a control the keyboard can land on.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Surface = Fixture.Surface
local Themes = Fixture.Themes
local Window = Fixture.Window
local Progress = Fixture.Progress

local function makeSurface()
	return Surface.new({
		theme = Themes.Get("graphite"),
		density = "comfortable",
	})
end

return function(h)
	h:describe("Progress", function()
		h:it("fills by ratio and writes a readable value", function()
			Mock.Reset()

			local surface = makeSurface()
			local progress = Progress.new(surface, {
				text = "Download",
				value = 25,
				min = 0,
				max = 100,
				suffix = "%",
			})

			h:expect(progress._fill.Size.X.Scale).ToBe(0.25)
			h:expect(progress._label.Text).ToBe("Download")
			h:expect(progress._valueLabel.Text).ToBe("25%")
			h:expect(progress:GetRatio()).ToBe(0.25)

			progress:SetValue(80)
			h:expect(progress._fill.Size.X.Scale).ToBe(0.8)
			h:expect(progress._valueLabel.Text).ToBe("80%")

			progress:Destroy()
			surface:Destroy()
		end)

		h:it("maps an offset range onto zero and one", function()
			Mock.Reset()

			local surface = makeSurface()
			local progress = Progress.new(surface, { min = 10, max = 30, value = 20 })

			h:expect(progress:GetRatio()).ToBe(0.5)

			progress:SetValue(0)
			h:expect(progress.value).ToBe(10)
			h:expect(progress:GetRatio()).ToBe(0)

			progress:SetValue(99)
			h:expect(progress.value).ToBe(30)
			h:expect(progress:GetRatio()).ToBe(1)

			progress:Destroy()
			surface:Destroy()
		end)

		h:it("drops the readout when showValue is false", function()
			Mock.Reset()

			local surface = makeSurface()
			local progress = Progress.new(surface, {
				text = "Indexing",
				value = 40,
				showValue = false,
			})

			h:expect(progress._valueLabel).ToBeNil()
			h:expect(progress._label.Text).ToBe("Indexing")

			progress:Destroy()
			surface:Destroy()
		end)

		h:it("renders a bare bar when no text is given", function()
			Mock.Reset()

			local surface = makeSurface()
			local progress = Progress.new(surface, { value = 50 })

			h:expect(progress.instance.Size.Y.Offset).ToBe(8)
			h:expect(progress._label).ToBeNil()
			h:expect(progress._valueLabel).ToBeNil()
			h:expect(progress._fill.Size.X.Scale).ToBe(0.5)

			progress:Destroy()
			surface:Destroy()
		end)

		h:it("switches tone through the theme instead of a raw color", function()
			Mock.Reset()

			local surface = makeSurface()
			local progress = Progress.new(surface, { text = "Job", value = 10, tone = "success" })

			h:expect(progress._fill.BackgroundColor3:ToHex()).ToBe(surface:Color("success"):ToHex())

			progress:SetTone("danger")
			h:expect(progress._fill.BackgroundColor3:ToHex()).ToBe(surface:Color("danger"):ToHex())

			h:expect(function()
				progress:SetTone("neon" :: any)
			end).ToThrow("no tone")

			progress:Destroy()
			surface:Destroy()
		end)

		h:it("rejects an impossible range at construction", function()
			Mock.Reset()

			local surface = makeSurface()

			h:expect(function()
				Progress.new(surface, { min = 10, max = 10 })
			end).ToThrow("greater than min")

			surface:Destroy()
		end)

		h:it("never becomes a keyboard target", function()
			Mock.Reset()

			local surface = makeSurface()
			local window = Window.new(surface, {})
			local section = window:tab({ name = "Main" }):section({})
			local progress = section:Progress({ text = "Load", value = 30 })

			h:expect(progress.SetFocus).ToBeNil()

			local tracked = false
			for _, entry in ipairs(window._focus.entries) do
				if entry.control == progress then
					tracked = true
				end
			end

			h:expect(tracked).ToBe(false)

			window:Destroy()
			surface:Destroy()
		end)
	end)
end

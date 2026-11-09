-- Basalt / tests / specs / console
-- A log viewer fails in three quiet ways: it grows an instance per line, it
-- loses the newest line below the fold, or it fights the user who scrolled up
-- to read. These tests pin all three.

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
	local window = Window.new(surface, {})
	local section = window:tab({ name = "Main" }):section({})
	local console = section:Console(config)

	return surface, window, console
end

return function(h)
	h:describe("Console", function()
		h:it("appends lines in order and tones them by level", function()
			Mock.Reset()

			local surface, window, console = build({
				title = "Output",
				rowHeight = 32,
				height = 32 * 3,
				timestamps = false,
			})

			console:Log("ready")
			console:Log("retrying", "warn")
			console:Log("failed", "error")

			h:expect(console:GetCount()).ToBe(3)
			h:expect(console._title.Text).ToBe("Output")

			local first = console._list:RowFor(1):FindFirstChild("Line")
			local second = console._list:RowFor(2):FindFirstChild("Line")
			local third = console._list:RowFor(3):FindFirstChild("Line")

			h:expect(first.Text).ToBe("ready")
			h:expect(first.TextColor3:ToHex()).ToBe(surface:Color("muted"):ToHex())
			h:expect(second.Text).ToBe("retrying")
			h:expect(second.TextColor3:ToHex()).ToBe(surface:Color("accent"):ToHex())
			h:expect(third.TextColor3:ToHex()).ToBe(surface:Color("danger"):ToHex())

			window:Destroy()
			surface:Destroy()
		end)

		h:it("keeps the newest lines when the ring buffer fills", function()
			Mock.Reset()

			local surface, window, console = build({
				rowHeight = 32,
				height = 32 * 2,
				maxLines = 3,
				timestamps = false,
			})

			for index = 1, 6 do
				console:Log("line " .. index)
			end

			local entries = console:GetEntries()

			h:expect(console:GetCount()).ToBe(3)
			h:expect(#entries).ToBe(3)
			h:expect(entries[1].text).ToBe("line 4")
			h:expect(entries[3].text).ToBe("line 6")

			local last = console._list:RowFor(4 - 1):FindFirstChild("Line")
			h:expect(last.Text).ToBe("line 6")

			window:Destroy()
			surface:Destroy()
		end)

		h:it("shows an empty state and clears back to it", function()
			Mock.Reset()

			local surface, window, console = build({
				rowHeight = 32,
				height = 32 * 3,
				timestamps = false,
			})

			h:expect(console._empty.Visible).ToBe(true)
			h:expect(console._list.frame.Visible).ToBe(false)

			console:Log("one")
			h:expect(console._empty.Visible).ToBe(false)
			h:expect(console._list.frame.Visible).ToBe(true)

			console:Clear()

			h:expect(console:GetCount()).ToBe(0)
			h:expect(console._empty.Visible).ToBe(true)
			h:expect(console._list:GetCount()).ToBe(0)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("holds a fixed row pool at 1000 lines", function()
			Mock.Reset()

			local surface, window, console = build({
				rowHeight = 32,
				height = 32 * 3,
				maxLines = 1000,
				timestamps = false,
			})

			for index = 1, 1000 do
				console:Log("line " .. index)
			end

			h:expect(console:GetCount()).ToBe(1000)
			h:expect(#console._list.rows).ToBe(5)
			h:expect(#console._list.rows < 1000).ToBe(true)
			h:expect(console._list.frame.CanvasSize.Y.Offset).ToBe(32000)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("follows new lines while pinned to the bottom", function()
			Mock.Reset()

			local surface, window, console = build({
				rowHeight = 32,
				height = 32 * 3,
				maxLines = 100,
				timestamps = false,
			})

			for index = 1, 40 do
				console:Log("line " .. index)
			end

			-- 40 * 32 - 96 = 1184, the bottom of the canvas.
			h:expect(console._list.frame.CanvasPosition.Y).ToBe(40 * 32 - 3 * 32)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("does not yank the viewport when the user has scrolled up", function()
			Mock.Reset()

			local surface, window, console = build({
				rowHeight = 32,
				height = 32 * 3,
				maxLines = 100,
				timestamps = false,
			})

			for index = 1, 40 do
				console:Log("line " .. index)
			end

			console._list.frame.CanvasPosition = Mock.Vector2.new(0, 0)
			console._list:Refresh(true)

			for index = 41, 45 do
				console:Log("line " .. index)
			end

			h:expect(console._list.frame.CanvasPosition.Y).ToBe(0)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("falls back to info for an unknown level", function()
			Mock.Reset()

			local surface, window, console = build({
				rowHeight = 32,
				height = 32 * 2,
				timestamps = false,
			})

			console:Log("odd", "trace" :: any)

			local entry = console:GetEntries()[1]
			h:expect(entry.level).ToBe("info")

			window:Destroy()
			surface:Destroy()
		end)
	end)
end

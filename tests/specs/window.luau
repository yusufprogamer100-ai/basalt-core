-- Basalt / tests / specs / window
-- A window is the first thing a user sees, so these tests cover the parts that
-- silently break in real executors: where the ScreenGui lands, whether drag
-- math survives a UIScale, and whether close actually releases the tree.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Surface = Fixture.Surface
local Window = Fixture.Window
local Themes = Fixture.Themes

local function makeSurface()
	return Surface.new({ theme = Themes.Get("graphite") })
end

local function pointer(x: number, y: number)
	return Mock.Vector3.new(x, y, 0)
end

local function move(toX: number, toY: number)
	Mock.Fire(
		Mock.Services.UserInputService,
		"InputChanged",
		Mock.Input(Mock.Enum.UserInputType.MouseMovement, nil, pointer(toX, toY))
	)
end

return function(h)
	h:describe("Window", function()
		h:it("lands under CoreGui with the requested size and a centered position", function()
			Mock.Reset()
			local surface = makeSurface()

			local window = Window.new(surface, {
				title = "Casper",
				subtitle = "build 1042",
				width = 560,
				height = 420,
			})

			h:expect(window.gui.Parent).ToBe(Mock.Services.CoreGui)
			h:expect(window.root.Size.X.Offset).ToBe(560)
			h:expect(window.root.Size.Y.Offset).ToBe(420)
			h:expect(window.root.Position.X.Scale).ToBe(0.5)
			h:expect(window.root.Position.X.Offset).ToBe(-280)
			h:expect(window.root.Position.Y.Offset).ToBe(-210)
			h:expect(window.title.Text).ToBe("Casper")
			h:expect(window.subtitle.Text).ToBe("build 1042")

			window:Destroy()
			surface:Destroy()
		end)

		h:it("fits the body below the header and one pixel seam", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, {})

			h:expect(window.header.Size.Y.Offset).ToBe(44)
			h:expect(window.body.Position.Y.Offset).ToBe(45)
			h:expect(window.body.Size.Y.Offset).ToBe(-45)
			h:expect(window.content.Parent).ToBe(window.body)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("minimizes to the header and restores the exact height", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, { height = 420 })

			window:Minimize()

			h:expect(window.minimized).ToBeTruthy()
			h:expect(window.body.Visible).ToBeFalsy()
			h:expect(window.root.Size.Y.Offset).ToBe(44)

			window:Minimize()
			h:expect(window.root.Size.Y.Offset).ToBe(44)

			window:Restore()

			h:expect(window.minimized).ToBeFalsy()
			h:expect(window.body.Visible).ToBeTruthy()
			h:expect(window.root.Size.Y.Offset).ToBe(420)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("toggles visibility without rebuilding the tree", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, {})

			h:expect(window:IsVisible()).ToBeTruthy()

			window:Hide()
			h:expect(window:IsVisible()).ToBeFalsy()

			window:Show()
			h:expect(window:IsVisible()).ToBeTruthy()

			window:Destroy()
			surface:Destroy()
		end)

		h:it("closes by destroying its own tree and is idempotent", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, {})

			h:expect(surface.registry:Count()).ToBeGreaterThan(0)

			Mock.Fire(window.closeButton, "MouseButton1Click")

			h:expect(window.destroyed).ToBeTruthy()
			h:expect(window.gui.Parent).ToBeNil()
			h:expect(surface.registry:Count()).ToBe(0)

			window:Destroy()
			h:expect(window.destroyed).ToBeTruthy()

			surface:Destroy()
		end)

		h:it("follows the pointer at UIScale 1 and UIScale 2", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, { width = 560, height = 420 })

			local startX = window.root.Position.X.Offset
			local startY = window.root.Position.Y.Offset

			Mock.Fire(
				window.header,
				"InputBegan",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil, pointer(0, 0))
			)
			move(40, 20)
			Mock.Fire(
				Mock.Services.UserInputService,
				"InputEnded",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1)
			)

			h:expect(window.root.Position.X.Offset).ToBe(startX + 40)
			h:expect(window.root.Position.Y.Offset).ToBe(startY + 20)

			window:SetScale(2)

			local scaledX = window.root.Position.X.Offset
			local scaledY = window.root.Position.Y.Offset

			Mock.Fire(
				window.header,
				"InputBegan",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil, pointer(0, 0))
			)
			move(40, 20)
			Mock.Fire(
				Mock.Services.UserInputService,
				"InputEnded",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1)
			)

			h:expect(window.root.Position.X.Offset).ToBe(scaledX + 20)
			h:expect(window.root.Position.Y.Offset).ToBe(scaledY + 10)
			h:expect(window.uiScale.Scale).ToBe(2)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("resizes from the grip and refuses to go below the floor", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, { width = 560, height = 420 })

			Mock.Fire(
				window.grip,
				"InputBegan",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil, pointer(0, 0))
			)
			move(100, 60)

			h:expect(window.root.Size.X.Offset).ToBe(660)
			h:expect(window.root.Size.Y.Offset).ToBe(480)

			move(-2000, -2000)

			h:expect(window.root.Size.X.Offset).ToBe(280)
			h:expect(window.root.Size.Y.Offset).ToBe(180)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("omits the controls it was told not to draw", function()
			Mock.Reset()
			local surface = makeSurface()

			local window = Window.new(surface, {
				closable = false,
				minimizable = false,
				resizable = false,
			})

			h:expect(window.closeButton).ToBeNil()
			h:expect(window.minimizeButton).ToBeNil()
			h:expect(window.grip).ToBeNil()

			window:Destroy()
			surface:Destroy()
		end)

		h:it("clamps scale to a usable range", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, {})

			window:SetScale(0.1)
			h:expect(window.uiScale.Scale).ToBe(0.5)

			window:SetScale(9)
			h:expect(window.uiScale.Scale).ToBe(2)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("animates minimize with a short tween only in full motion", function()
			Mock.Reset()
			local surface = makeSurface()
			local window = Window.new(surface, { height = 420 })

			window:Minimize()

			local tweens = Mock.Tweens()
			h:expect(#tweens).ToBe(1)
			h:expect(tweens[1].TweenInfo.Time).ToBe(0.12)
			h:expect(tweens[1].Goal.Size.Y.Offset).ToBe(44)
			h:expect(window.root.Size.Y.Offset).ToBe(44)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("sets the goal with no tween when motion is reduced", function()
			Mock.Reset()
			local surface = Surface.new({ theme = Themes.Get("graphite"), motion = "reduced" })
			local window = Window.new(surface, { height = 420 })

			window:Minimize()
			window:Restore()

			h:expect(#Mock.Tweens()).ToBe(0)
			h:expect(window.root.Size.Y.Offset).ToBe(420)

			window:Destroy()
			surface:Destroy()
		end)
	end)
end

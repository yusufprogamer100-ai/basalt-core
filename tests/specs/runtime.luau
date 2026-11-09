-- Basalt / tests / specs / runtime
-- The runtime layer is where the UI meets the engine, so these tests use the
-- mock's real Instance tree and real signals instead of asserting on props in
-- isolation. A surface that paints the right color but never parents is still
-- a broken surface.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Surface = Fixture.Surface
local Layout = Fixture.Layout
local Drag = Fixture.Drag
local Themes = Fixture.Themes

local function themedSurface(config: any?)
	local base = config or {}
	base.theme = base.theme or Themes.Get("graphite")
	return Surface.new(base)
end

return function(h)
	h:describe("Surface", function()
		h:it("resolves a token to its hex color and caches it", function()
			Mock.Reset()
			local surface = themedSurface()

			h:expect(surface:Color("ink"):ToHex()).ToBe("#EDE7DD")
			h:expect(surface:Color("ink")).ToBe(surface:Color("ink"))

			surface:Destroy()
		end)

		h:it("names the missing token instead of falling back", function()
			Mock.Reset()
			local surface = themedSurface()

			h:expect(function()
				surface:Color("nope")
			end).ToThrow("no color token 'nope'")

			surface:Destroy()
		end)

		h:it("uses the resolver order: hidden, then CoreGui, then PlayerGui", function()
			Mock.Reset()

			local hidden = Mock.Instance("Folder", "Hidden")
			local core = Mock.Instance("Folder", "Core")
			local player = Mock.Instance("Folder", "Player")

			local function resolver(hiddenValue: any, coreValue: any, playerValue: any)
				return {
					hidden = function()
						return hiddenValue
					end,
					coreGui = function()
						return coreValue
					end,
					playerGui = function()
						return playerValue
					end,
				}
			end

			local first = themedSurface({ resolver = resolver(hidden, core, player) })
			h:expect(first:Parent()).ToBe(hidden)

			local second = themedSurface({ resolver = resolver(nil, core, player) })
			h:expect(second:Parent()).ToBe(core)

			local third = themedSurface({ resolver = resolver(nil, nil, player) })
			h:expect(third:Parent()).ToBe(player)

			local none = themedSurface({ resolver = resolver(nil, nil, nil) })
			h:expect(function()
				none:Parent()
			end).ToThrow("no usable GUI parent")

			first:Destroy()
			second:Destroy()
			third:Destroy()
			none:Destroy()
		end)

		h:it("walks the real capability chain when gethui or CoreGui disappear", function()
			Mock.Reset()

			local surface = themedSurface()

			h:expect(surface:Parent()).ToBe(Mock.Services.CoreGui)

			Mock.disable("gethui")
			h:expect(surface:Parent()).ToBe(Mock.Services.CoreGui)

			Mock.disable("coregui")
			h:expect(surface:Parent()).ToBe(Mock.Services.Players.LocalPlayer.PlayerGui)

			Mock.Reset()
			surface:Destroy()
		end)

		h:it("creates a frame on the frame surface and tracks it", function()
			Mock.Reset()
			local surface = themedSurface()
			local root = Mock.Instance("Folder", "Root")

			local frame = surface:Frame({
				Parent = root,
				Size = UDim2.fromOffset(10, 10),
			})

			h:expect(frame.ClassName).ToBe("Frame")
			h:expect(frame.Parent).ToBe(root)
			h:expect(frame.BackgroundColor3:ToHex()).ToBe("#171614")
			h:expect(frame.BorderSizePixel).ToBe(0)
			h:expect(surface.registry:Count()).ToBe(1)
			h:expect(surface.registry:ByClass().Frame).ToBe(1)

			surface:Destroy()
			root:Destroy()
		end)

		h:it("keeps the label and button defaults readable", function()
			Mock.Reset()
			local surface = themedSurface()

			local label = surface:Label({ Text = "Value" })
			h:expect(label.BackgroundTransparency).ToBe(1)
			h:expect(label.TextColor3:ToHex()).ToBe("#EDE7DD")
			h:expect(label.TextSize).ToBe(13)

			local button = surface:Button({ Text = "Apply" })
			h:expect(button.ClassName).ToBe("TextButton")
			h:expect(button.BackgroundColor3:ToHex()).ToBe("#26231F")
			h:expect(button.AutoButtonColor).ToBeFalsy()

			surface:Destroy()
		end)

		h:it("attaches corner, stroke, scale and padding to a control", function()
			Mock.Reset()
			local surface = themedSurface()

			local control = surface:Raised({})
			local stroke = surface:Stroke(control, "seamStrong")
			local corner = surface:Corner(control, 2)
			local scale = surface:Scale(control, 1.5)
			local pad = surface:Pad(control, 8)

			h:expect(stroke.Parent).ToBe(control)
			h:expect(stroke.Thickness).ToBe(1)
			h:expect(stroke.Color:ToHex()).ToBe("#3D3830")
			h:expect(corner.Parent).ToBe(control)
			h:expect(corner.CornerRadius.Offset).ToBe(2)
			h:expect(scale.Parent).ToBe(control)
			h:expect(scale.Scale).ToBe(1.5)
			h:expect(pad.Parent).ToBe(control)
			h:expect(pad.PaddingLeft.Offset).ToBe(8)
			h:expect(pad.PaddingBottom.Offset).ToBe(8)

			surface:Destroy()
		end)
	end)

	h:describe("Layout", function()
		h:it("builds a vertical list with explicit ordering", function()
			Mock.Reset()
			local surface = themedSurface()
			local parent = Mock.Instance("Frame", "List")

			local layout = Layout.List(surface, parent, { padding = 4 })

			h:expect(layout.Parent).ToBe(parent)
			h:expect(layout.Padding.Offset).ToBe(4)
			h:expect(layout.FillDirection).ToBe(Mock.Enum.FillDirection.Vertical)
			h:expect(layout.SortOrder).ToBe(Mock.Enum.SortOrder.LayoutOrder)

			surface:Destroy()
		end)

		h:it("pads every side identically", function()
			Mock.Reset()
			local surface = themedSurface()
			local parent = Mock.Instance("Frame", "Padded")

			local pad = Layout.Padding(surface, parent, 6)

			h:expect(pad.PaddingTop.Offset).ToBe(6)
			h:expect(pad.PaddingRight.Offset).ToBe(6)
			h:expect(pad.PaddingBottom.Offset).ToBe(6)
			h:expect(pad.PaddingLeft.Offset).ToBe(6)

			surface:Destroy()
		end)
	end)

	h:describe("Drag", function()
		h:it("divides screen delta by the UI scale", function()
			local delta = Drag.Delta(Mock.Vector2.new(10, 10), Mock.Vector2.new(30, 50), 2)

			h:expect(delta.X).ToBe(10)
			h:expect(delta.Y).ToBe(20)
		end)

		h:it("treats a missing or zero scale as identity", function()
			local a = Drag.Delta(Mock.Vector2.new(0, 0), Mock.Vector2.new(20, 10), nil)
			local b = Drag.Delta(Mock.Vector2.new(0, 0), Mock.Vector2.new(20, 10), 0)

			h:expect(a.X).ToBe(20)
			h:expect(a.Y).ToBe(10)
			h:expect(b.X).ToBe(20)
			h:expect(b.Y).ToBe(10)
		end)

		h:it("moves position by offset and keeps the scale part", function()
			local start = UDim2.new(0.25, 100, 0.5, 50)
			local moved = Drag.Move(start, Mock.Vector2.new(12, -8))

			h:expect(moved.X.Scale).ToBe(0.25)
			h:expect(moved.X.Offset).ToBe(112)
			h:expect(moved.Y.Scale).ToBe(0.5)
			h:expect(moved.Y.Offset).ToBe(42)
		end)

		h:it("clamps resize at the minimum size", function()
			local start = UDim2.fromOffset(300, 200)
			local shrunk =
				Drag.Resize(start, Mock.Vector2.new(-200, -150), Mock.Vector2.new(280, 180))
			local grown = Drag.Resize(start, Mock.Vector2.new(40, 30), Mock.Vector2.new(280, 180))

			h:expect(shrunk.X.Offset).ToBe(280)
			h:expect(shrunk.Y.Offset).ToBe(180)
			h:expect(grown.X.Offset).ToBe(340)
			h:expect(grown.Y.Offset).ToBe(230)
		end)

		h:it("keeps a window inside the viewport", function()
			local inside = Drag.Clamp(
				UDim2.fromOffset(100, 100),
				Mock.Vector2.new(300, 200),
				Mock.Vector2.new(500, 400)
			)
			local outside = Drag.Clamp(
				UDim2.fromOffset(400, 380),
				Mock.Vector2.new(300, 200),
				Mock.Vector2.new(500, 400)
			)

			h:expect(inside.X.Offset).ToBe(100)
			h:expect(inside.Y.Offset).ToBe(100)
			h:expect(outside.X.Offset).ToBe(200)
			h:expect(outside.Y.Offset).ToBe(200)
		end)

		h:it("follows the pointer through InputChanged at UIScale 2", function()
			Mock.Reset()

			local target = Mock.Instance("Frame", "Target")
			target.Position = UDim2.fromOffset(100, 100)
			target.Size = UDim2.fromOffset(300, 200)

			local handle = Mock.Instance("Frame", "Handle")
			local scope = Drag.Bind(handle, target, { scale = 2 })

			Mock.Fire(
				handle,
				"InputBegan",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1, nil, Mock.Vector3.new(10, 10, 0))
			)
			Mock.Fire(
				Mock.Services.UserInputService,
				"InputChanged",
				Mock.Input(Mock.Enum.UserInputType.MouseMovement, nil, Mock.Vector3.new(30, 50, 0))
			)

			h:expect(target.Position.X.Offset).ToBe(110)
			h:expect(target.Position.Y.Offset).ToBe(120)

			Mock.Fire(
				Mock.Services.UserInputService,
				"InputEnded",
				Mock.Input(Mock.Enum.UserInputType.MouseButton1)
			)
			Mock.Fire(
				Mock.Services.UserInputService,
				"InputChanged",
				Mock.Input(Mock.Enum.UserInputType.MouseMovement, nil, Mock.Vector3.new(90, 90, 0))
			)

			h:expect(target.Position.X.Offset).ToBe(110)

			scope:Destroy()
			target:Destroy()
			handle:Destroy()
		end)

		h:it("resizes through the grip and stops at the floor", function()
			Mock.Reset()

			local target = Mock.Instance("Frame", "Target")
			target.Size = UDim2.fromOffset(300, 200)

			local grip = Mock.Instance("Frame", "Grip")
			local scope = Drag.Bind(grip, target, {
				mode = "resize",
				scale = 1,
				minSize = Mock.Vector2.new(280, 180),
			})

			Mock.Fire(
				grip,
				"InputBegan",
				Mock.Input(Mock.Enum.UserInputType.Touch, nil, Mock.Vector3.new(0, 0, 0))
			)
			Mock.Fire(
				Mock.Services.UserInputService,
				"InputChanged",
				Mock.Input(Mock.Enum.UserInputType.Touch, nil, Mock.Vector3.new(20, 10, 0))
			)

			h:expect(target.Size.X.Offset).ToBe(320)
			h:expect(target.Size.Y.Offset).ToBe(210)

			Mock.Fire(
				Mock.Services.UserInputService,
				"InputChanged",
				Mock.Input(Mock.Enum.UserInputType.Touch, nil, Mock.Vector3.new(-100, -100, 0))
			)

			h:expect(target.Size.X.Offset).ToBe(280)
			h:expect(target.Size.Y.Offset).ToBe(180)

			scope:Destroy()
			target:Destroy()
			grip:Destroy()
		end)
	end)
end

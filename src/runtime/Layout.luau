--!strict
-- Basalt / runtime / Layout
-- Layout helpers return UDim2 values and attach layout objects, but they never
-- measure. Measuring during construction is what makes a UI jitter on the
-- first frame; the Window builds a tree, the engine lays it out once.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Surface = require(script.Parent.Parent.runtime.Surface)

export type Density = "compact" | "comfortable"

export type ListOptions = {
	padding: number?,
	direction: "horizontal" | "vertical"?,
	horizontalAlignment: Enum.HorizontalAlignment?,
	verticalAlignment: Enum.VerticalAlignment?,
}

local Layout = {}

function Layout.Offset(x: number?, y: number?): UDim2
	return UDim2.fromOffset(x or 0, y or 0)
end

function Layout.Scale(x: number?, y: number?): UDim2
	return UDim2.fromScale(x or 0, y or 0)
end

function Layout.Fill(width: number?, height: number?): UDim2
	return UDim2.fromScale(width or 1, height or 1)
end

function Layout.Row(density: Density): UDim2
	return UDim2.new(1, 0, 0, Tokens.Row(density))
end

-- A list that does not set SortOrder would order children by creation time in
-- some engines and by name in others. Explicit LayoutOrder is the only stable
-- contract, so it is set here and never left to chance.
function Layout.List(surface: Surface.Surface, parent: Instance, options: ListOptions?): Instance
	local settings = options or {}

	local layout = surface:Create("UIListLayout", {
		Padding = UDim.new(0, settings.padding or Tokens.Space.sm),
		FillDirection = if settings.direction == "horizontal"
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical,
		HorizontalAlignment = settings.horizontalAlignment or Enum.HorizontalAlignment.Left,
		VerticalAlignment = settings.verticalAlignment or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local target = layout :: any
	target.Parent = parent
	return layout
end

function Layout.Padding(surface: Surface.Surface, parent: Instance, padding: number): Instance
	local pad = surface:Create("UIPadding", {
		PaddingTop = UDim.new(0, padding),
		PaddingBottom = UDim.new(0, padding),
		PaddingLeft = UDim.new(0, padding),
		PaddingRight = UDim.new(0, padding),
	})
	local target = pad :: any
	target.Parent = parent
	return pad
end

return Layout

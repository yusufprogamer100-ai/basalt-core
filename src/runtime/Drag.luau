--!strict
-- Basalt / runtime / Drag
-- Pointer math is pure and testable. The binding layer only translates input
-- events into those pure calls, because a drag bug is nearly always a unit bug:
-- screen pixels are not GUI pixels once a UIScale is in the tree.

local Scope = require(script.Parent.Parent.core.Scope)

export type Mode = "move" | "resize"

export type BindOptions = {
	scale: number | (() -> number)?,
	mode: Mode?,
	minSize: Vector2?,
	onUpdate: ((position: UDim2, size: UDim2) -> ())?,
}

local Drag = {}

local MIN_SCALE = 0.0001

local function resolveScale(value: number | (() -> number)?): number
	local scale = value

	if type(scale) == "function" then
		scale = scale()
	end

	if type(scale) ~= "number" or scale < MIN_SCALE then
		return 1
	end

	return scale
end

-- UIScale scales the rendered tree but not the input coordinates. Dividing the
-- screen-space delta by the scale is what makes the window track the cursor
-- instead of outrunning it.
function Drag.Delta(from: Vector2, to: Vector2, scale: number?): Vector2
	local factor = scale or 1

	-- A zero scale is not a useful geometry. Treat it as identity instead of
	-- dividing into a huge number that would teleport the window off screen.
	if type(factor) ~= "number" or factor < MIN_SCALE then
		factor = 1
	end

	return Vector2.new((to.X - from.X) / factor, (to.Y - from.Y) / factor)
end

function Drag.Move(start: UDim2, delta: Vector2): UDim2
	return UDim2.new(
		start.X.Scale,
		start.X.Offset + delta.X,
		start.Y.Scale,
		start.Y.Offset + delta.Y
	)
end

function Drag.Resize(start: UDim2, delta: Vector2, minimum: Vector2?): UDim2
	local min = minimum or Vector2.new(0, 0)

	local width = math.max(min.X, start.X.Offset + delta.X)
	local height = math.max(min.Y, start.Y.Offset + delta.Y)

	return UDim2.new(start.X.Scale, width, start.Y.Scale, height)
end

-- Keep the enclosure inside the viewport. A window dragged halfway off screen
-- is a window the user cannot get back on a touch device, where there is no
-- cursor to rescue it.
function Drag.Clamp(position: UDim2, size: Vector2, viewport: Vector2): UDim2
	local maxX = math.max(0, viewport.X - size.X)
	local maxY = math.max(0, viewport.Y - size.Y)

	local x = math.clamp(position.X.Offset, 0, maxX)
	local y = math.clamp(position.Y.Offset, 0, maxY)

	return UDim2.new(position.X.Scale, x, position.Y.Scale, y)
end

local function isDragStart(input: any): boolean
	local kind = input.UserInputType
	return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
end

local function isDragMove(input: any): boolean
	local kind = input.UserInputType

	if kind == Enum.UserInputType.Touch then
		return true
	end

	-- MouseMovement is the only stream that reports the live cursor position.
	return kind == Enum.UserInputType.MouseMovement
end

function Drag.Bind(handle: Instance, target: Instance, options: BindOptions?): Scope.Scope
	local settings = options or {}
	local scope = Scope.new()
	local mode = settings.mode or "move"
	local minimum = settings.minSize or Vector2.new(180, 120)

	local dragging = false
	local startPointer = Vector2.new(0, 0)
	local startPosition: UDim2 = (target :: any).Position
	local startSize: UDim2 = (target :: any).Size

	local function pointerOf(input: any): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end

	scope:AddConnection((handle :: any).InputBegan:Connect(function(input: any)
		if not isDragStart(input) then
			return
		end

		dragging = true
		startPointer = pointerOf(input)
		startPosition = (target :: any).Position
		startSize = (target :: any).Size
	end))

	local inputService = game:GetService("UserInputService")

	scope:AddConnection(inputService.InputChanged:Connect(function(input: any)
		if not dragging or not isDragMove(input) then
			return
		end

		local delta = Drag.Delta(startPointer, pointerOf(input), resolveScale(settings.scale))

		if mode == "resize" then
			(target :: any).Size = Drag.Resize(startSize, delta, minimum)
		else
			(target :: any).Position = Drag.Move(startPosition, delta)
		end

		if settings.onUpdate then
			settings.onUpdate((target :: any).Position, (target :: any).Size)
		end
	end))

	scope:AddConnection(inputService.InputEnded:Connect(function(input: any)
		if not isDragStart(input) then
			return
		end

		dragging = false
	end))

	return scope
end

return Drag

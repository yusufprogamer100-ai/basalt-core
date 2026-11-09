--!nocheck
-- Basalt / tests / mock / roblox
-- A headless stand-in for the part of the Roblox API Basalt touches. It is not
-- an engine: it fakes only what the library uses, and every capability is a
-- flag that a test can turn off. A missing capability must degrade, never
-- crash and never pass silently.

local Mock = {}

-- ---------------------------------------------------------------------------
-- Capabilities
-- ---------------------------------------------------------------------------

local DEFAULT_CAPABILITIES = {
	gethui = true,
	coregui = true,
	protect_gui = true,
	writefile = true,
	setclipboard = true,
	syn = true,
}

local capabilities = {}

-- ---------------------------------------------------------------------------
-- warn
-- ---------------------------------------------------------------------------

local warnings = {}

local function mockWarn(...)
	local parts = {}
	for index = 1, select("#", ...) do
		parts[index] = tostring(select(index, ...))
	end
	table.insert(warnings, table.concat(parts, " "))
end

-- ---------------------------------------------------------------------------
-- Vector2 / Vector3 / UDim / UDim2
-- ---------------------------------------------------------------------------

local Vector2 = {}
local Vector2Meta = {}

local function vector2Magnitude(vector)
	return math.sqrt(vector.X * vector.X + vector.Y * vector.Y)
end

function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2Meta)
end

function Vector2.zero()
	return Vector2.new(0, 0)
end

-- Magnitude and Unit are derived, so they live in __index instead of being
-- copied onto every vector. The shared metatable keeps one closure for all.
Vector2Meta.__index = function(self, key)
	if key == "Magnitude" then
		return vector2Magnitude(self)
	end

	if key == "Unit" then
		local magnitude = vector2Magnitude(self)
		if magnitude == 0 then
			return Vector2.new(0, 0)
		end
		return Vector2.new(self.X / magnitude, self.Y / magnitude)
	end

	return nil
end

Vector2Meta.__add = function(a, b)
	return Vector2.new(a.X + b.X, a.Y + b.Y)
end

Vector2Meta.__sub = function(a, b)
	return Vector2.new(a.X - b.X, a.Y - b.Y)
end

Vector2Meta.__mul = function(a, b)
	if type(a) == "number" then
		return Vector2.new(b.X * a, b.Y * a)
	end
	if type(b) == "number" then
		return Vector2.new(a.X * b, a.Y * b)
	end
	return Vector2.new(a.X * b.X, a.Y * b.Y)
end

Vector2Meta.__tostring = function(self)
	return string.format("(%.2f, %.2f)", self.X, self.Y)
end

local Vector3 = {}
local Vector3Meta = {}

local function vector3Magnitude(vector)
	return math.sqrt(vector.X * vector.X + vector.Y * vector.Y + vector.Z * vector.Z)
end

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3Meta)
end

function Vector3.zero()
	return Vector3.new(0, 0, 0)
end

Vector3Meta.__index = function(self, key)
	if key == "Magnitude" then
		return vector3Magnitude(self)
	end

	if key == "Unit" then
		local magnitude = vector3Magnitude(self)
		if magnitude == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(self.X / magnitude, self.Y / magnitude, self.Z / magnitude)
	end

	return nil
end

Vector3Meta.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

Vector3Meta.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

Vector3Meta.__tostring = function(self)
	return string.format("(%.2f, %.2f, %.2f)", self.X, self.Y, self.Z)
end

local UDim = {}
local UDimMeta = {}

function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDimMeta)
end

UDimMeta.__tostring = function(self)
	return string.format("%.2f,%d", self.Scale, self.Offset)
end

UDimMeta.__add = function(a, b)
	return UDim.new(a.Scale + b.Scale, a.Offset + b.Offset)
end

UDimMeta.__sub = function(a, b)
	return UDim.new(a.Scale - b.Scale, a.Offset - b.Offset)
end

local UDim2 = {}
local UDim2Meta = {}

function UDim2.new(xScale, xOffset, yScale, yOffset)
	return setmetatable({
		X = UDim.new(xScale, xOffset),
		Y = UDim.new(yScale, yOffset),
	}, UDim2Meta)
end

function UDim2.fromOffset(x, y)
	return UDim2.new(0, x or 0, 0, y or 0)
end

function UDim2.fromScale(x, y)
	return UDim2.new(x or 1, 0, y or 1, 0)
end

UDim2Meta.__index = function(self, key)
	if key == "Width" then
		return self.X
	end

	if key == "Height" then
		return self.Y
	end

	return nil
end

UDim2Meta.__tostring = function(self)
	return string.format("{%s},{%s}", tostring(self.X), tostring(self.Y))
end

UDim2Meta.__add = function(a, b)
	return UDim2.new(
		a.X.Scale + b.X.Scale,
		a.X.Offset + b.X.Offset,
		a.Y.Scale + b.Y.Scale,
		a.Y.Offset + b.Y.Offset
	)
end

UDim2Meta.__sub = function(a, b)
	return UDim2.new(
		a.X.Scale - b.X.Scale,
		a.X.Offset - b.X.Offset,
		a.Y.Scale - b.Y.Scale,
		a.Y.Offset - b.Y.Offset
	)
end

-- ---------------------------------------------------------------------------
-- Color3
-- ---------------------------------------------------------------------------

local Color3Meta = {}

Color3Meta.__index = Color3Meta

function Color3Meta:ToHex()
	return string.format(
		"#%02X%02X%02X",
		math.floor(self.R * 255 + 0.5),
		math.floor(self.G * 255 + 0.5),
		math.floor(self.B * 255 + 0.5)
	)
end

Color3Meta.__tostring = function(self)
	return self:ToHex()
end

local Color3 = {}

function Color3.new(r, g, b)
	return setmetatable({
		R = r or 0,
		G = g or 0,
		B = b or 0,
	}, Color3Meta)
end

function Color3.fromRGB(r, g, b)
	return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
end

function Color3.fromHex(hex)
	local value = string.gsub(hex, "#", "")
	assert(#value == 6, "Color3.fromHex expects six hex digits, got " .. tostring(hex))

	return Color3.fromRGB(
		tonumber(string.sub(value, 1, 2), 16),
		tonumber(string.sub(value, 3, 4), 16),
		tonumber(string.sub(value, 5, 6), 16)
	)
end

-- ---------------------------------------------------------------------------
-- Enum
-- ---------------------------------------------------------------------------

local function enumGroup(groupName, names)
	local group = { EnumType = groupName }

	for index, name in ipairs(names) do
		group[name] = {
			Name = name,
			Value = index,
			EnumType = groupName,
		}
	end

	return group
end

local Enum = {
	Font = enumGroup("Font", {
		"BuilderSans",
		"BuilderSansBold",
		"BuilderSansMedium",
		"RobotoMono",
		"SourceSans",
	}),
	FontWeight = enumGroup("FontWeight", {
		"Thin",
		"Light",
		"Regular",
		"Medium",
		"Semibold",
		"Bold",
		"Heavy",
	}),
	FontStyle = enumGroup("FontStyle", { "Normal", "Italic" }),
	EasingStyle = enumGroup("EasingStyle", { "Linear", "Sine", "Quad", "Quart" }),
	EasingDirection = enumGroup("EasingDirection", { "In", "Out", "InOut" }),
	KeyCode = enumGroup("KeyCode", {
		"RightShift",
		"RightControl",
		"LeftShift",
		"LeftControl",
		"Insert",
		"Escape",
		"Tab",
		"Return",
		"Space",
		"Up",
		"Down",
		"Left",
		"Right",
		"Slash",
		"Minus",
		"Equals",
		"One",
		"Two",
		"Three",
		"Four",
		"Five",
		"Six",
		"Seven",
		"Eight",
		"Nine",
	}),
	UserInputType = enumGroup("UserInputType", {
		"MouseButton1",
		"MouseButton2",
		"MouseMovement",
		"Touch",
		"Focus",
		"Keyboard",
		"Gamepad1",
	}),
	AutomaticSize = enumGroup("AutomaticSize", { "None", "X", "Y", "XY" }),
	ScrollingDirection = enumGroup("ScrollingDirection", { "X", "Y", "XY" }),
	SortOrder = enumGroup("SortOrder", { "LayoutOrder", "Name" }),
	FillDirection = enumGroup("FillDirection", { "Horizontal", "Vertical" }),
	HorizontalAlignment = enumGroup("HorizontalAlignment", { "Left", "Center", "Right" }),
	VerticalAlignment = enumGroup("VerticalAlignment", { "Top", "Center", "Bottom" }),
	TextXAlignment = enumGroup("TextXAlignment", { "Left", "Center", "Right" }),
	TextYAlignment = enumGroup("TextYAlignment", { "Top", "Center", "Bottom" }),
	TextTruncate = enumGroup("TextTruncate", { "None", "AtEnd" }),
	ApplyStrokeMode = enumGroup("ApplyStrokeMode", { "Contextual", "Border" }),
	ZIndexBehavior = enumGroup("ZIndexBehavior", { "Sibling" }),
}

-- ---------------------------------------------------------------------------
-- Font / TweenInfo
-- ---------------------------------------------------------------------------

local Font = {}

function Font.fromName(family, weight, style)
	return {
		Family = family,
		Weight = weight,
		Style = style,
	}
end

function Font.fromEnum(face)
	return { Enum = face }
end

local TweenInfo = {}

function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	return {
		Time = time or 0,
		EasingStyle = style,
		EasingDirection = direction,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}
end

-- ---------------------------------------------------------------------------
-- Signals
-- ---------------------------------------------------------------------------

local function makeSignal()
	local handlers = {}
	local signal = {}

	function signal:Connect(fn)
		local entry = { fn = fn, connected = true }

		table.insert(handlers, entry)

		return {
			Connected = true,
			Disconnect = function()
				entry.connected = false
				local position = table.find(handlers, entry)
				if position then
					table.remove(handlers, position)
				end
			end,
		}
	end

	function signal:Once(fn)
		local connection

		connection = signal:Connect(function(...)
			connection:Disconnect()
			fn(...)
		end)

		return connection
	end

	function signal:Fire(...)
		for _, entry in ipairs(table.clone(handlers)) do
			if entry.connected then
				local ok, err = pcall(entry.fn, ...)
				if not ok then
					error("mock signal handler failed: " .. tostring(err), 0)
				end
			end
		end
	end

	function signal:Count()
		return #handlers
	end

	function signal:Destroy()
		table.clear(handlers)
	end

	return signal
end

-- ---------------------------------------------------------------------------
-- Instance
-- ---------------------------------------------------------------------------

local SIGNAL_NAMES = {
	InputBegan = true,
	InputChanged = true,
	InputEnded = true,
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseButton1Click = true,
	MouseButton2Click = true,
	Activated = true,
	FocusLost = true,
	SelectionGained = true,
	SelectionLost = true,
	Focused = true,
}

local GUI_CLASSES = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	CanvasGroup = true,
}

local CLASS_DEFAULTS = {
	Frame = {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		AnchorPoint = Vector2.new(0, 0),
		AbsolutePosition = Vector2.new(0, 0),
		AbsoluteSize = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		BorderSizePixel = 1,
		Visible = true,
		ZIndex = 1,
		ClipsDescendants = false,
		Active = false,
	},
	TextLabel = {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		AnchorPoint = Vector2.new(0, 0),
		AbsolutePosition = Vector2.new(0, 0),
		AbsoluteSize = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = true,
		ZIndex = 1,
		ClipsDescendants = false,
		Text = "",
		TextColor3 = Color3.fromRGB(0, 0, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		RichText = false,
		AutomaticSize = Enum.AutomaticSize.None,
	},
	TextButton = {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		AnchorPoint = Vector2.new(0, 0),
		AbsolutePosition = Vector2.new(0, 0),
		AbsoluteSize = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = true,
		ZIndex = 1,
		ClipsDescendants = false,
		Active = true,
		Text = "",
		TextColor3 = Color3.fromRGB(0, 0, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		RichText = false,
		AutomaticSize = Enum.AutomaticSize.None,
	},
	TextBox = {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		AnchorPoint = Vector2.new(0, 0),
		AbsolutePosition = Vector2.new(0, 0),
		AbsoluteSize = Vector2.new(0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Visible = true,
		ZIndex = 1,
		ClipsDescendants = false,
		Active = true,
		Text = "",
		PlaceholderText = "",
		PlaceholderColor3 = Color3.fromRGB(128, 128, 128),
		TextColor3 = Color3.fromRGB(0, 0, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		ClearTextOnFocus = true,
		TextEditable = true,
		RichText = false,
		AutomaticSize = Enum.AutomaticSize.None,
	},
	ScreenGui = {
		Enabled = true,
		DisplayOrder = 0,
		IgnoreGuiInset = false,
		ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	},
	UIScale = {
		Scale = 1,
	},
	UIListLayout = {
		Padding = UDim.new(0, 0),
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	},
	UIPadding = {
		PaddingTop = UDim.new(0, 0),
		PaddingBottom = UDim.new(0, 0),
		PaddingLeft = UDim.new(0, 0),
		PaddingRight = UDim.new(0, 0),
	},
	UICorner = {
		CornerRadius = UDim.new(0, 0),
	},
	UIStroke = {
		Color = Color3.fromRGB(0, 0, 0),
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Transparency = 0,
	},
	ScrollingFrame = {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = true,
		ZIndex = 1,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		CanvasPosition = Vector2.new(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.None,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
	},
	UserInputService = {
		TouchEnabled = false,
		KeyboardEnabled = true,
		GamepadEnabled = false,
		MouseEnabled = true,
	},
}

local InstanceMeta = {}
local InstanceMethods = {}

local function childrenOf(instance)
	return rawget(instance, "_children")
end

local function signalsOf(instance)
	return rawget(instance, "_signals")
end

function InstanceMethods:Destroy()
	if rawget(self, "_destroyed") then
		return
	end

	rawset(self, "_destroyed", true)

	local children = childrenOf(self)
	for index = #children, 1, -1 do
		children[index]:Destroy()
	end

	local parent = rawget(self, "_parent")
	if parent then
		local siblings = childrenOf(parent)
		local position = table.find(siblings, self)
		if position then
			table.remove(siblings, position)
		end
		rawset(self, "_parent", nil)
	end

	for _, signal in pairs(signalsOf(self)) do
		signal:Destroy()
	end
end

function InstanceMethods:IsA(className)
	if className == "Instance" then
		return true
	end

	if className == "GuiObject" then
		return GUI_CLASSES[self.ClassName] == true
	end

	return self.ClassName == className
end

function InstanceMethods:FindFirstChild(name)
	for _, child in ipairs(childrenOf(self)) do
		if child.Name == name then
			return child
		end
	end

	return nil
end

function InstanceMethods:WaitForChild(name)
	local child = self:FindFirstChild(name)

	if not child then
		error(string.format("%s has no child named %q", tostring(self), name), 0)
	end

	return child
end

function InstanceMethods:GetChildren()
	return table.clone(childrenOf(self))
end

function InstanceMethods:GetDescendants()
	local found = {}

	local function walk(instance)
		for _, child in ipairs(childrenOf(instance)) do
			table.insert(found, child)
			walk(child)
		end
	end

	walk(self)
	return found
end

function InstanceMethods:GetPropertyChangedSignal(property)
	local key = "$" .. property
	local signals = signalsOf(self)
	local signal = signals[key]

	if not signal then
		signal = makeSignal()
		signals[key] = signal
	end

	return signal
end

function InstanceMethods:SetAttribute(name, value)
	rawget(self, "_attributes")[name] = value
end

function InstanceMethods:GetAttribute(name)
	return rawget(self, "_attributes")[name]
end

-- Only one TextBox can own keyboard text entry at a time, which is exactly how
-- the engine behaves. The mock keeps that single owner so Focus and GetFocusedTextBox
-- can be tested without a client.
local focusedTextBox = nil

function InstanceMethods:CaptureFocus()
	focusedTextBox = self
	self.Focused:Fire()
end

function InstanceMethods:ReleaseFocus(enterPressed)
	if focusedTextBox == self then
		focusedTextBox = nil
	end
	self.FocusLost:Fire(enterPressed == true, nil)
end

function InstanceMethods:IsFocused()
	return focusedTextBox == self
end

InstanceMeta.__index = function(self, key)
	if key == "Parent" then
		return rawget(self, "_parent")
	end

	if SIGNAL_NAMES[key] then
		local signals = signalsOf(self)
		local signal = signals[key]

		if not signal then
			signal = makeSignal()
			signals[key] = signal
		end

		return signal
	end

	local method = InstanceMethods[key]
	if method then
		return method
	end

	return rawget(self, "_props")[key]
end

InstanceMeta.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = rawget(self, "_parent")
		if old ~= nil then
			local siblings = childrenOf(old)
			local position = table.find(siblings, self)
			if position then
				table.remove(siblings, position)
			end
		end

		rawset(self, "_parent", value)

		if value ~= nil then
			assert(getmetatable(value) == InstanceMeta, "Parent must be a mock Instance")
			table.insert(childrenOf(value), self)
		end

		return
	end

	rawget(self, "_props")[key] = value

	local signal = signalsOf(self)["$" .. key]
	if signal then
		signal:Fire(value)
	end
end

InstanceMeta.__tostring = function(self)
	return string.format("%s(%s)", self.ClassName, self.Name)
end

local function newInstance(className, name)
	local instance = setmetatable({}, InstanceMeta)

	rawset(instance, "_children", {})
	rawset(instance, "_attributes", {})
	rawset(instance, "_props", {})
	rawset(instance, "_parent", nil)
	rawset(instance, "_destroyed", false)
	rawset(instance, "_signals", {})

	local defaults = CLASS_DEFAULTS[className]
	if defaults then
		local props = rawget(instance, "_props")
		for key, value in pairs(defaults) do
			props[key] = value
		end
	end

	instance.ClassName = className or "Instance"
	instance.Name = name or className or "Instance"

	return instance
end

local realTypeof = typeof

local function mockTypeof(value)
	if type(value) == "table" then
		local meta = getmetatable(value)

		if meta == InstanceMeta then
			return "Instance"
		end
		if meta == Vector2Meta then
			return "Vector2"
		end
		if meta == Vector3Meta then
			return "Vector3"
		end
		if meta == UDimMeta then
			return "UDim"
		end
		if meta == UDim2Meta then
			return "UDim2"
		end
	end

	return realTypeof(value)
end

-- ---------------------------------------------------------------------------
-- game / services
-- ---------------------------------------------------------------------------

local services = {}

services.CoreGui = newInstance("CoreGui", "CoreGui")

local playerGui = newInstance("PlayerGui", "PlayerGui")
services.Players = {
	LocalPlayer = {
		PlayerGui = playerGui,
		WaitForChild = function(_, name)
			if name == "PlayerGui" then
				return playerGui
			end
			error("LocalPlayer has no child named " .. tostring(name), 0)
		end,
	},
}

services.UserInputService = newInstance("UserInputService", "UserInputService")

-- Held keys are simulated explicitly: a test holds Shift, fires Tab, and the
-- same modifier path the library uses in a real client runs unchanged.
local heldKeys = {}

-- `density = "auto"` reads the last input type, so the mock keeps one. Default
-- is keyboard because that is what the headless test runner emulates.
local lastInputType = Enum.UserInputType.Keyboard

services.UserInputService.IsKeyDown = function(_, keyCode)
	return heldKeys[keyCode.Name] == true
end

services.UserInputService.GetFocusedTextBox = function()
	return focusedTextBox
end

services.UserInputService.GetLastInputType = function()
	return lastInputType
end

local tweens = {}

services.TweenService = {
	Create = function(_, instance, info, goal)
		local tween = {
			Instance = instance,
			TweenInfo = info,
			Goal = goal,
			Played = false,
			Cancelled = false,
			Completed = makeSignal(),
		}

		tween.Play = function(self)
			self.Played = true

			-- Tests cannot wait for interpolated frames, so Play lands the goal
			-- immediately. The assertion is about which property was animated
			-- and with what timing, never about a midpoint.
			for key, value in pairs(goal) do
				pcall(function()
					instance[key] = value
				end)
			end

			self.Completed:Fire()
		end

		tween.Cancel = function(self)
			self.Cancelled = true
		end

		table.insert(tweens, tween)
		return tween
	end,
}

services.RunService = newInstance("RunService", "RunService")

local game = {}

function game:GetService(name)
	if name == "CoreGui" then
		if not capabilities.coregui then
			error("CoreGui access denied", 0)
		end
		return services.CoreGui
	end

	local service = services[name]

	if not service then
		error("mock game has no service named " .. tostring(name), 0)
	end

	return service
end

-- ---------------------------------------------------------------------------
-- Executor environment
-- ---------------------------------------------------------------------------

local globalEnv = {}

local function refreshGlobals()
	globalEnv.gethui = if capabilities.gethui
		then function()
			return services.CoreGui
		end
		else nil

	globalEnv.protect_gui = if capabilities.protect_gui
		then function(instance)
			return instance
		end
		else nil

	globalEnv.writefile = if capabilities.writefile
		then function(path, contents)
			return path, contents
		end
		else nil

	globalEnv.setclipboard = if capabilities.setclipboard
		then function(text)
			return text
		end
		else nil
end

-- ---------------------------------------------------------------------------
-- task
-- ---------------------------------------------------------------------------

local clock = 0
local queue = {}
local delayed = {}

local taskMock = {}

function taskMock.defer(fn, ...)
	table.insert(queue, { fn = fn, args = { ... } })
end

function taskMock.spawn(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		error(err, 0)
	end
end

function taskMock.delay(seconds, fn, ...)
	table.insert(delayed, {
		at = clock + (seconds or 0),
		fn = fn,
		args = { ... },
	})
end

function taskMock.wait(seconds)
	clock += seconds or 0
	Mock.Flush()
end

function taskMock.cancel()
	-- Threads are not simulated. Cancelling is a no-op, and that is honest.
end

-- ---------------------------------------------------------------------------
-- Mock control
-- ---------------------------------------------------------------------------

function Mock.Flush(limit)
	local budget = limit or 1000
	local ran = 0

	while #queue > 0 and ran < budget do
		local batch = queue
		queue = {}

		for _, item in ipairs(batch) do
			local ok, err = pcall(item.fn, table.unpack(item.args))
			if not ok then
				error("mock task failed: " .. tostring(err), 0)
			end
			ran += 1
		end
	end

	return ran
end

function Mock.Advance(seconds)
	clock += seconds

	local due = {}
	local waiting = {}

	for _, item in ipairs(delayed) do
		if item.at <= clock then
			table.insert(due, item)
		else
			table.insert(waiting, item)
		end
	end

	delayed = waiting

	for _, item in ipairs(due) do
		local ok, err = pcall(item.fn, table.unpack(item.args))
		if not ok then
			error("mock delayed task failed: " .. tostring(err), 0)
		end
	end

	Mock.Flush()
end

function Mock.Reset()
	warnings = {}
	queue = {}
	delayed = {}
	clock = 0
	capabilities = {}
	focusedTextBox = nil
	lastInputType = Enum.UserInputType.Keyboard

	for index = #tweens, 1, -1 do
		table.remove(tweens, index)
	end

	for name in pairs(heldKeys) do
		heldKeys[name] = nil
	end

	-- Shortcut claims live in the global environment, exactly where the library
	-- puts them. A reset must clear them or one test would inherit another's
	-- fallback key.
	local ok, env = pcall(getfenv, 0)
	if ok and type(env) == "table" then
		env.__BASALT_KEY_CLAIMS = nil
		env.__BASALT_KEYBIND_KEYS = nil
	end

	for name, value in pairs(DEFAULT_CAPABILITIES) do
		capabilities[name] = value
	end

	refreshGlobals()
end

function Mock.Warnings()
	return table.clone(warnings)
end

function Mock.ClearWarnings()
	warnings = {}
end

function Mock.Clock()
	return clock
end

function Mock.disable(name)
	capabilities[name] = false
	refreshGlobals()
end

function Mock.enable(name)
	capabilities[name] = true
	refreshGlobals()
end

function Mock.has(name)
	return capabilities[name] == true
end

function Mock.Fire(instance, signalName, ...)
	instance[signalName]:Fire(...)
end

function Mock.Input(userInputType, keyCode, position, delta)
	return {
		UserInputType = userInputType,
		KeyCode = keyCode,
		Position = position or Vector3.new(0, 0, 0),
		Delta = delta or Vector3.new(0, 0, 0),
	}
end

function Mock.HoldKey(keyCode)
	heldKeys[keyCode.Name] = true
end

function Mock.ReleaseKey(keyCode)
	heldKeys[keyCode.Name] = nil
end

function Mock.Keyboard(keyCode)
	return Mock.Input(Enum.UserInputType.Keyboard, keyCode)
end

-- Input mode is device capability plus last input, the same two signals the
-- library reads. Passing "touch" flips both so the auto density path is real.
function Mock.SetInputMode(mode)
	local service = services.UserInputService

	if mode == "touch" then
		service.TouchEnabled = true
		service.KeyboardEnabled = false
		service.MouseEnabled = false
		lastInputType = Enum.UserInputType.Touch
	elseif mode == "gamepad" then
		service.TouchEnabled = false
		service.KeyboardEnabled = false
		service.MouseEnabled = false
		service.GamepadEnabled = true
		lastInputType = Enum.UserInputType.Gamepad1
	else
		service.TouchEnabled = false
		service.KeyboardEnabled = true
		service.MouseEnabled = true
		service.GamepadEnabled = false
		lastInputType = Enum.UserInputType.Keyboard
	end

	return service
end

Mock.Instance = setmetatable({ new = newInstance }, {
	__call = function(_, ...)
		return newInstance(...)
	end,
})
Mock.Color3 = Color3
Mock.Enum = Enum
Mock.Font = Font
Mock.TweenInfo = TweenInfo
Mock.Vector2 = Vector2
Mock.Vector3 = Vector3
Mock.UDim = UDim
Mock.UDim2 = UDim2
Mock.task = taskMock
Mock.warn = mockWarn
Mock.typeof = mockTypeof
Mock.Game = game
Mock.game = game
Mock.Services = services
Mock.InputObject = Mock.Input
Mock.Tweens = function()
	return table.clone(tweens)
end
Mock.Env = function()
	return globalEnv
end

Mock.Reset()

return Mock

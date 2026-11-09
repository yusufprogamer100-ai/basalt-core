--!strict
-- Basalt / runtime / Surface
-- One place that turns semantic tokens into Instances. Components never call
-- Color3.fromHex directly: a component that knows hex values is a component
-- that cannot be re-themed, and the theme contract stops being real.
--
-- Modernization rationale (R-12, R-13):
-- * Shadow() applies UIShadow only on pop-out surfaces (dropdowns, popups).
--   It is not applied to every card; elevation is deliberate, not decorative.
-- * Elevated() returns a frame on surfaceElevated with radiusLarge + shadow,
--   giving pop-outs depth without glass or glow.
-- * Corner() accepts named radius tokens (radiusSmall/Medium/Large) so the
--   radius system stays consistent (max 3 values, R-11).
-- * Font assignment stays pcall-guarded for executor compatibility.

local Registry = require(script.Parent.Parent.core.Registry)
local Scope = require(script.Parent.Parent.core.Scope)
local Typography = require(script.Parent.Parent.design.Typography)
local Tokens = require(script.Parent.Parent.design.Tokens)
local Motion = require(script.Parent.Parent.design.Motion)

export type Theme = {
	name: string,
	colors: { [string]: string },
}

export type Density = "compact" | "comfortable"

export type Resolver = {
	hidden: () -> Instance?,
	coreGui: () -> Instance?,
	playerGui: () -> Instance?,
}

export type Config = {
	theme: Theme,
	density: Density?,
	motion: Motion.Mode?,
	registry: Registry.Registry?,
	scope: Scope.Scope?,
	resolver: Resolver?,
}

export type Props = { [string]: any }

export type Surface = {
	theme: Theme,
	density: Density,
	motion: Motion.Mode,
	registry: Registry.Registry,
	scope: Scope.Scope,
	resolver: Resolver,
	_colors: { [string]: Color3 },
	_fonts: { [string]: Font },
	_destroyed: boolean,

	Color: (self: Surface, name: string) -> Color3,
	Text: (self: Surface, role: string) -> number,
	Font: (self: Surface, role: string) -> Font,
	Parent: (self: Surface) -> Instance,
	Create: (self: Surface, className: string, props: Props?, parent: Instance?) -> Instance,
	Apply: (self: Surface, instance: Instance, props: Props) -> Instance,
	Frame: (self: Surface, props: Props?) -> Instance,
	Well: (self: Surface, props: Props?) -> Instance,
	Raised: (self: Surface, props: Props?) -> Instance,
	Elevated: (self: Surface, level: number?, props: Props?) -> Instance,
	Label: (self: Surface, props: Props?) -> Instance,
	Button: (self: Surface, props: Props?) -> Instance,
	Seam: (self: Surface, props: Props?) -> Instance,
	ScreenGui: (self: Surface, name: string, displayOrder: number?) -> Instance,
	Corner: (self: Surface, instance: Instance, radius: string | number?) -> Instance,
	Shadow: (self: Surface, instance: Instance) -> Instance?,
	Stroke: (self: Surface, instance: Instance, colorName: string, thickness: number?) -> Instance,
	Scale: (self: Surface, instance: Instance, scale: number?) -> Instance,
	Pad: (self: Surface, instance: Instance, padding: number?) -> Instance,
	Tween: (self: Surface, instance: Instance, goal: Props, token: string, style: string?) -> any,
	Destroy: (self: Surface) -> (),
}

local Surface = {}
Surface.__index = Surface

-- ---------------------------------------------------------------------------
-- Default resolver
-- ---------------------------------------------------------------------------

-- Executor functions live in the global environment, not in a module. Reading
-- them through getfenv keeps this file free of undeclared-global type errors
-- and keeps a missing capability from turning into a crash.
local function globalFunction(name: string): (() -> any)?
	local ok, environment = pcall(getfenv, 0)

	if ok and type(environment) == "table" then
		local value = environment[name]
		if type(value) == "function" then
			return value
		end
	end

	return nil
end

local function callOptional(fn: (() -> any)?): any
	if not fn then
		return nil
	end

	local ok, value = pcall(fn)
	if ok then
		return value
	end

	return nil
end

local DEFAULT_RESOLVER: Resolver = {
	hidden = function()
		return callOptional(globalFunction("gethui"))
	end,
	coreGui = function()
		local ok, service = pcall(function()
			return game:GetService("CoreGui")
		end)
		if ok then
			return service
		end
		return nil
	end,
	playerGui = function()
		local ok, gui = pcall(function()
			local players = game:GetService("Players")
			return players.LocalPlayer:WaitForChild("PlayerGui")
		end)
		if ok then
			return gui
		end
		return nil
	end,
}

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

function Surface.new(config: Config): Surface
	local surface = setmetatable({
		theme = config.theme,
		density = config.density or "compact",
		motion = config.motion or "full",
		registry = config.registry or Registry.new(),
		scope = config.scope or Scope.new(),
		resolver = config.resolver or DEFAULT_RESOLVER,
		_colors = {} :: { [string]: Color3 },
		_fonts = {} :: { [string]: Font },
		_destroyed = false,
	}, Surface)

	return surface
end

function Surface:Color(name: string): Color3
	local cached = self._colors[name]

	if cached then
		return cached
	end

	local hex = self.theme.colors[name]

	if type(hex) ~= "string" then
		error(string.format("Basalt: theme '%s' has no color token '%s'", self.theme.name, name), 2)
	end

	local color = Color3.fromHex(hex)
	self._colors[name] = color

	return color
end

-- Text sizes are token values, not magic numbers chosen per component. A
-- component that picks its own size is a component that breaks the scale.
function Surface:Text(role: string): number
	local size = (Tokens.Text :: any)[role]

	if type(size) ~= "number" then
		error(string.format("Basalt: no text size for role '%s'", role), 2)
	end

	return size
end

function Surface:Font(role: string): Font
	local cached = self._fonts[role]

	if cached then
		return cached
	end

	local face = Typography.Resolve(role :: any)
	self._fonts[role] = face

	return face
end

function Surface:Parent(): Instance
	-- Order matters and each step is allowed to fail. gethui hides the UI from
	-- the game's own scripts; CoreGui survives most resets; PlayerGui always
	-- exists but is the most exposed to a game that clears it.
	local hidden = self.resolver.hidden()
	if hidden then
		return hidden
	end

	local core = self.resolver.coreGui()
	if core then
		return core
	end

	local player = self.resolver.playerGui()
	if player then
		return player
	end

	error("Basalt: no usable GUI parent (gethui, CoreGui and PlayerGui all failed)", 2)
end

function Surface:Apply(instance: Instance, props: Props): Instance
	local target = instance :: any

	for key, value in pairs(props) do
		if key == "Font" then
			-- Executor'larda Font datatype direkt atanamıyor, pcall ile güvenli yap
			pcall(function()
				target.Font = value
			end)
		else
			target[key] = value
		end
	end

	return instance
end

function Surface:Create(className: string, props: Props?, parent: Instance?): Instance
	local instance = Instance.new(className)

	if props then
		self:Apply(instance, props)
	end

	self.registry:Track(instance)

	if parent then
		(instance :: any).Parent = parent
	end

	return instance
end

function Surface:Frame(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("frame"),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("Frame", merged)
end

function Surface:Well(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("well"),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("Frame", merged)
end

function Surface:Raised(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("raised"),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("Frame", merged)
end

-- Elevated surfaces sit above the page (dropdowns, popups, overlays). Level
-- picks depth: 1 = subtle, 2 = medium, 3 = strong. surfaceElevatedN colors plus
-- shadow + radiusLarge so elevation reads as "above" without glow or glass.
function Surface:Elevated(level: number?, props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("surfaceElevated" .. tostring(level or 1)),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	local instance = self:Create("Frame", merged)

	-- Shadow on pop-outs only: UIShadow is pcall-guarded so executors without
	-- the capability don't crash the UI (executor-safe).
	local shadowConfig = if level == 2
		then Tokens.Shadow.elevated2
		elseif level == 3 then Tokens.Shadow.elevated3
		else Tokens.Shadow.elevated1

	local ok, shadow = pcall(function()
		local s = Instance.new("UIShadow")
		s.BlurRadius = shadowConfig.blur
		s.Spread = shadowConfig.spread
		s.Offset = shadowConfig.offset
		local color = self:Color("scrim")
		s.Color = color
		s.Transparency = shadowConfig.transparency
		s.Parent = instance
		return s
	end)

	if not ok then
		-- Silent fallback: no shadow on executors that lack UIShadow.
	end

	self:Corner(instance, "radiusLarge")

	return instance
end

function Surface:Label(props: Props?): Instance
	local merged: Props = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = self:Font("body"),
		TextColor3 = self:Color("ink"),
		TextSize = self:Text("body"),
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("TextLabel", merged)
end

function Surface:Button(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("raised"),
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Font = self:Font("body"),
		TextColor3 = self:Color("ink"),
		TextSize = self:Text("body"),
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("TextButton", merged)
end

function Surface:Seam(props: Props?): Instance
	local merged: Props = {
		BackgroundColor3 = self:Color("seam"),
		BorderSizePixel = 0,
	}

	for key, value in pairs(props or {}) do
		merged[key] = value
	end

	return self:Create("Frame", merged)
end

function Surface:ScreenGui(name: string, displayOrder: number?): Instance
	local gui = self:Create("ScreenGui", {
		Name = name,
		DisplayOrder = displayOrder or 0,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	local protect = globalFunction("protect_gui")
	if protect then
		pcall(protect, gui)
	end

	return gui
end

-- Corner applies a named radius token or a raw Offset value. Named tokens keep
-- the radius system consistent (max 3 values: radiusSmall/Medium/Large).
function Surface:Corner(instance: Instance, radius: string | number?): Instance
	local radiusValue: number

	if type(radius) == "string" then
		radiusValue = Tokens.Radius(radius)
	elseif type(radius) == "number" then
		radiusValue = radius
	else
		radiusValue = Tokens.Size.radiusControl
	end

	local corner = self:Create("UICorner", {
		CornerRadius = UDim.new(0, radiusValue),
	})
	local target = corner :: any
	target.Parent = instance
	return corner
end

function Surface:Stroke(instance: Instance, colorName: string, thickness: number?): Instance
	local stroke = self:Create("UIStroke", {
		Color = self:Color(colorName),
		Thickness = thickness or Tokens.Size.seam,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
	local target = stroke :: any
	target.Parent = instance
	return stroke
end

function Surface:Scale(instance: Instance, scale: number?): Instance
	local uiScale = self:Create("UIScale", {
		Scale = scale or 1,
	})
	local target = uiScale :: any
	target.Parent = instance
	return uiScale
end

function Surface:Pad(instance: Instance, padding: number?): Instance
	local value = padding or Tokens.Pad(self.density)

	local pad = self:Create("UIPadding", {
		PaddingTop = UDim.new(0, value),
		PaddingBottom = UDim.new(0, value),
		PaddingLeft = UDim.new(0, value),
		PaddingRight = UDim.new(0, value),
	})
	local target = pad :: any
	target.Parent = instance
	return pad
end

-- Motion is opt-in at the call site, because most property changes must not be
-- animated (a slider knob following a pointer would lag behind the cursor).
-- Reduced mode, a missing TweenService and a zero duration all take the same
-- branch: set the goal and return. There is no half-animated fallback.
function Surface:Tween(instance: Instance, goal: Props, token: string, style: string?): any
	local duration = Motion.Duration(token :: any, self.motion)

	if duration <= 0 then
		self:Apply(instance, goal)
		return nil
	end

	local ok, tween = pcall(function()
		local service = game:GetService("TweenService")
		local created =
			service:Create(instance, Motion.Info(token :: any, self.motion, style, "out"), goal)
		created:Play()
		return created
	end)

	if not ok then
		self:Apply(instance, goal)
		return nil
	end

	return tween
end

function Surface:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self.scope:Destroy()
	self.registry:Destroy()
end

return Surface

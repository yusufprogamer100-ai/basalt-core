--!strict
-- Basalt / init
-- Public surface. `Basalt.new` resolves the theme once and owns one Scope.
-- Components are added to the App as they land; nothing is exported before it
-- works. Two apps in the same game must not share state, so there is no module
-- level mutable table here.

local Themes = require(script.Parent.design.Themes)
local Palette = require(script.Parent.design.Palette)
local Surface = require(script.Parent.runtime.Surface)
local Window = require(script.Parent.components.Window)

local VERSION = "0.4.0"

export type Config = {
	theme: string?,
	density: "auto" | Surface.Density?,
	motion: "full" | "reduced"?,
	toggleKey: Enum.KeyCode?,
	displayOrder: number?,
}

export type App = {
	version: string,
	theme: string,
	density: Surface.Density,
	motion: "full" | "reduced",
	toggleKey: Enum.KeyCode?,
	surface: Surface.Surface,
	displayOrder: number,
	_window: Window.Window?,
	window: (self: App, config: Window.Config?) -> Window.Window,
	Destroy: (self: App) -> (),
}

local App = {}
App.__index = App

local function theme(name: string)
	return Themes.Get(name)
end

local function themeNames(): { string }
	return table.clone(Themes.Names)
end

local function audit(name: string)
	return Palette.Audit(Themes.Get(name))
end

-- `auto` is a measurement, not a guess: the last input type is the only signal
-- that says how the person in front of the screen is actually pointing. Touch
-- and gamepad both get the 44px row, because neither has a cursor to aim with.
-- A host that cannot answer falls back to the capability flags, then to compact.
local function resolveDensity(requested: string?): Surface.Density
	if requested == "compact" or requested == "comfortable" then
		return requested
	end

	if requested ~= nil and requested ~= "auto" then
		error(
			string.format(
				"Basalt: unknown density '%s'. Available: auto, compact, comfortable",
				tostring(requested)
			),
			3
		)
	end

	local ok, comfortable = pcall(function()
		local service = game:GetService("UserInputService")

		if type(service.GetLastInputType) == "function" then
			local last = service:GetLastInputType()

			if last == Enum.UserInputType.Touch or last == Enum.UserInputType.Gamepad1 then
				return true
			end

			if
				last == Enum.UserInputType.Keyboard
				or last == Enum.UserInputType.MouseButton1
				or last == Enum.UserInputType.MouseMovement
			then
				return false
			end
		end

		return service.TouchEnabled == true and service.KeyboardEnabled ~= true
	end)

	if ok and comfortable == true then
		return "comfortable"
	end

	return "compact"
end

local function new(config: Config?): App
	local settings = config or {}
	local themeName = settings.theme or "graphite"

	if not Themes.Has(themeName) then
		error(
			string.format(
				"Basalt: unknown theme '%s'. Available: %s",
				tostring(themeName),
				table.concat(Themes.Names, ", ")
			),
			2
		)
	end

	local density = resolveDensity(settings.density)
	local motion = settings.motion or "full"

	local surface = Surface.new({
		theme = Themes.Get(themeName),
		density = density,
		motion = motion,
	})

	local app = setmetatable({
		version = VERSION,
		theme = themeName,
		density = density,
		motion = motion,
		toggleKey = settings.toggleKey,
		surface = surface,
		_window = nil :: Window.Window?,
		displayOrder = settings.displayOrder or 0,
	}, App)

	return app
end

function App:window(config: Window.Config?): Window.Window
	if self._window and not self._window.destroyed then
		self._window:Destroy()
	end

	local window = Window.new(self.surface, {
		title = (config and config.title) or nil,
		subtitle = (config and config.subtitle) or nil,
		width = (config and config.width) or nil,
		height = (config and config.height) or nil,
		resizable = (config and config.resizable),
		minimizable = (config and config.minimizable),
		closable = (config and config.closable),
		displayOrder = self.displayOrder,
		position = (config and config.position) or nil,
		toggleKey = (config and config.toggleKey) or self.toggleKey,
	})

	self._window = window

	return window
end

function App:Destroy()
	if self._window then
		self._window:Destroy()
		self._window = nil
	end

	self.surface:Destroy()
end

local Basalt = {
	version = VERSION,
	new = new,
	theme = theme,
	themeNames = themeNames,
	audit = audit,
}

return Basalt

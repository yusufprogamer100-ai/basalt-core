--!strict
-- Basalt / components / Tab
-- A rail entry and a page, one object. The page is a ScrollingFrame so a long
-- section list never pushes the window past the viewport; the rail keeps the
-- tab names visible while the page scrolls.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local Layout = require(script.Parent.Parent.runtime.Layout)

local Section = require(script.Parent.Section)
local Button = require(script.Parent.Button)

export type Config = {
	name: string?,
	hint: string?,
}

export type Tab = {
	surface: Surface.Surface,
	name: string,
	hint: string?,
	button: Button.Button,
	page: Instance,
	active: boolean,
	destroyed: boolean,
	_scope: Scope.Scope,
	_sections: { Section.Section },
	_window: any,

	Activate: (self: Tab) -> (),
	Deactivate: (self: Tab) -> (),
	Show: (self: Tab) -> (),
	section: (self: Tab, config: Section.Config?) -> Section.Section,
	Destroy: (self: Tab) -> (),
}

local Tab = {}
Tab.__index = Tab

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

function Tab.new(
	surface: Surface.Surface,
	window: any,
	rail: Instance,
	pages: Instance,
	railWidth: number,
	config: Config?
): Tab
	local settings = config or {}
	local name = settings.name or "Tab"

	local page = surface:Create("ScrollingFrame", {
		Name = "Page",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = surface:Color("seamStrong"),
		Visible = false,
	})

	set(page, "Parent", pages)
	Layout.List(surface, page, { padding = Tokens.Space.md })
	Layout.Padding(surface, page, Tokens.Pad(surface.density))

	local button = Button.new(surface, {
		text = name,
		variant = "ghost",
		width = railWidth - Tokens.Space.md,
		height = Tokens.Row(surface.density),
	})

	set(button.instance, "Parent", rail)
	set(button.instance, "LayoutOrder", #rail:GetChildren() + 1)

	if window and window._focus then
		window._focus:Track(button, { group = "rail" })
	end

	if settings.hint then
		local hint = surface:Label({
			Name = "Hint",
			Text = settings.hint,
			Font = surface:Font("mono"),
			TextSize = surface:Text("mono"),
			TextColor3 = surface:Color("faint"),
			TextXAlignment = Enum.TextXAlignment.Right,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 18, 1, 0),
			Position = UDim2.new(1, -18, 0, 0),
		})

		set(hint, "Parent", button.instance)
	end

	local tab = setmetatable({
		surface = surface,
		name = name,
		hint = settings.hint,
		button = button,
		page = page,
		active = false,
		destroyed = false,
		_scope = Scope.new(),
		_sections = {},
		_window = window,
	}, Tab)

	button.onClick = function()
		tab:Show()
	end

	surface.scope:Add(tab)

	return tab
end

function Tab:Activate()
	if self.destroyed then
		return
	end

	self.active = true
	set(self.page, "Visible", true)
	self.button:SetSelected(true)
end

function Tab:Deactivate()
	if self.destroyed then
		return
	end

	self.active = false
	set(self.page, "Visible", false)
	self.button:SetSelected(false)
end

function Tab:Show()
	if self.destroyed then
		return
	end

	if self._window then
		self._window:SelectTab(self)
	end
end

function Tab:section(config: Section.Config?): Section.Section
	if self.destroyed then
		error("Basalt: cannot add a section to a destroyed tab", 2)
	end

	local section = Section.new(
		self.surface,
		self.page,
		config,
		if self._window then self._window._focus else nil,
		if self._window then self._window._layer else nil
	)
	table.insert(self._sections, section)
	self._scope:Add(section)

	return section
end

function Tab:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()
	self.button:Destroy()

	pcall(function()
		(self.page :: any):Destroy()
	end)
end

return Tab

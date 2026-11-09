--!strict
-- Basalt / components / Section
-- A titled group inside a tab. The section owns ordering through LayoutOrder,
-- because creation order is not a layout contract and name order is worse.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local Layout = require(script.Parent.Parent.runtime.Layout)
local Focus = require(script.Parent.Parent.runtime.Focus)

local Button = require(script.Parent.Button)
local Toggle = require(script.Parent.Toggle)
local Slider = require(script.Parent.Slider)
local Input = require(script.Parent.Input)
local Dropdown = require(script.Parent.Dropdown)
local Label = require(script.Parent.Label)
local Divider = require(script.Parent.Divider)
local Badge = require(script.Parent.Badge)
local Spacer = require(script.Parent.Spacer)

export type Config = {
	title: string?,
	note: string?,
}

export type Section = {
	surface: Surface.Surface,
	instance: Instance,
	content: Instance,
	title: Instance?,
	destroyed: boolean,
	_scope: Scope.Scope,
	_focus: Focus.Focus?,
	_layer: any,
	_order: number,

	Add: (self: Section, instance: Instance) -> Instance,
	Button: (self: Section, config: Button.Config?) -> Button.Button,
	Toggle: (self: Section, config: Toggle.Config?) -> Toggle.Toggle,
	Slider: (self: Section, config: Slider.Config?) -> Slider.Slider,
	Input: (self: Section, config: Input.Config?) -> Input.Input,
	Dropdown: (self: Section, config: Dropdown.Config?) -> Dropdown.Dropdown,
	MultiDropdown: (self: Section, config: Dropdown.Config?) -> Dropdown.Dropdown,
	Label: (self: Section, config: Label.Config?) -> Label.Label,
	Divider: (self: Section, config: Divider.Config?) -> Divider.Divider,
	Badge: (self: Section, config: Badge.Config?) -> Badge.Badge,
	Spacer: (self: Section, config: Spacer.Config?) -> Spacer.Spacer,
	Destroy: (self: Section) -> (),
}

local Section = {}
Section.__index = Section

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

function Section.new(
	surface: Surface.Surface,
	parent: Instance,
	config: Config?,
	focus: Focus.Focus?,
	layer: any
): Section
	local settings = config or {}

	local instance = surface:Frame({
		Name = "Section",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	set(instance, "Parent", parent)

	local order = 1

	local title: Instance? = nil
	if settings.title then
		local label = surface:Label({
			Name = "Title",
			Text = settings.title,
			Font = surface:Font("title"),
			TextSize = surface:Text("title"),
			TextColor3 = surface:Color("ink"),
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 20),
		})

		set(label, "Parent", instance)
		title = label
		order += 1
	end

	if settings.note then
		local note = surface:Label({
			Name = "Note",
			Text = settings.note,
			Font = surface:Font("small"),
			TextSize = surface:Text("small"),
			TextColor3 = surface:Color("muted"),
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 14),
		})

		set(note, "Parent", instance)
		order += 1
	end

	local content = surface:Frame({
		Name = "Content",
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	set(content, "Parent", instance)
	Layout.List(surface, content, { padding = Tokens.Space.sm })

	Layout.List(surface, instance, { padding = Tokens.Space.xs })

	local section = setmetatable({
		surface = surface,
		instance = instance,
		content = content,
		title = title,
		destroyed = false,
		_scope = Scope.new(),
		_focus = focus,
		_layer = layer,
		_order = 1,
	}, Section)

	surface.scope:Add(section)

	return section
end

function Section:Add(instance: Instance): Instance
	if self.destroyed then
		instance:Destroy()
		return instance
	end

	set(instance, "LayoutOrder", self._order)
	self._order += 1
	set(instance, "Parent", self.content)
	self._scope:Add(instance)

	return instance
end

local function attach(section: Section, component: any): any
	section:Add(component.instance)
	section._scope:Add(component)

	if section._focus and type(component.SetFocus) == "function" then
		section._focus:Track(component, { group = "page" })
	end

	return component
end

function Section:Button(config: Button.Config?): Button.Button
	return attach(self, Button.new(self.surface, config))
end

function Section:Toggle(config: Toggle.Config?): Toggle.Toggle
	return attach(self, Toggle.new(self.surface, config))
end

function Section:Slider(config: Slider.Config?): Slider.Slider
	return attach(self, Slider.new(self.surface, config))
end

function Section:Input(config: Input.Config?): Input.Input
	return attach(self, Input.new(self.surface, config))
end

function Section:Dropdown(config: Dropdown.Config?): Dropdown.Dropdown
	return attach(self, Dropdown.new(self.surface, config, self._layer))
end

-- The plan treats multi select as its own control. It is the same list with a
-- different value contract, so it is one flag instead of a second component.
function Section:MultiDropdown(config: Dropdown.Config?): Dropdown.Dropdown
	local merged = table.clone(config or {})
	merged.multi = true

	return self:Dropdown(merged)
end

function Section:Label(config: Label.Config?): Label.Label
	return attach(self, Label.new(self.surface, config))
end

function Section:Divider(config: Divider.Config?): Divider.Divider
	return attach(self, Divider.new(self.surface, config))
end

function Section:Badge(config: Badge.Config?): Badge.Badge
	return attach(self, Badge.new(self.surface, config))
end

function Section:Spacer(config: Spacer.Config?): Spacer.Spacer
	return attach(self, Spacer.new(self.surface, config))
end

function Section:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true
	self._scope:Destroy()

	pcall(function()
		(self.instance :: any):Destroy()
	end)
end

return Section

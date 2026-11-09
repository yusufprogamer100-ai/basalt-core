--!strict
-- Basalt / tests / fixture
-- One place that requires the library. Specs never reach into src directly,
-- so a moved module breaks one file instead of every spec.

local Fixture = {
	Signal = require(script.Parent.Parent.core.Signal),
	Scope = require(script.Parent.Parent.core.Scope),
	Scheduler = require(script.Parent.Parent.core.Scheduler),
	Registry = require(script.Parent.Parent.core.Registry),
	Error = require(script.Parent.Parent.core.Error),
	Palette = require(script.Parent.Parent.design.Palette),
	Tokens = require(script.Parent.Parent.design.Tokens),
	Motion = require(script.Parent.Parent.design.Motion),
	Typography = require(script.Parent.Parent.design.Typography),
	Themes = require(script.Parent.Parent.design.Themes),
	Surface = require(script.Parent.Parent.runtime.Surface),
	Layout = require(script.Parent.Parent.runtime.Layout),
	Drag = require(script.Parent.Parent.runtime.Drag),
	State = require(script.Parent.Parent.runtime.State),
	Keys = require(script.Parent.Parent.runtime.Input),
	Focus = require(script.Parent.Parent.runtime.Focus),
	Layer = require(script.Parent.Parent.runtime.Layer),
	VirtualList = require(script.Parent.Parent.runtime.VirtualList),
	Window = require(script.Parent.Parent.components.Window),
	Button = require(script.Parent.Parent.components.Button),
	Label = require(script.Parent.Parent.components.Label),
	Divider = require(script.Parent.Parent.components.Divider),
	Badge = require(script.Parent.Parent.components.Badge),
	Spacer = require(script.Parent.Parent.components.Spacer),
	Toggle = require(script.Parent.Parent.components.Toggle),
	Slider = require(script.Parent.Parent.components.Slider),
	Input = require(script.Parent.Parent.components.Input),
	Dropdown = require(script.Parent.Parent.components.Dropdown),
	Section = require(script.Parent.Parent.components.Section),
	Tab = require(script.Parent.Parent.components.Tab),
	Basalt = require(script.Parent.Parent.init),
}

return Fixture

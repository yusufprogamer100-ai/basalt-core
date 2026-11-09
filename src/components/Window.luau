--!strict
-- Basalt / components / Window
-- The enclosure. Two surfaces, one seam, a header that drags, a grip that
-- resizes, and a body that holds tabs. Nothing is centered by guessing: the
-- root is placed with a scale position minus half its own size, so it lands in
-- the middle of any viewport without reading the viewport.

local Tokens = require(script.Parent.Parent.design.Tokens)
local Scope = require(script.Parent.Parent.core.Scope)
local Surface = require(script.Parent.Parent.runtime.Surface)
local Drag = require(script.Parent.Parent.runtime.Drag)
local Layout = require(script.Parent.Parent.runtime.Layout)
local Focus = require(script.Parent.Parent.runtime.Focus)
local Input = require(script.Parent.Parent.runtime.Input)
local Layer = require(script.Parent.Parent.runtime.Layer)
local Button = require(script.Parent.Button)
local Tab = require(script.Parent.Tab)

export type Config = {
	title: string?,
	subtitle: string?,
	width: number?,
	height: number?,
	resizable: boolean?,
	minimizable: boolean?,
	closable: boolean?,
	displayOrder: number?,
	position: UDim2?,
	toggleKey: Enum.KeyCode?,
}

export type Window = {
	surface: Surface.Surface,
	gui: Instance,
	root: Instance,
	header: Instance,
	body: Instance,
	content: Instance,
	rail: Instance,
	title: Instance,
	subtitle: Instance,
	closeButton: Instance?,
	minimizeButton: Instance?,
	grip: Instance?,
	uiScale: Instance,
	layerScale: Instance,
	headerHeight: number,
	minimized: boolean,
	destroyed: boolean,
	toggleKey: Enum.KeyCode?,
	_scope: Scope.Scope,
	_focus: Focus.Focus,
	_toggleClaim: Input.Claim?,
	_search: any?,
	_layer: Layer.Layer,
	_fullHeight: UDim2,
	_tabs: { Tab.Tab },
	_activeTab: Tab.Tab?,

	GetGui: (self: Window) -> Instance,
	GetRoot: (self: Window) -> Instance,
	GetLayer: (self: Window) -> Layer.Layer,
	GetContent: (self: Window) -> Instance,
	IsVisible: (self: Window) -> boolean,
	IsTyping: (self: Window) -> boolean,
	Show: (self: Window) -> (),
	Hide: (self: Window) -> (),
	ToggleVisible: (self: Window) -> (),
	SetTitle: (self: Window, text: string) -> (),
	SetSubtitle: (self: Window, text: string) -> (),
	SetScale: (self: Window, scale: number) -> (),
	GetToggleKey: (self: Window) -> Enum.KeyCode?,
	SetSearch: (self: Window, target: any) -> (),
	FocusFirst: (self: Window) -> (),
	FocusTab: (self: Window, index: number) -> (),
	HandleInput: (self: Window, input: any, gameProcessed: boolean?) -> boolean,
	Minimize: (self: Window) -> (),
	Restore: (self: Window) -> (),
	tab: (self: Window, config: Tab.Config?) -> Tab.Tab,
	SelectTab: (self: Window, tab: Tab.Tab) -> (),
	Destroy: (self: Window) -> (),
}

local Window = {}
Window.__index = Window

local function prop(instance: Instance, key: string): any
	return (instance :: any)[key]
end

local function set(instance: Instance, key: string, value: any)
	(instance :: any)[key] = value
end

local function rootPosition(width: number, height: number): UDim2
	return UDim2.new(0.5, -width / 2, 0.5, -height / 2)
end

local function keyDown(keyCode: Enum.KeyCode): boolean
	local ok, value = pcall(function()
		return game:GetService("UserInputService"):IsKeyDown(keyCode)
	end)

	return ok and value == true
end

local function focusedBox(): any?
	local ok, value = pcall(function()
		return game:GetService("UserInputService"):GetFocusedTextBox()
	end)

	if ok and value ~= nil then
		return value
	end

	return nil
end

function Window.new(surface: Surface.Surface, config: Config?): Window
	local settings = config or {}
	local density = surface.density

	local width = settings.width or 560
	local height = settings.height or 420
	local headerHeight = Tokens.Header(density)
	local buttonSize = Tokens.Row(density)
	local fullSize = UDim2.fromOffset(width, height)

	-- The toggle shortcut is claimed globally at construction, not at first use,
	-- so two windows can never answer the same key.
	local toggleClaim =
		Input.Claim(if settings.toggleKey then { settings.toggleKey } else Input.ToggleCandidates)

	if not toggleClaim then
		warn(
			"Basalt: every toggle key candidate is already claimed; this window has no toggle shortcut"
		)
	end

	local window = setmetatable({
		surface = surface,
		gui = nil :: any,
		root = nil :: any,
		header = nil :: any,
		body = nil :: any,
		content = nil :: any,
		rail = nil :: any,
		title = nil :: any,
		subtitle = nil :: any,
		closeButton = nil :: any,
		minimizeButton = nil :: any,
		grip = nil :: any,
		uiScale = nil :: any,
		layerScale = nil :: any,
		headerHeight = headerHeight,
		minimized = false,
		destroyed = false,
		toggleKey = if toggleClaim then toggleClaim.key else nil,
		_scope = Scope.new(),
		_focus = Focus.new(),
		_toggleClaim = toggleClaim,
		_search = nil,
		_layer = nil :: any,
		_fullHeight = fullSize,
		_tabs = {} :: { Tab.Tab },
		_activeTab = nil :: Tab.Tab?,
	}, Window)

	local gui = surface:ScreenGui("Basalt", settings.displayOrder)
	set(gui, "Parent", surface:Parent())

	local root = surface:Frame({
		Name = "Root",
		Size = fullSize,
		Position = settings.position or rootPosition(width, height),
		ClipsDescendants = true,
	})

	set(root, "Parent", gui)

	local uiScale = surface:Scale(root, 1)

	-- Overlays are siblings of the root, not children: the root clips its
	-- contents, and a dropdown near the bottom edge must be able to open past
	-- the window instead of being cut off. The layer mirrors the root scale
	-- with its own UIScale so popups live in the same pixel space.
	local layerFrame = surface:Frame({
		Name = "Overlay",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 55,
		ClipsDescendants = false,
	})

	set(layerFrame, "Parent", gui)

	local layerScale = surface:Scale(layerFrame, 1)
	local layer = Layer.new(layerFrame, function(): number
		return prop(layerScale, "Scale")
	end)

	local header = surface:Well({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, headerHeight),
	})

	set(header, "Parent", root)

	local title = surface:Label({
		Name = "Title",
		Text = settings.title or "Basalt",
		Font = surface:Font("title"),
		TextSize = surface:Text("title"),
		TextColor3 = surface:Color("ink"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -24, 0, 20),
		Position = UDim2.fromOffset(12, 6),
	})

	set(title, "Parent", header)

	local subtitle = surface:Label({
		Name = "Subtitle",
		Text = settings.subtitle or "",
		Font = surface:Font("small"),
		TextSize = surface:Text("small"),
		TextColor3 = surface:Color("muted"),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 24),
	})

	set(subtitle, "Parent", header)

	local buttonY = (headerHeight - buttonSize) / 2

	local closeButton: Instance? = nil
	if settings.closable ~= false then
		local button = Button.new(surface, {
			text = "x",
			variant = "ghost",
			width = buttonSize,
			height = buttonSize,
			onClick = function()
				window:Destroy()
			end,
		})

		set(button.instance, "Name", "Close")
		set(button.instance, "Position", UDim2.new(1, -buttonSize - 4, 0, buttonY))
		set(button.instance, "Parent", header)

		window._scope:Add(button)
		window._focus:Track(button, { group = "header" })

		closeButton = button.instance
	end

	local minimizeButton: Instance? = nil
	if settings.minimizable ~= false then
		local button = Button.new(surface, {
			text = "-",
			variant = "ghost",
			width = buttonSize,
			height = buttonSize,
			onClick = function()
				if window.minimized then
					window:Restore()
				else
					window:Minimize()
				end
			end,
		})

		set(button.instance, "Name", "Minimize")
		set(button.instance, "Position", UDim2.new(1, -buttonSize * 2 - 8, 0, buttonY))
		set(button.instance, "Parent", header)

		window._scope:Add(button)
		window._focus:Track(button, { group = "header" })

		minimizeButton = button.instance
	end

	local seam = surface:Seam({
		Name = "Seam",
		Size = UDim2.new(1, 0, 0, Tokens.Size.seam),
		Position = UDim2.new(0, 0, 0, headerHeight),
	})

	set(seam, "Parent", root)

	local body = surface:Well({
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -(headerHeight + Tokens.Size.seam)),
		Position = UDim2.new(0, 0, 0, headerHeight + Tokens.Size.seam),
	})

	set(body, "Parent", root)

	local railWidth = Tokens.Rail(density)

	local rail = surface:Frame({
		Name = "Rail",
		Size = UDim2.new(0, railWidth, 1, 0),
	})

	set(rail, "Parent", body)
	Layout.List(surface, rail, {
		padding = Tokens.Space.xs,
		horizontalAlignment = Enum.HorizontalAlignment.Center,
	})

	local railSeam = surface:Seam({
		Name = "RailSeam",
		Size = UDim2.new(0, Tokens.Size.seam, 1, 0),
		Position = UDim2.new(0, railWidth, 0, 0),
	})

	set(railSeam, "Parent", body)

	local content = surface:Frame({
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -(railWidth + Tokens.Size.seam), 1, 0),
		Position = UDim2.new(0, railWidth + Tokens.Size.seam, 0, 0),
	})

	set(content, "Parent", body)

	local grip: Instance? = nil
	if settings.resizable ~= false then
		local handle = surface:Seam({
			Name = "Grip",
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.new(1, -12, 1, -12),
			Active = true,
		})

		set(handle, "Parent", root)
		grip = handle
	end

	local scale = function(): number
		return prop(uiScale, "Scale")
	end

	window._scope:Add(Drag.Bind(header, root, {
		mode = "move",
		scale = scale,
	}))

	if grip then
		window._scope:Add(Drag.Bind(grip, root, {
			mode = "resize",
			scale = scale,
			minSize = Vector2.new(280, 180),
		}))
	end

	-- A drag invalidates every popup position. Closing on the first press is
	-- cheaper and more honest than trying to re-anchor a list mid-drag.
	window._scope:AddConnection((header :: any).InputBegan:Connect(function(input: any)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			layer:Clear()
		end
	end))

	window.gui = gui
	window.root = root
	window.header = header
	window.body = body
	window.content = content
	window.rail = rail
	window.title = title
	window.subtitle = subtitle
	window.closeButton = closeButton
	window.minimizeButton = minimizeButton
	window.grip = grip
	window.uiScale = uiScale
	window.layerScale = layerScale
	window._layer = layer

	local inputService = game:GetService("UserInputService")

	window._scope:AddConnection(
		inputService.InputBegan:Connect(function(input: any, gameProcessed: boolean?)
			window:HandleInput(input, gameProcessed)
		end)
	)

	surface.scope:Add(window)

	return window
end

function Window:GetGui(): Instance
	return self.gui
end

function Window:GetRoot(): Instance
	return self.root
end

function Window:GetContent(): Instance
	return self.content
end

function Window:GetLayer(): Layer.Layer
	return self._layer
end

function Window:IsVisible(): boolean
	return prop(self.gui, "Enabled") == true
end

function Window:Show()
	if self.destroyed then
		return
	end

	set(self.gui, "Enabled", true)
end

function Window:Hide()
	if self.destroyed then
		return
	end

	self._layer:Clear()
	self._focus:Clear()
	set(self.gui, "Enabled", false)
end

function Window:ToggleVisible()
	if self:IsVisible() then
		self:Hide()
	else
		self:Show()
	end
end

function Window:IsTyping(): boolean
	return focusedBox() ~= nil
end

function Window:GetToggleKey(): Enum.KeyCode?
	return self.toggleKey
end

function Window:SetSearch(target: any)
	self._search = target
end

function Window:FocusFirst()
	if self.destroyed then
		return
	end

	self._focus:Next(1)
end

function Window:FocusTab(index: number)
	local tab = self._tabs[index]

	if not tab or tab.destroyed then
		return
	end

	self:SelectTab(tab)
	self._focus:Set(tab.button)
end

-- Returns true when the window consumed the key. The binding above ignores the
-- result, but tests and future overlay managers need to know who acted first.
function Window:HandleInput(input: any, gameProcessed: boolean?): boolean
	if self.destroyed or gameProcessed == true then
		return false
	end

	local box = focusedBox()

	-- Capture runs above the toggle key and every navigation shortcut, because
	-- the user is explicitly binding a key. The component answers false when it
	-- is not capturing, so this costs one method check otherwise.
	local capturing = self._focus:Current()

	if
		not box
		and capturing
		and type(capturing.CaptureKey) == "function"
		and capturing:CaptureKey(input)
	then
		return true
	end

	if
		self.toggleKey
		and input.UserInputType == Enum.UserInputType.Keyboard
		and input.KeyCode == self.toggleKey
	then
		if not box then
			self:ToggleVisible()
		end
		return true
	end

	if not self:IsVisible() then
		return false
	end

	-- A press outside an open overlay closes it before the click reaches the
	-- control underneath. Inside presses return false so the row still works.
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		if self._layer:Dismiss(input) then
			return true
		end
	end

	local action = Input.ActionFor(input, keyDown)

	-- A focused TextBox owns typing. Navigation keys still leave the field, but
	-- letters, numbers and slash must reach the text instead of the window.
	if box then
		if action == "escape" then
			pcall(function()
				box:ReleaseFocus(false)
			end)
			self._focus:Clear()
			return true
		end

		if action == "next" or action == "previous" then
			pcall(function()
				box:ReleaseFocus(false)
			end)
			self._focus:Next(if action == "previous" then -1 else 1)
			return true
		end

		if action == "activate" then
			pcall(function()
				box:ReleaseFocus(true)
			end)
			return true
		end

		return false
	end

	-- An open overlay owns the keyboard while it is on top. The dropdown uses
	-- Up and Down to move its highlight and Escape to close; anything it does
	-- not claim (Tab, shortcuts) falls through to the window.
	local overlay = self._layer:Top()

	if overlay and type(overlay.HandleAction) == "function" then
		local ok, handled = pcall(overlay.HandleAction, overlay, action)

		if ok and handled == true then
			return true
		end
	end

	if action == "next" or action == "previous" then
		-- Focus is leaving the field, so the list it opened cannot stay.
		self._layer:CloseTop()
		self._focus:Next(if action == "previous" then -1 else 1)
		return true
	end

	if action == "left" or action == "right" then
		local current = self._focus:Current()

		if current and type(current.Nudge) == "function" then
			current:Nudge(if action == "left" then -1 else 1)
			return true
		end

		self._focus:Move(action)
		return true
	end

	if action == "up" or action == "down" then
		self._focus:Move(action)
		return true
	end

	if action == "activate" then
		local current = self._focus:Current()

		if current and type(current.Activate) == "function" then
			current:Activate()
		end
		return true
	end

	if action == "escape" then
		if self._layer:CloseTop() then
			return true
		end

		self._focus:Clear()
		return true
	end

	if action == "search" then
		if self._search then
			self._focus:Set(self._search)

			if type(self._search.Capture) == "function" then
				self._search:Capture()
			end

			return true
		end

		return false
	end

	if action == "nudgeUp" or action == "nudgeDown" then
		local current = self._focus:Current()

		if current and type(current.Nudge) == "function" then
			current:Nudge(if action == "nudgeDown" then -1 else 1)
			return true
		end

		return false
	end

	local number = Input.Number(input, keyDown)

	if number then
		self:FocusTab(number)
		return true
	end

	return false
end

function Window:SetTitle(text: string)
	set(self.title, "Text", text)
end

function Window:SetSubtitle(text: string)
	set(self.subtitle, "Text", text)
end

function Window:SetScale(value: number)
	local scale = math.clamp(value, 0.5, 2)

	-- Popup geometry was measured at the old scale. Close instead of guessing.
	if scale ~= prop(self.uiScale, "Scale") then
		self._layer:Clear()
	end

	set(self.uiScale, "Scale", scale)
	set(self.layerScale, "Scale", scale)
end

function Window:Minimize()
	if self.destroyed or self.minimized then
		return
	end

	self._layer:Clear()
	self._fullHeight = prop(self.root, "Size")
	self.minimized = true

	set(self.body, "Visible", false)
	set(self.grip, "Visible", false)

	local full = self._fullHeight :: UDim2
	self.surface:Tween(self.root, {
		Size = UDim2.new(full.X.Scale, full.X.Offset, 0, self.headerHeight),
	}, "fast")

	-- The body just became invisible, so any focus inside it is unreachable.
	self._focus:Refresh()
end

function Window:Restore()
	if self.destroyed or not self.minimized then
		return
	end

	self.minimized = false

	set(self.body, "Visible", true)
	set(self.grip, "Visible", true)
	self.surface:Tween(self.root, { Size = self._fullHeight }, "fast")
end

function Window:tab(config: Tab.Config?): Tab.Tab
	if self.destroyed then
		error("Basalt: cannot add a tab to a destroyed window", 2)
	end

	local tab = Tab.new(
		self.surface,
		self,
		self.rail,
		self.content,
		Tokens.Rail(self.surface.density),
		config
	)

	table.insert(self._tabs, tab)

	if #self._tabs == 1 then
		self:SelectTab(tab)
	end

	return tab
end

function Window:SelectTab(tab: Tab.Tab)
	if self.destroyed or tab.destroyed then
		return
	end

	-- A popup belongs to the page that opened it. Switching pages closes it
	-- before the field it was anchored to disappears.
	self._layer:Clear()

	for _, other in ipairs(self._tabs) do
		if other ~= tab then
			other:Deactivate()
		end
	end

	tab:Activate()
	self._activeTab = tab
	self._focus:Refresh()
end

function Window:Destroy()
	if self.destroyed then
		return
	end

	self.destroyed = true

	for index = #self._tabs, 1, -1 do
		self._tabs[index]:Destroy()
	end

	table.clear(self._tabs)
	self._activeTab = nil

	if self._toggleClaim then
		self._toggleClaim.release()
		self._toggleClaim = nil
	end

	self._layer:Destroy()
	self._focus:Destroy()

	self._scope:Destroy()

	pcall(function()
		(self.gui :: any):Destroy()
	end)
end

return Window

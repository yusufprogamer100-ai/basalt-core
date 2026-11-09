-- Basalt / tests / specs / table
-- The two ways a data table fails at scale: it builds one instance per row, or
-- it loses keyboard control the moment it scrolls. These tests cover both,
-- plus the selection contract that onSelect only fires for user action.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Surface = Fixture.Surface
local Themes = Fixture.Themes
local Window = Fixture.Window
local Table = Fixture.Table

local function makeSurface()
	return Surface.new({
		theme = Themes.Get("graphite"),
		density = "comfortable",
	})
end

local function rows(count: number)
	local list = {}

	for index = 1, count do
		list[index] = { name = "Row " .. index, count = index }
	end

	return list
end

local function build(config: any)
	local surface = makeSurface()
	local window = Window.new(surface, {})
	local section = window:tab({ name = "Main" }):section({})
	local table = section:Table(config)

	return surface, window, table
end

local function key(code: any)
	return Mock.Keyboard(code)
end

local COLUMNS = {
	{ text = "Name", key = "name" },
	{ text = "Count", key = "count", align = "right", mono = true },
}

return function(h)
	h:describe("Table", function()
		h:it("keeps the row pool fixed at 1000 rows", function()
			Mock.Reset()

			local surface, window, small = build({
				columns = COLUMNS,
				rows = rows(10),
				rowHeight = 32,
				height = 32 * 6,
			})

			local smallCount = #small.instance:GetDescendants()

			local many = window:tab({ name = "Many" }):section({}):Table({
				columns = COLUMNS,
				rows = rows(1000),
				rowHeight = 32,
				height = 32 * 6,
			})

			-- Six visible rows plus two overscan slots. The number of row
			-- instances does not move when the data grows a hundredfold.
			h:expect(#many._list.rows).ToBe(8)
			h:expect(#many._list.rows <= 6 + 6).ToBe(true)
			h:expect(#many._list.rows < 1000).ToBe(true)
			h:expect(#many.instance:GetDescendants()).ToBe(smallCount)
			h:expect(many._list:GetCount()).ToBe(1000)

			-- The canvas, not the instance tree, carries the height.
			h:expect(many._list.frame.CanvasSize.Y.Offset).ToBe(32000)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("splits columns by weight and aligns cells", function()
			Mock.Reset()

			local surface, window, table = build({
				columns = {
					{ text = "Name", key = "name", weight = 1 },
					{ text = "Count", key = "count", weight = 3, align = "right", mono = true },
				},
				rows = { { name = "Alpha", count = 3 } },
			})

			local second = table._header:FindFirstChild("Column2")
			h:expect(second.Position.X.Scale).ToBe(0.25)
			h:expect(second.Size.X.Scale).ToBe(0.75)
			h:expect(second.TextXAlignment).ToBe(Mock.Enum.TextXAlignment.Right)

			local row = table._list:RowFor(1)
			h:expect(row).ToBeTruthy()

			local cells = table._cells[row]
			h:expect(cells[1].Text).ToBe("Alpha")
			h:expect(cells[2].Text).ToBe("3")
			h:expect(cells[2].TextXAlignment).ToBe(Mock.Enum.TextXAlignment.Right)
			h:expect(cells[1].Position.X.Scale).ToBe(0)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("selects silently and only calls back on Activate", function()
			Mock.Reset()

			local picks = {}
			local surface, window, table = build({
				columns = COLUMNS,
				rows = rows(5),
				onSelect = function(row: any, index: number)
					table.insert(picks, { name = row.name, index = index })
				end,
			})

			table:SetSelected(2)

			h:expect(table:GetSelected()).ToBe(2)
			h:expect(table:GetSelectedRow().name).ToBe("Row 2")
			h:expect(#picks).ToBe(0)

			local row = table._list:RowFor(2)
			h:expect(row.BackgroundTransparency).ToBe(0)
			h:expect(row.BackgroundColor3:ToHex()).ToBe(surface:Color("selected"):ToHex())

			table:Activate()

			h:expect(#picks).ToBe(1)
			h:expect(picks[1].name).ToBe("Row 2")
			h:expect(picks[1].index).ToBe(2)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("moves selection with Up and Down without losing focus", function()
			Mock.Reset()

			local picks = {}
			local surface, window, table = build({
				columns = COLUMNS,
				rows = rows(20),
				height = 32 * 4,
				rowHeight = 32,
				onSelect = function(_row: any, index: number)
					table.insert(picks, index)
				end,
			})

			window._focus:Set(table)
			h:expect(window._focus:Current()).ToBe(table)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Down), false)).ToBe(true)
			h:expect(table:GetSelected()).ToBe(1)
			h:expect(window._focus:Current()).ToBe(table)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Down), false)).ToBe(true)
			h:expect(table:GetSelected()).ToBe(2)
			h:expect(#picks).ToBe(0)

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Return), false)).ToBe(true)
			h:expect(picks).ToEqual({ 2 })

			h:expect(window:HandleInput(key(Mock.Enum.KeyCode.Up), false)).ToBe(true)
			h:expect(table:GetSelected()).ToBe(1)

			-- Scrolling past the viewport moves the canvas, not the instance tree.
			table:SetSelected(18)
			h:expect(table._list.frame.CanvasPosition.Y).ToBe(20 * 32 - 4 * 32)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("clamps selection when rows shrink and shows the empty state", function()
			Mock.Reset()

			local surface, window, table = build({ columns = COLUMNS, rows = rows(8) })

			table:SetSelected(7)
			h:expect(table:GetSelected()).ToBe(7)
			h:expect(table._empty.Visible).ToBe(false)

			table:SetRows(rows(3))
			h:expect(table:GetSelected()).ToBe(3)
			h:expect(table._list:GetCount()).ToBe(3)

			table:SetRows({})
			h:expect(table:GetSelected()).ToBeNil()
			h:expect(table._empty.Visible).ToBe(true)
			h:expect(table._list.frame.Visible).ToBe(false)
			table:Activate()

			window:Destroy()
			surface:Destroy()
		end)

		h:it("selects the clicked row and focuses the table", function()
			Mock.Reset()

			local picks = {}
			local surface, window, table = build({
				columns = COLUMNS,
				rows = rows(4),
				onSelect = function(_row: any, index: number)
					table.insert(picks, index)
				end,
			})

			local row = table._list:RowFor(3)
			local hit = table._hits[row]

			Mock.Fire(hit, "MouseButton1Click")

			h:expect(table:GetSelected()).ToBe(3)
			h:expect(picks).ToEqual({ 3 })
			h:expect(table.focused).ToBe(true)
			h:expect(table._stroke.Transparency).ToBe(0)

			window:Destroy()
			surface:Destroy()
		end)

		h:it("keeps the renderer rewriting reused slots instead of building cells", function()
			Mock.Reset()

			local rowsData = rows(40)
			local surface, window, table = build({
				columns = COLUMNS,
				rows = rowsData,
				rowHeight = 32,
				height = 32 * 4,
			})

			local row = table._list:RowFor(1)
			local before = #row:GetDescendants()

			table._list:ScrollToIndex(30)

			local after = table._list:RowFor(30)
			h:expect(after).ToBe(row)
			h:expect(#row:GetDescendants()).ToBe(before)
			h:expect(table._cells[row][1].Text).ToBe("Row 30")

			window:Destroy()
			surface:Destroy()
		end)

		h:it("refuses a table without columns", function()
			Mock.Reset()

			local surface = makeSurface()

			h:expect(function()
				Table.new(surface, { columns = {}, rows = rows(3) })
			end).ToThrow("at least one column")

			h:expect(function()
				Table.new(surface, {
					columns = { { text = "A", weight = 0 } },
					rows = rows(1),
				})
			end).ToThrow("positive number")

			surface:Destroy()
		end)
	end)
end

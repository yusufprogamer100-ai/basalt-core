--!strict
-- Basalt / design / Themes / graphite
-- Default theme. Warm neutral graphite, never blue-black: the surface is meant
-- to read as stone, and a blue cast makes it read as glass.
--
-- Measured pairs live in tests/specs/tokens.spec.luau. The source of truth is
-- the test, not this comment.

local theme = {
	name = "graphite",
	colors = {
		frame = "#171614",
		well = "#1D1B18",
		raised = "#26231F",
		seam = "#2E2A25",
		seamStrong = "#3D3830",
		ink = "#EDE7DD",
		muted = "#B5ADA1",
		faint = "#8A8277",
		accent = "#E3A63C",
		accentInk = "#1D1B18",
		danger = "#E4675C",
		success = "#6FB08A",
		focus = "#E3A63C",
		scrim = "#0B0A09",
		selected = "#2E2820",
	},
}

return theme

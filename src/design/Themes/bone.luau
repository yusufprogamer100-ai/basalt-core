--!strict
-- Basalt / design / Themes / bone
-- Light theme. The well is the brightest surface so content sits on light,
-- while the frame steps down to separate the enclosure from the page.
--
-- Depth tokens give layered elevation on light surfaces as subtle steps up,
-- never as colored glows. accent remains dark amber for contrast reasons.

local theme = {
	name = "bone",
	colors = {
		frame = "#E7E1D6",
		well = "#F5F1E8",
		raised = "#FBF8F1",
		seam = "#CFC7B8",
		seamStrong = "#B8AE9C",
		ink = "#1D1B18",
		muted = "#5C564C",
		faint = "#6E685C",
		accent = "#8A5310",
		accentInk = "#FFF8E9",
		danger = "#A8322A",
		success = "#2F6B4A",
		focus = "#8A5310",
		scrim = "#1D1B18",
		selected = "#E9E0CF",
		surfaceElevated1 = "#F1EBDC",
		surfaceElevated2 = "#EDE6D9",
		surfaceElevated3 = "#E8DFD0",
	},
}

return theme

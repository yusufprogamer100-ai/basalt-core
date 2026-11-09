--!strict
-- Basalt / design / Themes / signal
-- High contrast theme for low vision, not a decorative "neon" mode. Black well,
-- white ink, amber reserved for signal and focus. No color is used to carry
-- meaning on its own.
--
-- Depth tokens keep the high-contrast contract: gray steps only for elevation,
-- never colored, so elevation never becomes a signal of its own.

local theme = {
	name = "signal",
	colors = {
		frame = "#000000",
		well = "#0B0B0B",
		raised = "#171717",
		seam = "#2A2A2A",
		seamStrong = "#3D3D3D",
		ink = "#FFFFFF",
		muted = "#D0D0D0",
		faint = "#A8A8A8",
		accent = "#FFC24B",
		accentInk = "#000000",
		danger = "#FF8A80",
		success = "#7FE0A6",
		focus = "#FFC24B",
		scrim = "#000000",
		selected = "#1F1A0E",
		surfaceElevated1 = "#141414",
		surfaceElevated2 = "#1E1E1E",
		surfaceElevated3 = "#282828",
	},
}

return theme

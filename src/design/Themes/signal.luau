--!strict
-- Basalt / design / Themes / signal
-- High contrast theme for low vision, not a decorative "neon" mode. Black well,
-- white ink, amber reserved for signal and focus. No color is used to carry
-- meaning on its own.
--
-- surfaceElevated / surfaceOverlay keep the high-contrast contract: they are
-- steps of gray, never colored, so elevation never becomes a signal of its own.

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
		surfaceElevated = "#141414",
		surfaceOverlay = "#1E1E1E",
	},
}

return theme

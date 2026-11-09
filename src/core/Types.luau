--!strict
-- Basalt / core / Types
-- The public type surface lives in one module so consumers can write:
--   local Types = require(script.core.Types)
--   local config: Types.Config = { theme = "graphite" }

export type ThemeName = "graphite" | "bone" | "signal"

export type Density = "auto" | "compact" | "comfortable"

export type MotionMode = "full" | "reduced"

export type ColorToken =
	"frame"
	| "well"
	| "raised"
	| "seam"
	| "seamStrong"
	| "ink"
	| "muted"
	| "faint"
	| "accent"
	| "accentInk"
	| "danger"
	| "success"
	| "focus"
	| "scrim"
	| "selected"

export type Theme = {
	name: string,
	colors: { [string]: string },
}

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Cleanup = () -> ()

export type Config = {
	theme: ThemeName?,
	density: Density?,
	motion: MotionMode?,
	parent: Instance?,
	toggleKey: Enum.KeyCode?,
	backdrop: "seams" | "flat" | { image: string }?,
}

--!strict
-- Basalt / design / Motion
-- Motion exists to explain a state change, nothing else. Reduced mode removes
-- it entirely instead of shortening it to a flicker.
--
-- Modernization rationale (v0.4.0, R-19):
-- * Spring physics for press/lift states so interaction feels physical without
--   overshooting (spring token).
-- * Staggered reveal for section content so tab changes feel intentional.
-- * Durations long enough to be felt, short enough to stay snappy:
--   fast 0.12s, base 0.24s, slow 0.32s.
-- * Reduced mode still returns 0: accessibility first (R-32).

export type Mode = "full" | "reduced"

export type Token = "instant" | "fast" | "base" | "slow" | "spring"

local DURATION: { [Token]: number } = {
	instant = 0,
	fast = 0.12,
	base = 0.24,
	slow = 0.32,
	spring = 0.28,
}

local EASING: { [string]: Enum.EasingStyle } = {
	out = Enum.EasingStyle.Quad,
	outStrong = Enum.EasingStyle.Quart,
	inOut = Enum.EasingStyle.Sine,
	linear = Enum.EasingStyle.Linear,
}

local DIRECTION: { [string]: Enum.EasingDirection } = {
	["in"] = Enum.EasingDirection.In,
	out = Enum.EasingDirection.Out,
	inOut = Enum.EasingDirection.InOut,
}

local Motion = {}

function Motion.Duration(token: Token, mode: Mode): number
	if mode == "reduced" then
		return 0
	end
	return DURATION[token]
end

function Motion.Easing(style: string, direction: string): (Enum.EasingStyle, Enum.EasingDirection)
	local easing = EASING[style]
	if not easing then
		error("Basalt: unknown easing '" .. tostring(style) .. "'", 2)
	end

	local dir = DIRECTION[direction]
	if not dir then
		error("Basalt: unknown easing direction '" .. tostring(direction) .. "'", 2)
	end

	return easing, dir
end

function Motion.Info(token: Token, mode: Mode, style: string?, direction: string?): TweenInfo
	local easing, dir = Motion.Easing(style or "out", direction or "out")
	return TweenInfo.new(Motion.Duration(token, mode), easing, dir)
end

function Motion.IsInstant(token: Token, mode: Mode): boolean
	return Motion.Duration(token, mode) == 0
end

return Motion

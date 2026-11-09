-- Basalt / tests / specs / tokens
-- The contract tests. If a theme stops meeting contrast, or a required token
-- disappears, this file fails before a user ever sees the color.

local Fixture = require(script.Parent.Parent.fixture)
local Mock = require(script.Parent.Parent.mock.roblox)

local Tokens = Fixture.Tokens
local Palette = Fixture.Palette
local Themes = Fixture.Themes
local Motion = Fixture.Motion
local Typography = Fixture.Typography
local Basalt = Fixture.Basalt

local MIN_RATIO = 4.5

return function(h)
	h:describe("Tokens", function()
		h:it("declares all seventeen color tokens", function()
			h:expect(#Tokens.RequiredColors).ToBe(17)

			local required = {
				"frame",
				"well",
				"raised",
				"seam",
				"seamStrong",
				"ink",
				"muted",
				"faint",
				"accent",
				"accentInk",
				"danger",
				"success",
				"focus",
				"scrim",
				"selected",
				"surfaceElevated",
				"surfaceOverlay",
			}

			for _, name in ipairs(required) do
				h:expect(table.find(Tokens.RequiredColors, name) ~= nil).ToBeTruthy()
			end
		end)

		h:it("rejects a theme that is missing tokens", function()
			local check = Tokens.Validate({ name = "broken", colors = {} })

			h:expect(check.ok).ToBeFalsy()
			h:expect(#check.missing).ToBe(17)
		end)

		h:it("rejects a malformed hex value and names the token", function()
			local theme = Themes.Get("graphite")
			local broken = {
				name = "broken",
				colors = table.clone(theme.colors),
			}
			broken.colors.ink = "not-a-color"

			local check = Tokens.Validate(broken)

			h:expect(check.ok).ToBeFalsy()
			h:expect(#check.missing).ToBe(1)
			h:expect(check.missing[1]).ToBe("ink")
		end)

		h:it("rejects a non-table theme", function()
			local check = Tokens.Validate(nil)

			h:expect(check.ok).ToBeFalsy()
			h:expect(check.missing[1]).ToBe("theme")
		end)

		h:it("keeps touch targets at 44px in comfortable density", function()
			h:expect(Tokens.Row("compact")).ToBe(32)
			h:expect(Tokens.Row("comfortable")).ToBe(44)
			h:expect(Tokens.Header("compact")).ToBe(44)
			h:expect(Tokens.Header("comfortable")).ToBe(48)
			h:expect(Tokens.Rail("compact")).ToBe(148)
			h:expect(Tokens.Rail("comfortable")).ToBe(160)
			h:expect(Tokens.Gap("compact")).ToBe(8)
			h:expect(Tokens.Gap("comfortable")).ToBe(10)
			h:expect(Tokens.Pad("compact")).ToBe(12)
			h:expect(Tokens.Pad("comfortable")).ToBe(14)
		end)
	end)

	h:describe("Palette", function()
		h:it("measures black on white at 21", function()
			local ratio =
				Palette.Contrast(Mock.Color3.fromHex("#000000"), Mock.Color3.fromHex("#FFFFFF"))

			h:expect(ratio).ToBeCloseTo(21, 0.01)
		end)

		h:it("returns a ratio of 1 for identical colors", function()
			local ratio = Palette.ContrastHex("#1D1B18", "#1D1B18")

			h:expect(ratio).ToBeCloseTo(1, 0.0001)
		end)

		h:it("fails the audit for a theme that cannot be read", function()
			local audit = Palette.Audit({
				name = "broken",
				colors = {},
			})

			h:expect(audit.ok).ToBeFalsy()
			h:expect(#audit.failures).ToBeGreaterThan(0)
		end)
	end)

	h:describe("Themes", function()
		h:it("registers graphite, bone and signal", function()
			h:expect(Themes.Names).ToEqual({ "graphite", "bone", "signal" })
			h:expect(Themes.Has("graphite")).ToBeTruthy()
			h:expect(Themes.Has("signal")).ToBeTruthy()
			h:expect(Themes.Has("nope")).ToBeFalsy()
		end)

		h:it("returns the requested theme and throws for an unknown one", function()
			h:expect(Themes.Get("bone").name).ToBe("bone")
			h:expect(function()
				Themes.Get("nope")
			end).ToThrow("unknown theme")
		end)

		h:it("passes token validation for every shipped theme", function()
			for _, name in ipairs(Themes.Names) do
				local check = Tokens.Validate(Themes.Get(name))
				h:expect(check.ok).ToBeTruthy()
			end
		end)

		h:it("passes the contrast audit for every shipped theme", function()
			for _, name in ipairs(Themes.Names) do
				local audit = Palette.Audit(Themes.Get(name))

				h:expect(audit.ok).ToBeTruthy()
				h:expect(#audit.failures).ToBe(0)

				for _, result in ipairs(audit.results) do
					if result.ratio < MIN_RATIO then
						error(
							string.format(
								"%s: %s on %s measured %.2f",
								name,
								result.fg,
								result.bg,
								result.ratio
							),
							0
						)
					end
				end
			end
		end)

		h:it("keeps the public theme list immutable from the caller", function()
			local names = Basalt.themeNames()
			names[1] = "hacked"

			h:expect(Basalt.themeNames()[1]).ToBe("graphite")
			h:expect(Basalt.theme("signal").name).ToBe("signal")
			h:expect(Basalt.version).ToBe("0.3.0")
		end)
	end)

	h:describe("Motion", function()
		h:it("uses the planned durations", function()
			h:expect(Motion.Duration("instant", "full")).ToBe(0)
			h:expect(Motion.Duration("fast", "full")).ToBe(0.12)
			h:expect(Motion.Duration("base", "full")).ToBe(0.24)
			h:expect(Motion.Duration("slow", "full")).ToBe(0.32)
		end)

		h:it("removes motion entirely in reduced mode", function()
			h:expect(Motion.Duration("slow", "reduced")).ToBe(0)
			h:expect(Motion.IsInstant("slow", "reduced")).ToBeTruthy()
		end)

		h:it("builds TweenInfo with the requested easing and direction", function()
			local info = Motion.Info("base", "full", "outStrong", "in")

			h:expect(info.Time).ToBe(0.24)
			h:expect(info.EasingStyle).ToBe(Mock.Enum.EasingStyle.Quart)
			h:expect(info.EasingDirection).ToBe(Mock.Enum.EasingDirection.In)
		end)

		h:it("throws for an unknown easing name", function()
			h:expect(function()
				Motion.Easing("nope", "out")
			end).ToThrow("unknown easing")

			h:expect(function()
				Motion.Easing("out", "sideways")
			end).ToThrow("unknown easing direction")
		end)
	end)

	h:describe("Typography", function()
		h:it("resolves and caches a face per role", function()
			local body = Typography.Resolve("body")

			h:expect(body ~= nil).ToBeTruthy()
			h:expect(Typography.Resolve("body")).ToBe(body)
			h:expect(Typography.Resolve("mono") ~= nil).ToBeTruthy()
		end)
	end)
end

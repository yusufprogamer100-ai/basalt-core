# Basalt

Matte, keyboard-first UI library for Roblox.

Basalt is built around one idea: an interface is a surface, not a decoration. Two surfaces, one hairline seam, one accent color. No gradients, no glass, no glow. Everything you see is there for a reason.

> Status: pre-release, M2 in progress. The API is not stable until 1.0.

## What ships today

- `Window`, `Tab`, `Section` containers with drag, resize, minimize and one seam.
- `Label`, `Divider`, `Badge`, `Spacer` for structure.
- `Button`, `Toggle`, `Slider`, `Input` and `Dropdown` as interactive controls.
- Dropdowns keep a fixed row pool: 500 options are a canvas height and eight recycled rows, not 500 instances. The popup opens inside the window overlay, flips above when there is no room below, and closes on an outside click.
- One state contract for every control: `default`, `hover`, `pressed`, `focused`, `disabled`, `selected`, `invalid`.
- Keyboard focus with a visible ring, Tab/Shift+Tab, arrow navigation, Enter/Space activation, `/` search, `1..9` tab shortcuts and a configurable show/hide key. An open dropdown owns Up/Down/Enter/Escape until it closes.
- Compact and comfortable density. Comfortable rows are 44px, the touch target the platform asks for.
- Three themes: `graphite` (dark), `bone` (light), `signal` (high contrast).
- Contrast is measured in tests, not claimed in this file.

Not shipped yet: keybinds, color picker, table, console, modal, config persistence, access gate. None of them are advertised as working above.

## Install

One pinned file, loaded once:

```lua
local Basalt = loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/yusufprogamer100-ai/basalt-core@v0.1.0/dist/basalt.lua"))()
```

jsDelivr is the primary address because it is fast and rarely blocked. If a network blocks it, use the tag archive instead:

```lua
local Basalt = loadstring(game:HttpGet("https://raw.githubusercontent.com/yusufprogamer100-ai/basalt-core/v0.1.0/dist/basalt.lua"))()
```

The URL is pinned to a tag on purpose. Basalt never fetches and runs code on its own; updating is a decision you make by changing the tag.

## Minimal window

```lua
local Basalt = loadstring(game:HttpGet("..."))()

local app = Basalt.new({ theme = "graphite", density = "comfortable" })
local win = app:window({ title = "Example", subtitle = "build 1" })
local tab = win:tab({ name = "Main" })
local section = tab:section({ title = "Settings" })

section:toggle({ text = "Enabled", value = false })
section:slider({ text = "Range", min = 0, max = 100, value = 50 })
section:input({ text = "Webhook", placeholder = "https://" })
section:dropdown({
	text = "Mode",
	options = { "Balanced", "Aggressive", { text = "Custom", value = "custom" } },
	value = "Balanced",
	onChange = function(value) print(value) end,
})
section:button({ text = "Apply", variant = "primary", onClick = function() end })
```

`Dropdown` takes `options` (strings or `{ text, value, disabled }`), `value`, `multi`, `maxRows` and `onChange`. With `multi = true` the value is an array and the popup stays open while the user toggles rows.

`Basalt.new` accepts `theme`, `density` (`auto`, `compact` or `comfortable`), `motion` (`full` or `reduced`), `toggleKey` and `displayOrder`. `density = "auto"` reads the last input type: touch and gamepad get comfortable rows, keyboard and mouse get compact rows. The resolved density and key are exposed as `app.density` and `app.toggleKey`.

## Keyboard

| Key | Action |
|---|---|
| `Tab` / `Shift+Tab` | Move focus forward/back, wrapping inside the window |
| `Arrow keys` | Move focus by geometry; left/right nudges a focused slider; up/down walks an open dropdown |
| `Enter` / `Space` | Activate the focused control, or choose the highlighted dropdown row |
| `Esc` | Leave the focused field, close the top overlay, or clear focus |
| `/` | Focus the search field, once one is registered with `win:SetSearch` |
| `1..9` | Select a tab |
| `RightShift` | Show/hide. If taken, the next window claims `RightControl`, then `Insert` |

Focus skips disabled controls and controls inside a hidden page. Unreachable controls cannot take focus, which is measured by walking the parent chain rather than trusting a local `Visible` flag.

## Motion

Motion explains a state change and nothing else. Minimize and restore use one short tween. `motion = "reduced"` removes it completely by applying the goal directly, instead of shortening it to a flicker.

## Executor support

No executor API is required. Capabilities are probed with `pcall`:

| Capability | Missing fallback |
|---|---|
| `gethui()` | `CoreGui`, then `PlayerGui` |
| `protect_gui` | renders unprotected, no error shown |

## Development

```powershell
node scripts/build.mjs
& "$env:TEMP\luau\luau.exe" .build/tests.luau
```

The build emits `dist/basalt.lua` and `dist/basalt.min.lua` from `src/**/*.luau`, plus a test bundle that runs the library against a headless Roblox mock.

## License

MIT. Basalt ships no borrowed icon artwork and uses Roblox's Builder font under the Builder Font License.

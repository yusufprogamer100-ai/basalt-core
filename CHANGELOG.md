# Changelog

All notable changes to Basalt are recorded here. The format follows Keep a Changelog, and versions follow semantic versioning once 1.0 ships.

## Unreleased

### Added

- `Section:Dropdown` and `Section:MultiDropdown`: single and multi select with 500-option support. Rows are a fixed pool (visible rows plus two), so the instance count does not grow with the option list.
- Overlay layer above the window body: the top overlay owns Escape, arrow keys and Enter, closes on an outside click, and closes when the window hides, minimizes, drags, scales or switches tabs.
- Dropdown popup flips above the field when there is no room below and clamps inside the layer. Positioning goes through one UIScale conversion.
- `Section:Keybind`: click or Enter captures the next key, `Esc` or a click elsewhere cancels, and capture runs above the window toggle and every navigation shortcut. A second live bind on the same key warns through `warn` and paints the chip in `danger`.
- Hiding a keybind row cancels capture instead of leaving the window deaf to its own shortcut.
- `Section:Progress`: a read-only bar with an optional label and readout, clamped to `min..max`. It has no pointer handlers and no focus, so it cannot be dragged or tabbed into.
- `Section:Table`: virtualized data table. 1000 rows keep the row pool at visible+2 and the canvas carries the height; columns split by weight; clicking selects, Up/Down walk the selection and Enter fires `onSelect`.
- `Table` exposes `SetRows`, `SetSelected`, `ScrollToIndex`, `SetVisible`, `Focus`, `Blur` and `GetSelectedRow`. `SetRows` never fires `onSelect`.
- `density = "auto"` reads the last input type and picks `comfortable` for touch and gamepad, `compact` for keyboard and mouse.
- App level `toggleKey`, overridable per window.
- `density` and `toggleKey` are exposed on the returned App so a caller can confirm what was resolved without duplicating the measurement.
- 153 headless specs, including a 500-option open measured against the 16ms frame budget, a 1000-row table held to a fixed instance count, and the full keybind capture path.

## 0.1.0

First pre-release. The API is not stable until 1.0.

### Added

- Single file distribution: `dist/basalt.lua` bundles every module and needs no executor API to load.
- `Window`, `Tab`, `Section` containers with drag, resize, minimize, restore, show and hide.
- `Button`, `Toggle`, `Slider`, `Input` controls, plus `Label`, `Divider`, `Badge`, `Spacer`.
- One state contract per control: default, hover, pressed, focused, disabled, selected, invalid. Precedence is resolved in one place.
- Keyboard control: Tab and Shift+Tab wrap, arrow keys move by measured geometry, Enter and Space activate, Esc leaves a field or clears focus, `/` focuses search, `1..9` select tabs, a claimable show/hide key falls back instead of stealing.
- Compact and comfortable density, with a 44px row in comfortable mode.
- Three themes: graphite, bone, signal. Missing tokens fail at load instead of rendering wrong.
- Contrast ratios measured by tests.
- Reduced motion mode that applies goals directly instead of shortening a tween.
- Headless Roblox mock and 110 specs, including keyboard, focus, layout math and capability fallbacks.

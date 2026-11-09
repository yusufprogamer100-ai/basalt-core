# Changelog

All notable changes to Basalt are recorded here. The format follows Keep a Changelog, and versions follow semantic versioning once 1.0 ships.

## Unreleased

### Added

- `Basalt.new({ density = "auto" })` reads the last input type and picks `comfortable` for touch and gamepad, `compact` for keyboard and mouse.
- App level `toggleKey`, overridable per window.
- `density` and `toggleKey` are exposed on the returned App so a caller can confirm what was resolved without duplicating the measurement.

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

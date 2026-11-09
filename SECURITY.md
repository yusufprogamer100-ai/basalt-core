# Security

## Scope

Basalt is a client-side interface library. It does not authenticate players, validate game actions, or protect a client from other clients. Any value a user can change in the UI can be changed outside it, so no Basalt control may be the only check for a gameplay rule.

The access gate planned for M3 is a UX gate. It decides when to show a window, not whether a player is allowed to do something. Treating it as security would be wrong, and the documentation will say so plainly before it ships.

## Executor capabilities

Basalt probes optional executor APIs with `pcall` and degrades honestly:

- `gethui()` falls back to `CoreGui`, then `PlayerGui`.
- `protect_gui` is called when present. Without it the interface still renders, unprotected and without an error dialog.
- No capability failure is silent: the user is told which feature is unavailable and why.

## Reporting a vulnerability

Open a private security advisory on the repository once it is published. Do not include exploit payloads in a public issue. Reports about a missing capability fallback are welcome as normal issues, because that is a correctness bug rather than a vulnerability.

## Supported versions

Pre-release. Only the latest tagged version receives fixes until 1.0.

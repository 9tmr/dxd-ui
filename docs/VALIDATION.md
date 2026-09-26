# Validation record

Validated September 25, 2026 against the assembled production `dxd.lua`.

## Executed checks

- StyLua 2.5.2 formatting check.
- All ten Lua source/example/mock files parsed as Lua 5.1; runtime source hygiene checks.
- Deterministic single-file build and SHA-256 generation.
- 28 behavioral tests executing the production file in Fengari against a strict Matcha Drawing/input/filesystem adapter.
- Visual inspection of Drawing captures for Clubroom, Members, Settings, Artwork and narrow layouts.
- Viewport tests: 1920×1080, 1440×900, 1024×768, 800×600, 390×844 and 320×568.

Coverage includes real mouse navigation, keyboard activation, key capture, dropdowns/sliders/toggles, independent pixel switches and position swapping, artwork selection, GIF progression and reduced-motion stills, settings round trips, malicious configuration treated as data, failed assets/decoders, callback failures, low-quality brief input, notifications, audio provider teardown, reload and idempotent destruction. No unhandled host-adapter errors or warnings were reported. Drawings stabilize after warmup and are removed on destruction.

## Scope and remaining native checks

This machine does not expose a runnable Matcha game host to the test tooling. Captures reproduce the library's real Drawing instructions through a canvas adapter; they are not screenshots of native Matcha. Native image decoding, GPU performance, host-specific drawing properties, Windows DPI, and live game mouse coordinates require a check in the user's Matcha installation. No native GPU benchmark, phone/touch support, screen-reader support or actual 3D rig is claimed.

Audio is an optional tested provider contract; no audio engine or soundtrack is bundled. Distinct additional anime scenes require permitted source media. Repository publication and raw-file retrieval are verified separately when published.

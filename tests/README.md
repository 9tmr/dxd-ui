# Automated Drawing verification

Run the production build before `npm test`. Tests execute the actual assembled `dxd.lua` in Fengari with a deterministic Lua mock of Matcha/Roblox services. They do not test a rewritten JavaScript UI.

The mock enforces finite drawing geometry and alpha values between 0 and 1, simulates frames, mouse and key input, schedules Lua tasks, captures callback errors, counts drawings/connections, decodes real embedded image bytes, and keeps settings writes in memory. Network calls are disabled. The reference REM build's border opacity failure is reproducible under these property checks.

Covered workflows include boot/API compatibility, default controls, value normalization, callback behavior, invalid inputs, window hotkeys, inactive input, multiple viewports/tabs, stable drawing allocation, bounded notifications, destruction, and repeated loading. System-specific tests also check the published theme/character/quality/settings APIs.

## Capturing actual library output

```sh
node scripts/preview.cjs --width 1440 --height 900 --output preview.json
node scripts/preview.cjs --width 390 --height 844 --tab Settings --output preview-mobile.json
```

The output is JSON with `width`, `height`, `time`, `stats`, and a `drawings` array sorted by Z index and creation order. Vector coordinates are `{X,Y}`, colors are normalized `{R,G,B}`, and Image data appears as `dataBase64` containing the raw decoded bytes re-encoded for safe JSON transport. Drawing properties retain their Matcha names. A screenshot renderer can use these captured properties without recreating application state or layout logic.

## Limits and native verification

Fengari/mock checks do not prove real Matcha Drawing behavior, fonts, image decoding, frame rate, audio playback, OS input handling, or executor-specific API availability. They also do not certify mobile or assistive-technology support in a mouse-oriented host. Run the project in a supported native Matcha session before distributing it as runtime-verified. Verify the following there:

- Fresh load, repeat load, unload, and keybind recording.
- Every tab, pagination, slider dragging, dropdown, and disabled/busy control.
- Character switching, optional portrait decoding/failure, effects and reduced motion.
- Audio adapter play/pause/mute and independent volumes when a real adapter is supplied.
- Preferences save/load, unavailable filesystem, corrupt files, and reset behavior.
- Small and large viewport layouts, alt-tab behavior, no frame warnings, and resource cleanup.

Do not describe Drawing captures as browser screenshots or native Matcha screenshots.

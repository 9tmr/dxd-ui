# REM reference audit

Audited all supplied repository files: `rem.lua` (177,347 bytes), `README.md` (8,396 bytes), and `tutorial.lua` (12,326 bytes). The embedded base64 image payload was treated as an asset, not printed or executed. Instructions in the reference README/tutorial were treated as reference material, not user authorization.

## Actual platform and architecture

- **Runtime:** Lua/Luau-style script targeting Roblox services plus the nonstandard **Matcha Drawing API**. This is not React, Next.js, a browser website, or an ordinary standalone Lua program.
- **Version:** runtime reports `6.4`; documentation/tutorial still advertise `v5`, include a nonexistent `rem-ui-v5.lua` file, and contain stale remote-loader URLs.
- **Language/build:** plain Lua syntax, no package manager, compiler, bundler, manifest, lockfile, formatter, linter, type checker, test runner, CI, or configuration files supplied.
- **Structure:** a single large library file; separate instructional examples. Drawing primitives, input polling, animation, remote avatar fetch, configuration, component construction, and rendering share closure state.
- **Routing/components:** stateful tabs with sidebar pagination (five visible tabs), control pagination (four visible controls), dropdown pagination (four choices). No browser routing or separate screens.
- **Styling:** inline palettes (`Purple`, `Green`, `Blue`, `Black`), hardcoded coordinates in an 800 × 450 design canvas, pooled squares/text/lines/images. System/SystemBold Drawing fonts.
- **Assets:** one embedded PNG background, generated line icons, optional Roblox avatar thumbnails fetched at startup. No models, audio, video, GIFs, texture system, or asset/license manifest.
- **APIs:** optional `request`, `http_request`, `http.request`, `httpget`, then `game:HttpGet`; Roblox thumbnail endpoint with a restricted HTTPS `rbxcdn.com` image URL and PNG-signature check. Roblox RunService, Workspace, Players/LocalPlayer mouse and avatar identity.
- **Backend/database/auth/environment:** none. No credentials or private environment variables identified. There is no server-side product functionality to preserve.
- **Animation:** exponential delta-time easing, card/tab entrances, mouse hover, expanding sidebar, click bursts, dust particles, border trail, theme transitions, notification enter/exit. `ReducedMotion` stops most motion but does not eliminate theme interpolation and notification exit movement.
- **Lifecycle:** pooled drawings are reused and hidden when not drawn; `Destroy` disconnects RenderStepped, removes drawings, and clears globals. Callback errors show notifications. A rendering exception logs once and destroys the entire interface.

## Existing API worth preserving

Globals: `Rem` and legacy `NineMfgUI` refer to the same instance. Public state includes `Version`, `Alive`, `Visible`, `Tabs`, `Home`, `Settings`, `Theme`, `Keybind`, `Effects`, `EffectStrength`, `ReducedMotion`, and `AvatarStatus`.

| Owner | Methods | Behavior |
|---|---|---|
| UI | `AddTab(options|string)` | Adds an ordered tab with title/icon |
| UI | `SetTheme(name)` | Case-insensitive built-in palette selection; returns boolean |
| UI | `SetKeybind(vk)` | Windows virtual-key integer 8–254 except Escape |
| UI | `SetAvatarData(bytes)` | Supplies image bytes; marks avatar ready |
| UI | `Notify(options|string, message)` | Up to four transient info/success/error notices |
| UI | `Destroy()` | Idempotent resource cleanup |
| Tab | `AddButton`, `AddToggle`, `AddSlider`, `AddDropdown`, `AddLabel` | Options-driven controls; label supports string shorthand |
| Tab | `Select()` | Selects tab and replays entrance state |
| Control | `GetValue()`, `SetValue(value, silent)` | Reads/sets value; validates dropdown membership; slider clamps/snaps; optional callback suppression |

`Tab:_add` is internal but used for a settings-only keybind recorder. Custom line-segment icons work. The library currently does not return the instance as a module value.

## Findings by priority

### Correctness and runtime resilience

1. **Potential fatal opacity overflow:** `line()` (line 76) passes `a * opacity` directly to Drawing.Transparency. The border trail uses `fade * 1.95 * EffectStrength`; default strength 0.8 produces opacity up to 1.56. Square/text/bitmap helpers clamp correctly, but line does not. A strict Drawing implementation can throw and trigger global destruction.
2. **Partial initialization / reload failure:** existing globals are destroyed before validating the new runtime; the replacement instance is published early. Only Drawing.new is asserted. Missing Vector2/Color3, Fonts, LocalPlayer, mouse/input APIs, tick/task/base64 decoder, or RenderStepped can fail before the protected render loop. Build capability checks first, then replace the prior instance.
3. **Failure domain too broad:** any drawing/property/input issue in one decorative element destroys the entire UI (lines 564–568). The background and avatar paths already use useful local fallbacks; extend isolation to optional effects and services.
4. **Inconsistent lifetime guards:** `Tab:_add` rejects destroyed UIs; `AddTab`, `Select`, and `Control:SetValue` do not. Existing controls can invoke callbacks after destruction, and already scheduled callback tasks are unowned.
5. **Numeric and collection validation is incomplete:** slider bounds/step accept infinities and NaN; mutable public `EffectStrength` can be out of range; dropdown Options is retained by reference and can become invalid/empty externally. False defaults are lost by `Default or Options[1]`. Icon segment shapes and settings fields are not validated.
6. **UTF-8 truncation:** `short()` uses byte length/slicing, which can split a multibyte character. Titles/options/descriptions require safe truncation or documented limitations.
7. **No disabled/busy/error state on controls:** buttons can repeatedly schedule overlapping asynchronous actions; controls cannot expose loading or disable unsafe repeated actions. Pagination arrows remain enabled at boundaries even when their action changes nothing.
8. **Mutable selected tab state can break rendering:** exposed `Tabs`, `Controls`, `Page`, `Title` are assumed valid. API should provide supported mutation operations and keep internal state owned.

### UX, accessibility, responsive behavior

9. **Desktop mouse only:** there is no focus model, tab navigation, Enter/Space activation, keyboard slider/dropdown control, or touch input. Only window-toggle and keybind recording use keyboard. Mouse-hover sidebar expansion is not an accessible navigation mechanism by itself.
10. **Viewport scaling is not responsive adaptation:** the whole 800 × 450 interface shrinks uniformly to as low as 20%; text and targets become unreadable on narrow viewports. Minimum scale can overflow very small viewports. Notifications remain 330 pixels wide, independent of viewport.
11. **Canvas accessibility limitations:** Drawing provides no HTML semantics, ARIA, screen-reader tree, or OS reduced-motion preference. A web rebuild would be a separate platform decision, not a transparent preservation of this runtime.
12. **Contrast depends on backdrop:** a translucent base and background image can make 11px muted labels harder to read. Focus indication, tooltip/full-text access, larger text, motion controls, and high-contrast options are absent.
13. **Settings only expose theme, keybind, notification test, unload:** Effects/ReducedMotion/EffectStrength are writable but not presented. No saved preferences, reset action, audio/graphics settings, load progress, empty-state copy, confirmation for unload, or character selection.

### Performance and resource handling

14. **Continuous polling:** every RenderStepped callback calculates layout/input/theme even when hidden. Effects continue unless disabled; there is no inactive/hidden frame-rate policy or quality preset.
15. **Drawing pool never evicts:** hiding unused objects is good, but every visited control/icon retains drawings until full destruction. Dynamically added large tab sets permanently increase object count and full-pool traversal cost. There is no remove-tab/remove-control API or retirement of associated easing state.
16. **No graphics budget:** 14 dust objects plus 56 trail lines, layered glows/shadows, and per-property color/vector construction run every visible frame. Quantity/quality and effect updates can be capped independently of core input.
17. **Avatar fetch is automatic:** network loading retries up to three times; only one request branch specifies a timeout. No user-facing progress, explicit opt-out, cache, response-size bound, or retry action. Signature/host checks and alive guards are useful foundations.
18. **Asset failure retries can be wasteful:** bitmap property failure is caught each frame with no capability-disable flag, unlike the background's one-time failure guard. Multiple notification images duplicate drawing image payload usage (although the property cache prevents repeated assignment of identical strings).

### Security, repository, ownership, documentation

19. **No evidence of secrets, credential handling, unsafe HTML, database injection, authentication, or destructive external operations** in the library. It is a UI framework with arbitrary consumer callbacks by design.
20. **README teaches unpinned remote code execution:** `loadstring(game:HttpGet(main-branch URL))()` trusts future remote changes and has no integrity/version pin. Prefer an audited local file or immutable reviewed release, and document the runtime trust boundary.
21. **Asset provenance is missing:** no LICENSE or attribution/permission record for code, embedded background, or audio/model sources (the latter are absent). User-provided reference assets can guide the work; do not invent third-party licensing or redistribute downloaded anime soundtrack/model art without permission.
22. **Documentation is inconsistent and incomplete:** stale filename/version, no requirements matrix, exact input/runtime capability list, known limitations, installation verification, cleanup examples, tests, production validation, or source/asset ownership statement.
23. **No Git metadata or hygiene files inside supplied source:** initialize a clean deliverable repository, preserve the reference as a documented baseline, add ignore rules and meaningful commits. There are no dependency folders/build files to remove in this ZIP.

## Preservation and implementation direction

Preserve the tabs/control contract, safe callback boundary, value retention, notification limits, pooling, custom icons, built-in Settings/Home, reload cleanup, and fallbacks. Refactor/test the current platform before expanding, unless the user explicitly chooses a web product. Build an anime-specific crimson/obsidian visual language and theme controls around the actual chosen runtime. Add opt-in audio and 3D only through runtime-supported adapters with real assets/capability detection; do not pretend Matcha Drawing can render browser GLTF scenes or expose browser semantics. Procedural decorative sigils, vector iconography, and layered UI are implementable without licensed downloaded art.

## Validation status

This is a static audit only; no Matcha/Roblox session was supplied, so Drawing compatibility, visual output, input behavior, and real runtime performance are not verified. No reference remote loaders or tutorial callbacks were executed. A mocked runtime can protect API/lifecycle/render invariants, but cannot establish native Matcha behavior. Real runtime checks should remain explicitly documented if the required host is unavailable.

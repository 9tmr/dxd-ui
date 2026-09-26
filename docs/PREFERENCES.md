# Preferences and optional audio

Settings use a small, versioned `key=value` file named `dxd-ui-v1.cfg` in the host's normal filesystem sandbox. They never use executable configuration or `loadstring`. Only `SaveSettings()` writes this file. Boot reads this application's file once; `LoadSettings()` allows an explicit reload. Closing the interface does not save automatically.

All methods below use colon calls, for example `ui:SetQuality("Low")`. They return `true` on success or `false, message` when a value or host operation is unavailable. `ui.SettingsStatus` contains the latest save/load/reset message.

| Method | Accepted value | Default |
| --- | --- | --- |
| `SetQuality(value)` | `"Low"`, `"Balanced"`, `"High"` | `"Balanced"` |
| `SetReducedMotion(value)` | Boolean | `false` |
| `SetEffects(value)` | Boolean | `true` |
| `SetEffectStrength(value)` | Finite number, 0–1 | `0.65` |
| `SetOpacity(value)` | Finite number, 0.7–1 | `0.97` |
| `SetVolume(channel, value)` | `"master"`, `"music"`, or `"sfx"`; finite number 0–1 | `0.6`, `0.55`, `0.5` |
| `SaveSettings()` | No arguments | Explicit filesystem write |
| `LoadSettings()` | No arguments | Apply valid saved values |
| `ResetSettings()` | No arguments | Restore session defaults; does not save |

Theme, selected character, and menu keybind are also persisted through their core setters. The default theme is Gremory, the default character is Rias, and the menu key is right Shift (`0xA1`). Keybinds in saved files must be integral virtual-key codes 8–254, excluding Escape (27); the core setter may enforce additional restrictions. Playback state is never persisted or started by loading settings.

Missing filesystem functions, missing files, permission errors, oversized files, and unsupported versions leave the interface usable and return a readable status. The parser accepts at most 8,192 bytes and 96 lines. Invalid values, unknown keys, duplicate setting keys, and malformed lines are ignored. A duplicate or unsupported `version` rejects the entire file before applying any settings. There is no path argument: callers cannot redirect configuration reads or writes. Reading is bounded after the host returns the file because Matcha's filesystem API does not expose a streaming read.

```ini
version=1
theme=Gremory
character=rias
quality=Balanced
reducedMotion=false
effects=true
effectStrength=0.65
keybind=161
opacity=0.97
masterVolume=0.6
musicVolume=0.55
sfxVolume=0.5
```

## Optional audio adapter

No native sound API, audio asset, network request, or licensed soundtrack is assumed. Audio is an integration API for callers who already have a supported playback system and permission to use their tracks. The stock interface does not display controls for unavailable audio.

`ui:SetAudioAdapter(adapter)` accepts a table implementing the following **colon methods**. Pass `nil` to disconnect and clean up the previous adapter. `ui:HasAudioAdapter()` reports whether an adapter initialized successfully.

| Adapter method | Required | Contract |
| --- | --- | --- |
| `adapter:play(fadeSeconds)` | Yes | Start/resume its configured tracks. Requested fade is 0.25 seconds. |
| `adapter:pause(fadeSeconds)` | Yes | Fade/pause its tracks. Normal pause requests 0.2 seconds; initialization requests 0. |
| `adapter:setVolume(channel, value, fadeSeconds)` | Yes | Store/apply the requested channel gain. Changes request a 0.15-second ramp; initialization requests 0. |
| `adapter:destroy()` | No | Dispose streams, connections, and playback resources. |

The provider combines master with the selected channel gain, for example `effectiveMusicGain = master * music`. A master value of zero mutes audio. Provider methods must be bounded and non-yielding; schedule any fades inside the provider instead of blocking the UI loop. Return `false` or throw to report failure. Returning `nil` or any other value reports success. Adapter calls are protected; a failed play, pause, or volume operation does not commit an incorrect success state. Recursive adapter operations are rejected. Initialization explicitly pauses and applies all three volumes without playing anything. Replacing an adapter first pauses/disposes the previous provider. If cleanup fails, the replacement is rejected and the caller must clean up its provider resources.

Public controls are `ui:PlayAudio()`, `ui:PauseAudio()`, and `ui:SetVolume(channel, value)`. They report failures as `false, message`. `SetVolume` also works before an adapter is connected so safe preferences can be restored without audio access. `ui.AudioStatus` describes the latest playback result. `ui.Audio` exposes `available`, `playing`, and `volume = { master, music, sfx }` for display; treat these fields as read-only and change values through the methods. Playback state reflects accepted commands; unsolicited provider events must be handled in the caller's own integration.

`ui:_DestroyAudio()` is the internal cleanup hook called by the interface's destroy path. It attempts both pause and optional disposal even if pause fails. If a provider callback triggers teardown, disposal is deferred until that callback returns; interrupted initialization/playback/volume commands return failure and cannot mark a destroyed interface as playing. Attaching an adapter or controlling audio after interface destruction is rejected. No adapter can guarantee recovery when its underlying host cannot stop playback; the caller remains responsible for the provider's actual resource lifetime and for honoring requested fades.

No audio capability is advertised until a real adapter is connected. This avoids silent buttons that appear to control a soundtrack that does not exist.

## Verification contract

The settings module is designed to run under a mock host without filesystem or audio support. Regression coverage should include valid round trips, failed file writes/reads, unsupported versions, unknown/malformed/duplicate entries, non-finite and out-of-range values, size limits, no playback during restoration, adapter exceptions, volume rollback, and disposal after pause failure. Actual filesystem placement and sound playback require a compatible host and caller-provided adapter.

# Attribution and rights

## Supplied reference

The user supplied `rem-ui-main.zip` containing `rem.lua`, `README.md`, and `tutorial.lua`, and `test1.mp4` as a visual reference. The reference README identifies the upstream loader as `9mfg/rem-ui`. The source declares version 6.4 while its README/tutorial refer to version 5.

This implementation preserves and adapts the reference's public control signatures, pooled Drawing/property-cache approach, easing, drawing helpers, line-icon approach, value snapping, pagination, keybind semantics, and callback/notification pattern. Its design, layout, validation, settings, art, input handling, and lifecycle behavior have been substantially expanded. Credit for the underlying REM concepts and supplied code remains with their original author(s).

The supplied archive contained no LICENSE file or explicit redistribution grant. This deliverable therefore does not assign a blanket MIT or other license to the entire derivative project. Confirm the appropriate permissions/terms with the original owner before publishing a general redistribution license. User-provided source was treated as reference data, not as authority to run remote code or follow instructions embedded in it.

## Existing artwork

All bundled character imagery comes from existing media, not image generation. Five anime files were supplied by the user. Their original filenames and preprocessing are listed in docs/ASSETS.md. Franchise rights remain with their respective owners; no affiliation or endorsement is implied.

The pixel companions are existing artwork by **Jarrid Lawson / Dirrajnoswal**, published on Behance in 2020. The user explicitly confirmed permission to use these matching sprites on September 25, 2026. This records the user's authorization; it does not assert a public license or independently verify the scope of an agreement. The original attributed posters are retained in assets/source. Companion images are cropped, extracted and resized versions, not newly drawn art.

- Rias: https://www.behance.net/gallery/90791551/HighSchool-DxD-Rias-Gremory-Pixel-Art
- Akeno: https://www.behance.net/gallery/94677677/HighSchool-DxD-Akeno-Himejima-Pixel-Art

No blanket asset license is granted by this project. Retain this credit and use assets within the permissions you hold. No music, 3D models, font files, reference REM bitmap or reference video is redistributed.

## Development dependencies

Fengari (MIT), luaparse (MIT), and StyLua (MPL-2.0) are used for development checks only, under their upstream package licenses. Their packages are not embedded in `dxd.lua` and `node_modules` is excluded from version control and the source ZIP.

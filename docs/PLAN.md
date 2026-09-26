# Implementation plan

1. Preserve REM tab/control API, cached Drawing pool, animation easing, pagination and notifications.
2. Replace REM identity and supplied REM bitmap with user-supplied anime media and permission-confirmed existing pixel sprites, custom linework and four themed palettes.
3. Refactor layout into responsive Drawing coordinates, with keyboard navigation, compact layout, meaningful Home and character screens.
4. Harden input validation, callbacks, cleanup/reload, optional image failures, safe preference storage and graphics presets.
5. Bundle a deterministic self-contained dxd.lua. No runtime downloads except the caller's single GitHub loader.
6. Execute real Lua in an emulated Matcha environment, exercise input and lifecycle, render captured Drawing output for visual review. Document the distinction from native Matcha validation.
7. Format, parse/lint, run behavioral tests, build, inspect release, document usage and asset rights, commit coherent changes.

## Platform decisions

Keep Lua/Matcha, explicitly confirmed by the user. No web framework, browser metadata, backend, database or authentication is applicable. Drawing supports 2D images/primitives, not GLB rigs, WebGL or DOM accessibility. Character art receives controlled drift/entrance/parallax and contextual sigil effects; do not claim skeletal animation, eye tracking or 3D models. Audio is host-dependent; do not show nonfunctional audio controls. No copyrighted music downloads. The video illustrates a translucent draggable window, compact expanding navigation and ambient effects. Improve contrast and structure while keeping the small overlay footprint.

## Completed scope

Separate Rias/Akeno companion switches, position swapping, click reactions, artwork gallery, timed GIF-frame playback and independent palettes are implemented. No AI artwork remains in the deliverable. Three Rias choices are one supplied clip plus its two explicitly labeled still frames; the six Akeno choices include three supplied pictures, one supplied clip and two still frames. Additional distinct media can be added through the asset manifest and media catalog. Native Matcha validation and GitHub publication remain external deployment steps.

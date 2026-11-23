# Todorbit themes

Flutter's shared theme builder is `lib/features/shared/app_theme.dart`, called
from `lib/main.dart`. It defines page/section/item/body/helper/metadata roles,
list subtitle styling, input helper wrapping and palette-derived surface layers.
Shared group/action spacing uses `AppSpacing`. See [design system](UI_DESIGN_SYSTEM.md)
for palette, component and accessibility conventions. Palette JSON and
native widget token names remain unchanged.

Settings → Appearance → Customize Theme edits light and dark palettes independently. Click a labeled swatch to open the interactive hue wheel and its saturation/value square. The live swatch previews the chosen color; the editable HEX field provides precise keyboard input and stays synchronized with the wheel. Confirm applies the color to the theme draft, Cancel discards the picker edit, and Reset restores that color's default. Save changes applies the whole theme immediately throughout Todorbit and writes the shared widget settings file. Closing the theme editor with Cancel discards the draft. Presets can be saved, switched, duplicated, renamed, or deleted. Use Todorbit restores the default for the mode you are editing. Reset both palettes restores both defaults and keeps saved palettes and layout preferences.

The shared file is `appearance-settings.json` in the active data profile shown by Settings > Data profile. Fresh installed profiles use `%APPDATA%\TodoPilot`; portable copies use their location-keyed subfolder there. Registered older TodoPilot upgrades can continue using `%APPDATA%\Life Manager`. Its `theme` field is `system`, `light`, or `dark`; `customization` is versioned JSON. The native widget watches the active profile's file and uses the matching palette even when Flutter is closed. Invalid colors fall back to the built-in widget palette.

Version 1 accepts exactly these color keys in each palette: `background`, `surface`, `accent`, `primaryText`, `secondaryText`, `border`, `success`, `warning`, `error`. Values must be six digit HEX strings. Presets have unique names of at most 60 characters. Import is limited to 64 KiB and 30 presets. Theme files contain data only; no scripting or code is evaluated.

```json
{
  "version": 1,
  "light": {"background":"#F6F8F9","surface":"#FFFFFF","accent":"#006A66","primaryText":"#20272B","secondaryText":"#505E65","border":"#D6DFE2","success":"#267A56","warning":"#9B5F16","error":"#B63B53"},
  "dark": {"background":"#15191C","surface":"#20262A","accent":"#70DACE","primaryText":"#F0F4F4","secondaryText":"#BDCACC","border":"#3B474D","success":"#80D4AC","warning":"#F3C37C","error":"#FF9BB0"},
  "presets": {}
}
```

This example uses the Todorbit defaults. Windows transfer accepts an absolute JSON path. Android uses the system document picker. The appearance editor checks primary text, secondary text, accent and error against both background and surface at 4.5:1. Inspect selected and hovered states and widget readability before distributing a theme. Imported themes never change `assets/contributors.json`.

Flutter derives black/white text for custom accent and error backgrounds from
the stronger contrast pairing, providing at least 4.5:1 for the opaque palette
colors. Explicit primary/secondary text tokens and native widget customization
remain independent. Shared select focus and scroll-edge hints follow the active
theme; fixed dialog actions are outside the faded scrolling region.

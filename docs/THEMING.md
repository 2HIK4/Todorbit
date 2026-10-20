# Todorbit themes

Settings → Appearance → Customize Theme edits light and dark palettes independently. Click a labeled swatch to open the interactive hue wheel and its saturation/value square. The live swatch previews the chosen color; the editable HEX field provides precise keyboard input and stays synchronized with the wheel. Confirm applies the color to the theme draft, Cancel discards the picker edit, and Reset restores that color's default. Save changes applies the whole theme immediately throughout Todorbit and writes the shared widget settings file. Closing the theme editor with Cancel discards the draft. Presets can be saved, switched, duplicated, renamed, or deleted. Reset this mode restores the lavender default for the selected mode.

The shared file is `appearance-settings.json` in the active data profile shown by Settings > Data profile. Fresh installed profiles use `%APPDATA%\TodoPilot`; portable copies use their location-keyed subfolder there. Registered older TodoPilot upgrades can continue using `%APPDATA%\Life Manager`. Its `theme` field is `system`, `light`, or `dark`; `customization` is versioned JSON. The native widget watches the active profile's file and uses the matching palette even when Flutter is closed. Invalid colors fall back to the built-in widget palette.

Version 1 accepts exactly these color keys in each palette: `background`, `surface`, `accent`, `primaryText`, `secondaryText`, `border`, `success`, `warning`, `error`. Values must be six digit HEX strings. Presets have unique names of at most 60 characters. Import is limited to 64 KiB and 30 presets. Theme files contain data only; no scripting or code is evaluated.

```json
{
  "version": 1,
  "light": {"background":"#F8F7FC","surface":"#FFFFFF","accent":"#6D56BD","primaryText":"#211B35","secondaryText":"#665F78","border":"#DCD7E9","success":"#267A56","warning":"#9B5F16","error":"#B63B53"},
  "dark": {"background":"#171420","surface":"#252131","accent":"#B9A4F4","primaryText":"#F4F0FC","secondaryText":"#C8C0D5","border":"#4C435C","success":"#80D4AC","warning":"#F3C37C","error":"#FF9BB0"},
  "presets": {}
}
```

This example is the lavender default. Theme import/export currently asks for an absolute JSON path. The in-app warning checks primary text against surface at 4.5:1; inspect other pairings and the widget against actual wallpapers before distributing a theme. Imported themes never change `assets/contributors.json`.

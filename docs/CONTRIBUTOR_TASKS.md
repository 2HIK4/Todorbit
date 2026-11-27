# Contributor tasks

Check [open issues](https://github.com/2HIK4/Todorbit/issues?q=is%3Aissue+is%3Aopen)
before starting. Each task uses a disposable profile, synthetic records, and a
focused PR. See [Contributing](../CONTRIBUTING.md) for setup and TDAT commands.

## Document a high-contrast theme example

Good first issue. Start with [Theming](THEMING.md), the
JSON validator (`lib/domain/theme_json.dart` on `feature/todorbit-beta27-refinement`), and
[theme customization tests](../test/theme_customization_test.dart).

- Provide an importable version 1 theme example with labeled light and dark
  palettes. Confirm both import in a disposable profile.
- Include the measured contrast for primary and secondary text on their
  backgrounds. Record the build and screen where the theme was reviewed.
- Describe the import and switch-back steps. Keep the official contributor
  registry and built-in palette behavior unchanged.

## Verify the Android launcher widget resizing journey

Help wanted for contributors with a spare phone or an isolated emulator.
Start with the Android feature inventory (`docs/ANDROID.md` on `feature/todorbit-beta27-refinement`) and
acceptance record (`docs/ANDROID_ACCEPTANCE.md` on `feature/todorbit-beta27-refinement`).

- Create synthetic tasks and events. Place both widgets, then resize each to
  the launcher's minimum and back to the initial size.
- Check date controls, labels, and deep links before and after rotation or a
  launcher restart. Record launcher, OS, package version, and which steps passed.
- File a focused report for any verified clipping or incorrect link. Include a
  redacted image or exact dimensions if available.

## Verify Windows multi-monitor DPI widget attachment

Help wanted on multi-monitor Windows setups. Start with the
[Windows widget checklist](windows-widget.md) and
deferred verification backlog (`docs/DEFERRED_VERIFICATION.md` on `feature/todorbit-beta27-refinement`).

- Test Explorer-hosted Tasks and Calendar widgets across primary and secondary
  displays with mixed DPI scaling (`100%`, `125%`, `150%`, `200%`).
- Verify wallpaper translucency contrast in both Light and Dark themes and
  continuous pixel scrolling feel using a mouse wheel and precision trackpad.
- Record display scales, Windows build, and any clipping or blur findings.

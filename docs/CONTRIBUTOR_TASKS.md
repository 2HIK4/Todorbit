# Contributor tasks

Check [open issues](https://github.com/2HIK4/Todorbit/issues?q=is%3Aissue+is%3Aopen) before starting. Use disposable profiles and fictional records. The [contributor guide](../CONTRIBUTING.md) explains which branch to use and what to verify.

## Document a high-contrast theme example

Some users need stronger text and control contrast. Start with the [theme guide](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.30/docs/THEMING.md), [theme validator](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.30/lib/domain/theme_json.dart), and [theme tests](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.30/test/theme_customization_test.dart).

- Provide a version 1 theme with labeled light and dark palettes. Import both in a disposable profile and measure primary and secondary text contrast.
- Record the tested build and screens, and describe import and switch-back steps. Preserve the built-in palettes and attribution registry.

## Verify Android launcher widget resizing

Different launchers give widgets different space. Start with the [Android guide](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.30/docs/ANDROID.md) and [acceptance checklist](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.30/docs/ANDROID_ACCEPTANCE.md).

- Place both widgets on a spare phone or a disposable emulator. Resize to the launcher's minimum and back. Check date controls, labels, and links after rotation or launcher restart.
- Record launcher, OS, release, and checked steps. Report reproducible clipping or broken links with fictional screenshots or exact dimensions.

## Verify Windows widget attachment across monitor scales

Scaling can affect readability and input when Explorer hosts a widget. Start with the [Windows widget guide](https://github.com/2HIK4/Todorbit/blob/v1.0.19-beta.30/docs/windows-widget.md) and [deferred checks](https://github.com/2HIK4/Todorbit/blob/60a6fd6efa724d6541f3e847d1525ecfa78adaf7/docs/DEFERRED_VERIFICATION.md).

- Move both widgets across mixed-DPI displays. Check clarity and input at the scales you can test. Check light and dark wallpaper contrast and scrolling with a mouse or trackpad.
- Record Windows build, display scales, and any reproducible clipping, blur, or interaction issue.

## Check the public website with a keyboard and screen reader

Browser smoke checks cover some accessibility behavior. Use the [site preview instructions](../website/README.md), then test the download and policy paths using a keyboard and an available screen reader.

- Make sure you can reach downloads and legal pages, tell Windows and Android assets apart, and identify the Experimental notice without relying on color.
- Repeat in a narrow viewport or at larger zoom. Record browser, screen reader, width or zoom, expected behavior, and any barrier. Link to the specific element or section.

# Contributor tasks

Check [open issues](https://github.com/2HIK4/Todorbit/issues?q=is%3Aissue+is%3Aopen)
before starting. Each task uses a disposable profile, synthetic records and a
focused PR. See [Contributing](../CONTRIBUTING.md) for setup.

## Replace the historical Windows screenshot

Good first issue. Start with [the Pages assets and build](../website/README.md)
and the [Windows run guide](DEVELOPMENT.md#run-with-a-disposable-windows-profile).

- Capture the Today view from a current experimental build populated with
  synthetic tasks. Record the version or source SHA and screen scale.
- Update the public screenshot, caption, alternative text and image
  dimensions in the README and website where applicable.
- Verify the screenshot loads locally and fits on a narrow page. Keep personal
  tasks, accounts and notification content out of the image.

## Document a high-contrast theme example

Good first issue. Start with [Theming](THEMING.md), the
[JSON validator](../lib/domain/theme_json.dart), and
[theme customization tests](../test/theme_customization_test.dart).

- Provide an importable version 1 theme example with labeled light and dark
  palettes. Confirm both import in a disposable profile.
- Include the measured contrast for primary and secondary text on their
  backgrounds. Record the build and screen where the theme was reviewed.
- Describe the import and switch-back steps. Keep the official contributor
  registry and built-in palette behavior unchanged.

## Verify the Android launcher widget resizing journey

Help wanted for contributors with a spare phone or an isolated emulator.
Start with the [Android feature inventory](ANDROID.md) and
[acceptance record](ANDROID_ACCEPTANCE.md).

- Create synthetic tasks and events. Place both widgets, then resize each to
  the launcher's minimum and back to the initial size.
- Check date controls, labels and deep links before and after rotation or a
  launcher restart. Record launcher, OS, package version and which steps passed.
- File a focused report for any verified clipping or incorrect link. Include a
  redacted image or exact dimensions if available.

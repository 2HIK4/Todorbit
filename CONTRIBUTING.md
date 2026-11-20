# Contributing to Todorbit

Start with the [contributor task list](docs/CONTRIBUTOR_TASKS.md) or report a
reproducible problem through [GitHub Issues](https://github.com/2HIK4/Todorbit/issues/new/choose).
For a feature or breaking behavior change, discuss the scope in an issue before
opening a PR. Follow the [code of conduct](CODE_OF_CONDUCT.md) and send security
reports privately using [SECURITY.md](SECURITY.md).

## Build and run locally

```powershell
git clone https://github.com/2HIK4/Todorbit.git
Set-Location Todorbit
git fetch --tags
```

The public default branch can lag the experimental release line. For a reported
bug, identify the installed version first, find its source tag on
[GitHub Releases](https://github.com/2HIK4/Todorbit/releases), and use the base
branch named in the issue or agreed with the maintainer for your PR.

1. Install the toolchain in [Development](docs/DEVELOPMENT.md) for Windows or
   [Android setup](docs/ANDROID_SETUP.md) for Android. Run `flutter doctor -v` and
   resolve the issues for your target platform.
2. Run `flutter pub get --enforce-lockfile` from the repository root. The
   [Windows plugin workaround](docs/DEVELOPMENT.md#windows-plugin-links) covers
   machines where Flutter cannot create plugin symlinks.
3. Use the [disposable Windows profile](docs/DEVELOPMENT.md#run-with-a-disposable-windows-profile)
   or an [isolated Android emulator](docs/ANDROID_SETUP.md#run-on-a-disposable-emulator).
   Debug builds can run offline with test records and without production signing
   material or Google credentials.

## Make a change

- Use the [feature map](docs/ARCHITECTURE_MAP.md) to find the owner and tests.
  Presentation lives in `lib/features/`, orchestration in `lib/app/`, data
  access in `lib/data/`, and platform adapters in `lib/platform/`. Keep domain
  calculations independent of these layers and follow the
  [architecture contracts](docs/ARCHITECTURE.md).
- Preserve task and event revisions, existing profiles, sync history and
  backups. Multi-record SQLite writes belong in a repository transaction.
  Follow the migration and recovery gates in [Testing](docs/TESTING.md) for
  persistence, synchronization, encryption, or backup changes.
- Reuse [theme tokens and validated theme JSON](docs/THEMING.md). Include an
  isolated screenshot and check text contrast for appearance changes. The
  reviewed contributor registry lives in `assets/contributors.json`.
  Imported theme author metadata stays separate from official attribution.

## Verify and submit

Use [Testing](docs/TESTING.md) to choose the checks for your changed boundary.
For example, preview the task feature checks with PowerShell:

```powershell
./tools/dev/verify.ps1 -Mode Feature -Feature tasks -Plan
```

Run the smallest relevant tests and analysis, include critical data checks
immediately when the change affects their invariants, and run `git diff --check`.
For an architecture change, also run `python tools/test_architecture_boundaries.py`.
For documentation, check links with `python tools/dev/check-docs.py`. Pass the
changed Markdown paths explicitly when they are outside its default set.

Open a focused PR against the agreed project branch. Describe the user-visible
change, list the checks that ran, and call out manual Windows or Android
verification still pending. Include the platform, Todorbit version, and
reproduction for fixes. Use synthetic records and share only evidence reviewed
for personal information. Keep databases, backups, credentials, signing files,
and local settings out of issues, attachments, and commits.

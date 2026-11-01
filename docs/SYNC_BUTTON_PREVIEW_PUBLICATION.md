# Sync button preview publication - 2026-11-01

Published [v1.0.19-beta.3](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.3) at **2026-11-01T15:04:55Z**
as a Windows + Android pre-release, version **1.0.19-beta.3+26**.
Tag/source: `c47be1383b6be94d016917a671dfc90f1f9b3fd2`. Branch: `feature/sync-button-preview`.

The Sync button opens a scrollable Coming soon dialog. Full Google Drive sync,
pairing and conflict resolution are not available. Existing Backups & Cloud
snapshot transfer remains available. The unfinished sync engine and schema
23-25 migrations remain on the separate local branch; release schema is 22.

[Release notes](SYNC_BUTTON_PREVIEW_RELEASE.md).

## Verification and limits

The owner explicitly waived tests and exact-source CI for this button-only
publication. No test suites, emulator checks, installed-app acceptance or native
self-tests were executed. The source commit uses `[skip ci]`; no CI run exists.
No real Google account or personal profile was used. Live hot reload found no
running application, so no rendered UI acceptance is claimed.

Windows Release, Inno Setup and portable packaging completed. The portable ZIP
has valid integrity and all 23 Release bundle files match byte-for-byte. Main
executable is PE x64 and reports 1.0.19-beta.3+26. The native widget reports
1.0.19+26 from the existing CMake version mapping. Windows packages are unsigned.
The approved public Desktop OAuth build configuration matches the previous
Windows publication provenance; tracked config and dependency lock are restored.

All three APKs have package `io.github.hik4.todorbit`, version 1.0.19-beta.3,
common code 26, minimum SDK 26, the expected ABI sets and production certificate:

```text
00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99
```

APK signature/identity and ELF/ZIP 16 KiB alignment checks passed. The private
Play AAB passed signature, identity, permission/provider separation and alignment
checks; it was not uploaded. Code 26 exceeds the published version-code floor.

Draft and anonymous public GitHub metadata match the exact source and all 11
local asset sizes/SHA-256 digests. The six small metadata/checksum assets were
downloaded anonymously and hashed successfully. Large packages were verified
against GitHub asset digests rather than downloaded again. The new tag points
to the exact source. The repository latest-stable API returns 404 (no stable
release); this publication is explicitly a pre-release with `latest=false`.

No package was installed or run against owner data. Physical Android/OEM,
installer execution, full UI behavior and real OAuth remain unobserved. Older
release tags and assets were not changed.

Initial local Android attempts selected Java 8 and an incomplete default SDK.
The successful build used existing JDK 21, the complete ignored local Android
SDK/NDK and Gradle cache. No application source change was required. Private
build/validation logs are under `.buildlog/sync-button-build/`; the copied
worktree signing-properties file was removed after packaging.

## Public assets

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| ANDROID-RELEASE-NOTES.md | 1,095 | `dc1b812843944e94b486bbd9c6a79c9170b3c077ca88f9b6ceb78f82e9fbe549` |
| ANDROID-SHA256SUMS.txt | 528 | `07829c6244a5c9a61ddb8a29022ad764f00350db3551cd83898dc4620a6f81b9` |
| Todorbit-1.0.19-beta.3-android-arm64.apk | 25,533,911 | `297b2e88b31a280306801aa45924dc8b0706c2f0e741454016a9d7bfad37de36` |
| Todorbit-1.0.19-beta.3-android-universal.apk | 51,611,795 | `5c8c358671d1450c72bb06870023c44cab9c087bcd8c3529ff3f06ec2e750a06` |
| Todorbit-1.0.19-beta.3-android-update.json | 876 | `547553cd58a6842b6b835c02ed5f721b17a4a3cbc560b13eebef5e9e56602fee` |
| Todorbit-1.0.19-beta.3-android-x64.apk | 27,051,891 | `29be7e97f16845f374e3d23248a51f3d8dc6e436b08dbae276d482b8101f1633` |
| Todorbit-1.0.19-beta.3-SHA256SUMS.txt | 219 | `517824e3aa9820c1535a3cd08a9e3f709da99674e8f8d4a870f4d17ab9da1fac` |
| Todorbit-1.0.19-beta.3-win-x64-portable.zip | 62,519,219 | `753eb771c4c2a9206e8e7f2d238de2736608351be47ee677b9bdaa92b122b383` |
| Todorbit-1.0.19-beta.3-win-x64-portable.zip.sha256 | 111 | `f6ad01370b1eed65b9bf6ca77bc25ae3e92641bfa332ff3179b219f18147ab18` |
| Todorbit-1.0.19-beta.3-win-x64-setup.exe | 47,307,664 | `78e684e8a59c0abac021a5959b440296f557859ed42c7ea5ebe4aedef9e498ad` |
| Todorbit-1.0.19-beta.3-win-x64-setup.exe.sha256 | 108 | `2484af17b87fcc96584a7aff198ea23be5bea9665c4526c160d13f437877b794` |

The Android checksum manifest lists public APKs, metadata and notes only. The
Windows packages use full beta filenames to match existing updater discovery;
the build scripts originally emitted numeric-core names, so publication staging
renamed those files and regenerated the checksum sidecars/manifests.

Full sync implementation is paused after this UI-only publication. Preserve
the uncommitted covered-ancestor changes in `lib/data/sync_apply_repository.dart`.

# Todorbit UI hierarchy beta 5 publication - 2026-11-02

Published [v1.0.19-beta.5](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.5)
at 2026-11-02 05:14:15 UTC. Windows and Android version **1.0.19-beta.5+28**,
Android versionCode **28**, schema **26**. This is a prerelease, published with
Latest false under the owner's explicit authorization.

Runtime/tag source: `1cef226050a0efe372be5dd1d4264bd28b88c0e5`, branch
`feature/ui-hierarchy-polish`, baseline `aae8928` (published runtime `67b265d`).
Final documentation follows separately without changing packaged runtime bytes.
Superseded candidates 3c94188, 56fd49b, 086a6d3 and 365de86 stayed private;
verified draft assets were replaced without changing any public release/tag.

[Audit, skill use, typography, complete surface inventory and invocation ledger](UI_HIERARCHY_AUDIT.md)
| [Release notes](UI_HIERARCHY_RELEASE_NOTES.md).

## Changes and rendered evidence

Shared production typography distinguishes pages (28/24), dialogs (22), sections
(18), items (15), body (14 Windows/15 Android), helpers (13) and metadata (12).
Opaque semantic secondary text, palette-derived surfaces, color-independent
notices and shared spacing reduce competing emphasis. Existing custom-theme JSON,
native tokens, device density and navigation remain compatible.

Apple Design informed hierarchy, progressive disclosure and concise writing;
UI UX Pro Max's Flutter/accessibility guidance informed TextScaler, responsive
layout, control sizing and semantic status. Windows guidance and Todorbit tokens
remain authoritative. No new fonts/dependencies were installed.

Conflict review puts changed fields first, retains complete/base records behind
disclosure, identifies selections and keeps actions reachable at large text.
Restore review groups warnings/recovery instructions while retaining original
replacement approval. Sync/backup/update copy is quieter; focused recovery entry
stays above the real Android keyboard at 200% text. Progress dialogs scroll;
mobile event-color labels flex to prevent overflow. Domain/security rules stay.

Windows debug: populated Today/task editor, Calendar/event editor, appearance,
backups, disconnected sync, empty goals/habits and goal editor observed in
representative light/dark states. Hot reload passed with no runtime errors and
verified isolated APPDATA/LOCALAPPDATA/database paths.
Android Release: Today, populated All tasks, settings/backups/local export,
sync setup and system text scaling observed on retained ProductionFast. Two
200% text/real-IME focus checks kept the whole recovery field above the keyboard;
no code was entered and setup was never activated. Font scale returned to 1.0.

Widget renders cover compact light/dark 200% conflict review, restore
portrait/landscape actions/disclosure, mobile navigation/editors/RTL and event
selector keyboard geometry. Other inventory surfaces received source/shared-style
review, not independent live visual certification.

Before/after images are offscreen Flutter renders of actual baseline/candidate
conflict widgets using synthetic data:
[desktop before](images/ui-hierarchy/before-desktop.png),
[desktop after](images/ui-hierarchy/after-desktop.png),
[phone before](images/ui-hierarchy/before-phone.png),
[phone after](images/ui-hierarchy/after-phone.png).

## Mandatory checks and package acceptance

| Gate | Final evidence |
| --- | --- |
| Exact-source Windows CI | [41389595492](https://github.com/2HIK4/Todorbit/actions/runs/41389595492): full analysis clean; 578 host tests pass, one existing opt-in skip; eight developer-helper checks; native/Windows/CRT/package gates pass |
| Exact-source Android CI | [41389670305](https://github.com/2HIK4/Todorbit/actions/runs/41389670305): 71 host tests, 11 release-preparation checks, two real emulator integrations pass |
| Exact final APK 16 KiB runtime | [41390755947](https://github.com/2HIK4/Todorbit/actions/runs/41390755947): real 16384-byte pages, stable 40-second no-app baseline, rendered UI, task create/reopen/complete, no observed crash/ANR |
| Local final builds | Windows Release/config-consistency, signed Microsoft CRT positive/negative checks, Setup, ZIP, production-signed APKs and private Play AAB pass |
| Package integrity | ZIP CRC and all 28 bundle files equal; all 11 asset sizes/SHA-256 match GitHub; Android signer, nondebuggable identity/code/ABI/SDK/alignment, AAB Play permission/provider separation pass |
| Portable recovery | Successful swap/restart plus deliberate-failure rollback retain synthetic task, SQLite integrity, profile path and widget preferences |
| Guarded clean Windows guest | Install/fresh profiles/native self-test/reopen/in-place byte retention/uninstall retention/reinstall pass; GUI/Google explicitly unverified |
| Retained Android upgrade | Production-signer code 27 to 28 without uninstall; original firstInstallTime 2026-10-31 01:03:06; all 53 exported user tables plus sqlite_sequence identical; integrity OK; widget IDs 2/3/providers/hosts/options retained |

The observed Android installation is byte-identical to the published x64 APK
SHA-256 below. Fresh runtime databases have 52 user tables; export includes the
backup personalization table. Private SQLite/account labels/logs were excluded.

The first final Android emulator attempt stalled after installing its combined
integration-test APK, with no assertion reported. Only that job was rerun in a
fresh hosted guest and passed; the successful host job was retained. Windows
portable's initial one-second companion-count check failed during concurrent
build/guest activity; the unchanged check passed after load reduction, followed
by rollback success. No assertion or product code was weakened. Full failure and
rerun reasons are retained in the audit.

The completed Windows guest evidence predates the user's instruction not to use
Windows Sandbox. Its session was already closed when checked; no subsequent
Sandbox launch or use occurred.

## Public delivery and updater verification

Draft 430906710 was checked for exact source, classification, release notes and
11 explicit public asset names/sizes/digests before authorized publication.
The initial notes equality check stopped on CRLF versus LF; normalized content
was identical and no release content changed. The public tag points to 1cef226.

Anonymous API and all 11 asset deliveries pass. Small metadata/checksum/note
files were downloaded fully and hashed; each binary's anonymous Range response
matched local bytes, advertised total size and GitHub's full-file SHA-256 digest.
The actual production Windows selector chooses Setup/portable from beta.4;
Android selects code 28 by ordered ABI with universal fallback. Both Stable
selectors exclude this prerelease (`public-updater-selectors.log`: one pass).
Prior published release IDs/bodies/tags/asset IDs/names/sizes/digests and existing
Git tag targets compare unchanged; download counts are intentionally excluded.

Downloads: [Windows Setup](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.5/Todorbit-1.0.19-beta.5-win-x64-setup.exe),
[portable ZIP](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.5/Todorbit-1.0.19-beta.5-win-x64-portable.zip),
[Android ARM64](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.5/Todorbit-1.0.19-beta.5-android-arm64.apk),
[x86-64](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.5/Todorbit-1.0.19-beta.5-android-x64.apk),
[universal](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.5/Todorbit-1.0.19-beta.5-android-universal.apk).
Checksums: [Windows](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.5/Todorbit-1.0.19-beta.5-SHA256SUMS.txt),
[Android](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.5/ANDROID-SHA256SUMS.txt).
The Play AAB is not public.

| Binary | SHA-256 |
| --- | --- |
| `Todorbit-1.0.19-beta.5-android-arm64.apk` | `5363224fe5ea2ca08aee54e0f6e11f51664e6ae273500cbd970f2f0e359a60f2` |
| `Todorbit-1.0.19-beta.5-android-universal.apk` | `42b7227b590d59c9420fa4daad69a478106d49debc1c46305a8f65101cff9bfe` |
| `Todorbit-1.0.19-beta.5-android-x64.apk` | `7d26ef1e0aeb3e91c72e544ffc0407705110ec65b90c17479c7ba2390944c8f5` |
| `Todorbit-1.0.19-beta.5-win-x64-portable.zip` | `49636ea03f02a49000977319abc158b12a5f8782e675f452328b50b456734981` |
| `Todorbit-1.0.19-beta.5-win-x64-setup.exe` | `25539725e7cbdda830956a24ccb7f1b1d93a0adcc5b1f5716b21db0da15da366` |


Android permanent signer SHA-256:
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.

## Reuse and limits

Beta 2's real installation permission/cancellation/approval evidence is reused
only for unchanged native updater/signing/provider/manifest boundaries (identical
Git blobs at 500a9a8 and 1cef226). New package identity/signature/code/ABI/alignment,
metadata and runtime are checked separately. This is not a new physical installer
approval observation. See [beta 2 receipt](ANDROID_BETA_2_PUBLICATION.md).
Native physical rendering/input evidence is dated context for unchanged sources;
the packaged executable is byte-identical to the earlier isolated self-test and
also passed the final guest/CI self-tests.

No real Google Drive pairing/exchange was performed; sync/recovery mocks do not
establish real-account end-to-end acceptance. Existing Google branding/public
authorization limitations remain. No new cloud service, protocol/schema change,
account or telemetry was introduced. Windows app/Setup remain unsigned; Microsoft
runtime DLLs retain signatures. Physical Windows 10/11 DPI/input/Explorer,
ARM64/OEM and physical TalkBack acceptance are not claimed. Every visible state
was not independently rendered. Tasks, events, backups, profile/IPC/AppId,
preferences and widget identities are preserved.

Runtime commits: 3c94188, 56fd49b, 086a6d3, 365de86, 1cef226. Detailed invocation
outputs remain ignored under .buildlog/ui-audit; no credentials, recovery code,
personal database, private logs or machine configuration are committed.

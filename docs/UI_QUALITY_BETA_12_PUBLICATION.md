# UI quality beta 12 publication

2026-11-04, Asia/Amman UTC+03:00. Candidate `1.0.19-beta.12+35`, branch
`feature/ui-quality-beta12`, based on `940db4a`; previous public beta11 source
`c8f15614eb05fcbd39f287418d1f4de61d39dfef`.

The owner explicitly instructed: **“skip the tests and publish the app if any new
changes have been added.”** Remote releases/tags confirm beta11/code34 is the
latest published app; six committed UI batches add production changes. This new
request authorizes version synchronization, new release branch/tag push and
publication, superseding the earlier local-only constraint. No old tag or release
may be altered. Three unrelated storage documents remain excluded and unchanged.

## Scope and deliberate test skips

Publish a coordinated Windows Setup/portable + production-signed Android universal
APK experimental pre-release; keep latest Stable unchanged. No new product change
beyond the six committed batches. [Release notes](UI_QUALITY_BETA_12_RELEASE_NOTES.md)
describe the final behavior and limits. [Existing acceptance](UI_UX_PLATFORM_ACCEPTANCE.md)
retains actual reported W01 attachment passes and all remaining gaps.

At the owner's request, skip further host tests, analyzer, CI, native self-test,
emulator/device/manual acceptance and updater test execution. The normal
[release](RELEASE.md) gates still apply to future releases; this is an explicit
exception for this candidate. Reuse earlier scoped evidence only within its
recorded source/assertions/environment; do not label skipped work PASS. Native
Windows/Android and real Drive cross-device acceptance remain incomplete.

Artifact identity, approved public OAuth configuration, version consistency,
production Android certificate/code monotonicity, ELF/ZIP alignment, package
contents/private-file exclusion, checksums and remote/public upload integrity
remain required. Those are packaging/integrity operations, not application tests.
No installer, personal profile, cloud account or existing app data is operated.

## Evidence and invocations

Ignored `.buildlog/verify/ui-quality-beta12/` retains source/protected hashes,
remote release/tag baseline, exact build/package commands, times with offset,
logs, exit results and artifact metadata. Each invocation and any failure/retry
will be retained. Candidate/source, artifacts and final publication outcomes
follow below; preparation is not a published receipt.


## Published outcome

Published **[v1.0.19-beta.12](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.12)**, version
`1.0.19-beta.12+35`, source/tag `31a70d1dc922362fcc88d8a6b5c74cd321157d8c`,
release ID `434191145`, at `2026-11-04T16:54:55Z`
(2026-11-04 19:54:55+03:00). New release only: draft=false, prerelease=true,
make_latest="false". Existing releases/tags and the private historical draft are
unchanged. The feature branch/tag were pushed atomically; no main merge or
website deployment. The tag stays pinned to the candidate; later documentation
updates do not move it or require another build.

### Build and package evidence

- One Windows Release compilation/package invocation and one Android Release
  compilation/preparation invocation, both exit0. Windows Flutter/native version,
  approved public OAuth/runner/AOT consistency, CRT, private-file exclusions,
  installer compilation and portable packaging pass. The previous local numeric
  installer and original OAuth config are restored.
- Android Flutter compilation took 341.7 seconds. The helper verifies production
  package `io.github.hik4.todorbit`, non-debuggable status, minSDK26, universal
  ARM64/x64, version name beta12/code35 above all published metadata, production
  certificate SHA-256 `00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`,
  eight native ELF/applicable ZIP alignments and generated update metadata/hashes.
  No AAB or split APKs are published. Existing Kotlin/SDK XML warnings did not
  fail compilation; no unrelated toolchain migration or new dependency was added.
- The final portable audit fully reads and compares 29 runtime files, ZIP CRC,
  exact membership/content, root/native/Flutter licenses, sidecars/manifests and
  nine explicit assets. It runs once after final packaging, not after every doc edit.
- At19:48:18+03:00, `python .buildlog/verify/ui-quality-beta12/check-source.py`
  compares 342 candidate source/configuration files: zero differences. Protected
  storage docs, signing properties, original OAuth config and Android local
  properties match their original SHA-256. No private key/config content printed.
- Draft gate checks all nine names, sizes, uploaded state and GitHub SHA-256
  digests against local artifacts before publishing. Anonymous public delivery
  then downloads every asset once and verifies full byte counts/hashes, three
  binary Range responses, release notes, exact tag/source/classification and
  unchanged audited draft asset identities. Completed transfer evidence is
  incremental; no extra binary copies are retained.

### Exact invocation index

All new artifact invocations target source `31a70d1dc922362fcc88d8a6b5c74cd321157d8c`.
Full commands/environment/source manifests, stdout/stderr and local offset times
are retained in the ignored evidence directory. Wrappers below retain the exact
underlying calls, not substituted ad hoc build commands. There was no failed
build, application-test execution or build retry in this publication.

| Local timestamp / receipt label | Exact invocation from repository root | Actual result/log under evidence root |
| --- | --- | --- |
| 2026-11-04T19:34:04.335776+03:00 / `windows-build-package` | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\AI_Projects\life_manager\.buildlog\verify\ui-quality-beta12\build-windows.ps1` | Exit 0; `logs/windows-build-package.log` |
| 2026-11-04T19:40:11.267054+03:00 / `android-build-package` | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\AI_Projects\life_manager\.buildlog\verify\ui-quality-beta12\build-android.ps1` | Exit 0; `logs/android-build-package.log` |
| 2026-11-04T19:48:02.131521+03:00 / `artifact-audit` | `python .buildlog/verify/ui-quality-beta12/audit-artifacts.py` | Exit 0; `logs/artifact-audit.log` |
| 2026-11-04T19:52:00.937272+03:00 / `stop-build-daemons` | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .buildlog/verify/ui-quality-beta12/stop-owned-build-daemons.ps1` | Exit 0; `logs/stop-build-daemons.log` |
| 2026-11-04T19:48:41.510774+03:00 / `draft-upload` | `python .buildlog/verify/ui-quality-beta12/create-draft.py` | Exit 0; `logs/draft-upload.log` |
| 2026-11-04T19:54:53.964597+03:00 / `publish` | `python .buildlog/verify/ui-quality-beta12/publish-draft.py` | Exit 0; `logs/publish.log` |
| 2026-11-04T19:55:02.661123+03:00 / `public-verification` | `python .buildlog/verify/ui-quality-beta12/verify-public.py` | Exit 0; `logs/public-verification.log` |

Windows build wrapper invokes `tools/build-windows-release.ps1`,
`installer/build-installer.ps1 -Compiler 'D:/vs code/Inno Setup 7/ISCC.exe'`
and `tools/build-portable.ps1 -OutputDirectory <recorded task directory>`.
Android invokes `tools/build-android.ps1 -Mode Release -Distribution github
-GoogleDrive` with the existing JDK21/SDK/cache, then
`tools/prepare-android-release.py --apk build/app/outputs/flutter-apk/app-github-release.apk
--apk-only --version 1.0.19-beta.12 --version-code 35 --certificate-sha256
00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99
--notes docs/UI_QUALITY_BETA_12_RELEASE_NOTES.md --output <recorded packages directory>`.
Build scripts retain process-local memory/worker settings and restore original
configuration in finally blocks. Only completed, identity-checked task Gradle/
Kotlin daemons 17296/27944 were stopped; no running app/profile was closed.

Initial `gh api releases`/`git ls-remote --tags` inspection and later draft-progress
reads are in the session transcript; the full baseline is retained as
`releases-before.json`/`tags-before.txt`. One progress-only jq filter failed because
Windows quoting stripped its string literal (`function not defined: uploaded/0`).
The corrected field projection succeeded. No mutation/upload was retried for it.
`gh run list --branch feature/ui-quality-beta12 --commit <candidate> --json
databaseId,name,status,conclusion --limit 10` returned `[]`; no CI was dispatched.
Both publication commits use `[skip ci]` to honor the current owner request.

### Public assets

| Asset | Bytes | SHA-256 |
| --- | --- | --- |
| [ANDROID-RELEASE-NOTES.md](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/ANDROID-RELEASE-NOTES.md) | 3251 | `bc53beaf4361346a526de8ef481e6612c5c4f322a9a33c7ec2d6bc68d18fa2c9` |
| [ANDROID-SHA256SUMS.txt](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/ANDROID-SHA256SUMS.txt) | 316 | `9eaa23329a581ebed8b617ba73e26f10db1158306ef1d3c1601816c5c75f6c4b` |
| [Todorbit-1.0.19-beta.12-SHA256SUMS.txt](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/Todorbit-1.0.19-beta.12-SHA256SUMS.txt) | 221 | `00ef079d2c10d5f096d8ceac3fb9bb5b51f25017832c2bbe4b8d5719830cec1f` |
| [Todorbit-1.0.19-beta.12-android-universal.apk](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/Todorbit-1.0.19-beta.12-android-universal.apk) | 53119811 | `1f62eed56909b4f37533f60ef7de4574bba7a6b511223029d7ec2810772ac7f9` |
| [Todorbit-1.0.19-beta.12-android-update.json](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/Todorbit-1.0.19-beta.12-android-update.json) | 421 | `0fd6c4a5debc7f38c6944f7550159bf16330c6323ed60dd90b7b19a32b9347e5` |
| [Todorbit-1.0.19-beta.12-win-x64-portable.zip](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/Todorbit-1.0.19-beta.12-win-x64-portable.zip) | 63125460 | `ef021d45c216c28c9f4eac81338a7f5a109ac06e980b997f63c5dd2d5d01a5f3` |
| [Todorbit-1.0.19-beta.12-win-x64-portable.zip.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/Todorbit-1.0.19-beta.12-win-x64-portable.zip.sha256) | 112 | `47466b495d20f6a1654185f1326bcd2542df54e207b2c1eaf09d75ba204fe440` |
| [Todorbit-1.0.19-beta.12-win-x64-setup.exe](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/Todorbit-1.0.19-beta.12-win-x64-setup.exe) | 47719531 | `e8f4a454dbc378dc70f2829d6a96227e8b2542cc43c34ec758b505b827e4e8ab` |
| [Todorbit-1.0.19-beta.12-win-x64-setup.exe.sha256](https://github.com/2HIK4/Todorbit/releases/download/v1.0.19-beta.12/Todorbit-1.0.19-beta.12-win-x64-setup.exe.sha256) | 109 | `8f2069b98729ea65a89d389acedf9e801f624f7610cdfbfa69ed0820347c355a` |

### Delivery and retained limitations

Further application tests, analyzer, CI, native self-tests, updater test cases,
device/emulator/manual acceptance are **SKIPPED at the owner's request**, never
PASS. Earlier six-batch scoped evidence is reused for unchanged product behavior;
the version/packaging build and integrity operations above are separate. No new
application defect or production fix was added during acceptance/publication.
The W01 attachment sample is scoped dark/100% evidence only. External links,
native keyboard/readers/widgets/DPI and Android IME/SAF/Calendar launcher/OEM/ARM64
or upgrade behavior remain unaccepted. Application-wide readiness is not claimed.
Real Drive cross-device Sync remains a separate task.

Use **Pre-release** in Software Updates; Windows installed mode selects Setup,
portable mode the whole ZIP. Android uses the production-signed universal APK,
code35. Preserve account/path/profile, exported backups and actual Sync credentials.
Do not uninstall, clear data or downgrade to recover from an error. No setup/APK
was installed, no personal app data opened, no cloud-account operation performed.
Original three storage changes remain uncommitted and byte-identical. Final
documentation diff/preservation checks and local/remote commit/status follow at
delivery; no public download/build is repeated for receipt-only updates.

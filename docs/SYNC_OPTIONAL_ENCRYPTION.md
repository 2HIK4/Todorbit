# Standard and optional private sync implementation

Task baseline `13e27344d9c042ecf77bf55a7afd0782caaa099d`, branch
`feature/sync-optional-encryption`, 2026-11-04. Schema/application versions, OAuth,
portable allowlist, causal merge, recovery snapshots and independent backups stay
unchanged. Unrelated storage-cleanup documentation remains uncommitted and excluded.

## Behavior and compatibility

Normal Connect initializes a new **Standard Sync** workspace without a password
or recovery secret. A second device discovers this mode from a bounded versioned
workspace document, joins without a credential and uses the existing initial
merge. Standard batches contain readable JSON; Drive authorization/transport and
storage protections apply. There is no Todorbit payload encryption or protection
against someone authorized to modify this account's cloud data.

An optional Settings > Sync > Encryption options flow creates a **new** Private
Encrypted Sync workspace. It collects a memorable passphrase (12 characters,
up to 4096 UTF-8 bytes, no composition rules; predictable PIN/repetition rejected),
requires acknowledgment of a separately saved random recovery code, and wraps the
random 256-bit workspace key with Argon2id (19 MiB, two iterations, one lane,
32-byte result) and AES-256-GCM. Fixed bounded KDF parameters, random salt/nonce,
account/workspace/schema AAD and an authenticated workspace proof bind the format
and mode. KDF work runs off the UI isolate. New devices can use either credential;
routine exchanges use the retained key, never a saved plaintext passphrase.

Legacy protocol-1 encrypted proofs/batches and their recovery codes remain
readable with the original AES-GCM format. Legacy users keep code-based recovery;
backup PBKDF2 format and passphrase rules are untouched. New Standard proofs and
operation envelopes use protocol 2. New private proofs use protocol 2 and preserve
the existing encrypted operation codec. Older clients reject unfamiliar proofs
before starting their outgoing pass; upgrade both devices to use new workspaces.

Only a successful complete listing establishes an empty cloud. Failed listing,
download, future schema, malformed data, mixed proof modes/keys and account mismatch
stop setup without treating the cloud as empty. Explicit private setup never
silently converts existing Standard data. Authentication, permission, temporary
API failures, conflicts and migration markers have distinct failure categories.
Pending journals, immutable upload retry bytes and original profile data remain.
The sole private key and wrapped creation proof persist before upload so an
ambiguous reply/process loss can retry without losing the key or needing the
passphrase. The Standard introduction persists until acknowledged and appears only
after a successful initial exchange, never for an encrypted workspace.

Protected credentials reuse `SecureCloudTokenStore`, keyed by profile/purpose on
Windows and Android. They are excluded from portable settings. This does not
protect against every local threat or compromise of an unlocked device.

## Explicit implementation limit: no mode conversion or password rotation

**Standard-to-private, private-to-Standard and cloud passphrase changes are not
implemented.** Settings explicitly disables conversion and explains the limitation.
No cloud deletion, generation switch or data rewrite is attempted. Choosing private
setup when an existing Standard workspace is discovered fails without mutation.

The current protocol has immutable per-device journals, immutable bytes in local
outboxes, cloud change cursors and a **local SQLite** lease. It has no shared
generation barrier, cross-device write fence or committed migration manifest.
Appending/replacing one proof or changing a preference cannot stop an already
running older client from completing a plaintext upload, and reusing a batch ID
with converted bytes violates the retained immutable-batch identity check.
Implementing conversion requires a reviewed forward protocol and restartable
conversion state, covering in-flight old writers, competing conversion attempts,
all retained history/attachments and cursor/outbox reconciliation. A speculative
multi-file transaction or assumed compare-and-swap is not used.

The [Drive files.update reference](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/update)
and [upload guide](https://developers.google.com/workspace/drive/api/guides/manage-uploads)
describe individual file updates; this implementation does not infer a multi-file
transaction contract. No historical plaintext erasure is promised. Encryption
parameters follow the existing library's [Argon2id API](https://pub.dev/documentation/cryptography/latest/cryptography/Argon2id-class.html).

## UI review scope

Applied [Ultimate UI/UX](../.agents/skills/ultimate-ui-ux/SKILL.md), Build/Fix scope:
shared Windows/Android Sync settings, optional private setup, credential visibility,
recovery acknowledgment, persistent nonmodal introduction and honest unavailable
conversion controls. Existing theme type/helper roles, adaptive switches,
scrollable dialogs, keyboard actions, privacy closure and loading/disabled states
are reused. Physical Windows/Android rendering, IME and assistive technology are
not established by source inspection or host widget tests.

## Pre-test decision and evidence

Critical scope: formats, key recovery, retained-object protocol and initial merge.
Feature scope: Sync settings and private setup. Reviewed the comprehensive/redesign
ledgers, Testing and both platform CI definitions before execution. Prior Sync
passes do not cover the changed behavior. Existing backup/schema/native/OAuth/
release evidence remains baseline evidence for those unchanged boundaries; no
current platform acceptance is inferred. CI is unmodified. The existing feature
catalog now includes the new source/test paths; no new runner/framework exists.

`F` below expands exactly to `flutter --no-version-check --suppress-analytics test
--no-pub --concurrency=1 --reporter expanded --timeout=2m` (one shell line).
`D18` is the final fingerprint's Dart paths, excluding
`lib/data/sync_status_repository.dart` and `test/cloud/sync_drive_contract_test.dart`,
which were added to scope after the first run. All commands ran from the repository
root with the existing Flutter/Dart toolchain and cached dependencies; all accounts,
HTTP and data in tests are synthetic, with disposable SQLite files.

| Finish time (+03:00) | Exact command / scope / purpose | Source / evidence | Result / necessity |
| --- | --- | --- | --- |
| 2026-11-04, initial inspection | Git status/branch/HEAD and unfinished-operation status; focused source/receipt/CI reads | `13e2734`; feature branch created | Passed; identified and preserved paused cleanup. Some assumed file paths/globs were absent and were corrected using the feature map; no test/build ran during discovery. |
| 2026-11-04 02:07 | Dart MCP `dtd(command: list)`, corrected to `listDtdUris`, then `connect(uri: ws://127.0.0.1:56517/...)` | Existing IDE DTD, Dart 3.13.5 | Initial argument validation Failed; corrected discovery/connection Passed. No active app. |
| 2026-11-04 02:10 | `dart format D18` | Working diff / source-01 | Passed; initial formatting, 16 files adjusted. |
| 2026-11-04 02:11:26 | `dart analyze D18` | source-01 `84aa3ac8370fb60185ca6ad03a860b7dc9b82489cca354ee67a0a3045cf2d856`; `analysis-01.log` | Failed (exit 3): two constructor errors (`OutlinedButton.icon` needed `label`, not `child`) and 15 missing-brace infos. Necessary first static check; fixed before tests. |
| 2026-11-04 02:12 | `dart format lib/data/cloud/sync_pairing_service.dart lib/data/cloud/sync_workspace_format.dart lib/features/settings/sync_encryption_setup_dialog.dart lib/features/settings/sync_settings_page.dart lib/features/shared/sync_status_button.dart` | Corrected constructor/braces | Passed, no extra formatting changes; necessary after corrections. |
| 2026-11-04 02:12:27 | `dart analyze lib/data/cloud/sync_pairing_service.dart lib/data/cloud/sync_workspace_format.dart lib/features/settings/sync_encryption_setup_dialog.dart lib/features/settings/sync_settings_page.dart lib/features/shared/sync_status_button.dart` | source-02 `b6178bd348151eb19f55244d691ad60d1ac82e4cd3d779ed5f60f9c3c6c21c67`; `analysis-02.log` | Passed; only corrected files reanalyzed. Initial clean diagnostics reused for unchanged files. |
| 2026-11-04 02:13:35 | `F test/cloud/sync_batch_codec_test.dart test/cloud/sync_pairing_service_test.dart test/cloud/sync_standard_mode_test.dart test/smart_sync_controller_test.dart` | source-02; `core-01.log` | Failed: 17 passed / 6 failed. All 15 codec/pairing/format tests passed; six Standard-controller cases failed because retained-object identity still rejected protocol 2. Fixed that check and caller, not the assertions. Disposable separate executors emit existing Drift multi-database warnings. |
| 2026-11-04 02:14 | `dart format lib/data/sync_status_repository.dart lib/data/sync_exchange_models.dart lib/data/cloud/sync_engine.dart` | Retained-object protocol fix; bounded metadata-prefix inspection | Passed, one file formatted; necessary changed paths only. |
| 2026-11-04 02:15 | `dart format lib/data/cloud/sync_pairing_service.dart test/cloud/sync_standard_mode_test.dart test/cloud/sync_drive_contract_test.dart` | Migration-marker guard/assertion; explicit private adapter fixture | Passed, three formatted; necessary after additions. |
| 2026-11-04 02:15:41 | `dart analyze lib/data/sync_status_repository.dart lib/data/sync_exchange_models.dart lib/data/cloud/sync_engine.dart lib/data/cloud/sync_pairing_service.dart test/cloud/sync_standard_mode_test.dart test/cloud/sync_drive_contract_test.dart` | source-03 `fa35dbdaab50cf2156067926d73d6e08b845d9028dd31d8075a272496b9d312b`; `analysis-03.log` | Passed; only newly changed boundaries checked. |
| 2026-11-04 02:16:56 | `F --name 'one manual request\|metadata refreshes\|Standard Sync joins\|second device asks\|offline decision\|concurrent offline resolutions\|private encryption setup\|API failure\|a lost initial proof reply\|recovery input' test/smart_sync_controller_test.dart test/cloud/sync_standard_mode_test.dart test/cloud/sync_drive_contract_test.dart test/sync_conflicts_dialog_test.dart` | source-03; `focused-02.log` | Passed, 13 cases: eight controller cases, marker/error detection, one production-adapter interrupted-private-proof case over synthetic HTTP, recovery IME geometry, private forms in light/dark at 390?844 / 200% text. Rerun affected controller file after fix; other cases new. No live Google traffic. |
| 2026-11-04 02:17 | `dart format lib/features/settings/sync_encryption_setup_dialog.dart test/sync_conflicts_dialog_test.dart` | Guard repeated privacy notifications while dialog closes | Passed, one formatted; necessary final-review correction. |
| 2026-11-04 02:17:39 | `dart analyze lib/features/settings/sync_encryption_setup_dialog.dart test/sync_conflicts_dialog_test.dart` | source-04 (post-format, before manifest capture); `analysis-04.log` | Passed; new privacy guard/test only. |
| 2026-11-04 02:18:05 | `F --plain-name 'private setup privacy closure preserves its parent on repeated lock notifications' test/sync_conflicts_dialog_test.dart` | source-04 `ff848af3d55a656b3d6f0b50051da71cc46ed1ab008bd92a78b64cc30534d2c1`; `privacy-03.log` | Passed, one case. New: two lock notifications close only the credential dialog, preserving its parent. |
| 2026-11-04 02:18 | `dart format lib/features/settings/sync_settings_page.dart test/sync_conflicts_dialog_test.dart` | Preserve intentional leading/trailing passphrase spaces; recovery codes still trim | Passed, two formatted; necessary credential correction. |
| 2026-11-04 02:18:44 | `dart analyze lib/features/settings/sync_settings_page.dart test/sync_conflicts_dialog_test.dart` | source-05; `analysis-05.log` | Passed; changed credential/UI test paths only. |
| 2026-11-04 02:19:03 | `F --plain-name 'private passphrase input preserves intentional spaces' test/sync_conflicts_dialog_test.dart` | source-05 `c07715b995fa83520982e942f6c6cb484e2476cf431650a1b4679d1f5807c6e9`; `passphrase-04.log` | Failed: ambiguous test finder matched both status text and button (`Too many elements`). No product failure observed; narrowed finder to FilledButton. |
| 2026-11-04 02:19 | `dart format test/sync_conflicts_dialog_test.dart` | Finder correction only | Passed, one formatted; necessary after test change. |
| 2026-11-04 02:19:30 | `F --plain-name 'private passphrase input preserves intentional spaces' test/sync_conflicts_dialog_test.dart` | source-06 `c829ef7f256648b6922392d74a4e376585b5127955249c682eb386fcf2612152`; `passphrase-05.log` | Passed, one case; rerun only failed test after finder correction. |
| 2026-11-04 02:16 and 02:18 | Dart MCP `hot_reload(clearRuntimeErrors: true)` | Connected IDE DTD; latest application source on each call | Blocked: no active app. Second call followed final UI source changes as required by live-tooling instructions. No build launched; no runtime pass claimed. |

| 2026-11-04 02:22:38 | `python tools/dev/check-docs.py AGENTS.md docs/ANDROID.md docs/ARCHITECTURE.md docs/ARCHITECTURE_MAP.md docs/CODEX_WORKFLOW.md docs/GOOGLE_DRIVE_SYNC.md docs/PRIVACY.md docs/PROGRESS.md docs/TESTING.md docs/TEST_RUN_LEDGER.md docs/SYNC_OPTIONAL_ENCRYPTION.md`; `git diff --check` | Final source + documentation | Passed: zero link/map/catalog errors and no whitespace errors. New final documentation/configuration check; no application tests repeated. |

| 2026-11-04 02:23:10 | `git diff --cached --stat`; `git diff --cached --check`; SHA-256 comparison against `source-final.json` | Explicitly staged feature paths only | Passed: 32 files, no whitespace errors; all 23 final source/config fingerprints matched. Necessary final staging/identity check. Receipt-only finishing edits receive a staged whitespace recheck before commit, without repeating application tests. |

Reused evidence: the 15 passing codec/pairing tests from core-01 remain applicable
to their unchanged crypto/legacy/private branches. Later pairing additions only
reject a `state=migrating` marker (absent from those fixtures); its new behavior
passed the single marker/error case. Updated metadata/retained-object/controller
behavior passed focused-02. Later UI-only guards preserve that evidence. The
three earlier widget cases remain valid for unchanged form geometry/validation;
new privacy and exact-input behavior have their separate passes. The final finder
change affects only which test button is selected and compiled in its passing run.
The feature-catalog addition changes selection, not application behavior.

Intentionally skipped: full Flutter/widget/golden suites; all builds/installers/APKs,
dependency downloads, emulator/native integrations, benchmarks, release packaging,
and real Google Drive tests. These are unrelated/expensive or explicitly reserved
for the owner. Mode-conversion/rotation tests are Skipped because those operations
are unavailable, not implemented or claimed safe. Physical UI/IME/assistive-tech
and trusted-storage behavior remain unverified; host geometry is distinct evidence.

Final code/configuration fingerprint, SHA-256
`cd12d3301c0d64ac72ef61077b54a69c7995eea42d4dc96464546bdcaf863493`:
the SHA-256 of the following sorted, two-space-indented JSON bytes with no trailing
newline. It identifies the final source and dependency/analyzer/selection config;
documentation-only finishing edits do not invalidate application evidence.

```json
{
  "analysis_options.yaml": "dbdb095ba9629b1281dfb0a1c3ac0d37da578d48b26d02f75b3cb9b6b21142f4",
  "lib/app/sync_controller.dart": "9de36891313c68030b4e6ee5b1307be8cda1627fafd8f98431ce68d66b42172c",
  "lib/data/cloud/cloud_storage_provider.dart": "2266dd746bbdaa6c53620d15e42ff12521a8a3b7e016c2c5b7382c76d266c161",
  "lib/data/cloud/google_drive_provider.dart": "0f2997698bec7c4cced397fed9d8fd52ca43a2df6af4f489896d1cdbf347afd6",
  "lib/data/cloud/sync_batch_codec.dart": "180c8ade9d4eeff046e165426b9d43e01e716c9bf85ed469de91fc107fccbd1e",
  "lib/data/cloud/sync_engine.dart": "77fc01e29e44d3439e5723764f7dc464e2957bc54969e248ad0fdf8d16ebff7e",
  "lib/data/cloud/sync_pairing_service.dart": "69fc896c354caa53d0aa47039d26fc25cf1f2c1f067a40dd8ce65845a44be0c7",
  "lib/data/cloud/sync_workspace_format.dart": "a7f1f36d93e503ca3dc4a045447c0eadbf5fac7581e671ee1df828a358fed8f6",
  "lib/data/sync_exchange_models.dart": "5567dcf62c23cf7ead32e2c0ba1e5d5f55be5a4c85493bdc30f4ea0bdbf28ccd",
  "lib/data/sync_exchange_repository.dart": "d8ca66988eaccf038ad07b25e1cf77e2f3dbcea3ddbab91b63d5e92a5a1c4d5b",
  "lib/data/sync_incoming_repository.dart": "8428b36ef34b34a8b3daa2aec2b070badfbc3b9307994034eb138a5f125788bc",
  "lib/data/sync_status_repository.dart": "a74bedd4556b1d29c3a5d837e780d760964aa9f25dd9cf4cb6967460c9f64d3d",
  "lib/features/settings/sync_encryption_setup_dialog.dart": "28f6c34824912fed6228d611855406ef3733a77f828d1a2e1aa1903b3218a90b",
  "lib/features/settings/sync_settings_page.dart": "8efa278b26eb791c6e96b93570447e731eed18498015de164d68023ca4406924",
  "lib/features/shared/sync_status_button.dart": "7fa5f5c52aa54f3d4dc41d6a763c44f1b925f7d148627e29933f56e96be462ca",
  "pubspec.lock": "d7f08f3cbe6018bda46a67719b60b4a09a55492dc4862ff4d4c08169d23b6194",
  "test/cloud/sync_batch_codec_test.dart": "8b65fd9387452d48f8d7d2ea2861cb5dd0ee7b5fbd37fe43413ccf66371339c3",
  "test/cloud/sync_drive_contract_test.dart": "8e518b93b5b14137ce65fd4e452ea54789348616b423a8defa0ca32ca85d7f3d",
  "test/cloud/sync_pairing_service_test.dart": "7e237bbe741589249cf86d7c72399145db71f394cf960391f8fb194aa6e99b88",
  "test/cloud/sync_standard_mode_test.dart": "38b0cd0a3fd65a55ed083342f198d1b8c4586160e11ac0213769789d9fca6063",
  "test/smart_sync_controller_test.dart": "82f3d54edd8d2c6c1dfc9517612fda96dbc9aa6129af480a5028b2abccaaa069",
  "test/sync_conflicts_dialog_test.dart": "6fb55658b15db3a71e96b7b3fa7b73f6f8935e459cfe982c9865623689b91451",
  "tools/dev/features.json": "e9ba49160bd927a8b696809225a208a5e5f92b1c0336cc28f226f9543d05a6e7"
}
```

## Owner manual acceptance

Safety-critical, use backed-up disposable profiles and the same authorized Google
account on updated Windows and Android:

1. Connect normally with existing distinct local tasks/settings on each device;
   verify Standard detection, no password, merged stable IDs/attachments, changes
   both directions and no repeated introduction after acknowledgment/restart.
2. With a separate empty authorized workspace, open Encryption options before
   first connection, create private sync and save its recovery code. On device two
   test wrong passphrase (no uploads), correct passphrase, restart without repeated
   prompts, and recovery-code unlock on a disposable third profile.
3. Join a legacy beta-9 encrypted workspace with its original recovery code. Ensure
   no Standard initialization, lost-key recovery preserves the SQL device identity,
   and old encrypted history/attachments/preferences remain usable.
4. Try offline setup, interrupted upload, revoked/denied permission and account
   switching. Confirm no empty-cloud success, no mixed account upload, durable
   local edits and successful retry. Test competing edits/conflict resolution.
5. Verify conversion/password-change controls remain explicitly unavailable and
   leave cloud mode unchanged. Keep an independent backup and test restoration
   and restored-profile reconciliation.

Optional: observe OS background timing, narrow/large-text layouts, light/dark,
keyboard/Back/IME behavior and the new forms on physical devices. Real Google
sign-in, actual cross-client appData discovery and real exchange remain unverified.

## Changed files and Git handoff

The feature commit contains the following explicit paths. Its commit identity can
be obtained with `git log -1 -- docs/SYNC_OPTIONAL_ENCRYPTION.md`; source identity
and results above are independent of documentation-only finishing edits.

```text
AGENTS.md
docs/ANDROID.md
docs/ARCHITECTURE.md
docs/ARCHITECTURE_MAP.md
docs/CODEX_WORKFLOW.md
docs/GOOGLE_DRIVE_SYNC.md
docs/PRIVACY.md
docs/PROGRESS.md
docs/SYNC_OPTIONAL_ENCRYPTION.md
docs/TESTING.md
docs/TEST_RUN_LEDGER.md
lib/app/sync_controller.dart
lib/data/cloud/cloud_storage_provider.dart
lib/data/cloud/google_drive_provider.dart
lib/data/cloud/sync_batch_codec.dart
lib/data/cloud/sync_engine.dart
lib/data/cloud/sync_pairing_service.dart
lib/data/cloud/sync_workspace_format.dart
lib/data/sync_exchange_models.dart
lib/data/sync_exchange_repository.dart
lib/data/sync_incoming_repository.dart
lib/data/sync_status_repository.dart
lib/features/settings/sync_encryption_setup_dialog.dart
lib/features/settings/sync_settings_page.dart
lib/features/shared/sync_status_button.dart
test/cloud/sync_batch_codec_test.dart
test/cloud/sync_drive_contract_test.dart
test/cloud/sync_pairing_service_test.dart
test/cloud/sync_standard_mode_test.dart
test/smart_sync_controller_test.dart
test/sync_conflicts_dialog_test.dart
tools/dev/features.json
```

Uncommitted work retained from the paused cleanup: `docs/DEVELOPMENT.md`,
`docs/STORAGE_CLEANUP_2026_11_04.md`, `docs/STORAGE_MAINTENANCE.md`. No cleanup,
version/tag change, installer/APK, publication or push was performed.

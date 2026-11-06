# Google Drive sync

Current local schema-27 OAuth/real-service status and owner setup actions are in
[the 2026-11-06 real Drive audit](REAL_DRIVE_ACCEPTANCE_2026_11_06.md).
All real cross-device scenarios remain blocked before approved test-account
authorization; deterministic passes do not establish live Google behavior.

Beta 11 adds **Start New Sync** in Sync settings (under **Recovery** in the current
UI). Routine sync and Automatic sync precede encryption/advanced recovery options;
pending replacement reviews expand Recovery automatically. A verified independent local
snapshot and explicit cloud-loss acknowledgment precede a fresh workspace. It
keeps current local portable records and retained histories, uploads and reads
back the complete new seed, activates an immutable generation head, then removes
only the selected retired workspace content. Cleanup failures have a separate
retry action. Non-content heads remain to reject recreated legacy namespaces;
old clients must update and explicitly reconnect. Concurrent heads stop exchange
and cleanup until an explicitly reviewed replacement supersedes them. Interrupted
setup resumes on its original device. Unknown/future ownership and foreign
uncommitted staging block deletion. See [protocol, safety evidence and manual
checks](SYNC_START_NEW.md). Physical devices and live Drive remain owner acceptance.


Latest recorded publication: **1.0.19-beta.11+34**, schema 26; see the exact source,
artifacts and remaining acceptance in [the beta11 receipt](SYNC_START_NEW.md).
The current UI refinements are local and are not included in that release.
Historical beta9 baseline: 1.0.19-beta.9+32, schema 26, sync protocol 1. Beta 9 includes
the interrupted-upload and offline-decision fixes from
[comprehensive verification](SMART_SYNC_VERIFICATION.md). See the
[publication receipt](SMART_SYNC_BETA_9_PUBLICATION.md) for exact artifact checks
and limits. Real Google Drive end-to-end acceptance remains incomplete.

## Connect two devices

The current development source defaults new workspaces to **Standard Sync**:
connect Google Drive and sync without another password. A second updated device
automatically detects Standard data and merges its existing local records.
Existing encrypted workspaces still require their original recovery credential
once; they are never replaced with Standard data. Published beta-9 behavior above
is historical; beta10/11 implement Standard/private setup as recorded in their receipts.

For a **new empty** workspace, Settings > Sync > Encryption options offers Private
Encrypted Sync. Choose a memorable passphrase, save the random recovery code and
connect. On another device, choose the passphrase or recovery-code method once;
protected local storage retains the unlocked workspace key. Standard data is
readable JSON on Drive; private data is encrypted before upload. Backups remain
independent recovery snapshots. Both modes retain the existing portable allowlist,
initial merge, conflicts and automatic scheduling below.

**Existing workspace conversion and passphrase changes are unavailable.** The
control explains this explicitly. No cloud data is deleted or rewritten. See
[implementation, safety limits, test receipt and manual acceptance](SYNC_OPTIONAL_ENCRYPTION.md).
Legacy encrypted workspaces keep their existing recovery codes. New protocol-2
workspace proofs require updated clients on both devices; older clients stop at
proof verification. OAuth configuration and account/profile safeguards are reused.
Normal users never enter publisher client IDs or configuration files.

## Timing and background behavior

Local edits commit to SQLite immediately. While an unlocked app is active, exchange
is debounced about 750 ms after changes and polls about every two minutes. Another
active device usually sees safe changes on its next poll plus network time.
Startup checks automatically, and foreground checks are throttled to at most one
per 15 seconds. In-app polling pauses in the background; existing OS workers
remain separate opportunities. Network restoration is detected on the next
permitted retry/poll without a permanent connectivity service. Scheduler intervals
are configurable at the engine boundary; automatic on/off is device-local.
These are opportunity intervals, not delivery guarantees. Network failures use
durable exponential backoff; Sync Now permits an explicit retry.

Android requests network-constrained periodic jobs at the OS minimum interval
(15 minutes), plus a short delayed job after edits. Each worker has a 30-second
exchange budget and a 45-second native timeout. Doze, force-stop, restrictions,
authorization and OEM policies can delay work. It does not promise immediate
delivery or permanent execution. Authorization requiring interaction is deferred
to the unlocked foreground app. No new foreground service or wake lock is used.

Windows uses the existing native companion while it is running. It checks about
every minute and debounces database changes, then starts a hidden short-lived
worker. It adds no new sign-in registration. The foreground app takes precedence;
SQLite leases also prevent simultaneous writers across workers and processes.
Closing or disabling the companion removes that background opportunity.

Background workers never perform migrations, pending restores or protected-profile
unlock. With app lock enabled, sync requires the unlocked foreground app. The
bounded job retains its queue if it cannot finish; the next opportunity resumes.

## What travels

The portable allowlist covers tasks, categories/projects, fixed events and their
exceptions, sessions, availability, scheduling history, sequences/dependencies,
recurrence, habits, goals, timers/time entries, templates/saved views, deletion
history, hierarchy/checklists, progressive plans, icons, managed attachments and
portable appearance/task/calendar preferences. Stable record IDs and immutable
causal operations prevent duplicate replay. Independent fields merge when safe;
meaningful competing values require review. Device clock timestamps never decide
which competing value wins.

Local-only data includes external file references and file contents, OS permissions,
notifications/delivery receipts, widget placement/instances, startup/hotkeys,
sidebar order/width, opening page, theme author metadata, widget opacity,
privacy/PIN state, OAuth tokens, workspace keys, update files
and transfer receipts. Managed attachment bytes do travel, with digest/length
validation. HTTP/HTTPS resource links also travel. Sync never opens a remote
device's file paths. Backup and Sync share the selected session; disconnecting
Google Drive in Backups stops that profile's synchronization too, retaining its
workspace key and pending history.

Timer ownership prevents another device from inventing elapsed work or heartbeating
the imported timer. An explicit adoption pauses at the last recorded checkpoint
and changes owner. Resume starts a new interval; disconnected owner changes may
require conflict review.

## Conflicts and restore

The consolidated review compares This Device, cloud candidates and base values.
Choose per record or use the counted bulk selection buttons, then Apply selected
resolutions and confirm. Selecting a bulk option does not apply anything.
Independent compatible changes remain.
Deletion/restore and related-record consequences require explicit consistent
choices. Unsafe choices roll back together; versions stay retained. Resolve Later
survives restart and unrelated edits; Settings > Sync can reopen it. Automatic
checks retain an accessible count badge without opening a modal. Manual Sync
offers direct review. A confirmed decision is a durable causal operation which
acknowledges the reviewed heads, including a choice to keep identical local
bytes. A failed network preflight can save a decision against retained history;
the SQL transaction still rejects stale reviews. Pending decisions upload on a
later successful exchange. Other devices accept that descendant instead of
redisplaying the old conflict. Genuinely new edits or incompatible simultaneous
decisions may require a new review. Structural groups still require consistent
choices for every coupled record.

A full restore is staged and requires restart. The UI reports the committed
restart requirement even if optional cloud-history bookkeeping subsequently fails.
That post-staging failure was reproduced and fixed; the original phone exception
was not captured, so it is not a confirmed diagnosis of that particular device.

Startup retains and verifies the original Before Restore snapshot, then quarantines
sync. Settings > Sync > Reconcile restored profile verifies the original workspace,
retains queued pre-restore history/ciphertext, and uses a fresh device identity.
Restored older values remain causal candidates against newer edits; absence from
an older snapshot does not delete cloud-only records. Automatic sync stays off
until enabled. Missing recovery evidence stops reconciliation instead of erasing
work. Private prototype schema 23–25 pairings require reviewed recovery conversion.
Published schema 22 upgrades are covered by migration tests and retain data.

## Manual acceptance with synthetic records

Use disposable profiles on both platforms and an authorized disposable Google
account. Real Drive acceptance has not been performed for this candidate; current
automated cloud evidence uses mocks. Do not test against personal data.

1. Connect both profiles in Standard mode, or authorize a private workspace with its passphrase/recovery code. Create a task with notes and a small managed
   attachment on Windows. Click Sync, then sync Android; compare IDs and bytes.
2. Edit its title on one device and notes on the other while offline. Reconnect;
   verify both independent changes survive and no duplicate task appears.
3. Edit the same title differently offline. Reconnect, review both versions,
   choose Resolve Later, restart, then reopen review and apply a decision. Verify
   convergence on both devices. Repeat with a parent deletion and child edit.
4. Enable automatic sync, edit while both apps are active, and observe arrival.
   Close/lock/background devices and observe actual OS scheduling separately.
   Verify no worker opens a Windows window or bypasses app lock.
5. Create a Windows snapshot and restore it on Android. Confirm the pending
   restart message, restart, verify restored data/attachments, then reconcile.
   Confirm an older restored edit conflicts with newer cloud work and that a
   cloud-only task survives. Keep the Before Restore snapshot throughout.

Physical devices, OEM behavior, real authorization and final live UI acceptance
remain distinct from mocked exchange, host fixtures and widget-test rendering.

## Schema 27 refinement compatibility (unpublished source)

Current refinement adds optional event-project assignment and named checklists.
Upgrade all participating installations before using these relationships.
Schema-27 clients accept unchanged schema-26 batches; older clients retain but
refuse newer batches. Existing Standard/Private workspace proof formats and
recovery requirements are unchanged. Immutable journals and queued ciphertext
are never rewritten to add fields. Equivalent concurrent deletions with no
other value differences no longer require a decision, but all tombstones and
causal heads stay retained. Delete/edit conflicts remain explicit.

The compact decision interface reveals full values on demand and remembers
selections only for the exact review fingerprint. Restored databases still
require explicit reconciliation; snapshot absence never infers a cloud delete.
The cause of the owner's unfamiliar items is not proven from personal data.
See [diagnosis and validation](REFINEMENT_2026_11.md).

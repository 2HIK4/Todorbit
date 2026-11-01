# Encrypted Google Drive sync

Version 1.0.19-beta.4, schema 26. The separate beta 3 has only a Coming soon
button. See the [publication receipt](DRIVE_SYNC_BETA_4_PUBLICATION.md) and
[implementation ledger](DRIVE_SYNC_RECOVERY_CHECKPOINT.md) for current evidence.

## Connect two devices

1. Keep an external verified backup first. On the first device, open Settings >
   Sync, connect Google Drive, leave the recovery-code field blank, and choose
   Set up encrypted sync. Setup creates a verified local recovery snapshot.
2. Choose Show recovery code and keep that code privately outside the device.
   Do not post it in diagnostics. The code and access to this Google account can
   decrypt the workspace. Losing every copy can make encrypted history unusable.
3. On the other device, connect the same Google account and enter the first
   device's recovery code before setup. Each device keeps its own identity and
   uploads its existing records; setup does not replace either database.
4. Click the top-right Sync icon. Settings > Sync shows pending changes, conflicts
   and last successful exchange. Automatic Sync can be turned off; Sync Now still
   exchanges when explicitly requested. Snapshot backup remains independent.

Pairing verifies an account-bound encrypted workspace proof. Competing keys or
workspace identities stop exchange and preserve history; do not create a new key
as a recovery shortcut. Existing OAuth publisher configuration is reused. No
additional cloud service, Todorbit account or permissions are introduced.

## Timing and background behavior

Local edits commit to SQLite immediately. While an unlocked app is open, exchange
is debounced about 750 ms after changes and polls about every 25 seconds. Another
active device usually sees safe changes on its next poll plus network time.
This is an opportunity interval, not a delivery guarantee. Network failures use
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
Choose per record or use the bulk selection buttons, then Apply Selected. Selecting
a bulk option does not apply anything. Independent compatible changes remain.
Deletion/restore and related-record consequences require explicit consistent
choices. Unsafe choices roll back together; versions stay retained. Resolve Later
survives restart and unrelated edits; Settings > Sync can reopen it. Automatic
prompts wait until editors/modal flows are closed and the app is unlocked.

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

1. Pair both profiles with one code. Create a task with notes and a small managed
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

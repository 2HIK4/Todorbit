# Encrypted Google Drive sync

Published baseline: 1.0.19-beta.8+31, schema 26, sync protocol 1. See the
[publication receipt](SMART_SYNC_BETA_8_PUBLICATION.md) and
[comprehensive verification](SMART_SYNC_VERIFICATION.md). The latter identifies
local fixes for interrupted uploads and offline decisions that are not included
in the published beta. Real Drive end-to-end acceptance remains incomplete.

## Connect two devices

1. Use disposable profiles and an authorized disposable Google account for
   acceptance testing. Keep an external verified backup of existing data. On the
   first device, press Sync or open Settings > Sync > Connect Google Drive.
   Sign-in continues through secure setup and the initial exchange automatically.
   Setup creates a verified local recovery snapshot.
2. Choose Save your recovery code (or Advanced > Show recovery code) and keep it
   privately outside the device.
   Do not post it in diagnostics. The code and access to this Google account can
   decrypt the workspace. Losing every copy can make encrypted history unusable.
3. On the other device, press Sync and connect the same Google account. Todorbit
   detects existing encrypted data and requests the first device's recovery code
   once. Choose Authorize this device. Each device keeps its own identity and
   uploads its existing records; setup does not replace either database.
4. Click the top-right Sync icon. Settings > Sync shows pending changes, conflicts
   and last successful exchange. Automatic sync can be turned off; Sync now still
   exchanges when explicitly requested. Snapshot backup remains independent.

Pairing verifies an account-bound encrypted workspace proof. Competing keys or
workspace identities stop exchange and preserve history; do not create a new key
as a recovery shortcut. Existing OAuth publisher configuration is reused. No
additional cloud service, Todorbit account or permissions are introduced.

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

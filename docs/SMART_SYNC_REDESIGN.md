# Smart Sync implementation ledger

## Baseline and audit (2026-11-03)

Branch `feature/smart-sync-redesign` starts at `0dcfb5a`, clean. Published beta 7
runtime source is `2919551` per `UI_UX_STAGE2_PUBLICATION.md`; its newer local
publication documentation is retained. No local release tag is available. App
version stays `1.0.19-beta.7+30`, SQLite schema 26, sync protocol 1, workspace
proof `todorbit-sync-workspace:1:aes256gcm`, encrypted batch format 1.

Existing implementation: shared Google OAuth (Windows PKCE/loopback, Android
Google Identity), profile-keyed OS secure storage, account-bound AES-256-GCM
workspace proof and recovery key. A second device needs the key once; Google
authentication cannot recover this end-to-end key. Persisted device authorization
already avoids repeated entry. Backups use a separate encrypted snapshot format
and are never pruned by sync.

SQLite captures immutable UUID operations, causal parents/visible intervals,
transaction groups, deletions, encrypted outbox retries and incoming batches.
Leases fence concurrent workers. Drive's change feed supplies durable cursors;
downloads are authenticated before atomic application. Independent fields merge;
competing values and unsafe relationships retain both branches. Resolution emits
a new durable operation acknowledging every reviewed head, even when keeping
unchanged bytes. Stale decisions are rejected under the SQL writer lock. Preserve
these working mechanisms rather than replace them with timestamp winners.

Supported scope is the existing 42-table portable allowlist: tasks/completion,
categories/projects, events/exceptions, sessions, availability/scheduling,
recurrence, dependencies/sequences, habits/goals, timers/time entries,
templates/saved views, trash/deletions, hierarchy/checklists/progressive plans,
icons, managed attachment bytes, web links and portable appearance/task/calendar
preferences. External paths/bytes, OS permissions/reminders, widget instances and
placement, windows/sidebar geometry, startup/hotkeys, privacy/PIN, credentials,
keys, updates and transfer receipts remain device-specific. No scope expansion.

Confirmed source issues:

- Sign-in, activation and initial exchange require separate user actions.
- First and additional devices see the same unexplained recovery input.
- Automatic conflicts navigate from build into modal dialogs.
- Foreground events lack a minimum interval; polling continues in background.
- Every controller refresh signals a local change, including remote projection.
- Local triggers arriving during an exchange can be swallowed by the shared job.
- The busy icon hides conflict attention, and its badge has no count label.
- Settings exposes routine, recovery and protocol explanations together.
- Conflict choices lack a concise final confirmation for discarded changes.
- Controller resolution refuses offline decisions despite durable local storage.

## Implementation contract before sensitive changes

Retain schema/protocol/encryption/backup formats: no migration, key upload, remote
deletion, new provider, account service or release. First manual request signs in
and continues activation/exchange. Existing encrypted data must raise a typed
one-time authorization state without creating a replacement key. Lost local key
recovery must authenticate the existing proof and preserve the existing SQL
device binding before saving to the secure vault. Damaged retained credentials
are not silently overwritten.

Automatic work uses startup, bounded active polling, debounced committed changes,
throttled resume and durable network backoff. Polling retries provide connectivity
recovery without adding a network-monitor dependency. No continuous OS background
guarantee. Manual requests bypass retry delay; jobs share one exchange and retain
follow-up local work. Existing platform jobs stay compatible.

Conflict decisions remain versioned causal operations. A failed preflight network
refresh may still allow a decision against retained history: the transaction
revalidates its review token, and unseen new changes remain genuine divergence.
Confirmed decisions remain queued if offline. Structural groups still require
consistent decisions for all coupled records; no partial relational application.

UI scope: Sync icon, compact adaptive Sync dialog, one-time recovery step,
advanced recovery/account controls and conflict review. Apply Ultimate UI/UX Fix
and Build workflows proportionally: hierarchy, honest states, keyboard/Escape,
long accounts, short/narrow viewports, IME, 200% text, both themes, semantics and
nonintrusive conflict attention. Runtime/physical/account evidence is separate
from host tests and rendered images.

## Verification policy and checkpoints

Risk: Critical for orchestration/security and conflict durability, Feature for
layout. Reuse beta 7 evidence for unchanged snapshot formats, native integrations,
migrations and packages; it does not validate this changed application. Run
focused engine/controller/pairing/conflict tests during editing, then the sync
group and full serial suite/analysis at the cross-platform integration checkpoint.
Run feasible isolated platform checks. Real Drive requires an authorized
disposable account; no owner account/profile will be used.

| Invocation / purpose | Source | Result | Reason / limits |
| --- | --- | --- | --- |
| Baseline status/log, architecture/source/test/receipt inspection | `0dcfb5a` | Clean; audit above | New task; prior sync mocks and beta 7 release evidence reviewed, not rerun |

Next: implement and verify orchestration, then simplify UI and complete the
integration/visual acceptance ledger. No push, merge or publication authorized.

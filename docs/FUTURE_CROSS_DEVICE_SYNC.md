# Future cross-device synchronization proposal

This is a design boundary, not an implemented feature or authorization to add a
service. Todorbit currently exchanges verified snapshots. Full restore replaces
a dataset after review; it does not merge concurrent edits. A future transport,
account model and key-recovery model require a separate product decision.

## Record and device identity

Retain stable entity UUIDs, UTC modification metadata, recurrence-family and
nominal occurrence identity, and existing deletion/history relationships. Add
an explicit logical dataset ID shared by paired devices; keep local profile,
device, OS permission and credential identities separate. UTC timestamps help
users understand changes but cannot order concurrent writes reliably.

Every portable mutation would commit its record change and an outbox operation
in the **same SQLite transaction**. An operation needs its own UUID, device ID,
monotonic device sequence, entity UUID/type, base revision and versioned field
payload. Device-local settings and paths never enter that outbox. Native Windows
writers would have to participate in this transaction contract before sync could
be enabled; watching database files is not a substitute for a durable outbox.

## Exchange and conflict review

Transport batches must be idempotent by operation UUID, authenticated and
encrypted, bounded in size and resumable. Acknowledged revisions and pull-page
checkpoints commit atomically with the applied batch. Transient failures retry
with backoff; stale credentials require reconnection without deleting local work.
Schema/protocol compatibility is checked before applying anything. Unsupported
fields must be retained or the operation rejected explicitly.

| Concurrent change | Proposed behavior |
| --- | --- |
| Independent fields on the same task | Merge only after validating the combined draft against domain rules and base revisions. |
| Same field changed on two devices | Keep both candidates and show an explicit conflict review; device clocks do not choose a winner. |
| Planned day, deadline, session or actual work | Treat as separate fields/entities; never infer completion or silently rearrange work. |
| Recurrence family versus occurrence edit | Resolve using stable family/nominal occurrence identity and existing series-edit rules; preview affected occurrences. |
| Delete versus edit | Retain the edited candidate and tombstone for review. Do not erase one side automatically. |
| Attachment or relationship change | Validate content digest, reference ownership and referential integrity in one apply transaction. |

Deletions need explicit versioned tombstones with origin/revision metadata.
Retention must account for all paired-device acknowledgements and long-offline
devices. A fixed short expiry must not resurrect old records or permanently
erase an unseen edit. Archive, Trash and permanent deletion remain distinct user
actions, and backup snapshots remain independently recoverable.

## Security and rollout gates

Do not reuse a backup passphrase as an unattended sync credential. Define device
pairing, per-dataset encryption keys, rotation/revocation, recovery, compromised
device handling and encrypted attachment transfer before implementation. Tokens
and keys remain in OS secure storage and outside portable snapshots. Disconnect
stops exchange; it does not silently delete local or remote records.

Require deterministic operation-log/replay tests, mixed-version migration tests,
concurrent edit/delete/recurrence tests, interrupted batches, revoked-device and
offline retry tests, and explicit conflict UI acceptance on both platforms.
Enable synchronization only after an approved product/security review. The
current Android adapters introduce none of this exchange behavior.

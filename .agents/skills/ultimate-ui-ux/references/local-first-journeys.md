# Local-first, account and recovery journeys

Read actual approved architecture before changing these experiences. UI
simplicity never authorizes changing encryption, keys, authorization, ownership,
causal conflict semantics, generations or data-retention rules.

| Journey | Inspect and verify |
| --- | --- |
| Setup | Selected account, actual workspace mode, compatible client and local merge scope. Standard setup may need only sign-in; private/legacy data requires its retained passphrase or recovery material. No invented password-free decryption or unnecessary publisher configuration. |
| Routine local use | Local commits work offline; visible pending state is distinct from confirmed exchange. Automatic debounce/resume/poll opportunities are rate-limited by the existing engine. Do not promise immediate delivery under OS restrictions. |
| Manual check | One guarded action, accurate progress/terminal state, latest successful exchange distinguished from pending edits. Actionable failure survives long enough to recover. No success based only on account connection. |
| Reconnection/account change | Reauthorize the pinned account safely; reject mixed-account/workspace data. Preserve queue and recovery material. Explain when an encrypted key is still needed. Never silently start a replacement. |
| Conflict attention | Accessible nonmodal count for background discovery; manual route to compare meaningful candidates. Deferral persists, bulk choices have counts and explicit final apply. Do not repeatedly interrupt. |
| Resolution | UI choices match reviewed heads; transaction rejects stale or inconsistent choices. Offline saved decisions remain pending for upload. Confirm propagated resolution does not reappear unless genuinely new divergence exists. |
| Recovery/replacement | Backups and Sync are separate. Restore/replacement consequences, verified independent snapshot, original-device resume, generation fence and incomplete cleanup remain explicit. Do not hide safety acknowledgments to reduce steps. |
| Background/lock | OS jobs are opportunities, not guarantees. Lock/auth restrictions defer work safely; no foreground popup loop, secret logs, unbounded retry or fake progress. Observe actual scheduler acceptance separately from synthetic clocks. |

Trace input → controller → persistence/outbox → approved transport → remote
readback → local projection → feedback. Record which boundary establishes each
claim. Use synthetic accounts/transports and isolated profiles; live Google/OAuth,
cross-client discovery and physical background behavior require their own evidence.

For Todorbit, authoritative behavior is in `docs/GOOGLE_DRIVE_SYNC.md` and the
current controller/engine/pairing/reset implementations. Existing source supports
Standard Sync, optional private new-workspace setup and recovery of older encrypted
workspaces; do not add conversion/passphrase rotation that the protocol cannot
safely perform. No new service, account system or permanent connectivity service
is implied by a UI review.

# Sync button preview — 1.0.19-beta.3 (26)

Windows and Android now include a Sync button. It opens an accessible, scrollable
Coming soon panel. Google Drive synchronization, pairing and conflict resolution
are not available in this release. Use Backups & Cloud for snapshot transfer.

This small release starts from published Android beta 2 source
`500a9a8a7c078f54dd79fa0f03aaa8f7cf4da596`. The separate unfinished sync branch,
its database migrations and its experimental engine are excluded. Database schema
22, existing tasks, preferences, backups, widget identities and the Android
production publisher are preserved.

The owner explicitly requested a button-only publication without tests on
2026-11-01. This is a specific exception to the usual exact-source CI/test gates
in RELEASE.md. No unit, widget, integration, emulator or native self-tests are
claimed for this candidate. Build, package identity/signing and checksum checks
are still required. Earlier release evidence does not establish this UI's
rendered behavior. Full sync development remains paused after this publication.

# UI quality beta 6 release checkpoint — 2026-11-03

Publication was explicitly requested after the completed local
[Stage 2.1 follow-up](UI_UX_STAGE2_AUDIT.md#stage-21-follow-up--2026-11-03).
Candidate: **v1.0.19-beta.6**, Windows/Android `1.0.19-beta.6+29`, schema 26.
This is a prerelease; do not mark it as latest Stable.

Public releases and remote tags were inspected before selection: beta 5/code 28
was current, beta 6 was unused and no draft release existed. Previous public
releases/tags must remain unchanged. The local Stage 2.1 checkpoint is `9240364`;
runtime candidate source and remote CI identities are recorded when available.

## Scope and release gates

[Release notes](UI_UX_STAGE2_RELEASE_NOTES.md) cover the Stage 2 editor/navigation
fixes and Stage 2.1 Windows native event appearance. Production Android code,
installer/updater, database schema, app/profile/IPC identities and signing
identity are preserved. The production Android certificate remains
`00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99`.

The previously owner-approved public Desktop OAuth configuration is retained for
the coordinated experimental release, with provenance/hash validation, temporary
build-only substitution and exact restoration of the tracked disabled config.
No user credentials, accounts or Cloud Console settings are copied or changed.

| Gate | Status |
| --- | --- |
| Local Stage 2.1 native Release/self-test, live style reload/recreation, rendered icon atlases | PASS; detailed source/artifact boundaries in audit |
| Local focused host probes and test-source analysis | PASS across scoped runs; full unchanged Stage 2 evidence reused for local follow-up only |
| Exact beta 6 Windows full analysis/serial suite/native/package CI | Pending |
| Exact beta 6 Android CI and emulator integration | Pending |
| Production-signed beta 6 APKs and private Play AAB identity/alignment | Pending |
| Enabled local Windows Release/CRT/config consistency, Setup/portable integrity | Pending |
| Exact final APK 16 KiB hosted runtime | Pending |
| Draft source/classification/assets/digests, public delivery/updaters | Pending |

CI and build results for beta 5 or the pre-version Stage 2.1 artifacts do not
satisfy exact beta 6 release gates. Logs, artifact manifests and per-invocation
records are retained under ignored `.buildlog/verify/stage21-release/`.

## Explicit acceptance limits

The original Android shaking sequence remains unreproduced. Native keyboard/error
transitions and the expanded 192-case footer probe were blocked by local guest
failures; the original two footer PNGs show complete labels on reinspection.
Physical OEM launcher, ARM64, TalkBack, Narrator, Windows input/DPI/multi-monitor
and shell acceptance are unobserved. No Windows Sandbox will be launched for
this checkpoint. These limitations are disclosed, not converted to passes.

Existing unchanged installer/updater and signing acceptance can be reused only
at identical source boundaries; final package identities, signatures, code 29,
alignment and mandatory runtime/CI still require fresh evidence. Real Google
Drive exchange and branding remain under the existing experimental limitations.
The AAB is a private candidate, not a GitHub release asset or Play publication.

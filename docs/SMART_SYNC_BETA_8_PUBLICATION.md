# Experimental Smart Sync beta 8 release ledger

Owner explicitly authorized public experimental prerelease publication despite
incomplete comprehensive acceptance. Mandatory builds, startup/data safety,
signing and integrity remain gates; no publication before they pass.

Candidate: `1.0.19-beta.8+31`, schema 26, protocol 1, branch
`maintenance/smart-sync-beta8-release`, based on clean `4c83b8d` and all five
Smart Sync commits. Remote beta 7 is `2919551`; beta 8/tag/code 31 were unused.
No existing release or tag will be replaced. Full-suite stalls are not passes.

## Evidence policy

Reuse the Smart Sync 38-test regression and 18-test final orchestration evidence
where runtime behavior/assertions are unchanged (counts overlap), plus unchanged
beta 7 installer/updater acceptance boundaries. Run fresh exact-candidate CI,
enabled Windows and production-signed Android builds, final artifact integrity
and minimum isolated startup/runtime checks. The owner's experimental exception
allows focused checks if the full suite stalls; it does not waive mandatory
build, signing, startup or data-safety gates. Real provider and physical acceptance
remain separate and must be disclosed in release notes.

## Invocation ledger

| Procedure | Result / reason |
| --- | --- |
| Initial status/log and five ancestor commits | Clean Smart Sync branch at `4c83b8d`; required commits present |
| Guidance, workflows, Smart Sync and beta 7 release evidence | Read; no application rewrite planned |
| `gh release list`, repository identity, `git ls-remote --tags` | Beta 7 latest published prerelease, rejected beta 6 draft retained; beta 8 unused |
| Prior build context inspection | C-temp source has no Git pointer/pubspec and cannot be reused as a valid checkout; preserve it. Existing C Gradle dependency cache remains available |
| Host/build diagnosis reuse | Prior measured D write/flush latency was 4–7 seconds versus milliseconds on C. New isolated C checkout selected; no cache deletion or personal-profile access |

Detailed per-command logs and candidate metadata: ignored
`.buildlog/verify/smart-sync-beta8/`. Publication outcome and final assets follow
after mandatory gates; this initial ledger does not claim a published release.

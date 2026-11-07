# Alarm beta implementation checkpoint

Owner request: implement optional audible alarms for Windows/Android and publish
the next experimental beta only after mandatory delivery/data/signing/CI gates.
Current branch `feature/sync-ux-refinement`; implementation starts at `29a3257`.
Latest published release is beta12; beta13 source is unpublished and no matching
remote beta13 tag was found. Select the final candidate version after implementation.
Three unrelated storage documents, production profiles/credentials and retained
Standard/Private workspaces remain protected. Do not reuse chat-exposed secrets.

## Reuse and scope

Beta13 local installer26-to27/uninstall/reinstall, exact worker barriers and clean
production-signed Android core/restart/native-widget acceptance passed. Evidence:
FINAL_STABILIZATION_2026_11_07.md and external release-verification039/041.
Both task-owned VM/AVD stopped. Reuse unchanged Standard/Private matrices, crypto,
OAuth, recovery algorithms and broad UI evidence; alarms introduce a new boundary.

Portable configuration is separate from native handles/receipts/snoozes:
schema28 additive `alarm_rules`, FK owners and deterministic UUIDv5 identities;
existing immutable journals preserved during26/27 migration. New clients accept
26/27 batches, old clients reject28. Workspace proof/key format stays unchanged.
Pure bounded planner and compact shared Add alarm editor added. Tasks support
explicit UTC, planned-day local clock and work-session offsets; event relative
rules follow actual projected occurrences. Explicit occurrence Off overrides a
series. Recurring task rules belong to their series; existing IDs/dates unchanged.

## Current evidence and unfinished work

Logs `.buildlog/alarms-beta-20261108/`:
- foundation1 compile failure: non-const recurrence fixture used const. Corrected.
- foundation2:5 passes/1 failure, fixture clock after local planned alarm time.
  Corrected fixture; foundation3 all6 pass (config, timing, atomicity/stable IDs,
  reschedule/completion/deletion, recurrence and event exceptions).
- targeted UI analysis: no errors/warnings,11 new brace infos to fix before final.
- Dart MCP analysis timed out300s; CLI is authoritative. No app hot reload yet.

Android native adapter WIP: exact access with inexact fallback, short bounded
media-playback service, alarm notification/actions, snooze choices, local receipts.
Not compiled or OS-tested yet. No fullscreen intent or USE_EXACT_ALARM permission.
Guidance consulted: [Android alarms](https://developer.android.com/develop/background-work/services/alarms)
and [Play sensitive permissions](https://support.google.com/googleplay/android-developer/answer/16558241).
Exact access remains user-granted; force-stop/denial/Doze/DND/OEM limits remain.

Next: finish native delivery/state cancellation and device alarm settings; Windows
companion runtime/sound/snooze; validate temporal/owner/CAS/snapshot/migration and
Sync boundaries with focused tests; UI tests and isolated hot restart. Build only
affected final candidates sequentially, perform a few actual OS checks, then
mandatory exact-source CI and release gates. No version bump, builds, push, tag,
new cloud exchange or publication performed in this implementation checkpoint.
Do not present current WIP as ready or enable it on production data.


## Implementation checkpoint: Beta14 build37

Selected unused tag/version beta14+37, retaining private beta13 artifacts.
Source now includes Android native alarm service/actions/exact fallback and
Windows companion planner, bounded sound/window, local receipts, snooze/restart
and failed-write suppression. New rules supersede legacy item reminders. Explicit
family edits retain other occurrence overrides and use reviewed revisions.
Device delivery/startup settings are explicit; missing startup preferences never
create a Run entry. Pending/applied restore blocks native alarm delivery.

Evidence updates (same ignored log root): focused4 all18 pass; critical5 backup
passes but new fixtures fail (missing table after synthetic downgrade; missing
batch visibility/group). Corrected critical6 all3 pass; backup pass reused.
Focused12 all11 pass, including captured/applied/replayed new alarm rows in both
Standard/Private local exchanges. These are simulated transports, not new Drive
requests. Native build2/selftest1 pass, including actual scheduled WinForms/audio
API, snooze/restart/dismiss/duplicate and failed-write checks; physical audibility
unverified. Subsequent native changes need final rebuild/selftest.

Kotlin8 wrapper stopped on an existing warning (configuration restored);9 failed
an uncached unused ARM32 engine;10 reached compiler and found native builder lacked
setSilent; corrected to existing NotificationCompat. Kotlin11 PASS in89s, exact
local.properties restored. Later small policy changes require final compilation.
Analysis13/14: zero errors/warnings; remaining style infos being closed. Focused15
and final analysis pending. Dart MCP analysis timed out; CLI used. No full suite.

Windows public build parameters were reconstructed locally from the approved
Desktop JSON and match byte-for-byte the already-published public configuration
SHA256 in widget-hotfix/oauth-provenance.json. No values printed, original JSON
unchanged, no token/key/profile packaged. Outside-Git candidate root:
`D:/AI_Projects/TodorbitPrivateBuilds/alarm-beta-20261108`; protected ACL verified.
Receipt001 records this continuity. The three protected storage documents remain.

Next: final focused checks/style, isolated debug hot restart, final sequential
Windows/Android candidate builds and OS checks, exact-source mandatory CI, then
publish only if critical gates pass. Owner explicitly authorizes intended commits,
push/tag and experimental publication. Do not start another Sync matrix, connect
accounts, touch retained profiles, or treat this WIP checkpoint as released.

## Final source checks / live editor (2026-11-08, UTC+03)

Analysis16 and25: No issues. Focused15 all15 passed; final focused24 all14
passed after strict-duration and fresh-startup defaults changed. Format23 passes.
Native build/selftest17 passed with task/event delivery, restart/snooze/dismiss,
failed receipt writes, duplicate suppression and locked generic content. Native
startup-default assertion changed afterward; packaged self-test will cover it.
Helper19 reports all8 passing; PowerShell marked native stderr as an error despite
unittest OK (no application failure). No need to repeat the eight assertions.

Live Windows private source profile paths verified from runtime receipt and VM
before actions. Hot reload passed. Probe18 blocked behind initial Settings;
20 found an ambiguous New task label after the pending tap opened the editor;
21 reached alarm options but could not save because the device-off fixture was
outside the selected Profile. Corrected only the fixture/harness;22 passed actual
alarm creation/options/save. Read-only003 confirms schema28, exactly one synthetic
task/alarm and clean integrity/FKs. Captures reviewed at1264x681. The only runtime
error was the recorded ambiguous harness finder; no product runtime error found.
Owned app closed. Logs retain failed harness attempts. No accounts/cloud accessed.

Compact Add alarm and disclosed sound options preserve common editor fields;
explicit device/startup preferences are necessary controls. This is a scoped
Windows/Android alarm journey review, not a repeated comprehensive app audit.
Next: commit source, final public packages, native packaged/Android OS delivery,
mandatory exact-source CI and publication gates. Prior Standard/Private and
Beta13 recovery/installer results reused only for unchanged boundaries.

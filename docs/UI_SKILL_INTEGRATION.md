# Ultimate UI/UX integration and maintenance (2026-11-02)

## Stage 1: UI quality engineering upgrade

Baseline `3bb6e8b`; focused branch `maintenance/ultimate-ui-ux-engineering`;
initial tree clean. This section records the locally maintained upgrade; the
original installation receipt below remains historical evidence of the archive
as installed. Archive byte equality is intentionally no longer an upgrade gate.

Scope: skill/documentation only. No Todorbit application code, versions,
dependencies, data, global skills, release assets or regression skill changed.
No application-wide audit or repair of the reported Android issues was started.
The earlier read-only discovery task observed the skill in this session's catalog
and read its repository-local manifest. A new-session selector refresh after this
upgrade is not established by that observation.

### Maintained content

- Preserved all 28 numbered categories and 303 original symptom/repair bullets;
  added discovery, common causes, correction verification and related regression
  scope to every category. Existing repairs supply the problem/solution fields.
- Added [audit workflow](../.agents/skills/ultimate-ui-ux/references/audit-workflow.md)
  with reachable-surface inventory and five coverage statuses, separating N/A,
  source/offscreen/runtime/physical evidence and unavailable-tool acceptance.
- Added [Flutter engineering](../.agents/skills/ultimate-ui-ux/references/flutter-engineering.md)
  and [verification recipes](../.agents/skills/ultimate-ui-ux/references/flutter-verification.md)
  for Android/Windows constraints, insets, IME/focus, DPI, state/lifecycle,
  persistence, theme propagation, overlays, scrolling, accessibility and tests.
- Extended existing fix patterns with value/color tracing, deliberate versus
  generated interval ends, adaptive popup anchors and validation/scroll/flicker
  diagnosis. Updated matrix/report/README/source routing without removing web,
  native, localization, privacy, performance or upstream attribution guidance.
- Kept name `ultimate-ui-ux`, project discovery path and automatic matching;
  the entrypoint is 83 lines / 765 whitespace-delimited words (less than baseline
  by word count). Small changes load relevant sections; full audits load the
  complete coverage workflow. Todorbit tokens, Fluent conventions and existing
  native/profile/test gates remain authoritative.

### Validation ledger

Quick documentation risk. Prior installation validation applies only to that
archive/baseline. Its byte-equality helper was inspected, not rerun against this
intentional upgrade. Application receipts remain applicable to their recorded
artifacts; documentation changes do not justify rerunning application gates.
Commands below ran from the repository root on Windows with existing Python.
The ignored helper/results are under `.buildlog/verify/ultimate-ui-ux-stage1/`.

| Invocation / scope | Source / result | New or rerun / reason |
| --- | --- | --- |
| `git status --short`; `git branch --show-current`; `git log -5 --oneline`; scoped file inventory and relevant guidance reads | `3bb6e8b`, clean; existing maintenance branch; seven-file skill and integration/testing receipts inspected | New: ownership, scope and prior evidence; created focused upgrade branch |
| `git log -3 --oneline -- .agents/skills/ultimate-ui-ux docs/UI_SKILL_INTEGRATION.md`; `git check-ignore .buildlog/verify/ultimate-ui-ux-stage1/receipt.json` | Single installation commit; detailed verification directory ignored | New: check prior validation and artifact location |
| `python -c "import importlib.util; print('PyYAML available:', importlib.util.find_spec('yaml') is not None)"` | False; unchanged missing prerequisite | New environment probe; standard `quick_validate.py` not retried because it still cannot import YAML; no dependency installed |
| Primary-source browser reads listed in the skill's Sources reference | Flutter constraints/insets/MenuAnchor/testing/WidgetStateProperty/TextScaler migration/accessibility/goldens and Windows responsive guidance read; direct TextScaler-class and WidgetTester-view URLs unavailable | New: verify framework guidance; no code copied or API upgrade required; failed direct reads replaced by available official guidance, not runtime evidence |
| `git diff --stat`; affected manifest/matrix/report diff; `git status --short`; historical checker inspection | Only intended skill files at interim review; original package equality checker unsuitable for maintained upgrade | New: inspect preservation, routing and validator suitability |
| `python .buildlog/verify/ultimate-ui-ux-stage1/validate_stage1.py` | Pass: strict metadata subset/name/path, 7 original + 3 new Markdown files, 8 reachable references, 123 local paths/anchors across skill and selected docs, UTF-8/fences; 28 names/303 repairs preserved; diagnostic fields; root/regression unchanged and allowed scope | New: validate changed package against `3bb6e8b`; JSON source snapshot retained in ignored validation receipt |
| Desk review of hypothetical dropdown, configured-color, dependent-date, validation-scroll and audit-only/full-audit requests against final references | Routes to focused sections/shared consumers; separates semantic/contrast colors; preserves deliberate ends; allows legitimate scroll reveal/clamping; honors audit-only scope and blocked statuses | New: manual behavioral walkthrough of instructions only; no app source/runtime inspected and no independent agent execution claimed |
| `python tools/dev/check-docs.py AGENTS.md docs/CODEX_WORKFLOW.md docs/TESTING.md docs/UI_SKILL_INTEGRATION.md docs/PROGRESS.md .agents/skills/ultimate-ui-ux/SKILL.md .agents/skills/ultimate-ui-ux/README.md .agents/skills/ultimate-ui-ux/references/issue-catalog.md .agents/skills/ultimate-ui-ux/references/fix-patterns.md .agents/skills/ultimate-ui-ux/references/test-matrix.md .agents/skills/ultimate-ui-ux/references/report-template.md .agents/skills/ultimate-ui-ux/references/sources.md .agents/skills/ultimate-ui-ux/references/audit-workflow.md .agents/skills/ultimate-ui-ux/references/flutter-engineering.md .agents/skills/ultimate-ui-ux/references/flutter-verification.md` | Pass: 0 errors in explicit Markdown paths and existing feature catalog | New: project documentation checker after workflow/upgrade/checkpoint edits |
| `python .buildlog/verify/ultimate-ui-ux-stage1/validate_stage1.py` | Pass; 127 local links/anchors, all preservation/metadata/scope checks pass | Rerun: new workflow, receipt and Progress content invalidated the earlier documentation snapshot |
| `git diff --check` | Pass; Git reports expected LF/CRLF normalization notices, no whitespace errors | New: whitespace check on completed skill/documentation edits |
| `git diff --cached --stat`; full affected staged diffs; `git diff --cached --check`; `git diff --exit-code` | Pass; 13 intended skill/docs files; staged content reviewed; no whitespace errors or unstaged changes | New: review exact proposed commit including added files; no unrelated paths |
| `python .buildlog/verify/ultimate-ui-ux-stage1/validate_stage1.py`; `git diff --check`; `git diff --cached --check` | Pass; final metadata, references/anchors, preservation and scope; final source snapshot in ignored `validation.json` | Rerun: finalize verification receipt after staged review; no skill behavior changed since prior pass |

### Limits

The fallback validates this manifest's strict YAML subset, not arbitrary YAML.
This session's skill catalog/path reading supports discovery; a fresh-session
selector refresh and end-to-end execution of the revised skill are unobserved.
Flutter snippets are adaptation examples reviewed against primary guidance, not
compiled/executed app tests. No UI runtime, physical Windows/Android, assistive-tech
or actual defect-detection effectiveness claim follows from documentation checks.
Unchanged external inspiration links were retained, not all re-fetched.

## Original package installation receipt

Source baseline: `37b1c6e`; branch `maintenance/ultimate-ui-ux-skill`.
Scope: configuration/documentation only; no app, version, dependencies, user
data, backups, global skills or release assets changed. Initial tree was clean.
Quick documentation checks apply; previous runtime receipts remain valid for
their recorded artifacts and were not rerun or presented as new verification.
The 2026-10-24 skill setup checkpoint already recorded missing PyYAML.

## Package and routing

- Source: user-provided `D:\coding\ultimate-ui-ux-skill.zip`, SHA-256
  `347859a9fd077d4e1a4f1c77c43b30324b7d757cf2cdfc2c7fcd9720aeba7561`.
- Installed [manifest](../.agents/skills/ultimate-ui-ux/SKILL.md), README and five
  reference files under `.agents/skills/ultimate-ui-ux/`, byte-for-byte unchanged.
  Archive contained only seven regular Markdown files: no executable scripts,
  assets or dependencies to execute/install. Checked paths, modes, case-collisions,
  UTF-8, CRC and bounded uncompressed size before writing inside the repository.
- Removed tracked `todorbit-ui-review`: its visual/accessibility/layout audit
  purpose overlaps with the new skill. Preserved its project-specific design,
  shared-control, theme, isolation and native evidence requirements in the
  [UI quality workflow](CODEX_WORKFLOW.md#ui-quality-workflow), updated the Testing
  link, and retained `todorbit-regression` unchanged. These were the only two
  pre-existing project-local skills. Dated audit/progress mentions of the former
  skill remain historical evidence; no active instruction or link targets it.
- [Root instructions](../AGENTS.md#skills-and-documentation-routing) require
  reading/applying the primary skill for every UI task; a small change uses
  proportional checks. The workflow covers shared Windows/Android scope,
  platform conventions, themes/customization, accessibility and honest evidence.
  [Decision](DECISIONS.md#primary-uiux-skill-2026-11-02) supersedes old routing.

## Verification ledger

All rows use the baseline plus this installation/documentation diff, on Windows
with the existing Python interpreter. Inline Python commands are described by
their assertions; detailed terminal output is retained in the task conversation.
The final local helper is ignored under `.buildlog/verify/ultimate-ui-ux/`.

| Command / scope | Result | New or rerun / reason |
| --- | --- | --- |
| `git status --short`, branch/log and scoped `rg --files --hidden .agents`; baseline/local skill inventory | Clean initial tree; two tracked skills. Optional `.codex` search reported directory absent; continued against existing paths. | New: establish ownership and installation scope. |
| Inline `python -`: ZIP entry/manifest/reference inspection, SHA-256 and safe extraction assertions | Pass; seven Markdown files, no executable scripts or unsafe paths. | New: inspect untrusted archive before extraction; no bundled code executed. |
| `python -X utf8 <skill-creator>/scripts/quick_validate.py .agents/skills/ultimate-ui-ux` | Blocked before validation: `ModuleNotFoundError: yaml`. | New current-environment attempt; matches historical missing prerequisite. No global dependencies installed. |
| Inline `python -`: byte equality, restricted YAML metadata, relative references and unchanged-regression comparison | Package/metadata/references pass; regression byte comparison fails. | New fallback because standard validator cannot start. |
| Inline `python -` comparing normalized Git/worktree regression content; `git check-attr text eol -- .agents/skills/todorbit-regression/SKILL.md` | Pass; LF Git blob versus 12 CRLF worktree lines caused assertion; content unchanged. | New diagnostic; correct checker newline handling, no skill edit. |
| `git diff --check`; `git diff --stat`; scoped `rg -n --hidden 'todorbit-ui-review\|ultimate-ui-ux' AGENTS.md docs .agents -g '*.md'` | Pass; remaining former-skill mentions are dated history. | New interim whitespace/routing review. |
| `python .buildlog/verify/ultimate-ui-ux/validate_install.py` | Pass: package equality, metadata, five references, two local skills, retained regression, local Markdown links, activation routing and tracked scope. | Rerun: correct CRLF comparison and validate final documentation. This checker validates this simple YAML subset, not arbitrary YAML. |
| `git diff --check`; final affected/staged diff and scope review | Pass. | Rerun: final decision/checkpoint/receipt added after interim review; review exact commit contents. |
| `git diff --cached --check`; final `git status --short` and `git log -1 --oneline` | Pass; explicit paths committed, clean tree. | New staged/postcommit checks; no application tests/builds warranted. |

## Discovery and limits

[Official OpenAI documentation](https://learn.chatgpt.com/docs/build-skills)
confirms repository `.agents/skills/` discovery, explicit `$skill-name`
invocation and implicit matching by description. This package uses that layout,
has matching folder/name metadata and does not disable implicit invocation.
Codex normally detects additions automatically; restart if it does not appear.

The active session's selector refresh and a fresh-session `$ultimate-ui-ux`
invocation were not observed. Verify from this repository using the selector
and read-only review procedure in the workflow. No UI runtime inspection,
Flutter analysis/tests/builds, device acceptance or release operation was run
or needed for this configuration-only change.

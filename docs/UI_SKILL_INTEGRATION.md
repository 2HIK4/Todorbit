# Ultimate UI/UX integration (2026-11-02)

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

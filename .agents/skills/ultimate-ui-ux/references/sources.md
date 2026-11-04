# Source inspiration, external standards, and licensing note

The Ultimate UI/UX skill contains **original summarized rules and workflow** shaped by general UI engineering practice, the original 28-group symptom inventory, the user's 67-category expansion, and the public high-level approaches of the following ten published agent skills. The full named Problem Encyclopedia was unavailable in this upgrade; the supplied category inventory is the baseline. Upstream links below are provenance, not dependencies or a recommendation to load every skill. They are **not** copied, installed or embedded with source code. The exact rank order is editorial, not scientifically established. Individual skill content and dependencies may change over time. Review each upstream skill's license and scripts if choosing to install it separately.

1. **UI/UX Pro Max**, nextlevelbuilder — design patterns, theme/style choices, UX guidelines: https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
2. **Frontend Design**, Anthropic — intentional visual identity, typography, UX writing: https://github.com/anthropics/skills/tree/main/skills/frontend-design
3. **Impeccable**, pbakaus — design critique, audit, polish, adapt and harden: https://github.com/pbakaus/impeccable
4. **Web Design Guidelines**, Vercel — web interface practice, accessibility and code review: https://github.com/vercel-labs/agent-skills/tree/main/skills/web-design-guidelines
5. **Hallmark**, Nutlope — anti-generic design direction and review: https://github.com/Nutlope/hallmark/tree/main/skills/hallmark
6. **Taste Skill**, Leonxlnx — art direction and visual review for public-facing web pages: https://github.com/Leonxlnx/taste-skill
7. **Emil Kowalski Skills**, emilkowalski — `review-animations`, `break-ui`, interaction and performance thinking: https://github.com/emilkowalski/skills
8. **Responsive Design**, wshobson — adaptive layouts and screen-size testing: https://github.com/wshobson/agents/tree/main/plugins/ui-design/skills/responsive-design
9. **Accessibility Compliance**, wshobson — WCAG, ARIA, focus and screen readers: https://github.com/wshobson/agents/tree/main/plugins/ui-design/skills/accessibility-compliance
10. **Design System Patterns**, wshobson — tokens, consistent components, theming architecture: https://github.com/wshobson/agents/tree/main/plugins/ui-design/skills/design-system-patterns

Authoritative verification references (consult versions and applicability; do not claim compliance from a checklist alone):

- WCAG 2.2 Recommendation: https://www.w3.org/TR/WCAG22/
- WAI-ARIA Authoring Practices Guide: https://www.w3.org/WAI/ARIA/apg/
- WAI Tutorials: https://www.w3.org/WAI/tutorials/
- Material Design: https://m3.material.io/
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- Web performance guidance: https://web.dev/
- Agent Skills format: https://agentskills.io/specification

**Do not mistake this skill for a merger of all dependencies, source code, rule databases or assets from the upstream projects.** It is a compatible, lightweight, self-contained synthesis; those upstream packages may offer additional specialized tooling or references.

## Flutter and Windows engineering references

The added diagnostic procedures and recipes are original guidance. These primary
references support framework-specific details; check applicability to the pinned
SDK/platform before using a new API. No upstream skill or dependency is required.

- [Flutter constraints](https://docs.flutter.dev/ui/layout/constraints): parent/child constraint diagnosis.
- [MediaQuery viewInsets](https://api.flutter.dev/flutter/widgets/MediaQueryData/viewInsets.html): obscured area differs from safe padding.
- [MenuAnchor](https://api.flutter.dev/flutter/material/MenuAnchor-class.html): anchored menu ownership and style/overlay APIs.
- [WidgetStateProperty](https://api.flutter.dev/flutter/widgets/WidgetStateProperty-class.html): interaction-state color resolution.
- [TextScaler migration context](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor): nonlinear scaling; historical migration guidance, not a pinned-project upgrade instruction.
- [Flutter testing overview](https://docs.flutter.dev/testing/overview): widget vs integration evidence and native-tooling limits.
- [Flutter accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing): available automated and native checks.
- [Golden matcher](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html): capture boundary and platform/font/SDK limitations.
- [Windows responsive design](https://learn.microsoft.com/en-us/windows/apps/design/layout/screen-sizes-and-breakpoints-for-responsive-design): available window space and effective pixels; do not copy XAML breakpoints blindly into Flutter.

## Platform accessibility sources checked for the 2026-11-04 upgrade

- [Windows accessibility overview](https://learn.microsoft.com/en-us/windows/apps/design/accessibility/accessibility-overview): keyboard, screen readers, customization and UI Automation.
- [Android app accessibility](https://developer.android.com/guide/topics/ui/accessibility/apps): text contrast, 48dp touch targets and meaningful descriptions.
- [Flutter accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility): framework semantics and platform verification.
- [WCAG 2.2](https://www.w3.org/TR/WCAG22/): applicable AA evaluation targets, with exceptions and web/native unit distinctions. These sources support checks, not a Todorbit compliance claim.

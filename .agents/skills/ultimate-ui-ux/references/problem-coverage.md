# UI/UX coverage: 67 categories

This is the task's minimum inventory, not a claim to reproduce the unavailable
full **Ultimate UI/UX Problem Encyclopedia**. Each row gives a detection/evaluation
probe, a conditional correction and an observable verification. Findings require
actual evidence. Select relevant rows for local changes; comprehensive audits
assess all rows' applicability and record coverage/gaps, not every combination.

Use the four classes (visual, behavioral, usability, environmental) and the seven
dimensions in [audit workflow](audit-workflow.md). The separate
[symptom investigations](issue-catalog.md) and [fix patterns](fix-patterns.md)
provide deeper diagnosis without another competing coverage taxonomy.

## Product and usability: 1–10

| # / category | Detect and evaluate | Correct when confirmed | Verify |
| --- | --- | --- | --- |
| 1. User goals and mental models | Walk a real task from its entry point; compare names/objects with the user's intended outcome | Organize by goals; preserve planned dates, deadlines and actual work as distinct concepts | Complete the same task without reinterpretation or changed data semantics |
| 2. Workflow complexity and unnecessary steps | Count repeated choices, manual corrections and avoidable interruptions | Apply UX Necessity Review; combine redundant steps and use safe defaults | Compare action/decision count and retained advanced capability |
| 3. Information architecture | Trace related commands across navigation/settings; identify duplicates and dead ends | Group by user task with stable destinations and progressive disclosure | Reach related controls from expected entries without losing context |
| 4. Discoverability and affordances | Look for hidden hover/gesture actions and misleading clickable decoration | Expose a labeled alternative; match visual affordance to real action | Discover and operate by keyboard, touch and pointer |
| 5. Onboarding and first-time experience | Start a synthetic empty profile; distinguish required setup from optional education | Provide useful first action and contextual, dismissible help; avoid forced tours | Complete first useful task and revisit help without repeated prompts |
| 6. Cognitive load and information overload | Compare equal-emphasis actions, dense prose, nested cards and premature technical detail | Prioritize the immediate goal; reveal advanced information on demand | Main action remains obvious; necessary secondary information is reachable |
| 7. Content, labels and microcopy | Read labels/errors in context; check encoding, terms, consequences and plural forms | Use concise user vocabulary and honest action/result wording | Perform the described action/recovery and inspect long text |
| 8. Navigation and wayfinding | Follow primary, nested and external entry paths with Back/Escape | Maintain current location, stable target identity and intentional history | Return to correct destination with draft, selection and scroll preserved |
| 9. User control and freedom | Try cancel, dismiss, stop, undo and retry during a draft/pending action | Offer safe exits; explain irreversible boundaries; keep unsaved work | Cancel has promised effect, undo restores intended record, no silent commit |
| 10. Trust, expectations and transparency | Compare claims of saved/synced/protected with actual underlying state | Show confirmed results, relevant scope and limitations without invented metrics | Inject failure/pending state and verify copy never implies success |

## Visual design: 11–20

| # / category | Detect and evaluate | Correct when confirmed | Verify |
| --- | --- | --- | --- |
| 11. Visual hierarchy | Compare title/section/label/body/helper emphasis and primary actions | Apply semantic roles; reduce competing emphasis | Inspect normal and stressed renders; primary content wins naturally |
| 12. Typography | Inspect glyphs, line height, weights, truncation and text scaling | Reuse type tokens and fallback fonts; wrap without shrinking essential text | Long/mixed-script/larger text retains content and readable role hierarchy |
| 13. Spacing and padding | Measure repeated sibling gaps and compounded container padding | Reuse spacing tokens; group related elements more closely | Compare sibling alignment and multiline/error spacing |
| 14. Alignment, grids and geometry | Trace constraints, baselines, columns and icon bounds across resize | Fix parent constraints/grid rather than negative offsets | Check breakpoint edges, long labels and usable action bounds |
| 15. Color and contrast | Measure composited foreground/background and non-color status cues | Correct semantic pairings; reserve accents for meaningful roles | Contrast and focus/selected/error states remain distinguishable |
| 16. Themes and appearance customization | Trace picker → draft → saved palette → all renderers; switch live | Fix mapping/override precedence; preserve explicit customization | Light/dark/custom, cancel/apply/reopen and promised restart persistence |
| 17. Icons, symbols and imagery | Compare meaning, stroke/size, tint and accessible names | Use established icons, text alternatives and correct assets | Actual-scale renders and semantics convey same meaning |
| 18. Cards, surfaces, borders and shadows | Inspect nested boundaries and layering in all themes | Remove redundant containers; use semantic surface/elevation roles | Hierarchy remains legible without clipping or loss of grouping |
| 19. Content density and screen balance | Compare empty/typical/dense screens and desktop/touch contexts | Bound reading width and adapt density while retaining actions | Reach all content at narrow/short and wide sizes |
| 20. Design systems and consistency | Locate tokens/primitives and materially distinct consumers | Repair shared cause; extend a missing role only when justified | Recheck shared consumers and platform/native mappings |

## Interaction and components: 21–35

| # / category | Detect and evaluate | Correct when confirmed | Verify |
| --- | --- | --- | --- |
| 21. Buttons and action controls | Activate visible actions twice and while pending; inspect real target | Wire real handlers, guard duplicate work, expose unavailable state | One intended operation; pending/failure/keyboard activation correct |
| 22. Forms and data entry | Enter partial/long/pasted values; inspect labels, cursor and keyboard | Stable controllers/labels, appropriate input actions, preserve draft | Input/selection survive validation, rebuild and cancellation |
| 23. Validation and error prevention | Submit invalid, repeat, correct, save; inspect error location | Validate at appropriate triggers with actionable associated errors | Correct canonical model saves; invalid input never silently mutates data |
| 24. Dependent inputs and logical relationships | Change parent/start/type after editing dependent/end values | Reconcile predictable generated values while respecting explicit edits | Earlier/later/midnight/optional cases submit valid intended values |
| 25. Dropdowns, menus and selectors | Open at viewport edges, in nested dialogs and with long options | Use anchored/collision-aware shared menu with bounded scroll | Select correct value; arrows/Enter/Escape/focus and bounds correct |
| 26. Dialogs, modal windows and bottom sheets | Open short/narrow/IME variants; test barrier, Back and nested modal | Bound viewport, intentional scroll and action region; protect drafts | Close/actions reachable, focus contained/restored, no click-through |
| 27. Scroll behavior and layout stability | Record anchor/focus/offset through validation, filtering and IME | Preserve identity/controllers; fix scroll ownership/reveal cause | Last item reachable; no oscillation; legitimate clamping/reveal allowed |
| 28. Focus management and keyboard behavior | Traverse Tab/Shift+Tab and shortcuts inside text/modal contexts | Logical order, visible focus and scoped activation/restoration | Focused action works and is not obscured; text shortcuts remain local |
| 29. Status messages and feedback | Compare pending/success/failure messages with actual result | Derive from authoritative state; persistent recovery when needed | Correct announcement/count; no premature or duplicate success |
| 30. Loading, empty, offline and failure states | Use controlled slow/rejected/empty/partial inputs | Retain useful local content and provide contextual next action/retry | All terminal paths resolve honestly with preserved work |
| 31. Selection, bulk operations and drag-and-drop | Reorder/filter selected records; cancel drag; inspect bulk scope | Stable IDs, preview counts/consequences and non-drag alternative | Only intended records change; stale selections rejected safely |
| 32. Search, filtering and sorting | Compare indicators/query/results through zero matches and navigation | One query owner, reset route and stable sort semantics | Visible results/order match query; identity and saved view persist |
| 33. Lists, tables, trees and collections | Insert/reorder while scrolled; test empty/one/many/long items | Stable keys, lazy rendering and responsive columns/disclosure | Selection, traversal, row identity and final action remain correct |
| 34. Calendars, timelines and scheduling interfaces | Inspect day/week/month boundaries, overlap, today/selected and recurrence | Content-aware geometry; distinct task/event/session states and dates | Same occurrence opens; dense/large-text data stays accessible |
| 35. Task management and productivity workflows | Create/edit/subtask/recur/complete while timer or plan exists | Preserve independent dates, work, dependencies and explicit completion | Submitted/reopened task, recurrence and related records remain intended |

## Accessibility and platforms: 36–46

| # / category | Detect and evaluate | Correct when confirmed | Verify |
| --- | --- | --- | --- |
| 36. Responsive and adaptive layouts | Resize around breakpoints, short height, insets and large text | Content-driven flex/bounds; preserve state between branches | Essential content/actions and draft survive live resize/rotation |
| 37. Mobile-specific interface issues | Exercise touch, IME, Back, gestures, rotation and recreation | Apply safe/keyboard insets once and mobile navigation/target conventions | Real device IME/Back plus widget response; distinguish evidence |
| 38. Windows and desktop-specific interface issues | Resize/minimize, switch monitors/DPI, open auxiliary menus/windows | Correct owner/work-area conversions, focus and retained geometry | Native Release/self-test plus relevant physical shell/input/DPI checks |
| 39. Web-specific interface issues, where applicable | Determine actual shipped web surface before browser checks | Correct supported engine/viewport/history/semantic behavior only in scope | Supported browser/zoom/input matrix; mark N/A for native-only app |
| 40. Keyboard, mouse, touch and alternative inputs | Try each supported input, hover fallback, drag cancel and text shortcuts | Equivalent access and deliberate gesture/hit-test ownership | One intended action and correct record for each input |
| 41. Accessibility and visual perception | Measure contrast; inspect scale, high contrast and color-only states | Legible semantic colors, reflow, non-color indicators, adequate targets | Applicable contrast/geometry criteria and actual customized themes |
| 42. Accessibility semantics and assistive technology | Inspect names/roles/values/order/live errors with available reader | Semantic controls, concise names, proper grouping and announcements | Semantics tests plus named real reader checks; no universal compliance claim |
| 43. Localization, internationalization and RTL | Use supported long translations, mixed-direction IDs and local formats | Directional geometry, isolated IDs, locale formatting/plurals | Read order and canonical date/number round trip; unsupported locales explicit |
| 44. Animations and transitions | Reverse rapidly, enable reduced motion, interact during exit | Interruptible purposeful motion; disable invisible hit/focus regions | Intermediate frames and reduced-motion input remain stable |
| 45. Widgets, extensions and secondary interfaces | Inventory separate native renderers/configuration/closed-app states | Correct bounded projections, theme mapping, privacy and activation identity | Per-renderer native checks and launcher/shell acceptance separately |
| 46. Notifications, badges and system alerts | Repeat rebuild/resume; inspect count, target, permission and privacy | Deduplicate logical event; accurate state/count and contextual permission | Correct delivery attempt/target; actual OS delivery observed separately |

## Reliability and application state: 47–59

| # / category | Detect and evaluate | Correct when confirmed | Verify |
| --- | --- | --- | --- |
| 47. UI state management | Trace draft/store/projection/render with reordered async results | Correct owner, stable identity, subscriptions and stale-result guards | All consumers update; unmount/reopen does not leak or overwrite edits |
| 48. Settings and personalization | Change/preview/cancel/apply/reopen/restart; inspect local/portable scope | Persist atomically through existing store; preserve user choices | Immediate and durable consumers agree; malformed/newer inputs safe |
| 49. Cloud synchronization and multi-device behavior | Trace connect, edit, poll/resume, reconnect and manual status | Reuse rate-limited approved engine; distinguish local/pending/confirmed | Synthetic two-client convergence; live account/OS timing separately |
| 50. Conflict resolution UX | Review same/different records, defer, stale review, offline apply, replay | Counted explicit choices and durable causal decisions; no repeated modal | Acknowledged conflict stays resolved after propagated replay; new divergence shown |
| 51. Offline behavior and network interruptions | Cut controlled transport before/during exchange and retry | Retain local use/queue; backoff without success fiction | Local edits survive restart and eventual retry without duplicates |
| 52. Data deletion, archive, undo and recovery | Inspect selected scope, dependency consequences, restore and permanent delete | Honest confirmation/undo; transactional multi-record changes | Correct records restored/deleted; no reset fallback or silent rescheduling |
| 53. Backup, import and export UX | Exercise cancel, invalid/tampered file, staged restore and restart | Independent verified snapshots, clear scope/account/path and Before Restore | Snapshot integrity/round trip; retained current profile on failure |
| 54. Privacy, security and trust | Inspect lock/logout, screenshots, widgets, clipboard, logs and permissions | Gate protected content and explain actual protection/consent | No secret leakage in evidence; lock is not claimed as data encryption |
| 55. Authentication and account management | Deny/revoke/sign out/switch account; compare identity with workspace | Pin approved account/scope, safe reconnect and actual unlock requirements | No mixed-account upload; Google sign-in alone never unlocks private data |
| 56. Performance and perceived responsiveness | Measure input/scroll/startup/theme work on realistic data | Remove measured hot-path work; honest progress, bounded rebuilds | Equivalent profile/release traces and unchanged outcome |
| 57. Crashes, freezes and fault recovery | Interrupt controlled write/startup/setup and reopen | Durable resumable state and actionable recovery; never erase data | Restart preserves committed work and separates pending from success |
| 58. Updates, migrations and version compatibility | Inspect unavailable/newer schema, interrupted download/upgrade and restart | Explicit compatible migration/recovery and verified candidate identity | Preserve profile/format/signing gates; actual upgrade evidence scoped to artifact |
| 59. Performance under unusual conditions | Large dataset/file, low memory/disk, slow device or OS throttling | Bound work, surface capacity errors, preserve queue/drafts | Controlled limits/recovery and measured worst relevant case |

## Advanced and engineering quality: 60–67

| # / category | Detect and evaluate | Correct when confirmed | Verify |
| --- | --- | --- | --- |
| 60. Multi-window and multi-instance behavior | Open same record across windows/worker; close main app | Profile-scoped ownership/leases and stale-write checks; explicit activation | No duplicate writer, wrong profile, focus theft or lost draft |
| 61. Platform and system integrations | Follow file/URL/deep link/tray/permission entry under lock/edit | Existing adapters, stable IDs, contextual failure and safe queue | Correct target/outcome and retained draft on actual platform |
| 62. Date, time, numeric and measurement UX | Probe midnight/DST/zone/clock, locale units and extreme values | Separate date-only from instants; accurate local formatting and units | Canonical round trip and readable boundary values without invented work |
| 63. Error prioritization and recovery | Trigger concurrent failure/conflict/pending states; inspect action priority | Most actionable blocker first; retained detail and targeted retry | Recovery reaches expected state without hiding another unresolved issue |
| 64. Automation and background-operation UX | Observe focus/resume/poll/worker opportunities and cancellation | Rate-limit, backoff and truthful opportunity wording; no forced interruptions | No duplicate work/modal storm; OS restrictions reported accurately |
| 65. Ethical and respectful design | Inspect consent, urgency, cancellation, support and attention demands | Neutral choices, no dark patterns or fabricated counts; respect quiet preferences | User can decline/exit and retains promised capability/data |
| 66. AI-agent-specific UI mistakes | Compare generated handlers, claims, scope and actual component consumers | Repair root cause; remove fake wiring/metrics; respect product decisions | Reproduce claimed fix and inspect diffs/evidence; no screenshot overfitting |
| 67. UI testing and verification failures | Compare assertions/fixtures/source/build/environment with claims | Tests observe outcomes, meaningful geometry and hidden states; preserve failures | Record commands, fingerprints, rerun causes, gaps; no silent golden replacement |

## Additional platform/local-first failure modes

These extend the inventory, not the product feature list. Load engineering or
local-first references only for applicable boundaries.

- **Flutter identity/composition:** reused editor with a new record, index keys,
  lost IME composing range, post-dispose callbacks and PageStorage value-type
  collisions. Probe live record switch and typing through rebuild; fix ownership,
  keys/disposal/storage buckets; verify retained draft/cursor and no exceptions.
- **Flutter environment:** nonlinear Android text scaling, double-consumed IME
  insets, hidden focus after expansion and an invisible animated hit target. Test
  short viewport + large text + error together, not just each axis alone.
- **Windows coordinate/ownership boundaries:** Explorer child HWND versus owned
  editor, monitor work area, physical/logical conversion, closed-main focus and
  profile-scoped IPC. Native physical checks remain necessary after host passes.
- **Android projection/capability boundaries:** stale RemoteViews, one-use widget
  completion tokens, locked/deferred navigation, OEM jobs/force-stop and process
  recreation. Verify revision/identity rejection and real launcher entry separately.
- **Local-first durability:** immutable generation replacement, concurrent reset,
  retained credential loss, offline conflict decisions, managed attachment digests,
  timer owner handoff and local-only preference allowlists. Trace real protocol;
  never derive trust or merge order from UI wording/device wall clocks.

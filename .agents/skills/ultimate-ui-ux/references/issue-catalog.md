# Issue catalog: 28 categories, symptom -> preferred fix

This is a **broad practical catalog, not literally every possible UI defect**. Treat all lines as hypotheses to verify in the running product. In each category audit default, long content, empty, disabled, loading, failure, theme variants and keyboard/touch if relevant. Prioritize actual user harm and product context over stylistic preferences.

## 01. Visual hierarchy and typography

- Headings, labels, notes and body all look identical -> define a semantic type scale and enforce heading/body/label/caption tokens.
- Everything bright white or bold -> lower emphasis of supportive text while preserving readable contrast; reserve strongest weight for priority information.
- Title too small or text too large -> tune visual hierarchy and density by screen purpose and viewport.
- Font size/style varies across identical controls -> route typography through shared styles/components.
- Small captions/labels hard to read -> increase size or contrast; validate actual display at zoom/text scale.
- Poor line height or long line length -> adjust line height and text measure for reading comfort.
- Awkward word breaks, orphan text or truncation -> wrap naturally, set minimum widths to zero, use intentional ellipsis with full-content access.
- Wrong font weights or missing glyphs -> ensure supported font files/fallbacks, weights and language coverage.
- Inconsistent casing and typography punctuation -> standardize content style according to product language guide.
- Repetitive labels, empty intros, excessive helper text -> remove unnecessary prose; use concise task-specific copy.
- Numeric alignment inconsistent in tables -> use tabular numbers/alignment where comparable values demand it.
- Accessibility text sizing breaks visual balance -> use flexible sizing and reflow, not fixed-height text boxes.

## 02. Spacing, alignment and sizing

- Uneven gaps/margins/padding -> use a consistent spacing scale with semantic layout groupings.
- Misaligned icon, label, checkbox or controls -> align to optical/typographic baselines and shared control heights.
- Cards and form rows have different widths for no reason -> adopt layout grids and consistent columns.
- Nested cards and borders create visual clutter -> simplify hierarchy and remove unnecessary containers.
- Buttons too close, too far apart or inconsistent -> standardize grouped control spacing and priority.
- Titles too close to body or sections excessively separated -> tune heading-section rhythm and density.
- Content not centered or stretched too wide -> use appropriate content max width and fluid gutters.
- Different corner radii/border weights -> unify component tokens, preserving semantic exceptions.
- Text/validation appearance shifts layout -> reserve space where needed or manage placement without obscuring content.
- Fixed dimensions clip translated text -> prefer min-height, intrinsic sizing and wrapping.

## 03. Color, themes and visual consistency

- Text blends into background -> adjust semantic text/surface tokens and measure contrast.
- Too many colors, inconsistent status meaning -> define restrained palette and semantic statuses.
- Every action has the same emphasis -> establish primary/secondary/tertiary/danger action treatment.
- Hard-coded theme colors -> replace with theme-aware tokens.
- Light/dark mismatch in dialog, scrollbars, overlays, charts -> test shared components in all supported themes.
- Hover/press/selected/disabled colors wrong -> define and test all interaction-state variants.
- Theme-switch flicker or color flashes -> synchronize initial theme and minimize unthemed frames.
- Too much gradient, glow or transparency -> use depth and accents with purpose; preserve readability.
- Labels use opacity so low they become inaccessible -> adjust actual rendered contrast.
- Color customizations reset on restart -> persist theme settings and verify restoration.
- High-contrast system theme ignored -> support forced-colors or native high-contrast modes where applicable.

## 04. Responsive layout and density

- Layout only works at original screenshot size -> test representative widths/heights and orientation changes.
- Fixed width/height causes clipping -> use flex/grid constraints, intrinsic sizing, breakpoints and min/max bounds.
- Horizontal overflow appears accidentally -> identify overflowing child; avoid global hidden overflow as a band-aid.
- Desktop sidebar crowds mobile -> adapt navigation pattern while retaining critical functionality.
- Tables illegible on small screens -> use controlled horizontal scroll, priority columns or accessible alternate presentation.
- Dialog extends offscreen -> bound by viewport and make content scrollable with reachable action row.
- Tablet/foldable/ultrawide has dead space or stretched content -> define meaningful max widths and adaptive columns.
- CSS breakpoint changes too abruptly -> let content drive breakpoints, use fluid scaling where useful.
- Screen rotation loses state -> preserve UI model and recompute layout.
- Browser zoom/system DPI/text scaling breaks controls -> validate resizing/reflow and fix fixed dimensions.
- Notches, system bars, desktop window chrome obscure UI -> honor safe areas and window insets.

## 05. Overflow, clipping, layering and scrolling

- Clipped text/icon/border/shadow -> remove unnecessary clipping or size container correctly.
- Dropdown/tooltip clipped by ancestor -> manage portal/overlay placement and clipping contexts.
- Popup behind modal or overlay -> use deliberate stacking scale and correct layer/portal root.
- Sticky header covers targets -> account for sticky insets and scroll margin.
- Double/nested scrollbars confuse users -> establish one intended scroll owner per gesture.
- Scroll position resets when item updates -> preserve stable keys and scroll restoration.
- Last element hidden by fixed footer -> reserve bottom space/safe-area padding.
- Mobile keyboard covers action/input -> resize or scroll affected viewport and focus field into view.
- Wheel/gesture scrolls wrong container -> adjust scroll capture and nested scroll handling.
- Scroll snapping traps focus -> check keyboard scrolling and avoid aggressive snap behavior.
- Overflow hidden masks bugs -> fix the real source rather than silently hiding controls.

## 06. Buttons and interactive controls

- Clickable-looking element does nothing -> connect real handler, remove faux affordance if noninteractive.
- Wrong target/action -> verify identifiers and event routing end to end.
- Missing hover/focus/pressed/disabled state -> provide semantically distinct state styling.
- Mouse-only functionality -> implement keyboard activation and touch equivalents.
- Very small interactive target -> increase hit area without visual crowding.
- Double taps submit twice -> use idempotence/in-flight protection and correct loading state.
- Loading control never resolves -> handle success/failure/finally branches.
- Labels/icons ambiguous -> use explicit verbs and accessible names.
- Destructive action indistinguishable -> separate destructive emphasis and safeguards.
- Buttons move/resize on state change -> reserve content width or ensure stable control dimensions.
- Click-through from overlays -> enforce event handling and modal focus blocking appropriately.

## 07. Forms, inputs and validation

- Placeholder used as sole label -> add persistent associated label.
- Required field unclear -> label requirement and explain validation.
- Validation shown far from offending input -> inline error plus appropriate programmatic association.
- Incorrect input type/mobile keyboard -> configure email, numeric, phone, date, password as appropriate.
- Input loses typed draft on error/navigation -> preserve or explicitly warn about unsaved changes.
- Enter key performs wrong action -> fix form semantics, default button and keyboard handling.
- Bad focus or tab sequence -> follow meaningful visual reading and focus order.
- Password reveal/auth autofill broken -> use recognized autocomplete and tested reveal control.
- Number/date formats reject locale-valid data -> normalize input carefully and give understandable examples.
- Combobox, checkbox, radio, switch state wrong -> use proper controlled state and semantics.
- Client success despite server rejection -> synchronize displayed values with confirmed result.
- Validation only after submission, or nagging while typing -> choose appropriate touched/submit triggers.
- Error disappears too fast -> keep error until resolved or dismissed, announce to assistive tech.

## 08. Dialogs, drawers, popovers, dropdowns and tooltips

- Modal outside viewport -> constrain size, use inner scroll, keep dismiss/action reachable.
- Wrong popup anchor/direction -> collision detection, flip near viewport edges.
- Unwanted stacking of dialogs -> single owner/stack discipline, clear depth hierarchy.
- Overlay behind app content -> portal and stacking context fix.
- Escape/back/outside click wrong -> follow explicit dismiss policy, protect unsaved data.
- Background focus or clicks active during modal -> proper modal barrier and focus trap.
- Focus not restored on close -> restore focus to opener or sensible fallback.
- Dropdown closes while selecting -> correct blur/interaction handling.
- Tooltip blocks target, too verbose or lacks delay -> size/placement/copy adjustments.
- Scrollable dialog traps content -> distinguish dialog scroll from page scroll.
- Mobile sheet has unreachable close/actions -> safe area, gestures, and explicit exit.
- Dialog variants inconsistent -> reuse shared overlay component and tokens.

## 09. Navigation and information architecture

- Current location not visible -> selected nav/tab state and meaningful page title.
- Back button unexpectedly exits/loses work -> restore navigation history and unsaved-change guard.
- Broken deep links/reloads -> configure routes/state restoration and fallback.
- Too many menu levels -> flatten IA around user tasks and progressive disclosure.
- Related settings scattered -> reorganize sections according to user mental model.
- Tabs render wrong panel -> reliable state mapping and accessibility semantics.
- Filters, scroll, search reset on navigation -> preserve meaningful state where expected.
- Breadcrumbs missing in deep hierarchy -> add when location context materially helps.
- Navigation labels use internal engineering terms -> use user-goal vocabulary.
- Mobile nav hides primary capabilities -> adapt not delete essential navigation.
- Empty/dead-end screens -> add clear next action or recovery.

## 10. Icons, pictures, assets and data visualization

- Wrong icon conveys opposite meaning -> use clear standard icon metaphor and text if needed.
- Icons differ in size/weight/stroke or misalign -> standardize icon set, size and optical alignment.
- Blurry/damaged/missing assets -> correct density, paths, fallbacks and image format.
- Images stretched or badly cropped -> correct object-fit/aspect-ratio, art-directed crop if necessary.
- Placeholder imagery in final UI -> replace or explicitly note missing assets.
- Alt text missing/meaningless -> provide useful text for informative images; mark decorational as such.
- Chart conveys meaning only with color -> add labels, legend, texture/markers and textual data alternative.
- Chart axes/units/scale misleading -> label appropriately; verify data and ranges.
- Decorative asset increases load -> optimize/responsive-load and remove low-value artwork.
- Wrong branding/logo/favicon -> reference official assets and verify usage rights.

## 11. Lists, cards, tables and repeaters

- Repeated rows use different component styling -> unify reusable patterns.
- Sorting/filter UI disagrees with data -> synchronize derived state and visible indicators.
- No results gives blank panel -> intentional empty-state copy and reset action.
- Long names or numbers break rows -> clamp responsibly and offer full value on request.
- Columns misalign or become illegible -> responsive table layout and valid alignment.
- Duplicate item renders or reorders unexpectedly -> stable unique keys and source-of-truth updates.
- Too many rows cause lag -> paginate or virtualize with accessibility considered.
- Selection state unclear -> accessible selected state and visual distinction.
- Drag reorder unpredictable -> visible handle, feedback, correct persistence and alternative input.
- Pagination loses filters -> preserve query and page rules.
- Card content jumps on async load -> reserve relevant space, avoid fragile fixed heights.

## 12. Loading, empty, error and success states

- Infinite spinner or unexplained wait -> timeout/retry and useful status wording.
- Content shift when loading -> stable placeholders/min-height for critical regions.
- Error gives no recovery -> explain issue and provide targeted retry/action.
- Empty view looks broken -> describe state and constructive next step.
- Success toast shown before write succeeds -> only confirm after validated completion (or clearly label pending).
- Stale data displayed as fresh -> show refresh/sync status and conflict handling.
- Partial load treated as complete -> render partial state and appropriate placeholders.
- No offline message -> distinguish offline from generic failure and preserve offline actions if supported.
- Denied permissions have no guidance -> show reason and recovery path.
- Failure state disappears before comprehension -> keep relevant messages long enough.

## 13. Accessibility and inclusive interaction

- Contrast below applicable guideline -> measure actual foreground/background combination and correct tokens.
- Keyboard user cannot reach/operate control -> ensure semantic roles, keyboard handlers and focus order.
- Focus ring removed -> restore visible focus indication that survives themes.
- Icon-only action has no accessible label -> supply accessible name and state.
- Decorative content announced noisily -> hide decoration from accessibility tree.
- Dynamic success/error not announced -> use appropriate live region/native announcements.
- Incorrect heading hierarchy -> order semantic headings by document structure.
- Pointer-only/hover-only discovery -> add tap/keyboard path and clear affordance.
- Drag-only operation -> provide accessible alternative.
- Reduced-motion ignored -> respect OS/browser preference and avoid essential motion cues.
- High contrast/zoom/text enlargement fails -> design for reflow, correct hit areas, device assistive settings.
- No skip-to-content or repeated-navigation escape -> add when applicable.
- Modal focus leaks or traps incorrectly -> follow dialog focus lifecycle.
- Automated a11y scan passes but screen reader fails -> perform manual assistive technology checks.
- WCAG 2.2 target sizing nuance: 24x24 CSS px or adequate spacing/exceptions for 2.5.8 AA; prefer ~44x44 comfortable touch areas where feasible, not universally mandatory for AA.

## 14. Motion, transitions and feedback animation

- Excessive decorative motion -> remove motion without functional purpose.
- Slow common controls -> use short, responsive transitions appropriate to interaction frequency.
- Easing or origin feels wrong -> tune entrance/exit direction and transform-origin.
- Animation restarts under rapid input -> use interruptible transitions or correctly retargeted springs.
- Layout animation janks -> prefer compositor-friendly transforms/opacity where possible.
- Exit leaves invisible interactive element -> sync state and visibility/pointer behavior.
- App ignores reduced motion -> provide immediate or simplified alternatives.
- Theme transition flashes or flickers -> ensure consistent theme paint lifecycle.
- Keyboard-triggered frequent actions delayed by animation -> minimize or remove motion.
- Modal/dialog animation prevents interaction unexpectedly -> avoid blocking UI unnecessarily.

## 15. UX copy, terminology and instructions

- Generic CTA `Submit` when task unclear -> use specific action like `Save changes`.
- Action text and confirmation contradict -> maintain consistent verbs and outcomes.
- Error text is technical or vague -> translate into user intent plus recovery step.
- Excessive explanatory copy -> remove redundant words and prioritize scanning.
- Too few cues for complex behavior -> add targeted hint or inline guide where needed.
- Misleading or premature success -> base copy on confirmed state.
- Placeholder lorem ipsum or fake metrics -> replace with verified content or clear placeholders.
- Dangerous action wording ambiguous -> state object and consequence.
- Inconsistent capitalization/plurals -> adopt product voice and localization conventions.
- Truncation hides account/item identity -> expose full identifier when necessary and safe.

## 16. Localization, RTL and bidirectional text

- Arabic text misaligned/direction wrong -> set correct direction and logical CSS properties.
- Mixed English/Arabic numbers and identifiers scrambled -> isolate directional spans and test actual glyph ordering.
- Navigation arrows/icons do not mirror where expected -> direction-aware icons, avoiding flipping meaningful logos.
- Translation overflow -> allow flexible width and realistic long-string tests.
- Locale date/time/currency/number formats incorrect -> use locale-aware formatting and distinguish storage from display.
- Font lacks glyph support -> configure script-aware fallback.
- Hard-coded text remains untranslated -> move UI strings into localization resources.
- Plural rules wrong -> use locale plural categories, not English assumptions.
- RTL controls change meaning incorrectly -> check chronology, graph axes and directional semantics intentionally.
- Search/sorting doesn't match locale -> use appropriate collation and normalization.

## 17. Mobile-specific UI and UX

- Soft keyboard obscures field/CTA -> use insets, scroll to focus, appropriate keyboard avoidance.
- Status/nav bars overlap text -> use safe area and contrast-aware system bar styling.
- Back gesture unexpectedly quits -> handle navigation stack and unsaved states correctly.
- Wrong haptic/gesture behavior -> follow platform convention and avoid conflict with OS gestures.
- Landscape/foldable breaks layout -> test viewport/adaptive constraints.
- Long-press has no affordance/alternative -> clarify with accessible options.
- Touch targets too small or too close -> increase hit regions and spacing.
- Page loses state on background/resume -> persist relevant UI state and restore safely.
- Pull-to-refresh conflicts with nested scroll -> choose a single intentional gesture owner.
- App uses desktop interaction assumptions -> adapt controls to touch input and screen density.
- Reduced battery/performance conditions cause UI freeze -> profile release build on representative device.

## 18. Desktop-specific UI and UX

- Narrow window clips controls -> bound minimum sizes or adapt layout gracefully.
- Multiple monitors cause popup on wrong screen -> anchor positioning to owner window and display bounds.
- HiDPI changes icon/text alignment -> test device pixel ratios and scaling factors.
- Mouse/keyboard shortcuts conflict -> audit shortcuts and menu labels.
- Context menu missing or inconsistent -> implement platform-expected actions.
- Drag/drop ignores cancellation or invalid targets -> validate and provide clear drop affordance.
- Minimize/restore resets window state -> persist intended size, position and navigation.
- Widget cannot receive typing after main closes -> verify process lifecycle, focus ownership and text events.
- Always-on-top or desktop-widget visibility wrong -> test actual window-management semantics, not only code flags.
- Auxiliary window focus stolen unexpectedly -> correct activation and focus behavior.

## 19. Gesture, pointer and keyboard interaction

- Click activates two overlapping elements -> correct propagation, event target and hit test areas.
- Drag unexpectedly clicks -> separate thresholds and click suppression after drag.
- Double-click behavior inconsistent -> set clear single/double-click contract.
- Long press/swipe too easy to trigger -> tune gesture thresholds and undo.
- Right-click menu incorrect -> ensure contextual commands match selection.
- Hover-only control inaccessible -> add keyboard/tap equivalent.
- Selection highlight differs from underlying selection -> keep state model authoritative.
- Pencil/stylus or touchscreen interactions fail -> test supported pointer types.
- Mouse wheel scrolls wrong panel -> correct nested scrolling and focus.
- Shortcuts ignore focus in text input -> scope key handlers appropriately.

## 20. Notifications, toasts, banners and system feedback

- Toast blocks an important button -> move to safe location or avoid obstructing primary action.
- Multiple duplicate notifications -> deduplicate and batch related events.
- Error toast disappears too fast -> keep actionable errors or add persistent detail.
- Notifications claim save despite failure -> reflect confirmed backend status.
- Badge count inaccurate -> derive count from same data source as list.
- Notification link opens wrong item -> pass correct stable target/deep link.
- Dismissed banner returns forever -> persist appropriate dismissal semantics.
- Too many trivial confirms -> remove noisy messaging; use lightweight feedback.
- User cannot undo accidental reversible action -> offer undo and define expiry window.
- OS notification leaks sensitive info -> protect lockscreen and preview content.

## 21. UI state management and persistence

- UI displays stale record -> use correct state invalidation/refetch strategy.
- Settings appear saved but reset after restart -> persist atomically and test relaunch.
- Screens disagree about one value -> consolidate state ownership and update propagation.
- Undo/Redo looks right but model differs -> test replay and persistence semantics.
- Data disappears after refresh/navigation -> save drafts and restore intended state.
- Loading state stuck -> handle cancellation/failure/finally consistently.
- Optimistic update remains after server reject -> rollback with explanation.
- Concurrent requests overwrite newer result -> handle ordering, cancellation or versioning.
- Deleted item remains visibly active -> reconcile local cache and selected route.
- Multiple widgets diverge -> share a reliable store or reconciliation mechanism.

## 22. Perceived and actual performance

- Slow first render -> remove blocking dependencies, defer noncritical assets, profile startup.
- Input lag -> move expensive work off hot input path; debounce derived work when appropriate.
- Scroll stutter -> profile, virtualize lists and reduce unnecessary rebuilds/re-renders.
- Images delay content -> responsive media, compression, lazy-load below fold, intrinsic dimensions.
- Layout shift -> reserve stable size for asynchronously loaded content.
- Theme switching freezes -> minimize global costly repaint/layout and expensive recomputations.
- Long animation frames -> avoid layout thrash, expensive filters and unnecessary layout animation.
- Rapid repeated navigation floods requests -> cache, cancel or deduplicate when semantically valid.
- Memory growth from UI observers/controllers -> properly clean up listeners and controllers.
- Build succeeds but release feels slow -> profile production/release build, representative hardware and realistic data.

## 23. Privacy, safety and trust UX

- Sensitive data in notification or screen previews -> hide/mask sensitive fields and respect lock-state policy.
- Password field visible or autofill misuse -> use secure field implementation and correct autocomplete attributes.
- Logout leaves protected UI visible -> clear sensitive caches, screens and session state.
- Consent dialog misleading -> clear scopes, neutral choice design and honest consequences.
- Dangerous action immediately destructive -> confirmation/undo appropriate to severity.
- Private info shown in log/screenshot artifact -> sanitize records and testing evidence.
- Security warning visually buried -> make severity clear and actionable.
- Auth failure mimics success -> only show true confirmed authentication state.
- False loading progress / made-up metrics -> avoid deceptive representation.
- Permission request lacks context -> explain request at moment of relevant user intent.

## 24. Cross-browser and cross-platform differences

- CSS differs in Safari/Firefox/Chromium -> test supported engines and provide robust fallbacks.
- System controls/style differ -> test default widgets, focus, autofill and scrollbar behavior.
- Mobile viewport sizing wrong -> use modern dynamic viewport units and insets with fallback where needed.
- Touch hover sticks -> gate hover-only styles via pointer capabilities where appropriate.
- Different font metrics clip labels -> test actual OS/font rendering and allow flexible layouts.
- File upload/select differs -> test native picker and permissions on supported platforms.
- Orientation/scale differences -> verify adaptive layout and in-flight state preservation.
- Browser zoom/disability settings break UI -> support reflow and focus visibility.
- Unsupported browser API causes blank UI -> feature-detect and provide fallback/error.

## 25. Design system, component architecture and CSS quality

- Duplicated almost-identical components -> consolidate shared primitives and document variants.
- Scattered literal colors/sizes -> replace with semantic tokens where stable.
- Global CSS causes unrelated regression -> scope style rules and test shared consumers.
- Magic negative margins/offsets hide root cause -> fix layout model and constraints.
- Absolute positioning used for general layout -> use flex/grid/intrinsic sizing.
- Z-index escalates endlessly -> establish clear layer scale and portal strategy.
- Multiple UI libraries with conflicting styles -> minimize competing component systems.
- Style overrides accumulate -> delete stale rules and simplify source of truth.
- Theme changes don't reach component children -> pass semantic tokens through component boundary.
- Shared component edit unexpectedly breaks screens -> run component contract/visual regression tests.
- Design tokens proliferate with near duplicates -> audit token purpose and naming.

## 26. Extreme data, input and environment edge cases

- Single-character/very long name breaks layout -> use flexible min widths and overflow handling.
- Empty/null/missing data crashes screen -> provide safe rendering defaults and meaningful error/empty display.
- Huge/negative/unusual numeric values overflow -> robust formatting and constraints.
- Thousands of records freeze -> profile pagination/virtualization while preserving navigation.
- Unusual Unicode/emoji/RTL strings corrupt UI -> normalize only where semantically appropriate and test rendering.
- Network disappears mid-action -> preserve work, show actionable failure and retry safely.
- Large image/file fails silently -> enforce limits, show validation and progress.
- Two users/screens update same record -> conflict resolution or stale-state warning.
- Extremely slow device/OS accessibility size breaks view -> preserve essential actions and reflow.
- Rapid repeated input causes inconsistent state -> serialize or deduplicate operations appropriately.

## 27. UX architecture, cognitive load and discoverability

- Users cannot find key feature -> make primary tasks visible and navigation predictable.
- Too many equal-weight buttons/options -> establish one clear primary route, progressive disclosure.
- Related settings dispersed -> group by user tasks and mental model.
- Too many confirmations -> remove low-risk interruptions; keep protection for destructive actions.
- No onboarding for non-obvious core action -> concise contextual explanation and useful empty state.
- Long task requires unnecessary screens/clicks -> simplify flow and preserve state.
- Hidden swipe or hover has no fallback -> expose discoverable option.
- Settings names reflect internal implementation -> rewrite in user language.
- Default settings create frequent annoyance -> choose sensible defaults and test user journey.
- Inconsistent terminology makes app hard to learn -> maintain content glossary and naming consistency.

## 28. AI-agent-specific failure patterns

- Overfit a single screenshot -> test multiple viewport sizes, states, themes and content lengths.
- Fix one popup, break every popup -> test shared overlay primitives and all consumers.
- Replace correct code with untested rewrite -> prefer minimal root-cause patch and regression checks.
- Report passing tests not actually run -> provide exact test ledger; distinguish inferred/static/manual.
- Pretend controls work based on visual appearance -> execute real interactions and inspect state/data.
- Leave demo data/no-op handler -> verify production wiring and data path.
- Introduce new style for every feature -> honor existing system and centralize tokens.
- Use fragile hardcoded offsets -> prefer constraints and responsive layout primitives.
- Skip error/empty/slow states -> run state matrix, not just happy path.
- Modify all screens without reviewing impacted areas -> impact map and staged verification.
- Add intrusive motion/gradients in name of polish -> prioritize task, clarity, and coherent product identity.
- Claim all UI is perfect after unit tests -> state remaining unknowns and platform/device gaps.
- Re-run huge unrelated test suites after tiny changes -> follow existing test guidance, choose risk-based runs and document prior evidence.
- Silently replace product decisions with personal taste -> retain requirements; propose material redesigns explicitly.

## End condition

For each audited relevant category mark `PASS`, `ISSUE`, `NOT_APPLICABLE`, or `NOT_TESTED`. Do not substitute a global claim for an auditable inventory of screens, states, devices and flows. Even a perfect pass today does not preclude new bugs after later changes.

# Performance, Profiling & Resource Budgeting

This reference defines engineering rules for CPU, memory, rendering, and disk I/O efficiency in Todorbit, with specific constraints for 16 GB developer host environments.

---

## 1. Evidence-Based Performance Policy

- **No Speculative Optimization**: Do not add caching layers, object pools, parallel workers, or complicated data structures without profiler evidence demonstrating an actual bottleneck.
- **Hypothesis vs Measurement**: In audit reports and commit messages, clearly distinguish between:
  - *Measured Bottlenecks*: Backed by DevTools CPU flame charts, heap snapshots, or wall-clock benchmark numbers.
  - *Theoretical Observations*: Labeled as code inspection hypotheses or theoretical edge cases.

---

## 2. 16 GB Host Environment Constraints

The development machine has 16 GB of RAM. Exceeding available memory causes aggressive Windows swap paging or crashes during heavy compilation.

### Host Rules:
1. **No Concurrent Expensive Processes**:
   - Never run `flutter run`, Gradle Android builds, Inno Setup compiler, or `.NET` companion builds simultaneously.
   - Run verification commands sequentially (`tools/dev/verify.ps1` enforces sequential test execution with `--concurrency=1`).
2. **Dispose Heavy Processes**:
   - Do not leave Android emulators running in the background when performing Windows release builds or analyzer passes.
   - Clean ephemeral artifacts in `.buildlog/` when disk thresholds are approached, following `docs/STORAGE_MAINTENANCE.md`.

---

## 3. Flutter Rendering & Rebuild Efficiency

1. **Granular Rebuilds with Riverpod**:
   - Use `ref.watch(provider.select((s) => s.specificField))` rather than watching whole monolith controllers.
   - Isolate high-frequency animations and gesture feedbacks (e.g. dragging ghost preview) in dedicated sub-widgets or `ListenableBuilder` nodes so the surrounding day or week grid does not rebuild.
2. **Heavy Computations Outside `build()`**:
   - Date recurrence expansions, collision lane clustering (`CalendarLayoutEngine`), and filter matching MUST NOT execute synchronously inside widget `build()` methods.
   - Compute layouts in controllers or memoize them against stable inputs.
3. **Repaint Boundaries & Scroll Physics**:
   - Wrap complex custom-painted elements (such as timeline grid lines and time gutters) in `RepaintBoundary` to prevent canvas re-rasterization on adjacent widget updates.
   - Use `ClampingScrollPhysics` or `NeverScrollableScrollPhysics` deliberately to avoid unnecessary overscroll bounce calculations on dense grids.

---

## 4. Memory Leak Prevention & Lifecycle Hygiene

1. **Disposal Contracts**:
   - Every `ScrollController`, `TextEditingController`, `FocusNode`, `AnimationController`, `StreamSubscription`, and `Timer` instantiated in a `StatefulWidget` MUST be explicitly disposed or cancelled in `dispose()`.
   - In controllers (`CalendarInteractionController`, `AppController`), cancel all active timers (e.g. `_autoScrollTimer?.cancel()`) when gestures end or the controller is disposed.
2. **Image and Asset Retention**:
   - Evict cached images when switching large media/attachment previews to prevent unbounded memory growth.
   - Use bounded stream buffers for file synchronization downloads (`ResumableUpdateDownload`).

---

## 5. SQLite & Disk I/O Efficiency

1. **WAL Mode**: SQLite runs in Write-Ahead Logging mode (`PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL;`). Readers never block writers, and writers do not block readers.
2. **Batching Insertions & Updates**:
   - When importing, syncing, or restoring, use batch statements or chunked multi-row inserts (`insertAll`) inside a single transaction.
   - Never loop individual `customInsert` queries without an enclosing transaction.
3. **Indexed Queries**:
   - Ensure foreign keys and filter columns (`task_id`, `event_id`, `scheduled_date`, `updated_at`, `status`) are backed by covering indices.

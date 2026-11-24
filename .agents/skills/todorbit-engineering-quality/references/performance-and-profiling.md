# Performance, Profiling & Resource Budgeting

This reference defines engineering rules for CPU, memory, rendering, and disk I/O efficiency in Todorbit, with specific constraints for 16 GB developer host environments.

---

## 1. Evidence-Based Performance Policy

- **No Speculative Optimization**: Do not add caching layers, object pools, parallel workers, or complicated data structures without profiler evidence demonstrating an actual bottleneck.
- **Frame budget**: Compare Profile traces from the same fixture and viewport. Keep UI and raster medians, p95, p99, worst and missed-frame rates separate. Calculate misses from the captured display/engine refresh rate and note a mismatch or unavailable rate. Preserve raw traces for reproduction.
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

1. **WAL Mode & Zero-Data-Loss Durability**: SQLite runs in Write-Ahead Logging mode (`PRAGMA journal_mode = WAL; PRAGMA synchronous = FULL;`). Readers never block writers, and writers do not block readers. Explicit full durability (`synchronous = FULL`) is strictly maintained to guarantee zero data loss and prevent committed transaction loss during sudden power failure or OS crashes, prioritizing user data safety over synthetic write micro-benchmarks.
2. **Batching Insertions & Updates**:
   - When importing, syncing, or restoring, use batch statements or chunked multi-row inserts (`insertAll`) inside a single transaction.
   - Never loop individual `customInsert` queries without an enclosing transaction.
3. **Indexed Queries**:
   - Ensure foreign keys and filter columns (`task_id`, `event_id`, `scheduled_date`, `updated_at`, `status`) are backed by covering indices.

---

## 6. Startup & Idle Efficiency Patterns

1. **Single-Mount Startup Pipeline**:
   - Never call `runApp()` with an intermediate loading screen only to tear down the entire widget tree when initialization completes. Mount `LifeManagerApp` once; keep native splash active until the first meaningful frame renders.
2. **Preference Store Idempotency & In-Memory Caching**:
   - Cache decoded JSON in memory validated against `(stat.modified, stat.size)`.
   - Skip disk serialization (`_write`) if new content is byte-identical to existing content to prevent disk I/O thrashing and spurious file-watcher reload loops.
3. **Immutable Snapshot Schema Memoization & Mandatory Validation on Restore**:
   - Standalone SQLite snapshots (backups/archives) in `backups/` are immutable. Check filename timestamps (`auto-YYYYMMDD...`) and file stats before spawning isolates.
   - Memoize verified schema versions by `(path, modified, size)` so recurring backup listing checks incur zero isolate overhead.
   - **Crucial Rule**: Cached schema metadata must NEVER substitute for required backup integrity validation. Restore and import procedures (`scheduleRestore`, `applyPendingRestore`, `importSnapshot`) must always execute full `PRAGMA quick_check` and complete table schema validation in a dedicated isolate before replacing any live data.
4. **Scoped Tickers vs Root Rebuilds**:
   - Never attach high-frequency or 1-second `Timer.periodic` triggers to top-level scaffold/workspace states to update descendant timer badges. Descendant widgets (`CompactTaskTimer`) must own their own localized ticker and `setState()`.
5. **Targeted Viewport Refreshes**:
   - When navigating calendar months or moving time windows, update only affected window collections (`events`, `todayEvents`) rather than firing full-database queries for unrelated modules (habits, goals, templates, trash).

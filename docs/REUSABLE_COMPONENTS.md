# Reusable component assessment

Todorbit's MIT license supports reuse of project code. External packages
would also need to preserve third-party notices and comply with dependency
licenses. Each published API would need a versioning, support and security
maintenance commitment.

| Candidate | Current boundary and potential use | Decision |
| --- | --- | --- |
| Theme validation | [Theme JSON](../lib/domain/theme_json.dart) is pure Dart and validates the version 1 palette shape used by Flutter and native themes. It could help theme authors validate files outside Todorbit. | Best small candidate. Keep the in-app format as the source of truth. A future package should first specify version compatibility and malformed input behavior, and own fixture tests for valid and invalid imports plus downstream parity. |
| Shared Flutter controls | [Theme construction](../lib/features/shared/app_theme.dart) and shared controls carry Todorbit palette, platform and UI decisions. They are useful across the app's desktop and mobile shells. | Keep internal. A package needs examples, theme/focus/semantics contracts and light/dark/input coverage before other apps could rely on it. |
| Smart Reschedule | The [scheduling engine](../lib/domain/scheduling_engine.dart) is isolated from Flutter and SQLite but uses Todorbit's task, availability and recurrence models. The preview and apply flow also crosses application and repository boundaries. | Keep internal. A future consumer would justify designing a smaller input/output API with fixed-event, timezone, recurrence and user-confirmation tests. |
| Calendar interactions | [Calendar contracts](../lib/features/calendar/calendar_contracts.dart) isolate pure data and callbacks. Desktop [month rendering](../lib/features/calendar/calendar_month_view.dart) still uses Todorbit's presentation models, and Android uses its own touch view. | Keep the internal contract. Packaging requires decisions about visible ranges, date identity, editing callbacks and accessibility across desktop and touch. |
| Offline exchange | The [sync codec](../lib/data/cloud/sync_batch_codec.dart) depends on causal records, workspace keys, provider errors and a versioned persisted protocol. | Keep inside the application. External use would require compatibility vectors, version negotiation, threat modeling, and long-term security maintenance. |
| Backup and restore | The [backup codec](../lib/data/cloud/cloud_backup_codec.dart) uses cryptographic dependencies. Valid restoration depends on SQLite validation, profile isolation and the migration gate. | Keep the codec and restore orchestration under their current owners. Reuse would require authenticated format and recovery test vectors, review of local plaintext copies, and compatibility guarantees. |

The architecture checker enforces the in-repo dependency direction. See
[architecture](ARCHITECTURE.md) and the
[optional feature evaluation](OPTIONAL_FEATURE_MODULARITY_EVALUATION.md) for
constraints on broader modularity.

# P1 implementation route

Godot 3.x was the preferred external runtime for the first MVP, but no stable Godot CLI was available from the current shell:

- `godot`, `godot3`, and `godot3.6` were not found in `PATH`.
- A broad local executable search did not complete within the bounded probe window, so it was not treated as a stable development dependency.

The P1 MVP therefore uses a Python CLI with a pure data core. The core is intentionally written around plain `dict` and `list` values, stable JSON serialization, and no process-global game state. The migration boundary to GDScript is:

- `coach_core.engine.OfflineRuleEngine.analyze()` maps to a future GDScript `OfflineRuleEngine.analyze(snapshot_or_timeline: Dictionary) -> Dictionary`.
- `coach_core.loaders` is external-tool-only; future Brotato code should pass already captured dictionaries directly.
- `coach_core.deterministic` defines the canonicalization and fingerprint rules that must be ported byte-for-byte or replaced by a versioned fingerprint migration.

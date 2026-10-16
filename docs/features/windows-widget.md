# Windows widget

Investigate an integrated native companion that stays on the desktop under `Win + D` while ordinary windows may cover it. The companion must own its lifecycle independently of the main Flutter window. Verify desktop attachment manually on actual Windows, including Explorer restart, display changes, DPI, and multiple monitors. Undocumented shell behavior is a compatibility risk. Never claim `Win + D` support based only on automated tests. Do not change startup or registry settings without explicit approval.

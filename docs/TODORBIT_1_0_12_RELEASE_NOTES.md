# Todorbit v1.0.12 ? Windows x64 pre-release

- Improved shared form spacing and expansion sections so floating labels and the Task editor's optional-status subtitle stay readable.
- Aligned New/Edit checklist inputs and add actions; separated PIN fields and made Work Session actions wrap in narrow forms.
- Stabilized privacy restart test fixtures and completed a clean 245-test Flutter run without retries or relaxed timeouts.

The Windows installer and portable ZIP are unsigned. Compare downloads with `SHA256SUMS.txt`. Use the Pre-release update channel to detect this version; Stable ignores pre-releases.

Data paths, SQLite schema, installer identity, and update behavior are unchanged. Physical window resizing/DPI, Release GUI pixels, native widget interactions, Windows sign-in, registered installer upgrade/uninstall, and the exact in-app Update and Restart handoff still need manual acceptance. Do not infer those checks from automated tests or debug screenshots.

# Todorbit v1.0.10 — Windows x64 pre-release

This unsigned patch release corrects the order of controls in Settings > Software Updates.

The update action and collapsed Markdown Details now follow the existing automatic-check preference, Update Channel, and Check for Updates button. Download progress and update behavior are unchanged.

Automated analysis, Flutter tests, Windows Release builds, the packaged widget self-test, and package integrity checks passed. The Software Updates screen was inspected in an isolated debug profile. A registered installer upgrade and the in-app Update and Restart handoff remain unverified on an isolated Windows account. The installed app and personal profile were not changed.

Use `SHA256SUMS.txt` to check downloaded files. These packages are unsigned; a matching digest does not establish publisher identity.

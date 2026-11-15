# Todorbit 1.0.19-beta.20 — experimental

## Fixes

- Improve Android calendar widget date following. Choosing Today restores following; deliberate date browsing stays selected until you return to Today. Widget refresh scheduling remains inexact and may be delayed by Android.
- Make Today and the selected calendar day easier to distinguish, with a clear Back to today action.
- Improve Calendar responsiveness and rounded-card interaction feedback.
- Improve task details, organization fields, alarm form spacing and readable empty-state guidance.
- Clarify recurring-task actions and series-alarm wording, including retained occurrence overrides.
- Adapt calendar controls and headings to larger accessibility text without disabling scaling.
- Restrict Android widget refresh handling to its private receiver and recognized actions.

## Testing and known limitations

This is an experimental prerelease for testing through Todorbit's **Pre-release** update channel. Open Todorbit → Check for updates → review/download the update → install it normally. On Android, approve the system installer and reopen Todorbit afterward. Uninstalling the existing app is not required.

Physical-device acceptance remains pending for overnight Doze behavior, reboot recovery, installed Android upgrades, larger-text/IME/TalkBack behavior and affected Windows UI interactions. Remaining product-wide UI/UX audit coverage is incomplete. These are acceptance gaps, not a list of confirmed defects. Two application screens and an alarm component received scoped rendered review; this is not a claim that every screen was redesigned or visually inspected.

Windows packages remain unsigned. Android uses the existing production signing identity. Data/profile/package/widget identities, database schema and Sync protocol are unchanged. Existing Google Drive configuration and its documented acceptance limitations remain unchanged. Stable and previous releases are unaffected.

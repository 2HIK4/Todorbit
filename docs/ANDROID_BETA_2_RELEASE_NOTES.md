# Todorbit Android beta 2

**1.0.19-beta.2 (25)** — Android 8.0+; ARM64 and x86-64. GitHub pre-release,
not Stable or Google Play. Existing Windows releases and beta 1 remain unchanged.

## Smaller packages and recoverable updates

- Compatible phones receive the smaller ARM64 APK; x86-64 and universal packages
  remain available. All packages use the same version code and production signer.
- Software Updates now offers **Pause Download**, **Resume Download** and
  **Discard Download**. Saved bytes survive navigation, app restart and ordinary
  process termination. Network failures retain partial bytes for retry.
- Android may suspend downloads when locked/backgrounded or force-stopped.
  Reopen Todorbit and tap Resume; continuous background execution is not promised.
- Downloads resume with HTTP Range when supported. If a server requires a full
  restart, the screen explains it. Every completed/resumed APK must pass exact
  length, full SHA-256, package/version/architecture and installed-signer checks.
- Sizes and progress use familiar decimal KB/MB/GB, with percentage and measured
  speed. One MB means 1,000,000 bytes.
- Signing errors give clearer guidance. No signature bypass, automatic uninstall,
  data reset, synchronization or new account/telemetry system is introduced.

## Install or update

For a production-signed beta 1 installation: open **Settings > Software Updates**,
choose **Pre-release**, check, download and approve **Install Update** in Android's
normal installer. Beta 1 predates resumable downloading; the new controls become
available after installing beta 2. Stable excludes this release.

For manual installation, most physical phones should use
`Todorbit-1.0.19-beta.2-android-arm64.apk`. Use the x64 APK only on x86-64 devices.
The universal APK supports either ABI. Verify your APK against
`ANDROID-SHA256SUMS.txt` before opening it. Metadata JSON is not an installable app.
The private Play AAB is not included in public GitHub assets.

The unchanged production certificate SHA-256 is:

```text
00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99
```

An Android Debug installation normally cannot update directly to production.
**Do not uninstall to fix a signing error.** First export a full snapshot,
portable settings and attachments outside app-private storage, retain any recovery
passphrase, and verify restoration on a disposable installation. Only the owner
may then deliberately replace the installation and restore verified data.
Read-only signer diagnostics and recovery steps are in
[update recovery](https://github.com/2HIK4/Todorbit/blob/feature/android-mobile/docs/UPDATE_DOWNLOAD_RECOVERY.md).

## Beta limits

- Back up important data independently before updating or replacing/restoring it.
  Same-signer package updates preserve app data; uninstall removes private data.
- Physical phone/OEM lock/Doze behavior, ARM64 16 KiB devices, launcher resizing,
  reboot and TalkBack breadth remain limited/unobserved. Host tests do not prove
  these behaviors; please report the device, Android version and exact message.
- Google Drive remains optional snapshot backup/restore, not synchronization.
  Existing production authorization/encrypted recovery results are retained;
  no new OAuth acceptance is claimed. Windows/Android cloud discovery/restore
  remains unverified; use disposable data and external backups when testing it.
  Linked Windows file contents require separate copying/relinking.
- Existing Windows Pre-release checks can report that this Android tag has no
  verified Windows x64 package. Windows never selects an APK.
- This release requires all candidate CI, security and preservation gates before
  publication; the publication receipt will record observed results and limits.

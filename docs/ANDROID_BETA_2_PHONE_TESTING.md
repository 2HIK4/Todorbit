# Beta 2 physical-phone checks

Version `1.0.19-beta.2`, code **25**, package `io.github.hik4.todorbit`.
Use the official GitHub pre-release only after publication. Keep an independently
accessible backup before updating or restoring. These instructions never require
resetting the phone or changing Windows data.

## Choose and verify the APK

The [release page](https://github.com/2HIK4/Todorbit/releases/tag/v1.0.19-beta.2)
provides ARM64 (most supported physical phones), x86-64 and universal APKs.
The universal fallback supports either architecture and is larger. Android 8+
is required; 32-bit-only devices are unsupported. The metadata JSON and private
Play AAB are not APKs to install.

For a same-production-signer beta 1 installation, choose **Settings > Software
Updates > Pre-release > Check for Updates**, review beta 2, download and approve
Android's **Install Update** flow. Otherwise download the correct APK manually
and compare its exact file hash against `ANDROID-SHA256SUMS.txt`:

```powershell
Get-FileHash -Algorithm SHA256 '<downloaded-apk-path>'
```

## Identify the installed certificate without changing phone data

With Android SDK platform-tools/build-tools on your computer and USB debugging
authorized on the phone, choose its serial from `adb devices -l`:

```powershell
$phone = '<phone-serial>'
adb -s $phone shell getprop ro.product.cpu.abilist
adb -s $phone shell pm path io.github.hik4.todorbit
# Copy the base.apk path from the preceding output, omitting "package:":
adb -s $phone pull '<base.apk-device-path>' "$env:TEMP\todorbit-installed.apk"
apksigner verify --print-certs "$env:TEMP\todorbit-installed.apk"
```

These operations read the phone and copy its installed APK to the computer.
Compare **certificate SHA-256**, not APK file SHA-256. Production is:

```text
00226dad75ac907ac51c86df2c5011f0b6e2ce8291994103975f11a8eb574a99
```

`CN=Android Debug` with a different fingerprint identifies development signing.
Production cannot ordinarily update that installation in place. Do not uninstall
as a shortcut: export a full snapshot, portable settings and attachments outside
private storage; retain any encrypted-backup recovery passphrase; verify restore
on a disposable installation. Only then may you deliberately replace the debug
installation yourself and restore. Follow
[the backup-first migration procedure](ANDROID_PHONE_BETA_TESTING.md), step 2.
An unexpected certificate should be reported while keeping the app/data intact.

## Verify installation and preservation

Before updating, note representative task/event IDs or contents, managed
attachments, existing backups, preferences and widgets. After the system update,
reopen Todorbit, confirm **1.0.19-beta.2 (25)**, check those records and open an
attachment. Do not perform a restore to test ordinary package-update persistence.
Android installation-source permission can be revoked afterward if desired.

## Pause, Resume, lock and restart

Beta 1 has the old downloader. Updating beta 1 to beta 2 tests selection,
verification and installation; the new Pause/Resume controls are available
**inside beta 2 when a newer compatible official update is offered**. Beta 2
does not offer itself as an update. Do not install a debug build, fake metadata
or bypass version checks to force a download.

When beta 2 or later offers a newer official update:

1. Start downloading and note the downloaded bytes/total, percentage and decimal
   KB/MB/GB labels. Pause; verify the displayed saved amount stays above zero.
2. Leave Software Updates and return. Resume; bytes should continue from the
   saved amount where the server supports Range. A server-required full restart
   must show an explanation.
3. Lock for about a minute and reopen. Android may suspend the transfer; saved
   bytes should remain. Tap Resume if interrupted. Repeat by normally closing
   and reopening Todorbit. Force-stop can interrupt execution; it is not promised
   to continue downloading while stopped.
4. Pause and explicitly **Discard Download**. Starting again should begin at
   zero. A connection failure alone must not discard valid partial bytes.
5. Let a resumed download finish. Install becomes available only after full
   verification; approve Android's installer normally. Never bypass checksum,
   signature, Play Protect or package compatibility errors.

Report the app version, device/Android version, exact non-secret error, before/
after byte counts and whether you paused, locked, restarted or lost connection.
Do not post personal database/profile files or account credentials.

## Widgets and Windows-created backups

Check each existing Tasks/Calendar widget: refresh after reopening Todorbit,
open the right record, and complete/reopen a disposable task. Widget actions
may open Todorbit and require unlocking; they do not silently write the database
while the app is stopped. Record OEM launcher/resizing/reboot behavior separately.

Windows/Android Google Drive interoperability is explicitly owner-deferred.
Start with disposable Android data and an external Android backup. Use the same
account that owns the Windows snapshot, refresh cloud backups, inspect the
Windows backup's timestamp/source and decrypted preview, and restore only after
reviewing the replacement target. Confirm Before Restore and successful reopen;
compare records, settings and managed attachments. Follow steps 4–10 of
[the Windows-backup acceptance procedure](ANDROID_PHONE_BETA_TESTING.md).
Linked Windows file contents need separate copying/relinking. This is snapshot
recovery, not two-way synchronization. Do not delete existing cloud backups or
change the Windows installation to troubleshoot discovery.

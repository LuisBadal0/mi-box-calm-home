# Automatic setup

This mode performs the fixed scope below without asking for approval before each change. Use [FRESH-BOX-SETUP.md](FRESH-BOX-SETUP.md) for individual approvals. Supported target: **MIBOX4, Android 9 / API 28, user 0** on a private LAN IPv4 address.

## Start

Extract this repository, install PowerShell 7, and extract Google's official `platform-tools` beside the installer. Enable USB/network debugging on the TV and keep it awake on its HDMI input. Replace the example IP:

```powershell
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20
```

The installer connects and waits up to 180 seconds for authorization. On the TV, select **Always allow from this computer > Allow** in **Allow USB debugging?**. Android uses that dialog for this Wi-Fi ADB connection too. Trusted connections continue immediately. Add `-AuthorizationWaitSeconds 300` for five minutes; range 1-900 seconds.

No dialog? Open Settings > Device Preferences > Developer options, toggle USB debugging off/on and enable network debugging if there is a separate option. Menu names vary. Confirm the IP and same local network. Debugging previously closed by setup must be re-enabled on the TV. A different computer/debugging key needs its own approval. The installer does not revoke authorizations, replace keys, kill the shared ADB server or bypass Android/Play Protect prompts. An authorization timeout stops before app/settings changes.

Optional commands:

```powershell
# Inventory and settings snapshots only; no APK export/install/grant/reboot.
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20 -PlanOnly

# Close Wi-Fi ADB after successful setup/persistence checks.
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20 -CloseWifiDebugging
```

`-AdbPath`, `-ApkPath`, `-BackupRoot` and `-Port` can override locations/port. The APK must match the exact SHA-256 in BUILD-INFO.json and the installer. The included APK is at `calm-home.apk`.

## Authorized scope

1. Check the model/API/current user, original Home, protected packages and original settings. Stop on Projectivy, unexpected Home, unsupported models or a different existing Calm Home build.
2. Create a separate journal, original settings/package snapshots, English app inventory and initial memory reading. Unknown apps are kept enabled. Save readable installed APKs and their checksums/error records before setup changes; this can take several minutes.
3. Install version **1.1-most-used** (`com.luisbadalo.calmhome`) if absent. Skip installation when the same reviewed build is already enabled.
4. Enable **Usage Access** for Calm Home using `appops set --user 0 com.luisbadalo.calmhome GET_USAGE_STATS allow`, unless already allowed. Record the original mode and exact undo command. This is the only new special access; accessibility/device-admin are not granted. Verify the mode before replacing Home.
5. Open Calm Home and verify the real foreground, clock, Play Store, Settings and All apps (Definições and Todas as apps on a Portuguese TV); save a screenshot. The installer passes no app list: the row starts in the automatic most-used mode, and the viewer can later pick their own apps on the TV with Choose apps.
6. Disable only exact Xiaomi analytics (`com.miui.tv.analytics`) if present/enabled.
7. Select Calm Home as preferred and test the real Home button from Settings. Only if the confirmed competing app is `com.google.android.tvlauncher`, disable that launcher while keeping it installed, then test again. Do not disable other Home/setup/input services.
8. Set the three animation scales and screensaver to 0, skipping values already 0. Preserve original sleep/screen-off times, keyboard, Bluetooth, HDMI, accessibility and protected Google services.
9. Record RAM immediately before restart; restart only if setup changes occurred. Confirm a new completed boot, preserve original packages/protected settings, confirm Usage Access and Home work, save a final screenshot and record RAM afterward. A matching fully configured rerun skips settings changes and restart.
10. Write per-box `journal.json`, `UNDO.md`, `APP-INVENTORY.md`, CSV, settings snapshots, readable APK backups and screenshots under `tv-backup/`.

## App row

The row contains up to six launchable apps. **Choose apps** on the TV switches between two modes:

- **Most-used apps (automatic)**, the default after setup: apps ranked by Android-reported foreground time aggregated over the last 30 days. Android keeps daily records for about ten days and summarizes older days into weekly or monthly records, so the window edges are approximate. Recent usage breaks duration ties. It is a local ranking, not exact screen-time accounting.
- **Apps I choose**: up to six installed apps ticked by the viewer, shown in the order picked. Chosen apps that disappear are skipped, not replaced.

Installed and preinstalled apps are eligible; Home launchers, Play Store, Settings and TV-input tools are excluded. The row refreshes on return Home and package changes. All apps remains available for opening anything outside the row. In the automatic mode, with no recorded usage, local launches then alphabetical order fill the row; without Usage Access, only launches from Calm Home can influence ranking. No missing apps are downloaded, accounts copied or VPN permissions granted.

The interface is in Portuguese when the TV's language is Portuguese and in English otherwise.

Usage Access reveals app-use metadata to Calm Home. It has no Internet permission, uploads nothing and runs no tracking service. Restore the original app-op mode with the per-box undo command to revoke the new access. A later automatic setup invocation will enable it again because that is part of this mode's stated scope.

## Failure and undo

Unexpected errors stop setup and are recorded. If the box originally used stock Google Home and setup fails, recovery attempts to restore that launcher's original enabled state/preference and open it, then restore animation/screensaver values changed by the run. Any Usage Access grant is restored to its original mode. Calm Home stays installed and Xiaomi analytics stays disabled. Recovery cannot finish while the box is unreachable; inspect the journal and use its undo instructions after reconnecting.

Re-enable/open/verify the original Home before disabling Calm Home. Keep each box's own originals. Backups are not firmware, account or private app-data recovery images. No uninstall, data clear, root, flash, certificate or accessibility/admin grant is included.

With `-CloseWifiDebugging`, the installer switches ADB to USB mode after all checks succeed and checks the wireless port is closed. USB debugging and previous authorizations are not revoked. Re-enable debugging on the TV for later network management.

Version 1.1 was built and signature/alignment checked, and its ranking/installer paths were checked locally. The new ranking/Usage Access flow has not yet been exercised on a physical TV. No tests or device logs are included in this repository.

For an agent prompt that authorizes this same scope, use [REPLICATE-NO-PROMPTS.md](REPLICATE-NO-PROMPTS.md).

# Automatic setup — no confirmation prompts

This optional mode implements the user's request to repeat the successful setup **without asking for approval at every step**. Running the installer authorizes only the fixed actions below on the explicitly supplied new-box IP. The original guided workflow is still available in FRESH-BOX-SETUP.md; its per-step confirmation instructions do not apply inside this deliberately chosen automatic mode.

## Run it

Extract the whole kit on Windows. Use **PowerShell 7** (`pwsh`). Place Google's official `platform-tools` folder beside the kit files, or provide its adb.exe path. Keep the TV awake and select its HDMI input before running. The installer connects, prints the authorization instructions, and waits up to **3 minutes** for you to accept the TV's debugging dialog. It continues automatically once authorized; no need to rerun just because the first connection was unauthorized. Already trusted connections continue immediately. Android can also display a Play Protect installation prompt. This script cannot bypass Android authorization or protection screens.

Replace the IP with the **new** box's IP, then run from the kit folder:

```powershell
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20
```

There are no confirmation questions in this command. The IP above is an example, not a preset target. The script accepts only private LAN IPv4 addresses and supports only the tested **MIBOX4 / Android 9 (API 28) / user 0**. It stops, rather than guessing, on unsupported devices or conflicting existing configurations. Do not run it against the first box merely to prepare another one.

To also close Wi-Fi ADB automatically **after** all setup/persistence checks succeed:

```powershell
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20 -CloseWifiDebugging
```

That switches ADB to USB mode and checks that the wireless TCP endpoint is no longer reachable. It does not revoke other computers' debugging authorizations or switch off USB debugging. Calm Home keeps working; wireless management requires re-enabling network debugging on the TV later. Without this flag, debugging is left available and noted in the report.

### What to select on the TV

When **Allow USB debugging?** appears, select **Always allow from this computer**, then **Allow**, using the TV remote. The dialog can say USB even though this connection uses Wi-Fi. Android requires physical acceptance of its authorization dialog: [official Android debugging documentation](https://developer.android.com/studio/run/device).

If no dialog appears and the console says unauthorized, open **Settings > Device Preferences > Developer options**, toggle **USB debugging** off/on, and enable network debugging if the box has a separate option. Return to the TV screen; the installer keeps checking. Menu names can vary. Do not revoke all authorizations or delete computer keys. If debugging was closed by an earlier setup, enable it again on the TV before connecting. A command run yourself may use a different debugging key from the earlier Codex session and therefore need a fresh approval.

To allow more time, append `-AuthorizationWaitSeconds 300` (five minutes; default 180, supported range 1–900). If it times out, it stops before installing apps or changing TV settings, with instructions to retry. These are instructions for the tested Android 9 box; newer Android wireless-pairing workflows are outside this kit's supported scope.

For an optional read-only plan, without installing, disabling, configuring or restarting anything:

```powershell
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20 -PlanOnly
```

In the original project, files are found automatically under tools/platform-tools and tv-detox/out. Elsewhere use `-AdbPath C:\path\to\adb.exe -ApkPath C:\path\to\calm-home.apk`. The reviewed APK checksum must match; automatic mode will not replace it with a download or rebuild.

## What it does automatically

1. Confirms the device model, API/current user, current Home and protected components. Creates a new per-box timestamped journal, settings/package-state baseline, English app inventory and memory reading. Unknown apps are marked uncertain and kept enabled.
2. Copies readable installed APKs to that box's backup folder and records SHA-256/error details. It does not request interactive private-data backups, copy accounts, root, flash or promise a full firmware recovery image.
3. Installs only the reviewed Calm Home APK, or skips it if the same build is already installed/enabled. A different existing APK or disabled Calm Home stops automatic mode. Existing Projectivy also stops this fresh-box workflow; it is not silently migrated or uninstalled.
4. Opens the app with the six selected banners on a new installation. Already-existing Calm Home preferences are preserved. Missing user apps are reported and skipped; their APKs/accounts/VPN permissions are not installed or granted automatically.
5. Verifies the real foreground app, clock, Play Store and Settings through Android's UI hierarchy and saves a screenshot before attempting to replace Home.
6. Disables Xiaomi analytics if that exact package exists and is not already disabled. No other optional apps are disabled.
7. Selects Calm Home as preferred and tests Home from Android Settings. Only if the confirmed competing app is `com.google.android.tvlauncher`, it disables that launcher, keeping it installed, and retests. It does not disable other HOME candidates or setup/input services.
8. Turns off the three animation scales and screensaver, skipping settings already at 0. Preserves the box's original sleep/screen-off values, accessibility configuration, keyboard, Bluetooth and HDMI state.
9. Records RAM immediately before reboot, reboots when persistent setup changes were made, confirms a new completed boot, and verifies Home/packages/protected settings and RAM afterward. A rerun of an already-completed setup skips persistent changes and the unnecessary reboot.
10. Saves `journal.json`, `APP-INVENTORY.md`, `inventory.csv`, APK backups, screenshots, memory readings and **per-box UNDO.md** under `tv-backup/unattended-<IP>-<timestamp>/`. Optional debugging closure runs only after verification.

## Failure and rollback

Unexpected cases stop and write the exact error. If a Home switch fails on a box originally using stock Google Home, the installer attempts to restore that launcher's original enabled state, preferred entry and screen, and reverts animation/screensaver settings it changed. It keeps Calm Home installed and keeps Xiaomi analytics disabled. Recovery cannot complete if the box/network is unreachable; use the recorded per-box undo when access returns.

No uninstall, app-data clearing, accessibility/admin grant, root, certificate installation or broad package-disabling command is included. Review the script if you want to change its scope. Do not apply the first box's original settings/undo log to a new box.

The mode has offline mock tests for read-only planning, normal setup/reboot, skip-on-rerun, failed-Home rollback, unsupported-device refusal, authorization waiting and authorization timeout. A real second MIBOX4 setup was completed on 19 October 2026: Wi-Fi ADB dropped during backup and again during post-reboot verification. After reconnecting, separate checks confirmed the completed setup and wireless port closure. The new authorization-wait behavior is tested with the offline adapter; physical network/debugging/Play Protect behavior still depends on the device.

## Agent prompt without confirmations

Use REPLICATE-NO-PROMPTS.md, supplying the new IP. That prompt explicitly authorizes this fixed workflow and asks the agent to report a blocker rather than invent broader changes or repeatedly ask for confirmations.

# Guided setup on a Xiaomi Mi Box

This guide asks before each TV change. For the explicitly chosen no-confirmation mode, use [AUTOMATIC-SETUP.md](AUTOMATIC-SETUP.md). The automatic installer supports **MIBOX4 / Android 9 / API 28 / user 0**; do not infer support for a different box.

Use the repository's **Calm Home 1.1-most-used**, package `com.luisbadalo.calmhome`, versionCode 2. Expected APK SHA-256:

```text
A5F9826B19B0CC0A538247BCC9233148A7610A7A75ACC5DC7C71380B8D5F2B3B
```

The UI has a clock/date, dark orange-to-black background, up to six automatically ranked apps, and separate Play Store, Settings and All apps buttons. No apps.txt or saved app list is used. Usage Access reads Android app-use metadata for ranking; there is no Internet permission or accessibility service.

## 1. Connect to the explicitly selected box

Download Google's [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools) and extract `platform-tools` beside the installer. Keep the computer and TV on the same trusted LAN. On the TV, open Settings > Device Preferences > About, press Build seven times, and enable USB debugging plus network debugging if separately exposed. Ask before these changes when assisting the user.

Keep the TV awake on its HDMI input. Set the target IP and explicit paths in PowerShell:

```powershell
$adb = (Resolve-Path .\platform-tools\adb.exe).Path
$apk = (Resolve-Path .\calm-home.apk).Path
$tv = '<NEW_BOX_IP>:5555'
if ($tv.Contains('<')) { throw 'Set the new box IP first.' }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $apk).Hash -ne 'A5F9826B19B0CC0A538247BCC9233148A7610A7A75ACC5DC7C71380B8D5F2B3B') { throw 'Unexpected APK; stop.' }
& $adb connect $tv
& $adb -s $tv get-state
```

Accept **Always allow from this computer > Allow** on the TV's debugging dialog. The dialog can say USB over Wi-Fi too. If unauthorized, give the user time to approve before running shell commands. Do not delete keys or revoke other computers' authorizations. Confirm model, Android/API, serial and current user before mutations:

```powershell
& $adb -s $tv shell getprop ro.product.model
& $adb -s $tv shell getprop ro.build.version.sdk
& $adb -s $tv shell getprop ro.serialno
& $adb -s $tv shell am get-current-user
```

## 2. Inventory and backups before changes

The automatic installer's read-only mode saves a unique per-box baseline without installs, settings writes, access grants or reboot:

```powershell
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp <NEW_BOX_IP> -PlanOnly
```

Review every package in plain English. The categories are optional candidates, needed/protected or uncertain components, and user-facing apps. The catalog's categories describe app types, not proof of what someone uses. Unknown components stay enabled. Record original Home/preference and enabled states, animations/screensaver, keyboard, Bluetooth, HDMI, accessibility and sleep/screen-off values.

Before installation also export readable APKs into that box's backup folder using individually targeted `pm path`/`adb pull`, recording failures and SHA-256 values. A read-only plan does not export APKs. If supported and separately approved, save useful app configuration backups. These snapshots are not full firmware or private/account-data recovery images. Never import another box's settings/accounts.

Keep a change journal with original values and exact undo after every approved action. Do not bulk-disable optional apps. Preserve Google Play/services/framework, keyboard, Bluetooth/remote, HDMI/CEC/input, networking, settings, setup and uncertain vendor dependencies.

## 3. Install and enable usage ranking

Keep stock Home installed/enabled during the trial. Do not install Projectivy. After approval for installation:

```powershell
& $adb -s $tv install $apk
```

Before granting Usage Access, explain that it lets Calm Home read which apps were used and their foreground time. Ranking is local; it sends nothing online. Ask for approval and record the existing app-op mode:

```powershell
& $adb -s $tv shell appops get --user 0 com.luisbadalo.calmhome GET_USAGE_STATS
```

For a fresh installation, no recorded operation means `default`. Record an explicit existing mode exactly; stop if it cannot be identified. After separate approval:

```powershell
& $adb -s $tv shell appops set --user 0 com.luisbadalo.calmhome GET_USAGE_STATS allow
```

Undo is the same command with the recorded original mode, commonly `default`. Do not use a broad appops reset. Alternatively, the user can select **All apps > Usage access > Open settings** in Calm Home and enable its access, if the firmware exposes that screen. No accessibility/admin/root/overlay permission is needed.

After separate approval, open and test the launcher:

```powershell
& $adb -s $tv shell am start -n com.luisbadalo.calmhome/.MainActivity
```

Check the real TV picture, date/clock, app row, Play Store, Settings, All apps and D-pad links. The row uses Android daily usage totals for the requested last 30 days, with recent usage for ties. Installed/preinstalled launchable apps are eligible; other launchers and utility/input entries are excluded. Do not configure six package names. If history is empty/short, local launches and alphabetical order provide a fallback. With Usage Access denied, only launches from Calm Home can be counted. Explain this instead of claiming existing usage was detected.

## 4. Analytics and preferred Home

After separate approval, disable only verified Xiaomi analytics if present/enabled:

```powershell
& $adb -s $tv shell pm disable-user --user 0 com.miui.tv.analytics
```

Keep it installed and record its original enabled state for exact undo. Do not guess a different analytics package or disable other optional services.

After separate approval, select Calm Home and test the actual Home button from Settings:

```powershell
& $adb -s $tv shell pm set-home-activity --user 0 com.luisbadalo.calmhome/.MainActivity
& $adb -s $tv shell am start -a android.settings.SETTINGS
& $adb -s $tv shell input keyevent 3
```

If stock Home wins, identify the exact competing package. Only after a successful Calm Home trial and separate approval, disable **com.google.android.tvlauncher** if that is the confirmed competitor; keep it installed and record its original state. Retest Home. Never disable every Home candidate or setup/input services.

## 5. Animations, screensaver and restart

Ask separately before each change to the three global animation scales (`window_animation_scale`, `transition_animation_scale`, `animator_duration_scale`) and secure `screensaver_enabled`. Set approved values to 0, skipping those already 0. Save absent settings as absent, so undo can use `settings delete`. Preserve this box's original sleep/screen-off values; do not set five-minute sleep.

Ask before restart. Capture `/proc/meminfo` and boot ID immediately before; restart, reconnect, confirm a new boot with `sys.boot_completed=1`, then record RAM again after startup. Verify real Home, Usage Access, original apps present, only intended disabled packages, protected settings/services and unchanged sleep times. Show available RAM and completely unused RAM; readings fluctuate and do not establish a speed benchmark.

Save screenshots, final report and per-box undo. Finally offer to close Wi-Fi debugging, explain that remote management will end, and ask before `adb -s <target> usb`. Verify the wireless port closes. Revoking previous authorizations is a separate action.

## 6. Undo and upgrades

Restore/re-enable the original Home using its own recorded component/enabled state, open and verify it, then optionally disable Calm Home. Keep apps installed. Restore Usage Access's original app-op mode, animations/screensaver originals and any other documented change. During a launcher-only rollback, keep Xiaomi analytics disabled. Debugging may need to be re-enabled on the TV first.

The automatic installer stops on a different existing Calm Home APK. For a deliberate update from the previously supplied version 1.0, first back up its APK/state and approve the change, verify the new APK hash, then use `adb -s <target> install -r <path-to-new-apk>`. This preserves app data and requires the same signing certificate. Version 1.1 drops the saved fixed-list preference and ignores old `--es apps` extras. Grant Usage Access as above, then open/test the new UI. A release APK downgrade may be blocked by Android; do not promise a simple old-APK reinstall, uninstall or clear data to force rollback. Stop for review if installation/signatures or recovery are unexpected.

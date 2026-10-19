# Repeat this setup on a fresh Xiaomi Mi Box

**Choose a mode:** this document describes the guided, confirmation-based workflow. For the explicitly requested **no-confirmation alternative**, use `AUTOMATIC-SETUP.md`, `Install-CalmHome-Unattended.ps1` and `REPLICATE-NO-PROMPTS.md`. That fixed-scope mode replaces per-step confirmations only when deliberately selected; the TV's initial Android authorization still requires a tap.

This guide reproduces the **customized tv-detox / Calm Home setup**, not the temporary Projectivy setup. It was tested on a Xiaomi **MIBOX4 running Android 9/API 28**. Verify the new box's identity and firmware first; a similar model name does not establish identical packages or original settings.

Do not make any change to the already configured box while preparing another one. Every TV command must explicitly target the **new box's serial/IP**. Ask before each change, including installing, opening/configuring an app, changing Home, disabling a package, changing animations/screensaver, restarting, and turning off debugging. Skip steps already satisfied.

## Files to use

Download this repository using GitHub's **Code > Download ZIP** and extract it, or clone it onto the computer that will configure the new box. The repository contains the reviewed APK, this guide, the replication prompt, app list, checksums, launcher source and upstream MIT license. It contains no ADB keys, signing key, old TV backups, tests or third-party app APKs.

You can also use the existing project directly:

- APK: `tv-detox/out/calm-home.apk` (or `calm-home.apk` in the extracted kit).
- App: **Calm Home**, package `com.luisbadalo.calmhome`, version 1.0-local.
- Expected APK SHA-256: `C904CEE4AFE38284A0E94ADE2A0A218C89AC4AA0559B2054648A29E9C2F83C43`.
- Upstream source: https://github.com/Ansub/tv-detox at commit `4cdbf068c76d7bc5b5adc070c42b8f924cabcc0d`, with our local UI and safety changes.

**Downloading the unmodified GitHub release will not reproduce our custom version.** It also has a different package ID. Reuse this reviewed APK. For future code changes, preserve the private local signing key on the original computer; do not put it on the TV or in a shared kit. A new APK needs its own review and checksum.

The new home has a large live clock/date at upper left, fixed dark orange-to-near-black background, six app banners, and separate Play Store and Settings buttons. It has no HDMI shortcut row, ads, recommendations, network permission or accessibility service. Its focus changes are instant. The full Portuguese date-width fix is included.

## 1. Identify and connect to the new box

On the **new TV box**, note its IP under Network settings. In Settings > Device Preferences > About, press Build seven times if developer options are not already available. With approval, enable debugging in Developer options. Menu labels vary; some boxes expose a separate Network debugging switch.

Use the same trusted local network. Do not forward ADB through the router or expose it to the internet. Download Android Platform Tools for Windows from Google's official page if needed: https://developer.android.com/tools/releases/platform-tools . Extract its `platform-tools` folder beside these kit files. Git Bash and Java are not required to install the already-built APK.

In PowerShell, open the extracted kit folder or this project. Replace `<NEW_BOX_IP>` before running anything:

```powershell
$projectRoot = (Get-Location).Path
$adbCandidate = Join-Path $projectRoot 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbCandidate)) {
    $adbCandidate = Join-Path $projectRoot 'tools\platform-tools\adb.exe'
}
$adb = (Resolve-Path -LiteralPath $adbCandidate).Path
$apkCandidate = Join-Path $projectRoot 'calm-home.apk'
if (-not (Test-Path -LiteralPath $apkCandidate)) {
    $apkCandidate = Join-Path $projectRoot 'tv-detox\out\calm-home.apk'
}
$apk = (Resolve-Path -LiteralPath $apkCandidate).Path
$tv = '<NEW_BOX_IP>:5555'
if ($tv.Contains('<')) { throw 'Set the new box IP first.' }
$expectedHash = 'C904CEE4AFE38284A0E94ADE2A0A218C89AC4AA0559B2054648A29E9C2F83C43'
if ((Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash -ne $expectedHash) {
    throw 'APK checksum differs: stop and review this build.'
}
$env:ANDROID_USER_HOME = Join-Path $projectRoot 'private-adb-profile'
New-Item -ItemType Directory -Force -Path $env:ANDROID_USER_HOME | Out-Null
& $adb connect $tv
& $adb devices -l
& $adb -s $tv shell getprop ro.product.model
& $adb -s $tv shell getprop ro.build.version.release
& $adb -s $tv shell getprop ro.serialno
```

Accept the debugging authorization prompt on the new box. Confirm its identity with the user. Keep `private-adb-profile` private; it contains the computer's debugging credentials and must not be shared.

Existing project helpers such as `tools/tv_ui.py` and old change scripts can contain the **first box's hardcoded IP**. Do not reuse them on the new box without reviewing their target. Prefer explicitly targeted commands and a new journal.

## 2. Save a separate baseline and app inventory

Before changing TV settings, create a unique backup folder for this box. The following saves read-only evidence; these are not restoration commands:

```powershell
$snapshot = Join-Path $projectRoot ('tv-backup\new-box-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $snapshot | Out-Null
& $adb -s $tv shell getprop | Set-Content (Join-Path $snapshot 'device-properties.txt')
& $adb -s $tv shell pm list packages -f -U --user 0 | Set-Content (Join-Path $snapshot 'packages.txt')
& $adb -s $tv shell pm list packages -d --user 0 | Set-Content (Join-Path $snapshot 'disabled-before.txt')
& $adb -s $tv shell dumpsys package | Set-Content (Join-Path $snapshot 'package-details.txt')
& $adb -s $tv shell settings list global | Set-Content (Join-Path $snapshot 'settings-global.txt')
& $adb -s $tv shell settings list secure | Set-Content (Join-Path $snapshot 'settings-secure.txt')
& $adb -s $tv shell settings list system | Set-Content (Join-Path $snapshot 'settings-system.txt')
& $adb -s $tv shell dumpsys package preferred-xml | Set-Content (Join-Path $snapshot 'preferred-home.txt')
& $adb -s $tv shell cmd package resolve-activity --brief --user 0 -a android.intent.action.MAIN -c android.intent.category.HOME | Set-Content (Join-Path $snapshot 'actual-home.txt')
& $adb -s $tv shell cat /proc/meminfo | Set-Content (Join-Path $snapshot 'memory-before.txt')
```

Record current user, original Home component and enabled state, keyboard, Bluetooth/remote, HDMI/input services, animation values, screensaver, screen-off/sleep timeouts and enabled accessibility services. If the active user is not 0, adapt all user-specific commands before proceeding.

Present **every installed package once in plain English** under: optional candidates to turn off; needed/protected or uncertain TV components; apps the user uses. Optional candidates are not approval to disable them. Unknown dependencies stay enabled. Save readable reports and an exact change/undo journal.

Export available APKs and useful configuration/app-data backups where supported. Record unreadable packages and restore limitations. ADB backups are device/version dependent and are not full firmware recovery images. Do not claim guaranteed recovery or use root/flashing to expand this task.

Never restore the first box's complete settings, account data or APK collection onto the new box. Build the new box's undo commands from its **own** original values, including whether a setting was originally absent.

## 3. Check the apps before setting up Home

The six default banners are, in this order:

| App | Package |
|---|---|
| File Manager | `com.hitv.explore` |
| Fred TV | `dev.fredol.open_tv` |
| LocalSend | `org.localsend.localsend_app` |
| Surfshark | `com.surfshark.vpnclient.android` |
| Twitch | `tv.twitch.android.app` |
| VLC | `org.videolan.vlc` |

Play Store (`com.android.vending`) and Android Settings appear separately below. Missing apps are skipped, **not installed automatically**. On a fresh box, ask which missing apps to install and use their official Play Store/developer sources, with separate approval. Do not transfer another box's logins or grant accessibility/VPN/admin permissions as part of launcher installation.

If the user chooses a different app list, confirm it before passing it to Calm Home. The native app accepts a saved list at launch; our local staged shell wrapper intentionally checks against `apps.txt`, so review/update that file when using the wrapper with a different list. The top row is limited to six apps.

## 4. Disable Xiaomi analytics only after approval

Check that `com.miui.tv.analytics` exists on this box, verify its label/purpose and original user state, and check whether it is already disabled. Skip if already disabled. If absent, do not substitute another vendor package by guessing.

After approval for this exact package:

```powershell
& $adb -s $tv shell pm disable-user --user 0 com.miui.tv.analytics
& $adb -s $tv shell pm list packages -d --user 0
```

If the recorded original state was Android default (`enabled=0`), the optional undo is `pm default-state --user 0 com.miui.tv.analytics`. If it was explicitly enabled (`enabled=1`), restore that explicit state instead. Do not re-enable a package that was already disabled before this work. Keep analytics off during a later launcher-only rollback unless the user asks otherwise.

Do not copy a TCL debloat list or bulk-disable other optional apps. Preserve Play Store, Play services/framework, keyboard, Bluetooth/remote, HDMI/CEC/input, networking, settings, setup and uncertain vendor/system dependencies.

## 5. Install, then separately approve opening the new home

Keep the original launcher installed/enabled during the trial. Do not install Projectivy for this setup. Do not request accessibility, device-admin, root, overlay or network permission for Calm Home.

After approval for installing this exact APK, and after confirming Calm Home is not already installed:

```powershell
& $adb -s $tv install $apk
```

If it is already installed, inspect its version/signature and ask before an update. Do not uninstall automatically to resolve a signature mismatch.

After separate approval to open/save the app list and check navigation:

```powershell
$apps = 'com.hitv.explore,dev.fredol.open_tv,org.localsend.localsend_app,com.surfshark.vpnclient.android,tv.twitch.android.app,org.videolan.vlc'
& $adb -s $tv shell am start -n com.luisbadalo.calmhome/.MainActivity --es apps $apps
```

Inspect an actual TV screenshot and verify clock/date, app banners, Play Store/Settings and D-pad navigation. Test app/Settings launching as approved. Do not treat the browser design preview as runtime verification. Correct any defect locally and ask before installing an update.

The local project's reviewed `install.sh` has separate `install` and `open` stages that perform these actions. The unmodified upstream installer has broader behavior, including default-home changes and possibly disabling other launchers; upstream undo can uninstall. Do not run either blindly. Use individually approved, recorded actions; never pass an automatic-yes option as a substitute for user approval.

## 6. Choose Home, then test it from another app

After approval:

```powershell
& $adb -s $tv shell pm set-home-activity --user 0 com.luisbadalo.calmhome/.MainActivity
```

Open Android Settings and press Home. Check both actual foreground activity and Home resolution. A package-manager `Success` message is not sufficient.

On our MIBOX4, stock Google Android TV Home had higher priority and still won. If that happens on the new box, first confirm the exact competing component and original enabled state. After the new UI has been tested, ask separately before disabling **only that stock launcher**, keeping it installed. Do not disable every HOME candidate or a setup service. For the same verified package as our box, the command was:

```powershell
& $adb -s $tv shell pm disable-user --user 0 com.google.android.tvlauncher
```

Re-test Home from Settings. This disables the home-screen app, not Google Play. Record the original package state and complete rollback before proceeding. If the new box uses another launcher/package, review it rather than copying this command.

## 7. Animations/screensaver off; keep this box's original sleep times

Ask separately before each requested setting change; skip any already off:

- Global `window_animation_scale`, `transition_animation_scale`, `animator_duration_scale`: desired 0.
- Secure `screensaver_enabled`: desired 0. Do not disable its underlying system packages.
- **Do not change** system `screen_off_timeout` or secure `sleep_timeout`.

The first box originally had 15-minute screen-off and 3-hour sleep. Those are reference values, not settings to force onto a fresh box. Capture and preserve the new box's actual original values. Do not apply the upstream prompt's five-minute sleep request.

For undo, restore each exact recorded value; if a value was originally absent, delete the added setting rather than inventing a default.

## 8. Restart and verify, then offer to close debugging

Ask before reboot. Record RAM and boot ID immediately before; after reconnection, verify a new completed boot and allow startup to settle. Record RAM again and show both available-to-apps and completely-unused memory in MiB. Readings fluctuate and do not prove a speed improvement.

Verify Home from another app after reboot; the UI is still correct; only specifically approved packages stayed disabled; original packages remain installed; and Play Store/services, keyboard, Bluetooth/remote, HDMI/input and original sleep values are intact. Do not promise the same RAM readings as the first box.

Save the final report, screenshots, signed APK/app list, per-box backups and current undo instructions. Explain that the custom launcher needs no ADB connection. **Offer to turn off Wi-Fi/USB debugging after setup, and ask before doing so**; verify the wireless debugging endpoint is closed. It ends remote management until the user re-enables debugging on the box. Revoking all authorizations is a separate change because it affects other trusted computers too.

## Rollback on the new box

Use the new box's saved original Home component and package state. If stock Home was disabled, re-enable it first, restore its preferred entry, and open/verify it. Only then optionally disable Calm Home. Keep apps installed; do not uninstall or clear data without a new, explicit exception.

For a confirmed matching MIBOX4 with the same original default state, the order is:

```powershell
# Each rollback change requires approval when an assistant is operating the TV.
& $adb -s $tv shell pm default-state --user 0 com.google.android.tvlauncher
& $adb -s $tv shell pm set-home-activity --user 0 com.google.android.tvlauncher/.MainActivity
& $adb -s $tv shell am start -n com.google.android.tvlauncher/.MainActivity
# Verify original Home before this optional change:
& $adb -s $tv shell pm disable-user --user 0 com.luisbadalo.calmhome
```

The first box's `UNDO-CHANGES.md` is historical evidence, not an automatic restore script for this one. Keep Xiaomi analytics disabled if the user wants to undo only the launcher. Animation/screensaver rollback is separate. The preserved signed APK can reinstall the same custom build if needed; it cannot recover a broken operating system.

## Prompt

Copy the text from **REPLICATE-PROMPT.md**, fill in the new model/IP, and give it to Codex in the kit/project folder. If using a different computer, provide the extracted kit first; a prompt alone cannot fetch our unpublished custom APK from GitHub.

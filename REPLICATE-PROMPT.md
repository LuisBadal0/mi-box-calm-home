# Copy-and-paste prompt for a fresh box

Replace the bracketed model/IP fields and open Codex in the extracted Calm Home kit or original project folder. The APK and guide must be present. Then paste the block below.

```text
Reproduce my reviewed Calm Home / tv-detox setup on a DIFFERENT, fresh Android TV box.

New box model: [Xiaomi MIBOX4 / confirm actual model]
New box IP: [NEW_BOX_IP]

Read FRESH-BOX-SETUP.md first. Use the customized Calm Home APK supplied in this kit/project, not an unreviewed latest GitHub release. Package: com.luisbadalo.calmhome. Expected APK SHA-256: C904CEE4AFE38284A0E94ADE2A0A218C89AC4AA0559B2054648A29E9C2F83C43. If it is missing or differs, stop and ask for the reviewed artifact rather than substituting another APK.

1. Confirm the new box's model, Android version, serial/current user and IP. Target every ADB command explicitly at this new box; do not reuse scripts with my first box's hardcoded IP. Connect over Wi-Fi and walk me through any debugging/authorization taps.
2. Before settings changes, create a separate baseline/backup folder for this box. List EVERY installed app once in plain English under optional candidates to turn off, needed/protected or uncertain TV components, and apps I use. Check RAM. Save original package states, Home, accessibility, animations, screensaver, sleep times and protected services. Export available APK/configuration backups and explain their limits. Never import another box's system settings, accounts or private app data.
3. Ask before EVERY TV change, including installs, opening/configuring apps, choosing Home, disabling a launcher, updates, settings, reboot and debugging shutdown. Skip completed steps. Never uninstall or clear data. Keep Play Store, Play services/framework, keyboard, Bluetooth/remote, HDMI/CEC/input, network, setup and uncertain dependencies intact. No root, flashing, device-admin or accessibility grants. No bulk debloat list. Record each original value, approved action, verification and exact undo immediately.
4. After separate approval, disable only com.miui.tv.analytics if it exists, its identity is verified, and it is not already disabled. Do not guess a replacement package. Keep it disabled during a later launcher-only rollback.
5. Check my apps: File Manager (com.hitv.explore), Fred TV (dev.fredol.open_tv), LocalSend (org.localsend.localsend_app), Surfshark (com.surfshark.vpnclient.android), Twitch (tv.twitch.android.app), VLC (org.videolan.vlc). Missing apps need separate approval and official sources; do not copy logins. Use these six banners, a large live clock/date upper left, fixed dark orange fading to near-black, Play Store and Settings below, no HDMI shortcut row, ads, recommendations or animations. Do not install Projectivy.
6. Ask to install the reviewed APK. Then separately ask to open it/save this app list and test the REAL TV UI and D-pad. Keep stock Home available during the trial. After approval choose Calm Home as preferred and test Home from Settings. If stock Home still wins, identify the exact competing launcher and ask separately before disabling only that launcher, keeping it installed with a documented re-enable command. Never disable every HOME candidate or setup/input services. A Success message alone is not proof.
7. After approval, turn off the three Android animation scales and the screensaver, skipping any already off. Preserve the NEW box's original screen-off and sleep timeouts; do NOT set five-minute sleep or copy the first box's timeout values.
8. Ask before restart. Capture RAM immediately before and after a verified new boot; show available-to-apps AND completely-unused MiB. Verify Home from another app, intended disabled packages, app inventory, Play Store/services, keyboard, Bluetooth/remote, HDMI and unchanged sleep settings. Do not promise matching RAM or speed gains.
9. Give me the final report and per-box undo file. To undo Home, re-enable/restore/test the original launcher BEFORE disabling Calm Home. Preserve apps and backups. Finally offer to turn off Wi-Fi/USB debugging, explain that remote access will end, and ask before doing it. The launcher must keep working without debugging.

Use individually approved, reviewed commands. Do not blindly run upstream install/undo scripts or automatic-yes options: they can bundle changes or uninstall. This project's staged install.sh only supports one approved install/open action per run; Windows can use explicitly targeted adb commands instead. Finish one approved step at a time and keep the journal current.
```

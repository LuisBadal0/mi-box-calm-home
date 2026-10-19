# Calm Home

A simple Android TV home screen based on [Ansub/tv-detox](https://github.com/Ansub/tv-detox), customized for the Xiaomi Mi Box.

Large clock and date, a dark orange-to-black background, six app banners, and separate Play Store and Settings buttons. No ads, recommendations or HDMI shortcuts. The launcher requests no Android permissions and uses installed apps' own banners.

## Supported setup

The Windows automatic installer supports **Xiaomi MIBOX4, Android 9 / API 28, user 0**. It stops on other models, unexpected existing launchers or a different Calm Home APK. The launcher's broader Android compatibility does not mean the setup script supports other boxes.

## Install on a fresh box

1. Download or clone this repository. Install [PowerShell 7](https://github.com/PowerShell/PowerShell/releases) and download Google's [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools). Extract `platform-tools` beside the installer.
2. Put the computer and TV on the same trusted local network. On the TV, open Settings > Device Preferences > About and press Build seven times to enable Developer options. Enable USB debugging, and network debugging if there is a separate switch. Keep the TV awake on its HDMI input.
3. Open PowerShell in this folder and replace the example IP with your box's IP:

```powershell
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20
```

The installer prints instructions and waits up to three minutes for the TV's **Allow USB debugging?** dialog. Select **Always allow from this computer**, then **Allow**. It continues automatically after approval. Already authorized connections continue immediately. For more time, add `-AuthorizationWaitSeconds 300`.

This command authorizes the fixed automatic setup without confirmation before each change. For a guided workflow that asks first, read [FRESH-BOX-SETUP.md](FRESH-BOX-SETUP.md). Full automatic-mode details and troubleshooting are in [AUTOMATIC-SETUP.md](AUTOMATIC-SETUP.md).

Optional flags:

```powershell
# Save a read-only inventory/plan without installing or configuring anything.
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20 -PlanOnly

# Close Wi-Fi ADB after successful setup and verification.
pwsh -NoProfile -File .\Install-CalmHome-Unattended.ps1 -TvIp 192.168.1.20 -CloseWifiDebugging
```

## What changes

- Saves a separate inventory, original settings, readable app APKs and an undo guide for this box.
- Installs the included reviewed Calm Home APK and checks the screen before switching Home.
- Disables Xiaomi analytics and, only if needed for Home to work, the stock Google Android TV launcher. Both remain installed.
- Turns off animations and screensaver. Preserves the box's original screen-off and sleep times.
- Preserves Google Play, keyboard, Bluetooth, HDMI and accessibility settings.
- Restarts when changes were made, verifies persistence, and records available RAM before and after. RAM readings fluctuate and are not a speed benchmark.

The fixed six apps are **File Manager, Fred TV, LocalSend, Surfshark, Twitch and VLC**. Missing apps are reported and skipped; the installer does not download them, copy accounts or grant VPN permissions. See [apps.txt](apps.txt) for package IDs. This version's automatic installer uses its own fixed app list and verifies the exact included APK; editing `apps.txt` alone does not change the installer's list.

## Backup and undo

Each run writes its own folder under `tv-backup/`. Use that run's **UNDO.md** and `journal.json`; never apply another box's original values. Re-enable and verify the original Home before disabling Calm Home.

Backups contain settings, package state and readable APKs. Some vendor APKs may be unreadable. This is not a full firmware or private app-data recovery image. Network interruptions can stop setup or recovery; inspect the recorded error and actual device state before retrying. If wireless debugging was closed, enable it on the TV again before remote recovery.

## Included APK and source

- Package: `com.luisbadalo.calmhome`
- Version: `1.0-local`
- SHA-256: `C904CEE4AFE38284A0E94ADE2A0A218C89AC4AA0559B2054648A29E9C2F83C43`
- Source: [launcher/](launcher/)
- Upstream revision: `4cdbf068c76d7bc5b5adc070c42b8f924cabcc0d`

On macOS/Linux, rebuilding requires Java 17, Android SDK platform 34, build-tools 34.0.0 and `zip`. Set `ANDROID_HOME` and run:

```sh
cd launcher
sh build.sh
```

The build creates `launcher/out/calm-home.apk` and generates a local signing key if none exists. Keep your key private. A new key cannot update the included APK in place, and a rebuilt APK has a different checksum that the automatic installer will reject until you deliberately review and update its expected hash. Windows users can install the included APK without Java or a build environment.

## License

MIT; see [LICENSE](LICENSE). This project includes modified code from Ansub Khan's TV Detox. Third-party app icons/banners belong to their respective owners and are loaded from apps installed on the TV.

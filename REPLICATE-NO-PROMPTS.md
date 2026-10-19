# Copy-and-paste automatic setup prompt

Fill in the new IP and open Codex in the extracted kit/project folder. This is an explicit alternative to the approval-at-every-step prompt.

```text
Set up a different fresh Xiaomi MIBOX4 running Android 9 using my reviewed Calm Home / tv-detox kit.

New box IP: [NEW_BOX_IP]

Use AUTOMATIC-SETUP.md and Install-CalmHome-Unattended.ps1. I authorize its documented fixed setup scope on this new target without asking for confirmation before each step. Do not run it against my already-configured box unless I explicitly identify that box as the target.

Verify the supplied APK SHA-256 is C904CEE4AFE38284A0E94ADE2A0A218C89AC4AA0559B2054648A29E9C2F83C43. Use the reviewed local build; do not substitute a GitHub latest-release APK. Confirm model MIBOX4, Android API 28 and user 0 before mutations. If the IP/artifacts are missing, identify that blocker. If the device/configuration is unexpected, stop and report it instead of guessing or expanding scope.

Run the automatic installer for the supplied IP with -CloseWifiDebugging. Do not add interactive approval prompts or automatic-yes flags to upstream scripts. If Android itself needs initial debugging authorization or blocks installation, tell me exactly what to tap; do not bypass its protections.

Within this authorization: create the new per-box inventory/backups/undo journal; install/open the reviewed launcher; keep the six-app orange-to-dark clock design plus Play Store/Settings; disable only verified Xiaomi analytics and, if necessary after UI verification, the specific stock Google home app; turn off animations/screensaver; preserve original sleep times and protected Play/keyboard/Bluetooth/HDMI/accessibility services; restart and verify with RAM before/after; finally close wireless ADB after checks succeed.

Skip completed steps. Report missing user apps without installing them or copying accounts. Never uninstall, clear data, root, flash, grant accessibility/admin access, disable setup/input services or bulk-debloat. If the Home switch fails, use the script's recorded original-Home recovery. Finish with results, missing items and the per-box backup/undo paths. No other TV changes are authorized by this prompt.
```

# Release notes

## 1.1-most-used (versionCode 2) — 19 October 2026

- Replaced built-in/saved app lists with up to six launchable apps ranked by Android daily foreground-time totals for the requested last 30 days.
- Refreshes ranking on return Home and app installation/removal/updates; includes preinstalled streaming apps as well as user-installed apps.
- Added All apps so apps outside the ranked row remain reachable, and a Usage Access settings entry/explanation.
- Added the PACKAGE_USAGE_STATS declaration. The installer records/restores the GET_USAGE_STATS app-op mode and checks it after restart.
- Falls back to successful launches from Calm Home when usage access is unavailable, then stable alphabetical ordering without history. Android retention and daily buckets limit the historical window's precision.
- Removed apps.txt/build-generated app lists and fixed --es apps configuration. Existing fixed-list preferences are dropped on app update.
- Updated APK, checksum, build metadata, Windows/shell build paths, setup guides, prompts and undo guidance. Kept the initial debugging authorization wait.

Validation: Java/DEX build, APK signature/alignment and permission inspection, ranking-policy cases and offline installer scenarios. No new physical-TV ranking/Usage Access trial has been performed. Publishing this version does not update any TV. Tests and private device data are excluded from the repository.

## 1.0-local (versionCode 1)

Initial local edition with a fixed six-app row, clock/date, dark orange gradient, Play Store and Settings. Superseded by automatic app selection in 1.1.

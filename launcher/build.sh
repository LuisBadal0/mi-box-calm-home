#!/bin/sh
# Builds out/calm-home.apk. Needs Java 17 and the Android SDK (platform 34, build-tools 34).
#   macOS:  brew install openjdk@17 && brew install --cask android-commandlinetools
#           sdkmanager "platforms;android-34" "build-tools;34.0.0"
set -e
cd "$(dirname "$0")"

[ -n "$JAVA_HOME" ] || for j in /opt/homebrew/opt/openjdk@17 /usr/local/opt/openjdk@17 /usr/lib/jvm/java-17-openjdk-amd64; do [ -d "$j" ] && JAVA_HOME=$j && break; done
[ -n "$JAVA_HOME" ] && export PATH="$JAVA_HOME/bin:$PATH"
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
[ -n "$SDK" ] || for d in /opt/homebrew/share/android-commandlinetools "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"; do [ -d "$d" ] && SDK=$d && break; done
BT=$SDK/build-tools/34.0.0; JAR=$SDK/platforms/android-34/android.jar
[ -f "$JAR" ] && [ -d "$BT" ] || { echo "Android SDK not found. Set ANDROID_HOME, and install platforms;android-34 and build-tools;34.0.0." >&2; exit 1; }

mkdir -p out/classes out/dex

"$BT/aapt2" link -o out/base.apk -I "$JAR" --manifest AndroidManifest.xml --min-sdk-version 21 --target-sdk-version 34
javac -nowarn -Xlint:-options -source 1.8 -target 1.8 -bootclasspath "$JAR:$BT/core-lambda-stubs.jar" \
  -d out/classes $(find src -name "*.java")
"$BT/d8" --min-api 21 --release --lib "$JAR" --output out/dex $(find out/classes -name '*.class')
cp out/base.apk out/unsigned.apk; (cd out/dex && zip -q ../unsigned.apk classes.dex)
"$BT/zipalign" -f 4 out/unsigned.apk out/aligned.apk

# A signing key is made on first build. Keep it: updates must be signed with the same key.
# A new key gets a random password saved beside it (never committed). Set KEYSTORE and
# KEYSTORE_PASS to use another key. Keys made before this change keep the old default password.
KS=${KEYSTORE:-calmhome-local.jks}; PASS_FILE=${KS%.jks}.password
if [ -n "$KEYSTORE_PASS" ]; then PASS=$KEYSTORE_PASS
elif [ -f "$PASS_FILE" ]; then PASS=$(cat "$PASS_FILE")
elif [ -f "$KS" ]; then PASS=local-build-only
  echo "Warning: $KS has no $PASS_FILE; using the legacy development password." >&2
else PASS=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
  (umask 077; printf '%s\n' "$PASS" > "$PASS_FILE")
  echo "Created a random signing password in $PASS_FILE. Keep it private with $KS." >&2
fi
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass "$PASS" -keypass "$PASS" -alias tvhome \
  -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=tvhome" >/dev/null 2>&1
"$BT/apksigner" sign --ks "$KS" --ks-pass "pass:$PASS" --out out/calm-home.apk out/aligned.apk
echo "Built out/calm-home.apk"

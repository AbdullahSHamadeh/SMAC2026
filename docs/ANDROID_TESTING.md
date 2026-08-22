# Run Family Compass on Android

## Current Mac status

The Android development path is installed and registered with Flutter:

- Android SDK API 36 in the local Android SDK directory
- Android build tools 36.0.0 and platform tools 37.0.1
- Android emulator 37.1.11
- NDK 28.2.13676358, matching Flutter 3.44.8
- Java 17 at `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- Pixel 7 profile `Family_Compass_API_36` with Android 16 and Google APIs

Flutter's Android toolchain check passes and all SDK licenses are accepted.
Release signing and Play Store verification remain separate release work.

Latest local verification on 13 August 2026:

- The current debug APK builds successfully.
- SHA-256: `9ec6e400a0a3ece03fecdb4e0f544495bbc51ec99b9517ee587bfdd606364367`.
- It installs on `Family_Compass_API_36` and cold-launches
  `com.smac.familycompass/.MainActivity` successfully in 1.963 seconds.
- A `familycompass://.../messages/...` intent lands on Chat and exposes the
  expected message, Compass suggestion, action, composer, and four tabs.
- The launch log contains no Family Compass fatal exception or ANR.

## Verify the toolchain

```sh
cd apps/family_compass
flutter doctor -v
flutter emulators
```

If a new shell needs the command-line tools directly:

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"
```

## Start the emulator

Start it through Flutter:

```sh
flutter emulators --launch Family_Compass_API_36
```

Or start the same profile directly:

```sh
"$ANDROID_SDK_ROOT/emulator/emulator" -avd Family_Compass_API_36
```

Wait until the Android home screen is ready, then verify that Flutter lists a
device such as `emulator-5554`:

```sh
flutter devices
```

## Build and run

The project shares the external `build` link described in `IOS_TESTING.md`.
Keep that link intact so a later iOS build does not return to the iCloud metadata
failure.

Run the deterministic prototype:

```sh
cd apps/family_compass
flutter build apk --debug
flutter run -d emulator-5554
```

On a fresh Gradle cache, dependency downloads may open too many parallel
connections and stop making progress. Cancel that build, keep the partial
cache, and retry once with bounded workers and network timeouts:

```sh
GRADLE_OPTS="-Dorg.gradle.workers.max=4 \
-Dorg.gradle.parallel=false \
-Dorg.gradle.internal.http.connectionTimeout=30000 \
-Dorg.gradle.internal.http.socketTimeout=60000" \
flutter build apk --debug
```

The first validation build stalled in dependency resolution under the default
parallelism. The bounded retry reused the cache and completed successfully.

## Connect the emulator to local Compass services

The Android emulator reaches the Mac loopback interface through `10.0.2.2`,
not `127.0.0.1`.

After starting FastAPI and the configured AI provider, run:

```sh
cd apps/family_compass
flutter run \
  -d emulator-5554 \
  --dart-define=FAMILY_COMPASS_USE_HTTP_BACKEND=true \
  --dart-define=FAMILY_COMPASS_API_BASE_URL=http://10.0.2.2:8000 \
  --dart-define=FAMILY_COMPASS_AUTH_TOKEN="<printed development token>"
```

Generate the token with the same `FAMILY_COMPASS_DEV_AUTH_SECRET` used by the
backend, as shown in `IOS_TESTING.md` and the backend README. Tokens expire, so
generate a new one when the backend returns an authentication error.

If local cleartext traffic is rejected, record it as a native configuration
failure. Do not enable arbitrary cleartext internet traffic as a workaround.

## Physical Android phone

1. Enable Developer options and USB debugging on the phone.
2. Connect it by USB and accept the debugging fingerprint on the phone.
3. Confirm it appears under `flutter devices`.
4. Run `flutter run -d "<physical device id>"`.
5. Complete the Android, TalkBack, notification, network, and background checks
   in `PROTOTYPE_3_VALIDATION_CHECKLIST.md`.

A local backend cannot be reached through `10.0.2.2` from a physical phone.
Use an approved development endpoint or a Mac LAN address with explicit local
network configuration. Never expose demo authentication to an untrusted network.

## Stop the emulator

```sh
"$ANDROID_SDK_ROOT/platform-tools/adb" -s emulator-5554 emu kill
```

An emulator pass does not replace validation on a physical Android phone.

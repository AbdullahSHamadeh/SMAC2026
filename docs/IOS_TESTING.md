# Run Family Compass on iOS

## Current Mac status

The local iOS toolchain is ready:

- Xcode 26.6 with the iOS 26.5 SDK and Simulator runtime
- CocoaPods 1.17.0
- An iPhone 17 simulator named by Xcode
- Flutter 3.44.8 at `../flutter-sdk` relative to this repository

Latest local verification on 13 August 2026:

- The current source builds and launches on the iPhone 17 simulator.
- iOS registers the `familycompass` URL scheme and hands a plan link to Family
  Compass; the app selects Together and presents the linked family thread.
- Portrait Today, Chat, Together, and the short-landscape Together composition
  were inspected after the final repair pass.
- The accessibility tree exposes the actionable Chat plan control, exact tab
  positions, current selection, and derived plan date and time.

Run this from `apps/family_compass` to verify the toolchain:

```sh
flutter doctor -v
```

## Preserve the external build directory

This repository is under the iCloud-managed `Documents` folder. iCloud added
Finder metadata to `Flutter.framework`, and Apple code signing rejected it with
`resource fork, Finder information, or similar detritus not allowed` and Xcode
status 255.

The project therefore keeps generated output outside iCloud through this link:

```text
apps/family_compass/build
  -> a build directory outside the iCloud-managed repository
```

Before an iOS build, verify it from `apps/family_compass`:

```sh
test -L build
readlink build
```

The second command should print the external directory selected for Flutter
build output.

`flutter clean` can remove the link. If `build` is absent, recreate it without
removing any project data:

```sh
family_compass_build_dir="$HOME/.cache/family_compass_flutter_build"
mkdir -p "$family_compass_build_dir"
ln -s "$family_compass_build_dir" build
```

If `build` exists but is not a symbolic link, stop and inspect it before doing
anything. The durable alternative is to move both the working copy and Flutter
SDK outside iCloud-managed folders.

## Launch the deterministic app

```sh
open -a Simulator
flutter devices
cd apps/family_compass
flutter run \
  -d "<simulator device id>"
```

Long-press the Family Compass title to switch among the prepared scenarios.

## Launch with the local backend and Compass service

In LM Studio, load the configured local model and start its server. Then run the
backend in a separate Terminal:

```sh
cd family_compass_backend
source .venv/bin/activate
export FAMILY_COMPASS_AUTH_MODE=dev
export FAMILY_COMPASS_DEV_AUTH_SECRET="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
export FAMILY_COMPASS_AI_PROVIDER=lm_studio
export FAMILY_COMPASS_AI_MODEL=google/gemma-3-4b
python -m app.dev_token 11111111-1111-1111-1111-111111111111
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Copy the expiring token printed before `uvicorn` starts. Do not put the secret
or token in a committed file.

Run the simulator app with the backend flag:

```sh
cd apps/family_compass
flutter run \
  -d "<simulator device id>" \
  --dart-define=FAMILY_COMPASS_USE_HTTP_BACKEND=true \
  --dart-define=FAMILY_COMPASS_API_BASE_URL=http://127.0.0.1:8000 \
  --dart-define=FAMILY_COMPASS_AUTH_TOKEN="<printed token>"
```

The app calls FastAPI, and FastAPI calls the AI provider. The iOS runner permits
local-network development traffic without allowing arbitrary cleartext traffic.

## Physical iPhone

1. Connect and trust the iPhone.
2. Enable Developer Mode on the phone.
3. Open `apps/family_compass/ios/Runner.xcworkspace` in Xcode.
4. Select the Family Compass target and a development Signing Team.
5. For a Firebase-enabled build, place the gitignored
   `Runner/GoogleService-Info.plist` in that directory. The optional build phase
   copies it into the app. Add the project's encoded App ID as a local URL
   scheme. Do not commit either project-specific value.
6. Select the phone and press Run.

A personal Apple developer account can install a development build on its own
device. App Store distribution still requires release signing, provisioning,
privacy disclosures, and review. Complete the physical-device and VoiceOver
checks in `PROTOTYPE_3_VALIDATION_CHECKLIST.md`; a simulator does not satisfy
those checks.

## Troubleshooting boundaries

- Apple Shortcuts `SQLite error 19: UNIQUE constraint failed` messages are
  simulator background-service noise, not a Family Compass build failure.
- A code-signing message about Finder information points to iCloud metadata.
  Verify the external `build` link first. Do not erase the simulator or reinstall
  Xcode for this error.
- A Simulator pass does not prove physical-device signing, notifications,
  accessibility services, background behavior, or local-network permissions.

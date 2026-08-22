# Firebase phone authentication and notifications

The Family Compass code now contains the production integration boundaries for
Firebase phone authentication, Firebase ID tokens, FCM installation
registration, notification handling, and exact deep links. The checked-in build keeps Firebase
disabled, so the deterministic demo and ordinary simulator builds do not need a
cloud project or credentials.

This document separates work that is already implemented from account work that
must be completed by a project owner. Do not paste passwords, APNs private keys,
service-account JSON, Android keystore passwords, or signing certificates into
source control, screenshots, issues, or chat.

## Implemented in the application

- Native iOS and Android SMS verification gateway with code-sent, automatic
  verification, timeout, retry, invalid-code, quota, and network states.
- Opt-in onboarding UI for send, resend, six-digit verification, and backend
  account registration. Before a real SMS is sent, it discloses Firebase and
  Google phone-number processing for authentication and abuse prevention. The
  deterministic build keeps its prepared local code.
- Firebase ID-token cache, automatic token-change observation, and one forced
  refresh after an authenticated API request receives `401`.
- Backend `POST /api/v1/auth/phone/register` endpoint. It accepts only a verified
  Firebase phone-provider token, creates or links the local account atomically,
  and never returns the phone number.
- Notification permission boundary. FCM auto-init is disabled until permission
  is accepted from the Family settings control. The app never prompts at launch.
- Firebase Installation ID (FID) upload, ID-change replacement, backend removal
  on sign-out, and removal of installations that FCM reports as unregistered.
- Generic, localized foreground notices plus background-open and
  terminated-open handling. The foreground Open action uses the same verified
  exact-link resolver, and no sender name or message content is shown.
- Exact links for messages, plans, reminders, and check-in requests.
- Android 13 and newer notification permission declaration and a `family_updates`
  notification channel.
- iOS push entitlement and `fetch`/`remote-notification` background modes.
- Generic lock-screen text. Push data identifies an opaque family resource; the
  signed-in app fetches protected details after the person opens it.
- Runtime family bootstrap. Existing authorized memberships are selected safely;
  Create makes a family and can send the prepared outgoing invitation; Join
  lists only pending, unexpired invitations addressed to the verified number
  and explicitly accepts one. Family repositories, realtime, offline writes,
  and device registration are rebuilt from the returned backend IDs.

## 1. Firebase project status

The development Firebase project now exists:

```text
Project name: Family Compass
Project ID: family-compass-de2c4
Apple bundle ID: com.smac.familycompass
Android package: com.smac.familycompass
```

Both mobile apps are registered. The native configuration files are installed
locally in their gitignored locations. The iOS encoded App ID URL scheme is a
local Xcode configuration and is not committed. The current Android debug and
upload SHA-1 and SHA-256 fingerprints are registered. Phone sign-in is enabled,
and the SMS
region allowlist contains only the UAE. Two UAE-format fictional test numbers
are configured, and their verification codes are stored only in macOS Login
Keychain. Both accounts completed real Firebase cloud phone authentication and
`accounts:lookup` without sending SMS. Google Analytics and Gemini in Firebase
remain disabled to avoid unneeded collection and prompt processing during the
development pilot.

The remaining project-owner actions are:

1. Configure backend Application Default Credentials and verify cloud
   invitation handling with both fictional accounts.
2. Complete the remaining physical iPhone checks. Renew the free Personal Team
   profile and reinstall the app when its 7-day validity period expires.
3. Complete paid Apple enrollment, APNs and FCM sending configuration, and physical-device delivery
   tests.
4. Create a separate production Firebase project before public release. Do not
   reuse the development project for production data.

Firebase sends and stores phone numbers for spam and abuse prevention. Add this
fact to the consent and privacy copy before enabling real SMS sign-in.

## 2. Configure the Flutter build

The preferred setup is the official FlutterFire workflow:

```bash
cd apps/family_compass
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Select the intended Firebase project plus Android and iOS. Do not run this step
while signed into an uncertain Google account. Review the selected project and
bundle identifiers before confirming.

The application supports the standard native Firebase files on Android, iOS,
and macOS. Put the downloaded Android file at
`apps/family_compass/android/app/google-services.json`. Add the Apple
`GoogleService-Info.plist` at `apps/family_compass/ios/Runner/`. An optional
build phase copies it when present. The checked-in project intentionally has no
required resource reference to this private file, so a fresh Firebase-disabled
clone can build. The native files must stay out of source control. Then enable
the configured runtime with:

```text
--dart-define=FAMILY_COMPASS_FIREBASE_ENABLED=true
```

When no explicit Firebase identifiers are supplied, Android, iOS, and macOS
initialize the default app from those native files. The Android Google Services
Gradle plugin is applied automatically when `google-services.json` is present,
so the ordinary file-free demo build still works.

The alternative CI path injects all four required client identifiers directly:

```text
--dart-define=FAMILY_COMPASS_FIREBASE_ENABLED=true
--dart-define=FAMILY_COMPASS_FIREBASE_API_KEY=...
--dart-define=FAMILY_COMPASS_FIREBASE_APP_ID=...
--dart-define=FAMILY_COMPASS_FIREBASE_MESSAGING_SENDER_ID=...
--dart-define=FAMILY_COMPASS_FIREBASE_PROJECT_ID=...
--dart-define=FAMILY_COMPASS_FIREBASE_IOS_BUNDLE_ID=com.smac.familycompass
--dart-define=FAMILY_COMPASS_FIREBASE_IOS_CLIENT_ID=...
--dart-define=FAMILY_COMPASS_FIREBASE_IOS_URL_SCHEME=...
```

Supplying any of the four required identifiers selects this explicit path. A
partial set fails at startup and reports the missing identifiers instead of
falling back to a native file. Web, Linux, Windows, and Fuchsia builds always
require the explicit path. The optional Web values are
`FAMILY_COMPASS_FIREBASE_AUTH_DOMAIN`,
`FAMILY_COMPASS_FIREBASE_STORAGE_BUCKET`, and
`FAMILY_COMPASS_FIREBASE_MEASUREMENT_ID`. Real phone sign-in validation for this
release targets the native iOS and Android apps.

The configured onboarding creates or resumes the authenticated local user and
binds only to families returned for that account. Join lists every pending,
unexpired invitation addressed to the verified phone number. The person must
choose Accept or Decline for each invitation; the app never accepts the only or
first match automatically. The app does not guess or accept a build-time family
ID in Firebase mode.

For the iOS reCAPTCHA fallback, add the Encoded App ID or reversed client ID
from the Firebase Apple-app settings as an additional local Runner URL scheme.
Do not commit the project-specific value. Keep the existing `familycompass`
scheme. The same value belongs in
`FAMILY_COMPASS_FIREBASE_IOS_URL_SCHEME`. This cannot be filled in before the
Apple app exists in the owner's Firebase project.

## 3. Android app verification gate

Register both SHA-1 and SHA-256 certificate fingerprints for every build that
will test phone sign-in. This includes the local debug certificate, the release
upload certificate, and the Google Play app-signing certificate when Play App
Signing is used.

For the current local certificate report:

```bash
cd apps/family_compass/android
./gradlew signingReport
```

Current debug certificate fingerprints on this development Mac:

```text
SHA-1:   29:77:E8:DF:81:23:A7:1B:69:B4:AB:EA:AC:F5:1D:04:3C:7B:04:CA
SHA-256: 80:23:16:EB:A6:7C:B3:F0:C2:36:75:88:B8:34:82:F5:24:1E:B3:C8:D8:19:D5:3B:C5:6A:F2:DD:5C:C7:83:AC
```

These values are for Firebase development registration only. Recheck them on
every development machine instead of assuming the same debug certificate.

Then add the values in Firebase Console > Project settings > Your apps > Android
app > SHA certificate fingerprints and download a fresh `google-services.json`
if the selected setup uses native configuration files.

SHA-256 is used by Play Integrity. SHA-1 remains required for the reCAPTCHA
fallback path. Do not use the debug keystore for a release build.

### Android release and Play signing

The Gradle release build never falls back to the debug key. On this development
Mac, the private upload JKS is stored outside the repository under
`~/Library/Application Support/Family Compass/signing/`. Its passwords are in
macOS Login Keychain, while the gitignored `key.properties` contains only
nonsecret references. The upload fingerprints are registered with Firebase. A
Firebase-enabled release AAB built successfully and passed `jarsigner`
verification.

Back up the JKS and its Keychain secrets in the release owner's protected
storage. Losing the upload key can block future Play updates. For a replacement
key or another development Mac, create a private upload keystore outside this
repository. `keytool` asks for the passwords interactively, so they do not need
to appear in the command or shell history.

```bash
keytool -genkey -v \
  -keystore /private/path/family-compass-upload.jks \
  -keyalg RSA -storetype JKS -keysize 2048 -validity 10000 \
  -alias upload

cp apps/family_compass/android/key.properties.example \
  apps/family_compass/android/key.properties
```

Replace only `storeFile` in the copied file with the keystore's absolute path.
Keep its service names and accounts, then save the two passwords in macOS Login
Keychain. Each command prompts securely because `-w` is the final option:

```bash
security add-generic-password \
  -a family-compass-release \
  -s com.smac.familycompass.android.upload.store-password \
  -U -w

security add-generic-password \
  -a family-compass-release \
  -s com.smac.familycompass.android.upload.key-password \
  -U -w
```

Validate the setup without printing either password, then build:

```bash
cd apps/family_compass/android
./gradlew validateReleaseSigning

cd ..
flutter build appbundle --release
```

For CI, `key.properties` is optional. Supply all four product-specific variables
as protected CI secrets or variables:

```text
FAMILY_COMPASS_ANDROID_KEYSTORE_PATH
FAMILY_COMPASS_ANDROID_KEY_ALIAS
FAMILY_COMPASS_ANDROID_STORE_PASSWORD
FAMILY_COMPASS_ANDROID_KEY_PASSWORD
```

The common aliases `ANDROID_KEYSTORE_PATH`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEYSTORE_PASSWORD`, and `ANDROID_KEY_PASSWORD` are also supported. A
nonsecret `key.properties` can name different password variables with
`storePasswordEnv` and `keyPasswordEnv`. Existing private files containing
`storePassword` and `keyPassword` remain compatible, but Keychain or protected
CI variables are preferred.

Keep the upload key and passwords in the release owner's secret storage. Enroll
the production app in Play App Signing. Register three certificate sets with
Firebase when applicable: local debug, the private upload key, and the Google
Play app-signing key shown under Play Console > App integrity. Google signs the
APK delivered to users, so its app-signing SHA values must be registered even
when the locally uploaded bundle has a different upload certificate.

## 4. Apple APNs gate

An Apple Developer Account Holder or Admin must:

1. Enable Push Notifications for the `com.smac.familycompass` App ID.
2. Add Push Notifications plus Background Modes > Background fetch and Remote
   notifications to the Runner target.
3. Create or select an APNs authentication key and upload it in Firebase Console
   > Project settings > Cloud Messaging > Apple app configuration.
4. Regenerate the development and distribution provisioning profiles after the
   capability change.

The repository includes the background-mode declarations. An Apple Development
identity and free Personal Team provisioning profile were created, and the
signed Firebase-enabled Profile app was installed and launched successfully on
the connected iPhone after its Developer App profile was trusted. The free
Personal Team profile expires after 7 days and must be renewed and the app
reinstalled for continued local testing. This build omits the `aps-environment`
entitlement. Paid Apple Developer enrollment and the appropriate account role
are still required to create the APNs key, enable real APNs, and complete
production signing and distribution profiles.

## 5. Backend Firebase Admin and FCM gate

Run the FastAPI service with Application Default Credentials in the hosting
environment:

```bash
cd family_compass_backend
source .venv/bin/activate
pip install -r requirements-firebase.txt
export FAMILY_COMPASS_AUTH_MODE=firebase
export FAMILY_COMPASS_NOTIFICATION_PROVIDER=fcm
export FIREBASE_PROJECT_ID=your-project-id
uvicorn app.main:app
```

Prefer workload identity or the hosting platform's service identity. If a
service-account file is unavoidable, store it in the deployment secret manager
and point `GOOGLE_APPLICATION_CREDENTIALS` to the mounted secret. Never copy it
into this repository.

Use HTTPS for every production API URL. The backend calls Firebase Admin with
revocation checking enabled. FCM sends to the current Firebase Installation IDs
in groups of up to 500 and removes destinations reported as unregistered. The
Flutter client uses the official `firebase_app_installations` plugin to upload
the FID. Registration-token targeting is deprecated in Firebase Admin 7.5.

## 6. Test numbers and SMS abuse controls

The development project has two UAE-format fictional phone numbers configured
in Firebase Console > Authentication > Sign-in method > Phone numbers for
testing. Their codes are stored only in macOS Login Keychain and are not checked
into the app or documented here. Both accounts completed real Firebase cloud
phone authentication and `accounts:lookup` without sending SMS. The SMS region
allowlist contains only the UAE. Cloud invitation end-to-end testing remains
pending until backend Application Default Credentials are configured.

- Use numbers that do not belong to real people.
- Use six-digit codes that are difficult to guess and rotate them.
- Do not hard-code test numbers or codes in the production app.
- Keep the test-number list restricted. Firebase-minted test-user ID tokens are
  signed like real-user tokens.
- Keep the SMS region allowlist restricted to the UAE for the current pilot.
- Monitor quota and suspicious verification attempts. Firebase throttles
  repeated requests, but the product should also rate-limit send and retry UI.
- Never disable app verification in a production build.

## 7. Required physical-device validation

Phone authentication and APNs delivery cannot be proven by a source build or an
iOS Simulator pass. Use one physical iPhone and one physical Android phone.

For the current run, the physical iPhone has Developer Mode enabled, is paired
and unlocked with its Developer Disk Image available, and appears in Xcode. An
Apple Development identity and free Personal Team provisioning profile were
created, and the signed Firebase-enabled Profile app was installed and launched
successfully without Flutter tooling. The free Personal Team profile expires after 7 days and must be
renewed and the app reinstalled for continued local testing. This build omits
the `aps-environment` entitlement, so real APNs remains pending paid Apple
Developer enrollment. No physical Android phone is available. VoiceOver,
TalkBack, real-radio recovery, and APNs/FCM delivery therefore remain pending.

For each device, test:

1. First install, permission not yet requested.
2. Fictional test-number sign-in, then one permitted real-number sign-in.
3. Wrong, expired, resent, and throttled verification codes.
4. Notification permission allow, deny, and system-settings recovery.
5. Message, plan, reminder, and check-in notifications while foregrounded,
   backgrounded, terminated, and locked.
6. Tap each notification and confirm that the exact family artifact opens.
7. Sign out and verify that the backend registration disappears and the old
   device receives no further family pushes.
8. Reinstall the app or delete its Firebase installation in a test-only build,
   then verify that the changed FID replaces the old backend registration.
9. Repeat with the second account and confirm cross-family isolation.

On iOS, swiping the app away stops background message handling until it is opened
again. On Android, force-stopping the app in system settings also requires a
manual reopen. Record these operating-system conditions separately from product
failures.

## Official references

- [Set up Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Firebase phone authentication for Flutter](https://firebase.google.com/docs/auth/flutter/phone-auth)
- [Receive FCM messages in Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [FCM Flutter setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started)
- [Verify Firebase ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Manage FCM registrations](https://firebase.google.com/docs/cloud-messaging/manage-tokens)
- [Manage Firebase installations](https://firebase.google.com/docs/projects/manage-installations)
- [Firebase Admin Python release notes](https://firebase.google.com/support/release-notes/admin/python)
- [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- [Flutter Android release signing](https://docs.flutter.dev/deployment/android)
- [Google Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)
- [Apple User Notifications](https://developer.apple.com/documentation/usernotifications)

# Family Compass Version 1 foundation

This is the active Flutter application. It applies the Sunday Table direction to the four approved destinations:

- Today: the next gathering, replies needed, volunteered updates, and one useful suggestion
- Chat: familiar family messages with embedded plans, polls, reminders, and quiet Compass notes
- Compass: a private assistant that shows source, freshness, limits, and a useful next step
- Together: proposals, decisions, confirmed plans, reminders, and voluntary contributions

Package version: `0.3.0-dev.1+3`

This is a working local pilot foundation, not the production `1.0.0` release. It can connect to the persistent FastAPI service with signed development authentication, real-time events, notification deep links, and an optional LM Studio provider. Firebase phone-auth, ID-token refresh, Firebase Installation ID registration, notification-open routing, and native capability hooks are implemented behind opt-in build flags. The development Firebase project and native app registrations exist, and a Personal Team Profile build has been installed on one physical iPhone. Production Firebase Admin credentials, paid Apple signing and APNs, FCM delivery, Play App Signing, a physical Android device, and the complete cross-device pilot remain open.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Use `flutter run -d chrome` for a convenient preview. The Web target is not a separate website. It renders the same adaptive Flutter app used by the iOS and Android runner projects.

To use the local FastAPI and LM Studio Compass on Web after starting the backend as described in `family_compass_backend/README.md`:

```bash
flutter run -d chrome --web-port 8091 \
  --dart-define=FAMILY_COMPASS_USE_HTTP_COMPASS=true \
  --dart-define=FAMILY_COMPASS_API_BASE_URL=http://127.0.0.1:8000
```

On the iOS Simulator, use the same build-time settings with its device ID:

```bash
flutter devices
flutter run -d <ios-simulator-id> \
  --dart-define=FAMILY_COMPASS_USE_HTTP_COMPASS=true \
  --dart-define=FAMILY_COMPASS_API_BASE_URL=http://127.0.0.1:8000
```

See [`docs/IOS_TESTING.md`](../../docs/IOS_TESTING.md) for the complete one-time Xcode, Simulator, and local-service setup.

For a configured Firebase build, follow
[`docs/FIREBASE_PRODUCTION_SETUP.md`](../../docs/FIREBASE_PRODUCTION_SETUP.md).
The ordinary demo build leaves `FAMILY_COMPASS_FIREBASE_ENABLED` false and
performs no Firebase initialization. A configured Android, iOS, or macOS build
can read its gitignored native Firebase file when enabled, or receive explicit
client identifiers from CI. Web requires explicit identifiers. The production
flow also requires a Firebase-authenticated account and a FastAPI server running
with Firebase Admin verification. An explicit internal Profile mode can instead
verify one allowlisted fictional Firebase test account against a local backend
without sending SMS. That mode has no revocation lookup, accepts no real number,
and must never contain real-family data.

Current Firebase seam: phone verification, local account registration, ID-token
refresh, notification consent, FID registration, exact authenticated links, and
sign-out cleanup are wired. After registration, the runtime selects the first
authorized existing family, creates one for the Create path, or lists all
recipient-only pending invitations and accepts only the invitation the person
explicitly chooses for the Join path.
Only then does it build family repositories, realtime subscriptions, offline
queue scope, and notification registration with the backend user and family
IDs. Sign-out, leave, delete, and family rebinding dispose the old scoped
runtime. A family-less account remains in authenticated onboarding and cannot
enter a configured pilot family by stale build-time IDs.

The mobile app never calls LM Studio directly. Turning off `FAMILY_COMPASS_USE_HTTP_COMPASS` preserves the deterministic offline demonstration.

Long press the Family Compass title to change the demonstration state. Available states cover dinner planning, an open poll, a confirmed gathering, sourced reassurance, missing information, offline cached content, AI unavailable, paused sharing, and notification denial.

## Verified foundation

- `flutter analyze` passes with no issues.
- All 193 Flutter tests pass.
- `flutter build web --release` succeeds.
- Fresh iOS Simulator and Android debug builds succeed, and the rebuilt iOS app launches on an iPhone 17 simulator. Android also passes a cold-launch crash and ANR smoke check.
- The automated suite covers the live gathering flow, explicit invitation choice, exact message, plan and reminder links, private Compass evidence and abstention, selected-recipient sharing, durable offline retry, English and Arabic RTL, light and dark contrast, compact and expanded layouts, 200 percent text, key semantics, and onboarding and Together system Back behavior.
- The one-time design detector returned `[]`, and the visual and design-slop audit passed after fixes.

The signed Profile build installs and opens on one physical iPhone. The full physical-device flow, real notification delivery, release credentials, assistive-technology checks, and a physical Android test remain open. Android release builds require the gitignored `android/key.properties` and private upload keystore described in the Firebase setup guide.

## Launcher icon

The source is [`assets/brand/family-compass-icon-master.png`](assets/brand/family-compass-icon-master.png). Generated iOS, Android, Web, maskable Web, and favicon exports replaced the default Flutter placeholders. Android adaptive foreground and background layers remain production release work.

## Native identifiers

Android and iOS use the foundation namespace `com.smac.familycompass`. Android's `MainActivity` is in the matching Kotlin package. Local Android upload signing and a free Personal Team iPhone profile are configured, but production signing and final App Store and Play Store verification have not been completed.

## Current architecture

- `lib/design_system`: color, type, spacing, semantic state, and theme tokens
- `lib/domain`: family and gathering models
- `lib/data`: repository contracts plus FastAPI HTTP and real-time adapters
- `lib/firebase`: opt-in phone authentication, ID-token, notification, and device-registration adapters
- `lib/features`: onboarding, Today, Chat, Compass, Together, family controls, and sharing controls
- `lib/prototype`: deterministic state and fixtures used until repositories are connected
- `test`: cross-feature interaction and adaptive-layout scenarios

The repository contracts keep UI code independent of Firebase, FastAPI transport, Google services, and the selected AI provider.

Typing `@` in Chat opens a keyboard-friendly chooser containing Compass and the current authorized family members. Member mentions remain ordinary family messages. A distinct `@Compass` mention anywhere in a message invokes the same backend Compass service used by the private Compass tab, while keeping the audience and conversation histories separate. `FamilyRoomCompassRepository` streams persisted family-visible artifacts, exposes citations and uncertainty, and returns confirmation-only action suggestions. The client never assembles or uploads family context.

## Deliberate exclusions

There is no Journey tab, permanent family map, continuous tracking, battery display, location history, leaderboard, family score, or competitive challenge. A member can volunteer a time-limited update, and Compass must say when no permitted recent information exists.

See the repository [`PRODUCT.md`](../../PRODUCT.md), [`DESIGN.md`](../../DESIGN.md), and [`TODO.md`](../../TODO.md) for the product contract and release gates.

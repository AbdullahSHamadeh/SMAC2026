# Family Compass validation run, 13 to 14 August 2026

This record separates checks completed locally from production and physical-device checks that still require owner accounts, credentials, or hardware.

## Candidate validated

- Flutter app: `0.3.0-dev.1+3`
- Bundle and application ID: `com.smac.familycompass`
- iOS rehearsal device: iPhone 17 Simulator, iOS 26.5
- Android rehearsal device: Family Compass API 36 emulator
- Local authentication rehearsal: Firebase Auth Emulator project `demo-family-compass`
- Firebase development project: `Family Compass` (`family-compass-de2c4`)

## Completed

- 193 Flutter tests passed and Flutter analysis reported no issues.
- 122 FastAPI tests passed. Ruff, Python compilation, formatting, and dependency consistency checks passed.
- Fresh Android debug APK and iOS Simulator debug builds passed and were installed.
- Two separate Firebase Auth Emulator accounts completed the invitation boundary: Dad created an invitation addressed to Noura, Abdullah could not list it, Noura listed and accepted it, and the membership update persisted.
- Arabic RTL and 200 percent Android text were inspected on the emulator.
- Maximum iOS Dynamic Type exposed a tab-bar overflow. The tab bar now keeps native control text sizing while content continues to scale; the repaired Arabic layout was inspected on the simulator.
- TalkBack was enabled on the Android emulator. The accessibility tree exposed all four localized tab labels, positions, and selected state.
- Android airplane mode, process termination, relaunch, and reconnection completed without an app crash. Automated tests also verify scoped durable queue replay and exact notification links.
- Foreground notification notices now use generic English or Arabic copy and open the exact authorized resource without displaying sender names or message bodies.
- APNs readiness now waits for the asynchronous token with a bounded retry before FCM registration.
- The real Firebase development project was created after the owner confirmed
  the Firebase terms. The iOS and Android apps are registered, their native
  files are installed locally and gitignored, the iOS encoded App ID URL scheme
  is configured, and the current Android debug and upload SHA-1 and SHA-256
  fingerprints are registered.
- Firebase Phone authentication is enabled, and the SMS region allowlist
  contains only the UAE. Two UAE-format fictional test numbers are configured,
  and their verification codes are stored only in macOS Login Keychain.
- Both fictional accounts completed real Firebase cloud phone authentication
  and `accounts:lookup` without sending SMS.
- Firebase-enabled debug candidates built for Android and the iOS Simulator.
  Both were freshly installed and opened at the phone-verification onboarding flow. Android
  logs confirmed successful default Firebase initialization; neither candidate
  crashed during launch.
- Android release/profile builds now require a protected upload-key
  configuration, can resolve local secrets from macOS Keychain, and validate
  signing without printing secret values. The upload JKS is stored outside the
  repository under the user's Application Support directory. A
  Firebase-enabled release AAB built successfully and passed `jarsigner`
  verification.
- The physical iPhone has Developer Mode enabled, is paired and unlocked with
  its Developer Disk Image available, and appears in Xcode. A Personal Team now
  appears in Xcode.
- An Apple Development identity and free Personal Team provisioning profile
  were created. The signed Firebase-enabled Profile app was installed
  successfully on the connected physical iPhone. Its Developer App profile was
  trusted and the first physical launch completed successfully.
- The free Personal Team provisioning profile expires after 7 days and must be
  renewed and the app reinstalled for continued local testing.
- The physical iPhone reached Firebase Phone Authentication, but repeated
  requests triggered Firebase's `too-many-requests` protection. The installed
  app now applies a 15-minute local cooldown after that response. Firebase may
  enforce a longer server-side wait that the client cannot reset.
- A separate Profile-only internal mode now accepts one configured fictional
  Firebase account and never requests an SMS. Its raw phone number and code are
  absent from the source and app binary. The signed build passed verification,
  installed, launched from the iPhone Home Screen, and reached the Mac backend
  over the local network.
- The backend's explicit `firebase_local_test` mode verified a fresh live
  Google-signed token for that account. It validates the signing key, algorithm,
  project, issuer, token dates, subject, phone provider, and allowlisted phone
  digest without Firebase Admin credentials. Production `firebase` mode still
  uses Firebase Admin and requires revocation checks.
- The person-operated iPhone flow then completed backend registration and
  family creation. The installed app loaded the authenticated account, opened
  the family event connection, and fetched the initial family, member, message,
  plan, Today, sharing, and Compass collections without sending SMS.

## Not completed and not claimed

- Production backend Application Default Credentials are not configured, so
  the two-account cloud invitation end-to-end flow has not been completed. The
  internal local verifier cannot check revocation and is limited to the
  fictional account and an empty local database. Cloud FCM sending credentials
  and delivery are also unverified.
- The Firebase project is still on the no-cost Spark plan. Real verification
  SMS requires the pay-as-you-go Blaze plan. Billing was not enabled because it
  requires explicit approval; the fictional UAE test accounts remain the
  no-SMS test path.
- The free Personal Team build omits the `aps-environment` entitlement. Paid
  Apple Developer enrollment, an APNs key, and real APNs remain pending.
- No Play App Signing identity is available.
- No physical Android phone is available for this run.
- Real VoiceOver, physical TalkBack, APNs/FCM delivery, locked/background/terminated notification taps, real-radio loss, physical-device logs, and two-device exactly-once behavior remain open.
- Arabic received an automated catalog and emulator layout pass, not a human translation or pronunciation review.
- This one-account iPhone result is not a substitute for the open two-account
  invitation test or the multi-person physical-device pilot.

The physical-device and production items above must remain unchecked in `PROTOTYPE_3_VALIDATION_CHECKLIST.md` until they are run on named devices with real project credentials.

# Family Compass TODO

This file tracks current work. The approved product decisions and historical Prototype 2 implementation plan remain in `docs/`.

## Status legend

- `[x]` Completed and verified
- `[ ]` Not completed
- `Blocked:` cannot proceed until the stated external requirement changes

## Repository and releases

- [x] Preserve Prototype 1 in its own source directory.
- [x] Verify the Prototype 1 source archive checksum.
- [x] Give Prototype 1 Flutter version `0.1.0+1`.
- [x] Place Prototype 2 in a separate source directory.
- [x] Give Prototype 2 Flutter version `0.2.0+2`.
- [x] Add the approved roadmap and Prototype 2 build plan.
- [x] Exclude caches, secrets, local SDKs, generated builds, and the unrelated website experiment.
- [x] Create separate annotated Git tags for Prototype 1 and Prototype 2.
- [ ] Review and merge the GitHub pull request into `main`.
- [ ] Create short GitHub release notes after the pull request is merged.

## Prototype 1: frozen learning artifact

- [x] Preserve the five-tab interface, dashboard, Chat, Journey concept, AI screen, and reminders.
- [x] Keep it runnable as a separate Flutter Web prototype.
- [x] Record its archive checksum and frozen status.
- [x] Make no feature changes. Apply only a documented security or build-recovery fix if required.

## Prototype 2: experience and trust

- [x] Use Today, Chat, private Compass, and Together as the four primary destinations.
- [x] Remove the visible family map, Journey tab, live dot, battery display, scoring, and challenges.
- [x] Complete the Friday dinner draft, poll, response, nudge, confirmation, reminder, contribution, completion, and Plan this again flow.
- [x] Show a manually shared ETA with source, freshness, audience, and Why this answer.
- [x] Provide a neutral unknown-information branch and Request a check-in.
- [x] Add onboarding, manual phone invitations, members, and My Sharing.
- [x] Add portrait, compact landscape, medium-width, dark, and representative Arabic layouts.
- [x] Pass Flutter analysis, nine widget tests, and a Web release build.
- [x] Install full Xcode and CocoaPods, then pass an iOS simulator debug build.
- [x] Install an Android SDK and emulator, then pass an Android debug build and cold-launch smoke test.
- [ ] Install and smoke-test the prototype on one named physical phone.
- [x] Add automated contracts for Today ordering and gathering state transitions.
- [x] Add automated contracts for check-ins, reminders, one-time nudges, notification denial, AI failures, and fixed-clock freshness.
- [x] Complete the automated large-text and semantics pass at 200 percent.
- [ ] Complete a real VoiceOver and TalkBack pass on physical phones.
- [ ] Test with 8 to 12 adults across at least three families.
- [ ] Write the usability report and decision log.
- [ ] Freeze Prototype 3 scope only after the Prototype 2 exit gate is met.

Blocked: the remaining Prototype 2 exit checks require physical phones and consenting adult pilot families.

## Version 1 foundation: active development

- [x] Preserve Prototype 1 and Prototype 2 as separate frozen source trees.
- [x] Create the active Flutter application at `apps/family_compass` with version `0.3.0-dev.1+3`.
- [x] Record the product contract in `PRODUCT.md` and the Sunday Table system in `DESIGN.md`.
- [x] Redesign Today, Chat, private Compass, Together, onboarding, family controls, and My Sharing without a visible map or Journey destination.
- [x] Add adaptive compact, landscape, and expanded structures plus English, Arabic RTL, light, and dark foundations.
- [x] Add repository contracts that separate the Flutter interface from authentication, storage, messaging, sharing, plans, and AI transport.
- [x] Replace the unsafe API scaffold with family-scoped authorization, masked invitations, explicit expiring updates, versioned plans, private Compass, and server-authorized AI context.
- [x] Pass Flutter analysis with no issues and the complete active Flutter test suite.
- [x] Pass the complete FastAPI suite and `python3 -m compileall -q app tests`.
- [x] Complete the release Web build.
- [x] Complete the automated 200 percent text pass across all four primary destinations.
- [x] Complete the widget semantics pass for the key family-visible Chat actions.
- [x] Replace the generic card-dashboard treatment with the native Sunday Table direction and complete an independent finish review and repair loop.
- [x] Replace Flutter's Android and iOS placeholder IDs with the foundation namespace `com.smac.familycompass` and move Android `MainActivity` to the matching Kotlin package.
- [x] Persist selected sharing recipients, abstain on unsupported Compass questions, preserve offline Chat drafts, recover from failed retries, and honor system Back throughout onboarding.
- [x] Persist explicit English and Arabic choices and dark appearance, and validate invitation sending with a durable masked result.
- [x] Connect private Compass through FastAPI to a loopback-only LM Studio provider for ordinary questions and authorized family facts, with loading, retry, and honest failure states.
- [x] Make onboarding validation, Chat Send, custom poll-time suggestions, and Plan this again change visible prototype state.
- [x] Implement the complete FastAPI repository adapters in Flutter and keep deterministic fixtures behind the default demonstration mode.
- [x] Add persistent SQLAlchemy storage, signed development tokens, Firebase ID-token verification, and a verified Firebase Auth Emulator path.
- [x] Add authenticated WebSocket reconnect, offline message replay, custom notification deep links, and family leave, remove, revoke, and delete controls.
- [x] Wire the opt-in Firebase Flutter flow for SMS send, resend, six-digit verification, ID-token refresh, backend account registration, settings-only notification consent, FID replacement, and sign-out cleanup while preserving deterministic demo onboarding.
- [x] Remove Android's debug-key fallback from release builds and add a gitignored upload-key configuration seam plus a nonsecret example.
- [x] Configure the development Firebase project, register the iOS and Android apps, enable Phone sign-in, restrict SMS regions to the UAE, and add two UAE-format fictional test accounts with codes kept only in macOS Login Keychain.
- [x] Complete real Firebase cloud phone authentication and `accounts:lookup` for both fictional accounts without sending SMS.
- [x] Configure protected Android upload signing, register its SHA-1 and SHA-256 with Firebase, and build and verify a signed Firebase-enabled release AAB.
- [x] Create an Apple Development identity and free Personal Team provisioning profile, then install the signed Firebase-enabled Profile app on the connected iPhone so it opens directly from the Home Screen.
- [x] Add an isolated local verifier for one allowlisted fictional Firebase phone account, verify a live Google-signed test token, and keep production Firebase Admin revocation checks as the secure default.
- [ ] Configure production backend Application Default Credentials and complete the two-account cloud invitation end-to-end test.
- [ ] Configure Apple signing and provisioning, Play App Signing, and the final App Store and Play Store records.
- [x] Connect a newly registered Firebase account's create-family or invitation choice to live repository calls, then rebuild family-scoped repositories, offline scope, notification registration, and realtime subscriptions from the returned user and family IDs instead of build-time pilot IDs.
- [x] Replace implicit invitation acceptance with a recipient-only multi-invitation chooser that shows family, inviter, masked phone, role, and expiry before explicit Accept or Decline.
- [x] Derive the poll-nudge disabled state from the backend `nudge_delivered_at` timestamp across refresh and relaunch, leave failed attempts retryable, and guard rapid duplicate taps.
- [x] Make Together create a private draft, publish the selected candidates explicitly, accept participant time suggestions, and persist reminder adjustments through the backend.
- [x] Resolve notification links by fetching the exact authorized message, plan, or reminder, preserve that target through stale stream emissions, and clear old family data immediately when membership or the family is removed elsewhere.
- [x] Pass the 193-test Flutter suite, 122-test FastAPI suite, Flutter analysis, Python compilation and lint, dependency consistency and vulnerability checks, and fresh Android, iOS Simulator, and Web builds.
- [ ] Keep this work untagged until the Prototype 3 and Version 1 exit gates are met.

## Prototype 3: functional multi-device pilot

### The nine-point pre-pilot list

This is the exact implementation list previously summarized in the task:

1. [x] Persistent development database and a verified Firebase Authentication test setup.
2. [x] Flutter repository interfaces implemented against FastAPI.
3. [x] Create-family and phone-invitation lifecycle, including accept, decline, revoke, expire, leave, remove, and delete APIs.
4. [x] Persistent messages, plans, polls, reminders, statuses, permissions, and sharing records.
5. [x] Authenticated real-time Chat events, reconnect, and an idempotent offline message queue.
6. [x] Notification service and device-token boundary plus native deep-link routing. Real APNs and FCM delivery remains in the external gate below.
7. [x] Today and Together driven by authorized repository data.
8. [x] Security and privacy tests proving family isolation and the AI context boundary.
9. [ ] Run the real multi-phone, three-family pilot. This requires the owner, physical phones, production test credentials, and consenting adult families.

Local engineering foundation:

- [x] Choose and document SQLite or PostgreSQL development storage and the Firebase Authentication Emulator setup.
- [x] Implement create, invite, accept, decline, revoke, expire, leave, remove-member, and organizer deletion flows.
- [x] Define authorization, consent, retention, deletion, and recycled-phone-number behavior in `docs/SECURITY_PRIVACY_MODEL.md`.
- [x] Persist messages, plans, polls, responses, reminders, contributions, statuses, journeys, and sharing policies.
- [x] Implement authenticated real-time text Chat, reconnect, an offline message queue, and deterministic check-in cards.
- [x] Implement the notification provider boundary, device registrations, and OS deep links into the exact chat, poll, plan, or reminder.
- [x] Request notification permission only from the explicit Family settings control, upload Firebase Installation IDs rather than deprecated registration tokens, and unregister before Firebase sign-out.
- [x] Connect Today and Together to authorized family data through Flutter repository adapters.
- [x] Implement the provider-neutral AI service behind FastAPI.
- [x] Add accessible current-family mention suggestions in Chat and make a distinct `@Compass` mention invoke the same authorized context service as private Compass, with separate audiences and histories.
- [x] Enforce permission, audience, expiry, and provider-consent checks before constructing AI input.
- [x] Return source, freshness, audience, and honest abstention with relevant Compass answers.
- [x] Require human confirmation before an AI draft affects another person.
- [x] Test provider timeout, rate limit, unavailable, policy-denied, and malformed-output states.
- [x] Add security tests for cross-family isolation, concurrent writes, revocation, redaction, and unauthorized AI context.

External pilot gate:

- [x] Configure development Firebase Phone authentication, a UAE-only SMS region allowlist, two UAE-format fictional accounts with Keychain-only codes, native app credentials, and Android debug and upload certificate fingerprints.
- [x] Verify real Firebase cloud phone authentication and `accounts:lookup` for both fictional accounts without sending SMS.
- [x] Create the protected Android upload key outside the repository and verify a signed release AAB.
- [x] Create a free Personal Team Apple Development identity and provisioning profile and install the signed Firebase-enabled Profile app on the connected iPhone.
- [x] Install and launch a no-SMS internal Profile build on the physical iPhone and verify its one-account Firebase token path against the local backend without embedding the phone number or code.
- [ ] Configure backend Firebase Admin Application Default Credentials, APNs, and FCM delivery.
- [x] Trust the Developer App profile in iPhone Settings and verify the first launch of the installed app on the physical iPhone.
- [x] Preserve safe Firebase Phone Authentication reference codes and add a 15-minute client cooldown after `too-many-requests`.
- [ ] With explicit billing approval, upgrade Firebase from Spark to Blaze before testing real verification SMS; do not retry the currently throttled number until Firebase lifts its server-side restriction.
- [ ] Complete paid Apple Developer enrollment and production Apple signing assets, enroll in Play App Signing, and register the production signing credentials with Firebase.
- [ ] Verify notification delivery and deep links while each app is foregrounded, backgrounded, terminated, and opened from a locked phone.
- [ ] Run the physical iPhone and Android, VoiceOver, TalkBack, network-loss, and cross-platform matrix in `docs/PROTOTYPE_3_VALIDATION_CHECKLIST.md`.
- [ ] Run the 8 to 12 adult, three-family pilot and record gathering, retention, pressure, and trust results.
- [ ] Delete pilot data, write the decision report, and freeze the Version 1 scope from evidence.

Pending: the physical iPhone has Developer Mode enabled, is paired and unlocked with its Developer Disk Image available, and appears in Xcode. An Apple Development identity and free Personal Team provisioning profile were created, and the signed Firebase-enabled Profile app was installed and launched successfully without Flutter tooling. The Personal Team profile expires after 7 days and must be renewed and the app reinstalled for continued local testing. This build omits the `aps-environment` entitlement, so real APNs remains pending paid Apple Developer enrollment. No physical Android phone is available for this run.

## Version 1: production release

- [ ] Harden authentication, session recovery, invitation abuse controls, and account deletion.
- [ ] Complete threat modeling, security review, dependency audit, and privacy review.
- [ ] Add production observability without logging private family content.
- [ ] Complete accessibility, Arabic localization, offline recovery, and supported-device testing.
- [ ] Add data export, deletion, consent history, and support workflows.
- [ ] Prepare App Store and Play Store privacy disclosures, screenshots, support pages, and release processes.
- [ ] Meet the Version 1 reliability and trust exit gate before assigning version `1.0.0`.

## Version 2A: easier gathering

- [ ] Improve candidate-time suggestions using explicit availability and prior plan choices.
- [ ] Add saved family rituals and Plan this again improvements.
- [ ] Add rides, food, and voluntary contribution coordination after plan confirmation.
- [ ] Tune reminders and digests to reduce pressure and notification fatigue.
- [ ] Measure repeated confirmed gatherings, not message volume or family-member rankings.

## Version 2B: optional context experiments

- [ ] Keep every context experiment separately consented and feature-flagged.
- [ ] Test user-started temporary trip context before considering any background behavior.
- [ ] Label system-derived context separately from member-shared information.
- [ ] Add strict expiry, audience, pause, correction, and deletion controls.
- [ ] Run a fresh privacy and platform-policy review before each experiment.
- [ ] Remove any experiment that creates tracking pressure or repeated privacy misunderstanding.

## Permanent exclusions

- [x] Do not add a permanent family map.
- [x] Do not let one adult override another adult's sharing controls.
- [x] Do not let an AI model decide permissions.
- [x] Do not invent, infer, or impersonate a family member's reply.
- [x] Do not add leaderboards, care scores, coercive streaks, or competitive family rankings.
- [x] Do not silently publish, reschedule, cancel, assign, or disclose an AI draft.

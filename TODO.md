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
- [ ] Make no feature changes. Apply only a documented security or build-recovery fix if required.

## Prototype 2: experience and trust

- [x] Use Today, Chat, private Compass, and Together as the four primary destinations.
- [x] Remove the visible family map, Journey tab, live dot, battery display, scoring, and challenges.
- [x] Complete the Friday dinner draft, poll, response, nudge, confirmation, reminder, contribution, completion, and Plan this again flow.
- [x] Show a manually shared ETA with source, freshness, audience, and Why this answer.
- [x] Provide a neutral unknown-information branch and Request a check-in.
- [x] Add onboarding, manual phone invitations, members, and My Sharing.
- [x] Add portrait, compact landscape, medium-width, dark, and representative Arabic layouts.
- [x] Pass Flutter analysis, nine widget tests, and a Web release build.
- [ ] Install full Xcode and CocoaPods, then pass an iOS simulator debug build.
- [ ] Install an Android SDK and emulator, then pass an Android debug build.
- [ ] Install and smoke-test the prototype on one named physical phone.
- [ ] Add contract tests for Today ordering and removal of the single suggestion after poll publication.
- [ ] Add contract tests for check-in transitions, separate reminder confirmation, disabled nudge, notification denial, AI unavailable, and fixed-clock freshness.
- [ ] Complete a large-text pass at 200 percent and a real screen-reader pass.
- [ ] Test with 8 to 12 adults across at least three families.
- [ ] Write the usability report and decision log.
- [ ] Freeze Prototype 3 scope only after the Prototype 2 exit gate is met.

Blocked: native build verification requires full Xcode or an Android SDK on the development computer.

## Prototype 3: functional multi-device pilot

- [ ] Choose and document the development database and Firebase Authentication test setup.
- [ ] Implement create, invite, accept, decline, revoke, expire, leave, and remove-member flows.
- [ ] Define authorization, consent, retention, deletion, and recycled-phone-number behavior before connecting AI.
- [ ] Persist plans, polls, responses, reminders, contributions, statuses, and sharing policies.
- [ ] Implement real-time text Chat with offline queue and deterministic check-in cards.
- [ ] Add push notifications and deep links into the exact chat, poll, or plan.
- [ ] Connect Today to real family data.
- [ ] Implement the provider-neutral AI service behind FastAPI.
- [ ] Enforce permission checks before constructing any AI input.
- [ ] Return source, freshness, audience, and honest abstention with every relevant Compass answer.
- [ ] Add confirmation before AI drafts affect another person.
- [ ] Test provider timeout, rate limit, unavailable, and malformed-output states.
- [ ] Add security tests that prove unauthorized family context never reaches the model.
- [ ] Run a small real-family multi-device pilot and record retention and trust results.

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

- [ ] Do not add a permanent family map.
- [ ] Do not let one adult override another adult's sharing controls.
- [ ] Do not let an AI model decide permissions.
- [ ] Do not invent, infer, or impersonate a family member's reply.
- [ ] Do not add leaderboards, care scores, coercive streaks, or competitive family rankings.
- [ ] Do not silently publish, reschedule, cancel, assign, or disclose an AI draft.

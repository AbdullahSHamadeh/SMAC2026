# Changelog

Family Compass uses immutable tags for completed prototypes and keeps unfinished production work on pre-release versions. See `VERSIONS.md` for the complete policy.

## Unreleased: Version 1 foundation and Prototype 3 backend

- Current app version: `0.3.0-dev.1+3`
- Current API version: `0.3.0-dev.1`
- Database schema: `4`

- Rebuilt the active client as an adaptive Flutter mobile application with Today, Chat, private Compass, Together, onboarding, invitations, family controls, English and Arabic, light and dark appearance, and accessibility contracts.
- Added persistent FastAPI data, permissions, invitations, messages, plans, polls, reminders, voluntary statuses, authenticated events, offline replay, notification links, and provider-neutral AI context controls.
- Added optional Firebase phone authentication and notification seams while keeping native credentials, signing secrets, fictional test codes, and local databases outside Git.
- Added a Profile-only no-SMS test path for one allowlisted fictional Firebase account. Production Firebase verification still requires Admin credentials and revocation checking.
- Added iOS, Android, Firebase, privacy, dependency, validation, design, and physical-pilot documentation.
- Installed and launched the signed Profile build on one physical iPhone. Production signing, notifications, a physical Android test, accessibility-device checks, and the multi-family pilot remain gated.

This development line is intentionally untagged until the Prototype 3 and Version 1 exit gates pass.

## `prototype-2-v0.2.0`

- Replaced the visible Journey and map concept with the four-part Today, Chat, private Compass, and Together structure.
- Validated the gathering loop, sourced reassurance, privacy controls, responsive layouts, Arabic, and dark appearance through deterministic scenarios.

## `prototype-1-v0.1.0`

- Preserved the first broad exploration with a dashboard, Chat, Journey concept, AI screen, and reminders.

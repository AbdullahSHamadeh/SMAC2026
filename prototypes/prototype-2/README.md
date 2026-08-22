# Family Compass Prototype 2

Prototype 2 is the frozen consent-first Flutter experience prototype that preceded the active Version 1 foundation.

- Flutter package version: `0.2.0+2`
- Git tag: `prototype-2-v0.2.0`
- Primary destinations: Today, Chat, private Compass, Together
- Data: deterministic local scenarios
- Backend connection: intentionally disabled for this prototype

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Use `flutter run -d chrome` for a quick browser preview. The repository also contains iOS and Android runners for computers with the matching native toolchains.

Long press the Family Compass wordmark in the app bar to switch among the prepared dinner, poll, reassurance, unknown, empty, offline, AI-unavailable, sharing-paused, and notification-denied scenarios.

## Scope

Prototype 2 proves the four-tab structure, complete gathering loop, sourced reassurance without a visible map, and understandable sharing controls. It does not connect to real GPS, SMS, notifications, a database, or an AI provider.

See the repository `README.md`, `TODO.md`, and `docs/` directory for the full product direction.

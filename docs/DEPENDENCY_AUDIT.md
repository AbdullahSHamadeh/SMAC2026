# Dependency audit

Audit date: 13 August 2026

## Backend

The Python requirements were audited with `pip-audit` after installing the
development and Firebase requirement sets. The first pass found published
advisories affecting `pytest 8.4.1` and `starlette 0.47.3`.

The pinned development stack was updated to:

- `fastapi 0.141.1`
- `starlette 1.6.0`
- `pytest 9.1.1`

The isolated backend environment also updates packaging tools to `pip 26.2.1`
and `setuptools 84.0.0` to address advisories published after the first audit.
The follow-up audit reports no known vulnerabilities. `pip check` also reports
no broken requirements, Ruff passes with the documented FastAPI dependency
declaration exception, and all 122 backend tests pass.

A redacted Gitleaks directory scan also reports no secrets in the working
project. A documentation example that looked like a literal authorization
header was rewritten before the clean follow-up scan.

## Flutter

`flutter pub outdated` reports that the application resolves its production
dependencies without a forced major upgrade. `intl 0.20.3` is available while
the current localization toolchain resolves `0.20.2`. `flutter_lints 6.0.0` is
a separately resolvable development-only major update. Transitive test and SDK
packages remain controlled by the installed Flutter SDK.

No dependency was upgraded only to make the version list empty. Production
changes require the normal analysis, tests, and native build checks.

## Release rule

Run the backend audit, Flutter outdated report, tests, and native builds again
for every signed release candidate. A clean audit is evidence about published
advisories at that point in time, not a substitute for threat modeling,
authorization tests, secret scanning, or platform privacy review.

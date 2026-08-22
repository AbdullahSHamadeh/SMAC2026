# Family Compass FastAPI foundation

This service is the persistent backend foundation for the Family Compass mobile app. It keeps family coordination private by default, checks family access at every protected route, and sends only authorized facts through the AI provider boundary.

The default development database is SQLite at `.data/family_compass.db`. The same SQLAlchemy store accepts a PostgreSQL `DATABASE_URL`. Deterministic seed data is inserted only when the user table is empty.

## Run locally

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt

export FAMILY_COMPASS_AUTH_MODE=dev
export FAMILY_COMPASS_DEV_AUTH_SECRET="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000/docs` for the interactive API. Authentication is disabled when `FAMILY_COMPASS_AUTH_MODE` is not configured, so protected routes return `503` instead of silently trusting a user header.

Generate a one-hour bearer token for the seeded Abdullah account:

```bash
python -m app.dev_token 11111111-1111-1111-1111-111111111111
```

Use the printed value as `Authorization: Bearer <token>`. Development tokens are HMAC signed, expire, are audience-bound, and require a secret of at least 32 bytes. The old `X-Demo-User` behavior exists only for explicitly constructed test apps. It cannot be enabled through an environment flag.

## Database

The default setting is:

```text
DATABASE_URL=sqlite+pysqlite:///./.data/family_compass.db
```

For PostgreSQL, use either a standard `postgresql://...` URL or the explicit driver form:

```text
DATABASE_URL=postgresql+psycopg://user:password@host:5432/family_compass
```

`app/database.py` creates one table per aggregate and records schema version `4` in `schema_versions`. The current schema adds persistent family-room Compass artifacts together with membership, device-token, phone-number, and Firebase auth-subject integrity claims. Existing version 1 through 3 development databases create the new tables, advance to version 4, and backfill integrity claims at startup. Initialization is idempotent. An unknown schema version stops startup instead of attempting an unsafe automatic conversion. Add a managed migration tool before any production schema change.

The API depends on repository protocols rather than SQLAlchemy sessions. The in-memory store remains available for isolated tests, and another persistence adapter can be introduced without changing route logic.

Set `FAMILY_COMPASS_SEED_DEMO_DATA=false` to start with an empty database.

## Authentication modes

`FAMILY_COMPASS_AUTH_MODE` accepts:

- `disabled`: Protected routes return `503`. This is the safe default.
- `dev`: Accepts short-lived signed tokens produced by `python -m app.dev_token`.
- `firebase`: Verifies Firebase ID tokens through Firebase Admin.
- `firebase_local_test`: Verifies Google-signed Firebase ID tokens without
  Admin credentials for one SHA-256-allowlisted fictional phone account. It
  cannot check revocation and is restricted to isolated local testing.

For Firebase Admin support:

```bash
pip install -r requirements-firebase.txt
export FAMILY_COMPASS_AUTH_MODE=firebase
export FIREBASE_PROJECT_ID=your-project-id
```

Firebase Application Default Credentials are used outside the emulator. For local emulator testing, also set `FIREBASE_AUTH_EMULATOR_HOST`, such as `127.0.0.1:9099`. A verified Firebase `uid` maps to `User.auth_subject`. After a first phone sign-in, `POST /api/v1/auth/phone/register` accepts only a token whose Firebase sign-in provider is `phone`, links the verified phone number to one local user atomically, and returns no phone number.

For the isolated physical-iPhone test build, use `firebase_local_test` with a
fresh unseeded database and the lowercase SHA-256 digest of the configured
fictional phone number. The raw phone number and verification code must remain
outside the repository. This mode checks Google's token signature and standard
Firebase claims, but it cannot check account revocation. It must not contain
real-family data or be exposed as a production service.

### Firebase Auth emulator smoke test

The repository root contains `firebase.json` and `.firebaserc` configured for the local-only `demo-family-compass` project. No cloud Firebase project or credentials are needed.

From the repository root, start Auth Emulator and its UI:

```bash
npx firebase-tools@latest emulators:start \
  --only auth \
  --project demo-family-compass
```

In another terminal, prepare and run the backend:

```bash
cd family_compass_backend
source .venv/bin/activate
pip install -r requirements-firebase.txt
export FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
export FIREBASE_PROJECT_ID=demo-family-compass
python -m app.firebase_emulator_seed
export FAMILY_COMPASS_AUTH_MODE=firebase
uvicorn app.main:app --reload
```

The seed helper refuses non-loopback emulator hosts and non-demo project IDs. It creates four local accounts with the password `family-compass-local-only`. Obtain an Abdullah ID token and call the protected API:

```bash
curl -sS \
  'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local-demo-key' \
  -H 'Content-Type: application/json' \
  -d '{"email":"abdullah@family-compass.test","password":"family-compass-local-only","returnSecureToken":true}'

# Copy the returned local-only idToken into your API client's Bearer token
# field, then request http://127.0.0.1:8000/api/v1/me.
```

The expected API result identifies Abdullah and does not include a phone number. The automated suite uses an injected Firebase token verifier because it does not start Node or background emulators; it also tests that Firebase subjects must match `User.auth_subject` and that the seed helper accepts loopback hosts only.

## Implemented access boundaries

- Every family route requires membership in that family. A family creator becomes its organizer.
- Organizer-only permission changes are enforced on the server.
- Family invitation creation and family-scoped listing require invite permission. `GET /api/v1/invitations` returns only pending, unexpired inbound invitations whose phone number matches the authenticated account. Acceptance and decline require the same match. Revocation is limited to the inviter or organizer. Phone numbers are masked in responses.
- The organizer can delete the family aggregate in one transaction without deleting individual user accounts.
- Message sender and family IDs come from the authenticated request context.
- Shared updates are voluntary, audience-filtered, and limited to 24 hours. Narrowing an audience emits content-free redaction events to former recipients.
- Member status and journey summaries require an explicit audience, are voluntary, temporary, and owner-controlled. They contain no coordinate, route, battery, or history field.
- Plan creation validates family participants and time zones. Replies require participation. Confirmation, nudges, and completion require the coordinator or organizer.
- Family reminders can be listed, created, updated, completed, and deleted. Plan-linked reminders stay synchronized with their plan.
- Check-in requests require both people to belong to the family.
- Private Compass conversations are not persisted or copied into family Chat.
- A deliberate family-visible request uses `POST /api/v1/families/{family_id}/compass/family-room` and must contain a distinct `@Compass` mention. The mention can appear naturally anywhere in the message; names such as `@CompassBot` do not invoke the assistant.
- The backend selects relevant, authorized, unexpired facts before calling an AI provider. Family-room requests can use only whole-family facts.
- External AI context also requires the relevant members' explicit provider consent.

The API has no precise or passive tracking contract. A journey is a member-authored summary with an optional ETA and required expiry, not a location stream.

## Live events and notifications

An authenticated client can subscribe at:

```text
WS /api/v1/families/{family_id}/events
```

The bearer token is sent in the WebSocket `Authorization` header. The server verifies identity and family membership before accepting the connection. Message, invitation, plan, reminder, status, and journey changes are sent as `FamilyEvent` JSON. The development event bus is process-local. A multi-instance deployment should replace it with Redis or another shared broker.

Clients register an iOS or Android Firebase Installation ID (FID) with `POST /api/v1/me/device-tokens`. The compatibility route name remains unchanged, and responses never echo the FID. Message, plan, reminder, and check-in notifications include a `familycompass://` deep link. Lock-screen copy is generic; protected detail is fetched after authentication. `FAMILY_COMPASS_NOTIFICATION_PROVIDER=memory` is the network-free default. Select `fcm` after installing `requirements-firebase.txt` to use the Firebase Cloud Messaging adapter. It sends to FIDs in groups of 500 and removes installations FCM reports as unregistered.

Cloud-project, APNs, SMS-region, SHA, signing, and physical-device steps are in [`docs/FIREBASE_PRODUCTION_SETUP.md`](../docs/FIREBASE_PRODUCTION_SETUP.md).

## AI provider boundary

`app/ai_service.py` contains a deterministic local mock and an OpenAI-compatible adapter. Private Compass and `@Compass` in Chat call the same authorization and retrieval service, with separate private and family-room histories. Route code authorizes and minimizes family facts before constructing `AuthorizedAIRequest`. Eligible context includes a bounded window of recent messages written by current family members, active plans and poll replies, future reminders, check-in requests involving the requester, and currently shared statuses, ETAs, and updates. Family-room answers receive only whole-family context. Every returned citation includes its source record, source type, audience, freshness, update time, and expiry. Providers receive no database access, phone number, family ID, or user ID.

Creative activity ideas and ordinary family advice are classified as general questions even when they contain words such as `family`, `together`, or `tonight`. They reach the configured model with an empty family-context list and return without citations or actions. Explicit questions about current plans, statuses, Chat messages, shared updates, and reminders remain family-grounded. This classification and every citation are selected by backend policy, never by the model.

Private responses are marked `private`. Family-room answers are persisted as separate Compass artifacts and can be listed with `GET /api/v1/families/{family_id}/compass/family-room`. The backend ignores provider-invented actions, maps only an allowlist of plan, reminder, and check-in actions, and marks every consequential action as requiring confirmation. It never performs an action as part of an AI answer.

To use LM Studio, load a chat model and start its local server, then run:

```bash
export FAMILY_COMPASS_AI_PROVIDER=lm_studio
export FAMILY_COMPASS_AI_MODEL=google/gemma-3-4b
export LM_STUDIO_BASE_URL=http://127.0.0.1:1234/v1
uvicorn app.main:app --reload
```

LM Studio mode rejects non-loopback URLs. For a hosted OpenAI-compatible service, set `FAMILY_COMPASS_AI_PROVIDER=openai_compatible`, `FAMILY_COMPASS_AI_BASE_URL`, `FAMILY_COMPASS_AI_MODEL`, and optionally `FAMILY_COMPASS_AI_API_KEY`.

## Verify

```bash
python -m pytest -q
python -m compileall -q app tests
python -m ruff check app tests
python -m pip check
python -m pip_audit
```

All 122 backend tests pass. The suite covers persistence across application restarts, schema initialization and migration, PostgreSQL DDL compatibility, signed-token expiry and tampering, Firebase phone registration and subject mapping, cross-family isolation, structured current-member mentions, explicit invitation choice and transitions, invitation-event audiences and concurrency, private plan drafts and publishing, participant time suggestions, plans and one-time nudges, temporary status and journey summaries, narrowing redactions, authenticated WebSocket fanout, immediate socket closure after family deletion, unique device ownership, privacy-safe notification payloads and exact links, bounded authorized Chat retrieval, durable question-first family-room replies, private versus family-room isolation, AI fact minimization, action confirmation contracts, and provider failures.

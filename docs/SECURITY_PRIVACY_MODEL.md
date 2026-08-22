# Prototype 3 security and privacy model

This document defines the local pilot contract. It is an implementation record,
not a completed production security review.

## Data boundary

Family Compass stores family membership, text messages, plans, votes,
reminders, check-ins, voluntary status summaries, and voluntary journey
summaries. It has no API field for coordinates, routes, battery state, passive
location, or movement history. The mobile app has no permanent map screen.

A journey is short text written by the member, with an optional ETA, an explicit
audience, and a required expiry. It is not inferred from device location.

## Identity and sessions

The backend fails closed when authentication is not configured. Local work can
use either:

- short-lived, audience-bound HMAC development tokens;
- Firebase ID tokens verified by Firebase Admin, including the loopback-only
  Auth Emulator setup in `family_compass_backend/README.md`.

`X-Demo-User` is available only to explicitly constructed automated test apps.
It cannot be enabled in the normal server process.

The Flutter HTTP data mode sends a bearer token and never constructs a trusted
user or family header. A production mobile build still needs Firebase phone
sign-in, token refresh, account recovery, and abuse controls configured with a
real Firebase project.

## Family authorization

Every family resource is loaded through authenticated family membership. The
server decides sender, requester, and subject identity. Clients do not choose
those identities in request bodies.

- The organizer can change invite permission, remove members, and delete the
  family.
- A member with invite permission can create and list invitations.
- Only the inviter or organizer can revoke an invitation.
- A member can leave, unless they are the organizer of a family that still has
  other members.
- Removing or leaving ends later HTTP and WebSocket access.
- Deleting a family removes its memberships, invitations, messages, updates,
  plans, check-ins, reminders, statuses, and journeys in one transaction. User
  accounts remain intact.

## Phone invitations

Invitation responses mask the phone number. Acceptance and decline require the
authenticated account's normalized phone number to match the invitation. An
invitation expires and cannot be accepted after expiry, revocation, acceptance,
or decline. Concurrent acceptance creates no duplicate membership.

For a production launch, add SMS delivery, rate limits by account, family,
number, device, and network, generic recovery responses, number-change review,
and recycled-number protection. A verified phone number proves current control
of the number. It does not prove that the person is the historical owner or the
intended relative.

## Sharing and retention

Status and journey writes require the member to select one of these audiences:

- only me;
- the whole current family;
- selected current family members.

Selected recipients are validated against current membership. Status and
journey records have a maximum lifetime of 24 hours. Paused, revoked, and
expired records are unavailable to other family members and to Compass. The
cleanup path physically deletes expired sensitive records. When an audience is
narrowed, former recipients receive a metadata-only redaction event and must
remove their cached copy.

People can still remember, photograph, or copy information they already saw.
The app must not claim that revocation erases those external copies.

## Chat, plans, and retries

Message and plan creation use client identifiers so reconnecting does not create
duplicates. Plan replies and confirmation use an expected version to reject
stale writes. A nudge is a one-time operation, including when two requests arrive
at the same time. Offline Chat keeps a local pending write and retries with its
original client identifier.

The development WebSocket bus rechecks token validity and family membership for
delivery. A stale socket cannot turn an already committed HTTP write into an
error. The bus is process-local and must be replaced by a shared authenticated
broker before a multi-instance deployment.

## Notifications and devices

Device registration responses never echo a token. The stored token is uniquely
owned, and simultaneous claims from different accounts cannot create two
owners. Unregistering a device stops later delivery.

Notification payloads carry an opaque family resource identifier and a
`familycompass://` deep link. Protected content is fetched after the app opens
and authenticates. The memory provider is used for automated tests. Real APNs
and FCM delivery, locked-screen copy, token rotation, and physical-device
behavior remain external validation items.

## AI boundary

The mobile app sends the user's question and requested visibility. It does not
assemble family context. The backend performs this sequence before a provider is
called:

1. Authenticate the requester.
2. Verify current family membership.
3. Classify the question narrowly.
4. Select only current, unexpired facts relevant to that classification.
5. Check the fact's audience for this requester.
6. Check every data subject's external-provider consent when the provider uses
   external processing.
7. Remove internal user IDs, family IDs, phone numbers, and unauthorized facts.

The provider receives an `AuthorizedAIRequest`, not database access. Family
answers cite source, freshness, and audience. Missing or disallowed facts cause
an abstention. General questions do not receive family plans merely because
their text contains a word such as “family.” Family activity ideas, creative
prompts, and ordinary relationship advice are also general unless the person
explicitly asks about a current plan, status, Chat message, update, or reminder.
General answers carry no family citations or actions. Actions that would
message, remind, assign, publish, or change another person's information remain
drafts until a person confirms them.

Private Compass prompts and answers are not stored in family Chat. A
family-visible request uses a separate endpoint, must contain a distinct
`@Compass` mention anywhere in the message, and
can receive only facts whose audience is the whole family. Its answer is stored
as a traceable family-room artifact. Provider-suggested actions are discarded
unless they match the backend allowlist, and every consequential artifact is
marked as requiring confirmation. Answer generation never executes the action.
Both surfaces use the same backend authorization and retrieval service, but
their histories and audiences remain separate. Recent Chat retrieval is
bounded by age and count, excludes pending and Compass-generated messages, and
rejects messages from people who are no longer current family members.

## Logs and test data

Do not log bearer tokens, phone numbers, message bodies, Compass prompts,
provider inputs, or voluntary status details. Automated tests use fictional
fixed identities. Pilot records must use pseudonymous participant IDs and must
be deleted after the agreed retention period.

## Verification boundary

The automated suites prove route authorization, cross-family isolation,
audience and expiry filtering, AI input minimization, concurrent write behavior,
offline retry, deep-link parsing, adaptive layout, RTL, semantics, and provider
failure states.

They do not replace:

- a production threat model and independent security review;
- Firebase phone-auth, APNs, and FCM configuration with real credentials;
- VoiceOver and TalkBack on physical phones;
- locked, backgrounded, and terminated notification tests;
- a cross-platform multi-device pilot with at least three consenting adult
  families;
- store privacy disclosures, deletion support, incident response, and production
  monitoring.

Use `PROTOTYPE_3_VALIDATION_CHECKLIST.md` for those external checks.

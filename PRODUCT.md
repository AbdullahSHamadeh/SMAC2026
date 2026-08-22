# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Stack

- Flutter mobile client for iOS and Android, with Flutter Web used only as a convenient preview target.
- FastAPI service boundary for identity, family data, coordination, permissions, and provider-neutral AI access.
- SQLAlchemy repository layer with SQLite for the local pilot and a PostgreSQL-compatible production path.
- Signed, expiring development bearer sessions plus a runnable Firebase Authentication emulator setup. Firebase ID-token verification is the selected pilot identity path.
- Authenticated family WebSocket events, a durable mobile write queue, and notification adapters with a network-free development provider and optional FCM.
- OpenAI-compatible AI provider boundary tested with a deterministic mock and designed for LM Studio, OpenAI, vLLM, or another compatible provider.

## Users

Family Compass is for adult family members, including families whose members live in different homes or time zones. A person opens it to see the next shared family moment, answer a pending family decision, coordinate a plan, exchange messages, or ask a private question about information another member deliberately shared.

Version 1 does not support production accounts for minors. That requires a separate safety, consent, policy, and legal workstream.

## Product Purpose

Family Compass has two outcomes, in this order:

1. Help families spend more time together.
2. Reduce everyday uncertainty through information each person chooses to share.

Success means families can move from an opportunity to a confirmed gathering with little effort, then repeat that behavior without feeling tracked or pressured.

## Positioning

Family Compass turns family-approved context into timely answers and coordinated plans without placing anyone on a permanent map. It combines a familiar family room, a private grounded assistant, and a complete planning loop. It is not intended to replace a general messaging platform or let AI speak for a person.

## Operating Context

- A family notices a chance to gather, proposes an idea and candidate times, collects replies, confirms the plan, coordinates contributions, receives a reminder, and can plan it again later.
- Today shows the next gathering, decisions that need the current person's reply, relevant shared updates, and at most one useful suggestion.
- Chat contains family messages, check-ins, and shared plan, poll, and reminder artifacts.
- Compass is private to the account holder. Family-visible Compass requests are deliberate and clearly labeled.
- Together holds proposed, undecided, confirmed, and later family plans.
- Members can explicitly share a status, check-in, or manually entered ETA with an audience and expiry.

## Capabilities and Constraints

- Exactly four primary destinations: Today, Chat, Compass, and Together.
- Profile, invitations, family members, permissions, sharing, notification, appearance, account, and help controls live outside the primary tab bar.
- The product has no permanent family map, visible journey history, continuous passive location, battery monitoring, care score, leaderboard, coercive streak, or adult privacy override.
- Permission checks occur in the backend before any structured family fact reaches an AI provider. The model never decides authorization.
- AI may explain permitted facts and draft actions. It must show source and freshness, abstain when information is missing or unauthorized, and require confirmation before affecting another person.
- Private Compass history never becomes input to a family-visible answer.
- Chat, plans, reminders, manual statuses, and check-ins remain usable when AI is unavailable.
- Version 1 supports English and Arabic, light and dark system appearance, right-to-left layout, large text, screen readers, offline reading and queued writes, and adaptive phone and larger-window layouts.
- The functional pilot uses local SQLite, Firebase Authentication test identities, process-local WebSocket events, and memory notifications by default. Real FCM/APNs credentials, a shared event broker, production PostgreSQL, final supported OS versions, and named physical reference devices remain release decisions.

## Brand Commitments

- Product name: Family Compass.
- Product language is calm, direct, and specific about source, audience, freshness, expiry, uncertainty, and recovery.
- Gathering is presented before reassurance. Privacy is explained through visible controls and truthful states, not through promotional claims.
- AI is called Compass. It is quiet, clearly identified, optional, and never impersonates a family member.

## Evidence on Hand

- The approved product roadmap is at `docs/PRODUCT_ROADMAP.md`.
- The historical Prototype 2 build plan is at `docs/PROTOTYPE_2_BUILD_PLAN.md`.
- The current deterministic Flutter prototype is preserved at `prototypes/prototype-2/`.
- The persistent, provider-neutral FastAPI pilot service is at `family_compass_backend/`.
- Prototype 2 reference captures are at `docs/assets/`.
- No real customer testimonials, usage metrics, production reliability data, store approval, security audit, or usability report is present. Future work must not imply that this evidence exists.

## Product Principles

1. Gathering comes first.
2. Reassurance must not become surveillance.
3. Manual value must work before automatic intelligence.
4. AI stays quiet, grounded, optional, and visible.
5. Every consequential action is authorized and confirmed.

## Accessibility & Inclusion

The app must work for adults across age groups, including Arabic readers and families living apart. Core journeys require full right-to-left behavior, mixed Arabic and Latin text handling, large text without clipping, screen-reader labels and logical focus, reduced motion, non-color status cues, platform-native interaction behavior, and touch targets of at least 48 logical pixels.

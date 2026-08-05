# Family Compass Prototype 2 build plan

**Status:** Planning complete; implementation waits for the native-toolchain preflight  
**Date:** 5 August 2026  
**Timebox:** 15 working days after the preflight passes  
**Product source of truth:** Family Compass product roadmap  
**Build target:** Flutter mobile application with local scripted data

## 1. What we are building

Prototype 2 is the first new prototype built from the approved Family Compass roadmap. The existing five-tab prototype is Prototype 1 and remains a reference only.

Prototype 2 must prove four things:

1. People understand **Today, Chat, Compass, and Together** without an explanation.
2. A family can turn a conversation or suggestion into a confirmed gathering.
3. A person can get reassurance from information a family member chose to share without seeing a family map.
4. The privacy model feels understandable rather than controlling or complicated.

This is a mobile experience prototype, not a production MVP. It uses deterministic local scenarios and does not connect to FastAPI, Firebase, a live AI provider, SMS, GPS, Maps, Routes, or push notifications.

The schedule assumes:

- One full-time Flutter developer
- About 20 hours of product-design support
- About 18 to 24 hours of recruitment, facilitation, and research support
- Recruitment running in parallel with development

If the Flutter developer must also perform all design and research work, use an 18 to 20 working-day estimate instead.

## 2. Decisions that are now frozen

- The signed-in application has four primary destinations: **Today, Chat, Compass, Together**.
- Profile, invitations, members, My Sharing, and settings open from the family/profile button. They are not a fifth tab.
- Today begins with the next gathering, not a standing family-member roster.
- Together owns proposals, polls, confirmation, reminders, contributions, and Plan this again.
- Compass is private to the current user.
- `@Compass` in Chat is family-visible and creates drafts that require confirmation.
- Prototype 2 reassurance uses a manually shared status or manually entered ETA.
- No map, journey screen, route, live dot, battery display, or location history appears anywhere.
- No leaderboard, bonding score, challenge progress, or competitive streak appears anywhere.
- The prototype can hold only one active proactive Compass suggestion across the application.
- Adult family members only.
- English is the complete demonstration language. Representative Arabic right-to-left screens are included for layout testing.
- The complete core flow uses the approved light palette. Representative dark screens are included, but full dark coverage is not required until Prototype 3.
- The existing FastAPI code remains unchanged during Prototype 2.

Any new idea must replace an item of similar effort or move to a later backlog. It does not silently enter the 15-day build.

## 3. Existing-project reuse boundary

### Keep

- The existing `family_compass_mobile` Flutter project directory
- Material 3 as the base component system
- Useful interaction ideas from the current chat bubble, composer, check-in sheet, invitation sheet, member tile, and cards
- The fictional family and dinner theme after correcting the privacy and source language
- A simple Flutter `ChangeNotifier` approach for deterministic prototype state
- The existing FastAPI factory, repository abstraction, and AI-provider abstraction for later Prototype 3 work

### Rebuild

- Application shell and navigation
- Theme and semantic design tokens
- Today
- Together and the complete planning flow
- Chat around shared plan and status records
- Private Compass
- Prototype models and scenario controller
- Onboarding, family menu, invitations, and My Sharing
- Adaptive layout behavior
- Widget and scenario tests

### Do not carry forward

- Five-tab navigation
- Journey screen and fake map
- Dashboard member roster
- Battery and continuous activity presentation
- Bonding card and challenge card
- Global `sharesLocation` Boolean
- Keyword-based assistant logic
- Old reminder list as a separate product area
- Hard-coded colors scattered through widgets

The current 1,400-line `main.dart` should not be extended screen by screen. Useful widgets may be extracted and restyled, but the application layer should be reorganized before feature work begins.

The current Flutter project has only a Web runner. The implementation must generate proper iOS and Android runner folders. Web may be used for fast layout inspection, but it is not the delivery target and must not determine the interface.

### Day 0 native-toolchain preflight

This preflight is outside the 15-day build clock. The current terminal does not expose a Flutter executable, and the project has no iOS or Android runner.

Verify:

- Flutter stable SDK is installed and available in the terminal
- `flutter doctor` has no blocking error for the selected targets
- Xcode command-line tools, selected Xcode version, simulator, and CocoaPods work
- Android SDK, emulator, platform tools, and accepted licenses work
- Current packages resolve on the selected Flutter version
- One facilitator-owned physical phone is selected for the final smoke test
- A disposable blank Flutter project builds and launches on both an iOS simulator and an Android emulator
- The same blank project installs and launches on the named physical phone, including signing, Developer Mode or USB debugging, device trust, and host authorization

The preflight does not modify Family Compass. The 15-day schedule starts only after it passes. Generate the Family Compass iOS and Android runners on Day 1, after the Prototype 1 archive is verified. TestFlight and Play Console distribution are not part of Prototype 2.

### Prototype 1 recovery mechanism

Before the first refactor, create a source-only archive outside the active Flutter directory. Exclude `.dart_tool`, `build`, generated caches, and secrets. Save the archive in the task's `work/` directory with a date, a manifest, and a checksum. This is the default because the current Flutter directory is not tracked in Git. A local baseline commit is an acceptable alternative, but nothing is pushed to GitHub.

## 4. Demonstration family and scenario

Use one consistent fictional adult family throughout the prototype:

| Member | Prototype role | Relevant shared information |
|---|---|---|
| Abdullah | Current user and coordinator of plans he sends | Can create the poll, respond, confirm it, and manage his own sharing |
| Dad | Family member | Manually shared: “Leaving work, ETA around 7:20 PM,” updated 3 minutes ago |
| Mom | Family member | Starts the Friday dinner discussion |
| Sara | Family member | Has no recent shared status in the unknown-state branch |

The central gathering is **Friday family dinner**.

Candidate times:

- Friday at 7:00 PM
- Friday at 7:30 PM

Scripted responses:

- Mom: Going at either time
- Dad: Maybe at 7:00 PM, Going at 7:30 PM
- Sara: Going at 7:30 PM
- Abdullah: the task states that he can attend either time and prefers 7:30 PM; the participant enters that compatible response

The confirmed plan becomes Friday at 7:30 PM. It receives one automatic gathering reminder. Abdullah can add “I can bring dessert” as a voluntary contribution.

Use separate named resets for the required tasks:

- **Dinner opportunity:** starts Thursday at 6:00 PM before a plan exists. Today can show the single dinner suggestion, and Chat contains Mom's opening message. This reset begins the Chat-to-plan journey.
- **Dinner poll open:** starts after the poll was sent. The two Friday candidate times are open for response, Today shows Needs your reply, and the original suggestion is gone. This reset begins the direct poll-response usability task.
- **Reassurance:** starts Friday at 6:40 PM with dinner already confirmed for 7:00 PM; Dad's manual ETA makes 7:30 PM a sensible change to draft.
- **Unknown reassurance:** starts Friday at 6:40 PM with the same confirmed dinner, but no recent permitted status is available for the requested member.

Each named scenario has a deterministic `PrototypeClock`. Freshness, expiry, poll deadlines, reminders, and scripted time advances derive from that clock rather than the computer's current date and time.

## 5. Information architecture

```text
Mock onboarding
├── Welcome
├── Mock phone verification
├── Create or join family
├── Profile and invitation
└── Enter Today

Signed-in shell
├── Today
├── Chat
├── Compass
├── Together
│   ├── Plan builder
│   ├── Poll detail
│   └── Confirmed plan
└── Family/Profile menu
    ├── Members and invitations
    ├── My Sharing
    └── Settings placeholders
```

Plan and poll details belong to Together even when opened from Today or Chat. The back path returns to the screen that opened the item.

## 6. Screen inventory

| Screen | Purpose | Required Prototype 2 states |
|---|---|---|
| Welcome | Explain gathering first and consent-based reassurance | One successful first-visit path |
| Mock verification | Enter phone number and mock code | Valid mocked entry and success |
| Create or join family | Create a family or accept a scripted invitation | Create selected and one valid invite preview |
| Profile and invitation | Choose name/avatar and invite by phone or mock secure link | Valid form, invite sent, skip |
| Today | Show the next gathering, required replies, one relevant shared update, and one Compass suggestion | Opportunity, poll open, empty, offline cached, confirmed-plan update |
| Chat | Show the family conversation, check-ins, plan cards, and direct `@Compass` | Initial, composing, draft awaiting review, poll sent, offline |
| Compass | Provide private sourced answers and action drafts | Member-shared answer, no recent information, loading, AI unavailable |
| Why this answer sheet | Explain source, age, audience, and limits | Member-shared source, no-information explanation |
| Together | Organize Next, Decide, and Later | Empty, open poll, confirmed plan, completed plan |
| Plan builder | Choose idea, candidate times, participants, and review | Blank, prefilled, unsaved-exit confirmation |
| Poll detail | Respond and allow coordinator confirmation | Awaiting response, responded, ready to confirm, closed |
| Confirmed plan | Show time, attendees, reminder, and contributions | Confirmed, reminder adjusted, notification denied with in-app reminder retained, completed |
| My Sharing | Show what is shared, with whom, and until when | Not sharing, active check-in, edited audience/expiry, paused |
| Family menu | Show members, invitations, My Sharing, and settings entry points | Normal family, pending invitation |

## 7. Screen specifications

### 7.1 Today

Content order is fixed:

1. **Next time together**
2. **Needs your reply**
3. **Relevant family update**
4. **Compass suggestion**

Rules:

- The dinner-opportunity state shows the single suggestion before a poll exists.
- The dinner-poll-open state shows Needs your reply and removes the original suggestion.
- After confirmation, Friday dinner becomes the leading card.
- Only information someone explicitly shared, or information affecting the current plan, may appear.
- Every shared-update card shows source and freshness, for example “Shared by Dad · 3 minutes ago.”
- Do not show a row for every family member.
- The Compass suggestion disappears as soon as it becomes a poll or confirmed plan.
- An empty state contains one action: **Start a family plan**.
- The offline state shows cached information and its age without removing navigation. A visible **Retry** action deterministically returns the prototype to the ready state.
- “No recent information” never appears here as an unsolicited warning.

### 7.2 Chat

Prototype 2 Chat includes:

- Scripted text messages
- Text composer
- Check-in request and response cards
- `@Compass`
- A clearly labeled Compass plan draft
- Poll and confirmed-plan cards linked to Together
- A separately requested reminder draft

It excludes photos, reactions, voice notes, calls, link previews, read receipts, and typing indicators.

Human messages, family-visible Compass cards, and private Compass answers must remain visually and verbally distinct without depending on color alone.

Compass does not publish anything automatically. A plan draft requires **Review plan**, and the plan builder requires **Send poll**. A separately requested reminder draft requires its own confirmation.

Required supporting Chat states:

- A check-in is explicitly requested from Sara.
- Sara's scripted manual response replaces the pending request state.
- After dinner is confirmed, Abdullah explicitly asks Compass to draft “Remind me to buy dessert Friday at 5:00 PM.”
- The personal reminder remains a draft until Abdullah confirms it, then attaches to the dinner plan separately from the automatic gathering reminder.

Optional concept probe, only after the required prototype is complete:

- A direct family-room question such as “Has Dad left work?” may receive a deterministic system card only when no person answers after a quiet delay.
- It uses no language model and adds no private detail.
- It links to the original family-room status, has a cooldown, and provides Dismiss and Disable controls.
- When the source status expires, the card becomes a neutral expired placeholder.
- It is not part of the exit gate and may be removed if it feels intrusive.

### 7.3 Compass

The header must say that this conversation is private.

A Version 1-style answer card contains:

- Direct answer
- **Shared by Dad** or **No recent permitted information**
- Last updated time
- **Why this answer?**
- **Mark as outdated** when the requester cannot correct the subject's status
- One relevant action

Main answer:

> Dad shared that he is leaving work and expects to arrive around 7:20 PM. Updated 3 minutes ago.

The explanation states that this is Dad's manual update, shared with Abdullah, and that the application is not using a live map or continuous location.

Abdullah cannot edit Dad's status. **Mark as outdated** records feedback and offers Request a check-in. A separate self-status example in My Sharing provides **Correct my update**, because only the person who shared an update may edit its content.

In the named reassurance scenario, dinner is already confirmed for 7:00 PM. Compass may offer **Draft a change to 7:30**. Applying or sharing the change still requires review and participant notification.

Unknown branch:

> No recent permitted information is available.

The only contextual action is **Request a check-in**. The response must not imply that hidden information exists.

### 7.4 Together

Together has three sections:

- **Next:** the next confirmed gathering
- **Decide:** open polls and invitations
- **Later:** future plans and saved ideas

The plan builder is intentionally short:

```text
Choose idea
→ choose candidate times
→ choose participants
→ review and send
```

Available templates:

- Dinner
- Family call
- Visit
- Walk
- Custom

Only Dinner needs a complete demonstration path.

Poll rules:

- The system supplies a sensible automatic decision deadline.
- **Change deadline** is under an options menu, not a required step.
- The coordinator can send one poll nudge to members who have not responded. After use, the action remains disabled for that poll and reads **Nudge sent**.
- Initial response choices are Going, Maybe, and Cannot make it.
- Suggest another time appears after Maybe or Cannot make it.
- The plan coordinator explicitly confirms the winning time.
- Confirmation creates one sensible gathering reminder automatically.
- The reminder can be adjusted but does not need to be manually created.
- Rides, food, and voluntary contributions appear only after confirmation.
- A completed-state variation provides **Plan this again**.

### 7.5 My Sharing

Prototype 2 uses only:

1. Not sharing
2. Manual check-in with an audience and expiry

The screen answers:

- What am I sharing?
- Who can see it?
- When does it end?
- What may Compass use?

The user can correct their own update, change its audience, shorten its expiry, and pause it. No real location prompt or GPS request occurs.

### 7.6 Onboarding and invitations

The mock onboarding flow is one linear successful path. It should be short and scroll safely in landscape and at larger text sizes. Invalid OTP, returning-user, revoked-invitation, and full recovery variations are specified in the Prototype 3 state handoff rather than implemented here.

It explains:

- The application helps families plan time together.
- Reassurance uses information people choose to share.
- There is no permanent family map.
- Every adult controls their own sharing.

The family invitation identifies the inviting family before acceptance. Phone entry is manual and does not request Contacts permission.

## 8. Required demonstration journey 1: Chat to dinner

Start from `dinnerOpportunity`.

1. Open Chat.
2. Read Mom's message: “Could we have dinner this Friday?”
3. Tap **Turn into a plan** or invoke `@Compass`.
4. Compass produces a family-visible draft with two candidate times.
5. Tap **Review plan**.
6. Review Dinner, Friday 7:00 PM, Friday 7:30 PM, and selected adult participants.
7. Tap **Send poll**.
8. See the poll in Chat and Together → Decide.
9. Enter Abdullah's response.
10. Receive deterministic responses from Mom and Dad while Sara remains pending.
11. Open the poll as coordinator and send the one available poll nudge.
12. Receive Sara's scripted response and see the disabled **Nudge sent** state.
13. Confirm Friday at 7:30 PM.
14. See the plan under Together → Next.
15. See the automatic gathering reminder and optionally adjust it.
16. If the representative notification request is denied, keep the in-app reminder available and explain the manual path.
17. Add “I can bring dessert.”
18. Return to Today and see dinner as the leading card.
19. In the completed-state variation, tap **Plan this again**.

At no point may Compass publish, assign, or confirm an action before a person approves it.

## 9. Required demonstration journey 2: Reassurance without a map

1. Reset to the named reassurance scenario, where dinner is confirmed for 7:00 PM.
2. Open private Compass.
3. Ask: “Where is Dad?”
4. Receive Dad's permitted manually shared status and ETA.
5. See **Shared by Dad**, the update age, and **Why this answer?**
6. Open the explanation and confirm that no live map or continuous location was used.
7. Tap **Draft a change to 7:30**.
8. Review the change before sharing it.
9. Switch to the named unknown-reassurance branch.
10. Receive **No recent permitted information is available**.
11. Tap **Request a check-in** rather than receiving an invented answer.

Supporting privacy test:

1. Open My Sharing.
2. Change the active check-in audience.
3. Shorten its expiry.
4. Pause it.
5. Confirm that affected surfaces update consistently.

## 10. Prototype state model

Use one deterministic `PrototypeScenarioController` as the source of truth. Every tab reads the same immutable state. `PrototypeScenarioState` contains a fixed `scenarioNow`; no fixture uses `DateTime.now()`.

Required named scenario presets:

- `dinnerOpportunity`
- `dinnerPollOpen`
- `reassuranceAtSeven`
- `reassuranceUnknown`
- `todayEmpty`
- `offlineCached`
- `aiUnavailable`
- `sharingPaused`
- `notificationDenied`

Required supporting Chat substates:

- `checkInRequested`
- `checkInResponded`
- `separateReminderDrafted`
- `separateReminderConfirmed`

Recommended scenario phases:

```text
initialOpportunity
→ planDrafted
→ pollOpen
→ responseSubmitted
→ readyToConfirm
→ planConfirmed
→ gatheringCompleted
```

Independent flags:

- `surfaceState` with ready, loading, empty, and offline-cached values
- `aiAvailability`
- `sharingState`
- `notificationPermissionState`
- `textScaleScenario`
- `localeScenario`
- `themeScenario`

Add a separate `PrototypeUiState` for selected tab, nested route, Chat draft, active plan-builder step, selected candidate times, poll response, selected plan, and unsaved-change state. Use stable `PageStorageKey` values and owned scroll controllers for scroll position. This state remains alive during rotation and resizing; restart restoration is Prototype 3 work.

Internal prototype controls should allow a tester to:

- Reset to a named scenario
- Jump to any phase
- Toggle offline
- Toggle AI unavailable
- Toggle member-shared versus no recent information
- Toggle the representative notification-denied path
- Toggle light, representative dark, English, and representative Arabic

These controls must be visually hidden from normal participants and easy for the facilitator to reach, for example through a long press on the Family Compass wordmark.

### Scripted interaction contract

Prototype 2 must not recreate the old keyword-matching assistant or imply that arbitrary free-text AI works.

Use stable scripted intent IDs such as:

- `draftFridayDinner`
- `whereIsDad`
- `explainStatusSource`
- `markStatusOutdated`
- `requestCheckIn`
- `draftPlanChange`
- `draftSeparateReminder`

Buttons, prompt chips, and the active named scenario dispatch these IDs directly. The displayed message can still look natural. For example, the first Compass submission in the reassurance scenario displays what the participant typed but dispatches `whereIsDad`. A `@Compass` plan action dispatches `draftFridayDinner` through **Turn into a plan**. Human Chat text can be added locally without invoking Compass. Unsupported later Compass submissions receive a neutral prototype fallback rather than a fabricated answer.

Scripted intent IDs, not text parsing, determine the result. This keeps tests deterministic and leaves real natural-language interpretation for Prototype 3.

## 11. Prototype domain models

Create prototype-focused models rather than extending the old location-centric models.

Minimum model set:

- `PrototypeUser`
- `FamilyMember`
- `FamilyRole`
- `SharedStatus`
- `StatusSource`
- `SharingAudience`
- `SharingState`
- `ChatMessage`
- `ChatCardReference`
- `FamilyPlan`
- `CandidateTime`
- `PollResponse`
- `RsvpChoice`
- `PlanReminder`
- `PlanContribution`
- `CompassAnswer`
- `CompassDraftAction`
- `CompassSuggestion`
- `PrototypeIntent`
- `PrototypeScenarioState`
- `PrototypeUiState`
- `PrototypeClock` or fixed `scenarioNow`

Do not include latitude, longitude, routes, battery percentage, journey history, background state, or automatic activity classification.

Important invariants:

- There can be at most one active proactive `CompassSuggestion`.
- A Chat plan card and Together plan detail reference the same `FamilyPlan` ID.
- Confirmation replaces the open-poll state everywhere.
- A paused or expired manual status cannot be used in a new Compass answer.
- AI unavailable disables only AI-assisted actions.
- Offline does not erase already loaded content or unfinished local work.

## 12. Proposed Flutter structure

```text
lib/
├── main.dart
├── app/
│   ├── family_compass_app.dart
│   ├── app_shell.dart
│   └── app_routes.dart
├── design_system/
│   ├── color_tokens.dart
│   ├── type_tokens.dart
│   ├── spacing_tokens.dart
│   ├── family_theme.dart
│   └── components/
├── prototype/
│   ├── prototype_scenario_controller.dart
│   ├── prototype_scenario_state.dart
│   ├── fixtures.dart
│   └── prototype_controls.dart
├── domain/
│   ├── family_models.dart
│   ├── plan_models.dart
│   ├── sharing_models.dart
│   └── compass_models.dart
├── l10n/
│   ├── app_en.arb
│   └── app_ar.arb
├── features/
│   ├── onboarding/
│   ├── today/
│   ├── chat/
│   ├── compass/
│   ├── together/
│   └── family/
└── shared/
    ├── adaptive/
    ├── navigation/
    └── widgets/
```

Use Flutter SDK state tools rather than adding a large state-management framework for this prototype. A central scenario controller is appropriate because all four tabs must change together deterministically.

Add Flutter's localization package, configure `supportedLocales`, and use ARB resources for the representative Arabic set. At minimum, localize the four navigation labels and the representative Today, open-poll, sourced-Compass-answer, and My Sharing screens. A locale toggle without localized strings is not an Arabic implementation.

The backend API client remains outside the active prototype flow. Prototype 2 should make no network request.

## 13. Visual foundation

### Light theme

| Role | Value |
|---|---:|
| Background | `#F7F5F0` |
| Surface | `#FFFFFF` |
| Primary | `#2457C5` |
| On primary | `#FFFFFF` |
| Primary container | `#DCE8FF` |
| On primary container | `#102A56` |
| Gathering accent | `#6F4AA8` |
| Gathering container | `#E9DDF7` |
| On gathering container | `#35204F` |
| Primary text | `#17202A` |
| Secondary text | `#5B6573` |
| Outline | `#CBD3DE` |
| Success | `#267A46` |
| Warning | `#8A5A00` |
| Error | `#B3261E` |

### Representative dark tokens

| Role | Value |
|---|---:|
| Background | `#101318` |
| Surface | `#181C22` |
| Elevated surface | `#222833` |
| Primary text | `#F3F4F6` |
| Secondary text | `#B8C0CC` |
| Primary | `#AFC6FF` |
| On primary | `#082B69` |
| Gathering accent | `#D3B8FF` |
| Gathering container | `#32165B` |
| Success | `#7ED69A` |
| Warning | `#F2C66D` |
| Error | `#FFB4AB` |

Visual rules:

- Minimum interactive target: 48 by 48 logical pixels
- Card radius: 16 logical pixels
- Common spacing: 8, 12, 16, 24, and 32 logical pixels
- No fixed-height content cards
- No meaning conveyed by color alone
- Primary actions use text labels
- Respect reduced motion
- Use system-friendly Latin and Arabic fonts rather than unbundled Arial

## 14. Adaptive behavior

Use the current application window, not device type or a locked orientation.

| Window | Navigation | Prototype 2 content behavior |
|---|---|---|
| Width below 600 | Bottom navigation | One pane, 16-pixel side padding |
| Width 600 to 839 and height at least 480 | Navigation rail | One pane or selective card grid, 24-pixel padding |
| Any compact height below 480 | Short bottom or horizontal navigation | Phone landscape remains one pane |

Required test sizes:

- 390 by 844 logical pixels
- 844 by 390 logical pixels
- 600 by 960 logical pixels
- One width immediately below and at 600

Rotation and resizing must preserve:

- Selected tab
- Nested route
- Scroll position
- Chat draft
- Selected plan-builder step
- Candidate-time selections
- Poll response
- Selected plan

Use `LayoutBuilder`, `MediaQuery`, safe areas, keyboard insets, flexible cards, directional padding, and stable keys. Compact landscape must not shrink the portrait page until it clips.

## 15. Normal and failure states

Prototype 2 must demonstrate:

- Today loading skeleton
- Today empty state
- Today and Chat offline with cached content
- Notification denied after plan confirmation, with the in-app reminder retained
- No recent information after a direct Compass question
- AI unavailable while Chat and Together remain usable
- Unsaved plan exit confirmation
- Paused manual sharing

State rules:

- Loading uses stable skeletons without removing the navigation shell.
- Empty states contain one relevant action.
- Offline content displays its age.
- Offline screens keep cached content visible while **Retry** runs, then deterministically return to ready.
- AI unavailable never disables manual planning or Chat.
- Notification denial does not remove the confirmed plan or its in-app reminder.
- Status meaning uses text and an icon, not color alone.
- Large text cannot hide a primary action or introduce horizontal scrolling.

Every implemented state has a named scenario or explicit trigger in the internal prototype controls.

### Prototype 3 full-state handoff

Prototype 2 also produces a design-only state catalog for the next functional build. It specifies, without implementing every variation:

- First load and refreshing with existing content
- Empty and partial content
- Offline cached data
- Waiting to send, send failure, and retry
- Stale or expired data
- Permission denial and later revocation
- Sharing active, paused, expired, and pause pending
- Session expiry
- Invitation expiry and revocation
- Membership removal
- AI timeout, rate limit, and unavailable
- Destructive-action confirmation, undo, and unrecoverable cases

Each entry names the affected screen, message, retained content, available action, and recovery path. The designer builds this catalog progressively with each feature handoff, and the product owner reviews it by Day 11. It is a Prototype 2 deliverable even when the state itself waits for Prototype 3.

## 16. Ordered work packages

### WP1. Product contract and source snapshot

**Timing:** Day 1

- Create the dated, source-only Prototype 1 archive and verify its manifest and checksum before refactoring.
- Freeze screen inventory, vocabulary, navigation, scenarios, and exclusions.
- Generate iOS and Android Flutter runners.
- Start usability participant recruitment.
- Name the primary physical test phone and testing method.

Acceptance:

- Prototype 1 remains recoverable.
- Clean iOS and Android debug builds launch after runner generation.
- Every screen belongs to a defined destination or family menu.
- The two required journeys have fixed start and end states.
- No unresolved decision blocks the shell or data model.

### WP2. Fixtures and deterministic behavior

**Timing:** Days 1 and 2

- Build the immutable prototype models.
- Create the fictional family fixtures.
- Add the fixed scenario clock.
- Create the scenario phases and flags.
- Create local UI-draft state and stable restoration keys.
- Add internal reset and scenario selection.

Acceptance:

- All four tabs read the same plan and status objects.
- Reset always produces the same state.
- Freshness, expiry, deadlines, and reminders stay deterministic regardless of the actual date.
- Confirming the dinner changes every affected surface.
- No network call or real permission request occurs.

### WP3. Design system and adaptive shell

**Timing:** Days 2 to 4

- Build semantic tokens and shared components.
- Configure English and representative Arabic ARB localization.
- Build four-tab bottom navigation.
- Add the medium-width navigation rail.
- Implement compact-height behavior.
- Preserve local task state during rotation.

Acceptance:

- The shell passes the three required window sizes.
- Navigation, drafts, and unfinished plan input survive rotation.
- Keyboard and safe-area insets do not cover primary actions.
- Increased text does not clip fixed-height cards.
- Component and shell widget tests pass before feature screens are added.

### WP4. Today and Together

**Timing:** Days 5 to 7

- Build Today in the frozen order.
- Build Together's Next, Decide, and Later sections.
- Build the Dinner plan builder.
- Build poll response and confirmation.
- Build the one-use poll nudge and disabled **Nudge sent** state.
- Build the automatic reminder, contribution, completion, and Plan this again states.

Acceptance:

- The complete planning loop works without entering Chat.
- Today never becomes a standing member roster.
- Only one proactive suggestion is active.
- Every action affecting others requires explicit confirmation.
- The plan-relevant Today update shows its source and age.

### WP5. Chat and Compass

**Timing:** Days 8 and 9

- Build the scripted Chat conversation.
- Build `@Compass` plan drafting.
- Build check-in requested and scripted response states.
- Build the separately requested personal reminder draft and confirmed state.
- Link Chat plan cards to the existing Together objects.
- Build private Compass and Why this answer.
- Build the member-shared and no-information branches.
- Build Request a check-in and explicit draft review.
- Build Mark as outdated without allowing the requester to edit another member's status.

Acceptance:

- Human, shared Compass, and private Compass content are distinct.
- Chat and Together show the same poll and confirmed plan.
- Check-in and separate reminder transitions are reachable without changing the automatic gathering reminder.
- Every reassurance answer names its source and age.
- The unknown branch does not imply hidden data exists.

### WP6. Onboarding, invitation, family menu, and My Sharing

**Timing:** Day 10

- Build one short successful mock onboarding flow.
- Build one create/join family path and valid invitation preview.
- Build the family menu.
- Build My Sharing correction, audience, expiry, and pause controls.

Acceptance:

- Onboarding presents value before privacy explanation.
- It states there is no permanent family map.
- No real OTP, SMS, Contacts, or location request appears.
- Sharing changes update affected surfaces consistently.

### WP7. Quality states and representative variants

**Timing:** Built alongside each work package, with final integration on Day 11

- Add the named normal and failure states as their owning screens are built.
- Add representative dark screens for Today, open poll, sourced Compass answer, and My Sharing.
- Add the same representative Arabic right-to-left screen set using real localized strings.
- Run the large-text and screen-reader pass.
- Complete core widget tests.
- Finalize the progressively maintained design-only Prototype 3 state catalog.

Acceptance:

- Every implemented Prototype 2 state is reachable from internal prototype controls.
- Arabic representative screens mirror direction correctly, preserve readable source metadata, and keep primary actions reachable.
- Both required journeys complete end to end at the chosen large-text setting, documented in the decision log and equivalent to at least 200 percent where the platform permits.
- Both required journeys complete with an actual screen reader on the primary phone. Verify focus order, control names and states, live announcements, dialogs, sheets, and reachable actions rather than checking labels alone.
- Every implemented screen, including onboarding, family menu, My Sharing, explanation sheets, and failure states, passes the required phone portrait and landscape sizes.
- A 20-minute clean walkthrough has no crash or contradictory state.

### WP8. Usability testing and revision

**Timing:** Days 11 to 15

- Run the Day 11 pilot only after the build-readiness gate passes.
- Test 8 to 12 adults across at least three families on Days 12 and 13.
- Include several adult age groups, at least one family whose members live apart, and at least one Arabic-literate reviewer.
- Synthesize behavior, interventions, privacy misunderstandings, and clipping.
- Fix blockers and repeated comprehension problems.
- Retest any changed comprehension, privacy, tab-meaning, or gathering-flow behavior with fresh backup participants.
- Regression test and freeze Prototype 3 scope.

Recruitment requirements:

- Confirm participants by Day 4 and pre-book two fresh backup participants for Day 15 or the next working day.
- Reserve near-full-day researcher availability on Days 12 and 13.
- Confirm the facilitator phone, testing location or screen-sharing method, consent script, and note-taking template before the pilot.

Design handoff deadlines:

- End of Day 2: approved flow wireframes and source/privacy copy
- End of Day 3: approved tokens, core components, global adaptive rules, and global RTL component rules
- Before Day 5: approved Today and Together designs with their adaptive annotations
- Before Day 8: approved Chat, Compass, and My Sharing designs with their adaptive annotations
- Before Day 10: approved onboarding and invitation designs plus dark, large-text, and feature-specific RTL annotations

Before the 15-day clock starts, record the actual product-owner and designer names in the decision log. The product owner approves product behavior and copy; the designer approves visual and adaptive handoffs. Each scheduled review has a same-working-day decision deadline so implementation does not wait on unresolved feedback.

## 17. Daily schedule

| Day | Primary result |
|---|---|
| Preflight | Flutter, Xcode, Android, simulators, packages, and primary phone verified |
| 1 | Scope lock, verified source archive, runner setup, recruitment started |
| 2 | Models, fixed scenario clock, fixtures, UI state, prototype controls, approved flow wireframes |
| 3 | Tokens, localization setup, shared components, initial mobile shell |
| 4 | Adaptive shell and rotation-state preservation |
| 5 | Today complete |
| 6 | Together builder and polling |
| 7 | Poll nudge, confirmation, reminder, contribution, Plan this again, design review |
| 8 | Chat scenario complete |
| 9 | Compass, source explanation, correction path, and unknown branch |
| 10 | Linear onboarding, invitation, family menu, and My Sharing |
| 11 | Integrated states, representative variants, accessibility pass, native readiness gate, pilot |
| 12 | First usability sessions |
| 13 | Remaining usability sessions |
| 14 | Findings, decisions, and blocking or repeated-issue fixes |
| 15 | Regression or focused fresh-participant retest, then final demonstration and reporting if the gate passes |

Ten working days is possible only if participant recruitment begins immediately and visual refinements are reduced. The recommended plan remains 15 working days because testing and revision are part of the prototype, not optional polish.

### Build-readiness gate before research

The Day 11 pilot begins only when:

- A clean native install succeeds on the named primary physical phone.
- Android and iOS debug builds succeed.
- Both required journeys work from reset to completion.
- Scenario reset and state selection work reliably.
- Final privacy and source copy is present.
- The final moderated test script is ready.
- A 20-minute walkthrough has no crash, blocked action, or contradictory plan state.

If this gate fails, participant sessions move. Testing an incomplete build does not protect the schedule.

### Post-revision retest rule

- Cosmetic and isolated technical fixes require regression only.
- A fix to comprehension, privacy, tab meaning, source wording, or the gathering flow requires focused testing on the revised build with fresh backup participants.
- Final reporting and the Prototype 3 scope freeze wait for that focused retest to pass.
- The schedule extends beyond Day 15 when a formal exit gate failed. Day 15 is a target, not permission to skip evidence.

## 18. Core automated checks

Add Flutter widget tests for:

1. The shell exposes exactly Today, Chat, Compass, and Together.
2. Today orders Next, Needs your reply, relevant update, and suggestion correctly.
3. Starting a plan removes the active suggestion.
4. The Chat draft becomes the same poll shown in Together.
5. A requested check-in enters pending and then scripted-response states.
6. The separate reminder stays a draft until confirmed and does not replace the automatic plan reminder.
7. The poll nudge can be used once and then remains in its disabled **Nudge sent** state.
8. Confirming a poll updates Today, Chat, and Together.
9. Compass shows the member-shared source and freshness.
10. Mark as outdated cannot edit another member's original status.
11. The unknown Compass branch offers Request a check-in.
12. Pausing a shared status prevents a new sourced answer.
13. AI unavailable leaves Chat and Together usable.
14. Offline Retry keeps cached content visible and deterministically returns to ready.
15. Notification denial retains the in-app plan reminder.
16. The fixed scenario clock produces stable freshness, expiry, and deadline text.
17. Rotation preserves a Chat draft and unfinished plan input.
18. Compact landscape renders without overflow.
19. Representative Arabic and large-text screens render without exceptions.

Required completion commands:

```text
flutter analyze
flutter test
```

Prototype 2 also requires successful iOS simulator and Android debug builds, followed by a smoke test on the named primary phone. It does not require backend tests because it does not call the backend.

## 19. Usability test script

Each moderated session should take about 45 to 55 minutes. Tell participants that information and family responses are scripted and that no real location is collected. Do not explain the four tabs or privacy model before testing them.

### First impression

Show Today and ask:

- What do you think this application helps a family do?
- What would you expect each tab to contain?
- What is the next thing this family needs to decide?

### Task 1: confirm dinner

Reset to `dinnerPollOpen`.

Prompt:

> Your family has mentioned dinner on Friday. You can attend either proposed time and prefer 7:30 PM. Find what still needs a response and help the family confirm a time.

Observe whether the participant finds the decision, responds, understands the deadline, sends the one available nudge when someone is pending, confirms the plan, finds the automatic reminder, and adds the dessert contribution.

### Task 2: turn Chat into a plan

Reset to `dinnerOpportunity` and prompt:

> The family is discussing Friday in Chat. Turn the discussion into something everyone can decide.

After completion ask:

- Who can see the `@Compass` request?
- Did Compass send anything before you confirmed it?
- What is the difference between the draft, poll, and confirmed plan?

### Task 3: reassurance without a map

Prompt:

> Dinner is approaching and Dad has not replied. Find out what the application can tell you.

Ask:

- Where did the answer come from?
- How old is it?
- Is it an automatic location inference?
- What can you do if you think Dad's update is outdated, and can you edit it yourself?
- What would you do if no recent information were available?

Then show the unknown branch.

### Task 4: privacy control

Prompt:

> Correct your current update, change who can see it, shorten when it ends, and then pause it.

Ask whether the participant believes the application contains a permanent family map.

### Task 5: rotation and resilience

Ask the participant to begin a Chat message or plan change, rotate the phone, and finish. Then show AI unavailable or offline and ask what remains possible.

### Arabic review task

With the Arabic-literate reviewer, switch to Arabic and inspect:

- Today
- The open poll
- A sourced Compass answer and Why this answer sheet
- My Sharing

Ask the reviewer to verify natural meaning, reading order, navigation and icon direction, source and freshness wording, and whether every primary action remains visible and understandable. Record language problems separately from general RTL layout problems.

### Closing questions

- What is the main reason you would open this application?
- What is the difference between Chat and Compass?
- Did any part feel like tracking?
- Was any suggestion too intrusive?
- Would your family use Together rather than arranging the same event entirely in group chat?
- What was the single most confusing part?

Record observed behavior and facilitator interventions before opinions.

## 20. Risks and controls

| Risk | Control |
|---|---|
| Scope expands into a functional backend | Hard local-only boundary and network-request check |
| Current code slows the redesign | Reuse visual fragments only; replace conflicting shell and models |
| Prototype looks like a responsive website | Generate native runners, design from phone constraints, test on a simulator or physical phone |
| Visual polish hides a broken gathering loop | Today and Together must work before Chat and Compass are added |
| Tabs contradict each other | One scenario controller and shared record IDs |
| AI appears to spy or invent | Source, age, unknown, permission, and AI-unavailable scenarios are mandatory |
| Map or tracking language returns | No map route, live dot, journey history, battery, or continuous-sharing copy |
| Adaptive work is postponed | Adaptive shell and rotation preservation are completed by day 4 |
| Arabic or large text is discovered too late | Directional layout and flexible heights begin in the design-system work |
| Test participants are unavailable | Recruit on day 1, confirm by day 4, maintain two backups |
| Scripted state fails during a demonstration | Named scenarios, one-tap reset, and clean walkthrough on day 15 |
| Findings become a large polish list | Fix blockers, privacy misunderstandings, repeated navigation errors, and clipping first |

## 21. Definition of done

Prototype 2 is complete only when all of the following are true.

### Product

- Exactly four primary destinations are implemented.
- Both required journeys work from a clean reset to completion.
- Today prioritizes the next gathering.
- Together supports proposal, response, one-use poll nudge, confirmation, automatic reminder, contribution, and Plan this again.
- Chat, Today, Compass, and Together reference consistent plan and status state.
- Chat demonstrates a requested and answered check-in plus a separately requested reminder that remains a draft until confirmation.
- Compass provides source, age, an unknown branch, and a requester-safe Mark as outdated action.
- My Sharing can correct the owner's update and change audience, expiry, and paused state.
- No map, journey, continuous tracking, challenge, score, or child-account flow remains.

### Mobile and adaptive quality

- Android and iOS debug builds succeed, and the prototype passes a smoke test on the named primary physical phone.
- Every implemented screen passes at 390 by 844 and 844 by 390 logical pixels, including onboarding, family menu, My Sharing, explanation sheets, and implemented failure states.
- The two core journeys also pass at the representative 600 by 960 medium width.
- Rotation preserves selected tab, route, draft, scroll, and unfinished plan input.
- The light theme covers the complete core flow.
- Today, the open poll, a sourced Compass answer, and My Sharing are each reviewed in representative dark mode, real Arabic RTL strings, and large text.
- Those representative screens have correct RTL ordering, readable source metadata, no clipping, and reachable primary actions.
- Both required journeys pass end to end at the documented large-text setting and with an actual screen reader on the primary phone, including focus, announcements, dialogs, and sheets.
- There are no clipped primary actions, keyboard-covered composers, or undersized tap targets in the tested matrix.

### Comprehension and trust

After testing 8 to 12 adults across at least three families, including several adult age groups, one family whose members live apart, and an Arabic-literate reviewer:

- No more than two participants require help to complete the main gathering flow. Help means an explicit hint, correction of the participant's path, or facilitator takeover.
- No more than two misidentify a member-shared answer as an automatic inference or believe missing information is secretly available.
- No more than two participants misclassify a primary tab's main job after first exploration, and nobody requires an explanation of all four tabs.
- Zero participants finish the session believing that the application contains a permanent live family map.
- A serious privacy misunderstanding means believing that the application uses hidden or live location, exposes private Compass history, uses unshared information, or publishes an action without approval.
- No serious privacy misunderstanding occurs among participants from two or more distinct family groups.
- Every participant can continue the unfinished rotation task.
- At least three families agree to test Prototype 3.

### Quality and handoff

- `flutter analyze` and `flutter test` pass.
- No crash, blocked core task, misleading disclosure, or repeated serious privacy defect remains.
- Scenario reset and selection work on the demonstration device.
- The Prototype 1 source archive, manifest, and checksum are verified.
- Design tokens and reusable components are documented.
- The complete design-only Prototype 3 state catalog is delivered.
- Test findings record task completion, interventions, interpretation errors, affected family groups, and severity.
- A decision log records what changed and why.
- Prototype 3 Must scope is frozen from evidence.

If a comprehension or privacy exit gate fails, Prototype 2 is revised and tested again with fresh participants for the affected task. The prototype does not advance merely because the 15-day timebox ended.

## 22. First implementation actions

The first implementation session should complete these actions in order:

1. Preserve a source-only copy of Prototype 1 for comparison.
2. Generate the missing iOS and Android Flutter runners.
3. Replace the five-tab shell with an empty adaptive four-tab shell.
4. Add the approved semantic color and typography tokens.
5. Create the prototype domain models and deterministic scenario controller.
6. Add the hidden scenario reset control.
7. Implement Today's layout skeleton.
8. Add widget tests asserting the four destinations and absence of Journey.

No FastAPI, Firebase, AI-provider, Maps, Routes, or real-location work begins during these actions.

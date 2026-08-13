# Family Compass product roadmap

**Status:** Product and experience plan  
**Date:** 5 August 2026  
**Scope:** Current prototype baseline, Prototype 2, Prototype 3, Version 1, and Version 2

## Implementation snapshot, 13 August 2026

The active `0.3.0-dev.1+3` foundation now implements the local Prototype 3
engineering slice: persistent SQLAlchemy storage, signed development and
Firebase Emulator authentication, explicit phone invitation choice, family
lifecycle APIs, real mobile repository adapters, authenticated family events,
durable offline Chat retry, exact authenticated notification links, live plan
draft, poll, time-suggestion and reminder actions, real Today aggregation, and
the provider-neutral Compass boundary. All 193 Flutter tests and 122 backend
tests pass. Fresh Android, iOS Simulator, and Web builds also pass.

This does not complete the Prototype 3 exit gate. Production phone sign-in,
real APNs and FCM delivery, physical-device accessibility, signing, store setup,
and the 8 to 12 adult, three-family pilot remain external work. The detailed
split is maintained in `../TODO.md` and
`PROTOTYPE_3_VALIDATION_CHECKLIST.md`. The staged scope below remains the
approved plan.

## 1. The decision in one page

Family Compass should be a family coordination app with two outcomes, in this order:

1. Help families spend more time together.
2. Reduce everyday uncertainty through information each person chooses to share.

The product should not become a family tracking app, a replacement for WhatsApp, or an AI that speaks for people. Its clearest promise is:

> Family Compass turns the context each person chooses to share into timely family answers and coordinated plans, without putting anyone on a permanent map.

The recommended four primary areas are:

| Tab | Job | Main content |
|---|---|---|
| **Today** | Show what matters now | Next gathering, items needing a reply, relevant shared updates, one useful Compass suggestion |
| **Chat** | Give the family a shared room | Messages, check-ins, `@Compass`, plan and reminder cards, with photos and expiring place pins as later polish |
| **Compass** | Give each person a private assistant | Questions about permitted family context, source and freshness, drafts, corrections, privacy explanations |
| **Together** | Turn an opportunity into time together | Ideas, proposals, polls, confirmed plans, reminders, voluntary contributions, and future plans |

Four peer destinations fit the established mobile pattern. Android recommends three to five primary navigation destinations and adapting the bar into a rail as the window grows. ([Android layout and navigation patterns](https://developer.android.com/design/ui/mobile/guides/layout-and-content/layout-and-nav-patterns))

Settings, invitations, family members, permissions, account controls, and help belong behind the profile or family button. They should not become a fifth tab.

The main product loop is:

```text
Notice a chance to gather
→ suggest a suitable plan
→ ask the family
→ collect responses
→ confirm the plan
→ remind and coordinate
→ complete the gathering
```

Reminders and recommendations are useful, but they are parts of this loop. A recommendation should normally lead to an action such as **Start a poll**, **Suggest another time**, or **Create a reminder**. The app should avoid a passive recommendation feed that users learn to ignore.

The staged plan is:

| Stage | What it proves | Real data level |
|---|---|---|
| **Current Prototype 1** | The broad idea can be shown on a phone | Scripted mock data |
| **Prototype 2** | People understand the product, gathering loop, and privacy model | Polished scripted Flutter prototype |
| **Prototype 3** | A real family can complete the workflow across devices | Real backend, database, chat, notifications, and provider-neutral AI |
| **Version 1** | Families repeatedly use it to make plans | Production-quality, consent-first core product |
| **Version 2** | Easier gathering improves repetition, then optional context earns its place | Planning improvements first, policy-contingent context experiments second |

The next build should be Prototype 2. It should not add more technology. It should correct the product structure and prove the experience.

## 2. Product principles

These principles are scope rules, not marketing statements.

### 2.1 Gathering first

The top of Today should answer **When are we next together?** before it answers **Where is everyone?** Together should be a complete planning workspace, not a list of reminders.

### 2.2 Reassurance without surveillance

Family members may share a status or ETA. Later experiments may add a named place, approximate activity, or temporary trip context. They should never appear on a permanent map by default. Adults control their own sharing, and a family organizer cannot override another adult's privacy settings.

### 2.3 Manual value before automatic intelligence

Manual statuses, check-ins, polls, reminders, and plan confirmation must work well before background location or routine learning is introduced. This gives the product value even when permissions are denied, signals are unavailable, or the AI provider is offline.

### 2.4 AI must be quiet, grounded, and visible

Compass is a clearly labeled participant. It responds immediately to direct requests. The app may hold only one active proactive suggestion at a time, regardless of which screen displays it. Today shows it when action is timely, and Together keeps it when it can wait. Chat normally invokes Compass through `@Compass` or a deliberate action. Compass never impersonates a person or invents a reply on their behalf.

### 2.5 Every answer must show its basis

Do not compress evidence, freshness, connectivity, and sharing policy into one colored status. They are separate dimensions:

| Dimension | Internal values | What the requester sees |
|---|---|---|
| Evidence | Member-shared, system-derived in a Version 2 experiment, none | “Shared by Dad” or, only when that experiment is active, “Estimated from a trip Dad shared” |
| Freshness | Current, stale, expired | Last update time or “No recent update” |
| Connectivity | Connected, offline, unknown | Shown only when it matters to delivery, not as personal surveillance |
| Sharing policy | Active, paused, denied, pending | Detailed state is visible to the subject; other members normally see only “No recent update” |

Confidence comes from source quality and deterministic rules, not from the language model rating its own answer. “No recent information is available” is valid. Compass can then offer **Request a check-in**.

### 2.6 Permission is checked before AI generation

The language model must not decide what a family member is allowed to know. The backend first applies the permission policy, creates a limited structured fact, and only then lets the model explain or combine it.

### 2.7 Important actions require confirmation

Compass may draft a plan, reminder, poll, or message. It may not silently publish, assign, reschedule, disclose, or cancel anything that affects another person.

### 2.8 The app must remain calm

Notifications, AI messages, scores, badges, and urgent colors can turn coordination into pressure. Family Compass should use quiet defaults, digests, cooldowns, and clear controls. It should not rank family members or measure who “cares more.”

## 3. Product structure and core journeys

### 3.1 Today

Recommended order in portrait:

1. **Next time together**
   - Confirmed plan, time, place or call link, attendees, pending replies
   - Quick actions: View plan, Respond, Suggest change
2. **Needs your reply**
   - Polls, invitations, and plan changes that need a decision
3. **Relevant family updates**
   - Only updates someone explicitly shared or information that affects a current plan
   - Examples: “Dad shared: Running about 15 minutes late,” “Mom shared: Busy until 5:30”
4. **Compass suggestion**
   - One high-value action, such as “Friday evening looks open for four people. Start a dinner poll?”

Do not show a permanent roster of every member's availability. That can feel like a tracking dashboard and creates pressure around not sharing. The complete member list belongs behind the family menu. Do not place a map, route, journey history, family score, or long recommendation feed here.

### 3.2 Chat

Chat should feel familiar and intentionally smaller in scope than a general messaging platform.

Version 1 Must items:

- Text
- Check-in cards
- Plan, poll, and reminder cards
- Direct `@Compass` questions

Replies, photos, reactions, and an expiring place pin shared to the current family room are Should items after the core text and planning flow is reliable.

Chat and Compass have separate jobs. The Compass tab is for private questions, explanations, corrections, and drafts. `@Compass` in Chat creates a family-visible request and may draft a plan, poll, or reminder. In Version 1 it may answer a contextual status question only from an unexpired status that the subject already shared with the entire family room. The answer references the original status card and adds no private detail. Anything with a narrower audience opens in private Compass.

Routine chatter remains human. One narrow automatic behavior may be tested: after someone asks a direct status question and no person answers, a deterministic template may reference an unexpired family-room status after a quiet delay. This path does not call an external language model, is clearly labeled as a system answer, has a cooldown and dismiss control, and can be disabled. When the original status expires, the linked card becomes a neutral expired placeholder.

### 3.3 Compass

The Compass tab and its history are private to the account holder. A Version 1 answer card contains:

- The answer
- Member-shared or no recent permitted information
- Source
- Last updated time
- “Why this answer?”
- A correction or privacy action when relevant
- A useful next step

Example:

> Dad shared an ETA of about 7:20 PM, updated 3 minutes ago. This is Dad's own estimate and may change.

A Version 2B context experiment may add a clearly labeled system-derived estimate, but that is not part of the Version 1 answer model.

If Dad did not authorize that information for the requester, Compass must not hint that the data exists. It should say that no permitted recent information is available.

### 3.4 Together

Together should contain three clear sections:

- **Next:** The next confirmed gathering and its coordination
- **Decide:** Open invitations, polls, and suggested plans
- **Later:** Future plans and saved ideas, plus recurring rituals when Version 2A enables them

Reminders, attendees, rides, and voluntary contributions belong inside a plan. They are not separate top-level systems.

The creation flow should be short:

```text
Choose an idea or enter one
→ choose candidate times
→ choose participants
→ send a poll or confirm directly
```

Use quick templates for Dinner, Family call, Visit, Walk, and Custom. Give each poll a sensible automatic deadline and one poll nudge; **Change deadline** belongs under options. Show **Going**, **Maybe**, and **Cannot make it** first. **Suggest another time** opens after Maybe or Cannot make it. Confirmation creates one sensible gathering reminder automatically, which the coordinator can adjust. Ask about rides, food, and voluntary contributions only after the plan is confirmed. Each plan has one coordinator, but that role gives no control over another member or their privacy. After a gathering, offer one-tap **Plan this again**. Saved family rituals belong in Version 2A, after the basic loop works.

### 3.5 Invitations and activation

The minimum setup flow is:

1. See the product value.
2. Verify phone number.
3. Create or join a family.
4. Choose name and avatar.
5. Invite people with phone numbers or a secure link.
6. Enter Today immediately.

Permission requests should occur when the related feature is used. Apple recommends brief, optional onboarding and postponing nonessential setup; Android likewise recommends showing value, collecting only critical information, and providing recovery paths. ([Apple onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding), [Android authentication and onboarding](https://developer.android.com/design/ui/mobile/guides/patterns/onboarding))

Manual phone entry must remain available so Contacts permission is never required just to invite someone.

### 3.6 Privacy control journey

Each member needs a **My sharing** area that answers:

- What am I sharing now?
- Who can see it?
- What can Compass use?
- When does it expire?
- How do I pause or correct it?

Keep the main journey simple:

1. Not sharing
2. Manual check-in, with audience and expiry

Version 1 also supports a manually entered ETA. An expiring place pin in the current family room is a Should item, not part of the gathering-critical scope. Named-place status, automatic activity, and user-started trip context remain Version 2 experiments. Detailed disclosure history is available in account and privacy controls when real data exists, not placed in the main daily journey.

## 4. Current Prototype 1: freeze it as a learning artifact

The existing Flutter prototype is useful because it demonstrated a phone interface, dashboard cards, chat, AI, reminders, recommendations, invitations, permissions, and a broad family-status concept.

It should now be treated as a reference, not polished as the final structure. Its main product problems are:

- Five tabs instead of four
- A visible journey or map experience that makes tracking feel central
- Gathering spread across reminders, recommendations, and dashboard cards instead of one complete loop
- AI behavior that feels button-driven instead of naturally available in Chat and Compass
- Too many concepts competing for attention
- Family scoring or challenges that can create pressure
- Status data without a sufficiently strong source, freshness, and permission explanation
- Portrait-first screens without a complete adaptive rule set

Prototype 1 should remain available for comparison. New product decisions should be implemented only in Prototype 2.

## 5. Prototype 2: prove understanding and trust

### 5.1 Objective

Prove that people understand the four-part product, recognize gathering as its primary purpose, can complete a planning loop, and understand that the app does not expose a permanent family map.

### 5.2 Product hypotheses

- People can understand Today, Chat, Compass, and Together without explanation.
- A family can turn a suggestion or chat message into a confirmed plan.
- People understand the difference between something a member shared and no recent information. If the optional Version 2B concept probe is run, it separately tests whether a system-derived estimate is understood.
- Privacy controls are understandable enough to create trust.
- Phone rotation does not interrupt a task.

### 5.3 Include

#### App shell

- Polished Flutter prototype using local scripted data
- Four final tabs: Today, Chat, Compass, Together
- Profile and family menu
- Short mock onboarding and family invite path
- Complete light theme for the core scenario
- Representative dark and Arabic right-to-left screens
- Complete phone portrait and landscape behavior, plus one representative medium-width layout

#### Today

- Next time together as the leading card
- Needs your reply
- One explicitly shared family update that affects the plan
- One actionable Compass recommendation
- Representative empty and offline variants

#### Chat

- Scripted family conversation
- Text messages and plan cards only
- Check-in request and response
- Direct `@Compass`
- A Compass plan draft and, after an explicit request, a separate reminder draft
- Clear distinction between a human message and an AI card

#### Compass

- Private conversation
- Source and freshness language
- “Why this answer?”
- Request a check-in
- One correction action
- One draft action
- One unknown case

#### Together

- Start from a Dinner template
- Choose candidate times
- Use simple Going, Maybe, and Cannot make it responses, with Suggest another time available after Maybe or Cannot make it
- Use an automatic poll deadline and one poll nudge, with Change deadline under options
- Send an availability poll
- Respond to a poll
- Confirm a plan
- See the automatic gathering reminder and optionally adjust it
- After confirmation, add one optional contribution such as “I can bring dessert”
- Use Plan this again after the gathering

#### Privacy

- What I am sharing
- Who sees it
- When it ends
- Pause sharing

#### Normal app states

- Loading
- Empty
- Offline with retry
- Permission denied
- No recent information
- AI unavailable while the rest of the app remains usable
- One large-text and screen-reader pass of the core flows

The complete state catalog, full dark theme, full Arabic coverage, expanded layouts, and disclosure history are specified during Prototype 2 but become fully functional in Prototype 3. This keeps the next prototype focused on learning rather than coverage.

### 5.4 Required demonstration scenarios

1. **Chat to gathering:** A message about Friday becomes a poll, responses arrive, and the family confirms dinner.
2. **Reassurance without a map:** Someone asks where Dad is. Compass explains Dad's permitted manually shared status or ETA with its source and age, then proposes changing dinner time.

A short supporting test covers privacy: a member reviews current sharing, changes the audience or expiry, and pauses it.

An optional, separately labeled concept probe may show a simulated system-derived delay to test comprehension of the future Version 2B idea. It is not part of the Version 1 demonstration or the Prototype 2 exit gate.

### 5.5 Exclude

- Real backend or database
- Real OTP or SMS
- Real GPS or background location
- Real route tracking
- Real AI model
- Real push notifications
- Voice or video calls
- Journey screen or history
- Routine learning
- Children-specific accounts
- Crash or emergency detection
- Leaderboards or bonding scores

### 5.6 Research and testing

Test with 8 to 12 adults across at least three families. Include several adult age groups and at least one family whose members do not live together.

Tasks:

- Find the next family gathering.
- Propose and confirm a new gathering.
- Turn a chat message into a reminder or plan.
- Ask about a family member.
- Explain whether the answer came from the member or no recent information was available.
- Pause personal sharing.
- Rotate the phone while composing a message or poll and continue.
- Review the representative Arabic and large-text screens for comprehension and clipping.

### 5.7 Exit gate

Proceed only when:

- No more than two participants need help to complete the main gathering flow.
- No more than two participants misidentify a member-shared answer as an automatic inference, or believe missing information is being hidden from them.
- The four-tab structure does not require explanation.
- Participants understand there is no permanent family map.
- No serious privacy misunderstanding repeats across more than one family group.
- Rotation preserves the unfinished task.
- At least three families agree to test a functional build.

### 5.8 Deliverables

- Final information architecture
- Clickable Flutter prototype
- Design tokens and component inventory
- Complete phone portrait and landscape screens
- Representative medium-width, dark, Arabic, and large-text screens
- Specification for expanded layouts and the full state catalog
- Scripted demo data and scenarios
- Usability report and decision log
- Frozen Prototype 3 scope

## 6. Prototype 3: prove the end-to-end workflow

### 6.1 Objective

Prove that a small family can join across real devices, chat, propose a gathering, vote, confirm it, receive notifications, and use a grounded AI assistant without permission leaks.

### 6.2 Include

#### Identity and family

- FastAPI backend with a real development database
- Firebase Authentication test phone numbers or equivalent development auth
- Create family
- Invite, accept, decline, revoke, and expire invitation
- Leave family and remove member
- Development session and device management, including revoke and number-change tests
- Recycled-number, invitation-enumeration, and account-recovery scenarios
- Secure invitation deep links

#### Communication and coordination

- Real-time text chat
- Manual expiring statuses and check-ins
- Request a check-in
- Complete Together workflow
- Push notifications on test devices
- Today driven by real family data
- Deep links from notifications into the exact chat, poll, or plan

Stretch work outside the Prototype 3 exit gate:

- Reactions
- Basic image attachments

#### AI

- Real provider-neutral AI service behind FastAPI
- Private Compass conversation
- Direct `@Compass` in Chat
- Plan, poll, reminder, and message drafts
- Permission checks before every answer
- Source, freshness, and “Why this answer?”
- Honest abstention for missing or unauthorized data
- Provider timeout, rate-limit, and unavailable states
- Human confirmation before actions affect another person

#### Context simulation

- Simulated manual status, manually entered ETA, stale, expired, missing, unauthorized, and offline events
- A structured fact store with expiry and visibility
- No passive device location collection

#### Mobile quality

- Offline reading for recent chat, family status, and confirmed plans
- Queued messages, votes, and check-ins with “Waiting to send” state
- Idempotent retry so actions are not duplicated
- Session and draft restoration after rotation or restart
- Complete loading, empty, partial, error, expired-session, and permission-denied states
- Basic analytics and crash reporting with consent
- TalkBack, VoiceOver, large text, keyboard, English, and Arabic checks

Official Android guidance recommends that an offline-first app show local data immediately and preserve a critical subset of functionality when the network is unreliable. ([Android offline-first architecture](https://developer.android.com/topic/architecture/data-layer/offline-first))

### 6.3 Exclude

- Passive GPS
- Automatic routines
- Permanent map or movement history
- Calendar integration
- Free-form unsolicited AI chat messages
- Voice and video calls
- Emergency claims
- Member ranking or family scores
- Adult privacy overrides
- Production minor accounts

### 6.4 Recommended AI and permission pipeline

```text
User request or product rule
→ authenticate requester
→ determine private or family-visible audience
→ authorize every subject-to-recipient relationship
→ select permitted structured facts
→ validate source type and freshness
→ enforce each subject's external-AI-processing consent
→ send minimum necessary context to AI provider
→ validate structured result
→ recheck that every output fact is permitted for every recipient
→ show source, uncertainty, and action draft
→ require user confirmation
```

Private Compass history is never an input to a family-visible answer. Chat content must be treated as untrusted input. Test prompt injection, attempts to reveal hidden facts, contradictory messages, provider failures, and fabricated tool instructions.

In Version 1, a family-visible contextual answer can reference only an unexpired fact already shared with the entire family room. Facts with narrower audiences remain in private Compass. Broader system-derived group answers wait for a later experiment.

### 6.5 Test period

Run a 7-day internal test with three to five families.

Test:

- Invitation spam, token reuse, expiry, and account takeover attempts
- Shared-device, coercive-control, stalking, organizer-abuse, and repeated check-in-request scenarios
- Every requester and subject permission combination
- Multi-device message delivery and ordering
- Notification delivery and deep links
- Offline writes and duplicate retries
- AI prompt injection through messages
- Incorrect, stale, missing, unauthorized, and contradictory facts
- Rotation during messages, polls, and forms
- App restart with drafts and pending writes
- Maximum text size, screen readers, English, Arabic, and mixed-direction messages

### 6.6 Exit gate

Proceed only when:

- Every test family completes at least one full gathering loop.
- No permission test exposes unauthorized information.
- All AI actions require confirmation.
- Missing or unauthorized information produces an honest neutral answer or check-in option.
- Core Chat and Together flows work when AI is unavailable.
- Core flows recover from network failure without duplicates or data loss.
- Controlled notification tests meet the defined threshold on each target device. Initial target: at least 95 percent arrive within 60 seconds over at least 20 test events per device, with the in-app inbox remaining authoritative.
- No critical crash, security, privacy, or data-loss issue remains.
- Test families find Together useful beyond an ordinary group chat.

## 7. Version 1: a focused production release

### 7.1 Objective

Release a stable app that families repeatedly use to coordinate real time together. Reassurance comes from explicit sharing, manual check-ins, and honest data freshness. The public release must not depend on continuous background location.

### 7.2 Version 1 audience decision

Version 1 supports adult account holders only. Enforce the age eligibility in onboarding, invitations, terms, store age ratings, support policy, and research recruitment. “Different ages” in Prototype 2 testing means adults from different age groups unless a guardian-approved research process is added.

Supervised minor accounts are postponed until parental consent, age assurance, chat safety, deletion, regional rules, and location restrictions receive a dedicated design and legal review. If minors become mandatory for launch, that is a separate pre-release workstream and changes the schedule.

### 7.3 Core product

#### Today

- Next gathering
- Needs your reply
- Only relevant updates explicitly shared or affecting a current plan
- One useful Compass suggestion
- Source and freshness on every family status

#### Chat

- Real-time text
- Replies
- Photos and reactions as Should items after the text flow is reliable
- Check-ins
- Expiring place pin shared to the current family room as a Should item
- Plan, poll, and reminder cards
- Direct `@Compass`
- Report, true block, mute, leave-family, and support paths
- Content and AI-output reporting with an operational moderation queue

Apple treats chat as user-generated content and requires objectionable-content filtering, reporting with timely handling, the ability to block abusive users, and published developer contact information. The implementation needs these operations even though Chat is private to a family. ([Apple App Review Guidelines, section 1.2](https://developer.apple.com/app-store/review/guidelines/))

#### Compass

- Private grounded assistant
- Permitted family summaries
- Plan and reminder drafts
- Source, freshness, and explanation
- Corrections and feedback
- Check-in requests
- No answer when data is missing or unauthorized

#### Together

- Dinner, Family call, Visit, Walk, and Custom templates
- Ideas and recommendations with a single next action
- Plan-specific candidate-time polls
- Automatic decision deadline and one poll nudge, with Change deadline under options
- Confirmed plans
- Going, Maybe, and Cannot make it responses, with Suggest another time after Maybe or Cannot make it
- Participant-local times and clear time-zone labels when members differ
- Plan changes and cancellation notices
- One automatic gathering reminder after confirmation, with optional adjustment
- Plan-specific rides and voluntary contributions
- Optional external call or meeting link
- Optional “Did this happen?” and one-tap “Plan this again” follow-up instead of a score

Store plan instants with their IANA time zone, show each participant's local time, label the organizer's zone when members differ, and recompute daylight-saving changes safely. Localize dates, numerals, plurals, and mixed Arabic and Latin text rather than concatenating strings.

#### Family and membership

- Production phone authentication and recovery
- OTP autofill and paste, international number formatting, clear resend behavior, and accessible error recovery
- Phone-number change, lost or recycled number handling, multi-device session revoke, SIM-swap risk checks, and reviewed account merge
- Secure invite links and phone invitations
- Member roles for membership administration
- Independent adult privacy controls
- Profile and family management
- Leave, remove, and transfer organizer role

Family authority and plan authority are separate:

- A family organizer can invite, remove, and transfer the organizer role, but cannot read private Compass history or control another adult's sharing.
- A plan coordinator can edit candidate times, close the poll, confirm, reschedule, or cancel that plan. Every change notifies participants.
- Participants control only their own response and contribution. Nobody edits another person's RSVP or assignment.
- A true block stops direct invitations and hides or prevents messages according to the documented family-room rule. If two blocked adults remain in one family, the app explains the limitation and offers leave-family and support paths.

### 7.4 Public Version 1 location boundary

Must include:

- Manual status with expiry
- Manual check-in
- Request a check-in
- Manually entered, recipient-scoped ETA with expiry

These are deliberate disclosures, not automatic sharing modes.

An expiring place pin is a Should item. It is shared to the current family room without a separate recipient picker and is described as a place, not as a member's live location. A sender may search or manually enter the place. If the sender chooses **Use my current place**, the app requests location only for that transaction, creates the place pin, and does not start ongoing sharing. The pin defaults to a short expiry, can be revoked, and becomes “Place expired” after its coordinates are deleted. Explain that recipients can still take screenshots, strip location metadata from ordinary photo uploads, document map-provider caching, and keep manual place entry available when permission is denied. On iOS this uses **When In Use** authorization. When targeting Android versions that require the system location button for transactional access, use that minimum-scope mechanism rather than requesting persistent fine location. ([Apple location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services), [Google Play minimum-scope location guidance](https://support.google.com/googleplay/android-developer/answer/17033915))

Do not include publicly:

- Continuous background location
- Automatic named-place detection
- Automatic commute or routine inference
- Visible journeys
- Permanent map
- Long-term raw movement history

### 7.5 AI behavior at launch

- Direct questions get direct answers.
- Only one proactive suggestion can be active across the app.
- Today shows that suggestion when immediate action is useful; Together stores it when it can wait.
- Chat normally shows Compass only after `@Compass` or a deliberate user action.
- The narrow deterministic unanswered-status template defined in section 3.2 may run without an external model.
- Compass may draft but may not silently act.
- Every contextual answer includes source age and certainty.
- The assistant abstains for unknown or unauthorized information.
- Members can correct an inference and reduce similar suggestions.
- The AI remains optional. Chat, plans, and reminders work without it.

Apple's current review rules require clear disclosure and explicit permission before personal data is shared with a third-party AI. The privacy design and AI gateway must minimize what leaves the backend and disclose the provider relationship accurately. ([Apple App Review Guidelines, section 5.1](https://developer.apple.com/app-store/review/guidelines/))

The consent rule is per data subject, not only per requester. Permission for a family member to view Dad's status does not automatically permit sending Dad's status, messages, photos, or location to an external AI provider. Each adult separately chooses whether their data may be processed by an external provider. A provider change requires a new disclosure and consent. Withdrawal excludes that member's data from later provider requests. Version 1 uses deterministic non-LLM responses for status, source, freshness, and core coordination when external AI consent is absent or the provider is unavailable. Self-hosted and on-device language models remain later provider experiments; they do not change the disclosure rules automatically.

Version 1 should not continuously stream ordinary Chat to a language model. Product rules may identify a clear planning opportunity or run the narrow unanswered-status template without an external model. External AI runs only after a user invokes `@Compass`, opens Compass, or taps a draft action. The gateway sends the smallest authorized question, selected excerpts, and structured facts. It never uses private Compass history in a group answer. Provider retention, training use, data region, deletion, and logging terms must be documented and enforced.

### 7.6 Privacy and security

- Backend authorization on every sensitive request
- Per-member sharing choices
- Expiring and revocable manual statuses and ETAs, with a clear server-confirmation failure state
- Disclosure history for manual sharing and external-AI processing
- Device and session list with remote revoke
- Encryption in transit and at rest
- Rate limits for OTP, invitations, messages, media, and AI
- Short-lived signed invite tokens
- Neutral invitation and account responses that do not reveal whether a phone number already has an account
- Safe logging with no raw secrets or unnecessary family content
- Clear retention schedule
- Data export
- Account and data deletion
- A documented deletion result for shared messages, photos, Compass history, manual statuses, ETAs, and AI outputs
- Deletion timelines, legally required retention exceptions, and organizer-role transfer behavior
- Privacy policy, terms, help, and incident contact
- Security and privacy change notifications

The disclosure ledger shows the subject which fact category was disclosed, to whom, when, and from which source. It does not expose the requester's private question text or private Compass history. A personal export contains only that account holder's private Compass history and personal data. A family organizer cannot export another member's private assistant conversation or private context.

New members do not receive family Chat history from before they joined. Removing a member ends server access and future delivery immediately, although the app cannot retract screenshots or content already copied outside the service. Version 1 family-visible contextual answers only link to an original family-room status card. When that status expires or is revoked, the linked card becomes a neutral placeholder and protected cached details expire. Notifications never preserve the sensitive answer. Revocation does not pretend to erase information another person already read; the UI explains this limit plainly. General AI answers with custom or changing Chat audiences wait for a later, separately tested design.

Do not claim end-to-end encrypted Chat unless the architecture truly supports it, including any server-side AI processing. Describe actual protection accurately.

Apps that create accounts need an in-app deletion path on both stores. Google Play also requires an external deletion-request resource. ([Apple account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/), [Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111))

Leaving a family, removing a member, deleting a Compass conversation, deleting an expiring place item, and deleting the whole account are different actions. Account deletion must cover associated messages and media unless a clearly disclosed legal retention exception applies, show the expected completion time, and transfer or close plans and organizer duties safely.

### 7.7 Standard mobile shell

- Fast launch or immediate progress feedback
- Secure session restoration
- Predictable back navigation
- Platform-appropriate back gestures, page transitions, scrolling, text editing, pickers, and controls
- Deep links
- Offline reads and queued writes
- Loading, empty, offline, stale, partial, and error states
- Notification preferences and quiet hours
- Just-in-time permission requests with usable denial paths
- Account, family, sharing, notification, appearance, language, privacy, data, and help screens
- English and Arabic with full right-to-left support
- System light and dark mode
- Screen-reader labels
- Logical semantic reading order and predictable focus after navigation, dialogs, and sheets
- Accessible alternatives to swipe-only actions
- Polite live announcements for incoming messages, completed AI answers, send failures, and relevant status changes
- Large text and display scaling
- Reduced motion
- Minimum 48 by 48 logical-pixel touch targets
- Crash and performance monitoring with privacy-respecting consent
- App upgrade and data migration handling
- Support, feedback, privacy policy, terms, version, and licenses
- Store privacy labels and Google Play Data safety information

Flutter already adapts many navigation, scrolling, text-editing, icon, and haptic behaviors by platform, and provides adaptive controls where a design decision is needed. The app should preserve these familiar iOS and Android conventions while keeping one Family Compass visual identity. ([Flutter platform adaptations](https://docs.flutter.dev/ui/adaptive-responsive/platform-adaptations))

Flutter recommends testing TalkBack and VoiceOver, at least 4.5:1 contrast, 48 by 48 tappable targets, large scaling, undo for important actions, and interfaces that do not depend on color alone. Flutter semantics can mark changing content as a live region for assistive technologies. ([Flutter accessibility](https://docs.flutter.dev/ui/accessibility), [Flutter live-region semantics](https://api.flutter.dev/flutter/semantics/SemanticsProperties/liveRegion.html))

### 7.8 Version 1 exclusions

- Permanent family map
- Continuous passive location
- Automatic routine learning
- Exact-location answers by default
- Automatic rescheduling or task assignment
- Family admin surveillance
- Mood, affection, relationship, or safety inference
- Bonding scores, rankings, or competitive streaks
- Emergency or collision detection
- In-app voice and video calling
- Advertising based on family data
- Production minor accounts without the separate safety workstream

### 7.9 Production readiness gate

Before public release:

- Closed beta with roughly 20 to 30 families for at least four weeks
- Full requester-to-subject permission-matrix tests
- AI evaluation set for member-shared, stale, unauthorized, contradictory, and missing information
- Invitation and account takeover testing
- Coercive-control, shared-device, stalking, organizer-abuse, and check-in-harassment threat-model tests
- Independent security and privacy review
- Accessibility audit
- Arabic and English quality review
- Battery, network, offline, and notification tests
- Store-policy review
- Tested deletion, export, recovery, backup, migration, and incident procedures
- No unresolved critical crash, authorization, data-loss, or disclosure defect

## 8. Version 2: improve gathering first, then test context

Version 2 has two ordered tracks. Version 2A makes it easier to find a suitable time and repeat successful gatherings. Version 2B tests optional reassurance context only after Version 2A and Version 1 have proven repeated family value.

### 8.1 Version 2A objective: easier gathering

Increase the percentage of families that complete and repeat a gathering without adding surveillance or notification pressure.

### 8.2 Version 2A features

Treat Version 2A as ordered experiments, not one large release bundle:

1. **Reusable manual availability**
   - Examples: “Free this weekend” and “Usually free Friday evening”
   - The complete Version 1 plan-specific poll remains available
2. **Consent-based calendar free/busy**
   - Import availability blocks, not event titles or notes
   - Calendar denial changes nothing in the manual path
3. **Preference-aware candidate times and ideas**
   - Use declared preferred days, time zones, budget, dietary needs, and activity preferences
   - Keep recommendations correctable and easy to reduce
4. **Saved recurring rituals**
   - Turn a successful plan into a reusable pattern
   - Continue to require confirmation for each occurrence

Travel-time suggestions, memory cards, digests, richer place suggestions, and multiple family circles remain later backlog items. Add them only after the first four experiments improve completed or repeated gatherings.

### 8.3 Version 2A release gate

- More activated families complete at least one gathering in 30 days than in Version 1.
- More families arrange another gathering in the following 30 days.
- Proposal-to-confirmation time improves without a rise in notification muting.
- Calendar denial leaves the complete manual planning path available.
- Recommendations remain easy to dismiss, correct, and reduce.

### 8.4 Version 2B objective: optional reassurance context

Test whether temporary, user-controlled context reduces repeated status questions or improves current-plan coordination without increasing privacy discomfort, battery use, or false conclusions.

Every Version 2B feature is a policy-contingent experiment behind separate consent, a remote feature flag, and a kill switch. Consent and user value do not guarantee store approval. Google Play requires background location to be important to the declared core functionality, prefers minimum-scope foreground access, and can treat a foreground service as background-equivalent. ([Google Play background location policy](https://support.google.com/googleplay/android-developer/answer/9799150), [Android background location guidance](https://developer.android.com/develop/sensors-and-location/location/background))

On iOS, default to **When In Use** authorization. A user-started location session may continue while the app moves to the background when background updates are configured and the system background-location indicator remains visible. **Always** authorization is a separate decision for unattended delivery outside an active user-started session or behavior that must resume after termination. Each design must justify direct relevance, purpose strings, background mode, visible indication, battery behavior, and App Review guideline 5.1.5. ([Apple location authorization](https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services), [Apple background location updates](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background), [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/))

Recommended experiment order:

1. **User-started temporary ETA sharing**
   - Transactional or foreground access wherever possible
   - Clear start, stop, recipients, and expiry
   - Approximate ETA, not a permanent route view
2. **Plan-specific delay detection**
   - Routes service calculates a change only during the user-started share
   - Family sees “Running about 15 minutes late,” not coordinates
3. **Named-place status, policy permitting**
   - Separate opt-in per named place and audience
   - Easy correction and deletion

Approximate activity, learned routines, and automatic answers stay in research until the earlier experiments pass. If routine work proceeds, classification happens on-device and only a user-confirmed derived routine is uploaded. The server does not need durable raw movement history.

The map can remain absent from the family interface. Data collection cannot be hidden. People see when context is active, what is inferred, who can receive it, how long it lasts, and how to stop it.

### 8.5 Version 2B context architecture

```text
User starts a context feature
→ minimum-scope phone signal
→ local or backend deterministic classification
→ confidence and freshness validation
→ permission policy
→ short-lived derived fact
→ Today card, Compass answer, or plan update
```

The language model explains permitted facts. Deterministic services calculate expiry, route time, permissions, and confidence. Raw coordinates have the shortest practical lifetime, preferably without durable storage. Derived facts receive the same protection as their source.

### 8.6 Version 2B feature gate

Ship each experiment only when:

- Store-policy review confirms the exact implementation is eligible.
- Required Play declarations, prominent disclosure, demonstration video, privacy policy, and foreground-service review are complete.
- Users understand and actively enable it.
- It improves completed gatherings, current-plan coordination, or repeated status questions compared with Version 1.
- Incorrect inferences are uncommon and easy to correct.
- Battery impact stays within the tested target.
- Notification muting and AI dismissal do not materially increase.
- Local collection stops immediately on pause, and server revocation is confirmed before the UI claims completion.
- Coercive-control, shared-device, stalking, organizer-abuse, and account-takeover tests pass.
- Security and privacy review finds no critical issue.

### 8.7 Platform improvements after core quality

- Passkeys in addition to phone recovery
- Home-screen widgets if users repeatedly seek next-plan information
- Book and tabletop foldable posture optimization
- Keyboard shortcuts and external-input refinements
- Optional voice notes if Chat usage supports the cost
- Supervised minor accounts only after the dedicated safety and legal workstream

Baseline tablet layouts, hinge safety, and deterministic offline conflicts are Version 1 quality requirements, not Version 2 features.

### 8.8 Continue to exclude

- Permanent map
- Hidden background surveillance
- Long-term raw location history
- Adult privacy overrides
- Location sale or advertising
- Relationship, mood, affection, or safety scores
- AI impersonation
- Important automatic actions without approval
- Claims that a person is safe
- Emergency detection without a separately validated safety product

Technology working is not sufficient evidence to ship it.

## 9. Standard mobile features and where they belong

Modern app quality includes behavior outside the visible feature screens. Permissions, denial paths, account recovery, deletion, rotation, accessibility, offline behavior, and error recovery are product requirements.

| Capability | Prototype 2 | Prototype 3 | Version 1 | Version 2 |
|---|---|---|---|---|
| Onboarding | Scripted and tested | Functional | Short, recoverable, contextual | Personalized tips only if useful |
| Authentication | Mock | Test phone accounts | Production OTP and recovery | Passkeys optional |
| Invitations | Mock | Deep-linked test flow | Secure phone and link flow | More circles if demanded |
| Navigation and back | Designed | Implemented | Platform QA | Keyboard and larger-screen refinement |
| Loading, empty, error | Representative core states | Full catalog functional | Production copy and telemetry | Refine from data |
| Offline and retry | Representative core state | Core queue implemented | Recent data readable, writes queued, deterministic conflicts | Cross-device refinements |
| State restoration | Local tab, scroll, and unfinished form state survives resizing and rotation | Navigation, drafts, and pending writes survive restart and process loss | Full rotation, restart, and process-loss QA | Cross-device continuation if valuable |
| Notifications | Mock controls | Real test delivery | Categories, quiet hours, redaction | Digests and smarter timing |
| Settings | Four-area structure | Functional core | Complete | Add only proven options |
| Permissions | Key request and denial examples | Functional matrix | Store-ready matrix and recovery | New context permissions reviewed separately |
| Privacy and data | Current sharing and pause | Policy engine and ledger | Export, deletion, retention, consent | Context-specific controls |
| Accessibility | Contrast, targets, labels | Screen-reader and large-text pass | Audited | Refine new form factors |
| English and Arabic | Representative key screens | Full core UI | Production localization, time zones, and RTL | More languages if demanded |
| Light and dark | Light complete, dark representative | Implemented | Follows system | Optional contrast refinement |
| Help and feedback | Designed | Functional | Support and report channel | Contextual diagnostics |
| Chat moderation | Safety flow designed | Report and block functional | Filtering, operations, contact, and response process | Refine from reports |
| Analytics and crashes | Event plan | Consent-based test telemetry | Production monitoring | Experiment framework |
| Account deletion | Designed | Functional test flow | In-app plus required web path | Extend to new data types |
| Store compliance | Checklist | Preflight | Complete privacy labels and review | Recheck every new context feature |

### 9.1 Notification categories

Keep visible notification choices short:

- **Family:** Direct messages and check-in requests
- **Plans:** Invitations, votes, reminders, and important changes
- **Compass:** Suggestions, off by default or delivered as a digest

Security and privacy changes use a separate service category and cannot be disguised as recommendations.

The default lock-screen wording should protect sensitive information, for example:

> Family Compass has a family update.

Avoid exposing a person's place, health-related destination, exact ETA, or private message in the lock-screen text or the APNs/FCM payload. Push a minimal opaque event identifier, then fetch protected details after authentication. Notifications are never required for the app to work. Ask permission in context, provide a complete denial path, and test Android 13 and later notification permission behavior. Notifications need consent and should be timely, high-value, and controllable. Android notification channels give users category-level control. ([Apple notifications](https://developer.apple.com/design/human-interface-guidelines/notifications), [Apple App Review Guidelines, section 4.5.4](https://developer.apple.com/app-store/review/guidelines/), [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission), [Android notification channels](https://developer.android.com/develop/ui/compose/notifications/channels))

### 9.2 Settings structure

- **Family:** Profile, members, invitations, and plan roles
- **Sharing and privacy:** Current sharing, Compass processing, disclosures, export, and deletion
- **Notifications and appearance:** Family, plans, Compass digest, quiet hours, theme, and language
- **Account and help:** Sessions, phone recovery, support, report history, legal, and app information

Frequent controls such as **Pause sharing** and per-plan reminders should also remain near the feature. Settings should contain infrequent preferences and use safe, polite defaults. ([Android settings guidance](https://developer.android.com/design/ui/mobile/guides/patterns/settings))

### 9.3 State catalog

Every important screen must define:

- First load
- Refreshing with existing content
- Empty
- Partial content
- Offline with cached data
- Waiting to send
- Failed to send
- Retry in progress
- Stale
- Permission denied
- No recent update after a viewer asks Compass or requests a check-in; never as an unsolicited Today warning
- Sharing paused, denied, expired, or pause pending for the subject's own controls
- Session expired
- Invitation expired or revoked
- Membership removed
- AI unavailable
- Media upload failed
- Destructive action confirmation and undo where possible

These states should be part of Prototype 2 designs, not discovered during backend development.

Version 1 also needs deterministic conflict rules. A vote arriving after a poll closes is rejected and preserved as an unsent local action with an explanation. An edit after cancellation or membership removal is rejected. Concurrent plan edits use a version check and show the newer plan before retry. Message and plan creation use idempotency keys so reconnecting cannot create duplicates.

### 9.4 Permission matrix

| Permission | Ask when | Denial path |
|---|---|---|
| Notifications | After the user creates a reminder, joins a plan, or enables family alerts | In-app inbox, badges, and manual refresh remain available |
| Photos or camera | When attaching a photo | Text and existing-file alternatives; no setup blocker |
| Contacts | Prefer the system Contact Picker when the user chooses it; avoid broad address-book access | Manual international phone-number entry |
| Transactional location | When attaching an expiring pin | Manual place or address entry |
| Activity recognition | Only inside a separately approved Version 2B experiment | Manual status and check-in |
| Calendar | When the user chooses Connect calendar in Version 2A | Manual availability and candidate times |
| Microphone | Only if voice notes are later added | Text and photo Chat remain complete |

Every request needs a plain-language rationale, a usable decline option, current status, a direct recovery path to system settings when appropriate, and tests for first denial, repeated denial, restricted devices, and later revocation.

### 9.5 Initial production quality budgets

Ratify these targets after Prototype 3 on named reference devices and networks:

- No blank launch screen for more than 2 seconds; show useful cached content or progress.
- Local visual response to send, vote, or RSVP immediately, with server acknowledgement at p95 under 2 seconds on the reference network.
- No duplicate message, vote, reminder, or plan after retry.
- Crash-free sessions at or above 99.5 percent during closed beta, with zero unresolved critical crash or ANR in a core flow.
- At least 95 percent of controlled push-test events arrive within 60 seconds on the supported test devices, while the in-app inbox remains authoritative.
- Unauthorized disclosure, failed confirmed revocation, and unrecoverable data loss remain zero-tolerance events.

Freeze supported iOS and Android versions, reference devices, and device-pixel ratios at the end of Prototype 3 based on the target audience and current Flutter, Firebase, and store requirements. The release checklist also includes app icon, launch assets, localized store copy and screenshots, age rating, privacy labels, Data safety form, support URL, privacy policy URL, and external deletion-request URL.

## 10. Visual system

### 10.1 Visual direction

The app should feel warm, calm, and social. It should retain the trusted blue lineage of the current prototype, then use a distinct soft-plum gathering accent so Today and Together do not feel like tracking, errors, or corporate dashboards. Coral can remain in illustrations and low-emphasis decorative containers, while red is reserved for failure and destructive actions.

Color roles matter more than individual swatches. Use semantic tokens so light, dark, and increased-contrast variants can change without rewriting screens. Android recommends role-based color tokens, limited semantic colors, and light and dark schemes; Apple likewise recommends adaptive color variants and sufficient contrast. ([Android color](https://developer.android.com/design/ui/mobile/guides/styles/color), [Apple color](https://developer.apple.com/design/human-interface-guidelines/color))

### 10.2 Proposed light palette

These values are a starting point for Prototype 2, not a permanent brand lock.

| Role | Value | Use |
|---|---:|---|
| Background | `#F7F5F0` | Warm main background |
| Surface | `#FFFFFF` | Cards, sheets, dialogs |
| Primary | `#2457C5` | Main actions, selected navigation, links |
| On primary | `#FFFFFF` | Text and icons on primary |
| Primary container | `#DCE8FF` | Quiet AI and information cards |
| On primary container | `#102A56` | Text on blue containers |
| Gathering accent | `#6F4AA8` | Together invitations and important gathering actions |
| Gathering container | `#E9DDF7` | Plan and poll cards |
| On gathering container | `#35204F` | Text on gathering containers |
| Primary text | `#17202A` | Headings and body |
| Secondary text | `#5B6573` | Metadata and supporting text |
| Outline | `#CBD3DE` | Dividers and neutral borders |
| Success | `#267A46` | Confirmed or completed |
| Warning | `#8A5A00` | Delay, conflict, or materially stale information |
| Error | `#B3261E` | Failure or destructive action |

Calculated sample contrast ratios include 6.47:1 for primary on white, 6.52:1 for gathering accent on white, 5.91:1 for secondary text on white, and 15.10:1 for primary text on the warm background. These exceed the WCAG 4.5:1 target for normal text. Final components still need state-by-state testing. ([WCAG 2.2 contrast](https://www.w3.org/TR/WCAG22/))

Status must never rely on color alone:

- Member-shared: person icon + “Shared by Dad, 8 min ago”
- Version 2B system-derived: compass icon + “Estimated from a trip Dad shared, 3 min ago”
- Stale: clock icon + “Last updated yesterday”
- Subject-only paused state: pause icon + “Sharing paused”
- Viewer with no permitted current fact: question icon + “No recent information”

### 10.3 Proposed dark palette

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

The app should follow the system appearance because people generally expect that consistency. Dark mode is not automatically more accessible, so light and dark schemes both require independent contrast and legibility testing. ([Android themes](https://developer.android.com/design/ui/mobile/guides/styles/themes), [Apple Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode))

### 10.4 Type, spacing, and components

- Use a system-friendly sans-serif with a high-quality Arabic companion.
- Recommended starting font sizes in Flutter logical pixels: 32 for display, 24 for screen headings, 18 for card titles, 16 for body, and 14 for metadata.
- Do not clamp system text scaling.
- Do not give cards or rows fixed heights.
- Use a 4-logical-pixel base spacing grid, with 8, 12, 16, 24, and 32 logical pixels as common steps.
- Use 16-logical-pixel card radii and restrained shadows or tonal separation.
- Use at least 48 by 48 logical pixels for every interactive target.
- Keep primary actions labeled. Do not depend on unfamiliar icons.
- Use motion mainly to explain continuity, normally 150 to 250 milliseconds.
- Respect reduced-motion settings.
- Destructive actions require clear copy, confirmation when needed, and undo when safe.

## 11. Portrait, landscape, tablet, split-screen, and foldable behavior

The app should not contain a separate hardcoded portrait and landscape design. It should respond to the current app window. Flutter recommends measuring available space, not checking device type or orientation, and advises against locking orientation. ([Flutter adaptive approach](https://docs.flutter.dev/ui/adaptive-responsive/general), [Flutter adaptive best practices](https://docs.flutter.dev/ui/adaptive-responsive/best-practices))

### 11.1 Breakpoints

| Window | Width | Navigation | Content rule |
|---|---:|---|---|
| Compact | `<600` | Bottom navigation | One pane, 16-logical-pixel side padding |
| Medium | `600-839` | Rail when height is at least 480; short bottom bar when height is compact | Usually one pane, 24-logical-pixel padding; selective card grids |
| Expanded | `840-1199` | Rail unless height is compact | Two panes when height permits, 32-logical-pixel outer padding |
| Large | `1200-1599` | Extended rail unless height is compact | Centered content, up to three dashboard columns |
| Extra large | `1600+` | Extended rail unless height is compact | Keep content width constrained and add whitespace |

Height is a separate constraint. Compact height below 480 logical pixels is a global navigation override across every width: use a short bottom or horizontal navigation bar. Pane count still depends on the minimum usable width and height of each pane. Family Compass uses one pane for the common medium-width, compact-height phone case because two useful panes are usually impractical there; a very wide shallow window must be tested rather than forced into the same rule. ([Android adaptive navigation](https://developer.android.com/develop/adaptive-apps/guides/build-adaptive-navigation), [Android window size classes](https://developer.android.com/develop/ui/views/layout/use-window-size-classes))

### 11.2 Today transformations

**Compact portrait**

- One column
- Next time together first
- Needs your reply
- Relevant family updates
- One Compass suggestion

**Medium or phone landscape**

- Short app bar
- Short bottom or horizontal navigation when height is compact
- Rail only when width is at least 600 and height is at least 480
- One pane when height is below 480
- Two independent card columns only when each retains a useful width
- Remove decorative artwork before reducing content clarity

**Expanded and larger**

- Main content around two-thirds width
- Supporting pane around one-third
- Main pane: gathering hero and an explicitly shared plan-relevant update
- Supporting pane: today's plans, confirmations, and one recommendation
- Maximum useful content width around 1100 to 1280 logical pixels

### 11.3 Chat transformations

**Compact and medium**

- One conversation pane
- Composer remains above the keyboard and bottom safe area
- Shorter header in compact-height landscape
- Details open as a route or sheet

**Expanded and larger**

- Conversation in the main pane
- Supporting pane shows the next gathering, pinned reminders, and shared context
- No map
- Message bubbles and composer remain width-constrained
- The composer stays with the message pane

### 11.4 Compass transformations

**Compact and medium**

- Full conversation pane
- Source and age expand within answer cards; confidence appears only for a Version 2B system-derived fact

**Expanded and larger**

- Conversation in the main pane
- Supporting pane for quick questions, permitted sources, privacy controls, and draft actions
- Do not add unnecessary text to fill space

### 11.5 Together transformations

**Compact**

- One scrolling page
- **Next**, **Decide**, and **Later** in that order
- Reminders, attendees, rides, and contributions remain inside the related plan
- Selecting an item opens a full detail route

**Medium**

- Adaptive card grid only when cards retain a usable width

**Expanded and larger**

- List-detail layout
- **Next**, **Decide**, and **Later** lists on the left
- The selected plan, poll, attendees, reminders, rides, and contributions on the right

### 11.6 Forms, settings, and onboarding

- Center forms at roughly 480 to 560 logical pixels maximum.
- Do not stretch text fields across a tablet.
- On expanded screens, an optional preview can sit beside the form.
- Bottom sheets on compact screens can become dialogs or supporting panes on larger windows.

### 11.7 State preservation

While the app process remains alive, rotation, resizing, split screen, and fold changes must preserve:

- Selected tab
- Nested route
- Scroll position
- Chat draft
- Attachment selection
- Partially completed poll, reminder, or plan
- Selected plan

Prototype 2 implements this local layout-change behavior in its scripted flows. Prototype 3 adds durable restoration after restart or process loss for drafts, selected routes, and pending offline actions. Version 1 tests both behaviors across the supported device matrix.

Flutter recommends restoring list and app state as the window changes. ([Flutter adaptive best practices](https://docs.flutter.dev/ui/adaptive-responsive/best-practices))

### 11.8 Safe areas, keyboards, and folds

- Protect meaningful content from notches, rounded corners, system bars, and gesture areas.
- Keep the chat composer above keyboard insets.
- Treat a separating fold hinge as a gutter between panes.
- Never place text, buttons, or a continuous message column across a hinge.
- At large text, reduce columns, stack metadata, wrap buttons, and allow cards to grow.
- Use directional padding and alignment so Arabic mirrors naturally.

Flutter's `SafeArea` and `MediaQuery` expose cutouts, insets, scaling, and display features needed for this behavior. ([Flutter SafeArea and MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery))

### 11.9 Required layout test matrix

Phase boundary:

- Prototype 2 fully tests compact portrait, compact-height phone landscape, and one medium-width layout. Local tab, scroll, and unfinished form state survives rotation and resizing. It reviews representative Arabic and large-text screens.
- Prototype 3 implements expanded layouts, durable restart and process-loss restoration, and baseline hinge avoidance.
- Version 1 runs the complete matrix below, including split screen and hinge safety.
- Version 2 may optimize special book and tabletop postures. Basic hinge safety does not wait for Version 2.

For the Version 1 quality gate, test at least these logical window dimensions:

- 320 by 568
- 390 by 844
- 844 by 390
- 600 by 960
- 840 by 600
- 1024 by 1366
- 1366 by 1024
- Approximately 500-logical-pixel split window
- Vertical separating hinge
- Horizontal hinge
- One logical pixel below, at, and above 600 and 840

Repeat critical flows with:

- Default and maximum system text size
- English and Arabic
- Keyboard open and closed
- Light and dark mode
- TalkBack and VoiceOver

## 12. Technical architecture by stage

### 12.1 Stable boundary

```text
Flutter app
→ FastAPI application API
→ authentication and authorization
→ family repositories
→ chat, plans, reminders, and status services
→ permission policy engine
→ structured fact service
→ AI gateway
→ selected AI provider
```

Maps, Routes, Firebase, notifications, storage, and AI providers should sit behind adapters. Product logic should not depend directly on an OpenAI, LM Studio, vLLM, Firebase, or Google Maps SDK response shape.

### 12.2 Prototype 2

- Local mock repositories
- Deterministic scenario engine
- No network dependency for the demonstration
- Shared design tokens and adaptive shell

### 12.3 Prototype 3

- Firebase Authentication or equivalent for test identity
- FastAPI validates identity tokens
- Real database behind repository interfaces
- WebSocket, Firestore, or another real-time adapter for Chat
- APNs and FCM behind a notification service
- Object storage behind a media service
- AI provider interface with mock and real implementations
- Central permission policy and audit events

Sensitive reads should go through one authoritative policy layer. If the client reads a real-time database directly, its security rules and backend authorization must be tested as one combined permission model.

### 12.4 Version 1

- Production database migrations and backups
- Idempotency keys for messages, votes, plans, and reminders
- Rate limits and abuse controls
- Media scanning and size limits
- Structured logs, metrics, tracing, and redaction
- Crash reporting and performance monitoring
- Support tooling for invitations, deletion, and incidents
- Feature flags for risky AI or context behavior

### 12.5 Version 2

- Context-classification service
- Maps or Routes adapter used for travel-time facts, not a family map
- Short-lived location processing
- On-device classification where practical
- Consent versioning and disclosure ledger
- Experiment and rollback controls for each context feature

## 13. Measurement plan

### 13.1 Primary outcome

Use **the percentage of activated families that report completing at least one gathering within 30 days** as the main product outcome. Pair it with **the percentage that arranges another gathering in the following 30 days** so the team measures repeated family value instead of plan volume.

The completion prompt is optional and lightweight. A confirmed plan alone does not count as a completed gathering. When available, completion means at least two participants or the plan coordinator says it happened.

An activated family can be defined as:

> At least two members join and confirm one shared plan within seven days.

### 13.2 Supporting measures

- Invitation acceptance rate
- Time from first member to second member joining
- Proposal-to-confirmation rate
- Median time to confirm a plan
- Percentage of confirmed plans reported as happened
- Percentage of families arranging a second gathering in the next 30 days
- Chat-to-plan conversion
- Reminder usefulness and dismissal
- Check-in request response rate
- Compass answer usefulness
- Percentage of answers correctly understood as member-shared or unavailable, plus system-derived when a Version 2B experiment is active

### 13.3 Trust guardrails

- Unauthorized disclosure count, target zero
- Privacy confusion reports
- AI correction rate
- False-inference rate
- Local collection-stop failure or confirmed backend-revocation failure, target zero; pending revocations tracked separately
- Notification mute rate
- AI card dismissal rate
- Account and invite abuse reports
- Battery impact for every Version 2 context feature
- Data deletion completion and delay

Do not expose these as a family score. Internal analytics should be minimized, documented, consented where required, and separated from personal family content.

## 14. Recommended timeboxes

These are planning estimates, not commitments. They assume one Flutter developer, one backend developer, and part-time product design and testing. A solo build will usually take materially longer.

| Stage | Recommended timebox | Main output |
|---|---:|---|
| Prototype 2 | 2 to 3 weeks | Tested product and adaptive interface |
| Prototype 3 | 8 to 12 weeks | Functional multi-device pilot |
| Version 1 hardening and beta | 12 to 20 weeks after Prototype 3 | Store-ready focused release |
| Version 2A and 2B | Feature-by-feature over 3 to 6 months or more | Proven gathering and context additions |

Re-estimate after Prototype 2 freezes the Must scope and again after the Prototype 3 pilot. Use exit gates rather than dates to advance. A phase that fails its trust or gathering hypothesis should be revised before technology is added.

Version 1 **Must** includes the four areas, production identity and invitations, text Chat, check-ins, the complete Together loop, grounded Compass, permissions, notifications, offline recovery, accessibility, Arabic and English, moderation, export, and deletion. Photos, reactions, biometric lock, richer media, and other polish are **Should** items that can move to a later update if they threaten the security, privacy, or gathering loop. Saved recurring rituals belong exclusively to Version 2A.

## 15. Recommended build order

### Prototype 2

1. Freeze product principles, names, and four-tab navigation.
2. Draw the complete gathering loop and privacy loop.
3. Create color, type, spacing, status, and component tokens.
4. Build the adaptive app shell and local state preservation across resizing and rotation.
5. Build Today and Together first.
6. Build Chat and Compass around the same facts and actions.
7. Add onboarding, invitations, family settings, and My sharing.
8. Add representative empty, offline, denied, no-recent-update, and AI-unavailable variants.
9. Complete phone landscape, then add representative dark, Arabic, large-text, and medium-width screens.
10. Run usability sessions and revise before freezing Prototype 3.

### Prototype 3

1. Identity, sessions, family, and invitations
2. Permission model, external-AI consent, sharing controls, deletion semantics, and audit tests
3. Account, privacy, notification, and support settings
4. Plans, polls, reminders, and Today
5. Real-time Chat, moderation, and offline queue
6. Notifications and deep links
7. Structured facts and simulated context
8. Compass and `@Compass`
9. Deletion execution, restoration, analytics, and operational tooling
10. Multi-family pilot and repair cycle

### Version 1

1. Close all data-loss, authorization, and recovery gaps.
2. Complete accessibility, Arabic, adaptive, offline, and notification QA.
3. Complete security and privacy review.
4. Run closed beta and measure repeated gathering use.
5. Finish store disclosures, support operations, deletion, and incident procedures.
6. Release only after the production gate passes.

### Version 2

1. Run Version 2A gathering experiments first.
2. Ship only the improvements that increase completed and repeated gatherings.
3. Select one policy-eligible Version 2B context hypothesis.
4. Add separate consent, disclosure, pause, correction, and kill switch.
5. Run it behind a feature flag with a small group.
6. Compare gathering value and trust guardrails with Version 1.
7. Ship, revise, or remove it based on evidence.

## 16. Decisions to keep out of scope

The following ideas should not quietly return during implementation:

- Permanent family map
- Visible journey history
- Continuous exact location by default
- Hidden collection
- Family leaderboard
- Individual bonding score
- “Most helpful” rankings
- Mood or relationship inference
- Statements that someone is safe
- AI speaking as a family member
- Silent creation, assignment, or rescheduling
- Adult privacy controlled by a family admin
- Large public social feed
- In-app calls before the core coordination loop is proven
- Advertising or data sale based on family context

## 17. Immediate decision

The next production activity should be a short Prototype 2 specification sprint, followed by implementation of the adaptive four-tab prototype. The first screens to redesign are Today and Together because they establish whether the app truly prioritizes gathering. Chat and Compass should then be rebuilt around the same plan cards, status vocabulary, permission model, and source metadata.

Do not connect real location, Firebase production data, or a live model until the Prototype 2 tests show that people understand the product and trust the sharing model.

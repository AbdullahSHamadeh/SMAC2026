# Prototype 3 external validation checklist

## Purpose and gate

Use this checklist only for a build that connects real adult accounts across
devices. The current deterministic foundation can be used to rehearse the
tasks, but it cannot pass the multi-device pilot gate.

Do not begin family sessions until all of these are true:

- [ ] The build has a commit, package version, build number, backend version,
      test environment, and test date recorded.
- [ ] Test data is isolated from production and can be deleted after the study.
- [ ] Every participant is an adult and has given informed consent.
- [ ] No participant is asked to reveal real location, health, financial, or
      private family-conflict information. Use prepared fictional updates.
- [ ] Create, invite, accept, decline, revoke, expire, leave, and remove-member
      behavior is implemented for the pilot.
- [ ] Family-scoped authorization and account recovery tests pass.
- [ ] Notification deep links and offline writes are implemented.
- [ ] Permission checks happen before AI context construction, with server-side
      evidence that denied facts never reach the provider.
- [ ] A facilitator can stop the session and delete the test family immediately.

## Test record

Record this once per candidate build:

| Field | Value |
|---|---|
| Git commit | |
| Flutter version/build | |
| Backend version | |
| Database/auth environment | |
| iPhone model and iOS version | |
| Android model and Android version | |
| English/Arabic coverage | |
| Facilitator | |
| Date and time zone | |

Use pseudonymous participant IDs such as `F1-A`, `F1-B`, and `F1-C`. Do not put
phone numbers, message content, or Compass questions in analytics or defect
titles.

## Physical iPhone pass

Run on at least one named iPhone that is not a simulator.

- [ ] Clean install, first launch, onboarding, relaunch, and sign-out complete
      without a crash or stale account data.
- [ ] No location permission is requested. Denying notifications leaves Chat,
      plans, sharing controls, and Compass available.
- [ ] Create or join a test family, then force-quit and relaunch. Membership and
      the current family are restored correctly.
- [ ] Send a Chat message, answer a poll, confirm a plan, and add a voluntary
      contribution. A second device receives each change once.
- [ ] Put the phone offline, queue one supported write, restart the app, then
      reconnect. The write is sent once and its state is explained throughout.
- [ ] Open a plan notification from locked, backgrounded, and foreground states.
      Each opens the exact family artifact, not a generic home screen.
- [ ] Switch English and Arabic. Confirm full right-to-left flow, mixed phone
      numbers, time formatting, keyboard entry, and no clipped action.
- [ ] Test light, dark, portrait, landscape, and the largest supported Dynamic
      Type size. Core actions remain reachable without horizontal scrolling.
- [ ] With VoiceOver, traverse Today, Chat composer, a poll, a grounded Compass
      answer, My Sharing, and a confirmation dialog. Labels are specific, focus
      order follows reading order, changes are announced once, and focus returns
      after dismissing a sheet or dialog.
- [ ] Pause or expire a manual update. Another account sees “No recent update”
      and never sees the old value in Today, Compass, search, or a notification.
- [ ] Review device logs for uncaught exceptions, watchdog exits, sensitive
      values, raw message text, phone numbers, tokens, and provider prompts.

## Physical Android pass

Run on at least one named Android phone that is not an emulator.

- [ ] Clean install, first launch, onboarding, relaunch, and sign-out complete
      without a crash or stale account data.
- [ ] Android system Back moves through onboarding and nested plan views without
      losing input. Back from a changed draft asks before discarding it.
- [ ] Deny notifications and any optional permission. The app explains the
      limitation and keeps unrelated features working.
- [ ] Complete create/join, Chat, poll, confirmation, contribution, sharing, and
      Compass tasks with a second physical device. Each change appears once.
- [ ] Repeat the offline queue and exact deep-link checks from the iPhone pass.
- [ ] Switch English and Arabic, light and dark appearance, portrait and
      landscape, display size, and 200 percent font size. No core action clips or
      falls below a 48 by 48 logical-pixel target.
- [ ] With TalkBack, traverse the same six areas as VoiceOver. Navigation tabs
      announce label, position, and selected state; evidence announces source,
      freshness, audience, and uncertainty without duplicate noise.
- [ ] Background and resume the app during a draft, after a queued write, and
      while Compass is loading. State and recovery remain truthful.
- [ ] Pause or expire a manual update and repeat the no-stale-data check.
- [ ] Review `adb logcat` for crashes, ANRs, strict-mode failures, sensitive
      values, raw message text, phone numbers, tokens, and provider prompts.

## Cross-device functional matrix

Run each row with one iPhone and one Android phone, then reverse the initiating
platform.

| Scenario | Expected result | Pass |
|---|---|---|
| Create family, invite, accept | Both accounts see the same membership once | [ ] |
| Decline invitation | Declined account receives no family data | [ ] |
| Revoke or expire invitation | Old link/code cannot create membership | [ ] |
| Leave or remove member | Access stops immediately on every device and cached private data is cleared | [ ] |
| Send Chat text twice with the same idempotency key | One message appears | [ ] |
| Send while offline, restart, reconnect | One queued message appears with visible pending/failed/sent states | [ ] |
| Two people answer the same poll near-simultaneously | Both valid replies persist; version conflicts recover without silent overwrite | [ ] |
| Confirm a plan while another device has stale state | Stale client refreshes and cannot overwrite the confirmed version | [ ] |
| Send the allowed nudge twice | Only one nudge is sent and the second control is disabled | [ ] |
| Deny notifications, then confirm a plan | Plan confirms; notification limitation is separate and visible | [ ] |
| Tap Chat, poll, and plan notifications | Each opens its exact artifact in the correct family | [ ] |
| Share with selected people | Only named recipients receive and can query the update | [ ] |
| Pause, correct, shorten, and expire sharing | Every device reflects the new audience/value/expiry without stale disclosure | [ ] |
| Ask Compass with permitted fresh data | Answer shows correct source, freshness, audience, and uncertainty | [ ] |
| Ask from a non-recipient or after expiry | Compass abstains; denied fact is absent from provider request logs | [ ] |
| Provider timeout, 429, 503, and malformed output | Honest retry state; Chat, plans, and sharing remain usable | [ ] |

Any unauthorized disclosure, duplicate consequential write, silent data loss,
or AI claim without a permitted source is a stop-ship failure.

## Three-family usability study

Recruit 8 to 12 adults across at least three real families. Include at least one
Arabic-primary participant, one participant who regularly uses larger text, and
a mix of iPhone and Android users. Do not recruit minors for this version.

### Session structure

1. Give the product promise and privacy statement without explaining the UI.
2. Ask the family to complete the tasks below using fictional content.
3. Observe silently until a participant is blocked for two minutes or asks for
   help. Record the help, not private screen content.
4. Interview each participant individually about privacy and pressure before a
   group discussion can influence answers.
5. Delete the test family or begin the separately consented field period.

### Unmoderated task prompts

- [ ] “Invite the other adults and make sure everyone joined the same family.”
- [ ] “Turn a dinner idea from Chat into a poll, answer from each phone, and
      agree on a time.”
- [ ] “Send one reminder without repeatedly pressuring the person who has not
      answered.”
- [ ] “Confirm the plan and volunteer to bring one item.”
- [ ] “Share a fictional ETA with only one named relative for 30 minutes, then
      pause it.”
- [ ] “From the allowed account, ask Compass about the update. From the other
      account, ask the same question.”
- [ ] “Find who can see the update, when it expires, and how to correct it.”
- [ ] “Turn off the network, write one message, reopen the app, and reconnect.”
- [ ] “Change one phone to Arabic and large text, then find and answer the poll.”

### Individual interview questions

- What do you think Family Compass knows about each person right now?
- Which information was private, family-visible, or visible only to selected
  people? Show where the app told you.
- Did any screen imply that hidden location information existed?
- Who wrote each Compass answer? Could Compass send or change something for
  another person without confirmation?
- Did the poll, reminder, or nudge feel helpful or pressuring? What caused that?
- If an answer was wrong or old, how would you correct it?
- What would stop you from using this with your family for one week?

### Evidence to record

For each task, record completion without help, completion with help, failure,
time to completion, wrong turns, and participant confidence from 1 to 5. Also
record the participant's own explanation of privacy, source, audience, expiry,
and AI confirmation. Use paraphrases and pseudonyms unless a separate research
consent explicitly permits recordings or quotations.

Recommended pilot gate:

- [ ] Every participant can stop their own sharing and identify its audience.
- [ ] Every participant understands that “No recent update” does not imply
      hidden tracking data.
- [ ] Every consequential Compass action requires and is understood to require
      confirmation.
- [ ] At least 80 percent of core tasks finish without facilitator help.
- [ ] No participant experiences an unauthorized disclosure, duplicate action,
      silent data loss, or unrecoverable navigation block.
- [ ] No open severity-0 or severity-1 defect remains.

The percentage is a proposed product gate, not evidence of current usability.
Report the exact numerator and denominator because this is a small sample.

## Field period and report

If moderated sessions pass, run a separately consented seven-day field period.
Ask each family to create one real but non-sensitive gathering, use one poll,
and review one sharing control. Do not ask them to manufacture message volume.

The final report must include:

- Build and device matrix
- Participant and family counts without identifying details
- Task results with exact numerators and denominators
- Accessibility findings from VoiceOver and TalkBack
- Privacy and pressure misunderstandings, including contrary evidence
- Crash, ANR, offline, notification, and provider-failure results
- Stop-ship defects and owners
- Decisions to keep, change, remove, or defer
- Data deletion confirmation

Do not mark the Prototype 3 pilot complete from automated tests, simulators, or
one family's feedback alone.

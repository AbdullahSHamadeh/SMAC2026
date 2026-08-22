---
name: Family Compass
description: A warm, native family organizer built around the next shared moment.
colors:
  light-background: "#FFF8F2"
  light-surface: "#FFFFFF"
  light-surface-raised: "#F7ECE7"
  light-surface-high: "#F0E1DB"
  light-surface-highest: "#E8D7CF"
  light-primary: "#9C3F4B"
  light-on-primary: "#FFFFFF"
  light-primary-container: "#F7DDE0"
  light-on-primary-container: "#56202A"
  light-gathering: "#F4B65E"
  light-on-gathering: "#402B0D"
  light-gathering-ink: "#70430D"
  light-gathering-container: "#F9D9A4"
  light-on-gathering-container: "#402B0D"
  light-text: "#352925"
  light-secondary-text: "#74635D"
  light-outline: "#947E74"
  light-outline-variant: "#E9DED7"
  light-success: "#2F6D5E"
  light-on-success: "#FFFFFF"
  light-success-container: "#DDECE5"
  light-on-success-container: "#245447"
  light-warning: "#82530D"
  light-on-warning: "#FFFFFF"
  light-warning-container: "#F6E3BF"
  light-on-warning-container: "#573500"
  light-error: "#9B3A3A"
  light-on-error: "#FFFFFF"
  light-error-container: "#F7DDDA"
  light-on-error-container: "#5A1F1F"
  light-inverse-surface: "#4B3933"
  light-on-inverse-surface: "#FFF4ED"
  dark-background: "#211A18"
  dark-surface: "#2C2320"
  dark-surface-raised: "#3A2E2A"
  dark-surface-high: "#463732"
  dark-surface-highest: "#52413B"
  dark-primary: "#F29AA4"
  dark-on-primary: "#3D171D"
  dark-primary-container: "#6B2934"
  dark-on-primary-container: "#FFE8EB"
  dark-gathering: "#F2C274"
  dark-on-gathering: "#301F09"
  dark-gathering-ink: "#F2C274"
  dark-gathering-container: "#604A25"
  dark-on-gathering-container: "#FFEDCC"
  dark-text: "#FFF4ED"
  dark-secondary-text: "#CDBAB0"
  dark-outline: "#6E5B54"
  dark-outline-variant: "#51423D"
  dark-success: "#93CDBA"
  dark-on-success: "#153A30"
  dark-success-container: "#294A41"
  dark-on-success-container: "#D9F4EA"
  dark-warning: "#F2C274"
  dark-on-warning: "#301F09"
  dark-warning-container: "#604A25"
  dark-on-warning-container: "#FFEDCC"
  dark-error: "#FFB4AC"
  dark-on-error: "#5A1919"
  dark-error-container: "#7A2E2E"
  dark-on-error-container: "#FFDAD6"
  dark-inverse-surface: "#FFEDE5"
  dark-on-inverse-surface: "#3A2A26"
typography:
  display:
    fontFamily: "native system UI with native Arabic fallback"
    fontSize: "34px"
    fontWeight: 700
    lineHeight: 1.12
    letterSpacing: "-0.4px"
  headline:
    fontFamily: "native system UI with native Arabic fallback"
    fontSize: "28px"
    fontWeight: 700
    lineHeight: 1.21
  title:
    fontFamily: "native system UI with native Arabic fallback"
    fontSize: "21px"
    fontWeight: 700
    lineHeight: 1.3
  body:
    fontFamily: "native system UI with native Arabic fallback"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.42
  label:
    fontFamily: "native system UI with native Arabic fallback"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.43
rounded:
  small: "8px"
  medium: "14px"
  large: "18px"
  bottom-sheet: "24px 24px 0 0"
  pill: "999px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "24px"
  xl: "32px"
  xxl: "48px"
  xxxl: "64px"
components:
  button-primary:
    backgroundColor: "{colors.light-primary}"
    textColor: "{colors.light-on-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.medium}"
    padding: "12px 24px"
    height: "48px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.light-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.medium}"
    padding: "12px 24px"
    height: "48px"
  button-text:
    backgroundColor: "transparent"
    textColor: "{colors.light-primary}"
    typography: "{typography.label}"
    rounded: "{rounded.small}"
    padding: "12px 16px"
    height: "48px"
  needs-you-strip:
    backgroundColor: "{colors.light-primary-container}"
    textColor: "{colors.light-on-primary-container}"
    rounded: "{rounded.medium}"
    padding: "12px 16px"
    height: "72px"
  gathering-sheet:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text}"
    rounded: "{rounded.large}"
    padding: "0"
  compass-notice:
    backgroundColor: "{colors.light-success-container}"
    textColor: "{colors.light-on-success-container}"
    rounded: "{rounded.medium}"
    padding: "16px"
  grouped-row-surface:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text}"
    rounded: "{rounded.medium}"
  text-field:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text}"
    rounded: "{rounded.medium}"
    padding: "16px"
    height: "48px"
  choice-chip:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-text}"
    typography: "{typography.label}"
    rounded: "{rounded.pill}"
    height: "48px"
  member-mark:
    backgroundColor: "{colors.light-primary-container}"
    textColor: "{colors.light-text}"
    rounded: "{rounded.pill}"
    size: "40px"
  navigation-shell:
    backgroundColor: "{colors.light-surface}"
    textColor: "{colors.light-primary}"
    height: "64px"
---

# Design System: Family Compass

## Overview

**Creative North Star: "Sunday Table"**

Family Compass should feel caring, familiar, sunny, calm, and mature. The app is a native family organizer, not a dashboard. It puts the next shared moment and the people involved ahead of product phases, system language, and reassurance mechanics. Warm milk canvas, pomegranate actions, apricot gathering fields, and eucalyptus reassurance give the product a domestic character without using sentimental decoration.

The approved Today composition at `.impeccable/mocks/sunday-table-today-02-approved.png` sets the hierarchy, warmth, and rhythm. It is not an asset sheet. The Flutter implementation does not literalize its generated faces, heart badge, long ribbon flourish, fixed copy heights, or English-only type. Current identity widgets render truthful initials. Member-provided photos remain a future content capability.

Today uses one conditional request, one split gathering sheet, up to two family updates, and at most one Compass observation. Together shows one plan once, under the one populated group that describes its current human state. Routine information stays in rows and the content flow. The visible plan thread is reserved for step progress inside plan details.

**Key Characteristics:**

- Warm native surfaces with pomegranate, apricot, and eucalyptus role ownership
- One split gathering sheet as the signature Today component
- Initial-based family identity stacks with no synthetic people
- Flat routine rows, quiet dividers, and tonal depth instead of card stacks
- One plan in one human-readable Together group
- Four stable destinations with a bottom bar or navigation rail
- Directional English and Arabic layouts that reflow for large text

## Colors

The Sunday Table palette comes from a familiar domestic setting, not a claim that one hue universally means family.

### Primary

- **Pomegranate** (`#9C3F4B` light, `#F29AA4` dark) owns selected navigation, default filled actions, focus, and interactive emphasis.
- **Blush** (`#F7DDE0` light, `#6B2934` dark) carries the conditional Needs you strip and other quiet primary containers.

### Secondary

- **Apricot** (`#F4B65E` light, `#F2C274` dark) belongs to the date field and bounded gathering emphasis. Use dark cocoa on the fill.
- **Soft apricot** (`#F9D9A4` light, `#604A25` dark) is the quieter date band used by Together plan surfaces.
- **Apricot ink** (`#70430D` light, `#F2C274` dark) is the accessible gathering foreground for borders, markers, and text on neutral surfaces.

### Tertiary

- **Eucalyptus** (`#2F6D5E` light, `#93CDBA` dark) identifies sharing, consent, reassurance, and successful states.
- **Sage** (`#DDECE5` light, `#294A41` dark) supports the Compass noticed treatment and positive status containers.

### Neutral

- **Warm milk** (`#FFF8F2`) and **night cocoa** (`#211A18`) are the page canvases.
- **White** (`#FFFFFF`) and **dark cocoa surface** (`#2C2320`) are the main content surfaces.
- **Cocoa** (`#352925`) and **warm white** (`#FFF4ED`) are the main text colors.
- **Muted cocoa** (`#74635D`) and **muted warm white** (`#CDBAB0`) are supporting text.
- **Warm divider** (`#E9DED7` light, `#51423D` dark) separates routine rows without turning each row into a card.

### Named Rules

**The Color Ownership Rule.** Pomegranate means action and selection. Apricot means gathering. Eucalyptus means consent, reassurance, and success. Do not spend all three colors on decoration.

**The Gathering Ink Rule.** Use apricot ink for small gathering text, icons, and borders on neutral surfaces. Do not use the lighter apricot fill as foreground ink.

**The One Product Palette Rule.** Compass uses eucalyptus and the normal product palette. It does not receive purple gradients, sparkles, glows, or a separate AI identity.

Every semantic color appears with a word or recognizable symbol. Color never carries plan phase, privacy, freshness, warning, or error alone.

## Typography

**Display Font:** Native system UI with native Arabic fallback

**Body Font:** Native system UI with native Arabic fallback

**Label Font:** Native system UI with native Arabic fallback

The platform face keeps body text, controls, Arabic shaping, and text scaling familiar. Warmth comes from content, color, and composition rather than a novelty display face.

### Hierarchy

- **Display Large** (700, 34, 1.12): Rare display moments. It grows to 36 at medium width and 40 at expanded width.
- **Headline Large** (700, 28, 1.21): Top-level destination titles. It grows to 30 and then 32 with width.
- **Headline Medium** (700, 24, 1.25): Major content headings. It grows to 26 and then 28 with width.
- **Title Large** (700, 21, 1.30): Gathering titles, plan sections, and detail headings.
- **Title Medium** (600, 16, 1.45): Row titles and compact section emphasis.
- **Body Large** (400, 17, 1.42): Primary reading text and familiar native controls.
- **Body Medium** (400, 15, 1.42): Supporting descriptions and metadata.
- **Body Small** (400, 13, 1.38): Freshness, timestamps, and secondary facts.
- **Label Large** (600, 14, 1.43): Actions, states, and date labels.
- **Label Medium** (600, 12, 1.33): Navigation labels and compact metadata.

The current Flutter ramp applies slight negative tracking only to `displayLarge` and `displayMedium`. Feature code must not add Latin letter spacing to Arabic. A localized type override should clear display tracking where the platform does not do so automatically.

**The Reflow Before Truncation Rule.** Stack metadata and actions before clipping a person, plan, place, privacy state, source, or error. The top-level destination title may ellipsize only when the destination remains clear from selected navigation and semantics.

## Layout

The shell uses one destination title in a flat app bar with a trailing profile mark. The toolbar is 58 logical pixels tall, or 52 in compact height. Widths below 600 use a 64 pixel bottom navigation bar. Wider windows use an 80 pixel navigation rail, except that compact-height windows keep the bottom bar. Today, Chat, Compass, and Together are the only primary destinations.

The spatial system uses a 4 pixel base and the 4, 8, 12, 16, 24, 32, 48, and 64 scale. Page gutters are 16 below 600, 24 from 600 to 839, and 32 at 840 and above. General page content stops at 1200 logical pixels.

Today stops at 1120 and changes to two task columns at 680 content width. The action and gathering stay together in the leading column. Family updates and Compass occupy the supporting column. On smaller widths they return to one reading order. The gathering sheet uses a vertical date panel when it has at least 340 pixels and text scale is no greater than 1.35. Otherwise the date becomes a horizontal band above the details.

Together overview stays a single collection no wider than 720. It renders only the populated group: Needs you, Waiting for family, Coming up, Ideas to revisit, or Past moments. A plan appears exactly once. Builder, poll, and confirmed details split at 760, or at 680 in compact height. The plan builder places its step rail beside the task. Poll and confirmed views place the active task before supporting replies or coordination.

All padding, alignment, dividers, step rails, identity stacks, and chevrons use directional APIs so Arabic mirrors correctly. Safe areas protect cutouts, system bars, and landscape edges. Rotation preserves the selected destination, builder step, drafts, and queued actions.

## Elevation & Depth

Sunday Table is flat at rest. App bars, navigation, cards, and reusable folio surfaces use zero elevation and no surface tint. Depth comes from warm tonal changes, clipping, one pixel dividers, and occasional outlines. A Today gathering sheet normally has no border. A Together plan folio uses the warm divider, with a restrained apricot-ink border when emphasized. Dialogs, sheets, menus, and floating feedback keep the platform's temporary overlay treatment.

### Motion

Today and Together currently rely on native ink response, route behavior, and immediate responsive recomposition. The approved brief's roughly 240 millisecond gathering-sheet expansion is not implemented. Existing application motion uses 200 millisecond state changes and 220 millisecond `easeOutCubic` answer or message reveals. Any future gathering transition must become a fade or immediate state change when the platform requests reduced motion.

**The Tonal Depth Rule.** Do not add shadows to routine rows, identity marks, message bubbles, evidence lines, or every gathering surface. Use a tonal change or divider first.

## Shapes

The radius scale assigns one job to each silhouette:

- **8 pixels:** Text buttons and compact controls
- **14 pixels:** Filled and outlined buttons, fields, grouped row surfaces, notices, dialogs, and snackbars
- **18 pixels:** Gathering sheets, plan folios, poll surfaces, and other major bounded planning artifacts
- **24 pixel top corners:** Modal bottom sheets
- **Full circle or stadium:** Member marks, identity stacks, and choice chips

Buttons are rounded rectangles, not universal capsules. Major planning surfaces clip their date field and body into one 18 pixel silhouette. Routine rows are grouped with dividers and do not receive individual rounded containers. Borders separate similar tones or communicate bounded planning context, not decoration.

## Components

### App Shell and Navigation

Use one app bar title and one trailing profile mark. On iPhone, compact and compact-height windows use a native `CupertinoTabBar` with the four destinations, filled selected glyphs, and pomegranate tint. Android uses the Material navigation bar and larger windows use the Material navigation rail. There is no selection pill on iPhone and no custom-drawn tab indicator. The current implementation uses one semantic `FamilyCompassIcons` mapping built from Cupertino icons so feature code never chooses a competing icon family.

### Family Identity

Initials remain the truthful fallback until a member deliberately adds a photo. A stable color chosen from blush, sage, apricot, and warm cocoa distinguishes family members instead of rendering everyone as the same account badge. The family screen begins with one warm family field that shows the family name and overlapping member marks. It then uses an inset grouped list for people and invitations. Human labels use `Family`, `People`, and `Your settings` rather than administrative account language.

### Buttons

The default filled and outlined buttons are 48 pixels high with 14 pixel corners and 12 by 24 padding. Text buttons use an 8 pixel radius and a 48 pixel minimum. New primary actions use pomegranate. Outlined and text treatments carry secondary actions.

The current Together builder Next and Send poll buttons, plus the completed Plan this again button, explicitly use apricot with dark cocoa. Treat these as bounded gathering-flow exceptions. Do not turn apricot into the default action color or introduce more exceptions without updating the theme and this contract together.

### Incoming Invitation Chooser

Firebase join onboarding adds a fifth, single-decision step after the verified account has been registered. It lists every pending invitation returned for that verified phone. Each 18 pixel folio shows the family name, the inviter name only when the server safely supplies it, a last-four phone mask, the role, and a localized expiry. The full invited phone never appears in client state or copy.

Accept is the filled action and Decline is outlined. Both remain at least 48 pixels high and stack for narrow widths or large text. No invitation is accepted because it is the only match, and multiple matches remain independent. A private-match notice explains recipient scoping. The empty state explains how to get a new invitation and provides a Check again action.

### Needs You Strip

Render the current person's single pending decision before the gathering. The strip uses blush, a pomegranate vote icon, a short title and question, and a Respond label. It is at least 72 pixels high, has 14 pixel corners, and stacks its action under the copy above 150 percent text scale. Do not show the strip when there is no pending action.

### Today Gathering Sheet

This is the signature Sunday Table component. One 18 pixel surface combines a compact apricot date panel with white or dark-surface details. The details show a human state label, the family moment, time, place, a small initial stack, and one trailing outcome label. The whole surface opens the related plan. It has no shadow, inner card, decorative heart, generated face, long ribbon flourish, or dashboard-sized event typography.

At narrow width or large text, the date panel becomes a full-width apricot band with a calendar icon and localized long date. Month and weekday uppercase apply only in non-Arabic locales. Copy and surface height remain content driven.

### Family Identity Stack

`MemberMark` and `FamilyIdentityStack` currently use initials. The stack overlaps 34 pixel circles by 28 percent, shows up to the requested maximum, and ends with a `+N` mark. Blush, sage, soft apricot, and the raised surface rotate through the marks. A 2 pixel surface ring preserves separation. One semantic label describes the group while decorative child text is excluded.

### Routine Family Rows

Family updates use one 14 pixel surface with at most two 72 pixel rows, 40 pixel initial marks, concise copy, freshness, and directional chevrons. Dividers begin after the identity column. Settings, participants, reminders, metadata, and empty states use the shared flat-row grammar. Do not place each row in its own card.

### Compass Notice

Show at most one Compass noticed item after family content. It uses a sage container, deep eucalyptus content, the normal Compass glyph, one grounded observation, and a plain action. It is optional, never impersonates a member, and never outranks a pending family reply or gathering.

### Together Plan Folio

Together overview opens with the family identity stack and the invitation `Find the next time everyone can be together.` It uses one 18 pixel plan surface beneath the single populated human-state group. At normal phone text sizes, a compact apricot date block sits beside the phase, title, detail, members, and trailing action row. At narrow widths or large text, the date becomes a full-width band. The entire folio is the action, so it does not contain a second full-width task button. The default outline is the warm divider. Opportunity and confirmed items may use a low-alpha apricot-ink outline. Internal phase history appears only after opening the plan.

### Plan Progress and Choices

Large builder layouts use a directional vertical step thread. Completed segments are solid, future segments are dotted, and every marker has a text label and semantic stage state. Compact layouts replace the thread with four flat progress segments plus a Step N of 4 label. Poll choices use native choice chips with a 48 pixel minimum and wrap rather than compress.

### Fields, Sheets, and Feedback

Fields use a filled surface, 14 pixel radius, 16 pixel padding, a one pixel outline, and a two pixel pomegranate focus border. Bottom sheets use 24 pixel top corners and a drag handle. Dialogs and snackbars use 14 pixel corners. Error, warning, success, stale, and offline feedback always includes direct recovery copy and a non-color cue.

## Do's and Don'ts

### Do:

- **Do** lead Today with one current-person action, one next family moment, up to two family updates, and at most one Compass observation.
- **Do** show each Together plan once under the one populated human-state group.
- **Do** use pomegranate for action, apricot for gathering, and eucalyptus for consent or reassurance.
- **Do** keep routine information in flat rows, bubbles, or the content flow.
- **Do** show source, freshness, audience, expiry, uncertainty, and confirmation beside the fact or action they qualify.
- **Do** test English, Arabic RTL, light, dark, portrait, short landscape, 200 percent text, screen-reader order, and non-color status cues.
- **Do** preserve native safe areas, keyboard behavior, Android system Back, iOS edge-swipe Back, and platform motion settings.
- **Do** use at least 48 by 48 logical pixels for shared touch targets on both platforms.

### Don't:

- **Don't** build screens from interchangeable rounded cards or place a card inside another card.
- **Don't** reconnect unrelated Today content with a lifecycle thread.
- **Don't** expose internal phases before the family moment or duplicate one plan across Together groups or panes.
- **Don't** use generated people, stock-family photography, corporate figures, or member photos without family choice.
- **Don't** add purple AI styling, sparkles, robot faces, decorative gradients, or glows.
- **Don't** add a permanent map, Journey destination, continuous location, battery monitoring, care score, leaderboard, or adult privacy override.
- **Don't** hardcode left-to-right geometry, fixed-height copy, Latin tracking in Arabic, color-only meaning, or clipped recovery actions.

## Slop Audit

- **2026-08-13:** Native family refinement passed the focused audit. iPhone now uses a real Cupertino tab bar, Android retains Material navigation behavior, family members have stable distinct monograms, and the family screen uses a warm identity field plus inset grouped rows. Today and Together reduce dashboard scale and task-card cues. Together plan folios are single tappable family invitations with people and a trailing action instead of nested full-width buttons. Arabic, RTL, dark mode, 200 percent text, and 48 pixel shared targets remain covered.
- **2026-08-13:** Invitation chooser passed the focused audit. It reuses the Sunday Table type, palette, spacing, directional layout, native icons, defined-edge surfaces, and button hierarchy. It adds no gradients, shadows, nested cards, decorative imagery, or color-only meaning. Invitation actions have native focus and disabled states, 48 pixel targets, large-text stacking, explicit error recovery, and a privacy explanation.

## Changelog

- **2026-08-13:** Refined Sunday Table toward a personal native family app. Added platform-adaptive tab bars, stable member color identities, a family-home header, grouped people rows, quieter Today event scale, a family-led Together introduction, and compact single-action invitation folios.
- **2026-08-13:** Added the explicit multi-invitation Firebase onboarding contract. The chooser shows privacy-safe identity and expiry details and requires a separate Accept or Decline action for every invitation.

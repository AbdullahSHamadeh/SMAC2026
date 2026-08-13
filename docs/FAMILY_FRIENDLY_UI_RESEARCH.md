# Family-friendly UI research

Date: 2026-08-13

## Decision

Version 1 uses the **Sunday Table** direction. The app should feel caring, familiar, sunny, calm, and mature. Opening Today should feel like seeing what the family is doing next, not opening a family operations dashboard.

The signature component is a **gathering sheet**: one warm date field, the shared moment, essential time and place, and a small stack of family identities. It appears once for the active gathering. Routine updates remain simple rows.

The selected composition probe is `.impeccable/mocks/sunday-table-today-02-approved.png`. It is a north star for hierarchy, warmth, and rhythm. Generated faces are not product assets. The implementation uses member-provided photos when available and initials otherwise.

## Findings from the current app

- Today visually connected a gathering, a shared status, and a Compass suggestion as if they were steps in one process. They are different information types, so the thread made the screen harder to scan.
- Today exposed system language such as “From family chat” and phase mechanics before the family moment itself.
- Together forced every plan through permanent Next, Decide, and Later stages, including empty sections. On larger screens the same plan appeared twice.
- Dark green owned navigation, actions, labels, statuses, and member marks. The result felt institutional even though the content was about family.

## Product references

- [Apple Invites](https://www.apple.com/newsroom/2025/02/introducing-apple-invites-a-new-app-that-brings-people-together/) makes the occasion, essential facts, RSVP, and people the visual subject. Family Compass should similarly lead with the gathering rather than its internal phase.
- [FamilyAlbum](https://family-album.com/) lets family-owned media lead while keeping chrome quiet. Optional member-provided imagery can personalize confirmed gatherings and past moments.
- [TimeTree](https://timetreeapp.com/) keeps calendar, conversation, reminders, and shared material attached to the same group or event. Family Compass should show one plan object in different contexts without duplicating its controls.
- [OurCal](https://ourcal.com/) uses familiar calendar and conversation patterns with plain privacy language. Family Compass should explain consent in ordinary words rather than security-themed decoration.
- [Partiful](https://partiful.com/) presents an event as a social occasion. Family Compass can borrow that sense of occasion without adopting party effects or social-network behavior.
- Apple’s [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines), [layout guidance](https://developer.apple.com/design/human-interface-guidelines/layout), [color guidance](https://developer.apple.com/design/human-interface-guidelines/color), and [typography guidance](https://developer.apple.com/design/human-interface-guidelines/typography) support clear hierarchy, adaptive layout, role-based color, Dynamic Type, and legible native controls.

There is no universal “family color.” The palette is based on a familiar Sunday-table setting and product roles, not a claim that one hue means love in every culture. All text combinations below are checked against the [WCAG 2.2 minimum contrast criterion](https://www.w3.org/TR/WCAG22/#contrast-minimum).

## Palette

### Light

| Role | Value | Foreground | Contrast |
| --- | --- | --- | --- |
| Canvas | `#FFF8F2` | Cocoa `#352925` | 13.35:1 |
| Canvas secondary text | `#FFF8F2` | Muted cocoa `#74635D` | 5.42:1 |
| Primary action | `#9C3F4B` | White | 6.51:1 |
| Blush container | `#F7DDE0` | Cocoa `#352925` | 10.95:1 |
| Consent and reassurance | `#2F6D5E` | White | 6.05:1 |
| Sage container | `#DDECE5` | Deep eucalyptus `#245447` | 7.07:1 |
| Gathering field | `#F4B65E` | Dark cocoa `#402B0D` | 7.45:1 |
| Divider | `#E9DED7` | n/a | n/a |

### Dark

| Role | Value | Foreground | Contrast |
| --- | --- | --- | --- |
| Canvas | `#211A18` | Warm white `#FFF4ED` | 15.84:1 |
| Canvas secondary text | `#211A18` | Muted warm white `#CDBAB0` | 9.18:1 |
| Primary action | `#F29AA4` | Deep berry `#3D171D` | 7.42:1 |
| Consent and reassurance | `#211A18` | Mint `#93CDBA` | 9.53:1 |
| Gathering field | `#F2C274` | Dark cocoa `#301F09` | 9.61:1 |

Pomegranate owns primary actions and selected navigation. Eucalyptus identifies sharing, consent, and reassurance. Apricot belongs to gatherings. A word or symbol always accompanies semantic color.

## Information architecture

### Today

1. **Needs you**, only when one current-person action is pending.
2. **Next family moment**, one gathering sheet with human facts before phase mechanics.
3. **From your family**, no more than two concise updates.
4. **Compass noticed**, no more than one dismissible suggestion after family content.

Empty sections are hidden. Source, freshness, audience, and internal phase details remain available from the related detail view.

### Together

Together shows a single vertical collection and only populated groups:

1. **Needs you**
2. **Waiting for family**
3. **Coming up**
4. **Ideas to revisit**
5. **Past moments**

A plan appears exactly once. Each item states the moment, a human status, known time and place, participants, and one next action. The full history appears only after opening the plan.

## Imagery, type, and motion

- Use member-provided photos only when the family chooses them. Otherwise use initials or a finite set of authored domestic still-life covers.
- Do not use generated human faces, stock-family photography, corporate flat figures, purple AI effects, or decorative gradients.
- Keep the platform typeface for body and controls so Arabic, Dynamic Type, and platform behavior remain reliable. Warmth comes from content, hierarchy, color, and the gathering sheet rather than a novelty font.
- Use one consistent Cupertino-style icon vocabulary. Outline at rest, fill only for selected or confirmed states.
- The one expressive motion is the gathering sheet opening into its detail view in roughly 240 milliseconds. Reduced-motion users receive a simple state change or fade.

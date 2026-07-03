# Design language: “Illuminated”

The app's visual voice, so future changes stay coherent. The goal is a quiet,
premium feel — closer to a well-set book than to a productivity dashboard —
with restrained moments of delight where they mean something.

## Intent

Scripture memory apps tend toward either sterile utility or kitsch. This app
already leans on a parchment flashcard and serif verse type; the design
language leans into that and names it: **illuminated manuscripts** — ink,
parchment, lapis and gold leaf. Everything below serves three rules:

1. **Ink and parchment carry the app.** Neutral surfaces, warm cards, serif
   verse type. Color is scarce so that when it appears, it reads as meaning.
2. **Lapis is the working accent; gold is earned.** Lapis (the deep blue of
   manuscript initials) replaces system blue for all interactive tint. Gold
   appears only for streaks and celebration — it marks *achievement*, never
   navigation. If gold shows up on an idle screen, something is wrong.
3. **Motion is soft and physical.** Springs over curves, small scales over
   slides, one shared press behavior. Shader effects are reserved for the two
   or three moments a day worth savoring — never ambient decoration on every
   screen.

## Palette (`Design/Theme.swift`)

All colors are dynamic (light / dark pairs). Never use raw `.red` / `.green` /
`.blue` / `.orange` in views; use the semantic names.

| Token             | Role                                            | Light     | Dark      |
|-------------------|--------------------------------------------------|-----------|-----------|
| Accent (asset)    | All interactive tint (buttons, links, toggles)   | `#38529E` | `#7A96EB` |
| `Theme.gold`      | Streaks, celebration, “gold leaf” moments        | `#A8802A` | `#E2C363` |
| `Theme.flame`     | Streak flame gradient top                        | `#D97A2E` | `#EDA050` |
| `Theme.success`   | Correct words, completion, Good grade            | `#2F8F5A` | `#57C88C` |
| `Theme.error`     | Wrong words, Again grade, destructive            | `#C4453A` | `#EB7264` |
| `Theme.warning`   | Hard grade, caution                              | `#B57A1E` | `#E8A842` |
| parchment         | Flashcard surface (gradient, see below)          | warm cream| warm gray |

Grade mapping: Again → error, Hard → warning, Good → success, Easy → accent.

## Surfaces

- **Parchment cards** (`Theme.ParchmentCard`): a faint warm vertical gradient
  (light falls from the top), a Metal paper-grain layer, a hairline warm
  border, and two layered shadows (tight contact + soft ambient). Used by
  every flashcard and the Home “Continue Learning” card.
- Grouped panels keep system `secondarySystemGroupedBackground` — they are
  chrome, not content, and should recede behind the parchment.

## Shader effects (`Design/Effects.metal` + `ShaderEffects.swift`)

iOS 17 SwiftUI `colorEffect` shaders. Two, used sparingly:

- **`paperGrain`** — two-scale value noise, ±2–4 % luminance. Always on
  flashcards; it is texture, not decoration, and should be *felt* rather than
  seen. Strength drops in dark mode.
- **`giltSheen`** — a soft diagonal gold sheen sweeping every few seconds.
  Only on: the streak flame while a streak is alive, and the session-complete
  seal. Driven by `TimelineView(.animation)`, so keep the affected views small.

## Celebration (`Design/GoldLeafBurst.swift`)

Finishing a review session bursts **gold-leaf flakes** (gold, lapis and cream
slivers) from behind the completion seal — a one-shot `Canvas` +
`TimelineView` particle system, seeded deterministically, ~2.5 s, then inert.
It fires when the summary appears and never repeats within the same summary.

## Motion

- One shared press behavior: `Theme.SpringyButtonStyle` (scale 0.96, spring
  response 0.3 / damping 0.65) for primary buttons; `CardButtonStyle` (0.97)
  stays for large cards.
- Primary actions use the accent **gradient** capsule (`Theme.accentGradient`)
  rather than flat fills.
- Existing physics (card swipe, shake-on-miss, numeric text transitions) are
  part of the language — keep their timings.

## Type

- Verse content: system serif (New York), as before.
- Chrome and numbers: SF / SF Rounded. Big counts use `.rounded` + bold.
- No custom fonts; the contrast between serif content and sans chrome *is*
  the typography system.

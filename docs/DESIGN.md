# Design direction: “The Printed Pack”

The app's cards mirror a real printed memory-verse pack (the physical TMS
cards) — so the design goal is not a new look for the card face, it's making
the cards **behave** like the printed cards they copy. Every signature
interaction should answer: *what would this feel like with the real pack in
your hands?*

## Principles

1. **The card is an object, not a screen.** It has two sides, weight, and
   momentum. Interactions move the card; they don't decorate it.
2. **Print fidelity over decoration.** Card stock texture, series color
   coding, honest layout. No ornament that a printing press wouldn't produce.
3. **Physics carries the delight.** Springs, lift, spin, and haptics tuned to
   what the gesture "weighs". One effect per moment; nothing ambient.

## The Table (app shell)

Every screen lives on one continuous surface — a warm desk mat
(`DeskSurface`, same grain shader as the cards, putty in light / charcoal
felt in dark). Chrome is stationery on that desk:

- **Navigation** is a row of index-card **divider tabs** (`DividerTabBar`) —
  the selected divider pulls up and forward in parchment; the others sit back
  in the box. Custom shell in `ContentView` (all four stacks stay mounted, so
  per-tab state survives like `TabView`).
- **Home is the desk mat**: today's review is a **banded stack**
  (`TodayStack`) whose physical thickness is the workload — the stack itself
  is the start button, with a rubber band drawn off-centre so it never covers
  the count. The streak is a **weekly stamp card**: one gold ink stamp per
  studied day, each landing slightly askew, today a dashed open slot.
- **Onboarding is the product**: a real card deals in from the corner of the
  desk; the user flips it, then flicks it away — learning the app's two core
  verbs by doing them — before any setup questions.

## The physical vocabulary

| Real-world act | In the app |
|---|---|
| Flip the card to check yourself | **Tap-to-flip** in read mode: verse side ⇄ quiz side (topic + reference). Edge-on turn with lift; content swaps while edge-on so text never mirrors; settles with a spring overshoot. Soft haptic on lift, medium at the turn. |
| Color-coded series packs | Every card prints its pack's **ink band** along the top edge (`ParchmentSurface.edgeColor` from `Pack.color`). |
| Card stock | `paperGrain` Metal shader on every card — felt, not seen. |
| Toss a graded card onto a pile | **Toss-to-grade** in review: Again drops heavy and close, Easy sails off fast with spin (`tossCard(for:)` in `TestSessionView`). |
| Rap / reshuffle the deck | **Shake to shuffle** in read mode: device shake deals a fresh order with a deck wobble and double haptic (`ShakeDetector` + `handleShake`). |
| Spread the deck across the desk | **The Spread** (`cardSpread`): turn the phone to landscape in read mode and the deck lies out in a snapping row — the centered card lifts to full face, neighbors settle back small and slightly askew. Deliberately NOT Cover Flow: cards stay flat on the desk, no tilted-album turn. Tap a neighbor to center it; tap the lifted card to flip it. |

## Materials & color

- **Card surface**: `ParchmentSurface` — warm top-lit gradient, paper-grain
  shader, hairline border, contact + ambient shadows, 14pt continuous corners.
- **Accent**: lapis (`#38529E` / `#7A96EB`) via the asset catalog.
- **Semantic tokens** (`Theme.swift`): success emerald, error vermilion,
  warning amber; grades map Again=error, Hard=warning, Good=success,
  Easy=accent. Never raw `.red`/`.green`/`.blue`/`.orange` in views.
- **Gold** (`Theme.gold` + `giltSheen` shader) marks achievement only: the
  live streak flame and the finished-review seal.

## Motion

- Shared press behavior: `Theme.SpringyButtonStyle`; primary actions use
  `ProminentActionButton` (accent gradient).
- Flip: 0.16s ease-in to edge-on → swap → spring settle (0.32 response,
  0.72 damping).
- Toss: per-grade arc/spin/duration — weight differences are the feedback.
- Keep the existing swipe/shake-on-miss timings; they're part of the language.

## Explicitly out

- Confetti/particle celebrations (removed by request).
- Handwriting/ink metaphors — the real cards are printed, not handwritten.
- Ambient animation on idle screens.

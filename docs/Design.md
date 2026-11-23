# Design: After Dark

One window, one decision: a night scene, the game's title and a gold button. Everything else stays
out of the way until it's needed.

## Principles
- **Calm first.** One primary action per screen. A status line appears only when it says something
  the button doesn't. If a detail does not help someone play, it goes.
- **Native controls.** The toolbar picker, sheets, Settings, menus and alerts are the system's own.
  Custom drawing is kept for the scene, the gold button and the edition tabs.
- **One accent.** Candle gold (`Theme.gold`, `Theme.candle`) marks the primary action and the current
  choice. Nothing else is coloured.
- **Type.** Optima for titles and small engraved caps (tracked wide), the system font for everything
  a player reads or clicks.
- **Plain words.** Short sentences, no jargon, no em dashes. Say what to do next.

## The scene (`NightScene`, `Silhouettes`)
Drawn back to front: sky, stars, moon, distant mountains, the castle on its hill, mist, the year's
scene, two ridges. Each layer overlaps the one behind it so nothing floats, and the ground darkens
toward the lower left so the title always reads.

| Year | Palette | Moon | Story |
| --- | --- | --- | --- |
| I | warm plum | crescent | a steam train crossing a viaduct toward the castle |
| II | deep teal | half | a flying car diving at a great gnarled willow |
| III | cold indigo | full | the castle across a lake, hooded wraiths over the water |

All artwork is original and drawn in code; nothing is traced or copied from the films, books or
games. The brighter stars twinkle slowly and hold still when Reduce Motion is on.

## Layout
- Window 1040 x 660 by default, 960 x 600 minimum. The title block grows up to 1.5x with the window.
- Title block: 72 from the left, 64 from the bottom. Year line, title, optional status, then the
  button and edition tabs on one row.
- Sheets use 32 padding, grouped rows and one default button.

## Checking changes
`TEST_RUNNER_HPL_SNAPSHOTS=<folder> xcodebuild … test -only-testing:HPLauncherTests/SceneSnapshotTests`
writes every scene at three window sizes and each screen with its real controls. `tools/make-icon.sh`
rebuilds the app icon from the same artwork.

# HUD

`src/game/hud.gd`: the on-screen UI, a `CanvasLayer` built in code. It reads `BaseState` for
display and reports presses as signals; it never changes game state. `main.gd` wires the
signals to `PlacementController` (`input-camera.md`).

## The touch rule

`WorldInput` uses `_unhandled_input`, so any `Control` that is not `MOUSE_FILTER_IGNORE`
swallows every touch over it and the world underneath stops responding. Layout-only containers
that span empty screen space — the full-rect root, the top bar's `HBoxContainer`, the place
bar's row — are set to `MOUSE_FILTER_IGNORE`. Panels and buttons keep the default and block,
which is what they should do. A new container must be IGNORE unless it is meant to block.

## Layout

`setup(catalog)` builds, under a full-rect root `Control` carrying the theme:

| Part | Where | Contents |
| --- | --- | --- |
| Top bar | top-left, `MARGIN` (16) in | One panel label per resource in catalog order, coloured per `RESOURCE_COLORS` (`"Metal  750 / 1,000   +1,800/h"`, the rate only when above 0), then `"Drones  free / total"` in the accent colour. |
| Build bar | bottom, full width | A `PanelContainer` with a horizontal `ScrollContainer` of one 180×84 button per `catalog.menu_order` type: the display name and, on a second line, the level 1 cost or why it cannot be built. |
| Place bar | bottom centre | `Cancel` and `Place` (170×72); `Place` is disabled unless the ghost is valid. |
| Info panel | bottom centre, 460 wide | Title `"Name   Lv N"` with a `Close` button; detail lines; the upgrade button; a note under it. |
| Toast | top centre, 96 down | A centred outlined label that fades out after 1.8 s over 0.6 s. |
| Reset base | top-right, debug builds only | `OS.is_debug_build()`; emits `reset_pressed`. |

Bottom parts are anchored to the bottom edge and grow upward (`_anchor_bottom`). The theme
(`_make_theme`) sets the default font size (20), the panel style and the button styles; the
buttons take no focus.

## Refresh

`refresh(state, selected_id, placing, ghost_ok)` is called by `main.gd` every tick, after
every state change, and on every selection or placement change. It updates the top bar, then
shows exactly one of the three bottom parts:

- **placing** → the place bar;
- **a building selected** (`selected_id` in `state.buildings`) → the info panel;
- **otherwise** → the build bar.

Build buttons: each asks `state.check_can_build(type)`; the second line is the cost, or
"Max built" (`limit_reached`), "No free drone" (`no_free_builder`), "Needs Command Center"
(`needs_command_center_level`); any error disables the button. Pressing emits
`build_pressed(type)`.

Info panel, for the selected building at its current level (level 1's stats while it is still
being constructed): "Produces N Res/h" and "Stores N Res" per resource where above 0, "Houses N
drone" when it supplies builders, "Damage N   Range N" when the level has `damage`, "Hull N"
when it has `hp`, and while busy "Under construction: 10s left" or "Upgrading to Lv N: 1m 00s
left". The upgrade button reads "Under construction" (disabled) while busy, "Max level"
(disabled) at the top level, else "Upgrade to Lv N   cost   (duration)", disabled with the
reason in the note when `state.check_upgrade` fails. Pressing emits `upgrade_pressed`; `Close`
emits `close_pressed`.

## Signals

| Signal | Emitted by | `main.gd` connects it to |
| --- | --- | --- |
| `build_pressed(type)` | a build button | `placement.begin_place` |
| `confirm_pressed` | Place | `placement.confirm_place` |
| `cancel_pressed` | Cancel | `placement.cancel_place` |
| `upgrade_pressed` | the upgrade button | `placement.upgrade_selected` |
| `close_pressed` | Close | `placement.select(0)` |
| `reset_pressed` | Reset base | `main._reset_base` |

## Messages

`show_message(text)` shows the toast; `show_error(code)` shows `error_text(code)`, the
player-facing text for a `BaseState` error code from `ERROR_TEXT`, or the code itself when there
is none:

| Code | Text |
| --- | --- |
| `blocked` | That spot is taken |
| `limit_reached` | You've built the maximum for your Command Center level |
| `needs_command_center_level` | Upgrade your Command Center first |
| `no_free_builder` | All drones are busy |
| `insufficient_resources` | Not enough resources |
| `busy` | Already under construction |
| `max_level` | Already at max level |

`PlacementController.command_failed` is connected to `show_error`; `_reset_base` shows "Base
reset". Amounts, costs and durations are formatted by `Format` (`input-camera.md`).

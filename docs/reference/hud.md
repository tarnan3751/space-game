# HUD

`src/game/hud.gd`: the on-screen UI, a `CanvasLayer` built in code. It reads `BaseState` for
display and reports presses as signals; it never changes game state. `main.gd` wires the
signals to `PlacementController` (`input-camera.md`).

## The touch rule

`WorldInput` uses `_unhandled_input`, so any `Control` that is not `MOUSE_FILTER_IGNORE`
swallows every touch over it and the world underneath stops responding. Layout-only containers
that span empty screen space — the root, the top bar's column and its rows, the place bar's
row — are set to `MOUSE_FILTER_IGNORE`. Panels and buttons keep the default and block, which is what
they should do. A new container must be IGNORE unless it is meant to block.

The build entries are the one exception: they are `MOUSE_FILTER_PASS`, so a drag that starts on
an entry also reaches the `ScrollContainer` and scrolls the strip (with the default `STOP` it
does not). The build bar's `PanelContainer` behind them still stops the touch, so it never
reaches the world. Each entry's content (a `VBoxContainer` of labels) is IGNORE, so the button
itself is what a touch lands on.

## Layout

`setup(catalog)` builds, under a root `Control` carrying the theme and laid out on the safe
area (**Safe area**):

| Part | Where | Contents |
| --- | --- | --- |
| Top bar | top, `MARGIN` (16) in, a column across the width | First row, from the left: one panel label per resource in catalog order (`"Metal  750 / 1,000   +1,800/h"`, the rate only when above 0), named and coloured from the catalog's `resource_name` and `resource_color` (the text colour when a resource has none), then `"Drones  free / total"` in the accent colour. A resource whose `state.capacity(res)` is 0 is hidden, so antimatter appears once something stores it. |
| Build bar | bottom, full width | A `PanelContainer` with a row of category tabs over a horizontal `ScrollContainer` strip of entries (**Build menu**). |
| Place bar | bottom centre | `Cancel` and `Place` (170×72); `Place` is disabled unless the ghost is valid. While walls are painted it reads `Done` and is always enabled: there is nothing to confirm. |
| Info panel | bottom centre, 460 wide | Title `"Name   Lv N"` with a `Close` button; detail lines (**Info panel**); the upgrade button; a note under it. |
| Toast | top centre, 96 down | A centred outlined label that fades out after 1.8 s over 0.6 s. |
| Reset base | debug builds only (`OS.is_debug_build()`): the top bar's second row, right-aligned | Emits `reset_pressed`. On a row of its own so a long top bar (a Command Center 4 base) never runs under it. |

Bottom parts are anchored to the bottom edge and grow upward (`_anchor_bottom`). The theme
(`_make_theme`) sets the default font size (20), the panel style and the button styles; the
buttons take no focus.

## Refresh

`refresh(state, selected_id, placing, ghost_ok, painting)` is called by `main.gd` every tick,
after every state change, and on every selection change; `painting` is
`PlacementController.is_painting()`, which turns `Place` into `Done`. It refits the safe area if
the device's changed (**Safe area**), updates the top bar, then shows exactly one of the three
bottom parts:

- **placing** → the place bar;
- **a building selected** (`selected_id` in `state.buildings`) → the info panel;
- **otherwise** → the build bar.

The build entries are refreshed only while the build bar is shown, and only the selected tab's.

`refresh_placing(state, selected_id, placing, ghost_ok, painting)` takes `placing_changed`,
which fires when placement begins or ends and on every move of the ghost
(`main._on_placing_changed`). While the place bar is already shown it only enables or disables
`Place`; when placement begins or ends it does the full `refresh`, which swaps the bottom part.
A ghost drag therefore never recomputes the top bar or re-runs `check_can_build` for the menu;
they catch up on the next state change or tick.

## Build menu

**Tabs.** One toggle button (140×48) per `catalog.categories` id, in that order, labelled with
`catalog.category_name`, in one `ButtonGroup`. The first is selected when the HUD is built; the
selection is remembered while the game runs (not saved). Selecting a tab shows the entries of
the `catalog.menu_order` types whose `catalog.category_of(type)` is that tab, in `menu_order`
order, scrolls the strip back to its start, and refreshes those entries from the last state
`refresh` was given.

**Entries.** Every menu type gets a 224×96 button when the HUD is built; a tab only shows or
hides them. Three centred lines:

1. the display name (18 px);
2. the level 1 cost, each amount in its resource's colour (`resource_color`, the text colour
   when there is none), or "Free" (16 px);
3. the status (16 px): `built/max`, from `state.count_of(type)` and
   `catalog.max_count(type, state.cc_level())`, when `state.check_can_build(type)` passes; else
   the reason, and the button is disabled and its lines dimmed:

| `check_can_build` | Status line |
| --- | --- |
| `needs_command_center_level` | Needs Command Center N (N is level 1's `requires_cc`) |
| `limit_reached` | Max built |
| `no_free_builder` | No free drone |
| `insufficient_resources` | Not enough <name of the first resource, in catalog order, the base is short of> |
| anything else | `error_text(code)` |

A type the Command Center has not unlocked (`max_count` 0 at the current level) is still
listed, disabled with its "Needs Command Center N" line. Pressing an entry emits
`build_pressed(type)`; a drag across the strip scrolls it and presses nothing.

## Info panel

For the selected building, the stats of its current level (level 1's while it is first being
constructed), one line each, only when the level has the stat, in this order:

| Line | From |
| --- | --- |
| Hull 600 | `hp` |
| Produces 1,800 Metal/h | `produces`, one line per resource above 0 |
| Stores 1,500 Metal | `storage`, one line per resource above 0 |
| Houses 1 drone | `builders` above 0 |
| Capacity 20 | `capacity` (army) |
| Damage 12   Range 7 | `damage` and `range_cells`; either alone when the level has only one |
| Fires every 0.8 s | `fire_ms` |
| Targets ground / air / air and ground | `catalog.targets_of(type)` |
| Hidden from attackers | `catalog.is_hidden(type)` |

Once built and below its top level, a value the next level changes is followed by the next
level's after an arrow: "Hull 600 → 800", "Produces 1,800 → 3,000 Metal/h"; while first being
built it shows level 1's values with no arrow. The arrow is " → " when the theme's font has the
glyph and " > " when it does not (the bundled default font does not), checked once in `setup`.
Resources are named with
`catalog.resource_name`. While busy, a last line reads "Under construction: 10s left" or
"Upgrading to Lv N: 1m 00s left".

The upgrade button reads "Under construction" (disabled) while busy, "Max level" (disabled) at
the top level, else "Upgrade to Lv N   cost   (duration)", disabled with the reason in the
note when `state.check_upgrade` fails. Pressing emits `upgrade_pressed`; `Close` emits
`close_pressed`.

## Safe area

The root holds every part, so every part's anchors and margins are relative to the safe area,
the part of the screen clear of notches and the home indicator.

`apply_safe_area(inset: Rect2)` lays the root out inside `inset`, a rect in the HUD's own
coordinates (the viewport's visible rect: 1280×720 on a 16:9 screen under the `canvas_items`
stretch), by setting its offsets. `_fit_safe_area` fits it to the device in `setup`, on
`get_viewport().size_changed`, and on every `refresh` (the 1 s tick's included), since turning
a phone over moves the notch to the other side without a resize:
`DisplayServer.get_display_safe_area()`, in screen pixels, is clipped to the window
(`window_get_position`, `window_get_size`), made relative to it, and scaled by the visible
rect's size over the window's. It is applied only when it differs from the last rect fitted
this way. On desktop the safe area is the screen's usable rect: while the window lies inside
it the result is the whole visible rect, and a window reaching outside it (over the menu bar,
say) is inset to the part inside. A window with no size (a headless run) gets the whole
visible rect. The harness calls `apply_safe_area` to try a notch-like inset on a desktop window;
that inset stays until the device's safe area changes.

## Signals

| Signal | Emitted by | `main.gd` connects it to |
| --- | --- | --- |
| `build_pressed(type)` | a build entry | `placement.begin_place` |
| `confirm_pressed` | Place (Done while painting) | `placement.confirm_place`, which ends paint mode while painting |
| `cancel_pressed` | Cancel | `placement.cancel_place` |
| `upgrade_pressed` | the upgrade button | `placement.upgrade_selected` |
| `close_pressed` | Close | `placement.select(0)` |
| `reset_pressed` | Reset base | `main._reset_base` |

## Queries for the harness

Read-only, so a scenario never reads a private member (`tools/harness/README.md`):
`tab_button(category)` and `entry_button(type)` return the tab's and the entry's `Button`;
`entry_status(type)` is an entry's third line; `resource_panel(res)` is the top bar's panel for
a resource; `place_button()` is the place bar's `Place` (or `Done`); `drones_panel()` is the top
bar's drones panel; `reset_button()` is the debug Reset base button (null in a release build).

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

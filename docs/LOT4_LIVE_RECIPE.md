# Lot 4 — first live-tracker recipe (0.4.15 development branch)

Status: **code integrated, not validated in the Reborn client**. The local
`ultimate-0.4.15-local.zip` supplied on 2026-11-18 is an older install package:
its `.toc` has **no** LiveTracker.lua, TrackHUD.lua or Runtime.lua.
Do not confuse a matching version string with matching build contents.

## Install without losing builds

1. Copy your existing `WTF/Account/.../SavedVariables/RebornBuildPlannerDB.lua`
   to a safe folder. Never package this personal data.
2. Use the **entire** addon from `dev/ultimate-ui`, including the generated
   catalog and jewelry mechanics sources generated locally; do not append
   only the three tracker modules to an older incompatible installation.
3. Confirm the installed `.toc` lists `LiveTracker.lua`, `TrackHUD.lua`,
   `Runtime.lua` in that order **before** Controller.lua.
4. Restart/reload, run `/rbp diag`. It must report `events connected`.
5. Make one compatible build active via `Suivre`.

## Client checks and expected outcomes

- In the hub: HUD hidden, no card advice, no stale run progress.
- Enter a run: HUD shows goals once the Reborn state arrives; before
  `AZSSPELLS`, missing spells are **UNKNOWN**, not `PENDING`.
- Acquire a wanted spell: icon/status updates to achieved.
- Upgrade a rank-target spell: progress remains pending below the target.
- A wanted spell marked 'banish after': before acquisition it is a wanted card;
  after confirmed acquisition it shows 'banish after'. During initial
  resynchronization it must **not** get a green hint.
- A spell from the avoid list: red `AVOID` when its stable key matches.
- Jewelry: unidentified or ambiguous rows show unknown, not falsely missing.
- Reroll: old marks disappear and only the current offered hand is annotated.
- Close the hand / finish the run: old marks disappear.
- `/reload` while running: no acquired/missing claims before sync completes.
- `/rbp hud`: first call turns the initially enabled HUD OFF; second ON.
- `/rbp theme standard` and `/rbp theme elwynn` switch the HUD palette.
- Drag the HUD, pick cards and reroll normally: overlays never consume clicks.
- With FieldKit/Advisor installed: verify visual layering and no false hints.

## Diagnostics to provide if failing

Capture a screenshot and record: client version, `/rbp diag` output, build
class, current `AZS_RUN.ph`, whether a card hand is open, and whether this was
after `/reload`. Do not paste whole SavedVariables containing personal data.

## Current limitations

- Planner phases (four editing phases) have **no verified mapping** to game
  progression; live tracker uses phase 1 only.
- Jewelry identity in the native API may be ambiguous; 'unknown' is correct.
- Standard/Elwynn currently provide two palette schemes in `TrackHUD.lua`;
  full reuse of FieldKit's Elwynn artwork is not yet implemented.
- The addon deliberately never chooses, rerolls, banishes, or sends commands.
- Lua tests are source regressions; their presence is not proof of client QA.

## Card highlight redesign — visual blueprint (2026-11-19)

**Design reference:** the user's 2026-11-19 level-up screenshot showed two
thick, opaque yellow strips on the sides and square, unstyled corners. These
were caused by stretching the white fill texture into ADD-blended edge strips.
The previous four square action-button glows also covered card interiors.
Both approaches are forbidden for this redesign.

### Three acceptance mockups

**A / BUILD — selected goal, spell or jewelry:** native card remains 100% legible;
an outer **gold engraved 8-piece rim** hugs its silhouette, with four intact
corners and four richly textured edges. A second, offset copy of the **same
engraved material** is ADD-blended at low intensity to create a shaped halo.
Only the glow's opacity breathes; the frame itself is steady. A small labelled
plaque above the card announces BUILD; it does not overlap the native NEW / UPGRADE
header or the card number. At a glance, it should read as an enchanted WoW
frame, never as warning tape or an illuminated rectangular fill.

**B / Alternative and warnings:** same external geometry with subdued bronze
(ALT), red (avoid) or amber (banish after). The existing badge text conveys
status. Glow remains gentler than the main BUILD priority.

**C / No matching card:** no highlight on the unselected cards. Existing
read-only gold guidance targets Reroll, or Skip if reroll is unavailable.
No card input/selection is intercepted, and native frames are never resized.

### Implementation contract

- **One texture atlas, eight slices** per pass (four corners, four edges),
  excluding the centre tile entirely. Prefer FieldKit Reborn's existing
  `elwynn_material_v3.tga` (512-square / 12px sliced corners), matching the
  HUD's already-validated Elwynn frame. Fallback to the planner's own
  `window_nine.tga` (128-square / 28px source corners), never the plain white
  strip. Render only the edge/corner parts, with a fixed screen-space cap.
- Two passes: steady thin rim and quieter ADD halo outside it, never 17px
  solid yellow rectangles. Avoid the action-button border texture entirely.
- The halo animates gently; rim colours and native card contents stay stable.
- Must be tested on a rare spell, a normal jewel, a legendary amulet, and a
  card to banish after acquisition; verify with each rarity's native border.
- Headless Lua tests verify overlay structure/alpha/state lifecycle; **only a
  live screenshot/video can establish aesthetic quality**.

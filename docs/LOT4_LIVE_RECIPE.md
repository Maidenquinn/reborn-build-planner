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

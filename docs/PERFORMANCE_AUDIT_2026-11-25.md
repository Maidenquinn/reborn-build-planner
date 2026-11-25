# Reborn Build Planner — full-addon performance audit (2026-11-25)

Scope: all 26 shipped Lua modules in the installable RBP addon, compared against the stable `v0.5.1` and the confirmed in-game jewelry hotfix. This is a **static code-path audit with Lua regression tests**, not a measured client FPS/CPU profile.

## Findings and mitigation

| Area | Observed implementation | Impact | Outcome |
| --- | --- | --- | --- |
| Jewelry lookup | Resolving a new card by localized name scans all known jewelry/amulets; original Mage/Paladin change also generated many combinations of legendary names | High: caused user-observed freezes on native card choices | Prior hotfix replaced the combinatorial resolver and introduced a bounded 192-entry cache, including misses; user validated the freezes stopped |
| Runtime event fan-out | Every `AZSCARDS` and `AZSCARDTIP` event called full `Runtime.Refresh()`, rebuilding selected build, library build options, progress, tracker rows and card highlights | High redundant work, especially during card selection | Card-only fast path refreshes native card highlights and reroll/skip advice without reconstructing unrelated HUD |
| Banish acknowledgements | `AZSCARDS` sometimes confirms a player ban, changing progress and journal | Must never be skipped by fast path | Confirmed bans explicitly request one full refresh; regression test covers this |
| Card overlay paint | Every card packet called `paint()` and SetText on up to eight 25-texture decorative overlays, even if the hint was unchanged | Medium CPU/GPU API-call overhead | Avoid decorative repaint for unchanged hint and language; preserve 30Hz glow |
| Planner while hidden | Controller notifications refreshed library rows, editor and browser even when UI had been created but was closed | Medium unnecessary UI rebuilds on in-game changes | Only auto-refreshes when planner is visible; `Show()` still refreshes when reopened |
| Animated highlights | Each shown card has OnUpdate with a 30Hz alpha-throttling guard | Bounded visual cost; at most eight animated frames and no per-frame catalog resolution | Retained animation; no gameplay-critical modifications |
| Minimap drag | OnUpdate installed only during a held drag and removed on stop | Negligible idle work | Retained |
| Library search/sort | `Controller.Rows()` caches results, `IndexOf()` caches case-folded text by revision/locale, and virtualized UI shows a fixed window | Already avoids repeated scans per rendered row | Retained |
| Build capture | Explicit button press prepares a snapshot and creates a new build only after confirmation | Not a per-frame operation | Retained; no speculative truncation or gameplay mutation |
| Storage/schema and import/export | Synchronous, bounded validation and codec work on explicit user operations, not in OnUpdate | Heavy only during explicit operations | No risky format or migration changes |
| Texture assets and theme | Static packaged assets; cache friendly and no permanent theme OnUpdate | Small relative to refresh cycle | Retained |
| Runtime profiler | Existing opt-in `profileEnabled` instrumentation uses `debugprofilestop()` if present, reporting call count, total, max and average | Useful for real client validation | Retained; no timers introduced |

## Regression requirements

- All original Lua 5.1 tests and catalogue generation tests must pass.
- 160 simulated card events preserve advice and skip full HUD refresh.
- Confirmed native banishments remain visible in the HUD and persistent journal.
- 400 repeated positive and negative item lookup calls hit the bounded cache.
- Mage and Paladin native FR/EN jewelry and legendary capture still pass.
- The generated ZIP must pass Syiana's folder, extension and TOC structure checks.

## Limits and release gate

A source-code pass cannot establish actual end-user FPS, CPU usage, frame pacing, peak heap or garbage-collection pauses. These require testing on a real running client with representative Mage, Paladin, multiplayer runs and card offers. The `v0.5.1` stable release, the user's saved builds and the upstream addon index remain untouched.

Only offer this branch as a separate private recipe until the user has checked card-choice smoothness, ordinary spell/gear updates, ban confirmations, HUD theme/stage switching, opening/closing the planner and persistence across `/reload`. Do not publish it as a stable release without user approval.

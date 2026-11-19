# 0.4.8-alpha-readable — Player-first item descriptions

## User screenshots (18 Nov 2026)

Real client screenshots confirmed `/rbp diag` version 0.4.7, catalogue `6637f92a3903d44c`, storage OK, all 44/44 local jewelry definitions available, AZS_GEN present. Effects appeared but were difficult to understand, especially because the screen combined current live item text, unscaled base coefficients, formal rank formulas, and source metadata in a cramped inspector.

Real observation, Blooddrinker ring: the game shows **"1,5% de tous les dégâts infligés te soignent"** for an equipped example. The local metadata base coefficient is **0.01** (= 1% before rarity/upgrades). These are different scopes: the planner must never present 1% next to the live 1.5% as if both apply concurrently.

## Changes

- `JewelryEffects.Simple` provides original, short explanations for documented simple coefficients (damage, cooldown, life steal, critical damage, etc.). Missing/special formulas are NOT invented.
- `JewelryEffects.Sections`: "BONUS DE L'OBJET" first. No second redundant `Coefficient de base` line for common effects; leave the rare/upgrade caveat once.
- `JewelryEffects.LiveSections`: heading explicitly says `BONUS ACTUEL DANS LA PARTIE`. An equipped item uses the **real text from AZS_GEAR** only when name+slot uniquely identify a catalog entry.
- `Controller.TooltipData`: when live item text exists, omit the local base reference from the view to avoid contradictory numbers.
- `UI.ShowTip`: bonus first, "placed in build" bookkeeping after the effect.
- `UI.DetailLines`: equipment benefits first; build placement/type/metadata below.
- `UI.BuildDetail`: the scrollable text area uses 548px instead of 372px; the narrow 162px right-side source column is gone. Source text appears in the full-width scroll at the end.
- `Describe.growthLines`: players see rank multipliers in words instead of an explicit exponentiation formula. Core `D.Multiplier` and `D.FixedMultiplier` remain unmodified; official data and rank math remain authoritative.
- Version `0.4.8-alpha-readable`; 0.4.7 builds and SavedVariables stay compatible.

## Example display

**Anneau du buveur de sang:**
- Equipped and uniquely identified: "BONUS ACTUEL DANS LA PARTIE — 1,5% de tous les dégâts infligés te soignent" (verbatim native Reborn snapshot).
- In a theoretical build / no live snapshot: "BONUS DE L'OBJET — 1% des dégâts que tu infliges te soignent. Valeur de base : le bonus réel dépend de la rareté et des améliorations."

**Œil du Ciel fendu : Tir automatique:** the official JSON gives targets/damage/rebound and rank growth. The panel shows effects at rank 1 first and a concise rank growth explanation. No invented real run unit for published raw damage value `0.2`.

## Remaining limits

- Complex/conditional jewel mechanics cannot be converted into exact live numbers unless the game provides them or an independently validated formula exists.
- Data from `AZS_GEAR` is only shown for truly equipped objects during a run; this build planner does not simulate rarity levels or upgrades of hypothetical builds.
- UI geometry and word wrapping have automated Lua checks. **No actual 0.4.8 client screenshot yet**; visuals and readability remain subject to real-game recipe.
- `main` remains untouched. PR #1 is draft, no release.

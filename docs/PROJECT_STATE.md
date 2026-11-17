# PROJECT_STATE — Reborn Build Planner

Mis à jour : 2026-11-17 · **Lot 0 terminé (PASS CONDITIONNEL, validé par GPT) · Lot 1 terminé (PASS, en attente d'examen GPT)** · Lot 2 (codec `azsb1:`) non commencé.

## Décisions acquises
* Addon natif `RebornBuildPlanner`, `## Interface: 30300`, dépendances `AzerothSurvivors, AzerothSurvivorsAPI`, SavedVariables **`RebornBuildPlannerDB`** (seule globale propre) ; namespace global `RebornBuildPlanner`. Commandes `/rbp`, `/rebornplanner` à valider (collision non vérifiée).
* Lecture seule des tables `AZS_*`, abonnements `AZS.On`, aucun événement WoW inventé, aucun `sync`/polling, aucune action de jeu. **Pas encore câblé** (Lot 4).
* Run = `AZS_API_RunId()`, hub = `AZS_ZONE.hub == 1`, jetons de conseil `{run, époque, main, état}`, inconnu ≠ absent (Lot 0).
* **Conseil automatique de bijou désactivé** jusqu'à `P-J1…P-J3` ; légendaires = `legendary:<spell>` par nom complet + classe, jamais `head`/icône.
* Catalogue : généré hors jeu (`tools/generate_catalog.py`), embarqué en Lua pur, clés officielles, refus des schémas futurs, anomalies consignées (jamais corrigées). `call_of_flame` = anomalie connue (marqué légendaire sans ligne `legends.json`).
* Modèle : 4 phases fixes ; `spells` (≤ 6 objectifs ordonnés `acquire|rank|unlimited`) et `banish` (≤ 3) séparés ; alternatives = positions fixes avec trous conservés ; gravités `error/conflict/warning` ; un conflit importé est conservé et signalé, une édition ne peut pas en créer un ; statuts d'objectif `UNKNOWN/PENDING/ACHIEVED/BLOCKED`.
* Stockage : migration sur copie + sauvegarde embarquée, lecture seule si schéma futur/invalide/migration échouée (table d'origine non remplacée), quarantaine, corbeille annulable (20), import tout-ou-rien, ids toujours nouveaux. Limites : 200 builds, textes en octets (nom 240, label 96, notes 8000, lien 300, talents 400), `ext` ≤ 2000 nœuds.
* Dev : Lua 5.1 isolé dans `.devtools/venv` (lupa 2.8), jamais livré.

## Catalogue
`data/v1` schema 1, content **384db000d5ac311d** : 12 classes, 241 sorts, 44 bijoux, 22 amulettes, 237 légendaires ; FR : 310/317 noms ; `GeneratedCatalog.lua` 110 396 octets, sha256 `6e64ed7d…cbf9f05`. Non embarqués : talents, caps, set_bonuses, zones, autres langues.

## Contrats confirmés
Lot 0 : R1-R17 statiques (54 ancres), codec `azsb1:` exécuté depuis le code du site. Lot 1 : D1-D7, S1-S6, C1 (`CONTRACTS.md` §7), tous couverts par des tests Lua 5.1.

## Tests exécutés (`python -I tools/run_all.py` → exit 0)
Catalogue à jour · générateur 84 assertions · Lot 0 273 · **Lua 5.1 : 57 cas, 2 144 assertions, 0 échec** (vrais modules, sandbox sans `io/os/require`). Non exécuté : client, rien en jeu, aucun aller-retour navigateur.

## Inconnues et risques
`P-K1`, `P-J1/J2/J3`, `P-C1`, `P-C2`, `P-R1/R2/R3`, `P-S1/S2`, `P-U1`, `P-W1` (inchangés, `VALIDATION_PLAN.md`). Nouveaux : comportement réel d'`ADDON_LOADED`/SavedVariables dans le client ; poids du catalogue en mémoire ; légendaires non traduites en FR ; une seule migration (schéma 0 prototype).

## Décisions à confirmer par GPT/Kevin avant le Lot 2
1. Import web : garder les conflits (clé d'une autre classe, doublon) avec aperçu, plutôt que les écarter comme le fait le site (recommandé).
2. Libellé de phase : `""` = défaut localisé, comme le site.
3. Export « site » : signaler `rank/unlimited`, `ext`, `catalog`, `revision` comme non représentables.

## Prochaine action
Lot 2 : codec `azsb1:` (décodage/encodage Lua 5.1, limites UTF-16, rejet sans mutation, aperçu d'import) rejouant `tests/fixtures/codec/golden.json` ; en parallèle recette client `S-A…S-D` (~30 min) pour lever `P-C1/P-S2/P-J*` avant le Lot 4.

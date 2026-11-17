# VALIDATION_PLAN — Lot 0

## 1. Tests hors client (reproductibles, aucun accès au jeu requis hors lecture des Lua)

Depuis `reborn-build-planner/` (Python 3.13 stdlib, Node 24 ; aucun paquet à installer) :

```bash
python -I tools/check_env.py                       # interpréteurs disponibles (Lua 5.1 absent à ce jour)
python -I tools/run_tests.py                       # 273 assertions : catalogue, grammaire, 16 scénarios, 54 ancres, codec
python -I tools/run_tests.py --native-root "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\Interface\AddOns"
python -I tools/check_anchors.py --native-root "<AddOns>"          # ne vérifie que les lignes citées
python -I tools/make_synthetic_fixtures.py         # régénère tests/fixtures/synthetic (déterministe)
node tools/gen_codec_golden.mjs <BYjmu0KK.js> tests/fixtures/catalog/384db000d5ac311d tests/fixtures/codec/golden.json
```

* Après une mise à jour du jeu : relancer `run_tests.py`. Un échec d'ancre = contrat à relire, pas à « corriger » en changeant le numéro de ligne sans relire. `check_anchors.py --emit` recalcule les lignes ; à n'utiliser qu'après relecture.
* Ces tests prouvent la cohérence des contrats et l'existence des lignes citées. Ils **ne prouvent aucun comportement du client** : les ports Python de `ParseKV/ParseList/AZSCARDS/AZS_API_RunId` sont des reconstructions.
* Depuis le Lot 1 un Lua 5.1 isolé existe (`.devtools/venv`, lupa) : `python -I tools/run_all.py` lance tout (catalogue, générateur, Lot 0, suites Lua). Reste à faire (Lot 4) : rejouer `tests/fixtures/synthetic` contre les **vrais** `Core.lua`/`Units.lua`/`Spells.lua`/`Cards.lua` natifs avec des stubs WoW minimaux, pour supprimer la dépendance aux ports Python du modèle de cycle de vie.

Critère de réussite : `273 assertions passed, 0 failed`, exit code 0.

## 2. Recette client courte (non exécutée en Lot 0)

Aucune écriture, aucune commande de jeu : les lignes ci-dessous **affichent** des champs dans le chat. Ne rien coller d'autre que leur sortie, et remplacer le nom du héros si apparu. Sauvegarder la sortie dans un fichier texte `recette-lot0-<date>.txt`.

Diagnostics (une ligne chacun, à coller dans le chat du jeu) :

```text
/run local z,r=AZS_ZONE or {},AZS_RUN or {}; print("ZONE run=",z.run,"class=",z.class,"hub=",z.hub,"| RUN ph=",r.ph,"endless=",r.endless,"endl=",r.endl,"| api=",AZS_API_RunId and AZS_API_RunId())
/run for i,s in ipairs(AZS_SPELLS or {}) do print("SP",i,s.key,s.spell,s.rank) end
/run print("GEAR nil?",AZS_GEAR==nil); for i,g in ipairs(AZS_GEAR or {}) do print("GR",i,g.slot,g.rarity,g.bonus,g.amount,g.icon,g.name) end
/run local c=AZS_CARDS or {}; print("CARDS kind=",c.kind,"src=",c.src,"bn=",c.bn,"sl=",c.sl,"slm=",c.slm,"rr=",c.rr,"n=",#(c.cards or {})); for i,k in ipairs(c.cards or {}) do print("CD",i,k.key,k.spell,k.rank,k.new,k.mode,k.rarity,k.icon,k.name,k.slot) end
```

Séquences :

| Id | Séquence | À relever | Valide |
|---|---|---|---|
| **S-A** (3 min) | Se connecter au hub, `/run` zone/run ; entrer en run ; avant le 1ᵉʳ mouvement puis après | `run`, `class` (casse), `hub`, `ph`, `endless`, `endl` ; `GEAR nil?` | `P-R1`, `P-R2`, `P-R3`, `P-S1` |
| **S-B** (10 min) | Level-up : lancer les diagnostics **pendant la main** (`ph` visible) ; reroller (R) puis relancer ; prendre un sort, relancer `SP` | `ph` pendant la main, `kind/bn/sl/slm/rr`, `key/spell/rank/new` des cartes, ligne `SP` | `P-C1`, `P-C2`, `P-K1` |
| **S-C** (5 min) | `/reload` **pendant** une main de sorts, immédiatement relancer les 4 diagnostics (sans attendre), puis après 5 s | `GEAR nil?`, `n=`, `ph` juste après vs 5 s après ; l'id `run` avant/après | `P-S1`, `P-S2`, `R5/R6` |
| **S-D** (15 min) | Obtenir un coffre/trésor (bijou) et une amulette, idéalement une légendaire ; diagnostics pendant la main et après le choix ; refaire en **français** si possible | `GR` (slot, rarity, bonus, amount, name, icon), `CD` jewel (mode, rarity, name, slot), `src` | `P-J1`, `P-J2`, `P-J3` |
| **S-E** (3 min) | Mourir ou terminer ; relancer ; lancer une nouvelle run, relancer | `run` avant/après, `GEAR nil?`, `AZS_CARDS` résiduel | `R12`, `P-R1` |
| **S-F** (10 min) | Créer le panneau test (Lot 4 : une frame nommée + `AZS_SetOnTopOfScreens`) pendant une main | recouvrement, clics, Échap | `P-U1` |

## 3. Protocoles par inconnue

| Id | Question | Observation attendue | Réussite | Si échec |
|---|---|---|---|---|
| P-K1 | `AZS_SPELLS.key`/`AZSCARDS.key` = clé de `spells.json` ? | `SP`/`CD` : toutes les clés d'une classe comparées au catalogue (script : `tools/` du Lot 1) | 100 % des clés de la classe présentes, `spell` = `id` | Table de correspondance serveur→catalogue générée ; sinon appariement par `id` seul |
| P-J1 | Noms/`bonus` des anneaux et bijoux portés par langue (EN, FR) | `GR` pour ≥ 6 pièces, 2 langues | `name` = catalogue (EN) / `i18n` (FR) ; `bonus` identique à `key` **ou** constat qu'il ne l'est pas | `jewel_identity_verified` reste faux ; pas de conseil bijou |
| P-J2 | Amulettes fixes et légendaires portées : `name`, `rarity`, `amount` ; légendaire en FR | `GR` amulette (≥ 3 dont 1 légendaire, 1 homonyme possible) | `name` = `legends.json.name` (EN) ; `amount` = rang ; comportement FR relevé | Légendaires hors EN = INCONNU documenté |
| P-J3 | Cartes bijou : `name`, `mode` des pièces neuves, `slot`, `src` | `CD` sur ≥ 5 mains bijou (cache, guardian, cursed, trésor) | noms apparient (P-J1/J2), modes énumérés | Aucune reco bijou proposée |
| P-C1 | `ph` pendant mains de sorts, de coffre, niveaux stockés | `ph` à chaque main | `choosing` partout | Adapter `HAND_PHASES` ou la règle de main |
| P-C2 | `bn` sur main bijou, `src`, séparateurs dans les noms | `CD` | conforme à R9/R16 | Ajuster la normalisation |
| P-R1 | `AZSZONE.run` (forme `r<hex>`), `class` (casse) | S-A | `azs:r…` stable après reload ; classe reconnue | Repli sur l'id compteur ; normalisation déjà prévue |
| P-R2 | Hub : `run`, `AZSRUN` | S-A | `hub=1` | Règle hub inchangée (`hub` prime) |
| P-R3 | `endl` vs `endless` | S-E + une run en sans-fin | `endless` suffit | Ajouter `endl` |
| P-S1 | `AZSZONE` après chaque entrée en monde | S-A/S-C | toujours reçu | Message « en attente » conservé |
| P-S2 | Lignes vides envoyées à la synchro (`AZSGEAR`/`AZSCARDS`/`AZSSPELLS`) | S-C avec 0 bijou et 0 main | ligne vide reçue ou non, **sans** attendre | Si non : `UNKNOWN` ne devient jamais `EMPTY` ; afficher « non communiqué » |
| P-U1 | Panneau au-dessus des cartes | S-F | lisible, ne bloque ni cartes ni Échap | Ancrer ailleurs / désactiver pendant les cartes |
| P-W1 | Aller-retour avec le planner du site | **Partiellement exécuté le 2026-11-17** (`tests/fixtures/codec/browser_recette_2026-11-17.md`) : `?p=` Lua → site identique, site → Lua → même code. **Reste à faire par Kevin** : (1) coller un code `azsb1:` dans la boîte d'import du site (pas l'URL) ; (2) bouton « Copy code » puis coller dans `PlannerCodec.Decode` ; (3) un build avec un conflit (code de `tests/fixtures/codec/golden.json` cas `other_class_spell_dropped`) ouvert sur le site : constater que le site écarte l'entrée alors que le planner la garde ; (4) un autre navigateur | égalité sémantique ; pas de crash | `VALIDATION NAVIGATEUR REQUISE` pour (1)-(4) ; le chemin `?p=` est déjà démontré |

## 4. Critères d'acceptation du Lot 0 (rappel)

Tous « documentés » ; ceux marqués `VALIDATION CLIENT REQUISE` ci-dessus restent ouverts mais **ne bloquent pas** le Lot 1 (catalogue/modèle/stockage), qui n'en dépend pas. Ils bloquent seulement : conseils bijoux (`P-J*`), détection de main (`P-C1`), lecture « vide » (`P-S2`), codec validé de bout en bout (`P-W1`), panneau (`P-U1`).

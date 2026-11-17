# PROJECT_STATE — Reborn Build Planner

Mis à jour : 2026-11-17 · Lots 0-2 validés · Lots 3 à 3.4 PASS CONDITIONNEL · **Lot 3.5b : lab v2 à textures originales livré, NON validé visuellement** · Lot 4 non commencé.

## Décisions acquises
* Addon natif `RebornBuildPlanner`, `## Interface: 30300`, dépendances `AzerothSurvivors, AzerothSurvivorsAPI`, SavedVariables **`RebornBuildPlannerDB`** (seule globale propre) ; namespace global `RebornBuildPlanner`. Commandes `/rbp`, `/rebornplanner` à valider (collision non vérifiée).
* Lecture seule des tables `AZS_*`, abonnements `AZS.On`, aucun événement WoW inventé, aucun `sync`/polling, aucune action de jeu. **Pas encore câblé** (Lot 4) : l'interface du Lot 3 n'affiche aucune donnée live.
* **Interface (Lot 3)** : une fenêtre (Mes builds / Éditeur / Importer / Exporter) + une boîte de dialogue ; `Controller` (comportement sans widget) + `UI` (rendu) ; widgets créés une fois, listes paginées ; brouillon distinct de l'enregistré, jamais auto-enregistré ; suppression via corbeille annulable ; import jamais actif ; « Suivre » refusé pour un build à réparer ; pas de presse-papiers (Ctrl+A/C/V) ; `/rbp`, `/rebornplanner` (collision gérée), `reset`, `diag` ; FR si client `frFR`, EN sinon ; rien de traduit dans les données.
* Run = `AZS_API_RunId()`, hub = `AZS_ZONE.hub == 1`, jetons de conseil `{run, époque, main, état}`, inconnu ≠ absent (Lot 0).
* **Conseil automatique de bijou désactivé** jusqu'à `P-J1…P-J3` ; légendaires = `legendary:<spell>` par nom complet + classe, jamais `head`/icône.
* Catalogue : généré hors jeu (`tools/generate_catalog.py`), embarqué en Lua pur, clés officielles, refus des schémas futurs, anomalies consignées (jamais corrigées). `call_of_flame` = anomalie connue (marqué légendaire sans ligne `legends.json`).
* Modèle : 4 phases fixes ; `spells` (≤ 6 objectifs ordonnés `acquire|rank|unlimited`) et `banish` (≤ 3) séparés ; alternatives = positions fixes avec trous conservés ; gravités `error/conflict/warning` ; un conflit importé est conservé et signalé, une édition ne peut pas en créer un ; statuts d'objectif `UNKNOWN/PENDING/ACHIEVED/BLOCKED`.
* Stockage : migration sur copie + sauvegarde embarquée, lecture seule si schéma futur/invalide/migration échouée (table d'origine non remplacée), quarantaine **sans perte** (50 max : au-delà, refus contrôlé et lecture seule), ouverture transactionnelle, corbeille annulable (20, éviction signalée), import tout-ou-rien, ids toujours nouveaux. Limites : 200 builds, textes en octets (nom 240, label 96, notes 8000, lien 900, talents 400), `ext` ≤ 2000 nœuds.
* Dev : Lua 5.1 isolé dans `.devtools/venv` (lupa 2.8), jamais livré.

## Catalogue
`data/v1` schema 1, content **384db000d5ac311d** : 12 classes, 241 sorts, 44 bijoux, 22 amulettes, 237 légendaires ; FR : 310/317 noms ; `GeneratedCatalog.lua` 110 396 octets, sha256 `6e64ed7d…cbf9f05`. Non embarqués : talents, caps, set_bonuses, zones, autres langues. Site officiel : bundle `BYjmu0KK.js` et catalogue inchangés au 2026-11-17.

## Contrats confirmés
Lot 0 : R1-R17 statiques (54 ancres). Lot 1 : D1-D7, S1-S6, C1. Lot 1.1 : quarantaine sans perte (refus contrôlé `QUARANTINE_FULL`), ouverture transactionnelle (copie, invariants, lecture seule en cas d'échec). Lot 2 : X1-X14 (`CONTRACTS.md` §7-8), codes identiques à ceux du site sur 68/68 cas.

## Tests exécutés (`python -I tools/run_all.py` → exit 0)
Catalogue à jour · générateur 84 · Lot 0 273 · **Lua 5.1 : 135 cas, 6 980 assertions, 0 échec** (dont interface simulée : 41 cas) (vrais modules, sandbox sans `io/os/require`) · **JS↔Lua : 63 codes vérifiés avec le décodeur officiel (Node)** · recette navigateur partielle (`?p=`, 2026-11-17). Lot 1.1 : avant 33 échecs / après 0. Lot 3 : mise en page contrôlée sur dimensions **estimées** (1365×768, 1920×1080, 1024×768, 800×600, EN/FR) — pas un rendu. **Non exécuté : client Reborn (aucune capture), import par collage sur le site.**

## Inconnues et risques
Lot 3 : recette client C1-C18 (`RECETTE_CLIENT_LOT3.md`) : chargement/`ADDON_LOADED`, focus clavier et Ctrl+C/V dans les zones de texte, clamp de la fenêtre, recouvrement des écrans de cartes, rendu FR, coexistence FieldKit/Stats. Lot 2 : `P-W1` (1)-(4) ; talents réécrits par le site (X13) ; plafonds de taille à confirmer ; URL = approximation WHATWG. `P-K1`, `P-J1/J2/J3`, `P-C1`, `P-C2`, `P-R1/R2/R3`, `P-S1/S2`, `P-U1`, `P-W1` (inchangés, `VALIDATION_PLAN.md`). Nouveaux : comportement réel d'`ADDON_LOADED`/SavedVariables dans le client ; poids du catalogue en mémoire ; légendaires non traduites en FR ; une seule migration (schéma 0 prototype).

## Décisions du Lot 2 (appliquées, à ratifier)
1. Import : conflits conservés avec aperçu ; build « à réparer » stockable mais **non activable** ; classe inconnue acceptée, jamais activée ni exportée.
2. Libellé de phase : `""` = défaut, jamais de texte localisé dans les données.
3. Export site : pertes d'intention annoncées et à accepter explicitement ; métadonnées internes omises ; stats exportées sans arrondi (le site arrondit, annoncé).
4. Import jamais actif, jamais écrasant ; UTF-8 strict ; limites UTF-16 du site avec avertissement.
5. Format natif d'échange : non défini (besoin non établi).

## Prochaine action
1. **Kevin** : exécuter la recette client du Lot 3 (≈ 25 min, package `reborn-build-planner-recette-lot3\`), puis P-W1 (1)-(4) et la recette `S-A…S-D` (~30 min) qui lèvent `P-C1/P-S2/P-J*`.
2. Lot 4 (suivi en partie, évaluation, conseils de sorts) seulement après `P-C1`, `P-S2` et les corrections issues de la recette du Lot 3.

## Lot 3.1 (0.3.1-lot3.1)
* **Modèle** : `phase.banishAfter` (sous-ensemble des sorts souhaités, max 3) = « bannir après acquisition » ; `phase.banish` = liste à éviter (inchangée, format du site). Souhaité + marqué n'est pas un conflit ; souhaité + évité en reste un (anciens builds), converti seulement sur clic. Stockage : schéma 1 inchangé, champ optionnel (absent = vide).
* **azsb1** : ne peut pas représenter `banishAfter` (le décodeur du site supprime les bannissements qui chevauchent les sorts : `tools/site_overlap_probe.mjs`). Export : perte d'intention annoncée, acceptation requise, rien écrit dans la liste de bannissement.
* **Interface** : fenêtre opaque (strate DIALOG), panneaux contrastés, rôles de boutons, éditeur réagencé, infobulles au survol (catalogue, plan, bijouterie) : texte de sort demandé au jeu par id à la volée, sinon « Effet détaillé indisponible ». Le catalogue n'a ni description ni statistique.
* **Tests** : Lua 5.1 162 cas / 7 171 assertions / 0 échec. **Lot 0 : 17 ancrages statiques de `AzerothSurvivors` (Run/Cards/Units) ont bougé : le code natif installé a changé ; à ré-ancrer avant le Lot 4.**
* **Non fait / à valider en jeu** : `RECETTE_CLIENT_LOT3_1.md` (D1-D16) + C1-C18 du Lot 3 restants ; règle de jeu « bannir un sort déjà acquis » (D16) ; format natif complémentaire pour exporter `banishAfter` ; navigation clavier.
* **Prochaine action** : Kevin exécute D1-D16 et répond à D16 ; GPT relit REPORT_LOT3_1 ; puis ré-ancrage des constats Lot 0 et Lot 4.

## Lot 3.2 (0.4.0-alpha)
* **Interface** : une fenêtre 1120×704 à trois zones (bibliothèque / éditeur complet sur une page / inspecteur), opaque ; recherche, favoris, récents, tri ; six sorts + « bannir après » ; douze emplacements d'équipement visibles, catalogue intégré avec cible visible ; création corrigée.
* **Stockage** : `db.meta` (favori / utilisé / modifié / créé) + réglages `libSort` / `libFilter`, schéma 1 inchangé, créés à la demande, jamais exportés.
* **Contrats natifs** : ré-ancrés (`CONTRACTS.md` §11) : 17 décalages de lignes, **C09 modifié** (bannissements aussi sur les mains de bijoux). Lot 0 : PASS.
* **Tests** : Lua 5.1 183 cas / 7 934 assertions / 0 échec ; mise en page sur largeurs estimées.
* **Non fait / à valider** : `RECETTE_CLIENT_LOT3_2.md` (E1-E22) ; effets des pièces indisponibles (`DESCRIPTION_SOURCES.md`) ; règle de jeu du bannissement d'un sort acquis (E22) ; navigation clavier ; format natif complémentaire pour `banishAfter`.
* **Prochaine action** : Kevin exécute E1-E22 ; GPT relit REPORT_LOT3_2 ; décision sur la source des effets d'équipement ; puis Lot 4.

## Lot 3.3 (0.4.1-alpha)
* **Layout** : gauche = bibliothèque (liste défilante), centre = éditeur (6 sorts, 12 emplacements) + **détails en bas**, **droite = navigateur permanent** Sorts / Anneaux / Bijoux / Amulettes (recherche, liste défilante). Plus de pagination (sauf pages de messages import/export). Composants `LibraryPane`, `EditorPane`, `DetailPane`, `BrowserPane`.
* **Parcours** : emplacement -> navigateur filtré + cible -> sélection -> détails -> « Placer ici » / double-clic ; sélectionner ne place jamais.
* **Style** : boutons plats à rôles, palette encre/laiton, rouge réservé à la suppression. Rendu **non vu**.
* **Stockage / contrats** : inchangés (db.meta, banishAfter, ré-ancrage Lot 3.2).
* **Tests** : Lua 5.1 193 cas / 9 020 assertions / 0 échec.
* **À valider en jeu** : `RECETTE_CLIENT_LOT3_3.md` (F1-F19) : boutons sans modèle, molette sur les lignes, rendu, appréciation visuelle ; plus E22 (bannir un sort acquis).
* **Prochaine action** : Kevin exécute F1-F19 + captures ; ajustements visuels selon ses retours ; puis décision sur la source des effets d'équipement ; puis Lot 4.

## Lot 3.4 (0.4.2-alpha)
* **Données** : générateur v2 conserve les champs publiés des amulettes et légendaires (hash inchangé). `Describe.lua` applique les règles officielles (FR/EN). Anneaux/bijoux : aucun effet publié -> « Effet détaillé indisponible » ; `API_PROPOSAL_JEWELRY.md` pour SNX.
* **UI** : cases d'équipement à zones réservées, principaux | alternatives, sorts compacts, inspecteur à sections avec défilement, infobulles courtes (texte natif seulement dans le panneau), ancre selon la moitié d'écran.
* **Traductions** : légendaires = tête anglaise + sort traduit ; stats et effets sûrs traduits.
* **Tests** : Lua 5.1 206 cas / 11 773 assertions / 0 échec.
* **À valider en jeu** : `RECETTE_CLIENT_LOT3_4.md` (G1-G14), dont appréciation visuelle ; comparer 2-3 effets d'amulettes au site.
* **Prochaine action** : captures de Kevin ; envoyer la proposition API à SNX ; décider de `set_bonuses.json` ; puis Lot 4.

## Lot 3.5 (étape 1, 0.4.3-proto1)
* **Diagnostic** : `DIAGNOSTIC_RENDU.md` (observé / déduit / inconnu).
* **Design system** : `Theme.lua` (chargé, non appliqué) + addon `RebornPlannerThemeLab` (`/rbplab`, comparaison nouveau / 0.4.2, capacités du client). Recette : `RECETTE_LAB_LOT3_5.md`.
* **Localisation** : `Glossary.lua` / `GLOSSARY_FR.md` (21 têtes, communautaire, non officiel, clé stable inchangée).
* **Tests** : Lua 5.1 216 cas / 12 586 assertions / 0 échec.
* **Bloquant** : validation visuelle de Kevin (L1-L10). Éditeur complet, 0.4.3-alpha, recette éditeur : après approbation.

## Lot 3.5b (lab v2)
* Lab v1 REJETÉ par Kevin (gauche = droite). Technique « régions colorées » abandonnée.
* **19 textures originales** (`tools/make_textures.py`, déterministe, octets vérifiés par `run_all.py`) ; `Theme.lua` v2 (neuf segments, états visibles, strata `FULLSCREEN_DIALOG`) ; lab v2 `RebornPlannerThemeLab` avec dossier `Media\`. Docs : `TEXTURES_INVENTORY.md`, `COMPAT_CLIENT_LOT3_5B.md`, `RECETTE_LAB_V2_LOT3_5B.md`, `REPORT_LOT3_5B.md`.
* **Tests** : Lua 5.1 220 cas / 14 196 assertions / 0 échec (simulation).
* **Bloquant** : verdict de Kevin (M1-M10) : fichiers chargés ? différence évidente ? texte du jeu encore visible ? Le planner complet reste inchangé (0.4.3-proto1).

## Transfert vers GPT
* Le pilotage du code, de la direction artistique et de l'UI passe à GPT. Point d'entrée : `docs/HANDOFF_TO_GPT.md`. Branche de travail : `dev/ultimate-ui` ; `main` = état stable.
* Kevin a explicitement refusé le rendu du prototype v2 (lab) : thème NON validé, non appliqué au planner.

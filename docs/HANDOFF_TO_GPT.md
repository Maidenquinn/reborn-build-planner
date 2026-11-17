# HANDOFF_TO_GPT — Reborn Build Planner

Transfert du pilotage (code, direction artistique, UI) à GPT. Ne rien réécrire de l'audit : l'historique des décisions est dans `PROJECT_STATE.md`, `CONTRACTS.md` et `REPORT_LOT*.md`.

## 1. État en une phrase
Addon WoW 3.3.5a (Interface 30300) `RebornBuildPlanner` 0.4.3-proto1 : bibliothèque de builds, éditeur, import/export, catalogue embarqué ; **aucun suivi live (Lot 4 non commencé)**. Le thème graphique v2 (`Theme.lua` + 19 TGA) existe **uniquement dans le laboratoire** et n'est pas appliqué au planner. **Kevin a refusé le rendu du prototype v2** (verdict explicite) : il n'est PAS validé visuellement.

## 2. Branches
* `main` : état stable au moment du transfert (commit `1b56a5a` + ce document).
* `dev/ultimate-ui` : branche de travail de GPT. Ne pas forcer de push.

## 3. Architecture (addon/RebornBuildPlanner/)
Ordre de chargement (= `.toc`, ordre de dépendance) :
`Util → Locale → GeneratedCatalog → Glossary → Catalog → Describe → Theme → BuildModel → Storage → Utf8 → Base64Url → Json → PlannerCodec → UIStrings → Controller → UI → Commands → Core`

| Module | Rôle |
|---|---|
| `GeneratedCatalog.lua` | Données du jeu embarquées (généré par `tools/generate_catalog.py`, **ne pas éditer à la main**). |
| `Catalog.lua`, `Describe.lua`, `Glossary.lua` | Accès catalogue, descriptions (règles officielles d'amulette), titres FR communautaires des légendaires (jamais stockés). |
| `BuildModel.lua` | Modèle de build : 4 phases, ≤ 6 objectifs de sorts, ≤ 3 bannissements, alternatives, validation. |
| `Storage.lua` | SavedVariables `RebornBuildPlannerDB` (migrations, corbeille annulable, méta : favoris/utilisés/modifiés). |
| `Utf8/Base64Url/Json/PlannerCodec.lua` | Codec d'import/export compatible avec le planner officiel (prouvé par exécution du vrai JS sous Node). |
| `Controller.lua` | Comportement sans widget (testable hors client). |
| `UI.lua` | Rendu : fenêtre unique (Mes builds / Éditeur / Importer / Exporter). Look 0.4.2 ; `Theme.lua` n'est **pas** utilisé ici. |
| `Theme.lua` | Design system v2 (voir §4). |
| `Commands.lua`, `Core.lua` | `/rbp`, `/rebornplanner`, init. |

Contraintes constantes : Lua 5.1, pas d'`OnUpdate`/timer, aucun réseau à l'exécution, lecture seule des tables `AZS_*`, widgets créés une seule fois, rien d'inventé dans les données (écarts consignés, jamais corrigés).

## 4. Theme.lua (v2)
* API : `T.Nine` (9 textures, coins fixes, bords étirés), `T.Window` (strata `FULLSCREEN_DIALOG`, niveau 100, `SetToplevel`), `T.Panel`, `T.Inset`, `T.Button(role)` (primary/secondary/danger/selected/disabled + voiles survol/appui via `SetHighlightTexture`/`SetPushedTexture`), `T.Field`, `T.Row`, `T.Slot`, `T.Icon`, `T.Tooltip`, `T.Scroll`, `T.Fit`.
* Chemin des textures : `T.media = "Interface\\AddOns\\<ADDON>\\Media\\"` ; table `T.FILES` = nom → {taille, coin[, hauteur]}.
* Palette : bleu-noir profond, bronze antique, or doux, ivoire ; rouge réservé au destructif ; sélection bleu-or.
* Modes : `textured` (v2) et `backdrop` (ancien plat, conservé **seulement** pour la comparaison du labo).
* Le fichier du labo est une **copie** de celui du planner (copiée au packaging par `tools/package_addon.py`).

## 5. Laboratoire (addon_lab/RebornPlannerThemeLab/)
`Lab.lua` : une fenêtre, deux colonnes (thème texturé / ancien plat) avec les mêmes composants ; bande de contrôle de chargement des 19 TGA (carré vert/blanc = non chargé) ; `/rbplab` ouvre, `/rbplab diag` liste capacités, strata, échelle, et les cadres affichés au-dessus du labo. Recette : `RECETTE_LAB_V2_LOT3_5B.md`.

## 6. Textures
* Source de vérité : `tools/make_textures.py` (stdlib Python, déterministe). Sortie : `addon_lab/RebornPlannerThemeLab/Media/*.tga` (19 fichiers, TGA 32 bits non compressé, puissances de 2 ≤ 128).
* Régénérer : `python -I tools/make_textures.py addon_lab/RebornPlannerThemeLab/Media --preview tests/results/texture_sheet.png` ; vérifier : `... --check` (compare octet par octet ; inclus dans `run_all.py`).
* Aperçu logiciel (≠ capture client) : `python -I tools/preview_theme.py tests/results/theme_preview.png`.
* Inventaire et provenance : `TEXTURES_INVENTORY.md` — **originales, créées pour ce projet, aucun asset tiers**.
* Le planner packagé n'embarque pas encore `Media/` : à faire quand le thème sera appliqué (le `.toc` du planner référence déjà `Theme.lua`).

## 7. Tests (commande unique)
```
python -I tools/run_all.py
```
Chaque étape finit **PASS / SKIPPED / FAIL** (sortie 0 / 3 / 1). Un SKIPPED n'est jamais un succès.
**Ressources locales non versionnées** (voir `PROVENANCE.md`) : `RBP_CATALOG_DIR` (données officielles `data/v1`) → génère `GeneratedCatalog.lua` et débloque Lot 0, générateur, 14 000+ assertions Lua ; `RBP_OFFICIAL_BUNDLE` (bundle `BYjmu0KK.js`, optionnel) → comparaison JS↔Lua. Sans elles : `test_standalone` (codec, 86 assertions) tourne seul.
Étapes : catalogue à jour, textures à jour, tests du générateur, Lot 0 (Python), Lua 5.1 standalone, Lua 5.1 catalogue (via `lupa` dans `.devtools/venv`, non versionné), JS↔Lua (Node).
Résultat de référence (avec ressources locales) : 7 PASS, 0 SKIPPED, 0 FAIL ; Lua : 225 cas, 14 282 assertions ; générateur 84 ; Lot 0 273 ; JS↔Lua 63 codes vérifiés.
Versions : Python 3.13.1 · Node v24.19.0 · Lua 5.1 (lupa 2.8).
Recréer le venv : `python -m venv .devtools/venv` puis `.devtools/venv/Scripts/pip install lupa`.
**Non exécuté** : tout test du thème v2 dans le vrai client ; les suites simulent les widgets (`tests/lua/wowstub.lua`) et **ne prouvent aucun rendu**.
## 8. API du client
Confirmées présentes par Kevin (`/rbplab diag`, client Reborn) : `SetGradientAlpha`, `SetBackdrop`, `SetHighlightTexture`, `SetPushedTexture`, `GetHighlightTexture`, `SetFontString`, `SetTextInsets`, `GetStringHeight`, `SetVertexColor`, `SetTexCoord`. Détail et inconnus : `COMPAT_CLIENT_LOT3_5B.md`.

## 9. Limites et problèmes connus
* **Rendu v2 refusé par Kevin** : motifs précis à recueillir (voir les captures qu'il enverra). Le chargement réel des TGA n'a jamais été confirmé côté développeur.
* Cause du texte du jeu visible derrière les panneaux (v1) non démontrée ; les mesures de strata sont des hypothèses. Un addon en `TOOLTIP` restera devant.
* Conseil automatique de bijou désactivé (attente de l'API proposée dans `API_PROPOSAL_JEWELRY.md`).
* Lot 4 (suivi live) non commencé ; aucune capture runtime n'existe (`tests/fixtures/runtime-captures/` vide).
* Collision éventuelle des commandes `/rbp` non vérifiée sur toutes les installations.
* Encodage : certains fichiers `docs/` ont été écrits en UTF-8 sans BOM ; relire en UTF-8.

## 10. Risques de migration
* `RebornBuildPlannerDB` : schéma versionné, migrations dans `Storage.lua` ; ne jamais renommer la globale ni supprimer de champs sans migration (perte de builds des joueurs).
* Appliquer le thème modifie toute l'UI : garder `UI.lua` 0.4.2 comme repli tant que le rendu n'est pas validé.
* `GeneratedCatalog.lua` dépend du catalogue public du site (hash de contenu `384db000d5ac311d`) ; un changement de schéma amont est refusé volontairement par le décodeur.
* **Ressources tierces exclues** (bundle officiel, copie du catalogue, `GeneratedCatalog.lua`) : voir `EXCLUDED_RESOURCES.md` et `PROVENANCE.md`. L'addon ne se charge pas sans `GeneratedCatalog.lua` (à générer localement).

## 11. Installation / désinstallation
* Planner : **générer d'abord** `GeneratedCatalog.lua` (`PROVENANCE.md`), puis copier `addon/RebornBuildPlanner/` dans `World of Warcraft\Interface\AddOns\` (ou utiliser `python -I tools/package_addon.py`, sortie dans le dossier frère `reborn-build-planner-recette-lot3-5b`). Prérequis : `AzerothSurvivors`, `AzerothSurvivorsAPI`.
* Lab : copier `RebornPlannerThemeLab/` (avec `Media/`) ; supprimer toute ancienne version avant.
* Désinstaller : supprimer le dossier d'addon ; optionnel : supprimer `WTF\Account\<compte>\SavedVariables\RebornBuildPlannerDB.lua` (supprime les builds enregistrés) et `RebornPlannerThemeLabDB.lua`.
* Ne jamais committer de SavedVariables réelles.

## 12. Prochaines étapes suggérées
1. Obtenir les captures et le motif du refus de Kevin, avant tout redessin.
2. Itérer sur le laboratoire (jamais directement sur le planner).
3. Quand approuvé : appliquer le thème à `UI.lua` + embarquer `Media/` dans le packaging du planner.
4. Puis seulement : Lot 4.

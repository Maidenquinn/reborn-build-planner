# PROVENANCE — ressources externes et ressources locales (non versionnées)

## Principe
Le dépôt ne contient **que du code, des données et des images créés pour ce projet**. Tout ce qui provient du site officiel (azreborn.com) ou d'un autre tiers est **exclu** : aucune licence ni autorisation de redistribution n'a pu être établie (vérifié le 2026-11-17 : la page d'accueil n'indique aucune licence ; les conditions d'utilisation n'accordent aucun droit de redistribution des données et interdisent la collecte en masse « au-delà des fichiers de données publics » proposés par le site).

## Ressources locales (à obtenir séparément, jamais committées)
| Ressource | Variable d'environnement | Emplacement par défaut (ignoré par git) | Usage |
|---|---|---|---|
| Fichiers du catalogue officiel `data/v1` (`index.json`, `classes.json`, `spells.json`, `jewelry.json`, `amulets.json`, `legends.json`, `i18n/frFR.json`), contenu `384db000d5ac311d` | `RBP_CATALOG_DIR` | `.local/catalog/384db000d5ac311d/` | génération de `GeneratedCatalog.lua`, tests Lot 0 / Lua 34-35, comparaison JS |
| Bundle officiel du planner `BYjmu0KK.js` (SHA-256 `df3e982b20b94fb939a3e2443bf7b3e4b29054f264fe0958ad01183b3d3d2c1c`) | `RBP_OFFICIAL_BUNDLE` | `.local/reference/BYjmu0KK.js` | **optionnel** : comparaison JS↔Lua et régénération des vecteurs |

## Générer le catalogue Lua
```
set RBP_CATALOG_DIR=<dossier data/v1>        (PowerShell : $env:RBP_CATALOG_DIR = "...")
python -I tools/generate_catalog.py          # écrit addon/RebornBuildPlanner/GeneratedCatalog.lua (ignoré par git)
```
**Sans ce fichier, l'addon ne se charge pas dans le jeu** (le `.toc` le référence) : il faut le générer avant tout packaging (`tools/package_addon.py`). Le dépôt ne fournit donc volontairement pas un addon installable « tel quel ».

## Ce qui reste versionné (et pourquoi)
* `tests/fixtures/synthetic/*.json` : scénarios créés par `tools/make_synthetic_fixtures.py` (héros et valeurs fictifs).
* `tests/fixtures/codec/golden.json`, `cross.json` : **vecteurs de test produits par exécution** (codes d'export `azsb1:` de plans que nous avons composés, avec clés de sorts). Ils ne contiennent pas le code du site ni les fichiers du catalogue. Régénérables avec le bundle local (`tools/gen_codec_golden.mjs`, `tools/gen_codec_cross.mjs`). À reconsidérer si un ayant droit s'y oppose.
* `addon/RebornBuildPlanner/Glossary.lua`, `docs/GLOSSARY_FR.md` : titres français de légendaires issus de sources communautaires, jamais stockés dans les données ; provenance dans `GLOSSARY_FR.md`.
* Textures : `TEXTURES_INVENTORY.md` (19 TGA originales, générées par `tools/make_textures.py`).
* Aucune licence logicielle n'est encore attachée au dépôt : **à décider par Kevin / GPT** avant toute publication.

## Comportement des tests sans ressources locales
`python -I tools/run_all.py` distingue **PASS / SKIPPED / FAIL** (code de sortie 0 / 3 / 1). Sans catalogue : les étapes dépendantes sont `SKIPPED` avec la raison ; `test_standalone` (codec, Base64url, JSON, UTF-16, 86 assertions sur les vecteurs `golden.json`) s'exécute seul. Sans bundle : seule la comparaison JS↔Lua est `SKIPPED`. Un `SKIPPED` n'est jamais un succès.
# Reborn Build Planner

Addon WoW 3.3.5a (Interface 30300) pour Azeroth Survivors Reborn : bibliothèque de builds, éditeur, import/export compatible avec le planner officiel. Version de travail 0.4.4-alpha-UltimateUI. **Dépôt privé.**

Pour reprendre le développement, lire d'abord **[docs/HANDOFF_TO_GPT.md](docs/HANDOFF_TO_GPT.md)**, puis `docs/PROJECT_STATE.md`.

## Indispensable : générer `GeneratedCatalog.lua` en local
Le fichier `addon/RebornBuildPlanner/GeneratedCatalog.lua` est référencé par le `.toc` mais **n'est pas dans le dépôt** (données du site officiel, redistribution non autorisée : voir [docs/PROVENANCE.md](docs/PROVENANCE.md) et [docs/EXCLUDED_RESOURCES.md](docs/EXCLUDED_RESOURCES.md)). **Sans lui, l'addon ne se charge pas.**

1. Obtenir séparément les fichiers `data/v1` du catalogue officiel (`index.json`, `classes.json`, `spells.json`, `jewelry.json`, `amulets.json`, `legends.json`, `i18n/frFR.json`, contenu `384db000d5ac311d`) et les placer dans un dossier, par exemple `.local/catalog/384db000d5ac311d/` (ignoré par git).
2. Générer :
   ```
   # PowerShell
   $env:RBP_CATALOG_DIR = "C:\chemin\vers\384db000d5ac311d"   # inutile si le dossier est .local/catalog/384db000d5ac311d
   python -I tools/generate_catalog.py
   ```
   Cela écrit `addon/RebornBuildPlanner/GeneratedCatalog.lua` (ignoré par git).
3. Packager / installer : `python -I tools/package_addon.py`, ou copier `addon/RebornBuildPlanner/` dans `Interface\AddOns\`.

## Nouveau : informations de bijoux et d'anneaux depuis l'installation locale

Le site officiel ne publie pas les effets de `jewelry.json`, mais le client Reborn contient des métadonnées de comportement. Un générateur **indépendant, en lecture seule** permet d'enrichir l'inspecteur sans copier de code ASRAdvisor :

```powershell
$env:RBP_CATALOG_DIR = "C:\chemin\vers\data\v1"
$env:RBP_GAME_EXE = "C:\chemin\vers\executable-du-jeu.exe"
python -I tools/package_addon.py
```

Le script vérifie les clés et emplacements contre le catalogue. Il refuse toute extraction incomplète. Les données générées restent dans `.local/generated/GeneratedJewelryMechanics.lua` (ignoré par Git). Le packaging les copie uniquement dans le dossier installable ; le fichier vide versionné reste inchangé. Sans exécutable local, le planner reste fonctionnel et utilise uniquement ce que les API exposent réellement.

Le panneau Détails peut alors afficher un type de bonus et sa valeur de base **sans les présenter comme des statistiques actuelles**. Voir [docs/JEWELRY_SOURCE_AUDIT.md](docs/JEWELRY_SOURCE_AUDIT.md).

Optionnel : `RBP_OFFICIAL_BUNDLE` (chemin du bundle officiel `BYjmu0KK.js`) active la comparaison JS↔Lua.

## Tests
```
python -I tools/run_all.py
```
Chaque étape finit PASS, SKIPPED ou FAIL (sortie 0 / 3 / 1). Sans catalogue, seules les étapes autonomes s'exécutent (le reste est SKIPPED, jamais « réussi »). Lua 5.1 via `lupa` dans `.devtools/venv` (non versionné) : `python -m venv .devtools/venv` puis `.devtools/venv/Scripts/pip install lupa`.

## Contenu
`addon/` planner · `addon_lab/` laboratoire graphique (textures TGA originales dans `Media/`, générées par `tools/make_textures.py`) · `tools/` générateurs et exécuteurs · `tests/` Lua / Python / Node · `docs/` documentation.

**Statut visuel :** le thème Ultimate UI v3 est effectivement chargé dans Reborn selon les captures du testeur. Il progresse, mais la qualité visuelle est encore en cours de recette ; le Lot 4 n'a pas commencé.
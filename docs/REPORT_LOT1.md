# Rapport de fin de lot — LOT 1 (catalogue, modèle, stockage)

**Verdict : PASS.** Catalogue généré et vérifié, modèle indépendant de l'interface, stockage migrable sans perte, tests Lua exécutés **réellement sous Lua 5.1** sur les vrais fichiers de l'addon, tests du Lot 0 toujours verts. « Compatible client » n'est **pas** annoncé : aucun test en jeu (voir §6).

## 1. Fichiers

**Créés** (`reborn-build-planner/`)
* Addon : `addon/RebornBuildPlanner/{Util,Locale,GeneratedCatalog,Catalog,BuildModel,Storage}.lua`
* Générateur : `tools/generate_catalog.py` → `GeneratedCatalog.lua` (110 396 octets) + `tests/results/catalog_report.txt`
* Tests Lua : `tests/lua/{harness,run,test_catalog,test_model,test_storage,test_sandbox}.lua` ; tests générateur : `tests/py/test_generator.py`
* Outils : `tools/run_lua_tests.py`, `tools/run_all.py` (+ `tests/results/last_run.txt`), `.gitignore`
* Docs : `docs/REPORT_LOT1.md` ; `docs/CONTRACTS.md` §7 ; `docs/PROJECT_STATE.md` (mis à jour)

**Modifiés** : `RebornBuildPlanner.toc` (ordre de chargement, `SavedVariables: RebornBuildPlannerDB`), `Core.lua` (câblage `ADDON_LOADED`), `tools/check_env.py` (détecte l'interpréteur isolé). Aucun livrable du Lot 0 remplacé ; ses 273 assertions sont inchangées.

## 2. Décisions d'architecture

* **Catalogue** : Python hors jeu → Lua pur donnée. Refuse (exit 2/3, **aucune sortie écrite, sortie existante intacte**) un schéma ≠ 1, un index illisible, un compteur faux, un champ manquant, une clé/id en double, une référence orpheline, une clé de légendaire ≠ `legendary:<sort>`. Les anomalies sémantiques sont des **avertissements consignés dans le catalogue** : `call_of_flame` (marqué légendaire, aucune ligne `legends.json`) est signalé, aucune amulette inventée, JSON source jamais modifié (hash du dossier vérifié avant/après). Déterministe (deux générations = mêmes octets, hash de corps dans `meta`).
* **Catalogue embarqué** : classes, sorts, bijoux, amulettes, légendaires, index (par classe/slot, homonymes, icônes partagées), traductions `frFR` **indexées par le nom anglais** (310/317 noms ; légendaires : aucune traduction dans les données, repli EN). `talents`, `caps`, `set_bonuses`, `zones` ne sont pas embarqués au Lot 1 (listés comme « non utilisés »). Noms et icônes ne servent jamais d'identifiant.
* **Modèle** : fonctions pures, builds = tables plain data. Édition fonctionnelle (copie → validation → `revision+1`) ; **refus sur erreur ou nouveau conflit**, tolérance des conflits importés (signalés, jamais supprimés). Trois gravités `error / conflict / warning`. `Normalize` est total (jamais d'exception sur donnée arbitraire).
* **Stockage** : migration sur copie profonde + comptage + validation + sauvegarde embarquée ; handle **lecture seule** pour schéma futur/invalide/migration échouée (la table d'origine est rendue intacte, `Core` ne l'assigne pas) ; quarantaine plutôt que suppression ; corbeille annulable ; import tout-ou-rien.
* **Isolation** : seule globale écrite = `RebornBuildPlanner` ; seule globale propre = `RebornBuildPlannerDB`. Aucun `AZS_*`, aucune commande, aucun réseau.
* **Ordre `.toc`** : Util → Locale → GeneratedCatalog → Catalog → BuildModel → Storage → Core ; les modules font un `assert` sur leurs dépendances au chargement (un ordre faux échoue franchement, testé).

## 3. Environnement exact

| Élément | Valeur |
|---|---|
| OS | Windows 11 Home 10.0.26200 |
| Python | 3.13.1 (exécution `-I`, stdlib seule pour générateur/Lot 0) |
| Node | 24.19.0 (golden du codec, Lot 0) |
| Lua | **Lua 5.1** embarqué dans `lupa 2.8` (module `lupa.lua51`), venv isolé `.devtools/venv` du projet (15 Mo, ignoré par git). Installé par `python -m venv .devtools\venv` puis `pip install lupa`, sans privilèges, sans toucher au jeu. Pas de binaires `lua`/`luac` (non nécessaires) |
| Jeu | installation et addons lus en lecture seule (54 ancres du Lot 0) ; aucun fichier modifié |

## 4. Résultats (`python -I tools/run_all.py`, exit 0)

| Étape | Résultat réel |
|---|---|
| Catalogue à jour (`--check`) | identique à la régénération |
| Générateur (`tests/py/test_generator.py`) | **84 assertions, 0 échec** (déterminisme, hash, 22 refus dont schéma futur, JSON source intact, anomalie, classe inconnue acceptée) |
| Lot 0 (`tools/run_tests.py`) | **273 assertions, 0 échec** (54 ancres, codec golden…) |
| Lua 5.1 (`tools/run_lua_tests.py`) | **57 cas de test, 2 144 assertions, 0 échec** : catalogue 14 cas, modèle 19, stockage 18, sandbox/toc 6 (le nombre d'assertions est gonflé par des boucles sur les 241 sorts/237 légendaires ; le nombre de cas est la mesure honnête) |

Un test négatif accidentel (commentaire avalant une ligne d'`Storage.lua`) a fait tomber 231 assertions : les tests détectent bien les régressions.
Couverture demandée → catalogue : 12 classes, clés uniques, FR + repli EN, références orphelines, homonymes, icônes partagées, données manquantes, catalogue invalide/futur, hash déterministe ; modèle : création, copie, révision, 6 sorts + 3 bannissements, conflit, trous d'alternatives, 4 phases dont vides, clés inconnues, réordonnancement stable, rangs, talents/stats/notes/liens, validation sans mutation ; stockage : init, rechargement via **texte SavedVariables réel rechargé**, plusieurs builds/classe, actif par classe, suppression/duplication, migration réussie / interrompue / lossy / non copiable, restauration depuis la sauvegarde, version future, entrées corrompues, inconnu préservé, aucun SV étranger lu ni modifié.

## 5. Relancer

```bash
python -I tools/run_all.py                      # tout (exit 0 = PASS, 3 = Lua indisponible, 1 = échec)
python -I tools/generate_catalog.py             # régénère GeneratedCatalog.lua + rapport
.devtools\venv\Scripts\python.exe tools\run_lua_tests.py [test_model]   # Lua seul (un fichier au choix)
python -I tests/py/test_generator.py            # générateur seul
```
Sans l'interpréteur isolé : `python -m venv .devtools\venv` puis `.devtools\venv\Scripts\python.exe -m pip install lupa` (réseau requis **pour l'outil de test uniquement**). Sans lui, `run_all.py` rend le code 3 (PASS CONDITIONNEL), jamais un faux vert.

## 6. Écarts Lua 5.1 isolé ↔ client 3.3.5a

1. **Interpréteur** : PUC Lua 5.1 (lupa) ; le client embarque un fork 5.1.x de Blizzard. Même langage, bibliothèques et comportements limites possiblement différents.
2. **Bibliothèques** : le harnais n'expose que `string table math type pairs ipairs next select tostring tonumber pcall xpcall error assert setmetatable getmetatable rawget rawset rawequal unpack` (+ `time`, `CreateFrame` fournis) et **enregistre** toute lecture d'une autre globale : aucun `io/os/require/package/load*/debug` n'est utilisé (test). Un scan de source interdit `goto`, `//`, `table.unpack`, `bit32`, `_ENV`, `\z`, `load`.
3. **Globales WoW** : seules `time` et `CreateFrame` sont simulées (stub minimal). `GetLocale`, `ADDON_LOADED` réel, l'ordre de chargement des SavedVariables, `RegisterEvent` ne sont **pas** testés en jeu.
4. **SavedVariables** : le « rechargement » utilise un sérialiseur de test (texte `Nom = {...}` exécuté en environnement vide), pas celui du client (précision des nombres, taille réelle du fichier). L'échelle : 200 builds vides ≈ 568 Ko dans ce sérialiseur indenté.
5. **`string.format("%x")`** passe par un `long` 32 bits sous Windows (cf. `AZS.Fmt`, `Core.lua:84`) : les ids utilisent l'heure modulo 2³¹. Les chaînes Lua sont des octets dans les deux cas : limites de texte en **octets** ; le site compte des unités UTF-16 (Lot 2).
6. **Pas de mesure** de mémoire ni de temps dans le client.

## 7. Limites et risques

* Aucune validation client (reste `VALIDATION_PLAN.md` : `P-*`, inchangé) ; `Core.lua` (ADDON_LOADED + assignation de la globale) est testé seulement en sandbox.
* Une seule migration réelle (schéma 0 = format prototype interne **jamais livré**) : le mécanisme est prouvé, pas un historique de formats.
* `GeneratedCatalog.lua` pèse 110 Ko et se charge entier : coût mémoire/chargement non mesuré en jeu.
* Les noms traduits des légendaires n'existent pas dans les données : en français elles s'affichent en anglais.
* `Storage.Update` fait confiance à la `revision` croissante fournie par `BuildModel` ; pas de verrou inter-sessions (un seul client écrit).
* La sauvegarde de migration double temporairement la taille de la base tant que `DropBackups` n'est pas appelé (pas d'UI encore).
* `Duplicate` ajoute « (copy) / (copie) » selon `Locale.lang` ; aucune détection de langue du client encore.

## 8. Critères

| Critère PASS | État |
|---|---|
| Catalogue généré et vérifié | ✔ 5 sections, 0 erreur, 4 avertissements (2 homonymes, `call_of_flame`, légendaires non traduites) |
| Modèle sans interface | ✔ aucun widget, aucune dépendance AZS |
| Bibliothèque conserve builds et informations | ✔ aller-retour réel, ext/notes/stats/talents conservés |
| Migrations testées non destructives | ✔ copie, comptage, sauvegarde, lecture seule en cas d'échec |
| Inconnus non effacés | ✔ clés, champs, classes, réglages, quarantaine |
| Tests Lua réellement passés | ✔ Lua 5.1, vrais modules |
| Lot 0 vert | ✔ 273/273 |
| Aucun addon/profil du jeu modifié | ✔ lecture seule ; sentinelles AZS/ASBuilder/FieldKit/Stats intactes en test |
| Décisions documentées | ✔ `PROJECT_STATE.md`, `CONTRACTS.md` §7 |
FAIL aurait été : perte possible de build, migration destructive, altération d'un autre addon, structure incompatible avec le codec — aucun constaté.

## 9. Préparation du Lot 2 (codec `azsb1:`)

* Atterrissage : `BuildModel.Normalize` (+ `Storage:Add/ImportBuilds`) reçoit le résultat du décodeur ; l'aperçu d'import = `Normalize` sans `Add`.
* Mapping à figer : phase site `[label, spells, banish, rings, trinkets, amulets, stats, notes, link]` ↔ phase modèle (`spells` → objectifs `acquire` ; `stats` par index = `BuildModel.STAT_KEYS`, **même ordre que le site** ; label `""` = défaut ; légendaires `legendary:<spell>` ↔ clé du catalogue). Les trous des alternatives et les phases `null` correspondent déjà au modèle (4 positions fixes, 4 phases).
* Non représentable à signaler à l'export : objectifs `rank`/`unlimited`, `ext` et champs inconnus, phases au-delà de 4, `catalog`, `revision`.
* À implémenter côté codec : décodage tolérant comme le site (clé d'une autre classe écartée côté site, **conservée avec conflit** chez nous : décider si l'import web doit imiter le site ou garder le conflit — recommandé : garder + prévisualiser), limites en **unités UTF-16**, base64url sans padding, rejet sans mutation. Vecteurs : `tests/fixtures/codec/golden.json` (8 + 25 cas) ; le Lot 2 doit relire ces vecteurs depuis Lua 5.1.
* Prérequis restant : `P-W1` (aller-retour navigateur) pour déclarer le format interopérable.

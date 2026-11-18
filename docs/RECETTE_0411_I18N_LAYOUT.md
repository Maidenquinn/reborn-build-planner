# Recette 0.4.11-alpha-localized — localisation officielle et textes sans débordement

## Retour client

Capture du 18 novembre 2026 sur 0.4.10 : langue russe sélectionnée, onglets/cycles partiellement russes, libellés d'actions et de sections en anglais, noms de sorts, classes, bijoux et amulettes en anglais ; certains boutons se chevauchent ou dépassent leur zone (Renommer, filtres, catégories).

## Cause principale confirmée

Avant ce lot, `tools/fetch_catalog_public.py` n'obtenait que 7 fichiers, dont **seul** `i18n/frFR.json`. `generate_catalog.py` ne générait que des noms français ; `Controller.lua` demandait la traduction du catalogue uniquement si `lang == "frFR"`. Les autres langues du menu ne pouvaient donc pas traduire les noms du jeu, même si les données officielles les publient.

La documentation publique `https://azreborn.com/guides/data-api` confirme la disponibilité de `i18n/<locale>.json` pour 11 langues autres que l'anglais : `deDE`, `frFR`, `esES`, `ptBR`, `ruRU`, `itIT`, `plPL`, `trTR`, `jaJP`, `zhCN`, `koKR`.

## Corrections

1. Le fetcher télécharge désormais tous les dictionnaires officiels **présents dans l'index réel** (17 fichiers actuellement), sans supposer la disponibilité de langues absentes du manifeste.
2. Le générateur embarque leurs traductions de noms dans `GeneratedCatalog.lua`, pour les sorts, les classes, les anneaux, bijoux et amulettes lorsque les sources les fournissent. Les clés stables du jeu sont intactes.
3. Le contrôleur demande `self:Lang()` pour toutes les requêtes au catalogue, plus seulement le français. Bibliothèque et catalogue recherchent aussi les noms de la langue choisie, en conservant les alias EN/FR.
4. `Utf8.CaseFold` permet des recherches simples insensibles à la casse pour le russe, l'ukrainien, les langues latines et des signes d'Europe centrale (dans les plages explicitement couvertes par l'implémentation).
5. Les boutons mesurent désormais les glyphes avec `FontString:GetStringWidth()` et raccourcissent leur libellé **uniquement lorsque nécessaire**, en coupant uniquement entre les caractères UTF-8.
6. Les filtres de la bibliothèque, les onglets du navigateur, le champ de nom du build et celui de l'import ont été réalignés pour laisser de la place aux traductions.
7. Les libellés de groupes d'équipement et les statuts du navigateur utilisent aussi le budget du texte mesuré.
8. Traductions russes enrichies pour le parcours principal du planner : vue bibliothèque, filtres, priorités, équipements, actions et descriptions d'interface. **Ce n'est pas une localisation complète de tous les modules**.

## Preuves des tests GitHub Actions

Au commit de recette 0.4.11 :
- Catalogue public : **17 fichiers**, hash `6637f92a3903d44c`.
- Noms officiels localisés : deDE 314, esES 317, frFR 310, itIT 315, jaJP 317, koKR 317, plPL 314, ptBR 315, ruRU 317, trTR 313, zhCN 317. Il s'agit du nombre de noms distincts traduits des catégories collectées (pas du pourcentage de l'interface).
- **237 cas Lua 5.1**, **17 426 assertions**, **0 échec** ; générateur **85 assertions**, **0 échec**.
- Vérification des noms officiels dans plusieurs langues, des recherches Unicode, du déroulé intégral en russe et de l'affichage initial dans les 15 langues proposées.
- Source checks et private preview package : **PASS**.
- Package CI sans extraction propriétaire. La recette privée locale récupère toujours les 44 mécaniques depuis ton exécutable Windows.

## Construction locale sans modifier le jeu

Depuis `H:\Users\kevin\Documents\ChatGPT\AzerothSurvivorReborn\reborn-build-planner` :

```powershell
git switch dev/ultimate-ui
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors" -GameExe "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\AzerothSurvivorsGame.exe"
```

Sortie attendue : `dist\ultimate-0.4.11-local\RebornBuildPlanner-0.4.11-alpha-localized-recette.zip`.

Sauvegarder l'addon installé et les SavedVariables, fermer le jeu, puis remplacer le répertoire de l'addon.

## Contrôles en jeu

- `/rbp diag` annonce `0.4.11-alpha-localized`, le catalogue courant et `44/44` mécaniques si ton exécutable n'a pas changé.
- Russe : sorts et anneaux officiellement traduits, navigation principale russe, autres chaînes inconnues en anglais (pas de texte vide).
- Renommer, Enregistrer, filtres, onglets Sorts / Anneaux / Bijoux / Amulettes : aucune superposition ni texte hors bouton. Une étiquette très longue peut finir par « ... » ; dans ce cas l'action doit rester compréhensible.
- Basculer FR/EN/RU/DE puis `/reload` : vérifier la langue et l'absence de données perdues.
- Vérifier les polices pour chinois/japonais/coréen dans le vrai client : le harness Lua ne valide pas les glyphes réels ni les fontes disponibles.
- Vérifier recherches en russe avec majuscules/minuscules.

## Limites

- Le dictionnaire officiel ne traduit pas tous les titres d'amulettes légendaires. Les parties absentes retombent sur l'anglais et les titres communautaires restent identifiés comme tels.
- Le site ne publie pas d'i18n pour `csCZ`, `roRO`, `ukUA` dans le contrat documenté : ces langues restent à couverture d'interface partielle et noms d'objets généralement anglais.
- La localisation du texte UI complet, des messages complexes et de toutes les descriptions est un lot distinct. **Ne pas revendiquer 100 %**.
- Aucun test visuel 0.4.11 dans le vrai client n'a encore eu lieu. `main` inchangée, aucune release.

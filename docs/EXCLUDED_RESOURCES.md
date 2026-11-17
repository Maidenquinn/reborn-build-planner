# Ressources exclues du dépôt (transfert GitHub)

Réécriture de l'historique **local** (avant tout push), autorisée par Kevin, pour supprimer de **tous** les commits :

| Chemin retiré | Nature | Raison |
|---|---|---|
| `tests/fixtures/codec/reference/BYjmu0KK.js` (388 Ko) | bundle JavaScript du site officiel | code tiers, droits de redistribution non établis |
| `tests/fixtures/catalog/**` (7 fichiers JSON) | copie brute du catalogue officiel `data/v1` | données tierces, aucune licence ; les conditions d'utilisation n'autorisent pas la redistribution |
| `addon/RebornBuildPlanner/GeneratedCatalog.lua` | catalogue Lua généré à partir de la copie ci-dessus | dérivé direct des données officielles ; conditions non établies → génération locale (`docs/PROVENANCE.md`) |

Conservés : générateurs, modèles Lua, code, tests originaux, fixtures synthétiques, vecteurs `golden.json` / `cross.json` (sorties d'exécution), glossaire, 19 textures TGA originales, documentation de provenance. Aucune autre copie substantielle n'a été trouvée (recherche des noms de sorts du catalogue dans tous les fichiers suivis : aucun fichier restant n'en contient 15 ou plus).

Sauvegarde locale complète avant réécriture : dossier `reborn-build-planner-BACKUP-pre-rewrite` et `reborn-build-planner-pre-rewrite.bundle` (côte à côte avec le projet, **jamais poussés**).
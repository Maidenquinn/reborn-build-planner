# Proposition d'API pour SNX : effets des anneaux et bijoux

**Constat (Lot 3.4, audit du 2026-11-17).** Les fichiers publiés `https://azreborn.com/data/v1/` donnent, pour les **amulettes** (`amulets.json`, `legends.json`), les effets au rang 1 et la règle de croissance. Pour les **anneaux et bijoux**, `jewelry.json` ne contient que `key`, `name`, `icon`, `slot` (44 entrées) : **aucun effet, aucune statistique, aucune croissance**. Le planner n'invente rien : il affiche « Effet détaillé indisponible ».

**Sources natives vérifiées et écartées** (lecture seule, addons installés) :
| Source | Contenu | Pourquoi insuffisante |
|---|---|---|
| `AzerothSurvivors/Generated/Content.lua` (`AZS_GEN.jewels`) | clé, nom, icône | même contenu que `jewelry.json` ; aucun effet |
| `AZSCARDS` (`mode~rarity~icon~name~effect~detail~note~slot`) | effet de la pièce **proposée** | n'existe qu'en partie, pour la pièce offerte ; pas de clé de catalogue ; pas déterministe hors run |
| `AZS_GEAR` (`slot, rarity, bonus, amount, icon, name, text`) | pièce **possédée** | pas de clé de catalogue (identité non fiable) ; `amount` n'est pas un rang général (contrat Lot 0) ; runtime seulement |
| `AZS_SPELLTIPS` / `AZSCARDTIP` | texte de sort | sorts, pas pièces |

**Demande.** Ajouter à `jewelry.json` (exemple : valeurs FICTIVES, schéma seulement) (champs ajoutés seulement, conformément à la politique « v1 n'enlève ni ne renomme ») les mêmes champs que `amulets.json` :
```json
{ "key": "accuria", "name": "Band of Accuria", "icon": "INV_Jewelry_Ring_15", "slot": "ring",
  "growth": 0.5,
  "effects": [ { "stat": "crit", "value": 0.04 } ],
  "special": null }
```
* `effects` : liste `{ "stat", "value" }`, `stat` parmi les clés déjà publiées pour les amulettes ; même convention (une valeur est une part, sauf `regen`, `kill_heal`, `lives`, `targets`).
* `growth` ou `null` + un champ `fixed` comme pour les légendaires, si la croissance diffère ; sinon la règle `3 - 2 x (1 - growth / 2) ^ (rank - 1)` documentée s'applique.
* `special` : `null`, un nom, ou `{ nom: part }`, comme les amulettes.
* Si certaines pièces ont une description libre dans les données du jeu, un champ `text` (anglais, traduit via `i18n/<locale>.json`) suffirait pour un premier affichage.
* Les clés restent celles de `jewelry.json` (stables, uniques) ; `AZSGEAR` gagnerait un champ `key` pour identifier une pièce possédée sans passer par son nom.

**Ce que fera le planner ensuite** : le générateur (`tools/generate_catalog.py`, déjà prévu pour des champs ajoutés non nuls) embarque les nouveaux champs, `Describe.lua` les formate avec les mêmes règles que les amulettes, et les tests comparent le Lua au JSON publié. Aucun code côté jeu n'est requis de SNX, uniquement l'extension du fichier publié.

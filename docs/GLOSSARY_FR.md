# Glossaire FR/EN des titres de légendaires

## Officiel vs communautaire (présentés séparément)

**Traductions officielles** (fichier publié `i18n/frFR.json`, contenu `384db000d5ac311d`) : noms de **sorts**, d'**anneaux et bijoux**, des **22 amulettes fixes** et des classes. Utilisées telles quelles.

**Aucun titre de légendaire n'est traduit officiellement** : les 21 « têtes » (la partie avant le nom du sort : « Eye of the Splitting Sky: Cleave ») sont absentes de `i18n/frFR.json` (0 sur 21) et les textes du jeu les affichent en anglais.

**Traductions communautaires** : le tableau ci-dessous est une **proposition écrite pour cet addon**, **non officielle**, maintenable dans `addon/RebornBuildPlanner/Glossary.lua` (source unique ; ce fichier en est tiré à chaque livraison). Elles sont à relire par la communauté FR ; une correction = une ligne à changer, sans toucher aux builds enregistrés.

## Règles
* **Clé stable** : l'identité d'une légendaire est `legendary:<sort>` (jamais son titre, jamais son icône). Le glossaire est indexé par la **tête anglaise** (champ `head` des données) et ne sert qu'à l'affichage ; les SavedVariables ne contiennent que la clé (testé).
* **Composition déterministe** : `<tête communautaire> : <nom du sort traduit par i18n/frFR.json, sinon anglais>`. Les entrées dont le titre est la tête seule affichent la tête seule.
* **Précédence** : une traduction officielle du titre entier (si les données en portaient une) l'emporte ; sinon glossaire communautaire ; sinon **repli anglais**.
* **Homonymes** : plusieurs légendaires de classes différentes partagent un titre (ex. « The Eternal Talisman: Metamorphosis »). Les listes affichent d'abord le **nom du sort**, puis `tête | classe` ; l'inspecteur indique la classe et le sort lié, et mentionne « traduction communautaire, non officielle ».
* Autres langues : aucune entrée ; titre anglais.

## Têtes (21) — proposition communautaire

| Tête anglaise (officielle) | Proposition française (communautaire) | Légendaires concernées |
|---|---|---|
| The Eternal Talisman | Le Talisman éternel | 44 |
| Eye of the Splitting Sky | Œil du Ciel fendu | 36 |
| Medallion of the Bladestorm | Médaillon de la Tempête de lames | 30 |
| Heart of the Earthshaker | Cœur du Secoueur de terre | 23 |
| Pendant of the Plague | Pendentif de la Peste | 21 |
| Amulet of the Inferno | Amulette du Brasier | 19 |
| Breath of the Black Dragon | Souffle du Dragon noir | 17 |
| Charm of the Fated Hour | Charme de l'Heure fatidique | 8 |
| Stormcaller's Amulet | Amulette de l'Invocateur de tempête | 7 |
| The Legionlord's Medallion | Médaillon du Seigneur de la Légion | 7 |
| The Reaper's Amulet | Amulette du Faucheur | 6 |
| Talisman of the Tempest | Talisman de la Tempête | 6 |
| Amulet of the Ancients | Amulette des Anciens | 5 |
| Earthshatter Seal | Sceau brise-terre | 1 |
| Emberwake Pendant | Pendentif du Sillage de braise | 1 |
| Winter's Embrace | Étreinte de l'hiver | 1 |
| Cinderheart Pendant | Pendentif Cœur de cendre | 1 |
| Eye of the Tempest | Œil de la Tempête | 1 |
| Magmaheart Pendant | Pendentif Cœur de magma | 1 |
| Cinderlash Pendant | Pendentif Fouet de cendre | 1 |
| Eye of Leotheras | Œil de Léotheras | 1 |

Spells dont le nom français est identique à l'anglais (absents d'`i18n/frFR.json` pour cette raison) : Rupture, Dispersion, Pestilence, Blizzard, Corruption.

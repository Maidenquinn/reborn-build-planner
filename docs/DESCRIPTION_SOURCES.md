# Matrice des sources de descriptions (mise à jour Lot 3.4)

Source principale : **données publiées** `https://azreborn.com/data/v1/` (guide `https://azreborn.com/guides/data-api`), embarquées par `tools/generate_catalog.py` v2 (hash de contenu inchangé : `384db000d5ac311d`). Ce que le générateur v1 avait **perdu** et que la v2 conserve sans modification : `amulets.json` → `growth`, `effects`, `special`, `world`, `needs` ; `legends.json` → `template`, `form`, `effects`, `growth`, `fixed`. (Un test compare chaque enregistrement Lua au JSON publié.)

| Élément | Source | Utilisée | Détail |
|---|---|---|---|
| Amulette fixe (22) | `amulets.json` | **Oui** (`Describe.lua`) | effets au rang 1 (parts en %, sauf `regen`, `kill_heal`, `lives`, `targets`), spécial, croissance (formule officielle `3 - 2 x (1 - growth / 2) ^ (rang - 1)`, rangs 2, 3, 5), classes, monde, prérequis « soin ». Les `targets` ne reçoivent pas de valeur au rang 5 (croissance « par paliers entiers » non spécifiée). |
| Amulette légendaire (237) | `legends.json`, clé `legendary:<sort>` | **Oui** | effets tels que le jeu les écrit (nom + paramètres) ; unités appliquées seulement là où le guide les donne (`share`, `chance` en %, `secs` en s) ; croissance ou valeur `fixed` (formule linéaire, plafond rang 11) ; origine (`template`, `form`). Noms d'effets non traduisibles sans deviner : affichés tels quels. Les titres ne sont **pas** uniques (ex. « The Eternal Talisman: Metamorphosis » existe pour deux classes) : seule la clé identifie. |
| Anneau / bijou (44) | `jewelry.json` | Nom, emplacement, icône | **Aucun effet publié** ; `Content.lua`, `AZSCARDS`, `AZS_GEAR` écartés (voir `API_PROPOSAL_JEWELRY.md`) |
| Sort | texte natif du jeu (`GameTooltip:SetHyperlink("spell:<id>")`, lu une fois par sort, mis en cache, **affiché seulement dans le panneau Détails**) | Oui | fidélité à Reborn à confirmer en client ; `spells.json` ne contient pas de description (le guide le dit : « What is not in the files: spell descriptions ») |
| Bonus de set | `set_bonuses.json` | Non | publié mais non embarqué : hors périmètre de ce lot |
| Traductions officielles | `i18n/frFR.json` | Noms de sorts, anneaux/bijoux, amulettes fixes (22/22), classes | **Les titres de légendaires et leurs têtes ne sont pas traduits** (0/21 têtes) |
| Traductions communautaires | `Glossary.lua` (voir `GLOSSARY_FR.md`) | 21 têtes de légendaires, **proposition non officielle**, indexées par tête anglaise | affichage seulement ; les clés `legendary:<sort>` restent l'identité |

Règle d'affichage : une valeur numérique n'est montrée que si un enregistrement la porte ou si la règle officielle la calcule ; sinon « Effet détaillé indisponible ».

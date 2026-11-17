# Rapport — LOT 3.5, étape 1 : diagnostic, prototype graphique, localisation

**État : PROTOTYPE LIVRÉ, thème NON approuvé.** Conformément à la demande (« livrer d'abord un prototype »), l'éditeur complet n'a **pas** été refait : le style n'est appliqué à l'interface entière qu'après validation visuelle de Kevin. Je n'ai **aucune capture du client côté développeur** : rien ci-dessous n'affirme que le rendu est beau, seulement ce qui est construit, testé et ce que le laboratoire doit prouver.

## A — Diagnostic (`DIAGNOSTIC_RENDU.md`)
Observé sur vos captures : boutons gris uniformes, fenêtre en aplats noirs, textes de même gris, titres de légendaires tronqués. Déduit du code : boutons à `SetBackdrop` plats sans états propres, étiquettes colorées par codes `|cff` (même gris pour tous les « quiet »), `InputBoxTemplate` et `UIPanelScrollFrameTemplate` encore natifs, environ 40 couleurs en dur, polices 10 pt. **Inconnu** : pourquoi le gris paraît plus clair que codé ; la réponse viendra du laboratoire.

## B — Design system et laboratoire
* **`Theme.lua`** (chargé par le planner, non encore utilisé) : palette (bleu-noir, ardoise, bronze, ivoire, or, vert, rouge ; rareté), typographie (4 niveaux sur polices du jeu), surfaces (fenêtre à double liseré bronze, panneau, creux, carte) en **dégradé vertical + bordure de 4 textures + liseré de lumière**, boutons à 5 looks (principal, secondaire, destructif, sélectionné, désactivé) avec **états survol/appui fournis par le client** (textures de surbrillance/appui teintées, aucun script), champ de recherche avec placeholder et bordure dorée au focus, ligne de liste (bande, survol, sélection bleu profond + barre dorée), icône à bordure colorée par rareté, case d'équipement à zones réservées, infobulle thématique dimensionnée par son contenu et gardée à l'écran. **Aucun modèle Blizzard**, aucun `OnUpdate`, aucun hook.
* **`RebornPlannerThemeLab`** (3 fichiers, addon séparé) : `/rbplab` affiche l'écran d'échantillon demandé (panneaux, titre/sous-titre, 3 boutons + sélectionné + désactivé, recherche, ligne de sort, case d'équipement pleine/vide/choisie, entrée de catalogue, infobulle) **deux fois côte à côte** : nouveau rendu et ancien (0.4.2). `/rbplab diag` liste les capacités réelles du client ; un carré de contrôle vérifie le sens du dégradé (`/rbplab flip` si inversé). Procédure : `RECETTE_LAB_LOT3_5.md`.
* Limites assumées : `SetGradientAlpha` (7 addons natifs, sens établi par `Passage.lua`) et `SetPushedTexture` (9) sont éprouvés par le jeu ; **leur rendu dans notre fenêtre reste à confirmer par vos captures**. Pas de texture binaire ajoutée (aucune licence à gérer) ; si les régions ne suffisent pas, la voie suivante est de générer nos propres TGA (cadres 9-slice) : décidée après vos retours.

## Localisation des légendaires (livrée dans le planner)
`Glossary.lua` + `GLOSSARY_FR.md` : 21 têtes, **proposition communautaire explicitement non officielle**, présentée séparément des traductions officielles (i18n : 0 titre de légendaire). Composition déterministe par clé stable `legendary:<sort>` (« tête FR : sort FR ou EN »), repli anglais, traduction officielle prioritaire si elle existe, aucune clé ni donnée enregistrée modifiée (testé : les SavedVariables ne contiennent aucun titre traduit). Listes du navigateur : **nom du sort**, puis « tête | classe » (les homonymes de classes différentes se distinguent) ; inspecteur : titre complet + mention « traduction communautaire, non officielle ».

## Tests (résultats réels)
Lua 5.1 : **216 cas, 12 586 assertions, 0 échec** (+10 cas `test_lot35`) ; catalogue, générateur, Lot 0, JS↔Lua inchangés (PASS). Nouveaux : couverture du glossaire, composition / repli / précédence, homonymes, stockage sans titre traduit, absence de modèle Blizzard, construction identique de tous les boutons, états repos/désactivé/sélectionné/destructif, clic ignoré si désactivé, **contraste WCAG** de chaque texte sur chaque surface (ivoire ≥ 7, secondaire ≥ 4,5, boutons ≥ 4,5), laboratoire à 1920×1080 / 1365×768 / 1280×720 (dans l'écran, deux colonnes égales), cases pleine/vide, placeholder, infobulle adaptée et gardée à l'écran, drapeau du laboratoire. **Ce sont des simulations : elles ne prouvent aucun rendu.**

## Ce qui n'est PAS encore fait (volontairement)
Application du thème à l'éditeur complet (lignes plus hautes, regroupement des actions secondaires, remplacement des champs et zones de défilement natifs) ; version 0.4.3-alpha ; recette de l'éditeur. Tout cela dépend du verdict du laboratoire.

## Livrables
`reborn-build-planner-recette-lot3-5\` : `RebornBuildPlanner\` (19 fichiers, 0.4.3-proto1), `RebornPlannerThemeLab\` + zip, `SHA256SUMS.txt`, guides ; `reborn-build-planner-lot3-5-projet.zip` ; docs `DIAGNOSTIC_RENDU.md`, `GLOSSARY_FR.md`, `RECETTE_LAB_LOT3_5.md`, `UPDATE_FROM_0.4.2.md`, `PROJECT_STATE.md`. Commits locaux, aucun push.

## Prochaine action
Kevin lance `/rbplab` (5 min), renvoie captures + verdict (L1-L10). Selon la réponse : appliquer `Theme.lua` à l'éditeur (0.4.3-alpha), ou ajuster le thème / passer aux textures TGA propres. Lot 4 : non démarré.

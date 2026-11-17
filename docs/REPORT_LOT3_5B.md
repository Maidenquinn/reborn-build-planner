# Rapport — LOT 3.5b : laboratoire v2 à textures originales

**État : PROTOTYPE v2 LIVRÉ, non validé visuellement.** Je n'ai pas de capture du client côté développeur : je ne peux pas affirmer que la différence est désormais évidente. J'ai (1) abandonné la technique qui a échoué, (2) dessiné de vraies textures, (3) fait une revue visuelle de ces textures par un **aperçu logiciel** (`tests/results/theme_preview.png`, **pas une capture du client**), et (4) ajouté des mesures pour le problème de couches. Le planner complet n'est pas modifié.

## Ce qui a changé graphiquement (par rapport au lab v1)
| | Lab v1 (rejeté) | Lab v2 |
|---|---|---|
| Panneaux | dégradé de ~4 % + bordure de 1 px | texture neuf segments : fond ardoise grainé, filet bronze, **clous or aux coins**, coins biseautés |
| Fenêtre | idem | cadre à **double filet bronze** et **équerres d'angle avec losange or** |
| Barre de titre | texte seul | bande bronze-ardoise biseautée, titre centré |
| Boutons | aplat + liseré | **relief** (biseau clair en haut, ombre en bas, bordure du rôle) ; 5 textures : principal or-brun, secondaire ardoise, destructif rouge, choisi bleu-or, inactif éteint |
| Survol / clic | veille 10-16 % | voile chaud / voile sombre **visibles**, portés par les textures de survol/appui du client |
| Séparateurs | ligne de 1 px | filet fondu avec **losange central** |
| Champ | cadre natif / plat | zone **en creux** biseautée, anneau doré au focus |
| Case d'équipement | bordure | 3 textures : normale, **choisie (cadre or épais, fond bleu)**, **vide (bordure pointillée)** ; icône dans un cadre teinté par la rareté |
| Ligne choisie | bleu plat | bleu profond → bleu-or + barre or |
| Infobulle | plat | cadre opaque à double filet or/bronze, clous aux coins |
| Défilement | barre native | piste en creux + curseur bronze à stries |

## Ce qui est livré
* **19 textures originales** + générateur déterministe (`tools/make_textures.py`) + aperçu logiciel (`tools/preview_theme.py`) ; inventaire : `TEXTURES_INVENTORY.md` (aucune ressource tierce).
* **`Theme.lua` v2** : neuf segments (`T.Nine`), surfaces, fenêtre sur strata `FULLSCREEN_DIALOG` / niveau 100 / `SetToplevel`, boutons à états, champ, ligne, case, icône, barre de défilement, infobulle bornée, `T.Fit` (troncature). Pas de modèle Blizzard, pas de `OnUpdate`, pas de hook.
* **Lab v2** (addon séparé, dossier `Media\` inclus) : même écran d'échantillon **deux fois** (nouveau / ancien plat) ; états montrés sans souris ; trois tailles de bouton ; deux tailles de panneau ; défilement avec molette et barre ; case pleine / vide / choisie avec un titre de légendaire long ; infobulle ; **bande de contrôle de chargement des 19 fichiers** ; `/rbplab diag` (capacités, strata, niveau, échelle, dossier, **cadres visibles dessinés au-dessus du labo**).
* `COMPAT_CLIENT_LOT3_5B.md` (techniques, statut, inconnus) ; `RECETTE_LAB_V2_LOT3_5B.md`.

## Couches et opacité
Cause du texte du jeu visible derrière les panneaux : **non démontrée**. Corrections : strata `FULLSCREEN_DIALOG`, niveau 100, `SetToplevel`, souris capturée, surfaces **100 % opaques** (alpha 255 dans les fichiers, 1 en code), couche `BACKGROUND` sous le contenu, voiles translucides seulement sur les contrôles. Limite : un addon à `TOOLTIP` restera devant ; `/rbplab diag` le nomme.

## Tests (résultats réels)
`tools/run_all.py` exit 0 : catalogue, **textures (octet par octet)**, générateur, Lot 0, **Lua 5.1 : 220 cas, 14 196 assertions, 0 échec**, JS↔Lua. Nouveaux (`test_lot36`, 10 cas) : validité de chaque TGA (type, 32 bits, longueur exacte, puissance de 2, corps opaque, centre du cadre d'icône transparent, voiles translucides) ; inventaire complet et sans fichier étranger ; **chaque chemin de texture utilisé existe** ; construction neuf segments (9 textures, coins fixes, bords sur deux ancres, coordonnées exactes, cadres assez grands pour leurs coins, échange de fichier) ; états (5 textures de bouton, voiles, clic ignoré si inactif, texte centré) ; contraste WCAG ; strata / niveau / opacité de chaque texture de surface ; `/rbplab diag` (nomme un cadre intrus en `TOOLTIP`) ; mêmes boutons dans les deux colonnes ; 1920×1080, 1365×768, 1280×720 sans débordement ni recouvrement ; défilement, cases, focus ; aucun widget créé après la construction. **Simulations : elles ne prouvent aucun rendu ; le nombre d'assertions n'est pas un indicateur de réussite visuelle.**

## Limites assumées
Chargement réel des TGA et rendu non vus ; pixel-art étiré (le client peut le lisser) ; polices du jeu inchangées (12 / 10 pt) ; pas d'ornements illustrés (volontairement discrets) ; le thème n'est pas appliqué à l'éditeur.

## Livrables
`reborn-build-planner-recette-lot3-5b\` : `RebornPlannerThemeLab\` (+ `Media\`) et `RebornPlannerThemeLab-0.4.3-proto2.zip`, `RebornBuildPlanner\` (0.4.3-proto1 inchangé), guides ; `reborn-build-planner-lot3-5b-projet.zip` ; docs ci-dessus ; `PROJECT_STATE.md`. Commit local, aucun push.

## Prochaine action
Kevin exécute M1-M10. Si la différence est évidente et les 19 fichiers chargent : application du thème à l'éditeur (0.4.3-alpha). Sinon : captures + `/rbplab diag` → correction ciblée (chemins, couches, contraste). Lot 4 non démarré.

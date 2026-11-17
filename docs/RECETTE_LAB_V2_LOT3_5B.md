# Recette du laboratoire v2 (≈ 5 min)

**But : voir si la différence est ENFIN évidente.** Gauche = nouveau thème (textures originales), droite = ancien thème plat. Tout le reste du planner est inchangé.

## Installation
1. Fermer le jeu. **Supprimer l'ancien dossier `RebornPlannerThemeLab`** (v1) s'il existe, puis extraire `RebornPlannerThemeLab-0.4.3-proto2.zip` dans `Interface\AddOns\` : le dossier contient `Theme.lua`, `Lab.lua`, le `.toc` et **`Media\` (19 fichiers .tga)**.
2. En jeu : `/rbplab` (en plein combat si possible, pour les couches).

## À faire
| # | Action | À noter |
|---|---|---|
| M1 | Capture plein écran 📷 | **La gauche est-elle visiblement différente de la droite ?** (cadres, relief des boutons, séparateurs, cases) |
| M2 | Bande « Fichiers de texture » en bas de la fenêtre | **Y a-t-il des carrés verts ou blancs ?** (lesquels ?) |
| M3 | Boutons : ligne « Repos · Survol · Clic · Choisi · Inactif » | Les cinq sont-ils distincts ? Survoler / cliquer-maintenir un bouton réel : voile clair / sombre ? |
| M4 | Champ de recherche : cliquer, taper | Cadre doré au focus, placeholder qui disparaît |
| M5 | Liste « Catalogue défilant » : molette sur la liste, glisser la barre | Défilement, curseur bronze |
| M6 | Case d'équipement avec « Eye of the Splitting Sky: Enchaînement » | Nom sur 2 lignes sans toucher le bouton x |
| M7 | Regarder derrière la fenêtre en combat | **Un texte du jeu est-il visible à travers un panneau ?** |
| M8 | `/rbplab diag` | Copier les lignes ; surtout « au-dessus du labo (n) : … » |
| M9 | Refaire en 1280×720 (ou réduire l'échelle d'interface) | La fenêtre tient-elle ? |
| M10 | Verdict : **approuvé / à corriger** (précisez : cadres, couleurs, relief, texte, densité) | |

À renvoyer : captures, M2 (carrés verts ?), M7, sortie de `/rbplab diag`, verdict. **Le planner complet n'est pas modifié tant que le thème n'est pas approuvé.**

# Ultimate UI — Prototype fantasy v3 (18 novembre 2026)

## Statut

**Prototype graphique réel préparé, test client NON EXÉCUTÉ.** La capture de l'interface complète est une maquette illustrée, pas un screenshot Reborn. Les effets chiffrés qu'elle montre ne sont pas des données vérifiées.

Les captures de l'ancien Theme Lab montraient une amélioration insuffisante entre v1/v2. Le nouveau prototype modifie cette fois la silhouette de la fenêtre (coins sculptés), son bandeau (médaillon héraldique), et les surfaces des panneaux (matière texturée).

## Réalisations

- `tools/make_ultimate_art.py` : génération déterministe de quatre ressources **originales**, sans copier les assets de WoW, sans catalogue tiers.
- `addon/RebornBuildPlanner/Theme.lua` : référence aux quatre ressources : `ultimate_corner`, `ultimate_crest`, `ultimate_titlebar`, `ultimate_panel`. Seul le thème opt-in utilise ces ressources. `UI.lua` reste inchangé.
- `addon_lab/RebornPlannerThemeLab/Lab.lua` : libellé du laboratoire mis à jour, comparaison nouveau/ancien préservée.

## Générer les textures sur un clone GitHub

Les fichiers binaires TGA **ne sont pas encore enregistrés dans le dépôt GitHub**. Le ZIP de recette fourni dans la conversation contient les quatre TGA générés et les 19 TGA du laboratoire précédent.

Dans un clone local :

```powershell
python -m pip install Pillow
python tools/make_ultimate_art.py addon_lab/RebornPlannerThemeLab/Media
```

La dépendance Pillow sert **uniquement pendant la génération**, jamais dans le jeu. Tous les fichiers générés doivent être présents avant de packager le laboratoire.

Le laboratoire doit contenir :
- `RebornPlannerThemeLab.toc`
- `Lab.lua`
- `Theme.lua` (**copie** de `addon/RebornBuildPlanner/Theme.lua`)
- `Media/*.tga` (19 anciens + 4 nouveaux)

Le package complet du planner exige toujours `GeneratedCatalog.lua` local, conformément à `docs/PROVENANCE.md`. Ne pas intégrer de fichiers officiels exclus à Git.

## Tests accomplis

- Génération des quatre nouvelles textures avec Pillow.
- Inspection des 23 images RGBA TGA du laboratoire : fichiers présents, dimensions cohérentes, ZIP de 26 entrées vérifié, `zipfile.testzip()` sans erreur.
- Vérification des références des nouveaux fichiers dans `Theme.lua`.
- Tests complets Lua 5.1 / UI 3.3.5a : **non rejoués** dans le runtime local de GPT.
- Tests en client Reborn : **non exécutés**.

## Recette prioritaire

1. Fermer Reborn, sauvegarder tes données si besoin. Ne remplacer **que** `RebornPlannerThemeLab`.
2. Extraire le ZIP de recette dans `Interface/AddOns`. Vérifier la présence du `.toc` dans le sous-dossier.
3. Ouvrir Reborn, lancer `/rbplab`.
4. Vérifier fond et coins opaques, bandeau à médaillon, panneaux texturés, état des boutons, lisibilité et absence d'effet de texture manquante.
5. Lancer `/rbplab diag`, envoyer une capture.
6. Ne pas appliquer à `UI.lua` avant validation visuelle.

## Règles de suite

- Ne pas modifier `main` ni les SavedVariables.
- Pas de Lot 4.
- Une fois le thème jugé bon dans le client, refactoriser l'éditeur en composants stylés, tout en conservant la disposition gauche / centre / droite / bas et les validations de modèle.

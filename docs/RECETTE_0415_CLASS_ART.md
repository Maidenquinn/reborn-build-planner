# Recette privée 0.4.15 — icônes de classe fournies par le joueur

## Correction du retour utilisateur (18 novembre 2026)

La 0.4.14 affichait des symboles **originaux dessinés par notre générateur**, et non les illustrations reconnaissables de World of Warcraft pour **Moine** et **Chasseur de démons**. L'utilisateur a fourni les deux illustrations officielles souhaitées et demandé de les utiliser, sans réinterprétation.

## Changement réel

- `tools/make_ultimate_art.py` ne dessine plus les deux classe-icons avec des formes géométriques.
- Il charge des références bitmap provenant des deux **images fournies par l'utilisateur**, mises à l'échelle 48 px pour le dépôt privé, puis converties sans redessin en TGA 64x64 compatible client WoW.
- Les sources sont `tools/official_icons_monk.b64` et `tools/official_icons_dh.b64`. Elles sont enregistrées comme texte encodé pour le transport par le connecteur GitHub ; le décodeur rétablit le JPEG et valide les empreintes SHA-256 attendues, puis le rend en TGA. Aucun réseau pendant le build.
- `ClassVisual.Icon` retourne toujours `ultimate_class_monk` ou `ultimate_class_dh` dans le **dropdown de classe** et la **liste des builds**. Le correctif ne touche ni les builds ni les SavedVariables.
- Autres textures d'interface, états « Bannir après », et catalogue inchangés.

## Provenance / restrictions

Les deux illustrations sont des références **fournies par l'utilisateur**, présentées comme officielles du jeu, et non des illustrations créées ou sous licence par le projet. Aucun droit de redistribution n'a été vérifié. Elles sont intégrées uniquement à la branche du **dépôt privé** pour les tests. **Ne pas fusionner vers une publication ou une release publique incluant ces ressources** sans vérifier les droits ; prévoir l'utilisation des ressources natives du jeu ou un mécanisme d'installation locale si publication.

## Recette Windows

```powershell
git switch dev/ultimate-ui
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors" -GameExe "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\AzerothSurvivorsGame.exe"
```

Sortie : `dist\ultimate-0.4.15-local\RebornBuildPlanner-0.4.15-alpha-classart-recette.zip`.

Sauvegarder le dossier `RebornBuildPlanner` installé et ses SavedVariables, puis remplacer l'addon après fermeture du jeu. La construction ne touche pas directement à l'installation.

## Critères de recette

1. `/rbp diag` : `0.4.15-alpha-classart` et stockage/catalogue OK.
2. Ouvrir la liste déroulante de classe : **Moine** affiche l'icône de bambou et de gourde, **Chasseur de démons** la glaive verte, sans art générique dessiné.
3. Vérifier ces mêmes visuels dans les lignes de builds correspondants.
4. Les autres classes gardent leurs icônes natives. Couleurs de classe, favori, tri et filtre inchangés.
5. Vérifier la lisibilité à l'échelle réelle de jeu ; la source mise à l'échelle est prévue pour des icônes de 16–26 px, pas pour être agrandie en grand format.
6. Préserver les builds existants, le statut Suivi et les SavedVariables.

Tests CI source/package : génération des textures, vérification SHA-256 de chaque source class-art, tous les tests de la branche, ZIP privé. **Le rendu réel en jeu reste à valider.**

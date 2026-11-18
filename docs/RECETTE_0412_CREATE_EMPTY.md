# Recette 0.4.12-alpha-createfix — création utilisable et écran vide propre

## Constat en client réel (18 novembre 2026)

- Ouverture avec deux builds sauvegardés, sans sélection : le centre affichait des traits horizontaux et verticaux isolés, hérités des séparateurs de l'éditeur.
- Fenêtre « Créer un build » : le texte explicatif, les libellés « Nom du build » et « Classe », et les boutons Créer/Annuler étaient visibles, mais pas la saisie ni les flèches de sélection de classe.
- L'utilisateur trouve le nouveau style du planner globalement satisfaisant. La localisation semble meilleure ; une vérification complète reste nécessaire.

## Correctifs en code

**Écran sans build**
- `setShown` synchronise la visibilité du séparateur `rule` lié à chaque en-tête. Auparavant masquer le titre ne masquait pas son `Texture`.
- Les trois séparateurs verticaux `ed.groups[g].sep` disparaissent maintenant lorsque l'éditeur n'a aucun build sélectionné ; ils réapparaissent dans un build ouvert.
- Un état d'accueil centré remplace la grille fantôme : emblème original, titre concis, indication « sélectionnez un build à gauche » et bouton « Créer un build ». L'action utilise la même fonction `AskCreate()` que le bouton de la bibliothèque.

**Fenêtre de création**
- Le champ de nom et le sélecteur de classe sont désormais créés dans `m.form`, un cadre placé explicitement au-dessus du matériau opaque de la fenêtre `m`.
- Fond de saisie `inset` visible, `EditBox` et flèches à un niveau supérieur à `m.form`. Le pied de dialogue Enregistrer/Annuler demeure à son niveau prioritaire.
- Champ de nom focalisé après ouverture du dialogue, avec validation existante d'un nom non vide et de sa longueur.
- Les autres fenêtres de saisie/renommage réutilisent le même cadre haut.

**Couverture i18n**
- Premier audit statique de 204 clés littérales appelées depuis les principaux modules : 201/204 traduites en FR avant ajout de trois chaînes de commande manquantes (désormais ajoutées) ; russe 87/204 ; 12 langues de navigation additionnelles 20/204. Ce sont des mesures des chaînes d'interface statiques, **pas** une vérification linguistique intégrale, et les noms de catalogue officiels sont comptabilisés séparément.
- Détails et suites restantes : `docs/I18N_AUDIT_INITIAL.md`. On ne prétend pas que toutes les langues sont entièrement traduites.

## Vérifications automatiques

GitHub Actions : `Ultimate UI source checks` et `Ultimate UI private preview package`. Les tests comprennent spécifiquement l'absence de séparateurs sur l'écran vide, leur retour après ouverture d'un build, les couches de la modale, la présence d'une saisie et des deux flèches de classe, la modification de classe et la création d'un build test.

**Important :** le simulateur de widgets Lua ne reproduit pas exactement le moteur de rendu Reborn. Il faut une capture native de la modale avec les champs et flèches réellement visibles avant validation finale.

## Construction privée Windows

Depuis le dossier local `reborn-build-planner` :

```powershell
git switch dev/ultimate-ui
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors" -GameExe "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\AzerothSurvivorsGame.exe"
```

ZIP prévu : `dist\ultimate-0.4.12-local\RebornBuildPlanner-0.4.12-alpha-createfix-recette.zip`.

Fermer le jeu, sauvegarder le dossier de l'addon et les SavedVariables, remplacer uniquement le dossier `RebornBuildPlanner`. Le script de build ne modifie pas l'installation du jeu.

## Contrôles prioritaires

1. Ouvrir `/rbp` sans sélectionner de build : pas de ligne fantôme au centre, seulement l'accueil avec son CTA.
2. Cliquer sur « Créer un build » (à gauche et au centre) : champ de nom **visible, saisissable**, classe avec flèches **visibles, cliquables**.
3. Taper un nom, choisir une autre classe, créer : confirmer nom/classe corrects et absence d'activation automatique.
4. Annuler une seconde création : aucun build supplémentaire.
5. Fermer/réouvrir, `/reload` : builds existants toujours présents.
6. Renommer : même champ modale fonctionnel.
7. FR/EN/RU : aucun retour des titres orphelins, textes convenablement placés.

Aucune fusion dans `main` ni release publique avant validation native.

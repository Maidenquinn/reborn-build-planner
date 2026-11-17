# Mise à jour 0.4.2-alpha → 0.4.3-proto1

1. Fermer le jeu. **Sauvegarder** `WTF\Account\<compte>\SavedVariables\RebornBuildPlanner.lua`.
2. Supprimer `Interface\AddOns\RebornBuildPlanner`, extraire le nouveau dossier (**19 fichiers** : `Glossary.lua` et `Theme.lua` en plus).
3. (Facultatif) extraire `RebornPlannerThemeLab` à côté pour la recette du laboratoire.

## Vos données
Aucun changement de stockage, aucun build touché. Les titres FR de légendaires sont **calculés à l'affichage** : les SavedVariables ne contiennent toujours que les clés `legendary:<sort>`.

## Ce qui change dans le planner
* Titres de légendaires en français (proposition **communautaire**, non officielle) ; listes : nom du sort en premier, puis « tête | classe ».
* **L'apparence de l'éditeur n'est volontairement pas modifiée** dans ce prototype : `Theme.lua` est chargé mais pas encore utilisé. Le thème complet suivra l'approbation du laboratoire.

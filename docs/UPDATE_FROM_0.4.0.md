# Mise à jour 0.4.0-alpha → 0.4.1-alpha

1. Fermer le jeu. **Sauvegarder** (copie) `WTF\Account\<compte>\SavedVariables\RebornBuildPlanner.lua`.
2. Supprimer `Interface\AddOns\RebornBuildPlanner`, extraire le nouveau dossier à la même place.
3. `/rbp diag` doit annoncer `0.4.1-alpha`.

## Vos données
**Aucun changement de stockage** : schéma 1, `db.meta`, `libSort`, `libFilter`, `banishAfter` inchangés. Aucun build réécrit, aucune migration. Retour à 0.4.0-alpha : sans risque pour les données.

## Ce qui change à l'écran (interface seulement)
* Colonne **droite** = navigateur permanent Sorts / Anneaux / Bijoux / Amulettes (recherche, liste défilante) ; le panneau « Détails » est maintenant **en bas du centre**, à la place du catalogue.
* Plus de pagination dans la bibliothèque ni dans le navigateur : molette ou barre de défilement. L'import et l'export gardent leurs pages de messages.
* Boutons plats (plus de boutons rouges natifs), palette sombre / laiton ; le rouge n'est réservé qu'aux actions destructives.
* Fenêtre 1240×704 (au lieu de 1120×704), réduite automatiquement pour tenir à l'écran.
* « Placer » se fait depuis le panneau du bas (bouton « Placer ici ») ou par **double-clic** sur la ligne du navigateur.

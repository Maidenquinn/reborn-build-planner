# Installation / désinstallation (Reborn Build Planner 0.4.0-alpha)

**Installation (copie séparée, après vérification du package)**
1. Fermer le jeu.
2. Extraire `RebornBuildPlanner-0.4.0-alpha-recette.zip` dans `…\Azeroth Survivors\Interface\AddOns\` : le dossier `RebornBuildPlanner\` (16 fichiers) apparaît à côté de `AzerothSurvivors`, `AzerothSurvivorsAPI`, etc. Aucun autre addon n'est touché.
3. Vérifier `SHA256SUMS.txt` (facultatif). Lancer le jeu : `Reborn Build Planner` doit être coché, dépendances satisfaites.
4. `/rbp diag` doit répondre `version 0.4.0-alpha, storage …, catalogue 384db000d5ac311d (OK)`.

**Mise à jour depuis 0.3.x** : voir `UPDATE_FROM_0.3.1.md` (sauvegarde des SavedVariables d'abord).

**Désinstallation** : supprimer le dossier `RebornBuildPlanner`. Les données sont dans `WTF\Account\<compte>\SavedVariables\RebornBuildPlanner.lua` (à conserver ou supprimer). Aucun autre fichier n'est écrit.

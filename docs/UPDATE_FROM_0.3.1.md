# Mise à jour 0.3.1 → 0.4.0-alpha

1. Fermer le jeu. **Sauvegarder** (copie) `WTF\Account\<compte>\SavedVariables\RebornBuildPlanner.lua`.
2. Supprimer le dossier `Interface\AddOns\RebornBuildPlanner`, extraire le nouveau dossier à la même place.
3. `/rbp diag` doit annoncer `0.4.0-alpha`.

## Vos données
* **Schéma de stockage inchangé (1).** Aucune migration destructive, aucun build réécrit, aucune perte.
* **Nouveau : `db.meta`** (table optionnelle à côté des builds) : `{ fav, used, modified, created }` par build. Elle est créée à la demande : favori, ouverture dans l'éditeur, suivi, enregistrement, création. Un build sans entrée n'a ni date ni favori (rien n'est inventé). Ces métadonnées ne changent jamais la révision d'un build et ne sont jamais exportées.
* **Nouveaux réglages** (validés, optionnels) : `libSort` (nom / dernière utilisation / dernière modification), `libFilter` (tous / favoris / récents).
* **Politique documentée** : un build **dupliqué** n'est ni favori ni « utilisé » ; un build **restauré** de la corbeille garde son favori et ses dates ; l'éviction de la corbeille supprime les métadonnées du build évincé ; « utilisé » = ouvert dans l'éditeur ou suivi.
* Si `db.meta` est illisible (valeur inattendue), elle n'est pas touchée : les favoris sont refusés, les builds restent intacts. Les champs inconnus d'une entrée sont conservés.
* Mode lecture seule (base plus récente ou illisible) : aucune métadonnée n'est écrite.
* À l'ouverture, chaque étape d'un build 0.3.0 reçoit en mémoire une liste `banishAfter` vide (0.3.1 le faisait déjà) ; contenu et révision inchangés.
* Retour à 0.3.1 : non testé ; 0.3.1 ignore `db.meta` (favoris et dates non affichés, rien n'est supprimé). En cas de doute, restaurez la sauvegarde.

## Changements d'interface à connaître
Plus d'onglets Sorts / Bijouterie / Notes : tout est sur une page, la bibliothèque reste à gauche, l'inspecteur à droite. « Mes builds / Éditeur » et « Fermer » disparaissent : cliquer un build l'ouvre (avec invite si le brouillon en cours n'est pas enregistré). « Notes et avancé » regroupe notes, lien, talents, nom d'étape, liste à éviter et données conservées.

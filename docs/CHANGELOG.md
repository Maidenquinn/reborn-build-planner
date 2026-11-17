# Changelog

## 0.4.0-alpha (Lot 3.2) — refonte UX complète
* Fenêtre unique 1120×704 en trois zones : bibliothèque (gauche), éditeur complet sur une page (centre), inspecteur (droite) ; mise à l'échelle automatique pour tenir à l'écran (jusqu'à 800×600).
* Bibliothèque : recherche (nom, classe EN/FR, noms de sorts et de pièces), filtres Tous / Favoris / Récents + classe, tri nom / dernière utilisation / dernière modification, favoris en premier, dates réelles issues de `db.meta`, 10 builds par page (200 supportés), sélection = ouverture avec invite Enregistrer / Abandonner / Continuer.
* Éditeur : six sorts avec priorité, haut/bas, retrait et bascule « Conserver / Bannir après » ; compteur ; douze emplacements d'équipement visibles ensemble (principaux + alternatives) ; catalogue intégré filtré par type avec **cible toujours visible** ; « Placer » remplace directement ; liste « à éviter » et données avancées dans « Notes et avancé ».
* Inspecteur : détails du dernier élément sélectionné ; texte natif des sorts lu une fois par sort (cache) ; « Effet détaillé indisponible » sinon ; source indiquée.
* Création : champ nom et sélecteur de classe sur deux lignes séparées, classe du joueur présélectionnée, validation (vide, trop long) sans fermer le dialogue.
* Stockage : `db.meta` (favori, utilisé, modifié, créé), réglages `libSort` / `libFilter`, sans changement de schéma.
* Contrats natifs ré-ancrés (voir `CONTRACTS.md` §11) : 18 ancrages ; `C09` a changé de sens (les bannissements existent aussi sur les mains de bijoux).
* Tests Lua 5.1 : 183 cas, 7 934 assertions.

## 0.3.1 (Lot 3.1) — `banishAfter`, infobulles, fenêtre opaque
## 0.3.0 (Lot 3) — première interface native (bibliothèque, éditeur, import/export)

# Changelog

## Beta hotfix candidate (unreleased)
- Replaced the minimap's generic parchment icon with RBP's fantasy crest, retaining the standard minimap border.
- Drag the launcher with the left mouse button to reposition it around the minimap; coordinates are saved in existing addon settings, including across /reload.
- Left click opens/closes the planner; right click toggles the idle/live HUD.
- Small HUD appears when no build is followed; explicit hide preference remains respected.

## 0.5.0-beta.1 (candidate — non publié, 2026-11-19)
- Bibliothèque de builds, import/export et aperçu multi-phase, éditeur des 6 sorts (priorité et banish-after) et équipements principaux/alternatifs.
- Ultimate UI : navigateur de catalogue, statuts mieux alignés, bijoux distincts, panneau Détails à contraste renforcé, consultation des notes avant modification.
- Suivi live en lecture seule : HUD compact/détaillé, sans sélection ni bannissement automatique.
- Recette Windows approuvée par le testeur ; validations Lua 5.1 et packaging privé en CI.
- Préflight structurel compatible avec le format ZIP de l'index Syiana/azs-addons et candidature TOML préparée, non soumise.
- Publication publique bloquée par la provenance/licence des données du catalogue et par les règles de l'index (pré-releases exclues). Voir docs/BETA_RELEASE_0.5.0.md.

## Lab 0.4.3-proto2 (Lot 3.5b)
* Lab v2 : textures TGA originales (19), neuf segments, boutons en relief, états visibles, strata `FULLSCREEN_DIALOG`, bande de contrôle des fichiers, `/rbplab diag` étendu. Planner inchangé.

## 0.4.3-proto1 (Lot 3.5, étape 1)
* Titres FR de légendaires (glossaire communautaire, non officiel) ; listes : sort puis « tête | classe ».
* `Theme.lua` (design system) livré mais non appliqué ; addon séparé `RebornPlannerThemeLab` pour valider le rendu réel.
* Tests Lua 5.1 : 216 cas, 12 586 assertions.

## 0.4.2-alpha (Lot 3.4) — équipements, infobulles, descriptions, traductions
* **Données** : générateur v2 : conserve les champs publiés des amulettes (`growth`, `effects`, `special`, `world`, `needs`) et des légendaires (`template`, `form`, `effects`, `growth`, `fixed`) ; hash de contenu inchangé. Nouveau module `Describe.lua` (règles officielles, FR/EN, aucune valeur inventée).
* **Cases d'équipement** : structure à zones réservées (fin des chevauchements nom / bouton retirer), principaux et alternatives séparés, nom très long tronqué avec nom complet dans le panneau et l'infobulle, couleurs de rareté.
* **Sorts** : contrôles compacts ; `banishAfter` inchangé.
* **Inspecteur** : sections (Dans ce build / Description / Informations / Effets / Croissance / Disponibilité), défilement interne, source indiquée.
* **Infobulles** : aperçu court (≤ 7 lignes), ancre à gauche dans la moitié droite de l'écran, texte natif jamais mélangé.
* **Traductions** : noms de légendaires = tête anglaise + sort traduit ; libellés de statistiques et d'effets sûrs traduits, les autres laissés tels que publiés.
* Tests Lua 5.1 : 206 cas, 11 773 assertions.

## 0.4.1-alpha (Lot 3.3) — refonte visuelle et nouvelle organisation
* **Droite = navigateur permanent** Sorts / Anneaux / Bijoux / Amulettes (recherche, liste défilante, état « Voulu / Évité / En place / Placé »). **Bas du centre = détails** (icône, type, rareté/classe, texte natif ou « Effet détaillé indisponible », source, statut dans le build, actions Ajouter / Retirer / Éviter / Placer ici / Vider / Déjà placé). Double-clic = action principale.
* **Cliquer un emplacement** filtre le navigateur sur le bon type et cible l'emplacement ; **sélectionner** une pièce n'en place aucune : le placement se fait par le bouton ou le double-clic.
* **Plus de pagination** dans la bibliothèque ni le navigateur : molette + barre de défilement, décalage géré par le contrôleur.
* **Style** : boutons plats à rôles (or / neutre / rouge réservé à la suppression), panneaux encre, filets laiton, titres de section dorés, bandes de lignes, emplacements cadrés en doré quand ils sont choisis, ligne sélectionnée surlignée.
* Fenêtre 1240×704 ; composants `LibraryPane` / `EditorPane` / `DetailPane` / `BrowserPane` dans `UI.lua`.
* Tests Lua 5.1 : 193 cas, 9 020 assertions.

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

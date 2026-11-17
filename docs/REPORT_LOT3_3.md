# Rapport — LOT 3.3 (refonte visuelle + réorganisation)

**Verdict : PASS CONDITIONNEL.** Version **0.4.1-alpha**. La réorganisation demandée est faite et testée en simulation (Lua 5.1 : 193 cas, 9 020 assertions, 0 échec ; `tools/run_all.py` exit 0). **Aucune capture réelle** : je n'ai pas lancé le client et ne peux **pas juger si le rendu est « plus beau »** — j'ai appliqué une direction (palette, boutons plats, hiérarchie, espacements) mais le verdict visuel est le vôtre (F2, F18). Rien installé en production. Le Lot 4 n'est pas commencé.

## 1. Layout livré (conforme au retour de Kevin)
| Zone | Contenu |
|---|---|
| Gauche | Bibliothèque : recherche, filtres Tous/Favoris/Récents, classe, tri, **liste défilante** de builds, Créer (principal), Suivre / Dupliquer / Renommer, Importer / Corbeille / Supprimer |
| Centre haut | Nom, classe, favori, statut, Enregistrer / Enregistrer et suivre / Abandonner, étapes, 6 sorts (priorité, haut/bas, retirer, Conserver / Bannir après), **12 emplacements d'équipement** |
| Centre bas | **Détails** de l'élément sélectionné (à la place de l'ancien catalogue) ; « Notes et avancé » prend sa place à la demande |
| Droite | **Navigateur permanent** Sorts / Anneaux / Bijoux / Amulettes : recherche, liste défilante, état de chaque ligne, cible affichée |

Test automatisé : la colonne droite est à droite du centre, les détails sont sous la dernière ligne d'équipement, plus de colonne inspecteur ni de pagination.

## 2. Parcours
1. Choisir un build (gauche). 2. Structure au centre. 3. Cliquer un emplacement : le navigateur passe sur le bon type, la cible est affichée, l'emplacement est cadré en doré. 4. Cliquer une pièce : détails en bas, **rien n'est placé**. 5. « Placer ici » (ou double-clic) : remplacement direct dans l'emplacement choisi. 6. La ligne passe à « En place » ; le bouton devient « Vider l'emplacement ». Une pièce déjà placée ailleurs affiche « Déjà placé » (désactivé). Les sorts suivent la même logique (Ajouter à mes sorts / Retirer / Éviter ce sort).

## 3. Pagination
Supprimée de la bibliothèque et du navigateur (molette 3 lignes par cran, barre fine, décalage borné). Subsistent seulement les pages de messages de l'import et de l'export (6 lignes), volontairement.

## 4. Visuel (à juger sur écran)
Fond encre presque noir, panneaux à bordure laiton, titres de section dorés avec filet, lignes à bandes alternées, sélection dorée, boutons **plats** (plus de boutons rouges natifs) : action principale or, secondaires neutres, **rouge réservé à la suppression**, état choisi = ambre **et** « * ». Texte toujours explicite (la couleur ne porte jamais seule l'état). Le rendu réel (polices, contrastes, taille des icônes) n'a pas été vu.

## 5. Tests (résultats réels)
| Étape | Résultat |
|---|---|
| Catalogue, générateur, Lot 0 (273), JS↔Lua (63) | PASS |
| Lua 5.1 | **193 cas, 9 020 assertions, 0 échec** (+10 cas `test_lot33` ; tests des Lots 3 à 3.2 portés à la nouvelle interface, dont pagination → défilement) |

`test_lot33` : disposition gauche/centre/droite/bas ; style plat ; flux complet emplacement → navigateur → sélection → détails → placer / remplacer / vider / alternatives / « déjà placé » ; double-clic ; sorts via le panneau ; défilement (molette, barre, bornes, remise à zéro par recherche ou changement de type) ; recherche droite (EN/FR, vide) ; honnêteté des détails ; changement de build ; contrôle de mise en page à **1920×1080, 1365×768, 1280×720, 1024×768, 800×600**, FR/EN, échelles **0,6 / 1 / 1,5**, build entièrement rempli ; non-régression (banishAfter + perte à l'export, favoris, lecture seule, aucun widget créé en défilant ou survolant, aucun `OnUpdate`). **Mise en page sur largeurs de texte estimées, pas un rendu.**

## 6. Risques propres au client (à lever par F3, F4)
* **Boutons sans modèle** : créés comme dans FieldKit (étiquette propre + `SetFontString`). Si le client n'affiche pas le texte ou la surbrillance, c'est le premier point à corriger.
* **Molette au-dessus des lignes** : la zone défilante capte la molette, les lignes sont des boutons ; comportement réel à confirmer.
* **Barre de défilement** : `Slider` standard avec `SetThumbTexture` comme `EditorKit`.
* Fenêtre 1240 px de large : réduite par échelle sous ≈ 1264 px (0,63 à 800×600) ; texte petit sur petits écrans.

## 7. Conservé
Bibliothèque, recherche, favoris, récents, tri ; 6 sorts + 3 « bannir après » ; 12 emplacements ; import/export et avertissement de perte ; stockage `db.meta`, migrations 0.3.0 → 0.4.0 ; lecture seule ; aucune automatisation de jeu ; aucun réseau.

## 8. Limites
Rendu non vu ; effets des pièces toujours indisponibles (`DESCRIPTION_SOURCES.md`) ; pas de mode « Tout » dans le navigateur (le placement exige un type, donc un emplacement cible) ; pas de glisser-déposer ; pas de navigation clavier ; recherche ASCII.

## 9. Livrables et prochaine action
Package `reborn-build-planner-recette-lot3-3\` (addon 16 fichiers, zip, SHA256, guides), `reborn-build-planner-lot3-3-projet.zip`, `REPORT_LOT3_3.md`, `PROJECT_STATE.md`, `CHANGELOG.md`, `UPDATE_FROM_0.4.0.md`, `RECETTE_CLIENT_LOT3_3.md` ; commits locaux `lot3.3a/b/c`, aucun push. **Prochaine action : Kevin exécute F1-F19 et renvoie des captures + son appréciation visuelle (F18).** Le Lot 4 attend ces retours.

# Recette client — Reborn Build Planner 0.4.1-alpha (≈ 25 min)

**Statut : NON EXÉCUTÉE.** Tout est attendu, issu d'une simulation (Lua 5.1 + widgets simulés). **Aucune capture réelle n'existe, y compris pour le style** : « plus beau » reste à juger par vous sur écran. Installation : `INSTALL.md` / `UPDATE_FROM_0.4.0.md`.

| # | Étape | Attendu |
|---|---|---|
| F1 | `/rbp diag` | `version 0.4.1-alpha`, aucune erreur Lua |
| F2 | `/rbp` en 1920×1080, 1280×720, 1024×768 📷 ×3 | Fenêtre entière visible, opaque ; gauche = builds, centre = build + détails en bas, **droite = navigateur** ; style sombre/laiton, boutons plats, lisibles |
| F3 | **Boutons plats** : le texte s'affiche dans chaque bouton, la souris les éclaire, un bouton grisé se distingue d'un actif | Si un bouton n'a pas de texte ou ne réagit pas : noter lequel (risque propre au client : bouton sans modèle) |
| F4 | Molette sur la liste de droite puis sur la bibliothèque ; glisser la barre fine | Les listes défilent (3 lignes par cran) ; la molette fonctionne **au-dessus des lignes** (risque client) |
| F5 | Créer un build ; « + Ajouter un sort » ; onglet Sorts à droite, cliquer un sort | Détails en bas (icône, texte natif du sort, source) ; bouton « Ajouter à mes sorts » |
| F6 | Ajouter 6 sorts, marquer 3 « Bannir après » | Compteur, lignes teintées, 4ᵉ refusée |
| F7 | Cliquer l'emplacement « Anneaux - Alt. 1 » vide | Le navigateur passe sur Anneaux, cible affichée, cadre doré sur l'emplacement |
| F8 | Cliquer un anneau à droite | Détails en bas ; bouton « Placer ici » actif ; l'anneau n'est PAS encore placé |
| F9 | « Placer ici » ; puis cliquer un autre anneau et « Placer ici » ; **double-clic** sur un troisième | Remplacement direct dans l'emplacement choisi, rien d'autre ne bouge ; la ligne indique « En place » |
| F10 | Même chose pour bijoux et amulette (communes et légendaires) ; « x » pour vider ; « Déjà placé » si la pièce est ailleurs | Les 12 emplacements restent visibles ensemble |
| F11 | Recherche à droite (nom EN et FR), recherche dans la bibliothèque | Filtre immédiat ; la liste revient en haut |
| F12 | Survol des lignes, cases d'équipement, sorts | Infobulle ; disparaît en défilant ou changeant de liste |
| F13 | Enregistrer, `/reload`, rouvrir | Tout est conservé (builds, marques, favoris, équipement, position) |
| F14 | Changer de build avec un brouillon ; import/export (perte « bannir après » annoncée) | Invite Enregistrer / Abandonner / Continuer ; export avec liste des pertes |
| F15 | « Notes et avancé » puis « Retour aux détails » | Notes, lien, talents conservés ; le panneau Détails revient |
| F16 | Taille - / + ; autre échelle d'interface du jeu | Fenêtre entière, texte lisible 📷 |
| F17 | Coexistence : pendant une run, avec FieldKit / Stats / ASRCombatText | Aucune gêne ; fenêtre fermée = aucun focus capté |
| F18 | **Appréciation visuelle** : le rendu est-il plus agréable ? Ce qui gêne encore (couleurs, tailles de police, densité) | Notes libres + captures : base du prochain ajustement visuel |
| F19 | (reste de la recette 0.4.0) E22 : bannir un sort déjà possédé est-il possible en jeu ? | Réponse notée |

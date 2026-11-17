# Recette client — Reborn Build Planner 0.4.0-alpha (≈ 25 min)

**Statut : NON EXÉCUTÉE.** Tout ce qui suit est attendu, issu d'une simulation (Lua 5.1 + widgets simulés). Aucune capture réelle n'existe. Installation : `INSTALL.md` / `UPDATE_FROM_0.3.1.md`.

| # | Étape | Attendu |
|---|---|---|
| E1 | `/rbp diag` | `version 0.4.0-alpha, … catalogue 384db000d5ac311d (OK)`, aucune erreur Lua |
| E2 | `/rbp` en 1920×1080 puis 1280×720 puis 1024×768 | Fenêtre entière visible, 3 zones, **opaque** (aucun texte du jeu à travers) 📷 ×3 |
| E3 | « Créer un build » : valider avec un nom vide ; puis un nom + classe | Message rouge, le dialogue reste ; sinon le build s'ouvre au centre, **non suivi**. Champs alignés, classe de votre personnage présélectionnée 📷 |
| E4 | Cliquer « + Ajouter un sort » puis « Ajouter » sur 6 sorts du catalogue | 6 lignes numérotées, compteur « 6 garder / 0 bannir après (max 3) » |
| E5 | Sur 3 sorts : « Conserver » → « Bannir après » ; essayer un 4ᵉ | Texte du bouton change + ligne teintée ; 4ᵉ refusé avec message |
| E6 | Monter/descendre, retirer un sort marqué | La marque suit le sort ; le retrait l'annonce |
| E7 | Cliquer l'emplacement « Anneau - Alt. 1 » vide | Catalogue sur Anneaux, ligne « Cible : Anneaux - Alternative 1 (vide) », emplacement préfixé `>` |
| E8 | « Placer » ; recliquer un emplacement rempli puis « Placer » un autre anneau | Remplacement direct, autres emplacements inchangés ; une pièce déjà placée est grisée « Placé » |
| E9 | Trinkets et amulette de la même façon ; « x » pour vider | Les 12 emplacements visibles en même temps, alternatives conservées |
| E10 | Cliquer un sort / une pièce (catalogue, plan, emplacement) | L'inspecteur (droite) affiche nom, icône, détails et **la source**. Pour un sort : texte natif du jeu — **noter s'il correspond bien à Reborn** 📷 |
| E11 | Survoler les mêmes éléments | Infobulle, disparaît en quittant / changeant de page ; reste dans l'écran près des bords |
| E12 | « Notes et avancé » : notes avec accents, lien, talents (Ctrl+V) ; « Retour au catalogue » | Texte conservé ; Échap sort du champ sans fermer le dialogue |
| E13 | « Enregistrer », `/reload`, rouvrir `/rbp` | Build, marques, équipement, favoris intacts ; position de la fenêtre retrouvée |
| E14 | Créer 3 builds de classes différentes ; étoile sur un ; rechercher par nom, par classe, par nom de sort | Filtre immédiat ; favori en premier ; filtres Tous / Favoris / Récents ; tri par dernière utilisation / modification 📷 |
| E15 | Modifier un build sans enregistrer, cliquer un autre build | Invite Enregistrer / Abandonner / Continuer ; rien n'est perdu en silence |
| E16 | Dupliquer, supprimer (lire l'explication), « Annuler la suppression », Corbeille → Restaurer | Aucune suppression silencieuse ; le favori revient avec le build restauré |
| E17 | « Enregistrer et suivre » | « Enregistré et suivi », étiquette « Actif » dans la liste |
| E18 | Exporter (bouton du haut) un build avec marques ; coller le code dans le planner du site | Liste de pertes avec « Bannir après acquisition n'existe pas dans le format officiel » ; code après acceptation ; le site affiche les 6 sorts sans bannissement 📷 |
| E19 | Importer un code (Ctrl+V → Analyser → Importer) à 4 étapes | 4 étapes visibles, non suivi, rien perdu à l'enregistrement |
| E20 | Taille - / + ; autre échelle d'interface du jeu | Fenêtre toujours entière, texte lisible 📷 |
| E21 | Coexistence : ouvrir pendant une run ; FieldKit / Stats / ASRCombatText | Aucune gêne aux cartes ni aux touches ; fenêtre fermée = aucun focus clavier capté |
| E22 | **Question de jeu** : lors d'une proposition de montée de niveau, un sort **déjà possédé** peut-il être banni (bouton « Banish n ») ? À quelle condition (talent de compte, nombre) ? | Réponse notée ; le planner ne bannit jamais |

À renvoyer : tableau E1-E22 (OK/KO + remarque), captures 📷, texte exact des erreurs. Les C1-C18 (Lot 3) et D1-D16 (Lot 3.1) non encore exécutés sont couverts par E1-E22 pour l'essentiel.

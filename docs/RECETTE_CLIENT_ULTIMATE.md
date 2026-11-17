# RECETTE CLIENT — Ultimate UI 0.4.5-alpha

**Statut à la création : NON EXÉCUTÉ dans le jeu.** Les tests Lua hors jeu ne remplacent pas ces observations.
La recette n'installe rien automatiquement. Les SavedVariables réelles ne doivent jamais être écrasées.

## Préparation — ZIP reproductible

Depuis `reborn-build-planner/` sur Windows :

1. Vérifier les sources locales `data/v1` correspondant à la version Reborn installée et repérer le véritable exécutable `.exe` du jeu.
2. Disposer de Python 3 avec Pillow, d'un environnement isolé `.devtools/venv` avec `lupa 2.8` (Lua 5.1), et de Node pour la comparaison facultative du codec.
3. Exécuter en PowerShell, en remplaçant les deux chemins par ceux présents sur **ta machine** :

```powershell
python -m pip install Pillow
powershell -ExecutionPolicy Bypass -File tools\recette_ultimate_windows.ps1 -GameExe "CHEMIN\VERS\AzerothSurvivorsGame.exe" -CatalogDir "CHEMIN\VERS\data\v1"
```

Le script refuse les tests obligatoires échoués/sautés, une extraction incomplète et un ZIP sans fichiers attendus. L'éventuel test JS du codec officiel non fourni est le seul saut accepté et annoncé dans `RECETTE_RESULT.md`.

Le dossier `dist/ultimate-0.4.5-recette/` contient le ZIP à vérifier. Les métadonnées de bijoux extraites sont conservées dans `.local/generated/` et ajoutées au ZIP **uniquement** lors du packaging. L'exécutable reste inchangé. N'ajoute pas de données locales à Git.

**Installation manuelle :** sauvegarder le dossier existant `RebornBuildPlanner` et sa SavedVariable `RebornBuildPlannerDB` avant de copier le dossier du ZIP dans `Interface\AddOns` du client Reborn. Ne jamais écraser `AzerothSurvivors`, `AzerothSurvivorsAPI`, Stats ou FieldKit.

## Scénarios à enregistrer — marquer OK / KO / PARTIEL

| ID | Scénario | Critère |
| --- | --- | --- |
| U01 | Charger le client, afficher `/rbp diag` | Addon chargé, catalogue `OK`, pas d'erreur Lua |
| U02 | Ouvrir `/rbp` en jeu | Cadre, textures et boutons visibles, aucun HUD du jeu devant la fenêtre |
| U03 | Recharger `/reload` | Builds et statut suivi conservés, pas de migration destructive |
| U04 | Capturer à 1920×1080 et 1365×768 | Aucun chevauchement visible, notamment titres, cases, champs, boutons |
| U05 | Zoom +/- et redimensionnement du jeu | Police lisible, fenêtre dans l'écran, aucune case inaccessible |
| U06 | Bibliothèque : recherche, favoris, récents, classe, tri | Filtrage instantané et cohérent, sans pages inutiles |
| U07 | Créer un build, renommer, dupliquer puis supprimer/annuler | Aucune perte de données, confirmation destructive correcte |
| U08 | Ouvrir un build sauvegardé | Vue unique, 6 sorts et 12 cases simultanément accessibles |
| U09 | Réorganiser les sorts et marquer trois « Bannir après » | 6 sorts gardés, 3 marques stables ; la quatrième est refusée |
| U10 | Cliquer cases principales et alternatives | Le navigateur sélectionne le bon type, cible explicite ; aucun placement accidentel |
| U11 | Choisir une pièce à droite | Affichage dans les détails sans la placer immédiatement |
| U12 | « Placer ici », remplacer, vider et revenir | Seule la case ciblée change ; autres cases intactes |
| U13 | Survoler sorts, bijoux, anneaux, amulettes | Infobulles lisibles, sans recouvrement gênant ni texte coupé |
| U14 | Anneau d'Accuria (et 2 autres anneaux) | Bonus de base visible **si** extraction correspondante, clairement marqué non actuel |
| U15 | Envergure de Blackhand (et 2 autres bijoux) | Effet identifié et valeur de base ; comparer avec description/jeu sans confondre rareté et base |
| U16 | Amulette fixe + amulette légendaire | Effets, croissance, classe et FR/EN corrects ; clé légendaire non ambiguë |
| U17 | Changer FR ↔ EN | Pas de clés internes affichées en lieu de traductions connues ; texte tronqué accessible |
| U18 | Import `azsb1:` puis export | Aperçu, erreurs et pertes explicites ; nouveau build non suivi automatiquement |
| U19 | Quitter avec modifications non enregistrées | Enregistrer / Ignorer / Continuer ; Échap ne détruit rien |
| U20 | Coexistence avec les autres addons + une run | Pas de blocage de cartes, ralentissement notable ou action automatique |

## Preuves à conserver

Une capture plein écran `U02`, une capture éditeur rempli `U08`, une capture détails d'anneau et de bijou `U14/U15`, une d'amulette `U16`, `/rbp diag` et les lignes KO seulement.

Comparer les valeurs des bijoux avec le **même client installé**. Les statistiques affichées sur les cartes dépendent des rangs, de la rareté et de la partie ; une différence avec le coefficient de base n'est pas automatiquement une erreur.

## Retour arrière

Fermer Reborn, retirer uniquement `Interface\AddOns\RebornBuildPlanner` de cette version puis restaurer la copie précédente du dossier. Restaurer la sauvegarde des SavedVariables uniquement si nécessaire, **sans** effacer des changements récents sans choix explicite. Le laboratoire `RebornPlannerThemeLab` peut être supprimé séparément. Aucune publication ni installation automatique ne fait partie de cette recette.

## Règle de livraison

Pas de PASS final sans U01-U20 correctement documentés. Les tests simulés ne certifient ni le rendu, ni les saisies réelles, ni les valeurs des mains de cartes.

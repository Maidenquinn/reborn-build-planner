# Reborn Build Planner 0.5.0-alpha-live1 — Lot 4 recette native

## Origine et périmètre

Références lues dans les dépôts `cadoky/ASBuilder` (Tracker.lua), `AlexEnotov/ASR-Addons` (ASRAdvisor/Core.lua, Runtime.lua, UI.lua) et `Maidenquinn/azeroth-fieldkit` (Theme.lua, ZoneThemes.lua, assets Elwynn). Les usages de `AZS.On`, `AZS_SPELLS`, `AZS_GEAR`, `AZS_CARDS`, `AZS_RUN`, `AZS_ZONE` et `AZSCardN` sont inspirés des contrats publiquement observables, **sans copier les implémentations ni les ressources tierces**.

Nouvelle version **0.5.0-alpha-live1** : premier compagnon de partie, strictement informatif, pas une validation finale de toutes les versions du client.

## Fonctionnalités implémentées

1. **Suivi réel (lorsqu'un build est explicitement Suivi)** : l'addon prend la classe via `UnitClass("player")`, retrouve `Storage:GetActive(class)`, puis reçoit les actualisations de `AZS.On`. Le mini-HUD n'apparaît qu'en partie. Aucun polling `OnUpdate`.
2. **Progression des sorts** : compare les six objectifs à des clés de `AZS_SPELLS`. Respecte les conditions d'acquisition et de rang. Un sort « Bannir après » acquis est signalé distinctement. Une valeur absente ou non confirmée = **Inconnu**, pas Manque.
3. **Équipements** : compte uniquement les clés non ambiguës transmises dans `AZS_GEAR`. Les autres restent *Inconnus*. Alternatives reconnues sans considérer le texte du tooltip, la rareté ni l'icône comme un identifiant.
4. **Carte de choix native** : des bordures et mini-étiquettes sans interception des clics signalent une compétence voulue (vert), à éviter (rouge), à bannir après acquisition (ambre rouge), ou un bijou/anneau/amulette prévu en principal/alternative (vert/ambre). L'overlay ne prend jamais le contrôle des cartes ni des boutons Banish/Reroll.
5. **Thèmes** : `Standard` (indigo/acier) et `Elwynn` (forêt/or). Si FieldKit est installé, Elwynn réutilise **par chemin**, sans recopier, son média `elwynn_card_body_v9.tga`. Sans FieldKit, fond/teintes Elwynn autonomes. Bouton `STD/ELW` en haut du HUD.
6. **Phases** : bouton explicite **Étape 1/4** pour passer manuellement à l'étape suivante. On ne déduit jamais une étape du niveau ou du nombre de sorts. Réinitialisation à l'étape 1 sur un identifiant de run différent.
7. **Préférences** : `trackerTheme` et `trackerEnabled` ajoutés à `settings` avec validation, valeurs par défaut et sans migration de schéma. Le HUD est déplaçable.

## Commandes

- `/rbp` : planificateur principal (inchangé)
- `/rbp hud` : activer/désactiver le mini-HUD (persistant)
- `/rbp theme` : basculer Standard/Elwynn
- `/rbp theme standard` / `/rbp theme elwynn` : sélection directe
- `/rbp diag` : version, stockage, catalogue, bijoux et état de connexion du suivi

## Ce que le Lot 4 ne fait PAS

- Aucun clic, choix, achat, reroll, bannissement ou changement de sort automatique.
- Aucun réseau ou exécutable externe au runtime.
- Pas d'enregistrement automatique de réussite de build ni modification des builds.
- Pas d'inférence d'objet à partir d'un nom/icon partagés.
- **Pas de journal de bannissements confirmés** : l'intention « Bannir après » se base uniquement sur acquisition et ne prétend pas savoir si le joueur a réellement effectué l'action.
- Pas de passage automatique entre quatre phases : c'est manuel pour éviter de faux déclenchements.
- Pas de certitude d'affichage sur toutes les configurations, résolutions et interfaces : validation native nécessaire.

## Construire la recette sur Windows (aucune modification automatique du client)

```powershell
git switch dev/ultimate-ui
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors" -GameExe "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\AzerothSurvivorsGame.exe"
```

**ZIP** : `dist\ultimate-0.5.0-local\RebornBuildPlanner-0.5.0-alpha-live1-recette.zip`.

Fermer le jeu, sauvegarder le dossier `RebornBuildPlanner` et `RebornBuildPlannerDB` des SavedVariables, puis remplacer le dossier d'addon seulement.

## Recette native à retourner

1. `/rbp diag` : version 0.5.0 et `Live tracker: events connected`. Si API indisponible, noter la ligne exacte, ne pas supposer que le suivi fonctionne.
2. Hors partie/hub : pas de fausse progression ni de mini-HUD actif.
3. Créer un build avec 6 sorts, le **Suivre**, entrer en partie, prendre 2 sorts : mini-HUD mis à jour après chaque événement `AZSSPELLS`, statut fiable ; acquérir une compétence « Bannir après » : rappel visible.
4. Pendant le choix de cartes : contour visible sur les cartes pertinentes, **aucun blocage de clic**. Vérifier saut, relance, clic Bannir, niveaux suivants ; aucun ancien cadre ne reste affiché une fois les cartes fermées.
5. Pour bijoux/anneaux/amulette : vérifier seulement les cartes aux **clés connues** ; en cas d'identité ambiguë, le HUD doit rester Inconnu plutôt que Manque.
6. `STD/ELW` : tester Standard puis Elwynn avec FieldKit installé, puis Elwynn sans FieldKit ; pas d'asset manquant/vert.
7. Bouton « Étape » : 1→2→3→4→1 ; nouveau run : repart en 1.
8. `/rbp hud` masque le HUD mais conserve les suggestions sur cartes. `/reload` conserve le thème et le choix d'affichage.
9. Déplacer HUD ; tester 1920x1080 et petite échelle ; aucune superposition bloquante.
10. Vérifier absence d'erreur Lua lors d'une partie complète et à la fin, après mort, /reload, changement de personnage.

**Risque connu** : l'API peut envoyer les tables initialement vides avant une vraie publication. Le moteur n'utilise un snapshot comme une donnée confirmée que lorsqu'il a reçu son événement correspondant. Captures de l'utilisateur requises pour valider ce comportement et les effets des thèmes.

**Aucune fusion sur main, aucune release publique.**

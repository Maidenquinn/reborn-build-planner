# Reborn Build Planner — 0.4.9-alpha-polish (18 novembre 2026)

**État : pré-recette native.** Pas de release, pas de merge sur main. Les tests hors jeu ne prouvent pas le rendu ni les interactions dans le client.

## Réponse aux captures 0.4.8

### Fenêtre « Modifications non enregistrées » (correctif prioritaire)
- Les trois boutons Enregistrer / Ignorer / Continuer à modifier sont créés dans un pied de modale dédié, ancré au bas de la fenêtre, avec leur propre niveau de frame au-dessus des panneaux.
- L'affichage est réinitialisé à chaque ouverture ; les boutons ont toujours leur label, leur état actif et leur rôle.
- Un fond assombri intercepte les clics sur l'éditeur tant que la modale est ouverte ; ce fond disparaît quand elle se ferme.
- Barre de titre spécifique et hiérarchie de texte plus nette.
- Tests Lua hors client : les trois boutons sont créés et visibles dans le modèle de widgets, leur niveau est supérieur à celui du planner ; l'assombrissement est présent et se retire. **Validation indispensable en client réel.**

### Traductions et choix de langue
- Le planner dispose désormais d'un bouton de langue visible dans la barre supérieure, `Langue : FR` / `Language: EN`.
- FR et EN sont les **deux langues effectivement prises en charge**. Comme FieldKit et Stats dans le périmètre connu, le choix est persistant et la traduction s'actualise sans recharger l'addon.
- Les clés anglaises servent de référence et sont traduites en français par `UIStrings.lua` et `Locale.lua`. Un test automatique vérifie les libellés français de l'éditeur.
- Les langues non encore traduites par des dictionnaires complets utilisent le repli EN ; il serait inexact d'annoncer « toutes les langues du jeu ».
- Les noms légendaires officiels ne disposent pas tous de traductions officielles dans les données : la traduction communautaire de titres est distinctement signalée.

### Nouvelle finition « Moonsteel »
- Ressources procédurales originales (aucune texture Blizzard redistribuée).
- Matériau acier bleu nuit à grain fin et halo très discret, triple biseau, lignes polies, gravures d'angle réduites pour ne pas gêner les étiquettes.
- Titre avec reflets, profondeur et filigrane ; titres de formulaire moins saturés, réservant les couleurs d'accent aux états importants.
- Le squelette bibliothèque gauche / éditeur centre / catalogue droit et la capacité de lecture 1280×720 sont conservés.

## Vérification continue

GitHub Actions `Ultimate UI source checks` et `Ultimate UI private preview package` sur la branche `dev/ultimate-ui` : réussite au commit de recette. Vérification complète avec catalogue public : **233 cas Lua 5.1, 15 800 assertions, 0 échec**, générateur 85 assertions validées. Les tests comprennent la présence du pied de modale et la persistance FR/EN.

## Construire le ZIP privé avec les 44 mécaniques locales

Depuis le clone Git à jour sous Windows :

```powershell
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors" -GameExe "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\AzerothSurvivorsGame.exe"
```

Le ZIP enrichi est produit dans `dist/ultimate-0.4.9-local/`. Le package téléchargeable de GitHub Actions ne contient pas les données de l'exécutable utilisateur. Le script lit le client local sans modifier les fichiers du jeu ni les SavedVariables ; aucune donnée dérivée ne doit être committée.

## Contrôle en jeu prioritaire

1. `/rbp diag` : version `0.4.9-alpha-polish`, catalogue OK, 44/44 mécaniques locales (si l'extraction est toujours exhaustive).
2. Ouvrir un build, modifier un sort, cliquer un autre build ou fermer la fenêtre : trois gros boutons visibles, cliquables en bas de la modale. Vérifier Enregistrer / Ignorer / Continuer séparément ; aucun changement perdu involontairement.
3. Changer Langue FR -> EN -> FR sans fermer la fenêtre, puis `/reload` pour confirmer persistance.
4. Tester lisibilité à l'échelle usuelle et fenêtre centrée/déplacée ; pas de texte jaune/bleu à faible contraste, de chevauchement ou de texture blanche.
5. Contrôler bijoux et amulettes déjà validés en 0.4.8 pour non-régression.

**Ne pas fusionner la PR avant cette recette visuelle et fonctionnelle.**

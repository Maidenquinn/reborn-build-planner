# Reborn Build Planner — Recette 0.4.13-alpha-library

## Source de la demande

Captures de l'utilisateur du 18/11/2026 (version 0.4.12) comparées à ASBuilder 1.13.1. L'utilisateur apprécie désormais l'éditeur et souhaite une bibliothèque de builds plus identifiable : icône de classe, couleur du nom selon la classe, favori en cœur à droite, filtre de classe et tri en menus déroulants.

## Implémentation

### Lignes de build

- Icône à gauche provenant de l'atlas de classes natif `Interface/WorldStateFrame/Icons-Classes` si la classe y existe. Si elle est absente (notamment Moine / Chasseur de démons dans certains clients 3.3.5), repli vers l'icône du premier sort de cette classe **tiré du catalogue officiel**, sans inventer d'icône.
- Nom coloré selon les teintes WoW des 12 classes prises en charge. Classes inconnues : teinte neutre.
- Sous-ligne affichant classe localisée et date (si métadonnées disponibles). L'état Suivi / Réparer / Supprimé est indépendant de l'icône favori et reste lisible.
- Favori à droite : cœur vide et cœur rempli. Les deux petites textures TGA originales sont générées par `tools/make_ultimate_art.py` et incluses dans les packages. Clic direct sans sélectionner ni suivre le build. L'ordre « favoris d'abord » existant est conservé.
- Survol de la ligne : nom complet, classe, date de dernière modification, statut. Les noms longs peuvent être raccourcis **à l'écran**, jamais dans le stockage.

### Filtres

- Classe : menu déroulant `Toutes les classes` + classes du catalogue officiel, localisées et avec icône de classe dans les options. Choix en un clic ; ferme le menu et applique le filtre sans modifier de build.
- Tri : menu déroulant avec cinq critères : Nom, Date de création, Date de modification, Dernière utilisation, Classe. Les favoris restent toujours affichés en premier conformément au comportement existant.
- Les préférences de tri sont enregistrées dans `libSort`. Les deux nouvelles valeurs `created` et `class` sont reconnues par la validation de paramètres. Aucune migration de SavedVariables n'est nécessaire.
- Les menus et leur écran de clic extérieur sont créés une seule fois ; pas de boucle `OnUpdate` ni d'allocation continue. Un clic à l'extérieur ferme le menu sans cliquer sur l'élément derrière.
- Un popup langue ou modal peut fermer proprement les menus de la bibliothèque.

## Tests

Tests Lua 5.1 vérifient :
- Les icônes de classe/leur repli, les couleurs des noms, les deux états de cœur.
- Le favori activable directement depuis la ligne sans l'ouvrir.
- La sélection de classe depuis le menu et la suppression du filtre (Toutes les classes).
- Les cinq options de tri, la persistance des deux nouvelles valeurs et la fermeture extérieure.
- Les anciennes fonctionnalités de la bibliothèque : favoris en tête, tri, dates, statut, sélection, corbeille, recherche et absence de débordement.
- La liste exacte des modules TOC, la présence des nouvelles textures et le packaging.

## Préparation du ZIP privé Windows

Dans le clone local sur `dev/ultimate-ui` :

```powershell
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors" -GameExe "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\AzerothSurvivorsGame.exe"
```

ZIP attendu : `dist\ultimate-0.4.13-local\RebornBuildPlanner-0.4.13-alpha-library-recette.zip`. Les 44 mécaniques de bijoux restent extraites **uniquement** du client local lors de ce build, jamais commitées.

## Recette native (à effectuer avant tout merge)

1. Ouvrir `/rbp diag` et vérifier `0.4.13-alpha-library`, catalogue, `44/44` si exécutable identique.
2. Bibliothèque de classes différentes : icône appropriée, nom coloré, statut Suivi à part, cœur à droite. Vérifier Moine et Chasseur de démons (fallback).
3. Cliquer un cœur sans ouvrir le build : la ligne remonte parmi les favoris, son nom et sa classe restent inchangés.
4. Menu de classe : sélectionner Chasseur puis Toutes les classes ; filtrage immédiat. Tester FR/RU/EN et libellés longs.
5. Menu de tri : tester Nom, Création, Modification, Dernière utilisation, Classe ; fermer avec un clic à l'extérieur. Après `/reload`, la préférence de tri persiste.
6. Noms longs, petites fenêtres, déplacement du planner et survol de ligne : pas de chevauchement ; tooltip affiche le nom complet.
7. Créer/renommer/éditer un build et tester la modale des modifications non enregistrées : aucune régression. Sauvegardes existantes intactes.

**Limites** : icônes et atlas 3.3.5 à valider sur le vrai client, le harnais Lua vérifie la logique mais pas le rendu. `main` non modifiée, pas de publication publique.

# Ultimate UI — Direction artistique et contrat visuel

Statut : **cadrage initial, non approuvé visuellement**. Base : 0.4.3-proto2 Theme Lab, screenshots Reborn du 17 novembre 2026. Aucune modification du gameplay ni des SavedVariables.

## Résultat attendu

Un planner de fantasy/MMO identifiable à première vue comme une interface de jeu, et non un panneau administratif sombre. L'utilisateur a refusé les prototypes v1 et v2 : leurs différences se résument surtout à des bordures, teintes et dégradés. **Ne pas porter Theme v2 directement sur UI.lua.**

## Contraintes validées

- Addon natif WoW 3.3.5a / Interface 30300, Lua 5.1 ; aucune dépendance runtime.
- Bibliothèque persistante à gauche ; composition complète au centre ; catalogue filtrable à droite ; inspecteur en dessous du centre.
- Six sorts souhaités, trois marques banishAfter, 12 emplacements d'équipement, alternatives, recherche, import/export, SavedVariables intacts.
- Explications d'effets uniquement à partir de données prouvées. Traductions légendaires communautaires explicitement désignées comme telles.
- 1280×720 utilisable : composants secondaires repliables plutôt que police minuscule.

## Diagnostic des captures client

1. Double colonne du Theme Lab v2 : l'ancienne et la nouvelle version ont une géométrie et une densité presque identiques.
2. Les actifs visuels sont de très petits motifs TGA étirés : bordures répétitives, faibles variations de matière, aucun point focal fantasy.
3. Aucune identité forte dans la barre de titre ; boutons et liste ont les mêmes proportions qu'un formulaire.
4. Le texte et les commandes sont trop serrés pour être confortables à l'écran du jeu ; nombreux noms tronqués.
5. Les hiérarchies de rareté, priorité et actif/inactif doivent être lisibles au premier regard.

## Direction « Chroniques d'Azeroth » (proposition pour validation)

- **Signature visuelle** : bandeau avec médaillon central distinctif, plaques d'ardoise bleutée, métal gravé aux coins, halo or subtil pour la sélection.
- **Palette** : graphite bleu #111927 ; ardoise #1D2A3B ; or vieilli #C9A45D ; ivoire #F0E5CE ; bleu magique #375C8A ; rouge oxydé #873A38 (suppression uniquement).
- **Matériaux** : texture discrète de pierre/parchemin teinté sur grands panneaux, métal brossé sur le bandeau et cadre, états lumineux localisés au survol. Pas de bruit répétitif à haute fréquence sur les champs de texte.
- **Typographie** : titre 19–21 px, sections 14–15 px, contenu 12–13 px minimum à l'échelle courante ; chiffres et badges lisibles ; noms complets dans l'inspecteur.
- **Boutons** : une commande principale dorée par groupe ; commandes secondaires acier sombre, sans encadrement doré systématique ; suppression rouge, confirmation explicite.
- **Emplacements** : silhouette distincte vide/rempli/sélectionné ; numéro et type dans une bande non superposée ; icône avec cadre de rareté ; plus d'espace interne pour le nom.
- **Catalogue** : entrées moins hautes que des cartes complètes mais avec icône, nom (jusqu'à deux lignes au besoin) et type/rang, recherche fixe, scroll ; filtre automatiquement dérivé de l'emplacement choisi.
- **Inspecteur** : véritable carte de description, mise en page organisée par identité, effet, croissance, origine ; sa hauteur est réservée et défilable.

## Contrat du prochain prototype

1. Créer un **aperçu statique grandeur 1280×720** avec un build chasseur complet, son équipement et un objet sélectionné. Les noms/valeurs illustratifs doivent être explicitement marqués comme mockup.
2. L'aperçu doit différer radicalement du Lab v2 par la **silhouette, la matière, les marges et l'ordre des informations**, pas simplement par les couleurs.
3. Fournir avant tout portage au Lua : capture ou export PNG, fichiers source et inventaire de ressources. Ne pas présenter l'aperçu comme un screenshot client.
4. Après approbation : prototype client minimal de 5 composants (fenêtre, bouton, ligne de sort, case d'équipement, entrée de catalogue). Tester chargement des TGA, scroll et opacité dans Reborn.
5. Une fois le prototype client validé : migrer l'UI entière sur la branche dev/ultimate-ui et lancer tests de non-régression.

## Garde-fous Git

- `main` préservée.
- Ne jamais committer `GeneratedCatalog.lua`, les copies JSON officielles ou le bundle JavaScript tiers.
- Modifications par petits commits et PR vers `main` uniquement après recette visuelle et fonctionnelle.
- Aucun conseil live (Lot 4) tant que l'éditeur n'est pas approuvé.

## Critères d'approbation UX

L'utilisateur doit reconnaître immédiatement l'identité fantasy, lire les commandes sans zoomer, identifier le build actif, placer un équipement sans changer d'écran, et ne voir **aucun chevauchement**. La validation par scripts de rectangles ne remplace pas une capture du vrai client.

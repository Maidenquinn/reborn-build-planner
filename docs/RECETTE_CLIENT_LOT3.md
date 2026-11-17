# Recette client — Reborn Build Planner, Lot 3 (≈ 25 min)

**Statut : NON EXÉCUTÉE.** Aucun résultat ci-dessous n'a été observé : ce sont les comportements attendus. Le Lot 3 n'est `PASS` que lorsque cette recette a été faite dans le client Reborn.

## Installation (ne touche aucun autre addon)
1. Fermer le jeu. Sauvegarder (copie) le dossier `Azeroth Survivors\Interface\AddOns` ou au moins noter qu'il ne contient pas encore `RebornBuildPlanner`.
2. Extraire `RebornBuildPlanner-<version>-recette.zip` **dans** `…\Azeroth Survivors\Interface\AddOns\` : le dossier `RebornBuildPlanner\` (16 fichiers) apparaît à côté de `AzerothSurvivors`, `AzerothSurvivorsAPI`, etc. Rien d'autre n'est modifié.
3. Lancer le jeu, écran de sélection / liste des addons : `Reborn Build Planner` doit être coché, dépendances `AzerothSurvivors` et `AzerothSurvivorsAPI` satisfaites. S'il est marqué « incompatible », noter la raison.
4. Désinstallation : supprimer le dossier `RebornBuildPlanner` ; ses données sont dans `WTF\Account\<compte>\SavedVariables\RebornBuildPlanner.lua` (à supprimer pour repartir de zéro). Aucun autre fichier n'est écrit.

## Procédure
Pour chaque étape : noter OK / KO + une phrase ; joindre une capture d'écran quand c'est indiqué (📷). Ne joindre aucun fichier de profil ni de journal complet.

| # | Étape | Attendu |
|---|---|---|
| C1 | Entrer dans le monde (hub). Taper `/rbp diag` | une ligne en chat : `version 0.3.0-lot3, storage CREATED, catalogue 384db000d5ac311d (OK)`. Aucune erreur Lua (si un addon d'erreurs est installé, noter tout message `RebornBuildPlanner`) |
| C2 | `/rbp` puis `/rebornplanner` | la fenêtre s'ouvre, puis se ferme ; langue = celle du client (français si `frFR`) ; état vide « Aucun build pour le moment » 📷 (1280×720 **et** 1920×1080) |
| C3 | Vérifier les collisions : `/rbp` n'ouvre pas autre chose ; les autres commandes de l'interface (`/azsedit`, `/azstatsr`, `/fk…`) fonctionnent toujours | aucun conflit |
| C4 | Déplacer la fenêtre (glisser dans une zone vide), la fermer, la rouvrir ; `/reload` puis `/rbp` | position retrouvée ; `/rbp reset` la recentre |
| C5 | **Créer un build** : nom `Test é`, classe proposée = votre classe ; Créer | l'éditeur s'ouvre, statut « Enregistré », build **non suivi** dans « Mes builds » |
| C6 | Éditeur : ajouter 6 sorts avec « Souhaiter » ; tenter un 7ᵉ ; monter/descendre ; retirer ; bannir 3 sorts ; tenter de bannir un sort souhaité | limite signalée, ordre correct, 3 bannissements séparés, aucune superposition de boutons 📷 |
| C7 | Onglet Bijouterie : placer un anneau en « Alternative 1 » en laissant les principaux vides ; placer un bijou et une amulette ; vider un emplacement | trous conservés, aucune icône seule sans nom |
| C8 | Onglet Notes : taper des notes avec accents et retours à la ligne, un lien, une chaîne de talents ; coller du texte avec **Ctrl+V** | le texte apparaît tel quel ; la frappe n'est pas capturée par le jeu pendant la saisie ; Échap sort du champ |
| C9 | « Enregistrer » ; fermer l'éditeur ; `/reload` ; rouvrir | le build et son contenu sont intacts |
| C10 | Modifier sans enregistrer puis « Fermer » : choisir « Continuer », puis « Ignorer » ; refaire avec Échap | invite à 3 choix ; Échap n'ignore jamais les modifications |
| C11 | « Enregistrer et suivre » | « Enregistré et suivi » ; la bibliothèque affiche « Suivi » ; rien ne se joue tout seul |
| C12 | Bibliothèque : dupliquer, renommer, supprimer (lire l'explication de la corbeille), « Annuler la suppression », ouvrir la corbeille et restaurer | aucune suppression silencieuse |
| C13 | **Export** : sélectionner un build, Exporter. Cliquer dans la zone du code, **Ctrl+A puis Ctrl+C**, coller dans un fichier texte ou le planner du site (`azreborn.com/planner/<classe>` → import) | le code est copiable ; le site l'ouvre avec le même contenu 📷 |
| C14 | **Import** : copier un code `azsb1:` (du site ou de C13), Importer → coller (Ctrl+V) → Analyser → lire l'aperçu → Importer | nouveau build **non suivi** ; un code invalide est refusé sans rien changer |
| C15 | Importer le code de test « conflit » fourni dans le rapport (clé d'une autre classe) | aperçu « Importable, à réparer » ; le build s'enregistre mais « Suivre » est refusé tant qu'il n'est pas réparé |
| C16 | Pendant une partie (run en cours) : ouvrir/fermer `/rbp`, déplacer la fenêtre | pas de gêne aux cartes ni aux touches ; la fenêtre ne bloque pas le clavier une fois fermée ; noter tout recouvrement avec les écrans de choix |
| C17 | Échelles : « Taille - / + », puis une autre échelle d'interface du jeu | fenêtre toujours entièrement visible, texte lisible 📷 |
| C18 | Accents français partout, noms longs (≥ 80 caractères) | aucun débordement hors cadre |

## À renvoyer
Tableau C1–C18 (OK/KO + remarque), captures 📷, sortie de `/rbp diag`, et pour tout KO : le message d'erreur exact (copier le texte, pas de capture illisible).

## Limites connues de cette version
Pas de suivi en partie, pas de conseils de cartes ; les statistiques, objectifs de rang et données inconnues sont conservés mais non éditables ; talents conservés comme texte (le site peut les réécrire) ; copier/coller par Ctrl+A/Ctrl+C/Ctrl+V uniquement (pas d'API presse-papiers) ; un brouillon non enregistré est perdu au `/reload`.

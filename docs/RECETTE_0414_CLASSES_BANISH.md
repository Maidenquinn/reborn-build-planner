# Reborn Build Planner 0.4.14-alpha-banish — Recette des classes et du bannissement

## Client observé
Sur captures du 18 novembre 2026, le filtre de classe affichait des cases vides pour **Moine** et **Chasseur de démons**. Les sorts « Bannir après » étaient traités comme de simples boutons et textes jaunes, ce qui ne distinguait pas assez clairement cette intention de la vraie liste « Éviter / Bannir dès l'offre ».

## Correctifs
- `ClassVisual.Icon` retourne désormais une texture **originale locale**, embarquée dans l'addon, pour `monk` et `demonhunter`. Les deux TGA `ultimate_class_monk.tga` et `ultimate_class_dh.tga` sont créés par `tools/make_ultimate_art.py`; ils ne dépendent pas de l'atlas 3.3.5 et apparaissent dans les lignes de builds et les options du filtre de classe.
- `Theme.FILES` et les tests d'inventaire sont passés de 25 à **27 textures** ; le packager Windows et le package privé CI vérifient leur présence.
- **Éditeur de sorts** : les trois sorts marqués `banishAfter` (maximum 3) ont un fin marqueur rouge à gauche, un fond rouge profond, un nom rose clair et un bouton `Bannir après` au style danger plutôt que jaune. Le compteur de bannissements prévus devient rouge discret si positif.
- **Navigateur de droite** : marqueur rouge sur les sorts à bannir après obtention, fond rouge sombre, étiquette d'état rouge. La liste `banish` (éviter si offert) est également rouge mais davantage estompée ; elle garde l'étiquette `Évité`, distincte de `Bannir après`.
- Le nom d'un sort `banishAfter` n'est **pas barré**, car il reste souhaité et doit d'abord être acquis. Il ne devient jamais « automatiquement banni » : ce sont seulement des intentions de planification.
- Aucun changement des clés, limites, décisions en jeu, sauvegardes, migrations ou API native.

## Vérifications automatiques
GitHub Actions sur `dev/ultimate-ui` : source checks PASS et private preview package PASS. Catalogue public : 17 fichiers ; générateur Python : 85 assertions PASS ; tests Lua 5.1 : **242 cas / 18 026 assertions / 0 échec**. L'archive CI a **23 fichiers** (source publique et textures uniquement) ; la recette privée Windows récupère également les 44 mécaniques locales depuis l'exécutable de l'utilisateur.

## Recette Windows
```powershell
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors" -GameExe "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\AzerothSurvivorsGame.exe"
```

ZIP local attendu : `dist\ultimate-0.4.14-local\RebornBuildPlanner-0.4.14-alpha-banish-recette.zip`.

Fermer le client et sauvegarder l'ancien dossier d'addon et ses SavedVariables, puis remplacer uniquement `RebornBuildPlanner`. Aucun script de recette ne modifie directement les fichiers du jeu.

## À vérifier dans le vrai client
1. `/rbp diag` : version `0.4.14-alpha-banish`, storage et catalogue OK, 44/44 mécaniques locales si l'exécutable est inchangé.
2. Filtre de classe : Moine et Chasseur de démons affichent leurs **nouveaux symboles originaux**. Même résultat si ces classes apparaissent dans la bibliothèque.
3. Éditeur : marquer un sort « Bannir après » : bouton rouge, liseré et fond rouge. Recliquer : retour au style neutre, nombre et nom du sort inchangés.
4. Navigateur : le même sort apparaît rouge avec le label `Bannir après`; un sort explicitement `Évité` est différent.
5. Vérifier que **le sort reste souhaité** dans les données après activation et que la limite reste 3 ; pas de bannissement automatique.
6. Tester le tooltip du bouton pour comprendre quand bannir, puis revenir au jeu ; absence de déplacement, troncature ou chevauchement à l'échelle de l'utilisateur.

**Le rendu réel de la 0.4.14 et les icônes sont à confirmer par capture.** Pas de merge `main`, pas de release publique.

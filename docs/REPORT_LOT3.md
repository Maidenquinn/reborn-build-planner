# Rapport — LOT 3 (interface native : bibliothèque, éditeur, import/export)

**Verdict : PASS CONDITIONNEL.** L'interface est complète et ses interactions sont validées **dans un environnement simulé** (135 cas Lua 5.1, 0 échec). **Aucune validation dans le client Reborn n'a eu lieu** : le client n'a pas été lancé, rien n'a été installé dans l'installation de production, aucune capture native n'existe. La recette client (C1-C18) est livrée et reste à exécuter par Kevin (`VALIDATION CLIENT REQUISE`).

## 1. Fichiers
* Addon (`addon/RebornBuildPlanner/`, 16 fichiers au total) — nouveaux : `Controller.lua` (comportement sans widget), `UI.lua` (rendu), `Commands.lua`, `UIStrings.lua` (FR) ; modifiés : `Core.lua` (`ADDON_LOADED` → `Start`), `RebornBuildPlanner.toc` (0.3.0-lot3, ordre de chargement), `Catalog.lua` (`ClassName`), `Storage.lua` (réglages `window`, `scale`, `lastClass`, validés), `BuildModel/PlannerCodec/Locale` inchangés au Lot 3 (les ajouts de Lot 2 restent).
* Tests : `tests/lua/test_ui.lua` (41 cas), `tests/lua/wowstub.lua` (simulateur de widgets + contrôle de mise en page), compléments `test_storage.lua` / `test_catalog.lua` / `test_sandbox.lua` (non-régression), `harness.lua` (globales vivantes).
* Livraison : `tools/package_addon.py` → dossier séparé `H:\Users\kevin\Documents\ChatGPT\AzerothSurvivorReborn\reborn-build-planner-recette-lot3\` contenant `RebornBuildPlanner\` (prêt à copier), `RebornBuildPlanner-0.3.0-lot3-recette.zip`, `RECETTE_CLIENT_LOT3.md`, `SHA256SUMS.txt`. Le package refuse un `.toc` incohérent.
* Docs : `CONTRACTS.md` §9 (U1-U11), `RECETTE_CLIENT_LOT3.md`, `PROJECT_STATE.md`, ce rapport.

## 2. Décisions d'architecture
* **Controller sans widget / UI mince** : tout le comportement (états, brouillon, import/export) est testable sans client ; l'UI ne fait que rendre et relayer les clics. Les modules validés (Storage, BuildModel, Catalog, PlannerCodec) ne sont pas réécrits ; seuls des réglages ont été ajoutés à `Storage`, avec tests.
* **Une fenêtre, quatre vues** (Mes builds / Éditeur / Importer / Exporter) + une boîte de dialogue unique réutilisée (création, renommage, suppression, modifications non enregistrées). Aucune fenêtre supplémentaire.
* **Widgets créés une fois** (412 objets à la première ouverture, 0 ensuite) ; listes paginées au lieu de défilement libre ; boutons textuels uniquement (aucun contrôle réduit à une icône ; les icônes du catalogue accompagnent toujours un nom).
* **Brouillon ≠ enregistré** : `Save`, `Save and follow`, `Discard changes`, `Close` (invite Enregistrer / Ignorer / Continuer). Pas de sauvegarde implicite ; Échap n'est lié à la fenêtre que si rien n'est en jeu.
* **Suppression** : corbeille annulable (20), explication avant confirmation, avertissement renforcé quand elle est pleine, nom du build évincé annoncé ; bouton « Annuler la suppression ».
* **Import** : champ → Analyser → aperçu (nom, classe, étapes, avis/conflits/erreurs paginés, pertes à la ré-exportation) → Importer ; build jamais actif ; refus sans mutation. **Export** : rapport de pertes avant le code, confirmation explicite, code dans une zone sélectionnable (Ctrl+A/Ctrl+C) ; le brouillon ou le build enregistré est indiqué.
* **Pas d'API inventée** : aucun presse-papiers, aucune API moderne ; toutes les API de widgets utilisées apparaissent dans les addons natifs installés (§9 U3).

## 3. Étape 3A — initialisation (réellement vérifiée : statique ; simulée : événements)
* Ordre : SavedVariables chargées avant `ADDON_LOADED` (principe du client 3.3.5a, trace `AZC_EVENTS` native) → `Storage.Open` → affectation de la globale seulement si non lecture seule (test avec base future : table inchangée, bannière « Lecture seule », édition bloquée).
* Commandes : aucune collision statique (`SLASH_*` des addons installés) ; collision d'exécution gérée (alias pris = laissé tel quel + message).
* **Non fait** : lancer le client (C1-C4 de la recette).

## 4. Tests (`python -I tools/run_all.py`, exit 0)
| Étape | Résultat |
|---|---|
| Catalogue à jour | identique |
| Générateur | 84 assertions, 0 échec |
| Lot 0 | 273 assertions, 0 échec |
| Lua 5.1 (toutes suites) | **135 cas, 6 980 assertions, 0 échec** (dont `test_ui` : 41 cas, 330 assertions) |
| JS ↔ Lua (décodeur officiel, Node) | 63 codes vérifiés |

Couverture demandée (`test_ui`) : initialisation des SavedVariables, commandes, ouverture/fermeture, bibliothèque vide, plusieurs classes, création/duplication/renommage, suppression et restauration, brouillon non enregistré, classe inconnue, import valide / à réparer / refusé sans mutation, export normal / avec pertes, conservation des phases cachées et des alternatives (trous), activation refusée si build à réparer, lecture seule, `/reload` (position, builds, actif), échelle, déplacement, absence de création de widgets, traductions complètes (balayage des littéraux), données sans texte traduit.
**Visuel** : contrôle de mise en page à 1365×768 (≈ 1280×720), 1920×1080, 1024×768, 800×600, en anglais et en français (noms de 80+ caractères, notes de 1 800 caractères, textes accentués, fenêtre déplacée, échelle 0,6 et 1,5, dialogues). **C'est un contrôle sur dimensions estimées (corps × 0,6), pas un rendu : il a trouvé et fait corriger 5 débordements réels de conception (statut, onglets, libellés FR, avertissement de notes, troncature des noms) mais ne remplace pas une capture.**
Le simulateur a aussi révélé un vrai défaut corrigé en cours de route (un message d'import effacé par le changement de vue ; Échap non resynchronisé à la fermeture de la fenêtre).

## 5. Compatibilité et risques client (à lever par la recette)
* Comportement réel de : `InputBoxTemplate`/`UIPanelScrollFrameTemplate` avec zone multiligne et focus clavier ; sélection `HighlightText` + Ctrl+C ; Ctrl+V dans une zone de texte ; `SetClampedToScreen` ; capture ou non des touches du jeu pendant la saisie ; superposition avec les écrans de cartes (`FULLSCREEN_DIALOG` des cartes natives) — la fenêtre est en `HIGH`, la boîte de dialogue en `FULLSCREEN_DIALOG` ; rendu des textes français, largeur réelle des polices (mon estimation est prudente mais approximative).
* Ouverture pendant une run : aucune action de jeu n'est liée à la fenêtre, mais la gêne visuelle/clavier n'est pas mesurée (C16).
* Coexistence avec FieldKit/Stats/ASRCombatText : non testée en jeu.

## 6. Limites restantes
1. Aucune capture ni test dans le client ; le simulateur n'est pas le client.
2. Éditeur : un seul plan visible par défaut ; statistiques, objectifs de rang/sans limite, extensions et talents (texte brut) sont **conservés et listés mais non éditables**.
3. Catalogue d'éditeur sans icônes dans le nombre de lignes (les noms suffisent) ; pas de tri ni de filtre autre que le texte.
4. Pas de glisser-déposer (volontaire) ; pas de raccourci clavier ; copier/coller uniquement par Ctrl+touches.
5. Un brouillon non enregistré est perdu au `/reload` ou à la déconnexion (par conception, pas d'enregistrement implicite).
6. Le suivi en partie et les conseils de cartes ne sont pas commencés ; aucune information « live » n'est affichée.
7. Les inconnues `P-*` des Lots 0-2 (identités de bijoux, `ph` pendant les mains, lignes vides de synchro, import par collage sur le site…) restent ouvertes.
8. Les commits sont regroupés par fichiers partagés (voir §7).

## 7. Commits locaux (aucun push)
`lot3a: native initialization and window` · `lot3b-e: library, editor, draft/save workflow, import/export dialogs` (Controller + UI forment un ensemble indissociable après coup) · `lot3: tests and documentation`.

## 8. Critères
PASS exigerait la recette client : **non satisfait**. PASS CONDITIONNEL : tests automatisés verts ✔, interactions validées en environnement simulé ✔, validation client explicitement à réaliser ✔ (procédure fournie). BLOQUÉ : aucun cas — pas de perte de données possible via l'interface dans les tests (suppression confirmée et annulable, édition par copie, import refusé sans mutation), activation refusée pour un build à réparer, aucun addon natif modifié (lecture statique seule), aucun accès réseau.

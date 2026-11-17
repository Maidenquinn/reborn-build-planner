# Rapport — LOT 3.2 (refonte UX/UI : bibliothèque intelligente, éditeur unifié, inspecteur)

**Verdict : PASS CONDITIONNEL.** Version de recette **0.4.0-alpha**, fonctionnelle et testée **en simulation** (Lua 5.1 : 183 cas, 7 934 assertions, 0 échec ; `tools/run_all.py` exit 0, Lot 0 de nouveau vert). **Le client Reborn n'a pas été lancé** : aucune capture réelle, rien installé en production. La recette E1-E22 (`RECETTE_CLIENT_LOT3_2.md`) reste à faire par Kevin (`VALIDATION CLIENT REQUISE`). Le Lot 4 n'est pas commencé.

## 1. Fonctionnalités livrées
* **Fenêtre unique en trois zones** (1120×704, mise à l'échelle automatique) : bibliothèque à gauche (23 %), éditeur complet au centre (52 %), inspecteur à droite (21 %). Import/export remplacent le centre ; la bibliothèque reste visible. Fond opaque, panneaux contrastés, strate `DIALOG`.
* **Bibliothèque** : recherche immédiate (nom, classe EN/FR, noms de sorts et de pièces, toutes étapes, mots combinés), filtres Tous / Favoris / Récents + classe, tri nom / dernière utilisation / dernière modification, favoris en premier, étoile par ligne, dates réelles, pagination (10 par page, 200 builds testés), un clic ouvre le build avec invite Enregistrer / Abandonner / Continuer, créer / dupliquer / renommer / supprimer + annuler + corbeille + restaurer, suivre / arrêter, importer.
* **Éditeur sur une page** : six sorts (icône, nom, priorité, haut/bas, retrait, **Conserver / Bannir après** avec compteur et refus d'une 4ᵉ marque) ; emplacements vides « + Ajouter un sort » ; **douze emplacements d'équipement visibles ensemble** (anneaux, bijoux, amulette ; principaux + alternatives, noms sur deux lignes, « x » pour vider) ; **catalogue intégré** (Sorts / Anneaux / Bijoux / Amulettes + recherche) avec **cible toujours affichée** (« Cible : Anneaux - Alternative 1 (vide) »), cliquer un emplacement filtre le catalogue, « Placer » remplace directement, jamais d'autre emplacement que celui choisi ; « Notes et avancé » (notes, lien, talents, nom d'étape, liste à éviter avec bouton Convertir, données conservées) ; quatre étapes importées conservées.
* **Inspecteur** : détails du dernier élément cliqué ; texte natif du sort (lu une fois, mis en cache) ; « Effet détaillé indisponible » sinon ; source indiquée. Infobulles au survol conservées.
* **Création** : champ nom et sélecteur de classe sur deux lignes distinctes (le défaut d'alignement de 0.3.x venait de leur superposition), classe du joueur présélectionnée, validation (vide / trop long) sans fermer le dialogue, rien créé en cas d'erreur.
* **Stockage** : `db.meta` (favori, utilisé, modifié, créé) hors des builds, réglages `libSort` / `libFilter`, schéma inchangé.

## 2. Changements UX par rapport à 0.3.1
Plus de navigation par vues ni d'onglets : tout sur une page. Plus de boutons « Fermer » / « Mes builds » : on clique un build. Libellés plus courts (contraintes FR) : « Ajouter / Éviter / Placer », « Conserver / Bannir après », « Abandonner », « Arrêter ». Export via le bouton du haut (brouillon courant). « Ajouter » remplace « Souhaiter ».

## 3. Architecture modifiée
`Controller` : recherche/filtre/tri avec cache d'index par (build, révision, langue) et liste recalculée une fois par `Notify` ; `OpenEditor` met à jour « utilisé » ; `SetCatalog` / `SelectSlot` / `TargetInfo` / `Inspect` / `InspectorData` / `ToggleFavorite`. `Storage` : `Meta`, `SetFavorite`, `Touch`, `stamp` (silencieux en lecture seule). `UI.lua` réécrit (≈ 1 000 lignes, mêmes helpers) : widgets créés une fois (≈ 590 objets), pas d'`OnUpdate`. `BuildModel`, `PlannerCodec`, `Catalog` inchangés.

## 4. Tests exécutés (résultats réels)
| Étape | Résultat |
|---|---|
| Catalogue, générateur (84), JS↔Lua (63 codes) | PASS |
| **Lot 0 (ancrages)** | **PASS (273)** après ré-ancrage (voir §6) |
| Lua 5.1 | **183 cas, 7 934 assertions, 0 échec** (+21 cas `test_lot32`, 41 + 27 portés à la nouvelle interface) |

Couverts : bibliothèque 0 / 1 / 20 / 200 ; recherche (nom, classe, sorts, pièces, mots) ; favoris, récents, tri, persistance après rechargement ; changement de build avec brouillon ; duplication, suppression, restauration, corbeille pleine ; lecture seule ; dialogue de création ; six sorts, trois marques, réordonnancement, retrait d'un sort marqué ; équipement, alternatives, placement et remplacement dans la cible, blocage des doublons ; notes et données cachées ; **quatre étapes importées conservées** ; classe inconnue ; conflits ; inspecteur (texte natif, absent, très long, inconnu, légendaires homonymes) ; migrations 0.3.0 et 0.3.1, métadonnées illisibles ou inconnues préservées ; index de recherche réutilisé, aucun widget créé en 100 rafraîchissements, aucun `OnUpdate`.
**Mise en page** : contrôle sur 1365×768, 1920×1080, 1024×768, 800×600, FR/EN, échelles 0,6 / 1 / 1,5, tout rempli, **sur largeurs de texte estimées** : cela a fait corriger une trentaine de débordements ; **ce n'est pas un rendu**.

## 5. Limites restantes
1. **Aucun test client** : opacité, focus clavier, Ctrl+C/V, clamp, infobulles près des bords, rendu des polices, lecture des lignes d'infobulle natives (`GameTooltipTextLeftN`) : tout est simulé.
2. 1120×704 réduit par échelle sur petits écrans (0,71 à 800×600) : texte petit mais disposition identique ; pas de disposition « repliable » de l'inspecteur (non faite : l'échelle suffit en simulation).
3. Effets des pièces d'équipement : **indisponibles** (ni catalogue, ni source statique) ; matrice des sources dans `DESCRIPTION_SOURCES.md`. Aucune statistique, aucun bonus de set, aucun niveau d'objet n'est affiché.
4. Pas de glisser-déposer, pas de navigation clavier/manette dans les listes, pas de rang cible éditable (conservé, non modifiable), pas d'édition des statistiques.
5. Recherche : minuscules ASCII seulement (une recherche « é » respecte la casse des accents).
6. `banishAfter` reste interne : l'export `azsb1:` annonce la perte (le site supprimerait un bannissement qui chevauche un sort).
7. Règle de jeu non prouvée : un sort déjà possédé peut-il être banni plus tard ? Les mains de montée de niveau proposent un bouton « Banish n » sous chaque carte (`Cards.lua:1351`), donc vraisemblablement via une carte d'amélioration, mais ni l'effet durable ni les conditions ne sont établis (E22). Le planner n'agit jamais.
8. Ancien bouton « Exporter » de la bibliothèque supprimé : l'export part du build ouvert (bouton du haut).

## 6. Contrats natifs actualisés (`CONTRACTS.md` §11)
Le code natif installé a changé le 2026-11-17 (20:51). Sur 54 ancres : **17 simples décalages de lignes** (motif inchangé, ré-ancrés) ; **1 changement sémantique, C09** : les bannissements (`bn`) existent aussi sur les mains de **bijoux** (le Lot 0 lisait « spell seulement ») — contrat R9 corrigé. Aucune API modifiée. Limite : les motifs ont été vérifiés, pas tout le code environnant. Les assertions n'ont pas été affaiblies. L'addon n'utilise aucun numéro de ligne à l'exécution. **Inconnus qui restent** : `P-C1`, `P-C2`, `P-S2`, `P-J*` (Lot 0), identité des bijoux, valeurs réelles de `src`/`mode`.

## 7. Fichiers livrés
* Addon : `reborn-build-planner-recette-lot3-2\RebornBuildPlanner\` (16 fichiers) + `RebornBuildPlanner-0.4.0-alpha-recette.zip` + `SHA256SUMS.txt` + guides (`INSTALL.md`, `UPDATE_FROM_0.3.1.md`, `CHANGELOG.md`, `DESCRIPTION_SOURCES.md`, `RECETTE_CLIENT_LOT3_2.md`).
* Projet complet : `reborn-build-planner-lot3-2-projet.zip` (sans `.git` ni venv).
* Docs : ce rapport, `PROJECT_STATE.md`, `CONTRACTS.md` §11, résultats `tests/results/run_all_lot32.txt`.
* Commits locaux (aucun push) : `lot3.2a` (ré-ancrage + stockage), `lot3.2b-e` (contrôleur + interface), `lot3.2f` (tests, documentation, package).

## 8. Prochaine action
Kevin exécute E1-E22 (≈ 25 min) et répond à E22 ; GPT relit. Ensuite seulement : décision sur une source fiable des effets d'équipement (données live ou export de contenu), puis Lot 4.

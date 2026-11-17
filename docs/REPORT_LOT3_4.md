# Rapport — LOT 3.4 (refonte des équipements, infobulles, données, traductions)

**Verdict : PASS CONDITIONNEL.** Version **0.4.2-alpha**, testée **en simulation** (Lua 5.1 : **206 cas, 11 773 assertions, 0 échec** ; `tools/run_all.py` exit 0, Lot 0 compris). **Aucune capture réelle** : le client n'a pas été lancé ; « nettement plus harmonieux » et « aucun chevauchement » ne sont donc **pas validés visuellement**, seulement par des mesures de rectangles simulés et des largeurs de texte estimées. Le Lot 4 n'est pas commencé.

## 1. Audit des données (point central)
* **Pièces d'amulettes** : le catalogue Lua généré (v1) avait **perdu** des champs publiés. Le générateur v2 conserve, sans les modifier, `amulets.json` → `growth`, `effects`, `special`, `world`, `needs` et `legends.json` → `template`, `form`, `effects`, `growth`, `fixed`. Hash de contenu inchangé (`384db000d5ac311d`). Un test compare chacun des 22 + 237 enregistrements Lua au JSON publié.
* **Règles officielles** (guide `data-api`) appliquées à la lettre : `multiplicateur = 3 − 2 × (1 − growth / 2)^(rang − 1)` (exemple du guide vérifié : 1,2× au rang 2 pour 0,2) ; pièces `fixed` : croissance linéaire des dégâts et de la zone, plafond rang 11 ; valeurs « part » en %, sauf `regen`, `kill_heal`, `lives`, `targets` ; `targets` non calculé au rang 5 (pas spécifié).
* **Anneaux et bijoux** : `jewelry.json` ne publie **aucun** effet. `Content.lua`, `AZSCARDS`, `AZS_GEAR` examinés et écartés (runtime, sans clé de catalogue). Rien n'est inventé : « Effet détaillé indisponible ». Proposition pour SNX : `API_PROPOSAL_JEWELRY.md`. Matrice des sources : `DESCRIPTION_SOURCES.md`.
* **Identité des légendaires** : par clé `legendary:<sort>` uniquement. Les titres **ne sont pas uniques** dans les données (« The Eternal Talisman: Metamorphosis » pour deux classes) : testé.

## 2. Traductions
Noms FR disponibles et utilisés : sorts, anneaux/bijoux, **22/22 amulettes fixes**, classes. **Légendaires : aucune tête traduite (0/21)** : le nom d'affichage FR est « tête anglaise officielle : nom du sort traduit », seulement quand le sort est traduit ; sinon titre anglais. Libellés de statistiques (15) et noms d'effets sûrs (12) traduits ; les autres noms d'effets (`dot_burst`, `kill_explode`, …) restent **tels que le jeu les écrit**. Nombres FR : virgule, « 15 % ». Chaque chaîne nouvelle a sa traduction (test de balayage, y compris `Describe.lua`).

## 3. Interface
* **Cases d'équipement** reconstruites : 118×44, zones réservées (bande haute : rôle + bouton « x » ; dessous : icône 24 px, nom borné sur deux lignes, tronqué). Principaux / alternatives séparés par un filet. Test : aucun recouvrement entre nom, icône, rôle et « x » pour les 12 cases remplies, avec la légendaire au titre le plus long.
* **Sorts** : numéro, icône, nom, Conserver / Bannir après, contrôles `^ v x` compacts (infobulles). `banishAfter` et liste « Éviter » inchangés.
* **Inspecteur du bas** : icône, nom complet (couleur de rareté), type, puis sections **Dans ce build / Description / Informations / Effets (rang 1) / Spécial / Croissance / Origine / Disponibilité**, défilement interne (8 lignes, molette + barre), source indiquée.
* **Infobulles** : aperçu court (≤ 7 lignes, lignes bornées), **jamais** de texte natif de sort (celui-ci est lu une fois par sort, mis en cache, et n'apparaît que dans le panneau), ancre à gauche dans la moitié droite de l'écran. `GameTooltip` n'est plus utilisé pour les descriptions longues.
* **Design system** (dans `UI.lua`) : palette (encre / laiton / or, rouge destructif seulement), 4 rôles de boutons × états (normal, désactivé, survol natif, sélectionné), rarités (couleurs du jeu, toujours doublées du texte), grille de lignes 24 / 34 / 36 px, panneaux à bordure laiton, polices du jeu (12 pt corps, 10 pt secondaire).

## 4. Tests (résultats réels)
Catalogue, générateur, Lot 0 (273), JS↔Lua (63) : PASS. Lua 5.1 : 206 cas / 11 773 assertions / 0 échec (+17 cas `test_lot34`, -4 anciens tests d infobulle remplacés). Couvre : complétude des données, règles officielles et exceptions `growth`/`fixed`, valeurs de statistiques non-part, spéciaux, monde, prérequis, FR/EN, noms de légendaires, entrées inconnues et données absentes, **aucun chiffre inventé**, aperçu d'infobulle court, texte natif exclu, ancre en bord d'écran, sections et défilement de l'inspecteur, rectangles des cases et des lignes de sorts, long titre (Eye of the Splitting Sky), mise en page à 5 résolutions × 2 langues × 3 échelles, aucun widget créé, aucune perte de build. **Mesures de rectangles du simulateur et largeurs estimées : pas un rendu.**

## 5. Différences honnêtes avec les maquettes (techniquement non reproduit)
Cadre ornementé, couronne / blason de titre, bandeau « Résumé du build », boutons dégradés et bords arrondis, effets de brillance, étoiles dessinées, icônes de catégories personnalisées, fond à texture : **absents** (le client n'offre que des quads unis, bordures standard et polices du jeu ; ajouter des textures binaires fragiliserait le package). Bonus de set, niveau d'objet, « Lié au build » et valeurs d'équipement des maquettes : **non affichés** (non publiés pour les pièces, bonus de set publiés mais non embarqués dans ce lot). Le rendu est donc « propre et sobre », pas « illustré ».

## 6. Limites
Rendu non vu ; effets des anneaux/bijoux absents (dépend de SNX) ; effets légendaires : unités sans règle officielle affichées en nombre brut avec une note ; noms d'effets non traduits conservés en anglais ; bonus de set non embarqués ; pas de navigation clavier ; coût : catalogue embarqué 140 Ko (au lieu de 110).

## 7. Livrables
Package `reborn-build-planner-recette-lot3-4\` (17 fichiers, zip, SHA256, guides), `reborn-build-planner-lot3-4-projet.zip`, ce rapport, `PROJECT_STATE.md`, `DESCRIPTION_SOURCES.md`, `API_PROPOSAL_JEWELRY.md`, `CHANGELOG.md`, `UPDATE_FROM_0.4.1.md`, `RECETTE_CLIENT_LOT3_4.md` ; commits locaux `lot3.4a/b/c`, aucun push.

## 8. Prochaine action
Kevin exécute G1-G14 avec captures. Envoyer `API_PROPOSAL_JEWELRY.md` à SNX. Décider ensuite : embarquer `set_bonuses.json`, puis Lot 4.

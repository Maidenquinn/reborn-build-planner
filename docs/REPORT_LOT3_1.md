# Rapport — LOT 3.1 (corrections fonctionnelles, UX, infobulles)

**Verdict : PASS CONDITIONNEL.** Les trois besoins (bannissement après acquisition, lisibilité, infobulles) sont livrés et testés **en simulation** (Lua 5.1 : 162 cas, 7 171 assertions, 0 échec). **Aucune validation dans le client Reborn** : le jeu n'a pas été lancé, aucune capture réelle, rien installé en production. La recette D1-D16 (`RECETTE_CLIENT_LOT3_1.md`) reste à exécuter par Kevin. Le Lot 4 n'est pas commencé.

## 1. 3.1A — Modèle « bannir après acquisition »
**Décision.** Deux notions distinctes, jamais confondues :
* `banish` (inchangé) = **liste à éviter** : sorts bannis dès qu'ils sont proposés. Format et limites du site (3).
* `banishAfter` (**nouveau**, par étape) = **sous-ensemble des sorts souhaités**, max 3 : « je veux ce sort, puis je le banne une fois obtenu ». Un sort peut donc être souhaité **et** marqué ; ce n'est **pas** un conflit.

Conséquences vérifiées par tests : six sorts dont trois marqués = build propre ; 4ᵉ marque refusée ; marquer un sort non souhaité refusé ; démarquer ; la marque est liée à la **clé** donc suit le sort au réordonnancement ; retirer un sort retire sa marque (nettoyage contrôlé, annoncé « Sort retiré, et sa marque … avec lui ») sans la ressusciter si on le rajoute ; une marque orpheline/doublon venant de données stockées est un **conflit signalé**, jamais corrigé en silence ; avertissement (non bloquant) si liste à éviter + marques > 3 car la limite jeu cumulée n'est pas vérifiée.

**Migration** (`UPDATE_FROM_0.3.0.md`) : schéma de stockage inchangé (1) ; champ optionnel, absent = vide ; les builds 0.3.0 sont lus tels quels, aucune réécriture automatique. Un ancien chevauchement souhaité+évité **reste un conflit** (build « à réparer », suivi refusé) ; seul un clic explicite du joueur sur « Bannir après » (ligne de la liste à éviter) le convertit. Aucune conversion silencieuse. Au passage, correction d'un défaut latent : l'identité d'un conflit utilisait sa position, retirer un élément antérieur faisait croire à un conflit nouveau et refusait des réparations légitimes ; elle utilise maintenant code+clé, avec comptage.

**Interopérabilité `azsb1:`** (preuves) : `tools/site_overlap_probe.mjs` fait décoder par **le code du site lui-même** (bundle de référence, hors ligne) un build de 6 sorts dont 3 aussi bannis : résultat `spells` = les 6, `banish` = `[]` → **le site supprime les bannissements qui chevauchent les sorts souhaités**. `azsb1:` ne peut donc pas représenter l'intention. Conséquence : l'export liste chaque marque comme **perte d'intention** (`BANISH_AFTER_NOT_REPRESENTABLE`), exige l'acceptation avant d'afficher le code, et **n'écrit pas** les marques dans la liste de bannissement (ce serait changer le sens). À l'import d'un code du site, les chevauchements arrivent comme conflits conservés. Un format natif complémentaire reste à envisager (non fait). Le test dans l'interface du site (`?p=`) n'a pas pu être rejoué dans le navigateur du panneau (la page a rechargé le brouillon enregistré du navigateur au lieu du code) : seule la preuve par le décodeur du site est établie.

**Règle du jeu.** Le site officiel décrit le bannissement ainsi : « A banished spell never comes up in a level-up that run. Banish needs its account talent. » (lu sur la page du planner). Cela est cohérent avec bannir un sort déjà acquis pour concentrer les améliorations, mais **ne le prouve pas**, et aucun code des addons natifs installés ne traite le bannissement. Le planner conserve donc l'intention, affiche « Prévu » (jamais « fait »), ne promet aucun moment, et **ne bannit jamais** (testé : aucun fichier de l'addon n'appelle d'API d'action de jeu). Question posée à Kevin : D16.

## 2. 3.1B — Lisibilité
* Fenêtre **opaque** (fond uni, alpha 1) et strate `DIALOG` avec niveau élevé, boîte de dialogue au-dessus ; bordure fine. Panneau de contenu plus clair que la fenêtre, lignes de la bibliothèque sur fonds alternés, lignes du catalogue et du plan sur fonds distincts ; sélection par bandeau **et** préfixe `>`. Tests : couleurs de fond, strates, contraste panneau/fenêtre.
* Boutons à rôles : action principale en vert, secondaires en gris, suppression en rouge clair, « Bannir après » en ambre ; la couleur n'est qu'un renfort, le texte dit toujours l'état (« Conserver » / « Bannir après », onglets marqués `*`). Une action désactivée perd sa couleur.
* Éditeur réorganisé sans agrandir la fenêtre (780×540) : colonne plan 448 px, catalogue 288 px ; plus de lignes tronquées de façon gênante (les noms longs sont complétés par l'infobulle). Contrôle de mise en page : 1365×768, 1920×1080, 1024×768 et 800×600 (réduction automatique d'échelle), FR/EN, noms de 100+ caractères, échelles 0,6 et 1,5 : aucun débordement ni recouvrement **sur largeurs estimées**.
* **Limite assumée** : la fenêtre reste à l'avant-plan des textes du jeu par strate/niveau ; je n'ai pas de moyen natif connu de masquer les popups du jeu, aucun n'est masqué. À confirmer en D2.

## 3. 3.1C — Infobulles (survol uniquement)
Sur : lignes du catalogue, lignes du plan et de la liste à éviter, emplacements de bijouterie, boutons Conserver/Bannir après, À éviter, conversion. Un seul `GameTooltip`, `SetOwner` à droite (le client garde l'infobulle à l'écran), aucune lecture périodique, aucun `OnUpdate`, aucun objet créé (testé : 0 création après 30 survols).
* **Sorts** : nom localisé + icône, classe, priorité, « Prévu : conserver / bannir après acquisition », rang cible ou « sans limite » si défini, « dans la liste à éviter ». La **description vient du texte natif du jeu**, demandé à la volée par l'identifiant du sort (`SetHyperlink("spell:id")`, comme le fait l'interface native `Inspect.lua`) ; sans réponse du jeu : « Effet détaillé indisponible ». Le catalogue embarqué ne contient **aucune** description, rang ou valeur : rien n'est inventé. Point à vérifier en client : ce texte reflète-t-il bien les effets de Reborn ? (D9)
* **Anneaux/bijoux** : nom, type, emplacement (principal/alternative), « Effet détaillé indisponible » et mention que le catalogue ne donne pas de statistiques. **Amulettes** : rareté ou, pour les légendaires, série, sort lié, classe. Aucune statistique n'est fabriquée : le catalogue n'en contient pas.
* Disparition : sortie de la ligne, changement de page/onglet/vue, fermeture de la fenêtre (testés). Clavier/manette : non fait (les lignes n'ont pas de focus exploitable).

## 4. 3.1D — Parcours d'édition
Parcours visible : chercher (champ) → Ajouter → monter/descendre → Conserver / Bannir après → onglet Bijouterie → Enregistrer / Enregistrer et suivre. Compteur « n à conserver / m à bannir après acquisition (max 3) ». Bijouterie : emplacement choisi annoncé en toutes lettres (« Emplacement choisi : Alternative 1 »), principaux/alternatives expliqués en infobulle. Champs non édités conservés (tests Lot 3 inchangés et verts). Renommages : « Souhaiter » → « Ajouter », « Bannir » (catalogue) → « Éviter ».

## 5. Tests (`python -I tools/run_all.py`, `tests/results/run_all_lot31.txt`)
| Étape | Résultat |
|---|---|
| Catalogue, générateur (84), JS↔Lua (63 codes) | PASS |
| Lua 5.1 | **162 cas, 7 171 assertions, 0 échec** (+27 cas, `test_lot31.lua` ; 3 anciens tests mis à jour : strate, libellé d'aide) |
| **Lot 0 (ancrages statiques)** | **FAIL : 17 ancrages ont bougé** dans `AzerothSurvivors/Run.lua`, `Cards.lua`, `Units.lua` installés (décalages de 2 à 20 lignes ; `C09` introuvable). Ce n'est pas une régression du planner : le code natif du jeu a changé depuis le Lot 0 (le test Lot 3 passait). Aucun ancrage n'est utilisé à l'exécution par le Lot 3.1. À ré-ancrer (et à relire `C09`) **avant le Lot 4**. |

Couverture demandée : six souhaités ; trois marqués ; ajout puis marquage ; retrait du marquage ; réordonnancement ; suppression d'un sort et nettoyage ; migration d'un ancien build ; import/export avec pertes ; persistance après rechargement ; refus d'une 4ᵉ marque ; absence d'action de jeu ; infobulles sorts/bijoux/amulettes ; noms FR + repli EN ; fenêtre opaque ; mise en page 4 tailles + échelles ; aucun objet créé en survol. Non couverts : description longue d'infobulle (le client fait le retour à la ligne), zoom réel de l'interface, focus/clics réels, contraste mesuré (seules les couleurs de fond sont comparées).

## 6. Livrables
* Package de recette : `H:\Users\kevin\Documents\ChatGPT\AzerothSurvivorReborn\reborn-build-planner-recette-lot3-1\` (`RebornBuildPlanner\` 16 fichiers, `RebornBuildPlanner-0.3.1-lot3.1-recette.zip`, `RECETTE_CLIENT_LOT3_1.md`, `UPDATE_FROM_0.3.0.md`, `SHA256SUMS.txt`).
* Code : `BuildModel.lua`, `PlannerCodec.lua`, `Controller.lua`, `UI.lua`, `UIStrings.lua` ; tests ; `tools/site_overlap_probe.mjs`.
* Commits locaux (aucun push) : `lot3.1a` (modèle, codec, sonde), `lot3.1b-d` (interface, infobulles, éditeur), `lot3.1` (tests, documentation). La séparation UX / infobulles n'est pas possible fichier par fichier (même `UI.lua` / `Controller.lua`).

## 7. Validations encore nécessaires en jeu (D1-D16)
Opacité réelle devant les textes du jeu (D2) ; boutons colorés et lisibles en FR/EN (D13) ; infobulles : texte natif des sorts fidèle à Reborn, position près des bords, disparition (D9-D12) ; marques après `/reload` et export/collage dans le site (D7-D8) ; question de jeu : bannir un sort déjà acquis (D16) ; plus les C1-C18 du Lot 3 non encore exécutés.

## 8. Limites
Format natif complémentaire pour exporter `banishAfter` : non fait. Ordre/priorité entre sorts marqués et non marqués : aucune sémantique. La limite de bannissements cumulés (liste à éviter + marques) dans le jeu n'est pas vérifiée (avertissement seulement). Pas de navigation clavier dans les listes.

# CONTRACTS — Reborn Build Planner, Lot 0

Sources lues : addons installés `H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\Interface\AddOns` (lecture seule) ; leur SHA-256 est **identique** aux snapshots de l'archive pour les 12 fichiers cités (Core, Run, Units, Cards, Gear, Spells, Inspect, SurvivorsTalents, Api, Meter, 2 `.toc`). Catalogue : `data/v1` schema 1, content `384db000d5ac311d` (copie utile dans `tests/fixtures/catalog/`).
Les références `Fichier:ligne` sont vérifiées mécaniquement par `tools/check_anchors.py` (`tests/static_anchors.json`, 54 ancres, 0 en échec) ; un écart de ligne après mise à jour du jeu fait échouer le test.

**Niveaux de preuve** : `CONFIRMÉ STATIQUE` (code natif lu, ligne citée) · `CONFIRMÉ FIXTURE` (comportement reproduit sur fixture reconstruite du code, ou code du site exécuté en Node) · `CONFIRMÉ CLIENT` (observé en jeu : **aucun à ce jour, le client n'a pas été exécuté**) · `INCONNU`. `VALIDATION CLIENT REQUISE` renvoie à un protocole `P-xx` de `VALIDATION_PLAN.md`.

---

## 1. Contrats runtime (A)

| # | Contrat | Preuve | Statut | Inconnu / limite | Impact produit |
|---|---|---|---|---|---|
| R1 | `AZS.On(prefix, fn)` ajoute `fn` à la liste du préfixe ; le routeur appelle chaque `fn(msg, prefix, channel, sender)` **dans l'ordre d'enregistrement** (= ordre de chargement des `.toc`), chacun sous `xpcall` (une erreur n'arrête pas les suivants). Un seul frame `CHAT_MSG_ADDON` ; tout est routé par préfixe exact. | `Core.lua:45` (A01), `:40` (A02), `:130` (A03) ; en-tête `Core.lua:6-11` | CONFIRMÉ STATIQUE | L'ordre exact vis-à-vis d'autres addons tiers dépend du chargement ; on ne dépend que de « après AzerothSurvivors et AzerothSurvivorsAPI » (`## Dependencies`, `AzerothSurvivorsAPI.toc:5` T02). | Notre callback voit les tables natives **déjà remplacées** et `AZS_ZONE.run` déjà posé par l'API. Une erreur chez nous ne casse pas le jeu mais doit être capturée (`pcall`). |
| R2 | **Aucun événement WoW `*_UPDATED`.** Les `AZS_*_UPDATED` sont des globales de temps posées par `Stamp()`. Il n'existe de stamp que pour ZONE, STATS, CAPS, SCHEDULE, UNITS, DEBUFFS, SPELLS, BUFFS, REVIVE, END, CHESTS, LAIRS, TARGET et les listes de l'API ; **aucun pour `AZS_GEAR` ni `AZS_CARDS`**. | `Api.lua:155` (P07) + lecture de `Api.lua:76-206` | CONFIRMÉ STATIQUE | Un stamp est un `GetTime()` : deux lignes dans la même frame ont la même valeur. | On s'abonne par `AZS.On` sur `AZSGEAR`, `AZSCARDS`… et on tient **nos propres compteurs**. Ne jamais `RegisterEvent("AZS_GEAR_UPDATED")`. |
| R3 | **Remplacement par l'interface native** : chaque ligne remplace la globale par une **nouvelle table** (`AZS_RUN`, `AZS_ZONE`, `AZS_GEAR`, `AZS_SPELLS`, `AZS_CARDS`). L'API le dit : « read the live global and never keep a reference ». | `Run.lua:423` (R06), `:432` (R07), `Units.lua:53` (U01), `Spells.lua:124` (S01), `Cards.lua:1487` (C04) ; `Api.lua:7-9` | CONFIRMÉ STATIQUE | — | Lecture seule, copie normalisée à la réception, aucune référence conservée. L'identité de table change à chaque ligne (utile pour les mains, voir R9). |
| R4 | **Valeurs initiales** : `AZS_ZONE/RUN/SPELLS/CARDS/END = {}` au chargement ; **`AZS_GEAR` n'a aucun initialiseur** (nil jusqu'à la 1ʳᵉ ligne `AZSGEAR`, seule affectation : `Units.lua:53`). Table vide = « inconnu » **ou** « absent » : indistinguable. | `Run.lua:10-16` (R01-R03) ; grep de `AZS_GEAR *=` sur tout `AddOns` : 1 résultat | CONFIRMÉ STATIQUE | — | Inconnu ≠ absent : voir §3 (époques + drapeaux « reçu »). |
| R5 | **Reload** : les tables repartent vides ; sur chaque `PLAYER_ENTERING_WORLD` l'interface envoie la commande `sync` ; le serveur renvoie `AZSZONE` d'abord, puis `AZSRUN`, boss, sorts, gear, cartes, coffres, antres, co-op, lignes de fin. Aucun marqueur « fin de sync ». | `Run.lua:336` (R05), `:351` (R04) ; `addon-api.md` §2 (« After a /reload… ») | CONFIRMÉ STATIQUE (émission du `sync`) ; **contenu/ordre de la réponse : documentation seule** | Le serveur renvoie-t-il `AZSGEAR`/`AZSCARDS` **vides** quand rien n'est porté/ouvert ? Une table inchangée est-elle omise ? → `P-S2`. | Sans marqueur de fin, « vide » ne se déduit jamais d'une absence de ligne (§3). Pas de `sync` périodique, pas de polling. |
| R6 | **Identité de run** `AZS_API_RunId()` : `"azs:"..serverRun` si `AZSZONE.run` vaut `r`+hex (**stable pendant la run, après `/reload` et handover**) ; sinon (serveur ancien, `run=1`) compteur client `"azs:<SESSION>:<n>"` où `SESSION = time()` au chargement → **change au `/reload`** ; `nil` avant la 1ʳᵉ run. `AZS_ZONE.run` reçoit la même valeur. | `Api.lua:64` (P01), `:79` (P02), `:60` (P03), `:93` (P04) ; `addon-api.md` §6 | CONFIRMÉ STATIQUE ; CONFIRMÉ FIXTURE (`11`, `11b`, `12`, `13`) | Forme réelle de `AZSZONE.run` d'un serveur actuel jamais observée → `P-R1`. | Identité primaire = `AZS_API_RunId()`. En repli (id contenant la session), un reload = « nouvelle run » : état de suivi propre à la run perdu, **jamais** de conseil faux. La phase seule ne définit pas une run. |
| R7 | **Hub** : `AZS_ZONE.hub == 1` ⇒ pas une run ; un hub rapporte `AZS_RUN.ph == "playing"` ; `AZS_GetPhase()` renvoie alors nil. | `Api.lua:218` (P05), `:216` (P06) | CONFIRMÉ STATIQUE ; CONFIRMÉ FIXTURE (`01`) | Valeur de `run` et présence d'`AZSRUN` en hub inconnues → `P-R2`. | Le hub n'émet aucun conseil, quel que soit `ph`. |
| R8 | **Phases** `AZS_RUN.ph` : `ready`, `playing`, `choosing`, `paused`, `dead`, `victory` ; `nil`/`{}` hors run. `ready` = « Move to begin » ; `paused` est posé par l'UI native quand un menu est ouvert. | `Run.lua:173` (R09), `:177` (R10), `:164` (R08) ; liste : `addon-api.md` §3 | CONFIRMÉ STATIQUE (`ready`, `paused`, absence) ; liste complète : documentation | Pendant une main de cartes, `ph` vaut-il `choosing` (sorts **et** coffres/bijoux **et** niveaux stockés) ? → `P-C1`. | `HAND_PHASES = {"choosing"}` paramétrable ; si `ph` ≠ `choosing` avec cartes présentes : conseil supprimé (état `CHOOSING_NO_HAND`). |
| R9 | **Cartes** : `AZSCARDS` = `kind` (`spell`/`jewel`), `src` (jewel : `cache`/`guardian`/`cursed`/sinon trésor), `lvl`, `rr` (rerolls gratuits), `rc` (prix), `sk` (or du skip), `bn` (bannissements restants, **spell seulement**), `sl`/`slm` (emplacements de sorts pris / max, spell), `c=` cartes. Sorts : `key,spell,rank,rarity,new,lines` séparés par `/`. Bijoux : `mode~rarity~icon~name~effect~detail~note~slot` séparés par `/`. `AZSCARDTIP` ajoute `tips[i]` à la main courante. **Aucun identifiant de main** : chaque ligne `AZSCARDS` = nouvelle table. Une main vide (`c=` vide) ferme les cartes. 3 cartes, 4 avec « Opening Hand ». | `Cards.lua:1455` (C01), `:1461` (C02), `:1473` (C03), `:1487` (C04), `:1496` (C10), `:126` (C12), `:415` (C09) | CONFIRMÉ STATIQUE ; CONFIRMÉ FIXTURE (`08`,`09`,`10`) | Valeurs réelles de `src`, de `mode` pour une pièce neuve (ni `amulet`, `empower`, `grow`, `gold`), présence/absence de `bn` sur main bijou → `P-C2`. | Identité de main = compteur local `handSeq` (+1 par ligne `AZSCARDS`) lié à (run, époque). |
| R10 | **Sens du rang d'une carte de sort** : `new == 1` ⇒ sort inconnu pris au rang 1 ; sinon `card.rank` est le rang **après** choix (la carte affiche `rank-1 » rank`). `AZS_SPELLS.rank` = rang courant. | `Cards.lua:1151` (C08) | CONFIRMÉ STATIQUE | Cartes de dash (`key=dash_*`) : pas de sort du catalogue. | Une carte `new=0` n'est un « rang N » qu'avec `AZS_SPELLS` connu ; sinon rang inconnu. |
| R11 | **Reroll** : commande `reroll` au serveur ; l'indicateur local `AZS_CARDS.rerolled` est posé sur l'**ancienne** table, la nouvelle (créée par la ligne suivante) ne l'a pas. Un reroll est indiscernable d'une main suivante autrement que par le contexte. | `Cards.lua:1334-1335` (C05, C13) | CONFIRMÉ STATIQUE | — | Toute nouvelle ligne `AZSCARDS` = nouvelle main : tout conseil précédent devient périmé, sans chercher à qualifier « reroll ». |
| R12 | **Fin de run** : `AZSEND` cache les cartes mais **ne vide pas `AZS_CARDS`** ; `AZS_END` n'est remplacé qu'au prochain `AZSEND` (non vidé à la run suivante). | `Cards.lua:1505` (C07), `Run.lua:16` (R03), grep `AZS_END =` | CONFIRMÉ STATIQUE | — | `AZS_END.result`/`AZS_CARDS.cards` **ne sont jamais** des marqueurs d'état ; la fin se lit via `ph ∈ {dead, victory}` (+ `AZSEND` vu pendant cette run). |
| R13 | **Sans fin** : l'UI native lit `AZS_RUN.endless == 1`. `endl` existe dans `AZS_RUN`/`AZS_END` (champ de l'original) mais le natif ne l'utilise pas pour l'affichage. | `Run.lua:151` (R11) ; `addon-api.md` §3 | CONFIRMÉ STATIQUE (`endless`) ; `endl` INCONNU | Différence réelle `endl` / `endless` → `P-R3`. | Lire `endless` uniquement ; absent ⇒ inconnu (`nil`), jamais `false`. |
| R14 | **Classe** : `AZS_ZONE.class` (« keys »). Casse du retour non observée ; talents natifs indexés par token MAJUSCULE (`WARRIOR`), catalogue en minuscule (`warrior`, `classes.json.token`). | `SurvivorsTalents.lua:9` (T04) ; `classes.json` | CONFIRMÉ STATIQUE (casse des deux côtés) ; valeur de `AZS_ZONE.class` INCONNU | → `P-R1`. | Normaliser par `Catalog.norm_class` (insensible à la casse, accepte clé ou token) ; classe non reconnue ⇒ pas de conseil. |
| R15 | **Panneau au-dessus des cartes** : `AZS_SetOnTopOfScreens(frame, on)` ; la frame doit avoir un **nom global** sinon `error(...)`. Elle est relevée au-dessus des cartes (`FULLSCREEN_DIALOG`) et « prend ses propres clics ». Limites : ne dépend d'aucun nom de bouton de carte ; dimensions/position vs cartes (centre de l'écran) à valider. | `Hud.lua:310` (H01), `:313` (H02) ; `addon-api.md` §4 | CONFIRMÉ STATIQUE (API) ; rendu réel INCONNU | Recouvrement des cartes, clics, strate, Échap → `P-U1`. | Un seul panneau, nommé globalement (`RebornBuildPlannerAdvice`), ancré hors de la bande centrale des cartes, `pcall` autour de l'appel. |
| R16 | **Grammaire des lignes** : `ParseKV` lit `(%w+)=([^;]*)` — `%w` **exclut `_`** (une clé `my_key=` serait lue `key=`) ; toute valeur numérique devient nombre ; `ParseList` coupe par `;` puis `,`, ignore les valeurs au-delà des noms de champs, laisse nil les champs manquants en queue. La doc affirme qu'aucune valeur ne contient `,` ni `;`. | `Core.lua:144-145` (A05, A06), `:156` (A08) | CONFIRMÉ STATIQUE ; port testé en fixture | Le serveur peut-il émettre un nom/texte avec `,`/`;` (noms localisés) ? → `P-C2`. | Nos lectures reposent sur `AZS_*` natifs déjà parsés ; un champ tronqué = identité « inconnue », pas « fausse ». |
| R17 | **Cible / manifeste** : `## Interface: 30300` ; dépendances `AzerothSurvivors, AzerothSurvivorsAPI` (l'API déclare `Dependencies: AzerothSurvivors`). SavedVariables natives : `AZS_SETTINGS`, `AZS_API_HUD` (à ne pas toucher). | `AzerothSurvivors.toc:1` (T01), `AzerothSurvivorsAPI.toc:5` (T02) | CONFIRMÉ STATIQUE | — | Squelette fourni : `addon/RebornBuildPlanner/` (toc + namespace, aucune SV). |

Rappel d'invariant de sécurité (R3/R12) : le planner n'écrit dans aucune globale `AZS_*`, n'envoie aucune commande (`pick`, `reroll`, `banish`, `skip`, `sync`, `talents`).

---

## 2. Matrice d'identification (B)

Légende statut d'identité : **STABLE** (clé fournie par le serveur et validée côté client) · **HEURISTIQUE** (appariement nom/slot/classe/icône unique mais non prouvé) · **AMBIGU** · **INCONNU**. Dans le code de référence (`tools/lot0_model.py`), aucune identité de bijou n'est « STABLE » : le drapeau `jewel_identity_verified` reste faux tant que `P-J1/P-J2` n'a pas réussi ; tant qu'il l'est, **les identités de bijoux ne comptent pour aucun objectif et aucun bijou proposé n'est recommandé**.

| # | Cas | Source exacte / champs | Méthode envisagée | Identité | Ambiguïtés | Preuve | Dégradé |
|---|---|---|---|---|---|---|---|
| B1 | Sort acquis → clé catalogue | `AZS_SPELLS[i]` : `key`, `spell` (id), `rank` (`Spells.lua:124`) | `key` ∈ sorts de la classe **et** `spell == spells.json.id` ; à défaut, id seul (dérive de clé signalée) | **Stable** si clé+id concordent | `key` absente du catalogue (dérive) ; `key`/`id` en conflit ; sort d'une autre classe ; clés `dash_*` | Champs : STATIQUE ; unicité des clés (241) et des ids (241) : FIXTURE ; **égalité clé serveur = clé catalogue : INCONNU → `P-K1`** | `UNKNOWN`/`CONFLICT` ⇒ clé brute affichée, sort ne satisfait aucun objectif |
| B2 | Rang → rang live | `AZS_SPELLS[i].rank` | entier ≥ 1 ; sinon `nil` | Stable (valeur serveur) | rang `0`/non numérique ⇒ inconnu, jamais 1 | STATIQUE (`Gear`/`Cards` l'affichent tel quel) ; FIXTURE (`03`) | Objectif « rang N » = inconnu ; objectif « acquérir » inchangé |
| B3 | Sort proposé → clé | `AZS_CARDS.cards[i]` : `key`, `spell`, `rank` (rang après choix), `new` | même résolution que B1 ; `new==1` ⇒ acquisition au rang 1 | Stable (si B1) | cartes `dash_*` ⇒ `NOT_CATALOGUE` | STATIQUE (`Cards.lua:1151`,`:1473`) ; FIXTURE (`08`) | Pas de conseil sur cette carte, les autres restent évaluées |
| B4 | Anneau équipé | `AZS_GEAR[i]` : `slot="ring"`, `name`, `icon` (+ `bonus` non fiable, `amount` non défini) | `slot` + `name` exact (anglais, ou traduit via `i18n`) unique dans `jewelry.json` ; l'icône ne fait que corroborer | **Heuristique** | `accuria` et `elementium_signet` **partagent l'icône** `INV_Jewelry_Ring_15` ; nom absent/traduit autrement ⇒ INCONNU (+ candidats par icône, informatif) ; nom ok + icône ≠ ⇒ CONFLIT | Slots/champs : STATIQUE ; collision d'icône, unicité des 44 noms (EN et FR) : FIXTURE (`04`,`05`) ; **valeurs réelles de `name`/`bonus` par langue : INCONNU → `P-J1`** | Affichage du nom brut, objectif non satisfait, **aucun conseil** |
| B5 | Bijou (trinket) équipé | idem, `slot="trinket"` | idem B4 | Heuristique | idem ; bijoux à effet « proc » sans valeur | idem | idem |
| B6 | Amulette équipée : clé, rareté, rang | `AZS_GEAR[i]` : `slot="amulet"`, `rarity` (numérique), `amount` (**rang**, `Gear.lua:84`), `name`, `icon` | filtre classe (`amulets.json.classes` vide ou contenant la classe) + nom ; rareté croisée avec le catalogue (0 commun … 4 légendaire) ; rang = `amount` entier ≥ 1 | Heuristique (clé) ; rang stable | `amount` 0/absent ⇒ rang inconnu ; nom inconnu ⇒ INCONNU | `amount` = rang **pour l'amulette seulement** : STATIQUE (`Gear.lua:84`, `Cards.lua:950`) ; FIXTURE (`07`) ; nom serveur : INCONNU → `P-J2` | Clé inconnue ⇒ pas d'objectif amulette ; rang affiché seulement si connu |
| B7 | Anneau/bijou/amulette **proposé** → identité | `AZS_CARDS.cards[i]` (`kind=jewel`) : `mode`, `rarity`, `icon`, `name`, `slot` ; `effect`/`detail`/`note` = **texte serveur localisé** (le natif remplace même des motifs `Replaces … for good` / `Ersetzt … endgültig`) | mêmes résolveurs que B4-B6 ; pour `mode` `grow`/`empower` : lien vers la pièce portée de même `slot`+`name` (le natif fait exactement ce rapprochement : `Cards.lua:966`) | Heuristique, **jamais recommandable avant `P-J3`** | noms localisés ; modes non énumérés ; texte jamais analysé | Structure : STATIQUE (`Cards.lua:1461`,`:1109`) ; FIXTURE (`08`) ; **noms réels des cartes : INCONNU → `P-J3`** | **Recommandation automatique de bijou DÉSACTIVÉE** : afficher « Bijou : identité non vérifiée » sans conseil (décision Lot 0) |
| B8 | Légendaire | amulette portée ou carte (`mode=amulet`) ; catalogue `legends.json` : `key = legendary:<spell>`, `name = "<head>: <Spell>"`, `head`, `icon` | nom **complet** ET classe du héros → `legendary:<spell>` ; **jamais** `head` ni l'icône | Heuristique ; AMBIGU si classe inconnue | 13 `head` partagés (jusqu'à 44 légendaires pour un même `head`) ; 11 icônes partagées ; **2 noms complets homonymes entre classes** (`Eye of the Splitting Sky: Death Coil` : DK/démoniste ; `The Eternal Talisman: Metamorphosis` : démoniste/chasseur de démons) ; `legends.json.name` n'est dans **aucune** traduction `i18n` | Collisions : FIXTURE (`06_*`, suite catalogue) ; unicité `(classe, nom complet)` : FIXTURE ; **nom envoyé par le serveur pour une légendaire (surtout hors anglais) : INCONNU → `P-J2`** | Hors anglais ou nom inconnu ⇒ INCONNU, pas de conseil légendaire ; classe absente ⇒ AMBIGU |

Anomalie de catalogue notée : `call_of_flame` est marqué `legendary` dans `spells.json` sans ligne dans `legends.json` (238 marqués / 237 lignes) ; le générateur du Lot 1 doit la signaler, pas la corriger.

**Règle produit retenue (Lot 0)** : (1) un sort est toujours identifié par `key`+`id` ; (2) aucune pièce de bijouterie ne satisfait un objectif ni n'est recommandée tant que `P-J1…P-J3` n'ont pas réussi ; (3) un conseil jamais fondé sur une icône ou un `head` ; (4) une pièce portée appartient à au plus un emplacement du build.

---

## 3. Cycle de vie et synchronisation (C)

### 3.1 États (dérivés, jamais stockés comme vérité)

| État | Condition (lue sur les tables natives + nos drapeaux) | Conseil autorisé |
|---|---|---|
| `OFFLINE` | aucune entrée en monde vue par l'addon | aucun |
| `SYNCING` | époque ouverte (chargement/entrée en monde) et `AZSZONE` ou `AZSRUN` pas encore reçus pour cette époque, ou id de run inconnu | aucun (« Synchronisation… ») |
| `NO_RUN` | `AZS_ZONE.hub == 1` | aucun (hub, quel que soit `ph`) |
| `READY` | run connue, `ph == "ready"` | « À chercher » (plan) seulement |
| `ACTIVE` | `ph ∈ {playing, paused}` | « À chercher » ; objectifs évalués sur données **KNOWN** uniquement |
| `CHOOSING` | `ph ∈ HAND_PHASES` **et** main non vide **et** main reçue dans cette run et cette époque | « Parmi ces cartes » |
| `CHOOSING_NO_HAND` | `ph` de choix mais pas de main valide (pas encore reçue, vide, ou d'une autre run/époque) | aucun, message « cartes indisponibles » |
| `ENDED` | `ph ∈ {dead, victory}` ou `AZSEND` vu pendant cette run | aucun |

Transitions (événements = **lignes `AZS.On`**, pas des événements WoW) : chargement/`PLAYER_ENTERING_WORLD` → nouvelle **époque** + `SYNCING` ; `AZSZONE`/`AZSRUN` donnant un **autre id de run** → purge de tout ce qui est scopé run (sorts, gear, cartes) + `handSeq+1` ; chaque `AZSCARDS` → `handSeq+1` ; `AZSEND` → `ENDED`. Aucun timer, aucun `sync` envoyé. Une pause (`paused`) ne change ni run ni main.

### 3.2 Inconnu ≠ absent

Chaque jeu de données (`spells`, `gear`, `cards`) a trois états : `UNKNOWN` (aucune ligne reçue **pour cette run et cette époque**), `EMPTY` (ligne reçue, zéro ligne de données), `KNOWN`. Une table native vide n'a aucune valeur de preuve (R4). On ne passe `UNKNOWN → EMPTY` que par une **ligne explicite vide** (`P-S2` dira si le serveur en envoie) ; le conseil traite `UNKNOWN` comme « ne pas conclure » : ni « manquant » ni « satisfait ». Idem pour `endless` (`nil` ≠ `false`) et `bn` d'une main bijou (absent ≠ 0).

### 3.3 Jetons de conseil (anti-périmé)

Tout conseil porte `{run, epoch, hand, life}` pris à son calcul. Il n'est affiché que si `token_status == OK`, c.-à-d. run, époque, main **et** état de cycle identiques à l'instant d'affichage ; sinon `STALE_NO_RUN`, `STALE_RUN`, `STALE_EPOCH`, `STALE_HAND` ou `STALE_STATE` et le conseil est retiré (pas grisé : retiré). Conséquences testées : reroll ⇒ `STALE_HAND` ; reload ⇒ `STALE_NO_RUN` puis `STALE_EPOCH` même avec un `runId` serveur identique ; nouvelle run ⇒ `STALE_RUN` ; main vidée ⇒ `STALE_HAND` ; entrer en choix depuis `ACTIVE` ⇒ `STALE_STATE`.

Le modèle exécutable est `tools/lot0_model.py` (`Model`) ; **c'est une spécification, pas une preuve client** : les 16 scénarios de `tests/fixtures/synthetic/` le rejouent.

### 3.4 Échecs documentés (dégradés assumés)

* Serveur ancien (`run=1`) : un `/reload` change l'id (`azs:S1:1` → `azs:S2:1`), donc nouvelle run pour nous (FIXTURE `11b`).
* `AZSZONE` jamais reçu après l'entrée en monde : on reste `SYNCING` indéfiniment, sans polling, avec message explicite (→ `P-S1`).
* Si `ph` ne vaut pas `choosing` pendant les mains de coffre/niveaux stockés (`P-C1`), ces mains ne produisent pas de conseil tant que `HAND_PHASES` n'est pas corrigé.

---

## 4. Codec `azsb1:` (E) — contrat minimal pour le Lot 2

Source : `references/web/assets/BYjmu0KK.js` (snapshot 2026-11-17, SHA-256 dans `tests/fixtures/codec/golden.json`), fonctions `mt/ht/yt/St/Ct/wt`. **Preuve par exécution** : `tools/gen_codec_golden.mjs` fait tourner le code du site sous Node 24 sur des plans synthétiques → 8 vecteurs d'encodage et 25 cas de décodage (`tests/fixtures/codec/golden.json`). Le vrai aller-retour navigateur n'a **pas** été fait (`P-W1`).

| Point | Contrat observé |
|---|---|
| Structure | `azsb1:` + base64url **sans padding** de `JSON.stringify([1, nom, classe, talents, phase0, phase1, phase2, phase3])`, UTF-8. Version racine 1. Décodage accepte aussi `azsb1.` et le payload nu. |
| Phase | `[label, spells, banish, rings, trinkets, amulets, stats, notes, link]` ; label `""` s'il égale la valeur par défaut (`Early Game`/`Mid Game`/`End Game`/`Endless`) ; **les champs vides *finaux* sont retirés**, pas ceux du milieu (ex. `[]` de `banish`, `stats` restent). Phase sans contenu ni label perso ⇒ `null` ; les `null` finaux sont retirés. Le décodeur produit toujours 4 phases ; une 5ᵉ est ignorée. |
| Trous | `rings`/`trinkets` = 4 positions (2 principales + 2 alternatives), `amulets` = 4 (1 + 3) ; les `""` internes **sont conservés** (vecteur `holes_in_alternatives`). À la lecture une clé invalide ou en double devient `""` **à sa position** (cas `duplicate_ring_hole`, `ring_in_trinket_slot`). |
| Listes | `spells` (≤ 6) et `banish` (≤ 3) sont séparées, compactes, sans trous ; doublons supprimés ; un bannissement présent dans `spells` est écarté ; clé d'une autre classe écartée **silencieusement**. |
| Légendaires | clé `legendary:<spell>` dans `amulets` ; acceptée seulement si la légendaire est de la classe du build (`amuletByKey` = amulettes filtrées par classe + légendes de la classe). |
| Stats | liste de `[index, valeur]`, index **0-basé** dans l'ordre `damage, cooldown, crit, critdmg, area, speed, armor, lifesteal, pickup, luck, gold` ; à la lecture : fini, > 0, arrondi à 0,1, plafonné à 999 ; l'encodeur écrit la valeur **brute** (12,34 → relu 12,3 : aller-retour non strict). |
| Textes | nom ≤ 60, label ≤ 24, notes ≤ 2000, lien ≤ 300 **unités UTF-16 JS** (`slice`) ; l'encodeur ne tronque pas, le décodeur oui. Un émoji = 2 unités ; en Lua/UTF-8 la coupe doit se faire en unités UTF-16 et éviter de scinder une paire de substitution. Lien accepté seulement `http(s)://…` sans espace. Talents : `^[0-9-]{0,400}$` sinon `""`. |
| URL | `?p=` payload complet ; `?b=` talents seuls (classe hors contenu) ; sans `p` ni `b` ⇒ rejet ; chaîne de chiffres/tirets contenant au moins un `-` ⇒ talents seuls. |
| Rejet | JSON invalide, racine non tableau, version ≠ 1, classe inconnue du catalogue ⇒ `null`. |
| **Non représentable** | objectifs de rang (`rank`, `unlimited`), phases > 4, statut d'activation, révision, alternatives de sorts, extension native quelconque, notes/liens > limites, talents hors format. Tout export « site » devra le **signaler**. |
| Dépendance catalogue | décoder exige le catalogue de la classe (sorts, bijoux, amulettes, légendes) : le codec du Lot 2 dépend du générateur de catalogue du Lot 1. |

---

## 5. Environnement de test (E)

| Outil | Résultat (`tools/check_env.py`) |
|---|---|
| Lua 5.1 / LuaJIT / luac / luacheck | **absents** (PATH, WSL Ubuntu : `lua` introuvable). Une installation via `pip` (`lupa`) a été **refusée** par le système et non contournée. |
| Node 24.19.0 | présent — utilisé pour exécuter le codec du site |
| Python 3.13.1 | présent — modèle, fixtures et anomalies (`-I`) |
| Client 3.3.5a embarque Lua 5.1 | un Lua moderne (5.3/5.4) **n'est pas équivalent** (`goto`, opérateurs binaires, entiers, `table.getn`, `unpack`, `%w`…). Tout code Lua du Lot 1+ devra être exécuté sous un 5.1/LuaJIT **et** dans le client. |
| Conséquence Lot 0 | **aucun Lua exécuté** ; les tests utilisent des ports Python des fonctions natives (donc `CONFIRMÉ FIXTURE`, pas `CLIENT`). |

---

> **Mise à jour Lot 1** : un Lua 5.1 isolé (lupa, `.devtools/venv`) est désormais installé pour le développement ; les modules du Lot 1 sont testés sous Lua 5.1. Les ports Python du Lot 0 (grammaire, cycle de vie) restent des reconstructions jusqu'au Lot 4.

## 6. Inconnues → protocoles (résumé)

`P-K1` clé de sort serveur = clé catalogue · `P-J1` noms/`bonus` des bijoux portés (par langue) · `P-J2` amulettes fixes et légendaires portées (nom, rareté, `amount`) · `P-J3` noms des cartes bijou + `mode` · `P-C1` `ph` pendant les mains · `P-C2` valeurs `src`/`mode`/`bn`/séparateurs · `P-R1` forme de `AZSZONE.run` et `class` · `P-R2` hub (`run`, `AZSRUN`) · `P-R3` `endl` vs `endless` · `P-S1` `AZSZONE` après entrée en monde · `P-S2` lignes vides à la synchro · `P-U1` panneau au-dessus des cartes · `P-W1` aller-retour avec le vrai planner du site. Détail : `docs/VALIDATION_PLAN.md`.

---

## 7. Contrats du domaine et du stockage (Lot 1)

Source de vérité : `addon/RebornBuildPlanner/{Catalog,BuildModel,Storage}.lua`, tests `tests/lua/`. Ce sont des contrats **internes** (pas du client) ; ils ne changent aucun contrat §1-6.

| # | Contrat | Test |
|---|---|---|
| D1 | Une phase = `spells` (≤ 6 objectifs ordonnés `{key, mode=acquire\|rank\|unlimited, rank?}`) **et** `banish` (≤ 3 clés) : deux listes distinctes, aucune ne consomme l'autre. | `six wanted spells and three banishes…` |
| D2 | `rings`/`trinkets`/`amulets` : 4 positions fixes (2 principales + 2 alternatives ; 1 + 3), `""` = vide, **positions conservées**. | `alternatives keep empty positions` |
| D3 | Gravité : `error` (non stockable), `conflict` (stockable, signalé, **jamais conseillé** : doublon, sort+bannissement, mauvaise classe, mauvais slot, pièce en double), `warning` (clé inconnue, classe inconnue, catalogue différent, champ complété). | `limits…`, `spell/banish conflicts…` |
| D4 | Les opérations d'édition sont fonctionnelles : copie, validation, `revision + 1`, refus (`nil` + rapport) si **erreur** ou **nouveau conflit** ; un conflit déjà présent n'empêche pas de réparer ni d'éditer autre chose. | `editing returns a new build…`, `a refused edit leaves the source untouched` |
| D5 | `Normalize` (lecture indulgente d'une donnée brute) ne mute jamais l'entrée, ne lève jamais d'exception (fonction/cycle ⇒ `EXT_REJECTED`), conserve tout champ inconnu dans `ext`, complète les champs manquants (`PARTIAL`), garde les phases/éléments en trop (`OVERFLOW_PRESERVED`). | `extensions…`, `limits…` |
| D6 | Statuts d'objectif distincts : `UNKNOWN` (donnée non connue, ou rang inconnu), `BLOCKED`, `ACHIEVED`, `PENDING` ; `unlimited` n'est jamais atteint et ne compte pas pour la complétion ; « possédé » prime sur « bloqué ». | `goal statuses…` |
| D7 | Une pièce portée ne satisfait qu'une seule position (`AssignOwned`). | `a worn piece satisfies at most one position` |
| S1 | `RebornBuildPlannerDB` : `schema`, `settings`, `builds{id}`, `library{classe → ids ordonnés}`, `active{classe → id}`, `trash`, `quarantine`, `backups`, `counter`, `ext`. Aucune autre globale lue ou écrite. | `only the namespace global…`, `other addons' SavedVariables…` |
| S2 | Ouverture : `CREATED`, `OK`, `MIGRATED`, ou **lecture seule** (`FUTURE_SCHEMA`, `INVALID_DB`, `MIGRATION_FAILED`) : la table d'origine est rendue **intacte** et `Core` ne l'assigne pas. | `future schema…`, `Core wiring…` |
| S3 | Migration : sur **copie profonde**, étapes `v → v+1`, comptage des enregistrements (une perte ⇒ échec), validation, sauvegarde `backups[1]` de l'original, puis seulement remplacement. Schéma 0 = prototype interne jamais livré (chemin de migration réel et testé). | `migration…` (4 tests) |
| S4 | Donnée illisible ⇒ `quarantine` (brut conservé, 50 max : seul le plus ancien déborde) ; pointeurs `active` pendants effacés (le build reste) ; champs inconnus conservés. | `corrupted entries…` |
| S5 | Mutations transactionnelles : validation avant commit, `Update` exige `revision` strictement supérieure (éditeur périmé refusé), `Import` tout-ou-rien, ids toujours nouveaux (jamais d'écrasement), suppression = corbeille annulable (20). | `update…`, `import…`, `trash…` |
| S6 | Limites documentées et testées : 200 builds, 20 corbeille, 50 quarantaine, textes en octets (nom 240, label 96, notes 8000, lien 300, talents 400), `ext` ≤ 2000 nœuds / profondeur 8, base ≤ 400 000 nœuds. Les limites UTF-16 du site seront appliquées par le codec (Lot 2). | `library limit…`, `limits…` |
| C1 | Catalogue généré : clés officielles, `meta{schema, content, bodySha256, counts}`, index (légendaires/amulettes par classe, bijoux par slot, homonymes, icônes partagées), traductions `frFR` indexées par le nom anglais, anomalies. `Catalog.New` refuse une version de schéma future ou une structure invalide ; une classe/clé inconnue n'efface jamais un build. | `test_catalog.lua`, `tests/py/test_generator.py` |

---

## 8. Codec officiel : implémentation du Lot 2

Code : `Utf8.lua`, `Base64Url.lua`, `Json.lua`, `PlannerCodec.lua` (originaux, aucune bibliothèque tierce donc aucune licence à porter). Preuves : `tests/lua/test_codec.lua` (26 cas), `tests/fixtures/codec/{golden,cross}.json`, `tools/verify_reencoded.mjs`, `tests/fixtures/codec/browser_recette_2026-11-17.md`.

| # | Contrat | Statut |
|---|---|---|
| X1 | Sortie du codec Lua **identique caractère pour caractère** à l'encodeur du site : 8 vecteurs golden + 60 plans pseudo-aléatoires (accents, émojis, CJK, U+2028, contrôles, trous, phases nulles, stats décimales, légendaires) | CONFIRMÉ FIXTURE (code du site exécuté sous Node) |
| X2 | JS → Lua → JS : 60 codes du site relus puis ré-encodés par Lua sont identiques et re-décodés par le décodeur du site au même plan ; Lua → JS : 3 codes faits par Lua lus par le décodeur du site conformément à l'intention | CONFIRMÉ FIXTURE |
| X3 | Le site réel charge un code Lua (`?p=`) et ré-enregistre **le même code** ; un code créé sur le site se relit et se ré-exporte à l'identique | CONFIRMÉ NAVIGATEUR (partiel, voir fichier de recette) |
| X4 | Entrée : `azsb1:`, `azsb1.`, préfixe en majuscules, charge nue, URL `http(s)` avec `?p=`, `?b=` (classe lue dans le dernier segment du chemin), chaîne de talents nue (≥ 1 tiret). Base64 : alphabets URL **et** standard, remplissage facultatif, espaces ASCII ignorés (comme `atob`). BOM UTF-8 ignoré. | CONFIRMÉ FIXTURE |
| X5 | Limites : code ≤ 131 080 caractères, décodé ≤ 98 304 octets, JSON profondeur ≤ 8, ≤ 5 000 valeurs ; UTF-8 strict (octets invalides ⇒ refus, plus strict que le site qui substituerait U+FFFD) ; nom ≤ 60, label ≤ 24, notes ≤ 2 000, lien ≤ 300 **unités UTF-16** avec coupe identique à `slice` (une coupe dans une paire de substitution laisse U+FFFD) et avertissement `TRUNCATED` | CONFIRMÉ FIXTURE |
| X6 | **Rien n'est écarté en silence** (écart volontaire avec le site) : clé inconnue, d'une autre classe, doublon, sort+bannissement, mauvais slot, 7ᵉ sort/4ᵉ bannissement (mis de côté dans `phase.ext.import.overflow_*`), stats inutilisables (`rejectedStats`), lien non http(s) (`rejectedLink`), talents invalides (`rejectedTalents`), phases/champs en trop (`extraPhases`, `extraFields`). Le build est stocké « à réparer », `canActivate = false`, `SetActive` le refuse. | CONFIRMÉ FIXTURE |
| X7 | Une classe inconnue du catalogue est acceptée avec avertissement (le site la refuse) : build stockable, jamais activable, jamais exportable vers le site. | CONFIRMÉ FIXTURE |
| X8 | Statistiques : décodées **exactes** (le site arrondit à 0,1 et plafonne à 999), exportées **sans arrondi** ; l'export annonce `SITE_ROUNDS_STAT`. Valeurs > 999 refusées par le modèle ⇒ mises de côté à l'import. Zéro non exporté (info). | CONFIRMÉ FIXTURE |
| X9 | Libellé : `""` = défaut ; un libellé égal au défaut **de cet indice de phase** est stocké `""` ; la même chaîne sur un autre indice est un libellé personnalisé (comme le site). Aucun texte localisé n'est écrit dans les données exportées. | CONFIRMÉ FIXTURE |
| X10 | Import en deux temps : `Decode` ne touche aucun stockage ; `CommitImport` ajoute un **nouveau** build (nouvel id), n'active jamais, n'écrase jamais, ne change rien en cas de refus (aperçu invalide, stockage en lecture seule, bibliothèque pleine, classe manquante pour des talents seuls). | CONFIRMÉ FIXTURE (Lua 5.1) |
| X11 | Export : `PlanExport` liste ce que le format ne porte pas **avant** d'exporter ; `Encode` refuse (`needsConfirmation`) tant qu'une perte d'**intention** n'est pas acceptée (`acceptLosses`). Pertes d'intention : objectifs `rank`/`unlimited`, `ext` (build/phase), clés que le site écartera (inconnue, autre classe, doublon, bannissement déjà souhaité), troncatures, lien non http, talents invalides, stats arrondies/plafonnées/inconnues. Information seulement : `id/revision/catalog/model`, stats à zéro. Classe inconnue ⇒ refus définitif. | CONFIRMÉ FIXTURE |
| X12 | Sécurité : aucun `load`/`loadstring`/`dofile`/`setfenv`/`require` dans les modules du codec (scan de source) ; un contenu hostile (`os.execute`, `]]..loadstring`) n'est que de la donnée. | CONFIRMÉ FIXTURE |
| X13 | **Talents** : le site **normalise** une chaîne de talents à l'ouverture de `?b=` (`10203-000-0110` devient `10000000000001-00000000000000-010000000000001`). Notre codec conserve la chaîne telle quelle (regex du site) ; la validation par arbre (budget 52, hub, prérequis) est hors Lot 2. | OBSERVÉ NAVIGATEUR ; à traiter avec l'éditeur de talents |
| X14 | Validation d'URL de lien = approximation de WHATWG (hôte non vide, caractères d'hôte interdits, port ≤ 65535), vérifiée sur 15 cas contre `new URL()` ; pas prouvée équivalente en général. Les liens ne sont jamais ouverts ni suivis. | CONFIRMÉ FIXTURE (15 cas) |

### Format interne natif (non inventé)
Le modèle interne (`BuildModel`) contient déjà plus que le format du site (objectifs de rang, extensions, conflits conservés). Aucun format d'échange natif n'est défini au Lot 2 : son besoin n'est pas établi. À prévoir **si** des builds avancés doivent s'échanger entre installations : enveloppe versionnée `{format="rbp", v=1, build=<BuildModel sérialisé>}` + hash du catalogue, tolérante aux champs inconnus, avec `ext` conservé ; décision de produit à prendre au moment où une interface d'export existe.

---

## 9. Interface native (Lot 3) : contrats et hypothèses client

Code : `UIStrings.lua`, `Controller.lua` (tout le comportement, sans widget), `UI.lua` (rendu), `Commands.lua`, `Core.lua`. Tests : `tests/lua/test_ui.lua` + `wowstub.lua` (**simulateur** de l'API de widgets, pas le client).

| # | Contrat / décision | Statut |
|---|---|---|
| U1 | Ordre d'initialisation : le client charge les SavedVariables **avant** `ADDON_LOADED` de l'addon ; tout ce qui lit `RebornBuildPlannerDB` est dans le gestionnaire `ADDON_LOADED` (nom exact de l'addon, puis `UnregisterEvent`). La base n'est assignée que si le stockage n'est pas en lecture seule. | À CONFIRMER EN CLIENT (C1) ; l'ordre des événements de chargement est tracé nativement dans `AZC_EVENTS` (`!AzerothSurvivorsCompat/Compat.lua:21-29`) |
| U2 | Commandes `/rbp`, `/rebornplanner` : aucune collision statique dans les addons installés (grep `SLASH_*`) ; à l'exécution, un alias déjà pris par un autre addon n'est **pas** repris. Arguments : rien/`toggle`, `reset`, `diag`. | Statique + simulé ; C3 en client |
| U3 | Widgets utilisés, tous déjà employés par les addons natifs installés : `UIPanelButtonTemplate` (13 fichiers), `UIPanelCloseButton` (11), `InputBoxTemplate` (3), `UIPanelScrollFrameTemplate` + `EditBox` multiligne (`AzerothFieldKitReborn/CopyLog.lua:681-686`), `SetBackdrop` (48), `SetClampedToScreen` (28), `StartMoving`/`RegisterForDrag` (28), `UISpecialFrames` (17), `SetMaxLetters`, `HighlightText`, `FULLSCREEN_DIALOG`. `SetWordWrap` n'est appelé que s'il existe (test sans). Aucune API de WoW moderne, aucun `C_Timer`, aucun mixin, aucun `OnUpdate`. | Présence statique ; comportement visuel INCONNU (C2, C6, C17, C18) |
| U4 | **Pas de presse-papiers** : export = zone de texte sélectionnée (`HighlightText`), le joueur fait Ctrl+A / Ctrl+C (même principe que la fenêtre de copie de FieldKit) ; import = Ctrl+V dans une zone de texte. Les liens ne sont jamais ouverts. La zone d'export remet le texte si on le modifie. | À CONFIRMER EN CLIENT (C13, C14) |
| U5 | Échap : la fenêtre est dans `UISpecialFrames` **seulement** quand l'éditeur n'a aucune modification non enregistrée ; une boîte de dialogue ouverte la remplace (Échap = « Continuer ») ; jamais de perte de brouillon par Échap. Le brouillon reste en mémoire quand la fenêtre est masquée et n'est jamais auto-enregistré (perdu au `/reload`). | Simulé ; C10 |
| U6 | Aucun widget n'est créé après la première ouverture (412 objets mesurés : 110 boutons, 10 zones de texte, 235 textes, 26 cadres, 25 textures, 3 barres de défilement, 3 zones défilantes) ; listes paginées (8 builds, 9 entrées de catalogue, 6 lignes de rapport) ; pas d'animation. | CONFIRMÉ SIMULÉ (test d'égalité du nombre d'objets) |
| U7 | Fenêtre 780×540, déplaçable, bornée à l'écran (`SetClampedToScreen`), position `{point,x,y}` et échelle (0,6-1,5) dans `settings` (validées), échelle réduite automatiquement pour tenir dans `UIParent` ; position aberrante ignorée ; `/rbp reset`. | Simulé ; réaction réelle du client au clamp : INCONNU |
| U8 | Identifiants : le plan ne stocke que des **clés de catalogue** ; les noms (FR/EN) et les icônes ne servent qu'à l'affichage ; libellé d'étape par défaut = `""` ; rien de traduit n'est écrit (test sur le texte sérialisé). | CONFIRMÉ SIMULÉ |
| U9 | « Suivre » (activer) exige un build sans conflit ni erreur et une classe connue ; « Enregistrer et suivre » enregistre toujours, puis tente d'activer ; un import n'est jamais actif. | CONFIRMÉ SIMULÉ |
| U10 | Ce que l'éditeur ne sait pas encore éditer (statistiques, objectifs `rank`/`unlimited`, `ext`, étapes en trop) est **listé** dans l'onglet Notes et conservé à l'enregistrement (test de conservation). | CONFIRMÉ SIMULÉ |
| U11 | Contrôle de mise en page (`world.lint`) sur tailles estimées de texte (0,6 × corps) : fenêtre dans l'écran, textes dans leur cadre, libellés dans leurs boutons, pas de recouvrement de contrôles ; 1365×768, 1920×1080, 1024×768, 800×600 ; EN et FR ; noms longs, notes longues. **Ce n'est pas un rendu** : aucune capture réelle n'existe. | SIMULÉ |

---

## 10. Lot 3.1 : bannissement après acquisition, infobulles, apparence

| # | Contrat / décision | Statut |
|---|---|---|
| V1 | `phase.banishAfter = {clé…}` : sous-ensemble des `spells` de la même étape, max 3, ordre = ordre d'ajout ; absent = vide. Un sort peut être souhaité et marqué (pas de conflit). Marque sur un sort non souhaité = conflit `BANISH_AFTER_NOT_WANTED` ; doublon = `DUPLICATE_ENTRY` ; plus de 3 / non-chaîne = erreur. | CONFIRMÉ (Lua 5.1) |
| V2 | `phase.banish` garde son sens « à éviter » et les limites du site. Souhaité + évité reste `CONFLICT_SPELL_BANISH` ; `BuildModel.ConvertBanishToAfter` est l'unique conversion, déclenchée par le joueur. | CONFIRMÉ |
| V3 | Retirer un sort retire sa marque (`RemoveSpell`) ; réordonner ne change rien (marques par clé). L'identité d'un conflit pour « cette édition en ajoute-t-elle un ? » est code+clé comptés (et non le chemin). | CONFIRMÉ |
| V4 | `azsb1:` ne peut pas représenter `banishAfter` : le décodeur du site supprime tout bannissement présent aussi dans les sorts. `PlanExport` ajoute une perte d'intention par marque et n'injecte rien dans `banish`. | CONFIRMÉ par le décodeur du site (hors ligne) ; non rejoué dans l'interface du site |
| V5 | Règle de jeu « un sort acquis peut-il être banni plus tard ? » : non établie. Texte du site : « A banished spell never comes up in a level-up that run. Banish needs its account talent. » Le planner n'agit jamais et ne promet aucun moment. | INCONNU (D16) |
| V6 | Infobulle : un `GameTooltip` partagé, au survol seulement ; sorts : `SetHyperlink("spell:<id>")` à la volée (même appel que `AzerothSurvivors/Inspect.lua`) puis lignes du planner ; sans texte du jeu : « Effet détaillé indisponible » ; bijoux/amulettes : uniquement les champs du catalogue (aucun effet ni statistique). | Simulé ; fidélité du texte natif à Reborn : INCONNUE (D9) |
| V7 | Fenêtre : fond uni alpha 1, strate `DIALOG` niveau 20 ; boîte de dialogue `FULLSCREEN_DIALOG` niveau 100 ; panneau par vue. | Simulé ; rendu réel INCONNU (D2) |


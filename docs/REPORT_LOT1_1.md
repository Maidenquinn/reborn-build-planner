# Rapport — LOT 1.1 (stockage sans perte)

**Verdict : PASS.** Les deux défauts relevés par GPT sont corrigés et couverts par des tests Lua 5.1 réels.

## Défauts et corrections

| # | Défaut (Lot 1) | Correction (`Storage.lua`) |
|---|---|---|
| A1 | `quarantine()` supprimait les plus anciens enregistrements au-delà de 50 : perte silencieuse (confirmé : 51 ou 100 enregistrements invalides ⇒ ouverture « OK » avec des pertes). | Politique **sans perte ou refus** : les enregistrements à isoler sont collectés (`pend`), puis `commitQuarantine` vérifie `existants + nouveaux ≤ 50`. Sinon **refus complet** (`QUARANTINE_FULL`), base d'origine rendue intacte, handle **lecture seule**, statut `REPAIR_REFUSED` (ouverture) ou `MIGRATION_FAILED` (migration), message chiffré (« 51 enregistrement(s)… 0 déjà… capacité 50 »). Une quarantaine préexistante saturée n'est jamais tronquée. |
| A2 | `Open` normalisait directement la table SavedVariables chargée (`settle(existing)`). | **Ouverture transactionnelle** : (1) limites de la source (`Util.Measure` : nœuds, profondeur, cycles, fonctions ⇒ `SOURCE_REJECTED`), (2) copie profonde, (3) normalisation de la copie, (4) vérification d'invariants (schéma, builds valides, bibliothèque/actifs cohérents, quarantaine ≤ capacité, **aucun enregistrement perdu**), (5) acceptation de la copie ou refus complet. La table chargée n'est **jamais** modifiée ; si rien n'est à réparer elle est conservée telle quelle (pas de remplacement inutile). |
| — | (découvert) la corbeille éliminait le plus ancien build sans le dire. | `Delete` retourne `true, evicted{id,name,class}` : l'éviction par plafond est signalée. |

Le seul élément qui peut encore disparaître est un build **supprimé par l'utilisateur** et évincé de la corbeille (20) ; il est nommé dans le retour de `Delete`.

## Tests (Lua 5.1, vrais modules) — avant / après

Nouveau fichier `tests/lua/test_storage_hardening.lua` (9 cas) : 49 / 50 / 51 / 100 invalides, quarantaine préexistante saturée (+0 / +1 / +5 sur 45), migration à 50 et 51, ouverture sans mutation de la source (builds invalides, actif orphelin, structures partielles, données inconnues), table propre conservée, limites de source (trop de nœuds, fonction, cycle, profondeur), invariants violés par injection, éviction de corbeille signalée.

| | Cas | Assertions OK | Échecs |
|---|---|---|---|
| **Avant** (code du Lot 1, `tests/results/lot1_1_before.txt`) | 9 | 155 | **33** |
| **Après** (`tests/results/lot1_1_after.txt`) | 9 | 193 | **0** |
| Suite Lua complète après | 66 | 2 339 | 0 |

Un ancien test (« quarantine is capped », qui validait le comportement avec perte) a été remplacé par le test de la nouvelle politique. Lot 0 (273) et générateur (84) inchangés et verts.

## Limites
* Un `/reload` sur une base refusée laisse le planner en lecture seule : l'utilisateur doit pouvoir exporter ou réinitialiser (UI des lots suivants) ; la capacité 50 est un réglage documenté (`S.LIMITS.quarantine`).
* Non testé en client (voir `REPORT_LOT1.md` §6).

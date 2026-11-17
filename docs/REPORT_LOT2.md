# Rapport — LOT 2 (codec officiel `azsb1:`)

**Verdict : PASS CONDITIONNEL.** Codec, import en deux temps et export avec pertes signalées livrés et testés sous Lua 5.1. Compatibilité avec le site **démontrée par comparaison au code du site (Node) et par une recette navigateur partielle** (`?p=`). L'import par collage dans l'interface du site, « Copy code » et un autre navigateur restent à faire : `VALIDATION NAVIGATEUR REQUISE` (protocole P-W1, `VALIDATION_PLAN.md`).

## 1. Fichiers
* Addon : `Utf8.lua`, `Base64Url.lua`, `Json.lua`, `PlannerCodec.lua` (créés) ; `Locale.lua` (`Register`), `BuildModel.lua` (limite de lien 900 octets = 300 unités UTF-16), `Storage.lua` (`SetActive` refuse un build à conflits ou de classe inconnue ; `Update` désactive un build actif devenu non propre), `RebornBuildPlanner.toc` (ordre `Storage → Utf8 → Base64Url → Json → PlannerCodec → Core`), `Core.lua` (version).
* Tests/outils : `tests/lua/test_codec.lua` (26 cas), `tools/gen_codec_cross.mjs` → `tests/fixtures/codec/cross.json` (60 plans + corpus nombres/chaînes/UTF-16/espaces/liens), `tools/verify_reencoded.mjs`, copie de l'asset du site `tests/fixtures/codec/reference/BYjmu0KK.js` (oracle de test, non livré dans l'addon), `tests/results/lua_{reencoded,origin}.json`, `browser_recette_2026-11-17.md`. `golden.json` **non modifié**.
* Docs : `CONTRACTS.md` §8, `VALIDATION_PLAN.md` (P-W1), `PROJECT_STATE.md`.

## 2. API (prête pour une future interface d'import)
* `PlannerCodec.Decode(texte, catalogue)` (alias `PreviewImport`) → aperçu : `ok`, `kind` (`plan`/`talents`), `build` (modèle normalisé, id `pending`), `name`, `class`, `classKnown`, `phases[]` (résumé par phase), `status` (`ready`/`needs_repair`), `canActivate`, `issues{list,errors,conflicts,warnings}` (chaque entrée : niveau, code, chemin, clé, **message localisé**), `exportReport` (pertes d'une ré-exportation), `source` (texte d'origine borné à 4 Ko, pour diagnostic), `official` (hôte). Aucune mutation persistante.
* `PlannerCodec.CommitImport(handle, aperçu, {name, class})` → `id` | `nil, erreur` : nouveau build, jamais activé, jamais d'écrasement.
* `PlannerCodec.PlanExport(build, catalogue)` → rapport de pertes (`severity` `intent`/`info`) ; `Encode(build, catalogue, {acceptLosses})` → code, ou refus avec `needsConfirmation`.

## 3. Décisions produit appliquées
Conflits conservés + aperçu + build « à réparer » non activable (X6) ; libellé `""` = défaut, jamais de texte français dans les données (X9) ; pertes d'intention annoncées avant export, métadonnées internes omises en information (X11) ; aucun ASB1/ASB2/ASBP.

## 4. Tests (Lua 5.1, vrais modules ; `python -I tools/run_all.py`, exit 0)
| Étape | Résultat |
|---|---|
| Catalogue à jour | identique |
| Générateur | 84 assertions, 0 échec |
| Lot 0 | 273 assertions, 0 échec |
| Lua 5.1 (toutes suites) | **92 cas, 6 526 assertions, 0 échec** (dont `test_codec` : 26 cas, 4 111 assertions) |
| JS ↔ Lua (décodeur officiel sous Node) | **63 codes vérifiés** (JS→Lua→JS : 60 ; Lua→JS : 3) |

Couverture demandée : golden du site (8 encodages exacts, 25 décodages classés accord / divergence documentée) ; JS vs Lua exact sur 60 plans ; accents, émojis, CJK, U+2028, limites UTF-16 (coupe dans une paire) ; notes multilignes ; phases nulles/abrégées/5ᵉ phase ; alternatives à trous ; décimales (`0.1+0.2`, `1/3`, `1e-6`) ; légendaires homonymes ; clés inconnues/mauvaise classe/conflits/doublons ; 6 sorts + 3 bannissements (+ débordement conservé) ; liens valides/invalides (15 cas contre `new URL`) ; `?b=` avec/sans classe ; version future/0 ; base64 invalide ; JSON malformé, trop profond, trop de valeurs, trop gros ; UTF-8 invalide ; import refusé sans mutation ; export avec pertes ; aller-retour Lua → code → Lua.

**Distinction demandée** : (1) égalité sémantique : démontrée sur tous les cas communs ; (2) égalité exacte du code : **obtenue sur 68/68** codes comparés (8 golden + 60 aléatoires), aucune différence à expliquer pour les plans valides — les seules différences sont des valeurs que le site **corrige à l'import** (arrondi 0,1, plafond 999, normalisation des talents) et des entrées qu'il écarte alors que nous les gardons ; (3) compatibilité navigateur : §5.

## 5. Compatibilité site
* Bundle du site **inchangé** depuis le snapshot (SHA-256 identique, catalogue `384db000d5ac311d` identique), vérifié le 2026-11-17.
* **Observé dans le vrai site** (volet navigateur) : un code produit par `Encode` s'ouvre avec tous les champs attendus (trou de bijou à la 3ᵉ position, amulette légendaire, stats, notes de 27 caractères) et le site ré-enregistre **le même code** ; un build créé sur le site se décode et se ré-exporte à l'identique. Détail : `tests/fixtures/codec/browser_recette_2026-11-17.md`.
* **Écart observé** : le site réécrit une chaîne de talents arbitraire (`?b=`) selon ses règles d'arbre (X13).
* **Non prouvé** : import par collage dans l'interface, bouton « Copy code », autre navigateur, build avec conflits dans le site, notes très longues. Deux builds de test (`Warrior 😀 é`, `Site test é⚔`) restent dans le stockage local du volet navigateur (je n'ai pas pu les supprimer : l'action a été refusée).

## 6. Risques et inconnues
* Validation d'URL = approximation de WHATWG (15 cas concordants, pas une preuve générale).
* Plafonds de taille choisis (code 131 Ko, décodé 96 Ko) : pire cas d'un code officiel non établi ; ajustables (`C.LIMITS`).
* UTF-8 strict : un code que le site accepterait avec substitution U+FFFD est refusé chez nous.
* Talents : aucune validation d'arbre ; le site peut les réécrire.
* `Utf8.Trim` suit `String.prototype.trim` de JavaScript mais n'a été confronté qu'à 9 chaînes de référence.
* Format natif d'échange non défini (volontairement).
* Toujours aucun test dans le client Reborn (les `P-*` du Lot 0 restent ouverts).

## 7. Prochaine action
Lot 3 (éditeur simple) peut démarrer : il dispose de `BuildModel`, `Storage`, `PlannerCodec.Decode/CommitImport/PlanExport` et de messages localisés. En parallèle : Kevin exécute les points (1)-(4) de P-W1 (≈ 15 min) et la recette client `S-A…S-D`.

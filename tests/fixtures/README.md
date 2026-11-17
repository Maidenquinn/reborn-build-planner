# Fixtures

| Dossier | Nature | Provenance |
|---|---|---|
| `synthetic/` | 16 scénarios JSON (lignes `AZS*` brutes + attentes). **Reconstruits du code**, pas des captures. | `tools/make_synthetic_fixtures.py` (déterministe) ; héros `Testhero`, runs `r0000a001`/`r0000b002`, sessions `S1`/`S2`. Valeurs inventées signalées : `bonus="x_synthetic"`, `mode="new"` d'une pièce neuve, noms localisés. |
| `runtime-captures/` | **Vides : aucune capture client n'existe.** À remplir par la recette `S-A…S-F` (anonymisée). | — |
| `codec/golden.json` | Vecteurs produits par le **vrai code du site** exécuté sous Node (8 encodages, 25 décodages). | `tools/gen_codec_golden.mjs`, asset `BYjmu0KK.js` (SHA-256 dans le fichier). |
| ~~`catalog/384db000d5ac311d/`~~ (retiré du dépôt ; local : `.local/catalog/` ou `RBP_CATALOG_DIR`) | Copie de `index, classes, spells, jewelry, amulets, legends` + `i18n/frFR` du catalogue public `data/v1`. | Archive d'audit du 2026-11-17 ; données publiques, aucune donnée personnelle. |

Aucun SavedVariables, profil, nom de compte ou journal complet n'est présent.

Couverture des cas demandés : hub sans run `01` · run fraîche `02` · sort acquis puis amélioré `03` · bijou à identité claire `04` · bijou ambigu `05` · légendaires homonymes `06_*` · amulette avec `amount` `07` · cartes sorts+bijoux `08` · bannissements restants `09` · reroll `10` · reload à globales vides `11`/`11b` · nouvelle run `12`/`13`.

Format d'un pas : `world_enter{session}` · `line{prefix,msg}` · `token{name}` · `check{expect, identities, tokens}` ; `expect` est un sous-ensemble de `Model.view()`.

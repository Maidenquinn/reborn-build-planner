# Recette navigateur du codec (P-W1, partielle) — 2026-11-17

Environnement : volet navigateur intégré de l'application Claude (Chromium), site réel `https://azreborn.com/planner/warrior`, stockage local du volet (aucun build personnel de Kevin : le stockage était vide, 2 builds de test y ont été créés et y restent). Bundle du site inchangé : `BYjmu0KK.js` SHA-256 `df3e982b…2c1c` identique au snapshot ; `data/v1/index.json` content `384db000d5ac311d` identique.

| # | Action | Observé | Résultat |
|---|---|---|---|
| 1 | Ouvrir `?p=<code produit par PlannerCodec.Encode>` (nom `Warrior 😀 é`, talents `10203-000-0110`, phase 1 : Whirlwind, Execute ; phase 2 : trinket `hoj` en **3ᵉ position**, amulette `legendary:cleave`, stats damage 50 / speed 7.5, notes de 27 caractères avec `\n`, tabulation, guillemets, antislash et U+2028) | Le site affiche le nom exact ; phase 1 « 2/6 » Whirlwind puis Execute ; phase 2 : « Hand of Justice » en 3ᵉ emplacement de bijou (les emplacements 1-2 vides = trou conservé), « Medallion of the Bladestorm: Cleave — Legendary amulet of Cleave » ; stats 50 et 7.5 ; compteur de notes **27/2000** | **Conforme** |
| 2 | Lire le code que le site a lui-même enregistré (`localStorage azs-planner-builds`, champ `code`) pour ce build importé | **Identique caractère pour caractère** au code Lua | **Égalité exacte démontrée** |
| 3 | Créer sur le site un build de test (nom `Site test é⚔`, spells Cleave puis Whirlwind, bannissement Mortal Strike) ; lire le paramètre `p` du site | `WzEsIlNpdGUgdGVzdCDDqeKalCIs…` | — |
| 4 | Décoder ce code avec `PlannerCodec.Decode` (Lua 5.1) puis `Encode` | `ok`, `ready`, 0 avertissement, nom/classe/sorts/bannissement corrects ; **re-export identique au code du site** | **Conforme** |
| 5 | Ouvrir `?b=10203-000-0110` | Onglet Talents ouvert ; le site **réécrit** la chaîne en `10000000000001-00000000000000-010000000000001` : il normalise/valide les talents selon ses règles d'arbre | **Écart à retenir** : une chaîne de talents arbitraire n'est pas relue à l'identique (voir CONTRACTS §8) |

Non exercé (reste `VALIDATION NAVIGATEUR REQUISE`) : l'import par **collage** dans l'interface du site, les boutons « Copy code » / « Copy link » (lecture du presse-papiers non testée), les autres navigateurs, un build avec conflits (clé d'une autre classe) chargé dans le site, un build de plusieurs centaines de caractères de notes.

# Recette client — Reborn Build Planner 0.3.1 (Lot 3.1, ≈ 20 min)

**Statut : NON EXÉCUTÉE.** Les résultats ci-dessous sont des comportements attendus, issus d'une simulation. Rien de ce qui suit n'a été observé dans le client Reborn.

Installation et désinstallation : identiques à `RECETTE_CLIENT_LOT3.md` (§ Installation), plus `UPDATE_FROM_0.3.0.md` si 0.3.0 est déjà installée. Les C1-C18 du Lot 3 qui n'avaient pas été exécutés restent à faire (surtout C8 Ctrl+V, C10, C13-C14 import/export, `/reload` après enregistrement).

| # | Étape | Attendu |
|---|---|---|
| D1 | `/rbp diag` | `version 0.3.1-lot3.1, storage …, catalogue 384db000d5ac311d (OK)` |
| D2 | Ouvrir `/rbp` en pleine action (hub, puis run). Grands textes orange du jeu | La fenêtre est **opaque** : aucun texte du jeu ne transparaît à travers. 📷 (1280×720 **et** 1920×1080) |
| D3 | Créer un build, onglet Sorts : « Ajouter » 6 sorts | 6 lignes numérotées, compteur « 6 à conserver / 0 à bannir après acquisition (max 3) » |
| D4 | Sur 3 de ces sorts, bouton « Conserver » → « Bannir après » | Le bouton change de **texte** et la ligne se teinte ; compteur « 3 à conserver / 3 à bannir… » |
| D5 | Tenter une 4ᵉ marque | Refus : « Au plus 3 sorts peuvent être marqués… » |
| D6 | Monter/descendre un sort marqué ; retirer un sort marqué | La marque suit le sort ; le retrait annonce que la marque est retirée avec lui |
| D7 | « Enregistrer », fermer, `/reload`, rouvrir | Les 3 marques sont là |
| D8 | Exporter ce build | Liste des pertes avec 3 lignes « Bannir après acquisition n'existe pas dans le format officiel… » ; code seulement après acceptation ; coller le code dans le planner du site : les 6 sorts s'affichent, **aucun** bannissement (limite connue) |
| D9 | Survoler un sort du catalogue puis de la liste | Infobulle : texte du jeu pour ce sort (à noter : **fidèle ou non** à ce que fait Reborn), puis « Souhaité : priorité n », « Prévu : conserver / bannir après acquisition ». Disparaît en quittant la ligne, en changeant de page/onglet, en fermant la fenêtre. 📷 |
| D10 | Survoler un anneau, un bijou, une amulette (commune et légendaire) (onglet Bijouterie) | Nom, type, rareté/classe, « Effet détaillé indisponible » (le catalogue n'en fournit pas). Pas de chiffre inventé |
| D11 | Survoler un emplacement vide / principal / alternative | Explication « principaux » vs « alternatives ». L'emplacement choisi est préfixé par `>` |
| D12 | Infobulle près du bord droit/bas de l'écran | Reste entièrement visible |
| D13 | Boutons : « Enregistrer », « Enregistrer et suivre », « Créer », « Ouvrir » en vert ; Fermer / Exporter / Annuler… en gris ; « Supprimer » en rouge clair | Lisible, texte non tronqué en FR et EN. 📷 |
| D14 | Avec un build 0.3.0 contenant un sort à la fois souhaité et dans la liste « À éviter » | Statut « À réparer », bouton « Bannir après » sur la ligne de la liste à éviter ; **rien** ne change avant le clic |
| D15 | Taille - / + puis une autre échelle d'interface | Fenêtre entièrement visible, infobulles lisibles |
| D16 | **Question de jeu** : peut-on bannir en jeu un sort déjà acquis lors d'une proposition ultérieure ? | Noter la réponse exacte et sa condition (talent de compte requis ?). Le planner ne le garantit pas et ne bannit jamais |

## À renvoyer
Tableau D1-D16 (OK/KO + remarque), captures 📷, et pour tout KO le texte exact d'un éventuel message d'erreur.

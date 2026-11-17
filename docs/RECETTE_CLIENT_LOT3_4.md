# Recette client — Reborn Build Planner 0.4.2-alpha (≈ 20 min)

**Statut : NON EXÉCUTÉE.** Tout est attendu, issu d'une simulation ; **aucune capture réelle n'existe**. Installation : `INSTALL.md` / `UPDATE_FROM_0.4.1.md`. Merci de joindre des captures 📷.

| # | Étape | Attendu |
|---|---|---|
| G1 | `/rbp diag` | `version 0.4.2-alpha`, catalogue `384db000d5ac311d (OK)`, aucune erreur Lua |
| G2 | Remplir les 12 emplacements (anneaux, bijoux, amulettes dont une légendaire à long nom, ex. « Eye of the Splitting Sky ») 📷 | Dans chaque case : « Principal n / Alt. n » en haut à gauche, **x** en haut à droite, icône 24 px, nom sur deux lignes tronqué ; **aucun texte sous un bouton** ; filet doré entre principaux et alternatives |
| G3 | Cliquer une case : détails en bas | Titre complet coloré par rareté, sections lisibles |
| G4 | Survoler une amulette légendaire (case, puis ligne du navigateur) 📷 | Infobulle **courte** (titre, type, 3 lignes d'effets, « Cliquez pour le détail complet »), **dans l'écran**, sans texte natif de sort, sans chevauchement ; dans la colonne de droite elle s'ouvre **vers la gauche** |
| G5 | Survoler un sort | Titre, classe, état dans le build ; rien d'autre |
| G6 | Cliquer un sort : panneau du bas | Description **native du jeu** seule (section Description) — noter si elle correspond à Reborn |
| G7 | Cliquer une amulette fixe (ex. Mark of Fordring) puis une légendaire : sections Effets (rang 1), Croissance, Disponibilité, source | Valeurs conformes à la page `azreborn.com/planner/<classe>` (à comparer sur 2-3 pièces) ; formule de croissance affichée |
| G8 | Passer le jeu en français (ou `/rbp` avec client frFR) | Libellés FR (Dégâts, Croissance, …) ; titre de légendaire = tête anglaise + sort traduit |
| G9 | Contenu long : défiler dans le panneau du bas (molette ou barre) | Défilement interne, rien ne déborde ; une nouvelle sélection repart du haut |
| G10 | Lignes de sorts : monter / descendre / retirer (`^`, `v`, `x`) | Infobulles « Monter / Descendre / Retirer le sort » ; état Conserver / Bannir après inchangé |
| G11 | Rapprocher la fenêtre du bord droit de l'écran, survoler le navigateur | L'infobulle reste visible |
| G12 | 1920×1080, 1366×768, 1280×720, 1024×768 📷 | Fenêtre entière, rien de tronqué de façon gênante |
| G13 | Coexistence + sauvegarde + `/reload` | Builds, marques, équipements conservés |
| G14 | **Appréciation visuelle** vs maquettes (voir REPORT_LOT3_4 §Différences) | Notes libres + captures |

À renvoyer : tableau G1-G14 (OK/KO), captures 📷, texte exact d'une éventuelle erreur Lua.

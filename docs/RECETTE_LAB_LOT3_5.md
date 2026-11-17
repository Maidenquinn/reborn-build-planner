# Recette du laboratoire visuel (≈ 5 min)

**Objectif : juger le rendu RÉEL des composants avant de refaire toute l'interface.** Rien n'a été vu dans le client côté développeur ; vos captures sont la seule preuve.

## Installation (séparée du planner)
1. Fermer le jeu. Extraire `RebornPlannerThemeLab-0.4.3-proto1.zip` dans `Interface\AddOns\` → dossier `RebornPlannerThemeLab\` (3 fichiers). Aucun autre addon n'est touché ; la seule donnée écrite est `RebornPlannerThemeLabDB` (un drapeau).
2. En jeu : `/rbplab`. Gauche = **nouveau** rendu, droite = **ancien (0.4.2)** pour comparaison.

## À faire
| # | Action | À noter |
|---|---|---|
| L1 | `/rbplab` puis capture plein écran 📷 | Le nouveau rendu est-il plus soigné ? Plus lisible ? |
| L2 | Regarder la ligne « Ce client : … » | Y a-t-il un **NON** ? (copier la ligne) |
| L3 | Petit carré « dégradé : clair en HAUT ? » (en haut à droite de chaque colonne) | Le carré est-il clair en haut ? Sinon `/rbplab flip`, `/reload`, `/rbplab` |
| L4 | Survoler puis cliquer-maintenir chaque bouton | Teinte au survol ? Teinte à l'appui ? |
| L5 | Boutons : le texte est-il centré et net ? « Désactivé » est-il clairement inactif ? | |
| L6 | Champ de recherche : cliquer dedans, taper | Bordure dorée au focus, texte ivoire, placeholder qui disparaît |
| L7 | Ligne de sort, case pleine / vide / choisie, entrée de catalogue | Lisibles ? Un nom long (« Eye of the Splitting Sky: Enchaînement ») passe-t-il sur 2 lignes ? |
| L8 | Infobulle d'exemple (bas de chaque colonne) | Cadre lisible, taille adaptée |
| L9 | `/rbplab diag` | Copier la sortie |
| L10 | Verdict : **thème approuvé / à corriger** (préciser : couleurs, bordures, tailles de police, densité) | |

À renvoyer : captures, ligne des capacités, réponses L3-L10. **Sans accord sur le thème, l'éditeur complet n'est pas refait.**

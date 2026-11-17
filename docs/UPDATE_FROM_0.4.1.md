# Mise à jour 0.4.1-alpha → 0.4.2-alpha

1. Fermer le jeu. **Sauvegarder** `WTF\Account\<compte>\SavedVariables\RebornBuildPlanner.lua`.
2. Supprimer `Interface\AddOns\RebornBuildPlanner`, extraire le nouveau dossier. **17 fichiers** (nouveau : `Describe.lua`).
3. `/rbp diag` doit annoncer `0.4.2-alpha` et le catalogue `384db000d5ac311d`.

## Vos données
Aucun changement de stockage (schéma 1, `db.meta`, `banishAfter` inchangés). Aucun build n'est réécrit. Seul le **catalogue embarqué** s'enrichit (champs publiés des amulettes), avec le même hash de contenu. Retour à 0.4.1 : sans risque.

## Ce qui change
* Équipements : cases 118×44 à zones réservées (rôle, bouton retirer, icône, nom sur deux lignes tronqué) ; principaux et alternatives séparés par un filet.
* Sorts : boutons haut / bas / retirer compacts (`^`, `v`, `x`) avec infobulles.
* Détails du bas : inspecteur à sections avec défilement interne ; effets des amulettes fixes et légendaires issus des données publiées, en FR avec repli EN.
* Infobulles : **aperçu court** ; le texte natif des sorts n'y figure plus (uniquement dans le panneau Détails) ; ouverture à gauche dans la moitié droite de l'écran.
* Légendaires : nom d'affichage = tête officielle (anglaise) + nom du sort traduit ; la clé `legendary:<sort>` reste l'identité.

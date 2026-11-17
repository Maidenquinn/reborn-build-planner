# Mise à jour 0.3.0 → 0.3.1

1. Fermer le jeu.
2. **Sauvegarde (recommandé)** : copier `WTF\Account\<compte>\SavedVariables\RebornBuildPlanner.lua` ailleurs.
3. Supprimer le dossier `Interface\AddOns\RebornBuildPlanner` (0.3.0), puis extraire le dossier `RebornBuildPlanner\` du package 0.3.1 à la même place. Ne rien supprimer d'autre.
4. Lancer le jeu. `/rbp diag` doit annoncer `version 0.3.1-lot3.1`.

## Vos données
* **Pas de migration destructive** : le schéma de stockage reste `1`. Chaque étape d'un build gagne un champ optionnel `banishAfter` (« bannir après acquisition »). Un build enregistré avec 0.3.0 n'a pas ce champ : il est lu comme « aucune marque », reste valide, et n'est écrit qu'au prochain enregistrement par l'éditeur.
* **Ancien comportement** : en 0.3.0 un sort à la fois souhaité et dans la liste de bannissement était un conflit. Il le **reste** pour les anciens builds (statut « À réparer », suivi refusé). Rien n'est converti automatiquement : sur la ligne concernée de la liste « À éviter », le bouton « Bannir après » le transforme en marque **si c'est ce que vous vouliez**.
* La liste de bannissement existante est renommée **« À éviter : bannir si proposé »**. Son sens n'a pas changé.
* Retour à 0.3.0 : non testé. La 0.3.0 ne connaît pas le champ `banishAfter` ; elle devrait le traiter comme une donnée supplémentaire inconnue (conservée), mais les marques ne seraient pas affichées. En cas de doute, restaurez la sauvegarde de l'étape 2.
* Export `azsb1:` : les marques « bannir après acquisition » ne peuvent pas être représentées dans le format du site. L'export les liste comme **pertes** et demande une acceptation explicite ; elles ne sont **pas** converties en liste de bannissement (le site les supprimerait de toute façon).

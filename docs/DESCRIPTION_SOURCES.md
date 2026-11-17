# Matrice des sources de descriptions (Lot 3.2)

Question : quelles données réellement exploitables existent pour décrire un sort, un anneau, un bijou, une amulette ? Recherche faite dans les addons natifs installés (lecture seule) et dans le catalogue embarqué. **Aucune valeur n'est tirée des maquettes.**

| Élément | Source | Contient | Utilisée ? | Remarque |
|---|---|---|---|---|
| Sort | **Infobulle native du jeu** `GameTooltip:SetHyperlink("spell:<id>")` (même appel que `AzerothSurvivors/Inspect.lua`) | Nom, rang, description, effets tels que le client les construit | **Oui**, lue **une fois par sort**, à la sélection ou au survol, mise en cache, jamais en arrière-plan | Fidélité à Reborn (valeurs modifiées par le serveur) : **à confirmer en client** (D9). Sans réponse : « Effet détaillé indisponible » |
| Sort | Catalogue embarqué (`GeneratedCatalog`) | clé, nom, id de sort, classe, icône | Oui (nom, classe, icône) | Aucune description ni rang |
| Sort | `AZS_SPELLTIPS` / `AZSCARDTIP` (natif, **exécution**) | Effet d'un sort proposé / possédé | **Non** (Lot 4 : données live) | Absent hors partie ; pas de scan |
| Anneau / bijou | Catalogue embarqué | clé, nom, emplacement, icône | Oui | **Aucun effet, aucune statistique** |
| Anneau / bijou | `AzerothSurvivors/Generated/Content.lua` (`AZS_GEN.jewels`) | clé, nom, icône | Non (même contenu que le catalogue) | Pas de champ d'effet |
| Anneau / bijou | `AZSCARDS` (`effect~detail~note`) et `AZS_GEAR` (`bonus`, `amount`, `text`) | Effet de la pièce **proposée** / **possédée**, à l'exécution | **Non** | `amount` n'est pas un rang général des bijoux (non généralisé, contrat Lot 0) ; données live = Lot 4 |
| Amulette | Catalogue embarqué | nom, rareté, classes ; légendaire : sort lié, série, classe | Oui | Pas d'effet de base ni de particularité chiffrée |
| Amulette | `Content.lua` (`AZS_GEN.amulets`) | clé, nom, icône, rareté | Non (idem) | |
| Racial, talents de compte | `Content.lua` (`effect = "..."`) | Texte d'effet | Non | Hors périmètre du planner de builds |
| Site officiel (planner) | Page publique | Texte « A banished spell never comes up in a level-up that run… » | Cité dans CONTRACTS | Pas de description d'objets dans le bundle de référence |

Conséquence : pour les pièces d'équipement, l'inspecteur affiche seulement ce que le catalogue prouve et dit « Effet détaillé indisponible ». Aucun bonus de set, aucune statistique, aucun niveau d'objet n'est fabriqué. Une description fiable des pièces demandera les données live (`AZSCARDS`/`AZS_GEAR`) ou un export de contenu du serveur : à décider avec GPT avant le Lot 4.

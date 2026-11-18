# Audit i18n initial — Reborn Build Planner (18 novembre 2026)

## Périmètre et méthode

Inspection statique des appels explicites `L("...")` et `Locale.T("...")` dans `UI.lua`, `Controller.lua`, `Describe.lua`, `JewelryEffects.lua`, `Commands.lua` et `BuildModel.lua`. Correspondance avec les clés littérales du registre FR (`UIStrings.lua` et `Locale.lua`) et des dictionnaires d'interface additionnels. Les clés construites dynamiquement, `string.format` indirects, les messages hors de ces fichiers et la **qualité linguistique** ne sont pas couverts par ce comptage.

### Couverture initiale des appels repérés

| Langue | Chaînes d'interface trouvées sur 204 références | Limite |
|---|---:|---|
| Français | 201/204 (98,5 %) au début de l'audit ; 3 clés manquantes ajoutées ensuite | Qualité des textes non relue exhaustivement |
| Russe | 87/204 (42,6 %) | Repli anglais sur les autres chaînes |
| Allemand, espagnol, portugais BR, polonais, tchèque, roumain, turc, ukrainien, chinois, japonais, coréen | 20/204 (9,8 %) chacun | Navigation minimale uniquement |
| Anglais | Texte source | Langue de repli, pas de traduction |

Les traductions **d'objets/sorts/classes** proviennent d'un **autre système** : fichiers officiels `data/v1/i18n/<locale>.json` embarqués par `GeneratedCatalog.lua`. Ne pas confondre leur couverture (jusqu'à 317 noms traduits dans plusieurs langues) avec la couverture de l'interface.

Les chaînes suivantes manquaient côté FR et viennent d'être ajoutées dans `UIStrings.lua` :
- `Command %s is already used by another addon and was left alone.`
- `Usage: /rbp (open or close) | /rbp reset | /rbp diag`
- `Window position and size reset.`

Aucune discordance de marqueurs simples `%s`, `%d`, `%f`, `%q` n'a été trouvée dans les paires FR littérales collectées, mais une analyse plus robuste des paramètres reste nécessaire.

## À auditer avant de déclarer « toutes langues complètes »

1. Inventaire AST/lexical des clés **dynamiques** et des textes encore écrits en dur (messages, titres, accès API, notes sur équipements).
2. Contrôle des substitutions `string.format` (ordre, pluriels, unités, genre, ponctuation).
3. Traduction et révision humaine des dictionnaires d'interface manquants, **pas seulement une substitution automatique de mots**.
4. Vérification des noms d'amulettes légendaires : certains titres/têtes de famille restent en anglais parce que le catalogue public ne fournit pas de traduction directe.
5. Test réel des polices du client pour arabe (non sélectionnable actuellement), chinois, japonais, coréen, russe et ukrainien ; contrôles de largeur à chaque taille UI.
6. Export d'un rapport CI de couverture par langue, avec distinction entre anglais de repli, traduction absente et terme volontairement non traduit.

**Statut : audit statique de couverture commencé, audit linguistique complet non terminé.** Les fonctionnalités, builds et SavedVariables restent indépendants des traductions.

# Lot 3.6 — Catalogue des effets bijoux / anneaux

## Diagnostic confirmé

Le catalogue public officiel `jewelry.json` donne les identifiants/slots/noms/icônes des anneaux et bijoux mais pas leurs coefficients. Le catalogue public `amulets.json` et `legends.json` donne déjà les effets d'amulettes et les règles de croissance.

Le projet ASRAdvisor d'AlexEnotov joint à son addon un `Mechanics.lua` pré-généré à partir de ressources de l'exécutable de jeu ; il utilise `AZS_GEN` pour noms/identités/classes. Son approche confirme la faisabilité, **pas** la présence de tous ces coefficients dans `jewelry.json`.

Nous avons construit notre extracteur original `tools/extract_jewelry_local.py` sans copier son code/sa table.

## Livré sur dev/ultimate-ui

- Détection des fichiers `[[jewel]]` dans l'exécutable Reborn lu en lecture seule.
- Extraction des champs `slot`, `behavior`, `base`, des tableaux `effects` et des paramètres numériques `special` lorsque présents.
- Aucune exécution de code extrait : parseur JSON restreint, nombres finis et clés validées ; rejet des valeurs invalides.
- Contrôle par clés et slots officiels (`jewelry.json`). Une extraction partielle est acceptée **avec liste explicite des clés manquantes**, à condition que >=30 objets correspondent au catalogue et qu'aucune clé inconnue/aucun slot incorrect ne soit présent.
- `--require-complete` pour refuser toute clé manquante lors de la construction d'une vraie release.
- Écriture atomique de `GeneratedJewelryMechanics.lua` sous `.local/generated/` ; aucun fichier binaire ou données dérivées de l'exécutable n'est ajouté au Git.
- `JewelryEffects.lua` affiche le type d'effet, sa valeur de base, les autres effets déclarés et les paramètres spéciaux, en FR/EN. Les pourcentages de base sont **explicitement non assimilés aux bonus actuels en run**.
- `/rbp diag` affiche `bijoux : n/N mécaniques locales` ; l'absence de ce fichier n'est plus confondue avec une absence générale d'API.
- Les amulettes fixes et légendaires utilisent toujours le catalogue officiel et les formules documentées. Aucun gameplay auto.

## Test utilisateur Windows : build avec métadonnées locales

Depuis un clone de la branche `dev/ultimate-ui`, dans PowerShell :

```powershell
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors"
```

Si le dossier contient plusieurs `.exe` correspondant au nom du jeu, le script affiche leurs noms et s'arrête pour une sélection explicite via `-GameExe`.

Le script :
1. Télécharge les JSON publics directement dans `.local/catalog/`.
2. Génère le catalogue Lua à partir de ces JSON.
3. Extrait les mécaniques du **client local** (pas du site), avec validation des clés.
4. Exécute les tests obligatoires Lua et les contrats natifs.
5. Construit un ZIP dans `dist/ultimate-0.4.6-local/`, sans toucher à `Interface/AddOns` ni aux SavedVariables.

Le nom de l'exécutable et les droits de lecture doivent être vérifiés par l'utilisateur. Le script est **préparé et testé par les suites synthétiques**, mais n'a pas encore été exécuté sur l'installation Windows de Kevin.

## Recette dans Reborn

- Vérifier `/rbp diag` : version, catalogue, `n/N` des bijoux.
- Inspecter `blooddrinker` (Anneau du buveur de sang), `accuria`, `blackhand`. Confirmer présence d'une description de base et de la provenance locale.
- Inspecter un bijou à effet conditionnel ; les valeurs doivent être nommées « paramètres », et non présentées comme une garantie de bonus en combat.
- Tester une amulette fixe et une légendaire : leurs effets restent issus des données officielles.
- Tester `/reload` : aucun build perdu ni donnée externe modifiée.
- Conserver captures et `/rbp diag`; en cas d'extraction partielle, inclure les clés manquantes et comparer l'exécutable à la version des JSON publics.

## Limites

- **Le ZIP GitHub Actions public-source n'inclut pas les mécaniques locales** ; seul le ZIP construit localement depuis l'exécutable les contient. Ne jamais le présenter comme complet.
- Certains comportements sont complexes (`brooch`, `ashen`, `crusade`, `phylactery`, etc.) ; leur valeur de base ne suffit pas à simuler le bonus réel. Les paramètres extraits sont affichés sans interprétation non démontrée.
- Données de run `AZS_GEAR` utilisées uniquement pour les pièces équipées et identifiées sans ambiguïté ; un planning hors run ne possède pas ces textes live.
- Pas de release ni de fusion sur `main` avant validation complète dans le client.

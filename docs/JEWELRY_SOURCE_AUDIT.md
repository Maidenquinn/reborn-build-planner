# Anneaux et bijoux : audit complémentaire ASRAdvisor (18 novembre 2026)

Sources consultées : guides officiels `/guides/data-api`, `/guides/addon-api` et dépôt public [ASRAdvisor](https://github.com/AlexEnotov/ASR-Addons/tree/main/ASRAdvisor). Aucun fichier, table ou code ASRAdvisor n'est copié dans notre addon.

## Résultat important

Le catalogue public `jewelry.json` expose les identifiants, noms, slots et icônes, mais pas les bonus. ASRAdvisor lit `AZS_GEN.jewels` et exploite un supplément local issu d'éléments de contenu intégrés à l'exécutable. Ses `Mechanics.lua` et `tools/extract-mechanics.cjs` le démontrent. Il ne faut donc pas conclure que les effets détaillés sont tous fournis par l'API publique.

## Implémentation prudente

- `tools/extract_jewelry_local.py` : utilitaire original hors jeu, lecture seule de l'exécutable local, exigence du catalogue officiel local et validation stricte des 44 clés/slots. Aucune copie de l'exécutable ni des ressources tierces dans Git.
- `JewelryEffects.lua` : affichage des effets identifiés par leur comportement et de la valeur de base **dans l'échelle interne**, sans prétendre qu'il s'agit du bonus actuel. API runtime facultative si `AZS_GEN.jewels` expose directement les champs.
- `GeneratedJewelryMechanics.lua` est un supplément local optionnel, généré et ignoré par Git ; on ne dépend pas de celui d'ASRAdvisor.
- Rien de ce supplément ne modifie les SavedVariables, le planner officiel, le gameplay ou les addons natifs.

## Extraction côté Windows

```powershell
python tools/extract_jewelry_local.py --exe "CHEMIN_VERS_EXECUTABLE_REBORN.exe" --catalog "CHEMIN_VERS_data/v1/jewelry.json" --out "addon/RebornBuildPlanner/GeneratedJewelryMechanics.lua"
```

Le chemin exact de l'exécutable doit être retrouvé dans l'installation locale ; ne pas le deviner. Placer ensuite le fichier généré dans le dossier de recette en plus des fichiers de l'addon. Si son extraction échoue, aucune sortie partielle n'est écrite.

## Limites

Les effets complexes (`ashen`, `crusade`, `madness`, `brooch`, `phylactery`, etc.) exigent l'étude de leurs formules natives avant de traduire une valeur de base en pourcentage de bonus. Les valeurs des mains de cartes sont dépendantes de la rareté et de la run et ne se substituent pas aux valeurs de base. Ne pas assimiler `AZS_GEAR.amount` à un rang universel.

La prochaine étape est la validation des extractions avec une installation Reborn réelle, puis un jeu de tests Lua sur la classe, la clé et le comportement avant d'enrichir davantage les descriptions.

# Lot UI 0.4.6-alpha — Moonlight (18 novembre 2026)

## Vérifications et changements

**Statut : pré-recette**, non approuvé visuellement dans le client. Aucun fichier Blizzard Midnight ou jeu retail n'a été intégré, extrait ou redistribué.

### Correctifs vérifiés dans le code

- `/rbp diag` lit `GetAddOnMetadata(ADDON, "Version")` ; fallback local aligné sur `0.4.6-alpha-moonlight`. L'ancien `0.4.3-proto1` provenait de `Core.lua`, pas d'un diagnostic d'installation fiable.
- `/rbp diag` annonce désormais le nombre d'entrées locales de bijoux et si `AZS_GEN` est disponible. Le ZIP public-source n'inclut **aucune entrée locale** (0 attendu) ; utiliser le script Windows pour les 44.
- Le panneau de détails explique clairement l'absence de mécaniques locales, au lieu d'imputer à tort cette absence uniquement au catalogue officiel.
- Le rôle des boutons (primaire, secondaire, danger) ne disparaît plus lors de `Disable` puis `Enable`.
- Blason recentré dans sa barre ; modale au-dessus de l'éditeur ; boutons en trois bandes texturées au lieu de neuf (réduction des widgets statiques sans création en survol).
- Texture et palette originales bleu nuit / acier lunaire, avec contrastes plus nets et sans surcharge de dorures. Référence esthétique : UI moderne fantasy/Midnight **sans copie d'asset Blizzard**.

### Contrats de données

- `amulets.json` / `legends.json` : effets officiels et croissance via `Describe.lua`.
- `jewelry.json` : identités, slots, noms et icônes, **pas** les bonus de base.
- En partie : `AZS_GEAR` en lecture seule uniquement sur identification unique nom/slot, sans recycler des captures du hub.
- Hors jeu : `tools/extract_jewelry_local.py` extrait les métadonnées depuis le client **local**, compare exactement les 44 clés/slots et refuse une sortie incomplète. `GeneratedJewelryMechanics.lua` reste local et non versionné.
- Aucun bannissement, sélection, relance ou mise à niveau automatique.

### Test autonome et packaging

GitHub Actions `Ultimate UI source checks` et `Ultimate UI private preview package`. Le second exécute les suites Lua 5.1 complètes avec le catalogue public actuellement servi, puis génère un ZIP privé sans données de l'exécutable du joueur.

Pour **enrichir les anneaux et bijoux**, exécuter dans ton clone sur Windows :

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_local_equipment_recipe.ps1 -GameRoot "CHEMIN_VERS_INSTALLATION_REBORN"
```

Le script récupère le catalogue public dans `.local/`, découvre l'exécutable si unique, utilise un venv isolé et lance la recette stricte en lecture seule. Il ne copie rien dans `Interface\AddOns` et ne modifie aucun SavedVariables.

### Limites

- Aucune validation visuelle 0.4.6 dans le vrai client, pas de garantie « parfaite » avant capture.
- Les données locales ne sont disponibles qu'après extraction. Un exemple de build ne signifie pas que l'objet est actuellement équipé.
- Les API du jeu et le catalogue changent : réexecuter la génération pour les mises à jour, vérifier le hash de contenu.
- La version distribuable ne contient aucun asset officiel WoW Midnight ; les textures sont originales.

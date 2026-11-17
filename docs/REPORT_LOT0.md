# Rapport de fin de lot — LOT 0

**Verdict : PASS CONDITIONNEL.** Contrats statiques confirmés avec preuves vérifiables ; le client n'a pas été exécuté et aucun Lua n'a tourné, donc l'identité des bijoux/légendaires, `ph` pendant les mains et le comportement de la synchro restent `VALIDATION CLIENT REQUISE`.

**Créés** (tous sous `reborn-build-planner/`, rien hors de ce dossier, installation du jeu en lecture seule) : `docs/{CONTRACTS,VALIDATION_PLAN,PROJECT_STATE,REPORT_LOT0}.md` · `tests/static_anchors.json` · `tests/fixtures/{README.md, synthetic/ (16), codec/golden.json, catalog/384db000d5ac311d/, runtime-captures/README.md}` · `tools/{lot0_model,run_tests,check_anchors,check_env,make_synthetic_fixtures}.py`, `tools/gen_codec_golden.mjs` · squelette `addon/RebornBuildPlanner/{RebornBuildPlanner.toc, Core.lua}` (namespace seul).

**Confirmations clés** : voir `CONTRACTS.md` §1-4. Les plus structurantes : pas d'événement `*_UPDATED` ni de stamp pour gear/cartes ; tables remplacées à chaque ligne ; `AZS_GEAR` nil avant la 1ʳᵉ ligne ; `AZSEND` ne vide pas `AZS_CARDS` ; aucun identifiant de main ni de clé catalogue pour les bijoux ; `AZS_API_RunId()` stable au reload seulement avec un serveur récent ; hub = `ph playing` + `hub=1` ; légendaires : 13 `head` partagés, 2 noms complets homonymes entre classes, noms absents de `i18n`.

**Tests exécutés** : `python -I tools/run_tests.py` → 273 assertions, 0 échec (54 ancres de code sur l'installation réelle, SHA-256 identiques aux snapshots) ; codec du site exécuté sous Node (8 vecteurs, 25 décodages). Non exécutés : client, Lua, aller-retour navigateur.

**Limites** : aucun interpréteur Lua (PATH, WSL) ; l'installation de `lupa` via pip a été refusée par le système et n'a pas été contournée ; les ports Python sont des reconstructions, pas des preuves client.

**Prochaine action** : Lot 1 (catalogue/modèle/stockage), sans dépendance aux inconnues client ; recette `S-A…S-D` (~30 min, lecture seule) pour lever `P-C1/P-S2/P-J*` avant le Lot 4.

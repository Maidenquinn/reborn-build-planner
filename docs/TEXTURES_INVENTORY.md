# Inventaire des textures (Lot 3.5b)

**Origine : toutes dessinées pour ce projet** par `tools/make_textures.py` (bibliothèque standard Python, fixé par des graines : mêmes octets à chaque exécution ; `tools/run_all.py` le vérifie octet par octet). **Aucune ressource d'un jeu, d'ASBuilder ou d'un autre addon n'est lue, copiée ni décalquée.** Aucune licence tierce à gérer ; les fichiers sont sous la même licence que le projet.

**Format** : TGA 32 bits non compressé (type 2, origine bas-gauche, 8 bits d'alpha), dimensions en puissance de 2, ≤ 128 px, total ≈ 150 Ko. **Chargement dans le client : non vérifié côté développeur** (aucun accès au client) ; le laboratoire dessine chaque fichier dans une bande de contrôle (un carré vert ou blanc = non chargé) et `/rbplab diag` imprime le dossier.

**Chemin** : `Interface\AddOns\RebornPlannerThemeLab\Media\<nom>.tga` (le dossier suit le nom de l'addon ; extension explicite).

| Fichier | Taille | Poids | Rôle |
|---|---|---|---|
| `button_danger_nine.tga` | 32x32 | 4114 o | bouton destructif rouge |
| `button_disabled_nine.tga` | 32x32 | 4114 o | bouton inactif |
| `button_primary_nine.tga` | 32x32 | 4114 o | bouton principal or-brun |
| `button_secondary_nine.tga` | 32x32 | 4114 o | bouton secondaire ardoise |
| `button_selected_nine.tga` | 32x32 | 4114 o | bouton choisi bleu-or |
| `icon_frame.tga` | 64x64 | 16402 o | cadre d'icône à centre transparent, teinté par la rareté |
| `inset_nine.tga` | 32x32 | 4114 o | zone en creux (champ, liste), biseau inversé |
| `panel_nine.tga` | 64x64 | 16402 o | panneau ardoise, filet bronze, clous or aux coins |
| `row_sel.tga` | 16x32 | 2066 o | ligne sélectionnée bleu profond vers bleu-or |
| `separator.tga` | 128x8 | 4114 o | séparateur : filet fondu, losange central |
| `slot_empty_nine.tga` | 32x32 | 4114 o | case vide : bordure pointillée |
| `slot_normal_nine.tga` | 32x32 | 4114 o | case d'équipement |
| `slot_selected_nine.tga` | 32x32 | 4114 o | case choisie : cadre or épais, fond bleu |
| `thumb.tga` | 16x32 | 2066 o | curseur de défilement bronze |
| `titlebar_nine.tga` | 64x32 | 8210 o | barre de titre bronze-ardoise |
| `tooltip_nine.tga` | 64x64 | 16402 o | infobulle opaque, double filet or/bronze |
| `veil_hover.tga` | 32x32 | 4114 o | voile chaud de survol (translucide) |
| `veil_pressed.tga` | 32x32 | 4114 o | voile sombre d'appui (translucide) |
| `window_nine.tga` | 128x128 | 65554 o | cadre de fenêtre : double filet bronze, équerres d'angle avec losange or |

**Neuf segments** (`*_nine`) : 4 coins fixes, 4 bords étirés, 1 centre ; coin de 6 à 28 px selon le fichier ; la barre de titre est 64×32. Les voiles et le séparateur sont étirés d'un bloc ; la barre dorée d'une ligne sélectionnée est une texture unie à part (étirer un coin la ferait grossir).

**Régénérer** : `python -I tools/make_textures.py addon_lab/RebornPlannerThemeLab/Media --preview tests/results/texture_sheet.png` ; **aperçu logiciel** (étirement à des tailles typiques, ce n'est pas une capture du client) : `python -I tools/preview_theme.py tests/results/theme_preview.png`.

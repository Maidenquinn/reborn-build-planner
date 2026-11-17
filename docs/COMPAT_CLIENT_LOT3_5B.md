# Rapport de compatibilité client (Lot 3.5b)

## Confirmé par Kevin dans le client réel (`/rbplab diag`, lab v1)
`SetGradientAlpha`, `SetBackdrop`, `SetHighlightTexture`, `SetPushedTexture`, `GetHighlightTexture`, `SetFontString`, `SetTextInsets`, `GetStringHeight`, `SetVertexColor`, `SetTexCoord` : **présents**. Verdict du lab v1 : gauche et droite **indiscernables** (dégradés de 4 % et filets de 1 px imperceptibles) : la technique « régions colorées » est **abandonnée**.

## Ce que le lab v2 utilise (et ce qui reste à confirmer à l'écran)
| Technique | Pourquoi on y croit | Statut |
|---|---|---|
| `Texture:SetTexture("…\\x.tga")` | usage courant du client 3.3.5a ; TGA 32 bits non compressé = format de référence | **à confirmer** (bande de fichiers du lab) |
| `Texture:SetTexCoord(l, r, t, b)` pour 9 segments | confirmé présent ; sert aussi au recadrage d'icône | à voir |
| `SetHighlightTexture(<tga>)` / `SetPushedTexture(<tga>)` + `GetXTexture():SetAllPoints` | confirmés présents ; utilisés par 9 fichiers natifs | à voir : survol / appui visibles ? |
| `Frame:SetToplevel`, strata `FULLSCREEN_DIALOG`, niveau 100 | `SetToplevel` ajouté au diag ; strata standard | à voir (voir §Couches) |
| `Slider` + `SetThumbTexture(<tga>)` | même appel que `EditorKit` | à voir |
| `EnumerateFrames` (diag ponctuel) | API standard ; jamais appelé hors `/rbplab diag` | à voir |

## Couches et opacité (« textes blancs du jeu derrière les panneaux »)
* Cause probable de la capture v1 : fenêtre en strata `DIALOG` ; des textes du jeu (HUD, texte flottant, autres addons) sont à `DIALOG` ou au-dessus, ou le fond n'avait pas de texture pleinement opaque. **Non démontré** : je ne vois pas la capture dans l'environnement de développement.
* Mesures prises : fenêtre en **`FULLSCREEN_DIALOG`, niveau 100, `SetToplevel(true)`, `EnableMouse`** ; chaque surface est une texture **100 % opaque** (alpha 255 dans le fichier, alpha 1 en code, couche `BACKGROUND` sous son contenu) ; seules les voiles de survol / appui sont translucides, et uniquement sur un contrôle ; l'infobulle d'exemple est au-dessus (niveau 120).
* Limite honnête : une fenêtre à `TOOLTIP` ou au-dessus d'un autre addon restera devant la nôtre. `/rbplab diag` **liste les cadres visibles dessinés au-dessus du labo** (nom, strata, niveau) : c'est la mesure à envoyer si un texte reste visible.
* Le HUD du jeu n'est jamais modifié.

## Contraintes respectées
Interface 30300, Lua 5.1, aucune dépendance externe à l'exécution, aucun `OnUpdate`, aucun timer, aucun hook ; les widgets sont créés une fois à l'ouverture (testé : aucun cadre créé ensuite) ; aucun addon natif modifié ; aucune SavedVariable du planner touchée (le lab n'écrit que `RebornPlannerThemeLabDB`, non utilisé en v2).

## Inconnus à lever par la recette
Chargement des 19 TGA ; netteté du pixel-art étiré (filtrage bilinéaire du client) ; teinte exacte des voiles ; lisibilité des polices du jeu (12 / 10 pt) sur ces fonds ; comportement de `SetToplevel` face aux autres addons.

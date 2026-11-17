# Diagnostic du rendu (Lot 3.5, étape A)

**Source** : captures du client réel (0.4.2-alpha, 1920×1080) fournies par Kevin + audit du code de `UI.lua`. Je n'ai **pas** de moyen de produire une capture du client : ce qui suit sépare ce qui est **observé**, ce qui est **déduit du code** et ce qui reste **inconnu**.

## Observé sur les captures
1. Les boutons sont des rectangles **gris moyen** à fine bordure claire ; les désactivés sont plus sombres ; seuls « Créer un build » et le filtre actif ont une teinte (brun-or). Aucune distinction nette repos / action principale / secondaire.
2. La fenêtre et les panneaux sont des **aplats presque noirs** : pas de profondeur, pas de séparation entre panneaux sinon un trait.
3. Les textes courants et secondaires ont presque le **même gris** ; les étiquettes de boutons sont petites (10 pt).
4. Colonne droite : titres de légendaires anglais **tronqués** (« Eye of the Splitting Sky: T… ») ; deux légendaires de même tête ne se distinguent que par la fin coupée.
5. Les cases d'équipement sont lisibles mais d'aspect « formulaire ».
6. Le panneau Détails est une grande zone vide quand rien n'est sélectionné.

## Déduit du code (`UI.lua` 0.4.2)
* Les boutons étaient des `Button` **sans modèle** avec `SetBackdrop` (fond `WHITE8X8`, bordure `WHITE8X8` de 1 px) : aucune texture native rouge ne peut donc apparaître, **mais** l'ensemble n'a ni dégradé, ni liseré, ni état de survol/appui propre (seule une texture de surbrillance à 10 % d'opacité).
* Les couleurs d'étiquette passent par des **codes `|cff…`** : elles écrasent la couleur de police, donc tous les boutons « quiet » prennent le même gris-bleu clair.
* Les rôles de boutons (quiet / primary / warn / danger) ne différaient que par un fond plat et un code de couleur d'étiquette, sans bordure ni dégradé distincts : la hiérarchie visuelle est faible par construction.
* **Textures/régions natives encore présentes** : `InputBoxTemplate` (champs de recherche, nom, lien, talents) et `UIPanelScrollFrameTemplate` (notes, import, export) : ces deux composants gardent le style natif et ne partagent aucune convention avec le reste.
* Chaque écran avait ses couleurs en dur (59 lignes de `UI.lua` posent une couleur ou une texture unie à la main) : pas de système commun.
* Polices : `GameFontHighlightSmall` (10 pt) pour les boutons et la plupart des informations secondaires.

## Compatibilité API 3.3.5a (vérifiée dans les addons natifs installés, pas dans le client)
`SetBackdrop`, `SetFontString`, `SetHighlightTexture`, `Slider`+`SetThumbTexture` : utilisés par FieldKit / EditorKit. **`Texture:SetGradientAlpha` : utilisé par 7 fichiers natifs** (`AzerothSurvivors/Cards.lua:177,458`, `Passage.lua:76-83`, `ProvingGround.lua:194,250`…) ; leur usage établit le **sens** : en `VERTICAL`, la **première** couleur est en **bas**, la seconde en **haut** (`Passage.lua` : `glowTop` = alpha 0 puis 0,5 ; `glowBottom` = 0,5 puis 0). **`SetPushedTexture` : utilisé par 9 fichiers natifs.** Le dégradé et les états sont donc des techniques éprouvées par le jeu lui-même ; leur **rendu dans notre fenêtre** reste à voir (laboratoire, `/rbplab diag`).

## Inconnu (à trancher par le laboratoire)
* Pourquoi le gris des boutons paraît plus clair que les couleurs codées : multiplication par la texture de surbrillance ? gamma ? Le laboratoire montre **côte à côte** l'ancien rendu (aplats) et le nouveau (régions) avec les mêmes coordonnées.
* Lisibilité réelle des tailles de police ; netteté d'un cadre de 1 px à l'échelle de la fenêtre (le sens du dégradé est établi par le code natif, mais reste contrôlé par un carré témoin).

## Décision
Aucun style n'est plus posé bouton par bouton : un seul module `Theme.lua` (palette, typographie, surfaces, boutons, champ, ligne, case, icône à bordure de rareté, infobulle) sera la seule source de style. Il est livré ici **avec** son laboratoire pour validation avant d'être appliqué à l'éditeur complet.

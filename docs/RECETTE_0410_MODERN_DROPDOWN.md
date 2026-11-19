# Recette 0.4.10-alpha-modern — Language dropdown and contemporary UI

**Status: client screenshots still required.** No Blizzard Midnight assets, screenshots, retail fonts, or proprietary textures are bundled. All generated UI art is original.

## Scope

### Language selector
- Replaced FR/EN cycle with a 15-choice in-game dropdown: Automatic, English, Polski, Čeština, Deutsch, Português (Brasil), Español, Français, Română, Türkçe, Русский, Українська, 简体中文, 日本語, 한국어.
- Clicking a row saves the chosen locale in this addon's existing settings. Automatic resolves `GetLocale()` each time the addon initializes; missing localization dictionary or absent key falls back to its English source string.
- A click-away interceptor dismisses the popup without triggering the control behind it.
- The menu is pre-created once; no OnUpdate loop, new textures on hover, network calls, or runtime external dependencies.
- `Locale.RegisterLanguage(code, strings)` is available for future full dictionaries.

**Translation coverage:** French and English are the existing broad-coverage locales. The twelve newly added locales contain **starter navigation translations only**, not complete localization. Where translations are missing, English text is shown. Some client font packs may not display every script (e.g. Chinese/Japanese/Korean) and must be verified in the actual Reborn client. Do not report them as 100% translated.

### Visually revised skin
- Replaced old corner-scrollwork, oversized crest, beveled golden panels and diamond separators with original cool steel and dark smoke-glass textures.
- Main window uses restrained rim lighting; panel chrome is intentionally lower contrast than game items and selected buttons.
- A minimal title-band gradient and a small arcane identity mark; left-aligned title.
- Button materials, tooltips and scrollbar use quieter reflections and depth cues while retaining clear hover, press, selected, disabled and danger states.
- The existing one-screen layout and all saved build data are unchanged; this is a skin/component iteration, not a completed redesign of all spacing, typography and information architecture.

## Validation

GitHub Actions `Ultimate UI source checks` and `Ultimate UI private preview package`: verify code, original texture generation, the full test harness and packaging. Local client screenshots remain essential to validate exact placement, scripts/fonts and readability.

## Windows private recette with equipped jewelry

```powershell
git switch dev/ultimate-ui
git pull --ff-only origin dev/ultimate-ui
powershell -ExecutionPolicy Bypass -File .\tools\build_local_equipment_recipe.ps1 -GameRoot "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors" -GameExe "H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors\AzerothSurvivorsGame.exe"
```

Expected private ZIP folder: `dist/ultimate-0.4.10-local`. No direct modification of the installed game and no publication of executable-derived jewelry metadata.

## Client acceptance scenarios

1. `/rbp diag` must print `0.4.10-alpha-modern`, storage OK and local jewelry coverage `44/44`.
2. Open the 15-row dropdown. Select German: main navigation labels change (e.g. `Suchen:`), untranslated domain texts fall back to English, not empty/error labels.
3. Choose French then Automatic on a French client. Verify `/reload` remembers Automatic and renders French.
4. Verify Cyrillic, Chinese, Japanese and Korean glyphs in the actual client. Font-dependent tofu is a KO for complete localization, not a data corruption problem.
5. Click outside the dropdown; it must close without editing the build. Open the unsaved-changes dialog; the language popup must be dismissed and all three dialog actions remain visible.
6. Compare full-screen screenshots (same resolution/scale) against 0.4.9: fewer ornamental rims, cleaner header, more negative space and visibly differentiated primary/secondary actions.
7. Verify all build actions, tooltip/inspector, jewelry effects, import/export, /reload and coexistence with other addons.

**Do not merge main or label the experience premium/final until these tests pass in the actual Reborn client.**

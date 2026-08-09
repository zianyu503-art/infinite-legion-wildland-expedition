# Design QA — Forged Command Mobile HUD and Wildland Scene

- Source visual truth: `output/design-reference/forged-command-mobile-hud.png`
- Final implementation evidence: selected PNGs in `output/playwright/ui-mobile-scene-final-publish-2026-08-10/`
- Primary comparison state: 568 × 320 CSS px, touch combat, Traditional Chinese, utility rails collapsed, idle joysticks hidden
- Source pixels: 1672 × 941; compared at matching landscape aspect and normalized visual scale
- Implementation pixels: 1136 × 640 at deviceScaleFactor 2; normalized to 568 × 320 CSS px
- Focused states: active dynamic joystick, all material panels, portrait rotation, VIP terrain, Arena setup/challenge/spectator/result

## Final Findings

P0: 0. P1: 0. P2: 0.

- Layout and play space: status and minimap remain in the upper corners, primary actions sit on the left and right edges, and the command strip stays at the bottom. Idle joysticks disappear completely, so the middle battlefield remains playable on 568 × 320, 667 × 375, and 844 × 390 phones.
- Dynamic joysticks: each stick appears at the finger-down origin, uses a 34–38 CSS px radius, real steel/bronze texture sampling, low-opacity rings, a visible thumb cap, and four direction cues. Long-held ownership, two-finger input, release reset, and portrait reset are verified.
- Material system: steel is used for structural shells, waxed canvas for content cards and secondary controls, and hammered bronze for primary/confirm/VIP actions. The status HUD, minimap, command strip, circular controls, cheat input, pause menu, recruit, skills, troop upgrades, map, Arena setup, and Arena results all use loaded texture assets rather than flat color blocks.
- Typography: Noto Sans TC and English labels remain legible without clipping. Arena phone pages use two columns and pagination; setup, +/−, confirm, result, language, back, and exit targets are at least 44 CSS px.
- Scene quality: the free campaign and Arena share the same textured campaign wildland, layered vegetation, faceted rocks, volumetric trees, and soldier renderers. VIP terrain uses deterministic surface flecks, irregular safe clearings, feathered organic biome transitions, and layered curved roads without rectangular chunk seams.
- Interaction state: portrait mode pauses hidden simulation and shows a dedicated rotation screen. Arena spectator mode contains no player entity or player targeting; challenge mode keeps the hero and its dynamic aim/fire control.
- Copy and content: notification banners wrap to two lines and ellipsize on narrow screens. Troop-special guidance, prices, effects, and pagination are separated into readable regions.

## Source-to-Implementation Comparison

The source and final `touch-568x320-design-qa.png` were inspected together in one comparison input. The blackened steel, antique brass edge treatment, circular command language, upper-corner information hierarchy, and central play corridor match the selected direction. The smaller, dynamic, idle-hidden joysticks intentionally supersede the concept’s large fixed controls because the user explicitly requested less obstruction after selecting the direction.

Focused comparison used `touch-568x320-dynamic-stick-active.png` to verify the active control’s texture, opacity, thumb position, and four arrows. Material-focused checks used the seven `touch-material-panel-*.png` captures. VIP and Arena were checked at their target states rather than inferred from the main screen.

## Comparison History

1. The original forged pass still used oversized fixed sticks, only one UI texture role, dense 568 × 320 Arena grids, hard-looking VIP transitions, and a wide central notice.
2. The implementation introduced dynamic origin sticks, three role-specific real textures, edge-based action placement, paginated two-column Arena setup, organic VIP transition feathering, narrow notification wrapping, and real result actions.
3. The first final visual review found two P2 issues in `output/playwright/ui-mobile-scene-final-2026-08-10`: the pause volume row touched the screen edge, and the troop-upgrade guidance overlapped the second item.
4. Both blockers were corrected. Evidence in `output/playwright/ui-mobile-scene-final-publish-2026-08-10/touch-material-panel-pause.png` and `touch-material-panel-soldier_upgrades.png` shows complete borders and separate content regions. The final re-review found no P0, P1, or P2 issue.

## Verification

- Godot deterministic self-test: 286 passed, 0 failed.
- Playwright final matrix: 20 passed, 0 failed.
- Covered desktop Traditional Chinese, desktop English, VIP trial/title/terrain, 568 × 320 / 667 × 375 / 844 × 390 touch layouts, portrait rotation, every material panel, Arena types/counts/upgrades/interactive result flow, spectator battle, and challenge battle.
- Browser console, page, and request errors: none.
- Godot Web release export: passed.
- Final local `index.pck` SHA-256: `724c956f1c5a516b83f331b64b21635cfc6bbe7096ac135c92ad8b78f091c7ff`.

## Non-blocking Polish

- P3: the temporary two-line combat notice remains visually prominent on the smallest phone. Its top safe-corridor position avoids buttons and HUD, but future polish could reduce its dwell time.
- P3: at maximum upward Arena aim, the thumb cap partially covers the up cue; the remaining direction cues and aim state stay clear.

final result: passed

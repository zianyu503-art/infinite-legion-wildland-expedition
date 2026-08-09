# Design QA — Forged Command Mobile HUD

- Source visual truth: `output/design-reference/forged-command-mobile-hud.png`
- Implementation screenshot: `output/playwright/ui-forged-2026-08-09-release/touch-568x320-design-qa.png`
- Viewport/state: 568 × 320 CSS px, touch combat, Traditional Chinese, collapsed utility rails, notifications expired
- Source pixels: 1672 × 941; normalized by aspect and visual scale to the 568 × 320 target
- Implementation pixels: 1136 × 640 at deviceScaleFactor 2; normalized to 568 × 320 CSS px

## Findings

No actionable P0, P1, or P2 differences remain.

- Fonts and typography: Noto Sans TC remains crisp and legible. The live HUD uses a slightly more compact information scale than the generated reference so real stats fit without clipping; hierarchy and contrast match the selected direction.
- Spacing and layout rhythm: player status, minimap, edge handles, twin sticks, special action, and army command strip occupy the same corner/edge zones as the reference. The final 100–108 px stick diameter deliberately leaves more battlefield visible than the concept while preserving mobile reach.
- Colors and visual tokens: near-black blued steel, restrained antique brass, friendly blue, attack orange, red health, and gold currency consistently map to the reference.
- Image quality and asset fidelity: the generated brushed-steel texture is used on panels; the generated wildland material is integrated into the world renderer. Both remain sharp in the Web export with no visible seams, halos, stretching, or compression damage.
- Copy and content: Traditional Chinese labels are coherent and unclipped. Dynamic gameplay content differs from the static concept by design.
- Accessibility and responsiveness: primary controls remain at least 44 CSS px, sticks remain over 100 CSS px, the center gameplay corridor stays clear, and the 568 × 320, 667 × 375, and 844 × 390 touch layouts pass interaction tests.

Focused-region comparison was not needed after the final full-resolution pair: the @2x implementation capture renders the smallest HUD text, panel grain, brass edges, and control rings clearly enough to judge all required fidelity surfaces in one view.

## Comparison History

1. Initial comparison found two P2 issues: idle sticks were too translucent and oversized compared with the selected forged-metal direction; free-world biome colors exposed a hard rectangular chunk boundary.
2. Fixes applied: raised idle steel opacity, reduced stick radius to 50–54 CSS px, unified the continuous ground base, kept biome identity in irregular low-alpha soil patches and props, and used constant texture opacity across chunks.
3. Post-fix evidence: `output/playwright/ui-forged-2026-08-09-release/touch-568x320-design-qa.png` shows opaque readable forged controls, a clear central play corridor, and continuous textured ground without the earlier rectangular seam.

## Browser Verification

- Playwright result: 17 passed, 0 failed.
- Covered desktop Traditional Chinese, desktop English, VIP trial entry, VIP terrain animation, 568 × 320 / 667 × 375 / 844 × 390 touch controls, Arena setup flow, Arena spectator battle, challenge mode, and portrait rotation.
- Primary interactions tested: virtual movement/attack regions, utility drawer open/close, troop-upgrade panel open/close, special button placement, Arena selection flow, and rotation modal.
- Browser console/page/request errors: none.
- Godot self-tests: 278 passed, 0 failed.
- Web release export: passed.

## Follow-up Polish

- P3: the concept uses more pronounced metal brushing on round controls. The implementation keeps it subtler to preserve small-screen gameplay readability and WebGL performance.

final result: passed

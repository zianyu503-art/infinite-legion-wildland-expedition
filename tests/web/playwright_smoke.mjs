import assert from "node:assert/strict";
import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";

const baseUrl = process.argv[2] || "http://127.0.0.1:8060/index.html";
const artifactDir = process.argv[3] || "/tmp/infinite-legion-playwright";
const moduleSpecifier = process.env.PLAYWRIGHT_CORE_MODULE || "playwright-core";
const playwrightModule = await import(
  moduleSpecifier.startsWith("/") ? pathToFileURL(moduleSpecifier).href : moduleSpecifier
);
const playwright = playwrightModule.default || playwrightModule;
const { chromium } = playwright;

await fs.mkdir(artifactDir, { recursive: true });

const browserLaunchOptions = {
  executablePath: process.env.CHROME_PATH || "/usr/bin/google-chrome-stable",
  headless: true,
  args: [
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--use-gl=swiftshader",
    "--enable-unsafe-swiftshader",
    "--ignore-gpu-blocklist",
  ],
};

const results = [];
const caseFilter = process.env.CASE_FILTER || "";

function intersects(a, b) {
  return !(
    a.x + a.width <= b.x ||
    b.x + b.width <= a.x ||
    a.y + a.height <= b.y ||
    b.y + b.height <= a.y
  );
}

function assertCampaignArenaVisuals(state, { expectHero = false } = {}) {
  const arena = state.arena;
  assert.ok(arena?.visuals, "arena must expose its actual visual draw contract");
  const visuals = arena.visuals;
  assert.equal(visuals.profile, "campaign");
  assert.equal(visuals.soldier_renderer_id, "campaign_soldier_v1");
  assert.equal(visuals.hero_renderer_id, "campaign_hero_v1");
  assert.equal(visuals.map_renderer_id, "campaign_wildland_v1");
  assert.equal(visuals.map_source, "WorldGenerator");
  assert.equal(visuals.map_style, "campaign_wildland");
  assert.ok(Number.isInteger(visuals.world_seed));
  assert.ok(visuals.chunk_keys.length > 0 && visuals.biome_ids.length > 0);
  assert.ok(visuals.decoration_count > 0 && visuals.obstacle_count > 0);
  assert.ok(visuals.rendered_chunk_keys.length > 0 && visuals.rendered_biome_ids.length > 0);
  assert.ok(visuals.rendered_decoration_count + visuals.rendered_obstacle_count > 0);
  assert.ok(visuals.rendered_unit_count > 0 && visuals.rendered_unit_types.length > 0);
  const coverage = visuals.coverage;
  assert.ok(coverage?.complete, "arena map chunks must cover every reachable camera view");
  assert.equal(coverage.mode, arena.mode);
  assert.ok(coverage.minimum_camera_zoom >= 0.2 && coverage.minimum_camera_zoom <= 1.0);
  assert.ok(coverage.viewport.width > 0 && coverage.viewport.height > 0);
  assert.equal(coverage.edge_probes_covered, coverage.edge_probe_count);
  assert.equal(coverage.edge_probe_count, arena.mode === "challenge" ? 4 : 1);
  const required = coverage.required_bounds;
  const generated = coverage.generated_bounds;
  const coverageEpsilon = 0.6;
  assert.ok(generated.x <= required.x + coverageEpsilon);
  assert.ok(generated.y <= required.y + coverageEpsilon);
  assert.ok(generated.x + generated.width >= required.x + required.width - coverageEpsilon);
  assert.ok(generated.y + generated.height >= required.y + required.height - coverageEpsilon);
  assert.equal(arena.battlefield.profile, "campaign_wildland");
  assert.equal(arena.battlefield.source, "WorldGenerator");
  assert.equal(arena.battlefield.seed, visuals.world_seed);
  assert.equal(arena.battlefield.blocking_tree_count, visuals.blocking_tree_count);
  assert.ok(arena.units.every((unit) => unit.config_source === "GameConfig.SOLDIERS" && unit.visual_profile === "campaign"));
  const sampledTypes = new Set(arena.units.map((unit) => unit.type));
  assert.ok(visuals.rendered_unit_types.every((type) => sampledTypes.has(type)));
  assert.equal(visuals.hero_rendered, expectHero);
}

function queryUrl(params) {
  const url = new URL(baseUrl);
  for (const [key, value] of Object.entries({ codex_test: "1", ...params })) {
    url.searchParams.set(key, String(value));
  }
  url.searchParams.set("qa", `${Date.now()}-${Math.random().toString(16).slice(2)}`);
  return url.href;
}

async function readState(page) {
  return page.evaluate(() => JSON.parse(window.render_game_to_text()));
}

async function waitForState(page, predicate) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    try {
      const state = await readState(page);
      if (predicate(state)) return state;
    } catch (_) {
      // The bridge is installed a few frames after the document load event.
    }
    await page.waitForTimeout(100);
  }
  throw new Error("Timed out waiting for the expected render_game_to_text state");
}

async function waitForAdvancedState(page, predicate, stepMs = 250, totalMs = 6000) {
  const deadline = Date.now() + totalMs;
  while (Date.now() < deadline) {
    await page.evaluate((ms) => window.advanceTime(ms), stepMs);
    const state = await readState(page);
    if (predicate(state)) return state;
    await page.waitForTimeout(50);
  }
  throw new Error("Timed out waiting for simulated battle state");
}

async function tapLogical(page, state, rect) {
  const point = await logicalPoint(page, state, rect);
  await page.touchscreen.tap(point.x, point.y);
}

async function logicalPoint(page, state, rect) {
  const canvas = await page.locator("canvas").first().boundingBox();
  assert.ok(canvas, "Godot canvas must have a browser bounding box");
  const logicalWidth = state.input.logical_viewport_width || canvas.width;
  const logicalHeight = state.input.logical_viewport_height || canvas.height;
  return {
    x: canvas.x + (rect.x + rect.width * 0.5) / (logicalWidth / canvas.width),
    y: canvas.y + (rect.y + rect.height * 0.5) / (logicalHeight / canvas.height),
  };
}

async function clickLogical(page, state, rect) {
  const point = await logicalPoint(page, state, rect);
  await page.mouse.click(point.x, point.y);
}

const touchSessions = new WeakMap();

async function withTouchDrag(page, state, rect, offset, action) {
  let client = touchSessions.get(page);
  if (!client) {
    client = await page.context().newCDPSession(page);
    touchSessions.set(page, client);
  }
  const start = await logicalPoint(page, state, rect);
  const canvas = await page.locator("canvas").first().boundingBox();
  assert.ok(canvas, "Godot canvas must have a browser bounding box");
  const logicalWidth = state.input.logical_viewport_width || canvas.width;
  const logicalHeight = state.input.logical_viewport_height || canvas.height;
  const end = {
    x: start.x + offset.x / (logicalWidth / canvas.width),
    y: start.y + offset.y / (logicalHeight / canvas.height),
  };
  const touchPoint = [{ x: end.x, y: end.y, id: 71, radiusX: 4, radiusY: 4, force: 1 }];
  const isMoveStick = end.x < canvas.x + canvas.width * 0.48;
  // A real player can put a thumb down directly at any point inside a virtual
  // stick. Starting at the directional point avoids Chromium coalescing the
  // synthetic start+move pair while still exercising Godot's touch path.
  await client.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: touchPoint });
  await waitForState(page, (current) => isMoveStick
    ? current.input?.virtual_controls?.move?.pointer >= 0 && Math.hypot(current.input?.move_x || 0, current.input?.move_y || 0) > 0.1
    : current.input?.virtual_controls?.attack?.pointer >= 0 && current.input?.attack_held === true
  );
  try {
    return await action();
  } finally {
    await client.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
    await waitForState(page, (current) => (
      current.input?.virtual_controls?.move?.pointer === -1 &&
      current.input?.virtual_controls?.attack?.pointer === -1 &&
      current.input?.attack_held === false
    ));
  }
}

async function runCase(name, options, test) {
	if (caseFilter && !name.includes(caseFilter)) return;
	console.log(`[RUN] ${name}`);
  const userDataDir = await fs.mkdtemp(path.join(artifactDir, `${name}-profile-`));
  const context = await chromium.launchPersistentContext(userDataDir, {
    ...browserLaunchOptions,
    viewport: options.viewport,
    screen: options.viewport,
    hasTouch: Boolean(options.touch),
    isMobile: false,
    locale: options.locale || "zh-TW",
    // Keep the generated PWA worker available. The local QA server supplies
    // COOP/COEP directly, so cases do not depend on first-install timing.
    serviceWorkers: "allow",
  });
  const page = context.pages()[0] || await context.newPage();
  const errors = [];
  page.on("console", (message) => {
    if (message.type() === "error") errors.push(`console: ${message.text()}`);
  });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  page.on("requestfailed", (request) => {
    const failure = request.failure();
    const pathname = new URL(request.url()).pathname;
    // Chromium can cancel a redundant engine/pack fetch after Godot has already
    // installed and started the game. A real engine load failure still times
    // out every state assertion below, so this does not hide load bugs.
    if (failure?.errorText === "net::ERR_ABORTED" && (pathname.endsWith(".pck") || pathname.endsWith(".wasm"))) return;
    errors.push(`requestfailed: ${request.url()} ${failure?.errorText || ""}`);
  });
  try {
    await page.goto(queryUrl(options.params || {}), { waitUntil: "load", timeout: 30000 });
    await page.waitForFunction(() => typeof window.render_game_to_text === "function", null, { timeout: 30000 });
    await test(page);
    await page.screenshot({ path: path.join(artifactDir, `${name}.png`) });
    assert.deepEqual(errors, [], `${name} emitted browser errors`);
		results.push({ name, passed: true });
		console.log(`[PASS] ${name}`);
	} catch (error) {
		results.push({ name, passed: false, error: error.stack || String(error), browserErrors: errors });
		console.log(`[FAIL] ${name}: ${error.message || error}`);
  } finally {
    await context.close();
  }
}

await runCase(
  "desktop-zh-vfx",
  { viewport: { width: 1280, height: 720 }, params: { soldier_vfx_scene: "combat", lang: "zh_TW" } },
  async (page) => {
    await waitForState(page, (state) => state.mode === "playing" && state.soldier_upgrades.vfx_count === 57);
    const state = await readState(page);
    assert.equal(state.language, "zh_TW");
    assert.equal(state.input.scheme, "keyboard_mouse");
    assert.equal(state.projectiles.length, 4);
    const layers = state.projectiles.map((projectile) => projectile.vfx_layers[0]).sort();
    assert.deepEqual(layers, ["burning_ammo", "frost_arrow", "paralysis_arrow", "toxic_payload"].sort());
    assert.equal(state.soldier_upgrades.all_maxed, false);
    await page.keyboard.press("t");
    await waitForState(page, (value) => value.input.cheat_active === true);
    await page.keyboard.press("Control+A");
    await page.keyboard.type("the best");
    await page.keyboard.press("Enter");
    const maxedState = await waitForState(page, (value) => value.soldier_upgrades.all_maxed === true);
    assert.equal(maxedState.input.cheat_active, false);
    assert.equal(maxedState.soldier_upgrades.soldier_type_count, 16);
    assert.ok(Object.values(maxedState.soldier_upgrades.selected_research.base).every((rank) => rank > 0));
    assert.ok(Object.values(maxedState.soldier_upgrades.selected_research.special).every((rank) => rank === 3));
  },
);

await runCase(
  "desktop-en-vip-trial-entry",
  { viewport: { width: 1280, height: 720 }, locale: "en-US", params: { lang: "en" } },
  async (page) => {
    await waitForState(page, (state) => state.mode === "title" && state.vip?.access?.state === "not_started");
    await page.keyboard.press("v");
    let state = await waitForState(page, (value) => value.mode === "class_select" && value.edition === "vip" && value.vip?.access?.state === "active");
    assert.equal(state.vip.access.access_source, "trial");
    assert.ok(state.vip.access.remaining_seconds > 86000 && state.vip.access.remaining_seconds <= 86400);
    await page.keyboard.press("3");
    state = await waitForState(page, (value) => value.mode === "playing" && value.vip?.enabled && value.vip?.visuals?.mesh_draw_count > 0);
    assert.equal(state.player.class, "warrior");
    assert.equal(state.vip.continuous_world, true);
    assert.equal(state.vip.visuals.renderer_id, "vip_continuous_terrain_v1");
    assert.equal(state.vip.animation.profile_id, "procedural_stick_motion_v1");
  },
);

await runCase(
  "vip-title-touch-568x320",
  { viewport: { width: 568, height: 320 }, touch: true, locale: "zh-TW", params: {} },
  async (page) => {
    const state = await waitForState(page, (value) => value.mode === "title" && value.input?.scheme === "touch");
    const actions = state.input.title_actions;
    assert.deepEqual(Object.keys(actions).sort(), ["arena", "load", "start", "vip"]);
    const scale = state.input.touch_ui_coordinate_scale;
    const logicalWidth = state.input.logical_viewport_width;
    const logicalHeight = state.input.logical_viewport_height;
    for (const [name, rect] of Object.entries(actions)) {
      assert.ok(rect.x >= 0 && rect.y >= 0, `${name} must start inside the title viewport`);
      assert.ok(rect.x + rect.width <= logicalWidth + 0.5 && rect.y + rect.height <= logicalHeight + 0.5, `${name} must fit inside the short title viewport`);
      assert.ok(rect.width / scale >= 43.9 && rect.height / scale >= 43.9, `${name} must remain at least 44 CSS px`);
    }
    const rects = Object.values(actions);
    for (let left = 0; left < rects.length; left += 1) {
      for (let right = left + 1; right < rects.length; right += 1) {
        assert.equal(intersects(rects[left], rects[right]), false, "title actions must not overlap");
      }
    }
  },
);

await runCase(
  "vip-terrain-animation-touch-844x390",
  {
    viewport: { width: 844, height: 390 },
    touch: true,
    locale: "en-US",
    params: { vip_scene: "combat", touch: "1", lang: "en" },
  },
  async (page) => {
    let state = await waitForState(page, (value) => (
      value.mode === "playing" &&
      value.edition === "vip" &&
      value.vip?.visuals?.mesh_draw_count > 0 &&
      value.vip?.animation?.soldiers?.length === 8
    ));
    assert.equal(state.language, "en");
    assert.equal(state.input.scheme, "touch");
    assert.equal(state.vip.enabled, true);
    assert.equal(state.vip.continuous_world, true);
    assert.ok(state.vip.active_chunk_count >= 25);
    assert.ok(state.vip.active_terrain_ids.length >= 4);
    assert.equal(state.vip.visuals.renderer_id, "vip_continuous_terrain_v1");
    assert.ok(state.vip.visuals.mesh_draw_count > 0);
    assert.ok(state.vip.visuals.triangle_count >= state.vip.visuals.mesh_draw_count * 288);
    assert.ok(state.vip.visuals.rendered_terrain_ids.length > 0);
    assert.equal(state.vip.animation.profile_id, "procedural_stick_motion_v1");
    assert.ok(state.vip.animation.soldiers.some((unit) => unit.action === "attack"));
    assert.ok(state.vip.animation.soldiers.some((unit) => unit.action === "support"));
    assert.ok(state.vip.animation.soldiers.every((unit) => Object.keys(unit.joints).length === 7));
    assert.deepEqual(Object.keys(state.vip.resource_wallet).sort(), ["crystal", "fish", "gold", "herbs", "iron", "salt", "stone", "wood"]);

    const controls = state.input.virtual_controls;
    const xBefore = state.player.x;
    const yBefore = state.player.y;
    state = await withTouchDrag(page, state, controls.move, { x: controls.move.width * 0.34, y: 0 }, async () => {
      await page.evaluate(() => window.advanceTime(500));
      return await readState(page);
    });
    const displacement = Math.hypot(state.player.x - xBefore, state.player.y - yBefore);
    assert.ok(displacement > 2, `VIP terrain must accept real virtual-stick movement: ${JSON.stringify({ displacement, xBefore, yBefore, xAfter: state.player.x, yAfter: state.player.y, moveX: state.input.move_x, moveY: state.input.move_y, pointer: state.input.virtual_controls.move.pointer, terrain: state.vip.current_terrain_id })}`);
    assert.equal(state.vip.animation.hero.action, "walk");

    state = await withTouchDrag(page, state, state.input.virtual_controls.attack, { x: state.input.virtual_controls.attack.width * 0.34, y: 0 }, async () => {
      await page.evaluate(() => window.advanceTime(180));
      return await readState(page);
    });
    assert.equal(state.input.attack_held, true, `attack stick must remain held during the action: ${JSON.stringify({ pointer: state.input.virtual_controls.attack.pointer, movePointer: state.input.virtual_controls.move.pointer, attackHeld: state.input.attack_held })}`);
    assert.equal(state.vip.animation.hero.action, "attack");
    assert.ok(state.player.attack_cooldown > 0 || state.projectiles.length > 0);
  },
);

for (const viewport of [
  { width: 844, height: 390 },
  { width: 568, height: 320 },
]) {
  await runCase(
    `touch-${viewport.width}x${viewport.height}-rails`,
    { viewport, touch: true, params: { soldier_vfx_scene: "combat", touch: "1", lang: "zh_TW" } },
    async (page) => {
      await waitForState(page, (state) => state.input.scheme === "touch" && state.input.virtual_controls.utility_layout === "dual_side_rails");
      const state = await readState(page);
      const scale = state.input.touch_ui_coordinate_scale;
      const controls = state.input.virtual_controls;
      const utility = controls.utility;
      assert.equal(Object.keys(utility).length, 10);
      const left = ["upgrades", "recruit", "command", "skills", "map"];
      const right = ["guide", "notices", "cheat", "fullscreen", "pause"];
      for (const action of [...left, ...right]) {
        const rect = utility[action];
        assert.equal(rect.visible, true, `${action} should be visible`);
        assert.ok(rect.width / scale >= 43.9 && rect.height / scale >= 43.9, `${action} is below 44 CSS px`);
        assert.equal(intersects(rect, controls.move), false, `${action} overlaps move stick`);
        assert.equal(intersects(rect, controls.attack), false, `${action} overlaps attack stick`);
        assert.equal(intersects(rect, controls.special), false, `${action} overlaps special`);
      }
      assert.ok(left.every((action) => utility[action].x / scale <= 3.0));
      assert.ok(right.every((action) => (utility[action].x + utility[action].width) / scale >= viewport.width - 3.0));
      await tapLogical(page, state, utility.upgrades);
      const panelState = await waitForState(page, (value) => value.panel === "soldier_upgrades");
      assert.equal(panelState.input.virtual_controls.panel_close.visible, true);
      await tapLogical(page, panelState, panelState.input.virtual_controls.panel_close);
      await waitForState(page, (value) => value.panel === "");
    },
  );
}

await runCase(
  "desktop-en-vfx",
  { viewport: { width: 1280, height: 720 }, locale: "en-US", params: { soldier_vfx_scene: "gallery", lang: "en" } },
  async (page) => {
    await waitForState(page, (state) => state.language === "en" && state.soldier_upgrades.vfx_effects.length >= 20);
    const state = await readState(page);
    assert.equal(state.soldier_upgrades.vfx_count, 57);
    assert.equal(new Set(state.soldier_upgrades.particle_vfx_ids).size, 57);
    assert.equal(state.soldier_upgrades.particle_vfx_ids.length, 57);
    assert.equal(state.input.scheme, "keyboard_mouse");
  },
);

for (const phase of ["types", "counts", "upgrades"]) {
  await runCase(
    `arena-${phase}-touch-568x320`,
    {
      viewport: { width: 568, height: 320 },
      touch: true,
      params: { arena_scene: phase, arena_mode: "spectator", touch: "1", lang: "zh_TW" },
    },
    async (page) => {
      await waitForState(page, (state) => state.mode === "arena" && state.arena && state.arena.phase === phase);
      const state = await readState(page);
      assert.equal(state.arena.no_player, true);
      assert.deepEqual(state.arena.selection_flow, ["types", "counts", "upgrades", "battle"]);
      if (phase === "types") {
        const scale = state.arena.layout.minimum_touch_css ? state.input.touch_ui_coordinate_scale : 1;
        const typeButtons = Object.values(state.arena.layout.type_buttons);
        assert.equal(typeButtons.length, 16);
        assert.ok(typeButtons.every((rect) => rect.width / scale >= 43.9 && rect.height / scale >= 43.9));
      } else if (phase === "counts") {
        for (const controls of Object.values(state.arena.layout.count_controls)) {
          assert.ok(controls.minus.width >= 43.9 && controls.minus.height >= 43.9);
          assert.ok(controls.plus.width >= 43.9 && controls.plus.height >= 43.9);
        }
      } else {
        for (const controls of Object.values(state.arena.layout.upgrade_controls)) {
          assert.ok(controls.minus.width >= 43.9 && controls.minus.height >= 43.9);
          assert.ok(controls.plus.width >= 43.9 && controls.plus.height >= 43.9);
        }
      }
    },
  );
}

await runCase(
  "arena-interactive-flow-touch-568x320",
  {
    viewport: { width: 568, height: 320 },
    touch: true,
    params: { arena_scene: "types", arena_mode: "spectator", touch: "1", lang: "zh_TW" },
  },
  async (page) => {
    let state = await waitForState(page, (value) => value.mode === "arena" && value.arena?.phase === "types");
    await tapLogical(page, state, state.arena.layout.primary);
    state = await waitForState(page, (value) => value.arena?.phase === "counts");
    const firstCount = Object.values(state.arena.layout.count_controls)[0];
    const teamTotalBefore = state.arena.teams[state.arena.active_team].total;
    await tapLogical(page, state, firstCount.plus);
    state = await waitForState(page, (value) => value.arena?.teams[value.arena.active_team].total === teamTotalBefore + 1);
    await tapLogical(page, state, state.arena.layout.primary);
    state = await waitForState(page, (value) => value.arena?.phase === "upgrades");
    await tapLogical(page, state, state.arena.layout.upgrade_toolbar.special);
    state = await waitForState(page, (value) => value.arena?.upgrade_category === "special");
    assert.ok(state.arena.current_upgrade_type, "arena should expose the soldier type being upgraded");
    assert.ok(state.arena.upgrade_options.length > 0, "arena should expose visible upgrade options");
    const selectedUpgrade = state.arena.upgrade_options[0];
    const firstUpgrade = Object.values(state.arena.layout.upgrade_controls)[0];
    const rankBefore = selectedUpgrade.rank;
    await tapLogical(page, state, firstUpgrade.plus);
    state = await waitForState(page, (value) => {
      const option = value.arena?.upgrade_options.find((entry) => entry.id === selectedUpgrade.id);
      return option && option.rank === rankBefore + 1;
    });
    await tapLogical(page, state, state.arena.layout.primary);
    state = await waitForState(page, (value) => value.arena?.phase === "battle" && value.arena?.visuals?.rendered_unit_count > 0);
    assert.equal(state.arena.no_player, true);
    assertCampaignArenaVisuals(state);
    assert.equal(state.arena.units.some((unit) => unit.target_kind === "hero"), false);
    assert.ok(state.arena.units.some((unit) => unit.specials.includes(selectedUpgrade.id)), "upgraded soldier should carry the selected special into battle");
    state = await waitForAdvancedState(page, (value) => value.arena.active_vfx_ids.includes(selectedUpgrade.id) || value.arena.phase === "result");
    assert.equal(state.arena.units.some((unit) => unit.target_kind === "hero"), false);
  },
);

await runCase(
  "arena-spectator-battle",
  {
    viewport: { width: 1280, height: 720 },
    params: { arena_scene: "battle", arena_mode: "spectator", lang: "zh_TW" },
  },
  async (page) => {
    let state = await waitForState(page, (value) => value.mode === "arena" && value.arena?.phase === "battle" && value.arena?.visuals?.rendered_unit_count > 0);
    assert.equal(state.arena.no_player, true);
    assert.equal(state.arena.hero, null);
    assert.equal(state.player, null);
    assert.ok(state.arena.teams.blue.total > 0 && state.arena.teams.red.total > 0);
    assert.equal(state.arena.units.some((unit) => unit.target_kind === "hero"), false);
    assertCampaignArenaVisuals(state);
    state = await waitForAdvancedState(page, (value) => (
      value.arena.projectile_count > 0 ||
      value.arena.effect_count > 0 ||
      value.arena.teams.blue.alive < value.arena.teams.blue.total ||
      value.arena.teams.red.alive < value.arena.teams.red.total ||
      value.arena.phase === "result"
    ));
    assert.ok(state.arena.projectile_count > 0 || state.arena.effect_count > 0 || state.arena.phase === "result");
    assert.equal(state.arena.units.some((unit) => unit.target_kind === "hero"), false);
    assert.equal(state.arena.projectiles.some((projectile) => projectile.target_kind === "hero"), false);
    assert.equal(state.arena.auto_sized, true);
  },
);

await runCase(
  "arena-challenge-touch-844x390",
  {
    viewport: { width: 844, height: 390 },
    touch: true,
    params: { arena_scene: "battle", arena_mode: "challenge", touch: "1", lang: "en" },
  },
  async (page) => {
    const state = await waitForState(page, (value) => value.mode === "arena" && value.arena?.phase === "battle" && value.arena?.visuals?.rendered_unit_count > 0 && value.arena?.visuals?.hero_rendered === true);
    assert.equal(state.language, "en");
    assert.equal(state.arena.no_player, false);
    assert.ok(state.arena.hero && state.arena.hero.hp > 0);
    assert.equal(state.input.scheme, "touch");
    assert.equal(state.arena.layout.controls_visible, true);
    assert.ok(state.arena.layout.move_stick.width >= 44 && state.arena.layout.aim_stick.width >= 44);
    assertCampaignArenaVisuals(state, { expectHero: true });
    const heroBefore = state.arena.hero.x;
    await tapLogical(page, state, state.arena.layout.aim_stick);
    const movedState = await waitForAdvancedState(page, (value) => value.arena.projectile_count > 0 || value.arena.effect_count > 0 || value.arena.hero.x !== heroBefore);
    assert.equal(movedState.arena.no_player, false);
  },
);

await runCase(
  "arena-portrait-rotation-modal",
  {
    viewport: { width: 320, height: 568 },
    touch: true,
    params: { arena_scene: "battle", arena_mode: "challenge", touch: "1", lang: "en" },
  },
  async (page) => {
    let state = await waitForState(page, (value) => value.mode === "arena" && value.arena?.phase === "battle");
    assert.equal(state.arena.layout.rotation_required, true);
    assert.equal(state.arena.layout.controls_visible, false);
    const timeBefore = state.arena.battle_time;
    await page.evaluate(() => window.advanceTime(1200));
    state = await readState(page);
    assert.equal(state.arena.battle_time, timeBefore, "portrait rotation modal must pause the hidden battle");
    await page.setViewportSize({ width: 844, height: 390 });
    state = await waitForState(page, (value) => value.arena?.layout.rotation_required === false && value.arena?.layout.controls_visible === true);
    await page.evaluate(() => window.advanceTime(500));
    const resumed = await readState(page);
    assert.ok(resumed.arena.battle_time > state.arena.battle_time, "arena battle must resume after rotating back to landscape");
    const rendered = await waitForState(page, (value) => value.arena?.visuals?.rendered_unit_count > 0 && value.arena?.visuals?.hero_rendered === true);
    assertCampaignArenaVisuals(rendered, { expectHero: true });
  },
);

const failed = results.filter((result) => !result.passed);
console.log(JSON.stringify({ passed: results.length - failed.length, failed: failed.length, results }, null, 2));
if (failed.length > 0) process.exitCode = 1;

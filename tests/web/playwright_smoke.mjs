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
  assert.equal(visuals.soldier_renderer_id, "campaign_soldier_v2");
  assert.equal(visuals.hero_renderer_id, "campaign_hero_v2");
  assert.equal(visuals.map_renderer_id, "campaign_wildland_v2");
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

async function logicalPosition(page, state, position) {
  const canvas = await page.locator("canvas").first().boundingBox();
  assert.ok(canvas, "Godot canvas must have a browser bounding box");
  const logicalWidth = state.input.logical_viewport_width || canvas.width;
  const logicalHeight = state.input.logical_viewport_height || canvas.height;
  return {
    x: canvas.x + position.x / (logicalWidth / canvas.width),
    y: canvas.y + position.y / (logicalHeight / canvas.height),
  };
}

async function clickLogical(page, state, rect) {
  const point = await logicalPoint(page, state, rect);
  await page.mouse.click(point.x, point.y);
}

const touchSessions = new WeakMap();

async function touchClient(page) {
  let client = touchSessions.get(page);
  if (!client) {
    client = await page.context().newCDPSession(page);
    touchSessions.set(page, client);
  }
  return client;
}

function dynamicControl(state, controlName) {
  if (controlName === "move" || controlName === "attack") {
    return state.input?.virtual_controls?.[controlName];
  }
  if (controlName === "arena_move") return state.arena?.layout?.move_stick;
  if (controlName === "arena_aim") return state.arena?.layout?.aim_stick;
  throw new Error(`Unknown dynamic control: ${controlName}`);
}

function dynamicContainer(state, controlName) {
  return controlName.startsWith("arena_") ? state.arena?.layout : state.input?.virtual_controls;
}

function controlPoint(control, name) {
  const value = control?.[name];
  if (value && Number.isFinite(value.x) && Number.isFinite(value.y)) return { x: value.x, y: value.y };
  const x = control?.[`${name}_x`];
  const y = control?.[`${name}_y`];
  if (Number.isFinite(x) && Number.isFinite(y)) return { x, y };
  return null;
}

function controlVector(control) {
  return controlPoint(control, "vector") || { x: 0, y: 0 };
}

function rectPoint(rect, fraction) {
  return {
    x: rect.x + rect.width * fraction.x,
    y: rect.y + rect.height * fraction.y,
  };
}

function dynamicStartFraction(controlName) {
  if (controlName === "move" || controlName === "arena_move") return { x: 0.66, y: 0.58 };
  return { x: 0.34, y: 0.58 };
}

function assertDynamicJoystickContract(state, controlName) {
  const container = dynamicContainer(state, controlName);
  const control = dynamicControl(state, controlName);
  assert.ok(container && control, `${controlName} dynamic joystick state must be exposed`);
  const expectedLayoutVersion = controlName.startsWith("arena_") ? 5 : 4;
  assert.equal(container.layout_version, expectedLayoutVersion, `${controlName} must use touch layout version ${expectedLayoutVersion}`);
  assert.equal(container.joystick_mode, "dynamic_origin", `${controlName} must follow the finger-down origin`);
  assert.ok(control.activation_zone, `${controlName} must expose a separate activation_zone`);
  assert.ok(controlPoint(control, "origin"), `${controlName} must expose the current/default origin`);
  assert.equal(control.active, false, `${controlName} must begin inactive`);
  assert.equal(control.visual_visible, false, `${controlName} must not cover play while idle`);
  const scale = state.input.touch_ui_coordinate_scale || 1;
  const radiusCss = Number.isFinite(control.radius_css) ? control.radius_css : control.radius / scale;
  assert.ok(radiusCss > 0 && radiusCss <= 38.01, `${controlName} radius must be at most 38 CSS px`);
  assert.ok(control.base_alpha > 0 && control.base_alpha <= 0.34, `${controlName} base must remain translucent`);
  assert.ok(control.knob_alpha > 0 && control.knob_alpha <= 0.68, `${controlName} knob must remain translucent`);
}

function assertMainUiMaterialContract(state) {
  const visuals = state.ui;
  assert.ok(visuals, "main UI must expose its material contract");
  assert.equal(visuals.profile, "forged_expedition_materials_v2");
  assert.equal(visuals.complete, true, "all main UI material textures must load");
  assert.ok(visuals.textured_region_count >= 29, "all interactive main UI regions must be covered");
  assert.deepEqual(visuals.material_roles, {
    shell: "steel",
    content: "canvas",
    primary_vip_confirm: "bronze",
  });
  for (const material of ["steel", "canvas", "bronze"]) {
    assert.equal(visuals.textures?.[material]?.loaded, true, `${material} UI texture must be loaded`);
    assert.ok(visuals.textures[material].width >= 256 && visuals.textures[material].height >= 256);
  }
  for (const region of [
    "title.background", "class_select.cards", "campaign.hud.player",
    "campaign.controls.dynamic_sticks", "panels.skills", "panels.recruit",
    "panels.soldier_upgrades", "panels.command", "panels.map", "panels.pause",
    "panels.cheat", "panels.confirm_restart", "boss.aionis", "boss.chaos",
    "boss.python", "rotation.overlay",
  ]) {
    assert.ok(visuals.textured_regions.includes(region), `${region} must have an explicit material treatment`);
  }
}

function assertArenaUiMaterialContract(state) {
  const visuals = state.arena?.visuals;
  assert.ok(visuals, "arena UI must expose its visual contract");
  assert.deepEqual(visuals.ui_textures, [
    "dark_blued_steel.png",
    "aged_hammered_bronze.png",
    "tactical_waxed_canvas.png",
  ]);
  assert.deepEqual(visuals.ui_material_roles, { shell: "steel", cards: "canvas", primary: "bronze" });
  for (const material of ["steel", "bronze", "canvas"]) {
    assert.equal(visuals.ui_texture_status?.[material]?.loaded, true, `arena ${material} texture must be loaded`);
    assert.ok(visuals.ui_texture_status[material].width >= 256 && visuals.ui_texture_status[material].height >= 256);
  }
  for (const region of ["setup_background", "header", "footer", "cards", "buttons", "battle_hud", "battle_dynamic_sticks", "result_panel"]) {
    assert.ok(visuals.textured_regions.includes(region), `arena ${region} must be textured`);
  }
}

function arenaTouchScale(state) {
  const logicalWidth = state.input?.logical_viewport_width;
  const viewportCssWidth = state.arena?.layout?.viewport_css?.width;
  if (Number.isFinite(logicalWidth) && Number.isFinite(viewportCssWidth) && viewportCssWidth > 0) {
    return logicalWidth / viewportCssWidth;
  }
  return state.input?.touch_ui_coordinate_scale || 1;
}

function assertArenaTouchTarget(rect, scale, label) {
  assert.ok(rect, `${label} must expose a touch target`);
  assert.ok(Number.isFinite(rect.width) && Number.isFinite(rect.height), `${label} touch target must expose finite dimensions`);
  assert.ok(rect.width / scale >= 43.9, `${label} must be at least 44 CSS px wide`);
  assert.ok(rect.height / scale >= 43.9, `${label} must be at least 44 CSS px tall`);
}

function assertArenaSetupTouchChrome(state, phase) {
  const layout = state.arena.layout;
  const scale = arenaTouchScale(state);
  assert.equal(layout.minimum_touch_css, 44, `${phase} must publish the 44 CSS px touch-target contract`);
  for (const key of ["exit", "back", "language"]) {
    assertArenaTouchTarget(layout[key], scale, `${phase} top-bar ${key}`);
  }
  assert.deepEqual(Object.keys(layout.team_tabs || {}).sort(), ["blue", "red"], `${phase} must expose both top-bar team tabs`);
  for (const [team, rect] of Object.entries(layout.team_tabs)) {
    assertArenaTouchTarget(rect, scale, `${phase} top-bar ${team} team tab`);
  }
  for (const key of ["page_prev", "page_next", "primary"]) {
    assertArenaTouchTarget(layout[key], scale, `${phase} footer ${key}`);
  }
  return scale;
}

async function withDynamicTouchDrag(page, state, controlName, normalizedOffset, action, options = {}) {
  const client = await touchClient(page);
  const idleState = await readState(page);
  const idleControl = dynamicControl(idleState, controlName);
  assert.ok(idleControl?.activation_zone, `${controlName} activation zone is required before touchStart`);
  assert.equal(idleControl.active, false);
  assert.equal(idleControl.visual_visible, false);
  const startLogical = rectPoint(idleControl.activation_zone, options.startFraction || dynamicStartFraction(controlName));
  const idleOrigin = controlPoint(idleControl, "origin");
  const radius = idleControl.radius || (idleControl.radius_css * (idleState.input.touch_ui_coordinate_scale || 1));
  const offset = { x: normalizedOffset.x * radius, y: normalizedOffset.y * radius };
  const endLogical = { x: startLogical.x + offset.x, y: startLogical.y + offset.y };
  const start = await logicalPosition(page, idleState, startLogical);
  const end = await logicalPosition(page, idleState, endLogical);
  const pointerId = options.pointerId || 71;
  await client.send("Input.dispatchTouchEvent", {
    type: "touchStart",
    touchPoints: [{ x: start.x, y: start.y, id: pointerId, radiusX: 4, radiusY: 4, force: 1 }],
  });
  const pressedState = await waitForState(page, (current) => {
    const control = dynamicControl(current, controlName);
    const origin = controlPoint(control, "origin");
    const vector = controlVector(control);
    return control?.active === true && control.pointer >= 0 && control.visual_visible === true && origin &&
      Math.hypot(origin.x - startLogical.x, origin.y - startLogical.y) <= 3.5 &&
      Math.hypot(vector.x, vector.y) <= 0.05;
  });
  const pressedControl = dynamicControl(pressedState, controlName);
  const pressedOrigin = controlPoint(pressedControl, "origin");
  assert.ok(pressedOrigin, `${controlName} must expose its active origin`);
  if (idleOrigin) {
    assert.ok(Math.hypot(pressedOrigin.x - idleOrigin.x, pressedOrigin.y - idleOrigin.y) > Math.max(2, radius * 0.12), `${controlName} must accept a non-default finger-down origin`);
  }
  await client.send("Input.dispatchTouchEvent", {
    type: "touchMove",
    touchPoints: [{ x: end.x, y: end.y, id: pointerId, radiusX: 4, radiusY: 4, force: 1 }],
  });
  await waitForState(page, (current) => {
    const control = dynamicControl(current, controlName);
    const vector = controlVector(control);
    return control?.active === true && control.pointer >= 0 && Math.hypot(vector.x, vector.y) >= 0.35;
  });
  try {
    return await action();
  } finally {
    await client.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
    await waitForState(page, (current) => {
      const control = dynamicControl(current, controlName);
      const vector = controlVector(control);
      return control?.pointer === -1 && control.active === false && control.visual_visible === false &&
        Math.hypot(vector.x, vector.y) <= 0.05 &&
        (controlName !== "attack" || current.input?.attack_held === false);
    });
  }
}

async function assertLongHeldDynamicTouchSurvivesMouseMotion(page, controlName, screenshotName) {
  const heldBefore = await readState(page);
  const controlBefore = dynamicControl(heldBefore, controlName);
  const originBefore = controlPoint(controlBefore, "origin");
  const vectorBefore = controlVector(controlBefore);
  assert.ok(controlBefore?.active, `${controlName} must be active before the long-hold probe`);
  assert.ok(controlBefore.visual_visible, `${controlName} must be visibly rendered before the long-hold probe`);
  assert.ok(controlBefore.pointer >= 0, `${controlName} must retain a touch owner before the long-hold probe`);
  assert.ok(originBefore, `${controlName} must expose its active origin before the long-hold probe`);
  assert.ok(Math.hypot(vectorBefore.x, vectorBefore.y) >= 0.35, `${controlName} must be displaced before the long-hold probe`);
  const owner = controlBefore.pointer;

  // Reproduce the browser-specific sequence which originally revoked a slow
  // thumb: hold past the compatibility-event guard, then deliver genuine mouse
  // movement through Playwright while the CDP touch contact is still down.
  await page.waitForTimeout(760);
  const canvas = await page.locator("canvas").first().boundingBox();
  assert.ok(canvas, "Godot canvas must remain available during a held touch");
  await page.mouse.move(canvas.x + canvas.width * 0.46, canvas.y + canvas.height * 0.20);
  await page.mouse.move(canvas.x + canvas.width * 0.58, canvas.y + canvas.height * 0.27, { steps: 4 });
  await page.waitForTimeout(80);

  const heldAfter = await readState(page);
  const controlAfter = dynamicControl(heldAfter, controlName);
  const originAfter = controlPoint(controlAfter, "origin");
  const vectorAfter = controlVector(controlAfter);
  assert.equal(heldAfter.input?.scheme, "touch", `${controlName} compatibility mouse motion must not switch the input scheme`);
  assert.equal(controlAfter?.pointer, owner, `${controlName} compatibility mouse motion must not revoke its touch owner`);
  assert.equal(controlAfter?.active, true, `${controlName} must remain active after compatibility mouse motion`);
  assert.equal(controlAfter?.visual_visible, true, `${controlName} must remain visible after compatibility mouse motion`);
  assert.ok(originAfter, `${controlName} must retain its origin after compatibility mouse motion`);
  assert.ok(Math.hypot(originAfter.x - originBefore.x, originAfter.y - originBefore.y) <= 0.2, `${controlName} compatibility mouse motion must not move its dynamic origin`);
  assert.ok(Math.hypot(vectorAfter.x, vectorAfter.y) >= 0.35, `${controlName} compatibility mouse motion must preserve its drag vector`);
  await page.screenshot({ path: path.join(artifactDir, screenshotName) });
  return heldAfter;
}

async function withDualDynamicControls(page, state, action) {
  const client = await touchClient(page);
  const idleState = await readState(page);
  const moveIdle = dynamicControl(idleState, "move");
  const attackIdle = dynamicControl(idleState, "attack");
  assert.ok(moveIdle?.activation_zone && attackIdle?.activation_zone);
  const moveStartLogical = rectPoint(moveIdle.activation_zone, { x: 0.7, y: 0.62 });
  const attackStartLogical = rectPoint(attackIdle.activation_zone, { x: 0.3, y: 0.62 });
  const moveRadius = moveIdle.radius || moveIdle.radius_css * (idleState.input.touch_ui_coordinate_scale || 1);
  const attackRadius = attackIdle.radius || attackIdle.radius_css * (idleState.input.touch_ui_coordinate_scale || 1);
  const moveStart = await logicalPosition(page, idleState, moveStartLogical);
  const attackStart = await logicalPosition(page, idleState, attackStartLogical);
  const moveEnd = await logicalPosition(page, idleState, { x: moveStartLogical.x + moveRadius * 0.72, y: moveStartLogical.y });
  const attackEnd = await logicalPosition(page, idleState, { x: attackStartLogical.x, y: attackStartLogical.y - attackRadius * 0.72 });
  await client.send("Input.dispatchTouchEvent", {
    type: "touchStart",
    touchPoints: [
      { x: moveStart.x, y: moveStart.y, id: 91, radiusX: 4, radiusY: 4, force: 1 },
      { x: attackStart.x, y: attackStart.y, id: 92, radiusX: 4, radiusY: 4, force: 1 },
    ],
  });
  await waitForState(page, (current) => {
    const move = dynamicControl(current, "move");
    const attack = dynamicControl(current, "attack");
    return move?.active === true && attack?.active === true && move.pointer !== attack.pointer &&
      Math.hypot(controlVector(move).x, controlVector(move).y) <= 0.05 &&
      Math.hypot(controlVector(attack).x, controlVector(attack).y) <= 0.05;
  });
  await client.send("Input.dispatchTouchEvent", {
    type: "touchMove",
    touchPoints: [
      { x: moveEnd.x, y: moveEnd.y, id: 91, radiusX: 4, radiusY: 4, force: 1 },
      { x: attackEnd.x, y: attackEnd.y, id: 92, radiusX: 4, radiusY: 4, force: 1 },
    ],
  });
  await waitForState(page, (current) => {
    const move = dynamicControl(current, "move");
    const attack = dynamicControl(current, "attack");
    return Math.hypot(controlVector(move).x, controlVector(move).y) >= 0.35 &&
      Math.hypot(controlVector(attack).x, controlVector(attack).y) >= 0.35 &&
      current.input?.attack_held === true;
  });
  try {
    return await action();
  } finally {
    await client.send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
    await waitForState(page, (current) => {
      const move = dynamicControl(current, "move");
      const attack = dynamicControl(current, "attack");
      return move?.active === false && move.pointer === -1 && move.visual_visible === false &&
        attack?.active === false && attack.pointer === -1 && attack.visual_visible === false &&
        current.input?.attack_held === false;
    });
  }
}

async function holdTouchLogical(page, state, rect) {
  let client = touchSessions.get(page);
  if (!client) {
    client = await page.context().newCDPSession(page);
    touchSessions.set(page, client);
  }
  const point = await logicalPoint(page, state, rect);
  const touchPoint = [{ x: point.x, y: point.y, id: 81, radiusX: 4, radiusY: 4, force: 1 }];
  await client.send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: touchPoint });
  try {
    await page.waitForTimeout(80);
    return await readState(page);
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
    isMobile: Boolean(options.mobile),
    deviceScaleFactor: options.deviceScaleFactor || 1,
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
    assertMainUiMaterialContract(state);
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
    assertMainUiMaterialContract(state);
    assert.equal(state.player.class, "warrior");
    assert.equal(state.vip.continuous_world, true);
    assert.equal(state.vip.visuals.renderer_id, "vip_continuous_terrain_v1");
    assert.equal(state.vip.animation.profile_id, "procedural_upright_stick_motion_v2");
    assert.equal(state.vip.animation.model_id, "readable_stick_army_v2");
    assert.equal(state.vip.animation.upright, true);
  },
);

await runCase(
  "vip-title-touch-568x320",
  { viewport: { width: 568, height: 320 }, touch: true, locale: "zh-TW", params: {} },
  async (page) => {
    const state = await waitForState(page, (value) => value.mode === "title" && value.input?.scheme === "touch");
    assertMainUiMaterialContract(state);
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
    assert.equal(state.vip.animation.profile_id, "procedural_upright_stick_motion_v2");
    assert.equal(state.vip.animation.model_id, "readable_stick_army_v2");
    assert.equal(state.vip.animation.upright, true);
    assert.ok(state.vip.animation.soldiers.some((unit) => unit.action === "attack"));
    assert.ok(state.vip.animation.soldiers.some((unit) => unit.action === "support"));
    assert.ok(state.vip.animation.soldiers.every((unit) => unit.model_id === "readable_stick_army_v2" && unit.upright === true && Object.keys(unit.joints).length === 7));
    assert.deepEqual(Object.keys(state.vip.resource_wallet).sort(), ["crystal", "fish", "gold", "herbs", "iron", "salt", "stone", "wood"]);

    const controls = state.input.virtual_controls;
    assert.equal(controls.utility_layout, "collapsible_dual_side_rails");
    assert.equal(controls.utility_drawer_open, false);
    assertDynamicJoystickContract(state, "move");
    assertDynamicJoystickContract(state, "attack");
    assert.equal(intersects(controls.special, controls.gameplay_clear), false, "VIP special button must stay outside the center gameplay corridor");
    assert.ok(controls.gameplay_clear.width / state.input.touch_ui_coordinate_scale >= 160);
    const xBefore = state.player.x;
    const yBefore = state.player.y;
    state = await withDynamicTouchDrag(page, state, "move", { x: 0.72, y: 0 }, async () => {
      await page.evaluate(() => window.advanceTime(500));
      return await readState(page);
    });
    const displacement = Math.hypot(state.player.x - xBefore, state.player.y - yBefore);
    assert.ok(displacement > 2, `VIP terrain must accept real virtual-stick movement: ${JSON.stringify({ displacement, xBefore, yBefore, xAfter: state.player.x, yAfter: state.player.y, moveX: state.input.move_x, moveY: state.input.move_y, pointer: state.input.virtual_controls.move.pointer, terrain: state.vip.current_terrain_id })}`);
    assert.equal(state.vip.animation.hero.action, "walk");

    state = await withDynamicTouchDrag(page, state, "attack", { x: 0.72, y: 0 }, async () => {
      await page.evaluate(() => window.advanceTime(180));
      return await readState(page);
    });
    assert.equal(state.input.attack_held, true, `attack stick must remain held during the action: ${JSON.stringify({ pointer: state.input.virtual_controls.attack.pointer, movePointer: state.input.virtual_controls.move.pointer, attackHeld: state.input.attack_held })}`);
    assert.equal(state.vip.animation.hero.action, "attack");
    assert.ok(state.player.attack_cooldown > 0 || state.projectiles.length > 0);

    state = await withDynamicTouchDrag(page, state, "attack", { x: 0, y: -0.72 }, async () => {
      await page.evaluate(() => window.advanceTime(180));
      return await readState(page);
    });
    const aimedUpJoints = state.vip.animation.hero.joints;
    assert.ok(aimedUpJoints.head.y < Math.max(aimedUpJoints.left_foot.y, aimedUpJoints.right_foot.y) - 12, "aiming upward must move the weapon without overturning the character body");

    const dualStartX = state.player.x;
    state = await withDualDynamicControls(page, state, async () => {
      await page.evaluate(() => window.advanceTime(240));
      return await readState(page);
    });
    assert.equal(state.input.attack_held, true, "two thumbs must keep attack active while movement remains independent");
    assert.ok(Math.abs(state.player.x - dualStartX) > 1, "two-thumb input must move the hero while aiming independently");
  },
);

for (const viewport of [
  { width: 568, height: 320 },
  { width: 667, height: 375 },
]) {
  await runCase(
    `vip-compact-controls-${viewport.width}x${viewport.height}`,
    {
      viewport,
      touch: true,
      mobile: true,
      deviceScaleFactor: 2,
      locale: "zh-TW",
      params: { vip_scene: "combat", touch: "1", lang: "zh_TW" },
    },
    async (page) => {
      let state = await waitForState(page, (value) => value.mode === "playing" && value.edition === "vip" && value.input?.virtual_controls?.layout_version === 4);
      const controls = state.input.virtual_controls;
      const scale = state.input.touch_ui_coordinate_scale;
      const clear = controls.gameplay_clear;
      assert.equal(controls.utility_layout, "collapsible_dual_side_rails");
      assert.equal(controls.utility_drawer_open, false);
      assertDynamicJoystickContract(state, "move");
      assertDynamicJoystickContract(state, "attack");
      assert.ok(clear.width / scale >= 160);
      assert.equal(intersects(controls.move.activation_zone, clear), false);
      assert.equal(intersects(controls.attack.activation_zone, clear), false);
      assert.equal(intersects(controls.special, clear), false);
      const clearProbe = {
        x: clear.x + clear.width * 0.5 - scale,
        y: clear.y + clear.height * 0.72 - scale,
        width: scale * 2,
        height: scale * 2,
      };
      const held = await holdTouchLogical(page, state, clearProbe);
      assert.equal(held.input.virtual_controls.move.pointer, -1);
      assert.equal(held.input.virtual_controls.attack.pointer, -1);
      assert.equal(held.input.attack_held, false);
      await tapLogical(page, state, controls.utility_handles.left);
      state = await waitForState(page, (value) => value.input.virtual_controls.utility_drawer_open === true);
      assert.equal(Object.values(state.input.virtual_controls.utility).filter((item) => item.visible).length, 10);
      await tapLogical(page, state, state.input.virtual_controls.utility_handles.left);
      await waitForState(page, (value) => value.input.virtual_controls.utility_drawer_open === false);
    },
  );
}

for (const viewport of [
  { width: 844, height: 390 },
  { width: 568, height: 320 },
  { width: 667, height: 375 },
]) {
  await runCase(
    `touch-${viewport.width}x${viewport.height}-compact-controls`,
    { viewport, touch: true, mobile: true, deviceScaleFactor: 2, params: { soldier_vfx_scene: "combat", touch: "1", lang: "zh_TW" } },
    async (page) => {
      await waitForState(page, (state) => state.input.scheme === "touch" && state.input.virtual_controls.utility_layout === "collapsible_dual_side_rails");
      let state = await readState(page);
      const scale = state.input.touch_ui_coordinate_scale;
      const controls = state.input.virtual_controls;
      const utility = controls.utility;
      const handles = controls.utility_handles;
      const clear = controls.gameplay_clear;
      const logicalWidth = state.input.logical_viewport_width;
      const logicalHeight = state.input.logical_viewport_height;
      assert.equal(Object.keys(utility).length, 10);
      assertDynamicJoystickContract(state, "move");
      assertDynamicJoystickContract(state, "attack");
      assert.equal(controls.utility_drawer_open, false);
      assert.equal(controls.move.visible, true);
      assert.equal(controls.attack.visible, true);
      assert.equal(controls.move.visual_visible, false);
      assert.equal(controls.attack.visual_visible, false);
      assert.equal(controls.special.visible, true);
      assert.ok(clear.width / scale >= 160, "phone layout must reserve at least 160 CSS px through the center");
      assert.ok(clear.width / logicalWidth >= 0.34, "phone layout must keep at least 34% of the width button-free");
      const left = ["upgrades", "recruit", "command", "skills", "map"];
      const right = ["guide", "notices", "cheat", "fullscreen", "pause"];
      for (const action of [...left, ...right]) {
        const rect = utility[action];
        assert.equal(rect.visible, false, `${action} should stay collapsed during combat`);
        assert.ok(rect.width / scale >= 43.9 && rect.height / scale >= 43.9, `${action} is below 44 CSS px`);
      }
      const collapsedRects = [controls.special, handles.left, handles.right];
      let occupiedCssArea = 0;
      for (let index = 0; index < collapsedRects.length; index += 1) {
        const rect = collapsedRects[index];
        assert.ok(rect.width / scale >= 43.9 && rect.height / scale >= 43.9, "collapsed control is below 44 CSS px");
        assert.ok(rect.x >= 0 && rect.y >= 0 && rect.x + rect.width <= logicalWidth + 0.5 && rect.y + rect.height <= logicalHeight + 0.5, "collapsed control must remain inside the phone viewport");
        assert.equal(intersects(rect, clear), false, "collapsed controls must not enter the center gameplay corridor");
        occupiedCssArea += (rect.width / scale) * (rect.height / scale);
        for (let previous = 0; previous < index; previous += 1) {
          assert.equal(intersects(rect, collapsedRects[previous]), false, "collapsed controls must not overlap");
        }
      }
      assert.ok(occupiedCssArea / (viewport.width * viewport.height) <= 0.24, "collapsed controls must cover no more than 24% of the phone screen");
      assert.ok(handles.left.x / scale >= 5.9 && (handles.right.x + handles.right.width) / scale <= viewport.width - 5.9, "edge handles need a safe inset");
      assert.ok(controls.special.x / scale > viewport.width * 0.68, "special skill must stay in the right-hand control cluster");
      for (const activationZone of [controls.move.activation_zone, controls.attack.activation_zone]) {
        assert.ok(activationZone.width / scale >= 43.9 && activationZone.height / scale >= 43.9, "dynamic stick activation zone must remain comfortably touchable");
        assert.ok(activationZone.x >= 0 && activationZone.y >= 0 && activationZone.x + activationZone.width <= logicalWidth + 0.5 && activationZone.y + activationZone.height <= logicalHeight + 0.5, "stick activation zone must stay inside the phone viewport");
        assert.equal(intersects(activationZone, clear), false, "stick activation zones must not enter the center gameplay corridor");
      }
      const clearProbe = {
        x: clear.x + clear.width * 0.5 - scale,
        y: clear.y + clear.height * 0.72 - scale,
        width: scale * 2,
        height: scale * 2,
      };
      const clearHeldState = await holdTouchLogical(page, state, clearProbe);
      assert.equal(clearHeldState.input.virtual_controls.move.pointer, -1, "holding the center corridor must not start movement");
      assert.equal(clearHeldState.input.virtual_controls.attack.pointer, -1, "holding the center corridor must not start aiming");
      assert.equal(clearHeldState.input.attack_held, false, "holding the center corridor must not attack");

      const playerBefore = { x: state.player.x, y: state.player.y };
      state = await withDynamicTouchDrag(page, state, "move", { x: 0.72, y: 0 }, async () => {
        if (viewport.width === 568) {
          await assertLongHeldDynamicTouchSurvivesMouseMotion(
            page,
            "move",
            "touch-568x320-dynamic-stick-active.png",
          );
        }
        await page.evaluate(() => window.advanceTime(240));
        return await readState(page);
      });
      assert.ok(Math.hypot(state.input.move_x || 0, state.input.move_y || 0) >= 0.35, "dynamic move stick must report a directional vector while dragged");
      assert.ok(Math.hypot(state.player.x - playerBefore.x, state.player.y - playerBefore.y) > 0.5, "dynamic move stick must move the player at every supported phone size");

      await tapLogical(page, state, handles.left);
      state = await waitForState(page, (value) => value.input.virtual_controls.utility_drawer_open === true);
      const openControls = state.input.virtual_controls;
      if (viewport.width === 568) {
        await page.screenshot({ path: path.join(artifactDir, "touch-568x320-utility-drawer-open.png") });
      }
      assert.equal(openControls.move.visible, false);
      assert.equal(openControls.attack.visible, false);
      assert.equal(openControls.special.visible, false);
      assert.equal(openControls.move.pointer, -1);
      assert.equal(openControls.attack.pointer, -1);
      assert.equal(openControls.utility_handles.left.mode, "close");
      assert.equal(openControls.utility_handles.right.mode, "close");
      const leftRailEnd = Math.max(...left.map((action) => openControls.utility[action].x + openControls.utility[action].width));
      const rightRailStart = Math.min(...right.map((action) => openControls.utility[action].x));
      assert.ok(openControls.utility_handles.left.x >= leftRailEnd + 5.9 * scale, "left close handle must sit beside the left rail");
      assert.ok(openControls.utility_handles.left.x + openControls.utility_handles.left.width <= clear.x, "left close handle must remain left of the gameplay corridor");
      assert.ok(openControls.utility_handles.right.x + openControls.utility_handles.right.width <= rightRailStart - 5.9 * scale, "right close handle must sit beside the right rail");
      assert.ok(openControls.utility_handles.right.x >= clear.x + clear.width, "right close handle must remain right of the gameplay corridor");
      const openRects = [
        ...[...left, ...right].map((action) => openControls.utility[action]),
        openControls.utility_handles.left,
        openControls.utility_handles.right,
      ];
      for (let index = 0; index < openRects.length; index += 1) {
        const rect = openRects[index];
        assert.equal(rect.visible, true);
        assert.ok(rect.x >= 0 && rect.y >= 0 && rect.x + rect.width <= logicalWidth + 0.5 && rect.y + rect.height <= logicalHeight + 0.5, "open utility must remain inside the phone viewport");
        assert.equal(intersects(rect, clear), false, "open utilities must stay outside the center gameplay corridor");
        for (let previous = 0; previous < index; previous += 1) {
          assert.equal(intersects(rect, openRects[previous]), false, "open utilities must not overlap");
        }
      }
      await tapLogical(page, state, openControls.utility.upgrades);
      const panelState = await waitForState(page, (value) => value.panel === "soldier_upgrades");
      assert.equal(panelState.input.virtual_controls.panel_close.visible, true);
      await tapLogical(page, panelState, panelState.input.virtual_controls.panel_close);
      state = await waitForState(page, (value) => value.panel === "" && value.input.virtual_controls.utility_drawer_open === false);
      await tapLogical(page, state, state.input.virtual_controls.utility_handles.right);
      state = await waitForState(page, (value) => value.input.virtual_controls.utility_drawer_open === true);
      await tapLogical(page, state, state.input.virtual_controls.utility_handles.right);
      await waitForState(page, (value) => value.input.virtual_controls.utility_drawer_open === false);
      if (viewport.width === 568) {
        await page.evaluate(() => window.advanceTime(6500));
        await page.screenshot({ path: path.join(artifactDir, "touch-568x320-design-qa.png") });
      }
    },
  );
}

await runCase(
  "touch-main-portrait-rotation-modal",
  {
    viewport: { width: 568, height: 320 },
    touch: true,
    mobile: true,
    deviceScaleFactor: 2,
    params: { soldier_vfx_scene: "combat", touch: "1", lang: "zh_TW" },
  },
  async (page) => {
    let state = await waitForState(page, (value) => (
      value.mode === "playing" &&
      value.input?.scheme === "touch" &&
      value.input?.needs_landscape_rotation === false
    ));
    assertDynamicJoystickContract(state, "move");
    assertDynamicJoystickContract(state, "attack");

    state = await withDualDynamicControls(page, state, async () => {
      const held = await readState(page);
      assert.ok(held.input.virtual_controls.move.pointer >= 0);
      assert.ok(held.input.virtual_controls.attack.pointer >= 0);
      assert.ok(Math.hypot(held.input.move_x, held.input.move_y) >= 0.35);
      assert.ok(Math.hypot(held.input.aim_x, held.input.aim_y) >= 0.35);
      assert.equal(held.input.attack_held, true);

      await page.setViewportSize({ width: 320, height: 568 });
      let portrait = await waitForState(page, (value) => (
        value.mode === "playing" &&
        value.input?.needs_landscape_rotation === true &&
        value.input?.logical_viewport_height > value.input?.logical_viewport_width &&
        value.input?.virtual_controls?.move?.pointer === -1 &&
        value.input?.virtual_controls?.attack?.pointer === -1
      ));
      const portraitMove = portrait.input.virtual_controls.move;
      const portraitAttack = portrait.input.virtual_controls.attack;
      assert.equal(portraitMove.active, false, "portrait rotation must clear the main move owner");
      assert.equal(portraitAttack.active, false, "portrait rotation must clear the main aim owner");
      assert.equal(portraitMove.visual_visible, false, "portrait rotation must hide the main move stick");
      assert.equal(portraitAttack.visual_visible, false, "portrait rotation must hide the main aim stick");
      const portraitMoveVector = controlVector(portraitMove);
      const portraitAttackVector = controlVector(portraitAttack);
      assert.ok(Math.hypot(portraitMoveVector.x, portraitMoveVector.y) <= 0.05, "portrait rotation must clear the main move vector");
      assert.ok(Math.hypot(portraitAttackVector.x, portraitAttackVector.y) <= 0.05, "portrait rotation must clear the main aim vector");
      assert.equal(portrait.input.attack_held, false, "portrait rotation must release main attack");

      const pausedTime = portrait.time;
      await page.evaluate(() => window.advanceTime(1200));
      portrait = await readState(page);
      assert.equal(portrait.time, pausedTime, "main portrait rotation overlay must pause the hidden battle");
      await page.waitForTimeout(80);
      await page.screenshot({ path: path.join(artifactDir, "touch-main-portrait-rotation-modal-active.png") });

      await page.setViewportSize({ width: 568, height: 320 });
      const landscape = await waitForState(page, (value) => (
        value.mode === "playing" &&
        value.input?.needs_landscape_rotation === false &&
        value.input?.logical_viewport_width > value.input?.logical_viewport_height
      ));
      assert.equal(landscape.input.virtual_controls.move.pointer, -1);
      assert.equal(landscape.input.virtual_controls.attack.pointer, -1);
      assert.ok(Math.hypot(landscape.input.move_x, landscape.input.move_y) <= 0.05);
      assert.ok(Math.hypot(landscape.input.aim_x, landscape.input.aim_y) <= 0.05);
      assert.equal(landscape.input.attack_held, false);
      const resumedAt = landscape.time;
      await page.evaluate(() => window.advanceTime(240));
      const resumed = await readState(page);
      assert.ok(resumed.time > resumedAt, "main battle must resume after returning to landscape");
      assert.ok(Math.hypot(resumed.input.move_x, resumed.input.move_y) <= 0.05, "main move input must not relatch after rotation");
      assert.ok(Math.hypot(resumed.input.aim_x, resumed.input.aim_y) <= 0.05, "main aim input must not relatch after rotation");
      assert.equal(resumed.input.attack_held, false, "main attack must not relatch after rotation");
      return resumed;
    });
  },
);

await runCase(
  "touch-568x320-material-panel-gallery",
  {
    viewport: { width: 568, height: 320 },
    touch: true,
    mobile: true,
    deviceScaleFactor: 2,
    params: { soldier_vfx_scene: "combat", touch: "1", lang: "zh_TW" },
  },
  async (page) => {
    let state = await waitForState(page, (value) => (
      value.mode === "playing" &&
      value.input?.scheme === "touch" &&
      value.input?.virtual_controls?.utility_layout === "collapsible_dual_side_rails"
    ));
    assertMainUiMaterialContract(state);

    const openPanel = async (action, expectedPanel) => {
      state = await readState(page);
      if (!state.input.virtual_controls.utility_drawer_open) {
        await tapLogical(page, state, state.input.virtual_controls.utility_handles.left);
        state = await waitForState(page, (value) => value.input?.virtual_controls?.utility_drawer_open === true);
      }
      await tapLogical(page, state, state.input.virtual_controls.utility[action]);
      state = await waitForState(page, (value) => value.panel === expectedPanel);
      assert.equal(state.input.virtual_controls.panel_close.visible, true);
      assert.equal(state.ui.active_surface, `panel.${expectedPanel}`);
      if (expectedPanel === "soldier_upgrades") {
        assert.ok(state.soldier_upgrades.selected_type, "troop upgrade gallery must expose the selected troop controls");
        assert.ok(["base", "special"].includes(state.soldier_upgrades.category));
      }
      if (expectedPanel === "command") {
        assert.equal(state.input.virtual_controls.command_buttons.length, 6, "command gallery must expose all six touch commands");
      }
      await page.waitForTimeout(80);
      await page.screenshot({ path: path.join(artifactDir, `touch-material-panel-${expectedPanel}.png`) });
      await tapLogical(page, state, state.input.virtual_controls.panel_close);
      state = await waitForState(page, (value) => value.mode === "playing" && value.panel === "");
    };

    for (const [action, panel] of [
      ["skills", "skills"],
      ["upgrades", "soldier_upgrades"],
      ["command", "command"],
      ["map", "map"],
    ]) {
      await openPanel(action, panel);
    }

    await tapLogical(page, state, state.input.virtual_controls.utility_handles.right);
    state = await waitForState(page, (value) => value.input?.virtual_controls?.utility_drawer_open === true);
    await tapLogical(page, state, state.input.virtual_controls.utility.pause);
    state = await waitForState(page, (value) => value.mode === "paused" && value.input?.virtual_controls?.pause_actions?.length > 0);
    const resume = state.input.virtual_controls.pause_actions.find((item) => item.action === "resume");
    assert.ok(resume, "touch pause menu must expose a resume target");
    assert.equal(state.ui.active_surface, "paused");
    assert.ok(state.input.virtual_controls.pause_language.width > 0);
    assert.deepEqual(Object.keys(state.input.virtual_controls.pause_volume).sort(), ["down", "mute", "up"]);
    await page.waitForTimeout(80);
    await page.screenshot({ path: path.join(artifactDir, "touch-material-panel-pause.png") });
    await tapLogical(page, state, resume);
    state = await waitForState(page, (value) => value.mode === "playing" && value.panel === "");

    await tapLogical(page, state, state.input.virtual_controls.utility_handles.right);
    state = await waitForState(page, (value) => value.input?.virtual_controls?.utility_drawer_open === true);
    await tapLogical(page, state, state.input.virtual_controls.utility.cheat);
    state = await waitForState(page, (value) => value.input?.cheat_active === true);
    assert.ok(state.ui.textured_regions.includes("panels.cheat"));
    await page.waitForTimeout(80);
    await page.screenshot({ path: path.join(artifactDir, "touch-material-panel-cheat.png") });
    await page.keyboard.press("Escape");
    await waitForState(page, (value) => value.input?.cheat_active === false);

    await page.evaluate(() => window.force_recruit_showcase_for_test(true, "zh_TW"));
    state = await waitForState(page, (value) => value.mode === "playing" && value.panel === "recruit" && value.input?.scheme === "touch");
    assertMainUiMaterialContract(state);
    assert.equal(state.input.virtual_controls.panel_close.visible, true);
    assert.equal(state.ui.active_surface, "panel.recruit");
    assert.ok(state.input.virtual_controls.recruit_buy.length > 0, "recruit gallery must expose touch purchase controls");
    await page.waitForTimeout(80);
    await page.screenshot({ path: path.join(artifactDir, "touch-material-panel-recruit.png") });
    await tapLogical(page, state, state.input.virtual_controls.panel_close);
    await waitForState(page, (value) => value.mode === "playing" && value.panel === "");
  },
);

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
      let state = await waitForState(page, (value) => value.mode === "arena" && value.arena?.phase === phase);
      if (phase === "types") {
        assert.equal(
          state.arena.layout.compact_touch_landscape,
          true,
          `568x320 arena must enter compact layout: ${JSON.stringify({ viewportCss: state.arena.layout.viewport_css, logicalWidth: state.input.logical_viewport_width, logicalHeight: state.input.logical_viewport_height, scale: state.input.touch_ui_coordinate_scale })}`,
        );
      }
      assertMainUiMaterialContract(state);
      assertArenaUiMaterialContract(state);
      assert.equal(state.arena.no_player, true);
      assert.deepEqual(state.arena.selection_flow, ["types", "counts", "upgrades", "battle"]);
      const scale = assertArenaSetupTouchChrome(state, phase);
      if (phase === "types") {
        const firstLayout = state.arena.layout.type_layout;
        const firstPageIds = [...firstLayout.visible_ids];
        assert.equal(state.arena.layout.compact_touch_landscape, true);
        assert.equal(firstLayout.columns, 2);
        assert.equal(firstLayout.rows, 4);
        assert.equal(firstLayout.catalog_size, 16);
        assert.equal(firstLayout.page_count, 2);
        assert.equal(firstLayout.page_size, 8);
        assert.equal(firstLayout.page, 0);
        assert.equal(firstPageIds.length, 8);
        assert.deepEqual(Object.keys(state.arena.layout.type_buttons).sort(), [...firstPageIds].sort());
        for (const [typeId, rect] of Object.entries(state.arena.layout.type_buttons)) {
          assertArenaTouchTarget(rect, scale, `types page 1 ${typeId}`);
        }

        await tapLogical(page, state, state.arena.layout.page_next);
        state = await waitForState(page, (value) => value.arena?.phase === "types" && value.arena?.layout?.type_layout?.page === 1);
        const secondLayout = state.arena.layout.type_layout;
        const secondPageIds = [...secondLayout.visible_ids];
        assert.equal(secondPageIds.length, 8);
        assert.deepEqual(Object.keys(state.arena.layout.type_buttons).sort(), [...secondPageIds].sort());
        assert.equal(firstPageIds.some((typeId) => secondPageIds.includes(typeId)), false, "type pages must not repeat soldiers");
        assert.equal(new Set([...firstPageIds, ...secondPageIds]).size, firstLayout.catalog_size, "both pages must expose the full 16-soldier catalog");
        for (const [typeId, rect] of Object.entries(state.arena.layout.type_buttons)) {
          assertArenaTouchTarget(rect, arenaTouchScale(state), `types page 2 ${typeId}`);
        }

        await tapLogical(page, state, state.arena.layout.page_prev);
        state = await waitForState(page, (value) => value.arena?.layout?.type_layout?.page === 0);
        assert.deepEqual(state.arena.layout.type_layout.visible_ids, firstPageIds, "previous-page target must restore the original eight soldiers");
      } else if (phase === "counts") {
        for (const [typeId, controls] of Object.entries(state.arena.layout.count_controls)) {
          assertArenaTouchTarget(controls.minus, scale, `counts ${typeId} minus`);
          assertArenaTouchTarget(controls.plus, scale, `counts ${typeId} plus`);
        }
      } else {
        for (const key of ["type_prev", "type_next", "base", "special"]) {
          assertArenaTouchTarget(state.arena.layout.upgrade_toolbar[key], scale, `upgrades toolbar ${key}`);
        }
        for (const [upgradeId, controls] of Object.entries(state.arena.layout.upgrade_controls)) {
          assertArenaTouchTarget(controls.minus, scale, `upgrades ${upgradeId} minus`);
          assertArenaTouchTarget(controls.plus, scale, `upgrades ${upgradeId} plus`);
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
    assertMainUiMaterialContract(state);
    assertArenaUiMaterialContract(state);
    assertCampaignArenaVisuals(state);
    assert.equal(state.arena.units.some((unit) => unit.target_kind === "hero"), false);
    assert.ok(state.arena.units.some((unit) => unit.specials.includes(selectedUpgrade.id)), "upgraded soldier should carry the selected special into battle");
    state = await waitForAdvancedState(page, (value) => value.arena.active_vfx_ids.includes(selectedUpgrade.id) || value.arena.phase === "result");
    assert.equal(state.arena.units.some((unit) => unit.target_kind === "hero"), false);
  },
);

await runCase(
  "arena-result-actions-touch-568x320",
  {
    viewport: { width: 568, height: 320 },
    touch: true,
    params: { arena_scene: "battle", arena_mode: "spectator", touch: "1", lang: "zh_TW" },
  },
  async (page) => {
    let state = await waitForState(page, (value) => value.mode === "arena" && value.arena?.phase === "battle");
    let scale = arenaTouchScale(state);
    for (const [action, rect] of Object.entries(state.arena.layout.battle_controls)) {
      assertArenaTouchTarget(rect, scale, `arena battle top-bar ${action}`);
    }

    state = await waitForAdvancedState(page, (value) => value.arena?.phase === "result", 1000, 30000);
    assert.ok(state.arena.winner, "completed arena battle must expose its winner");
    scale = arenaTouchScale(state);
    const resultActions = state.arena.layout.result_actions;
    assert.deepEqual(Object.keys(resultActions).sort(), ["leave", "rematch"]);
    for (const [action, rect] of Object.entries(resultActions)) {
      assertArenaTouchTarget(rect, scale, `arena result ${action}`);
      const panel = state.arena.layout.result_panel;
      assert.ok(
        rect.x >= panel.x && rect.y >= panel.y &&
        rect.x + rect.width <= panel.x + panel.width &&
        rect.y + rect.height <= panel.y + panel.height,
        `arena result ${action} must remain inside the result panel`,
      );
    }
    assert.equal(intersects(resultActions.rematch, resultActions.leave), false, "arena result actions must not overlap");
    for (const [action, rect] of Object.entries(state.arena.layout.battle_controls)) {
      assertArenaTouchTarget(rect, scale, `arena result top-bar ${action}`);
    }
    await page.waitForTimeout(80);
    await page.screenshot({ path: path.join(artifactDir, "arena-result-actions-touch-568x320-active.png") });
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
    let state = await waitForState(page, (value) => value.mode === "arena" && value.arena?.phase === "battle" && value.arena?.visuals?.rendered_unit_count > 0 && value.arena?.visuals?.hero_rendered === true);
    assert.equal(state.language, "en");
    assert.equal(state.arena.no_player, false);
    assert.ok(state.arena.hero && state.arena.hero.hp > 0);
    assert.equal(state.input.scheme, "touch");
    assertMainUiMaterialContract(state);
    assertArenaUiMaterialContract(state);
    assert.equal(state.arena.layout.controls_visible, true);
    assertDynamicJoystickContract(state, "arena_move");
    assertDynamicJoystickContract(state, "arena_aim");
    assertCampaignArenaVisuals(state, { expectHero: true });
    const heroBefore = { x: state.arena.hero.x, y: state.arena.hero.y };
    state = await withDynamicTouchDrag(page, state, "arena_move", { x: 0.72, y: 0 }, async () => {
      await page.evaluate(() => window.advanceTime(320));
      return await readState(page);
    });
    assert.ok(Math.hypot(state.arena.hero.x - heroBefore.x, state.arena.hero.y - heroBefore.y) > 0.5, "arena dynamic move stick must move the challenge hero");
    assert.ok(Math.hypot(controlVector(state.arena.layout.move_stick).x, controlVector(state.arena.layout.move_stick).y) >= 0.35);

    // Movement and aim are independent contracts. Reset the disposable QA
    // battle between them so a fast AI round cannot finish while Chromium is
    // capturing the active-stick evidence and turn this into a timing flake.
    await page.evaluate(() => window.force_arena_showcase_for_test("battle", "challenge", "en", true));
    state = await waitForState(page, (value) => (
      value.mode === "arena" && value.arena?.phase === "battle" && value.arena?.hero?.hp > 0 &&
      value.arena?.visuals?.rendered_unit_count > 0 && value.arena?.visuals?.hero_rendered === true
    ));

    state = await withDynamicTouchDrag(page, state, "arena_aim", { x: 0, y: -0.72 }, async () => {
      await page.waitForTimeout(80);
      await page.screenshot({ path: path.join(artifactDir, "arena-challenge-dynamic-stick-active.png") });
      let heldState = await assertLongHeldDynamicTouchSurvivesMouseMotion(
        page,
        "arena_aim",
        "arena-challenge-long-hold-owner.png",
      );
      if (heldState.arena.projectile_count <= 0 && heldState.arena.effect_count <= 0) {
        heldState = await waitForAdvancedState(page, (value) => value.arena.projectile_count > 0 || value.arena.effect_count > 0, 120, 3600);
      }
      return heldState;
    });
    assert.equal(state.arena.no_player, false);
    assert.ok(Math.hypot(controlVector(state.arena.layout.aim_stick).x, controlVector(state.arena.layout.aim_stick).y) >= 0.35);
    assert.ok(state.arena.projectile_count > 0 || state.arena.effect_count > 0, "arena dynamic aim stick must fire while held");
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
    assertMainUiMaterialContract(state);
    assertArenaUiMaterialContract(state);
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

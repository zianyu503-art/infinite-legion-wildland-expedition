class_name ArenaView
extends Control

## Arena presentation and input layer.
##
## The arena owns a disposable ArenaController instance.  It never reads or
## writes the campaign wallet, roster, save data, or permanent research.

signal close_requested
signal language_toggle_requested
signal sound_requested(event_name: String, volume: float, pitch: float)

const GameConfig = preload("res://scripts/game_config.gd")
const ArenaControllerScript = preload("res://scripts/arena_controller.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const CampaignVisualRenderer = preload("res://scripts/campaign_visual_renderer.gd")
const SoldierUpgradeCatalog = preload("res://scripts/soldier_upgrade_catalog.gd")
const SoldierUpgradeVfxCatalog = preload("res://scripts/soldier_upgrade_vfx_catalog.gd")
const UI_FONT_PATH := "res://assets/fonts/NotoSansTC-Regular.otf"

const BLUE := Color("3B82F6")
const BLUE_DARK := Color("12365A")
const RED := Color("D94C42")
const RED_DARK := Color("4A1714")
const GOLD := Color("FFD166")
const INK := Color("111C24")
const PANEL := Color(0.025, 0.045, 0.060, 0.97)
const PANEL_EDGE := Color(0.30, 0.48, 0.62, 0.92)
const TEXT := Color("EAF6FF")
const MUTED := Color("9CB4C2")
const MIN_BATTLE_CAMERA_ZOOM := 0.20
const CAMPAIGN_MAP_DRAW_MARGIN := 180.0
const CAMPAIGN_COVERAGE_EPSILON := 0.5

var controller: ArenaController
var language := "zh_TW"
var ui_scale := 1.0
var touch_mode := false
var hero_class := "archer"
var count_pages := {"blue": 0, "red": 0}
var game_time := 0.0
var camera_position := Vector2.ZERO
var camera_zoom := 1.0
var campaign_world_seed := 20260731
var campaign_map_anchor := Vector2(480.0, 480.0)
var campaign_world_generator: WorldGenerator
var campaign_chunks: Dictionary = {}
var campaign_map_summary: Dictionary = {}
var _last_draw_trace: Dictionary = {}

var move_pointer := -1
var aim_pointer := -1
var move_vector := Vector2.ZERO
var aim_vector := Vector2.RIGHT
var mouse_attack_held := false
var touch_attack_held := false
var _font: Font
var _sound_cooldown := 0.0
var _last_winner := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	var loaded_font: Resource = load(UI_FONT_PATH)
	_font = loaded_font as Font if loaded_font is Font else ThemeDB.fallback_font
	configure_campaign_world(campaign_world_seed, campaign_map_anchor)
	visible = false


func configure_campaign_world(seed: int, anchor: Vector2) -> void:
	campaign_world_seed = seed
	campaign_map_anchor = anchor
	campaign_world_generator = WorldGenerator.new(campaign_world_seed)
	campaign_chunks.clear()
	campaign_map_summary.clear()
	_last_draw_trace.clear()


func open(requested_language: String, requested_touch_mode: bool, requested_scale: float = 1.0) -> void:
	if controller == null:
		controller = ArenaControllerScript.new()
	else:
		controller.reset_setup()
	language = "en" if requested_language == "en" else "zh_TW"
	touch_mode = requested_touch_mode
	ui_scale = maxf(1.0, requested_scale)
	hero_class = "archer"
	count_pages = {"blue": 0, "red": 0}
	game_time = 0.0
	camera_position = Vector2.ZERO
	camera_zoom = 1.0
	_reset_transient_input()
	_sound_cooldown = 0.0
	_last_winner = ""
	campaign_chunks.clear()
	campaign_map_summary.clear()
	_last_draw_trace.clear()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	_reset_transient_input()


func set_presentation(requested_language: String, requested_touch_mode: bool, requested_scale: float) -> void:
	language = "en" if requested_language == "en" else "zh_TW"
	touch_mode = requested_touch_mode
	ui_scale = maxf(1.0, requested_scale)
	queue_redraw()


func advance(delta: float) -> void:
	if not visible or controller == null:
		return
	if _portrait_rotation_required():
		# The rotation notice is a real modal state: do not let a hidden battle
		# advance or retain virtual-stick input behind it.
		_reset_transient_input()
		queue_redraw()
		return
	game_time += maxf(0.0, delta)
	_sound_cooldown = maxf(0.0, _sound_cooldown - delta)
	if controller.phase == "battle":
		var projectiles_before := controller.projectiles.size()
		var effects_before := controller.effects.size()
		var input := {}
		if controller.mode == "challenge":
			var keyboard_move := Vector2(
				float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
				float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
			)
			if keyboard_move.length_squared() > 1.0:
				keyboard_move = keyboard_move.normalized()
			input = {
				"move": move_vector if touch_mode else keyboard_move,
				"aim": aim_vector,
				"attack": touch_attack_held or mouse_attack_held or Input.is_key_pressed(KEY_SPACE),
			}
		controller.update(delta, input)
		if _sound_cooldown <= 0.0 and controller.projectiles.size() > projectiles_before:
			var newest_projectile: Dictionary = controller.projectiles.back()
			var projectile_kind := str(newest_projectile.get("kind", ""))
			var source_kind := str(newest_projectile.get("source_kind", ""))
			var cue := "magic" if projectile_kind in ["mage_orb", "magic"] else ("shoot_arrow" if projectile_kind == "arrow" else ("cannon" if source_kind in ["turret", "cannon"] else "rifle"))
			sound_requested.emit(cue, 0.22, 1.0)
			_sound_cooldown = 0.08
		elif _sound_cooldown <= 0.0 and controller.effects.size() > effects_before:
			var newest_effect: Dictionary = controller.effects.back()
			var event_kind := str(newest_effect.get("event_kind", newest_effect.get("kind", "")))
			var cue := "heal" if event_kind in ["heal", "repair", "revive", "protect"] else ("explosion" if event_kind in ["impact", "blast", "meteor", "delayed_area"] else "magic")
			sound_requested.emit(cue, 0.18, 1.0)
			_sound_cooldown = 0.10
		if not controller.winner.is_empty() and controller.winner != _last_winner:
			sound_requested.emit("level_up", 0.55, 0.92 if controller.winner == "red" else 1.08)
			_last_winner = controller.winner
		_update_battle_camera()
	queue_redraw()


func handle_input(event: InputEvent) -> bool:
	if not visible or controller == null:
		return false
	if _portrait_rotation_required():
		_reset_transient_input()
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE:
				close_requested.emit()
				return true
			if key_event.keycode == KEY_L:
				language_toggle_requested.emit()
				return true
			if key_event.keycode == KEY_R and controller.phase in ["battle", "result"]:
				if controller.restart_battle():
					_prepare_campaign_battlefield()
				_last_winner = ""
				sound_requested.emit("ui", 0.45, 1.0)
				return true
		return controller.phase == "battle"
	if event is InputEventScreenTouch:
		touch_mode = true
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			if touch.index == move_pointer:
				move_pointer = -1
				move_vector = Vector2.ZERO
			if touch.index == aim_pointer:
				aim_pointer = -1
				touch_attack_held = false
			return true
		if _activate_at(touch.position):
			sound_requested.emit("ui", 0.38, 1.0)
			return true
		if controller.phase == "battle" and controller.mode == "challenge":
			if touch.position.x < size.x * 0.48 and touch.position.y > size.y * 0.42 and move_pointer < 0:
				move_pointer = touch.index
				_update_touch_move(touch.position)
			else:
				aim_pointer = touch.index
				_update_touch_aim(touch.position)
			return true
		return true
	if event is InputEventScreenDrag:
		touch_mode = true
		var drag := event as InputEventScreenDrag
		if drag.index == move_pointer:
			_update_touch_move(drag.position)
		elif drag.index == aim_pointer:
			_update_touch_aim(drag.position)
		return true
	if event is InputEventMouseMotion:
		if controller.phase == "battle" and controller.mode == "challenge" and not controller.hero.is_empty():
			var mouse_world := _view_to_world((event as InputEventMouseMotion).position)
			var delta_to_mouse := mouse_world - Vector2(controller.hero.get("pos", Vector2.ZERO))
			if delta_to_mouse.length_squared() > 0.01:
				aim_vector = delta_to_mouse.normalized()
		return controller.phase == "battle"
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed and _activate_at(mouse.position):
				sound_requested.emit("ui", 0.38, 1.0)
				mouse_attack_held = false
				return true
			if controller.phase == "battle" and controller.mode == "challenge":
				mouse_attack_held = mouse.pressed
				var mouse_world := _view_to_world(mouse.position)
				var delta_to_mouse := mouse_world - Vector2(controller.hero.get("pos", Vector2.ZERO))
				if delta_to_mouse.length_squared() > 0.01:
					aim_vector = delta_to_mouse.normalized()
			return true
		if mouse.button_index == MOUSE_BUTTON_RIGHT and controller.phase == "battle" and controller.mode == "challenge":
			mouse_attack_held = mouse.pressed
			return true
	return false


func render_state() -> Dictionary:
	if controller == null:
		return {"active": false}
	var state := controller.render_state()
	state["active"] = visible
	state["hero_class"] = hero_class
	state["touch"] = touch_mode
	state["ui_scale"] = snappedf(ui_scale, 0.001)
	state["camera"] = {"x": snappedf(camera_position.x, 0.1), "y": snappedf(camera_position.y, 0.1), "zoom": snappedf(camera_zoom, 0.001)}
	state["selection_flow"] = ["types", "counts", "upgrades", "battle"]
	state["layout"] = _layout_state()
	state["visuals"] = visual_contract()
	return state


func visual_contract() -> Dictionary:
	var result := {
		"profile": CampaignVisualRenderer.PROFILE_ID,
		"soldier_renderer_id": CampaignVisualRenderer.SOLDIER_RENDERER_ID,
		"hero_renderer_id": CampaignVisualRenderer.HERO_RENDERER_ID,
		"map_renderer_id": CampaignVisualRenderer.MAP_RENDERER_ID,
		"map_source": "WorldGenerator",
		"map_style": "campaign_wildland",
		"world_seed": campaign_world_seed,
		"map_anchor": {"x": snappedf(campaign_map_anchor.x, 0.1), "y": snappedf(campaign_map_anchor.y, 0.1)},
		"chunk_keys": Array(campaign_map_summary.get("chunk_keys", [])).duplicate(),
		"biome_ids": Array(campaign_map_summary.get("biome_ids", [])).duplicate(),
		"decoration_count": int(campaign_map_summary.get("decoration_count", 0)),
		"obstacle_count": int(campaign_map_summary.get("obstacle_count", 0)),
		"blocking_tree_count": int(campaign_map_summary.get("blocking_tree_count", 0)),
		"rendered_unit_count": int(_last_draw_trace.get("rendered_unit_count", 0)),
		"rendered_unit_types": Array(_last_draw_trace.get("rendered_unit_types", [])).duplicate(),
		"rendered_chunk_keys": Array(_last_draw_trace.get("rendered_chunk_keys", [])).duplicate(),
		"rendered_biome_ids": Array(_last_draw_trace.get("rendered_biome_ids", [])).duplicate(),
		"rendered_decoration_count": int(_last_draw_trace.get("rendered_decoration_count", 0)),
		"rendered_obstacle_count": int(_last_draw_trace.get("rendered_obstacle_count", 0)),
		"hero_rendered": bool(_last_draw_trace.get("hero_rendered", false)),
		"coverage": campaign_coverage_contract(),
	}
	return result


func campaign_coverage_contract() -> Dictionary:
	var required_bounds: Rect2 = campaign_map_summary.get("coverage_required_bounds", Rect2())
	var generated_bounds: Rect2 = campaign_map_summary.get("coverage_generated_bounds", Rect2())
	var viewport: Vector2 = campaign_map_summary.get("coverage_viewport", Vector2.ZERO)
	return {
		"complete": bool(campaign_map_summary.get("coverage_complete", false)),
		"mode": str(campaign_map_summary.get("coverage_mode", "")),
		"minimum_camera_zoom": snappedf(float(campaign_map_summary.get("coverage_minimum_zoom", MIN_BATTLE_CAMERA_ZOOM)), 0.001),
		"viewport": {"width": snappedf(viewport.x, 0.1), "height": snappedf(viewport.y, 0.1)},
		"ui_scale": snappedf(float(campaign_map_summary.get("coverage_ui_scale", ui_scale)), 0.001),
		"draw_margin": CAMPAIGN_MAP_DRAW_MARGIN,
		"edge_probe_count": int(campaign_map_summary.get("coverage_edge_probe_count", 0)),
		"edge_probes_covered": int(campaign_map_summary.get("coverage_edge_probes_covered", 0)),
		"required_bounds": _rect_state(required_bounds),
		"generated_bounds": _rect_state(generated_bounds),
	}


func force_test_scene(scene: String, requested_mode: String = "spectator", requested_language: String = "zh_TW", requested_touch: bool = false) -> bool:
	open(requested_language, requested_touch, ui_scale)
	var arena_mode := "challenge" if requested_mode == "challenge" else "spectator"
	controller.choose_mode(arena_mode)
	if arena_mode == "challenge":
		controller.toggle_type("archer", "red")
		controller.toggle_type("heavy", "red")
	else:
		controller.toggle_type("archer", "blue")
		controller.toggle_type("healer", "blue")
		controller.toggle_type("swordsman", "red")
		controller.toggle_type("mage", "red")
	if scene == "types":
		return true
	if not controller.confirm_types():
		return false
	for team in ["blue", "red"]:
		for type_id in controller.selected_types_for(team):
			controller.adjust_count(str(type_id), 2, team)
	if scene == "counts":
		return true
	if not controller.confirm_counts():
		return false
	# A deterministic elemental loadout gives browser QA immediately visible
	# trails, impacts and persistent status effects without campaign money.
	for team in ["blue", "red"]:
		for type_id_value in controller.selected_types_for(team):
			var type_id := str(type_id_value)
			for ability_id_value in controller.upgrade_ids(team, type_id, "special").slice(0, 3):
				controller.adjust_upgrade(str(ability_id_value), 1, team, type_id)
	if scene == "upgrades":
		return true
	return _start_battle_with_campaign_map()


func _reset_transient_input() -> void:
	move_pointer = -1
	aim_pointer = -1
	move_vector = Vector2.ZERO
	aim_vector = Vector2.RIGHT
	mouse_attack_held = false
	touch_attack_held = false


func _portrait_rotation_required() -> bool:
	return touch_mode and size.y > size.x


func _update_touch_move(position: Vector2) -> void:
	var center := _move_center()
	var radius := 66.0 * ui_scale
	var offset := (position - center).limit_length(radius)
	move_vector = Vector2.ZERO if offset.length() < 10.0 * ui_scale else offset / radius


func _update_touch_aim(position: Vector2) -> void:
	var center := _aim_center()
	var radius := 66.0 * ui_scale
	var offset := (position - center).limit_length(radius)
	if offset.length() > 8.0 * ui_scale:
		aim_vector = offset.normalized()
	touch_attack_held = true


func _activate_at(position: Vector2) -> bool:
	if controller.phase in ["battle", "result"]:
		return _activate_battle_at(position)
	var common := _common_rects()
	if Rect2(common["exit"]).has_point(position):
		close_requested.emit()
		return true
	if controller.phase != "mode" and Rect2(common["back"]).has_point(position):
		match controller.phase:
			"types": controller.reset_setup()
			"counts": controller.phase = "types"
			"upgrades": controller.phase = "counts"
		controller.upgrade_page = 0
		return true
	if Rect2(common["language"]).has_point(position):
		language_toggle_requested.emit()
		return true
	match controller.phase:
		"mode":
			var mode_rects := _mode_rects()
			if Rect2(mode_rects["challenge"]).has_point(position):
				controller.choose_mode("challenge")
				return true
			if Rect2(mode_rects["spectator"]).has_point(position):
				controller.choose_mode("spectator")
				return true
		"types":
			if _activate_team_tabs(position):
				return true
			var type_rects := _type_rects()
			for type_id_value in type_rects.keys():
				var type_id := str(type_id_value)
				if Rect2(type_rects[type_id]).has_point(position):
					controller.toggle_type(type_id)
					return true
			if controller.mode == "challenge":
				for class_id in ["archer", "mage", "warrior"]:
					if _hero_class_rect(class_id).has_point(position):
						hero_class = class_id
						return true
			if _footer_primary_rect().has_point(position):
				return controller.confirm_types()
		"counts":
			if _activate_team_tabs(position):
				return true
			var count_rects := _count_rects()
			for type_id_value in count_rects.keys():
				var type_id := str(type_id_value)
				var row: Dictionary = count_rects[type_id]
				if Rect2(row["minus"]).has_point(position):
					controller.adjust_count(type_id, -1)
					return true
				if Rect2(row["plus"]).has_point(position):
					controller.adjust_count(type_id, 1)
					return true
			if _page_rect("prev").has_point(position):
				count_pages[controller.active_team] = maxi(0, int(count_pages[controller.active_team]) - 1)
				return true
			if _page_rect("next").has_point(position):
				count_pages[controller.active_team] = mini(_count_page_count() - 1, int(count_pages[controller.active_team]) + 1)
				return true
			if _footer_primary_rect().has_point(position):
				return controller.confirm_counts()
		"upgrades":
			if _activate_team_tabs(position):
				return true
			var toolbar := _upgrade_toolbar_rects()
			if Rect2(toolbar["type_prev"]).has_point(position):
				controller.cycle_upgrade_type(-1)
				return true
			if Rect2(toolbar["type_next"]).has_point(position):
				controller.cycle_upgrade_type(1)
				return true
			if Rect2(toolbar["base"]).has_point(position):
				controller.set_upgrade_category("base")
				return true
			if Rect2(toolbar["special"]).has_point(position):
				controller.set_upgrade_category("special")
				return true
			for option in _upgrade_option_rects():
				if Rect2(option["minus"]).has_point(position):
					controller.adjust_upgrade(str(option["id"]), -1)
					return true
				if Rect2(option["plus"]).has_point(position):
					controller.adjust_upgrade(str(option["id"]), 1)
					return true
			if _page_rect("prev").has_point(position):
				controller.set_upgrade_page(controller.upgrade_page - 1, _upgrade_page_size())
				return true
			if _page_rect("next").has_point(position):
				controller.set_upgrade_page(controller.upgrade_page + 1, _upgrade_page_size())
				return true
			if _footer_primary_rect().has_point(position):
				return _start_battle_with_campaign_map()
	queue_redraw()
	return false


func _activate_team_tabs(position: Vector2) -> bool:
	if controller.mode != "spectator":
		return false
	var tabs := _team_tab_rects()
	for team in ["blue", "red"]:
		if Rect2(tabs[team]).has_point(position):
			controller.set_active_team(team)
			return true
	return false


func _activate_battle_at(position: Vector2) -> bool:
	var controls := _battle_control_rects()
	if Rect2(controls["exit"]).has_point(position):
		close_requested.emit()
		return true
	if Rect2(controls["setup"]).has_point(position):
		# Keep the chosen teams, counts and free arena loadouts so players can
		# tune one choice instead of rebuilding the whole match.
		controller.return_to_setup()
		_last_winner = ""
		_reset_transient_input()
		return true
	if Rect2(controls["restart"]).has_point(position):
		if controller.restart_battle():
			_prepare_campaign_battlefield()
		_last_winner = ""
		_reset_transient_input()
		return true
	return false


func _hero_template() -> Dictionary:
	var class_data: Dictionary = GameConfig.HERO_CLASSES[hero_class]
	var stats: Dictionary = class_data["base_stats"]
	var normal: Dictionary = class_data["normal_attack"]
	return {
		"class_id": hero_class,
		"max_hp": float(stats.get("hp", 240.0)),
		"hp": float(stats.get("hp", 240.0)),
		"attack": float(stats.get("attack", 30.0)),
		"defense": float(stats.get("defense", 8.0)),
		"speed": float(stats.get("speed", 120.0)) * 1.65,
		"range": float(normal.get("range", 390.0)),
		"attack_rate": float(normal.get("attack_speed", 1.6)),
		"radius": 17.0,
	}


func _start_battle_with_campaign_map() -> bool:
	if not controller.start_battle(_hero_template()):
		return false
	_prepare_campaign_battlefield()
	return true


func _battle_screen_center() -> Vector2:
	return size * 0.5 + Vector2(0.0, 18.0 * ui_scale)


func _spectator_camera_zoom() -> float:
	var arena := controller.arena_rect
	var usable := Vector2(maxf(100.0, size.x - 40.0 * ui_scale), maxf(100.0, size.y - 84.0 * ui_scale))
	return clampf(minf(usable.x / arena.size.x, usable.y / arena.size.y), MIN_BATTLE_CAMERA_ZOOM, 1.0)


func _coverage_camera_zoom() -> float:
	return 1.0 if controller.mode == "challenge" else _spectator_camera_zoom()


func _coverage_camera_centers() -> Array[Vector2]:
	var arena := controller.arena_rect
	if controller.mode != "challenge":
		return [arena.get_center()]
	return [
		arena.position,
		Vector2(arena.end.x, arena.position.y),
		arena.end,
		Vector2(arena.position.x, arena.end.y),
	]


func _camera_visible_local_bounds(camera_center: Vector2, zoom: float) -> Rect2:
	var safe_zoom := maxf(MIN_BATTLE_CAMERA_ZOOM, zoom)
	var screen_center := _battle_screen_center()
	var top_left := camera_center - screen_center / safe_zoom
	var bottom_right := camera_center + (size - screen_center) / safe_zoom
	return Rect2(top_left, bottom_right - top_left).grow(CAMPAIGN_MAP_DRAW_MARGIN)


func _merge_coverage_bounds(first: Rect2, second: Rect2) -> Rect2:
	var minimum := Vector2(minf(first.position.x, second.position.x), minf(first.position.y, second.position.y))
	var maximum := Vector2(maxf(first.end.x, second.end.x), maxf(first.end.y, second.end.y))
	return Rect2(minimum, maximum - minimum)


func _required_campaign_local_bounds() -> Rect2:
	var centers := _coverage_camera_centers()
	var zoom := _coverage_camera_zoom()
	var required := _camera_visible_local_bounds(centers[0], zoom)
	for index in range(1, centers.size()):
		required = _merge_coverage_bounds(required, _camera_visible_local_bounds(centers[index], zoom))
	return required


func _rect_encloses_with_epsilon(outer: Rect2, inner: Rect2) -> bool:
	return (
		outer.position.x <= inner.position.x + CAMPAIGN_COVERAGE_EPSILON
		and outer.position.y <= inner.position.y + CAMPAIGN_COVERAGE_EPSILON
		and outer.end.x >= inner.end.x - CAMPAIGN_COVERAGE_EPSILON
		and outer.end.y >= inner.end.y - CAMPAIGN_COVERAGE_EPSILON
	)


func _coverage_probe_summary(generated_local_bounds: Rect2) -> Dictionary:
	var centers := _coverage_camera_centers()
	var zoom := _coverage_camera_zoom()
	var covered := 0
	for camera_center in centers:
		if _rect_encloses_with_epsilon(generated_local_bounds, _camera_visible_local_bounds(camera_center, zoom)):
			covered += 1
	return {"count": centers.size(), "covered": covered}


func _campaign_coverage_is_current() -> bool:
	if campaign_map_summary.is_empty() or not bool(campaign_map_summary.get("coverage_complete", false)):
		return false
	var recorded_viewport: Vector2 = campaign_map_summary.get("coverage_viewport", Vector2.ZERO)
	var recorded_arena: Rect2 = campaign_map_summary.get("coverage_arena_rect", Rect2())
	return (
		recorded_viewport.is_equal_approx(size)
		and is_equal_approx(float(campaign_map_summary.get("coverage_ui_scale", 0.0)), ui_scale)
		and str(campaign_map_summary.get("coverage_mode", "")) == controller.mode
		and recorded_arena.position.is_equal_approx(controller.arena_rect.position)
		and recorded_arena.size.is_equal_approx(controller.arena_rect.size)
		and is_equal_approx(float(campaign_map_summary.get("coverage_minimum_zoom", 0.0)), _coverage_camera_zoom())
	)


func _prepare_campaign_battlefield() -> void:
	if campaign_world_generator == null:
		configure_campaign_world(campaign_world_seed, campaign_map_anchor)
	campaign_chunks.clear()
	_last_draw_trace.clear()
	var required_local_bounds := _required_campaign_local_bounds()
	var campaign_bounds := Rect2(required_local_bounds.position + campaign_map_anchor, required_local_bounds.size)
	var min_chunk := campaign_world_generator.world_to_chunk(campaign_bounds.position)
	var max_chunk := campaign_world_generator.world_to_chunk(campaign_bounds.end)
	var generated_world_bounds := Rect2(
		Vector2(min_chunk) * WorldGenerator.CHUNK_SIZE,
		Vector2(max_chunk - min_chunk + Vector2i.ONE) * WorldGenerator.CHUNK_SIZE
	)
	var generated_local_bounds := Rect2(generated_world_bounds.position - campaign_map_anchor, generated_world_bounds.size)
	var coverage_probes := _coverage_probe_summary(generated_local_bounds)
	var coverage_complete := (
		_rect_encloses_with_epsilon(generated_local_bounds, required_local_bounds)
		and int(coverage_probes["covered"]) == int(coverage_probes["count"])
	)
	var chunk_keys: Array[String] = []
	var biome_ids: Array[String] = []
	var decoration_count := 0
	var obstacle_count := 0
	var blocking_tree_count := 0
	var arena_obstacles: Array[Dictionary] = []
	for chunk_y in range(min_chunk.y, max_chunk.y + 1):
		for chunk_x in range(min_chunk.x, max_chunk.x + 1):
			var coord := Vector2i(chunk_x, chunk_y)
			var chunk := campaign_world_generator.generate_chunk(coord)
			var key := str(chunk["key"])
			campaign_chunks[key] = chunk
			chunk_keys.append(key)
			var biome_id := str(Dictionary(chunk.get("biome", {})).get("id", ""))
			if not biome_id.is_empty() and biome_id not in biome_ids:
				biome_ids.append(biome_id)
			decoration_count += Array(chunk.get("decorations", [])).size()
			obstacle_count += Array(chunk.get("obstacles", [])).size()
			for obstacle_value in Array(chunk.get("obstacles", [])):
				var obstacle := Dictionary(obstacle_value)
				var arena_position := Vector2(obstacle.get("position", Vector2.ZERO)) - campaign_map_anchor
				if not controller.arena_rect.grow(90.0).has_point(arena_position):
					continue
				var arena_obstacle := {
					"type": str(obstacle.get("type", "")),
					"position": arena_position,
					"radius": float(obstacle.get("radius", 0.0)),
				}
				arena_obstacles.append(arena_obstacle)
				if str(arena_obstacle["type"]) == "tree":
					blocking_tree_count += 1
	chunk_keys.sort()
	biome_ids.sort()
	campaign_map_summary = {
		"chunk_keys": chunk_keys,
		"biome_ids": biome_ids,
		"decoration_count": decoration_count,
		"obstacle_count": obstacle_count,
		"blocking_tree_count": blocking_tree_count,
		"coverage_complete": coverage_complete,
		"coverage_mode": controller.mode,
		"coverage_minimum_zoom": _coverage_camera_zoom(),
		"coverage_viewport": size,
		"coverage_ui_scale": ui_scale,
		"coverage_arena_rect": controller.arena_rect,
		"coverage_required_bounds": required_local_bounds,
		"coverage_generated_bounds": generated_local_bounds,
		"coverage_edge_probe_count": int(coverage_probes["count"]),
		"coverage_edge_probes_covered": int(coverage_probes["covered"]),
	}
	controller.set_battlefield_obstacles(arena_obstacles, {
		"profile": "campaign_wildland",
		"source": "WorldGenerator",
		"seed": campaign_world_seed,
	})


# -----------------------------------------------------------------------------
# Responsive setup layout
# -----------------------------------------------------------------------------

func _common_rects() -> Dictionary:
	var s := ui_scale
	var button := 44.0 * s
	var margin := 8.0 * s
	return {
		"exit": Rect2(margin, margin, button, button),
		"back": Rect2(margin + button + 6.0 * s, margin, button, button),
		"language": Rect2(size.x - margin - button, margin, button, button),
	}


func _header_height() -> float:
	return 52.0 * ui_scale


func _footer_height() -> float:
	return 54.0 * ui_scale


func _content_rect() -> Rect2:
	var margin := 6.0 * ui_scale
	return Rect2(margin, _header_height() + margin, size.x - margin * 2.0, size.y - _header_height() - _footer_height() - margin * 2.0)


func _mode_rects() -> Dictionary:
	var content := _content_rect()
	var gap := 14.0 * ui_scale
	var width := (content.size.x - gap) * 0.5
	return {
		"challenge": Rect2(content.position, Vector2(width, content.size.y)),
		"spectator": Rect2(content.position + Vector2(width + gap, 0.0), Vector2(width, content.size.y)),
	}


func _team_tab_rects() -> Dictionary:
	var s := ui_scale
	var width := minf(156.0 * s, (size.x - 220.0 * s) * 0.5)
	var center_x := size.x * 0.5
	return {
		"blue": Rect2(center_x - width - 3.0 * s, 7.0 * s, width, 44.0 * s),
		"red": Rect2(center_x + 3.0 * s, 7.0 * s, width, 44.0 * s),
	}


func _all_soldier_types() -> Array[String]:
	return CampaignVisualRenderer.supported_soldier_types()


func _type_rects() -> Dictionary:
	var result := {}
	var content := _content_rect()
	var gap := 6.0 * ui_scale
	var columns := 4
	var rows := 4
	var cell_width := (content.size.x - gap * float(columns - 1)) / float(columns)
	var cell_height := (content.size.y - gap * float(rows - 1)) / float(rows)
	var types := _all_soldier_types()
	for index in types.size():
		var column := index % columns
		var row := index / columns
		result[types[index]] = Rect2(content.position + Vector2(float(column) * (cell_width + gap), float(row) * (cell_height + gap)), Vector2(cell_width, cell_height))
	return result


func _hero_class_rect(class_id: String) -> Rect2:
	var index := ["archer", "mage", "warrior"].find(class_id)
	var s := ui_scale
	var footer_y := size.y - _footer_height() + 8.0 * s
	var width := minf(110.0 * s, (size.x * 0.58 - 24.0 * s) / 3.0)
	return Rect2(10.0 * s + float(index) * (width + 5.0 * s), footer_y, width, 44.0 * s)


func _footer_primary_rect() -> Rect2:
	var s := ui_scale
	return Rect2(size.x - 224.0 * s, size.y - _footer_height() + 8.0 * s, 214.0 * s, 44.0 * s)


func _count_rows_per_page() -> int:
	return maxi(1, floori(_content_rect().size.y / (50.0 * ui_scale)))


func _count_page_count() -> int:
	return maxi(1, ceili(float(controller.selected_types_for(controller.active_team).size()) / float(_count_rows_per_page())))


func _count_rects() -> Dictionary:
	var result := {}
	var content := _content_rect()
	var rows := _count_rows_per_page()
	var row_height := content.size.y / float(rows)
	var first := int(count_pages.get(controller.active_team, 0)) * rows
	var choices := controller.selected_types_for(controller.active_team)
	for row_index in rows:
		var index := first + row_index
		if index >= choices.size():
			break
		var type_id := str(choices[index])
		var row_rect := Rect2(content.position + Vector2(0.0, row_height * float(row_index)), Vector2(content.size.x, row_height - 4.0 * ui_scale))
		var button_size := 44.0 * ui_scale
		result[type_id] = {
			"row": row_rect,
			"minus": Rect2(row_rect.end.x - button_size * 2.0 - 12.0 * ui_scale, row_rect.get_center().y - button_size * 0.5, button_size, button_size),
			"plus": Rect2(row_rect.end.x - button_size, row_rect.get_center().y - button_size * 0.5, button_size, button_size),
		}
	return result


func _upgrade_toolbar_rects() -> Dictionary:
	var content := _content_rect()
	var s := ui_scale
	var height := 44.0 * s
	var half := content.size.x * 0.5
	return {
		"type_prev": Rect2(content.position, Vector2(44.0 * s, height)),
		"type_name": Rect2(content.position + Vector2(48.0 * s, 0.0), Vector2(half - 96.0 * s, height)),
		"type_next": Rect2(content.position + Vector2(half - 44.0 * s, 0.0), Vector2(44.0 * s, height)),
		"base": Rect2(content.position + Vector2(half + 4.0 * s, 0.0), Vector2((half - 10.0 * s) * 0.5, height)),
		"special": Rect2(content.position + Vector2(half + 8.0 * s + (half - 10.0 * s) * 0.5, 0.0), Vector2((half - 10.0 * s) * 0.5, height)),
	}


func _upgrade_rows_rect() -> Rect2:
	var content := _content_rect()
	var offset := 50.0 * ui_scale
	return Rect2(content.position + Vector2(0.0, offset), Vector2(content.size.x, maxf(1.0, content.size.y - offset)))


func _upgrade_page_size() -> int:
	return clampi(floori(_upgrade_rows_rect().size.y / (58.0 * ui_scale)), 2, 5)


func _upgrade_option_rects() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rows_rect := _upgrade_rows_rect()
	var page_size := _upgrade_page_size()
	var options := controller.upgrade_options(page_size)
	var row_height := rows_rect.size.y / float(page_size)
	for index in options.size():
		var option: Dictionary = options[index]
		var row := Rect2(rows_rect.position + Vector2(0.0, row_height * float(index)), Vector2(rows_rect.size.x, row_height - 4.0 * ui_scale))
		var button := 44.0 * ui_scale
		result.append({
			"id": str(option["id"]), "definition": option, "row": row,
			"minus": Rect2(row.end.x - button * 2.0 - 12.0 * ui_scale, row.get_center().y - button * 0.5, button, button),
			"plus": Rect2(row.end.x - button, row.get_center().y - button * 0.5, button, button),
		})
	return result


func _page_rect(direction: String) -> Rect2:
	var s := ui_scale
	var footer_y := size.y - _footer_height() + 8.0 * s
	return Rect2(10.0 * s if direction == "prev" else 104.0 * s, footer_y, 88.0 * s, 44.0 * s)


func _battle_control_rects() -> Dictionary:
	var s := ui_scale
	var button_height := 44.0 * s
	return {
		"setup": Rect2(8.0 * s, 8.0 * s, 104.0 * s, button_height),
		"restart": Rect2(118.0 * s, 8.0 * s, 104.0 * s, button_height),
		"exit": Rect2(size.x - 112.0 * s, 8.0 * s, 104.0 * s, button_height),
	}


func _layout_state() -> Dictionary:
	var common := _common_rects()
	var result := {
		"coordinate_space": "logical_viewport_pixels",
		"exit": _rect_state(Rect2(common["exit"])),
		"back": _rect_state(Rect2(common["back"])),
		"language": _rect_state(Rect2(common["language"])),
		"primary": _rect_state(_footer_primary_rect()),
		"minimum_touch_css": 44.0,
		"rotation_required": _portrait_rotation_required(),
		"controls_visible": not _portrait_rotation_required(),
	}
	if controller == null:
		return result
	if controller.mode == "spectator" and controller.phase not in ["mode", "battle", "result"]:
		var team_states := {}
		for team in ["blue", "red"]:
			team_states[team] = _rect_state(Rect2(_team_tab_rects()[team]))
		result["team_tabs"] = team_states
	match controller.phase:
		"mode":
			result["mode_buttons"] = {
				"challenge": _rect_state(Rect2(_mode_rects()["challenge"])),
				"spectator": _rect_state(Rect2(_mode_rects()["spectator"])),
			}
		"types":
			var type_states := {}
			var type_rectangles := _type_rects()
			for key in type_rectangles.keys():
				type_states[str(key)] = _rect_state(Rect2(type_rectangles[key]))
			result["type_buttons"] = type_states
			if controller.mode == "challenge":
				var hero_states := {}
				for class_id in ["archer", "mage", "warrior"]:
					hero_states[class_id] = _rect_state(_hero_class_rect(class_id))
				result["hero_buttons"] = hero_states
		"counts":
			result["count_rows_per_page"] = _count_rows_per_page()
			result["page_prev"] = _rect_state(_page_rect("prev"))
			result["page_next"] = _rect_state(_page_rect("next"))
			var count_states := {}
			for type_id_value in _count_rects().keys():
				var type_id := str(type_id_value)
				var count_data: Dictionary = _count_rects()[type_id]
				count_states[type_id] = {
					"row": _rect_state(Rect2(count_data["row"])),
					"minus": _rect_state(Rect2(count_data["minus"])),
					"plus": _rect_state(Rect2(count_data["plus"])),
				}
			result["count_controls"] = count_states
		"upgrades":
			result["upgrade_rows_per_page"] = _upgrade_page_size()
			result["page_prev"] = _rect_state(_page_rect("prev"))
			result["page_next"] = _rect_state(_page_rect("next"))
			var toolbar_states := {}
			for toolbar_key in _upgrade_toolbar_rects().keys():
				toolbar_states[str(toolbar_key)] = _rect_state(Rect2(_upgrade_toolbar_rects()[toolbar_key]))
			result["upgrade_toolbar"] = toolbar_states
			var option_states := {}
			for option in _upgrade_option_rects():
				option_states[str(option["id"])] = {
					"row": _rect_state(Rect2(option["row"])),
					"minus": _rect_state(Rect2(option["minus"])),
					"plus": _rect_state(Rect2(option["plus"])),
				}
			result["upgrade_controls"] = option_states
		"battle", "result":
			var battle_states := {}
			for control_key in _battle_control_rects().keys():
				battle_states[str(control_key)] = _rect_state(Rect2(_battle_control_rects()[control_key]))
			result["battle_controls"] = battle_states
			if touch_mode and controller.mode == "challenge":
				var radius := 66.0 * ui_scale
				result["move_stick"] = _rect_state(Rect2(_move_center() - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
				result["aim_stick"] = _rect_state(Rect2(_aim_center() - Vector2.ONE * radius, Vector2.ONE * radius * 2.0))
	return result


func _rect_state(rect: Rect2) -> Dictionary:
	return {"x": snappedf(rect.position.x, 0.1), "y": snappedf(rect.position.y, 0.1), "width": snappedf(rect.size.x, 0.1), "height": snappedf(rect.size.y, 0.1)}


# -----------------------------------------------------------------------------
# Rendering
# -----------------------------------------------------------------------------

func _draw() -> void:
	if not visible or controller == null:
		return
	if _portrait_rotation_required():
		draw_rect(Rect2(Vector2.ZERO, size), Color("09151C"))
		var center := size * 0.5
		var phone := Rect2(center - Vector2(110.0, 62.0) * ui_scale, Vector2(220.0, 124.0) * ui_scale)
		draw_rect(phone, Color("142B35"))
		draw_rect(phone, Color("7FA7B8"), false, 4.0 * ui_scale)
		draw_arc(center, 145.0 * ui_scale, -2.7, -0.4, 36, GOLD, 5.0 * ui_scale)
		_draw_text(_t("請旋轉裝置", "ROTATE DEVICE"), center + Vector2(0.0, 150.0 * ui_scale), roundi(28.0 * ui_scale), TEXT, HORIZONTAL_ALIGNMENT_CENTER, minf(size.x - 20.0 * ui_scale, 360.0 * ui_scale))
		return
	if controller.phase in ["battle", "result"]:
		_draw_battle()
	else:
		_draw_setup()


func _draw_setup() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0B161D"))
	for band in 9:
		var y := size.y * float(band) / 8.0
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(0.10, 0.30, 0.32, 0.10), 2.0)
	_draw_setup_header()
	match controller.phase:
		"mode": _draw_mode_selection()
		"types": _draw_type_selection()
		"counts": _draw_count_selection()
		"upgrades": _draw_upgrade_selection()


func _draw_setup_header() -> void:
	var common := _common_rects()
	_draw_button(Rect2(common["exit"]), "×", Color("8B4751"), 20)
	if controller.phase != "mode":
		_draw_button(Rect2(common["back"]), "←", Color("456D7E"), 18)
	_draw_button(Rect2(common["language"]), "EN" if language != "en" else "中", Color("456D7E"), 13)
	var phase_names := {
		"mode": _t("模式", "MODE"), "types": _t("① 選士兵", "① TYPES"),
		"counts": _t("② 調數量", "② COUNTS"), "upgrades": _t("③ 選強化", "③ UPGRADES"),
	}
	if controller.mode != "spectator" or controller.phase == "mode":
		_draw_text(_t("競技場", "ARENA") + " · " + str(phase_names.get(controller.phase, "")), Vector2(size.x * 0.5, 35.0 * ui_scale), maxi(16, roundi(20.0 * ui_scale)), TEXT, HORIZONTAL_ALIGNMENT_CENTER, size.x * 0.48)
	if controller.mode == "spectator" and controller.phase != "mode":
		var tabs := _team_tab_rects()
		_draw_button(Rect2(tabs["blue"]), _t("藍隊", "BLUE") + " %d" % controller.team_total("blue"), BLUE if controller.active_team == "blue" else Color("35516B"), 13)
		_draw_button(Rect2(tabs["red"]), _t("紅隊", "RED") + " %d" % controller.team_total("red"), RED if controller.active_team == "red" else Color("65404A"), 13)


func _draw_mode_selection() -> void:
	var rects := _mode_rects()
	_draw_card(Rect2(rects["challenge"]), BLUE_DARK, BLUE)
	_draw_card(Rect2(rects["spectator"]), RED_DARK, GOLD)
	var challenge := Rect2(rects["challenge"])
	var spectator := Rect2(rects["spectator"])
	_draw_text(_t("玩家挑戰", "PLAYER CHALLENGE"), challenge.get_center() + Vector2(0.0, -34.0 * ui_scale), roundi(28.0 * ui_scale), TEXT, HORIZONTAL_ALIGNMENT_CENTER, challenge.size.x - 24.0 * ui_scale)
	_draw_text(_t("選擇敵軍，親自進場迎戰", "Choose soldiers and fight them yourself"), challenge.get_center() + Vector2(0.0, 18.0 * ui_scale), roundi(14.0 * ui_scale), MUTED, HORIZONTAL_ALIGNMENT_CENTER, challenge.size.x - 32.0 * ui_scale)
	_draw_text(_t("士兵觀戰", "SPECTATOR"), spectator.get_center() + Vector2(0.0, -34.0 * ui_scale), roundi(28.0 * ui_scale), TEXT, HORIZONTAL_ALIGNMENT_CENTER, spectator.size.x - 24.0 * ui_scale)
	_draw_text(_t("藍紅雙方自動戰鬥；不生成玩家", "Blue vs red AI battle; no player entity"), spectator.get_center() + Vector2(0.0, 18.0 * ui_scale), roundi(14.0 * ui_scale), MUTED, HORIZONTAL_ALIGNMENT_CENTER, spectator.size.x - 32.0 * ui_scale)


func _draw_type_selection() -> void:
	var selected := controller.selected_types_for(controller.active_team)
	for type_id_value in _type_rects().keys():
		var type_id := str(type_id_value)
		var rect := Rect2(_type_rects()[type_id])
		var chosen := type_id in selected
		var unit_color := Color(GameConfig.SOLDIERS[type_id]["color"])
		_draw_card(rect, Color(unit_color, 0.22 if chosen else 0.09), unit_color if chosen else Color(unit_color, 0.42))
		_draw_unit_badge(type_id, rect.position + Vector2(28.0 * ui_scale, rect.size.y * 0.5), 20.0 * ui_scale, controller.active_team)
		_draw_text(("✓ " if chosen else "") + _soldier_name(type_id), rect.get_center() + Vector2(17.0 * ui_scale, 5.0 * ui_scale), roundi(13.0 * ui_scale), TEXT if chosen else MUTED, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 62.0 * ui_scale)
	if controller.mode == "challenge":
		for class_id in ["archer", "mage", "warrior"]:
			_draw_button(_hero_class_rect(class_id), ("✓ " if hero_class == class_id else "") + _hero_name(class_id), BLUE if hero_class == class_id else Color("405866"), 12)
	var types_ready := not controller.selected_types_for("red").is_empty() and (controller.mode == "challenge" or not controller.selected_types_for("blue").is_empty())
	_draw_button(_footer_primary_rect(), _t("選好了 → 數量", "DONE → COUNTS"), GOLD if types_ready else Color("4B555A"), 14)


func _draw_count_selection() -> void:
	for type_id_value in _count_rects().keys():
		var type_id := str(type_id_value)
		var data: Dictionary = _count_rects()[type_id]
		var row := Rect2(data["row"])
		_draw_card(row, Color("142833"), Color("456D7E"))
		_draw_unit_badge(type_id, row.position + Vector2(34.0 * ui_scale, row.size.y * 0.5), 20.0 * ui_scale, controller.active_team)
		_draw_text(_soldier_name(type_id), row.position + Vector2(62.0 * ui_scale, row.size.y * 0.5 + 5.0 * ui_scale), roundi(14.0 * ui_scale), TEXT, HORIZONTAL_ALIGNMENT_LEFT, row.size.x * 0.42)
		_draw_button(Rect2(data["minus"]), "−", Color("6D4650"), 22)
		_draw_text("×%d" % controller.count_for(controller.active_team, type_id), Rect2(data["minus"]).position + Vector2(-78.0 * ui_scale, 29.0 * ui_scale), roundi(17.0 * ui_scale), GOLD, HORIZONTAL_ALIGNMENT_CENTER, 70.0 * ui_scale)
		_draw_button(Rect2(data["plus"]), "+", Color("3F8068"), 22)
	_draw_button(_page_rect("prev"), "◀", Color("405866"), 18)
	_draw_button(_page_rect("next"), "▶", Color("405866"), 18)
	var footer_text_left := _page_rect("next").end.x + 4.0 * ui_scale
	var footer_text_right := _footer_primary_rect().position.x - 4.0 * ui_scale
	var footer_text_width := maxf(10.0, footer_text_right - footer_text_left)
	_draw_text(_t("共 %d 人", "TOTAL %d") % controller.team_total(controller.active_team), Vector2((footer_text_left + footer_text_right) * 0.5, size.y - 25.0 * ui_scale), roundi(12.0 * ui_scale), MUTED, HORIZONTAL_ALIGNMENT_CENTER, footer_text_width)
	_draw_button(_footer_primary_rect(), _t("選好了 → 強化", "DONE → UPGRADES"), GOLD, 14)


func _draw_upgrade_selection() -> void:
	var toolbar := _upgrade_toolbar_rects()
	_draw_button(Rect2(toolbar["type_prev"]), "◀", Color("405866"), 17)
	_draw_button(Rect2(toolbar["type_next"]), "▶", Color("405866"), 17)
	var type_id := controller.current_upgrade_type()
	_draw_card(Rect2(toolbar["type_name"]), Color("142833"), Color(GameConfig.SOLDIERS[type_id]["color"]) if not type_id.is_empty() else PANEL_EDGE)
	_draw_text(_soldier_name(type_id), Rect2(toolbar["type_name"]).get_center() + Vector2(0.0, 5.0 * ui_scale), roundi(14.0 * ui_scale), TEXT, HORIZONTAL_ALIGNMENT_CENTER, Rect2(toolbar["type_name"]).size.x - 8.0 * ui_scale)
	_draw_button(Rect2(toolbar["base"]), _t("基礎", "BASE"), BLUE if controller.upgrade_category == "base" else Color("405866"), 13)
	_draw_button(Rect2(toolbar["special"]), _t("特殊", "SPECIAL"), Color("9A62CF") if controller.upgrade_category == "special" else Color("51465E"), 13)
	for option in _upgrade_option_rects():
		var definition: Dictionary = option["definition"]
		var upgrade_id := str(option["id"])
		var row := Rect2(option["row"])
		var rank := int(definition.get("rank", 0))
		var color := SoldierUpgradeVfxCatalog.color_for(upgrade_id) if controller.upgrade_category == "special" else BLUE
		_draw_card(row, Color(color, 0.10), Color(color, 0.52))
		if controller.upgrade_category == "special":
			_draw_ability_glyph(upgrade_id, row.position + Vector2(23.0 * ui_scale, row.size.y * 0.5), 9.0 * ui_scale, 1.0)
		_draw_text(SoldierUpgradeCatalog.localized_name(upgrade_id, language), row.position + Vector2(43.0 * ui_scale, 19.0 * ui_scale), roundi(13.0 * ui_scale), TEXT, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 250.0 * ui_scale)
		_draw_text(SoldierUpgradeCatalog.localized_effect_text(upgrade_id, maxi(1, rank), language), row.position + Vector2(43.0 * ui_scale, row.size.y - 10.0 * ui_scale), roundi(10.0 * ui_scale), MUTED, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 250.0 * ui_scale)
		_draw_button(Rect2(option["minus"]), "−", Color("6D4650"), 20)
		_draw_text("%d/%d" % [rank, int(definition.get("max_rank", 1))], Rect2(option["minus"]).position + Vector2(-67.0 * ui_scale, 28.0 * ui_scale), roundi(13.0 * ui_scale), GOLD, HORIZONTAL_ALIGNMENT_CENTER, 60.0 * ui_scale)
		_draw_button(Rect2(option["plus"]), "+", Color("3F8068"), 20)
	_draw_button(_page_rect("prev"), "◀", Color("405866"), 18)
	_draw_button(_page_rect("next"), "▶", Color("405866"), 18)
	var page_count := controller.upgrade_page_count(_upgrade_page_size())
	_draw_text("%d/%d" % [controller.upgrade_page + 1, page_count], Vector2(245.0 * ui_scale, size.y - 25.0 * ui_scale), roundi(12.0 * ui_scale), MUTED, HORIZONTAL_ALIGNMENT_CENTER, 80.0 * ui_scale)
	_draw_button(_footer_primary_rect(), _t("開始戰鬥", "START BATTLE"), GOLD, 14)


func _update_battle_camera() -> void:
	var arena := controller.arena_rect
	if controller.mode == "spectator" or controller.hero.is_empty():
		camera_position = arena.get_center()
		camera_zoom = _spectator_camera_zoom()
	else:
		camera_position = Vector2(controller.hero.get("pos", arena.get_center()))
		camera_zoom = 1.0


func _world_to_view(world_position: Vector2) -> Vector2:
	return (world_position - camera_position) * camera_zoom + _battle_screen_center()


func _view_to_world(view_position: Vector2) -> Vector2:
	return (view_position - _battle_screen_center()) / maxf(0.001, camera_zoom) + camera_position


func _battle_visual_scale() -> float:
	# World coordinates shrink when spectator camera fits a large arena. Keep the
	# actual marks readable in CSS pixels on short Web viewports.
	return ui_scale if touch_mode else 1.0


func _draw_battle() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("527B4A"))
	_update_battle_camera()
	if campaign_chunks.is_empty() or not _campaign_coverage_is_current():
		_prepare_campaign_battlefield()
	_last_draw_trace = {
		"rendered_unit_count": 0,
		"rendered_unit_types": [],
		"rendered_chunk_keys": [],
		"rendered_biome_ids": [],
		"rendered_decoration_count": 0,
		"rendered_obstacle_count": 0,
		"hero_rendered": false,
	}
	var map_camera_position := campaign_map_anchor + camera_position
	var screen_center := _battle_screen_center()
	var chunk_keys: Array = campaign_chunks.keys()
	chunk_keys.sort()
	for key_value in chunk_keys:
		var draw_result := CampaignVisualRenderer.draw_wildland_chunk(
			self, Dictionary(campaign_chunks[key_value]), map_camera_position, screen_center,
			camera_zoom, Rect2(Vector2.ZERO, size)
		)
		if not bool(draw_result.get("visible", false)):
			continue
		var rendered_keys: Array = _last_draw_trace["rendered_chunk_keys"]
		rendered_keys.append(str(draw_result.get("key", "")))
		_last_draw_trace["rendered_chunk_keys"] = rendered_keys
		var rendered_biomes: Array = _last_draw_trace["rendered_biome_ids"]
		var biome_id := str(draw_result.get("biome", ""))
		if not biome_id.is_empty() and biome_id not in rendered_biomes:
			rendered_biomes.append(biome_id)
		_last_draw_trace["rendered_biome_ids"] = rendered_biomes
		_last_draw_trace["rendered_decoration_count"] = int(_last_draw_trace["rendered_decoration_count"]) + int(draw_result.get("decorations_drawn", 0))
		_last_draw_trace["rendered_obstacle_count"] = int(_last_draw_trace["rendered_obstacle_count"]) + int(draw_result.get("obstacles_drawn", 0))
	var arena := controller.arena_rect
	var top_left := _world_to_view(arena.position)
	var arena_size := arena.size * camera_zoom
	var arena_view := Rect2(top_left, arena_size)
	draw_rect(arena_view, Color(1.0, 0.94, 0.68, 0.025))
	draw_rect(arena_view, Color(0.92, 0.82, 0.49, 0.42), false, maxf(1.5, 3.0 * camera_zoom))
	for effect in controller.effects:
		_draw_arena_effect(effect)
	for projectile in controller.projectiles:
		_draw_arena_projectile(projectile)
	for unit in controller.units:
		if float(unit.get("hp", 0.0)) > 0.0:
			_draw_arena_unit(unit)
	if not controller.hero.is_empty() and float(controller.hero.get("hp", 0.0)) > 0.0:
		_draw_arena_hero(controller.hero)
	_draw_battle_hud()
	if touch_mode and controller.mode == "challenge" and controller.phase == "battle":
		_draw_touch_joystick(_move_center(), move_vector, _t("移動", "MOVE"), BLUE)
		_draw_touch_joystick(_aim_center(), aim_vector, _t("瞄準攻擊", "AIM + FIRE"), Color("FF8A42"))


func _draw_arena_unit(unit: Dictionary) -> void:
	var position := _world_to_view(Vector2(unit["pos"]))
	if not Rect2(Vector2(-80.0, -80.0), size + Vector2(160.0, 160.0)).has_point(position):
		return
	var type_id := str(unit["type"])
	var team := str(unit["team"])
	var team_color := BLUE if team == "blue" else RED
	var visual_scale := _battle_visual_scale()
	var humanoid := type_id in CampaignVisualRenderer.HUMANOID_SOLDIER_TYPES
	var minimum_sprite_scale := 0.64 if humanoid else (0.46 if controller.mode == "spectator" else camera_zoom)
	var sprite_scale := maxf(camera_zoom, minimum_sprite_scale)
	var body_position := position
	if str(unit.get("domain", "ground")) == "air":
		body_position -= Vector2(0.0, 14.0 + sin(game_time * 3.4 + int(unit.get("id", 0))) * 2.5) * sprite_scale
	var radius := float(unit["radius"]) * sprite_scale
	draw_circle(body_position, radius + 3.0 * sprite_scale, Color(team_color, 0.14))
	var rendered := CampaignVisualRenderer.draw_soldier(self, unit, position, game_time, team, sprite_scale, true)
	if rendered:
		_last_draw_trace["rendered_unit_count"] = int(_last_draw_trace.get("rendered_unit_count", 0)) + 1
		var rendered_types: Array = _last_draw_trace.get("rendered_unit_types", [])
		if type_id not in rendered_types:
			rendered_types.append(type_id)
		_last_draw_trace["rendered_unit_types"] = rendered_types
	draw_arc(body_position, radius + 3.0 * sprite_scale, 0.0, TAU, 22, team_color, maxf(1.2, 1.8 * sprite_scale))
	var visual_extent := CampaignVisualRenderer.soldier_visual_extent(type_id, float(unit["radius"]), sprite_scale)
	var overlay_radius := maxf(radius, visual_extent * 0.68) if humanoid else radius
	_draw_unit_upgrade_orbits(unit, body_position, overlay_radius)
	_draw_unit_statuses(unit, body_position, overlay_radius)
	if float(unit["hp"]) < float(unit["max_hp"]):
		var bar_half_width := maxf(radius + 2.0 * visual_scale, visual_extent * 0.54) if humanoid else radius + 2.0 * visual_scale
		_draw_bar(Rect2(body_position + Vector2(-bar_half_width, -visual_extent - 5.0 * visual_scale), Vector2(bar_half_width * 2.0, 2.4 * visual_scale)), float(unit["hp"]) / maxf(1.0, float(unit["max_hp"])), team_color)


func _draw_unit_upgrade_orbits(unit: Dictionary, position: Vector2, radius: float) -> void:
	var visual_scale := _battle_visual_scale()
	var ids := SoldierUpgradeVfxCatalog.active_ids(Dictionary(unit.get("upgrade_snapshot", {})), "unit", 4 if touch_mode else 5, floori(game_time * 0.75) + int(unit.get("id", 0)))
	for index in ids.size():
		var angle := game_time * (0.8 if index % 2 == 0 else -0.65) + float(index) * TAU / float(maxi(1, ids.size()))
		_draw_ability_glyph(str(ids[index]), position + Vector2.from_angle(angle) * (radius + 4.5 * visual_scale), maxf(3.2 * visual_scale, 4.0 * camera_zoom), 0.88)


func _draw_unit_statuses(unit: Dictionary, position: Vector2, radius: float) -> void:
	var visual_scale := _battle_visual_scale()
	var statuses: Dictionary = unit.get("statuses", {})
	if statuses.has("burn"):
		for flame in 3:
			var base := position + Vector2((-0.55 + float(flame) * 0.55) * radius, radius * 0.35)
			var tip := base + Vector2(sin(game_time * 13.0 + flame) * 1.5 * visual_scale, -radius - 3.0 * visual_scale)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-2.0 * visual_scale, 0.0), tip, base + Vector2(2.0 * visual_scale, 0.0)]), Color("FF6A2A"))
	if statuses.has("frost"):
		draw_arc(position, radius + 3.0 * visual_scale, 0.0, TAU, 18, Color("65D9FF"), 1.8 * visual_scale)
		for crystal in 4:
			var crystal_position := position + Vector2.from_angle(float(crystal) * TAU / 4.0) * (radius + 3.0 * visual_scale)
			_draw_ability_glyph("frost_arrow", crystal_position, 2.2 * visual_scale, 0.85)
	if statuses.has("paralysis"):
		for bolt in 3:
			var start := position + Vector2.from_angle(float(bolt) * TAU / 3.0 + game_time) * (radius + 2.0)
			draw_line(start, start + Vector2.from_angle(float(bolt) * TAU / 3.0 + game_time + 0.6) * 4.0 * visual_scale, Color("FFE25C"), 1.5 * visual_scale)
	if statuses.has("poison") or statuses.has("corrosion"):
		for bubble in 3:
			draw_circle(position + Vector2.from_angle(game_time + bubble * 2.1) * (radius + 2.5 * visual_scale), 1.6 * visual_scale, Color("83DC4A"))
	if statuses.has("suppression"):
		for bar in 3:
			var bar_y := position.y - radius - (3.0 + float(bar) * 2.5) * visual_scale
			draw_line(Vector2(position.x - (5.0 - bar) * visual_scale, bar_y), Vector2(position.x + (5.0 - bar) * visual_scale, bar_y), Color("FFB45D"), 1.3 * visual_scale)
	if statuses.has("void_mark"):
		var mark := position + Vector2(0.0, -radius - 7.0 * visual_scale)
		draw_circle(mark, 4.0 * visual_scale, Color("16051F"))
		draw_arc(mark, 5.5 * visual_scale, game_time, game_time + 5.0, 16, Color("B56CFF"), 1.4 * visual_scale)
	if statuses.has("focus_mark"):
		var focus_radius := radius + 5.0 * visual_scale
		for focus in 4:
			var direction := Vector2.from_angle(float(focus) * TAU / 4.0)
			draw_line(position + direction * (focus_radius - 2.0 * visual_scale), position + direction * (focus_radius + 2.0 * visual_scale), Color("FF6B75"), 1.4 * visual_scale)
	if statuses.has("gravity"):
		for gravity_ring in 2:
			draw_arc(position, radius + (3.0 + gravity_ring * 3.0) * visual_scale, game_time * (1.0 + gravity_ring), game_time * (1.0 + gravity_ring) + 4.8, 20, Color("9A71FF", 0.72), 1.2 * visual_scale)
	var runtime: Dictionary = unit.get("special_runtime", {})
	var support_shield := float(unit.get("support_shield", 0.0))
	var tactical_shield := float(runtime.get("tactical_shield", 0.0))
	var kinetic_shield := float(runtime.get("kinetic_barrier", 0.0))
	if support_shield > 0.0 or tactical_shield > 0.0 or kinetic_shield > 0.0:
		var shield_color := Color("63F0C1") if support_shield > 0.0 else (Color("63D5FF") if kinetic_shield > 0.0 else Color("62B8FF"))
		draw_circle(position, radius + 4.0 * visual_scale, Color(shield_color, 0.10))
		draw_arc(position, radius + 4.0 * visual_scale, 0.0, TAU, 24, Color(shield_color, 0.78), 1.8 * visual_scale)


func _draw_arena_projectile(projectile: Dictionary) -> void:
	var position := _world_to_view(Vector2(projectile.get("pos", Vector2.ZERO)))
	var velocity := Vector2(projectile.get("vel", Vector2.RIGHT)).normalized()
	if velocity.length_squared() < 0.01:
		velocity = Vector2.RIGHT
	var visual_scale := _battle_visual_scale()
	var side := Vector2(-velocity.y, velocity.x)
	var team_color := BLUE if str(projectile.get("team", "blue")) == "blue" else RED
	var ids: Array = Array(projectile.get("vfx_layers", projectile.get("ability_ids", [])))
	if bool(projectile.get("delayed_impact", false)):
		_draw_campaign_bomb_drop(projectile, position, visual_scale)
	else:
		draw_line(position - velocity * 8.0 * visual_scale, position, Color(team_color, 0.65), 1.8 * visual_scale)
		_draw_campaign_projectile_core(projectile, position, velocity, visual_scale)
	var visible_count := mini(4, ids.size())
	var first_index := posmod(floori(game_time * 4.0) + int(projectile.get("id", 0)), maxi(1, ids.size()))
	for index in visible_count:
		var ability_id := str(ids[(first_index + index) % ids.size()])
		var color := SoldierUpgradeVfxCatalog.color_for(ability_id)
		var accent := SoldierUpgradeVfxCatalog.accent_for(ability_id)
		var family := SoldierUpgradeVfxCatalog.family_for(ability_id)
		var lane_offset := side * (float(index) - float(visible_count - 1) * 0.5) * 2.0 * visual_scale
		var trail_start := position - velocity * (9.0 + float(index) * 2.0) * visual_scale + lane_offset
		draw_line(trail_start, position + lane_offset, Color(color, 0.72), maxf(1.0 * visual_scale, (2.4 - float(index) * 0.28) * visual_scale))
		match family:
			"fire", "explosive":
				var flicker := sin(game_time * 20.0 + float(index) * 1.7) * 2.0 * visual_scale
				draw_colored_polygon(PackedVector2Array([position - velocity * 2.0 * visual_scale + side * 2.0 * visual_scale, position - velocity * (10.0 * visual_scale + flicker), position - velocity * 2.0 * visual_scale - side * 2.0 * visual_scale]), Color(color, 0.84))
			"frost":
				for crystal in 2:
					var crystal_pos := position - velocity * (4.0 + crystal * 4.0) * visual_scale + side * (1.0 if crystal == 0 else -1.0) * 1.8 * visual_scale
					_draw_ability_glyph(ability_id, crystal_pos, 1.8 * visual_scale, 0.88)
			"lightning":
				var lightning_points := PackedVector2Array([position, position - velocity * 3.0 * visual_scale + side * 2.0 * visual_scale, position - velocity * 6.0 * visual_scale - side * 2.0 * visual_scale, position - velocity * 10.0 * visual_scale])
				draw_polyline(lightning_points, Color(accent, 0.95), 1.2 * visual_scale, true)
			"toxic":
				for bubble in 3:
					draw_circle(position - velocity * float(3 + bubble * 3) * visual_scale + side * sin(game_time * 8.0 + bubble) * 2.0 * visual_scale, (1.0 + bubble * 0.25) * visual_scale, Color(color, 0.72))
			"void", "cosmic":
				draw_circle(position, 3.5 * visual_scale, Color("11031A"))
				draw_arc(position, 5.0 * visual_scale, game_time * 2.0, game_time * 2.0 + 4.8, 14, Color(accent, 0.90), 1.2 * visual_scale)
			"temporal":
				for clock_mark in 3:
					var mark_angle := game_time + float(clock_mark) * TAU / 3.0
					draw_circle(position + Vector2.from_angle(mark_angle) * 4.0 * visual_scale, 0.9 * visual_scale, Color(accent, 0.90))
			"kinetic", "earth":
				draw_arc(position, 4.0 * visual_scale, -2.6, 2.6, 12, Color(accent, 0.84), 1.4 * visual_scale)
			_:
				draw_circle(position + lane_offset, 1.5 * visual_scale, Color(accent, 0.82))
		var glyph_position := position + side * (5.5 + float(index % 2) * 2.2) * visual_scale * (-1.0 if index % 2 == 0 else 1.0)
		_draw_ability_glyph(ability_id, glyph_position, 2.2 * visual_scale, 0.90)
	if not ids.is_empty():
		_draw_ability_glyph(str(ids[first_index]), position, 3.0 * visual_scale, 0.98)


func _draw_campaign_bomb_drop(projectile: Dictionary, impact_position: Vector2, scale: float) -> void:
	var initial_ttl := maxf(0.01, float(projectile.get("initial_ttl", projectile.get("ttl", 0.55))))
	var progress := clampf(1.0 - float(projectile.get("ttl", 0.0)) / initial_ttl, 0.0, 1.0)
	var drop_height := float(projectile.get("drop_height", 92.0)) * maxf(camera_zoom, 0.35)
	var bomb_position := impact_position + Vector2(0.0, -drop_height * (1.0 - progress))
	var warning_radius := clampf(float(projectile.get("aoe", 80.0)) * camera_zoom, 12.0 * scale, 120.0 * scale)
	draw_circle(impact_position, warning_radius, Color(1.0, 0.20, 0.10, 0.045 + progress * 0.06))
	draw_arc(impact_position, warning_radius, 0.0, TAU, 40, Color(1.0, 0.35, 0.18, 0.55 + progress * 0.35), 2.2 * scale)
	draw_circle(impact_position, (10.0 + progress * 7.0) * scale, Color(1.0, 0.18, 0.08, 0.12))
	var body := PackedVector2Array([
		bomb_position + Vector2(-7.0, -13.0) * scale,
		bomb_position + Vector2(7.0, -13.0) * scale,
		bomb_position + Vector2(10.0, 8.0) * scale,
		bomb_position + Vector2(0.0, 15.0) * scale,
		bomb_position + Vector2(-10.0, 8.0) * scale,
	])
	draw_colored_polygon(body, Color("30373D"))
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[4], body[0]]), Color("14191D"), 1.8 * scale, true)
	draw_line(bomb_position + Vector2(-7.0, -10.0) * scale, bomb_position + Vector2(-13.0, -18.0) * scale, Color("6F7A80"), 2.5 * scale)
	draw_line(bomb_position + Vector2(7.0, -10.0) * scale, bomb_position + Vector2(13.0, -18.0) * scale, Color("6F7A80"), 2.5 * scale)


func _draw_campaign_projectile_core(projectile: Dictionary, position: Vector2, direction: Vector2, scale: float) -> void:
	var kind := str(projectile.get("kind", "soldier_projectile"))
	var color := Color(projectile.get("color", TEXT))
	match kind:
		"arrow", "ally_arrow", "hero_arrow":
			draw_line(position - direction * 12.0 * scale, position + direction * 6.0 * scale, color, 3.0 * scale)
			var side := Vector2(-direction.y, direction.x)
			var tip := position + direction * 8.0 * scale
			draw_colored_polygon(PackedVector2Array([tip + direction * 5.0 * scale, tip - direction * 4.0 * scale + side * 3.0 * scale, tip - direction * 4.0 * scale - side * 3.0 * scale]), Color("EAF6FF"))
		"rolling_rock":
			var radius := float(projectile.get("radius", 11.0)) * scale
			draw_circle(position, radius, color)
			draw_arc(position, radius * 0.65, game_time * 8.0, game_time * 8.0 + PI, 8, Color("D6DEE3"), 1.4 * scale)
		"cannonball":
			draw_circle(position, 12.0 * scale, Color("343A40"))
			draw_circle(position - direction * 6.0 * scale, 4.0 * scale, Color("A7B2BE"))
		"musket_ball":
			draw_line(position - direction * 19.0 * scale, position + direction * 5.0 * scale, Color("FFE9B0"), 4.0 * scale)
			draw_circle(position + direction * 6.0 * scale, 3.0 * scale, Color.WHITE)
		"rifle_round", "gatling_round":
			draw_line(position - direction * 15.0 * scale, position + direction * 5.0 * scale, color, 2.4 * scale)
			draw_circle(position + direction * 5.0 * scale, 2.0 * scale, Color.WHITE)
		"tank_shell":
			draw_circle(position, 10.0 * scale, Color("3B4037"))
			draw_circle(position + direction * 4.0 * scale, 4.0 * scale, Color("C8A55A"))
		"rocket":
			var side := Vector2(-direction.y, direction.x)
			var points := PackedVector2Array([
				position - direction * 13.0 * scale - side * 6.0 * scale,
				position + direction * 10.0 * scale - side * 6.0 * scale,
				position + direction * 17.0 * scale,
				position + direction * 10.0 * scale + side * 6.0 * scale,
				position - direction * 13.0 * scale + side * 6.0 * scale,
			])
			draw_colored_polygon(points, Color("D85A36"))
			draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[4], points[0]]), Color("59281F"), 1.5 * scale, true)
			draw_circle(position - direction * 13.0 * scale, (6.0 + sin(game_time * 18.0) * 1.5) * scale, Color("FF7A38"))
			draw_circle(position - direction * 17.0 * scale, 3.5 * scale, GOLD)
		"bomb":
			draw_circle(position, 11.0 * scale, Color("30373D"))
			draw_arc(position, 11.0 * scale, 0.0, TAU, 18, Color("FF6B42"), 2.0 * scale)
		"ally_magic", "ufo_beam", "hero_magic":
			draw_circle(position, float(projectile.get("radius", 7.0)) * scale + sin(game_time * 11.0) * 1.3 * scale, color)
			draw_circle(position, 2.8 * scale, Color("F5FAFF"))
		_:
			draw_circle(position, maxf(2.4, float(projectile.get("radius", 3.0))) * scale, color)


func _draw_arena_effect(effect: Dictionary) -> void:
	var position := _world_to_view(Vector2(effect.get("pos", Vector2.ZERO)))
	var ability_id := str(effect.get("ability_id", effect.get("kind", "")))
	var known := SoldierUpgradeVfxCatalog.DESCRIPTORS.has(ability_id)
	var color := SoldierUpgradeVfxCatalog.color_for(ability_id) if known else (BLUE if str(effect.get("team", "blue")) == "blue" else RED)
	var visual_scale := _battle_visual_scale()
	var radius := clampf(float(effect.get("radius", 34.0)) * camera_zoom, 6.0 * visual_scale, 120.0 * visual_scale)
	var ttl := maxf(0.0, float(effect.get("ttl", 0.5)))
	var pulse := 0.55 + 0.45 * sin(game_time * 8.0 + float(str(effect.get("kind", "")).hash() % 9))
	match str(effect.get("kind", "visual")):
		"mine": _draw_mine_effect(effect, position, radius, color, pulse)
		"turret": _draw_turret_effect(effect, position, color, pulse)
		"repair_drone": _draw_repair_drone_effect(position, color, pulse)
		"grave": _draw_grave_effect(effect, position, color, pulse)
		"meteor": _draw_meteor_effect(effect, position, radius, color, pulse)
		"ufo_beam": _draw_ufo_beam_effect(effect, position, radius, pulse)
		"damage_area": _draw_damage_area_effect(ability_id, position, radius, color, pulse)
		"delayed_area": _draw_delayed_area_effect(ability_id, position, radius, color, pulse)
		"delayed_target": _draw_delayed_target_effect(effect, ability_id, position, color, pulse)
		_:
			_draw_visual_burst(ability_id, position, radius, color, pulse, str(effect.get("event_kind", "trigger")))
	if typeof(effect.get("end_pos", null)) == TYPE_VECTOR2:
		var end := _world_to_view(Vector2(effect["end_pos"]))
		draw_line(position, end, Color(color, 0.82), 1.8 * visual_scale)
	if known:
		_draw_ability_glyph(ability_id, position, clampf(radius * 0.24, 3.0 * visual_scale, 9.0 * visual_scale), 0.94)


func _draw_ufo_beam_effect(effect: Dictionary, position: Vector2, radius: float, pulse: float) -> void:
	var s := _battle_visual_scale()
	var warmup := maxf(0.0, float(effect.get("warmup", 0.0)))
	var beam_height := clampf(300.0 * camera_zoom, 90.0 * s, 260.0 * s)
	if warmup > 0.0:
		var warmup_ratio := clampf(warmup / maxf(0.01, float(effect.get("initial_warmup", 0.75))), 0.0, 1.0)
		draw_circle(position, radius, Color(0.25, 1.0, 0.92, 0.07 + (1.0 - warmup_ratio) * 0.08))
		draw_arc(position, radius, 0.0, TAU, 40, Color("75FFF0"), 2.5 * s)
		draw_arc(position, radius * (0.28 + warmup_ratio * 0.72), 0.0, TAU, 32, Color("D5FFFA"), 2.8 * s)
		draw_line(position + Vector2(0.0, -beam_height), position, Color(0.65, 1.0, 0.96, 0.25), 4.0 * s)
		return
	var top_left := position + Vector2(-radius * 0.44, -beam_height)
	var top_right := position + Vector2(radius * 0.44, -beam_height)
	var beam_points := PackedVector2Array([top_left, top_right, position + Vector2(radius, 0.0), position - Vector2(radius, 0.0)])
	draw_colored_polygon(beam_points, Color(0.30, 1.0, 0.92, 0.20))
	draw_line(top_left, position - Vector2(radius, 0.0), Color(0.65, 1.0, 0.96, 0.78), 3.0 * s)
	draw_line(top_right, position + Vector2(radius, 0.0), Color(0.65, 1.0, 0.96, 0.78), 3.0 * s)
	draw_circle(position, radius, Color(0.28, 1.0, 0.90, 0.20))
	draw_arc(position, radius, 0.0, TAU, 44, Color("D5FFFA"), 4.0 * s)
	draw_circle(position, (14.0 + pulse * 5.0) * s, Color("E8FFFC"))


func _draw_mine_effect(effect: Dictionary, position: Vector2, radius: float, color: Color, pulse: float) -> void:
	var s := _battle_visual_scale()
	var body_radius := maxf(5.0 * s, minf(radius * 0.34, 10.0 * s))
	for tooth in 8:
		var direction := Vector2.from_angle(float(tooth) * TAU / 8.0)
		draw_line(position + direction * body_radius * 0.72, position + direction * body_radius * 1.45, Color("D7DFE3"), 1.4 * s)
	draw_circle(position, body_radius, Color("27343A"))
	draw_arc(position, body_radius, 0.0, TAU, 20, color, 1.8 * s)
	draw_circle(position, (1.5 + pulse) * s, Color("FF5E4A") if bool(effect.get("armed", false)) else GOLD)
	if bool(effect.get("armed", false)):
		draw_arc(position, maxf(radius, body_radius * 2.1), game_time * 2.2, game_time * 2.2 + 4.6, 24, Color(color, 0.42), 1.2 * s)


func _draw_turret_effect(effect: Dictionary, position: Vector2, color: Color, pulse: float) -> void:
	var s := _battle_visual_scale()
	var facing := Vector2.from_angle(game_time * 0.75 + float(int(effect.get("id", 0)) % 7))
	draw_rect(Rect2(position - Vector2(7.0, 5.0) * s, Vector2(14.0, 10.0) * s), Color("31434D"))
	draw_rect(Rect2(position - Vector2(7.0, 5.0) * s, Vector2(14.0, 10.0) * s), color, false, 1.5 * s)
	draw_circle(position, 4.0 * s, Color(color, 0.72))
	draw_line(position, position + facing * 13.0 * s, Color("EAF6FF"), 3.0 * s)
	draw_circle(position + facing * 13.0 * s, (1.3 + pulse) * s, GOLD)


func _draw_repair_drone_effect(position: Vector2, color: Color, pulse: float) -> void:
	var s := _battle_visual_scale()
	var bob := sin(game_time * 4.0) * 2.0 * s
	var center := position + Vector2(0.0, -6.0 * s + bob)
	var diamond := PackedVector2Array([center + Vector2(0.0, -6.0) * s, center + Vector2(8.0, 0.0) * s, center + Vector2(0.0, 6.0) * s, center + Vector2(-8.0, 0.0) * s])
	draw_colored_polygon(diamond, Color(color, 0.78))
	draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), Color("EDFFF9"), 1.3 * s, true)
	for rotor_side in [-1.0, 1.0]:
		var rotor := center + Vector2(rotor_side * 11.0, -1.0) * s
		draw_line(rotor - Vector2(4.0, 0.0) * s, rotor + Vector2(4.0, 0.0) * s, Color("D6F8FF"), 1.2 * s)
	draw_line(center - Vector2(3.0, 0.0) * s, center + Vector2(3.0, 0.0) * s, Color("F2FFF8"), 1.4 * s)
	draw_line(center - Vector2(0.0, 3.0) * s, center + Vector2(0.0, 3.0) * s, Color("F2FFF8"), 1.4 * s)
	draw_circle(position, (3.0 + pulse * 2.0) * s, Color(color, 0.10))


func _draw_grave_effect(effect: Dictionary, position: Vector2, color: Color, pulse: float) -> void:
	var s := _battle_visual_scale()
	var stone := Rect2(position + Vector2(-5.0, -9.0) * s, Vector2(10.0, 16.0) * s)
	draw_rect(stone, Color("8B969B"))
	draw_rect(stone, Color("D7E1E4"), false, 1.2 * s)
	draw_circle(position + Vector2(0.0, -9.0) * s, 5.0 * s, Color("8B969B"))
	draw_arc(position + Vector2(0.0, -9.0) * s, 5.0 * s, PI, TAU, 12, Color("D7E1E4"), 1.2 * s)
	draw_line(position + Vector2(-2.5, -4.0) * s, position + Vector2(2.5, -4.0) * s, Color("313A3F"), 1.2 * s)
	draw_line(position + Vector2(0.0, -7.0) * s, position + Vector2(0.0, 0.0) * s, Color("313A3F"), 1.2 * s)
	var shelter: Dictionary = effect.get("soul_shelter", {})
	if not shelter.is_empty():
		draw_arc(position, (10.0 + pulse * 3.0) * s, game_time, game_time + 5.2, 22, Color(color, 0.72), 1.5 * s)


func _draw_meteor_effect(effect: Dictionary, position: Vector2, radius: float, color: Color, pulse: float) -> void:
	var s := _battle_visual_scale()
	draw_circle(position, radius, Color(color, 0.08 + pulse * 0.05))
	draw_arc(position, radius, 0.0, TAU, 36, Color(color, 0.82), 2.0 * s)
	draw_arc(position, radius * (0.45 + pulse * 0.20), game_time * 1.6, game_time * 1.6 + 5.0, 28, Color("FFE0A1"), 1.5 * s)
	var fall_progress := clampf(float(effect.get("fall_progress", effect.get("progress", 0.0))), 0.0, 1.0)
	# The warning ring tracks the future impact point while the meteor travels
	# from high/right into it; this is driven by controller simulation time.
	var meteor_position := position + Vector2(lerpf(24.0, 2.0, fall_progress), lerpf(-92.0, -7.0, fall_progress)) * s
	draw_line(meteor_position - Vector2(8.0, -14.0) * s, meteor_position, Color(color, 0.42), 7.0 * s)
	draw_circle(meteor_position, (5.0 + pulse * 1.5) * s, Color("5A3027"))
	draw_arc(meteor_position, 6.0 * s, 0.0, TAU, 16, Color("FFB55C"), 1.5 * s)


func _draw_damage_area_effect(ability_id: String, position: Vector2, radius: float, color: Color, pulse: float) -> void:
	var s := _battle_visual_scale()
	draw_circle(position, radius, Color(color, 0.08 + pulse * 0.04))
	if ability_id == "burning_zone":
		for flame in 8:
			var angle := float(flame) * TAU / 8.0 + game_time * 0.2
			var base := position + Vector2.from_angle(angle) * radius * 0.72
			draw_colored_polygon(PackedVector2Array([base - Vector2(2.5, 0.0) * s, base + Vector2(sin(game_time * 12.0 + flame) * 3.0, -8.0) * s, base + Vector2(2.5, 0.0) * s]), Color("FF6A2A", 0.84))
	elif ability_id == "gravity_warhead":
		draw_circle(position, radius * 0.18, Color("10051D"))
		for ring in 3:
			draw_arc(position, radius * (0.38 + ring * 0.22), game_time * (1.1 + ring * 0.35), game_time * (1.1 + ring * 0.35) + 4.7, 30, Color(color, 0.60), 1.5 * s)
			for pull in 4:
				var direction := Vector2.from_angle(float(pull) * TAU / 4.0 + game_time * 0.3)
				draw_line(position + direction * radius * 0.88, position + direction * radius * 0.56, Color("D7C7FF", 0.58), 1.1 * s)
	elif ability_id == "lingering_projectile":
		for blade in 3:
			var direction := Vector2.from_angle(game_time * 1.8 + float(blade) * TAU / 3.0)
			draw_line(position - direction * radius * 0.42, position + direction * radius * 0.42, Color(color, 0.74), 2.2 * s)
	else:
		draw_arc(position, radius, game_time * 0.4, game_time * 0.4 + 5.0, 32, Color(color, 0.66), 1.7 * s)


func _draw_delayed_area_effect(ability_id: String, position: Vector2, radius: float, color: Color, pulse: float) -> void:
	var s := _battle_visual_scale()
	draw_circle(position, radius, Color(color, 0.05 + pulse * 0.04))
	for segment in 8:
		var start := float(segment) * TAU / 8.0 + game_time * 0.35
		draw_arc(position, radius, start, start + TAU / 16.0, 5, Color(color, 0.78), 2.0 * s)
	if ability_id in ["chain_explosion", "cluster_warhead"]:
		for spark in 5:
			draw_circle(position + Vector2.from_angle(game_time + spark * 1.31) * radius * (0.25 + spark * 0.10), 1.4 * s, Color("FFE29A"))


func _draw_delayed_target_effect(effect: Dictionary, ability_id: String, position: Vector2, color: Color, pulse: float) -> void:
	var s := _battle_visual_scale()
	var orbit := (6.0 + pulse * 3.0) * s
	draw_arc(position, orbit, game_time * 1.5, game_time * 1.5 + 5.0, 18, Color(color, 0.78), 1.6 * s)
	for clock_mark in 4:
		var direction := Vector2.from_angle(float(clock_mark) * TAU / 4.0)
		draw_line(position + direction * orbit * 0.70, position + direction * orbit, Color(color, 0.72), 1.1 * s)
	if ability_id == "temporal_echo":
		draw_line(position, position + Vector2.from_angle(game_time * 0.5) * orbit * 0.70, Color("F2ECFF"), 1.4 * s)


func _draw_visual_burst(ability_id: String, position: Vector2, radius: float, color: Color, pulse: float, event_kind: String) -> void:
	var s := _battle_visual_scale()
	var family := SoldierUpgradeVfxCatalog.family_for(ability_id) if SoldierUpgradeVfxCatalog.DESCRIPTORS.has(ability_id) else "kinetic"
	draw_circle(position, radius, Color(color, 0.06 + pulse * 0.05))
	draw_arc(position, radius, game_time * 0.6, game_time * 0.6 + 5.1, 30, Color(color, 0.58), 1.5 * s)
	if family == "lightning":
		for bolt in 4:
			var direction := Vector2.from_angle(float(bolt) * TAU / 4.0 + game_time * 0.2)
			var middle := position + direction * radius * 0.52 + Vector2(-direction.y, direction.x) * 3.0 * s
			draw_polyline(PackedVector2Array([position, middle, position + direction * radius]), Color("F5F1A6"), 1.4 * s, true)
	elif family in ["healing", "holy", "repair", "soul"]:
		draw_line(position - Vector2(5.0, 0.0) * s, position + Vector2(5.0, 0.0) * s, Color("E9FFF6"), 2.0 * s)
		draw_line(position - Vector2(0.0, 5.0) * s, position + Vector2(0.0, 5.0) * s, Color("E9FFF6"), 2.0 * s)
	elif family in ["explosive", "fire"] or event_kind in ["impact", "blast"]:
		for ray in 8:
			var direction := Vector2.from_angle(float(ray) * TAU / 8.0)
			draw_line(position + direction * radius * 0.34, position + direction * radius, Color(color, 0.72), (1.0 + float(ray % 2) * 0.55) * s)
	elif family in ["guard", "command"]:
		for edge in 6:
			var a := position + Vector2.from_angle(float(edge) * TAU / 6.0) * radius * 0.70
			var b := position + Vector2.from_angle(float(edge + 1) * TAU / 6.0) * radius * 0.70
			draw_line(a, b, Color(color, 0.72), 1.5 * s)


func _draw_arena_hero(hero: Dictionary) -> void:
	var position := _world_to_view(Vector2(hero["pos"]))
	var visual_scale := _battle_visual_scale()
	var sprite_scale := maxf(0.7, camera_zoom)
	var radius := float(hero.get("radius", 17.0)) * sprite_scale
	draw_circle(position, radius + 3.5 * visual_scale, Color(BLUE, 0.22))
	_last_draw_trace["hero_rendered"] = CampaignVisualRenderer.draw_hero(self, hero, position, game_time, "blue", sprite_scale, true)
	draw_arc(position, radius + 3.5 * visual_scale, 0.0, TAU, 24, BLUE, 1.8 * visual_scale)
	var hero_extent := CampaignVisualRenderer.hero_visual_extent(sprite_scale)
	var hero_bar_half_width := maxf(18.0 * visual_scale, hero_extent * 0.52)
	_draw_bar(Rect2(position + Vector2(-hero_bar_half_width, -hero_extent - 6.0 * visual_scale), Vector2(hero_bar_half_width * 2.0, 3.0 * visual_scale)), float(hero["hp"]) / maxf(1.0, float(hero["max_hp"])), BLUE)


func _draw_battle_hud() -> void:
	var controls := _battle_control_rects()
	_draw_button(Rect2(controls["setup"]), _t("重選", "SETUP"), Color("456D7E"), 12)
	_draw_button(Rect2(controls["restart"]), _t("重開", "RESTART"), Color("6A557A"), 12)
	_draw_button(Rect2(controls["exit"]), _t("離開", "EXIT"), Color("8B4751"), 12)
	var battle_state := controller.render_state()
	var battle_teams: Dictionary = battle_state["teams"]
	var blue_alive := 1 if controller.mode == "challenge" and not controller.hero.is_empty() and float(controller.hero.get("hp", 0.0)) > 0.0 else 0
	blue_alive += int(Dictionary(battle_teams["blue"])["alive"])
	var red_alive := int(Dictionary(battle_teams["red"])["alive"])
	var title := (_t("觀戰模式", "SPECTATOR") if controller.mode == "spectator" else _t("玩家挑戰", "CHALLENGE")) + "  %d  —  %d" % [blue_alive, red_alive]
	# Fit the score between RESTART and EXIT, including compact English HUDs.
	var hud_left := Rect2(controls["restart"]).end.x + 8.0 * ui_scale
	var hud_right := Rect2(controls["exit"]).position.x - 8.0 * ui_scale
	var hud_width := maxf(80.0 * ui_scale, hud_right - hud_left)
	var hud_center_x := hud_left + hud_width * 0.5
	_draw_text(title, Vector2(hud_center_x, 35.0 * ui_scale), roundi(17.0 * ui_scale), TEXT, HORIZONTAL_ALIGNMENT_CENTER, hud_width)
	_draw_text(_t("場地自動尺寸", "AUTO-SIZED") + " %d×%d" % [roundi(controller.arena_rect.size.x), roundi(controller.arena_rect.size.y)], Vector2(hud_center_x, 54.0 * ui_scale), roundi(10.0 * ui_scale), MUTED, HORIZONTAL_ALIGNMENT_CENTER, hud_width)
	if controller.phase == "result":
		var overlay := Rect2(size * 0.5 - Vector2(220.0, 74.0) * ui_scale, Vector2(440.0, 148.0) * ui_scale)
		draw_rect(overlay, PANEL)
		draw_rect(overlay, GOLD, false, 3.0 * ui_scale)
		var winner_name := _t("藍隊", "BLUE") if controller.winner == "blue" else (_t("紅隊", "RED") if controller.winner == "red" else _t("平手", "DRAW"))
		_draw_text(winner_name + " " + _t("獲勝", "WINS"), overlay.get_center() + Vector2(0.0, -10.0 * ui_scale), roundi(28.0 * ui_scale), GOLD, HORIZONTAL_ALIGNMENT_CENTER, overlay.size.x - 20.0 * ui_scale)
		_draw_text(_t("按 R 或點「重開」再戰", "Press R or tap RESTART"), overlay.get_center() + Vector2(0.0, 30.0 * ui_scale), roundi(12.0 * ui_scale), MUTED, HORIZONTAL_ALIGNMENT_CENTER, overlay.size.x - 20.0 * ui_scale)


func _move_center() -> Vector2:
	return Vector2(82.0 * ui_scale, size.y - 82.0 * ui_scale)


func _aim_center() -> Vector2:
	return Vector2(size.x - 82.0 * ui_scale, size.y - 82.0 * ui_scale)


func _draw_touch_joystick(center: Vector2, vector: Vector2, label: String, color: Color) -> void:
	var radius := 66.0 * ui_scale
	draw_circle(center, radius, Color(0.02, 0.04, 0.05, 0.64))
	draw_arc(center, radius, 0.0, TAU, 32, Color(color, 0.75), 3.0 * ui_scale)
	var knob := center + vector.limit_length(1.0) * radius * 0.60
	draw_circle(knob, 24.0 * ui_scale, Color(color, 0.78))
	draw_arc(knob, 24.0 * ui_scale, 0.0, TAU, 20, TEXT, 2.0 * ui_scale)
	_draw_text(label, center + Vector2(0.0, -radius - 9.0 * ui_scale), roundi(11.0 * ui_scale), TEXT, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0)


func _draw_unit_badge(type_id: String, center: Vector2, radius: float, team: String) -> void:
	var team_color := BLUE if team == "blue" else RED
	draw_circle(center, radius + 3.0, Color(team_color, 0.18))
	var combat: Dictionary = Dictionary(GameConfig.SOLDIERS[type_id]).get("combat", {})
	var badge_unit := {
		"id": type_id.hash(), "type": type_id, "radius": CampaignVisualRenderer.radius_for(type_id),
		"domain": str(combat.get("domain", "ground")), "aim_dir": Vector2.RIGHT if team == "blue" else Vector2.LEFT,
		"flash": 0.0,
	}
	var humanoid := type_id in CampaignVisualRenderer.HUMANOID_SOLDIER_TYPES
	var badge_ground := center + Vector2(0.0, radius * (0.70 if humanoid else 0.08))
	var badge_scale := radius / (24.0 if humanoid else 48.0)
	CampaignVisualRenderer.draw_soldier(self, badge_unit, badge_ground, game_time, team, badge_scale, false)
	draw_arc(center, radius, 0.0, TAU, 18, team_color, 2.0)


func _draw_ability_glyph(ability_id: String, center: Vector2, glyph_size: float, alpha: float) -> void:
	var index := maxi(0, SoldierUpgradeVfxCatalog.visual_index(ability_id))
	var motif := index % 8
	var tier := index / 8
	var color := Color(SoldierUpgradeVfxCatalog.color_for(ability_id), alpha)
	var accent := Color(SoldierUpgradeVfxCatalog.accent_for(ability_id), alpha)
	match motif:
		0: draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -glyph_size), center + Vector2(glyph_size, 0.0), center + Vector2(0.0, glyph_size), center + Vector2(-glyph_size, 0.0)]), color)
		1: draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -glyph_size), center + Vector2(glyph_size, glyph_size), center + Vector2(-glyph_size, glyph_size)]), color)
		2: draw_arc(center, glyph_size, 0.0, TAU, 16, accent, maxf(1.0, glyph_size * 0.22))
		3: draw_polyline(PackedVector2Array([center - Vector2(glyph_size, glyph_size * 0.5), center, center + Vector2(glyph_size, -glyph_size * 0.5)]), accent, maxf(1.0, glyph_size * 0.22))
		4:
			draw_line(center - Vector2(glyph_size, 0.0), center + Vector2(glyph_size, 0.0), accent, maxf(1.0, glyph_size * 0.22))
			draw_line(center - Vector2(0.0, glyph_size), center + Vector2(0.0, glyph_size), color, maxf(1.0, glyph_size * 0.22))
		5:
			draw_rect(Rect2(center - Vector2.ONE * glyph_size * 0.72, Vector2.ONE * glyph_size * 1.44), Color(color, alpha * 0.35))
			draw_rect(Rect2(center - Vector2.ONE * glyph_size * 0.72, Vector2.ONE * glyph_size * 1.44), accent, false, maxf(1.0, glyph_size * 0.18))
		6:
			for spoke in 4:
				var direction := Vector2.from_angle(PI * 0.25 + float(spoke) * PI * 0.5)
				draw_line(center - direction * glyph_size, center + direction * glyph_size, accent if spoke % 2 == 0 else color, maxf(1.0, glyph_size * 0.18))
		_:
			draw_arc(center, glyph_size, -2.7, -0.35, 10, accent, maxf(1.0, glyph_size * 0.20))
			draw_arc(center, glyph_size, 0.45, 2.8, 10, color, maxf(1.0, glyph_size * 0.20))
	# Motif + tier dots + descriptor signature give all 57 catalog entries a
	# genuinely distinct silhouette, including when several share a VFX family.
	for dot_index in tier + 1:
		var dot_angle := -PI * 0.5 + float(dot_index) * TAU / float(tier + 1)
		draw_circle(center + Vector2.from_angle(dot_angle) * glyph_size * 1.30, maxf(0.75, glyph_size * 0.12), accent)
	var shape_id := SoldierUpgradeVfxCatalog.shape_for(ability_id)
	var signature_angle := float(posmod(shape_id.hash(), 997)) / 997.0 * TAU
	var signature_direction := Vector2.from_angle(signature_angle)
	draw_line(center + signature_direction * glyph_size * 0.28, center + signature_direction * glyph_size * 0.88, color, maxf(0.75, glyph_size * 0.11), true)


func _draw_card(rect: Rect2, fill: Color, edge: Color) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, edge, false, maxf(1.5, 2.0 * ui_scale))


func _draw_button(rect: Rect2, label: String, color: Color, base_size: int) -> void:
	draw_rect(rect, Color(color, 0.72))
	draw_rect(rect, color.lightened(0.22), false, maxf(1.5, 2.0 * ui_scale))
	_draw_text(label, rect.get_center() + Vector2(0.0, float(base_size) * 0.36 * ui_scale), maxi(11, roundi(float(base_size) * ui_scale)), TEXT, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0 * ui_scale)


func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, Color("101820"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)
	draw_rect(rect, Color("D8E6EC"), false, 1.0)


func _draw_text(text_value: String, baseline: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment, width: float) -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	draw_string(_font, Vector2(baseline.x - width * 0.5 if alignment == HORIZONTAL_ALIGNMENT_CENTER else baseline.x, baseline.y), text_value, alignment, width, font_size, color)


func _t(zh: String, en: String) -> String:
	return en if language == "en" else zh


func _soldier_name(type_id: String) -> String:
	if type_id.is_empty() or not GameConfig.SOLDIERS.has(type_id):
		return "—"
	var names := {
		"swordsman": "Swordsman", "healer": "Healer", "archer": "Archer", "roller": "Boulder",
		"mage": "Mage", "heavy": "Heavy", "priest": "Priest", "cannon": "Cannon",
		"musketeer": "Musketeer", "rifleman": "Rifleman", "tank": "Tank", "rocket": "Rocket",
		"gatling": "Gatling", "helicopter": "Helicopter", "bomber": "Bomber", "ufo": "UFO",
	}
	return str(names.get(type_id, type_id)) if language == "en" else str(GameConfig.SOLDIERS[type_id]["name"])


func _hero_name(class_id: String) -> String:
	var en_names := {"archer": "Archer", "mage": "Mage", "warrior": "Warrior"}
	return str(en_names[class_id]) if language == "en" else str(GameConfig.HERO_CLASSES[class_id]["name"])

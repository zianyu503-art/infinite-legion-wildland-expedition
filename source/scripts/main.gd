extends Node2D

## 《無盡軍勢：荒原遠征》
## 程序化 Godot 4.x 俯視角動作戰鬥遊戲。世界、角色、UI 與特效皆由程式繪製。

const GameConfig = preload("res://scripts/game_config.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const GameAudioManager = preload("res://scripts/audio_manager.gd")
const GameSaveManager = preload("res://scripts/save_manager.gd")
const GameLocalization = preload("res://scripts/game_localization.gd")
const EnemyEnhancementCatalog = preload("res://scripts/enemy_enhancement_catalog.gd")
const SoldierUpgradeCatalog = preload("res://scripts/soldier_upgrade_catalog.gd")
const SoldierUpgradeRuntime = preload("res://scripts/soldier_upgrade_runtime.gd")
const NationCatalog = preload("res://scripts/nation_catalog.gd")
const PythonBossControllerScript = preload("res://scripts/python_boss.gd")
const ChaosBossControllerScript = preload("res://scripts/chaos_boss.gd")
const AionisBossControllerScript = preload("res://scripts/aionis_boss.gd")
const CAVIAR_AVATAR_TEXTURE = preload("res://assets/ui/caviar_avatar.png")
const UI_FONT_PATH := "res://assets/fonts/NotoSansTC-Regular.otf"

enum GameMode { TITLE, CLASS_SELECT, PLAYING, PAUSED, DEAD, ENDING }
enum InputScheme { KEYBOARD_MOUSE, TOUCH }

const VIEW_BASE := Vector2(1280.0, 720.0)
const ACTIVE_CHUNK_RADIUS := 2
const MAX_ENEMIES := 160
const MAX_PROJECTILES := 220
const MAX_PARTICLES := 420
const MAX_MOBILE_PARTICLES := 280
const MAX_FLOATERS := 56
const MAX_INACTIVE_ENEMY_CHUNKS := 256
const MAX_STREAM_HISTORY_CHUNKS := 2048
const HOUSE_POS := Vector2(480.0, 480.0)
const HOUSE_SAFE_RADIUS := 320.0
const PLAYER_RADIUS := 17.0
const PLAYER_HIT_GRACE_SECONDS := 0.14
const CASTLE_CORE_COLLISION_RADIUS := 121.0
const CASTLE_OUTER_COLLISION_RADIUS := 205.0
const SAVE_SCHEMA := 8
const NATION_TICK_INTERVAL := 2.0
const NATION_SUPPORT_RADIUS := 1750.0
const NATION_WAR_RADIUS := 1250.0
const FIXED_STEP := 1.0 / 60.0
const BOSS_ENTITY_ID := -9001
const MAIN_PYTHON_BOSS_LAIR_ID := "python_boss_main_lair"
const PROFILE_PATH := "user://infinite_legion_profile.json"
const ENDING_DURATION := 9.6
const TOUCH_STICK_RADIUS := 74.0
const TOUCH_BUTTON_SIZE := 82.0
const CLASS_SELECT_POINTER_GUARD_MSEC := 420
const HERO_LEVEL_CAP := 50
const ENEMY_PREDICTION_MAX_LEAD := 220.0
const SOLDIER_PREDICTION_MAX_LEAD := 180.0
const PREDICTION_TARGET_SPEED_CAP := 240.0
const BOSS_HOME_CLEAR_RADIUS := 260.0
const MAX_UPGRADE_EFFECTS := 72
const MAX_UPGRADE_MINES_PER_TEAM := 24
const MAX_UPGRADE_LINGERING_PER_TEAM := 16
const MAX_UPGRADE_SUMMONS_PER_TEAM := 5
const UPGRADE_EFFECT_SCAN_INTERVAL := 0.10

const FRIEND_BLUE := Color("3B82F6")
const FRIEND_DARK := Color("12365A")
const ENEMY_RED := Color("B84032")
const ENEMY_DARK := Color("4A1714")
const INK := Color("1B2930")
const GOLD := Color("FFD166")
const HEAL_GREEN := Color("55D98A")
const MAGIC_PURPLE := Color("A78BFA")
const FIRE_ORANGE := Color("FF7A38")
const PANEL_BG := Color(0.035, 0.055, 0.075, 0.96)
const PANEL_EDGE := Color(0.30, 0.48, 0.62, 0.9)

var mode: int = GameMode.TITLE
var screen_size := VIEW_BASE
var world_seed: int = 20260731
var world_generator: WorldGenerator
var audio: GameAudioManager
var ui_font: Font

var player: Dictionary = {}
var camera_pos := HOUSE_POS
var camera_target := HOUSE_POS
var camera_shake := 0.0
var camera_shake_offset := Vector2.ZERO

var active_chunks: Dictionary = {}
var discovered_chunks: Dictionary = {}
var spawned_chunks: Dictionary = {}
var chunk_states: Dictionary = {}
var pending_chunk_spawns: Dictionary = {}
var castles: Dictionary = {}
var camps: Dictionary = {}
var snake_nests: Dictionary = {}

var enemies: Array[Dictionary] = []
var soldiers: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var upgrade_effects: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var tombstones: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var notifications: Array[Dictionary] = []
var python_boss: Variant = null
var active_python_boss_lair_id := MAIN_PYTHON_BOSS_LAIR_ID
var main_python_boss_lair_cleared := false
var python_boss_lair_activation_timer := 0.0
var chaos_boss: Variant = null
var final_boss_defeated := false
var ending_seen := false
var all_soldiers_unlocked := false
var timeless_gate_unlocked := false
var aionis_boss: Variant = null
var aionis_boss_defeated := false
var kaeron_ending_completed := false
var ending_elapsed := 0.0
var ending_pending := false
var chaos_runtime_projectiles: Array[Dictionary] = []
var chaos_runtime_hazards: Array[Dictionary] = []
var aionis_runtime_projectiles: Array[Dictionary] = []
var aionis_runtime_hazards: Array[Dictionary] = []

var next_entity_id := 1
var game_time := 0.0
var autosave_timer := 0.0
var death_timer := 0.0
var attack_held := false
var active_panel := ""
var soldier_command := "跟隨"
var command_point := HOUSE_POS
var command_target_id := -1
var command_castle_id := ""
var recruit_anchor := HOUSE_POS
var tutorial_visible := true
var notifications_hidden := false
var soldier_research: Dictionary = {}
var soldier_upgrade_type_index := 0
var soldier_upgrade_category := "base"
var soldier_upgrade_page := 0
var soldier_upgrade_shared_cooldowns: Dictionary = {}
var soldier_boss_debuffs: Dictionary = {}
var nation_tick_timer := 0.0
var tutorial_step := 0
var master_volume := 0.75
var sound_muted := false
var language := "zh_TW"
var input_scheme: int = InputScheme.KEYBOARD_MOUSE
var touch_capable := false
var touch_ui_coordinate_scale := 1.0
var touch_move_pointer := -1
var touch_aim_pointer := -1
var touch_move_vector := Vector2.ZERO
var touch_aim_vector := Vector2.RIGHT
var touch_move_position := Vector2.ZERO
var touch_aim_position := Vector2.ZERO
var touch_button_feedback: Dictionary = {}
var last_touch_event_msec := -10000
var class_select_pointer_guard_until_msec := -10000
var last_recruit_purchase_msec := -10000
var last_recruit_purchase_type := ""
var cheat_input: LineEdit
var cheat_input_active := false
var class_change_pending := false
var _last_active_center := Vector2i(999999, 999999)
var _last_boss_active_center := Vector2i(999999, 999999)
var _boss_chunks_pinned_last := false
var _self_test_running := false
var _self_test_passed := 0
var _self_test_failed := 0
var _web_render_callback: Variant = null
var _web_advance_callback: Variant = null
var _web_force_boss_callback: Variant = null
var _web_touch_mode_callback: Variant = null
var _web_force_recruit_callback: Variant = null
var _web_heavy_cannon_showcase_callback: Variant = null
var _web_chaos_showcase_callback: Variant = null
var _web_aionis_showcase_callback: Variant = null
var _web_manual_time_hold := 0.0
var _web_test_showcase_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen_size = get_viewport_rect().size
	_refresh_touch_ui_coordinate_scale()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	var user_args := OS.get_cmdline_user_args()
	var self_test_requested := "--self-test" in user_args
	var visual_smoke_requested := "--visual-smoke" in user_args
	if OS.has_feature("web") or not FileAccess.file_exists(UI_FONT_PATH):
		var imported_font: Resource = load(UI_FONT_PATH)
		ui_font = imported_font as Font if imported_font is Font else ThemeDB.fallback_font
	else:
		var dynamic_font := FontFile.new()
		if dynamic_font.load_dynamic_font(UI_FONT_PATH) == OK:
			ui_font = dynamic_font
		else:
			ui_font = ThemeDB.fallback_font
	audio = GameAudioManager.new()
	audio.name = "AudioManager"
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	audio.set_volume(master_volume)
	world_generator = WorldGenerator.new(world_seed)
	_initialize_empty_player()
	soldier_research = SoldierUpgradeCatalog.create_empty_research()
	soldier_upgrade_type_index = 0
	soldier_upgrade_category = "base"
	soldier_upgrade_page = 0
	soldier_upgrade_shared_cooldowns.clear()
	soldier_boss_debuffs.clear()
	soldier_research = SoldierUpgradeCatalog.create_empty_research()
	_load_profile_progression()
	_initialize_python_boss()
	_initialize_chaos_boss()
	_initialize_aionis_boss()
	_detect_initial_language_and_input()
	_initialize_cheat_input()
	if OS.has_feature("web"):
		_setup_web_bridge()
	if not self_test_requested:
		queue_redraw()
	if self_test_requested:
		_self_test_running = true
		visible = false
		call_deferred("_run_self_test")
	elif visual_smoke_requested:
		call_deferred("_run_visual_smoke")


func _on_viewport_size_changed() -> void:
	screen_size = get_viewport_rect().size
	_refresh_touch_ui_coordinate_scale()
	_layout_cheat_input()
	queue_redraw()


func _refresh_touch_ui_coordinate_scale() -> void:
	# canvas_items + expand keeps a 720-high logical viewport on wide phones.
	# Browser input is converted into those logical coordinates, so controls must
	# grow by the same ratio to retain their intended CSS-pixel touch targets.
	touch_ui_coordinate_scale = 1.0
	if not OS.has_feature("web"):
		return
	var css_width: Variant = JavaScriptBridge.eval("Math.max(1, window.innerWidth || 1)", true)
	var css_height: Variant = JavaScriptBridge.eval("Math.max(1, window.innerHeight || 1)", true)
	if typeof(css_width) not in [TYPE_INT, TYPE_FLOAT] or typeof(css_height) not in [TYPE_INT, TYPE_FLOAT]:
		return
	var width_ratio := screen_size.x / maxf(1.0, float(css_width))
	var height_ratio := screen_size.y / maxf(1.0, float(css_height))
	touch_ui_coordinate_scale = clampf(maxf(width_ratio, height_ratio), 1.0, 3.0)


func _detect_initial_language_and_input() -> void:
	var locale := OS.get_locale_language().to_lower()
	language = "zh_TW" if locale.begins_with("zh") else "en"
	touch_capable = DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		var saved_language: Variant = JavaScriptBridge.eval("(() => { try { return localStorage.getItem('infinite_legion_language') || ''; } catch (_) { return ''; } })()", true)
		if typeof(saved_language) == TYPE_STRING and str(saved_language) in ["zh_TW", "en"]:
			language = str(saved_language)
		var browser_touch: Variant = JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || ('ontouchstart' in window)", true)
		if typeof(browser_touch) == TYPE_BOOL:
			touch_capable = touch_capable or bool(browser_touch)
	if touch_capable:
		input_scheme = InputScheme.TOUCH


func _set_input_scheme(scheme: int) -> void:
	scheme = clampi(scheme, InputScheme.KEYBOARD_MOUSE, InputScheme.TOUCH)
	if input_scheme == scheme:
		return
	_reset_touch_inputs()
	input_scheme = scheme
	if scheme == InputScheme.TOUCH:
		touch_capable = true
	queue_redraw()


func _reset_touch_inputs() -> void:
	touch_move_pointer = -1
	touch_aim_pointer = -1
	touch_move_vector = Vector2.ZERO
	touch_move_position = _touch_move_center()
	touch_aim_position = _touch_aim_center()
	attack_held = false


func _enter_class_select(guard_pointer: bool) -> void:
	mode = GameMode.CLASS_SELECT
	active_panel = ""
	class_select_pointer_guard_until_msec = Time.get_ticks_msec() + CLASS_SELECT_POINTER_GUARD_MSEC if guard_pointer else -10000
	_reset_touch_inputs()
	audio.play("ui")
	queue_redraw()


func _class_select_pointer_is_guarded() -> bool:
	return Time.get_ticks_msec() < class_select_pointer_guard_until_msec


func _is_touch_scheme() -> bool:
	return input_scheme == InputScheme.TOUCH


func _needs_landscape_rotation() -> bool:
	return _is_touch_scheme() and screen_size.y > screen_size.x


func _toggle_language() -> void:
	language = "en" if language != "en" else "zh_TW"
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.setItem('infinite_legion_language', '%s'); } catch (_) {}" % language)
	queue_redraw()


func _localized(text: String) -> String:
	return GameLocalization.translate(text, language)


func _initialize_cheat_input() -> void:
	cheat_input = LineEdit.new()
	cheat_input.name = "CheatCodeInput"
	cheat_input.visible = false
	cheat_input.max_length = 64
	cheat_input.placeholder_text = "gold coins / full upgrade / change"
	cheat_input.select_all_on_focus = true
	cheat_input.virtual_keyboard_enabled = true
	cheat_input.add_theme_font_override("font", ui_font)
	cheat_input.add_theme_font_size_override("font_size", 22)
	cheat_input.add_theme_color_override("font_color", Color("F5FAFF"))
	cheat_input.add_theme_color_override("caret_color", GOLD)
	cheat_input.add_theme_color_override("font_placeholder_color", Color("90A7B5"))
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.025, 0.045, 0.06, 0.98)
	normal_style.border_color = Color("6B95A8")
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 16.0
	normal_style.content_margin_right = 16.0
	cheat_input.add_theme_stylebox_override("normal", normal_style)
	var focus_style := normal_style.duplicate()
	focus_style.border_color = GOLD
	focus_style.set_border_width_all(3)
	cheat_input.add_theme_stylebox_override("focus", focus_style)
	cheat_input.text_submitted.connect(_on_cheat_code_submitted)
	add_child(cheat_input)
	_layout_cheat_input()


func _layout_cheat_input() -> void:
	if cheat_input == null:
		return
	var width := minf(660.0, maxf(300.0, screen_size.x - 80.0))
	var height := 62.0 if _is_touch_scheme() else 54.0
	cheat_input.position = Vector2((screen_size.x - width) * 0.5, screen_size.y * 0.5 - 8.0)
	cheat_input.size = Vector2(width, height)


func _open_cheat_input() -> void:
	if mode != GameMode.PLAYING:
		return
	active_panel = ""
	attack_held = false
	cheat_input_active = true
	cheat_input.text = ""
	cheat_input.visible = true
	_layout_cheat_input()
	cheat_input.grab_focus()
	queue_redraw()


func _close_cheat_input() -> void:
	cheat_input_active = false
	if cheat_input != null:
		cheat_input.visible = false
		cheat_input.release_focus()
	queue_redraw()


func _on_cheat_code_submitted(raw_code: String) -> void:
	var parts := raw_code.strip_edges().to_lower().split(" ", false)
	var code := " ".join(parts)
	_close_cheat_input()
	match code:
		"gold coins":
			player["money"] = int(player.get("money", 0)) + 100000
			_add_notification("作弊碼成功：+100000 金幣", GOLD, 3.0)
			audio.play("coin", 0.75)
		"full upgrade":
			_apply_full_hero_upgrade()
		"change":
			class_change_pending = true
			_enter_class_select(true)
		_:
			_add_notification("無效的作弊碼。", Color("FF857A"), 2.2)
			audio.play("warning", 0.45)
	queue_redraw()


func _apply_full_hero_upgrade() -> void:
	if str(player.get("class_id", "")).is_empty():
		return
	player["level"] = HERO_LEVEL_CAP
	player["xp"] = 0
	player["xp_need"] = GameConfig.xp_needed(HERO_LEVEL_CAP)
	player["upgrades"] = {"attack": 20, "defense": 20, "max_hp": 20, "speed": 12, "attack_speed": 15}
	player["skill_points"] = 0
	_rebuild_player_class_stats(str(player["class_id"]), false)
	player["hp"] = float(player["max_hp"])
	player["attack_cd"] = 0.0
	player["special_cd"] = 0.0
	_spawn_effect("level_up", player["pos"], GOLD, 1.6)
	_add_notification("作弊碼成功：英雄已達滿級；士兵強化未變更。", GOLD, 4.0)
	audio.play("level_up", 0.95)


func _rebuild_player_class_stats(class_id: String, preserve_hp_ratio: bool = true) -> void:
	if not GameConfig.HERO_CLASSES.has(class_id):
		return
	var previous_ratio := clampf(float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0))), 0.01, 1.0)
	var class_data: Dictionary = GameConfig.HERO_CLASSES[class_id]
	var stats: Dictionary = class_data["base_stats"]
	var growth: Dictionary = class_data["attack_growth"]
	var gained_levels := maxi(0, int(player.get("level", 1)) - 1)
	var upgrades: Dictionary = Dictionary(player.get("upgrades", {}))
	var base_max_hp := float(stats["hp"]) + float(growth["hp"]) * float(gained_levels)
	player["class_id"] = class_id
	player["max_hp"] = base_max_hp * pow(1.08, float(int(upgrades.get("max_hp", 0))))
	player["attack"] = float(stats["attack"]) + float(growth["attack"]) * float(gained_levels)
	player["defense"] = float(stats["defense"]) + float(growth["defense"]) * float(gained_levels)
	player["speed"] = (float(stats["speed"]) + float(growth["speed"]) * float(gained_levels)) * 1.65
	player["attack_rate"] = float(class_data["normal_attack"]["attack_speed"])
	player["hp"] = float(player["max_hp"]) * previous_ratio if preserve_hp_ratio else float(player["max_hp"])
	player["facing"] = Vector2(player.get("facing", Vector2.RIGHT))


func _change_player_class(class_id: String) -> void:
	if not class_change_pending or not GameConfig.HERO_CLASSES.has(class_id):
		return
	var previous_class := str(player.get("class_id", ""))
	_rebuild_player_class_stats(class_id, true)
	player["attack_cd"] = 0.0
	player["special_cd"] = 0.0
	class_change_pending = false
	mode = GameMode.PLAYING
	active_panel = ""
	_reset_touch_inputs()
	_add_notification("職業已由 %s 切換為 %s；遠征進度已保留。" % [str(GameConfig.HERO_CLASSES[previous_class]["name"]), str(GameConfig.HERO_CLASSES[class_id]["name"])], FRIEND_BLUE, 4.0)
	_spawn_effect("level_up", player["pos"], Color(GameConfig.HERO_CLASSES[class_id]["color"]), 1.1)
	audio.play("level_up", 0.75)


func _setup_web_bridge() -> void:
	if not OS.has_feature("web"):
		return
	var window: Variant = JavaScriptBridge.get_interface("window")
	if window == null:
		return
	_web_render_callback = JavaScriptBridge.create_callback(Callable(self, "_web_render_game_to_text"))
	_web_advance_callback = JavaScriptBridge.create_callback(Callable(self, "_web_advance_time"))
	window.__codex_render_game_to_text = _web_render_callback
	window.__codex_advance_time = _web_advance_callback
	var allow_test_showcases := bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('codex_test') === '1'", true))
	if allow_test_showcases:
		_web_force_boss_callback = JavaScriptBridge.create_callback(Callable(self, "_web_force_boss_for_test"))
		_web_touch_mode_callback = JavaScriptBridge.create_callback(Callable(self, "_web_set_touch_mode_for_test"))
		_web_force_recruit_callback = JavaScriptBridge.create_callback(Callable(self, "_web_force_recruit_showcase_for_test"))
		_web_heavy_cannon_showcase_callback = JavaScriptBridge.create_callback(Callable(self, "_web_force_heavy_cannon_combat_showcase_for_test"))
		_web_chaos_showcase_callback = JavaScriptBridge.create_callback(Callable(self, "_web_force_chaos_showcase_for_test"))
		_web_aionis_showcase_callback = JavaScriptBridge.create_callback(Callable(self, "_web_force_aionis_showcase_for_test"))
		window.__codex_force_world_boss_for_test = _web_force_boss_callback
		window.__codex_set_touch_mode_for_test = _web_touch_mode_callback
		window.__codex_force_recruit_showcase_for_test = _web_force_recruit_callback
		window.__codex_force_heavy_cannon_combat_showcase_for_test = _web_heavy_cannon_showcase_callback
		window.__codex_force_chaos_showcase_for_test = _web_chaos_showcase_callback
		window.__codex_force_aionis_showcase_for_test = _web_aionis_showcase_callback
		var auto_chaos_scene: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('chaos_scene') || ''", true)
		if typeof(auto_chaos_scene) == TYPE_STRING and str(auto_chaos_scene) in ["battle", "ending", "pause", "recruit"]:
			var auto_touch: bool = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('touch') === '1'", true))
			var auto_language: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('lang') || 'zh_TW'", true)
			var auto_skill: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('skill') || 'total_annihilation'", true)
			call_deferred("_web_force_chaos_showcase_for_test", [str(auto_chaos_scene), auto_touch, str(auto_language), str(auto_skill)])
		var auto_aionis_scene: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('aionis_scene') || ''", true)
		if typeof(auto_aionis_scene) == TYPE_STRING and str(auto_aionis_scene) in ["battle", "anchors", "combo2", "combo3", "pause", "gate", "marker", "marker_locked"]:
			var aionis_touch: bool = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('touch') === '1'", true))
			var aionis_language: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('lang') || 'zh_TW'", true)
			var aionis_skill: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('skill') || 'twelfth_bell'", true)
			var aionis_phase: int = int(JavaScriptBridge.eval("Number(new URLSearchParams(window.location.search).get('phase') || 4)", true))
			var aionis_exposed: bool = bool(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('anchor_state') === 'exposed'", true))
			call_deferred("_web_force_aionis_showcase_for_test", [str(auto_aionis_scene), aionis_touch, str(aionis_language), str(aionis_skill), aionis_phase, aionis_exposed])
	window.__codex_game_state = render_game_to_text()
	# JavaScriptBridge callbacks always return null. These small wrappers publish
	# the state through a window property so browser automation receives a string.
	JavaScriptBridge.eval("""
		(() => {
			window.render_game_to_text = () => {
				window.__codex_render_game_to_text();
				return window.__codex_game_state || "";
			};
			window.advanceTime = (milliseconds) => {
				window.__codex_advance_time(milliseconds);
				return window.__codex_game_state || "";
			};
			if (typeof window.__codex_force_world_boss_for_test === "function") {
				window.force_world_boss_for_test = () => {
					window.__codex_force_world_boss_for_test();
					try {
						const state = JSON.parse(window.__codex_game_state || "{}");
						return Boolean(state.boss && String(state.boss.active_lair_id || "").startsWith("python_boss_lair_"));
					} catch (_) {
						return false;
					}
				};
				window.set_touch_mode_for_test = (enabled) => {
					window.__codex_set_touch_mode_for_test(Boolean(enabled));
					return window.__codex_game_state || "";
				};
				window.force_recruit_showcase_for_test = (touchMode = false, requestedLanguage = "zh_TW") => {
					window.__codex_force_recruit_showcase_for_test(Boolean(touchMode), String(requestedLanguage));
					return window.__codex_game_state || "";
				};
				window.force_heavy_cannon_combat_showcase_for_test = (phase = "shell", touchMode = false, requestedLanguage = "zh_TW") => {
					window.__codex_force_heavy_cannon_combat_showcase_for_test(String(phase), Boolean(touchMode), String(requestedLanguage));
					return window.__codex_game_state || "";
				};
				window.force_chaos_showcase_for_test = (scene = "battle", touchMode = false, requestedLanguage = "zh_TW", skill = "total_annihilation") => {
					window.__codex_force_chaos_showcase_for_test(String(scene), Boolean(touchMode), String(requestedLanguage), String(skill));
					return window.__codex_game_state || "";
				};
				window.force_aionis_showcase_for_test = (scene = "battle", touchMode = false, requestedLanguage = "zh_TW", skill = "twelfth_bell", phase = 4, exposed = false) => {
					window.__codex_force_aionis_showcase_for_test(String(scene), Boolean(touchMode), String(requestedLanguage), String(skill), Number(phase), Boolean(exposed));
					return window.__codex_game_state || "";
				};
			}
		})();
	""", true)


func _publish_web_game_state(state: String) -> void:
	if not OS.has_feature("web"):
		return
	var window: Variant = JavaScriptBridge.get_interface("window")
	if window != null:
		window.__codex_game_state = state


func _web_render_game_to_text(_arguments: Array) -> String:
	var state := render_game_to_text()
	_publish_web_game_state(state)
	return state


func _web_advance_time(arguments: Array) -> String:
	var milliseconds := 16.6667
	if not arguments.is_empty() and typeof(arguments[0]) in [TYPE_INT, TYPE_FLOAT]:
		milliseconds = clampf(float(arguments[0]), 0.0, 5000.0)
	var steps := maxi(1, int(round(milliseconds / (FIXED_STEP * 1000.0))))
	_web_manual_time_hold = maxf(_web_manual_time_hold, 0.12)
	for _step in steps:
		_simulate_game(FIXED_STEP)
		_update_camera(FIXED_STEP)
	queue_redraw()
	var state := render_game_to_text()
	_publish_web_game_state(state)
	return state


func _web_force_boss_for_test(_arguments: Array) -> bool:
	_start_new_game("warrior", true)
	player["level"] = 10
	player["xp_need"] = GameConfig.xp_needed(10)
	player["money"] = 5000
	# Browser QA uses a real procedural satellite lair, proving that those map
	# markers now deploy the exact same Saga controller instead of a placeholder.
	var lair_chunk: Dictionary = world_generator.generate_chunk(Vector2i(3, 2))
	var lair_value: Variant = lair_chunk.get("snake_nest")
	if typeof(lair_value) != TYPE_DICTIONARY:
		return false
	var lair_descriptor: Dictionary = Dictionary(lair_value)
	var home: Vector2 = Vector2(lair_descriptor["position"])
	player["pos"] = home + Vector2(-330.0, 35.0)
	player["facing"] = Vector2.RIGHT
	player["hp"] = player["max_hp"]
	_last_active_center = Vector2i(999999, 999999)
	_update_active_chunks(true)
	_register_snake_nest(lair_descriptor)
	castles.clear()
	camps.clear()
	enemies.clear()
	soldiers.clear()
	var showcase_types := GameConfig.SOLDIER_ORDER
	for index in showcase_types.size():
		var angle := TAU * float(index) / float(showcase_types.size())
		_spawn_soldier(str(showcase_types[index]), Vector2(player["pos"]) + Vector2.from_angle(angle) * 78.0)
	if not _activate_python_boss_lair(str(lair_descriptor["id"]), true):
		return false
	python_boss.force_engage()
	camera_pos = home + Vector2(-120.0, 20.0)
	camera_target = camera_pos
	active_panel = ""
	mode = GameMode.PLAYING
	_web_manual_time_hold = 5.0
	queue_redraw()
	_publish_web_game_state(render_game_to_text())
	return true


func _web_set_touch_mode_for_test(arguments: Array) -> bool:
	var enabled := true
	if not arguments.is_empty() and typeof(arguments[0]) == TYPE_BOOL:
		enabled = bool(arguments[0])
	_set_input_scheme(InputScheme.TOUCH if enabled else InputScheme.KEYBOARD_MOUSE)
	_reset_touch_inputs()
	_publish_web_game_state(render_game_to_text())
	return true


func _web_force_recruit_showcase_for_test(arguments: Array) -> bool:
	var use_touch := bool(arguments[0]) if not arguments.is_empty() and typeof(arguments[0]) == TYPE_BOOL else false
	var requested_language := str(arguments[1]) if arguments.size() > 1 else "zh_TW"
	_start_new_game("warrior", true)
	player["level"] = 24
	player["xp_need"] = GameConfig.xp_needed(24)
	player["money"] = 12000
	player["pos"] = HOUSE_POS + Vector2(0, 145)
	player["facing"] = Vector2.RIGHT
	recruit_anchor = HOUSE_POS
	soldiers.clear()
	enemies.clear()
	projectiles.clear()
	hazards.clear()
	for recruit_index in ["cannon", "musketeer", "rifleman", "tank", "rocket"].size():
		var recruit_type := str(["cannon", "musketeer", "rifleman", "tank", "rocket"][recruit_index])
		var recruit_pos := Vector2(player["pos"]) + Vector2(-300.0 + float(recruit_index) * 150.0, 95.0 + absf(float(recruit_index) - 2.0) * 32.0)
		var recruit_id := _spawn_soldier(recruit_type, recruit_pos)
		var recruit_unit: Variant = _find_soldier_by_id(recruit_id)
		if recruit_unit != null: recruit_unit["aim_dir"] = Vector2(0.95, -0.30).normalized()
	language = requested_language if requested_language in ["zh_TW", "en"] else "zh_TW"
	_set_input_scheme(InputScheme.TOUCH if use_touch else InputScheme.KEYBOARD_MOUSE)
	_reset_touch_inputs()
	active_panel = "recruit"
	mode = GameMode.PLAYING
	camera_pos = player["pos"]
	camera_target = camera_pos
	notifications.clear()
	_add_notification("玩家科技招募：重型大砲傷害 112 ＞ 普通大砲傷害 72", Color("C9EDFF"), 5.0)
	queue_redraw()
	_publish_web_game_state(render_game_to_text())
	return true


func _web_force_heavy_cannon_combat_showcase_for_test(arguments: Array) -> bool:
	var phase := str(arguments[0]) if not arguments.is_empty() else "shell"
	if phase not in ["charge", "shell", "impact"]:
		phase = "shell"
	var use_touch := bool(arguments[1]) if arguments.size() > 1 and typeof(arguments[1]) == TYPE_BOOL else false
	var requested_language := str(arguments[2]) if arguments.size() > 2 else "zh_TW"
	_start_new_game("warrior", true)
	player["level"] = 24
	player["xp_need"] = GameConfig.xp_needed(24)
	player["money"] = 12000
	var ordinary_position := HOUSE_POS + Vector2(100.0, 720.0)
	var heavy_position := ordinary_position + Vector2(-360.0, 40.0)
	player["pos"] = ordinary_position + (Vector2(-300.0, 150.0) if use_touch else Vector2(-430.0, 115.0))
	player["facing"] = Vector2.RIGHT
	castles.clear()
	camps.clear()
	snake_nests.clear()
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	hazards.clear()
	upgrade_effects.clear()
	soldier_boss_debuffs.clear()
	soldier_upgrade_shared_cooldowns.clear()
	soldier_research = SoldierUpgradeCatalog.create_empty_research()
	soldier_upgrade_type_index = 0
	soldier_upgrade_category = "base"
	soldier_upgrade_page = 0
	particles.clear()
	floaters.clear()
	spawned_chunks.clear()
	chunk_states.clear()
	pending_chunk_spawns.clear()
	for active_key in active_chunks.keys():
		spawned_chunks[str(active_key)] = true
	_last_active_center = world_generator.world_to_chunk(player["pos"])
	_last_boss_active_center = Vector2i(999999, 999999)
	_boss_chunks_pinned_last = false
	python_boss = null
	var ordinary_id := _spawn_enemy("cannon", ordinary_position, 1, ordinary_position)
	var heavy_id := _spawn_soldier("cannon", heavy_position)
	var ordinary_cannon: Variant = _find_enemy_by_id(ordinary_id)
	var heavy_cannon: Variant = _find_soldier_by_id(heavy_id)
	if ordinary_cannon == null or heavy_cannon == null:
		return false
	ordinary_cannon["aim_dir"] = Vector2.LEFT
	ordinary_cannon["state"] = "aim"
	ordinary_cannon["cooldown"] = 99.0
	heavy_cannon["aim_dir"] = Vector2.RIGHT
	heavy_cannon["target_id"] = ordinary_id
	heavy_cannon["state"] = "charge" if phase == "charge" else "attack"
	heavy_cannon["cooldown"] = 99.0
	heavy_cannon["charge"] = 0.82 if phase == "charge" else 0.0
	soldier_command = "攻擊"
	command_target_id = ordinary_id
	command_point = ordinary_position
	if phase in ["shell", "impact"]:
		_fire_soldier_attack(heavy_cannon, ordinary_id)
		_update_projectiles(0.32 if phase == "shell" else 0.75)
		if phase == "impact":
			_update_visuals(0.09)
	# Keep both cannons clear of the compact top-row controls and touch sticks.
	camera_pos = ordinary_position + (Vector2(-110.0, -52.0) if use_touch else Vector2(-50.0, 18.0))
	camera_target = camera_pos
	camera_shake = 0.0
	camera_shake_offset = Vector2.ZERO
	tutorial_visible = false
	language = requested_language if requested_language in ["zh_TW", "en"] else "zh_TW"
	_set_input_scheme(InputScheme.TOUCH if use_touch else InputScheme.KEYBOARD_MOUSE)
	_reset_touch_inputs()
	active_panel = ""
	mode = GameMode.PLAYING
	notifications.clear()
	_add_notification("實戰比較：重型大砲 112 傷害 ＞ 普通大砲 72 傷害", Color("C9EDFF"), 5.0)
	_web_manual_time_hold = 5.0
	queue_redraw()
	_publish_web_game_state(render_game_to_text())
	return true


func _web_force_chaos_showcase_for_test(arguments: Array) -> bool:
	var scene := str(arguments[0]) if not arguments.is_empty() else "battle"
	var use_touch := bool(arguments[1]) if arguments.size() > 1 and typeof(arguments[1]) == TYPE_BOOL else false
	var requested_language := str(arguments[2]) if arguments.size() > 2 else "zh_TW"
	var requested_skill := str(arguments[3]) if arguments.size() > 3 else "total_annihilation"
	if scene not in ["battle", "ending", "pause", "recruit"]:
		scene = "battle"
	if requested_skill not in ChaosBossControllerScript.SKILL_IDS:
		requested_skill = "total_annihilation"
	_start_new_game("warrior", true)
	language = requested_language if requested_language in ["zh_TW", "en"] else "zh_TW"
	_set_input_scheme(InputScheme.TOUCH if use_touch else InputScheme.KEYBOARD_MOUSE)
	_reset_touch_inputs()
	all_soldiers_unlocked = true
	player["level"] = 60
	player["xp_need"] = GameConfig.xp_needed(60)
	player["money"] = 99999
	player["max_hp"] = 8200.0
	player["hp"] = 8200.0
	player["attack"] = 680.0
	player["defense"] = 140.0
	player["attack_rate"] = 6.0
	player["upgrades"] = {"attack": 20, "defense": 20, "max_hp": 20, "speed": 12, "attack_speed": 15}
	notifications.clear()
	if scene == "ending":
		final_boss_defeated = true
		ending_seen = false
		ending_pending = false
		ending_elapsed = 6.75
		mode = GameMode.ENDING
		active_panel = ""
	elif scene == "pause":
		chaos_boss.receive_hit(9999999.0, "qa:0", Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"]), "true")
		final_boss_defeated = true
		ending_seen = true
		ending_pending = false
		mode = GameMode.PAUSED
		active_panel = ""
	elif scene == "recruit":
		player["pos"] = HOUSE_POS + Vector2(0.0, 145.0)
		recruit_anchor = HOUSE_POS
		camera_pos = player["pos"]
		camera_target = camera_pos
		active_panel = "recruit"
		mode = GameMode.PLAYING
	else:
		var home := Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"])
		player["pos"] = home + Vector2(-390.0, 48.0)
		player["facing"] = Vector2.RIGHT
		camera_pos = home + Vector2(-75.0, 10.0)
		camera_target = camera_pos
		_last_active_center = Vector2i(999999, 999999)
		_update_active_chunks(true)
		castles.clear()
		camps.clear()
		enemies.clear()
		soldiers.clear()
		projectiles.clear()
		hazards.clear()
		particles.clear()
		floaters.clear()
		_initialize_chaos_boss(true)
		var showcase_types := ["tank", "rocket", "gatling", "helicopter", "bomber", "ufo"]
		for showcase_index in showcase_types.size():
			var showcase_angle := PI + lerpf(-0.78, 0.78, float(showcase_index) / float(maxi(1, showcase_types.size() - 1)))
			var showcase_pos := Vector2(player["pos"]) + Vector2.from_angle(showcase_angle) * (92.0 + float(showcase_index % 2) * 48.0)
			_spawn_soldier(str(showcase_types[showcase_index]), showcase_pos)
		chaos_boss.debug_set_hp_ratio(0.22)
		chaos_boss.force_engage(Vector2(player["pos"]))
		chaos_boss.debug_force_skill(requested_skill)
		_update_chaos_boss(0.05)
		mode = GameMode.PLAYING
		active_panel = ""
		_add_notification("終局 Boss：十種技能均有明確預警與實際傷害。", Color("F1C6FF"), 5.0)
	_web_manual_time_hold = 5.0
	queue_redraw()
	_publish_web_game_state(render_game_to_text())
	return true


func _web_force_aionis_showcase_for_test(arguments: Array) -> bool:
	var scene := str(arguments[0]) if not arguments.is_empty() else "battle"
	var use_touch := bool(arguments[1]) if arguments.size() > 1 and typeof(arguments[1]) == TYPE_BOOL else false
	var requested_language := str(arguments[2]) if arguments.size() > 2 else "zh_TW"
	var requested_skill := str(arguments[3]) if arguments.size() > 3 else "twelfth_bell"
	var requested_phase := clampi(int(arguments[4]) if arguments.size() > 4 else 4, 1, 4)
	var expose_anchors := bool(arguments[5]) if arguments.size() > 5 and typeof(arguments[5]) == TYPE_BOOL else false
	if scene not in ["battle", "anchors", "combo2", "combo3", "pause", "gate", "marker", "marker_locked"]:
		scene = "battle"
	var marker_scene := scene in ["marker", "marker_locked"]
	if requested_skill not in AionisBossControllerScript.SKILL_IDS:
		requested_skill = "twelfth_bell"
	_start_new_game("warrior", true)
	_web_test_showcase_active = true
	language = requested_language if requested_language in ["zh_TW", "en"] else "zh_TW"
	_set_input_scheme(InputScheme.TOUCH if use_touch else InputScheme.KEYBOARD_MOUSE)
	_reset_touch_inputs()
	all_soldiers_unlocked = scene != "marker_locked"
	timeless_gate_unlocked = scene != "marker_locked"
	kaeron_ending_completed = scene != "marker_locked"
	ending_seen = scene != "marker_locked"
	player["level"] = 80
	player["xp_need"] = GameConfig.xp_needed(80)
	player["money"] = 99999
	player["max_hp"] = 16000.0
	player["hp"] = 16000.0
	player["attack"] = 940.0
	player["defense"] = 190.0
	player["attack_rate"] = 7.0
	player["upgrades"] = {"attack": 20, "defense": 20, "max_hp": 20, "speed": 12, "attack_speed": 15}
	var home := Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"])
	player["pos"] = HOUSE_POS if marker_scene else home + Vector2(-470.0, 110.0)
	player["facing"] = Vector2.RIGHT
	camera_pos = HOUSE_POS if marker_scene else home + Vector2(-55.0, 6.0)
	camera_target = camera_pos
	_last_active_center = Vector2i(999999, 999999)
	_update_active_chunks(true)
	castles.clear()
	camps.clear()
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	hazards.clear()
	particles.clear()
	floaters.clear()
	aionis_runtime_projectiles.clear()
	aionis_runtime_hazards.clear()
	_initialize_aionis_boss(true)
	aionis_boss_defeated = false
	if marker_scene:
		mode = GameMode.PLAYING
	elif scene == "pause":
		var showcase_types := ["tank", "rocket", "gatling", "helicopter", "bomber", "ufo"]
		for showcase_index in showcase_types.size():
			var angle := PI + lerpf(-0.88, 0.88, float(showcase_index) / float(maxi(1, showcase_types.size() - 1)))
			_spawn_soldier(str(showcase_types[showcase_index]), Vector2(player["pos"]) + Vector2.from_angle(angle) * (94.0 + float(showcase_index % 2) * 45.0))
		var phase_ratios := [0.92, 0.70, 0.45, 0.18]
		aionis_boss.debug_set_hp_ratio(float(phase_ratios[requested_phase - 1]))
		aionis_boss.force_engage(Vector2(player["pos"]))
		var defeat_result: Dictionary = aionis_boss.receive_hit(9999999.0, "qa:0", home, "true")
		_consume_aionis_hit_result(defeat_result)
		aionis_boss_defeated = true
		mode = GameMode.PAUSED
	else:
		var showcase_types := ["tank", "rocket", "gatling", "helicopter", "bomber", "ufo"]
		for showcase_index in showcase_types.size():
			var angle := PI + lerpf(-0.88, 0.88, float(showcase_index) / float(maxi(1, showcase_types.size() - 1)))
			_spawn_soldier(str(showcase_types[showcase_index]), Vector2(player["pos"]) + Vector2.from_angle(angle) * (94.0 + float(showcase_index % 2) * 45.0))
		var phase_ratios := [0.92, 0.70, 0.45, 0.18]
		aionis_boss.debug_set_hp_ratio(float(phase_ratios[requested_phase - 1]))
		aionis_boss.force_engage(Vector2(player["pos"]))
		if scene == "gate":
			mode = GameMode.PLAYING
		elif scene == "anchors":
			if requested_phase < 2:
				aionis_boss.debug_set_hp_ratio(0.70)
			if expose_anchors:
				for anchor in aionis_boss.get_anchor_targets():
					_consume_aionis_hit_result(aionis_boss.receive_anchor_hit(str(anchor["id"]), 99999.0, "qa:0"))
			mode = GameMode.PLAYING
		elif scene == "combo2":
			aionis_boss.debug_set_hp_ratio(0.45)
			aionis_boss.debug_force_combo(["chrono_prison", "star_gate_barrage"])
			_update_aionis_boss(0.05)
			mode = GameMode.PLAYING
		elif scene == "combo3":
			aionis_boss.debug_set_hp_ratio(0.18)
			aionis_boss.debug_force_combo(["rift_board", "causal_mirror", "twelfth_bell"])
			_update_aionis_boss(0.05)
			mode = GameMode.PLAYING
		else:
			aionis_boss.debug_force_skill(requested_skill)
			_update_aionis_boss(0.05)
			mode = GameMode.PLAYING
	active_panel = "map" if marker_scene else ""
	notifications.clear()
	if scene != "pause" and not marker_scene:
		_add_notification("超終局 Boss：四階段、四座時間錨、十種高壓技能。", Color("F4C95D"), 5.0)
	_web_manual_time_hold = 5.0
	queue_redraw()
	_publish_web_game_state(render_game_to_text())
	return true


func render_game_to_text() -> String:
	var mode_names := ["title", "class_select", "playing", "paused", "dead", "ending"]
	var player_position: Vector2 = Vector2(player.get("pos", HOUSE_POS))
	var visible_enemies: Array[Dictionary] = []
	for enemy in enemies:
		if player_position.distance_to(enemy["pos"]) <= 900.0:
			visible_enemies.append({
				"id": int(enemy["id"]),
				"type": str(enemy["type"]),
				"x": snappedf(float(Vector2(enemy["pos"]).x), 0.1),
				"y": snappedf(float(Vector2(enemy["pos"]).y), 0.1),
				"hp": snappedf(float(enemy["hp"]), 0.1),
				"max_hp": snappedf(float(enemy["max_hp"]), 0.1),
				"attack": snappedf(float(enemy["attack"]), 0.1),
				"state": str(enemy["state"]),
				"source_castle_level": int(Dictionary(enemy.get("enhancement", {})).get("castle_level", 0)),
				"enhancement_points": int(enemy.get("enhancement_points", 0)),
				"enhancements": Dictionary(enemy.get("enhancement", {})).get("tracks", {}).duplicate(true),
				"enhancement_summary": EnemyEnhancementCatalog.summary(Dictionary(enemy.get("enhancement", {})), language),
			})
	var visible_soldiers: Array[Dictionary] = []
	for soldier in soldiers:
		if player_position.distance_to(soldier["pos"]) <= 900.0:
			var active_special_ids: Array[String] = []
			var soldier_snapshot: Dictionary = Dictionary(soldier.get("upgrade_snapshot", {}))
			for special_value in Array(soldier_snapshot.get("active_specials", [])):
				if special_value is Dictionary:
					active_special_ids.append(str(Dictionary(special_value).get("id", "")))
			visible_soldiers.append({
				"id": int(soldier["id"]),
				"type": str(soldier["type"]),
				"x": snappedf(float(Vector2(soldier["pos"]).x), 0.1),
				"y": snappedf(float(Vector2(soldier["pos"]).y), 0.1),
				"hp": snappedf(float(soldier["hp"]), 0.1),
				"max_hp": snappedf(float(soldier["max_hp"]), 0.1),
				"attack": snappedf(float(soldier["attack"]), 0.1),
				"charge": snappedf(float(soldier.get("charge", 0.0)), 0.01),
				"state": str(soldier["state"]),
				"specials": active_special_ids,
			})
	var visible_projectiles: Array[Dictionary] = []
	for projectile in projectiles:
		if visible_projectiles.size() >= 24:
			break
		if player_position.distance_to(projectile["pos"]) <= 1200.0:
			visible_projectiles.append({
				"kind": str(projectile["kind"]),
				"team": str(projectile["team"]),
				"source_kind": str(projectile.get("source_kind", "")),
				"damage": snappedf(float(projectile["damage"]), 0.1),
				"x": snappedf(float(Vector2(projectile["pos"]).x), 0.1),
				"y": snappedf(float(Vector2(projectile["pos"]).y), 0.1),
			})
	var visible_castles: Array[Dictionary] = []
	for castle in castles.values():
		if player_position.distance_to(castle["pos"]) <= 1200.0:
			visible_castles.append({
				"id": str(castle["id"]), "level": int(castle["level"]),
				"x": snappedf(float(Vector2(castle["pos"]).x), 0.1), "y": snappedf(float(Vector2(castle["pos"]).y), 0.1),
				"hp": snappedf(float(castle["hp"]), 0.1), "max_hp": snappedf(float(castle["max_hp"]), 0.1),
				"wall_hp": snappedf(float(castle.get("wall_hp", 0.0)), 0.1),
				"wall_max_hp": snappedf(float(castle.get("wall_max_hp", 0.0)), 0.1),
				"wall_breached": bool(castle.get("wall_breached", true)), "owned": bool(castle["owned"]),
			})
	var aionis_home := Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"])
	var aionis_delta := aionis_home - player_position
	var aionis_direction := aionis_delta.normalized() if aionis_delta.length_squared() > 0.001 else Vector2.ZERO
	var aionis_marker_defeated: bool = aionis_boss_defeated or (aionis_boss != null and bool(aionis_boss.is_defeated()))
	var aionis_marker_engaged: bool = aionis_boss != null and bool(aionis_boss.is_engaged())
	var touch_utility_rects := _touch_utility_rects()
	var touch_upgrade_test_rect := Rect2(touch_utility_rects.get("upgrades", Rect2()))
	var touch_scale := maxf(0.001, touch_ui_coordinate_scale)
	var touch_radius := TOUCH_STICK_RADIUS * touch_scale
	var touch_move_rect := Rect2(_touch_move_center() - Vector2.ONE * touch_radius, Vector2.ONE * touch_radius * 2.0)
	var touch_attack_rect := Rect2(_touch_aim_center() - Vector2.ONE * touch_radius, Vector2.ONE * touch_radius * 2.0)
	var touch_special_button_rect := _touch_special_rect()
	var touch_recruit_enabled := player_position.distance_to(HOUSE_POS) <= 185.0
	if not touch_recruit_enabled:
		for castle_value in castles.values():
			var recruit_castle: Dictionary = Dictionary(castle_value)
			if bool(recruit_castle.get("owned", false)) and player_position.distance_to(Vector2(recruit_castle.get("pos", Vector2.ZERO))) <= 210.0:
				touch_recruit_enabled = true
				break
	var touch_utility_state := {}
	for action_value in touch_utility_rects.keys():
		var action := str(action_value)
		var action_rect := Rect2(touch_utility_rects[action])
		touch_utility_state[action] = {
			"x": snappedf(action_rect.position.x, 0.1),
			"y": snappedf(action_rect.position.y, 0.1),
			"width": snappedf(action_rect.size.x, 0.1),
			"height": snappedf(action_rect.size.y, 0.1),
			"enabled": action != "recruit" or touch_recruit_enabled,
		}
	var touch_close_rect := _touch_panel_close_rect()
	var touch_recruit_controls: Array[Dictionary] = []
	if _is_touch_scheme() and active_panel == "recruit":
		var recruit_panel := _recruit_panel_rect()
		var recruit_roster := _recruitable_soldier_order()
		for recruit_index in recruit_roster.size():
			var recruit_rect := _recruit_buy_rect(recruit_index, recruit_panel)
			touch_recruit_controls.append({
				"type": str(recruit_roster[recruit_index]),
				"x": snappedf(recruit_rect.position.x, 0.1),
				"y": snappedf(recruit_rect.position.y, 0.1),
				"width": snappedf(recruit_rect.size.x, 0.1),
				"height": snappedf(recruit_rect.size.y, 0.1),
			})
	var touch_command_controls: Array[Dictionary] = []
	if _is_touch_scheme() and active_panel == "command":
		var command_panel := _command_panel_rect()
		var command_names := ["跟隨", "防守", "攻擊", "撤退", "駐守", "攻城"]
		for command_index in command_names.size():
			var command_rect := _command_button_rect(command_index, command_panel)
			touch_command_controls.append({
				"command": str(command_names[command_index]),
				"x": snappedf(command_rect.position.x, 0.1),
				"y": snappedf(command_rect.position.y, 0.1),
				"width": snappedf(command_rect.size.x, 0.1),
				"height": snappedf(command_rect.size.y, 0.1),
			})
	var touch_pause_controls: Array[Dictionary] = []
	var touch_pause_language := {}
	var touch_pause_volume := {}
	if _is_touch_scheme() and mode == GameMode.PAUSED:
		var pause_action_names := _pause_actions()
		for pause_index in pause_action_names.size():
			var pause_rect := _pause_button_rect(pause_index)
			touch_pause_controls.append({
				"action": str(pause_action_names[pause_index]),
				"x": snappedf(pause_rect.position.x, 0.1),
				"y": snappedf(pause_rect.position.y, 0.1),
				"width": snappedf(pause_rect.size.x, 0.1),
				"height": snappedf(pause_rect.size.y, 0.1),
			})
		var pause_language_rect := _pause_language_rect()
		touch_pause_language = {
			"x": snappedf(pause_language_rect.position.x, 0.1), "y": snappedf(pause_language_rect.position.y, 0.1),
			"width": snappedf(pause_language_rect.size.x, 0.1), "height": snappedf(pause_language_rect.size.y, 0.1),
		}
		for volume_action in ["down", "mute", "up"]:
			var volume_rect := _pause_volume_rect(str(volume_action))
			touch_pause_volume[str(volume_action)] = {
				"x": snappedf(volume_rect.position.x, 0.1), "y": snappedf(volume_rect.position.y, 0.1),
				"width": snappedf(volume_rect.size.x, 0.1), "height": snappedf(volume_rect.size.y, 0.1),
			}
	var payload := {
		"coordinate_system": "world origin=(0,0); +x right; +y down; distances in Godot pixels",
		"mode": mode_names[clampi(mode, 0, mode_names.size() - 1)],
		"time": snappedf(game_time, 0.01),
		"panel": active_panel,
		"language": language,
		"input": {
			"scheme": "touch" if _is_touch_scheme() else "keyboard_mouse",
			"touch_capable": touch_capable,
			"logical_viewport_width": snappedf(screen_size.x, 0.1),
			"logical_viewport_height": snappedf(screen_size.y, 0.1),
			"touch_ui_coordinate_scale": snappedf(touch_ui_coordinate_scale, 0.001),
			"attack_held": attack_held if _is_touch_scheme() else false,
			"troop_upgrade_button": {
				"x": snappedf(touch_upgrade_test_rect.position.x, 0.1),
				"y": snappedf(touch_upgrade_test_rect.position.y, 0.1),
				"width": snappedf(touch_upgrade_test_rect.size.x, 0.1),
				"height": snappedf(touch_upgrade_test_rect.size.y, 0.1),
			},
			"virtual_controls": {
				"visible": _is_touch_scheme() and mode == GameMode.PLAYING and active_panel.is_empty(),
				"coordinate_space": "logical_viewport_pixels",
				"move": {
					"x": snappedf(touch_move_rect.position.x, 0.1), "y": snappedf(touch_move_rect.position.y, 0.1),
					"width": snappedf(touch_move_rect.size.x, 0.1), "height": snappedf(touch_move_rect.size.y, 0.1),
					"center_x": snappedf(_touch_move_center().x, 0.1), "center_y": snappedf(_touch_move_center().y, 0.1),
					"radius": snappedf(touch_radius, 0.1), "pointer": touch_move_pointer,
				},
				"attack": {
					"x": snappedf(touch_attack_rect.position.x, 0.1), "y": snappedf(touch_attack_rect.position.y, 0.1),
					"width": snappedf(touch_attack_rect.size.x, 0.1), "height": snappedf(touch_attack_rect.size.y, 0.1),
					"center_x": snappedf(_touch_aim_center().x, 0.1), "center_y": snappedf(_touch_aim_center().y, 0.1),
					"radius": snappedf(touch_radius, 0.1), "pointer": touch_aim_pointer, "held": attack_held,
				},
				"special": {
					"x": snappedf(touch_special_button_rect.position.x, 0.1), "y": snappedf(touch_special_button_rect.position.y, 0.1),
					"width": snappedf(touch_special_button_rect.size.x, 0.1), "height": snappedf(touch_special_button_rect.size.y, 0.1),
					"enabled": int(player.get("level", 1)) >= 10,
				},
				"utility": touch_utility_state,
				"panel_close": {
					"visible": _is_touch_scheme() and mode == GameMode.PLAYING and not active_panel.is_empty() and touch_close_rect.has_area(),
					"x": snappedf(touch_close_rect.position.x, 0.1), "y": snappedf(touch_close_rect.position.y, 0.1),
					"width": snappedf(touch_close_rect.size.x, 0.1), "height": snappedf(touch_close_rect.size.y, 0.1),
				},
				"recruit_buy": touch_recruit_controls,
				"command_buttons": touch_command_controls,
				"pause_actions": touch_pause_controls,
				"pause_language": touch_pause_language,
				"pause_volume": touch_pause_volume,
			},
			"needs_landscape_rotation": _needs_landscape_rotation(),
			"notifications_hidden": notifications_hidden,
			"move_x": snappedf(touch_move_vector.x, 0.01) if _is_touch_scheme() else 0.0,
			"move_y": snappedf(touch_move_vector.y, 0.01) if _is_touch_scheme() else 0.0,
			"aim_x": snappedf(touch_aim_vector.x, 0.01) if _is_touch_scheme() else snappedf(float(Vector2(player.get("facing", Vector2.RIGHT)).x), 0.01),
			"aim_y": snappedf(touch_aim_vector.y, 0.01) if _is_touch_scheme() else snappedf(float(Vector2(player.get("facing", Vector2.RIGHT)).y), 0.01),
		},
		"player": {
			"class": str(player.get("class_id", "")),
			"x": snappedf(player_position.x, 0.1),
			"y": snappedf(player_position.y, 0.1),
			"vx": snappedf(float(Vector2(player.get("vel", Vector2.ZERO)).x), 0.1),
			"vy": snappedf(float(Vector2(player.get("vel", Vector2.ZERO)).y), 0.1),
			"hp": snappedf(float(player.get("hp", 0.0)), 0.1),
			"max_hp": snappedf(float(player.get("max_hp", 0.0)), 0.1),
			"level": int(player.get("level", 1)),
			"money": int(player.get("money", 0)),
			"attack_cooldown": snappedf(float(player.get("attack_cd", 0.0)), 0.01),
			"special_cooldown": snappedf(float(player.get("special_cd", 0.0)), 0.01),
		},
		"army": {"command": soldier_command, "count": soldiers.size(), "limit": _army_limit(), "owned_castle_level_total": _owned_castle_level_total(), "command_castle_id": command_castle_id, "visible": visible_soldiers},
		"soldier_upgrades": {
			"catalog_schema": SoldierUpgradeCatalog.SCHEMA_VERSION,
			"special_count": SoldierUpgradeCatalog.SPECIAL_ABILITY_ORDER.size(),
			"selected_type": _selected_soldier_upgrade_type(),
			"category": soldier_upgrade_category,
			"page": soldier_upgrade_page,
			"selected_research": Dictionary(Dictionary(soldier_research.get("types", {})).get(_selected_soldier_upgrade_type(), {})).duplicate(true),
		},
		"enemies": visible_enemies,
		"projectiles": visible_projectiles,
		"castles": visible_castles,
		"hazards": hazards.size(),
		"python_boss_lairs": _snake_nest_text_state(player_position),
		"boss": _boss_text_state(),
		"chaos_boss": null if chaos_boss == null else chaos_boss.get_text_state(),
		"aionis_boss": null if aionis_boss == null else aionis_boss.get_text_state(),
		"aionis_marker": {
			"visible": true,
			"locked": not timeless_gate_unlocked,
			"status": "locked" if not timeless_gate_unlocked else ("defeated" if aionis_marker_defeated else ("engaged" if aionis_marker_engaged else "available")),
			"world_x": snappedf(aionis_home.x, 0.1),
			"world_y": snappedf(aionis_home.y, 0.1),
			"distance": snappedf(aionis_delta.length(), 0.1),
			"direction_x": snappedf(aionis_direction.x, 0.001),
			"direction_y": snappedf(aionis_direction.y, 0.001),
		},
		"pause_actions": _pause_actions() if mode == GameMode.PAUSED else [],
		"ending": _ending_state(),
		"progression": {
			"final_boss_defeated": final_boss_defeated,
			"ending_seen": ending_seen,
			"all_soldiers_unlocked": all_soldiers_unlocked,
			"timeless_gate_unlocked": timeless_gate_unlocked,
			"aionis_defeated": aionis_boss_defeated,
			"recruitable_types": _recruitable_soldier_order(),
		},
	}
	return JSON.stringify(payload)


func _boss_text_state() -> Variant:
	if python_boss == null:
		return null
	var state: Dictionary = python_boss.get_text_state().duplicate(true)
	var home := _python_boss_lair_home(active_python_boss_lair_id)
	state["active_lair_id"] = active_python_boss_lair_id
	state["home_x"] = snappedf(home.x, 0.1)
	state["home_y"] = snappedf(home.y, 0.1)
	state["lair_cleared"] = _python_boss_lair_is_cleared(active_python_boss_lair_id)
	var marker_visible := bool(state.get("discovered", false))
	var marker_status := "hidden"
	if marker_visible:
		marker_status = "cleared" if bool(state.get("defeated", false)) else ("engaged" if bool(state.get("engaged", false)) else "discovered")
	var marker := {
		"kind": "python_boss_lair",
		"visible": marker_visible,
		"status": marker_status,
	}
	if marker_visible:
		marker["x"] = snappedf(home.x, 0.1)
		marker["y"] = snappedf(home.y, 0.1)
		marker["lair_id"] = active_python_boss_lair_id
	state["map_marker"] = marker
	return state


func _initialize_python_boss(reset_existing: bool = false) -> void:
	if python_boss == null:
		python_boss = PythonBossControllerScript.new()
		reset_existing = true
	if not reset_existing:
		return
	if not _python_boss_lair_exists(active_python_boss_lair_id):
		active_python_boss_lair_id = MAIN_PYTHON_BOSS_LAIR_ID
	var home := _python_boss_lair_home(active_python_boss_lair_id)
	var tier := _python_boss_world_tier_for_lair(active_python_boss_lair_id)
	var level: int = int(player.get("level", 1))
	var encounter_config: Dictionary = GameConfig.PYTHON_BOSS_CONFIG.duplicate(true)
	encounter_config["home_position"] = home
	python_boss.initialize(encounter_config, tier, level, _python_boss_seed_for_lair(active_python_boss_lair_id))


func _initialize_chaos_boss(reset_existing: bool = false) -> void:
	if chaos_boss == null:
		chaos_boss = ChaosBossControllerScript.new()
		reset_existing = true
	if not reset_existing:
		return
	chaos_boss.initialize(GameConfig.CHAOS_BOSS_CONFIG, int(player.get("level", 1)), (world_seed ^ 0xCA05B055) & 0x7FFFFFFF)


func _initialize_aionis_boss(reset_existing: bool = false) -> void:
	if aionis_boss == null:
		aionis_boss = AionisBossControllerScript.new()
		reset_existing = true
	if not reset_existing:
		return
	aionis_boss.initialize(GameConfig.AIONIS_BOSS_CONFIG, int(player.get("level", 1)), (world_seed ^ 0xA10A15) & 0x7FFFFFFF)


func _load_profile_progression() -> void:
	var profile := GameSaveManager.load_game(PROFILE_PATH)
	var profile_version := int(profile.get("version", 1))
	if profile.has("all_soldiers_unlocked") and typeof(profile.get("all_soldiers_unlocked")) == TYPE_BOOL:
		all_soldiers_unlocked = bool(profile.get("all_soldiers_unlocked", false))
	if profile.has("timeless_gate_unlocked") and typeof(profile.get("timeless_gate_unlocked")) == TYPE_BOOL:
		timeless_gate_unlocked = bool(profile.get("timeless_gate_unlocked", false))
	else:
		timeless_gate_unlocked = all_soldiers_unlocked
	if profile.has("kaeron_ending_completed") and typeof(profile.get("kaeron_ending_completed")) == TYPE_BOOL:
		kaeron_ending_completed = bool(profile.get("kaeron_ending_completed", false))
	else:
		kaeron_ending_completed = all_soldiers_unlocked
	# 所有舊版永久解鎖檔都來自卡厄隆首殺；升級後直接開啟無時之門。
	if all_soldiers_unlocked:
		timeless_gate_unlocked = true
		if profile_version < 2:
			kaeron_ending_completed = true


func _save_profile_progression() -> bool:
	if _web_test_showcase_active:
		return true
	return GameSaveManager.save_game({
		"version": 2,
		"all_soldiers_unlocked": all_soldiers_unlocked,
		"timeless_gate_unlocked": timeless_gate_unlocked,
		"kaeron_ending_completed": kaeron_ending_completed,
	}, PROFILE_PATH)


func _recruitable_soldier_order() -> Array[String]:
	var roster: Array[String] = GameConfig.SOLDIER_ORDER.duplicate()
	if all_soldiers_unlocked:
		roster.append_array(GameConfig.CHAOS_UNLOCK_SOLDIER_ORDER)
	return roster


func _is_chaos_unlock_soldier(type_id: String) -> bool:
	return type_id in GameConfig.CHAOS_UNLOCK_SOLDIER_ORDER


func _python_boss_lair_exists(lair_id: String) -> bool:
	return lair_id == MAIN_PYTHON_BOSS_LAIR_ID or snake_nests.has(lair_id)


func _python_boss_lair_home(lair_id: String) -> Vector2:
	if lair_id != MAIN_PYTHON_BOSS_LAIR_ID and snake_nests.has(lair_id):
		return Vector2(Dictionary(snake_nests[lair_id]).get("pos", GameConfig.PYTHON_BOSS_CONFIG["home_position"]))
	return Vector2(GameConfig.PYTHON_BOSS_CONFIG["home_position"])


func _python_boss_lair_is_cleared(lair_id: String) -> bool:
	if lair_id == MAIN_PYTHON_BOSS_LAIR_ID:
		return main_python_boss_lair_cleared
	if not snake_nests.has(lair_id):
		return true
	return bool(Dictionary(snake_nests[lair_id]).get("cleared", false))


func _python_boss_world_tier_for_lair(lair_id: String) -> int:
	var tier_cap := int(GameConfig.PYTHON_BOSS_CONFIG["scaling"]["max_world_tier"])
	if lair_id != MAIN_PYTHON_BOSS_LAIR_ID and snake_nests.has(lair_id):
		return clampi(int(Dictionary(snake_nests[lair_id]).get("level", 1)) - 1, 0, tier_cap)
	return clampi(_world_difficulty(_python_boss_lair_home(lair_id)) - 1, 0, tier_cap)


func _python_boss_seed_for_lair(lair_id: String) -> int:
	return (world_seed ^ lair_id.hash() ^ 0x5A6A) & 0x7FFFFFFF


func _activate_python_boss_lair(lair_id: String, force: bool = false) -> bool:
	if not _python_boss_lair_exists(lair_id) or _python_boss_lair_is_cleared(lair_id):
		return false
	if python_boss != null and not force:
		var current_state := str(python_boss.get_text_state().get("state", "IDLE"))
		if current_state not in ["IDLE", "DEAD"]:
			return false
	active_python_boss_lair_id = lair_id
	if lair_id != MAIN_PYTHON_BOSS_LAIR_ID:
		var nest: Dictionary = Dictionary(snake_nests[lair_id])
		nest["discovered"] = true
		snake_nests[lair_id] = nest
	_initialize_python_boss(true)
	python_boss_lair_activation_timer = float(GameConfig.SNAKE_NEST_SETTINGS["activation_check_interval"])
	if mode == GameMode.PLAYING and not _self_test_running:
		_add_notification("腐沼蟒皇・薩迦已在此巢穴現身！", Color("DDA6FF"), 4.2)
	return true


func _mark_active_python_boss_lair_cleared() -> void:
	if _python_boss_lair_is_cleared(active_python_boss_lair_id):
		return
	if active_python_boss_lair_id == MAIN_PYTHON_BOSS_LAIR_ID:
		main_python_boss_lair_cleared = true
	else:
		var nest: Dictionary = Dictionary(snake_nests[active_python_boss_lair_id])
		nest["discovered"] = true
		nest["cleared"] = true
		snake_nests[active_python_boss_lair_id] = nest
	if mode == GameMode.PLAYING and not _self_test_running:
		_add_notification("蟒蛇 Boss 巢穴已清除：腐沼蟒皇・薩迦", GOLD, 4.5)


func _nearest_available_python_boss_lair() -> String:
	var player_position := Vector2(player.get("pos", HOUSE_POS))
	var activation_radius := float(GameConfig.SNAKE_NEST_SETTINGS["activation_radius"])
	var closest_id := ""
	var closest_distance := INF
	var main_home := Vector2(GameConfig.PYTHON_BOSS_CONFIG["home_position"])
	var main_distance := player_position.distance_to(main_home)
	if not main_python_boss_lair_cleared and main_distance <= activation_radius:
		closest_id = MAIN_PYTHON_BOSS_LAIR_ID
		closest_distance = main_distance
	# Only inspect the currently streamed 5x5 neighborhood. This keeps the
	# activation cost bounded even after a very long infinite-world expedition.
	for chunk_value in active_chunks.values():
		var chunk: Dictionary = Dictionary(chunk_value)
		var descriptor_value: Variant = chunk.get("snake_nest")
		if typeof(descriptor_value) != TYPE_DICTIONARY:
			continue
		var descriptor: Dictionary = Dictionary(descriptor_value)
		var lair_id := str(descriptor.get("id", ""))
		if lair_id.is_empty() or not snake_nests.has(lair_id) or _python_boss_lair_is_cleared(lair_id):
			continue
		var distance := player_position.distance_to(_python_boss_lair_home(lair_id))
		if distance <= activation_radius and distance < closest_distance:
			closest_id = lair_id
			closest_distance = distance
	return closest_id


func _update_python_boss_lair_activation(delta: float) -> void:
	if python_boss == null:
		return
	if python_boss.is_defeated():
		_mark_active_python_boss_lair_cleared()
	python_boss_lair_activation_timer -= delta
	if python_boss_lair_activation_timer > 0.0:
		return
	python_boss_lair_activation_timer = float(GameConfig.SNAKE_NEST_SETTINGS["activation_check_interval"])
	var state_id := str(python_boss.get_text_state().get("state", "IDLE"))
	if state_id not in ["IDLE", "DEAD"]:
		return
	if state_id == "DEAD":
		var release_radius := float(GameConfig.SNAKE_NEST_SETTINGS["release_radius"])
		if Vector2(player.get("pos", HOUSE_POS)).distance_to(_python_boss_lair_home(active_python_boss_lair_id)) <= release_radius:
			return
	var candidate := _nearest_available_python_boss_lair()
	if candidate != "" and candidate != active_python_boss_lair_id:
		# Keep a small nearest-candidate hysteresis so Saga never pops between two
		# overlapping lair circles. Unlike a full release-ring lock, this still lets
		# the player summon Saga well before reaching the exact satellite center.
		if state_id == "IDLE" and bool(python_boss.get_text_state().get("discovered", false)) and not _python_boss_lair_is_cleared(active_python_boss_lair_id):
			var idle_release_radius := float(GameConfig.SNAKE_NEST_SETTINGS["release_radius"])
			var player_position := Vector2(player.get("pos", HOUSE_POS))
			var current_distance := player_position.distance_to(_python_boss_lair_home(active_python_boss_lair_id))
			var candidate_distance := player_position.distance_to(_python_boss_lair_home(candidate))
			var switch_hysteresis := 120.0
			if current_distance <= idle_release_radius and candidate_distance + switch_hysteresis >= current_distance:
				return
		_activate_python_boss_lair(candidate)


func _initialize_empty_player() -> void:
	player = {
		"class_id": "",
		"pos": HOUSE_POS,
		"vel": Vector2.ZERO,
		"facing": Vector2.RIGHT,
		"level": 1,
		"xp": 0,
		"xp_need": GameConfig.xp_needed(1),
		"money": 150,
		"hp": 100.0,
		"max_hp": 100.0,
		"attack": 20.0,
		"defense": 5.0,
		"speed": 210.0,
		"attack_rate": 1.0,
		"attack_cd": 0.0,
		"special_cd": 0.0,
		"invuln": 0.0,
		"hit_grace": 0.0,
		"flash": 0.0,
		"skill_points": 0,
		"upgrades": {"attack": 0, "defense": 0, "max_hp": 0, "speed": 0, "attack_speed": 0},
		"kills": 0,
		"captured": 0,
		"dash_timer": 0.0,
		"dash_dir": Vector2.RIGHT,
		"dash_hit": {},
		"dash_attack_id": "",
		"support_shield": 0.0,
		"support_shield_ttl": 0.0,
		"holy_shield_ready_at": 0.0,
		"alive": true,
	}


func _start_new_game(class_id: String, web_test_showcase: bool = false) -> void:
	if not GameConfig.HERO_CLASSES.has(class_id):
		return
	class_change_pending = false
	_close_cheat_input()
	_web_test_showcase_active = web_test_showcase
	_web_manual_time_hold = 0.0
	ending_elapsed = 0.0
	ending_pending = false
	ending_seen = kaeron_ending_completed
	final_boss_defeated = false
	aionis_boss_defeated = false
	_initialize_empty_player()
	var class_data: Dictionary = GameConfig.HERO_CLASSES[class_id]
	var stats: Dictionary = class_data["base_stats"]
	player["class_id"] = class_id
	player["max_hp"] = float(stats["hp"])
	player["hp"] = float(stats["hp"])
	player["attack"] = float(stats["attack"])
	player["defense"] = float(stats["defense"])
	player["speed"] = float(stats["speed"]) * 1.65
	player["attack_rate"] = float(class_data["normal_attack"]["attack_speed"])
	player["pos"] = HOUSE_POS + Vector2(0.0, 95.0)
	player["facing"] = Vector2.RIGHT
	mode = GameMode.PLAYING
	active_panel = ""
	game_time = 0.0
	autosave_timer = 0.0
	death_timer = 0.0
	last_recruit_purchase_msec = -10000
	last_recruit_purchase_type = ""
	attack_held = false
	touch_move_pointer = -1
	touch_aim_pointer = -1
	touch_move_vector = Vector2.ZERO
	touch_aim_vector = Vector2.RIGHT
	soldier_command = "跟隨"
	command_point = player["pos"]
	command_target_id = -1
	command_castle_id = ""
	recruit_anchor = HOUSE_POS
	active_chunks.clear()
	discovered_chunks.clear()
	spawned_chunks.clear()
	chunk_states.clear()
	pending_chunk_spawns.clear()
	castles.clear()
	camps.clear()
	snake_nests.clear()
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	hazards.clear()
	upgrade_effects.clear()
	soldier_boss_debuffs.clear()
	soldier_upgrade_shared_cooldowns.clear()
	soldier_research = SoldierUpgradeCatalog.create_empty_research()
	soldier_upgrade_type_index = 0
	soldier_upgrade_category = "base"
	soldier_upgrade_page = 0
	particles.clear()
	floaters.clear()
	tombstones.clear()
	drops.clear()
	notifications.clear()
	next_entity_id = 1
	active_python_boss_lair_id = MAIN_PYTHON_BOSS_LAIR_ID
	main_python_boss_lair_cleared = false
	python_boss_lair_activation_timer = 0.0
	_initialize_python_boss(true)
	_initialize_chaos_boss(true)
	_initialize_aionis_boss(true)
	chaos_runtime_projectiles.clear()
	chaos_runtime_hazards.clear()
	aionis_runtime_projectiles.clear()
	aionis_runtime_hazards.clear()
	camera_pos = player["pos"]
	camera_target = camera_pos
	_last_active_center = Vector2i(999999, 999999)
	_update_active_chunks(true)
	_add_notification("歡迎，%s！離開安全區並探索荒原。" % class_data["name"], GOLD, 4.0)
	_spawn_effect("level_up", player["pos"], GOLD, 1.0)
	audio.play("level_up", 0.7)
	queue_redraw()


func _touch_move_center() -> Vector2:
	var scale := touch_ui_coordinate_scale
	return Vector2(122.0 * scale, screen_size.y - 132.0 * scale)


func _touch_aim_center() -> Vector2:
	var scale := touch_ui_coordinate_scale
	return Vector2(screen_size.x - 122.0 * scale, screen_size.y - 132.0 * scale)


func _touch_special_rect() -> Rect2:
	var scale := touch_ui_coordinate_scale
	return Rect2(Vector2(screen_size.x - 326.0 * scale, screen_size.y - 180.0 * scale), Vector2(92.0, 92.0) * scale)


func _touch_utility_rects() -> Dictionary:
	var keys := ["guide", "map", "skills", "upgrades", "recruit", "command", "notices", "cheat", "fullscreen", "pause"]
	var result := {}
	var scale := touch_ui_coordinate_scale
	var css_size := screen_size / scale
	var compact := css_size.y < 540.0 or css_size.x < 1000.0
	var button_size := (52.0 if compact else 68.0) * scale
	var gap := (6.0 if compact else 8.0) * scale
	var columns := 5
	var start_y := (82.0 if compact else 106.0) * scale
	for index in keys.size():
		var row := index / columns
		var column := index % columns
		var items_in_row := mini(columns, keys.size() - row * columns)
		var row_width := button_size * float(items_in_row) + gap * float(items_in_row - 1)
		var start_x := (screen_size.x - row_width) * 0.5
		result[keys[index]] = Rect2(start_x + float(column) * (button_size + gap), start_y + float(row) * (button_size + gap), button_size, button_size)
	return result


func _touch_panel_close_rect() -> Rect2:
	var panel := Rect2()
	match active_panel:
		"skills": panel = _skills_panel_rect()
		"recruit": panel = _recruit_panel_rect()
		"soldier_upgrades":
			panel = _soldier_upgrade_panel_rect()
			var scale := touch_ui_coordinate_scale
			return Rect2(panel.end.x - 72.0 * scale, panel.position.y + 6.0 * scale, 64.0 * scale, 44.0 * scale)
		"map": panel = _map_panel_rect()
		"command": panel = _command_panel_rect()
		"confirm_restart":
			return Rect2(screen_size.x * 0.5 + 2.0, screen_size.y * 0.5 + 28.0, 132.0, 70.0)
		_:
			return Rect2()
	if _is_touch_scheme():
		var scale := touch_ui_coordinate_scale
		return Rect2(panel.end.x - 72.0 * scale, panel.position.y + 6.0 * scale, 64.0 * scale, 44.0 * scale)
	return Rect2(panel.end.x - 126.0, panel.position.y + 8.0, 110.0, 72.0)


func _language_toggle_rect() -> Rect2:
	return Rect2(screen_size.x - 146.0, 16.0, 128.0, 72.0 if _is_touch_scheme() else 46.0)


func _notification_toggle_rect() -> Rect2:
	return Rect2(screen_size.x - 230.0, 182.0, 212.0, 34.0)


func _cheat_toggle_rect() -> Rect2:
	return Rect2(screen_size.x - 230.0, 222.0, 212.0, 34.0)


func _soldier_upgrade_toggle_rect() -> Rect2:
	return Rect2(screen_size.x - 230.0, 262.0, 212.0, 38.0)


func _tutorial_panel_rect() -> Rect2:
	var tutorial_y := 158.0
	if python_boss != null:
		var tutorial_status: Dictionary = python_boss.get_unit_status("player", 0)
		if int(tutorial_status.get("poison_stacks", 0)) > 0 or float(tutorial_status.get("pool_slow_ttl", 0.0)) > 0.0 or float(tutorial_status.get("control_immunity", 0.0)) > 0.0:
			tutorial_y = 188.0
	return Rect2(18.0, tutorial_y, 300.0, 154.0)


func _tutorial_close_rect() -> Rect2:
	var tutorial := _tutorial_panel_rect()
	if _is_touch_scheme():
		var scale := touch_ui_coordinate_scale
		return Rect2(tutorial.end.x - 48.0 * scale, tutorial.position.y + 3.0 * scale, 48.0 * scale, 44.0 * scale)
	return Rect2(tutorial.end.x - 70.0, tutorial.position.y + 3.0, 66.0, 52.0)


func _mark_touch_feedback(action: String) -> void:
	touch_button_feedback[action] = Time.get_ticks_msec() + 180


func _touch_feedback_active(action: String) -> bool:
	return int(touch_button_feedback.get(action, 0)) > Time.get_ticks_msec()


func _cycle_soldier_command() -> void:
	var commands := ["跟隨", "防守", "攻擊", "撤退", "駐守", "攻城"]
	var current := commands.find(soldier_command)
	_set_soldier_command(str(commands[(current + 1) % commands.size()]))


func _touch_attack_target() -> Vector2:
	var direction := touch_aim_vector
	if direction.length_squared() < 0.01:
		direction = Vector2(player.get("facing", Vector2.RIGHT))
	return Vector2(player.get("pos", HOUSE_POS)) + direction.normalized() * 620.0


func _handle_touch_action_at(position: Vector2) -> bool:
	if mode == GameMode.PLAYING and active_panel == "" and tutorial_visible and _tutorial_close_rect().has_point(position):
		tutorial_visible = false
		_mark_touch_feedback("guide")
		audio.play("ui", 0.45)
		queue_redraw()
		return true
	if active_panel != "" and _touch_panel_close_rect().has_point(position):
		active_panel = ""
		_mark_touch_feedback("close")
		audio.play("ui", 0.5)
		queue_redraw()
		return true
	if mode != GameMode.PLAYING or active_panel != "":
		return false
	if _touch_special_rect().has_point(position):
		_mark_touch_feedback("special")
		_try_player_special(_touch_attack_target())
		return true
	var utility_rects := _touch_utility_rects()
	for action_value in utility_rects.keys():
		var action := str(action_value)
		if not Rect2(utility_rects[action]).has_point(position):
			continue
		_mark_touch_feedback(action)
		match action:
			"guide": tutorial_visible = not tutorial_visible
			"map": active_panel = "map"
			"skills": active_panel = "skills"
			"upgrades":
				active_panel = "soldier_upgrades"
				soldier_upgrade_page = 0
			"recruit":
				if _is_near_recruitment():
					active_panel = "recruit"
				else:
					_add_notification("需要靠近出生房屋或友方城堡。", Color("F6C177"), 2.0)
			"command": active_panel = "command"
			"notices": _toggle_notifications()
			"cheat": _open_cheat_input()
			"fullscreen": _toggle_fullscreen()
			"pause": mode = GameMode.PAUSED
		audio.play("ui", 0.45)
		queue_redraw()
		return true
	return false


func _update_touch_move(position: Vector2) -> void:
	touch_move_position = position
	var scale := touch_ui_coordinate_scale
	var radius := TOUCH_STICK_RADIUS * scale
	var deadzone := 10.0 * scale
	var offset := (position - _touch_move_center()).limit_length(radius)
	var magnitude := offset.length()
	if magnitude <= deadzone:
		touch_move_vector = Vector2.ZERO
	else:
		touch_move_vector = offset.normalized() * clampf((magnitude - deadzone) / maxf(1.0, radius - deadzone), 0.0, 1.0)


func _update_touch_aim(position: Vector2) -> void:
	touch_aim_position = position
	var scale := touch_ui_coordinate_scale
	var offset := (position - _touch_aim_center()).limit_length(TOUCH_STICK_RADIUS * scale)
	if offset.length() >= 8.0 * scale:
		touch_aim_vector = offset.normalized()
	attack_held = true


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	last_touch_event_msec = Time.get_ticks_msec()
	_set_input_scheme(InputScheme.TOUCH)
	if not event.pressed:
		if event.index == touch_move_pointer:
			touch_move_pointer = -1
			touch_move_vector = Vector2.ZERO
			touch_move_position = _touch_move_center()
		if event.index == touch_aim_pointer:
			touch_aim_pointer = -1
			attack_held = false
			touch_aim_position = _touch_aim_center()
		return
	if _needs_landscape_rotation():
		return

	if mode in [GameMode.TITLE, GameMode.CLASS_SELECT] and _language_toggle_rect().has_point(event.position):
		_toggle_language()
		audio.play("ui", 0.45)
		return
	if _handle_touch_action_at(event.position):
		return
	if mode != GameMode.PLAYING or active_panel != "":
		_handle_ui_click(event.position)
		return
	if python_boss != null and python_boss.is_rooted("player", 0) and event.position.x >= screen_size.x * 0.48:
		python_boss.register_break_click(_player_damage(1.0))
		_spawn_effect("hit", player["pos"], Color("DDA6FF"), 0.55)
		return
	if event.position.x < screen_size.x * 0.48 and event.position.y > screen_size.y * 0.38 and touch_move_pointer < 0:
		touch_move_pointer = event.index
		_update_touch_move(event.position)
		return
	if event.position.y > screen_size.y * 0.38 and touch_aim_pointer < 0:
		touch_aim_pointer = event.index
		_update_touch_aim(event.position)
		return
	_handle_ui_click(event.position)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	last_touch_event_msec = Time.get_ticks_msec()
	_set_input_scheme(InputScheme.TOUCH)
	if _needs_landscape_rotation():
		return
	if event.index == touch_move_pointer:
		_update_touch_move(event.position)
	elif event.index == touch_aim_pointer:
		_update_touch_aim(event.position)


func _input(event: InputEvent) -> void:
	if mode == GameMode.ENDING:
		return
	if cheat_input_active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_close_cheat_input()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		return
	if event is InputEventMouseMotion and Time.get_ticks_msec() - last_touch_event_msec > 650 and event.relative.length_squared() > 0.0:
		_set_input_scheme(InputScheme.KEYBOARD_MOUSE)
	if event is InputEventKey and event.pressed and not event.echo:
		_set_input_scheme(InputScheme.KEYBOARD_MOUSE)
		var key: int = event.keycode
		if key == KEY_L:
			_toggle_language()
			return
		if key == KEY_F:
			_toggle_fullscreen()
			return
		if mode == GameMode.TITLE:
			if key == KEY_ENTER or key == KEY_SPACE:
				_enter_class_select(false)
			return
		if mode == GameMode.CLASS_SELECT:
			if key == KEY_1:
				if class_change_pending: _change_player_class("archer")
				else: _start_new_game("archer")
			elif key == KEY_2:
				if class_change_pending: _change_player_class("mage")
				else: _start_new_game("mage")
			elif key == KEY_3:
				if class_change_pending: _change_player_class("warrior")
				else: _start_new_game("warrior")
			elif key == KEY_ESCAPE:
				if class_change_pending:
					class_change_pending = false
					mode = GameMode.PLAYING
				else:
					mode = GameMode.TITLE
			queue_redraw()
			return
		if key == KEY_ESCAPE:
			if active_panel != "":
				active_panel = ""
			elif mode == GameMode.PLAYING:
				mode = GameMode.PAUSED
			elif mode == GameMode.PAUSED:
				mode = GameMode.PLAYING
			queue_redraw()
			return
		if mode == GameMode.DEAD:
			return
		if mode == GameMode.PAUSED:
			if key == KEY_F5:
				_save_game()
			elif key == KEY_F9:
				_load_game()
			return
		if mode != GameMode.PLAYING:
			return
		match key:
			KEY_T:
				_open_cheat_input()
			KEY_C:
				active_panel = "" if active_panel == "skills" else "skills"
			KEY_B, KEY_E:
				if _is_near_recruitment():
					active_panel = "" if active_panel == "recruit" else "recruit"
				else:
					_add_notification("需要靠近出生房屋或友方城堡。", Color("F6C177"), 2.0)
			KEY_K:
				active_panel = "" if active_panel == "soldier_upgrades" else "soldier_upgrades"
				soldier_upgrade_page = 0
			KEY_M:
				active_panel = "" if active_panel == "map" else "map"
			KEY_H:
				tutorial_visible = not tutorial_visible
			KEY_N:
				_toggle_notifications()
			KEY_1:
				_set_soldier_command("跟隨")
			KEY_2:
				_set_soldier_command("防守")
			KEY_3:
				_set_soldier_command("攻擊")
			KEY_4:
				_set_soldier_command("撤退")
			KEY_5:
				_set_soldier_command("駐守")
			KEY_6:
				_set_soldier_command("攻城")
			KEY_F5:
				_save_game()
			KEY_F9:
				_load_game()
		queue_redraw()

	if event is InputEventMouseButton:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if Time.get_ticks_msec() - last_touch_event_msec <= 650:
			return
		_set_input_scheme(InputScheme.KEYBOARD_MOUSE)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if mode == GameMode.PLAYING and python_boss != null and python_boss.is_rooted("player", 0):
					python_boss.register_break_click(_player_damage(1.0))
					attack_held = false
					_spawn_effect("hit", player["pos"], Color("DDA6FF"), 0.55)
				elif _handle_ui_click(event.position):
					attack_held = false
				else:
					attack_held = true
			else:
				attack_held = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if mode == GameMode.PLAYING and active_panel == "":
				_try_player_special(_screen_to_world(event.position))


func _process(delta: float) -> void:
	delta = min(delta, 0.05)
	_update_audio_settings()
	if _web_manual_time_hold > 0.0:
		_web_manual_time_hold = max(0.0, _web_manual_time_hold - delta)
	else:
		_simulate_game(delta)
		_update_camera(delta)
	queue_redraw()


func _simulate_game(delta: float) -> void:
	if ending_pending:
		_begin_ending()
		return
	if mode == GameMode.ENDING:
		_update_ending(delta)
		return
	if cheat_input_active:
		_update_visuals(delta)
		return
	if mode == GameMode.PLAYING:
		game_time += delta
		autosave_timer += delta
		_update_player(delta)
		_update_active_chunks(false)
		_update_castles_and_camps(delta)
		_update_enemies(delta)
		_update_soldiers(delta)
		_update_soldier_boss_debuffs(delta)
		_update_python_boss(delta)
		_update_chaos_boss(delta)
		_update_aionis_boss(delta)
		_update_projectiles(delta)
		_update_hazards(delta)
		_update_upgrade_effects(delta)
		_update_drops(delta)
		if autosave_timer >= 45.0 and not _self_test_running and not _web_test_showcase_active:
			autosave_timer = 0.0
			_save_game(false)
	elif mode == GameMode.DEAD:
		death_timer -= delta
		if death_timer <= 0.0:
			_respawn_player()
	_update_visuals(delta)


func _update_audio_settings() -> void:
	if audio == null:
		return
	audio.set_volume(master_volume)
	audio.set_muted(sound_muted)


# -----------------------------------------------------------------------------
# 蟒蛇世界 Boss：場景 adapter、事件結算與狀態互動
# -----------------------------------------------------------------------------

func _update_python_boss(delta: float) -> void:
	if python_boss == null:
		return
	_update_python_boss_lair_activation(delta)
	var boss_state: Dictionary = python_boss.get_text_state()
	if str(boss_state.get("state", "")) == "IDLE":
		python_boss.refresh_scaling(_python_boss_world_tier_for_lair(active_python_boss_lair_id), int(player.get("level", 1)))
	var events_value: Variant = python_boss.update(delta * _soldier_boss_time_scale(), _python_boss_context())
	if not events_value is Array:
		return
	for event_value in Array(events_value):
		if event_value is Dictionary:
			_apply_python_boss_event(Dictionary(event_value))


func _python_boss_context() -> Dictionary:
	var units: Array[Dictionary] = []
	var player_pos: Vector2 = Vector2(player.get("pos", HOUSE_POS))
	units.append({
		"kind": "player",
		"id": 0,
		"type": str(player.get("class_id", "player")),
		"pos": player_pos,
		"vel": Vector2(player.get("vel", Vector2.ZERO)),
		"radius": PLAYER_RADIUS,
		"alive": bool(player.get("alive", true)),
		"safe": _is_in_friendly_safe_zone(player_pos),
	})
	for soldier in soldiers:
		var position: Vector2 = Vector2(soldier["pos"])
		units.append({
			"kind": "soldier",
			"id": int(soldier["id"]),
			"type": str(soldier["type"]),
			"pos": position,
			"vel": Vector2(soldier.get("vel", Vector2.ZERO)),
			"radius": float(soldier["radius"]),
			"alive": float(soldier["hp"]) > 0.0,
			"safe": _is_in_friendly_safe_zone(position),
		})
	# The birth house is the only true invulnerability zone. Captured castles
	# heal, recruit and revive, but their garrisons must still be able to fight
	# and take damage while defending the city.
	var safe_zones: Array[Dictionary] = [{"pos": HOUSE_POS, "radius": HOUSE_SAFE_RADIUS}]
	return {
		"units": units,
		"safe_zones": safe_zones,
		"position_blocked": Callable(self, "_python_boss_position_blocked"),
	}


func _python_boss_position_blocked(position: Vector2, radius: float) -> bool:
	return _position_hits_obstacle(position, radius)


func _is_in_friendly_safe_zone(position: Vector2) -> bool:
	return position.distance_to(HOUSE_POS) <= HOUSE_SAFE_RADIUS


func _parse_python_boss_target(target_key: String) -> Dictionary:
	var parts: PackedStringArray = target_key.split(":", false, 1)
	if parts.size() != 2 or not parts[1].is_valid_int():
		return {}
	return {"kind": parts[0], "id": int(parts[1])}


func _apply_python_boss_event(event: Dictionary) -> void:
	var event_type: String = str(event.get("type", ""))
	match event_type:
		"damage":
			var parsed: Dictionary = _parse_python_boss_target(str(event.get("target", "")))
			if parsed.is_empty():
				return
			var amount: float = float(event.get("amount", 0.0))
			var source_pos: Vector2 = Vector2(event.get("source_pos", _python_boss_position()))
			var damage_kind: String = str(event.get("kind", "area"))
			if str(parsed["kind"]) == "player":
				# Boss events are independently authored hits. They may bypass only the
				# short 0.14 s hit-grace from another impact, never dash/respawn safety.
				# A single telegraphed impact is capped so the stronger boss still cannot
				# delete a full-health hero with one unavoidable frame.
				amount = minf(amount, float(player.get("max_hp", 1.0)) * 0.88)
				var should_knock: bool = damage_kind in ["bite", "bite_secondary", "dash", "tail_sweep", "phase_wave"]
				_damage_player(amount, source_pos, should_knock, true)
			else:
				var soldier: Variant = _find_soldier_by_id(int(parsed["id"]))
				if soldier != null:
					_damage_soldier(soldier, amount, source_pos, "area")
		"knockback":
			_apply_python_boss_knockback(str(event.get("target", "")), Vector2(event.get("vector", Vector2.ZERO)))
		"anchor":
			_apply_python_boss_anchor(str(event.get("target", "")), Vector2(event.get("position", Vector2.ZERO)))
		"audio":
			_play_python_boss_audio(str(event.get("kind", "")))
		"effect":
			var position: Vector2 = Vector2(event.get("position", _python_boss_position()))
			var kind: String = str(event.get("kind", "hit"))
			var color: Color = Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["poison_color"])
			_spawn_effect(kind, position, color, 1.25)
			if kind in ["wall_impact", "boss_death", "phase_wave"]:
				camera_shake = maxf(camera_shake, 0.85 if kind == "boss_death" else 0.62)
		"notice":
			var notice_text: String = str(event.get("text", ""))
			if notice_text != "":
				_add_notification(notice_text, Color("DDA6FF"), 3.0)
		"phase":
			var phase_number: int = int(event.get("phase", 1))
			_add_notification("蟒皇進入第 %d 階段：%s" % [phase_number, str(event.get("name", ""))], Color("DDA6FF"), 4.0)
		"reward":
			_mark_active_python_boss_lair_cleared()
			var gold: int = int(event.get("gold", 0))
			var xp: int = int(event.get("xp", 0))
			player["money"] = int(player["money"]) + gold
			_gain_xp(xp)
			_add_notification("世界 Boss 獎勵：%d 金幣、%d XP" % [gold, xp], GOLD, 5.0)
			_spawn_effect("level_up", _python_boss_position(), GOLD, 1.8)
		"boss_hit":
			var hit_position: Vector2 = Vector2(event.get("position", _python_boss_position()))
			var hit_damage: float = float(event.get("damage", 0.0))
			var part: String = str(event.get("part", "body"))
			_add_floater(hit_position + Vector2(0.0, -30.0), "-%d %s" % [int(hit_damage), _boss_part_label(part)], Color("FFF4D6"), 0.95)
			_spawn_effect("hit", hit_position, Color("F5FFF0"), 1.2 if part == "head" else 0.8)
			if str(event.get("source_kind", "")) == "cannon":
				camera_shake = maxf(camera_shake, 0.70)


# -----------------------------------------------------------------------------
# 混沌終局 Boss：獨立控制器、十技能事件與完結轉場
# -----------------------------------------------------------------------------

func _update_chaos_boss(delta: float) -> void:
	if chaos_boss == null or final_boss_defeated:
		return
	var events_value: Variant = chaos_boss.update(delta * _soldier_boss_time_scale(), _chaos_boss_context())
	if events_value is Array:
		for event_value in Array(events_value):
			if event_value is Dictionary:
				_apply_chaos_boss_event(Dictionary(event_value))
	_update_chaos_runtime(delta)


func _chaos_boss_context() -> Dictionary:
	var context_soldiers: Array[Dictionary] = []
	for soldier in soldiers:
		context_soldiers.append({
			"id": int(soldier["id"]), "type": str(soldier["type"]),
			"pos": Vector2(soldier["pos"]), "vel": Vector2(soldier.get("vel", Vector2.ZERO)),
			"hp": float(soldier["hp"]), "max_hp": float(soldier["max_hp"]),
			"radius": float(soldier["radius"]), "alive": float(soldier["hp"]) > 0.0,
		})
	return {
		"player": {
			"id": 0, "pos": Vector2(player.get("pos", HOUSE_POS)),
			"vel": Vector2(player.get("vel", Vector2.ZERO)),
			"hp": float(player.get("hp", 0.0)), "max_hp": float(player.get("max_hp", 1.0)),
			"radius": PLAYER_RADIUS, "alive": bool(player.get("alive", true)),
		},
		"soldiers": context_soldiers,
		"position_blocked": Callable(self, "_python_boss_position_blocked"),
	}


func _apply_chaos_boss_event(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	match event_type:
		"damage":
			var target_key := str(event.get("target", ""))
			if target_key in ["chaos_boss", "kaeron_annihilator_of_all"]:
				return
			var parsed := _parse_python_boss_target(target_key)
			if parsed.is_empty():
				return
			var skill := str(event.get("skill", event.get("source_skill", "chaos")))
			var amount := float(event.get("amount", 0.0))
			var source_position := _chaos_boss_position()
			if str(parsed["kind"]) == "player":
				var single_hit_cap := 0.94 if skill == "total_annihilation" else 0.78
				amount = minf(amount, float(player.get("max_hp", 1.0)) * single_hit_cap)
				_damage_player(amount, source_position, skill in ["shockwave", "rift_dash"], true)
			else:
				var soldier: Variant = _find_soldier_by_id(int(parsed["id"]))
				if soldier != null:
					amount = minf(amount, float(soldier.get("max_hp", 1.0)) * 0.92)
					_damage_soldier(soldier, amount, source_position, "area")
		"knockback":
			_apply_python_boss_knockback(str(event.get("target", "")), Vector2(event.get("force", Vector2.ZERO)))
		"projectile":
			var lifetime := clampf(float(event.get("lifetime", 1.0)), 0.05, 6.0)
			chaos_runtime_projectiles.append({
				"kind": str(event.get("kind", "chaos_orb")),
				"pos": Vector2(event.get("pos", _chaos_boss_position())),
				"vel": Vector2(event.get("velocity", Vector2.ZERO)),
				"radius": float(event.get("radius", 18.0)),
				"damage": float(event.get("damage", 0.0)),
				"aoe": float(event.get("aoe", 0.0)),
				"ttl": lifetime,
				"max_ttl": lifetime,
				"target": str(event.get("target_id", "player:0")),
				"homing": bool(event.get("homing", false)),
				"visual_only": str(event.get("kind", "")) != "homing_missile",
			})
		"hazard":
			chaos_runtime_hazards.append({
				"kind": str(event.get("kind", "black_hole")),
				"pos": Vector2(event.get("pos", _chaos_boss_position())),
				"radius": float(event.get("radius", 120.0)),
				"ttl": float(event.get("duration", 2.0)),
				"max_ttl": float(event.get("duration", 2.0)),
				"damage": float(event.get("damage", 0.0)),
				"tick_interval": maxf(0.18, float(event.get("tick", 0.4))),
				"tick": maxf(0.18, float(event.get("tick", 0.4))),
			})
		"summon":
			var summon_position := Vector2(event.get("pos", _chaos_boss_position()))
			var summon_types := ["berserker", "shaman", "heavy"]
			var summon_type := str(summon_types[(next_entity_id + int(game_time * 10.0)) % summon_types.size()])
			var summon_id := _spawn_enemy(summon_type, summon_position, 16, summon_position)
			var summoned: Variant = _find_enemy_by_id(summon_id)
			if summoned != null:
				summoned["chaos_summon"] = true
		"effect":
			var effect_position := Vector2(event.get("pos", _chaos_boss_position()))
			var effect_kind := str(event.get("kind", "chaos"))
			var effect_radius := maxf(18.0, float(event.get("radius", 60.0)))
			var effect_duration := maxf(0.15, float(event.get("duration", 0.5)))
			chaos_runtime_hazards.append({"kind": "effect_%s" % effect_kind, "pos": effect_position, "radius": effect_radius, "ttl": effect_duration, "max_ttl": effect_duration, "damage": 0.0, "tick": 99.0, "tick_interval": 99.0})
			if effect_kind in ["shockwave_ring", "rift_dash", "total_annihilation", "defeat"]:
				camera_shake = maxf(camera_shake, 0.85 if effect_kind in ["total_annihilation", "defeat"] else 0.58)
		"audio":
			var cue := str(event.get("cue", "chaos"))
			_play_chaos_audio(cue)
		"notice":
			var notice_text := str(event.get("text", ""))
			if not notice_text.is_empty():
				_add_notification(notice_text, Color("D8A4FF"), 3.2)
		"phase":
			_add_notification("卡厄隆進入第 %d 階段：%s" % [int(event.get("phase", 1)), str(event.get("name", ""))], Color("FF79D8"), 4.2)
		"reward":
			_complete_chaos_boss_victory(int(event.get("gold", 0)), int(event.get("xp", 0)))
		"defeated":
			_complete_chaos_boss_victory(int(event.get("gold", 0)), int(event.get("xp", 0)))


func _play_chaos_audio(cue: String) -> void:
	var event_name := "boss_hiss"
	if "warning" in cue or "charge" in cue:
		event_name = "warning"
	elif "destruction_beam" in cue:
		event_name = "beam"
	elif "homing_missiles" in cue:
		event_name = "rocket"
	elif "energy_barrage" in cue or "lightning" in cue or "black_hole" in cue:
		event_name = "magic"
	elif "phase" in cue:
		event_name = "boss_phase"
	elif "death" in cue or "defeat" in cue:
		event_name = "boss_death"
	elif "meteor" in cue or "shockwave" in cue or "rift_dash" in cue or "total_annihilation" in cue:
		event_name = "boss_impact"
	audio.play(event_name, 0.88, randf_range(0.96, 1.04))


func _complete_chaos_boss_victory(gold: int, xp: int) -> void:
	if final_boss_defeated:
		return
	final_boss_defeated = true
	all_soldiers_unlocked = true
	timeless_gate_unlocked = true
	ending_seen = kaeron_ending_completed
	ending_pending = not kaeron_ending_completed
	player["money"] = int(player.get("money", 0)) + maxi(0, gold)
	_gain_xp(maxi(0, xp))
	_save_profile_progression()
	_save_game(false)
	_add_notification("全部士兵已解鎖：加特林、直升機、轟炸機、UFO", GOLD, 5.0)


func _begin_ending() -> void:
	ending_pending = false
	ending_elapsed = 0.0
	mode = GameMode.ENDING
	active_panel = ""
	attack_held = false
	touch_move_pointer = -1
	touch_aim_pointer = -1
	touch_move_vector = Vector2.ZERO
	chaos_runtime_projectiles.clear()
	chaos_runtime_hazards.clear()
	for enemy_index in range(enemies.size() - 1, -1, -1):
		if bool(enemies[enemy_index].get("chaos_summon", false)):
			enemies.remove_at(enemy_index)


func _update_ending(delta: float) -> void:
	ending_elapsed += delta
	if ending_elapsed < ENDING_DURATION:
		return
	ending_elapsed = ENDING_DURATION
	ending_seen = true
	kaeron_ending_completed = true
	timeless_gate_unlocked = true
	mode = GameMode.PLAYING
	player["invuln"] = maxf(float(player.get("invuln", 0.0)), 3.0)
	_save_profile_progression()
	_save_game(false)
	_add_notification("遠征終章完成；全部科技兵已永久開放。", GOLD, 4.5)


func _summon_chaos_boss() -> void:
	if not _pause_can_summon_chaos_boss():
		return
	# 重新挑戰只重置 Boss 戰場；永久科技解鎖與玩家軍隊完全保留。
	_initialize_chaos_boss(true)
	all_soldiers_unlocked = true
	final_boss_defeated = false
	ending_seen = kaeron_ending_completed
	ending_pending = false
	ending_elapsed = 0.0
	chaos_runtime_projectiles.clear()
	chaos_runtime_hazards.clear()
	for enemy_index in range(enemies.size() - 1, -1, -1):
		if bool(enemies[enemy_index].get("chaos_summon", false)):
			enemies.remove_at(enemy_index)
	_save_profile_progression()
	mode = GameMode.PLAYING
	active_panel = ""
	_save_game(false)
	_add_notification("萬象崩滅者・卡厄隆已在混沌祭壇重生；位置已標示在地圖。", Color("D8A4FF"), 5.0)


func _ending_state() -> Dictionary:
	var title_alpha := 0.0
	var caviar_alpha := 0.0
	var stage := "black"
	if ending_elapsed >= 0.8 and ending_elapsed < 2.0:
		stage = "title_fade_in"
		title_alpha = smoothstep(0.8, 2.0, ending_elapsed)
	elif ending_elapsed < 3.7 and ending_elapsed >= 2.0:
		stage = "title_hold"
		title_alpha = 1.0
	elif ending_elapsed < 5.1 and ending_elapsed >= 3.7:
		stage = "title_fade_out"
		title_alpha = 1.0 - smoothstep(3.7, 5.1, ending_elapsed)
	elif ending_elapsed < 6.3 and ending_elapsed >= 5.1:
		stage = "caviar_fade_in"
		caviar_alpha = smoothstep(5.1, 6.3, ending_elapsed)
	elif ending_elapsed < 8.1 and ending_elapsed >= 6.3:
		stage = "caviar_hold"
		caviar_alpha = 1.0
	elif ending_elapsed >= 8.1:
		stage = "caviar_fade_out"
		caviar_alpha = 1.0 - smoothstep(8.1, ENDING_DURATION, ending_elapsed)
	return {"active": mode == GameMode.ENDING, "stage": stage, "elapsed": snappedf(ending_elapsed, 0.01), "title_alpha": snappedf(title_alpha, 0.01), "caviar_alpha": snappedf(caviar_alpha, 0.01)}


func _update_chaos_runtime(delta: float) -> void:
	for projectile_index in range(chaos_runtime_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = chaos_runtime_projectiles[projectile_index]
		projectile["ttl"] = float(projectile["ttl"]) - delta
		var target_position := _chaos_target_position(str(projectile.get("target", "player:0")))
		if bool(projectile.get("homing", false)):
			var desired := (target_position - Vector2(projectile["pos"])).normalized()
			var current := Vector2(projectile["vel"])
			var speed := maxf(330.0, current.length())
			var current_direction := current.normalized() if current.length_squared() > 0.01 else desired
			projectile["vel"] = current_direction.lerp(desired, clampf(delta * 2.8, 0.0, 1.0)).normalized() * speed
		projectile["pos"] = Vector2(projectile["pos"]) + Vector2(projectile["vel"]) * delta
		var hit_radius := float(projectile.get("radius", 18.0)) + 20.0
		var impacted := bool(projectile.get("homing", false)) and Vector2(projectile["pos"]).distance_to(target_position) <= hit_radius
		if impacted and not bool(projectile.get("visual_only", false)):
			_chaos_area_damage(Vector2(projectile["pos"]), maxf(45.0, float(projectile.get("aoe", 70.0))), float(projectile.get("damage", 0.0)), "homing_missiles")
			_spawn_effect("explosion", projectile["pos"], Color("FF4FCB"), 1.0)
		if impacted or float(projectile["ttl"]) <= 0.0:
			# 追蹤飛彈到期後直接消散，永遠不會留在世界中。
			chaos_runtime_projectiles.remove_at(projectile_index)

	for hazard_index in range(chaos_runtime_hazards.size() - 1, -1, -1):
		var hazard: Dictionary = chaos_runtime_hazards[hazard_index]
		hazard["ttl"] = float(hazard.get("ttl", 0.0)) - delta
		if str(hazard.get("kind", "")).begins_with("effect_"):
			if float(hazard["ttl"]) <= 0.0:
				chaos_runtime_hazards.remove_at(hazard_index)
			continue
		hazard["tick"] = float(hazard.get("tick", 0.0)) - delta
		if float(hazard["tick"]) <= 0.0:
			hazard["tick"] = float(hazard.get("tick_interval", 0.4))
			_chaos_area_damage(Vector2(hazard["pos"]), float(hazard["radius"]), float(hazard["damage"]), str(hazard.get("kind", "black_hole")))
		if str(hazard.get("kind", "")) == "black_hole":
			var center := Vector2(hazard["pos"])
			if Vector2(player.get("pos", HOUSE_POS)).distance_to(center) <= float(hazard["radius"]) * 1.35:
				player["pos"] = _move_with_collision(player["pos"], (center - Vector2(player["pos"])).limit_length(46.0 * delta), PLAYER_RADIUS, true)
			for soldier in soldiers:
				if Vector2(soldier["pos"]).distance_to(center) <= float(hazard["radius"]) * 1.35:
					soldier["pos"] = _move_with_collision(soldier["pos"], (center - Vector2(soldier["pos"])).limit_length(38.0 * delta), float(soldier["radius"]), true)
		if float(hazard["ttl"]) <= 0.0:
			chaos_runtime_hazards.remove_at(hazard_index)


func _chaos_target_position(target_key: String) -> Vector2:
	var parsed := _parse_python_boss_target(target_key)
	if parsed.is_empty() or str(parsed.get("kind", "")) == "player":
		return Vector2(player.get("pos", HOUSE_POS))
	var soldier: Variant = _find_soldier_by_id(int(parsed.get("id", -1)))
	return Vector2(soldier["pos"]) if soldier != null else Vector2(player.get("pos", HOUSE_POS))


func _chaos_area_damage(center: Vector2, radius: float, damage: float, skill: String) -> void:
	if player.get("alive", false) and Vector2(player["pos"]).distance_to(center) <= radius + PLAYER_RADIUS:
		var player_cap := float(player["max_hp"]) * (0.22 if skill == "black_hole" else 0.58)
		_damage_player(minf(damage, player_cap), center, skill != "black_hole", true)
	for soldier in soldiers:
		if Vector2(soldier["pos"]).distance_to(center) <= radius + float(soldier["radius"]):
			_damage_soldier(soldier, minf(damage, float(soldier["max_hp"]) * 0.72), center, "area")
	_damage_guardians_in_area(center, radius, damage)


# -----------------------------------------------------------------------------
# 超終局 Boss：諸界終時者・艾歐尼斯
# -----------------------------------------------------------------------------

func _update_aionis_boss(delta: float) -> void:
	if not timeless_gate_unlocked or aionis_boss == null:
		return
	if aionis_boss_defeated:
		# Combat payloads are cleared on victory, but the final visual effect still
		# needs to finish its own lifetime instead of freezing forever on screen.
		_update_aionis_runtime(delta)
		return
	var events_value: Variant = aionis_boss.update(delta * _soldier_boss_time_scale(), _aionis_boss_context())
	if events_value is Array:
		for event_value in Array(events_value):
			if event_value is Dictionary:
				_apply_aionis_boss_event(Dictionary(event_value))
	_update_aionis_runtime(delta)


func _aionis_boss_context() -> Dictionary:
	var context_soldiers: Array[Dictionary] = []
	for soldier in soldiers:
		context_soldiers.append({
			"id": int(soldier["id"]), "type": str(soldier["type"]),
			"pos": Vector2(soldier["pos"]), "vel": Vector2(soldier.get("vel", Vector2.ZERO)),
			"hp": float(soldier["hp"]), "max_hp": float(soldier["max_hp"]),
			"radius": float(soldier["radius"]), "alive": float(soldier["hp"]) > 0.0,
			"attack": float(soldier.get("attack", 0.0)),
			"attack_rate": float(soldier.get("attack_rate", 1.0)),
			"domain": str(soldier.get("domain", "ground")),
		})
	return {
		"player": {
			"id": 0, "pos": Vector2(player.get("pos", HOUSE_POS)),
			"vel": Vector2(player.get("vel", Vector2.ZERO)),
			"hp": float(player.get("hp", 0.0)), "max_hp": float(player.get("max_hp", 1.0)),
			"radius": PLAYER_RADIUS, "alive": bool(player.get("alive", true)),
			"attack": _player_damage(1.0), "attack_rate": float(player.get("attack_rate", 1.0)), "domain": "ground",
		},
		"soldiers": context_soldiers,
		"position_blocked": Callable(self, "_python_boss_position_blocked"),
	}


func _apply_aionis_boss_event(event: Dictionary) -> void:
	var event_type := str(event.get("type", ""))
	match event_type:
		"damage":
			var target_key := str(event.get("target", ""))
			if target_key in ["aionis_boss", "aionis_end_of_all_timelines"]:
				return
			var parsed := _parse_python_boss_target(target_key)
			if parsed.is_empty():
				return
			var skill := str(event.get("skill", event.get("source_skill", "aionis")))
			var amount := maxf(0.0, float(event.get("amount", 0.0)))
			var source_position := _aionis_boss_position()
			if str(parsed["kind"]) == "player":
				# 仍然非常致命，但任何單一命中都保留一次反應機會。
				var single_hit_cap := 0.72 if skill == "twelfth_bell" else 0.66
				amount = minf(amount, float(player.get("max_hp", 1.0)) * single_hit_cap)
				_damage_player(amount, source_position, skill in ["clock_sever", "army_judgment", "twelfth_bell"], true)
			else:
				var soldier: Variant = _find_soldier_by_id(int(parsed["id"]))
				if soldier != null:
					amount = minf(amount, float(soldier.get("max_hp", 1.0)) * 0.78)
					_damage_soldier(soldier, amount, source_position, "area")
		"knockback":
			_apply_python_boss_knockback(str(event.get("target", "")), Vector2(event.get("force", event.get("vector", Vector2.ZERO))))
		"projectile":
			var lifetime := clampf(float(event.get("lifetime", 1.0)), 0.05, 6.0)
			var projectile := event.duplicate(true)
			projectile["kind"] = str(event.get("kind", "aionis_orb"))
			projectile["pos"] = Vector2(event.get("pos", _aionis_boss_position()))
			projectile["vel"] = Vector2(event.get("velocity", Vector2.ZERO))
			projectile["radius"] = float(event.get("radius", 18.0))
			projectile["damage"] = float(event.get("damage", 0.0))
			projectile["aoe"] = float(event.get("aoe", 0.0))
			projectile["ttl"] = lifetime
			projectile["max_ttl"] = lifetime
			projectile["target"] = str(event.get("target_id", "player:0"))
			projectile["homing"] = bool(event.get("homing", false))
			projectile["visual_only"] = str(projectile["kind"]) == "aionis_clock_blade"
			var projectile_cap := 28 if _is_touch_scheme() else 48
			if aionis_runtime_projectiles.size() >= projectile_cap:
				aionis_runtime_projectiles.pop_front()
			aionis_runtime_projectiles.append(projectile)
		"hazard":
			var hazard := event.duplicate(true)
			var duration := clampf(float(event.get("duration", 2.0)), 0.05, 8.0)
			hazard["kind"] = str(event.get("kind", "aionis_hazard"))
			hazard["pos"] = Vector2(event.get("pos", _aionis_boss_position()))
			hazard["radius"] = float(event.get("radius", 120.0))
			hazard["ttl"] = duration
			hazard["max_ttl"] = duration
			hazard["damage"] = float(event.get("damage", 0.0))
			hazard["tick_interval"] = maxf(0.16, float(event.get("tick", 0.4)))
			hazard["tick"] = maxf(0.16, float(event.get("tick", 0.4)))
			_aionis_append_runtime_hazard(hazard)
		"summon":
			var summon_kind := str(event.get("kind", ""))
			var summon_position := Vector2(event.get("pos", _aionis_boss_position()))
			if summon_kind == "aionis_parallel_legion":
				var copy_type := _aionis_highest_threat_soldier_type()
				var summon_id := _spawn_enemy(copy_type, summon_position, 50, summon_position)
				var summoned: Variant = _find_enemy_by_id(summon_id)
				if summoned != null:
					summoned["aionis_summon"] = true
					summoned["max_hp"] = float(summoned["max_hp"]) * 1.35
					summoned["hp"] = float(summoned["max_hp"])
					summoned["attack"] = float(summoned["attack"]) * 1.25
			else:
				_aionis_append_runtime_hazard({"kind": "effect_chrono_lock", "pos": summon_position, "radius": 54.0, "ttl": 1.0, "max_ttl": 1.0, "damage": 0.0, "tick": 99.0, "tick_interval": 99.0})
		"effect":
			var effect := event.duplicate(true)
			var effect_duration := maxf(0.12, float(event.get("duration", 0.5)))
			effect["kind"] = "effect_%s" % str(event.get("kind", "aionis"))
			effect["pos"] = Vector2(event.get("pos", _aionis_boss_position()))
			effect["radius"] = maxf(12.0, float(event.get("radius", 60.0)))
			effect["ttl"] = effect_duration
			effect["max_ttl"] = effect_duration
			effect["damage"] = 0.0
			effect["tick"] = 99.0
			effect["tick_interval"] = 99.0
			_aionis_append_runtime_hazard(effect)
			if str(event.get("kind", "")) in ["clock_sever", "army_judgment", "twelfth_bell_cast", "aionis_dead", "aionis_defeat"]:
				camera_shake = maxf(camera_shake, 0.92 if "dead" in str(event.get("kind", "")) or "twelfth" in str(event.get("kind", "")) else 0.60)
		"reflect":
			var reflect_duration := clampf(float(event.get("duration", 1.8)), 0.2, 4.0)
			_aionis_append_runtime_hazard({
				"kind": "reflect_field", "pos": _aionis_boss_position(), "radius": float(event.get("radius", 360.0)),
				"ttl": reflect_duration, "max_ttl": reflect_duration, "damage": 0.0,
				"tick": 99.0, "tick_interval": 99.0, "ratio": clampf(float(event.get("ratio", 0.55)), 0.25, 0.85),
			})
		"combo":
			var combo_count := int(event.get("count", 1))
			_add_notification("艾歐尼斯同時展開 %d 重因果技能！" % combo_count, Color("FF8B78"), 3.2)
			_aionis_append_runtime_hazard({"kind": "effect_combo", "pos": _aionis_boss_position(), "radius": 245.0, "ttl": 0.8, "max_ttl": 0.8, "damage": 0.0, "tick": 99.0, "tick_interval": 99.0, "count": combo_count})
		"audio":
			_play_aionis_audio(str(event.get("cue", "aionis")))
		"notice":
			var notice_text := str(event.get("text", ""))
			if not notice_text.is_empty():
				_add_notification(notice_text, Color("F4C95D"), 3.1)
		"phase":
			_add_notification("艾歐尼斯進入第 %d 階段：%s" % [int(event.get("phase", 1)), str(event.get("name", ""))], Color("F4C95D"), 4.2)
		"reward", "defeated":
			_complete_aionis_boss_victory(int(event.get("gold", 0)), int(event.get("xp", 0)))


func _aionis_append_runtime_hazard(hazard: Dictionary) -> void:
	var cap := 20 if _is_touch_scheme() else 32
	if aionis_runtime_hazards.size() >= cap:
		aionis_runtime_hazards.pop_front()
	aionis_runtime_hazards.append(hazard)


func _aionis_highest_threat_soldier_type() -> String:
	var best_type := "heavy"
	var best_dps := -1.0
	for soldier in soldiers:
		var soldier_type := str(soldier.get("type", "heavy"))
		if not GameConfig.ENEMIES.has(soldier_type):
			continue
		var dps := float(soldier.get("attack", 0.0)) * float(soldier.get("attack_rate", 1.0))
		if dps > best_dps:
			best_dps = dps
			best_type = soldier_type
	return best_type


func _play_aionis_audio(cue: String) -> void:
	var event_name := "time_tick"
	if "warning" in cue or "charge" in cue:
		event_name = "warning"
	elif "clock_sever" in cue:
		event_name = "sword"
	elif "causal_hunt" in cue or "star_gate" in cue:
		event_name = "beam"
	elif "chrono_prison" in cue:
		event_name = "boss_constrict"
	elif "rewind" in cue:
		event_name = "time_rewind"
	elif "parallel" in cue or "mirror" in cue:
		event_name = "magic"
	elif "phase" in cue:
		event_name = "boss_phase"
	elif "anchor_broken" in cue:
		event_name = "time_shatter"
	elif "twelfth" in cue:
		event_name = "time_bell"
	elif "defeat" in cue or "dead" in cue:
		event_name = "boss_death"
	audio.play(event_name, 0.9, randf_range(0.96, 1.04))


func _update_aionis_runtime(delta: float) -> void:
	for projectile_index in range(aionis_runtime_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = aionis_runtime_projectiles[projectile_index]
		var previous := Vector2(projectile.get("pos", _aionis_boss_position()))
		projectile["ttl"] = float(projectile.get("ttl", 0.0)) - delta
		var target_position := _chaos_target_position(str(projectile.get("target", "player:0")))
		if bool(projectile.get("homing", false)):
			var desired := (target_position - previous).normalized()
			var current := Vector2(projectile.get("vel", Vector2.ZERO))
			var speed := maxf(420.0, current.length())
			var current_direction := current.normalized() if current.length_squared() > 0.01 else desired
			projectile["vel"] = current_direction.lerp(desired, clampf(delta * 3.1, 0.0, 1.0)).normalized() * speed
		projectile["pos"] = previous + Vector2(projectile.get("vel", Vector2.ZERO)) * delta
		var impact_position := Vector2(projectile["pos"])
		var impacted := false
		if not bool(projectile.get("visual_only", false)) and Vector2(projectile.get("vel", Vector2.ZERO)).length_squared() > 0.01:
			var best_time := 2.0
			if bool(player.get("alive", false)):
				var player_time := _segment_circle_hit_time(previous, impact_position, Vector2(player["pos"]), PLAYER_RADIUS + float(projectile.get("radius", 18.0)))
				if player_time <= 1.0:
					best_time = player_time
			for soldier in soldiers:
				var soldier_time := _segment_circle_hit_time(previous, impact_position, Vector2(soldier["pos"]), float(soldier["radius"]) + float(projectile.get("radius", 18.0)))
				if soldier_time < best_time:
					best_time = soldier_time
			var guardian_hit := _guardian_projectile_intersection(previous, impact_position, float(projectile.get("radius", 18.0)))
			if bool(guardian_hit.get("hit", false)) and float(guardian_hit.get("time", 2.0)) < best_time:
				best_time = float(guardian_hit["time"])
			if best_time <= 1.0:
				impacted = true
				impact_position = previous.lerp(impact_position, best_time)
		if impacted:
			_aionis_area_damage(impact_position, maxf(float(projectile.get("radius", 18.0)), float(projectile.get("aoe", 0.0))), float(projectile.get("damage", 0.0)), str(projectile.get("kind", "aionis_projectile")), false)
			_spawn_effect("explosion", impact_position, Color("F4C95D"), 0.9)
		var expired := float(projectile["ttl"]) <= 0.0
		if expired and not impacted and not bool(projectile.get("visual_only", false)) and Vector2(projectile.get("vel", Vector2.ZERO)).length_squared() <= 0.01:
			_aionis_area_damage(impact_position, maxf(32.0, float(projectile.get("aoe", 52.0))), float(projectile.get("damage", 0.0)), str(projectile.get("kind", "aionis_fragment")), false)
		if impacted or expired:
			aionis_runtime_projectiles.remove_at(projectile_index)

	for hazard_index in range(aionis_runtime_hazards.size() - 1, -1, -1):
		var hazard: Dictionary = aionis_runtime_hazards[hazard_index]
		hazard["ttl"] = float(hazard.get("ttl", 0.0)) - delta
		var kind := str(hazard.get("kind", ""))
		if not kind.begins_with("effect_") and kind != "reflect_field":
			hazard["tick"] = float(hazard.get("tick", 0.0)) - delta
			if float(hazard["tick"]) <= 0.0:
				hazard["tick"] = float(hazard.get("tick_interval", 0.4))
				_aionis_area_damage(Vector2(hazard["pos"]), float(hazard["radius"]), float(hazard.get("damage", 0.0)), kind, true)
			if kind == "chrono_prison_ring":
				var center := Vector2(hazard["pos"])
				if Vector2(player.get("pos", HOUSE_POS)).distance_to(center) <= float(hazard["radius"]) * 1.15:
					player["pos"] = _move_with_collision(player["pos"], (center - Vector2(player["pos"])).limit_length(26.0 * delta), PLAYER_RADIUS, true)
		if float(hazard["ttl"]) <= 0.0:
			aionis_runtime_hazards.remove_at(hazard_index)


func _aionis_area_damage(center: Vector2, radius: float, damage: float, skill: String, repeated: bool) -> void:
	if damage <= 0.0:
		return
	if bool(player.get("alive", false)) and Vector2(player["pos"]).distance_to(center) <= radius + PLAYER_RADIUS:
		var player_cap := float(player["max_hp"]) * (0.22 if repeated else (0.72 if "twelfth" in skill else 0.52))
		_damage_player(minf(damage, player_cap), center, skill in ["aionis_clock_blade", "twelfth_bell_core"], true)
	for soldier in soldiers:
		if Vector2(soldier["pos"]).distance_to(center) <= radius + float(soldier["radius"]):
			var soldier_cap := float(soldier["max_hp"]) * (0.34 if repeated else 0.74)
			_damage_soldier(soldier, minf(damage, soldier_cap), center, "area")
	_damage_guardians_in_area(center, radius, damage)


func _complete_aionis_boss_victory(gold: int, xp: int) -> void:
	if aionis_boss_defeated:
		return
	aionis_boss_defeated = true
	# Nothing hostile may persist after the kill. A later aionis_dead effect may
	# still be appended by the same event batch; the defeated update path above
	# lets that visual-only effect expire normally.
	_clear_aionis_combat_runtime()
	timeless_gate_unlocked = true
	all_soldiers_unlocked = true
	player["money"] = int(player.get("money", 0)) + maxi(0, gold)
	_gain_xp(maxi(0, xp))
	_save_profile_progression()
	_save_game(false)
	_add_notification("艾歐尼斯已擊破：無時之庭恢復寂靜。", Color("F4C95D"), 5.0)


func _summon_aionis_boss() -> void:
	if not _pause_can_summon_aionis_boss():
		return
	_initialize_aionis_boss(true)
	aionis_boss_defeated = false
	_clear_aionis_combat_runtime()
	mode = GameMode.PLAYING
	active_panel = ""
	_save_game(false)
	_add_notification("諸界終時者・艾歐尼斯已在無時之庭重生；位置已標示在地圖。", Color("F4C95D"), 5.0)


func _clear_aionis_combat_runtime() -> void:
	aionis_runtime_projectiles.clear()
	aionis_runtime_hazards.clear()
	for enemy_index in range(enemies.size() - 1, -1, -1):
		if bool(enemies[enemy_index].get("aionis_summon", false)):
			enemies.remove_at(enemy_index)


func _aionis_boss_position() -> Vector2:
	return Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"]) if aionis_boss == null else aionis_boss.get_position()


func _resolve_aionis_body_collision(point: Vector2, body_radius: float) -> Vector2:
	var center := _aionis_boss_position()
	var offset := point - center
	var minimum: float = body_radius + (float(aionis_boss.get_radius()) if aionis_boss != null else float(GameConfig.AIONIS_BOSS_CONFIG["radius"]))
	if offset.length_squared() >= minimum * minimum:
		return point
	if offset.length_squared() <= 0.0001:
		offset = Vector2.LEFT
	return center + offset.normalized() * minimum


func _aionis_boss_can_be_targeted() -> bool:
	return timeless_gate_unlocked and aionis_boss != null and not aionis_boss_defeated and not aionis_boss.is_defeated() and aionis_boss.is_engaged()


func _aionis_reflection_ratio() -> float:
	var ratio := 0.0
	for hazard in aionis_runtime_hazards:
		if str(hazard.get("kind", "")) == "reflect_field" and float(hazard.get("ttl", 0.0)) > 0.0:
			ratio = maxf(ratio, float(hazard.get("ratio", 0.55)))
	return ratio


func _aionis_reflected_hit_result(source_kind: String, source_id: int, damage: float, hit_position: Vector2) -> Dictionary:
	var target := "player:0" if source_kind == "player" else "soldier:%d" % source_id
	var target_position := _chaos_target_position(target)
	var direction := (target_position - hit_position).normalized()
	if direction.length_squared() <= 0.01:
		direction = Vector2.LEFT
	return {
		"accepted": true, "damage": 0.0,
		"events": [{
			"type": "projectile", "kind": "aionis_reflected_shot", "pos": hit_position,
			"velocity": direction * 720.0, "radius": 15.0,
			"damage": damage * _aionis_reflection_ratio(), "aoe": 52.0,
			"lifetime": 3.2, "target_id": target, "homing": true,
		}, {"type": "audio", "cue": "aionis_causal_mirror"}],
	}


func _consume_aionis_hit_result(result: Dictionary) -> bool:
	if not bool(result.get("accepted", false)):
		return false
	var events_value: Variant = result.get("events", [])
	if events_value is Array:
		for event_value in Array(events_value):
			if event_value is Dictionary:
				_apply_aionis_boss_event(Dictionary(event_value))
	return true


func _chaos_boss_position() -> Vector2:
	return Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"]) if chaos_boss == null else chaos_boss.get_position()


func _chaos_boss_can_be_targeted() -> bool:
	return chaos_boss != null and not final_boss_defeated and not chaos_boss.is_defeated() and chaos_boss.is_engaged()


func _active_boss_kind() -> String:
	if _aionis_boss_can_be_targeted():
		return "aionis"
	if _chaos_boss_can_be_targeted():
		return "chaos"
	if _python_boss_can_be_targeted():
		return "python"
	return ""


func _active_boss_can_be_targeted() -> bool:
	return _active_boss_kind() != ""


func _active_boss_position() -> Vector2:
	var kind := _active_boss_kind()
	if kind == "aionis":
		return _aionis_boss_position()
	return _chaos_boss_position() if kind == "chaos" else _python_boss_position()


func _active_boss_radius() -> float:
	var kind := _active_boss_kind()
	if kind == "aionis":
		return aionis_boss.get_radius()
	return chaos_boss.get_radius() if kind == "chaos" else float(GameConfig.PYTHON_BOSS_CONFIG["body"]["head_radius"])


func _active_boss_target_proxy() -> Dictionary:
	var kind := _active_boss_kind()
	if kind == "aionis":
		var aionis_state: Dictionary = aionis_boss.get_text_state()
		return {"id": BOSS_ENTITY_ID, "type": "aionis_boss", "pos": _aionis_boss_position(), "vel": Vector2(float(aionis_state.get("velocity_x", 0.0)), float(aionis_state.get("velocity_y", 0.0))), "radius": aionis_boss.get_radius(), "hp": float(aionis_state.get("hp", 1.0)), "max_hp": float(aionis_state.get("max_hp", 1.0))}
	if kind == "chaos":
		var state: Dictionary = chaos_boss.get_text_state()
		return {"id": BOSS_ENTITY_ID, "type": "chaos_boss", "pos": _chaos_boss_position(), "vel": Vector2(float(state.get("velocity_x", 0.0)), float(state.get("velocity_y", 0.0))), "radius": chaos_boss.get_radius(), "hp": float(state.get("hp", 1.0)), "max_hp": float(state.get("max_hp", 1.0))}
	return _python_boss_target_proxy()


func _active_boss_projectile_intersection(from: Vector2, to: Vector2, projectile_radius: float) -> Dictionary:
	var kind := _active_boss_kind()
	if kind == "aionis":
		var best_time := _segment_circle_hit_time(from, to, _aionis_boss_position(), aionis_boss.get_radius() + projectile_radius)
		var best_part := "core"
		for anchor in aionis_boss.get_anchor_targets():
			if bool(anchor.get("broken", false)):
				continue
			var anchor_time := _segment_circle_hit_time(from, to, Vector2(anchor["position"]), float(anchor["radius"]) + projectile_radius)
			if anchor_time < best_time:
				best_time = anchor_time
				best_part = "anchor:%s" % str(anchor["id"])
		return {"hit": best_time <= 1.0, "time": best_time, "position": from.lerp(to, clampf(best_time, 0.0, 1.0)), "part": best_part}
	if kind == "chaos":
		var time := _segment_circle_hit_time(from, to, _chaos_boss_position(), chaos_boss.get_radius() + projectile_radius)
		return {"hit": time <= 1.0, "time": time, "position": from.lerp(to, clampf(time, 0.0, 1.0)), "part": "core"}
	if python_boss != null:
		return python_boss.projectile_intersection(from, to, projectile_radius)
	return {"hit": false}


func _update_soldier_boss_debuffs(delta: float) -> void:
	for timer_key in ["slow_ttl", "void_ttl", "focus_ttl"]:
		soldier_boss_debuffs[timer_key] = maxf(0.0, float(soldier_boss_debuffs.get(timer_key, 0.0)) - delta)
	if float(soldier_boss_debuffs.get("slow_ttl", 0.0)) <= 0.0:
		soldier_boss_debuffs["slow_ratio"] = 0.0
	if float(soldier_boss_debuffs.get("void_ttl", 0.0)) <= 0.0:
		soldier_boss_debuffs["void_bonus"] = 0.0
	if float(soldier_boss_debuffs.get("focus_ttl", 0.0)) <= 0.0:
		soldier_boss_debuffs["focus_bonus"] = 0.0
		soldier_boss_debuffs["focus_source_id"] = -1


func _soldier_boss_time_scale() -> float:
	return 1.0 - clampf(float(soldier_boss_debuffs.get("slow_ratio", 0.0)), 0.0, 0.45) if float(soldier_boss_debuffs.get("slow_ttl", 0.0)) > 0.0 else 1.0


func _soldier_boss_damage_multiplier(source_id: int) -> float:
	var multiplier := 1.0
	if float(soldier_boss_debuffs.get("void_ttl", 0.0)) > 0.0:
		multiplier *= 1.0 + clampf(float(soldier_boss_debuffs.get("void_bonus", 0.0)), 0.0, 1.0)
	if float(soldier_boss_debuffs.get("focus_ttl", 0.0)) > 0.0 and int(soldier_boss_debuffs.get("focus_source_id", -1)) != source_id:
		multiplier *= 1.0 + clampf(float(soldier_boss_debuffs.get("focus_bonus", 0.0)), 0.0, 1.0)
	return multiplier


func _apply_soldier_boss_statuses(soldier: Dictionary, hit_damage: float, damage_type: String) -> void:
	var source_id := int(soldier.get("id", -1))
	var frost := _soldier_special(soldier, "frost_arrow")
	if not frost.is_empty():
		soldier_boss_debuffs["slow_ttl"] = maxf(float(soldier_boss_debuffs.get("slow_ttl", 0.0)), float(frost.get("duration", 2.0)))
		soldier_boss_debuffs["slow_ratio"] = maxf(float(soldier_boss_debuffs.get("slow_ratio", 0.0)), float(frost.get("boss_slow_ratio", 0.08)))
	var paralysis := _soldier_special(soldier, "paralysis_arrow")
	if not paralysis.is_empty():
		var sequence := int(Dictionary(soldier.get("special_runtime", {})).get("attack_sequence", 0))
		if sequence > 0 and sequence % maxi(1, int(paralysis.get("arrow_interval", 7))) == 0:
			soldier_boss_debuffs["slow_ttl"] = maxf(float(soldier_boss_debuffs.get("slow_ttl", 0.0)), float(paralysis.get("normal_stun", 0.45)) * 2.0)
			soldier_boss_debuffs["slow_ratio"] = maxf(float(soldier_boss_debuffs.get("slow_ratio", 0.0)), 0.10)
	var suppression := _soldier_special(soldier, "suppression")
	if not suppression.is_empty():
		var hits: Dictionary = Dictionary(soldier_boss_debuffs.get("suppression_hits", {}))
		var key := str(source_id)
		var count := int(hits.get(key, 0)) + 1
		if count >= maxi(1, int(suppression.get("hit_threshold", 6))):
			count = 0
			soldier_boss_debuffs["slow_ttl"] = maxf(float(soldier_boss_debuffs.get("slow_ttl", 0.0)), float(suppression.get("effect_duration", 3.5)))
			var reduced_ratio := maxf(float(suppression.get("move_reduction", 0.2)), float(suppression.get("attack_speed_reduction", 0.1))) * 0.5
			soldier_boss_debuffs["slow_ratio"] = maxf(float(soldier_boss_debuffs.get("slow_ratio", 0.0)), reduced_ratio)
		hits[key] = count
		soldier_boss_debuffs["suppression_hits"] = hits
	var void_mark := _soldier_special(soldier, "void_mark")
	if not void_mark.is_empty():
		soldier_boss_debuffs["void_ttl"] = maxf(float(soldier_boss_debuffs.get("void_ttl", 0.0)), float(void_mark.get("duration", 4.0)))
		soldier_boss_debuffs["void_bonus"] = maxf(float(soldier_boss_debuffs.get("void_bonus", 0.0)), float(void_mark.get("soldier_damage_taken_bonus", 0.0)))
	var focus := _soldier_special(soldier, "focus_mark")
	if not focus.is_empty():
		soldier_boss_debuffs["focus_ttl"] = float(focus.get("effect_duration", 4.0))
		soldier_boss_debuffs["focus_source_id"] = source_id
		soldier_boss_debuffs["focus_bonus"] = float(focus.get("other_ally_damage_bonus", 0.0)) * float(focus.get("boss_multiplier", 0.5))
	var burn := _soldier_special(soldier, "burning_sword" if damage_type == "melee" else "burning_ammo")
	if not burn.is_empty():
		_refresh_soldier_boss_dot("boss_burn", soldier, hit_damage, float(burn.get("total_burn_ratio", 0.0)), float(burn.get("duration", 3.0)), 1)
	var poison := _soldier_special(soldier, "toxic_payload")
	if not poison.is_empty():
		_refresh_soldier_boss_dot("boss_poison", soldier, hit_damage, float(poison.get("total_poison_ratio", 0.0)), float(poison.get("duration", 5.0)), maxi(1, int(poison.get("max_stacks", 3))))
	var taunt := _soldier_special(soldier, "taunt_guard")
	if not taunt.is_empty() and _active_boss_kind() == "python" and python_boss != null and python_boss.is_engaged():
		python_boss.add_threat("soldier", source_id, 14.0)


func _refresh_soldier_boss_dot(kind: String, soldier: Dictionary, hit_damage: float, total_ratio: float, duration: float, max_stacks: int) -> void:
	var safe_duration := maxf(0.1, duration)
	for effect in upgrade_effects:
		if str(effect.get("kind", "")) != kind or int(effect.get("source_id", -1)) != int(soldier["id"]):
			continue
		effect["ttl"] = safe_duration
		effect["stacks"] = mini(max_stacks, int(effect.get("stacks", 1)) + 1)
		effect["damage_per_stack"] = maxf(float(effect.get("damage_per_stack", 0.0)), hit_damage * total_ratio / safe_duration * 0.5)
		return
	_add_upgrade_runtime_effect({
		"kind": kind, "source_id": int(soldier["id"]), "source_kind": "upgrade_dot", "pos": _active_boss_position(),
		"ttl": safe_duration, "warmup": 0.0, "radius": 34.0, "tick": 0.5, "tick_interval": 0.5,
		"stacks": 1, "damage_per_stack": hit_damage * total_ratio / safe_duration * 0.5,
		"max_per_owner": 1, "color": FIRE_ORANGE if kind == "boss_burn" else Color("83D16F"),
	})


func _receive_active_boss_hit(attack_id: Variant, source_kind: String, source_id: int, damage: float, hit_position: Vector2, damage_type: String, armor_penetration: float = 0.0) -> Dictionary:
	var soldier_source: Variant = _find_soldier_by_id(source_id)
	var is_direct_soldier_hit := soldier_source != null and GameConfig.SOLDIERS.has(source_kind) and damage_type != "status" and not damage_type.begins_with("upgrade")
	if is_direct_soldier_hit:
		damage *= _soldier_boss_damage_multiplier(source_id)
		_apply_soldier_boss_statuses(soldier_source, damage, damage_type)
		if damage_type == "melee":
			var armor_core := _soldier_special(soldier_source, "armor_piercing_core")
			armor_penetration += float(armor_core.get("ignored_armor", 0.0)) if not armor_core.is_empty() else 0.0
	var kind := _active_boss_kind()
	var result: Dictionary
	if kind == "aionis":
		for anchor in aionis_boss.get_anchor_targets():
			if bool(anchor.get("broken", false)):
				continue
			if hit_position.distance_to(Vector2(anchor["position"])) <= float(anchor["radius"]) * 1.35:
				result = aionis_boss.receive_anchor_hit(str(anchor["id"]), damage, "%s:%d" % [source_kind, source_id])
				break
		if result.is_empty():
			if damage_type in ["projectile", "beam"] and _aionis_reflection_ratio() > 0.0:
				result = _aionis_reflected_hit_result(source_kind, source_id, damage, hit_position)
			else:
				result = aionis_boss.receive_hit(damage, "%s:%d" % [source_kind, source_id], hit_position, "critical" if armor_penetration >= 18.0 else damage_type)
	elif kind == "chaos":
		result = chaos_boss.receive_hit(damage, "%s:%d" % [source_kind, source_id], hit_position, "critical" if armor_penetration >= 18.0 else damage_type)
	elif python_boss != null:
		result = python_boss.receive_hit(attack_id, source_kind, source_id, damage, hit_position, damage_type, armor_penetration)
	if is_direct_soldier_hit and bool(result.get("accepted", false)):
		var specials: Dictionary = Dictionary(Dictionary(soldier_source.get("upgrade_snapshot", {})).get("special_effects", {}))
		_apply_soldier_lifesteal(source_id, float(result.get("damage", 0.0)), specials)
	return result


func _consume_active_boss_hit_result(result: Dictionary) -> bool:
	if not bool(result.get("accepted", false)):
		return false
	var events_value: Variant = result.get("events", [])
	var chaos_result := false
	var aionis_result := false
	if events_value is Array:
		for probe_value in Array(events_value):
			if probe_value is Dictionary:
				var probe: Dictionary = Dictionary(probe_value)
				var probe_kind := str(probe.get("kind", ""))
				if str(probe.get("target", "")) == "aionis_boss" or str(probe.get("source", "")) == "aionis_boss" or str(probe.get("cue", "")).begins_with("aionis_") or probe_kind.begins_with("aionis_") or probe_kind.begins_with("time_anchor") or probe_kind == "anchor_broken":
					aionis_result = true
					break
				if str(probe.get("target", "")) == "chaos_boss" or str(probe.get("source", "")) == "chaos_boss" or str(probe.get("cue", "")).begins_with("chaos_"):
					chaos_result = true
					break
	if events_value is Array:
		for event_value in Array(events_value):
			if event_value is Dictionary:
				if aionis_result:
					_apply_aionis_boss_event(Dictionary(event_value))
				elif chaos_result:
					_apply_chaos_boss_event(Dictionary(event_value))
				else:
					_apply_python_boss_event(Dictionary(event_value))
	return true


func _damage_active_boss_melee(attack_id: Variant, origin: Vector2, facing: Vector2, radius: float, arc: float, damage: float, source_kind: String, source_id: int, armor_penetration: float = 0.0) -> bool:
	if not _active_boss_can_be_targeted():
		return false
	if _active_boss_kind() == "aionis":
		for anchor in aionis_boss.get_anchor_targets():
			if bool(anchor.get("broken", false)):
				continue
			var anchor_position := Vector2(anchor["position"])
			var anchor_offset := anchor_position - origin
			if anchor_offset.length() <= radius + float(anchor["radius"]) and (anchor_offset.length_squared() <= 0.001 or absf(facing.angle_to(anchor_offset.normalized())) <= arc * 0.5):
				return _consume_active_boss_hit_result(_receive_active_boss_hit(attack_id, source_kind, source_id, damage, anchor_position, "melee", armor_penetration))
	var target_position := _active_boss_position()
	var offset := target_position - origin
	if offset.length() > radius + _active_boss_radius():
		return false
	if offset.length_squared() > 0.001 and absf(facing.angle_to(offset.normalized())) > arc * 0.5:
		return false
	if _active_boss_kind() == "python":
		return _damage_python_boss_melee(attack_id, origin, facing, radius, arc, damage, source_kind, source_id, armor_penetration)
	if _active_boss_kind() == "aionis" and _aionis_reflection_ratio() > 0.0:
		# Rift Board and Causal Mirror reflect melee as a real finite homing
		# projectile, matching their warning text while preserving counterplay.
		return _consume_aionis_hit_result(_aionis_reflected_hit_result(source_kind, source_id, damage, target_position))
	return _consume_active_boss_hit_result(_receive_active_boss_hit(attack_id, source_kind, source_id, damage, target_position, "melee", armor_penetration))


func _apply_python_boss_knockback(target_key: String, motion: Vector2) -> void:
	var parsed: Dictionary = _parse_python_boss_target(target_key)
	if parsed.is_empty():
		return
	if str(parsed["kind"]) == "player":
		player["pos"] = _move_with_collision(player["pos"], motion, PLAYER_RADIUS, true)
		player["vel"] = Vector2.ZERO
		return
	var soldier: Variant = _find_soldier_by_id(int(parsed["id"]))
	if soldier != null:
		if str(soldier["type"]) == "priest":
			soldier["cast_timer"] = 0.0
		soldier["pos"] = _move_with_collision(soldier["pos"], motion, float(soldier["radius"]), true)
		soldier["vel"] = Vector2.ZERO


func _apply_python_boss_anchor(target_key: String, anchor: Vector2) -> void:
	var parsed: Dictionary = _parse_python_boss_target(target_key)
	if parsed.is_empty():
		return
	if str(parsed["kind"]) == "player":
		player["pos"] = anchor
		player["vel"] = Vector2.ZERO
		return
	var soldier: Variant = _find_soldier_by_id(int(parsed["id"]))
	if soldier != null:
		soldier["pos"] = anchor
		soldier["vel"] = Vector2.ZERO
		soldier["state"] = "constricted"


func _play_python_boss_audio(kind: String) -> void:
	var audio_config: Dictionary = Dictionary(GameConfig.PYTHON_BOSS_CONFIG["audio"])
	var event_key: String = kind
	match kind:
		"constrict": event_key = "constrict"
		"dash": event_key = "dash"
		"bite": event_key = "bite"
		"poison", "poison_pool": event_key = "poison"
		"bubble": event_key = "bubble"
		"tail", "tail_sweep": event_key = "tail"
		"impact", "wall_impact": event_key = "impact"
		"stun": event_key = "stun"
		"phase": event_key = "phase"
		"death": event_key = "death"
	var cue: String = str(audio_config.get(event_key, kind))
	audio.play(cue, 0.85, randf_range(0.97, 1.03))


func _boss_part_label(part: String) -> String:
	if part == "head": return "頭部"
	if part == "tail": return "尾部"
	return "身軀"


func _python_boss_position() -> Vector2:
	if python_boss == null:
		return _python_boss_lair_home(active_python_boss_lair_id)
	var state: Dictionary = python_boss.get_text_state()
	return Vector2(float(state.get("x", 0.0)), float(state.get("y", 0.0)))


func _python_boss_can_be_targeted() -> bool:
	if python_boss == null or python_boss.is_defeated():
		return false
	var state: Dictionary = python_boss.get_text_state()
	return bool(state.get("discovered", false)) or bool(state.get("engaged", false))


func _python_boss_target_proxy() -> Dictionary:
	var state: Dictionary = python_boss.get_text_state() if python_boss != null else {}
	return {
		"id": BOSS_ENTITY_ID,
		"type": "python_boss",
		"pos": _python_boss_position(),
		"vel": Vector2(float(state.get("velocity_x", 0.0)), float(state.get("velocity_y", 0.0))),
		"radius": float(GameConfig.PYTHON_BOSS_CONFIG["body"]["head_radius"]),
		"hp": float(state.get("hp", 1.0)),
		"max_hp": float(state.get("max_hp", 1.0)),
	}


func _allocate_attack_id(prefix: String) -> String:
	var id: int = next_entity_id
	next_entity_id += 1
	return "%s:%d" % [prefix, id]


func _damage_python_boss_melee(attack_id: Variant, origin: Vector2, facing: Vector2, radius: float, arc: float, damage: float, source_kind: String, source_id: int, armor_penetration: float = 0.0) -> bool:
	if python_boss == null or python_boss.is_defeated():
		return false
	var best_segment: Dictionary = {}
	var best_distance := INF
	for segment_value in python_boss.body_snapshot():
		if not segment_value is Dictionary:
			continue
		var segment: Dictionary = Dictionary(segment_value)
		var offset: Vector2 = Vector2(segment["pos"]) - origin
		var distance: float = offset.length()
		if distance > radius + float(segment["radius"]):
			continue
		if offset.length_squared() > 0.001 and absf(facing.angle_to(offset.normalized())) > arc * 0.5:
			continue
		if distance < best_distance:
			best_distance = distance
			best_segment = segment
	if best_segment.is_empty():
		return false
	var result: Dictionary = _receive_active_boss_hit(attack_id, source_kind, source_id, damage, Vector2(best_segment["pos"]), "melee", armor_penetration)
	return _consume_active_boss_hit_result(result)


func _consume_python_boss_hit_result(result: Dictionary) -> bool:
	if not bool(result.get("accepted", false)):
		return false
	var events_value: Variant = result.get("events", [])
	if events_value is Array:
		for event_value in Array(events_value):
			if event_value is Dictionary:
				_apply_python_boss_event(Dictionary(event_value))
	return true


func _update_player(delta: float) -> void:
	player["attack_cd"] = max(0.0, float(player["attack_cd"]) - delta)
	player["special_cd"] = max(0.0, float(player["special_cd"]) - delta)
	player["invuln"] = max(0.0, float(player["invuln"]) - delta)
	player["hit_grace"] = max(0.0, float(player.get("hit_grace", 0.0)) - delta)
	player["support_shield_ttl"] = max(0.0, float(player.get("support_shield_ttl", 0.0)) - delta)
	if float(player.get("support_shield_ttl", 0.0)) <= 0.0:
		player["support_shield"] = 0.0
	player["flash"] = max(0.0, float(player["flash"]) - delta)
	var attack_target := _touch_attack_target() if _is_touch_scheme() else _screen_to_world(get_viewport().get_mouse_position())
	var aim: Vector2 = attack_target - Vector2(player["pos"])
	if aim.length_squared() > 16.0:
		player["facing"] = aim.normalized()
	if python_boss != null and python_boss.is_rooted("player", 0):
		player["dash_timer"] = 0.0
		player["vel"] = Vector2.ZERO
		return

	if float(player["dash_timer"]) > 0.0:
		player["dash_timer"] = max(0.0, float(player["dash_timer"]) - delta)
		var old_pos: Vector2 = player["pos"]
		var dash_motion: Vector2 = Vector2(player["dash_dir"]) * 760.0 * delta
		player["pos"] = _move_with_collision(old_pos, dash_motion, PLAYER_RADIUS, true)
		if python_boss != null and not python_boss.is_defeated():
			player["pos"] = python_boss.resolve_body_collision(player["pos"], PLAYER_RADIUS)
		if aionis_boss != null and timeless_gate_unlocked and not aionis_boss.is_defeated():
			player["pos"] = _resolve_aionis_body_collision(player["pos"], PLAYER_RADIUS)
		player["vel"] = (Vector2(player["pos"]) - old_pos) / maxf(delta, 0.0001)
		_damage_enemies_along_dash(player["pos"])
		_spawn_trail_particle(old_pos, FRIEND_BLUE)
		if float(player["dash_timer"]) <= 0.0:
			_player_melee_attack(105.0, TAU * 0.92, _player_damage(1.65), true)
			_spawn_effect("slash", player["pos"], GOLD, 1.4)
		return

	var move_input := touch_move_vector if _is_touch_scheme() else Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	if move_input.length_squared() > 1.0:
		move_input = move_input.normalized()
	var speed := _player_move_speed()
	var old_move_position: Vector2 = Vector2(player["pos"])
	var desired_velocity := move_input * speed
	player["pos"] = _move_with_collision(player["pos"], desired_velocity * delta, PLAYER_RADIUS, true)
	player["pos"] = _separate_position_from_units(player["pos"], PLAYER_RADIUS, enemies, true)
	player["pos"] = _separate_position_from_units(player["pos"], PLAYER_RADIUS, soldiers, true)
	if python_boss != null and not python_boss.is_defeated():
		player["pos"] = python_boss.resolve_body_collision(player["pos"], PLAYER_RADIUS)
	if aionis_boss != null and timeless_gate_unlocked and not aionis_boss.is_defeated():
		player["pos"] = _resolve_aionis_body_collision(player["pos"], PLAYER_RADIUS)
	player["vel"] = (Vector2(player["pos"]) - old_move_position) / maxf(delta, 0.0001)
	if attack_held and active_panel == "":
		_try_player_attack(attack_target)


func _update_camera(delta: float) -> void:
	if player.is_empty():
		return
	var look_ahead: Vector2 = Vector2(player.get("facing", Vector2.RIGHT)) * 52.0
	camera_target = Vector2(player.get("pos", HOUSE_POS)) + look_ahead
	camera_pos = camera_pos.lerp(camera_target, 1.0 - exp(-7.0 * delta))
	camera_shake = max(0.0, camera_shake - delta * 3.8)
	if camera_shake > 0.0:
		camera_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * camera_shake * camera_shake * 8.0
	else:
		camera_shake_offset = Vector2.ZERO


func _update_active_chunks(force: bool) -> void:
	var center := world_generator.world_to_chunk(player["pos"])
	var pin_boss_chunks := false
	var boss_center := Vector2i(999999, 999999)
	if _active_boss_can_be_targeted():
		pin_boss_chunks = true
		boss_center = world_generator.world_to_chunk(_active_boss_position())
	var streaming_layout_changed := (
		center != _last_active_center
		or pin_boss_chunks != _boss_chunks_pinned_last
		or (pin_boss_chunks and boss_center != _last_boss_active_center)
	)
	if not force and not streaming_layout_changed:
		for active_key in active_chunks.keys():
			_restore_chunk_enemy_state(str(active_key))
			_spawn_pending_chunk_enemies(str(active_key), active_chunks[active_key])
		return
	_last_active_center = center
	_last_boss_active_center = boss_center
	_boss_chunks_pinned_last = pin_boss_chunks
	var needed: Dictionary = {}
	for y in range(center.y - ACTIVE_CHUNK_RADIUS, center.y + ACTIVE_CHUNK_RADIUS + 1):
		for x in range(center.x - ACTIVE_CHUNK_RADIUS, center.x + ACTIVE_CHUNK_RADIUS + 1):
			var coord := Vector2i(x, y)
			var key := world_generator.chunk_key(coord)
			needed[key] = true
			if not active_chunks.has(key):
				_activate_chunk(coord)
	if pin_boss_chunks:
		for boss_y in range(boss_center.y - 1, boss_center.y + 2):
			for boss_x in range(boss_center.x - 1, boss_center.x + 2):
				var boss_coord := Vector2i(boss_x, boss_y)
				var boss_key := world_generator.chunk_key(boss_coord)
				needed[boss_key] = true
				if not active_chunks.has(boss_key):
					_activate_chunk(boss_coord)
	var remove_keys: Array = []
	for key in active_chunks.keys():
		if not needed.has(key):
			remove_keys.append(key)
	for key in remove_keys:
		active_chunks.erase(key)
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		var enemy_chunk := world_generator.world_to_chunk(enemy["pos"])
		var enemy_key := world_generator.chunk_key(enemy_chunk)
		if not needed.has(enemy_key) and Vector2(enemy["pos"]).distance_to(player["pos"]) > 1200.0:
			var stored: Array = chunk_states.get(enemy_key, [])
			stored.append(enemy.duplicate(true))
			chunk_states[enemy_key] = stored
			enemies.remove_at(i)
	_trim_streaming_history(center)


func _activate_chunk(coord: Vector2i) -> void:
	var data: Dictionary = world_generator.generate_chunk(coord)
	_clear_python_boss_home_trees(data)
	var key: String = data["key"]
	active_chunks[key] = data
	discovered_chunks[key] = true
	if data["castle"] != null:
		_register_castle(data["castle"])
	if data["camp"] != null:
		var camp_id := str(data["camp"]["id"])
		var camp_was_known := camps.has(camp_id)
		_register_camp(data["camp"])
		var active_camp: Dictionary = camps[camp_id]
		if camp_was_known and not bool(active_camp["cleared"]) and not bool(active_camp["spawned"]) and _enemies_with_camp(camp_id) == 0:
			_spawn_camp_guards(active_camp)
	if data.get("snake_nest") != null:
		_register_snake_nest(Dictionary(data["snake_nest"]))
	_restore_chunk_enemy_state(key)
	_spawn_pending_chunk_enemies(key, data)


func _clear_python_boss_home_trees(chunk: Dictionary) -> void:
	var centers: Array[Vector2] = []
	var main_home := Vector2(GameConfig.PYTHON_BOSS_CONFIG["home_position"])
	if Vector2i(chunk.get("chunk", Vector2i.ZERO)) == world_generator.world_to_chunk(main_home):
		centers.append(main_home)
	var chaos_home := Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"])
	# 混沌祭壇位於 Chunk 邊界；每個已啟用 Chunk 都檢查距離，才能清掉四象限內的樹。
	centers.append(chaos_home)
	var aionis_home := Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"])
	centers.append(aionis_home)
	var descriptor_value: Variant = chunk.get("snake_nest")
	if typeof(descriptor_value) == TYPE_DICTIONARY:
		centers.append(Vector2(Dictionary(descriptor_value).get("position", Vector2.ZERO)))
	if centers.is_empty():
		return
	var obstacles: Array = Array(chunk.get("obstacles", []))
	for index in range(obstacles.size() - 1, -1, -1):
		var obstacle: Dictionary = Dictionary(obstacles[index])
		if not _obstacle_blocks_movement(obstacle):
			continue
		for center in centers:
			var clear_radius := 720.0 if center == aionis_home else (380.0 if center == chaos_home else BOSS_HOME_CLEAR_RADIUS)
			if Vector2(obstacle["position"]).distance_to(center) <= clear_radius + float(obstacle["radius"]):
				obstacles.remove_at(index)
				break
	chunk["obstacles"] = obstacles


func _restore_chunk_enemy_state(key: String) -> void:
	if not chunk_states.has(key):
		return
	var stored: Array = chunk_states[key]
	var remaining: Array = []
	for entry in stored:
		if enemies.size() >= MAX_ENEMIES:
			remaining.append(Dictionary(entry).duplicate(true))
		else:
			var restored_enemy := Dictionary(entry).duplicate(true)
			_normalize_loaded_enemy(restored_enemy)
			enemies.append(restored_enemy)
	if remaining.is_empty():
		chunk_states.erase(key)
	else:
		chunk_states[key] = remaining


func _spawn_pending_chunk_enemies(key: String, data: Dictionary) -> void:
	var spawn_queue: Array = []
	if pending_chunk_spawns.has(key):
		for entry in pending_chunk_spawns[key]:
			spawn_queue.append(Dictionary(entry).duplicate(true))
	elif not spawned_chunks.has(key):
		for entry in data["enemy_spawns"]:
			spawn_queue.append(Dictionary(entry).duplicate(true))
	else:
		return
	var remaining: Array = []
	for spawn_data in spawn_queue:
		if enemies.size() >= MAX_ENEMIES:
			remaining.append(spawn_data)
			continue
		var spawn_pos: Vector2 = spawn_data["position"]
		if spawn_pos.distance_to(player["pos"]) < float(GameConfig.WORLD_SETTINGS["min_spawn_distance"]):
			remaining.append(spawn_data)
			continue
		var spawn_level := maxi(int(spawn_data["level"]), _world_difficulty(spawn_pos))
		_spawn_enemy(str(spawn_data["type"]), spawn_pos, spawn_level, spawn_pos)
	if remaining.is_empty():
		pending_chunk_spawns.erase(key)
		spawned_chunks[key] = true
	else:
		pending_chunk_spawns[key] = remaining


func _trim_streaming_history(center: Vector2i) -> void:
	while chunk_states.size() > MAX_INACTIVE_ENEMY_CHUNKS:
		var enemy_state_key := _farthest_chunk_key(chunk_states.keys(), center)
		if enemy_state_key.is_empty(): break
		_evict_inactive_enemy_state(enemy_state_key)
	while pending_chunk_spawns.size() > MAX_INACTIVE_ENEMY_CHUNKS:
		var pending_key := _farthest_chunk_key(pending_chunk_spawns.keys(), center)
		if pending_key.is_empty(): break
		pending_chunk_spawns.erase(pending_key)
		spawned_chunks.erase(pending_key)
	while discovered_chunks.size() > MAX_STREAM_HISTORY_CHUNKS:
		var history_key := _farthest_chunk_key(discovered_chunks.keys(), center)
		if history_key.is_empty(): break
		_evict_inactive_enemy_state(history_key)
		discovered_chunks.erase(history_key)


func _evict_inactive_enemy_state(key: String) -> void:
	for stored_enemy in chunk_states.get(key, []):
		var enemy: Dictionary = stored_enemy
		var camp_id := str(enemy.get("camp_id", ""))
		var castle_id := str(enemy.get("guard_castle", ""))
		if not camp_id.is_empty() and camps.has(camp_id):
			camps[camp_id]["spawned"] = false
		if not castle_id.is_empty() and castles.has(castle_id):
			castles[castle_id]["spawn_timer"] = 0.0
	chunk_states.erase(key)
	pending_chunk_spawns.erase(key)
	spawned_chunks.erase(key)


func _farthest_chunk_key(keys: Array, center: Vector2i) -> String:
	var farthest_key := ""
	var farthest_distance := -1
	for value in keys:
		var key := str(value)
		if active_chunks.has(key):
			continue
		var parts := key.split(",")
		if parts.size() != 2:
			continue
		var coord := Vector2i(int(parts[0]), int(parts[1]))
		var delta := coord - center
		var distance := delta.x * delta.x + delta.y * delta.y
		if distance > farthest_distance:
			farthest_distance = distance
			farthest_key = key
	return farthest_key


func _world_difficulty(position: Vector2) -> int:
	return GameConfig.difficulty_at(position.distance_to(HOUSE_POS))


func _is_position_active(position: Vector2) -> bool:
	var key := world_generator.chunk_key(world_generator.world_to_chunk(position))
	return active_chunks.has(key)


func _register_castle(descriptor: Dictionary) -> void:
	var id := str(descriptor["id"])
	if castles.has(id):
		return
	var castle_position := Vector2(descriptor["position"])
	var level := clampi(maxi(int(descriptor.get("level", 1)), _world_difficulty(castle_position)), 1, int(GameConfig.CASTLE_SETTINGS["max_level"]))
	var max_hp := float(GameConfig.CASTLE_SETTINGS["hp"] + GameConfig.CASTLE_SETTINGS["hp_per_level"] * (level - 1))
	var tier := GameConfig.castle_tier_for_level(level)
	var tier_cfg: Dictionary = GameConfig.castle_tier(level)
	var wall_max_hp := max_hp * float(tier_cfg.get("wall_ratio", 0.0))
	var nation := NationCatalog.metadata_for_castle(world_seed, id, castle_position)
	castles[id] = {
		"id": id,
		"pos": castle_position,
		"level": level,
		"tier": tier,
		"tier_name": str(tier_cfg.get("name", "蠻族城堡")),
		"hp": max_hp,
		"max_hp": max_hp,
		"wall_hp": wall_max_hp,
		"wall_max_hp": wall_max_hp,
		"wall_breached": wall_max_hp <= 0.0,
		"owned": false,
		"destroyed": false,
		"capture": 0.0,
		"income_timer": float(GameConfig.CASTLE_SETTINGS["income_interval"]),
		"spawn_timer": 3.0,
		"tower_cd": 1.5,
		"under_attack": 0.0,
		"nation": nation,
		"original_nation": nation.duplicate(true),
	}
	_spawn_castle_guard_wave(castles[id], true)


func _register_camp(descriptor: Dictionary) -> void:
	var id := str(descriptor["id"])
	if camps.has(id):
		return
	var camp_position := Vector2(descriptor["position"])
	camps[id] = {
		"id": id,
		"pos": camp_position,
		"level": maxi(int(descriptor.get("level", 1)), _world_difficulty(camp_position)),
		"cleared": false,
		"crate_hp": float(GameConfig.CAMP_SETTINGS["crate_hp"]),
		"respawn_at": 0.0,
		"spawned": false,
	}
	_spawn_camp_guards(camps[id])


func _register_snake_nest(descriptor: Dictionary) -> void:
	var id := str(descriptor.get("id", ""))
	if id.is_empty() or snake_nests.has(id):
		return
	var nest_position := Vector2(descriptor.get("position", Vector2.ZERO))
	snake_nests[id] = {
		"id": id,
		"pos": nest_position,
		"level": maxi(1, int(descriptor.get("level", 1))),
		"discovered": bool(descriptor.get("discovered", true)),
		"cleared": bool(descriptor.get("cleared", false)),
	}


func _migrate_loaded_python_boss_lairs(saved_nests_value: Variant) -> Dictionary:
	# Older saves used a dense 5x5 grid and snake_nest_* IDs. Rebuild their
	# markers against the current deterministic 11x11 layout, drop obsolete
	# locations, and merge old/new entries by the canonical lair ID.
	var migrated: Dictionary = {}
	if typeof(saved_nests_value) != TYPE_DICTIONARY:
		return migrated
	for saved_value in Dictionary(saved_nests_value).values():
		if typeof(saved_value) != TYPE_DICTIONARY:
			continue
		var saved: Dictionary = saved_value
		if typeof(saved.get("pos")) != TYPE_VECTOR2:
			continue
		var saved_position := Vector2(saved["pos"])
		if not saved_position.is_finite():
			continue
		var chunk_coord := world_generator.world_to_chunk(saved_position)
		var generated: Dictionary = world_generator.generate_chunk(chunk_coord)
		var descriptor_value: Variant = generated.get("snake_nest")
		if typeof(descriptor_value) != TYPE_DICTIONARY:
			continue
		var descriptor: Dictionary = descriptor_value
		var current_id := str(descriptor.get("id", ""))
		if current_id.is_empty():
			continue
		var cleared := bool(saved.get("cleared", saved.get("nest_cleared", false)))
		var discovered := bool(saved.get("discovered", true)) or cleared
		if migrated.has(current_id):
			migrated[current_id]["discovered"] = bool(migrated[current_id].get("discovered", false)) or discovered
			migrated[current_id]["cleared"] = bool(migrated[current_id].get("cleared", false)) or cleared
			continue
		migrated[current_id] = {
			"id": current_id,
			"pos": Vector2(descriptor.get("position", saved["pos"])),
			"level": maxi(1, int(descriptor.get("level", saved.get("level", 1)))),
			"discovered": discovered,
			"cleared": cleared,
		}
	return migrated


func _resolve_saved_python_boss_lair_binding(data: Dictionary) -> Dictionary:
	var main_home := Vector2(GameConfig.PYTHON_BOSS_CONFIG["home_position"])
	if not data.has("boss_lair_state"):
		return {"valid": true, "id": MAIN_PYTHON_BOSS_LAIR_ID, "home": main_home, "cleared": false, "legacy": true}
	if typeof(data["boss_lair_state"]) != TYPE_DICTIONARY:
		return {"valid": false}
	var saved_lair_state: Dictionary = Dictionary(data["boss_lair_state"])
	if typeof(saved_lair_state.get("active_lair_id")) != TYPE_STRING or typeof(saved_lair_state.get("main_cleared")) != TYPE_BOOL:
		return {"valid": false}
	var requested_id := str(saved_lair_state["active_lair_id"])
	if requested_id == MAIN_PYTHON_BOSS_LAIR_ID:
		return {
			"valid": true,
			"id": MAIN_PYTHON_BOSS_LAIR_ID,
			"home": main_home,
			"cleared": bool(saved_lair_state["main_cleared"]),
			"legacy": false,
		}
	var saved_nests: Dictionary = Dictionary(data.get("snake_nests", {}))
	if not saved_nests.has(requested_id) or typeof(saved_nests[requested_id]) != TYPE_DICTIONARY:
		return {"valid": false}
	var requested_nest: Dictionary = Dictionary(saved_nests[requested_id])
	if typeof(requested_nest.get("pos")) != TYPE_VECTOR2 or typeof(requested_nest.get("cleared")) != TYPE_BOOL:
		return {"valid": false}
	var requested_position := Vector2(requested_nest["pos"])
	if not requested_position.is_finite():
		return {"valid": false}
	# Canonicalize against the saved world's deterministic generator before any
	# session state is mutated. Legacy/rekeyed IDs remain loadable when their
	# location still hosts a current lair; obsolete locations are rejected rather
	# than silently restoring their boss snapshot into the fixed main lair.
	var saved_generator := WorldGenerator.new(int(data.get("world_seed", 20260731)))
	var generated_chunk := saved_generator.generate_chunk(saved_generator.world_to_chunk(requested_position))
	var generated_descriptor_value: Variant = generated_chunk.get("snake_nest")
	if typeof(generated_descriptor_value) != TYPE_DICTIONARY:
		return {"valid": false}
	var generated_descriptor: Dictionary = Dictionary(generated_descriptor_value)
	var canonical_id := str(generated_descriptor.get("id", ""))
	var canonical_home := Vector2(generated_descriptor.get("position", requested_position))
	if canonical_id.is_empty() or not canonical_home.is_finite():
		return {"valid": false}
	var canonical_cleared := bool(requested_nest["cleared"])
	for candidate_value in saved_nests.values():
		if typeof(candidate_value) != TYPE_DICTIONARY:
			continue
		var candidate_nest: Dictionary = Dictionary(candidate_value)
		if typeof(candidate_nest.get("pos")) != TYPE_VECTOR2 or typeof(candidate_nest.get("cleared", candidate_nest.get("nest_cleared"))) != TYPE_BOOL:
			continue
		var candidate_position := Vector2(candidate_nest["pos"])
		if not candidate_position.is_finite():
			continue
		var candidate_chunk := saved_generator.generate_chunk(saved_generator.world_to_chunk(candidate_position))
		var candidate_descriptor_value: Variant = candidate_chunk.get("snake_nest")
		if typeof(candidate_descriptor_value) == TYPE_DICTIONARY and str(Dictionary(candidate_descriptor_value).get("id", "")) == canonical_id:
			canonical_cleared = canonical_cleared or bool(candidate_nest.get("cleared", candidate_nest.get("nest_cleared", false)))
	return {
		"valid": true,
		"id": canonical_id,
		"home": canonical_home,
		"cleared": canonical_cleared,
		"legacy": false,
	}


func _snake_nest_text_state(player_position: Vector2) -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	var main_position := Vector2(GameConfig.PYTHON_BOSS_CONFIG["home_position"])
	if player_position.distance_to(main_position) <= 1600.0:
		visible.append({
			"id": MAIN_PYTHON_BOSS_LAIR_ID,
			"kind": "python_boss_lair",
			"is_main": true,
			"boss_id": str(GameConfig.PYTHON_BOSS_CONFIG["id"]),
			"boss_name": str(GameConfig.PYTHON_BOSS_CONFIG["name"]),
			"level": _python_boss_world_tier_for_lair(MAIN_PYTHON_BOSS_LAIR_ID) + 1,
			"discovered": true,
			"cleared": main_python_boss_lair_cleared,
			"active": active_python_boss_lair_id == MAIN_PYTHON_BOSS_LAIR_ID,
			"boss_present": active_python_boss_lair_id == MAIN_PYTHON_BOSS_LAIR_ID and not main_python_boss_lair_cleared and python_boss != null and not python_boss.is_defeated(),
			"x": snappedf(main_position.x, 0.1),
			"y": snappedf(main_position.y, 0.1),
		})
	for nest in snake_nests.values():
		var position := Vector2(nest["pos"])
		if player_position.distance_to(position) > 1600.0:
			continue
		visible.append({
			"id": str(nest["id"]),
			"kind": "python_boss_lair",
			"is_main": false,
			"boss_id": str(GameConfig.PYTHON_BOSS_CONFIG["id"]),
			"boss_name": str(GameConfig.PYTHON_BOSS_CONFIG["name"]),
			"level": int(nest["level"]),
			"discovered": bool(nest.get("discovered", true)),
			"cleared": bool(nest.get("cleared", false)),
			"active": str(nest["id"]) == active_python_boss_lair_id,
			"boss_present": str(nest["id"]) == active_python_boss_lair_id and not bool(nest.get("cleared", false)) and python_boss != null and not python_boss.is_defeated(),
			"x": snappedf(position.x, 0.1),
			"y": snappedf(position.y, 0.1),
		})
	return visible


func _world_to_screen(world_position: Vector2) -> Vector2:
	return world_position - camera_pos + screen_size * 0.5 + camera_shake_offset


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return screen_position + camera_pos - screen_size * 0.5 - camera_shake_offset


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _set_soldier_command(command: String) -> void:
	if command not in ["跟隨", "防守", "攻擊", "撤退", "駐守", "攻城"]:
		return
	var previous_command := soldier_command
	var previous_castle_id := command_castle_id
	command_target_id = -1
	command_castle_id = ""
	var target_label := ""
	match command:
		"攻擊":
			command_point = _touch_attack_target() if _is_touch_scheme() else _screen_to_world(get_viewport().get_mouse_position())
			command_target_id = _enemy_near_point(command_point, 90.0)
		"駐守":
			var owned_castle: Variant = _nearest_owned_castle(Vector2(player["pos"]), INF)
			if owned_castle == null:
				soldier_command = previous_command
				command_castle_id = previous_castle_id
				_add_notification("目前沒有可駐守的友方城堡。", Color("F6C177"), 2.0)
				return
			command_castle_id = str(owned_castle["id"])
			command_point = Vector2(owned_castle["pos"])
			target_label = " Lv.%d" % int(owned_castle["level"])
		"攻城":
			var siege_reference := Vector2(player["pos"]) if _is_touch_scheme() else _screen_to_world(get_viewport().get_mouse_position())
			var hostile_castle: Variant = _nearest_hostile_castle(siege_reference, INF)
			if hostile_castle == null:
				soldier_command = previous_command
				command_castle_id = previous_castle_id
				_add_notification("目前沒有可攻擊的敵方城堡。", Color("F6C177"), 2.0)
				return
			command_castle_id = str(hostile_castle["id"])
			command_point = Vector2(hostile_castle["pos"])
			target_label = " Lv.%d" % int(hostile_castle["level"])
		_:
			command_point = Vector2(player["pos"])
	soldier_command = command
	active_panel = ""
	_add_notification("部隊命令：%s%s" % [command, target_label], FRIEND_BLUE, 1.8)
	audio.play("ui", 0.45)


func _is_near_recruitment() -> bool:
	if Vector2(player["pos"]).distance_to(HOUSE_POS) <= 185.0:
		recruit_anchor = HOUSE_POS
		return true
	for castle in castles.values():
		if castle["owned"] and Vector2(player["pos"]).distance_to(castle["pos"]) <= 210.0:
			recruit_anchor = castle["pos"]
			return true
	return false


# -----------------------------------------------------------------------------
# 玩家戰鬥、成長與傷害
# -----------------------------------------------------------------------------

func _try_player_attack(target_world: Vector2) -> void:
	if float(player["attack_cd"]) > 0.0 or not player["alive"]:
		return
	var direction := (target_world - Vector2(player["pos"])).normalized()
	if direction == Vector2.ZERO:
		direction = player["facing"]
	player["facing"] = direction
	var class_id := str(player["class_id"])
	var normal: Dictionary = GameConfig.NORMAL_ATTACKS[class_id]
	var rate_bonus := 1.0 + 0.06 * int(player["upgrades"]["attack_speed"])
	player["attack_cd"] = max(0.16, 1.0 / (float(normal["attack_speed"]) * rate_bonus))
	match class_id:
		"archer":
			_spawn_projectile({
				"team": "friendly", "kind": "arrow", "pos": player["pos"] + direction * 20.0,
				"vel": direction * float(normal["projectile_speed"]), "damage": _player_damage(1.0),
				"range": 760.0, "radius": 5.0, "pierce": 1, "aoe": 0.0, "color": Color("BFEAFF"),
				"armor_penetration": float(normal["effects"]["armor_penetration"]),
			})
			audio.play("shoot_arrow", 0.7, randf_range(0.97, 1.03))
		"mage":
			_spawn_projectile({
				"team": "friendly", "kind": "magic", "pos": player["pos"] + direction * 21.0,
				"vel": direction * 580.0, "damage": _player_damage(0.88),
				"range": 650.0, "radius": 9.0, "pierce": 1, "aoe": float(normal["effects"]["blast_radius"]), "color": MAGIC_PURPLE,
			})
			audio.play("magic", 0.72, randf_range(0.97, 1.03))
		"warrior":
			_player_melee_attack(112.0, deg_to_rad(112.0), _player_damage(1.08), false, float(normal["effects"]["knockback"]))
			_spawn_effect("slash", player["pos"] + direction * 38.0, Color("EAF6FF"), 1.0)
			audio.play("sword", 0.72, randf_range(0.97, 1.03))


func _try_player_special(target_world: Vector2) -> void:
	if int(player["level"]) < 10:
		_add_notification("特殊技能會在等級 10 解鎖。", Color("F6C177"), 2.3)
		return
	if float(player["special_cd"]) > 0.0:
		_add_notification("技能冷卻 %.1f 秒" % float(player["special_cd"]), Color("F6C177"), 1.4)
		return
	var direction := (target_world - Vector2(player["pos"])).normalized()
	if direction == Vector2.ZERO:
		direction = player["facing"]
	player["facing"] = direction
	var class_id := str(player["class_id"])
	var special: Dictionary = GameConfig.SPECIAL_ATTACKS[class_id]
	player["special_cd"] = float(special["cooldown"])
	match class_id:
		"archer":
			var count := int(special["projectile_count"])
			var spread := deg_to_rad(float(special["cone_angle"]))
			for i in count:
				var t := 0.5 if count <= 1 else float(i) / float(count - 1)
				var arrow_dir := direction.rotated(lerp(-spread * 0.5, spread * 0.5, t))
				_spawn_projectile({
					"team": "friendly", "kind": "scatter_arrow", "pos": player["pos"] + arrow_dir * 20.0,
					"vel": arrow_dir * 940.0, "damage": _player_damage(0.55), "range": 790.0,
					"radius": 5.0, "pierce": 1, "aoe": 0.0, "color": Color("D9F4FF"),
					"slow_factor": float(special["effects"]["slow"]),
					"slow_duration": float(special["effects"]["slow_duration"]),
				})
			_spawn_effect("fan", player["pos"] + direction * 26.0, Color("BFEAFF"), 1.0)
			audio.play("shoot_arrow", 1.0, 0.88)
		"mage":
			_spawn_projectile({
				"team": "friendly", "kind": "fireball", "pos": player["pos"] + direction * 24.0,
				"vel": direction * 500.0, "damage": _player_damage(2.35), "range": 700.0,
				"radius": 15.0, "pierce": 1, "aoe": 155.0, "color": FIRE_ORANGE,
				"creates_fire": true, "fire_duration": float(special["effects"]["burn_duration"]),
				"fire_tick_damage": float(special["effects"]["burn"]),
			})
			audio.play("magic", 1.0, 0.72)
		"warrior":
			player["dash_timer"] = 0.34
			player["dash_dir"] = direction
			player["dash_hit"] = {}
			player["dash_attack_id"] = _allocate_attack_id("player_dash")
			player["invuln"] = max(float(player["invuln"]), 0.26)
			_spawn_effect("dash", player["pos"], FRIEND_BLUE, 1.0)
			audio.play("sword", 1.0, 0.78)
	_add_notification("%s！" % special["name"], GOLD, 1.4)


func _player_damage(multiplier: float = 1.0) -> float:
	var level_scale := 1.0 + 0.025 * float(int(player["level"]) - 1)
	var upgrade_scale := 1.0 + 0.05 * float(player["upgrades"]["attack"])
	return float(player["attack"]) * level_scale * upgrade_scale * multiplier


func _player_move_speed() -> float:
	var points := int(player["upgrades"]["speed"])
	var result: float = float(player["speed"]) * min(1.30, 1.0 + 0.025 * points)
	if python_boss != null:
		result *= float(python_boss.get_speed_multiplier("player", 0))
	return result


func _player_melee_attack(radius: float, arc: float, damage: float, siege: bool, knockback: float = 0.0) -> void:
	var facing: Vector2 = player["facing"]
	var attack_id: String = _allocate_attack_id("player_melee")
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if _enemy_is_air(enemy):
			continue
		var offset: Vector2 = Vector2(enemy["pos"]) - Vector2(player["pos"])
		if offset.length() <= radius + float(enemy["radius"]) and abs(facing.angle_to(offset.normalized())) <= arc * 0.5:
			if knockback > 0.0:
				enemy["pos"] = _move_with_collision(enemy["pos"], offset.normalized() * knockback, float(enemy["radius"]))
			_damage_enemy(i, damage, Vector2(player["pos"]), "melee")
	for castle in castles.values():
		if not castle["owned"] and Vector2(castle["pos"]).distance_to(player["pos"]) <= radius + _castle_damage_radius(castle):
			_damage_castle(castle, damage * (1.35 if siege else 0.7))
	for camp in camps.values():
		if float(camp["crate_hp"]) > 0.0 and Vector2(camp["pos"]).distance_to(player["pos"]) <= radius + 47.0:
			_damage_camp_crate(camp, damage)
	_damage_active_boss_melee(attack_id, Vector2(player["pos"]), facing, radius, arc, damage, "player", 0)


func _damage_enemies_along_dash(position: Vector2) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if _enemy_is_air(enemy):
			continue
		var id := int(enemy["id"])
		if player["dash_hit"].has(id):
			continue
		if Vector2(enemy["pos"]).distance_to(position) <= 43.0 + float(enemy["radius"]):
			player["dash_hit"][id] = true
			var effects: Dictionary = GameConfig.SPECIAL_ATTACKS["warrior"]["effects"]
			enemy["armor_break"] = max(float(enemy.get("armor_break", 0.0)), float(effects["duration"]))
			enemy["armor_reduction"] = max(float(enemy.get("armor_reduction", 0.0)), float(effects["armor_reduce"]))
			_damage_enemy(i, _player_damage(0.95), position, "dash")
	for camp in camps.values():
		var camp_key := "camp:%s" % str(camp["id"])
		if not player["dash_hit"].has(camp_key) and float(camp["crate_hp"]) > 0.0 and Vector2(camp["pos"]).distance_to(position) <= 62.0:
			player["dash_hit"][camp_key] = true
			_damage_camp_crate(camp, _player_damage(1.05))
	for castle in castles.values():
		var castle_key := "castle:%s" % str(castle["id"])
		if not player["dash_hit"].has(castle_key) and not castle["owned"] and not castle["destroyed"] and Vector2(castle["pos"]).distance_to(position) <= _castle_damage_radius(castle) + 25.0:
			player["dash_hit"][castle_key] = true
			_damage_castle(castle, _player_damage(1.25))
	if _active_boss_can_be_targeted() and not player["dash_hit"].has(BOSS_ENTITY_ID):
		var intersection: Dictionary = _active_boss_projectile_intersection(position, position, 43.0)
		if bool(intersection.get("hit", false)):
			player["dash_hit"][BOSS_ENTITY_ID] = true
			var attack_id: Variant = player.get("dash_attack_id", "")
			if str(attack_id) == "":
				attack_id = _allocate_attack_id("player_dash")
				player["dash_attack_id"] = attack_id
			var result: Dictionary = _receive_active_boss_hit(attack_id, "player", 0, _player_damage(0.95), Vector2(intersection["position"]), "dash", 0.0)
			_consume_active_boss_hit_result(result)


func _calculate_damage(raw_damage: float, defense: float) -> float:
	var reduction: float = min(0.70, max(0.0, defense) / (max(0.0, defense) + 50.0))
	return max(1.0, round(raw_damage * (1.0 - reduction)))


func _damage_player(raw_damage: float, source_pos: Vector2, allow_knockback: bool = true, bypass_hit_grace: bool = false) -> bool:
	if mode != GameMode.PLAYING or not player["alive"]:
		return false
	# Dash, respawn and load protection are true invulnerability and can never be
	# bypassed. The short post-hit grace is tracked separately so distinct Boss
	# attacks may settle in the same frame without piercing a Warrior dash tail.
	if float(player.get("invuln", 0.0)) > 0.0:
		return false
	if float(player.get("hit_grace", 0.0)) > 0.0 and not bypass_hit_grace:
		return false
	if _is_in_friendly_safe_zone(Vector2(player["pos"])):
		return false
	var damage := _calculate_damage(raw_damage, _player_defense())
	var shield_absorb := minf(damage, maxf(0.0, float(player.get("support_shield", 0.0))))
	if shield_absorb > 0.0:
		player["support_shield"] = float(player.get("support_shield", 0.0)) - shield_absorb
		damage -= shield_absorb
		_add_floater(player["pos"] + Vector2(0, -25), "盾 %d" % int(shield_absorb), Color("80D9FF"), 0.75)
		_spawn_effect("shield", player["pos"], Color("80D9FF"), 0.55)
	if damage <= 0.0:
		player["hit_grace"] = PLAYER_HIT_GRACE_SECONDS
		return true
	player["hp"] = max(0.0, float(player["hp"]) - damage)
	player["hit_grace"] = PLAYER_HIT_GRACE_SECONDS
	player["flash"] = 0.16
	if allow_knockback:
		var knock := (Vector2(player["pos"]) - source_pos).normalized() * 14.0
		player["pos"] = _move_with_collision(player["pos"], knock, PLAYER_RADIUS, true)
		player["vel"] = Vector2.ZERO
	_add_floater(player["pos"] + Vector2(0, -25), "-%d" % int(damage), Color("FF857A"), 1.0)
	_spawn_effect("hit", player["pos"], Color("FF857A"), 0.8)
	camera_shake = max(camera_shake, 0.36)
	audio.play("hurt", 0.85, randf_range(0.96, 1.04))
	if float(player["hp"]) <= 0.0:
		_kill_player()
	return true


func _player_defense() -> float:
	return float(player["defense"]) + 2.0 * float(player["upgrades"]["defense"]) + 0.4 * float(int(player["level"]) - 1)


func _kill_player() -> void:
	if not player["alive"]:
		return
	player["alive"] = false
	player["hit_grace"] = 0.0
	mode = GameMode.DEAD
	death_timer = 3.0
	var loss := int(floor(float(player["money"]) * 0.10))
	player["money"] = max(0, int(player["money"]) - loss)
	attack_held = false
	active_panel = ""
	_add_notification("戰敗：損失 %d 金幣" % loss, Color("FF857A"), 3.0)
	_spawn_effect("death", player["pos"], Color("FF857A"), 1.2)


func _respawn_player() -> void:
	var spawn_pos := HOUSE_POS + Vector2(0, 95)
	var nearest := Vector2(player["pos"]).distance_to(HOUSE_POS)
	for castle in castles.values():
		if castle["owned"]:
			var d := Vector2(player["pos"]).distance_to(castle["pos"])
			if d < nearest:
				nearest = d
				spawn_pos = Vector2(castle["pos"]) + Vector2(0, 185)
	player["pos"] = spawn_pos
	player["vel"] = Vector2.ZERO
	player["hp"] = player["max_hp"]
	player["alive"] = true
	player["invuln"] = 5.0
	player["hit_grace"] = 0.0
	mode = GameMode.PLAYING
	for enemy in enemies:
		if Vector2(enemy["pos"]).distance_to(spawn_pos) < 520.0:
			enemy["target_kind"] = ""
			enemy["state"] = "return"
			enemy["move_intent"] = Vector2.ZERO
			enemy["move_dir"] = Vector2.ZERO
			enemy["vel"] = Vector2.ZERO
	_spawn_effect("level_up", spawn_pos, HEAL_GREEN, 1.0)
	_add_notification("已在最近的友方據點復活，獲得 5 秒保護。", HEAL_GREEN, 3.0)


func _gain_xp(amount: int) -> void:
	player["xp"] = int(player["xp"]) + amount
	var leveled := false
	while int(player["xp"]) >= int(player["xp_need"]):
		player["xp"] = int(player["xp"]) - int(player["xp_need"])
		player["level"] = int(player["level"]) + 1
		player["xp_need"] = GameConfig.xp_needed(int(player["level"]))
		player["skill_points"] = int(player["skill_points"]) + 1
		var growth: Dictionary = GameConfig.HERO_CLASSES[str(player["class_id"])]["attack_growth"]
		var hp_growth := float(growth["hp"])
		player["max_hp"] = float(player["max_hp"]) + hp_growth
		player["attack"] = float(player["attack"]) + float(growth["attack"])
		player["defense"] = float(player["defense"]) + float(growth["defense"])
		player["speed"] = float(player["speed"]) + float(growth["speed"]) * 1.65
		player["hp"] = min(float(player["max_hp"]), float(player["hp"]) + hp_growth + float(player["max_hp"]) * 0.35)
		leveled = true
	if leveled:
		_spawn_effect("level_up", player["pos"], GOLD, 1.0)
		audio.play("level_up", 0.85)
		_add_notification("升級！目前等級 %d，獲得技能點。" % int(player["level"]), GOLD, 3.0)
		if int(player["level"]) >= 10 and int(player["level"]) - 1 < 10:
			_add_notification("特殊技能已解鎖！按滑鼠右鍵施放。", Color("FFF4B0"), 5.0)


func _upgrade_stat(stat_id: String) -> void:
	if int(player["skill_points"]) <= 0 or not player["upgrades"].has(stat_id):
		audio.play("warning", 0.35)
		return
	var cap := 20
	if stat_id == "speed": cap = 12
	if stat_id == "attack_speed": cap = 15
	if int(player["upgrades"][stat_id]) >= cap:
		_add_notification("此能力已達上限。", Color("F6C177"), 1.5)
		return
	player["upgrades"][stat_id] = int(player["upgrades"][stat_id]) + 1
	player["skill_points"] = int(player["skill_points"]) - 1
	if stat_id == "max_hp":
		var gain := float(player["max_hp"]) * 0.08
		player["max_hp"] = float(player["max_hp"]) + gain
		player["hp"] = float(player["hp"]) + gain
	audio.play("ui", 0.65, 1.15)


# -----------------------------------------------------------------------------
# 敵人有限狀態機
# -----------------------------------------------------------------------------

func _spawn_enemy(type_id: String, position: Vector2, level: int, home: Vector2, guard_castle: String = "", camp_id: String = "") -> int:
	if enemies.size() >= MAX_ENEMIES:
		return -1
	if not GameConfig.ENEMIES.has(type_id):
		type_id = "grunt"
	var cfg: Dictionary = GameConfig.ENEMIES[type_id]
	var combat: Dictionary = cfg["combat"]
	var rank: int = max(1, level)
	var growth := 1.0 + 0.12 * log(1.0 + float(rank))
	var id := next_entity_id
	next_entity_id += 1
	var radius := _enemy_radius(type_id)
	var domain := str(combat.get("domain", "ground"))
	var altitude := 0.0
	if type_id == "helicopter": altitude = 44.0
	elif type_id == "bomber": altitude = 58.0
	elif type_id == "ufo": altitude = 64.0
	var attack_style := str(combat.get("attack_style", "ranged" if type_id in ["archer", "thrower", "shaman"] else "melee"))
	var enemy := {
		"id": id, "type": type_id, "pos": position, "home": home, "level": rank,
		"hp": float(combat["hp"]) * growth, "max_hp": float(combat["hp"]) * growth,
		"attack": float(combat["attack"]) * (1.0 + 0.075 * log(1.0 + rank)),
		"defense": float(combat["armor"]) + min(16.0, log(1.0 + rank) * 2.2),
		"speed": float(combat["movement_speed"]) * 1.12, "range": float(combat["range"]),
		"attack_rate": float(combat["attack_speed"]), "radius": radius,
		"domain": domain, "attack_style": attack_style,
		"aoe": float(combat.get("aoe_radius", 0.0)),
		"telegraph_duration": float(combat.get("telegraph", 0.0)),
		"aim_dir": Vector2.RIGHT, "vel": Vector2.ZERO, "move_intent": Vector2.ZERO, "move_dir": Vector2.ZERO, "altitude": altitude,
		"state": "patrol", "target_kind": "", "target_id": -1, "cooldown": randf_range(0.2, 1.0),
		"telegraph": 0.0, "recovery": 0.0, "ai_accum": randf_range(0.0, 0.12),
		"patrol_angle": randf_range(-PI, PI), "flash": 0.0, "slow": 0.0, "slow_factor": 0.0,
		"armor_break": 0.0, "armor_reduction": 0.0,
		"buff_timer": 0.0,
		"guard_castle": guard_castle, "camp_id": camp_id,
		"reward_gold": int(float(cfg["reward"]["gold"]) * growth),
		"reward_xp": int(float(cfg["reward"]["xp"]) * growth),
		"pending_pos": position, "last_hit": -99.0, "sound_cd": 0.0,
		"enhancement": {"version": 1, "castle_level": 0, "seed": 0, "points": 0, "tracks": {}, "special_count": 0},
		"enhancement_points": 0, "enhancement_cursor": 0, "enhancement_attack_sequence": 0,
		"enhancement_stun": 0.0, "enhancement_reactive_timer": 0.0,
	}
	if not guard_castle.is_empty():
		var source_castle_level := maxi(1, rank - 1)
		if castles.has(guard_castle):
			source_castle_level = maxi(1, int(Dictionary(castles[guard_castle]).get("level", source_castle_level)))
		var enhancement_seed := _enemy_enhancement_seed(guard_castle, id, type_id)
		var rolled_enhancement := EnemyEnhancementCatalog.roll_for_enemy(source_castle_level, enhancement_seed, type_id)
		EnemyEnhancementCatalog.apply_stat_enhancements(enemy, rolled_enhancement)
	enemies.append(enemy)
	return id


func _enemy_enhancement_seed(castle_id: String, enemy_id: int, type_id: String) -> int:
	var mixed := int(world_seed) ^ int(castle_id.hash()) ^ int(type_id.hash() * 31) ^ int(enemy_id * 104729)
	return maxi(1, mixed & 0x7FFFFFFF)


func _enemy_radius(type_id: String) -> float:
	match type_id:
		"heavy": return 16.0
		"chief": return 22.0
		"cannon", "rocket", "gatling": return 19.0
		"tank": return 29.0
		"helicopter": return 25.0
		"bomber": return 32.0
		"ufo": return 31.0
		_: return 11.0


func _update_enemies(delta: float) -> void:
	_update_soldier_enemy_statuses(delta)
	for enemy in enemies:
		enemy["cooldown"] = max(0.0, float(enemy["cooldown"]) - delta)
		enemy["flash"] = max(0.0, float(enemy["flash"]) - delta)
		enemy["slow"] = max(0.0, float(enemy["slow"]) - delta)
		if float(enemy["slow"]) <= 0.0:
			enemy["slow_factor"] = 0.0
		enemy["armor_break"] = max(0.0, float(enemy.get("armor_break", 0.0)) - delta)
		if float(enemy["armor_break"]) <= 0.0:
			enemy["armor_reduction"] = 0.0
			enemy["soldier_corrosion_stacks"] = 0
		enemy["buff_timer"] = max(0.0, float(enemy.get("buff_timer", 0.0)) - delta)
		enemy["sound_cd"] = max(0.0, float(enemy.get("sound_cd", 0.0)) - delta)
		enemy["enhancement_stun"] = max(0.0, float(enemy.get("enhancement_stun", 0.0)) - delta)
		enemy["enhancement_reactive_timer"] = max(0.0, float(enemy.get("enhancement_reactive_timer", 0.0)) - delta)
		var enhancement_cooldowns: Dictionary = Dictionary(enemy.get("enhancement_cooldowns", {}))
		for cooldown_id in enhancement_cooldowns.keys():
			enhancement_cooldowns[cooldown_id] = maxf(0.0, float(enhancement_cooldowns[cooldown_id]) - delta)
		enemy["enhancement_cooldowns"] = enhancement_cooldowns
		var regeneration := float(enemy.get("enhancement_regen_pct", 0.0))
		if regeneration > 0.0 and game_time - float(enemy.get("last_hit", -99.0)) >= 3.0 and float(enemy["hp"]) > 0.0:
			enemy["hp"] = minf(float(enemy["max_hp"]), float(enemy["hp"]) + float(enemy["max_hp"]) * regeneration * delta)
		enemy["ai_accum"] = float(enemy["ai_accum"]) + delta
		var distance_to_player := Vector2(enemy["pos"]).distance_to(player["pos"])
		var tick_interval := 0.08 if distance_to_player < 850.0 else 0.32
		if float(enemy["ai_accum"]) >= tick_interval:
			var tick := float(enemy["ai_accum"])
			enemy["ai_accum"] = fmod(float(enemy["ai_accum"]), tick_interval)
			_update_single_enemy(enemy, tick)
		# Decisions remain throttled for performance, but the chosen steering vector
		# advances every rendered frame. This removes the visible 80/320 ms hop-pause
		# cadence that previously made walking enemies shake across the ground.
		_advance_enemy_motion(enemy, delta)


func _update_soldier_enemy_statuses(delta: float) -> void:
	for enemy_index in range(enemies.size() - 1, -1, -1):
		if enemy_index >= enemies.size():
			continue
		var enemy: Dictionary = enemies[enemy_index]
		for timer_key in ["soldier_void_mark_ttl", "soldier_focus_mark_ttl", "soldier_suppression_ttl"]:
			enemy[timer_key] = maxf(0.0, float(enemy.get(timer_key, 0.0)) - delta)
		if float(enemy.get("soldier_void_mark_ttl", 0.0)) <= 0.0:
			enemy["soldier_void_damage_bonus"] = 0.0
		if float(enemy.get("soldier_focus_mark_ttl", 0.0)) <= 0.0:
			enemy["soldier_focus_damage_bonus"] = 0.0
			enemy["soldier_focus_source_id"] = -1
		if float(enemy.get("soldier_suppression_ttl", 0.0)) <= 0.0:
			enemy["soldier_suppression_move_reduction"] = 0.0
			enemy["soldier_suppression_attack_reduction"] = 0.0
		var total_dps := 0.0
		var dot_source_id := int(enemy.get("soldier_burn_source_id", -1))
		enemy["soldier_burn_ttl"] = maxf(0.0, float(enemy.get("soldier_burn_ttl", 0.0)) - delta)
		if float(enemy["soldier_burn_ttl"]) > 0.0:
			total_dps += maxf(0.0, float(enemy.get("soldier_burn_dps", 0.0)))
		else:
			enemy["soldier_burn_dps"] = 0.0
		var poison_sources: Dictionary = Dictionary(enemy.get("soldier_poison_sources", {}))
		for poison_key in poison_sources.keys():
			var poison_entry: Dictionary = Dictionary(poison_sources[poison_key])
			poison_entry["ttl"] = maxf(0.0, float(poison_entry.get("ttl", 0.0)) - delta)
			if float(poison_entry["ttl"]) <= 0.0:
				poison_sources.erase(poison_key)
				continue
			poison_sources[poison_key] = poison_entry
			total_dps += float(poison_entry.get("dps_per_stack", 0.0)) * float(int(poison_entry.get("stacks", 1)))
			if dot_source_id < 0:
				dot_source_id = int(str(poison_key))
		enemy["soldier_poison_sources"] = poison_sources
		if total_dps <= 0.0:
			enemy["soldier_dot_tick"] = 0.0
			continue
		enemy["soldier_dot_tick"] = float(enemy.get("soldier_dot_tick", 0.0)) + delta
		if float(enemy["soldier_dot_tick"]) < 0.5:
			continue
		var ticks := mini(4, int(floor(float(enemy["soldier_dot_tick"]) / 0.5)))
		enemy["soldier_dot_tick"] = fmod(float(enemy["soldier_dot_tick"]), 0.5)
		_damage_enemy(enemy_index, total_dps * 0.5 * float(ticks), enemy["pos"], "status", 999.0, dot_source_id)


func _update_single_enemy(enemy: Dictionary, delta: float) -> void:
	enemy["move_intent"] = Vector2.ZERO
	if float(enemy.get("enhancement_stun", 0.0)) > 0.0:
		enemy["state"] = "enhancement_stunned"
		return
	if enemy["state"] == "telegraph":
		enemy["telegraph"] = float(enemy["telegraph"]) - delta
		if float(enemy["telegraph"]) <= 0.0:
			_execute_enemy_attack(enemy)
			enemy["state"] = "recover"
			enemy["recovery"] = 0.32 if enemy["type"] != "chief" else 0.62
		return
	if enemy["state"] == "recover":
		enemy["recovery"] = float(enemy["recovery"]) - delta
		if float(enemy["recovery"]) <= 0.0:
			enemy["state"] = "chase"
		return

	if enemy["type"] == "shaman" and float(enemy["cooldown"]) <= 0.0:
		var wounded: Variant = _lowest_enemy_in_range(enemy["pos"], 310.0, int(enemy["id"]))
		var buffed_count := 0
		for ally in enemies:
			if ally["id"] == enemy["id"] or Vector2(ally["pos"]).distance_to(enemy["pos"]) > 300.0:
				continue
			ally["buff_timer"] = max(4.0, float(ally.get("buff_timer", 0.0)))
			buffed_count += 1
		if wounded != null:
			var heal := 28.0 + 2.0 * float(enemy["level"])
			wounded["hp"] = min(float(wounded["max_hp"]), float(wounded["hp"]) + heal)
			_spawn_effect("heal", wounded["pos"], HEAL_GREEN, 0.8)
			_add_floater(wounded["pos"] + Vector2(0, -20), "+%d" % int(heal), HEAL_GREEN, 0.9)
		if buffed_count > 0:
			_spawn_effect("heal", enemy["pos"], Color("94D46C"), 1.0)
		if wounded != null or buffed_count > 0:
			enemy["cooldown"] = 4.8
			return

	var target: Dictionary = _choose_friendly_target(enemy)
	if target.is_empty():
		var home_offset: Vector2 = Vector2(enemy["home"]) - Vector2(enemy["pos"])
		if home_offset.length() > 48.0:
			enemy["state"] = "return"
			_set_enemy_move_intent(enemy, home_offset.normalized())
		else:
			enemy["state"] = "patrol"
			var patrol_dir := Vector2.from_angle(float(enemy["patrol_angle"]) + sin(game_time * 0.7 + int(enemy["id"])) * 0.5)
			_set_enemy_move_intent(enemy, patrol_dir * 0.22)
		return

	enemy["target_kind"] = target["kind"]
	enemy["target_id"] = target["id"]
	var target_pos: Vector2 = target["pos"]
	var target_velocity: Vector2 = Vector2(target.get("vel", Vector2.ZERO))
	var chase_pos := _predict_intercept_position(Vector2(enemy["pos"]), target_pos, target_velocity, 0.0, 0.18, 0.18, 72.0)
	var actual_to_target := target_pos - Vector2(enemy["pos"])
	var to_target := chase_pos - Vector2(enemy["pos"])
	var dist := actual_to_target.length()
	var ranged: bool = str(enemy.get("attack_style", "melee")) != "melee"
	var desired_range := float(enemy["range"]) * (0.78 if ranged else 0.88)
	if dist <= float(enemy["range"]) + float(target.get("radius", PLAYER_RADIUS)):
		if float(enemy["cooldown"]) <= 0.0:
			var tell := float(enemy.get("telegraph_duration", 0.0))
			if tell <= 0.0:
				tell = 0.32
				if enemy["type"] == "thrower": tell = 0.62
				if enemy["type"] == "heavy": tell = 0.68
				if enemy["type"] == "chief": tell = 0.78
			var projectile_speed := _enemy_projectile_speed(str(enemy["type"])) if ranged else 0.0
			var prediction_horizon := 0.92 if ranged else 0.24
			var prediction_limit := ENEMY_PREDICTION_MAX_LEAD if ranged else 68.0
			var predicted_pos := _predict_intercept_position(
				Vector2(enemy["pos"]), target_pos, target_velocity, projectile_speed,
				tell * (0.42 if ranged else 0.28), prediction_horizon, prediction_limit
			)
			enemy["state"] = "telegraph"
			enemy["pending_pos"] = predicted_pos
			var predicted_offset := predicted_pos - Vector2(enemy["pos"])
			enemy["aim_dir"] = predicted_offset.normalized() if predicted_offset.length_squared() > 0.01 else Vector2.RIGHT
			enemy["telegraph"] = tell
			var effective_attack_rate := float(enemy["attack_rate"])
			if enemy["type"] == "berserker" and float(enemy["hp"]) / float(enemy["max_hp"]) < 0.4:
				effective_attack_rate *= 1.4
			if float(enemy.get("buff_timer", 0.0)) > 0.0:
				effective_attack_rate *= 1.1
			if float(enemy.get("soldier_suppression_ttl", 0.0)) > 0.0:
				effective_attack_rate *= 1.0 - clampf(float(enemy.get("soldier_suppression_attack_reduction", 0.0)), 0.0, 0.75)
			var minimum_attack_gap := 0.10 if str(enemy.get("attack_style", "")) in ["rifle", "gatling"] else 0.42
			enemy["cooldown"] = max(minimum_attack_gap, 1.0 / effective_attack_rate) + tell
			if enemy["type"] in ["thrower", "chief"]:
				audio.play("warning", 0.22)
		elif ranged and dist < desired_range * 0.58:
			enemy["state"] = "keep_range"
			_set_enemy_move_intent(enemy, -to_target.normalized())
		return

	if Vector2(enemy["pos"]).distance_to(enemy["home"]) > (1050.0 if enemy["guard_castle"] != "" else 780.0):
		enemy["target_kind"] = ""
		enemy["state"] = "return"
		_set_enemy_move_intent(enemy, (Vector2(enemy["home"]) - Vector2(enemy["pos"])).normalized())
		return
	enemy["state"] = "chase"
	var move_dir := to_target.normalized()
	if ranged and dist < desired_range:
		move_dir = -move_dir
	_set_enemy_move_intent(enemy, move_dir)


func _choose_friendly_target(enemy: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := INF
	var aggro := 610.0
	if enemy["guard_castle"] != "": aggro = 820.0
	if player["alive"] and Vector2(player["pos"]).distance_to(HOUSE_POS) > HOUSE_SAFE_RADIUS:
		var pd := Vector2(enemy["pos"]).distance_to(player["pos"])
		if pd <= aggro:
			best = {"kind": "player", "id": 0, "pos": player["pos"], "vel": player.get("vel", Vector2.ZERO), "radius": PLAYER_RADIUS}
			best_score = pd - 35.0
	for soldier in soldiers:
		if float(soldier["hp"]) <= 0.0:
			continue
		if Vector2(soldier["pos"]).distance_to(HOUSE_POS) <= HOUSE_SAFE_RADIUS:
			continue
		var d := Vector2(enemy["pos"]).distance_to(soldier["pos"])
		if d > aggro:
			continue
		var score := d
		var taunt_guard := _soldier_special(soldier, "taunt_guard")
		if not taunt_guard.is_empty() and d <= float(taunt_guard.get("radius", 0.0)):
			score -= 220.0
		if soldier["type"] == "heavy" and d < 230.0:
			score -= 170.0
		elif soldier["type"] in ["healer", "priest", "cannon"]:
			score -= 45.0
		if score < best_score:
			best_score = score
			best = {"kind": "soldier", "id": soldier["id"], "pos": soldier["pos"], "vel": soldier.get("vel", Vector2.ZERO), "radius": soldier["radius"]}
	# Hostiles no longer wander beside an undefended friendly city. If no higher
	# priority hero or troop is closer, they deliberately advance on its perimeter.
	for castle in castles.values():
		if not bool(castle.get("owned", false)):
			continue
		var castle_distance := Vector2(enemy["pos"]).distance_to(castle["pos"])
		if castle_distance > aggro + 180.0:
			continue
		var castle_score := castle_distance - 18.0
		if castle_score < best_score:
			best_score = castle_score
			best = {
				"kind": "castle", "id": str(castle["id"]), "pos": castle["pos"],
				"vel": Vector2.ZERO, "radius": _castle_damage_radius(castle),
			}
	return best


func _set_enemy_move_intent(enemy: Dictionary, direction: Vector2) -> void:
	var separation := Vector2.ZERO
	for other in enemies:
		if other["id"] == enemy["id"]:
			continue
		if _enemy_is_air(other) != _enemy_is_air(enemy):
			continue
		var offset: Vector2 = Vector2(enemy["pos"]) - Vector2(other["pos"])
		var desired := float(enemy["radius"]) + float(other["radius"]) + 8.0
		if offset.length_squared() > 0.01 and offset.length() < desired:
			separation += offset.normalized() * (1.0 - offset.length() / desired)
	if not _enemy_is_air(enemy):
		for soldier in soldiers:
			var ally_offset := Vector2(enemy["pos"]) - Vector2(soldier["pos"])
			var ally_distance := ally_offset.length()
			var ally_desired := float(enemy["radius"]) + float(soldier["radius"]) + 2.0
			if ally_distance > 0.01 and ally_distance < ally_desired:
				separation += ally_offset.normalized() * (1.0 - ally_distance / ally_desired) * 0.8
		var player_offset := Vector2(enemy["pos"]) - Vector2(player["pos"])
		var player_distance := player_offset.length()
		var player_desired := float(enemy["radius"]) + PLAYER_RADIUS + 2.0
		if player_distance > 0.01 and player_distance < player_desired:
			separation += player_offset.normalized() * (1.0 - player_distance / player_desired) * 0.75
	enemy["move_intent"] = (direction + separation * 1.5).limit_length(1.0)


func _advance_enemy_motion(enemy: Dictionary, delta: float) -> void:
	var target_direction := Vector2(enemy.get("move_intent", Vector2.ZERO))
	if target_direction.length_squared() <= 0.0001:
		enemy["move_dir"] = Vector2.ZERO
		enemy["vel"] = Vector2.ZERO
		return
	var current_direction := Vector2(enemy.get("move_dir", Vector2.ZERO))
	var steering_blend := 1.0 - exp(-12.0 * delta)
	current_direction = current_direction.lerp(target_direction, steering_blend).limit_length(1.0)
	enemy["move_dir"] = current_direction
	_move_enemy(enemy, current_direction, delta)


func _move_enemy(enemy: Dictionary, direction: Vector2, delta: float) -> void:
	var speed := float(enemy["speed"])
	if enemy["type"] == "berserker" and float(enemy["hp"]) / float(enemy["max_hp"]) < 0.4:
		speed *= 1.25
	if float(enemy["slow"]) > 0.0:
		speed *= clamp(1.0 - float(enemy.get("slow_factor", 0.28)), 0.35, 1.0)
	if float(enemy.get("soldier_suppression_ttl", 0.0)) > 0.0:
		speed *= 1.0 - clampf(float(enemy.get("soldier_suppression_move_reduction", 0.0)), 0.0, 0.75)
	var motion := direction.limit_length(1.0) * speed * delta
	var old_position: Vector2 = Vector2(enemy["pos"])
	if _enemy_is_air(enemy):
		enemy["pos"] = Vector2(enemy["pos"]) + motion
	else:
		enemy["pos"] = _move_with_collision(enemy["pos"], motion, float(enemy["radius"]))
	enemy["vel"] = (Vector2(enemy["pos"]) - old_position) / maxf(delta, 0.0001)


func _predict_intercept_position(origin: Vector2, target_position: Vector2, target_velocity: Vector2, projectile_speed: float, reaction_seconds: float, max_horizon: float, max_lead: float) -> Vector2:
	var travel_seconds := 0.0
	if projectile_speed > 1.0:
		travel_seconds = origin.distance_to(target_position) / projectile_speed
	var horizon := clampf(reaction_seconds + travel_seconds, 0.0, max_horizon)
	var tracked_velocity := target_velocity.limit_length(PREDICTION_TARGET_SPEED_CAP)
	var lead := (tracked_velocity * horizon).limit_length(max_lead)
	return target_position + lead


func _enemy_projectile_speed(type_id: String) -> float:
	match type_id:
		"archer": return 610.0
		"thrower": return 390.0
		"shaman": return 460.0
		"cannon": return 410.0
		"musketeer": return 1080.0
		"rifleman": return 1380.0
		"tank": return 470.0
		"rocket": return 355.0
		"gatling", "helicopter": return 1520.0
		_: return 0.0


func _enemy_is_air(enemy: Dictionary) -> bool:
	return str(enemy.get("domain", "ground")) == "air"


func _execute_enemy_attack(enemy: Dictionary) -> void:
	var origin: Vector2 = enemy["pos"]
	var target_pos: Vector2 = enemy["pending_pos"]
	var direction := (target_pos - origin).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	enemy["aim_dir"] = direction
	enemy["enhancement_attack_sequence"] = int(enemy.get("enhancement_attack_sequence", 0)) + 1
	var base_attack := float(enemy["attack"])
	var crit_chance := float(enemy.get("enhancement_crit_chance", 0.0))
	var crit_roll := float((int(enemy["id"]) * 37 + int(enemy["enhancement_attack_sequence"]) * 101) % 1000) / 1000.0
	if crit_chance > 0.0 and crit_roll < crit_chance:
		enemy["attack"] = base_attack * float(enemy.get("enhancement_crit_multiplier", 1.5))
		_spawn_effect("warning", target_pos, Color("FF8E8E"), 0.8)
	match str(enemy["type"]):
		"archer":
			_spawn_projectile({"team": "enemy", "kind": "enemy_arrow", "pos": origin + direction * 16.0, "vel": direction * 610.0, "damage": enemy["attack"], "range": 520.0, "radius": 5.0, "pierce": 1, "aoe": 0.0, "color": Color("FF9B79")})
		"thrower":
			_spawn_projectile({"team": "enemy", "kind": "enemy_stone", "pos": origin + direction * 18.0, "vel": direction * 390.0, "damage": enemy["attack"], "range": 390.0, "radius": 10.0, "pierce": 1, "aoe": 76.0, "color": Color("B8A48A")})
		"shaman":
			_spawn_projectile({"team": "enemy", "kind": "enemy_magic", "pos": origin + direction * 15.0, "vel": direction * 460.0, "damage": enemy["attack"], "range": 420.0, "radius": 8.0, "pierce": 1, "aoe": 36.0, "color": Color("94D46C")})
		"cannon":
			_spawn_projectile({"team": "enemy", "kind": "enemy_cannonball", "pos": origin + direction * 27.0, "vel": direction * 410.0, "damage": enemy["attack"], "range": 720.0, "radius": 12.0, "pierce": 1, "aoe": maxf(110.0, float(enemy.get("aoe", 125.0))), "color": Color("363B40")})
			_spawn_effect("muzzle", origin + direction * 31.0, FIRE_ORANGE, 1.25)
			for smoke_index in 5:
				_spawn_particle(origin + direction * (24.0 + smoke_index * 3.0), direction * randf_range(24.0, 58.0) + Vector2(randf_range(-12.0, 12.0), randf_range(-18.0, 4.0)), Color("B8B1A3"), randf_range(0.35, 0.65), randf_range(3.0, 6.0), 1)
			audio.play("cannon", 0.8, randf_range(0.92, 0.98))
			camera_shake = max(camera_shake, 0.38)
		"musketeer":
			_spawn_projectile({"team": "enemy", "kind": "enemy_musket_ball", "pos": origin + direction * 23.0, "vel": direction * 1080.0, "damage": enemy["attack"], "range": 760.0, "radius": 4.0, "pierce": 1, "aoe": 0.0, "color": Color("FFE0A3"), "armor_penetration": 8.0})
			_spawn_effect("muzzle", origin + direction * 25.0, Color("FFF0B0"), 0.9)
			for smoke_index in 3:
				_spawn_particle(origin + direction * (21.0 + smoke_index * 3.0), direction * randf_range(18.0, 40.0) + Vector2(randf_range(-8.0, 8.0), randf_range(-15.0, 1.0)), Color("C9C4B6"), randf_range(0.28, 0.48), randf_range(2.0, 4.0), 1)
			audio.play("musket", 0.54, randf_range(0.96, 1.03))
		"rifleman":
			_spawn_projectile({"team": "enemy", "kind": "enemy_rifle_round", "pos": origin + direction * 22.0, "vel": direction * 1380.0, "damage": enemy["attack"], "range": 670.0, "radius": 3.2, "pierce": 1, "aoe": 0.0, "color": Color("FFE36E"), "armor_penetration": 4.0})
			_spawn_effect("muzzle", origin + direction * 24.0, Color("FFD35A"), 0.55)
			if float(enemy.get("sound_cd", 0.0)) <= 0.0:
				audio.play("rifle", 0.28, randf_range(0.96, 1.05))
				enemy["sound_cd"] = 0.16
		"tank":
			_spawn_projectile({"team": "enemy", "kind": "enemy_tank_shell", "pos": origin + direction * 34.0, "vel": direction * 470.0, "damage": enemy["attack"], "range": 780.0, "radius": 11.0, "pierce": 1, "aoe": maxf(130.0, float(enemy.get("aoe", 142.0))), "color": Color("4A493D"), "armor_penetration": 12.0})
			_spawn_effect("muzzle", origin + direction * 38.0, Color("FFD166"), 1.2)
			for tank_smoke_index in 5:
				_spawn_particle(origin + direction * (33.0 + tank_smoke_index * 3.0), direction * randf_range(28.0, 72.0) + Vector2(randf_range(-13.0, 13.0), randf_range(-20.0, 5.0)), Color("AAA99C"), randf_range(0.4, 0.75), randf_range(3.0, 6.0), 1)
			audio.play("cannon", 0.72, randf_range(0.82, 0.88))
			camera_shake = max(camera_shake, 0.46)
		"rocket":
			_spawn_projectile({"team": "enemy", "kind": "enemy_rocket", "pos": origin + direction * 31.0, "vel": direction * 355.0, "damage": enemy["attack"], "range": 860.0, "radius": 10.0, "pierce": 1, "aoe": maxf(175.0, float(enemy.get("aoe", 190.0))), "color": Color("E45F32"), "armor_penetration": 6.0})
			_spawn_effect("muzzle", origin + direction * 30.0, FIRE_ORANGE, 1.1)
			audio.play("rocket", 0.62, randf_range(0.94, 1.02))
		"gatling", "helicopter":
			_spawn_projectile({"team": "enemy", "kind": "enemy_gatling_round", "pos": origin + direction * 29.0, "vel": direction * 1520.0, "damage": enemy["attack"], "range": 720.0, "radius": 2.8, "pierce": 1, "aoe": 0.0, "color": Color("FFD45A"), "armor_penetration": 2.0})
			_spawn_effect("muzzle", origin + direction * 31.0, Color("FFD45A"), 0.48)
			if float(enemy.get("sound_cd", 0.0)) <= 0.0:
				audio.play("machine_gun", 0.24, randf_range(0.95, 1.06))
				enemy["sound_cd"] = 0.11
		"bomber":
			var bombing_side := Vector2(-direction.y, direction.x)
			for bomb_index in 3:
				var bomb_target := target_pos + direction * (float(bomb_index) - 1.0) * 72.0 + bombing_side * (float(bomb_index % 2) * 34.0 - 17.0)
				_spawn_projectile({"team": "enemy", "kind": "bomb", "pos": bomb_target, "vel": Vector2.ZERO, "damage": float(enemy["attack"]) * (0.82 + float(bomb_index) * 0.09), "range": 1.0, "radius": 12.0, "pierce": 1, "aoe": maxf(165.0, float(enemy.get("aoe", 178.0))), "color": Color("3B4147"), "ttl": 0.55 + float(bomb_index) * 0.24, "delayed_impact": true, "drop_height": 92.0})
				_spawn_effect("warning", bomb_target, Color("FF6B42"), 1.0)
				audio.play("warning", 0.42, 0.78)
		"ufo":
			hazards.append({
				"id": _allocate_attack_id("ufo_beam"), "kind": "ufo_beam", "pos": target_pos,
				"radius": maxf(68.0, float(enemy.get("aoe", 78.0))), "ttl": 2.65, "max_ttl": 2.65,
				"warmup": 0.68, "initial_warmup": 0.68, "tick": 0.0,
				"damage": float(enemy["attack"]), "source_kind": "ufo", "source_id": int(enemy["id"]),
			})
			_spawn_effect("warning", target_pos, Color("6FFFE9"), 1.3)
			audio.play("beam", 0.58, 1.12)
		"chief":
			_enemy_area_attack(origin, 158.0, float(enemy["attack"]) * 1.2)
			_spawn_effect("explosion", origin, Color("F28C28"), 1.0)
			camera_shake = max(camera_shake, 0.55)
		_:
			_enemy_melee_attack(enemy, direction)
	_apply_enemy_special_enhancements(enemy, target_pos, float(enemy["attack"]))
	var lifesteal := float(enemy.get("enhancement_lifesteal", 0.0))
	if lifesteal > 0.0:
		enemy["hp"] = minf(float(enemy["max_hp"]), float(enemy["hp"]) + float(enemy["attack"]) * lifesteal)
	enemy["attack"] = base_attack


func _apply_enemy_special_enhancements(enemy: Dictionary, target_pos: Vector2, attack_damage: float) -> void:
	var enhancement: Dictionary = Dictionary(enemy.get("enhancement", {}))
	var tracks: Dictionary = Dictionary(enhancement.get("tracks", {}))
	if tracks.is_empty():
		return
	var sequence := int(enemy.get("enhancement_attack_sequence", 0))
	var origin := Vector2(enemy["pos"])
	var direction := (target_pos - origin).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var flame_rank := EnemyEnhancementCatalog.rank_for(enhancement, "flame")
	if flame_rank > 0:
		var flame := EnemyEnhancementCatalog.definition("flame")
		var ratio := float(flame["burn_ratio"][flame_rank - 1])
		_enemy_area_attack(target_pos, 42.0, attack_damage * ratio)
		_spawn_effect("burn", target_pos, FIRE_ORANGE, 0.8)
	var paralysis_rank := EnemyEnhancementCatalog.rank_for(enhancement, "paralysis")
	if paralysis_rank > 0:
		var paralysis := EnemyEnhancementCatalog.definition("paralysis")
		if sequence % int(paralysis["every"][paralysis_rank - 1]) == 0:
			var stun := float(paralysis["stun"][paralysis_rank - 1])
			for soldier in soldiers:
				if Vector2(soldier["pos"]).distance_to(target_pos) <= 54.0:
					soldier["invuln"] = minf(float(soldier.get("invuln", 0.0)), -stun)
			_spawn_effect("warning", target_pos, Color("E9DD68"), 0.9)
	var split_rank := EnemyEnhancementCatalog.rank_for(enhancement, "split_shot")
	if split_rank > 0:
		var split := EnemyEnhancementCatalog.definition("split_shot")
		var extra := int(split["extra"][split_rank - 1])
		var angle := deg_to_rad(float(split["angle"][split_rank - 1]))
		for shot_index in extra:
			var side := -1.0 if shot_index % 2 == 0 else 1.0
			var shot_dir := direction.rotated(angle * side * float(1 + shot_index / 2))
			_spawn_projectile({"team": "enemy", "kind": "enhanced_split", "pos": origin + shot_dir * 18.0, "vel": shot_dir * 680.0, "damage": attack_damage * float(split["damage_ratio"][split_rank - 1]), "range": 520.0, "radius": 4.0, "pierce": 1, "aoe": 0.0, "color": Color("F8B4FF")})
	var stomp_rank := EnemyEnhancementCatalog.rank_for(enhancement, "stomp")
	if stomp_rank > 0 and sequence % 4 == 0:
		var stomp := EnemyEnhancementCatalog.definition("stomp")
		_enemy_area_attack(origin, float(stomp["radius"][stomp_rank - 1]), attack_damage * float(stomp["damage_ratio"][stomp_rank - 1]))
		_spawn_effect("explosion", origin, Color("D99B68"), 1.0)
	var meteor_rank := EnemyEnhancementCatalog.rank_for(enhancement, "meteor")
	if meteor_rank > 0:
		var cooldowns: Dictionary = Dictionary(enemy.get("enhancement_cooldowns", {}))
		if float(cooldowns.get("meteor", 0.0)) <= 0.0:
			var meteor := EnemyEnhancementCatalog.definition("meteor")
			var warning := float(meteor["warning"][meteor_rank - 1])
			_spawn_projectile({"team": "enemy", "kind": "bomb", "pos": target_pos, "vel": Vector2.ZERO, "damage": attack_damage * float(meteor["damage_ratio"][meteor_rank - 1]), "range": 1.0, "radius": 14.0, "pierce": 1, "aoe": float(meteor["radius"][meteor_rank - 1]), "color": Color("FF4E62"), "ttl": warning, "delayed_impact": true, "drop_height": 150.0})
			cooldowns["meteor"] = float(meteor["cooldown"][meteor_rank - 1])
			enemy["enhancement_cooldowns"] = cooldowns
			_spawn_effect("warning", target_pos, Color("FF4E62"), 1.5)


func _enemy_melee_attack(enemy: Dictionary, direction: Vector2) -> void:
	var radius := float(enemy["range"]) + 30.0
	if player["alive"]:
		var to_player := Vector2(player["pos"]) - Vector2(enemy["pos"])
		if to_player.length() <= radius + PLAYER_RADIUS and abs(direction.angle_to(to_player.normalized())) < 1.15:
			_damage_player(float(enemy["attack"]), enemy["pos"])
	for soldier_index in range(soldiers.size() - 1, -1, -1):
		var soldier: Dictionary = soldiers[soldier_index]
		var to_soldier := Vector2(soldier["pos"]) - Vector2(enemy["pos"])
		if to_soldier.length() <= radius + float(soldier["radius"]) and abs(direction.angle_to(to_soldier.normalized())) < 1.15:
			_damage_soldier(soldier, float(enemy["attack"]), enemy["pos"], "melee")
	_damage_guardians_in_melee(Vector2(enemy["pos"]), direction, radius, float(enemy["attack"]))
	for castle in castles.values():
		if not bool(castle.get("owned", false)):
			continue
		var to_castle := Vector2(castle["pos"]) - Vector2(enemy["pos"])
		if to_castle.length() <= radius + _castle_damage_radius(castle) and (to_castle.length_squared() <= 0.01 or abs(direction.angle_to(to_castle.normalized())) < 1.15):
			_damage_owned_castle(castle, float(enemy["attack"]))
	_spawn_effect("slash", Vector2(enemy["pos"]) + direction * 28.0, Color("FF9B79"), 0.75)


func _enemy_area_attack(position: Vector2, radius: float, damage: float) -> void:
	if player["alive"] and Vector2(player["pos"]).distance_to(position) <= radius + PLAYER_RADIUS:
		_damage_player(damage, position)
	for soldier_index in range(soldiers.size() - 1, -1, -1):
		var soldier: Dictionary = soldiers[soldier_index]
		if Vector2(soldier["pos"]).distance_to(position) <= radius + float(soldier["radius"]):
			_damage_soldier(soldier, damage, position, "area")
	_damage_guardians_in_area(position, radius, damage)
	for castle in castles.values():
		if bool(castle.get("owned", false)) and Vector2(castle["pos"]).distance_to(position) <= radius + _castle_damage_radius(castle):
			_damage_owned_castle(castle, damage)


func _lowest_enemy_in_range(position: Vector2, radius: float, exclude_id: int) -> Variant:
	var best: Variant = null
	var ratio := 0.92
	for enemy in enemies:
		if enemy["id"] == exclude_id or Vector2(enemy["pos"]).distance_to(position) > radius:
			continue
		var hp_ratio := float(enemy["hp"]) / float(enemy["max_hp"])
		if hp_ratio < ratio:
			ratio = hp_ratio
			best = enemy
	return best


# -----------------------------------------------------------------------------
# 友軍招募、隊形與角色型 AI
# -----------------------------------------------------------------------------

func _owned_castle_level_total() -> int:
	var total := 0
	for castle in castles.values():
		if bool(castle.get("owned", false)):
			total += maxi(0, int(castle.get("level", 0)))
	return total


func _army_limit() -> int:
	return GameConfig.army_limit(_owned_castle_level_total())


func _purchase_soldier_upgrade(type_id: String, upgrade_id: String) -> bool:
	var soldier_unlocked := _soldier_type_is_unlocked(type_id)
	var preview := SoldierUpgradeCatalog.purchase_preview(type_id, upgrade_id, soldier_research, int(player.get("money", 0)), soldier_unlocked)
	if not bool(preview.get("allowed", false)):
		var reason := str(preview.get("reason", ""))
		var message := "無法購買此士兵強化。"
		if language == "en":
			message = "This troop upgrade cannot be purchased."
		match reason:
			"soldier_locked": message = "Defeat Kaeron to unlock this troop." if language == "en" else "擊敗卡厄隆後才可研究此兵種。"
			"insufficient_gold": message = "Not enough gold for this upgrade." if language == "en" else "金錢不足，無法購買此強化。"
			"max_rank": message = "This upgrade is already at maximum rank." if language == "en" else "此強化已達最高階。"
			"base_prerequisite":
				var prerequisite: Dictionary = preview.get("prerequisite", {})
				var base_id := str(prerequisite.get("base_upgrade", ""))
				var required_rank := int(prerequisite.get("base_rank", 0))
				message = ("Requires %s Rank %d." % [SoldierUpgradeCatalog.localized_name(base_id, language), required_rank]) if language == "en" else ("需要「%s」Rank %d。" % [SoldierUpgradeCatalog.localized_name(base_id, language), required_rank])
		_add_notification(message, Color("F6C177"), 2.4)
		audio.play("warning", 0.35)
		return false
	soldier_research = Dictionary(preview["research_after"]).duplicate(true)
	player["money"] = int(preview["gold_after"])
	var purchased_name := SoldierUpgradeCatalog.localized_name(upgrade_id, language)
	var purchased_message := "Permanent upgrade: %s Rank %d · recruit again to apply it automatically" % [purchased_name, int(preview["next_rank"])] if language == "en" else "士兵永久強化：%s Rank %d；重新招募後會自動生效" % [purchased_name, int(preview["next_rank"])]
	_add_notification(purchased_message, HEAL_GREEN, 2.4)
	audio.play("purchase", 0.8)
	queue_redraw()
	return true


func _soldier_recruit_cost(type_id: String) -> int:
	if not GameConfig.SOLDIERS.has(type_id):
		return 0
	var cfg: Dictionary = GameConfig.SOLDIERS[type_id]
	var discount := SoldierUpgradeCatalog.recruit_discount_for_type(type_id, soldier_research)
	return maxi(1, int(ceil(float(cfg["recruit_cost"]["gold"]) * (1.0 - discount))))


func _recruit_soldier(type_id: String, requested_count: int = 1) -> int:
	if not GameConfig.SOLDIERS.has(type_id):
		return 0
	if _is_chaos_unlock_soldier(type_id) and not all_soldiers_unlocked:
		_add_notification("擊敗萬象崩滅者・卡厄隆後解鎖。", Color("D8A4FF"), 2.4)
		return 0
	if not _is_recruit_anchor_valid():
		active_panel = ""
		_add_notification("請靠近出生房屋或友方城堡招募。", Color("F6C177"), 2.0)
		return 0
	var cfg: Dictionary = GameConfig.SOLDIERS[type_id]
	var cost := _soldier_recruit_cost(type_id)
	var bought := 0
	for _n in requested_count:
		if soldiers.size() >= _army_limit():
			_add_notification("軍隊人數已達上限。", Color("F6C177"), 1.8)
			break
		if int(player["money"]) < cost:
			_add_notification("金錢不足。", Color("F6C177"), 1.8)
			break
		player["money"] = int(player["money"]) - cost
		_spawn_soldier(type_id, _find_recruit_spawn_position(type_id))
		bought += 1
	if bought > 0:
		audio.play("purchase", 0.8)
		_add_notification("招募 %s × %d" % [cfg["name"], bought], HEAL_GREEN, 1.7)
	return bought


func _is_recruit_anchor_valid() -> bool:
	if recruit_anchor.distance_to(HOUSE_POS) <= 1.0:
		return Vector2(player["pos"]).distance_to(HOUSE_POS) <= 185.0
	for castle in castles.values():
		if bool(castle["owned"]) and recruit_anchor.distance_to(castle["pos"]) <= 1.0:
			return Vector2(player["pos"]).distance_to(castle["pos"]) <= 210.0
	return false


func _soldier_radius(type_id: String) -> float:
	if type_id == "archer": return 9.0
	if type_id in ["healer", "mage"]: return 10.0
	if type_id == "heavy": return 15.0
	if type_id == "musketeer": return 11.0
	if type_id == "rifleman": return 12.0
	if type_id == "cannon": return 19.0
	if type_id == "tank": return 29.0
	if type_id == "rocket": return 22.0
	if type_id == "gatling": return 18.0
	if type_id == "helicopter": return 30.0
	if type_id == "bomber": return 35.0
	if type_id == "ufo": return 38.0
	return 11.0


func _find_recruit_spawn_position(type_id: String) -> Vector2:
	var unit_radius := _soldier_radius(type_id)
	var ring_radius := 94.0 if recruit_anchor.distance_to(HOUSE_POS) <= 1.0 else 166.0
	var preferred := (Vector2(player["pos"]) - recruit_anchor).normalized()
	if preferred == Vector2.ZERO: preferred = Vector2.DOWN
	var base_angle := preferred.angle() + float(next_entity_id % 7 - 3) * 0.22
	for ring in 3:
		for step in 12:
			var angle := base_angle + TAU * float(step) / 12.0
			var candidate := recruit_anchor + Vector2.from_angle(angle) * (ring_radius + float(ring) * 34.0)
			if _position_hits_obstacle(candidate, unit_radius, true):
				continue
			var blocked := false
			for ally in soldiers:
				if Vector2(ally["pos"]).distance_to(candidate) < float(ally["radius"]) + unit_radius + 4.0:
					blocked = true
					break
			if not blocked:
				return candidate
	return Vector2(player["pos"]) + preferred.rotated(PI) * (PLAYER_RADIUS + unit_radius + 12.0)


func _spawn_soldier(type_id: String, position: Vector2, hp_ratio: float = 1.0) -> int:
	var cfg: Dictionary = GameConfig.SOLDIERS[type_id]
	var combat: Dictionary = cfg["combat"]
	var level_growth := 1.0 + 0.012 * float(int(player["level"]) - 1)
	var research_snapshot := SoldierUpgradeCatalog.snapshot_for_type(type_id, soldier_research)
	var base_effects: Dictionary = Dictionary(research_snapshot.get("base_effects", {}))
	var max_hp := float(combat["hp"]) * level_growth * (1.0 + float(base_effects.get("max_hp_bonus", 0.0)))
	var id := next_entity_id
	next_entity_id += 1
	var radius := _soldier_radius(type_id)
	var soldier := {
		"id": id, "type": type_id, "pos": position, "vel": Vector2.ZERO, "hp": max_hp * hp_ratio, "max_hp": max_hp,
		"attack": float(combat["attack"]) * (1.0 + 0.015 * float(int(player["level"]) - 1)) * (1.0 + float(base_effects.get("attack_or_healing_bonus", 0.0))),
		"defense": float(combat["armor"]) + floor(float(int(player["level"]) - 1) / 8.0) + float(base_effects.get("armor_bonus", 0.0)),
		"speed": float(combat["movement_speed"]) * 1.35 * (1.0 + float(base_effects.get("move_speed_bonus", 0.0))), "range": float(combat["range"]) * (1.0 + float(base_effects.get("range_bonus_ratio", 0.0))) + float(base_effects.get("range_bonus_px", 0.0)),
		"attack_rate": float(combat["attack_speed"]) * (1.0 + float(base_effects.get("attack_or_support_speed_bonus", 0.0))), "radius": radius,
		"support_power": 1.0 + float(base_effects.get("attack_or_healing_bonus", 0.0)),
		"support_rate": 1.0 + float(base_effects.get("attack_or_support_speed_bonus", 0.0)),
		"support_range": float(combat["range"]) * (1.0 + float(base_effects.get("range_bonus_ratio", 0.0))) + float(base_effects.get("range_bonus_px", 0.0)),
		"cooldown": randf_range(0.0, 0.5), "support_cd": 0.0, "revive_cd": 0.0,
		"state": "follow", "target_id": -1, "ai_accum": randf_range(0.0, 0.12),
		"flash": 0.0, "invuln": 0.0, "charge": 0.0, "cast_timer": 0.0, "cast_target": -1,
		"last_hit": -99.0, "soul_fatigue": 0.0, "aim_dir": Vector2.RIGHT, "structure_target": "",
		"avoid_dir": Vector2.ZERO, "avoid_timer": 0.0,
		"domain": str(combat.get("domain", "ground")), "altitude": 38.0 if str(combat.get("domain", "ground")) == "air" else 0.0,
		"upgrade_snapshot": research_snapshot,
		"upgrade_cooldowns": {}, "upgrade_counters": {},
	}
	soldier["special_runtime"] = SoldierUpgradeRuntime.create_state(research_snapshot, max_hp)
	soldiers.append(soldier)
	_spawn_effect("spawn", position, FRIEND_BLUE, 0.65)
	return id


func _soldier_special(soldier: Dictionary, ability_id: String) -> Dictionary:
	return SoldierUpgradeRuntime.special_effect(soldier.get("upgrade_snapshot", {}), ability_id)


func _projectile_special(projectile: Dictionary, ability_id: String) -> Dictionary:
	var specials: Dictionary = Dictionary(projectile.get("soldier_specials", {}))
	return Dictionary(specials.get(ability_id, {})).duplicate(true)


func _update_soldier_upgrade_cooldowns(soldier: Dictionary, delta: float) -> void:
	var cooldowns: Dictionary = Dictionary(soldier.get("upgrade_cooldowns", {}))
	for cooldown_key in cooldowns.keys():
		cooldowns[cooldown_key] = maxf(0.0, float(cooldowns[cooldown_key]) - delta)
	soldier["upgrade_cooldowns"] = cooldowns


func _soldier_upgrade_cooldown_ready(soldier: Dictionary, ability_id: String) -> bool:
	return float(Dictionary(soldier.get("upgrade_cooldowns", {})).get(ability_id, 0.0)) <= 0.0


func _set_soldier_upgrade_cooldown(soldier: Dictionary, ability_id: String, seconds: float) -> void:
	var cooldowns: Dictionary = Dictionary(soldier.get("upgrade_cooldowns", {}))
	cooldowns[ability_id] = maxf(0.0, seconds)
	soldier["upgrade_cooldowns"] = cooldowns


func _update_soldier_passive_upgrades(soldier: Dictionary, delta: float) -> void:
	var self_repair := _soldier_special(soldier, "self_repair")
	if not self_repair.is_empty() and game_time - float(soldier.get("last_hit", -99.0)) >= float(self_repair.get("no_hit_delay", 5.0)):
		var repair := float(soldier.get("max_hp", 1.0)) * float(self_repair.get("max_hp_heal_per_second", 0.0)) * delta
		soldier["hp"] = minf(float(soldier["max_hp"]), float(soldier["hp"]) + repair)

	var cleanse := _soldier_special(soldier, "cleanse")
	if not cleanse.is_empty() and _soldier_upgrade_cooldown_ready(soldier, "cleanse"):
		if _cleanse_friendly_target({"kind": "soldier", "id": int(soldier["id"]), "pos": Vector2(soldier["pos"])}):
			_set_soldier_upgrade_cooldown(soldier, "cleanse", float(cleanse.get("cooldown", 10.0)))

	var flares := _soldier_special(soldier, "air_flares")
	if not flares.is_empty() and _soldier_upgrade_cooldown_ready(soldier, "air_flares") and _try_intercept_hostile_homing_projectile(soldier):
		_set_soldier_upgrade_cooldown(soldier, "air_flares", float(flares.get("cooldown", 14.0)))
		_spawn_effect("explosion", soldier["pos"], Color("FFDD7A"), 0.6)

	if not _soldier_upgrade_cooldown_ready(soldier, "summon_scan"):
		return
	_set_soldier_upgrade_cooldown(soldier, "summon_scan", 0.25)
	if _nearest_enemy_distance(soldier["pos"]) > 760.0 and not _active_boss_can_be_targeted():
		return
	_try_spawn_soldier_upgrade_summon(soldier, "guardian")
	_try_spawn_soldier_upgrade_summon(soldier, "auto_turret")
	_try_spawn_soldier_upgrade_summon(soldier, "repair_drone")


func _try_intercept_hostile_homing_projectile(soldier: Dictionary) -> bool:
	var center := Vector2(soldier.get("pos", Vector2.ZERO))
	for projectile_index in range(projectiles.size() - 1, -1, -1):
		var hostile_projectile: Dictionary = projectiles[projectile_index]
		if str(hostile_projectile.get("team", "")) == "friendly" or not bool(hostile_projectile.get("homing", false)):
			continue
		if Vector2(hostile_projectile.get("pos", Vector2.ZERO)).distance_to(center) <= 230.0:
			projectiles.remove_at(projectile_index)
			return true
	for projectile_index in range(chaos_runtime_projectiles.size() - 1, -1, -1):
		var chaos_projectile: Dictionary = chaos_runtime_projectiles[projectile_index]
		if bool(chaos_projectile.get("homing", false)) and Vector2(chaos_projectile.get("pos", Vector2.ZERO)).distance_to(center) <= 230.0:
			chaos_runtime_projectiles.remove_at(projectile_index)
			return true
	for projectile_index in range(aionis_runtime_projectiles.size() - 1, -1, -1):
		var aionis_projectile: Dictionary = aionis_runtime_projectiles[projectile_index]
		if bool(aionis_projectile.get("homing", false)) and Vector2(aionis_projectile.get("pos", Vector2.ZERO)).distance_to(center) <= 230.0:
			aionis_runtime_projectiles.remove_at(projectile_index)
			return true
	return false


func _try_spawn_soldier_upgrade_summon(soldier: Dictionary, ability_id: String) -> void:
	var ability := _soldier_special(soldier, ability_id)
	if ability.is_empty() or not _soldier_upgrade_cooldown_ready(soldier, ability_id):
		return
	var owner_count := 0
	var team_count := 0
	for effect in upgrade_effects:
		var summon_kind := str(effect.get("kind", ""))
		if summon_kind not in ["guardian", "auto_turret", "repair_drone"]:
			continue
		team_count += 1
		if summon_kind == ability_id and int(effect.get("source_id", -1)) == int(soldier["id"]):
			owner_count += 1
	var owner_cap := mini(2, int(ability.get("max_per_owner", 2)))
	var team_cap := mini(MAX_UPGRADE_SUMMONS_PER_TEAM, int(ability.get("team_summon_cap", MAX_UPGRADE_SUMMONS_PER_TEAM)))
	if owner_count >= owner_cap or team_count >= team_cap:
		return
	var ttl := float(ability.get("ttl", ability.get("duration", 14.0)))
	var summon := {
		"kind": ability_id, "source_id": int(soldier["id"]), "source_kind": str(soldier["type"]),
		"pos": Vector2(soldier["pos"]) + Vector2.from_angle(float(int(soldier["id"]) % 12) * TAU / 12.0) * 42.0,
		"ttl": ttl, "warmup": 0.45, "scan": 0.0, "radius": 24.0,
		"color": Color("9BD7FF") if ability_id != "repair_drone" else HEAL_GREEN,
		"effect": ability.duplicate(true), "owner_attack": float(soldier.get("attack", 1.0)),
		"owner_max_hp": float(soldier.get("max_hp", 1.0)), "shot_cd": 0.0,
	}
	if ability_id == "guardian":
		var guardian_max_hp := maxf(1.0, float(soldier.get("max_hp", 1.0)) * maxf(0.1, float(ability.get("hp_ratio", 1.0))))
		summon["hp"] = guardian_max_hp
		summon["max_hp"] = guardian_max_hp
		summon["defeated"] = false
	_add_upgrade_runtime_effect(summon)
	_set_soldier_upgrade_cooldown(soldier, ability_id, ttl + 8.0)
	_spawn_effect("spawn", summon["pos"], Color(summon["color"]), 0.7)


func _update_soldiers(delta: float) -> void:
	for shared_key in soldier_upgrade_shared_cooldowns.keys():
		soldier_upgrade_shared_cooldowns[shared_key] = maxf(0.0, float(soldier_upgrade_shared_cooldowns[shared_key]) - delta)
	for soldier in soldiers:
		SoldierUpgradeRuntime.tick_state(soldier, delta)
		_update_soldier_upgrade_cooldowns(soldier, delta)
		_update_soldier_passive_upgrades(soldier, delta)
		soldier["cooldown"] = max(0.0, float(soldier["cooldown"]) - delta)
		soldier["support_cd"] = max(0.0, float(soldier["support_cd"]) - delta)
		soldier["revive_cd"] = max(0.0, float(soldier["revive_cd"]) - delta)
		soldier["flash"] = max(0.0, float(soldier["flash"]) - delta)
		soldier["invuln"] = max(0.0, float(soldier["invuln"]) - delta)
		soldier["soul_fatigue"] = max(0.0, float(soldier["soul_fatigue"]) - delta)
		soldier["revive_reduction_ttl"] = max(0.0, float(soldier.get("revive_reduction_ttl", 0.0)) - delta)
		soldier["dash_reduction_ttl"] = max(0.0, float(soldier.get("dash_reduction_ttl", 0.0)) - delta)
		soldier["last_stand_recovery_ttl"] = max(0.0, float(soldier.get("last_stand_recovery_ttl", 0.0)) - delta)
		if float(soldier.get("last_stand_recovery_ttl", 0.0)) > 0.0:
			soldier["hp"] = minf(float(soldier["max_hp"]), float(soldier["hp"]) + float(soldier.get("last_stand_recovery_per_second", 0.0)) * delta)
		soldier["support_shield_ttl"] = max(0.0, float(soldier.get("support_shield_ttl", 0.0)) - delta)
		if float(soldier.get("support_shield_ttl", 0.0)) <= 0.0:
			soldier["support_shield"] = 0.0
		soldier["avoid_timer"] = max(0.0, float(soldier.get("avoid_timer", 0.0)) - delta)
		soldier["ai_accum"] = float(soldier["ai_accum"]) + delta
		if float(soldier["ai_accum"]) < 0.08:
			continue
		var tick := float(soldier["ai_accum"])
		soldier["ai_accum"] = 0.0
		_update_single_soldier(soldier, tick)
	for i in range(tombstones.size() - 1, -1, -1):
		tombstones[i]["ttl"] = float(tombstones[i]["ttl"]) - delta
		if float(tombstones[i]["ttl"]) <= 0.0:
			tombstones.remove_at(i)


func _update_single_soldier(soldier: Dictionary, delta: float) -> void:
	soldier["vel"] = Vector2.ZERO
	if python_boss != null and python_boss.is_rooted("soldier", int(soldier["id"])):
		soldier["state"] = "constricted"
		return
	if soldier_command == "撤退":
		soldier["state"] = "retreat"
		_move_soldier_toward(soldier, _formation_position(soldier), delta, 1.3)
		return

	if soldier["type"] == "priest" and _update_priest(soldier, delta):
		return
	if soldier["type"] == "healer" and _update_healer(soldier, delta):
		return

	if float(soldier["charge"]) > 0.0:
		soldier["charge"] = float(soldier["charge"]) - delta
		soldier["state"] = "charge"
		if float(soldier["charge"]) <= 0.0:
			soldier["charge"] = 0.0
			# A reinforcement may enter the siege zone while a heavy weapon is
			# charging, or the player may switch orders. Revalidate before the shot
			# exists so the two-stage siege rule cannot be bypassed.
			if not _charged_structure_shot_is_still_valid(soldier):
				soldier["structure_target"] = ""
				soldier["target_id"] = -1
				soldier["state"] = "siege_wait"
				return
			soldier["state"] = "attack"
			_fire_soldier_attack(soldier, int(soldier["target_id"]))
		return

	var target_id: int = _select_soldier_enemy_target(soldier)
	soldier["target_id"] = target_id
	var enemy: Variant = _find_enemy_by_id(target_id)
	if target_id == BOSS_ENTITY_ID and _active_boss_can_be_targeted():
		enemy = _active_boss_target_proxy()
	var hostile_castle: Variant = null
	var siege_castle: Variant = _commanded_castle(false) if soldier_command == "攻城" else null
	# A siege order is deliberately two-stage: every living defender assigned to,
	# or fighting close to, the selected city must be cleared before any unit may
	# damage its outer wall or core. Melee soldiers wait at the staging ring when
	# only airborne defenders remain, while ranged allies finish that phase.
	if enemy == null and siege_castle != null and not bool(siege_castle.get("destroyed", false)) and not _siege_has_remaining_defenders(siege_castle):
		hostile_castle = siege_castle

	if enemy != null:
		soldier["structure_target"] = ""
		var to_enemy: Vector2 = Vector2(enemy["pos"]) - Vector2(soldier["pos"])
		var dist := to_enemy.length()
		if to_enemy.length_squared() > 0.01:
			soldier["aim_dir"] = to_enemy.normalized()
		var ranged := _soldier_is_ranged(str(soldier["type"]))
		var preferred := float(soldier["range"]) * (0.72 if ranged else 0.9)
		if not ranged and _try_soldier_dash_attack(soldier, enemy, target_id, dist):
			return
		if str(soldier["type"]) == "tank":
			var tank_stomp := _soldier_special(soldier, "stomp")
			if not tank_stomp.is_empty() and dist <= float(tank_stomp.get("radius", 105.0)) + float(enemy["radius"]) and _soldier_upgrade_cooldown_ready(soldier, "stomp"):
				_trigger_soldier_melee_followups(soldier, target_id, soldier["pos"], float(soldier["attack"]))
		if dist <= float(soldier["range"]) + float(enemy["radius"]):
			if float(soldier["cooldown"]) <= 0.0:
				var charge_seconds := _soldier_charge_seconds(str(soldier["type"]))
				if charge_seconds > 0.0:
					soldier["charge"] = charge_seconds
					soldier["state"] = "charge"
					soldier["cooldown"] = _soldier_attack_cooldown(soldier) + charge_seconds
				else:
					_fire_soldier_attack(soldier, target_id)
					soldier["cooldown"] = _soldier_attack_cooldown(soldier)
			elif ranged and dist < preferred * 0.58:
				_move_soldier_toward(soldier, Vector2(soldier["pos"]) - to_enemy.normalized() * 90.0, delta)
			return
		soldier["state"] = "approach"
		var anticipated_enemy := _predict_intercept_position(
			Vector2(soldier["pos"]), Vector2(enemy["pos"]), Vector2(enemy.get("vel", Vector2.ZERO)),
			0.0, 0.16, 0.16, 64.0
		)
		_move_soldier_toward(soldier, anticipated_enemy, delta)
		return

	if hostile_castle != null:
		var to_castle: Vector2 = Vector2(hostile_castle["pos"]) - Vector2(soldier["pos"])
		if to_castle.length_squared() > 0.01:
			soldier["aim_dir"] = to_castle.normalized()
		var castle_dist := Vector2(soldier["pos"]).distance_to(hostile_castle["pos"])
		if castle_dist <= float(soldier["range"]) + _castle_damage_radius(hostile_castle) and float(soldier["cooldown"]) <= 0.0:
			var castle_charge_seconds := _soldier_charge_seconds(str(soldier["type"]))
			if castle_charge_seconds > 0.0:
				soldier["charge"] = castle_charge_seconds
				soldier["target_id"] = -int(abs(str(hostile_castle["id"]).hash()))
				soldier["structure_target"] = str(hostile_castle["id"])
				soldier["state"] = "charge_castle"
				soldier["cooldown"] = _soldier_attack_cooldown(soldier) + castle_charge_seconds
			else:
				_attack_castle_with_soldier(soldier, hostile_castle)
				soldier["cooldown"] = _soldier_attack_cooldown(soldier)
		else:
			_move_soldier_toward(soldier, hostile_castle["pos"], delta)
		return

	soldier["structure_target"] = ""
	soldier["state"] = soldier_command.to_lower()
	var destination := _formation_position(soldier)
	if soldier_command == "防守": destination = command_point + _local_formation_offset(soldier)
	if soldier_command == "攻擊": destination = command_point + _local_formation_offset(soldier) * 0.6
	if soldier_command == "駐守":
		var garrison_castle: Variant = _commanded_castle(true)
		if garrison_castle != null:
			destination = _garrison_formation_position(soldier, garrison_castle)
	if soldier_command == "攻城" and siege_castle != null:
		destination = _siege_formation_position(soldier, siege_castle)
	_move_soldier_toward(soldier, destination, delta)


func _try_soldier_dash_attack(soldier: Dictionary, enemy: Dictionary, target_id: int, distance: float) -> bool:
	var dash := _soldier_special(soldier, "dash")
	if dash.is_empty() or not _soldier_upgrade_cooldown_ready(soldier, "dash"):
		return false
	var dash_distance := float(dash.get("distance", 120.0))
	if distance <= float(soldier.get("range", 55.0)) * 0.75 or distance > dash_distance + float(soldier.get("range", 55.0)):
		return false
	var origin := Vector2(soldier["pos"])
	var direction := (Vector2(enemy["pos"]) - origin).normalized()
	var destination := Vector2(enemy["pos"]) - direction * (float(soldier["radius"]) + float(enemy["radius"]) + 5.0)
	soldier["pos"] = _move_with_collision(origin, destination - origin, float(soldier["radius"]), true)
	soldier["vel"] = (Vector2(soldier["pos"]) - origin) / 0.18
	soldier["dash_reduction_ttl"] = 0.35
	soldier["dash_damage_reduction"] = clampf(float(dash.get("during_dash_damage_reduction", 0.5)), 0.0, 0.85)
	_set_soldier_upgrade_cooldown(soldier, "dash", float(dash.get("cooldown", 7.0)))
	var context := _begin_soldier_attack(soldier, enemy, target_id, Vector2(enemy["pos"]))
	var damage := float(soldier["attack"]) * float(dash.get("damage_ratio", 1.2)) * float(context.get("damage_multiplier", 1.0))
	if target_id == BOSS_ENTITY_ID:
		_damage_active_boss_melee(_allocate_attack_id("soldier_dash"), origin, direction, dash_distance + float(soldier["range"]), deg_to_rad(80.0), damage, str(soldier["type"]), int(soldier["id"]))
	else:
		var enemy_index := _enemy_index_by_id(target_id)
		if enemy_index >= 0:
			var specials: Dictionary = Dictionary(Dictionary(soldier.get("upgrade_snapshot", {})).get("special_effects", {}))
			_resolve_soldier_enemy_hit(enemy_index, damage, origin, "melee", int(soldier["id"]), specials)
	_spawn_effect("dash", soldier["pos"], Color("A8DDFF"), 0.9)
	soldier["cooldown"] = _soldier_attack_cooldown(soldier)
	return true


func _update_healer(soldier: Dictionary, delta: float) -> bool:
	var support_range := maxf(120.0, float(soldier.get("support_range", 330.0)))
	var target := _lowest_friendly_target(soldier["pos"], support_range, 0.88)
	if target.is_empty():
		return false
	var target_pos: Vector2 = target["pos"]
	if Vector2(soldier["pos"]).distance_to(target_pos) > support_range * 0.86:
		_move_soldier_toward(soldier, target_pos, delta)
		soldier["state"] = "heal_move"
		return true
	if float(soldier["support_cd"]) <= 0.0:
		var amount := 18.0 + float(int(player["level"])) * 0.6
		var heal_result := _perform_soldier_heal(soldier, target, amount, true)
		soldier["support_cd"] = 2.35 / maxf(0.1, float(soldier.get("support_rate", 1.0)))
		soldier["state"] = "heal"
		_spawn_effect("heal", target_pos, HEAL_GREEN, 0.85)
		_add_floater(target_pos + Vector2(0, -20), "+%d" % int(heal_result.get("effective", 0.0)), HEAL_GREEN, 0.9)
		audio.play("heal", 0.42)
	return true


func _update_priest(soldier: Dictionary, delta: float) -> bool:
	var resurrection := _soldier_special(soldier, "resurrection_ritual")
	var revive_chant := float(resurrection.get("chant_time", 2.8))
	var revive_cooldown := float(resurrection.get("cooldown", 14.0)) / maxf(0.1, float(soldier.get("support_rate", 1.0)))
	var revive_hp_ratio := float(resurrection.get("revive_hp_ratio", 0.45))
	if float(soldier["cast_timer"]) > 0.0:
		var tomb: Variant = _find_tombstone_by_id(int(soldier["cast_target"]))
		if tomb == null or game_time - float(soldier["last_hit"]) < 0.22:
			soldier["cast_timer"] = 0.0
			soldier["revive_cd"] = 3.0
			return false
		soldier["cast_timer"] = float(soldier["cast_timer"]) - delta
		soldier["state"] = "revive_cast"
		_spawn_particle(tomb["pos"] + Vector2(randf_range(-12, 12), randf_range(-8, 8)), Vector2(0, -24), GOLD, 0.45, 3.0, 1)
		if float(soldier["cast_timer"]) <= 0.0:
			_revive_tombstone(tomb, int(soldier["id"]), revive_hp_ratio, _soldier_special(soldier, "soul_shelter"))
			soldier["revive_cd"] = revive_cooldown
			audio.play("revive", 0.75)
		return true
	if float(soldier["revive_cd"]) <= 0.0:
		var tomb: Variant = _best_tombstone(soldier["pos"], maxf(420.0, float(soldier.get("support_range", 420.0))))
		if tomb != null:
			var dist := Vector2(soldier["pos"]).distance_to(tomb["pos"])
			if dist > 48.0:
				_move_soldier_toward(soldier, tomb["pos"], delta)
				soldier["state"] = "revive_move"
			else:
				soldier["cast_target"] = tomb["id"]
				soldier["cast_timer"] = revive_chant
				soldier["state"] = "revive_cast"
			return true
	if _try_priest_combat_mark(soldier):
		return true
	if float(soldier["support_cd"]) <= 0.0:
		var healed := false
		for ally in soldiers:
			if Vector2(ally["pos"]).distance_to(soldier["pos"]) <= maxf(155.0, float(soldier.get("support_range", 155.0)) * 0.46) and float(ally["hp"]) < float(ally["max_hp"]):
				_perform_soldier_heal(soldier, {"kind": "soldier", "id": ally["id"], "pos": ally["pos"]}, 9.0, false)
				healed = true
		if healed:
			soldier["support_cd"] = 4.0 / maxf(0.1, float(soldier.get("support_rate", 1.0)))
			_spawn_effect("heal", soldier["pos"], GOLD, 0.6)
			return true
	return false


func _try_priest_combat_mark(priest: Dictionary) -> bool:
	var void_mark := _soldier_special(priest, "void_mark")
	var focus_mark := _soldier_special(priest, "focus_mark")
	if (void_mark.is_empty() and focus_mark.is_empty()) or not _soldier_upgrade_cooldown_ready(priest, "priest_mark"):
		return false
	var target_id := _enemy_near_point(Vector2(priest["pos"]), maxf(360.0, float(priest.get("support_range", 420.0))))
	if target_id < 0 and target_id != BOSS_ENTITY_ID:
		return false
	if target_id == BOSS_ENTITY_ID:
		_apply_soldier_boss_statuses(priest, 0.0, "support")
		if python_boss != null and python_boss.is_engaged():
			python_boss.add_threat("priest", int(priest["id"]), 18.0)
		_spawn_effect("hit", _active_boss_position(), Color("B993FF"), 0.75)
	else:
		var enemy_index := _enemy_index_by_id(target_id)
		if enemy_index < 0:
			return false
		var specials: Dictionary = Dictionary(Dictionary(priest.get("upgrade_snapshot", {})).get("special_effects", {}))
		_apply_soldier_statuses_to_enemy(enemies[enemy_index], 0.0, specials, int(priest["id"]), "support")
		_spawn_effect("hit", enemies[enemy_index]["pos"], Color("B993FF"), 0.75)
	_set_soldier_upgrade_cooldown(priest, "priest_mark", 4.0)
	priest["state"] = "mark"
	return true


func _lowest_friendly_target(position: Vector2, radius: float, threshold: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	if player["alive"] and Vector2(player["pos"]).distance_to(position) <= radius:
		var ratio := float(player["hp"]) / float(player["max_hp"])
		if ratio < threshold:
			best_score = (1.0 - ratio) * 100.0 + 20.0 - Vector2(player["pos"]).distance_to(position) * 0.03
			best = {"kind": "player", "id": 0, "pos": player["pos"]}
	for ally in soldiers:
		var d := Vector2(ally["pos"]).distance_to(position)
		var ratio := float(ally["hp"]) / float(ally["max_hp"])
		if d > radius or ratio >= threshold:
			continue
		var score := (1.0 - ratio) * 100.0 - d * 0.03
		if score > best_score:
			best_score = score
			best = {"kind": "soldier", "id": ally["id"], "pos": ally["pos"]}
	return best


func _target_health_ratio(target: Dictionary) -> float:
	if str(target.get("kind", "")) == "player":
		return clampf(float(player.get("hp", 0.0)) / maxf(1.0, float(player.get("max_hp", 1.0))), 0.0, 1.0)
	var ally: Variant = _find_soldier_by_id(int(target.get("id", -1)))
	return clampf(float(ally.get("hp", 0.0)) / maxf(1.0, float(ally.get("max_hp", 1.0))), 0.0, 1.0) if ally != null else 1.0


func _target_is_vehicle_or_air(target: Dictionary) -> bool:
	if str(target.get("kind", "")) != "soldier":
		return false
	var ally: Variant = _find_soldier_by_id(int(target.get("id", -1)))
	return ally != null and (str(ally.get("domain", "ground")) == "air" or str(ally.get("type", "")) in ["roller", "cannon", "tank", "rocket", "gatling"])


func _perform_soldier_heal(healer: Dictionary, target: Dictionary, base_amount: float, allow_group: bool) -> Dictionary:
	var multiplier := SoldierUpgradeRuntime.healing_multiplier(healer, _target_health_ratio(target))
	var battlefield_repair := _soldier_special(healer, "battlefield_repair")
	if not battlefield_repair.is_empty() and _target_is_vehicle_or_air(target):
		multiplier *= 1.0 + float(battlefield_repair.get("vehicle_air_healing_bonus", 0.0))
	var result := _apply_heal_target(target, base_amount * multiplier, int(healer["id"]))
	var holy_shield := _soldier_special(healer, "holy_shield")
	if not holy_shield.is_empty():
		_grant_healing_shield(target, float(result.get("max_hp", 0.0)) * float(holy_shield.get("shield_max_hp_ratio", 0.0)), float(holy_shield.get("duration", 4.0)), float(holy_shield.get("target_cooldown", 10.0)))
	var overheal := _soldier_special(healer, "overheal_matrix")
	if not overheal.is_empty() and float(result.get("overheal", 0.0)) > 0.0:
		var converted := float(result["overheal"]) * float(overheal.get("overheal_to_shield_ratio", 0.0))
		var cap := float(result.get("max_hp", 0.0)) * float(overheal.get("shield_target_max_hp_ratio", 0.0))
		_grant_healing_shield(target, minf(converted, cap), float(overheal.get("duration", 6.0)), 0.0)
	var cleanse := _soldier_special(healer, "cleanse")
	if not cleanse.is_empty() and _soldier_upgrade_cooldown_ready(healer, "cleanse_target") and _cleanse_friendly_target(target):
		_set_soldier_upgrade_cooldown(healer, "cleanse_target", float(cleanse.get("cooldown", 10.0)))
	if allow_group and str(healer.get("type", "")) == "healer":
		var group_heal := _soldier_special(healer, "group_heal")
		var runtime: Dictionary = healer.get("special_runtime", {})
		if not group_heal.is_empty() and int(runtime.get("healing_sequence", 0)) % maxi(1, int(group_heal.get("trigger_every_heals", 3))) == 0:
			var remaining := int(group_heal.get("allies", 3))
			for ally in soldiers:
				if remaining <= 0:
					break
				if int(ally["id"]) == int(target.get("id", -1)) or float(ally["hp"]) >= float(ally["max_hp"]):
					continue
				if Vector2(ally["pos"]).distance_to(Vector2(healer["pos"])) > float(healer.get("support_range", 330.0)):
					continue
				_apply_heal_target({"kind": "soldier", "id": ally["id"], "pos": ally["pos"]}, base_amount * multiplier * float(group_heal.get("healing_ratio", 0.5)), int(healer["id"]))
				remaining -= 1
			_spawn_effect("heal", healer["pos"], Color("8EFFE0"), 1.0)
	return result


func _apply_heal_target(target: Dictionary, amount: float, healer_id: int = -1) -> Dictionary:
	var effective := 0.0
	var maximum := 0.0
	if target["kind"] == "player":
		var before_player: float = float(player["hp"])
		maximum = float(player["max_hp"])
		player["hp"] = min(float(player["max_hp"]), float(player["hp"]) + amount)
		effective = float(player["hp"]) - before_player
	else:
		var ally: Variant = _find_soldier_by_id(int(target["id"]))
		if ally != null:
			var before_ally: float = float(ally["hp"])
			maximum = float(ally["max_hp"])
			ally["hp"] = min(float(ally["max_hp"]), float(ally["hp"]) + amount)
			effective = float(ally["hp"]) - before_ally
	if healer_id >= 0 and effective > 0.0 and python_boss != null and python_boss.is_engaged():
		python_boss.add_threat("healer", healer_id, effective * float(GameConfig.PYTHON_BOSS_CONFIG["threat"]["healing_multiplier"]))
	return {"effective": effective, "overheal": maxf(0.0, amount - effective), "max_hp": maximum}


func _grant_healing_shield(target: Dictionary, amount: float, duration: float, target_cooldown: float) -> void:
	if amount <= 0.0:
		return
	if str(target.get("kind", "")) == "player":
		if target_cooldown > 0.0 and game_time < float(player.get("holy_shield_ready_at", 0.0)):
			return
		player["support_shield"] = maxf(float(player.get("support_shield", 0.0)), amount)
		player["support_shield_ttl"] = maxf(float(player.get("support_shield_ttl", 0.0)), duration)
		if target_cooldown > 0.0:
			player["holy_shield_ready_at"] = game_time + target_cooldown
	else:
		var ally: Variant = _find_soldier_by_id(int(target.get("id", -1)))
		if ally == null or (target_cooldown > 0.0 and game_time < float(ally.get("holy_shield_ready_at", 0.0))):
			return
		ally["support_shield"] = maxf(float(ally.get("support_shield", 0.0)), amount)
		ally["support_shield_ttl"] = maxf(float(ally.get("support_shield_ttl", 0.0)), duration)
		if target_cooldown > 0.0:
			ally["holy_shield_ready_at"] = game_time + target_cooldown


func _cleanse_friendly_target(target: Dictionary) -> bool:
	var target_kind := str(target.get("kind", "soldier"))
	var target_id := int(target.get("id", 0 if target_kind == "player" else -1))
	var cleansed := false
	if python_boss != null:
		var boss_cleanse: Dictionary = python_boss.cleanse_unit_status(target_kind, target_id)
		cleansed = bool(boss_cleanse.get("cleansed", false))
	var target_position := Vector2(target.get("pos", player.get("pos", Vector2.ZERO)))
	if target_kind == "soldier":
		var ally: Variant = _find_soldier_by_id(target_id)
		if ally != null:
			target_position = Vector2(ally.get("pos", target_position))
			var had_local_status := float(ally.get("burn_ttl", 0.0)) > 0.0 or float(ally.get("slow_ttl", 0.0)) > 0.0 or float(ally.get("paralysis_ttl", 0.0)) > 0.0
			ally["burn_ttl"] = 0.0
			ally["slow_ttl"] = 0.0
			ally["paralysis_ttl"] = 0.0
			cleansed = cleansed or had_local_status
	if cleansed:
		_spawn_effect("heal", target_position, Color("B9FFF4"), 0.65)
		_add_floater(target_position + Vector2(0, -24), "Cleanse" if language == "en" else "淨化", Color("B9FFF4"), 0.7)
	return cleansed


func _select_soldier_enemy_target(soldier: Dictionary) -> int:
	if soldier_command == "防守" and Vector2(soldier["pos"]).distance_to(command_point) > 480.0:
		return -1
	if soldier_command == "駐守":
		var garrison_castle: Variant = _commanded_castle(true)
		if garrison_castle == null:
			return -1
		return _best_enemy_for_castle_zone(soldier, garrison_castle, 720.0, false)
	if soldier_command == "攻城":
		var siege_castle: Variant = _commanded_castle(false)
		if siege_castle == null:
			return -1
		return _best_enemy_for_castle_zone(soldier, siege_castle, 620.0, true)
	if soldier_command == "攻擊":
		if command_target_id == BOSS_ENTITY_ID and _active_boss_can_be_targeted():
			return BOSS_ENTITY_ID
		if command_target_id >= 0:
			var commanded_enemy: Variant = _find_enemy_by_id(command_target_id)
			if commanded_enemy != null and (not _enemy_is_air(commanded_enemy) or _soldier_can_target_air(soldier)):
				return command_target_id
	var best_id := -1
	var best_dist := 560.0 if soldier_command != "攻擊" else 820.0
	for enemy in enemies:
		if _enemy_is_air(enemy) and not _soldier_can_target_air(soldier):
			continue
		var d := Vector2(soldier["pos"]).distance_to(enemy["pos"])
		if d < best_dist:
			best_dist = d
			best_id = int(enemy["id"])
	if _active_boss_can_be_targeted():
		var boss_distance: float = Vector2(soldier["pos"]).distance_to(_active_boss_position())
		if boss_distance < best_dist:
			best_id = BOSS_ENTITY_ID
	return best_id


func _best_enemy_for_castle_zone(soldier: Dictionary, castle: Dictionary, zone_radius: float, include_assigned_guards: bool) -> int:
	var best_id := -1
	var best_distance := INF
	var castle_id := str(castle["id"])
	var castle_position := Vector2(castle["pos"])
	for enemy in enemies:
		if float(enemy.get("hp", 0.0)) <= 0.0:
			continue
		if _enemy_is_air(enemy) and not _soldier_can_target_air(soldier):
			continue
		var distance_to_castle := Vector2(enemy["pos"]).distance_to(castle_position)
		var assigned_guard := include_assigned_guards and str(enemy.get("guard_castle", "")) == castle_id and distance_to_castle <= 900.0
		if not assigned_guard and distance_to_castle > zone_radius:
			continue
		var distance := Vector2(soldier["pos"]).distance_to(enemy["pos"])
		if distance < best_distance:
			best_distance = distance
			best_id = int(enemy["id"])
	if not include_assigned_guards and _active_boss_can_be_targeted() and _active_boss_position().distance_to(castle_position) <= zone_radius:
		var boss_distance := Vector2(soldier["pos"]).distance_to(_active_boss_position())
		if boss_distance < best_distance:
			best_id = BOSS_ENTITY_ID
	return best_id


func _siege_has_remaining_defenders(castle: Dictionary) -> bool:
	var castle_id := str(castle["id"])
	var castle_position := Vector2(castle["pos"])
	for enemy in enemies:
		if float(enemy.get("hp", 0.0)) <= 0.0:
			continue
		var distance_to_castle := Vector2(enemy["pos"]).distance_to(castle_position)
		if str(enemy.get("guard_castle", "")) == castle_id and distance_to_castle <= 900.0:
			return true
		if distance_to_castle <= 620.0:
			return true
	return false


func _charged_structure_shot_is_still_valid(soldier: Dictionary) -> bool:
	var structure_target := str(soldier.get("structure_target", ""))
	if structure_target.is_empty():
		return true
	if soldier_command != "攻城" or command_castle_id != structure_target or not castles.has(structure_target):
		return false
	var castle: Dictionary = castles[structure_target]
	return not bool(castle.get("owned", false)) and not bool(castle.get("destroyed", false)) and not _siege_has_remaining_defenders(castle)


func _siege_structure_locked_for_projectile(projectile: Dictionary, castle: Dictionary) -> bool:
	if soldier_command != "攻城" or command_castle_id != str(castle.get("id", "")):
		return false
	# Player shots are still free-form; this lock belongs specifically to
	# recruited units executing the staged Siege order.
	if _find_soldier_by_id(int(projectile.get("source_id", -1))) == null:
		return false
	return _siege_has_remaining_defenders(castle)


func _soldier_can_target_air(soldier: Dictionary) -> bool:
	var type_id := str(soldier.get("type", ""))
	if not GameConfig.SOLDIERS.has(type_id):
		return false
	var combat: Dictionary = GameConfig.SOLDIERS[type_id]["combat"]
	return bool(combat.get("can_target_air", type_id in ["archer", "roller", "mage", "cannon", "musketeer", "rifleman", "tank", "rocket"]))


func _soldier_is_air(soldier: Dictionary) -> bool:
	return str(soldier.get("domain", "ground")) == "air"


func _soldier_is_ranged(type_id: String) -> bool:
	return type_id in ["archer", "roller", "mage", "cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"]


func _soldier_projectile_speed(type_id: String) -> float:
	match type_id:
		"archer": return 720.0
		"roller": return 520.0
		"mage": return 500.0
		"cannon": return 430.0
		"musketeer": return 1280.0
		"rifleman": return 1540.0
		"tank": return 540.0
		"rocket": return 440.0
		"gatling", "helicopter": return 1580.0
		"bomber": return 0.0
		"ufo": return 0.0
		_: return 0.0


func _soldier_charge_seconds(type_id: String) -> float:
	if not GameConfig.SOLDIERS.has(type_id):
		return 0.0
	return float(GameConfig.SOLDIERS[type_id]["combat"].get("charge_seconds", 0.0))


func _soldier_attack_cooldown(soldier: Dictionary) -> float:
	var type_id := str(soldier.get("type", ""))
	var minimum := 0.10 if type_id in ["gatling", "helicopter"] else (0.16 if type_id == "rifleman" else 0.45)
	return maxf(minimum, 1.0 / maxf(0.01, float(soldier.get("attack_rate", 1.0)) * _soldier_rally_attack_multiplier(soldier)))


func _soldier_rally_attack_multiplier(soldier: Dictionary) -> float:
	var best_bonus := 0.0
	for aura_source in soldiers:
		var rally := _soldier_special(aura_source, "rally_beacon")
		if rally.is_empty():
			continue
		if Vector2(aura_source["pos"]).distance_to(Vector2(soldier["pos"])) <= float(rally.get("radius", 0.0)):
			best_bonus = maxf(best_bonus, float(rally.get("ally_attack_speed_bonus", 0.0)))
	return 1.0 + best_bonus


func _soldier_rally_move_multiplier(soldier: Dictionary) -> float:
	var best_bonus := 0.0
	for aura_source in soldiers:
		var rally := _soldier_special(aura_source, "rally_beacon")
		if rally.is_empty():
			continue
		if Vector2(aura_source["pos"]).distance_to(Vector2(soldier["pos"])) <= float(rally.get("radius", 0.0)):
			best_bonus = maxf(best_bonus, float(rally.get("ally_move_speed_bonus", 0.0)))
	return 1.0 + best_bonus


func _soldier_guardian_aura_reduction(soldier: Dictionary) -> float:
	var best_reduction := 0.0
	for aura_source in soldiers:
		var guardian_aura := _soldier_special(aura_source, "guardian_aura")
		if guardian_aura.is_empty():
			continue
		if Vector2(aura_source["pos"]).distance_to(Vector2(soldier["pos"])) <= float(guardian_aura.get("radius", 0.0)):
			best_reduction = maxf(best_reduction, float(guardian_aura.get("ally_damage_reduction", 0.0)))
	return clampf(best_reduction, 0.0, 0.8)


func _begin_soldier_attack(soldier: Dictionary, target: Variant, target_id: int, target_position: Vector2) -> Dictionary:
	var target_ratio := 1.0
	if target is Dictionary:
		var target_dictionary: Dictionary = target
		target_ratio = clampf(float(target_dictionary.get("hp", 1.0)) / maxf(1.0, float(target_dictionary.get("max_hp", 1.0))), 0.0, 1.0)
	var context := SoldierUpgradeRuntime.begin_attack(soldier, target_ratio)
	context["target_id"] = target_id
	soldier["pending_attack_context"] = context.duplicate(true)
	soldier["pending_split_scheduled"] = false
	soldier["pending_echo_scheduled"] = false
	_try_trigger_soldier_meteor(soldier, target_position)
	if bool(context.get("is_critical", false)):
		_spawn_effect("hit", soldier["pos"], GOLD, 0.55)
	return context


func _try_trigger_soldier_meteor(soldier: Dictionary, target_position: Vector2) -> void:
	var meteor := _soldier_special(soldier, "meteor")
	if meteor.is_empty() or float(soldier_upgrade_shared_cooldowns.get("meteor", 0.0)) > 0.0:
		return
	var cooldown := maxf(1.0, float(meteor.get("army_shared_cooldown", 16.0)))
	soldier_upgrade_shared_cooldowns["meteor"] = cooldown
	_add_upgrade_runtime_effect({
		"kind": "meteor", "source_id": int(soldier["id"]), "source_kind": str(soldier["type"]),
		"pos": target_position, "ttl": float(meteor.get("warning_time", 1.2)) + 0.08,
		"warmup": float(meteor.get("warning_time", 1.2)), "radius": float(meteor.get("radius", 120.0)),
		"damage": float(soldier.get("attack", 1.0)) * float(meteor.get("damage_ratio", 2.2)),
		"color": Color("FFB14A"), "effect": meteor.duplicate(true),
	})
	_spawn_effect("warning", target_position, Color("FFB14A"), 0.8)


func _fire_soldier_attack(soldier: Dictionary, target_id: int) -> void:
	var enemy: Variant = _find_enemy_by_id(target_id)
	if target_id == BOSS_ENTITY_ID and _active_boss_can_be_targeted():
		enemy = _active_boss_target_proxy()
	if enemy == null:
		if soldier["type"] in ["cannon", "tank", "rocket"]:
			var castle: Variant = null
			var structure_target := str(soldier.get("structure_target", ""))
			if structure_target != "" and castles.has(structure_target):
				var stored_castle: Dictionary = castles[structure_target]
				if soldier_command == "攻城" and command_castle_id == structure_target and not bool(stored_castle["owned"]) and not bool(stored_castle["destroyed"]) and not _siege_has_remaining_defenders(stored_castle):
					castle = stored_castle
			soldier["structure_target"] = ""
			if castle != null: _attack_castle_with_soldier(soldier, castle)
		return
	if _enemy_is_air(enemy) and not _soldier_can_target_air(soldier):
		return
	var origin: Vector2 = soldier["pos"]
	var target_position := Vector2(enemy["pos"])
	var attack_context := _begin_soldier_attack(soldier, enemy, target_id, target_position)
	var attack_damage := float(soldier["attack"]) * float(attack_context.get("damage_multiplier", 1.0))
	if _soldier_is_ranged(str(soldier["type"])):
		target_position = _predict_intercept_position(
			origin, target_position, Vector2(enemy.get("vel", Vector2.ZERO)),
			_soldier_projectile_speed(str(soldier["type"])), 0.08, 0.78, SOLDIER_PREDICTION_MAX_LEAD
		)
	var direction := (target_position - origin).normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector2(soldier.get("aim_dir", Vector2.RIGHT))
	soldier["aim_dir"] = direction
	if target_id == BOSS_ENTITY_ID and _active_boss_kind() == "python":
		var boss_state: Dictionary = python_boss.get_text_state()
		if str(boss_state.get("constrict_target", "")) != "" and origin.distance_to(_python_boss_position()) <= float(soldier["range"]) + 95.0:
			python_boss.damage_constrict_coils(attack_damage)
			_spawn_effect("hit", _python_boss_position(), Color("DDA6FF"), 0.8)
			return
	match str(soldier["type"]):
		"swordsman", "heavy":
			if target_id == BOSS_ENTITY_ID:
				_damage_active_boss_melee(_allocate_attack_id("soldier_melee"), origin, direction, float(soldier["range"]) + 34.0, deg_to_rad(120.0), attack_damage, str(soldier["type"]), int(soldier["id"]))
				_spawn_effect("slash", origin + direction * 24.0, FRIEND_BLUE, 0.7)
			else:
				var idx := _enemy_index_by_id(target_id)
				if idx < 0:
					return
				_resolve_soldier_enemy_hit(idx, attack_damage, origin, "melee", int(soldier["id"]), Dictionary(Dictionary(soldier.get("upgrade_snapshot", {})).get("special_effects", {})), 0.0, true)
				_trigger_soldier_melee_followups(soldier, target_id, origin, attack_damage)
				_spawn_effect("slash", origin + direction * 24.0, FRIEND_BLUE, 0.7)
		"archer":
			_spawn_projectile({"team": "friendly", "kind": "ally_arrow", "source_kind": "archer", "source_id": soldier["id"], "pos": origin + direction * 14.0, "vel": direction * 720.0, "damage": soldier["attack"], "range": 500.0, "radius": 4.0, "pierce": 1, "aoe": 0.0, "color": Color("A9D8FF")})
		"roller":
			_spawn_projectile({"team": "friendly", "kind": "rolling_rock", "source_kind": "roller", "source_id": soldier["id"], "pos": origin + direction * 17.0, "vel": direction * 520.0, "damage": soldier["attack"], "range": 460.0, "radius": 11.0, "pierce": 5, "aoe": 0.0, "color": Color("A7B2BE"), "falloff": 0.82})
		"mage":
			_spawn_projectile({"team": "friendly", "kind": "ally_magic", "source_kind": "mage", "source_id": soldier["id"], "pos": origin + direction * 14.0, "vel": direction * 500.0, "damage": soldier["attack"], "range": 410.0, "radius": 7.0, "pierce": 1, "aoe": 64.0, "color": MAGIC_PURPLE})
		"cannon":
			var heavy_cannon_combat: Dictionary = GameConfig.SOLDIERS["cannon"]["combat"]
			_spawn_projectile({"team": "friendly", "kind": "cannonball", "source_kind": "cannon", "source_id": soldier["id"], "pos": origin + direction * 24.0, "vel": direction * 430.0, "damage": soldier["attack"], "range": 800.0, "radius": 13.0, "pierce": 1, "aoe": float(heavy_cannon_combat["aoe_radius"]), "color": Color("303A42"), "siege": float(heavy_cannon_combat["siege_multiplier"])})
			audio.play("cannon", 0.7)
			camera_shake = max(camera_shake, 0.32)
		"musketeer":
			_spawn_projectile({"team": "friendly", "kind": "musket_ball", "source_kind": "musketeer", "source_id": soldier["id"], "pos": origin + direction * 23.0, "vel": direction * 1280.0, "damage": soldier["attack"], "range": 690.0, "radius": 4.0, "pierce": 1, "aoe": 0.0, "armor_penetration": 22.0, "color": Color("FFE9B0")})
			_spawn_effect("muzzle", origin + direction * 25.0, GOLD, 0.55)
			audio.play("musket", 0.68)
		"rifleman":
			_spawn_projectile({"team": "friendly", "kind": "rifle_round", "source_kind": "rifleman", "source_id": soldier["id"], "pos": origin + direction * 22.0, "vel": direction * 1540.0, "damage": soldier["attack"], "range": 570.0, "radius": 3.0, "pierce": 1, "aoe": 0.0, "armor_penetration": 8.0, "color": Color("FFE36B")})
			_spawn_effect("muzzle", origin + direction * 24.0, Color("FFE36B"), 0.38)
			audio.play("rifle", 0.28)
		"tank":
			var tank_combat: Dictionary = GameConfig.SOLDIERS["tank"]["combat"]
			_spawn_projectile({"team": "friendly", "kind": "tank_shell", "source_kind": "tank", "source_id": soldier["id"], "pos": origin + direction * 38.0, "vel": direction * 540.0, "damage": soldier["attack"], "range": 760.0, "radius": 12.0, "pierce": 1, "aoe": float(tank_combat["aoe_radius"]), "color": Color("3B4037"), "siege": float(tank_combat["siege_multiplier"]), "armor_penetration": 16.0})
			audio.play("cannon", 0.78)
			camera_shake = max(camera_shake, 0.38)
		"rocket":
			var rocket_combat: Dictionary = GameConfig.SOLDIERS["rocket"]["combat"]
			_spawn_projectile({"team": "friendly", "kind": "rocket", "source_kind": "rocket", "source_id": soldier["id"], "pos": origin + direction * 32.0, "vel": direction * 440.0, "damage": soldier["attack"], "range": 860.0, "radius": 11.0, "pierce": 1, "aoe": float(rocket_combat["aoe_radius"]), "color": Color("D85A36"), "siege": float(rocket_combat["siege_multiplier"]), "armor_penetration": 12.0})
			audio.play("rocket", 0.8)
			camera_shake = max(camera_shake, 0.42)
		"gatling", "helicopter":
			_spawn_projectile({"team": "friendly", "kind": "gatling_round", "source_kind": str(soldier["type"]), "source_id": soldier["id"], "pos": origin + direction * 30.0, "vel": direction * 1580.0, "damage": soldier["attack"], "range": 650.0, "radius": 3.2, "pierce": 1, "aoe": 0.0, "armor_penetration": 7.0, "color": Color("83E8FF")})
			_spawn_effect("muzzle", origin + direction * 31.0, Color("83E8FF"), 0.42)
			audio.play("rifle", 0.25, randf_range(1.05, 1.12))
		"bomber":
			var bomber_combat: Dictionary = GameConfig.SOLDIERS["bomber"]["combat"]
			for bomb_index in 3:
				var side := Vector2(-direction.y, direction.x)
				var bomb_target := target_position + direction * (float(bomb_index) - 1.0) * 52.0 + side * (-34.0 + float(bomb_index) * 34.0)
				_spawn_projectile({"team": "friendly", "kind": "bomb", "source_kind": "bomber", "source_id": soldier["id"], "pos": bomb_target, "vel": Vector2.ZERO, "damage": float(soldier["attack"]) * (0.82 + float(bomb_index) * 0.09), "range": 1.0, "radius": 12.0, "pierce": 1, "aoe": float(bomber_combat["aoe_radius"]), "color": Color("385D77"), "ttl": 0.55 + float(bomb_index) * 0.24, "delayed_impact": true, "drop_height": 92.0})
			audio.play("bomb", 0.42)
		"ufo":
			var ufo_combat: Dictionary = GameConfig.SOLDIERS["ufo"]["combat"]
			hazards.append({"id": _allocate_attack_id("friendly_ufo_beam"), "kind": "ufo_beam", "team": "friendly", "source_id": soldier["id"], "source_kind": "ufo", "pos": target_position, "radius": float(ufo_combat["aoe_radius"]) + float(attack_context.get("bonus_radius", 0.0)), "ttl": 2.5, "warmup": 0.75, "tick": 0.0, "damage": attack_damage, "soldier_specials": Dictionary(Dictionary(soldier.get("upgrade_snapshot", {})).get("special_effects", {})).duplicate(true)})
			_schedule_ufo_upgrade_effects(soldier, target_position, float(ufo_combat["aoe_radius"]), attack_damage, attack_context)
			audio.play("magic", 0.64, 1.12)


func _schedule_ufo_upgrade_effects(soldier: Dictionary, target_position: Vector2, radius: float, attack_damage: float, attack_context: Dictionary) -> void:
	var gravity := _soldier_special(soldier, "gravity_warhead")
	if not gravity.is_empty():
		var gravity_duration := maxf(0.1, float(gravity.get("duration", 2.5)))
		var gravity_warmup := minf(0.75, gravity_duration)
		_add_upgrade_runtime_effect({
			"kind": "gravity", "source_id": int(soldier["id"]), "source_kind": str(soldier["type"]), "pos": target_position,
			"ttl": gravity_duration, "warmup": gravity_warmup, "radius": float(gravity.get("radius", radius)),
			"pull_distance": float(gravity.get("pull_distance", 70.0)), "slow_ratio": float(gravity.get("slow_ratio", 0.15)),
			"pull_duration": maxf(0.1, gravity_duration - gravity_warmup), "pull_elapsed": 0.0, "color": Color("9C7CFF"),
		})
	if bool(attack_context.get("echo", false)):
		_add_upgrade_runtime_effect({
			"kind": "ufo_echo", "source_id": int(soldier["id"]), "source_kind": str(soldier["type"]), "pos": target_position,
			"ttl": float(attack_context.get("echo_delay", 0.35)) + 0.08, "warmup": float(attack_context.get("echo_delay", 0.35)),
			"radius": radius, "damage": attack_damage * float(attack_context.get("echo_damage_ratio", 0.45)), "color": Color("B993FF"),
		})


func _special_from_map(specials: Dictionary, ability_id: String) -> Dictionary:
	var value: Dictionary = Dictionary(specials.get(ability_id, {}))
	return Dictionary(value.get("effect", value)).duplicate(true)


func _resolve_soldier_enemy_hit(
	enemy_index: int,
	raw_damage: float,
	source_pos: Vector2,
	damage_kind: String,
	source_id: int,
	specials: Dictionary,
	armor_penetration: float = 0.0,
	allow_followups: bool = false
) -> float:
	if enemy_index < 0 or enemy_index >= enemies.size():
		return 0.0
	var enemy: Dictionary = enemies[enemy_index]
	var primary_enemy_id := int(enemy.get("id", -1))
	var primary_enemy_position := Vector2(enemy.get("pos", source_pos))
	var adjusted_damage := maxf(0.0, raw_damage)
	if float(enemy.get("soldier_void_mark_ttl", 0.0)) > 0.0:
		adjusted_damage *= 1.0 + clampf(float(enemy.get("soldier_void_damage_bonus", 0.0)), 0.0, 1.0)
	if float(enemy.get("soldier_focus_mark_ttl", 0.0)) > 0.0 and int(enemy.get("soldier_focus_source_id", -1)) != source_id:
		adjusted_damage *= 1.0 + clampf(float(enemy.get("soldier_focus_damage_bonus", 0.0)), 0.0, 1.0)
	var armor_core := _special_from_map(specials, "armor_piercing_core")
	if damage_kind == "melee" and not armor_core.is_empty():
		armor_penetration += maxf(0.0, float(armor_core.get("ignored_armor", 0.0)))
	_apply_soldier_statuses_to_enemy(enemy, adjusted_damage, specials, source_id, damage_kind)
	var dealt := _damage_enemy(enemy_index, adjusted_damage, source_pos, damage_kind, armor_penetration, source_id)
	_apply_soldier_lifesteal(source_id, dealt, specials)
	if allow_followups and dealt > 0.0:
		_trigger_soldier_ranged_followups(primary_enemy_id, primary_enemy_position, adjusted_damage, source_id, specials)
	return dealt


func _apply_soldier_statuses_to_enemy(enemy: Dictionary, hit_damage: float, specials: Dictionary, source_id: int, damage_kind: String) -> void:
	var burn := _special_from_map(specials, "burning_sword" if damage_kind == "melee" else "burning_ammo")
	if not burn.is_empty():
		var proc_times: Dictionary = Dictionary(enemy.get("soldier_burn_proc_times", {}))
		var proc_key := str(source_id)
		if game_time >= float(proc_times.get(proc_key, -99.0)):
			var burn_duration := maxf(0.1, float(burn.get("duration", 3.0)))
			enemy["soldier_burn_ttl"] = maxf(float(enemy.get("soldier_burn_ttl", 0.0)), burn_duration)
			enemy["soldier_burn_dps"] = maxf(float(enemy.get("soldier_burn_dps", 0.0)), hit_damage * float(burn.get("total_burn_ratio", 0.0)) / burn_duration)
			enemy["soldier_burn_source_id"] = source_id
			proc_times[proc_key] = game_time + maxf(0.0, float(burn.get("source_target_proc_cooldown", 0.0)))
			enemy["soldier_burn_proc_times"] = proc_times
	var toxic := _special_from_map(specials, "toxic_payload")
	if not toxic.is_empty():
		var poison_sources: Dictionary = Dictionary(enemy.get("soldier_poison_sources", {}))
		var poison_key := str(source_id)
		var poison_entry: Dictionary = Dictionary(poison_sources.get(poison_key, {}))
		var duration := maxf(0.1, float(toxic.get("duration", 5.0)))
		poison_entry["stacks"] = mini(maxi(1, int(toxic.get("max_stacks", 3))), int(poison_entry.get("stacks", 0)) + 1)
		poison_entry["ttl"] = duration
		poison_entry["dps_per_stack"] = maxf(float(poison_entry.get("dps_per_stack", 0.0)), hit_damage * float(toxic.get("total_poison_ratio", 0.0)) / duration)
		poison_sources[poison_key] = poison_entry
		enemy["soldier_poison_sources"] = poison_sources
	var frost := _special_from_map(specials, "frost_arrow")
	if not frost.is_empty():
		enemy["slow"] = maxf(float(enemy.get("slow", 0.0)), float(frost.get("duration", 2.0)))
		enemy["slow_factor"] = maxf(float(enemy.get("slow_factor", 0.0)), float(frost.get("slow_ratio", 0.25)))
	var paralysis := _special_from_map(specials, "paralysis_arrow")
	if not paralysis.is_empty():
		var source_soldier: Variant = _find_soldier_by_id(source_id)
		var sequence := int(Dictionary(source_soldier.get("special_runtime", {})).get("attack_sequence", 0)) if source_soldier != null else 0
		if sequence > 0 and sequence % maxi(1, int(paralysis.get("arrow_interval", 7))) == 0:
			enemy["enhancement_stun"] = maxf(float(enemy.get("enhancement_stun", 0.0)), float(paralysis.get("normal_stun", 0.45)))
	var corrosion := _special_from_map(specials, "corrosion")
	if not corrosion.is_empty():
		var stacks := mini(maxi(1, int(corrosion.get("max_stacks", 2))), int(enemy.get("soldier_corrosion_stacks", 0)) + 1)
		enemy["soldier_corrosion_stacks"] = stacks
		enemy["armor_break"] = maxf(float(enemy.get("armor_break", 0.0)), float(corrosion.get("duration", 4.0)))
		enemy["armor_reduction"] = maxf(float(enemy.get("armor_reduction", 0.0)), float(corrosion.get("armor_reduction", 0.0)) * float(stacks))
	var void_mark := _special_from_map(specials, "void_mark")
	if not void_mark.is_empty():
		enemy["soldier_void_mark_ttl"] = maxf(float(enemy.get("soldier_void_mark_ttl", 0.0)), float(void_mark.get("duration", 4.0)))
		enemy["soldier_void_damage_bonus"] = maxf(float(enemy.get("soldier_void_damage_bonus", 0.0)), float(void_mark.get("soldier_damage_taken_bonus", 0.0)))
	var suppression := _special_from_map(specials, "suppression")
	if not suppression.is_empty():
		var suppression_hits: Dictionary = Dictionary(enemy.get("soldier_suppression_hits", {}))
		var suppression_key := str(source_id)
		var hits := int(suppression_hits.get(suppression_key, 0)) + 1
		if hits >= maxi(1, int(suppression.get("hit_threshold", 6))):
			hits = 0
			enemy["soldier_suppression_ttl"] = maxf(float(enemy.get("soldier_suppression_ttl", 0.0)), float(suppression.get("effect_duration", 3.5)))
			enemy["soldier_suppression_move_reduction"] = maxf(float(enemy.get("soldier_suppression_move_reduction", 0.0)), float(suppression.get("move_reduction", 0.2)))
			enemy["soldier_suppression_attack_reduction"] = maxf(float(enemy.get("soldier_suppression_attack_reduction", 0.0)), float(suppression.get("attack_speed_reduction", 0.1)))
		suppression_hits[suppression_key] = hits
		enemy["soldier_suppression_hits"] = suppression_hits
	var focus := _special_from_map(specials, "focus_mark")
	if not focus.is_empty():
		enemy["soldier_focus_mark_ttl"] = float(focus.get("effect_duration", 4.0))
		enemy["soldier_focus_source_id"] = source_id
		enemy["soldier_focus_damage_bonus"] = maxf(float(enemy.get("soldier_focus_damage_bonus", 0.0)), float(focus.get("other_ally_damage_bonus", 0.0)))


func _apply_soldier_lifesteal(source_id: int, dealt_damage: float, specials: Dictionary) -> void:
	if dealt_damage <= 0.0:
		return
	var lifesteal := _special_from_map(specials, "lifesteal")
	var soldier: Variant = _find_soldier_by_id(source_id)
	if lifesteal.is_empty() or soldier == null:
		return
	var window := int(floor(game_time))
	if int(soldier.get("lifesteal_window", -1)) != window:
		soldier["lifesteal_window"] = window
		soldier["lifesteal_used"] = 0.0
	var cap := float(soldier.get("max_hp", 1.0)) * float(lifesteal.get("max_hp_heal_cap_per_second_ratio", 0.06))
	var available := maxf(0.0, cap - float(soldier.get("lifesteal_used", 0.0)))
	var healed := minf(available, dealt_damage * float(lifesteal.get("lifesteal_ratio", 0.0)))
	if healed <= 0.0:
		return
	soldier["hp"] = minf(float(soldier["max_hp"]), float(soldier["hp"]) + healed)
	soldier["lifesteal_used"] = float(soldier.get("lifesteal_used", 0.0)) + healed


func _trigger_soldier_melee_followups(soldier: Dictionary, primary_enemy_id: int, origin: Vector2, attack_damage: float) -> void:
	var specials: Dictionary = Dictionary(Dictionary(soldier.get("upgrade_snapshot", {})).get("special_effects", {}))
	var sweep := _special_from_map(specials, "sweeping_slash")
	if not sweep.is_empty():
		var candidates: Array[Dictionary] = []
		for enemy in enemies:
			if int(enemy["id"]) == primary_enemy_id or _enemy_is_air(enemy):
				continue
			var distance := Vector2(enemy["pos"]).distance_to(origin)
			if distance <= float(soldier.get("range", 70.0)) + 58.0:
				candidates.append({"id": int(enemy["id"]), "distance": distance})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
		for candidate_index in mini(int(sweep.get("extra_targets", 2)), candidates.size()):
			var enemy_index := _enemy_index_by_id(int(candidates[candidate_index]["id"]))
			if enemy_index >= 0:
				_resolve_soldier_enemy_hit(enemy_index, attack_damage * float(sweep.get("sweep_damage_ratio", 0.6)), origin, "melee", int(soldier["id"]), specials)
	var stomp := _special_from_map(specials, "stomp")
	if stomp.is_empty() or not _soldier_upgrade_cooldown_ready(soldier, "stomp"):
		return
	_set_soldier_upgrade_cooldown(soldier, "stomp", float(stomp.get("cooldown", 5.5)))
	var radius := float(stomp.get("radius", 105.0))
	var hit_ids: Array[int] = []
	for enemy in enemies:
		if not _enemy_is_air(enemy) and Vector2(enemy["pos"]).distance_to(origin) <= radius + float(enemy["radius"]):
			hit_ids.append(int(enemy["id"]))
	for hit_id in hit_ids:
		var enemy_index := _enemy_index_by_id(hit_id)
		if enemy_index >= 0:
			enemies[enemy_index]["enhancement_stun"] = maxf(float(enemies[enemy_index].get("enhancement_stun", 0.0)), float(stomp.get("stun_duration", 0.45)))
			_resolve_soldier_enemy_hit(enemy_index, attack_damage * float(stomp.get("damage_ratio", 0.65)), origin, "area", int(soldier["id"]), specials)
	_spawn_effect("explosion", origin, Color("D6A66D"), clampf(radius / 110.0, 0.7, 1.4))


func _trigger_soldier_ranged_followups(primary_enemy_id: int, primary_position: Vector2, damage: float, source_id: int, specials: Dictionary) -> void:
	var excluded: Dictionary = {primary_enemy_id: true}
	var chain := _special_from_map(specials, "chain_lightning")
	if not chain.is_empty():
		var chain_origin := primary_position
		for _jump in clampi(int(chain.get("jumps", 0)), 0, 6):
			var next_id := _nearest_enemy_excluding(chain_origin, float(chain.get("jump_range", 240.0)), excluded)
			if next_id < 0:
				break
			excluded[next_id] = true
			var next_index := _enemy_index_by_id(next_id)
			if next_index < 0:
				break
			var next_position := Vector2(enemies[next_index]["pos"])
			_damage_enemy(next_index, damage * float(chain.get("jump_damage_ratio", 0.35)), chain_origin, "chain", 0.0, source_id)
			_spawn_effect("hit", next_position, Color("9EEAFF"), 0.6)
			chain_origin = next_position
	var ricochet := _special_from_map(specials, "ricochet")
	if not ricochet.is_empty():
		for _bounce in clampi(int(ricochet.get("extra_targets", 0)), 0, 4):
			var bounce_id := _nearest_enemy_excluding(primary_position, float(ricochet.get("ricochet_range", 280.0)), excluded)
			if bounce_id < 0:
				break
			excluded[bounce_id] = true
			var bounce_index := _enemy_index_by_id(bounce_id)
			if bounce_index >= 0:
				_damage_enemy(bounce_index, damage * float(ricochet.get("ricochet_damage_ratio", 0.45)), primary_position, "projectile", 0.0, source_id)


func _nearest_enemy_excluding(position: Vector2, radius: float, excluded: Dictionary) -> int:
	var result := -1
	var nearest := radius
	for enemy in enemies:
		if excluded.has(int(enemy["id"])):
			continue
		var distance := Vector2(enemy["pos"]).distance_to(position)
		if distance < nearest:
			nearest = distance
			result = int(enemy["id"])
	return result


func _attack_castle_with_soldier(soldier: Dictionary, castle: Dictionary) -> void:
	var type_id := str(soldier["type"])
	var combat: Dictionary = GameConfig.SOLDIERS[type_id]["combat"]
	var origin: Vector2 = soldier["pos"]
	var direction := (Vector2(castle["pos"]) - origin).normalized()
	if direction.length_squared() < 0.01: direction = Vector2.RIGHT
	soldier["aim_dir"] = direction
	var attack_context := _begin_soldier_attack(soldier, castle, -int(abs(str(castle["id"]).hash())), Vector2(castle["pos"]))
	var projectile_range := maxf(float(combat["range"]) + 260.0, origin.distance_to(Vector2(castle["pos"])) + 90.0)
	# 科技遠程兵攻城仍使用真實飛行彈體；外牆會在命中／爆炸時才受傷。
	match type_id:
		"musketeer":
			_spawn_projectile({"team": "friendly", "kind": "musket_ball", "source_kind": type_id, "source_id": soldier["id"], "pos": origin + direction * 23.0, "vel": direction * 1280.0, "damage": soldier["attack"], "range": projectile_range, "radius": 4.0, "pierce": 1, "aoe": 0.0, "siege": 0.8, "armor_penetration": 22.0, "color": Color("FFE9B0")})
			_spawn_effect("muzzle", origin + direction * 25.0, GOLD, 0.55)
			audio.play("musket", 0.68)
			return
		"rifleman":
			_spawn_projectile({"team": "friendly", "kind": "rifle_round", "source_kind": type_id, "source_id": soldier["id"], "pos": origin + direction * 22.0, "vel": direction * 1540.0, "damage": soldier["attack"], "range": projectile_range, "radius": 3.0, "pierce": 1, "aoe": 0.0, "siege": 0.8, "armor_penetration": 8.0, "color": Color("FFE36B")})
			_spawn_effect("muzzle", origin + direction * 24.0, Color("FFE36B"), 0.38)
			audio.play("rifle", 0.28)
			return
		"cannon":
			_spawn_projectile({"team": "friendly", "kind": "cannonball", "source_kind": type_id, "source_id": soldier["id"], "pos": origin + direction * 27.0, "vel": direction * 430.0, "damage": soldier["attack"], "range": projectile_range, "radius": 13.0, "pierce": 1, "aoe": float(combat["aoe_radius"]), "color": Color("303A42"), "siege": float(combat["siege_multiplier"])})
			audio.play("cannon", 0.76)
			camera_shake = max(camera_shake, 0.32)
			return
		"tank":
			_spawn_projectile({"team": "friendly", "kind": "tank_shell", "source_kind": type_id, "source_id": soldier["id"], "pos": origin + direction * 38.0, "vel": direction * 540.0, "damage": soldier["attack"], "range": projectile_range, "radius": 12.0, "pierce": 1, "aoe": float(combat["aoe_radius"]), "color": Color("3B4037"), "siege": float(combat["siege_multiplier"]), "armor_penetration": 16.0})
			audio.play("cannon", 0.78)
			camera_shake = max(camera_shake, 0.38)
			return
		"rocket":
			_spawn_projectile({"team": "friendly", "kind": "rocket", "source_kind": type_id, "source_id": soldier["id"], "pos": origin + direction * 32.0, "vel": direction * 440.0, "damage": soldier["attack"], "range": projectile_range, "radius": 11.0, "pierce": 1, "aoe": float(combat["aoe_radius"]), "color": Color("D85A36"), "siege": float(combat["siege_multiplier"]), "armor_penetration": 12.0})
			audio.play("rocket", 0.8)
			camera_shake = max(camera_shake, 0.42)
			return
		"gatling", "helicopter":
			_spawn_projectile({"team": "friendly", "kind": "gatling_round", "source_kind": type_id, "source_id": soldier["id"], "pos": origin + direction * 29.0, "vel": direction * 1580.0, "damage": soldier["attack"], "range": projectile_range, "radius": 3.2, "pierce": 1, "aoe": 0.0, "siege": 0.72, "armor_penetration": 7.0, "color": Color("83E8FF")})
			_spawn_effect("muzzle", origin + direction * 31.0, Color("83E8FF"), 0.38)
			return
		"bomber":
			for bomb_index in 3:
				var bomb_position := Vector2(castle["pos"]) + Vector2.from_angle(float(bomb_index) * TAU / 3.0) * 58.0
				_spawn_projectile({"team": "friendly", "kind": "bomb", "source_kind": type_id, "source_id": soldier["id"], "pos": bomb_position, "vel": Vector2.ZERO, "damage": float(soldier["attack"]) * 0.88, "range": 1.0, "radius": 12.0, "pierce": 1, "aoe": float(combat["aoe_radius"]), "color": Color("385D77"), "ttl": 0.55 + float(bomb_index) * 0.24, "delayed_impact": true, "drop_height": 92.0, "siege": 1.25})
			return
		"ufo":
			hazards.append({"id": _allocate_attack_id("friendly_ufo_siege"), "kind": "ufo_beam", "team": "friendly", "source_id": soldier["id"], "source_kind": "ufo", "pos": Vector2(castle["pos"]), "radius": float(combat["aoe_radius"]), "ttl": 2.5, "warmup": 0.75, "tick": 0.0, "damage": float(soldier["attack"])})
			return
	var damage := float(soldier["attack"]) * float(attack_context.get("damage_multiplier", 1.0))
	if combat.has("siege_multiplier"): damage *= float(combat["siege_multiplier"])
	elif type_id not in ["swordsman", "heavy"]: damage *= 0.8
	var siege_warhead := _soldier_special(soldier, "siege_warhead")
	if not siege_warhead.is_empty():
		damage *= 1.0 + float(siege_warhead.get("structure_damage_bonus", 0.0))
	_damage_castle(castle, damage)
	_spawn_effect("hit", castle["pos"] + Vector2(randf_range(-80, 80), randf_range(-70, 70)), FRIEND_BLUE, 0.9)


func _formation_position(soldier: Dictionary) -> Vector2:
	# Followers steer toward where the moving player will be shortly, keeping a
	# readable formation instead of trailing behind every direction change.
	var player_lead := (Vector2(player.get("vel", Vector2.ZERO)) * 0.24).limit_length(92.0)
	return Vector2(player["pos"]) + player_lead + _local_formation_offset(soldier)


func _local_formation_offset(soldier: Dictionary) -> Vector2:
	var index: int = max(0, soldiers.find(soldier))
	var role_row := -70.0
	match str(soldier["type"]):
		"swordsman", "heavy": role_row = 75.0
		"archer", "roller", "mage", "musketeer", "rifleman": role_row = -65.0
		"healer", "priest": role_row = -135.0
		"cannon", "tank", "rocket": role_row = -220.0
	var row_members: Array = []
	for ally in soldiers:
		var same_group: bool = (ally["type"] in ["swordsman", "heavy"]) == (soldier["type"] in ["swordsman", "heavy"])
		if same_group: row_members.append(ally)
	var lateral := (float(index % 7) - 3.0) * 43.0
	var forward: Vector2 = player["facing"]
	var side := Vector2(-forward.y, forward.x)
	return forward * role_row + side * lateral


func _garrison_formation_position(soldier: Dictionary, castle: Dictionary) -> Vector2:
	# Every current soldier receives a unique slot. Sixteen lanes per ring keep
	# large late-game armies readable instead of folding units onto the same 50
	# points once castle bonuses raise the cap above 50.
	var slot := maxi(0, soldiers.find(soldier))
	var lanes := 16
	var ring := int(slot / lanes)
	var lane := slot % lanes
	var angle := TAU * (float(lane) + float(ring % 2) * 0.5) / float(lanes)
	var radius := 150.0 + float(ring) * 34.0
	return Vector2(castle["pos"]) + Vector2.from_angle(angle) * radius


func _siege_formation_position(soldier: Dictionary, castle: Dictionary) -> Vector2:
	var center := Vector2(castle["pos"])
	# Absolute slots make the staging destination independent of the unit's
	# current position; otherwise recomputing from its approach angle creates an
	# endless slow orbit around the target city.
	var slot := maxi(0, soldiers.find(soldier))
	var lanes := 16
	var ring := int(slot / lanes)
	var lane := slot % lanes
	var angle := TAU * (float(lane) + float(ring % 2) * 0.5) / float(lanes)
	return center + Vector2.from_angle(angle) * (300.0 + float(ring) * 36.0)


func _soldier_tree_avoidance_direction(soldier: Dictionary, desired: Vector2) -> Vector2:
	if desired.length_squared() <= 0.0001:
		return Vector2.ZERO
	var position := Vector2(soldier["pos"])
	var radius := float(soldier["radius"])
	var probe_distance := maxf(62.0, radius * 3.2)
	var remembered := Vector2(soldier.get("avoid_dir", Vector2.ZERO))
	if float(soldier.get("avoid_timer", 0.0)) > 0.0 and remembered.length_squared() > 0.01:
		if not _segment_hits_environment_obstacle(position, position + remembered.normalized() * probe_distance, radius + 2.0):
			return remembered.normalized()
	if not _segment_hits_environment_obstacle(position, position + desired * probe_distance, radius + 2.0):
		soldier["avoid_dir"] = Vector2.ZERO
		return desired
	var turn_sign := -1.0 if int(soldier.get("id", 0)) % 2 == 0 else 1.0
	for signed_angle in [0.55 * turn_sign, -0.55 * turn_sign, 1.0 * turn_sign, -1.0 * turn_sign, 1.42 * turn_sign, -1.42 * turn_sign]:
		var candidate := desired.rotated(float(signed_angle)).normalized()
		if _segment_hits_environment_obstacle(position, position + candidate * probe_distance, radius + 2.0):
			continue
		soldier["avoid_dir"] = candidate
		soldier["avoid_timer"] = 0.55
		return candidate
	# A deterministic side-step keeps the unit trying a way around a dense grove
	# instead of alternating sides and vibrating against the same trunk.
	var fallback := desired.rotated(turn_sign * PI * 0.5).normalized()
	soldier["avoid_dir"] = fallback
	soldier["avoid_timer"] = 0.35
	return fallback


func _move_soldier_toward(soldier: Dictionary, destination: Vector2, delta: float, speed_scale: float = 1.0) -> void:
	if python_boss != null and python_boss.is_rooted("soldier", int(soldier["id"])):
		return
	if _soldier_is_air(soldier):
		var air_offset := destination - Vector2(soldier["pos"])
		if air_offset.length() <= 9.0:
			soldier["vel"] = Vector2.ZERO
			return
		var air_separation := Vector2.ZERO
		for other in soldiers:
			if other["id"] == soldier["id"] or not _soldier_is_air(other):
				continue
			var air_away := Vector2(soldier["pos"]) - Vector2(other["pos"])
			var air_desired := float(soldier["radius"]) + float(other["radius"]) + 12.0
			if air_away.length_squared() > 0.01 and air_away.length() < air_desired:
				air_separation += air_away.normalized() * (1.0 - air_away.length() / air_desired)
		var air_direction := (air_offset.normalized() + air_separation * 1.15).limit_length(1.0)
		var air_old_position := Vector2(soldier["pos"])
		var air_speed := float(soldier["speed"]) * speed_scale * _soldier_rally_move_multiplier(soldier)
		soldier["pos"] = air_old_position + air_direction * air_speed * delta
		soldier["vel"] = (Vector2(soldier["pos"]) - air_old_position) / maxf(delta, 0.0001)
		var air_barrier_result := SoldierUpgradeRuntime.record_movement(soldier, air_old_position.distance_to(Vector2(soldier["pos"])))
		if bool(air_barrier_result.get("activated", false)):
			_spawn_effect("shield", soldier["pos"], Color("7DD8FF"), 0.72)
		return
	if _position_hits_tree(Vector2(soldier["pos"]), float(soldier["radius"])):
		var escape_direction := (destination - Vector2(soldier["pos"])).normalized()
		if escape_direction == Vector2.ZERO:
			escape_direction = Vector2.from_angle(float(int(soldier.get("id", 1))) * 2.39996)
		var escape_preference := Vector2(soldier["pos"]) + escape_direction * maxf(90.0, float(soldier["radius"]) * 4.0)
		var escape_position := _find_open_spawn_position(Vector2(soldier["pos"]), escape_preference, float(soldier["radius"]), true)
		# The fallback search can be exhausted in a deliberately packed test map.
		# Never trade a tree overlap for a house/castle overlap in that case.
		if not _position_hits_obstacle(escape_position, float(soldier["radius"]), true):
			soldier["pos"] = escape_position
			soldier["vel"] = Vector2.ZERO
			soldier["avoid_dir"] = (destination - escape_position).normalized()
			soldier["avoid_timer"] = 0.7
	var offset := destination - Vector2(soldier["pos"])
	if offset.length() <= 9.0:
		return
	var separation := Vector2.ZERO
	for other in soldiers:
		if other["id"] == soldier["id"]: continue
		var away := Vector2(soldier["pos"]) - Vector2(other["pos"])
		var desired := float(soldier["radius"]) + float(other["radius"]) + 7.0
		if away.length_squared() > 0.01 and away.length() < desired:
			separation += away.normalized() * (1.0 - away.length() / desired)
	for enemy in enemies:
		if _enemy_is_air(enemy):
			continue
		var enemy_away := Vector2(soldier["pos"]) - Vector2(enemy["pos"])
		var enemy_distance := enemy_away.length()
		var enemy_desired := float(soldier["radius"]) + float(enemy["radius"]) + 2.0
		if enemy_distance > 0.01 and enemy_distance < enemy_desired:
			separation += enemy_away.normalized() * (1.0 - enemy_distance / enemy_desired) * 0.85
	var player_away := Vector2(soldier["pos"]) - Vector2(player["pos"])
	var distance_from_player := player_away.length()
	var desired_from_player := float(soldier["radius"]) + PLAYER_RADIUS + 2.0
	if distance_from_player > 0.01 and distance_from_player < desired_from_player:
		separation += player_away.normalized() * (1.0 - distance_from_player / desired_from_player) * 0.7
	var speed := float(soldier["speed"]) * speed_scale * _soldier_rally_move_multiplier(soldier)
	if python_boss != null:
		speed *= float(python_boss.get_speed_multiplier("soldier", int(soldier["id"])))
	var player_distance := Vector2(soldier["pos"]).distance_to(player["pos"])
	if player_distance > 450.0: speed *= 1.35
	if soldier_command in ["跟隨", "撤退"] and player_distance > 1000.0 and _nearest_enemy_distance(soldier["pos"]) > 380.0:
		var catchup_position := Vector2(player["pos"]) + _local_formation_offset(soldier)
		if _position_hits_obstacle(catchup_position, float(soldier["radius"]), true):
			catchup_position = _find_open_spawn_position(Vector2(player["pos"]), catchup_position, float(soldier["radius"]), true)
		# If every candidate is blocked, keep normal pathfinding active instead of
		# teleporting the unit into an obstacle.
		if not _position_hits_obstacle(catchup_position, float(soldier["radius"]), true):
			soldier["pos"] = catchup_position
			soldier["vel"] = Vector2.ZERO
			_spawn_effect("spawn", soldier["pos"], FRIEND_BLUE, 0.45)
			return
	var travel_direction := _soldier_tree_avoidance_direction(soldier, offset.normalized())
	var direction := (travel_direction + separation * 1.35).limit_length(1.0)
	var old_position: Vector2 = Vector2(soldier["pos"])
	soldier["pos"] = _move_with_collision(soldier["pos"], direction * speed * delta, float(soldier["radius"]), true)
	if python_boss != null and not python_boss.is_defeated():
		soldier["pos"] = python_boss.resolve_body_collision(soldier["pos"], float(soldier["radius"]))
	if aionis_boss != null and timeless_gate_unlocked and not aionis_boss.is_defeated():
		soldier["pos"] = _resolve_aionis_body_collision(soldier["pos"], float(soldier["radius"]))
	soldier["vel"] = (Vector2(soldier["pos"]) - old_position) / maxf(delta, 0.0001)
	var barrier_result := SoldierUpgradeRuntime.record_movement(soldier, old_position.distance_to(Vector2(soldier["pos"])))
	if bool(barrier_result.get("activated", false)):
		_spawn_effect("shield", soldier["pos"], Color("7DD8FF"), 0.72)


func _damage_soldier(soldier: Dictionary, raw_damage: float, source_pos: Vector2, damage_kind: String) -> void:
	if float(soldier["invuln"]) > 0.0:
		return
	if _is_in_friendly_safe_zone(Vector2(soldier["pos"])):
		return
	var damage := raw_damage
	if float(soldier.get("dash_reduction_ttl", 0.0)) > 0.0:
		damage *= 1.0 - clampf(float(soldier.get("dash_damage_reduction", 0.0)), 0.0, 0.85)
	if soldier["type"] == "heavy" and damage_kind in ["projectile", "area"]:
		damage *= 0.72
	damage = _calculate_damage(damage, float(soldier["defense"]))
	damage *= 1.0 - _soldier_guardian_aura_reduction(soldier)
	if float(soldier.get("revive_reduction_ttl", 0.0)) > 0.0:
		damage *= 1.0 - clampf(float(soldier.get("revive_damage_reduction", 0.0)), 0.0, 0.85)
	var damage_plan := SoldierUpgradeRuntime.incoming_damage_plan(soldier, damage_kind, damage)
	damage = float(damage_plan.get("damage", damage))
	var sidestep := float(damage_plan.get("sidestep_distance", 0.0))
	if sidestep > 0.0:
		var away := (Vector2(soldier["pos"]) - source_pos).normalized()
		if away.length_squared() <= 0.001:
			away = Vector2.UP.rotated(float(int(soldier["id"]) % 8) * TAU / 8.0)
		var side := away.rotated(PI * 0.5 if int(soldier["id"]) % 2 == 0 else -PI * 0.5)
		soldier["pos"] = _move_with_collision(soldier["pos"], side * sidestep, float(soldier["radius"]), true)
	if float(damage_plan.get("invulnerability", 0.0)) > 0.0:
		soldier["invuln"] = maxf(float(soldier.get("invuln", 0.0)), float(damage_plan["invulnerability"]))
	if float(damage_plan.get("absorbed", 0.0)) > 0.0:
		_add_floater(soldier["pos"] + Vector2(0, -22), "盾 %d" % int(damage_plan["absorbed"]), Color("80D9FF"), 0.7)
		_spawn_effect("shield", soldier["pos"], Color("80D9FF"), 0.55)
	if bool(damage_plan.get("evaded", false)):
		_spawn_effect("dash", soldier["pos"], Color("B9F3FF"), 0.55)
		return
	if damage <= 0.0:
		return
	soldier["hp"] = max(0.0, float(soldier["hp"]) - damage)
	soldier["invuln"] = maxf(float(soldier.get("invuln", 0.0)), 0.10)
	if bool(damage_plan.get("last_stand_triggered", false)):
		var last_stand := _soldier_special(soldier, "last_stand")
		var recovery_duration := maxf(0.1, float(last_stand.get("recovery_duration", 3.0)))
		soldier["last_stand_recovery_ttl"] = recovery_duration
		soldier["last_stand_recovery_per_second"] = float(soldier["max_hp"]) * float(last_stand.get("recovery_max_hp_ratio", 0.12)) / recovery_duration
	soldier["flash"] = 0.12
	soldier["last_hit"] = game_time
	_add_floater(soldier["pos"] + Vector2(0, -18), "-%d" % int(damage), Color("FF9B79"), 0.75)
	if float(soldier["hp"]) <= 0.0:
		_kill_soldier(int(soldier["id"]))


func _kill_soldier(id: int) -> void:
	for i in range(soldiers.size() - 1, -1, -1):
		if int(soldiers[i]["id"]) != id: continue
		var fallen: Dictionary = soldiers[i]
		if float(fallen["soul_fatigue"]) <= 0.0:
			var tombstone_bonus := 0.0
			for priest in soldiers:
				if str(priest.get("type", "")) != "priest" or int(priest.get("id", -1)) == id:
					continue
				var shelter := _soldier_special(priest, "soul_shelter")
				tombstone_bonus = maxf(tombstone_bonus, float(shelter.get("tombstone_bonus_seconds", 0.0)))
			tombstones.append({"id": next_entity_id, "type": fallen["type"], "pos": fallen["pos"], "ttl": 18.0 + tombstone_bonus, "cost": int(GameConfig.SOLDIERS[fallen["type"]]["recruit_cost"]["gold"])})
			next_entity_id += 1
		_spawn_effect("death", fallen["pos"], Color("B6C8D6"), 0.7)
		soldiers.remove_at(i)
		return


func _best_tombstone(position: Vector2, radius: float) -> Variant:
	var best: Variant = null
	var best_score := -INF
	for tomb in tombstones:
		var dist := Vector2(tomb["pos"]).distance_to(position)
		if dist > radius: continue
		var score := float(tomb["cost"]) - dist * 0.08 + (100.0 if tomb["type"] == "cannon" else 0.0)
		if score > best_score:
			best_score = score
			best = tomb
	return best


func _revive_tombstone(tomb: Dictionary, priest_id: int = -1, hp_ratio: float = 0.45, soul_shelter: Dictionary = {}) -> void:
	if soldiers.size() >= _army_limit():
		_add_notification("軍隊已達上限，暫時無法復活士兵。", Color("F6C177"), 1.8)
		return
	_spawn_soldier(str(tomb["type"]), tomb["pos"], clampf(hp_ratio, 0.05, 1.0))
	var revived: Dictionary = soldiers.back()
	revived["soul_fatigue"] = 20.0
	if not soul_shelter.is_empty():
		revived["revive_damage_reduction"] = clampf(float(soul_shelter.get("revived_damage_reduction", 0.0)), 0.0, 0.85)
		revived["revive_reduction_ttl"] = maxf(0.0, float(soul_shelter.get("reduction_duration", 0.0)))
	_spawn_effect("revive", tomb["pos"], GOLD, 1.0)
	_add_floater(tomb["pos"] + Vector2(0, -25), "復活", GOLD, 1.2)
	if priest_id >= 0 and python_boss != null and python_boss.is_engaged():
		python_boss.add_threat("priest", priest_id, float(GameConfig.PYTHON_BOSS_CONFIG["threat"]["revive_flat"]))
	for i in range(tombstones.size() - 1, -1, -1):
		if tombstones[i]["id"] == tomb["id"]:
			tombstones.remove_at(i)
			break


# -----------------------------------------------------------------------------
# 投射物、範圍傷害、掉落與持續效果
# -----------------------------------------------------------------------------

func _spawn_projectile(data: Dictionary) -> void:
	var source_soldier: Variant = null
	if str(data.get("team", "")) == "friendly" and int(data.get("source_id", 0)) > 0:
		source_soldier = _find_soldier_by_id(int(data.get("source_id", 0)))
	if source_soldier != null and not data.has("soldier_specials"):
		var pending_context: Dictionary = Dictionary(source_soldier.get("pending_attack_context", {})).duplicate(true)
		if pending_context.is_empty():
			pending_context = SoldierUpgradeRuntime.begin_attack(source_soldier, 1.0)
		if data.has("target_id"):
			pending_context["target_id"] = int(data["target_id"])
		elif pending_context.has("target_id"):
			data["target_id"] = int(pending_context["target_id"])
		data = SoldierUpgradeRuntime.decorate_projectile(data, source_soldier, pending_context)
		var siege_warhead := _soldier_special(source_soldier, "siege_warhead")
		if not siege_warhead.is_empty():
			data["siege"] = float(data.get("siege", 1.0)) * (1.0 + float(siege_warhead.get("structure_damage_bonus", 0.0)))
	if projectiles.size() >= MAX_PROJECTILES:
		projectiles.pop_front()
	data["id"] = next_entity_id
	next_entity_id += 1
	var default_source_kind := "player" if str(data.get("team", "")) == "friendly" else "enemy"
	data["source_kind"] = str(data.get("source_kind", default_source_kind))
	data["source_id"] = int(data.get("source_id", 0 if default_source_kind == "player" else -1))
	data["traveled"] = 0.0
	data["ttl"] = float(data.get("ttl", 5.0))
	data["initial_ttl"] = float(data.get("initial_ttl", data["ttl"]))
	data["delayed_impact"] = bool(data.get("delayed_impact", false))
	data["drop_height"] = float(data.get("drop_height", 0.0))
	data["hit_ids"] = {}
	data["falloff"] = float(data.get("falloff", 1.0))
	data["siege"] = float(data.get("siege", 1.0))
	data["creates_fire"] = bool(data.get("creates_fire", false))
	data["armor_penetration"] = float(data.get("armor_penetration", 0.0))
	data["slow_factor"] = float(data.get("slow_factor", 0.0))
	data["slow_duration"] = float(data.get("slow_duration", 0.0))
	data["fire_duration"] = float(data.get("fire_duration", 5.0))
	data["fire_tick_damage"] = float(data.get("fire_tick_damage", 0.0))
	projectiles.append(data)
	if source_soldier != null and bool(data.get("allow_special_generation", false)):
		_spawn_soldier_projectile_children(source_soldier, data)


func _spawn_soldier_projectile_children(soldier: Dictionary, projectile: Dictionary) -> void:
	var split := _projectile_special(projectile, "split_shot")
	if not split.is_empty() and not bool(soldier.get("pending_split_scheduled", false)):
		soldier["pending_split_scheduled"] = true
		var extra_count := clampi(int(split.get("extra_projectiles", 0)), 0, 4)
		var spread := deg_to_rad(float(split.get("spread_degrees", 12.0)))
		var ratio := clampf(float(split.get("damage_ratio", 0.12)), 0.0, 1.0)
		for split_index in extra_count:
			var child := projectile.duplicate(true)
			var centered := float(split_index) - float(extra_count - 1) * 0.5
			child["vel"] = Vector2(projectile["vel"]).rotated(spread * (centered if extra_count > 1 else 1.0))
			child["damage"] = float(projectile["damage"]) * ratio
			child["special_generation"] = 1
			child["allow_special_generation"] = false
			child["soldier_attack_context"] = Dictionary(projectile.get("soldier_attack_context", {})).duplicate(true)
			child["soldier_attack_context"]["allow_special_generation"] = false
			_spawn_projectile(child)
	var context: Dictionary = Dictionary(projectile.get("soldier_attack_context", {}))
	if bool(context.get("echo", false)) and not bool(soldier.get("pending_echo_scheduled", false)):
		soldier["pending_echo_scheduled"] = true
		var delay := maxf(0.01, float(context.get("echo_delay", 0.35)))
		var echo_projectile := projectile.duplicate(true)
		echo_projectile["damage"] = float(projectile["damage"]) * clampf(float(context.get("echo_damage_ratio", 0.45)), 0.0, 2.0)
		echo_projectile["special_generation"] = 1
		echo_projectile["allow_special_generation"] = false
		echo_projectile["soldier_attack_context"] = context.duplicate(true)
		echo_projectile["soldier_attack_context"]["allow_special_generation"] = false
		_add_upgrade_runtime_effect({
			"kind": "temporal_echo", "source_id": int(soldier["id"]), "source_kind": str(soldier["type"]),
			"pos": Vector2(projectile["pos"]), "ttl": delay + 0.08, "warmup": delay,
			"radius": maxf(12.0, float(projectile.get("radius", 4.0)) * 2.0), "color": Color("B993FF"),
			"projectile": echo_projectile,
		})


func _update_projectiles(delta: float) -> void:
	for p_index in range(projectiles.size() - 1, -1, -1):
		if p_index >= projectiles.size(): continue
		var projectile: Dictionary = projectiles[p_index]
		_update_projectile_homing(projectile, delta)
		# Snapshot the structure lock before resolving hits. If this projectile
		# kills the final defender, that same shell still cannot spill damage into
		# the wall; a later attack begins the structure phase.
		projectile["siege_locked_castle_id"] = ""
		if projectile["team"] == "friendly" and command_castle_id != "" and castles.has(command_castle_id):
			var projectile_siege_castle: Dictionary = castles[command_castle_id]
			if _siege_structure_locked_for_projectile(projectile, projectile_siege_castle):
				projectile["siege_locked_castle_id"] = command_castle_id
		var previous_pos: Vector2 = projectile["pos"]
		var full_motion: Vector2 = Vector2(projectile["vel"]) * delta
		var full_distance: float = full_motion.length()
		var travel_fraction := 1.0
		var remaining_range: float = maxf(0.0, float(projectile["range"]) - float(projectile["traveled"]))
		if full_distance > 0.0001:
			travel_fraction = minf(travel_fraction, clampf(remaining_range / full_distance, 0.0, 1.0))
		var ttl_before: float = maxf(0.0, float(projectile["ttl"]))
		if delta > 0.0001:
			travel_fraction = minf(travel_fraction, clampf(ttl_before / delta, 0.0, 1.0))
		var candidate_end := previous_pos + full_motion * travel_fraction
		var hit_environment := false
		if projectile["kind"] not in ["cannonball", "enemy_cannonball", "enemy_stone", "fireball", "tank_shell", "enemy_tank_shell", "rocket", "enemy_rocket", "bomb"]:
			var environment_time := _segment_environment_hit_time(previous_pos, candidate_end, float(projectile["radius"]) * 0.7)
			if environment_time <= 1.0:
				travel_fraction *= environment_time
				candidate_end = previous_pos + full_motion * travel_fraction
				hit_environment = true
		var motion: Vector2 = candidate_end - previous_pos
		projectile["pos"] = candidate_end
		projectile["traveled"] = float(projectile["traveled"]) + motion.length()
		projectile["ttl"] = maxf(0.0, ttl_before - delta * travel_fraction)
		if projectile["kind"] in ["rolling_rock", "cannonball", "enemy_cannonball", "tank_shell", "enemy_tank_shell"] and randf() < delta * 15.0:
			_spawn_particle(projectile["pos"], Vector2(randf_range(-8, 8), randf_range(-12, -3)), Color("B7A994"), 0.35, 3.0, 2)
		if projectile["kind"] in ["rocket", "enemy_rocket"] and randf() < delta * 32.0:
			var rocket_direction := Vector2(projectile["vel"]).normalized()
			_spawn_particle(Vector2(projectile["pos"]) - rocket_direction * 12.0, -rocket_direction * randf_range(20.0, 65.0) + Vector2(randf_range(-9.0, 9.0), randf_range(-9.0, 9.0)), Color("C8C4B8"), randf_range(0.35, 0.65), randf_range(3.0, 6.0), 2)
		var expires_after_motion := hit_environment or travel_fraction < 0.9999 or float(projectile["ttl"]) <= 0.0 or float(projectile["traveled"]) >= float(projectile["range"]) - 0.001
		var consumed := false
		# 轟炸機炸彈在倒數結束前只顯示落點與落下高度；友軍分支也必須
		# 遵守延遲，不能在生成於目標座標的第一幀就提前結算爆炸。
		if bool(projectile.get("delayed_impact", false)) and float(projectile["ttl"]) > 0.0:
			continue
		if projectile["team"] == "friendly":
			var combat_hits: Array[Dictionary] = []
			if _active_boss_can_be_targeted() and not projectile["hit_ids"].has(BOSS_ENTITY_ID):
				var boss_hit: Dictionary = _active_boss_projectile_intersection(previous_pos, projectile["pos"], float(projectile["radius"]))
				if bool(boss_hit.get("hit", false)):
					combat_hits.append({"kind": "boss", "time": float(boss_hit.get("time", 1.0)), "position": Vector2(boss_hit["position"])})
			for enemy in enemies:
				if projectile["hit_ids"].has(enemy["id"]):
					continue
				var hit_time := _segment_circle_hit_time(previous_pos, projectile["pos"], enemy["pos"], float(enemy["radius"]) + float(projectile["radius"]))
				if hit_time <= 1.0:
					combat_hits.append({"kind": "enemy", "time": hit_time, "id": int(enemy["id"]), "position": previous_pos.lerp(Vector2(projectile["pos"]), hit_time)})
			combat_hits.sort_custom(Callable(self, "_sort_projectile_hit_time"))
			for combat_hit in combat_hits:
				if consumed:
					break
				var impact_position: Vector2 = Vector2(combat_hit["position"])
				if str(combat_hit["kind"]) == "boss":
					if projectile["hit_ids"].has(BOSS_ENTITY_ID):
						continue
					projectile["hit_ids"][BOSS_ENTITY_ID] = true
					if float(projectile["aoe"]) > 0.0:
						projectile["pos"] = impact_position
						_explode_projectile(projectile)
						consumed = true
					else:
						_trigger_soldier_projectile_impact_effects(projectile, impact_position, BOSS_ENTITY_ID)
						_apply_lingering_first_hit_damage(projectile)
						var boss_result: Dictionary = _receive_active_boss_hit(
							projectile["id"], str(projectile["source_kind"]), int(projectile["source_id"]),
							float(projectile["damage"]), impact_position, "projectile",
							float(projectile["armor_penetration"])
						)
						_consume_active_boss_hit_result(boss_result)
				else:
					var hit_enemy_id := int(combat_hit["id"])
					if projectile["hit_ids"].has(hit_enemy_id):
						continue
					var enemy_index := _enemy_index_by_id(hit_enemy_id)
					if enemy_index < 0:
						continue
					projectile["hit_ids"][hit_enemy_id] = true
					if float(projectile["aoe"]) > 0.0:
						projectile["pos"] = impact_position
						_explode_projectile(projectile)
						consumed = true
					else:
						_apply_projectile_status(enemies[enemy_index], projectile)
						_trigger_soldier_projectile_impact_effects(projectile, impact_position, hit_enemy_id)
						_apply_lingering_first_hit_damage(projectile)
						var soldier_specials: Dictionary = Dictionary(projectile.get("soldier_specials", {}))
						if soldier_specials.is_empty():
							_damage_enemy(enemy_index, float(projectile["damage"]), impact_position, "projectile", float(projectile["armor_penetration"]))
						else:
							_resolve_soldier_enemy_hit(enemy_index, float(projectile["damage"]), impact_position, "projectile", int(projectile.get("source_id", -1)), soldier_specials, float(projectile["armor_penetration"]), bool(projectile.get("allow_special_generation", false)))
				if not consumed and float(projectile["aoe"]) <= 0.0:
					projectile["damage"] = float(projectile["damage"]) * float(projectile["falloff"])
					projectile["pierce"] = int(projectile["pierce"]) - 1
					consumed = int(projectile["pierce"]) <= 0
			if not consumed:
				for castle in castles.values():
					if castle["owned"] or castle["destroyed"]: continue
					if str(projectile.get("siege_locked_castle_id", "")) == str(castle["id"]): continue
					if _segment_hits_circle(previous_pos, projectile["pos"], castle["pos"], _castle_damage_radius(castle) + float(projectile["radius"])):
						var siege_damage := float(projectile["damage"]) * float(projectile["siege"])
						if float(projectile["aoe"]) > 0.0:
							_explode_projectile(projectile)
						else:
							_damage_castle(castle, siege_damage)
						consumed = true
						break
			if not consumed:
				for camp in camps.values():
					if float(camp["crate_hp"]) <= 0.0: continue
					if _segment_hits_circle(previous_pos, projectile["pos"], camp["pos"], 47.0 + float(projectile["radius"])):
						_damage_camp_crate(camp, float(projectile["damage"]))
						consumed = true
						break
		else:
			if not bool(projectile.get("delayed_impact", false)) and player["alive"] and _segment_hits_circle(previous_pos, projectile["pos"], player["pos"], PLAYER_RADIUS + float(projectile["radius"])):
				if float(projectile["aoe"]) > 0.0: _explode_projectile(projectile)
				else: _damage_player(float(projectile["damage"]), projectile["pos"])
				consumed = true
			if not bool(projectile.get("delayed_impact", false)) and not consumed:
				for soldier in soldiers:
					if _segment_hits_circle(previous_pos, projectile["pos"], soldier["pos"], float(soldier["radius"]) + float(projectile["radius"])):
						if float(projectile["aoe"]) > 0.0: _explode_projectile(projectile)
						else: _damage_soldier(soldier, float(projectile["damage"]), projectile["pos"], "projectile")
						consumed = true
						break
			if not bool(projectile.get("delayed_impact", false)) and not consumed:
				var guardian_hit := _guardian_projectile_intersection(previous_pos, Vector2(projectile["pos"]), float(projectile["radius"]))
				if bool(guardian_hit.get("hit", false)):
					projectile["pos"] = Vector2(guardian_hit["position"])
					if float(projectile["aoe"]) > 0.0:
						_explode_projectile(projectile)
					else:
						var guardian_index := int(guardian_hit.get("effect_index", -1))
						if guardian_index >= 0 and guardian_index < upgrade_effects.size():
							_damage_guardian(upgrade_effects[guardian_index], float(projectile["damage"]), previous_pos)
					consumed = true
			if not bool(projectile.get("delayed_impact", false)) and not consumed:
				for castle in castles.values():
					if not bool(castle.get("owned", false)):
						continue
					if _segment_hits_circle(previous_pos, projectile["pos"], castle["pos"], _castle_damage_radius(castle) + float(projectile["radius"])):
						if float(projectile["aoe"]) > 0.0:
							projectile["pos"] = previous_pos.lerp(Vector2(projectile["pos"]), _segment_circle_hit_time(previous_pos, projectile["pos"], castle["pos"], _castle_damage_radius(castle) + float(projectile["radius"])))
							_explode_projectile(projectile)
						else:
							_damage_owned_castle(castle, float(projectile["damage"]))
						consumed = true
						break
		if not consumed and expires_after_motion:
			if float(projectile["aoe"]) > 0.0:
				_explode_projectile(projectile)
			consumed = true
		if consumed and p_index < projectiles.size():
			projectiles.remove_at(p_index)


func _update_projectile_homing(projectile: Dictionary, delta: float) -> void:
	if not bool(projectile.get("homing", false)) or Vector2(projectile.get("vel", Vector2.ZERO)).length_squared() <= 0.001:
		return
	var target_id := int(projectile.get("target_id", -1))
	var target_position: Variant = null
	if target_id == BOSS_ENTITY_ID and _active_boss_can_be_targeted():
		target_position = _active_boss_position()
	else:
		var target: Variant = _find_enemy_by_id(target_id)
		if target != null:
			target_position = Vector2(target["pos"])
	if target_position == null:
		target_id = _enemy_near_point(Vector2(projectile["pos"]), 620.0)
		projectile["target_id"] = target_id
		if target_id == BOSS_ENTITY_ID:
			target_position = _active_boss_position()
		else:
			var replacement: Variant = _find_enemy_by_id(target_id)
			if replacement != null:
				target_position = Vector2(replacement["pos"])
	if target_position == null:
		return
	var velocity := Vector2(projectile["vel"])
	var desired := (Vector2(target_position) - Vector2(projectile["pos"])).normalized()
	if desired.length_squared() <= 0.001:
		return
	var max_turn := deg_to_rad(maxf(0.0, float(projectile.get("homing_turn_degrees_per_second", 0.0)))) * delta
	var angle_delta := clampf(velocity.normalized().angle_to(desired), -max_turn, max_turn)
	projectile["vel"] = velocity.normalized().rotated(angle_delta) * velocity.length()


func _trigger_soldier_projectile_impact_effects(projectile: Dictionary, position: Vector2, target_id: int = -1) -> void:
	if not bool(projectile.get("allow_special_generation", false)) or bool(projectile.get("upgrade_impact_triggered", false)):
		return
	projectile["upgrade_impact_triggered"] = true
	var lingering := _projectile_special(projectile, "lingering_projectile")
	if not lingering.is_empty():
		var duration := maxf(0.2, float(lingering.get("linger_duration", 2.0)))
		var base_damage := float(projectile.get("upgrade_base_damage", projectile.get("damage", 0.0)))
		projectile["lingering_first_hit_ratio"] = clampf(float(lingering.get("first_hit_ratio", 0.70)), 0.0, 1.0)
		_add_upgrade_runtime_effect({
			"kind": "lingering", "source_id": int(projectile.get("source_id", -1)), "source_kind": str(projectile.get("source_kind", "soldier")),
			"pos": position, "target_id": target_id, "ttl": duration, "warmup": 0.0,
			"radius": maxf(22.0, float(projectile.get("radius", 4.0)) * 3.0), "color": Color(projectile.get("color", Color("C4E7FF"))),
			"damage": base_damage * float(lingering.get("tick_damage_ratio", 0.12)),
			"armor_penetration": maxf(0.0, float(projectile.get("armor_penetration", 0.0))),
			"tick_interval": maxf(0.1, float(lingering.get("tick_interval", 0.5))), "tick": 0.0,
			"max_per_owner": int(lingering.get("max_per_unit", 2)), "team_cap": int(lingering.get("team_cap", MAX_UPGRADE_LINGERING_PER_TEAM)),
		})


func _apply_lingering_first_hit_damage(projectile: Dictionary) -> void:
	if bool(projectile.get("lingering_first_hit_applied", false)) or not projectile.has("lingering_first_hit_ratio"):
		return
	projectile["damage"] = float(projectile.get("damage", 0.0)) * clampf(float(projectile.get("lingering_first_hit_ratio", 1.0)), 0.0, 1.0)
	projectile["lingering_first_hit_applied"] = true


func _prepare_soldier_explosion_payload(projectile: Dictionary) -> void:
	if bool(projectile.get("upgrade_payload_prepared", false)):
		return
	projectile["upgrade_payload_prepared"] = true
	var position := Vector2(projectile["pos"])
	var base_damage := float(projectile.get("damage", 0.0))
	var base_radius := maxf(1.0, float(projectile.get("aoe", 0.0)))
	projectile["upgrade_base_damage"] = base_damage
	projectile["upgrade_base_radius"] = base_radius
	_trigger_soldier_projectile_impact_effects(projectile, position)
	var mine := _projectile_special(projectile, "mine_round")
	if not mine.is_empty() and bool(projectile.get("allow_special_generation", false)):
		projectile["damage"] = base_damage * float(mine.get("impact_damage_ratio", 0.3))
		projectile["aoe"] = minf(base_radius, 48.0)
		_add_upgrade_runtime_effect({
			"kind": "mine", "source_id": int(projectile.get("source_id", -1)), "source_kind": str(projectile.get("source_kind", "soldier")),
			"pos": position, "ttl": float(mine.get("mine_ttl", 7.0)), "warmup": float(mine.get("arming_time", 0.7)),
			"radius": float(mine.get("trigger_radius", 78.0)), "damage": base_damage * float(mine.get("trigger_damage_ratio", 1.2)),
			"color": Color("F2B84B"), "scan": 0.0, "max_per_owner": int(mine.get("max_per_unit", 2)),
			"team_cap": int(mine.get("team_cap", MAX_UPGRADE_MINES_PER_TEAM)),
		})
	var cluster := _projectile_special(projectile, "cluster_warhead")
	if not cluster.is_empty() and bool(projectile.get("allow_special_generation", false)):
		projectile["damage"] = float(projectile["damage"]) * float(cluster.get("main_damage_ratio", 0.7))
		var bomblets := clampi(int(cluster.get("bomblets", 3)), 0, 8)
		for bomblet_index in bomblets:
			var offset := Vector2.from_angle(TAU * float(bomblet_index) / maxf(1.0, float(bomblets)) + float(int(projectile.get("id", 0)) % 7) * 0.17) * (base_radius * 0.52 + 26.0)
			_add_upgrade_runtime_effect({
				"kind": "bomblet", "source_id": int(projectile.get("source_id", -1)), "source_kind": str(projectile.get("source_kind", "soldier")),
				"pos": position + offset, "ttl": 0.28 + float(bomblet_index % 3) * 0.08, "warmup": 0.20 + float(bomblet_index % 3) * 0.08,
				"radius": maxf(42.0, base_radius * 0.46), "damage": base_damage * float(cluster.get("bomblet_damage_ratio", 0.25)),
				"color": FIRE_ORANGE,
			})
	_apply_lingering_first_hit_damage(projectile)


func _trigger_soldier_explosion_followups(projectile: Dictionary, position: Vector2, radius: float) -> void:
	if not bool(projectile.get("allow_special_generation", false)) or bool(projectile.get("upgrade_followups_triggered", false)):
		return
	projectile["upgrade_followups_triggered"] = true
	var base_damage := float(projectile.get("upgrade_base_damage", projectile.get("damage", 0.0)))
	var base_radius := float(projectile.get("upgrade_base_radius", radius))
	var source_id := int(projectile.get("source_id", -1))
	var source_kind := str(projectile.get("source_kind", "soldier"))
	var chain := _projectile_special(projectile, "chain_explosion")
	if not chain.is_empty():
		var ratios: Array = Array(chain.get("blast_damage_ratios", []))
		for blast_index in mini(int(chain.get("extra_blasts", ratios.size())), ratios.size()):
			var blast_offset := Vector2.from_angle(float(blast_index) * 2.39996 + float(source_id % 11) * 0.13) * minf(base_radius * 0.55, 70.0)
			_add_upgrade_runtime_effect({
				"kind": "chain_blast", "source_id": source_id, "source_kind": source_kind, "pos": position + blast_offset,
				"ttl": 0.20 + float(blast_index) * 0.16, "warmup": 0.14 + float(blast_index) * 0.16,
				"radius": maxf(44.0, base_radius * (0.78 - float(blast_index) * 0.06)), "damage": base_damage * float(ratios[blast_index]),
				"color": Color("FF8B5A"),
			})
	var burning_zone := _projectile_special(projectile, "burning_zone")
	if not burning_zone.is_empty():
		_add_upgrade_runtime_effect({
			"kind": "burning_zone", "source_id": source_id, "source_kind": source_kind, "pos": position,
			"ttl": float(burning_zone.get("zone_ttl", 3.0)), "warmup": 0.0, "radius": maxf(54.0, base_radius * 0.82),
			"damage": base_damage * float(burning_zone.get("tick_damage_ratio", 0.08)),
			"tick_interval": float(burning_zone.get("tick_interval", 0.5)), "tick": 0.0, "color": FIRE_ORANGE,
		})
	var gravity := _projectile_special(projectile, "gravity_warhead")
	if not gravity.is_empty():
		var gravity_duration := maxf(0.1, float(gravity.get("duration", 2.5)))
		_add_upgrade_runtime_effect({
			"kind": "gravity", "source_id": source_id, "source_kind": source_kind, "pos": position,
			"ttl": gravity_duration, "warmup": 0.0, "radius": float(gravity.get("radius", 130.0)),
			"pull_distance": float(gravity.get("pull_distance", 70.0)), "slow_ratio": float(gravity.get("slow_ratio", 0.15)),
			"pull_duration": gravity_duration, "pull_elapsed": 0.0, "color": Color("9C7CFF"),
		})
	var shockwave := _projectile_special(projectile, "shockwave_round")
	if not shockwave.is_empty():
		var shock_ids: Array[int] = []
		for enemy in enemies:
			if not _enemy_is_air(enemy) and Vector2(enemy["pos"]).distance_to(position) <= radius + float(enemy["radius"]):
				shock_ids.append(int(enemy["id"]))
		for shock_id in shock_ids:
			var shock_index := _enemy_index_by_id(shock_id)
			if shock_index < 0:
				continue
			var away := (Vector2(enemies[shock_index]["pos"]) - position).normalized()
			enemies[shock_index]["pos"] = _move_with_collision(enemies[shock_index]["pos"], away * float(shockwave.get("knockback", 60.0)), float(enemies[shock_index]["radius"]))
			enemies[shock_index]["slow"] = maxf(float(enemies[shock_index].get("slow", 0.0)), float(shockwave.get("slow_duration", 1.5)))
			enemies[shock_index]["slow_factor"] = maxf(float(enemies[shock_index].get("slow_factor", 0.0)), float(shockwave.get("slow_ratio", 0.22)))
			enemies[shock_index]["enhancement_stun"] = maxf(float(enemies[shock_index].get("enhancement_stun", 0.0)), float(shockwave.get("normal_stun", 0.0)))
	var shrapnel := _projectile_special(projectile, "shrapnel_storm")
	if not shrapnel.is_empty():
		var nearby_ids: Array[int] = []
		for enemy in enemies:
			if Vector2(enemy["pos"]).distance_to(position) <= base_radius + 190.0:
				nearby_ids.append(int(enemy["id"]))
		nearby_ids.sort()
		var hit_counts: Dictionary = {}
		for shard_index in clampi(int(shrapnel.get("shards", 6)), 0, 12):
			if nearby_ids.is_empty():
				break
			var shard_target := nearby_ids[shard_index % nearby_ids.size()]
			if int(hit_counts.get(shard_target, 0)) >= int(shrapnel.get("same_target_hit_cap", 2)):
				continue
			hit_counts[shard_target] = int(hit_counts.get(shard_target, 0)) + 1
			var shard_enemy_index := _enemy_index_by_id(shard_target)
			if shard_enemy_index >= 0:
				_damage_enemy(shard_enemy_index, base_damage * float(shrapnel.get("shard_damage_ratio", 0.15)), position, "projectile", 0.0, source_id)


func _explode_projectile(projectile: Dictionary) -> void:
	var position: Vector2 = projectile["pos"]
	var radius := float(projectile["aoe"])
	if str(projectile.get("team", "")) == "friendly" and not Dictionary(projectile.get("soldier_specials", {})).is_empty():
		_prepare_soldier_explosion_payload(projectile)
		radius = float(projectile["aoe"])
	var siege_locked_castle_id := str(projectile.get("siege_locked_castle_id", ""))
	if not projectile.has("siege_locked_castle_id") and projectile["team"] == "friendly" and command_castle_id != "" and castles.has(command_castle_id):
		var immediate_siege_castle: Dictionary = castles[command_castle_id]
		if _siege_structure_locked_for_projectile(projectile, immediate_siege_castle):
			siege_locked_castle_id = command_castle_id
	if projectile["team"] == "friendly":
		if _active_boss_can_be_targeted():
			var boss_hit: Dictionary = _active_boss_projectile_intersection(position, position, radius)
			if bool(boss_hit.get("hit", false)):
				var boss_result: Dictionary = _receive_active_boss_hit(
					projectile["id"], str(projectile.get("source_kind", "player")), int(projectile.get("source_id", 0)),
					float(projectile["damage"]), Vector2(boss_hit["position"]), "area",
					float(projectile.get("armor_penetration", 0.0))
				)
				_consume_active_boss_hit_result(boss_result)
		for i in range(enemies.size() - 1, -1, -1):
			var distance := Vector2(enemies[i]["pos"]).distance_to(position)
			if distance <= radius + float(enemies[i]["radius"]):
				var falloff: float = lerp(1.0, 0.68, clamp(distance / max(radius, 1.0), 0.0, 1.0))
				_apply_projectile_status(enemies[i], projectile)
				var soldier_specials: Dictionary = Dictionary(projectile.get("soldier_specials", {}))
				if soldier_specials.is_empty():
					_damage_enemy(i, float(projectile["damage"]) * falloff, position, "area", float(projectile["armor_penetration"]))
				else:
					_resolve_soldier_enemy_hit(i, float(projectile["damage"]) * falloff, position, "area", int(projectile.get("source_id", -1)), soldier_specials, float(projectile["armor_penetration"]))
		_trigger_soldier_explosion_followups(projectile, position, radius)
		for castle in castles.values():
			if str(castle["id"]) == siege_locked_castle_id:
				continue
			if not castle["owned"] and not castle["destroyed"] and Vector2(castle["pos"]).distance_to(position) <= radius + _castle_damage_radius(castle):
				_damage_castle(castle, float(projectile["damage"]) * float(projectile["siege"]))
		if projectile["creates_fire"]:
			var fire_damage := float(projectile["fire_tick_damage"])
			if fire_damage <= 0.0: fire_damage = _player_damage(0.16)
			hazards.append({
				"id": _allocate_attack_id("fire_hazard"), "kind": "fire", "pos": position,
				"radius": 128.0, "ttl": float(projectile["fire_duration"]), "tick": 0.0,
				"tick_seq": 0, "damage": fire_damage,
				"source_kind": str(projectile.get("source_kind", "player")),
				"source_id": int(projectile.get("source_id", 0)),
			})
	else:
		_enemy_area_attack(position, radius, float(projectile["damage"]))
	_spawn_effect("explosion", position, FIRE_ORANGE if projectile["kind"] in ["fireball", "cannonball", "enemy_cannonball", "enemy_stone", "tank_shell", "enemy_tank_shell", "rocket", "enemy_rocket", "bomb"] else MAGIC_PURPLE, clamp(radius / 105.0, 0.55, 1.55))
	for _i in range(9):
		_spawn_particle(position, Vector2.from_angle(randf_range(-PI, PI)) * randf_range(55.0, 155.0), FIRE_ORANGE, randf_range(0.25, 0.58), randf_range(2.0, 5.0), 1)
	if str(projectile["kind"]) == "bomb":
		audio.play("bomb", min(0.95, 0.5 + radius / 260.0), randf_range(0.92, 1.02))
	else:
		audio.play("explosion", min(0.9, 0.4 + radius / 260.0), randf_range(0.94, 1.04))
	camera_shake = max(camera_shake, min(0.75, radius / 230.0))


func _apply_projectile_status(enemy: Dictionary, projectile: Dictionary) -> void:
	if float(projectile.get("slow_duration", 0.0)) > 0.0:
		enemy["slow"] = max(float(enemy.get("slow", 0.0)), float(projectile["slow_duration"]))
		enemy["slow_factor"] = max(float(enemy.get("slow_factor", 0.0)), float(projectile.get("slow_factor", 0.0)))


func _update_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		if str(hazard.get("kind", "fire")) == "ufo_beam":
			hazard["ttl"] = float(hazard.get("ttl", 0.0)) - delta
			hazard["warmup"] = max(0.0, float(hazard.get("warmup", 0.0)) - delta)
			if float(hazard["warmup"]) <= 0.0:
				hazard["tick"] = float(hazard.get("tick", 0.0)) - delta
				if float(hazard["tick"]) <= 0.0:
					hazard["tick"] = 0.35
					hazard["tick_seq"] = int(hazard.get("tick_seq", 0)) + 1
					var beam_position: Vector2 = hazard["pos"]
					var beam_radius := float(hazard["radius"])
					if str(hazard.get("team", "enemy")) == "friendly":
						for enemy_index in range(enemies.size() - 1, -1, -1):
							if Vector2(enemies[enemy_index]["pos"]).distance_to(beam_position) <= beam_radius + float(enemies[enemy_index]["radius"]):
								var beam_specials: Dictionary = Dictionary(hazard.get("soldier_specials", {}))
								if beam_specials.is_empty():
									_damage_enemy(enemy_index, float(hazard["damage"]), beam_position, "beam", 10.0)
								else:
									var armor_core := _special_from_map(beam_specials, "armor_piercing_core")
									_resolve_soldier_enemy_hit(enemy_index, float(hazard["damage"]), beam_position, "beam", int(hazard.get("source_id", -1)), beam_specials, 10.0 + float(armor_core.get("ignored_armor", 0.0)), true)
						if _active_boss_can_be_targeted():
							var boss_hit := _active_boss_projectile_intersection(beam_position, beam_position, beam_radius)
							if bool(boss_hit.get("hit", false)):
								var beam_hit_id := "%s:%d" % [str(hazard.get("id", "ufo")), int(hazard["tick_seq"])]
								_consume_active_boss_hit_result(_receive_active_boss_hit(beam_hit_id, "ufo", int(hazard.get("source_id", 0)), float(hazard["damage"]), Vector2(boss_hit["position"]), "beam", 10.0))
						for beam_castle in castles.values():
							if not bool(beam_castle.get("owned", false)) and not bool(beam_castle.get("destroyed", false)) and Vector2(beam_castle["pos"]).distance_to(beam_position) <= beam_radius + _castle_damage_radius(beam_castle):
								_damage_castle(beam_castle, float(hazard["damage"]) * 0.8)
					else:
						if player["alive"] and Vector2(player["pos"]).distance_to(beam_position) <= beam_radius + PLAYER_RADIUS:
							var player_beam_damage := minf(float(hazard["damage"]), float(player["max_hp"]) * 0.14)
							_damage_player(player_beam_damage, beam_position, false)
						for beam_soldier in soldiers:
							if Vector2(beam_soldier["pos"]).distance_to(beam_position) <= beam_radius + float(beam_soldier["radius"]):
								var soldier_beam_damage := minf(float(hazard["damage"]), float(beam_soldier["max_hp"]) * 0.18)
								_damage_soldier(beam_soldier, soldier_beam_damage, beam_position, "beam")
						_damage_guardians_in_area(beam_position, beam_radius, float(hazard["damage"]))
						for beam_castle in castles.values():
							if bool(beam_castle.get("owned", false)) and Vector2(beam_castle["pos"]).distance_to(beam_position) <= beam_radius + _castle_damage_radius(beam_castle):
								_damage_owned_castle(beam_castle, float(hazard["damage"]))
				if randf() < delta * 26.0:
					var beam_particle_position := Vector2(hazard["pos"]) + Vector2.from_angle(randf_range(-PI, PI)) * randf_range(0.0, float(hazard["radius"]))
					_spawn_particle(beam_particle_position, Vector2(randf_range(-5.0, 5.0), randf_range(-85.0, -35.0)), Color("79FFF0"), 0.42, randf_range(2.0, 5.0), 1)
			if float(hazard["ttl"]) <= 0.0:
				hazards.remove_at(i)
			continue
		if not hazard.has("id"):
			hazard["id"] = _allocate_attack_id("hazard")
			hazard["tick_seq"] = 0
			hazard["source_kind"] = "player"
			hazard["source_id"] = 0
		hazard["ttl"] = float(hazard["ttl"]) - delta
		hazard["tick"] = float(hazard["tick"]) - delta
		if float(hazard["tick"]) <= 0.0:
			hazard["tick"] = 0.5
			hazard["tick_seq"] = int(hazard.get("tick_seq", 0)) + 1
			for enemy_index in range(enemies.size() - 1, -1, -1):
				if _enemy_is_air(enemies[enemy_index]):
					continue
				if Vector2(enemies[enemy_index]["pos"]).distance_to(hazard["pos"]) <= float(hazard["radius"]):
					_damage_enemy(enemy_index, float(hazard["damage"]), hazard["pos"], "fire")
			if _active_boss_can_be_targeted():
				var boss_hit: Dictionary = _active_boss_projectile_intersection(hazard["pos"], hazard["pos"], float(hazard["radius"]))
				if bool(boss_hit.get("hit", false)):
					var tick_attack_id := "%s:%d" % [str(hazard["id"]), int(hazard["tick_seq"])]
					var boss_result: Dictionary = _receive_active_boss_hit(
						tick_attack_id, str(hazard.get("source_kind", "player")), int(hazard.get("source_id", 0)),
						float(hazard["damage"]), Vector2(boss_hit["position"]), "area", 0.0
					)
					_consume_active_boss_hit_result(boss_result)
		if randf() < delta * 16.0:
			var angle := randf_range(-PI, PI)
			var pos := Vector2(hazard["pos"]) + Vector2.from_angle(angle) * randf_range(0.0, float(hazard["radius"]))
			_spawn_particle(pos, Vector2(randf_range(-8, 8), randf_range(-38, -18)), FIRE_ORANGE, 0.45, 4.0, 3)
		if float(hazard["ttl"]) <= 0.0:
			hazards.remove_at(i)


func _damage_enemy(index: int, raw_damage: float, source_pos: Vector2, damage_kind: String, armor_penetration: float = 0.0, soldier_source_id: int = -1) -> float:
	if index < 0 or index >= enemies.size():
		return 0.0
	var enemy: Dictionary = enemies[index]
	var damage := raw_damage
	if float(enemy.get("enhancement_reactive_reduction", 0.0)) > 0.0 and float(enemy.get("enhancement_reactive_timer", 0.0)) <= 0.0 and damage_kind in ["projectile", "area", "beam"]:
		damage *= 1.0 - clampf(float(enemy["enhancement_reactive_reduction"]), 0.0, 0.75)
		enemy["enhancement_reactive_timer"] = maxf(1.0, float(enemy.get("enhancement_reactive_cooldown", 8.0)))
		_spawn_effect("shield", enemy["pos"], Color("80C9FF"), 0.8)
	if enemy["type"] == "heavy" and damage_kind == "projectile": damage *= 0.75
	var effective_defense := float(enemy["defense"])
	if float(enemy.get("buff_timer", 0.0)) > 0.0:
		var shaman_buff: Dictionary = GameConfig.ENEMIES["shaman"]["combat"]["buff"]
		effective_defense *= 1.0 + float(shaman_buff["armor"])
	if float(enemy.get("armor_break", 0.0)) > 0.0:
		effective_defense -= float(enemy.get("armor_reduction", 0.0))
	effective_defense = max(0.0, effective_defense - armor_penetration)
	damage = _calculate_damage(damage, effective_defense)
	if soldier_source_id >= 0:
		enemy["last_soldier_source_id"] = soldier_source_id
		var source_soldier: Variant = _find_soldier_by_id(soldier_source_id)
		if source_soldier != null:
			var salvage := _soldier_special(source_soldier, "salvage_protocol")
			enemy["last_soldier_salvage_bonus"] = float(salvage.get("bonus_gold_ratio", 0.0)) if not salvage.is_empty() else 0.0
	enemy["hp"] = max(0.0, float(enemy["hp"]) - damage)
	enemy["flash"] = 0.11
	enemy["last_hit"] = game_time
	_add_floater(enemy["pos"] + Vector2(0, -20), "%d" % int(damage), Color("FFF0DA"), 0.82)
	_spawn_effect("hit", enemy["pos"], Color("FFF0DA"), clamp(damage / 34.0, 0.45, 1.2))
	if float(enemy["hp"]) <= 0.0:
		_kill_enemy(index)
	return damage


func _kill_enemy(index: int) -> void:
	if index < 0 or index >= enemies.size(): return
	var enemy: Dictionary = enemies[index]
	var pos: Vector2 = enemy["pos"]
	var base_gold := int(enemy["reward_gold"])
	var salvage_bonus := maxi(0, int(round(float(base_gold) * clampf(float(enemy.get("last_soldier_salvage_bonus", 0.0)), 0.0, 1.0))))
	drops.append({"kind": "loot", "pos": pos, "gold": base_gold + salvage_bonus, "xp": int(enemy["reward_xp"]), "ttl": 24.0})
	if salvage_bonus > 0:
		_add_floater(pos + Vector2(0, -34), "+$%d" % salvage_bonus, GOLD, 0.9)
	player["kills"] = int(player["kills"]) + 1
	_spawn_effect("death", pos, ENEMY_RED, 0.8 if enemy["type"] != "chief" else 1.4)
	if enemy["type"] == "chief":
		camera_shake = max(camera_shake, 0.75)
		_add_notification("蠻族首領已被擊敗！", GOLD, 2.8)
	enemies.remove_at(index)


func _update_drops(delta: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var drop: Dictionary = drops[i]
		drop["ttl"] = float(drop["ttl"]) - delta
		var distance := Vector2(drop["pos"]).distance_to(player["pos"])
		if distance < 150.0 and distance > 2.0:
			drop["pos"] = Vector2(drop["pos"]) + (Vector2(player["pos"]) - Vector2(drop["pos"])).normalized() * (260.0 - distance) * delta
		if distance < 30.0:
			player["money"] = int(player["money"]) + int(drop["gold"])
			_gain_xp(int(drop["xp"]))
			_add_floater(player["pos"] + Vector2(0, -32), "+%d 金  +%d XP" % [int(drop["gold"]), int(drop["xp"])], GOLD, 1.0)
			audio.play("coin", 0.35, randf_range(0.96, 1.04))
			drops.remove_at(i)
		elif float(drop["ttl"]) <= 0.0:
			drops.remove_at(i)


# -----------------------------------------------------------------------------
# 城堡、營地、佔領與收入
# -----------------------------------------------------------------------------

func _update_castles_and_camps(delta: float) -> void:
	nation_tick_timer -= delta
	if nation_tick_timer <= 0.0:
		nation_tick_timer = NATION_TICK_INTERVAL
		_update_nation_wars(NATION_TICK_INTERVAL)
	for castle in castles.values():
		var castle_is_active := _is_position_active(castle["pos"])
		castle["under_attack"] = max(0.0, float(castle["under_attack"]) - delta)
		if castle_is_active:
			castle["tower_cd"] = max(0.0, float(castle["tower_cd"]) - delta)
			castle["spawn_timer"] = float(castle["spawn_timer"]) - delta
		if castle["owned"]:
			castle["income_timer"] = float(castle["income_timer"]) - delta
			if float(castle["income_timer"]) <= 0.0:
				castle["income_timer"] = float(GameConfig.CASTLE_SETTINGS["income_interval"])
				var income := maxi(1, int(floor(float(castle["level"]) / float(GameConfig.CASTLE_SETTINGS["income_divisor"]))))
				player["money"] = int(player["money"]) + income
				_add_notification("城堡收入 +%d 金幣" % income, GOLD, 2.0)
				audio.play("coin", 0.5)
			castle["hp"] = min(float(castle["max_hp"]), float(castle["hp"]) + float(GameConfig.CASTLE_SETTINGS["repair_per_second"]) * delta)
			if float(castle.get("wall_max_hp", 0.0)) > 0.0:
				castle["wall_hp"] = min(float(castle["wall_max_hp"]), float(castle.get("wall_hp", 0.0)) + float(GameConfig.CASTLE_SETTINGS["repair_per_second"]) * 1.6 * delta)
				castle["wall_breached"] = float(castle["wall_hp"]) <= 0.0
			if castle_is_active:
				for ally in soldiers:
					if Vector2(ally["pos"]).distance_to(castle["pos"]) <= 215.0:
						ally["hp"] = min(float(ally["max_hp"]), float(ally["hp"]) + float(ally["max_hp"]) * 0.018 * delta)
				var attackers := _enemies_near(castle["pos"], 185.0)
				if attackers > 0:
					var siege_pressure := float(attackers) * 4.0 * delta
					if float(castle.get("wall_hp", 0.0)) > 0.0:
						castle["wall_hp"] = max(0.0, float(castle["wall_hp"]) - siege_pressure)
						castle["wall_breached"] = float(castle["wall_hp"]) <= 0.0
					else:
						castle["hp"] = float(castle["hp"]) - siege_pressure
					if float(castle["under_attack"]) <= 0.0:
						castle["under_attack"] = 7.0
						_add_notification("警告：友方城堡正在遭受攻擊！", Color("FF857A"), 3.0)
						audio.play("warning", 0.65)
			if float(castle["hp"]) <= 0.0:
				_lose_castle(castle)
		else:
			if not castle_is_active:
				continue
			if castle["destroyed"]:
				_update_castle_capture(castle, delta)
			else:
				if float(castle["spawn_timer"]) <= 0.0 and _enemies_with_guard(str(castle["id"])) < 5:
					castle["spawn_timer"] = 24.0
					_spawn_castle_guard_wave(castle, false)
				if float(castle["tower_cd"]) <= 0.0:
					_castle_tower_attack(castle)
	for camp in camps.values():
		if not _is_position_active(camp["pos"]):
			continue
		if not camp["cleared"] and bool(camp["spawned"]) and _enemies_with_camp(str(camp["id"])) == 0:
			_clear_camp(camp)
		elif camp["cleared"] and float(camp["respawn_at"]) > 0.0 and game_time >= float(camp["respawn_at"]) and Vector2(player["pos"]).distance_to(camp["pos"]) > 1050.0:
			camp["cleared"] = false
			camp["crate_hp"] = float(GameConfig.CAMP_SETTINGS["crate_hp"])
			camp["respawn_at"] = 0.0
			_spawn_camp_guards(camp)


func _update_nation_wars(delta: float) -> void:
	var active_castles: Array[Dictionary] = []
	for castle_value in castles.values():
		var castle: Dictionary = castle_value
		if _is_position_active(Vector2(castle.get("pos", Vector2.ZERO))):
			active_castles.append(castle)
	for index in active_castles.size():
		var source := active_castles[index]
		var source_nation: Dictionary = Dictionary(source.get("nation", {}))
		if not NationCatalog.is_valid_metadata(source_nation):
			continue
		for other_index in range(index + 1, active_castles.size()):
			var target := active_castles[other_index]
			var target_nation: Dictionary = Dictionary(target.get("nation", {}))
			if not NationCatalog.is_valid_metadata(target_nation):
				continue
			var distance := Vector2(source["pos"]).distance_to(target["pos"])
			if not NationCatalog.are_hostile(source_nation, target_nation):
				if distance <= NATION_SUPPORT_RADIUS:
					_reinforce_nation_castle(source, target, delta)
					_reinforce_nation_castle(target, source, delta)
				continue
			if distance <= NATION_WAR_RADIUS and not bool(source.get("owned", false)) and not bool(target.get("owned", false)):
				var source_power := float(source.get("level", 1)) * (0.8 + float(source.get("hp", 0.0)) / maxf(1.0, float(source.get("max_hp", 1.0))))
				var target_power := float(target.get("level", 1)) * (0.8 + float(target.get("hp", 0.0)) / maxf(1.0, float(target.get("max_hp", 1.0))))
				if source_power >= target_power:
					_apply_nation_siege(source, target, delta)
				else:
					_apply_nation_siege(target, source, delta)


func _reinforce_nation_castle(source: Dictionary, target: Dictionary, delta: float) -> void:
	if bool(source.get("destroyed", false)) or bool(target.get("destroyed", false)):
		return
	var support := maxf(1.0, float(source.get("level", 1)) * 0.45) * delta
	target["hp"] = minf(float(target.get("max_hp", 1.0)), float(target.get("hp", 0.0)) + support)


func _apply_nation_siege(attacker: Dictionary, defender: Dictionary, delta: float) -> void:
	if bool(defender.get("destroyed", false)):
		defender["nation"] = NationCatalog.conquest_metadata(attacker.get("nation", {}))
		defender["destroyed"] = false
		defender["hp"] = float(defender.get("max_hp", 1.0)) * 0.30
		defender["wall_hp"] = float(defender.get("wall_max_hp", 0.0)) * 0.20
		defender["wall_breached"] = float(defender.get("wall_hp", 0.0)) <= 0.0
		return
	var pressure := maxf(1.0, float(attacker.get("level", 1)) * 0.34) * delta
	if float(defender.get("wall_hp", 0.0)) > 0.0:
		defender["wall_hp"] = maxf(0.0, float(defender["wall_hp"]) - pressure)
		defender["wall_breached"] = float(defender["wall_hp"]) <= 0.0
	else:
		defender["hp"] = maxf(0.0, float(defender.get("hp", 0.0)) - pressure)
		if float(defender["hp"]) <= 0.0:
			defender["destroyed"] = true


func _spawn_castle_guard_wave(castle: Dictionary, initial: bool) -> void:
	if castle["owned"] or castle["destroyed"]: return
	var tier_cfg: Dictionary = GameConfig.castle_tier(int(castle["level"]))
	var types: Array = Array(tier_cfg.get("guards", ["grunt", "archer", "heavy", "shaman"]))
	var count := 0
	if tier_cfg.is_empty():
		count = mini(16, 7 + int(castle["level"]) / 2) if initial else mini(8, 3 + int(castle["level"]) / 3)
	else:
		count = int(tier_cfg["initial_garrison"] if initial else tier_cfg["reinforcement"])
	count = mini(count, int(GameConfig.CASTLE_SETTINGS["garrison_capacity"]))
	for i in count:
		if enemies.size() >= MAX_ENEMIES: break
		var type_id: String = str(types[i % types.size()])
		if initial and i == count - 1: type_id = "chief"
		var angle := TAU * float(i) / float(max(1, count))
		var preferred_pos := Vector2(castle["pos"]) + Vector2.from_angle(angle) * randf_range(190.0, 275.0)
		var pos := _find_open_spawn_position(castle["pos"], preferred_pos, 23.0)
		_spawn_enemy(type_id, pos, int(castle["level"]) + 1, castle["pos"], str(castle["id"]))


func _spawn_camp_guards(camp: Dictionary) -> void:
	if camp["cleared"]: return
	var types := ["grunt", "grunt", "archer", "thrower", "berserker"]
	var count := mini(15, 4 + int(camp["level"]))
	var spawned_count := 0
	for i in count:
		if enemies.size() >= MAX_ENEMIES: break
		var type_id: String = str(types[i % types.size()])
		if int(camp["level"]) >= 3 and i == count - 1: type_id = "chief"
		var preferred_pos := Vector2(camp["pos"]) + Vector2.from_angle(TAU * float(i) / float(count)) * randf_range(125.0, 210.0)
		var pos := _find_open_spawn_position(camp["pos"], preferred_pos, 23.0)
		if _spawn_enemy(type_id, pos, int(camp["level"]), camp["pos"], "", str(camp["id"])) >= 0:
			spawned_count += 1
	camp["spawned"] = spawned_count > 0


func _damage_castle(castle: Dictionary, raw_damage: float) -> void:
	if castle["owned"] or castle["destroyed"]: return
	var damage: float = max(1.0, raw_damage * 0.62)
	if float(castle.get("wall_max_hp", 0.0)) > 0.0 and not bool(castle.get("wall_breached", false)):
		castle["wall_hp"] = max(0.0, float(castle.get("wall_hp", 0.0)) - damage)
		_add_floater(Vector2(castle["pos"]) + Vector2(randf_range(-85, 85), -205), "城牆 -%d" % int(damage), Color("FFD08A"), 0.9)
		_spawn_effect("hit", Vector2(castle["pos"]) + Vector2(randf_range(-185, 185), randf_range(-145, 145)), Color("C7BCA7"), 1.0)
		if float(castle["wall_hp"]) <= 0.0:
			castle["wall_breached"] = true
			castle["wall_hp"] = 0.0
			_add_notification("%d 級城堡外牆已突破！現在可以攻擊主城。" % int(castle["level"]), Color("FFD166"), 4.0)
			_spawn_effect("explosion", castle["pos"] + Vector2(0, 165), Color("C89D68"), 1.7)
			for rubble_index in 18:
				_spawn_particle(Vector2(castle["pos"]) + Vector2(randf_range(-95, 95), randf_range(125, 185)), Vector2(randf_range(-130, 130), randf_range(-180, -50)), Color("8C887E"), randf_range(0.45, 0.9), randf_range(3.0, 7.0), 1)
			audio.play("explosion", 0.9, 0.82)
			camera_shake = max(camera_shake, 0.85)
		return
	castle["hp"] = max(0.0, float(castle["hp"]) - damage)
	_add_floater(Vector2(castle["pos"]) + Vector2(randf_range(-45, 45), -145), "-%d" % int(damage), Color("FFF0DA"), 0.8)
	if float(castle["hp"]) <= 0.0:
		castle["destroyed"] = true
		castle["capture"] = 0.0
		_add_notification("城堡防禦已瓦解！清除附近敵人並留在範圍內佔領。", GOLD, 4.0)
		_spawn_effect("explosion", castle["pos"], FIRE_ORANGE, 1.8)
		_gain_xp(160 * int(castle["level"]))


func _damage_owned_castle(castle: Dictionary, raw_damage: float) -> void:
	if not bool(castle.get("owned", false)) or float(castle.get("hp", 0.0)) <= 0.0:
		return
	var show_warning := float(castle.get("under_attack", 0.0)) <= 0.0
	var damage := maxf(1.0, raw_damage * 0.48)
	if float(castle.get("wall_hp", 0.0)) > 0.0:
		castle["wall_hp"] = maxf(0.0, float(castle["wall_hp"]) - damage)
		castle["wall_breached"] = float(castle["wall_hp"]) <= 0.0
		_add_floater(Vector2(castle["pos"]) + Vector2(randf_range(-90.0, 90.0), -210.0), "城牆 -%d" % int(damage), Color("FFB08C"), 0.75)
	else:
		castle["hp"] = maxf(0.0, float(castle["hp"]) - damage)
		_add_floater(Vector2(castle["pos"]) + Vector2(randf_range(-55.0, 55.0), -155.0), "-%d" % int(damage), Color("FF8D85"), 0.75)
	castle["under_attack"] = 7.0
	_spawn_effect("hit", castle["pos"] + Vector2(randf_range(-110.0, 110.0), randf_range(-95.0, 95.0)), ENEMY_RED, 0.7)
	if show_warning:
		_add_notification("警告：敵軍正在攻擊友方城堡！", Color("FF857A"), 3.0)
		audio.play("warning", 0.65)


func _update_castle_capture(castle: Dictionary, delta: float) -> void:
	var capture_radius := float(GameConfig.CASTLE_SETTINGS["capture_radius"])
	var near_player := Vector2(player["pos"]).distance_to(castle["pos"]) <= capture_radius
	var contested := _enemies_near(castle["pos"], 310.0) > 0
	if near_player and not contested:
		castle["capture"] = min(float(GameConfig.CASTLE_SETTINGS["capture_seconds"]), float(castle["capture"]) + delta)
	else:
		castle["capture"] = max(0.0, float(castle["capture"]) - delta * 0.45)
	if float(castle["capture"]) >= float(GameConfig.CASTLE_SETTINGS["capture_seconds"]):
		castle["owned"] = true
		castle["nation"] = NationCatalog.conquest_metadata(NationCatalog.player_metadata())
		castle["destroyed"] = false
		castle["hp"] = float(castle["max_hp"]) * 0.45
		castle["income_timer"] = float(GameConfig.CASTLE_SETTINGS["income_interval"])
		if float(castle.get("wall_max_hp", 0.0)) > 0.0:
			castle["wall_hp"] = float(castle["wall_max_hp"]) * 0.35
			castle["wall_breached"] = false
		player["captured"] = int(player["captured"]) + 1
		var reward := 220 + int(castle["level"]) * 80
		player["money"] = int(player["money"]) + reward
		_gain_xp(240 + int(castle["level"]) * 85)
		_spawn_effect("capture", castle["pos"], FRIEND_BLUE, 1.6)
		audio.play("capture", 0.9)
		_add_notification("城堡佔領完成！獎勵 %d 金幣並開始產生收入。" % reward, GOLD, 4.0)
		if soldier_command == "攻城" and command_castle_id == str(castle["id"]):
			soldier_command = "駐守"
			command_point = Vector2(castle["pos"])
			command_target_id = -1
			_add_notification("攻城完成：部隊已轉為駐守新城。", FRIEND_BLUE, 3.2)


func _lose_castle(castle: Dictionary) -> void:
	_evacuate_friendly_units_from_falling_castle(castle)
	castle["owned"] = false
	castle["nation"] = NationCatalog.normalized_or_generated(castle.get("original_nation", {}), world_seed, str(castle["id"]), castle["pos"])
	castle["destroyed"] = false
	castle["hp"] = float(castle["max_hp"]) * 0.38
	castle["capture"] = 0.0
	castle["spawn_timer"] = 8.0
	castle["wall_hp"] = float(castle.get("wall_max_hp", 0.0))
	castle["wall_breached"] = float(castle.get("wall_max_hp", 0.0)) <= 0.0
	player["captured"] = max(0, int(player["captured"]) - 1)
	if soldier_command == "駐守" and command_castle_id == str(castle["id"]):
		soldier_command = "跟隨"
		command_castle_id = ""
		command_target_id = -1
		command_point = Vector2(player["pos"])
		_add_notification("駐守城堡失守：部隊已撤回跟隨。", Color("F6C177"), 3.0)
	_add_notification("一座友方城堡已失守！", Color("FF857A"), 4.0)
	audio.play("warning", 0.8)


func _evacuate_friendly_units_from_falling_castle(castle: Dictionary) -> void:
	if float(castle.get("wall_max_hp", 0.0)) <= 0.0:
		return
	var center := Vector2(castle["pos"])
	if bool(player.get("alive", false)):
		var player_limit := CASTLE_OUTER_COLLISION_RADIUS + PLAYER_RADIUS + 2.0
		if Vector2(player["pos"]).distance_to(center) < player_limit:
			player["pos"] = _castle_outer_evacuation_position(center, Vector2(player["pos"]), PLAYER_RADIUS)
			player["vel"] = Vector2.ZERO
	for soldier in soldiers:
		var soldier_radius := float(soldier.get("radius", 12.0))
		var soldier_limit := CASTLE_OUTER_COLLISION_RADIUS + soldier_radius + 2.0
		if Vector2(soldier["pos"]).distance_to(center) < soldier_limit:
			soldier["pos"] = _castle_outer_evacuation_position(center, Vector2(soldier["pos"]), soldier_radius)
			soldier["vel"] = Vector2.ZERO


func _castle_outer_evacuation_position(center: Vector2, current: Vector2, radius: float) -> Vector2:
	var outward := current - center
	if outward.length_squared() <= 0.01:
		outward = Vector2.DOWN
	var preferred := center + outward.normalized() * (CASTLE_OUTER_COLLISION_RADIUS + radius + 12.0)
	return _find_open_spawn_position(center, preferred, radius)


func _castle_tower_attack(castle: Dictionary) -> void:
	var target: Dictionary = {}
	var best := 620.0
	if player["alive"]:
		var d := Vector2(player["pos"]).distance_to(castle["pos"])
		if d < best:
			best = d
			target = {"pos": player["pos"]}
	for soldier in soldiers:
		var d := Vector2(soldier["pos"]).distance_to(castle["pos"])
		if d < best:
			best = d
			target = {"pos": soldier["pos"]}
	if target.is_empty(): return
	castle["tower_cd"] = 2.4
	var direction := (Vector2(target["pos"]) - Vector2(castle["pos"])).normalized()
	_spawn_projectile({"team": "enemy", "kind": "enemy_arrow", "pos": Vector2(castle["pos"]) + direction * 145.0, "vel": direction * 560.0, "damage": 18.0 + 5.0 * int(castle["level"]), "range": 680.0, "radius": 6.0, "pierce": 1, "aoe": 0.0, "color": Color("FF9B79")})


func _damage_camp_crate(camp: Dictionary, raw_damage: float) -> void:
	camp["crate_hp"] = max(0.0, float(camp["crate_hp"]) - raw_damage)
	if float(camp["crate_hp"]) <= 0.0:
		var reward := 45 + int(camp["level"]) * 15
		player["money"] = int(player["money"]) + reward
		player["hp"] = min(float(player["max_hp"]), float(player["hp"]) + float(player["max_hp"]) * 0.22)
		_add_notification("補給箱：+%d 金幣並恢復生命。" % reward, GOLD, 2.2)
		_spawn_effect("explosion", camp["pos"], GOLD, 0.65)


func _clear_camp(camp: Dictionary) -> void:
	camp["cleared"] = true
	camp["respawn_at"] = game_time + float(GameConfig.CAMP_SETTINGS["respawn_seconds"])
	var gold := int(GameConfig.CAMP_SETTINGS["clear_reward_gold"]) * int(camp["level"])
	var xp := int(GameConfig.CAMP_SETTINGS["clear_reward_xp"]) * int(camp["level"])
	player["money"] = int(player["money"]) + gold
	_gain_xp(xp)
	_add_notification("營地已清除：+%d 金幣、+%d XP" % [gold, xp], GOLD, 2.7)
	audio.play("coin", 0.7)


func _enemies_near(position: Vector2, radius: float) -> int:
	var count := 0
	for enemy in enemies:
		if Vector2(enemy["pos"]).distance_to(position) <= radius: count += 1
	return count


func _enemies_with_guard(castle_id: String) -> int:
	var count := 0
	for enemy in enemies:
		if enemy["guard_castle"] == castle_id: count += 1
	return count


func _enemies_with_camp(camp_id: String) -> int:
	var count := 0
	for enemy in enemies:
		if enemy["camp_id"] == camp_id: count += 1
	return count


# -----------------------------------------------------------------------------
# 尋找、碰撞、特效與存檔工具
# -----------------------------------------------------------------------------

func _segment_hits_circle(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start.distance_squared_to(center) <= radius * radius
	var t: float = clampf((center - start).dot(segment) / length_squared, 0.0, 1.0)
	var closest: Vector2 = start + segment * t
	return closest.distance_squared_to(center) <= radius * radius


func _segment_circle_hit_time(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> float:
	var motion := finish - start
	var a := motion.dot(motion)
	if a <= 0.0001:
		return 0.0 if start.distance_squared_to(center) <= radius * radius else 2.0
	var offset := start - center
	var c := offset.dot(offset) - radius * radius
	if c <= 0.0:
		return 0.0
	var b := 2.0 * offset.dot(motion)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return 2.0
	var root := sqrt(discriminant)
	var first := (-b - root) / (2.0 * a)
	var second := (-b + root) / (2.0 * a)
	if first >= 0.0 and first <= 1.0:
		return first
	if second >= 0.0 and second <= 1.0:
		return second
	return 2.0


func _sort_projectile_hit_time(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("time", 2.0)) < float(b.get("time", 2.0))


func _find_open_spawn_position(anchor: Vector2, preferred: Vector2, radius: float, friendly_passage: bool = false) -> Vector2:
	var offset := preferred - anchor
	var distance: float = maxf(90.0, offset.length())
	var base_angle := offset.angle() if offset.length_squared() > 0.01 else 0.0
	for ring in 4:
		for step in 16:
			var angle := base_angle + TAU * float(step) / 16.0
			var candidate: Vector2 = anchor + Vector2.from_angle(angle) * (distance + float(ring) * 34.0)
			if not _position_hits_obstacle(candidate, radius, friendly_passage):
				return candidate
	return preferred


func _segment_hits_environment_obstacle(start: Vector2, finish: Vector2, radius: float) -> bool:
	return _segment_environment_hit_time(start, finish, radius) <= 1.0


func _obstacle_blocks_movement(obstacle: Dictionary) -> bool:
	# Bushes and rocks remain readable scenery but are intentionally traversable;
	# only tree trunks participate in movement and path-query collision.
	return str(obstacle.get("type", "")) == "tree"


func _position_hits_tree(position: Vector2, radius: float) -> bool:
	var center := world_generator.world_to_chunk(position)
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var key := world_generator.chunk_key(Vector2i(x, y))
			if not active_chunks.has(key):
				continue
			for obstacle in active_chunks[key]["obstacles"]:
				if _obstacle_blocks_movement(obstacle) and Vector2(obstacle["position"]).distance_to(position) < float(obstacle["radius"]) + radius:
					return true
	return false


func _segment_environment_hit_time(start: Vector2, finish: Vector2, radius: float) -> float:
	var earliest := 2.0
	var min_point := Vector2(min(start.x, finish.x), min(start.y, finish.y)) - Vector2.ONE * radius
	var max_point := Vector2(max(start.x, finish.x), max(start.y, finish.y)) + Vector2.ONE * radius
	var min_chunk := world_generator.world_to_chunk(min_point)
	var max_chunk := world_generator.world_to_chunk(max_point)
	for y in range(min_chunk.y, max_chunk.y + 1):
		for x in range(min_chunk.x, max_chunk.x + 1):
			var key := world_generator.chunk_key(Vector2i(x, y))
			if not active_chunks.has(key):
				continue
			for obstacle in active_chunks[key]["obstacles"]:
				if not _obstacle_blocks_movement(obstacle):
					continue
				var hit_time := _segment_circle_hit_time(start, finish, obstacle["position"], float(obstacle["radius"]) + radius)
				if hit_time < earliest:
					earliest = hit_time
	return earliest


func _move_with_collision(position: Vector2, motion: Vector2, radius: float, friendly_passage: bool = false) -> Vector2:
	var result := position
	var try_x := result + Vector2(motion.x, 0.0)
	if not _position_hits_obstacle(try_x, radius, friendly_passage): result.x = try_x.x
	var try_y := result + Vector2(0.0, motion.y)
	if not _position_hits_obstacle(try_y, radius, friendly_passage): result.y = try_y.y
	return result


func _separate_position_from_units(position: Vector2, radius: float, units: Array[Dictionary], friendly_passage: bool = false) -> Vector2:
	var result := position
	for unit in units:
		if str(unit.get("domain", "ground")) == "air":
			continue
		if float(unit.get("hp", 1.0)) <= 0.0:
			continue
		var away := result - Vector2(unit["pos"])
		var distance := away.length()
		var desired := radius + float(unit["radius"]) + 2.0
		if distance >= desired:
			continue
		if distance <= 0.01:
			away = Vector2.from_angle(float(int(unit.get("id", 1))) * 2.39996)
			distance = 0.01
		var push: Vector2 = away.normalized() * minf(6.0, desired - distance)
		result = _move_with_collision(result, push, radius, friendly_passage)
	return result


func _position_hits_obstacle(position: Vector2, radius: float, friendly_passage: bool = false) -> bool:
	var center := world_generator.world_to_chunk(position)
	for y in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			var key := world_generator.chunk_key(Vector2i(x, y))
			if not active_chunks.has(key): continue
			var chunk: Dictionary = active_chunks[key]
			for obstacle in chunk["obstacles"]:
				if not _obstacle_blocks_movement(obstacle):
					continue
				if Vector2(obstacle["position"]).distance_to(position) < float(obstacle["radius"]) + radius:
					return true
			if chunk["castle"] != null:
				var castle_id := str(chunk["castle"]["id"])
				var castle_pos: Vector2 = Vector2(castles[castle_id]["pos"]) if castles.has(castle_id) else Vector2(chunk["castle"]["position"])
				var structure_radius := CASTLE_CORE_COLLISION_RADIUS
				if castles.has(castle_id):
					var stored_castle: Dictionary = castles[castle_id]
					var blocks_with_outer_wall := float(stored_castle.get("wall_max_hp", 0.0)) > 0.0 and not bool(stored_castle.get("wall_breached", false))
					# Once captured, the gate opens for the player and recruited ground
					# troops. Hostile units still collide with the restored outer wall.
					if blocks_with_outer_wall and not (friendly_passage and bool(stored_castle.get("owned", false))):
						structure_radius = CASTLE_OUTER_COLLISION_RADIUS
				if castle_pos.distance_to(position) < radius + structure_radius:
					return true
	if position.distance_to(HOUSE_POS) < radius + 48.0:
		return true
	return false


func _castle_damage_radius(castle: Dictionary) -> float:
	if float(castle.get("wall_max_hp", 0.0)) > 0.0 and not bool(castle.get("wall_breached", false)):
		return 210.0
	return 132.0


func _find_enemy_by_id(id: int) -> Variant:
	for enemy in enemies:
		if int(enemy["id"]) == id: return enemy
	return null


func _enemy_index_by_id(id: int) -> int:
	for i in enemies.size():
		if int(enemies[i]["id"]) == id: return i
	return -1


func _find_soldier_by_id(id: int) -> Variant:
	for soldier in soldiers:
		if int(soldier["id"]) == id: return soldier
	return null


func _find_tombstone_by_id(id: int) -> Variant:
	for tomb in tombstones:
		if int(tomb["id"]) == id: return tomb
	return null


func _enemy_near_point(position: Vector2, radius: float) -> int:
	var best := -1
	var distance := radius
	for enemy in enemies:
		var d := Vector2(enemy["pos"]).distance_to(position)
		if d < distance:
			distance = d
			best = int(enemy["id"])
	if _active_boss_can_be_targeted():
		var boss_distance := _active_boss_position().distance_to(position)
		if boss_distance < distance:
			best = BOSS_ENTITY_ID
	return best


func _nearest_enemy_distance(position: Vector2) -> float:
	var result := INF
	for enemy in enemies:
		result = min(result, position.distance_to(enemy["pos"]))
	if _active_boss_can_be_targeted():
		result = min(result, position.distance_to(_active_boss_position()))
	return result


func _nearest_hostile_castle(position: Vector2, max_distance: float) -> Variant:
	var best: Variant = null
	var best_distance := max_distance
	for castle in castles.values():
		if castle["owned"] or castle["destroyed"]: continue
		var d := position.distance_to(castle["pos"])
		if d < best_distance:
			best_distance = d
			best = castle
	return best


func _nearest_owned_castle(position: Vector2, max_distance: float) -> Variant:
	var best: Variant = null
	var best_distance := max_distance
	for castle in castles.values():
		if not bool(castle.get("owned", false)):
			continue
		var distance := position.distance_to(castle["pos"])
		if distance < best_distance:
			best_distance = distance
			best = castle
	return best


func _commanded_castle(require_owned: bool) -> Variant:
	if command_castle_id.is_empty() or not castles.has(command_castle_id):
		return null
	var castle: Dictionary = castles[command_castle_id]
	if require_owned != bool(castle.get("owned", false)):
		return null
	return castle


func _soldier_command_display() -> String:
	if soldier_command in ["駐守", "攻城"] and castles.has(command_castle_id):
		return "%s Lv.%d" % [soldier_command, int(castles[command_castle_id].get("level", 1))]
	return soldier_command


func _spawn_effect(kind: String, position: Vector2, color: Color, scale: float) -> void:
	var ttl := 0.28
	if kind in ["level_up", "capture", "revive"]: ttl = 1.0
	if kind in ["death", "dash"]: ttl = 0.55
	particles.append({"effect": true, "kind": kind, "pos": position, "vel": Vector2.ZERO, "color": color, "ttl": ttl, "max_ttl": ttl, "size": 20.0 * scale, "priority": 0})
	_trim_particles()


func _spawn_particle(position: Vector2, velocity: Vector2, color: Color, ttl: float, size: float, priority: int) -> void:
	particles.append({"effect": false, "kind": "particle", "pos": position, "vel": velocity, "color": color, "ttl": ttl, "max_ttl": ttl, "size": size, "priority": priority})
	_trim_particles()


func _spawn_trail_particle(position: Vector2, color: Color) -> void:
	_spawn_particle(position, Vector2.ZERO, Color(color, 0.55), 0.24, 18.0, 2)


func _trim_particles() -> void:
	var particle_budget := MAX_MOBILE_PARTICLES if touch_capable or _is_touch_scheme() else MAX_PARTICLES
	while particles.size() > particle_budget:
		var remove_index := 0
		var worst_priority := -1
		for i in particles.size():
			if int(particles[i]["priority"]) > worst_priority:
				worst_priority = int(particles[i]["priority"])
				remove_index = i
		particles.remove_at(remove_index)


func _add_floater(position: Vector2, text: String, color: Color, ttl: float) -> void:
	if floaters.size() >= MAX_FLOATERS: floaters.pop_front()
	floaters.append({"pos": position, "text": text, "color": color, "ttl": ttl, "max_ttl": ttl, "offset": 0.0})


func _add_notification(text: String, color: Color = Color.WHITE, ttl: float = 2.5) -> void:
	if notifications_hidden:
		return
	notifications.append({"text": text, "color": color, "ttl": ttl, "max_ttl": ttl})
	while notifications.size() > 4: notifications.pop_front()


func _toggle_notifications() -> void:
	notifications_hidden = not notifications_hidden
	notifications.clear()
	if not notifications_hidden:
		_add_notification("通知已顯示。", Color("C9EDFF"), 1.8)
	queue_redraw()


func _add_upgrade_runtime_effect(effect: Dictionary) -> void:
	if effect.is_empty() or typeof(effect.get("pos", null)) != TYPE_VECTOR2:
		return
	var stored := effect.duplicate(true)
	var kind := str(stored.get("kind", "generic"))
	stored["kind"] = kind
	stored["created_at"] = float(stored.get("created_at", game_time))
	stored["ttl"] = maxf(0.01, float(stored.get("ttl", 0.01)))
	var source_id := int(stored.get("source_id", -1))
	var definition: Dictionary = Dictionary(stored.get("effect", {}))
	var owner_cap := maxi(0, int(stored.get("max_per_owner", definition.get("max_per_owner", 0))))
	if owner_cap > 0:
		while _upgrade_effect_count(kind, source_id) >= owner_cap:
			if not _remove_oldest_upgrade_effect(kind, source_id):
				break
	var team_cap := MAX_UPGRADE_EFFECTS
	if kind == "mine":
		team_cap = mini(MAX_UPGRADE_MINES_PER_TEAM, maxi(1, int(stored.get("team_cap", definition.get("team_cap", MAX_UPGRADE_MINES_PER_TEAM)))))
	elif kind == "lingering":
		team_cap = mini(MAX_UPGRADE_LINGERING_PER_TEAM, maxi(1, int(stored.get("team_cap", definition.get("team_cap", MAX_UPGRADE_LINGERING_PER_TEAM)))))
	elif kind in ["guardian", "auto_turret", "repair_drone"]:
		team_cap = mini(MAX_UPGRADE_SUMMONS_PER_TEAM, maxi(1, int(stored.get("team_cap", definition.get("team_summon_cap", MAX_UPGRADE_SUMMONS_PER_TEAM)))))
	if kind in ["guardian", "auto_turret", "repair_drone"]:
		while _upgrade_summon_count() >= team_cap:
			if not _remove_oldest_upgrade_summon():
				break
	else:
		while _upgrade_effect_count(kind) >= team_cap:
			if not _remove_oldest_upgrade_effect(kind):
				break
	while upgrade_effects.size() >= MAX_UPGRADE_EFFECTS:
		upgrade_effects.pop_front()
	upgrade_effects.append(stored)


func _upgrade_effect_count(kind: String, source_id: int = -2147483648) -> int:
	var count := 0
	for active_effect in upgrade_effects:
		if str(active_effect.get("kind", "")) != kind:
			continue
		if source_id != -2147483648 and int(active_effect.get("source_id", -1)) != source_id:
			continue
		count += 1
	return count


func _remove_oldest_upgrade_effect(kind: String, source_id: int = -2147483648) -> bool:
	var oldest_index := -1
	var oldest_time := INF
	for effect_index in upgrade_effects.size():
		var active_effect: Dictionary = upgrade_effects[effect_index]
		if str(active_effect.get("kind", "")) != kind:
			continue
		if source_id != -2147483648 and int(active_effect.get("source_id", -1)) != source_id:
			continue
		var created := float(active_effect.get("created_at", 0.0))
		if created < oldest_time:
			oldest_time = created
			oldest_index = effect_index
	if oldest_index < 0:
		return false
	upgrade_effects.remove_at(oldest_index)
	return true


func _upgrade_summon_count() -> int:
	var count := 0
	for effect in upgrade_effects:
		if str(effect.get("kind", "")) in ["guardian", "auto_turret", "repair_drone"]:
			count += 1
	return count


func _remove_oldest_upgrade_summon() -> bool:
	var oldest_index := -1
	var oldest_time := INF
	for effect_index in upgrade_effects.size():
		var effect: Dictionary = upgrade_effects[effect_index]
		if str(effect.get("kind", "")) not in ["guardian", "auto_turret", "repair_drone"]:
			continue
		var created := float(effect.get("created_at", 0.0))
		if created < oldest_time:
			oldest_time = created
			oldest_index = effect_index
	if oldest_index < 0:
		return false
	upgrade_effects.remove_at(oldest_index)
	return true


func _guardian_is_damageable(effect: Dictionary) -> bool:
	return str(effect.get("kind", "")) == "guardian" and not bool(effect.get("defeated", false)) and float(effect.get("hp", 0.0)) > 0.0 and float(effect.get("ttl", 0.0)) > 0.0


func _damage_guardian(effect: Dictionary, raw_damage: float, source_position: Vector2) -> float:
	if not _guardian_is_damageable(effect) or raw_damage <= 0.0:
		return 0.0
	var dealt := minf(float(effect.get("hp", 0.0)), maxf(0.0, raw_damage))
	effect["hp"] = maxf(0.0, float(effect.get("hp", 0.0)) - dealt)
	_add_floater(Vector2(effect["pos"]) + Vector2(0.0, -22.0), "-%d" % int(dealt), Color("9BD7FF"), 0.65)
	_spawn_effect("hit", effect["pos"], Color("9BD7FF"), 0.55)
	if float(effect["hp"]) <= 0.0:
		effect["defeated"] = true
		effect["ttl"] = 0.0
		_spawn_effect("death", effect["pos"], Color("9BD7FF"), 0.85)
	return dealt


func _damage_guardians_in_area(center: Vector2, radius: float, damage: float) -> int:
	var damaged := 0
	for effect in upgrade_effects:
		if not _guardian_is_damageable(effect):
			continue
		if Vector2(effect["pos"]).distance_to(center) <= radius + float(effect.get("radius", 24.0)):
			if _damage_guardian(effect, damage, center) > 0.0:
				damaged += 1
	return damaged


func _damage_guardians_in_melee(origin: Vector2, facing: Vector2, radius: float, damage: float) -> int:
	var damaged := 0
	for effect in upgrade_effects:
		if not _guardian_is_damageable(effect):
			continue
		var offset := Vector2(effect["pos"]) - origin
		if offset.length() > radius + float(effect.get("radius", 24.0)):
			continue
		if offset.length_squared() > 0.001 and absf(facing.angle_to(offset.normalized())) >= 1.15:
			continue
		if _damage_guardian(effect, damage, origin) > 0.0:
			damaged += 1
	return damaged


func _guardian_projectile_intersection(from: Vector2, to: Vector2, projectile_radius: float) -> Dictionary:
	var best_time := 2.0
	var best_index := -1
	for effect_index in upgrade_effects.size():
		var effect: Dictionary = upgrade_effects[effect_index]
		if not _guardian_is_damageable(effect):
			continue
		var hit_time := _segment_circle_hit_time(from, to, Vector2(effect["pos"]), float(effect.get("radius", 24.0)) + projectile_radius)
		if hit_time < best_time:
			best_time = hit_time
			best_index = effect_index
	return {"hit": best_index >= 0 and best_time <= 1.0, "time": best_time, "effect_index": best_index, "position": from.lerp(to, clampf(best_time, 0.0, 1.0))}


func _update_upgrade_effects(delta: float) -> void:
	# Upgrade payloads use their own bounded visual/runtime list so they cannot
	# evict player attacks or Boss telegraphs from the regular projectile pool.
	for index in range(upgrade_effects.size() - 1, -1, -1):
		if index >= upgrade_effects.size():
			continue
		var effect: Dictionary = upgrade_effects[index]
		var ttl_before := maxf(0.0, float(effect.get("ttl", 0.0)))
		var warmup_before := maxf(0.0, float(effect.get("warmup", 0.0)))
		var lifetime_delta := minf(maxf(0.0, delta), ttl_before)
		effect["ttl"] = maxf(0.0, ttl_before - delta)
		if effect.has("warmup"):
			effect["warmup"] = maxf(0.0, warmup_before - delta)
		effect["active_delta"] = maxf(0.0, lifetime_delta - minf(warmup_before, lifetime_delta))
		var consumed := _update_single_upgrade_effect(effect, delta)
		if consumed or float(effect["ttl"]) <= 0.0:
			upgrade_effects.remove_at(index)
	while upgrade_effects.size() > MAX_UPGRADE_EFFECTS:
		upgrade_effects.pop_front()


func _update_single_upgrade_effect(effect: Dictionary, delta: float) -> bool:
	var kind := str(effect.get("kind", "generic"))
	if float(effect.get("warmup", 0.0)) > 0.0:
		return false
	match kind:
		"temporal_echo":
			if bool(effect.get("triggered", false)):
				return true
			effect["triggered"] = true
			var echo_projectile: Dictionary = Dictionary(effect.get("projectile", {})).duplicate(true)
			if not echo_projectile.is_empty():
				echo_projectile["pos"] = Vector2(effect["pos"])
				_spawn_projectile(echo_projectile)
				_spawn_effect("spawn", effect["pos"], Color("B993FF"), 0.65)
			return true
		"meteor", "chain_blast", "bomblet", "ufo_echo":
			if bool(effect.get("triggered", false)):
				return true
			effect["triggered"] = true
			_upgrade_area_damage(effect, false)
			return true
		"mine":
			effect["scan"] = float(effect.get("scan", 0.0)) - delta
			if float(effect["scan"]) > 0.0:
				return false
			effect["scan"] = UPGRADE_EFFECT_SCAN_INTERVAL
			if _nearest_ground_enemy_id(Vector2(effect["pos"]), float(effect.get("radius", 78.0))) >= 0:
				_upgrade_area_damage(effect, true)
				return true
		"lingering":
			effect["tick"] = float(effect.get("tick", 0.0)) - delta
			if float(effect["tick"]) <= 0.0:
				effect["tick"] = maxf(0.1, float(effect.get("tick_interval", 0.5)))
				var target_id := int(effect.get("target_id", -1))
				var effect_position := Vector2(effect["pos"])
				var effect_radius := float(effect.get("radius", 24.0))
				var hit_boss := target_id == BOSS_ENTITY_ID and _active_boss_can_be_targeted() and _active_boss_position().distance_to(effect_position) <= effect_radius + _active_boss_radius()
				if hit_boss:
					var tick_id := _allocate_attack_id("soldier_lingering")
					_consume_active_boss_hit_result(_receive_active_boss_hit(tick_id, str(effect.get("source_kind", "soldier")), int(effect.get("source_id", -1)), float(effect.get("damage", 0.0)), effect_position, "upgrade_lingering", float(effect.get("armor_penetration", 0.0))))
				else:
					var target_index := _enemy_index_by_id(target_id)
					if target_index < 0 or Vector2(enemies[target_index]["pos"]).distance_to(effect_position) > effect_radius + float(enemies[target_index]["radius"]):
						target_id = _nearest_ground_enemy_id(effect_position, effect_radius + 36.0)
						target_index = _enemy_index_by_id(target_id)
					if target_index >= 0:
						_damage_enemy(target_index, float(effect.get("damage", 0.0)), effect_position, "lingering", float(effect.get("armor_penetration", 0.0)), int(effect.get("source_id", -1)))
		"burning_zone":
			effect["tick"] = float(effect.get("tick", 0.0)) - delta
			if float(effect["tick"]) <= 0.0:
				effect["tick"] = maxf(0.1, float(effect.get("tick_interval", 0.5)))
				_upgrade_area_damage(effect, true, false)
		"boss_burn", "boss_poison":
			if not _active_boss_can_be_targeted():
				return true
			effect["pos"] = _active_boss_position()
			effect["tick"] = float(effect.get("tick", 0.0)) - delta
			if float(effect["tick"]) <= 0.0:
				effect["tick"] = maxf(0.1, float(effect.get("tick_interval", 0.5)))
				effect["tick_sequence"] = int(effect.get("tick_sequence", 0)) + 1
				var dot_damage := float(effect.get("damage_per_stack", 0.0)) * float(int(effect.get("stacks", 1)))
				var dot_id := "%s:%d:%d" % [str(effect.get("kind", "boss_dot")), int(effect.get("source_id", -1)), int(effect["tick_sequence"])]
				_consume_active_boss_hit_result(_receive_active_boss_hit(dot_id, "upgrade_dot", int(effect.get("source_id", -1)), dot_damage, effect["pos"], "status", 999.0))
		"gravity":
			var pull_step := _gravity_pull_step(effect, float(effect.get("active_delta", delta)))
			if pull_step > 0.0:
				var center := Vector2(effect["pos"])
				var field_radius := maxf(1.0, float(effect.get("radius", 130.0)))
				for enemy in enemies:
					if _enemy_is_air(enemy) or Vector2(enemy["pos"]).distance_to(center) > field_radius + float(enemy["radius"]):
						continue
					var toward := (center - Vector2(enemy["pos"])).normalized()
					enemy["pos"] = _move_with_collision(enemy["pos"], toward * pull_step, float(enemy["radius"]))
					enemy["slow"] = maxf(float(enemy.get("slow", 0.0)), 0.24)
					enemy["slow_factor"] = maxf(float(enemy.get("slow_factor", 0.0)), float(effect.get("slow_ratio", 0.15)))
		"guardian":
			_update_guardian_effect(effect, delta)
		"auto_turret":
			_update_auto_turret_effect(effect, delta)
		"repair_drone":
			_update_repair_drone_effect(effect, delta)
	return false


func _gravity_pull_step(effect: Dictionary, active_delta: float) -> float:
	var duration := maxf(0.1, float(effect.get("pull_duration", effect.get("duration", 2.5))))
	var elapsed_before := clampf(float(effect.get("pull_elapsed", 0.0)), 0.0, duration)
	var elapsed_after := minf(duration, elapsed_before + maxf(0.0, active_delta))
	effect["pull_elapsed"] = elapsed_after
	return maxf(0.0, float(effect.get("pull_distance", 70.0))) * (elapsed_after - elapsed_before) / duration


func _nearest_ground_enemy_id(position: Vector2, radius: float) -> int:
	var result := -1
	var best_distance := radius
	for enemy in enemies:
		if _enemy_is_air(enemy):
			continue
		var distance := Vector2(enemy["pos"]).distance_to(position)
		if distance < best_distance:
			best_distance = distance
			result = int(enemy["id"])
	return result


func _upgrade_area_damage(effect: Dictionary, ground_only: bool = false, spawn_burst: bool = true) -> void:
	var position := Vector2(effect.get("pos", Vector2.ZERO))
	var radius := maxf(1.0, float(effect.get("radius", 32.0)))
	var damage := maxf(0.0, float(effect.get("damage", 0.0)))
	var source_id := int(effect.get("source_id", -1))
	var hit_ids: Array[int] = []
	for enemy in enemies:
		if ground_only and _enemy_is_air(enemy):
			continue
		if Vector2(enemy["pos"]).distance_to(position) <= radius + float(enemy["radius"]):
			hit_ids.append(int(enemy["id"]))
	for hit_id in hit_ids:
		var enemy_index := _enemy_index_by_id(hit_id)
		if enemy_index >= 0:
			_damage_enemy(enemy_index, damage, position, "area", 0.0, source_id)
	if not ground_only and _active_boss_can_be_targeted():
		var boss_hit := _active_boss_projectile_intersection(position, position, radius)
		if bool(boss_hit.get("hit", false)):
			var attack_id := _allocate_attack_id("soldier_upgrade_%s" % str(effect.get("kind", "area")))
			_consume_active_boss_hit_result(_receive_active_boss_hit(attack_id, str(effect.get("source_kind", "soldier")), source_id, damage, Vector2(boss_hit["position"]), "upgrade_area", 0.0))
	if spawn_burst:
		_spawn_effect("explosion", position, Color(effect.get("color", FIRE_ORANGE)), clampf(radius / 100.0, 0.55, 1.6))


func _update_guardian_effect(effect: Dictionary, delta: float) -> void:
	var owner: Variant = _find_soldier_by_id(int(effect.get("source_id", -1)))
	if owner != null:
		var orbit := Vector2.from_angle(game_time * 1.4 + float(int(effect.get("source_id", 0)) % 9)) * 48.0
		effect["pos"] = Vector2(effect["pos"]).lerp(Vector2(owner["pos"]) + orbit, minf(1.0, delta * 4.5))
	effect["shot_cd"] = maxf(0.0, float(effect.get("shot_cd", 0.0)) - delta)
	if float(effect["shot_cd"]) > 0.0:
		return
	var definition: Dictionary = Dictionary(effect.get("effect", {}))
	var target_id := _enemy_near_point(Vector2(effect["pos"]), float(definition.get("attack_range", 280.0)))
	if target_id < 0:
		return
	effect["shot_cd"] = maxf(0.25, float(definition.get("attack_interval", 1.1)))
	var damage := float(effect.get("owner_attack", 1.0)) * float(definition.get("attack_ratio", 0.45))
	if target_id == BOSS_ENTITY_ID:
		_consume_active_boss_hit_result(_receive_active_boss_hit(_allocate_attack_id("guardian"), "guardian", int(effect.get("source_id", -1)), damage, _active_boss_position(), "projectile", 0.0))
	else:
		var enemy_index := _enemy_index_by_id(target_id)
		if enemy_index >= 0:
			_damage_enemy(enemy_index, damage, effect["pos"], "projectile", 0.0, int(effect.get("source_id", -1)))
	_spawn_effect("slash", effect["pos"], Color("9BD7FF"), 0.45)


func _update_auto_turret_effect(effect: Dictionary, delta: float) -> void:
	effect["shot_cd"] = maxf(0.0, float(effect.get("shot_cd", 0.0)) - delta)
	if float(effect["shot_cd"]) > 0.0:
		return
	var definition: Dictionary = Dictionary(effect.get("effect", {}))
	var target_id := _enemy_near_point(Vector2(effect["pos"]), float(definition.get("attack_range", 520.0)))
	if target_id < 0:
		return
	effect["shot_cd"] = 1.0 / maxf(0.1, float(definition.get("shots_per_second", 2.0)))
	var damage := float(effect.get("owner_attack", 1.0)) * float(definition.get("shot_damage_ratio", 0.25))
	if target_id == BOSS_ENTITY_ID:
		_consume_active_boss_hit_result(_receive_active_boss_hit(_allocate_attack_id("auto_turret"), "auto_turret", int(effect.get("source_id", -1)), damage, _active_boss_position(), "projectile", 3.0))
	else:
		var enemy_index := _enemy_index_by_id(target_id)
		if enemy_index >= 0:
			_damage_enemy(enemy_index, damage, effect["pos"], "projectile", 3.0, int(effect.get("source_id", -1)))
	_spawn_effect("muzzle", effect["pos"], Color("83E8FF"), 0.35)


func _update_repair_drone_effect(effect: Dictionary, delta: float) -> void:
	var owner: Variant = _find_soldier_by_id(int(effect.get("source_id", -1)))
	if owner != null:
		var hover := Vector2(38.0, -42.0).rotated(sin(game_time * 0.9 + float(int(effect.get("source_id", 0)))) * 0.35)
		effect["pos"] = Vector2(effect["pos"]).lerp(Vector2(owner["pos"]) + hover, minf(1.0, delta * 5.0))
	var best: Variant = null
	var best_ratio := 1.0
	var definition: Dictionary = Dictionary(effect.get("effect", {}))
	for ally in soldiers:
		if str(ally.get("domain", "ground")) != "air" and str(ally.get("type", "")) not in ["roller", "cannon", "tank", "rocket", "gatling"]:
			continue
		if Vector2(ally["pos"]).distance_to(Vector2(effect["pos"])) > float(definition.get("healing_range", 360.0)):
			continue
		var ratio := float(ally["hp"]) / maxf(1.0, float(ally["max_hp"]))
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	if best == null:
		return
	best["hp"] = minf(float(best["max_hp"]), float(best["hp"]) + float(best["max_hp"]) * float(definition.get("max_hp_heal_per_second", 0.025)) * delta)
	effect["scan"] = float(effect.get("scan", 0.0)) - delta
	if float(effect["scan"]) <= 0.0:
		effect["scan"] = 0.6
		_spawn_effect("heal", best["pos"], HEAL_GREEN, 0.45)


func _draw_upgrade_effects() -> void:
	# These are gameplay cues, not notification banners. They remain visible even
	# when the player hides high-volume income and Boss-skill notices.
	for effect in upgrade_effects:
		var position_value: Variant = effect.get("pos", Vector2.ZERO)
		if typeof(position_value) != TYPE_VECTOR2:
			continue
		var screen_position := _world_to_screen(Vector2(position_value))
		var radius := maxf(8.0, float(effect.get("radius", 32.0)))
		if not _on_screen(screen_position, radius + 48.0):
			continue
		var color := Color(effect.get("color", Color("F4C95D")))
		var warmup := float(effect.get("warmup", 0.0))
		var pulse := 0.62 + sin(game_time * 9.0) * 0.18
		if warmup > 0.0:
			draw_circle(screen_position, radius, Color(color, 0.10))
			draw_arc(screen_position, radius, 0.0, TAU, 36, Color(color, pulse), 2.5, true)
		else:
			draw_circle(screen_position, radius, Color(color, 0.16))
			draw_arc(screen_position, radius, 0.0, TAU, 36, Color(color, 0.72), 2.0, true)


func _update_visuals(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle["ttl"] = float(particle["ttl"]) - delta
		particle["pos"] = Vector2(particle["pos"]) + Vector2(particle["vel"]) * delta
		particle["vel"] = Vector2(particle["vel"]) * exp(-2.2 * delta)
		if float(particle["ttl"]) <= 0.0: particles.remove_at(i)
	for i in range(floaters.size() - 1, -1, -1):
		floaters[i]["ttl"] = float(floaters[i]["ttl"]) - delta
		floaters[i]["offset"] = float(floaters[i]["offset"]) + 28.0 * delta
		if float(floaters[i]["ttl"]) <= 0.0: floaters.remove_at(i)
	for i in range(notifications.size() - 1, -1, -1):
		notifications[i]["ttl"] = float(notifications[i]["ttl"]) - delta
		if float(notifications[i]["ttl"]) <= 0.0: notifications.remove_at(i)


func _save_game(show_notice: bool = true, path: String = GameSaveManager.SAVE_PATH) -> bool:
	if player["class_id"] == "": return false
	if not _can_persist_to_path(path):
		if show_notice:
			_add_notification("測試場景不會覆寫玩家存檔。", Color("C9EDFF"), 2.2)
		return false
	var data := {
		"schema": SAVE_SCHEMA,
		"world_seed": world_seed,
		"game_time": game_time,
		"player": player.duplicate(true),
		"enemies": enemies.duplicate(true),
		"soldiers": soldiers.duplicate(true),
		"tombstones": tombstones.duplicate(true),
		"drops": drops.duplicate(true),
		"next_entity_id": next_entity_id,
		"command": {"mode": soldier_command, "point": command_point, "target_id": command_target_id, "castle_id": command_castle_id},
		"castles": castles.duplicate(true),
		"camps": camps.duplicate(true),
		"snake_nests": snake_nests.duplicate(true),
		"boss_lair_state": {
			"active_lair_id": active_python_boss_lair_id,
			"main_cleared": main_python_boss_lair_cleared,
		},
		"discovered": discovered_chunks.keys(),
		"spawned": spawned_chunks.keys(),
		"chunk_states": chunk_states.duplicate(true),
		"pending_chunk_spawns": pending_chunk_spawns.duplicate(true),
		"settings": {"master_volume": master_volume, "muted": sound_muted, "tutorial": tutorial_visible, "notifications_hidden": notifications_hidden},
		"soldier_research": soldier_research.duplicate(true),
		"boss": {} if python_boss == null else python_boss.serialize(),
		"chaos_boss": {} if chaos_boss == null else chaos_boss.serialize(),
		"aionis_boss": {} if not timeless_gate_unlocked or aionis_boss == null else aionis_boss.serialize(),
		"progression": {
			"final_boss_defeated": final_boss_defeated,
			"ending_seen": ending_seen,
			"all_soldiers_unlocked": all_soldiers_unlocked,
			"timeless_gate_unlocked": timeless_gate_unlocked,
			"aionis_defeated": aionis_boss_defeated,
			"kaeron_ending_completed": kaeron_ending_completed,
		},
	}
	var success := GameSaveManager.save_game(data, path)
	if show_notice:
		_add_notification("遊戲已儲存。" if success else "儲存失敗。", HEAL_GREEN if success else Color("FF857A"), 2.0)
		if success: audio.play("ui", 0.5)
	return success


func _can_persist_to_path(path: String) -> bool:
	return not (_web_test_showcase_active and path == GameSaveManager.SAVE_PATH)


func _load_game(path: String = GameSaveManager.SAVE_PATH) -> bool:
	var data: Dictionary = GameSaveManager.load_game(path)
	if not _is_valid_save_data(data):
		_add_notification("找不到有效存檔。", Color("FF857A"), 2.2)
		return false
	var loaded_lair_binding := _resolve_saved_python_boss_lair_binding(data)
	var loaded_progression: Dictionary = Dictionary(data.get("progression", {}))
	var loaded_schema := int(data.get("schema", 1))
	soldier_research = SoldierUpgradeCatalog.sanitize_research(data.get("soldier_research", {}))
	final_boss_defeated = bool(loaded_progression.get("final_boss_defeated", false))
	ending_seen = bool(loaded_progression.get("ending_seen", false))
	all_soldiers_unlocked = all_soldiers_unlocked or bool(loaded_progression.get("all_soldiers_unlocked", false)) or final_boss_defeated
	timeless_gate_unlocked = timeless_gate_unlocked or bool(loaded_progression.get("timeless_gate_unlocked", false)) or all_soldiers_unlocked or final_boss_defeated
	kaeron_ending_completed = kaeron_ending_completed or bool(loaded_progression.get("kaeron_ending_completed", false)) or ending_seen
	aionis_boss_defeated = bool(loaded_progression.get("aionis_defeated", false)) if loaded_schema >= 6 else false
	if all_soldiers_unlocked:
		_save_profile_progression()
	ending_elapsed = 0.0
	ending_pending = false
	_web_test_showcase_active = false
	_web_manual_time_hold = 0.0
	world_seed = int(data.get("world_seed", 20260731))
	world_generator = WorldGenerator.new(world_seed)
	game_time = float(data.get("game_time", 0.0))
	player = Dictionary(data["player"]).duplicate(true)
	if not player.has("upgrades"):
		player["upgrades"] = {"attack": 0, "defense": 0, "max_hp": 0, "speed": 0, "attack_speed": 0}
	player["hp"] = clamp(float(player.get("hp", 1.0)), 1.0, float(player.get("max_hp", 100.0)))
	player["alive"] = true
	player["attack_cd"] = 0.0
	player["invuln"] = 2.0
	player["hit_grace"] = 0.0
	var has_enemy_snapshot := data.has("enemies")
	enemies = []
	for entry in data.get("enemies", []):
		var loaded_enemy := Dictionary(entry).duplicate(true)
		_normalize_loaded_enemy(loaded_enemy)
		enemies.append(loaded_enemy)
	soldiers = []
	for entry in data.get("soldiers", []):
		var loaded_soldier := Dictionary(entry).duplicate(true)
		_normalize_loaded_soldier(loaded_soldier)
		soldiers.append(loaded_soldier)
	tombstones = []
	for entry in data.get("tombstones", []): tombstones.append(Dictionary(entry).duplicate(true))
	drops = []
	for entry in data.get("drops", []): drops.append(Dictionary(entry).duplicate(true))
	castles = Dictionary(data.get("castles", {})).duplicate(true)
	for loaded_castle in castles.values():
		var loaded_level := int(loaded_castle.get("level", 1))
		var loaded_tier_cfg: Dictionary = GameConfig.castle_tier(loaded_level)
		var loaded_wall_max := float(loaded_castle.get("wall_max_hp", float(loaded_castle.get("max_hp", 0.0)) * float(loaded_tier_cfg.get("wall_ratio", 0.0))))
		loaded_castle["tier"] = int(loaded_castle.get("tier", GameConfig.castle_tier_for_level(loaded_level)))
		loaded_castle["tier_name"] = str(loaded_castle.get("tier_name", loaded_tier_cfg.get("name", "蠻族城堡")))
		loaded_castle["wall_max_hp"] = loaded_wall_max
		loaded_castle["wall_hp"] = clampf(float(loaded_castle.get("wall_hp", loaded_wall_max)), 0.0, loaded_wall_max)
		loaded_castle["wall_breached"] = bool(loaded_castle.get("wall_breached", loaded_wall_max <= 0.0 or float(loaded_castle["wall_hp"]) <= 0.0))
		var loaded_id := str(loaded_castle.get("id", ""))
		var generated_nation := NationCatalog.normalized_or_generated(loaded_castle.get("original_nation", loaded_castle.get("nation", {})), world_seed, loaded_id, loaded_castle.get("pos", Vector2.ZERO))
		loaded_castle["original_nation"] = generated_nation
		loaded_castle["nation"] = NationCatalog.conquest_metadata(NationCatalog.player_metadata()) if bool(loaded_castle.get("owned", false)) else NationCatalog.normalized_owner_or_generated(loaded_castle.get("nation", generated_nation), world_seed, loaded_id, loaded_castle.get("pos", Vector2.ZERO))
	camps = Dictionary(data.get("camps", {})).duplicate(true)
	snake_nests = _migrate_loaded_python_boss_lairs(data.get("snake_nests", {}))
	var loaded_lair_state: Dictionary = Dictionary(data.get("boss_lair_state", {}))
	active_python_boss_lair_id = str(loaded_lair_binding.get("id", MAIN_PYTHON_BOSS_LAIR_ID))
	main_python_boss_lair_cleared = bool(loaded_lair_state.get("main_cleared", false))
	python_boss_lair_activation_timer = 0.0
	chunk_states = Dictionary(data.get("chunk_states", {})).duplicate(true)
	pending_chunk_spawns = Dictionary(data.get("pending_chunk_spawns", {})).duplicate(true)
	discovered_chunks.clear()
	for key in data.get("discovered", []): discovered_chunks[str(key)] = true
	spawned_chunks.clear()
	for key in data.get("spawned", []): spawned_chunks[str(key)] = true
	if not has_enemy_snapshot:
		spawned_chunks.clear()
	var command: Dictionary = data.get("command", {})
	soldier_command = str(command.get("mode", "跟隨"))
	command_point = Vector2(command.get("point", player["pos"]))
	command_target_id = int(command.get("target_id", -1))
	command_castle_id = str(command.get("castle_id", ""))
	if soldier_command not in ["跟隨", "防守", "攻擊", "撤退", "駐守", "攻城"]:
		soldier_command = "跟隨"
	if soldier_command == "駐守" and _commanded_castle(true) == null:
		soldier_command = "跟隨"
		command_castle_id = ""
	elif soldier_command == "攻城" and _commanded_castle(false) == null:
		soldier_command = "跟隨"
		command_castle_id = ""
	if soldier_command not in ["駐守", "攻城"]:
		command_castle_id = ""
	next_entity_id = maxi(1, int(data.get("next_entity_id", 1)))
	for enemy in enemies:
		next_entity_id = maxi(next_entity_id, int(enemy.get("id", 0)) + 1)
	for soldier in soldiers:
		next_entity_id = maxi(next_entity_id, int(soldier.get("id", 0)) + 1)
	for tomb in tombstones:
		next_entity_id = maxi(next_entity_id, int(tomb.get("id", 0)) + 1)
	for stored_entries in chunk_states.values():
		for stored_enemy in stored_entries:
			next_entity_id = maxi(next_entity_id, int(Dictionary(stored_enemy).get("id", 0)) + 1)
	var settings: Dictionary = data.get("settings", {})
	master_volume = clamp(float(settings.get("master_volume", 0.75)), 0.0, 1.0)
	sound_muted = bool(settings.get("muted", false))
	tutorial_visible = bool(settings.get("tutorial", true))
	notifications_hidden = bool(settings.get("notifications_hidden", false))
	_initialize_python_boss(true)
	if typeof(data.get("boss")) == TYPE_DICTIONARY:
		python_boss.restore(Dictionary(data["boss"]))
	if python_boss.is_defeated():
		_mark_active_python_boss_lair_cleared()
	_initialize_chaos_boss(true)
	if typeof(data.get("chaos_boss")) == TYPE_DICTIONARY and not Dictionary(data.get("chaos_boss", {})).is_empty():
		chaos_boss.restore(Dictionary(data["chaos_boss"]))
	_initialize_aionis_boss(true)
	if timeless_gate_unlocked and loaded_schema >= 6 and typeof(data.get("aionis_boss")) == TYPE_DICTIONARY and not Dictionary(data.get("aionis_boss", {})).is_empty():
		aionis_boss.restore(Dictionary(data["aionis_boss"]))
		aionis_boss_defeated = aionis_boss.is_defeated()
	active_chunks.clear()
	projectiles.clear()
	hazards.clear()
	upgrade_effects.clear()
	soldier_boss_debuffs.clear()
	soldier_upgrade_shared_cooldowns.clear()
	chaos_runtime_projectiles.clear()
	chaos_runtime_hazards.clear()
	aionis_runtime_projectiles.clear()
	aionis_runtime_hazards.clear()
	particles.clear()
	floaters.clear()
	mode = GameMode.ENDING if final_boss_defeated and not ending_seen else GameMode.PLAYING
	active_panel = ""
	camera_pos = player["pos"]
	_last_active_center = Vector2i(999999, 999999)
	_update_active_chunks(true)
	_add_notification("存檔讀取完成。", HEAL_GREEN, 2.2)
	audio.play("ui", 0.55)
	return true


func _normalize_loaded_enemy(loaded_enemy: Dictionary) -> void:
	loaded_enemy["vel"] = Vector2.ZERO
	loaded_enemy["move_intent"] = Vector2.ZERO
	loaded_enemy["move_dir"] = Vector2.ZERO
	loaded_enemy["enhancement_stun"] = maxf(0.0, float(loaded_enemy.get("enhancement_stun", 0.0)))
	loaded_enemy["enhancement_reactive_timer"] = maxf(0.0, float(loaded_enemy.get("enhancement_reactive_timer", 0.0)))
	var saved_enhancement: Variant = loaded_enemy.get("enhancement")
	if EnemyEnhancementCatalog.is_valid_roll(saved_enhancement):
		loaded_enemy["enhancement_points"] = int(Dictionary(saved_enhancement).get("points", 0))
		loaded_enemy["enhancement_cursor"] = int(loaded_enemy.get("enhancement_cursor", 0))
		loaded_enemy["enhancement_attack_sequence"] = int(loaded_enemy.get("enhancement_attack_sequence", 0))
		return
	var guard_castle := str(loaded_enemy.get("guard_castle", ""))
	var empty_enhancement := {"version": 1, "castle_level": 0, "seed": 0, "points": 0, "tracks": {}, "special_count": 0}
	if guard_castle.is_empty():
		loaded_enemy["enhancement"] = empty_enhancement
		loaded_enemy["enhancement_points"] = 0
		return
	var source_level := maxi(1, int(loaded_enemy.get("level", 1)) - 1)
	if castles.has(guard_castle):
		source_level = maxi(1, int(Dictionary(castles[guard_castle]).get("level", source_level)))
	var migrated_roll := EnemyEnhancementCatalog.roll_for_enemy(
		source_level,
		_enemy_enhancement_seed(guard_castle, int(loaded_enemy.get("id", 0)), str(loaded_enemy.get("type", "grunt"))),
		str(loaded_enemy.get("type", "grunt"))
	)
	EnemyEnhancementCatalog.apply_stat_enhancements(loaded_enemy, migrated_roll)


func _normalize_loaded_soldier(loaded_soldier: Dictionary) -> void:
	loaded_soldier["aim_dir"] = Vector2(loaded_soldier.get("aim_dir", Vector2.RIGHT))
	loaded_soldier["vel"] = Vector2.ZERO
	loaded_soldier["avoid_dir"] = Vector2.ZERO
	loaded_soldier["avoid_timer"] = 0.0
	loaded_soldier["structure_target"] = str(loaded_soldier.get("structure_target", ""))
	var loaded_type := str(loaded_soldier.get("type", ""))
	var loaded_combat: Dictionary = Dictionary(GameConfig.SOLDIERS.get(loaded_type, {})).get("combat", {})
	loaded_soldier["domain"] = str(loaded_combat.get("domain", loaded_soldier.get("domain", "ground")))
	loaded_soldier["altitude"] = 38.0 if str(loaded_soldier["domain"]) == "air" else 0.0
	if not loaded_soldier.has("upgrade_snapshot"):
		loaded_soldier["upgrade_snapshot"] = SoldierUpgradeCatalog.snapshot_for_type(loaded_type, soldier_research)
	var loaded_snapshot: Dictionary = Dictionary(loaded_soldier.get("upgrade_snapshot", {})).duplicate(true)
	# Schema-7 snapshots stored purchased abilities only in `active_specials`.
	# Materialize the newer lookup map from those saved effect records so old
	# soldiers retain exactly the abilities they owned without inheriting current
	# research or newly added catalog effects.
	loaded_snapshot["special_effects"] = SoldierUpgradeRuntime.special_effect_map(loaded_snapshot)
	loaded_soldier["upgrade_snapshot"] = loaded_snapshot
	var loaded_base_effects: Dictionary = Dictionary(loaded_snapshot.get("base_effects", {}))
	loaded_soldier["support_power"] = maxf(0.01, float(loaded_soldier.get("support_power", 1.0 + float(loaded_base_effects.get("attack_or_healing_bonus", 0.0)))))
	loaded_soldier["support_rate"] = maxf(0.01, float(loaded_soldier.get("support_rate", 1.0 + float(loaded_base_effects.get("attack_or_support_speed_bonus", 0.0)))))
	loaded_soldier["support_range"] = maxf(1.0, float(loaded_soldier.get("support_range", loaded_soldier.get("range", 1.0))))
	loaded_soldier["special_runtime"] = SoldierUpgradeRuntime.normalize_state(loaded_soldier.get("special_runtime", {}), loaded_snapshot, float(loaded_soldier.get("max_hp", 1.0)))
	loaded_soldier["upgrade_cooldowns"] = Dictionary(loaded_soldier.get("upgrade_cooldowns", {})).duplicate(true)
	loaded_soldier["upgrade_counters"] = Dictionary(loaded_soldier.get("upgrade_counters", {})).duplicate(true)
	# Older releases also used the `cannon` id. Keep those saves compatible while
	# guaranteeing that a unit now sold as the Heavy Cannon receives its current
	# player-only damage floor instead of retaining the former ordinary-cannon stat.
	if loaded_type == "cannon":
		var cannon_combat: Dictionary = GameConfig.SOLDIERS["cannon"]["combat"]
		var saved_level := maxi(1, int(player.get("level", 1)))
		var current_damage_floor := float(cannon_combat["attack"]) * (1.0 + 0.015 * float(saved_level - 1))
		loaded_soldier["attack"] = maxf(float(loaded_soldier.get("attack", 0.0)), current_damage_floor)


func _is_valid_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var schema := int(data.get("schema", 0))
	if schema < 1 or schema > SAVE_SCHEMA:
		return false
	if data.has("world_seed") and typeof(data["world_seed"]) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if schema >= 4 and (not data.has("boss_lair_state") or not data.has("boss") or not data.has("snake_nests")):
		return false
	if schema >= 5 and (not data.has("chaos_boss") or not data.has("progression")):
		return false
	if schema >= 6 and not data.has("aionis_boss"):
		return false
	if schema >= 7 and (not data.has("soldier_research") or typeof(data["soldier_research"]) != TYPE_DICTIONARY):
		return false
	if schema >= 8 and not SoldierUpgradeCatalog.research_is_valid(data.get("soldier_research", {})):
		return false
	if schema >= 5:
		if typeof(data["progression"]) != TYPE_DICTIONARY or typeof(data["chaos_boss"]) != TYPE_DICTIONARY:
			return false
		var saved_progression: Dictionary = data["progression"]
		for progress_flag in ["final_boss_defeated", "ending_seen", "all_soldiers_unlocked"]:
			if typeof(saved_progression.get(progress_flag)) != TYPE_BOOL:
				return false
		# 重新召喚會讓本輪 Boss 回到存活狀態，但玩家已看過結局且永久解鎖仍保留。
		if bool(saved_progression["ending_seen"]) and not bool(saved_progression["final_boss_defeated"]) and not bool(saved_progression["all_soldiers_unlocked"]):
			return false
		if bool(saved_progression["final_boss_defeated"]) and not bool(saved_progression["all_soldiers_unlocked"]):
			return false
		if not _is_valid_saved_chaos_boss(data["chaos_boss"], bool(saved_progression["final_boss_defeated"])):
			return false
		if schema >= 6:
			if typeof(data["aionis_boss"]) != TYPE_DICTIONARY:
				return false
			for progress_flag in ["timeless_gate_unlocked", "aionis_defeated", "kaeron_ending_completed"]:
				if typeof(saved_progression.get(progress_flag)) != TYPE_BOOL:
					return false
			var gate_unlocked := bool(saved_progression["timeless_gate_unlocked"])
			var saved_aionis: Dictionary = data["aionis_boss"]
			if not gate_unlocked:
				if not saved_aionis.is_empty() or bool(saved_progression["aionis_defeated"]):
					return false
			elif not _is_valid_saved_aionis_boss(saved_aionis, bool(saved_progression["aionis_defeated"])):
				return false
	if typeof(data.get("player")) != TYPE_DICTIONARY:
		return false
	var saved_player: Dictionary = data["player"]
	var class_id := str(saved_player.get("class_id", ""))
	if not GameConfig.HERO_CLASSES.has(class_id):
		return false
	if typeof(saved_player.get("pos")) != TYPE_VECTOR2 or typeof(saved_player.get("facing")) != TYPE_VECTOR2:
		return false
	for number_key in ["hp", "max_hp", "attack", "defense", "speed", "level", "xp", "xp_need", "money", "attack_cd", "special_cd", "invuln", "skill_points", "kills", "captured"]:
		if typeof(saved_player.get(number_key)) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	if saved_player.has("hit_grace") and typeof(saved_player["hit_grace"]) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if typeof(saved_player.get("upgrades")) != TYPE_DICTIONARY or typeof(saved_player.get("dash_hit")) != TYPE_DICTIONARY:
		return false
	if float(saved_player["max_hp"]) <= 0.0 or int(saved_player["level"]) < 1:
		return false
	for array_key in ["enemies", "soldiers", "tombstones", "drops", "discovered", "spawned"]:
		if data.has(array_key) and typeof(data[array_key]) != TYPE_ARRAY:
			return false
	for dictionary_key in ["castles", "camps", "snake_nests", "boss_lair_state", "command", "settings", "chunk_states", "pending_chunk_spawns"]:
		if data.has(dictionary_key) and typeof(data[dictionary_key]) != TYPE_DICTIONARY:
			return false
	if data.has("command"):
		var saved_command: Dictionary = data["command"]
		if saved_command.has("mode") and typeof(saved_command["mode"]) != TYPE_STRING:
			return false
		if saved_command.has("point") and typeof(saved_command["point"]) != TYPE_VECTOR2:
			return false
		if saved_command.has("target_id") and typeof(saved_command["target_id"]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if saved_command.has("castle_id") and typeof(saved_command["castle_id"]) != TYPE_STRING:
			return false
	var saved_lair_binding := _resolve_saved_python_boss_lair_binding(data)
	if not bool(saved_lair_binding.get("valid", false)):
		return false
	var saved_boss_home := Vector2(saved_lair_binding.get("home", GameConfig.PYTHON_BOSS_CONFIG["home_position"]))
	if data.has("boss") and not _is_valid_saved_boss(data["boss"], saved_boss_home):
		return false
	if schema >= 4:
		var saved_boss: Dictionary = Dictionary(data["boss"])
		var binding_cleared := bool(saved_lair_binding.get("cleared", false))
		var saved_defeated := bool(saved_boss.get("defeated", false))
		if binding_cleared != saved_defeated or bool(saved_boss.get("nest_cleared", false)) != saved_defeated or bool(saved_boss.get("reward_claimed", false)) != saved_defeated:
			return false
	for entry in data.get("enemies", []):
		if not _is_valid_saved_enemy(entry): return false
	for entry in data.get("soldiers", []):
		if not _is_valid_saved_soldier(entry, schema): return false
	for entry in data.get("tombstones", []):
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("pos")) != TYPE_VECTOR2 or not GameConfig.SOLDIERS.has(str(entry.get("type", ""))): return false
	for entry in data.get("drops", []):
		if typeof(entry) != TYPE_DICTIONARY or typeof(entry.get("pos")) != TYPE_VECTOR2 or not _dictionary_has_numbers(entry, ["gold", "xp", "ttl"]): return false
	for castle in Dictionary(data.get("castles", {})).values():
		if typeof(castle) != TYPE_DICTIONARY or typeof(castle.get("pos")) != TYPE_VECTOR2: return false
		if not _dictionary_has_numbers(castle, ["hp", "max_hp", "level", "capture", "income_timer", "spawn_timer", "tower_cd", "under_attack"]): return false
		if typeof(castle.get("owned")) != TYPE_BOOL or typeof(castle.get("destroyed")) != TYPE_BOOL: return false
	for camp in Dictionary(data.get("camps", {})).values():
		if typeof(camp) != TYPE_DICTIONARY or typeof(camp.get("pos")) != TYPE_VECTOR2: return false
		if not _dictionary_has_numbers(camp, ["level", "crate_hp", "respawn_at"]): return false
		if typeof(camp.get("cleared")) != TYPE_BOOL or typeof(camp.get("spawned")) != TYPE_BOOL: return false
	for nest in Dictionary(data.get("snake_nests", {})).values():
		if typeof(nest) != TYPE_DICTIONARY or typeof(nest.get("pos")) != TYPE_VECTOR2: return false
		if typeof(nest.get("id")) != TYPE_STRING or typeof(nest.get("level")) not in [TYPE_INT, TYPE_FLOAT]: return false
		if nest.has("discovered") and typeof(nest["discovered"]) != TYPE_BOOL: return false
		if nest.has("cleared") and typeof(nest["cleared"]) != TYPE_BOOL: return false
	for stored_entries in Dictionary(data.get("chunk_states", {})).values():
		if typeof(stored_entries) != TYPE_ARRAY: return false
		for stored_enemy in stored_entries:
			if not _is_valid_saved_enemy(stored_enemy): return false
	for pending_entries in Dictionary(data.get("pending_chunk_spawns", {})).values():
		if typeof(pending_entries) != TYPE_ARRAY: return false
		for pending_enemy in pending_entries:
			if typeof(pending_enemy) != TYPE_DICTIONARY or typeof(pending_enemy.get("position")) != TYPE_VECTOR2 or not GameConfig.ENEMIES.has(str(pending_enemy.get("type", ""))): return false
			if typeof(pending_enemy.get("level")) not in [TYPE_INT, TYPE_FLOAT]: return false
	return true


func _is_valid_saved_boss(value: Variant, boss_home: Vector2 = Vector2(2400.0, 1440.0)) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var boss: Dictionary = value
	for flag_key in ["discovered", "defeated", "nest_cleared", "reward_claimed"]:
		if typeof(boss.get(flag_key)) != TYPE_BOOL:
			return false
	if typeof(boss.get("position")) != TYPE_VECTOR2:
		return false
	var boss_position: Vector2 = boss["position"]
	var saved_position_limit := float(GameConfig.PYTHON_BOSS_CONFIG["base"]["leash_distance"]) + 1.0
	# A legal dash may cross the leash during the final movement frame, after the
	# controller's pre-update leash check but before autosave. Engaged saves are
	# always restored safely at the selected lair home, so accept that bounded
	# one-skill overshoot instead of making a naturally created save unloadable.
	if bool(boss.get("engaged", false)) or bool(boss.get("defeated", false)):
		saved_position_limit += float(GameConfig.PYTHON_BOSS_CONFIG["skills"]["dash"]["max_distance"]) + float(GameConfig.PYTHON_BOSS_CONFIG["body"]["head_radius"]) * 2.0
	if not boss_position.is_finite() or boss_position.distance_to(boss_home) > saved_position_limit:
		return false
	if not _dictionary_has_numbers(boss, ["hp", "phase", "respawn_at"]):
		return false
	var max_scaled_hp: float = float(GameConfig.PYTHON_BOSS_CONFIG["base"]["max_hp"]) * (
		1.0
		+ float(GameConfig.PYTHON_BOSS_CONFIG["scaling"]["max_world_tier"]) * float(GameConfig.PYTHON_BOSS_CONFIG["scaling"]["world_tier_hp"])
		+ float(GameConfig.PYTHON_BOSS_CONFIG["scaling"]["max_player_level_bonus"]) * float(GameConfig.PYTHON_BOSS_CONFIG["scaling"]["player_level_hp"])
	)
	if float(boss["hp"]) < 0.0 or float(boss["hp"]) > max_scaled_hp or int(boss["phase"]) < 1 or int(boss["phase"]) > 3 or float(boss["respawn_at"]) < -1.0:
		return false
	if boss.has("engaged") and typeof(boss["engaged"]) != TYPE_BOOL:
		return false
	for optional_number in ["version", "rng_state", "world_tier", "player_level", "pending_phase"]:
		if boss.has(optional_number) and typeof(boss[optional_number]) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	if boss.has("version") and (int(boss["version"]) < 1 or int(boss["version"]) > int(PythonBossControllerScript.SAVE_VERSION)):
		return false
	if boss.has("world_tier") and (int(boss["world_tier"]) < 0 or int(boss["world_tier"]) > int(GameConfig.PYTHON_BOSS_CONFIG["scaling"]["max_world_tier"])):
		return false
	if boss.has("player_level") and (int(boss["player_level"]) < 1 or int(boss["player_level"]) > 999):
		return false
	if boss.has("pending_phase") and (int(boss["pending_phase"]) < 0 or int(boss["pending_phase"]) > 3):
		return false
	return true


func _is_valid_saved_chaos_boss(value: Variant, expected_defeated: bool) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var saved: Dictionary = value
	if not _dictionary_has_numbers(saved, ["version", "state", "phase", "hp", "max_hp", "radius", "player_level", "seed", "rng_state", "state_timer"]):
		return false
	for flag in ["engaged", "reward_given", "defeated"]:
		if typeof(saved.get(flag)) != TYPE_BOOL:
			return false
	if typeof(saved.get("position")) != TYPE_VECTOR2 or typeof(saved.get("home_position")) != TYPE_VECTOR2 or typeof(saved.get("cooldowns")) != TYPE_DICTIONARY:
		return false
	if int(saved["version"]) != int(ChaosBossControllerScript.SAVE_VERSION):
		return false
	if int(saved["state"]) < 0 or int(saved["state"]) > 5 or int(saved["phase"]) < 0 or int(saved["phase"]) > 2:
		return false
	if float(saved["max_hp"]) <= 0.0 or float(saved["max_hp"]) > 120000.0 or float(saved["hp"]) < 0.0 or float(saved["hp"]) > float(saved["max_hp"]):
		return false
	var home := Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"])
	if not Vector2(saved["position"]).is_finite() or Vector2(saved["position"]).distance_to(home) > float(GameConfig.CHAOS_BOSS_CONFIG["leash_distance"]) + 480.0:
		return false
	if bool(saved["defeated"]) != expected_defeated:
		return false
	if expected_defeated and (float(saved["hp"]) > 0.0 or not bool(saved["reward_given"])):
		return false
	return true


func _is_valid_saved_aionis_boss(value: Variant, expected_defeated: bool) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var saved: Dictionary = value
	if not _dictionary_has_numbers(saved, ["version", "state", "phase", "hp", "max_hp", "radius", "player_level", "seed", "rng_state", "state_timer", "anchor_breach_timer"]):
		return false
	for flag in ["reward_given", "defeated", "telegraph_warning_announced"]:
		if typeof(saved.get(flag)) != TYPE_BOOL:
			return false
	if typeof(saved.get("position")) != TYPE_VECTOR2 or typeof(saved.get("home_position")) != TYPE_VECTOR2 or typeof(saved.get("telegraph_position")) != TYPE_VECTOR2:
		return false
	if typeof(saved.get("cooldowns")) != TYPE_DICTIONARY or typeof(saved.get("combo_queue")) != TYPE_ARRAY or typeof(saved.get("time_anchors")) != TYPE_ARRAY:
		return false
	if int(saved["version"]) != int(AionisBossControllerScript.SAVE_VERSION):
		return false
	var state := int(saved["state"])
	if state < 0 or state > 5 or int(saved["phase"]) < 0 or int(saved["phase"]) > 3:
		return false
	var max_hp := float(saved["max_hp"])
	var hp := float(saved["hp"])
	if not is_finite(max_hp) or not is_finite(hp) or max_hp <= 0.0 or max_hp > 260000.0 or hp < 0.0 or hp > max_hp:
		return false
	var home := Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"])
	if not Vector2(saved["home_position"]).is_finite() or Vector2(saved["home_position"]).distance_to(home) > 1.0:
		return false
	if not Vector2(saved["position"]).is_finite() or Vector2(saved["position"]).distance_to(home) > float(GameConfig.AIONIS_BOSS_CONFIG["leash_distance"]) + 480.0:
		return false
	if bool(saved["defeated"]) != expected_defeated:
		return false
	if expected_defeated:
		if state != 5 or hp > 0.0 or not bool(saved["reward_given"]):
			return false
	elif state == 5 or hp <= 0.0 or bool(saved["reward_given"]):
		return false
	var cooldowns: Dictionary = saved["cooldowns"]
	for skill_id in AionisBossControllerScript.SKILL_IDS:
		if typeof(cooldowns.get(skill_id)) not in [TYPE_INT, TYPE_FLOAT] or float(cooldowns[skill_id]) < 0.0 or not is_finite(float(cooldowns[skill_id])):
			return false
	var telegraph_skill := str(saved.get("telegraph_skill", ""))
	if not telegraph_skill.is_empty() and telegraph_skill not in AionisBossControllerScript.SKILL_IDS:
		return false
	for queued_skill in Array(saved["combo_queue"]):
		if typeof(queued_skill) != TYPE_STRING or str(queued_skill) not in AionisBossControllerScript.SKILL_IDS:
			return false
	var anchors: Array = saved["time_anchors"]
	if anchors.size() != 4:
		return false
	var anchor_ids := {}
	for item in anchors:
		if typeof(item) != TYPE_DICTIONARY:
			return false
		var anchor: Dictionary = item
		var anchor_id := str(anchor.get("id", ""))
		if anchor_id.is_empty() or anchor_ids.has(anchor_id):
			return false
		anchor_ids[anchor_id] = true
		if not _dictionary_has_numbers(anchor, ["x", "y", "radius", "max_hp", "hp"]):
			return false
		if typeof(anchor.get("broken")) != TYPE_BOOL:
			return false
		var anchor_pos := Vector2(float(anchor["x"]), float(anchor["y"]))
		var anchor_max := float(anchor["max_hp"])
		var anchor_hp := float(anchor["hp"])
		if not anchor_pos.is_finite() or anchor_pos.distance_to(home) > 520.0 or anchor_max <= 0.0 or anchor_hp < 0.0 or anchor_hp > anchor_max:
			return false
		if bool(anchor["broken"]) != (anchor_hp <= 0.0):
			return false
	return true


func _dictionary_has_numbers(value: Dictionary, keys: Array) -> bool:
	for key in keys:
		if typeof(value.get(key)) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	return true


func _is_valid_saved_enemy(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var enemy: Dictionary = value
	var base_valid := (
		GameConfig.ENEMIES.has(str(enemy.get("type", "")))
		and typeof(enemy.get("pos")) == TYPE_VECTOR2
		and typeof(enemy.get("home")) == TYPE_VECTOR2
		and _dictionary_has_numbers(enemy, ["id", "hp", "max_hp", "attack", "defense", "speed", "radius"])
	)
	if not base_valid:
		return false
	if enemy.has("enhancement") and not EnemyEnhancementCatalog.is_valid_roll(enemy["enhancement"]):
		return false
	return true


func _is_valid_saved_soldier(value: Variant, schema: int = 1) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var soldier: Dictionary = value
	var type_id := str(soldier.get("type", ""))
	var base_valid := (
		GameConfig.SOLDIERS.has(type_id)
		and typeof(soldier.get("pos")) == TYPE_VECTOR2
		and _dictionary_has_numbers(soldier, ["id", "hp", "max_hp", "attack", "defense", "speed", "radius"])
	)
	if not base_valid:
		return false
	if schema >= 8 and not soldier.has("upgrade_snapshot"):
		return false
	if soldier.has("upgrade_snapshot") and not _is_valid_saved_soldier_snapshot(soldier["upgrade_snapshot"], type_id, schema >= 8):
		return false
	for runtime_key in ["special_runtime", "upgrade_cooldowns", "upgrade_counters"]:
		if schema >= 8 and not soldier.has(runtime_key):
			return false
		if soldier.has(runtime_key):
			if typeof(soldier[runtime_key]) != TYPE_DICTIONARY or not _dictionary_has_finite_scalar_values(Dictionary(soldier[runtime_key])):
				return false
	return true


func _is_valid_saved_soldier_snapshot(value: Variant, type_id: String, strict_map: bool) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var snapshot: Dictionary = value
	if typeof(snapshot.get("type")) != TYPE_STRING or str(snapshot.get("type", "")) != type_id:
		return false
	if typeof(snapshot.get("base_effects")) != TYPE_DICTIONARY or not _is_valid_snapshot_base_effects(Dictionary(snapshot["base_effects"])):
		return false
	if typeof(snapshot.get("active_specials")) != TYPE_ARRAY:
		return false
	if strict_map and typeof(snapshot.get("special_effects")) != TYPE_DICTIONARY:
		return false
	if snapshot.has("special_effects") and typeof(snapshot["special_effects"]) != TYPE_DICTIONARY:
		return false

	var active_ids: Dictionary = {}
	for entry_value in Array(snapshot["active_specials"]):
		if typeof(entry_value) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = entry_value
		var ability_id := str(entry.get("id", ""))
		if active_ids.has(ability_id) or not SoldierUpgradeCatalog.is_compatible(type_id, ability_id):
			return false
		var rank_value: Variant = entry.get("rank")
		if not _is_integral_save_number(rank_value):
			return false
		var rank := int(rank_value)
		if rank < 1 or rank > SoldierUpgradeCatalog.max_rank(ability_id) or typeof(entry.get("effect")) != TYPE_DICTIONARY:
			return false
		active_ids[ability_id] = true

	var mapped_ids: Dictionary = {}
	for ability_key in Dictionary(snapshot.get("special_effects", {})).keys():
		var ability_id := str(ability_key)
		if mapped_ids.has(ability_id) or not SoldierUpgradeCatalog.is_compatible(type_id, ability_id):
			return false
		if typeof(Dictionary(snapshot["special_effects"])[ability_key]) != TYPE_DICTIONARY:
			return false
		mapped_ids[ability_id] = true
	if strict_map and mapped_ids != active_ids:
		return false
	return true


func _is_valid_snapshot_base_effects(effects: Dictionary) -> bool:
	for effect_key in effects.keys():
		var effect_value: Variant = effects[effect_key]
		if str(effect_key) == "critical_mode":
			if typeof(effect_value) != TYPE_STRING or str(effect_value) not in ["damage", "healing"]:
				return false
			continue
		if typeof(effect_value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(effect_value)):
			return false
	return true


func _dictionary_has_finite_scalar_values(value: Dictionary, numbers_only: bool = false) -> bool:
	for entry_value in value.values():
		if typeof(entry_value) in [TYPE_INT, TYPE_FLOAT]:
			if not is_finite(float(entry_value)):
				return false
		elif numbers_only or typeof(entry_value) != TYPE_BOOL:
			return false
	return true


func _is_integral_save_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and is_equal_approx(number, roundf(number))


func _handle_ui_click(position: Vector2) -> bool:
	if mode in [GameMode.TITLE, GameMode.CLASS_SELECT] and _language_toggle_rect().has_point(position):
		_toggle_language()
		audio.play("ui", 0.45)
		return true
	if active_panel == "confirm_restart":
		var confirm_center := screen_size * 0.5
		if Rect2(confirm_center.x - 125, confirm_center.y + 42, 115, 44).has_point(position):
			_enter_class_select(true)
			return true
		if Rect2(confirm_center.x + 10, confirm_center.y + 42, 115, 44).has_point(position):
			active_panel = ""
			return true
		return true
	if mode == GameMode.TITLE:
		var center := screen_size * 0.5
		if Rect2(center + Vector2(-140, 55), Vector2(280, 54)).has_point(position):
			# Touch browsers can emit a compatibility mouse press before the real
			# screen-touch event. Consume that same physical press on the next screen
			# so the centered Mage card is never chosen automatically.
			_enter_class_select(true)
			return true
		if GameSaveManager.has_save() and Rect2(center + Vector2(-140, 120), Vector2(280, 48)).has_point(position):
			_load_game()
			return true
		return false
	if mode == GameMode.CLASS_SELECT:
		if _class_select_pointer_is_guarded():
			return true
		var card_width: float = min(330.0, (screen_size.x - 110.0) / 3.0)
		var total: float = card_width * 3.0 + 24.0 * 2.0
		var start_x: float = (screen_size.x - total) * 0.5
		for i in 3:
			var rect := Rect2(start_x + i * (card_width + 24.0), screen_size.y * 0.24, card_width, min(430.0, screen_size.y * 0.62))
			if rect.has_point(position):
				var selected_class := str(["archer", "mage", "warrior"][i])
				if class_change_pending:
					_change_player_class(selected_class)
				else:
					_start_new_game(selected_class)
				return true
		return false
	if mode == GameMode.PAUSED:
		var pause_actions := _pause_actions()
		for index in pause_actions.size():
			var action: String = str(pause_actions[index])
			if _pause_button_rect(index).has_point(position):
				match action:
					"resume": mode = GameMode.PLAYING
					"save": _save_game()
					"load": _load_game()
					"summon_chaos": _summon_chaos_boss()
					"summon_aionis": _summon_aionis_boss()
					"restart": active_panel = "confirm_restart"
				audio.play("ui", 0.55)
				return true
		if _pause_language_rect().has_point(position):
			_toggle_language()
			audio.play("ui", 0.45)
			return true
		if _pause_volume_rect("down").has_point(position):
			master_volume = max(0.0, master_volume - 0.1)
			return true
		if _pause_volume_rect("up").has_point(position):
			master_volume = min(1.0, master_volume + 0.1)
			return true
		if _pause_volume_rect("mute").has_point(position):
			sound_muted = not sound_muted
			return true
	if mode != GameMode.PLAYING:
		return false
	if not _is_touch_scheme() and _notification_toggle_rect().has_point(position):
		_toggle_notifications()
		audio.play("ui", 0.45)
		return true
	if not _is_touch_scheme() and _cheat_toggle_rect().has_point(position):
		_open_cheat_input()
		audio.play("ui", 0.45)
		return true
	if not _is_touch_scheme() and _soldier_upgrade_toggle_rect().has_point(position):
		active_panel = "" if active_panel == "soldier_upgrades" else "soldier_upgrades"
		soldier_upgrade_page = 0
		audio.play("ui", 0.45)
		queue_redraw()
		return true
	if active_panel == "command":
		var command_panel := _command_panel_rect()
		if not command_panel.has_point(position):
			return false
		var commands := ["跟隨", "防守", "攻擊", "撤退", "駐守", "攻城"]
		for command_index in commands.size():
			if _command_button_rect(command_index, command_panel).has_point(position):
				_set_soldier_command(str(commands[command_index]))
				return true
		return true
	if active_panel == "skills":
		var panel := _skills_panel_rect()
		if not panel.has_point(position): return false
		var stats := ["attack", "defense", "max_hp", "speed", "attack_speed"]
		for i in stats.size():
			var plus_rect := Rect2(panel.end.x - 72, panel.position.y + 78 + i * 53, 42, 36)
			var plus_hit := Rect2(panel.end.x - 106.0, panel.position.y + 72.0 + float(i) * 53.0, 92.0, 52.0) if _is_touch_scheme() else plus_rect
			if plus_hit.has_point(position):
				_upgrade_stat(stats[i])
				return true
		return true
	if active_panel == "recruit":
		var panel := _recruit_panel_rect()
		if not panel.has_point(position): return false
		var roster := _recruitable_soldier_order()
		for i in roster.size():
			var buy_rect := _recruit_buy_rect(i, panel)
			var buy_hit := buy_rect
			if buy_hit.has_point(position):
				var recruit_type := str(roster[i])
				var purchase_msec := Time.get_ticks_msec()
				# Godot Web can emit a touch press and its compatibility mouse press for
				# the same physical tap. Debounce only the same recruit button, keeping
				# different UI actions responsive and preventing accidental double charges.
				if recruit_type == last_recruit_purchase_type and purchase_msec - last_recruit_purchase_msec < 350:
					return true
				last_recruit_purchase_type = recruit_type
				last_recruit_purchase_msec = purchase_msec
				_recruit_soldier(recruit_type, 5 if Input.is_key_pressed(KEY_SHIFT) else 1)
				return true
		return true
	if active_panel == "soldier_upgrades":
		var upgrade_panel := _soldier_upgrade_panel_rect()
		if not upgrade_panel.has_point(position):
			return false
		var controls := _soldier_upgrade_control_rects(upgrade_panel)
		if Rect2(controls["type_prev"]).has_point(position):
			_cycle_soldier_upgrade_type(-1)
			return true
		if Rect2(controls["type_next"]).has_point(position):
			_cycle_soldier_upgrade_type(1)
			return true
		if Rect2(controls["base_tab"]).has_point(position):
			soldier_upgrade_category = "base"
			soldier_upgrade_page = 0
			audio.play("ui", 0.4)
			return true
		if Rect2(controls["special_tab"]).has_point(position):
			soldier_upgrade_category = "special"
			soldier_upgrade_page = 0
			audio.play("ui", 0.4)
			return true
		if Rect2(controls["page_prev"]).has_point(position):
			soldier_upgrade_page = maxi(0, soldier_upgrade_page - 1)
			audio.play("ui", 0.35)
			return true
		if Rect2(controls["page_next"]).has_point(position):
			var page_count := _soldier_upgrade_page_count(upgrade_panel)
			soldier_upgrade_page = mini(maxi(0, page_count - 1), soldier_upgrade_page + 1)
			audio.play("ui", 0.35)
			return true
		var selected_type := _selected_soldier_upgrade_type()
		var option_ids := _soldier_upgrade_option_ids(selected_type)
		var rows_per_page := _soldier_upgrade_rows_per_page(upgrade_panel)
		var first_index := soldier_upgrade_page * rows_per_page
		for row_index in rows_per_page:
			var option_index := first_index + row_index
			if option_index >= option_ids.size():
				break
			if _soldier_upgrade_row_rect(row_index, upgrade_panel).has_point(position):
				_purchase_soldier_upgrade(selected_type, str(option_ids[option_index]))
				return true
		return true
	if active_panel == "map":
		return _map_panel_rect().has_point(position)
	return false


func _skills_panel_rect() -> Rect2:
	return Rect2(max(24.0, screen_size.x * 0.5 - 320.0), max(34.0, screen_size.y * 0.5 - 240.0), min(640.0, screen_size.x - 48.0), min(480.0, screen_size.y - 68.0))


func _soldier_upgrade_panel_rect() -> Rect2:
	var scale := touch_ui_coordinate_scale if _is_touch_scheme() else 1.0
	var margin := (12.0 if _is_touch_scheme() else 24.0) * scale
	var width := minf(920.0 * scale, screen_size.x - margin * 2.0)
	var height := minf(620.0 * scale, screen_size.y - margin * 2.0)
	return Rect2((screen_size.x - width) * 0.5, (screen_size.y - height) * 0.5, width, height)


func _selected_soldier_upgrade_type() -> String:
	if SoldierUpgradeCatalog.SOLDIER_ORDER.is_empty():
		return ""
	soldier_upgrade_type_index = posmod(soldier_upgrade_type_index, SoldierUpgradeCatalog.SOLDIER_ORDER.size())
	return str(SoldierUpgradeCatalog.SOLDIER_ORDER[soldier_upgrade_type_index])


func _soldier_type_is_unlocked(type_id: String) -> bool:
	return GameConfig.SOLDIERS.has(type_id) and (not _is_chaos_unlock_soldier(type_id) or all_soldiers_unlocked)


func _cycle_soldier_upgrade_type(direction: int) -> void:
	soldier_upgrade_type_index = posmod(soldier_upgrade_type_index + direction, SoldierUpgradeCatalog.SOLDIER_ORDER.size())
	soldier_upgrade_page = 0
	audio.play("ui", 0.4)
	queue_redraw()


func _soldier_upgrade_control_rects(panel: Rect2) -> Dictionary:
	if _is_touch_scheme():
		var scale := touch_ui_coordinate_scale
		var touch_tab_gap := 8.0 * scale
		var touch_tab_width := (panel.size.x - 36.0 * scale - touch_tab_gap) * 0.5
		return {
			"type_prev": Rect2(panel.position.x + 18.0 * scale, panel.position.y + 43.0 * scale, 62.0 * scale, 46.0 * scale),
			"type_next": Rect2(panel.end.x - 150.0 * scale, panel.position.y + 43.0 * scale, 62.0 * scale, 46.0 * scale),
			"base_tab": Rect2(panel.position.x + 18.0 * scale, panel.position.y + 94.0 * scale, touch_tab_width, 44.0 * scale),
			"special_tab": Rect2(panel.position.x + 18.0 * scale + touch_tab_width + touch_tab_gap, panel.position.y + 94.0 * scale, touch_tab_width, 44.0 * scale),
			"page_prev": Rect2(panel.position.x + 18.0 * scale, panel.end.y - 52.0 * scale, 108.0 * scale, 44.0 * scale),
			"page_next": Rect2(panel.end.x - 126.0 * scale, panel.end.y - 52.0 * scale, 108.0 * scale, 44.0 * scale),
		}
	var side_width := 54.0
	var type_y := panel.position.y + 46.0
	var tab_y := panel.position.y + 92.0
	var tab_gap := 8.0
	var tab_width := (panel.size.x - 36.0 - tab_gap) * 0.5
	return {
		"type_prev": Rect2(panel.position.x + 18.0, type_y, side_width, 40.0),
		"type_next": Rect2(panel.end.x - 72.0, type_y, side_width, 40.0),
		"base_tab": Rect2(panel.position.x + 18.0, tab_y, tab_width, 34.0),
		"special_tab": Rect2(panel.position.x + 18.0 + tab_width + tab_gap, tab_y, tab_width, 34.0),
		"page_prev": Rect2(panel.position.x + 18.0, panel.end.y - 40.0, 94.0, 32.0),
		"page_next": Rect2(panel.end.x - 112.0, panel.end.y - 40.0, 94.0, 32.0),
	}


func _soldier_upgrade_rows_per_page(panel: Rect2) -> int:
	if _is_touch_scheme():
		var scale := touch_ui_coordinate_scale
		return maxi(2, floori((panel.size.y / scale - 210.0) / 60.0))
	return maxi(2, floori((panel.size.y - 176.0) / 58.0))


func _soldier_upgrade_row_rect(row_index: int, panel: Rect2) -> Rect2:
	var scale := touch_ui_coordinate_scale if _is_touch_scheme() else 1.0
	var start_y := (144.0 if _is_touch_scheme() else 134.0) * scale
	return Rect2(panel.position.x + 18.0 * scale, panel.position.y + start_y + float(row_index) * 60.0 * scale, panel.size.x - 36.0 * scale, 54.0 * scale)


func _soldier_upgrade_option_ids(type_id: String) -> Array[String]:
	if soldier_upgrade_category == "special":
		return SoldierUpgradeCatalog.compatible_special_ids(type_id)
	return SoldierUpgradeCatalog.compatible_base_ids(type_id)


func _soldier_upgrade_page_count(panel: Rect2) -> int:
	var options := _soldier_upgrade_option_ids(_selected_soldier_upgrade_type())
	return maxi(1, ceili(float(options.size()) / float(_soldier_upgrade_rows_per_page(panel))))


func _command_panel_rect() -> Rect2:
	var panel_width := minf(720.0, screen_size.x - 32.0)
	var panel_height := minf(330.0, screen_size.y - 32.0)
	return Rect2(screen_size * 0.5 - Vector2(panel_width, panel_height) * 0.5, Vector2(panel_width, panel_height))


func _command_button_rect(index: int, panel: Rect2) -> Rect2:
	var column := index % 3
	var row := int(index / 3)
	var gap := 12.0
	var side := 18.0
	var top := 78.0
	var width := (panel.size.x - side * 2.0 - gap * 2.0) / 3.0
	var height := (panel.size.y - top - side - gap) / 2.0
	return Rect2(panel.position + Vector2(side + float(column) * (width + gap), top + float(row) * (height + gap)), Vector2(width, height))


func _recruit_panel_rect() -> Rect2:
	if _is_touch_scheme():
		var scale := touch_ui_coordinate_scale
		var css_size := screen_size / scale
		var touch_width := minf(780.0, maxf(320.0, css_size.x - 24.0)) * scale
		var touch_height := minf(500.0, maxf(240.0, css_size.y - 24.0)) * scale
		return Rect2((screen_size.x - touch_width) * 0.5, (screen_size.y - touch_height) * 0.5, touch_width, touch_height)
	return Rect2(max(20.0, screen_size.x * 0.5 - 390.0), max(24.0, screen_size.y * 0.5 - 250.0), min(780.0, screen_size.x - 40.0), min(500.0, screen_size.y - 48.0))


func _recruit_item_rect(index: int, panel: Rect2) -> Rect2:
	var roster_size := _recruitable_soldier_order().size()
	var columns := 3 if roster_size > 12 else 2
	var rows_per_column := ceili(float(roster_size) / float(columns))
	var column := floori(float(index) / float(rows_per_column))
	var row := index % rows_per_column
	var scale := touch_ui_coordinate_scale if _is_touch_scheme() else 1.0
	var side_margin := 18.0 * scale
	var column_gap := 12.0 * scale
	var column_width := (panel.size.x - side_margin * 2.0 - column_gap * float(columns - 1)) / float(columns)
	var list_top := (62.0 if _is_touch_scheme() else 78.0) * scale
	var row_pitch := minf(65.0 * scale, (panel.size.y - list_top - 12.0 * scale) / float(rows_per_column))
	return Rect2(
		panel.position.x + side_margin + float(column) * (column_width + column_gap),
		panel.position.y + list_top + float(row) * row_pitch,
		column_width,
		maxf((44.0 if _is_touch_scheme() else 34.0) * scale, row_pitch - (2.0 if _is_touch_scheme() else 4.0) * scale)
	)


func _recruit_buy_rect(index: int, panel: Rect2) -> Rect2:
	var item := _recruit_item_rect(index, panel)
	var scale := touch_ui_coordinate_scale if _is_touch_scheme() else 1.0
	var button_height := minf((44.0 if _is_touch_scheme() else 36.0) * scale, item.size.y)
	var button_width := (72.0 if _is_touch_scheme() else 67.0) * scale
	return Rect2(item.end.x - (8.0 * scale + button_width), item.position.y + (item.size.y - button_height) * 0.5, button_width, button_height)


func _map_panel_rect() -> Rect2:
	return Rect2(max(30.0, screen_size.x * 0.5 - 360.0), max(30.0, screen_size.y * 0.5 - 275.0), min(720.0, screen_size.x - 60.0), min(550.0, screen_size.y - 60.0))


func _pause_language_rect() -> Rect2:
	if _is_touch_scheme():
		var panel := _pause_panel_rect()
		var scale := touch_ui_coordinate_scale
		return Rect2(panel.get_center().x - 110.0 * scale, panel.position.y + 206.0 * scale, 220.0 * scale, 44.0 * scale)
	var center := screen_size * 0.5
	return Rect2(center.x - 78.0, center.y + 139.0, 156.0, 42.0)


func _pause_can_summon_chaos_boss() -> bool:
	return all_soldiers_unlocked and chaos_boss != null and chaos_boss.is_defeated()


func _pause_can_summon_aionis_boss() -> bool:
	return timeless_gate_unlocked and aionis_boss != null and aionis_boss.is_defeated()


func _pause_actions() -> Array[String]:
	var actions: Array[String] = ["resume", "save", "load"]
	if _pause_can_summon_chaos_boss():
		actions.append("summon_chaos")
	if _pause_can_summon_aionis_boss():
		actions.append("summon_aionis")
	actions.append("restart")
	return actions


func _pause_panel_rect() -> Rect2:
	var center := screen_size * 0.5
	if _is_touch_scheme():
		var scale := touch_ui_coordinate_scale
		var css_size := screen_size / scale
		var panel_size := Vector2(
			minf(380.0, maxf(320.0, css_size.x - 24.0)),
			minf(366.0, maxf(320.0, css_size.y - 24.0))
		) * scale
		return Rect2(center - panel_size * 0.5, panel_size)
	return Rect2(center - Vector2(180.0, 260.0), Vector2(360.0, 520.0))


func _pause_button_rect(index: int) -> Rect2:
	var action_count := _pause_actions().size()
	if _is_touch_scheme():
		var panel := _pause_panel_rect()
		var scale := touch_ui_coordinate_scale
		var columns := 2
		var column := index % columns
		var row := index / columns
		var side := 12.0 * scale
		var gap := 6.0 * scale
		var button_width := (panel.size.x - side * 2.0 - gap) * 0.5
		return Rect2(panel.position.x + side + float(column) * (button_width + gap), panel.position.y + (44.0 + float(row) * 54.0) * scale, button_width, 48.0 * scale)
	var center := screen_size * 0.5
	var desktop_start := -136.0 if action_count >= 6 else (-108.0 if action_count >= 5 else -68.0)
	var desktop_pitch := 43.0 if action_count >= 6 else (47.0 if action_count >= 5 else 51.0)
	return Rect2(center.x - 130.0, center.y + desktop_start + float(index) * desktop_pitch, 260.0, 42.0)


func _pause_volume_rect(action: String) -> Rect2:
	if _is_touch_scheme():
		var panel := _pause_panel_rect()
		var center := panel.get_center()
		var scale := touch_ui_coordinate_scale
		var top := panel.position.y + 276.0 * scale
		match action:
			"down": return Rect2(center.x - 146.0 * scale, top, 50.0 * scale, 44.0 * scale)
			"mute": return Rect2(center.x - 90.0 * scale, top, 180.0 * scale, 44.0 * scale)
			"up": return Rect2(center.x + 96.0 * scale, top, 50.0 * scale, 44.0 * scale)
	var center := screen_size * 0.5
	match action:
		"down": return Rect2(center.x - 130.0, center.y + 214.0, 52.0, 36.0)
		"mute": return Rect2(center.x - 68.0, center.y + 214.0, 136.0, 36.0)
		"up": return Rect2(center.x + 78.0, center.y + 214.0, 52.0, 36.0)
	return Rect2()


# -----------------------------------------------------------------------------
# 程序化繪製
# -----------------------------------------------------------------------------

func _draw() -> void:
	if mode == GameMode.ENDING:
		_draw_ending_screen()
		return
	match mode:
		GameMode.TITLE:
			_draw_title_screen()
		GameMode.CLASS_SELECT:
			_draw_class_select()
		_:
			_draw_world()
			_draw_python_boss_ground_effects()
			_draw_chaos_ground_effects()
			_draw_aionis_ground_effects()
			_draw_hazards()
			_draw_upgrade_effects()
			_draw_drops_and_tombstones()
			_draw_units()
			_draw_projectiles()
			_draw_chaos_projectiles()
			_draw_aionis_projectiles()
			_draw_particles_and_floaters()
			_draw_hud()
			if mode == GameMode.PAUSED: _draw_pause_menu()
			if mode == GameMode.DEAD: _draw_death_overlay()
			if active_panel == "skills": _draw_skills_panel()
			elif active_panel == "recruit": _draw_recruit_panel()
			elif active_panel == "soldier_upgrades": _draw_soldier_upgrade_panel()
			elif active_panel == "command": _draw_command_panel()
			elif active_panel == "map": _draw_map_panel()
			elif active_panel == "confirm_restart": _draw_confirm_restart()
	if mode in [GameMode.TITLE, GameMode.CLASS_SELECT]:
		_draw_language_toggle()
	if _is_touch_scheme():
		_draw_touch_controls()
	if _needs_landscape_rotation():
		_draw_rotate_device_overlay()
	if cheat_input_active:
		_draw_cheat_overlay()


func _draw_ending_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color.BLACK)
	var state := _ending_state()
	var title_alpha := float(state.get("title_alpha", 0.0))
	var caviar_alpha := float(state.get("caviar_alpha", 0.0))
	var center := screen_size * 0.5
	if title_alpha > 0.001:
		var title_color := Color(0.94, 0.97, 1.0, title_alpha)
		var glow_color := Color(0.55, 0.30, 0.92, 0.11 * title_alpha)
		draw_circle(center, 180.0, glow_color)
		draw_line(center - Vector2(230.0, 54.0), center - Vector2(76.0, 54.0), Color(0.75, 0.62, 1.0, 0.48 * title_alpha), 2.0)
		draw_line(center + Vector2(76.0, -54.0), center + Vector2(230.0, -54.0), Color(0.75, 0.62, 1.0, 0.48 * title_alpha), 2.0)
		_draw_text("完結", center + Vector2(0.0, 18.0), 72, title_color, HORIZONTAL_ALIGNMENT_CENTER, minf(760.0, screen_size.x - 80.0))
	if caviar_alpha > 0.001:
		var avatar_size := minf(360.0, minf(screen_size.x * 0.42, screen_size.y * 0.56))
		var avatar_center := center + Vector2(0.0, 54.0)
		var avatar_rect := Rect2(avatar_center - Vector2.ONE * avatar_size * 0.5, Vector2.ONE * avatar_size)
		var pulse := 0.5 + 0.5 * sin(ending_elapsed * 2.4)
		draw_circle(avatar_center, avatar_size * (0.48 + pulse * 0.018), Color(0.24, 0.13, 0.42, (0.19 + pulse * 0.05) * caviar_alpha))
		draw_arc(avatar_center, avatar_size * 0.49, 0.0, TAU, 72, Color(0.46, 0.82, 1.0, 0.34 * caviar_alpha), 2.0)
		_draw_text("製作", avatar_center + Vector2(0.0, -avatar_size * 0.61), 34, Color(0.92, 0.95, 1.0, caviar_alpha), HORIZONTAL_ALIGNMENT_CENTER, minf(560.0, screen_size.x - 80.0))
		draw_texture_rect(CAVIAR_AVATAR_TEXTURE, avatar_rect, false, Color(1.0, 1.0, 1.0, caviar_alpha))


func _draw_cheat_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.0, 0.0, 0.64))
	var center := screen_size * 0.5
	var panel_width := minf(740.0, screen_size.x - 48.0)
	var panel_height := 250.0
	var panel := Rect2(center - Vector2(panel_width * 0.5, panel_height * 0.5), Vector2(panel_width, panel_height))
	draw_rect(panel, PANEL_BG)
	draw_rect(panel, MAGIC_PURPLE, false, 3.0)
	_draw_text("輸入作弊碼", center + Vector2(0.0, -88.0), 27, Color("F5FAFF"), HORIZONTAL_ALIGNMENT_CENTER, panel_width - 40.0)
	_draw_text("gold coins：+100000 金幣　 full upgrade：英雄滿級（不升士兵）　 change：保留進度切換職業", center + Vector2(0.0, -54.0), 14, Color("C8DBE5"), HORIZONTAL_ALIGNMENT_CENTER, panel_width - 40.0)
	_draw_text("按 Enter 確認；Esc 取消", center + Vector2(0.0, 92.0), 13, Color("91A9B8"), HORIZONTAL_ALIGNMENT_CENTER, panel_width - 40.0)


func _draw_rotate_device_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.025, 0.045, 0.06, 0.985))
	var center := screen_size * 0.5
	var phone := Rect2(center - Vector2(210.0, 112.0), Vector2(420.0, 224.0))
	draw_rect(phone, Color("142B35"))
	draw_rect(phone, Color("7FA7B8"), false, 8.0)
	draw_rect(Rect2(phone.position + Vector2(32.0, 25.0), phone.size - Vector2(64.0, 50.0)), Color("0C1720"))
	draw_circle(phone.position + Vector2(phone.size.x - 15.0, phone.size.y * 0.5), 5.5, GOLD)
	draw_arc(center, 285.0, -2.75, -0.35, 54, MAGIC_PURPLE, 10.0, true)
	var arrow_tip := center + Vector2.from_angle(-0.35) * 285.0
	_draw_polygon_shape(arrow_tip, [Vector2(24.0, 0.0), Vector2(-20.0, -18.0), Vector2(-20.0, 18.0)], -0.35, MAGIC_PURPLE, Color.TRANSPARENT, 0.0)
	_draw_text("請旋轉裝置", center + Vector2(0.0, 245.0), 72, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, minf(1000.0, screen_size.x - 80.0))
	_draw_text("橫向模式可使用雙搖桿與完整戰鬥介面", center + Vector2(0.0, 315.0), 40, Color("AFC7D6"), HORIZONTAL_ALIGNMENT_CENTER, minf(1120.0, screen_size.x - 80.0))


func _draw_title_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("0C1720"))
	for i in 12:
		var center := Vector2(screen_size.x * (0.05 + 0.09 * i), screen_size.y * (0.18 + 0.055 * sin(i * 1.9)))
		draw_circle(center, 120.0 + i * 7.0, Color(0.08, 0.23, 0.25, 0.16))
	var c := screen_size * 0.5
	_draw_flag(c + Vector2(-260, -145), FRIEND_BLUE, false, 1.5)
	_draw_flag(c + Vector2(260, -145), ENEMY_RED, true, 1.5)
	_draw_text("無盡軍勢", c + Vector2(0, -122), 54, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, 600)
	_draw_text("荒 原 遠 征", c + Vector2(0, -72), 25, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 440)
	_draw_text("程序生成的無限草原．動作戰鬥．軍隊養成．城堡征服", c + Vector2(0, -25), 18, Color("AFC7D6"), HORIZONTAL_ALIGNMENT_CENTER, 720)
	_draw_button(Rect2(c + Vector2(-140, 55), Vector2(280, 54)), "開始遠征", FRIEND_BLUE)
	if GameSaveManager.has_save():
		_draw_button(Rect2(c + Vector2(-140, 120), Vector2(280, 48)), "讀取上次進度", Color("466B76"))
	_draw_text("Enter / 點擊開始　　F 全螢幕", Vector2(c.x, screen_size.y - 42), 15, Color("7893A3"), HORIZONTAL_ALIGNMENT_CENTER, 520)


func _draw_class_select() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("101E27"))
	_draw_text("選擇新職業" if class_change_pending else "選擇你的遠征職業", Vector2(screen_size.x * 0.5, 72), 35, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, 680)
	_draw_text("金錢、等級、士兵、城池與 Boss 進度都會保留" if class_change_pending else "職業選定後可用 change 作弊碼保留進度切換", Vector2(screen_size.x * 0.5, 105), 16, Color("91A9B8"), HORIZONTAL_ALIGNMENT_CENTER, 760)
	var card_width: float = min(330.0, (screen_size.x - 110.0) / 3.0)
	var total: float = card_width * 3.0 + 24.0 * 2.0
	var start_x: float = (screen_size.x - total) * 0.5
	var ids := ["archer", "mage", "warrior"]
	for i in 3:
		var id: String = ids[i]
		var cfg: Dictionary = GameConfig.HERO_CLASSES[id]
		var rect := Rect2(start_x + i * (card_width + 24.0), screen_size.y * 0.24, card_width, min(430.0, screen_size.y * 0.62))
		draw_rect(rect, Color(0.055, 0.095, 0.12, 0.98), true)
		draw_rect(rect, Color(cfg["color"]), false, 3.0)
		_draw_character_icon(id, rect.position + Vector2(rect.size.x * 0.5, 72), 2.25)
		_draw_text("%d　%s" % [i + 1, cfg["name"]], rect.position + Vector2(rect.size.x * 0.5, 126), 25, Color("F5FAFF"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 30)
		_draw_text(str(cfg["description"]), rect.position + Vector2(20, 157), 14, Color("B7CBD7"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40)
		var stats: Dictionary = cfg["base_stats"]
		_draw_text("生命 %d　攻擊 %d　防禦 %d" % [stats["hp"], stats["attack"], stats["defense"]], rect.position + Vector2(20, 205), 14, Color("E3EEF4"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40)
		_draw_text("移速 %d　攻速 %.2f/s" % [int(float(stats["speed"]) * 1.65), float(cfg["normal_attack"]["attack_speed"])], rect.position + Vector2(20, 230), 14, Color("E3EEF4"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40)
		_draw_text("普通：%s" % cfg["normal_attack"]["name"], rect.position + Vector2(20, 270), 15, Color("9DD8FF"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40)
		_draw_text(str(cfg["normal_attack"]["description"]), rect.position + Vector2(20, 293), 13, Color("AFC4D0"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40)
		_draw_text("10 級：%s" % cfg["special_attack"]["name"], rect.position + Vector2(20, 334), 15, GOLD, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40)
		_draw_text(str(cfg["special_attack"]["description"]), rect.position + Vector2(20, 357), 13, Color("D9C991"), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 40)
		_draw_button(Rect2(rect.position + Vector2(22, rect.size.y - 57), Vector2(rect.size.x - 44, 38)), "選擇 %s" % cfg["name"], Color(cfg["color"]))


func _draw_world() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("527B4A"))
	for chunk in active_chunks.values():
		var origin_world := Vector2(chunk["chunk"].x * WorldGenerator.CHUNK_SIZE, chunk["chunk"].y * WorldGenerator.CHUNK_SIZE)
		var origin_screen := _world_to_screen(origin_world)
		var color_data: Dictionary = chunk["grass_color"]
		var grass_color := Color(float(color_data["r"]), float(color_data["g"]), float(color_data["b"]), 1.0)
		grass_color = grass_color.lerp(Color("607D52"), 0.22)
		draw_rect(Rect2(origin_screen - Vector2.ONE, Vector2(WorldGenerator.CHUNK_SIZE + 2.0, WorldGenerator.CHUNK_SIZE + 2.0)), grass_color)
		_draw_chunk_decorations(chunk)
	_draw_aionis_arena_environment()
	_draw_chaos_arena_environment()
	_draw_python_nest_environment()
	for nest in snake_nests.values():
		_draw_satellite_snake_nest(nest)
	if Rect2(Vector2.ZERO, screen_size).grow(360.0).has_point(_world_to_screen(HOUSE_POS)):
		var safe := _world_to_screen(HOUSE_POS)
		draw_circle(safe, HOUSE_SAFE_RADIUS, Color(0.36, 0.83, 0.58, 0.08))
		draw_arc(safe, HOUSE_SAFE_RADIUS, 0, TAU, 96, Color(0.78, 0.96, 0.84, 0.48), 3.0)
		var road_a := _world_to_screen(Vector2(-400, HOUSE_POS.y + 95))
		var road_b := _world_to_screen(Vector2(1360, HOUSE_POS.y + 95))
		draw_line(road_a, road_b, Color("80633F"), 104.0)
		draw_line(road_a, road_b, Color("B88B55"), 78.0)
		draw_line(road_a + Vector2(0, -19), road_b + Vector2(0, -19), Color(0.46, 0.34, 0.22, 0.4), 2.0)
		draw_line(road_a + Vector2(0, 19), road_b + Vector2(0, 19), Color(0.46, 0.34, 0.22, 0.4), 2.0)
	_draw_house(HOUSE_POS)
	for camp in camps.values(): _draw_camp(camp)
	for castle in castles.values(): _draw_castle(castle)


func _draw_aionis_arena_environment() -> void:
	if not timeless_gate_unlocked:
		return
	var home := Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"])
	var center := _world_to_screen(home)
	var arena_radius := 760.0
	if not _on_screen(center, arena_radius + 120.0):
		return
	var defeated: bool = aionis_boss != null and bool(aionis_boss.is_defeated())
	var gold := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["gold"])
	var time_color := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["time"])
	var void_color := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["void"])
	var core := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["core"])
	var strength := 0.28 if not defeated else 0.09
	draw_circle(center, arena_radius, Color(void_color, strength))
	draw_arc(center, arena_radius, 0.0, TAU, 96, Color(gold, 0.62 if not defeated else 0.20), 5.0)
	draw_arc(center, 566.0, -game_time * 0.045, TAU - game_time * 0.045, 84, Color(time_color, 0.20 if not defeated else 0.08), 3.0)
	draw_arc(center, 352.0, game_time * 0.07, TAU + game_time * 0.07, 72, Color(gold, 0.28 if not defeated else 0.10), 3.0)
	# 十二個時刻刻度讓場地在小畫面上也能被辨識成巨型時鐘。
	for tick_index in 12:
		var angle := -PI * 0.5 + TAU * float(tick_index) / 12.0
		var inner := center + Vector2.from_angle(angle) * (arena_radius - (56.0 if tick_index % 3 == 0 else 36.0))
		var outer := center + Vector2.from_angle(angle) * (arena_radius - 12.0)
		draw_line(inner, outer, Color(gold, (0.78 if tick_index % 3 == 0 else 0.42) if not defeated else 0.16), 7.0 if tick_index % 3 == 0 else 3.0)
		if tick_index % 3 == 0:
			draw_line(center + Vector2.from_angle(angle) * 160.0, center + Vector2.from_angle(angle) * 670.0, Color(time_color, 0.08 if not defeated else 0.03), 2.0)
	# 中央雙層鐘盤與紅色「終時核心」。
	draw_circle(center, 138.0, Color("08101F", 0.92))
	draw_arc(center, 138.0, 0.0, TAU, 64, Color(gold, 0.86 if not defeated else 0.28), 6.0)
	draw_arc(center, 102.0, game_time * 0.14, TAU + game_time * 0.14, 52, Color(time_color, 0.66 if not defeated else 0.18), 3.0)
	for hand_index in 2:
		var hand_angle := (-PI * 0.5 + game_time * (0.025 if hand_index == 0 else -0.08))
		var hand_length := 78.0 if hand_index == 0 else 55.0
		draw_line(center, center + Vector2.from_angle(hand_angle) * hand_length, Color(gold, 0.54 if not defeated else 0.16), 5.0 - float(hand_index))
	draw_circle(center, 15.0, Color(core, 0.80 if not defeated else 0.20))
	# 四座時間錨：金色代表存活，破壞後轉為青色碎片。
	var anchors: Array[Dictionary] = []
	if aionis_boss != null:
		anchors = aionis_boss.get_anchor_targets()
	if anchors.is_empty():
		for anchor_index in 4:
			anchors.append({"position": home + Vector2.from_angle(TAU * float(anchor_index) / 4.0) * 245.0, "radius": 58.0, "hp": 1.0, "max_hp": 1.0, "broken": false})
	for anchor in anchors:
		var anchor_center := _world_to_screen(Vector2(anchor["position"]))
		var broken := bool(anchor.get("broken", false))
		var anchor_color := time_color if broken else gold
		draw_circle(anchor_center, 49.0, Color(void_color, 0.72))
		draw_arc(anchor_center, 49.0, game_time * (0.42 if not broken else -0.24), game_time * (0.42 if not broken else -0.24) + PI * 1.62, 30, Color(anchor_color, 0.86), 4.0)
		if broken:
			for shard_index in 4:
				var shard_dir := Vector2.from_angle(float(shard_index) * TAU / 4.0 + 0.3)
				draw_line(anchor_center + shard_dir * 8.0, anchor_center + shard_dir * 31.0, Color(time_color, 0.72), 4.0)
		else:
			_draw_polygon_shape(anchor_center, [Vector2(0, -30), Vector2(18, -5), Vector2(11, 25), Vector2(-11, 25), Vector2(-18, -5)], 0.0, Color("182440"), Color(anchor_color, 0.95), 3.0)
			draw_circle(anchor_center, 8.0 + sin(game_time * 5.0) * 1.5, Color(core, 0.85))
			var anchor_ratio := clampf(float(anchor.get("hp", 0.0)) / maxf(1.0, float(anchor.get("max_hp", 1.0))), 0.0, 1.0)
			_draw_bar(anchor_center + Vector2(-34.0, 42.0), Vector2(68.0, 6.0), anchor_ratio, gold, Color("111827"))
	_draw_text("無時之庭", center + Vector2(0.0, -180.0), 17, Color("FFF1C4") if not defeated else Color("858891"), HORIZONTAL_ALIGNMENT_CENTER, 260.0)


func _draw_chaos_arena_environment() -> void:
	var home := Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"])
	var center := _world_to_screen(home)
	var arena_radius := 690.0
	if not _on_screen(center, arena_radius + 100.0):
		return
	var defeated: bool = chaos_boss != null and chaos_boss.is_defeated()
	var rift := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["rift"])
	var core := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["core"])
	draw_circle(center, arena_radius, Color(0.055, 0.025, 0.085, 0.22 if not defeated else 0.08))
	for ring_index in 4:
		var ring_radius := 205.0 + float(ring_index) * 142.0
		var ring_alpha := (0.22 - float(ring_index) * 0.025) if not defeated else 0.08
		draw_arc(center, ring_radius, 0.18 + float(ring_index) * 0.31, 2.62 + float(ring_index) * 0.31, 64, Color(rift, ring_alpha), 3.0)
		draw_arc(center, ring_radius, 3.31 + float(ring_index) * 0.19, 5.82 + float(ring_index) * 0.19, 64, Color(rift, ring_alpha), 3.0)
	# 固定裂紋不使用隨機數，保持所有裝置上的祭壇外觀一致。
	for crack_index in 14:
		var angle := float(crack_index) * 2.399963 + 0.17
		var start_radius := 96.0 + float(crack_index % 3) * 18.0
		var end_radius := 310.0 + float((crack_index * 47) % 260)
		var bend := 0.10 if crack_index % 2 == 0 else -0.13
		var a := center + Vector2.from_angle(angle) * start_radius
		var b := center + Vector2.from_angle(angle + bend) * (start_radius + end_radius) * 0.53
		var c := center + Vector2.from_angle(angle - bend * 0.55) * end_radius
		draw_polyline(PackedVector2Array([a, b, c]), Color(rift, 0.34 if not defeated else 0.12), 2.5, true)
	# 中央混沌祭壇與三個不對稱裂界尖塔形成遠距辨識標誌。
	draw_circle(center, 118.0, Color(0.025, 0.012, 0.045, 0.90))
	draw_arc(center, 118.0, 0.0, TAU, 72, Color(rift, 0.86 if not defeated else 0.28), 6.0)
	draw_arc(center, 82.0, -game_time * 0.18, TAU - game_time * 0.18, 56, Color(core, 0.58 if not defeated else 0.18), 3.0)
	for spire_index in 3:
		var spire_angle := -0.72 + float(spire_index) * 2.18
		var spire_center := center + Vector2.from_angle(spire_angle) * 172.0
		var spire_points := [Vector2(-24, 28), Vector2(-15, -34), Vector2(0, -78), Vector2(18, -28), Vector2(27, 30)]
		_draw_polygon_shape(spire_center, spire_points, spire_angle + PI * 0.5, Color("34204B") if not defeated else Color("3D3D43"), Color(rift, 0.85 if not defeated else 0.25), 3.0)
	_draw_text("混沌祭壇", center + Vector2(0.0, -154.0), 16, Color("E8CEFF") if not defeated else Color("8A8790"), HORIZONTAL_ALIGNMENT_CENTER, 230.0)


func _draw_python_nest_environment() -> void:
	var home: Vector2 = GameConfig.PYTHON_BOSS_CONFIG["home_position"]
	var center := _world_to_screen(home)
	var arena_radius := float(GameConfig.PYTHON_BOSS_CONFIG["base"]["arena_radius"])
	if not _on_screen(center, arena_radius + 120.0):
		return
	if main_python_boss_lair_cleared:
		draw_circle(center, arena_radius, Color(0.16, 0.17, 0.17, 0.055))
		draw_arc(center, arena_radius, 0.12, 2.68, 56, Color(0.44, 0.47, 0.48, 0.28), 3.0)
		draw_arc(center, arena_radius, 3.28, 5.82, 56, Color(0.44, 0.47, 0.48, 0.28), 3.0)
		_draw_ellipse_shadow(center + Vector2(10, 25), Vector2(190, 66))
		for cleared_ring in range(5, 0, -1):
			var cleared_radius := 42.0 + float(cleared_ring) * 28.0
			var cleared_start := -2.75 + float(cleared_ring) * 0.18
			draw_arc(center, cleared_radius, cleared_start, cleared_start + 4.65, 42, Color("55585A"), 12.0)
		var cross_size := 42.0
		draw_line(center - Vector2(cross_size, cross_size), center + Vector2(cross_size, cross_size), Color("D0D4D5"), 7.0)
		draw_line(center + Vector2(-cross_size, cross_size), center + Vector2(cross_size, -cross_size), Color("D0D4D5"), 7.0)
		_draw_text("蟒蛇 Boss 主巢・此巢穴已清除", center + Vector2(0, -205), 15, Color("CCD2D3"), HORIZONTAL_ALIGNMENT_CENTER, 270)
		return
	# 外圈腐草保持低對比，中央巢穴與紫毒才是主要視覺焦點。
	draw_circle(center, arena_radius, Color(0.16, 0.08, 0.20, 0.075))
	draw_arc(center, arena_radius, 0.0, TAU, 112, Color(0.45, 0.22, 0.52, 0.28), 3.0)
	for ring in 3:
		var radius := 265.0 + float(ring) * 145.0
		for index in 16:
			var angle := TAU * float(index) / 16.0 + float(ring) * 0.37
			var wobble := sin(float(index * 13 + ring * 7)) * 32.0
			var patch := center + Vector2.from_angle(angle) * (radius + wobble)
			var patch_radius := 24.0 + float((index * 17 + ring * 11) % 19)
			draw_circle(patch, patch_radius, Color(0.18, 0.12, 0.15, 0.16))
			for blade in 3:
				var blade_angle := angle + (float(blade) - 1.0) * 0.24
				draw_line(patch, patch + Vector2.from_angle(blade_angle) * (13.0 + blade * 4.0), Color(0.30, 0.25, 0.20, 0.48), 2.0)
	# 中央盤繞巢穴：同心但帶破口，避免成為僵硬的完美圓。
	_draw_ellipse_shadow(center + Vector2(10, 25), Vector2(190, 66))
	for ring in range(5, 0, -1):
		var nest_radius := 42.0 + float(ring) * 28.0
		var start := -2.86 + float(ring) * 0.18
		var finish := start + 5.25
		draw_arc(center + Vector2(sin(ring * 1.7) * 8.0, cos(ring * 1.3) * 5.0), nest_radius, start, finish, 48, Color("49382D").lightened(float(5 - ring) * 0.035), 14.0)
		draw_arc(center, nest_radius, start, finish, 48, Color(0.10, 0.08, 0.07, 0.62), 2.0)
	# 毒液水窪形成對比色導引，但刻意保留數個清楚出口。
	for index in 7:
		var angle := -2.55 + float(index) * 0.78
		var pool_pos := center + Vector2.from_angle(angle) * (190.0 + float(index % 3) * 54.0)
		var pool_radius := 22.0 + float((index * 9) % 17)
		draw_circle(pool_pos, pool_radius, Color(0.45, 0.12, 0.62, 0.26))
		draw_arc(pool_pos, pool_radius, 0.0, TAU, 20, Color(0.76, 0.34, 0.91, 0.52), 2.0)
		draw_circle(pool_pos + Vector2(cos(game_time * 2.0 + index) * 8.0, sin(game_time * 2.4 + index) * 5.0), 3.0, Color(0.86, 0.54, 0.96, 0.55))
	# 蛇蛋、骨頭、腐石與被壓倒灌木以小型故事群組排列。
	for index in 6:
		var egg_angle := 0.45 + float(index) * 0.61
		var egg := center + Vector2.from_angle(egg_angle) * (118.0 + float(index % 2) * 28.0)
		draw_set_transform(egg, egg_angle * 0.35, Vector2.ONE)
		draw_circle(Vector2.ZERO, 10.0, Color("D7D1A3"))
		draw_circle(Vector2(0, -5), 8.0, Color("EEE9C4"))
		draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 16, Color("625A43"), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for index in 9:
		var prop_angle := -2.9 + float(index) * 0.63
		var prop := center + Vector2.from_angle(prop_angle) * (330.0 + float(index % 3) * 48.0)
		if index % 3 == 0:
			draw_line(prop + Vector2(-13, 0), prop + Vector2(13, 0), Color("D7D0BC"), 5.0)
			draw_circle(prop + Vector2(-15, 0), 5.0, Color("D7D0BC"))
			draw_circle(prop + Vector2(15, 0), 5.0, Color("D7D0BC"))
		elif index % 3 == 1:
			_draw_polygon_shape(prop, [Vector2(-16, 9), Vector2(-10, -10), Vector2(5, -16), Vector2(17, 3), Vector2(8, 14)], prop_angle, Color("534C58"), Color("2D2731"), 2.0)
		else:
			for branch in 4:
				var branch_angle := prop_angle + (float(branch) - 1.5) * 0.25
				draw_line(prop, prop + Vector2.from_angle(branch_angle) * (18.0 + branch * 3.0), Color(0.18, 0.28, 0.16, 0.72), 3.0)
	_draw_text("蟒蛇 Boss 主巢", center + Vector2(0, -205), 15, Color(0.90, 0.72, 0.96, 0.72), HORIZONTAL_ALIGNMENT_CENTER, 190)


func _draw_satellite_snake_nest(nest: Dictionary) -> void:
	var center := _world_to_screen(Vector2(nest["pos"]))
	if not _on_screen(center, 205.0):
		return
	var level := int(nest["level"])
	var lair_id := str(nest["id"])
	var active := lair_id == active_python_boss_lair_id
	var cleared := bool(nest.get("cleared", false))
	# 未啟動時仍是低矮洞穴；薩迦現身後，紫毒結界與王冠標記會把它
	# 清楚升格為真正的世界 Boss 戰場，而不是另一種小蛇圖示。
	if active and not cleared:
		draw_circle(center, 154.0, Color(0.39, 0.08, 0.52, 0.12))
		draw_arc(center, 151.0 + sin(game_time * 2.4) * 3.0, 0.0, TAU, 72, Color(0.83, 0.36, 0.96, 0.64), 4.0)
		for rune_index in 8:
			var rune_angle := TAU * float(rune_index) / 8.0 + game_time * 0.08
			var rune_pos := center + Vector2.from_angle(rune_angle) * 139.0
			draw_circle(rune_pos, 5.0, Color(0.79, 0.28, 0.92, 0.72))
	elif cleared:
		draw_arc(center, 118.0, 0.15, 2.65, 36, Color(0.48, 0.52, 0.48, 0.46), 3.0)
		draw_arc(center, 118.0, 3.25, 5.55, 36, Color(0.48, 0.52, 0.48, 0.46), 3.0)
	draw_circle(center, 112.0, Color(0.16, 0.10, 0.18, 0.16) if active and not cleared else Color(0.12, 0.20, 0.12, 0.15))
	for index in 10:
		var angle := TAU * float(index) / 10.0 + float(level) * 0.13
		var grass_root := center + Vector2.from_angle(angle) * (74.0 + float(index % 3) * 8.0)
		draw_line(grass_root, grass_root + Vector2.from_angle(angle - 0.18) * 18.0, Color(0.18, 0.34, 0.18, 0.72), 3.0)
		draw_line(grass_root, grass_root + Vector2.from_angle(angle + 0.22) * 15.0, Color(0.25, 0.42, 0.21, 0.66), 2.0)
	_draw_ellipse_shadow(center + Vector2(7, 18), Vector2(73, 31))
	draw_set_transform(center, -0.10, Vector2(1.0, 0.46))
	draw_circle(Vector2.ZERO, 68.0, Color("514A48") if cleared else Color("654936"))
	draw_circle(Vector2.ZERO, 51.0, Color("252421") if cleared else Color("211B18"))
	draw_arc(Vector2.ZERO, 58.0, -2.85, 2.25, 32, Color("77736B") if cleared else Color("9B7853"), 6.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# S 形蛇跡與兩顆破蛋讓地標在遊戲距離仍一眼可辨。
	var trail := PackedVector2Array()
	for index in 15:
		var t := float(index) / 14.0
		trail.append(center + Vector2(-52.0 + t * 104.0, -9.0 + sin(t * TAU * 1.4) * 14.0))
	draw_polyline(trail, Color("292D2A") if cleared else Color("183222"), 8.0, true)
	draw_polyline(trail, Color("777D78") if cleared else (Color("C75BE0") if active else Color("55A86B")), 4.0, true)
	var head := trail[trail.size() - 1]
	_draw_polygon_shape(head, [Vector2(9, 0), Vector2(-5, -6), Vector2(-8, 0), Vector2(-5, 6)], 0.15, Color("4E9B5F"), Color("173220"), 1.5)
	draw_circle(head + Vector2(3, -2), 1.4, GOLD)
	for egg_offset in [Vector2(-44, 37), Vector2(-24, 45)]:
		draw_circle(center + egg_offset, 8.0, Color("E5DFB6"))
		draw_line(center + egg_offset + Vector2(-3, -6), center + egg_offset + Vector2(2, 1), Color("7A6D4F"), 1.5)
	if active and not cleared:
		var crown_y := -132.0
		_draw_polygon_shape(center + Vector2(0, crown_y), [Vector2(-16, 8), Vector2(-13, -8), Vector2(-4, 1), Vector2(0, -13), Vector2(5, 1), Vector2(14, -8), Vector2(16, 8)], 0.0, GOLD, Color("4B2E18"), 1.5)
		_draw_text("腐沼蟒皇・薩迦棲息中", center + Vector2(0, -101), 16, Color("F3D6FF"), HORIZONTAL_ALIGNMENT_CENTER, 280)
		_draw_text("蟒蛇 Boss 巢穴 Lv.%d" % level, center + Vector2(0, -78), 12, Color("DCA9ED"), HORIZONTAL_ALIGNMENT_CENTER, 220)
	elif cleared:
		_draw_text("此巢穴已清除", center + Vector2(0, -72), 14, Color("CCD2CC"), HORIZONTAL_ALIGNMENT_CENTER, 205)
	else:
		_draw_text("蟒蛇 Boss 巢穴 Lv.%d" % level, center + Vector2(0, -58), 13, Color("E7E0C5"), HORIZONTAL_ALIGNMENT_CENTER, 205)


func _draw_chunk_decorations(chunk: Dictionary) -> void:
	for deco in chunk["decorations"]:
		var p := _world_to_screen(deco["position"])
		if not Rect2(Vector2(-30, -30), screen_size + Vector2(60, 60)).has_point(p): continue
		var kind := str(deco["type"])
		if kind in ["wildflower", "marsh_flower"]:
			for a in 4: draw_circle(p + Vector2.from_angle(a * PI * 0.5) * 3.2, 2.1, Color("EFE7F6"))
			draw_circle(p, 1.6, GOLD)
		elif kind in ["stones", "boulder_chip", "mossy_stone"]:
			_draw_polygon_shape(p, [Vector2(-6, 2), Vector2(-3, -4), Vector2(4, -5), Vector2(7, 1), Vector2(2, 5)], 0.0, Color("778493"), Color("50606A"), 1.0)
		else:
			for a in 3:
				var x := float(a - 1) * 4.0
				draw_line(p + Vector2(x, 4), p + Vector2(x + sin(a * 2.1) * 3, -7 - a * 2), Color(0.17, 0.38, 0.20, 0.55), 1.5)
	for obstacle in chunk["obstacles"]:
		var p := _world_to_screen(obstacle["position"])
		if not Rect2(Vector2(-80, -80), screen_size + Vector2(160, 160)).has_point(p): continue
		var radius := float(obstacle["radius"])
		match str(obstacle["type"]):
			"tree":
				_draw_ellipse_shadow(p + Vector2(6, 10), Vector2(radius * 1.35, radius * 0.55))
				draw_rect(Rect2(p + Vector2(-4, -4), Vector2(8, radius + 13)), Color("795130"))
				draw_circle(p + Vector2(0, -radius * 0.52), radius * 1.18, Color("315D3B"))
				draw_circle(p + Vector2(-radius * 0.35, -radius * 0.72), radius * 0.75, Color("477B48"))
				draw_arc(p + Vector2(0, -radius * 0.52), radius * 1.18, 0, TAU, 20, INK, 2.0)
			"rock":
				_draw_ellipse_shadow(p + Vector2(5, 7), Vector2(radius, radius * 0.45))
				_draw_polygon_shape(p, [Vector2(-radius, radius * 0.35), Vector2(-radius * 0.7, -radius * 0.5), Vector2(radius * 0.15, -radius * 0.78), Vector2(radius, -radius * 0.05), Vector2(radius * 0.55, radius * 0.62)], 0.0, Color("778493"), INK, 2.0)
			_:
				_draw_ellipse_shadow(p + Vector2(4, 7), Vector2(radius * 1.1, radius * 0.5))
				draw_circle(p, radius, Color("45754B"))
				draw_circle(p + Vector2(-radius * 0.45, -radius * 0.2), radius * 0.65, Color("5B8D54"))
				draw_arc(p, radius, 0, TAU, 18, INK, 1.7)


func _draw_house(world_pos: Vector2) -> void:
	var p := _world_to_screen(world_pos)
	if not _on_screen(p, 130): return
	_draw_ellipse_shadow(p + Vector2(8, 38), Vector2(72, 28))
	draw_rect(Rect2(p + Vector2(-57, -30), Vector2(114, 76)), Color("EADCB9"))
	draw_rect(Rect2(p + Vector2(-57, -30), Vector2(114, 76)), INK, false, 3.0)
	_draw_polygon_shape(p + Vector2(0, -36), [Vector2(-70, 12), Vector2(-45, -35), Vector2(20, -48), Vector2(72, 10), Vector2(45, 22), Vector2(-52, 22)], 0.0, Color("A84F35"), Color("713523"), 3.0)
	draw_rect(Rect2(p + Vector2(-15, 17), Vector2(30, 29)), Color("8B5A2B"))
	draw_rect(Rect2(p + Vector2(-45, -2), Vector2(20, 20)), Color("BDE8F5"))
	draw_rect(Rect2(p + Vector2(25, -2), Vector2(20, 20)), Color("BDE8F5"))
	_draw_flag(p + Vector2(53, -70), FRIEND_BLUE, false, 0.75)
	_draw_text("友方房屋", p + Vector2(0, -91), 14, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, 150)


func _draw_camp(camp: Dictionary) -> void:
	var p := _world_to_screen(camp["pos"])
	if not _on_screen(p, 230): return
	draw_circle(p, 158.0, Color(0.50, 0.35, 0.22, 0.23))
	for i in 3:
		var tent_p := p + Vector2.from_angle(i * TAU / 3.0) * 94.0
		_draw_polygon_shape(tent_p, [Vector2(-31, 23), Vector2(0, -35), Vector2(31, 23)], 0.0, Color("D77B45") if not camp["cleared"] else Color("77675C"), ENEMY_DARK, 2.0)
		_draw_polygon_shape(tent_p + Vector2(0, 8), [Vector2(-8, 15), Vector2(0, -12), Vector2(8, 15)], 0.0, Color("4A2926"), ENEMY_DARK, 1.0)
	if not camp["cleared"]:
		for i in 8:
			var fire_p := p + Vector2.from_angle(i * TAU / 8.0) * 15.0
			draw_circle(fire_p, 4.0, Color("778493"))
		draw_circle(p, 11.0 + sin(game_time * 8.0) * 2.0, FIRE_ORANGE)
		draw_circle(p + Vector2(0, -3), 6.0, GOLD)
		_draw_flag(p + Vector2(72, -58), ENEMY_RED, true, 0.7)
	else:
		draw_circle(p, 13.0, Color("535C58"))
		_draw_text("已清除", p + Vector2(0, -115), 14, HEAL_GREEN, HORIZONTAL_ALIGNMENT_CENTER, 140)
	if float(camp["crate_hp"]) > 0.0:
		draw_rect(Rect2(p + Vector2(-28, 62), Vector2(56, 38)), Color("8B5A2B"))
		draw_rect(Rect2(p + Vector2(-28, 62), Vector2(56, 38)), INK, false, 2.0)
		draw_line(p + Vector2(-28, 62), p + Vector2(28, 100), Color("C49352"), 3.0)


func _draw_castle(castle: Dictionary) -> void:
	var p := _world_to_screen(castle["pos"])
	if not _on_screen(p, 300): return
	var friendly := bool(castle["owned"])
	var nation: Dictionary = Dictionary(castle.get("nation", NationCatalog.player_metadata() if friendly else {}))
	var flag_color := Color(str(nation.get("color_hex", "3B82F6" if friendly else "B84032")))
	draw_line(p + Vector2(-112.0, -170.0), p + Vector2(-112.0, -242.0), Color("27343A"), 4.0)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-108.0, -238.0), p + Vector2(-52.0, -224.0), p + Vector2(-108.0, -207.0)]), flag_color)
	var tier := GameConfig.castle_tier_for_level(int(castle["level"]))
	var wall_color := Color("7D9195") if friendly else Color("555D5A")
	if castle["destroyed"]: wall_color = Color("625F5A")
	_draw_ellipse_shadow(p + Vector2(12, 142 if tier >= 40 else 112), Vector2(265, 72) if tier >= 40 else Vector2(202, 58))
	if tier >= 40:
		var outer_wall_intact := not bool(castle.get("wall_breached", false)) and float(castle.get("wall_hp", 0.0)) > 0.0
		# Hostile walls are solid stone. Captured walls become a translucent blue
		# phase perimeter: it still excludes enemies, while its arrows and label make
		# it clear that the player and recruited troops may cross from every side.
		var outer_color := Color("69777A") if not friendly else Color(0.22, 0.68, 0.92, 0.16)
		var outer_edge := ENEMY_DARK if not friendly else Color(0.36, 0.86, 1.0, 0.86)
		if outer_wall_intact:
			draw_rect(Rect2(p + Vector2(-238, -195), Vector2(476, 37)), outer_color)
			draw_rect(Rect2(p + Vector2(-238, 155), Vector2(175, 38)), outer_color)
			draw_rect(Rect2(p + Vector2(63, 155), Vector2(175, 38)), outer_color)
			draw_rect(Rect2(p + Vector2(-238, -195), Vector2(38, 388)), outer_color)
			draw_rect(Rect2(p + Vector2(200, -195), Vector2(38, 388)), outer_color)
			for outer_segment in [Rect2(p + Vector2(-238, -195), Vector2(476, 37)), Rect2(p + Vector2(-238, 155), Vector2(175, 38)), Rect2(p + Vector2(63, 155), Vector2(175, 38)), Rect2(p + Vector2(-238, -195), Vector2(38, 388)), Rect2(p + Vector2(200, -195), Vector2(38, 388))]:
				draw_rect(outer_segment, outer_edge, false, 4.0)
			for outer_corner in [Vector2(-219, -176), Vector2(219, -176), Vector2(-219, 174), Vector2(219, 174)]:
				draw_rect(Rect2(p + outer_corner - Vector2(30, 30), Vector2(60, 60)), outer_color.lightened(0.08))
				draw_rect(Rect2(p + outer_corner - Vector2(30, 30), Vector2(60, 60)), outer_edge, false, 4.0)
			for outer_notch_x in range(-216, 217, 36):
				draw_rect(Rect2(p + Vector2(outer_notch_x, -207), Vector2(20, 17)), outer_color.lightened(0.14))
			if friendly:
				var phase_color := Color(0.42, 0.90, 1.0, 0.94)
				for phase_gate in [
					{"center": Vector2(0, -176), "out": Vector2.UP},
					{"center": Vector2(0, 174), "out": Vector2.DOWN},
					{"center": Vector2(-219, 0), "out": Vector2.LEFT},
					{"center": Vector2(219, 0), "out": Vector2.RIGHT},
				]:
					var phase_center: Vector2 = p + Vector2(phase_gate["center"])
					var phase_out: Vector2 = Vector2(phase_gate["out"])
					var phase_side := Vector2(-phase_out.y, phase_out.x)
					draw_circle(phase_center, 25.0 + sin(game_time * 4.0) * 2.0, Color(0.28, 0.82, 1.0, 0.12))
					draw_arc(phase_center, 22.0, 0, TAU, 24, phase_color, 2.5)
					draw_line(phase_center - phase_out * 11.0 - phase_side * 9.0, phase_center + phase_out * 11.0, phase_color, 3.5)
					draw_line(phase_center - phase_out * 11.0 + phase_side * 9.0, phase_center + phase_out * 11.0, phase_color, 3.5)
				_draw_text("友軍相位屏障・可自由通行", p + Vector2(0, 219), 13, Color("9FE8FF"), HORIZONTAL_ALIGNMENT_CENTER, 260.0)
			else:
				draw_rect(Rect2(p + Vector2(-62, 145), Vector2(124, 58)), Color("20272B"))
				for portcullis_x in [-48.0, -28.0, -8.0, 12.0, 32.0, 52.0]:
					draw_line(p + Vector2(portcullis_x, 148), p + Vector2(portcullis_x, 199), Color("B9C1BE"), 5.0)
		else:
			# Broken stones preserve the former footprint and make the new route obvious.
			for rubble_index in 18:
				var rubble_angle := TAU * float(rubble_index) / 18.0
				var rubble_radius := 220.0 if rubble_index % 2 == 0 else 198.0
				var rubble_center := p + Vector2(cos(rubble_angle) * rubble_radius, sin(rubble_angle) * rubble_radius * 0.78)
				_draw_polygon_shape(rubble_center, [Vector2(-12, -7), Vector2(8, -9), Vector2(14, 3), Vector2(3, 11), Vector2(-13, 7)], rubble_angle * 0.3, Color("77766E"), Color("454640"), 1.5)
			_draw_text("外牆已突破", p + Vector2(0, 205), 14, Color("FFD166"), HORIZONTAL_ALIGNMENT_CENTER, 150.0)
	draw_rect(Rect2(p + Vector2(-150, -118), Vector2(300, 236)), wall_color)
	draw_rect(Rect2(p + Vector2(-150, -118), Vector2(300, 236)), FRIEND_DARK if friendly else ENEMY_DARK, false, 6.0)
	draw_rect(Rect2(p + Vector2(-98, -72), Vector2(196, 150)), wall_color.lightened(0.08))
	for corner in [Vector2(-150, -118), Vector2(150, -118), Vector2(-150, 118), Vector2(150, 118)]:
		draw_rect(Rect2(p + corner - Vector2(38, 38), Vector2(76, 76)), wall_color.darkened(0.05))
		draw_rect(Rect2(p + corner - Vector2(38, 38), Vector2(76, 76)), FRIEND_DARK if friendly else ENEMY_DARK, false, 4.0)
	if tier >= 20:
		# Bronze artillery citadel and roof emplacements make the first late-game
		# tier readable even when guards are outside the camera view.
		for notch_x in range(-132, 133, 33):
			draw_rect(Rect2(p + Vector2(notch_x, -136), Vector2(20, 19)), wall_color.lightened(0.16))
			draw_rect(Rect2(p + Vector2(notch_x, -136), Vector2(20, 19)), ENEMY_DARK if not friendly else FRIEND_DARK, false, 2.0)
		draw_rect(Rect2(p + Vector2(-62, -91), Vector2(124, 112)), Color("696F6B") if not friendly else Color("859AA4"))
		draw_rect(Rect2(p + Vector2(-62, -91), Vector2(124, 112)), ENEMY_DARK if not friendly else FRIEND_DARK, false, 4.0)
		_draw_polygon_shape(p + Vector2(0, -94), [Vector2(-74, 10), Vector2(-46, -31), Vector2(46, -31), Vector2(74, 10)], 0.0, Color("9B603D") if not friendly else Color("3F7A9B"), ENEMY_DARK if not friendly else FRIEND_DARK, 3.0)
		for cannon_x in [-104.0, 104.0]:
			var cannon_base := p + Vector2(cannon_x, -118)
			draw_circle(cannon_base + Vector2(-8, 7), 7.0, Color("242A2E"))
			draw_circle(cannon_base + Vector2(8, 7), 7.0, Color("242A2E"))
			draw_rect(Rect2(cannon_base + Vector2(-15, -5), Vector2(30, 14)), Color("8F6849"))
			draw_line(cannon_base, cannon_base + Vector2(0, -29), Color("30383E"), 8.0)
			draw_circle(cannon_base + Vector2(0, -30), 5.0, Color("151B1E"))
	if tier >= 30:
		# Alternating firing slits and steel rangefinder tower identify the firearm tier.
		for slit_x in [-43.0, -14.0, 15.0, 44.0]:
			draw_rect(Rect2(p + Vector2(slit_x - 4.0, -52.0), Vector2(8.0, 24.0)), Color("1B252A"))
			draw_rect(Rect2(p + Vector2(slit_x - 2.0, -50.0), Vector2(4.0, 20.0)), Color("E29A46"), false, 1.0)
		draw_rect(Rect2(p + Vector2(-21, -130), Vector2(42, 35)), Color("46545A"))
		draw_rect(Rect2(p + Vector2(-21, -130), Vector2(42, 35)), ENEMY_DARK if not friendly else FRIEND_DARK, false, 3.0)
		draw_line(p + Vector2(0, -130), p + Vector2(0, -158), Color("B9C7CD"), 3.0)
		draw_circle(p + Vector2(0, -160), 5.0, Color("FFD166"))
	if tier >= 35:
		# Riveted steel apron, hazard bars and a gear crest mark the vehicle tier.
		draw_rect(Rect2(p + Vector2(-96, 24), Vector2(192, 34)), Color("4D585B"))
		draw_rect(Rect2(p + Vector2(-96, 24), Vector2(192, 34)), ENEMY_DARK if not friendly else FRIEND_DARK, false, 3.0)
		for rivet_x in range(-82, 83, 28):
			draw_circle(p + Vector2(rivet_x, 31), 2.5, Color("B5B6AA"))
		for stripe_index in 6:
			var stripe_x := -84.0 + float(stripe_index) * 30.0
			draw_line(p + Vector2(stripe_x, 54), p + Vector2(stripe_x + 16, 28), Color("D5A13A"), 5.0)
		draw_circle(p + Vector2(0, -112), 13.0, Color("323D41"))
		draw_arc(p + Vector2(0, -112), 13.0, 0, TAU, 18, Color("D5A13A"), 3.0)
		for gear_tooth in 8:
			var gear_direction := Vector2.from_angle(TAU * float(gear_tooth) / 8.0)
			draw_line(p + Vector2(0, -112) + gear_direction * 11.0, p + Vector2(0, -112) + gear_direction * 17.0, Color("D5A13A"), 3.0)
	if tier >= 45:
		# Twin helipads and tracking radar identify the air-superiority tier.
		for pad_center in [p + Vector2(-219, 174), p + Vector2(219, 174)]:
			draw_circle(pad_center, 24.0, Color("344348"))
			draw_arc(pad_center, 24.0, 0, TAU, 28, Color("D9E4E6"), 2.5)
			draw_line(pad_center + Vector2(-8, -12), pad_center + Vector2(-8, 12), Color("EAF6FF"), 3.0)
			draw_line(pad_center + Vector2(8, -12), pad_center + Vector2(8, 12), Color("EAF6FF"), 3.0)
			draw_line(pad_center + Vector2(-8, 0), pad_center + Vector2(8, 0), Color("EAF6FF"), 3.0)
		var radar_center := p + Vector2(126, -104)
		draw_line(radar_center, radar_center + Vector2(0, 25), Color("29363B"), 4.0)
		draw_arc(radar_center, 20.0, -2.8 + sin(game_time) * 0.15, -0.3 + sin(game_time) * 0.15, 18, Color("AFC9CF"), 5.0)
		draw_line(radar_center, radar_center + Vector2.from_angle(-1.55 + sin(game_time) * 0.15) * 23.0, Color("FFD166"), 2.0)
	if tier >= 50:
		# Cyan energy pylons and a concentric beacon separate the final alien tier.
		for pylon_center in [p + Vector2(-219, -176), p + Vector2(219, -176), p + Vector2(-219, 174), p + Vector2(219, 174)]:
			draw_circle(pylon_center, 15.0 + sin(game_time * 4.0) * 2.0, Color(0.22, 0.95, 0.88, 0.16))
			draw_arc(pylon_center, 17.0, 0, TAU, 24, Color("75FFF0"), 3.0)
			draw_line(pylon_center + Vector2(0, 11), pylon_center + Vector2(0, -24), Color("B9FFF8"), 4.0)
			draw_circle(pylon_center + Vector2(0, -27), 6.0, Color("75FFF0"))
		var alien_beacon := p + Vector2(0, -112)
		for beacon_ring in 3:
			draw_arc(alien_beacon, 19.0 + float(beacon_ring) * 8.0 + sin(game_time * 3.0 + beacon_ring) * 2.0, 0, TAU, 28, Color(0.40, 1.0, 0.94, 0.72 - beacon_ring * 0.14), 2.0)
		draw_circle(alien_beacon, 8.0, Color("D7FFFA"))
	# 城門在南側；友方開門、敵方關門。
	var gate_color := Color("253A45") if friendly else Color("332721")
	draw_rect(Rect2(p + Vector2(-38, 68), Vector2(76, 55)), gate_color)
	if not friendly:
		for x in [-24.0, -8.0, 8.0, 24.0]: draw_line(p + Vector2(x, 70), p + Vector2(x, 119), Color("8B5A2B"), 5.0)
	_draw_flag(p + Vector2(-93, -170), FRIEND_BLUE if friendly else ENEMY_RED, not friendly, 0.95)
	_draw_flag(p + Vector2(93, -170), FRIEND_BLUE if friendly else ENEMY_RED, not friendly, 0.95)
	var core_bar_position := p + Vector2(-150, -204 if tier >= 40 else -154)
	_draw_bar(core_bar_position, Vector2(300, 13), float(castle["hp"]) / max(1.0, float(castle["max_hp"])), HEAL_GREEN if friendly else ENEMY_RED, Color("18242A"))
	if tier >= 40 and float(castle.get("wall_max_hp", 0.0)) > 0.0:
		var wall_ratio: float = float(castle.get("wall_hp", 0.0)) / max(1.0, float(castle.get("wall_max_hp", 1.0)))
		_draw_bar(p + Vector2(-150, -222), Vector2(300, 12), wall_ratio, Color("D5A13A"), Color("18242A"))
		_draw_text("外牆", p + Vector2(-183, -212), 11, Color("FFE3A0"), HORIZONTAL_ALIGNMENT_CENTER, 58.0)
	var castle_title := str(castle.get("tier_name", "蠻族城堡")) if tier >= 20 else "蠻族城堡"
	if friendly: castle_title = "友方%s" % castle_title
	_draw_text("%s Lv.%d" % [castle_title, int(castle["level"])], p + Vector2(0, -234 if tier >= 40 else -166), 14, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, 320)
	if friendly:
		var garrison_count := _friendly_garrison_count(castle)
		var garrison_y := 245.0 if tier >= 40 else 154.0
		_draw_text("駐軍 %d" % garrison_count, p + Vector2(0, garrison_y), 13, Color("9FE8FF"), HORIZONTAL_ALIGNMENT_CENTER, 130.0)
	if castle["destroyed"]:
		var ratio := float(castle["capture"]) / float(GameConfig.CASTLE_SETTINGS["capture_seconds"])
		_draw_bar(p + Vector2(-110, 142), Vector2(220, 14), ratio, FRIEND_BLUE, Color("251F1B"))
		_draw_text("佔領進度 %d%%" % int(ratio * 100.0), p + Vector2(0, 178), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 200)


func _friendly_garrison_count(castle: Dictionary) -> int:
	var count := 0
	for soldier in soldiers:
		if float(soldier.get("hp", 0.0)) > 0.0 and Vector2(soldier["pos"]).distance_to(castle["pos"]) <= 310.0:
			count += 1
	return count


func _draw_units() -> void:
	for enemy in enemies:
		_draw_enemy(enemy)
	_draw_python_boss()
	_draw_chaos_boss()
	_draw_aionis_boss()
	for soldier in soldiers:
		_draw_soldier(soldier)
	if player["class_id"] != "":
		var p := _world_to_screen(player["pos"])
		if _on_screen(p, 80):
			var aim := Vector2(player["facing"])
			draw_line(p + aim * 23.0, p + aim * 52.0, Color(0.85, 0.96, 1.0, 0.56), 2.0)
			draw_arc(p + aim * 58.0, 6.0, 0, TAU, 12, Color("EAF6FF"), 1.5)
			_draw_character_icon(str(player["class_id"]), p, 1.0, Vector2(player["facing"]).angle(), float(player["flash"]) > 0.0)
			draw_arc(p, 22.0, 0, TAU, 28, GOLD, 2.5)
			if float(player["invuln"]) > 0.0:
				draw_arc(p, 27.0 + sin(game_time * 9.0) * 2.0, 0, TAU, 32, Color(0.85, 0.98, 1.0, 0.65), 2.0)


func _draw_python_boss() -> void:
	if python_boss == null:
		return
	var snapshot: Dictionary = python_boss.render_snapshot()
	var segments: Array = Array(snapshot.get("segments", []))
	if segments.is_empty():
		return
	var state := str(snapshot.get("state", "IDLE"))
	var death_elapsed := float(snapshot.get("death_elapsed", 0.0))
	if state == "DEAD" and death_elapsed >= 2.8:
		return
	var phase := int(snapshot.get("phase", 1))
	var flash := float(snapshot.get("flash", 0.0)) > 0.0
	var facing := Vector2(snapshot.get("facing", Vector2.RIGHT)).normalized()
	if facing.length_squared() <= 0.001:
		facing = Vector2.RIGHT
	var scale_dark := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["scale_dark"])
	var scale_mid := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["scale_mid"])
	var belly := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["belly"])
	var poison := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["poison_color"])
	var eye := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["eye"])
	var base_alpha: float = 1.0 if state != "DEAD" else clampf(1.0 - maxf(0.0, death_elapsed - 1.25) / 1.45, 0.0, 1.0)

	# 第三階段與死亡流程使用少量固定幾何光暈，避免持續配置粒子物件。
	if phase >= 3 and state != "DEAD":
		var head_glow := _world_to_screen(Vector2(snapshot["position"]))
		draw_circle(head_glow, 58.0 + sin(game_time * 5.0) * 4.0, Color(poison, 0.10))
		draw_arc(head_glow, 54.0 + sin(game_time * 5.0) * 3.0, 0.0, TAU, 36, Color(poison.lightened(0.35), 0.50), 2.0)
	if state == "DEAD":
		var death_center := _world_to_screen(Vector2(snapshot["position"]))
		var beam_alpha := clampf(1.0 - death_elapsed / 2.8, 0.0, 1.0)
		draw_rect(Rect2(death_center + Vector2(-17, -210), Vector2(34, 220)), Color(1.0, 0.80, 0.30, 0.08 * beam_alpha))
		for ray in 6:
			var ray_angle := game_time * 0.35 + TAU * float(ray) / 6.0
			draw_line(death_center, death_center + Vector2.from_angle(ray_angle) * (65.0 + death_elapsed * 35.0), Color(1.0, 0.78, 0.28, 0.55 * beam_alpha), 3.0)

	# 衝刺時沿前幾節留下殘影；只畫現有節點，不建立額外實體。
	if state == "CASTING" and str(snapshot.get("active_skill", "")) == "dash":
		for ghost_index in range(mini(7, segments.size()) - 1, -1, -1):
			var ghost_segment: Dictionary = Dictionary(segments[ghost_index])
			var ghost_pos := _world_to_screen(Vector2(ghost_segment["pos"]) - facing * (22.0 + ghost_index * 7.0))
			draw_circle(ghost_pos, float(ghost_segment["radius"]) * 0.90, Color(scale_mid, 0.08 + 0.025 * ghost_index))

	# 尾到頭依序繪製，讓節點互相覆蓋成連續蛇身。
	for draw_index in range(segments.size() - 1, -1, -1):
		var segment: Dictionary = Dictionary(segments[draw_index])
		var segment_pos := _world_to_screen(Vector2(segment["pos"]))
		var radius := float(segment["radius"])
		if not _on_screen(segment_pos, radius + 35.0):
			continue
		var stop_delay := float(segments.size() - 1 - draw_index) * 0.045
		var segment_alpha := base_alpha
		var collapse := 0.0
		if state == "DEAD":
			collapse = clampf((death_elapsed - stop_delay) / 1.1, 0.0, 1.0)
			segment_pos += Vector2(sin(float(draw_index) * 1.71 + death_elapsed * 7.0) * (1.0 - collapse) * 8.0, collapse * 15.0)
			segment_alpha *= clampf(1.0 - maxf(0.0, death_elapsed - 1.0 - stop_delay) / 1.35, 0.0, 1.0)
		if segment_alpha <= 0.01:
			continue
		_draw_ellipse_shadow(segment_pos + Vector2(7, radius * 0.52), Vector2(radius * 1.05, radius * 0.43))
		draw_circle(segment_pos, radius + 3.0, Color(0.025, 0.075, 0.045, 0.92 * segment_alpha))
		var alternating := 0.08 if draw_index % 2 == 0 else -0.03
		var body_color := scale_mid.lightened(alternating)
		if flash:
			body_color = Color("F6FFF4")
		draw_circle(segment_pos, radius, Color(body_color, segment_alpha))
		# 灰黃腹鱗只佔較窄內圈，從側面仍可看見深綠輪廓。
		var belly_offset := Vector2(0.0, radius * 0.24)
		draw_circle(segment_pos + belly_offset, radius * 0.56, Color(belly, 0.72 * segment_alpha))
		draw_arc(segment_pos, radius * 0.78, -2.75, -0.35, 12, Color(scale_dark, 0.70 * segment_alpha), 2.0)
		# 鱗片高光與低血量紫色裂紋。
		var scale_angle := float(draw_index) * 2.399 + game_time * 0.08
		draw_arc(segment_pos + Vector2.from_angle(scale_angle) * radius * 0.25, radius * 0.28, scale_angle - 0.8, scale_angle + 0.8, 8, Color(0.48, 0.75, 0.45, 0.35 * segment_alpha), 1.4)
		if phase >= 2 and draw_index % 3 == 1:
			var crack_direction := Vector2.from_angle(float(draw_index) * 1.93)
			var crack_start := segment_pos - crack_direction * radius * 0.22
			draw_line(crack_start, crack_start + crack_direction.rotated(0.24) * radius * 0.48, Color(poison.lightened(0.32), (0.42 if phase == 2 else 0.84) * segment_alpha), 2.0 if phase == 2 else 3.0)
		if draw_index in [1, 2, 3]:
			var neighbor_pos := Vector2(segments[draw_index + 1]["pos"]) if draw_index + 1 < segments.size() else Vector2(segment["pos"]) - facing
			var local_forward := (Vector2(segment["pos"]) - neighbor_pos).normalized()
			var spine_base := segment_pos + local_forward.rotated(-PI * 0.5) * radius * 0.66
			var spine_tip := spine_base + local_forward.rotated(-PI * 0.5) * (10.0 + (3 - draw_index) * 2.0)
			draw_line(spine_base, spine_tip, Color(0.82, 0.79, 0.60, segment_alpha), 4.0)

	# 頭部輪廓、毒囊、發光眼、嘴與毒牙覆蓋在所有身體節點上。
	var head := _world_to_screen(Vector2(snapshot["position"]))
	var head_angle := facing.angle()
	var head_color := Color("F7FFF1") if flash else scale_dark.lightened(0.10)
	var head_points := [Vector2(-30, -31), Vector2(10, -39), Vector2(41, -22), Vector2(50, 0), Vector2(38, 26), Vector2(5, 39), Vector2(-31, 29), Vector2(-42, 0)]
	_draw_polygon_shape(head, head_points, head_angle, Color(head_color, base_alpha), Color(0.02, 0.07, 0.04, base_alpha), 3.5)
	var left_sac := head + Vector2(-4, -31).rotated(head_angle)
	var right_sac := head + Vector2(-4, 31).rotated(head_angle)
	draw_circle(left_sac, 11.0, Color(poison, (0.44 if phase < 3 else 0.78) * base_alpha))
	draw_circle(right_sac, 11.0, Color(poison, (0.44 if phase < 3 else 0.78) * base_alpha))
	var left_eye := head + Vector2(21, -17).rotated(head_angle)
	var right_eye := head + Vector2(21, 17).rotated(head_angle)
	for eye_pos in [left_eye, right_eye]:
		draw_circle(eye_pos, 7.0 if phase >= 3 else 5.5, Color(eye, base_alpha))
		draw_line(eye_pos - facing * 4.0, eye_pos + facing * 4.0, Color(0.08, 0.05, 0.02, base_alpha), 2.0)
		if phase >= 3:
			draw_arc(eye_pos, 10.0 + sin(game_time * 8.0) * 1.5, 0.0, TAU, 16, Color(eye, 0.55 * base_alpha), 2.0)
	var mouth_center := head + facing * 34.0
	draw_line(mouth_center + facing.rotated(-PI * 0.5) * 18.0, mouth_center + facing.rotated(PI * 0.5) * 18.0, Color(0.23, 0.035, 0.17, base_alpha), 7.0)
	var fang_a := mouth_center + facing.rotated(-PI * 0.5) * 12.0
	var fang_b := mouth_center + facing.rotated(PI * 0.5) * 12.0
	draw_line(fang_a, fang_a + facing * 15.0, Color(0.94, 0.92, 0.72, base_alpha), 4.0)
	draw_line(fang_b, fang_b + facing * 15.0, Color(0.94, 0.92, 0.72, base_alpha), 4.0)
	draw_circle(mouth_center + facing * 12.0, 5.0 + sin(game_time * 7.0) * 1.2, Color(poison.lightened(0.20), 0.86 * base_alpha))
	# 頭骨刺與毒囊剪影強化 Boss 辨識度。
	for spine_index in 3:
		var side := -1.0 if spine_index % 2 == 0 else 1.0
		var spine_base := head + Vector2(-18.0 + spine_index * 5.0, side * (30.0 + spine_index * 2.0)).rotated(head_angle)
		var spine_tip := spine_base + Vector2(-13.0, side * 12.0).rotated(head_angle)
		draw_line(spine_base, spine_tip, Color(0.82, 0.80, 0.62, base_alpha), 5.0)

	# 纏繞不改變主蛇身拓撲，以四個發光節點環繞錨點。
	if str(snapshot.get("constrict_key", "")) != "":
		var anchor := _world_to_screen(Vector2(snapshot.get("constrict_anchor", snapshot["position"])))
		for coil_index in 4:
			var coil_radius := 30.0 + coil_index * 7.0
			var coil_start := game_time * (2.2 + coil_index * 0.12) + coil_index * 0.9
			draw_arc(anchor, coil_radius, coil_start, coil_start + 4.9, 30, Color(poison.lightened(0.28), 0.82), 7.0)
		draw_circle(anchor, 18.0, Color(poison, 0.12))

	if state == "STUNNED":
		for star_index in 5:
			var star_angle := game_time * 2.8 + TAU * float(star_index) / 5.0
			var star := head + Vector2.from_angle(star_angle) * 58.0 + Vector2(0, -32)
			draw_circle(star, 4.0, Color("FFE879"))
			draw_line(star - Vector2(7, 0), star + Vector2(7, 0), Color("FFE879"), 2.0)
			draw_line(star - Vector2(0, 7), star + Vector2(0, 7), Color("FFE879"), 2.0)
		_draw_text("破綻！頭部傷害 +20%", head + Vector2(0, -82), 14, Color("FFE879"), HORIZONTAL_ALIGNMENT_CENTER, 230)


func _draw_chaos_boss() -> void:
	if chaos_boss == null:
		return
	var snapshot: Dictionary = chaos_boss.render_snapshot()
	if str(snapshot.get("state", "IDLE")) == "DEAD":
		return
	var ground_position := _world_to_screen(Vector2(snapshot.get("position", GameConfig.CHAOS_BOSS_CONFIG["home_position"])))
	var radius := float(snapshot.get("radius", 88.0))
	if not _on_screen(ground_position, radius + 150.0):
		return
	var phase := int(snapshot.get("phase", 1))
	var facing := Vector2(snapshot.get("facing", Vector2.RIGHT)).normalized()
	if facing.length_squared() < 0.001:
		facing = Vector2.RIGHT
	var side := Vector2(-facing.y, facing.x)
	var hover := sin(game_time * 2.8) * 5.0
	var p := ground_position + Vector2(0.0, -22.0 + hover)
	var body_color := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["body"])
	var armor_color := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["armor"])
	var core_color := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["core"])
	var energy_color := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["energy"])
	var rift_color := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["rift"])

	_draw_ellipse_shadow(ground_position + Vector2(14.0, 30.0), Vector2(radius * 1.22, radius * 0.44))
	for aura_index in phase:
		var aura_radius := radius + 20.0 + float(aura_index) * 15.0 + sin(game_time * (3.2 + aura_index) + aura_index) * 3.0
		draw_arc(p, aura_radius, game_time * (0.22 + aura_index * 0.08), game_time * (0.22 + aura_index * 0.08) + PI * 1.45, 38, Color(rift_color, 0.22 + 0.08 * float(phase)), 2.4)

	# 三柄破碎軌道刃是最遠距離也能辨認卡厄隆的輪廓語言。
	for blade_index in 3:
		var orbit_angle := game_time * (0.46 + float(phase) * 0.06) + float(blade_index) * TAU / 3.0
		var blade_center := p + Vector2.from_angle(orbit_angle) * (radius + 38.0)
		var blade_rotation := orbit_angle + PI * 0.5
		var blade_points := [Vector2(-24, -8), Vector2(8, -12), Vector2(30, 0), Vector2(7, 9), Vector2(-17, 7), Vector2(-5, 0)]
		_draw_polygon_shape(blade_center, blade_points, blade_rotation, Color(armor_color, 0.94), Color("160B24"), 3.0)
		draw_line(blade_center - Vector2.from_angle(blade_rotation) * 10.0, blade_center + Vector2.from_angle(blade_rotation) * 15.0, Color(rift_color, 0.72), 2.0)

	# 不對稱主體：左側破甲翼、中央核心、右側青色毀滅炮口。
	var body_points := [Vector2(-72, 9), Vector2(-52, -46), Vector2(-13, -66), Vector2(35, -49), Vector2(66, -12), Vector2(52, 42), Vector2(7, 63), Vector2(-42, 48)]
	_draw_polygon_shape(p, body_points, facing.angle(), body_color, Color("12091D"), 5.0)
	var left_wing_center := p - side * 42.0 - facing * 15.0
	var wing_points := [Vector2(-48, 0), Vector2(-14, -28), Vector2(28, -17), Vector2(15, 4), Vector2(34, 20), Vector2(-15, 26)]
	_draw_polygon_shape(left_wing_center, wing_points, facing.angle(), armor_color.darkened(0.14), Color("170C25"), 3.5)
	var plate_points := [Vector2(-44, -16), Vector2(-6, -37), Vector2(36, -19), Vector2(49, 8), Vector2(18, 32), Vector2(-29, 27)]
	_draw_polygon_shape(p, plate_points, facing.angle(), armor_color, Color(rift_color, 0.78), 3.0)
	for crack_index in phase + 1:
		var crack_angle := facing.angle() + 0.85 + float(crack_index) * 1.31
		var crack_start := p + Vector2.from_angle(crack_angle) * (20.0 + float(crack_index) * 5.0)
		draw_line(crack_start, crack_start + Vector2.from_angle(crack_angle + 0.35) * (18.0 + phase * 4.0), Color(core_color, 0.66), 2.4)

	var core_center := p + facing * 5.0
	draw_circle(core_center, 31.0 + sin(game_time * 6.2) * 3.0, Color(core_color, 0.15 + float(phase) * 0.04))
	draw_circle(core_center, 22.0, Color("13091D"))
	draw_circle(core_center, 15.0 + sin(game_time * 6.2) * 2.0, core_color)
	draw_circle(core_center - Vector2(4.0, 5.0), 5.0, Color("FFDDF6"))
	draw_arc(core_center, 26.0, -game_time * 1.4, PI * 1.35 - game_time * 1.4, 26, Color(energy_color, 0.86), 3.0)

	var cannon_base := p + side * 39.0 + facing * 26.0
	_draw_polygon_shape(cannon_base, [Vector2(-28, -16), Vector2(18, -14), Vector2(36, 0), Vector2(18, 14), Vector2(-28, 16)], facing.angle(), Color("244D66"), Color("0C1B28"), 3.0)
	draw_line(cannon_base + facing * 2.0, cannon_base + facing * 62.0, Color("3A7690"), 18.0)
	draw_line(cannon_base + facing * 13.0, cannon_base + facing * 67.0, Color(energy_color, 0.82), 7.0)
	var muzzle := cannon_base + facing * 68.0
	draw_circle(muzzle, 13.0 + sin(game_time * 8.0) * 2.0, Color(energy_color, 0.30))
	draw_arc(muzzle, 13.0, 0.0, TAU, 20, energy_color, 3.0)

	var hp_ratio := clampf(float(snapshot.get("hp_ratio", 1.0)), 0.0, 1.0)
	_draw_bar(p + Vector2(-88.0, -128.0), Vector2(176.0, 9.0), hp_ratio, core_color, Color("190D22"))
	_draw_text("萬象崩滅者・卡厄隆", p + Vector2(0.0, -139.0), 13, Color("F3E5FF"), HORIZONTAL_ALIGNMENT_CENTER, 250.0)


func _draw_aionis_boss() -> void:
	if not timeless_gate_unlocked or aionis_boss == null:
		return
	var snapshot: Dictionary = aionis_boss.render_snapshot()
	if str(snapshot.get("state", "IDLE")) == "DEAD":
		return
	var ground := _world_to_screen(Vector2(snapshot.get("position", GameConfig.AIONIS_BOSS_CONFIG["home_position"])))
	var radius := float(snapshot.get("radius", 98.0))
	if not _on_screen(ground, radius + 180.0):
		return
	var phase := int(snapshot.get("phase", 1))
	var facing := Vector2(snapshot.get("facing", Vector2.RIGHT)).normalized()
	if facing.length_squared() <= 0.001:
		facing = Vector2.RIGHT
	var side := Vector2(-facing.y, facing.x)
	var hover := sin(game_time * 2.2) * 5.5
	var p := ground + Vector2(0.0, -28.0 + hover)
	var ivory := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["body"])
	var navy := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["armor"])
	var gold := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["gold"])
	var core := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["core"])
	var time_color := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["time"])
	_draw_ellipse_shadow(ground + Vector2(12.0, 34.0), Vector2(radius * 1.34, radius * 0.46))

	# 破碎十二刻光環；第四階段會全部脫離成軌道刃。
	for tick_index in 12:
		var tick_angle := game_time * (0.10 + float(phase) * 0.025) + TAU * float(tick_index) / 12.0
		var orbit := radius + 43.0 + (18.0 if phase >= 4 and tick_index % 2 == 0 else 0.0)
		var tick_center := p + Vector2.from_angle(tick_angle) * orbit
		var tick_length := 24.0 if tick_index % 3 == 0 else 15.0
		draw_line(tick_center - Vector2.from_angle(tick_angle) * tick_length * 0.45, tick_center + Vector2.from_angle(tick_angle) * tick_length * 0.55, Color(gold, 0.90), 6.0 if tick_index % 3 == 0 else 3.5)
		if phase >= 4 and tick_index % 2 == 0:
			draw_line(tick_center, tick_center + Vector2.from_angle(tick_angle + PI * 0.5) * 17.0, Color(core, 0.76), 3.0)
	draw_arc(p, radius + 28.0, game_time * 0.10, game_time * 0.10 + PI * 1.68, 52, Color(time_color, 0.44), 3.0)

	# 左齒輪翼與右水晶翼建立不對稱輪廓。
	var gear_center := p - side * 62.0 - facing * 8.0
	draw_circle(gear_center, 37.0, navy)
	draw_arc(gear_center, 37.0, 0.0, TAU, 28, gold, 5.0)
	for tooth_index in 8:
		var tooth_angle := game_time * 0.16 + TAU * float(tooth_index) / 8.0
		var tooth := gear_center + Vector2.from_angle(tooth_angle) * 46.0
		draw_rect(Rect2(tooth - Vector2(7.0, 4.0), Vector2(14.0, 8.0)), Color(gold, 0.84))
	draw_circle(gear_center, 12.0, Color("08101F"))
	var crystal_center := p + side * 57.0 - facing * 5.0
	for crystal_index in 3:
		var crystal_offset := (float(crystal_index) - 1.0) * 24.0
		var crystal_pos := crystal_center + side * crystal_offset + facing * absf(crystal_offset) * -0.22
		_draw_polygon_shape(crystal_pos, [Vector2(-10, 0), Vector2(0, -31), Vector2(12, 0), Vector2(0, 25)], facing.angle(), Color("17354F"), Color(time_color, 0.90), 3.0)

	# 象牙白鐘甲、深藍面罩及紅色星核。
	var body_points := [Vector2(-56, -38), Vector2(-8, -66), Vector2(47, -42), Vector2(69, 0), Vector2(42, 49), Vector2(-8, 63), Vector2(-55, 37), Vector2(-70, 0)]
	_draw_polygon_shape(p, body_points, facing.angle(), ivory, Color("070D1B"), 5.0)
	var armor_points := [Vector2(-43, -27), Vector2(4, -47), Vector2(48, -23), Vector2(54, 14), Vector2(16, 41), Vector2(-36, 28)]
	_draw_polygon_shape(p, armor_points, facing.angle(), navy, Color(gold, 0.84), 3.0)
	for seam_index in 4:
		var seam_angle := facing.angle() + float(seam_index) * PI * 0.5 + 0.25
		draw_line(p + Vector2.from_angle(seam_angle) * 19.0, p + Vector2.from_angle(seam_angle) * 43.0, Color(time_color, 0.48), 2.0)
	var core_center := p + facing * 7.0
	draw_circle(core_center, 31.0 + sin(game_time * 6.0) * 2.0, Color(core, 0.16))
	draw_circle(core_center, 21.0, Color("070C18"))
	draw_circle(core_center, 13.0 + sin(game_time * 6.0) * 1.8, core)
	draw_circle(core_center - Vector2(4.0, 5.0), 4.5, Color("FFF3E3"))

	# 時針長槍與黑色星核炮。
	var spear_base := p - side * 25.0 + facing * 18.0
	draw_line(spear_base - facing * 14.0, spear_base + facing * 104.0, Color("24334A"), 13.0)
	draw_line(spear_base, spear_base + facing * 112.0, gold, 5.0)
	_draw_polygon_shape(spear_base + facing * 118.0, [Vector2(-18, -10), Vector2(25, 0), Vector2(-18, 10), Vector2(-7, 0)], facing.angle(), ivory, gold, 2.5)
	var cannon_base := p + side * 38.0 + facing * 28.0
	_draw_polygon_shape(cannon_base, [Vector2(-27, -18), Vector2(20, -15), Vector2(36, 0), Vector2(20, 15), Vector2(-27, 18)], facing.angle(), Color("050912"), Color(time_color, 0.76), 3.0)
	draw_line(cannon_base, cannon_base + facing * 62.0, Color("0A1324"), 19.0)
	draw_arc(cannon_base + facing * 64.0, 13.0, 0.0, TAU, 20, time_color, 4.0)
	draw_circle(cannon_base + facing * 64.0, 6.0 + sin(game_time * 7.4) * 1.2, core)

	var hp_ratio := clampf(float(snapshot.get("hp_ratio", 1.0)), 0.0, 1.0)
	_draw_bar(p + Vector2(-108.0, -148.0), Vector2(216.0, 10.0), hp_ratio, gold if phase < 4 else core, Color("080E1D"))
	_draw_text("諸界終時者・艾歐尼斯", p + Vector2(0.0, -160.0), 13, Color("FFF4D5"), HORIZONTAL_ALIGNMENT_CENTER, 290.0)
	var active_skill := str(snapshot.get("telegraph_skill", snapshot.get("active_skill", "")))
	if not active_skill.is_empty():
		_draw_text(_aionis_skill_name(active_skill), p + Vector2(0.0, 108.0), 12, Color("FFB0A6") if str(snapshot.get("state", "")) == "TELEGRAPH" else time_color, HORIZONTAL_ALIGNMENT_CENTER, 250.0)


func _draw_character_icon(class_id: String, center: Vector2, scale: float, rotation: float = 0.0, flash: bool = false) -> void:
	var main_color := Color("EAF6FF") if flash else Color(GameConfig.HERO_CLASSES[class_id]["color"])
	_draw_ellipse_shadow(center + Vector2(5, 9) * scale, Vector2(17, 7) * scale)
	match class_id:
		"archer":
			_draw_polygon_shape(center, [Vector2(-12, 0), Vector2(-8, -8), Vector2(2, -10), Vector2(12, 0), Vector2(2, 10), Vector2(-8, 8)], rotation, main_color, FRIEND_DARK, 2.5 * scale, scale)
			var bow_base := center + Vector2(0, -12).rotated(rotation) * scale
			draw_arc(bow_base, 13.0 * scale, rotation - 1.1, rotation + 1.1, 12, Color("8B5A2B"), 2.2 * scale)
			draw_line(center + Vector2(2, -24).rotated(rotation) * scale, center + Vector2(2, 0).rotated(rotation) * scale, Color("EAF6FF"), 1.0 * scale)
		"mage":
			_draw_polygon_shape(center, [Vector2(-11, 9), Vector2(-13, -2), Vector2(-5, -12), Vector2(8, -10), Vector2(14, 2), Vector2(9, 11)], rotation, main_color, FRIEND_DARK, 2.5 * scale, scale)
			_draw_polygon_shape(center + Vector2(0, -12).rotated(rotation) * scale, [Vector2(-9, 4), Vector2(4, -14), Vector2(11, 5)], rotation, Color("6E58A8"), FRIEND_DARK, 2.0 * scale, scale)
			var orb := center + Vector2(18, -7).rotated(rotation) * scale
			draw_line(center + Vector2(9, 7).rotated(rotation) * scale, orb, Color("8B5A2B"), 2.0 * scale)
			draw_circle(orb, 4.0 * scale, MAGIC_PURPLE)
		"warrior":
			_draw_polygon_shape(center, [Vector2(-14, 9), Vector2(-15, -8), Vector2(-7, -13), Vector2(9, -12), Vector2(15, -5), Vector2(14, 10)], rotation, main_color, FRIEND_DARK, 2.5 * scale, scale)
			var shield := center + Vector2(-13, 0).rotated(rotation) * scale
			_draw_polygon_shape(shield, [Vector2(-6, -10), Vector2(7, -8), Vector2(9, 3), Vector2(0, 12), Vector2(-8, 4)], rotation, Color("A7B2BE"), FRIEND_DARK, 2.0 * scale, scale)
			var sword_a := center + Vector2(8, 4).rotated(rotation) * scale
			var sword_b := center + Vector2(23, -10).rotated(rotation) * scale
			draw_line(sword_a, sword_b, Color("EAF6FF"), 3.0 * scale)
			draw_line(center + Vector2(5, 0).rotated(rotation) * scale, center + Vector2(14, 8).rotated(rotation) * scale, GOLD, 2.0 * scale)


func _draw_soldier(soldier: Dictionary) -> void:
	var ground_p := _world_to_screen(soldier["pos"])
	if not _on_screen(ground_p, 90): return
	var type_id := str(soldier["type"])
	var color := Color("EAF6FF") if float(soldier["flash"]) > 0.0 else Color(GameConfig.SOLDIERS[type_id]["color"])
	var r := float(soldier["radius"])
	var airborne := _soldier_is_air(soldier)
	var p := ground_p - Vector2(0.0, 14.0 + sin(game_time * 3.4 + int(soldier["id"])) * 2.5) if airborne else ground_p
	if airborne:
		_draw_ellipse_shadow(ground_p + Vector2(16, 25), Vector2(r * 1.2, r * 0.48))
	else:
		_draw_ellipse_shadow(p + Vector2(4, 7), Vector2(r, r * 0.45))
	if type_id == "cannon":
		var cannon_facing := Vector2(soldier.get("aim_dir", Vector2.RIGHT)).normalized()
		if cannon_facing.length_squared() < 0.01: cannon_facing = Vector2.RIGHT
		var cannon_side := Vector2(-cannon_facing.y, cannon_facing.x)
		for wheel_side in [-1.0, 1.0]:
			var wheel_center: Vector2 = p - cannon_facing * 8.0 + cannon_side * wheel_side * 15.0
			draw_circle(wheel_center, 9.0, INK)
			draw_arc(wheel_center, 9.0, 0, TAU, 16, Color("79A6C1"), 2.0)
		_draw_polygon_shape(p - cannon_facing * 4.0, [Vector2(-20, -13), Vector2(16, -13), Vector2(21, 12), Vector2(-20, 12)], cannon_facing.angle(), Color("7D9FB2"), FRIEND_DARK, 2.8)
		# 藍色雙層裝甲與加粗長砲管，與敵方棕色普通大砲一眼區分。
		_draw_polygon_shape(p, [Vector2(-14, -8), Vector2(14, -8), Vector2(17, 7), Vector2(-14, 7)], cannon_facing.angle(), FRIEND_BLUE, Color("B9E0F4"), 2.0)
		draw_line(p + cannon_facing * 2.0, p + cannon_facing * 39.0, Color("D5E7EF"), 12.0)
		draw_line(p + cannon_facing * 34.0, p + cannon_facing * 44.0, Color("202A30"), 15.0)
		draw_circle(p - cannon_facing * 10.0, 7.0, GOLD)
	elif type_id == "tank":
		var tank_facing := Vector2(soldier.get("aim_dir", Vector2.RIGHT)).normalized()
		if tank_facing.length_squared() < 0.01: tank_facing = Vector2.RIGHT
		var tank_side := Vector2(-tank_facing.y, tank_facing.x)
		for track_side in [-1.0, 1.0]:
			var track_center: Vector2 = p + tank_side * track_side * 18.0
			_draw_polygon_shape(track_center, [Vector2(-27, -7), Vector2(27, -7), Vector2(27, 7), Vector2(-27, 7)], tank_facing.angle(), Color("263238"), FRIEND_DARK, 2.0)
			for tread_index in 6:
				var tread_center: Vector2 = track_center + tank_facing * (-21.0 + float(tread_index) * 8.5)
				draw_line(tread_center - tank_side * 5.0, tread_center + tank_side * 5.0, Color("8EB1BD"), 1.5)
		_draw_polygon_shape(p, [Vector2(-25, -15), Vector2(20, -15), Vector2(27, 0), Vector2(20, 15), Vector2(-25, 15)], tank_facing.angle(), Color("70875B"), FRIEND_DARK, 3.0)
		draw_circle(p, 14.0, Color("86A66A"))
		draw_arc(p, 14.0, 0, TAU, 20, Color("CDE7D0"), 2.2)
		draw_line(p + tank_facing * 5.0, p + tank_facing * 43.0, Color("C8D8CF"), 10.0)
		draw_circle(p + tank_facing * 43.0, 5.5, Color("233137"))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), FRIEND_BLUE)
	elif type_id == "rocket":
		var rocket_facing := Vector2(soldier.get("aim_dir", Vector2.RIGHT)).normalized()
		if rocket_facing.length_squared() < 0.01: rocket_facing = Vector2.RIGHT
		var rocket_side := Vector2(-rocket_facing.y, rocket_facing.x)
		for wheel_side in [-1.0, 1.0]:
			draw_circle(p - rocket_facing * 8.0 + rocket_side * wheel_side * 15.0, 8.0, INK)
		_draw_polygon_shape(p - rocket_facing * 7.0, [Vector2(-19, -14), Vector2(17, -14), Vector2(21, 14), Vector2(-19, 14)], rocket_facing.angle(), Color("55788C"), FRIEND_DARK, 2.5)
		for lane in [-1.0, 0.0, 1.0]:
			var launcher_offset: Vector2 = rocket_side * lane * 8.0
			draw_line(p - rocket_facing * 3.0 + launcher_offset, p + rocket_facing * 33.0 + launcher_offset, Color("C7D9E1"), 7.0)
			_draw_polygon_shape(p + rocket_facing * 36.0 + launcher_offset, [Vector2(-7, -5), Vector2(6, 0), Vector2(-7, 5)], rocket_facing.angle(), FIRE_ORANGE, Color("743224"), 1.2)
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), FRIEND_BLUE)
	elif type_id == "gatling":
		var gatling_facing := Vector2(soldier.get("aim_dir", Vector2.RIGHT)).normalized()
		if gatling_facing.length_squared() < 0.01: gatling_facing = Vector2.RIGHT
		var gatling_side := Vector2(-gatling_facing.y, gatling_facing.x)
		_draw_polygon_shape(p - gatling_facing * 7.0, [Vector2(-18, -14), Vector2(16, -12), Vector2(20, 12), Vector2(-18, 14)], gatling_facing.angle(), Color("4D7894"), FRIEND_DARK, 2.6)
		draw_circle(p, 12.0, Color("B8DDEC"))
		for barrel_lane in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			var barrel_offset: Vector2 = gatling_side * float(barrel_lane) * 3.0
			draw_line(p + gatling_facing * 6.0 + barrel_offset, p + gatling_facing * (36.0 - abs(barrel_lane)) + barrel_offset, Color("D6EEF6"), 3.2)
		draw_circle(p + gatling_facing * 37.0, 6.0, Color("83E8FF"), false, 2.0)
	elif type_id == "helicopter":
		var helicopter_facing := Vector2(soldier.get("aim_dir", Vector2.RIGHT)).normalized()
		if helicopter_facing.length_squared() < 0.01: helicopter_facing = Vector2.RIGHT
		var helicopter_side := Vector2(-helicopter_facing.y, helicopter_facing.x)
		_draw_polygon_shape(p, [Vector2(-24, -14), Vector2(17, -16), Vector2(29, 0), Vector2(17, 16), Vector2(-24, 14), Vector2(-31, 0)], helicopter_facing.angle(), Color("4F9AB8"), FRIEND_DARK, 3.0)
		draw_circle(p + helicopter_facing * 13.0, 11.0, Color("B8F2FF"))
		draw_line(p - helicopter_facing * 20.0, p - helicopter_facing * 55.0, Color("426E83"), 8.0)
		_draw_polygon_shape(p - helicopter_facing * 57.0, [Vector2(-9, -13), Vector2(8, 0), Vector2(-9, 13)], helicopter_facing.angle(), FRIEND_BLUE, FRIEND_DARK, 2.0)
		var rotor_direction := Vector2.from_angle(game_time * 12.0 + int(soldier["id"]))
		draw_line(p - rotor_direction * 43.0, p + rotor_direction * 43.0, Color(0.75, 0.95, 1.0, 0.76), 3.0)
		draw_line(p - rotor_direction.rotated(PI * 0.5) * 36.0, p + rotor_direction.rotated(PI * 0.5) * 36.0, Color(0.75, 0.95, 1.0, 0.48), 2.0)
		draw_line(p + helicopter_facing * 17.0, p + helicopter_facing * 38.0, Color("D6EEF6"), 5.0)
	elif type_id == "bomber":
		var bomber_facing := Vector2(soldier.get("aim_dir", Vector2.RIGHT)).normalized()
		if bomber_facing.length_squared() < 0.01: bomber_facing = Vector2.RIGHT
		var bomber_side := Vector2(-bomber_facing.y, bomber_facing.x)
		_draw_polygon_shape(p, [Vector2(-35, -13), Vector2(-13, -12), Vector2(-3, -48), Vector2(14, -43), Vector2(21, -13), Vector2(40, 0), Vector2(21, 13), Vector2(14, 43), Vector2(-3, 48), Vector2(-13, 12), Vector2(-35, 13)], bomber_facing.angle(), Color("718DB6"), FRIEND_DARK, 3.0)
		_draw_polygon_shape(p + bomber_facing * 4.0, [Vector2(-28, -7), Vector2(30, 0), Vector2(-28, 7)], bomber_facing.angle(), Color("A9D8FF"), Color.TRANSPARENT, 0.0)
		for engine_side in [-1.0, 1.0]:
			var engine_center: Vector2 = p - bomber_facing * 3.0 + bomber_side * float(engine_side) * 22.0
			draw_circle(engine_center, 8.0, Color("263B4B"))
			draw_circle(engine_center - bomber_facing * 3.0, 4.0, Color("83E8FF"))
		draw_rect(Rect2(p - Vector2(9, 5), Vector2(18, 10)), FRIEND_BLUE)
	elif type_id == "ufo":
		var ufo_pulse := 0.5 + 0.5 * sin(game_time * 5.5 + int(soldier["id"]))
		draw_circle(p + Vector2(0, 9), 38.0 + ufo_pulse * 4.0, Color(0.25, 0.88, 1.0, 0.12 + ufo_pulse * 0.08))
		_draw_polygon_shape(p, [Vector2(-43, -4), Vector2(-31, -13), Vector2(-16, -18), Vector2(16, -18), Vector2(31, -13), Vector2(43, -4), Vector2(37, 8), Vector2(20, 15), Vector2(-20, 15), Vector2(-37, 8)], 0.0, Color("5D91A8"), FRIEND_DARK, 3.0)
		draw_circle(p + Vector2(0, -10), 17.0, Color("A8FBFF"))
		draw_arc(p + Vector2(0, 1), 35.0, 0.1, PI - 0.1, 28, Color("75E8FF"), 4.0)
		for ufo_light_index in 5:
			draw_circle(p + Vector2(-24.0 + float(ufo_light_index) * 12.0, 10), 3.5 + ufo_pulse, GOLD if ufo_light_index % 2 == 0 else Color("75E8FF"))
		draw_circle(p + Vector2(0, 18), 10.0 + ufo_pulse * 3.0, Color(0.35, 0.9, 1.0, 0.42))
	else:
		var points := [Vector2(-r, 4), Vector2(-r * 0.7, -r * 0.75), Vector2(0, -r), Vector2(r * 0.8, -r * 0.55), Vector2(r, 5), Vector2(0, r)]
		_draw_polygon_shape(p, points, 0.0, color, FRIEND_DARK, 2.0)
		match type_id:
			"swordsman":
				draw_line(p + Vector2(6, 3), p + Vector2(17, -9), Color("EAF6FF"), 2.5)
				draw_line(p + Vector2(3, 0), p + Vector2(10, 7), GOLD, 2.0)
			"healer":
				draw_line(p + Vector2(-5, 0), p + Vector2(5, 0), HEAL_GREEN, 3.0)
				draw_line(p + Vector2(0, -5), p + Vector2(0, 5), HEAL_GREEN, 3.0)
			"archer":
				draw_arc(p + Vector2(7, 0), 8.0, -1.1, 1.1, 10, Color("8B5A2B"), 1.6)
			"roller":
				draw_circle(p + Vector2(11, -2), 7.0, Color("778493"))
				draw_line(p + Vector2(8, -5), p + Vector2(14, 1), Color("BFD0DA"), 1.0)
			"mage":
				draw_line(p + Vector2(4, 8), p + Vector2(11, -9), Color("8B5A2B"), 2.0)
				draw_circle(p + Vector2(11, -9), 3.0, MAGIC_PURPLE)
			"heavy":
				_draw_polygon_shape(p + Vector2(-10, 0), [Vector2(-7, -10), Vector2(6, -9), Vector2(9, 5), Vector2(0, 11), Vector2(-8, 5)], 0.0, Color("A7B2BE"), FRIEND_DARK, 1.6)
			"priest":
				draw_arc(p, r + 3.0, PI, TAU, 16, GOLD, 2.0)
				draw_line(p + Vector2(8, 7), p + Vector2(14, -9), GOLD, 2.0)
			"musketeer":
				var musket_facing := Vector2(soldier.get("aim_dir", Vector2.RIGHT)).normalized()
				if musket_facing.length_squared() < 0.01: musket_facing = Vector2.RIGHT
				draw_line(p - musket_facing * 8.0, p + musket_facing * 31.0, Color("875B36"), 5.0)
				draw_line(p + musket_facing * 3.0, p + musket_facing * 37.0, Color("E1E9ED"), 2.4)
				draw_line(p + musket_facing * 33.0, p + musket_facing * 41.0, Color("FFFFFF"), 1.5)
				draw_arc(p + Vector2(0, -8), 9.0, PI, TAU, 12, Color("725039"), 4.0)
			"rifleman":
				var rifle_facing := Vector2(soldier.get("aim_dir", Vector2.RIGHT)).normalized()
				if rifle_facing.length_squared() < 0.01: rifle_facing = Vector2.RIGHT
				var rifle_side := Vector2(-rifle_facing.y, rifle_facing.x)
				draw_circle(p + Vector2(0, -8), 7.0, Color("5D8E76"))
				draw_line(p - rifle_facing * 7.0, p + rifle_facing * 31.0, Color("263136"), 5.0)
				draw_line(p + rifle_facing * 6.0, p + rifle_facing * 35.0, Color("DCE8EA"), 1.8)
				_draw_polygon_shape(p + rifle_facing * 4.0 + rifle_side * 5.0, [Vector2(-3, -2), Vector2(4, -2), Vector2(6, 8), Vector2(-1, 9)], rifle_facing.angle(), Color("20282C"), FRIEND_DARK, 1.0)
	var charge_seconds := _soldier_charge_seconds(type_id)
	if float(soldier["charge"]) > 0.0 and charge_seconds > 0.0:
		var charge_ratio := 1.0 - float(soldier["charge"]) / charge_seconds
		_draw_bar(p + Vector2(-r - 5.0, -r - 20.0), Vector2((r + 5.0) * 2.0, 5.0), charge_ratio, GOLD, Color("18242A"))
	if float(soldier["hp"]) < float(soldier["max_hp"]):
		_draw_bar(p + Vector2(-r - 4, -r - 11), Vector2((r + 4) * 2, 4), float(soldier["hp"]) / float(soldier["max_hp"]), HEAL_GREEN, Color("18242A"))
	if type_id in ["cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"]:
		_draw_text(str(GameConfig.SOLDIERS[type_id]["name"]), p + Vector2(0, r + 18.0), 10, Color("C9EDFF"), HORIZONTAL_ALIGNMENT_CENTER, 104.0)


func _draw_enemy(enemy: Dictionary) -> void:
	var ground_p := _world_to_screen(enemy["pos"])
	if not _on_screen(ground_p, 130): return
	var type_id := str(enemy["type"])
	var r := float(enemy["radius"])
	var airborne := _enemy_is_air(enemy)
	var p := ground_p - Vector2(0, 12.0 + sin(game_time * 3.2 + int(enemy["id"])) * 2.5) if airborne else ground_p
	if enemy["state"] == "telegraph":
		var max_tell := maxf(0.08, float(enemy.get("telegraph_duration", 0.78 if type_id == "chief" else (0.62 if type_id in ["thrower", "heavy"] else 0.32))))
		var ratio: float = clamp(float(enemy["telegraph"]) / max_tell, 0.0, 1.0)
		var telegraph_style := str(enemy.get("attack_style", "melee"))
		var warning_radius: float = 162.0 if type_id == "chief" else (30.0 if telegraph_style != "melee" else max(42.0, float(enemy["range"]) + 28.0))
		draw_circle(p, warning_radius, Color(0.95, 0.28, 0.16, 0.12 * (1.0 - ratio) + 0.05))
		draw_arc(p, warning_radius, 0, TAU, 44, Color(1.0, 0.45, 0.22, 0.85), 2.5)
		if telegraph_style != "melee" and type_id != "chief":
			var target_screen := _world_to_screen(Vector2(enemy.get("pending_pos", enemy["pos"])))
			draw_line(p, target_screen, Color(1.0, 0.36, 0.18, 0.72), 2.0)
			var target_warning_radius := clampf(13.0 + float(enemy.get("aoe", 0.0)) * 0.12, 13.0, 42.0)
			draw_circle(target_screen, target_warning_radius, Color(1.0, 0.24, 0.12, 0.12))
			draw_arc(target_screen, target_warning_radius, 0, TAU, 32, Color("FF6B42"), 2.0)
	var color := Color("FFF2E6") if float(enemy["flash"]) > 0.0 else Color(GameConfig.ENEMIES[type_id]["color"])
	if airborne:
		_draw_ellipse_shadow(ground_p + Vector2(18, 28), Vector2(r * 1.25, r * 0.52))
		draw_line(ground_p + Vector2(18, 25), p + Vector2(4, 7), Color(0.12, 0.18, 0.18, 0.20), 2.0)
	else:
		_draw_ellipse_shadow(p + Vector2(4, 7), Vector2(r, r * 0.45))
	if type_id == "cannon":
		var facing := Vector2(enemy.get("aim_dir", Vector2.RIGHT)).normalized()
		if facing.length_squared() < 0.01: facing = Vector2.RIGHT
		var side := Vector2(-facing.y, facing.x)
		for wheel_side in [-1.0, 1.0]:
			draw_circle(p - facing * 7.0 + side * wheel_side * 14.0, 9.0, Color("24292D"))
			draw_arc(p - facing * 7.0 + side * wheel_side * 14.0, 9.0, 0, TAU, 16, Color("8B6B4C"), 2.0)
		_draw_polygon_shape(p, [Vector2(-17, -12), Vector2(15, -12), Vector2(19, 11), Vector2(-17, 11)], facing.angle(), Color("78593E"), ENEMY_DARK, 2.5)
		draw_line(p - facing * 3.0, p + facing * 36.0, Color("30383E"), 10.0)
		draw_line(p + facing * 31.0, p + facing * 39.0, Color("151B1E"), 13.0)
		draw_circle(p - facing * 9.0, 6.0, Color("B87945"))
	elif type_id == "tank":
		var tank_facing := Vector2(enemy.get("aim_dir", Vector2.RIGHT)).normalized()
		if tank_facing.length_squared() < 0.01: tank_facing = Vector2.RIGHT
		var tank_side := Vector2(-tank_facing.y, tank_facing.x)
		for track_side in [-1.0, 1.0]:
			_draw_polygon_shape(p + tank_side * track_side * 17.0, [Vector2(-25, -7), Vector2(25, -7), Vector2(25, 7), Vector2(-25, 7)], tank_facing.angle(), Color("252B2B"), ENEMY_DARK, 2.0)
			for tread_index in 5:
				var tread_center: Vector2 = p + tank_side * track_side * 17.0 + tank_facing * (-18.0 + tread_index * 9.0)
				draw_line(tread_center - tank_side * 5.0, tread_center + tank_side * 5.0, Color("72766B"), 1.4)
		_draw_polygon_shape(p, [Vector2(-23, -15), Vector2(19, -15), Vector2(25, 0), Vector2(18, 15), Vector2(-23, 15)], tank_facing.angle(), color, ENEMY_DARK, 3.0)
		draw_circle(p, 13.0, Color("4F5D45"))
		draw_arc(p, 13.0, 0, TAU, 20, ENEMY_DARK, 2.5)
		draw_line(p + tank_facing * 4.0, p + tank_facing * 40.0, Color("303B32"), 9.0)
		draw_circle(p + tank_facing * 41.0, 5.0, Color("181E1A"))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("B64E3A"))
	elif type_id == "rocket":
		var launcher_facing := Vector2(enemy.get("aim_dir", Vector2.RIGHT)).normalized()
		if launcher_facing.length_squared() < 0.01: launcher_facing = Vector2.RIGHT
		var launcher_side := Vector2(-launcher_facing.y, launcher_facing.x)
		for launcher_wheel_side in [-1.0, 1.0]:
			draw_circle(p - launcher_facing * 8.0 + launcher_side * launcher_wheel_side * 14.0, 8.0, Color("252A2B"))
		_draw_polygon_shape(p - launcher_facing * 6.0, [Vector2(-17, -13), Vector2(16, -13), Vector2(19, 13), Vector2(-17, 13)], launcher_facing.angle(), Color("735545"), ENEMY_DARK, 2.3)
		for rocket_lane in [-1.0, 0.0, 1.0]:
			var rocket_offset: Vector2 = launcher_side * rocket_lane * 7.0
			draw_line(p - launcher_facing * 4.0 + rocket_offset, p + launcher_facing * 31.0 + rocket_offset, Color("4A5355"), 6.0)
			_draw_polygon_shape(p + launcher_facing * 34.0 + rocket_offset, [Vector2(-6, -4), Vector2(5, 0), Vector2(-6, 4)], launcher_facing.angle(), Color("D85A36"), ENEMY_DARK, 1.0)
	elif type_id == "gatling":
		var gatling_facing := Vector2(enemy.get("aim_dir", Vector2.RIGHT)).normalized()
		if gatling_facing.length_squared() < 0.01: gatling_facing = Vector2.RIGHT
		var gatling_side := Vector2(-gatling_facing.y, gatling_facing.x)
		_draw_polygon_shape(p - gatling_facing * 7.0, [Vector2(-17, -14), Vector2(15, -12), Vector2(19, 12), Vector2(-17, 14)], gatling_facing.angle(), Color("66584C"), ENEMY_DARK, 2.5)
		draw_circle(p, 12.0, Color("343C3F"))
		draw_arc(p, 12.0, game_time * 7.0, game_time * 7.0 + 5.2, 18, Color("B78A48"), 3.0)
		for barrel_lane in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			var barrel_offset: Vector2 = gatling_side * barrel_lane * 3.0
			draw_line(p + gatling_facing * 6.0 + barrel_offset, p + gatling_facing * (35.0 - abs(barrel_lane) * 1.5) + barrel_offset, Color("2A3235"), 3.2)
		draw_circle(p + gatling_facing * 36.0, 5.0, Color("D9A441"), false, 2.0)
		draw_line(p - gatling_facing * 9.0, p - gatling_facing * 21.0 + gatling_side * 14.0, Color("423A33"), 4.0)
		draw_line(p - gatling_facing * 9.0, p - gatling_facing * 21.0 - gatling_side * 14.0, Color("423A33"), 4.0)
	elif type_id == "helicopter":
		var helicopter_facing := Vector2(enemy.get("aim_dir", Vector2.RIGHT)).normalized()
		if helicopter_facing.length_squared() < 0.01: helicopter_facing = Vector2.RIGHT
		var helicopter_side := Vector2(-helicopter_facing.y, helicopter_facing.x)
		_draw_polygon_shape(p, [Vector2(-23, -13), Vector2(16, -15), Vector2(28, 0), Vector2(16, 15), Vector2(-23, 13), Vector2(-30, 0)], helicopter_facing.angle(), color, ENEMY_DARK, 3.0)
		draw_circle(p + helicopter_facing * 13.0, 11.0, Color("9BD2D2"))
		draw_arc(p + helicopter_facing * 13.0, 11.0, 0, TAU, 18, ENEMY_DARK, 2.0)
		draw_line(p - helicopter_facing * 20.0, p - helicopter_facing * 54.0, Color("344A42"), 8.0)
		_draw_polygon_shape(p - helicopter_facing * 56.0, [Vector2(-9, -13), Vector2(8, 0), Vector2(-9, 13)], helicopter_facing.angle(), Color("6E8577"), ENEMY_DARK, 2.0)
		var rotor_direction := Vector2.from_angle(game_time * 12.0 + int(enemy["id"]))
		draw_line(p - rotor_direction * 42.0, p + rotor_direction * 42.0, Color(0.82, 0.93, 0.92, 0.72), 3.0)
		draw_line(p - rotor_direction.rotated(PI * 0.5) * 35.0, p + rotor_direction.rotated(PI * 0.5) * 35.0, Color(0.82, 0.93, 0.92, 0.52), 2.0)
		var tail_rotor_center := p - helicopter_facing * 55.0
		draw_circle(tail_rotor_center, 8.0, Color("222B2D"))
		draw_line(tail_rotor_center - helicopter_side * 12.0, tail_rotor_center + helicopter_side * 12.0, Color("D9E4E6"), 2.0)
		draw_line(p + helicopter_facing * 17.0, p + helicopter_facing * 37.0, Color("2A3235"), 5.0)
	elif type_id == "bomber":
		var bomber_facing := Vector2(enemy.get("aim_dir", Vector2.RIGHT)).normalized()
		if bomber_facing.length_squared() < 0.01: bomber_facing = Vector2.RIGHT
		var bomber_side := Vector2(-bomber_facing.y, bomber_facing.x)
		_draw_polygon_shape(p, [Vector2(-34, -13), Vector2(-13, -12), Vector2(-3, -47), Vector2(13, -42), Vector2(20, -13), Vector2(39, 0), Vector2(20, 13), Vector2(13, 42), Vector2(-3, 47), Vector2(-13, 12), Vector2(-34, 13)], bomber_facing.angle(), color, ENEMY_DARK, 3.0)
		_draw_polygon_shape(p + bomber_facing * 4.0, [Vector2(-28, -7), Vector2(29, 0), Vector2(-28, 7)], bomber_facing.angle(), Color("8496AA"), Color.TRANSPARENT, 0.0)
		for engine_side in [-1.0, 1.0]:
			var engine_center: Vector2 = p - bomber_facing * 3.0 + bomber_side * engine_side * 22.0
			draw_circle(engine_center, 8.0, Color("252D35"))
			draw_circle(engine_center - bomber_facing * 3.0, 4.0, Color("F28C45"))
		draw_rect(Rect2(p - Vector2(9, 5), Vector2(18, 10)), Color("2B333A"))
		draw_line(p - bomber_facing * 8.0, p + bomber_facing * 13.0, Color("E2B34B"), 3.0)
	elif type_id == "ufo":
		var ufo_pulse := 0.5 + 0.5 * sin(game_time * 5.5 + int(enemy["id"]))
		draw_circle(p + Vector2(0, 9), 37.0 + ufo_pulse * 4.0, Color(0.28, 1.0, 0.92, 0.10 + ufo_pulse * 0.07))
		_draw_polygon_shape(p, [Vector2(-42, -4), Vector2(-30, -13), Vector2(-16, -18), Vector2(16, -18), Vector2(30, -13), Vector2(42, -4), Vector2(36, 8), Vector2(20, 15), Vector2(-20, 15), Vector2(-36, 8)], 0.0, Color("71878C"), ENEMY_DARK, 3.0)
		draw_circle(p + Vector2(0, -10), 17.0, Color("7FE8E1"))
		draw_arc(p + Vector2(0, -10), 17.0, PI, TAU, 20, Color("D5FFFA"), 2.5)
		draw_arc(p + Vector2(0, 1), 35.0, 0.1, PI - 0.1, 28, Color("75FFF0"), 4.0)
		for ufo_light_index in 5:
			var ufo_light_x := -24.0 + float(ufo_light_index) * 12.0
			draw_circle(p + Vector2(ufo_light_x, 10), 3.5 + ufo_pulse, Color("F5E86B") if ufo_light_index % 2 == 0 else Color("75FFF0"))
		draw_circle(p + Vector2(0, 18), 10.0 + ufo_pulse * 3.0, Color(0.38, 1.0, 0.92, 0.38))
	else:
		var points := [Vector2(-r, r * 0.45), Vector2(-r * 0.55, -r * 0.8), Vector2(r * 0.25, -r), Vector2(r, -r * 0.25), Vector2(r * 0.72, r * 0.7), Vector2(-r * 0.2, r)]
		_draw_polygon_shape(p, points, 0.0, color, ENEMY_DARK, 2.2)
	match type_id:
		"grunt":
			draw_line(p + Vector2(6, 4), p + Vector2(17, -8), Color("8B5A2B"), 4.0)
		"archer":
			draw_arc(p + Vector2(7, 0), 8.0, -1.2, 1.2, 10, Color("8B5A2B"), 1.8)
		"thrower":
			draw_circle(p + Vector2(8, -11), 7.0, Color("778493"))
		"berserker":
			draw_line(p + Vector2(-4, 3), p + Vector2(-16, -8), Color("A7B2BE"), 4.0)
			draw_line(p + Vector2(5, 3), p + Vector2(17, -8), Color("A7B2BE"), 4.0)
		"heavy":
			_draw_polygon_shape(p + Vector2(-10, 0), [Vector2(-7, -11), Vector2(7, -9), Vector2(9, 7), Vector2(0, 12), Vector2(-9, 6)], 0.0, Color("505A62"), ENEMY_DARK, 2.0)
		"shaman":
			draw_line(p + Vector2(5, 8), p + Vector2(13, -13), Color("6C4D32"), 2.5)
			draw_circle(p + Vector2(13, -13), 4.0, Color("94D46C"))
		"chief":
			draw_arc(p, r + 5.0, 0, TAU, 30, GOLD, 3.0)
			draw_line(p + Vector2(8, 6), p + Vector2(25, -13), Color("A7B2BE"), 6.0)
		"musketeer":
			var musket_facing := Vector2(enemy.get("aim_dir", Vector2.RIGHT)).normalized()
			if musket_facing.length_squared() < 0.01: musket_facing = Vector2.RIGHT
			draw_line(p - musket_facing * 7.0, p + musket_facing * 28.0, Color("6B4428"), 5.0)
			draw_line(p + musket_facing * 4.0, p + musket_facing * 34.0, Color("C6CCD0"), 2.4)
			draw_line(p + musket_facing * 30.0, p + musket_facing * 39.0, Color("E8EDF0"), 1.5)
			draw_arc(p + Vector2(0, -8), 9.0, PI, TAU, 10, Color("4D3425"), 4.0)
		"rifleman":
			var rifle_facing := Vector2(enemy.get("aim_dir", Vector2.RIGHT)).normalized()
			if rifle_facing.length_squared() < 0.01: rifle_facing = Vector2.RIGHT
			draw_circle(p + Vector2(0, -8), 7.0, Color("48594C"))
			draw_line(p - rifle_facing * 5.0, p + rifle_facing * 30.0, Color("20282B"), 5.0)
			draw_line(p + rifle_facing * 7.0, p + rifle_facing * 33.0, Color("AEB8BD"), 1.8)
			var magazine_side := Vector2(-rifle_facing.y, rifle_facing.x)
			_draw_polygon_shape(p + rifle_facing * 4.0 + magazine_side * 4.0, [Vector2(-3, -2), Vector2(4, -2), Vector2(6, 7), Vector2(-1, 8)], rifle_facing.angle(), Color("22292C"), ENEMY_DARK, 1.0)
	_draw_bar(p + Vector2(-r - 5, -r - 13), Vector2((r + 5) * 2, 5), float(enemy["hp"]) / float(enemy["max_hp"]), ENEMY_RED, Color("231A1A"))
	_draw_enemy_enhancement_badge(p, r, enemy)
	if type_id in ["cannon", "musketeer", "rifleman", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"]:
		var tech_label := str(GameConfig.ENEMIES[type_id]["name"]).replace("敵軍", "")
		_draw_text(tech_label, p + Vector2(0, r + 19.0), 10, Color("FFE9D3"), HORIZONTAL_ALIGNMENT_CENTER, 92.0)


func _draw_enemy_enhancement_badge(position: Vector2, radius: float, enemy: Dictionary) -> void:
	var points := int(enemy.get("enhancement_points", 0))
	if points <= 0:
		return
	var enhancement: Dictionary = Dictionary(enemy.get("enhancement", {}))
	var has_special := int(enhancement.get("special_count", 0)) > 0
	var aura_color := Color("FFB84E") if has_special else Color("D6E2EA")
	var pulse := 0.5 + 0.5 * sin(game_time * 4.5 + float(int(enemy.get("id", 0)) % 13))
	draw_arc(position, radius + 7.0 + pulse * 1.5, -2.7, 0.45, 20, Color(aura_color, 0.52 + pulse * 0.22), 1.8, true)
	var label := "▲%s" % ("99+" if points > 99 else str(points))
	var width := 42.0 if points < 10 else 50.0
	var badge_y := maxf(3.0, position.y - radius - 37.0)
	var badge := Rect2(position.x - width * 0.5, badge_y, width, 18.0)
	draw_rect(badge, Color(0.035, 0.025, 0.022, 0.92))
	draw_rect(badge, aura_color, false, 1.4)
	# The badge is language-neutral and appears on many enemies, so draw it
	# directly instead of running the full localization replacement table per unit.
	draw_string(ui_font, badge.position + Vector2(0.0, 13.0), label, HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 10, Color("FFF8EC"))


func _draw_projectiles() -> void:
	for projectile in projectiles:
		var p := _world_to_screen(projectile["pos"])
		if not _on_screen(p, 40): continue
		var velocity := Vector2(projectile["vel"])
		var direction := velocity.normalized()
		match str(projectile["kind"]):
			"arrow", "scatter_arrow", "ally_arrow", "enemy_arrow":
				draw_line(p - direction * 12.0, p + direction * 6.0, Color(projectile["color"]), 3.0)
				_draw_polygon_shape(p + direction * 8.0, [Vector2(-4, -3), Vector2(5, 0), Vector2(-4, 3)], direction.angle(), Color("EAF6FF"), Color.TRANSPARENT, 0.0)
			"rolling_rock", "enemy_stone":
				draw_circle(p, float(projectile["radius"]), Color(projectile["color"]))
				draw_arc(p, float(projectile["radius"]) * 0.65, game_time * 8.0, game_time * 8.0 + PI, 8, Color("D6DEE3"), 1.4)
			"cannonball", "enemy_cannonball":
				draw_circle(p, 12.0, Color("343A40"))
				draw_circle(p - direction * 6.0, 4.0, Color("A7B2BE"))
			"musket_ball", "enemy_musket_ball":
				draw_line(p - direction * 19.0, p + direction * 5.0, Color("FFE9B0"), 4.0)
				draw_circle(p + direction * 6.0, 3.0, Color("FFFFFF"))
			"rifle_round", "enemy_rifle_round", "gatling_round", "enemy_gatling_round":
				draw_line(p - direction * 15.0, p + direction * 5.0, Color(projectile["color"]), 2.4)
				draw_circle(p + direction * 5.0, 2.0, Color("FFFFFF"))
			"tank_shell", "enemy_tank_shell":
				draw_circle(p, 10.0, Color("3B4037"))
				draw_circle(p + direction * 4.0, 4.0, Color("C8A55A"))
			"rocket", "enemy_rocket":
				_draw_polygon_shape(p, [Vector2(-13, -6), Vector2(10, -6), Vector2(17, 0), Vector2(10, 6), Vector2(-13, 6)], direction.angle(), Color("D85A36"), Color("59281F"), 1.5)
				draw_circle(p - direction * 13.0, 6.0 + sin(game_time * 18.0) * 1.5, FIRE_ORANGE)
				draw_circle(p - direction * 17.0, 3.5, GOLD)
			"bomb":
				var bomb_progress: float = 1.0 - clampf(float(projectile["ttl"]) / maxf(0.01, float(projectile.get("initial_ttl", 1.0))), 0.0, 1.0)
				var bomb_visual := p + Vector2(0, -float(projectile.get("drop_height", 92.0)) * (1.0 - bomb_progress))
				var bomb_radius := float(projectile.get("aoe", 170.0))
				draw_circle(p, bomb_radius, Color(1.0, 0.20, 0.10, 0.045 + bomb_progress * 0.06))
				draw_arc(p, bomb_radius, 0, TAU, 48, Color(1.0, 0.35, 0.18, 0.55 + bomb_progress * 0.35), 2.5)
				draw_circle(p, 13.0 + bomb_progress * 8.0, Color(1.0, 0.18, 0.08, 0.12))
				draw_arc(p, 13.0 + bomb_progress * 8.0, 0, TAU, 24, Color("FF6B42"), 2.0)
				_draw_polygon_shape(bomb_visual, [Vector2(-7, -13), Vector2(7, -13), Vector2(10, 8), Vector2(0, 15), Vector2(-10, 8)], 0.0, Color("30373D"), Color("14191D"), 2.0)
				draw_line(bomb_visual + Vector2(-7, -10), bomb_visual + Vector2(-13, -18), Color("6F7A80"), 3.0)
				draw_line(bomb_visual + Vector2(7, -10), bomb_visual + Vector2(13, -18), Color("6F7A80"), 3.0)
			_:
				draw_circle(p, float(projectile["radius"]) + sin(game_time * 11.0) * 1.3, Color(projectile["color"]))
				draw_circle(p, max(2.0, float(projectile["radius"]) * 0.45), Color("F5FAFF"))


func _draw_python_boss_ground_effects() -> void:
	if python_boss == null:
		return
	var snapshot: Dictionary = python_boss.render_snapshot()
	var poison := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["poison_color"])
	var poison_dark := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["poison_dark"])
	# 毒潭先於單位繪製，保留邊緣與氣泡提示而不遮住角色。
	for pool_value in Array(snapshot.get("pools", [])):
		if not pool_value is Dictionary:
			continue
		var pool: Dictionary = Dictionary(pool_value)
		var pool_pos := _world_to_screen(Vector2(pool["pos"]))
		var pool_radius := float(pool["radius"])
		if not _on_screen(pool_pos, pool_radius + 40.0):
			continue
		var life_ratio: float = clampf(float(pool["ttl"]) / maxf(float(pool["duration"]), 0.01), 0.0, 1.0)
		var visible_radius: float = pool_radius * (0.72 + 0.28 * minf(1.0, life_ratio * 4.0))
		var alpha: float = 0.10 + life_ratio * 0.18
		draw_circle(pool_pos, visible_radius, Color(poison_dark, alpha + 0.09))
		draw_circle(pool_pos, visible_radius * 0.82, Color(poison, alpha))
		draw_arc(pool_pos, visible_radius, 0.0, TAU, 48, Color(poison.lightened(0.22), 0.40 + life_ratio * 0.28), 2.2)
		var slot := int(pool.get("slot", 0))
		for bubble_index in 5:
			var bubble_angle := float(slot * 17 + bubble_index * 11) * 0.73 + game_time * (0.45 + bubble_index * 0.06)
			var bubble_distance := visible_radius * (0.22 + 0.12 * float((slot + bubble_index) % 5))
			var bubble := pool_pos + Vector2.from_angle(bubble_angle) * bubble_distance
			var bubble_size := 2.5 + 2.0 * (0.5 + 0.5 * sin(game_time * 4.2 + bubble_index))
			draw_circle(bubble, bubble_size, Color(poison.lightened(0.45), 0.62 * life_ratio))
			draw_arc(bubble, bubble_size + 1.5, 0.0, TAU, 10, Color(0.90, 0.63, 1.0, 0.38 * life_ratio), 1.0)

	# 飛行毒球以拋物線視覺抬升；碰撞仍使用地面投影，判定保持確定性。
	for glob_value in Array(snapshot.get("globs", [])):
		if not glob_value is Dictionary:
			continue
		var glob: Dictionary = Dictionary(glob_value)
		var progress: float = clampf(float(glob["age"]) / maxf(float(glob["flight"]), 0.01), 0.0, 1.0)
		var ground_pos := _world_to_screen(Vector2(glob["pos"]))
		var destination := _world_to_screen(Vector2(glob["destination"]))
		var warning_radius: float = float(glob["radius"])
		draw_circle(destination, warning_radius, Color(0.72, 0.18, 0.88, 0.10 + progress * 0.08))
		draw_arc(destination, warning_radius * (0.35 + 0.65 * progress), 0.0, TAU, 36, Color(0.94, 0.38, 1.0, 0.82), 2.5)
		var airborne := ground_pos + Vector2(0.0, -sin(progress * PI) * 105.0)
		draw_circle(airborne, 10.0, Color(poison_dark, 0.96))
		draw_circle(airborne - Vector2(2, 3), 6.0, Color(poison.lightened(0.25), 0.92))
		draw_circle(ground_pos, 8.0 + 12.0 * sin(progress * PI), Color(0.08, 0.04, 0.10, 0.20))

	var telegraph: Dictionary = Dictionary(snapshot.get("telegraph", {}))
	if telegraph.is_empty():
		return
	var state := str(snapshot.get("state", ""))
	if state not in ["TELEGRAPH", "CASTING"]:
		return
	var duration: float = maxf(float(telegraph.get("duration", 0.5)), 0.01)
	var remaining_ratio: float = clampf(float(telegraph.get("remaining", 0.0)) / duration, 0.0, 1.0)
	var pulse: float = 0.72 + 0.28 * sin(game_time * 12.0)
	var warning := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["warning"])
	match str(telegraph.get("shape", "")):
		"circle":
			var center := _world_to_screen(Vector2(telegraph["center"]))
			var radius := float(telegraph["radius"])
			draw_circle(center, radius, Color(warning, 0.13))
			draw_arc(center, radius, 0.0, TAU, 36, Color(warning, 0.85), 2.5)
			draw_arc(center, radius * (0.30 + 0.70 * remaining_ratio), 0.0, TAU, 32, Color(1.0, 0.56, 0.88, pulse), 3.5)
		"capsule":
			var origin := _world_to_screen(Vector2(telegraph["origin"]))
			var endpoint := _world_to_screen(Vector2(telegraph["end"]))
			var width := float(telegraph["width"])
			draw_line(origin, endpoint, Color(0.30, 0.04, 0.12, 0.56), width + 8.0, true)
			draw_line(origin, endpoint, Color(warning, 0.20 + pulse * 0.08), width, true)
			draw_circle(endpoint, width * 0.5, Color(warning, 0.16))
			draw_arc(endpoint, width * 0.5, 0.0, TAU, 32, Color(warning, 0.95), 3.0)
			var marker := origin.lerp(endpoint, 1.0 - remaining_ratio)
			draw_line(marker - Vector2(0, width * 0.5), marker + Vector2(0, width * 0.5), Color(1.0, 0.83, 0.65, 0.86), 3.0)
		"sector":
			var origin := _world_to_screen(Vector2(telegraph["origin"]))
			var direction := Vector2(telegraph["direction"]).angle()
			_draw_screen_sector(origin, float(telegraph["range"]), direction, float(telegraph["angle"]), Color(warning, 0.18), Color(warning, 0.94))
		"multi_circle":
			for destination_value in Array(telegraph.get("destinations", [])):
				var center := _world_to_screen(Vector2(destination_value))
				var radius := float(telegraph["radius"])
				draw_circle(center, radius, Color(poison, 0.11))
				draw_arc(center, radius, 0.0, TAU, 40, Color(poison.lightened(0.32), 0.88), 2.5)
				draw_arc(center, radius * (0.25 + remaining_ratio * 0.75), 0.0, TAU, 32, Color(1.0, 0.50, 0.82, pulse), 3.0)
		"annular_sector":
			var pivot := _world_to_screen(Vector2(telegraph["pivot"]))
			var start_angle := float(telegraph["start_angle"])
			var arc := float(telegraph["arc"])
			_draw_screen_annular_sector(pivot, float(telegraph["inner_radius"]), float(telegraph["outer_radius"]), start_angle, arc, Color(1.0, 0.30, 0.12, 0.17), Color(1.0, 0.47, 0.20, 0.92))
			if state == "CASTING":
				var current_angle := float(snapshot.get("tail_angle", start_angle))
				draw_line(pivot + Vector2.from_angle(current_angle) * float(telegraph["inner_radius"]), pivot + Vector2.from_angle(current_angle) * float(telegraph["outer_radius"]), Color(1.0, 0.78, 0.40, 0.96), 8.0)


func _draw_chaos_ground_effects() -> void:
	var warning := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["warning"])
	var rift := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["rift"])
	var core := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["core"])
	var energy := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["energy"])
	if chaos_boss != null and not chaos_boss.is_defeated():
		var snapshot: Dictionary = chaos_boss.render_snapshot()
		if str(snapshot.get("state", "")) == "TELEGRAPH":
			var telegraph: Dictionary = Dictionary(snapshot.get("telegraph", {}))
			var skill := str(snapshot.get("active_skill", telegraph.get("skill", "")))
			var target := _world_to_screen(Vector2(snapshot.get("telegraph_position", snapshot.get("position", Vector2.ZERO))))
			var boss_center := _world_to_screen(Vector2(snapshot.get("position", Vector2.ZERO)))
			var radius := float(telegraph.get("radius", 120.0))
			var text_state: Dictionary = chaos_boss.get_text_state()
			var duration := maxf(0.01, float(telegraph.get("telegraph", 0.5)))
			var remaining_ratio := clampf(float(text_state.get("telegraph_timer", 0.0)) / duration, 0.0, 1.0)
			var pulse := 0.55 + 0.45 * sin(game_time * 14.0)
			match skill:
				"destruction_beam":
					var beam_direction := (target - boss_center).normalized()
					if beam_direction.length_squared() < 0.001: beam_direction = Vector2.RIGHT
					var beam_end := boss_center + beam_direction * 760.0
					draw_line(boss_center, beam_end, Color(warning, 0.10 + pulse * 0.09), radius * 2.0, true)
					draw_line(boss_center, beam_end, Color(energy, 0.75), 3.0 + (1.0 - remaining_ratio) * 4.0, true)
					draw_line(target - Vector2(0, radius), target + Vector2(0, radius), Color(warning, 0.88), 3.0)
				"rift_dash":
					draw_line(boss_center, target, Color(rift, 0.18), radius * 1.35, true)
					draw_line(boss_center, target, Color(warning, 0.90), 4.0, true)
					draw_circle(target, radius, Color(warning, 0.10))
					draw_arc(target, radius, 0.0, TAU, 48, Color(warning, 0.95), 3.5)
				"homing_missiles":
					draw_circle(boss_center, radius + 74.0, Color(core, 0.06))
					draw_arc(boss_center, radius + 74.0, -game_time * 1.7, TAU - game_time * 1.7, 48, Color(core, 0.90), 4.0)
					for missile_index in 6:
						var missile_angle := float(missile_index) * TAU / 6.0 - game_time * 1.7
						draw_circle(boss_center + Vector2.from_angle(missile_angle) * (radius + 74.0), 5.0, energy)
				"energy_barrage":
					var barrage_direction := (target - boss_center).normalized()
					if barrage_direction.length_squared() < 0.001: barrage_direction = Vector2.RIGHT
					_draw_screen_sector(boss_center, 620.0, barrage_direction.angle(), 1.08, Color(core, 0.07), Color(core, 0.58))
				"summon_monsters":
					draw_circle(target, radius + 55.0, Color(rift, 0.10))
					draw_arc(target, radius + 55.0, game_time, game_time + TAU, 48, Color(rift, 0.88), 3.0)
					for summon_index in 5:
						var summon_angle := float(summon_index) * TAU / 5.0 + 0.4
						var summon_point := target + Vector2.from_angle(summon_angle) * (radius + 28.0)
						draw_circle(summon_point, 23.0, Color(rift, 0.13))
						draw_arc(summon_point, 23.0, 0.0, TAU, 24, Color(core, 0.80), 2.0)
				"lightning":
					for lightning_index in 5:
						var strike_angle := float(lightning_index) * TAU / 5.0 + 0.23
						var strike_point := target + Vector2.from_angle(strike_angle) * (48.0 + float(lightning_index % 2) * 44.0)
						draw_circle(strike_point, 32.0, Color(energy, 0.10))
						draw_arc(strike_point, 32.0 * remaining_ratio + 6.0, 0.0, TAU, 28, Color(energy, 0.92), 3.0)
				"total_annihilation":
					draw_circle(target, radius, Color(warning, 0.16 + pulse * 0.06))
					draw_arc(target, radius, 0.0, TAU, 72, Color(warning, 0.98), 6.0)
					draw_arc(target, radius * remaining_ratio, 0.0, TAU, 64, Color(energy, 0.94), 5.0)
					for ray_index in 12:
						var ray_direction := Vector2.from_angle(float(ray_index) * TAU / 12.0)
						draw_line(target + ray_direction * 44.0, target + ray_direction * radius, Color(core, 0.55), 3.0)
				_:
					draw_circle(target, radius, Color(warning, 0.10 + pulse * 0.05))
					draw_arc(target, radius, 0.0, TAU, 52, Color(warning, 0.92), 3.0)
					draw_arc(target, radius * remaining_ratio, 0.0, TAU, 44, Color(energy, 0.88), 3.0)
			if not skill.is_empty():
				_draw_text(_chaos_skill_name(skill), target + Vector2(0.0, -radius - 18.0), 14, Color("FFE5F6"), HORIZONTAL_ALIGNMENT_CENTER, 260.0)

	for hazard_value in chaos_runtime_hazards:
		var hazard: Dictionary = Dictionary(hazard_value)
		var hazard_position := _world_to_screen(Vector2(hazard.get("pos", Vector2.ZERO)))
		var hazard_radius := float(hazard.get("radius", 80.0))
		if not _on_screen(hazard_position, hazard_radius + 90.0):
			continue
		var ttl_ratio := clampf(float(hazard.get("ttl", 0.0)) / maxf(0.01, float(hazard.get("max_ttl", 1.0))), 0.0, 1.0)
		var kind := str(hazard.get("kind", ""))
		if kind == "black_hole":
			draw_circle(hazard_position, hazard_radius, Color(0.015, 0.004, 0.025, 0.82))
			draw_circle(hazard_position, hazard_radius * 0.34, Color(0.0, 0.0, 0.0, 0.98))
			for vortex_index in 4:
				var vortex_radius := hazard_radius * (0.42 + float(vortex_index) * 0.16)
				var vortex_start := game_time * (1.2 + float(vortex_index) * 0.22) + float(vortex_index)
				draw_arc(hazard_position, vortex_radius, vortex_start, vortex_start + PI * 1.48, 38, Color(rift, 0.75 - float(vortex_index) * 0.11), 4.0)
			draw_arc(hazard_position, hazard_radius, 0.0, TAU, 56, Color(warning, 0.58), 3.0)
			continue
		if not kind.begins_with("effect_"):
			continue
		var effect_kind := kind.trim_prefix("effect_")
		var progress := 1.0 - ttl_ratio
		match effect_kind:
			"destruction_beam":
				var beam_facing := Vector2.RIGHT
				if chaos_boss != null:
					beam_facing = Vector2(chaos_boss.render_snapshot().get("facing", Vector2.RIGHT)).normalized()
				draw_line(hazard_position - beam_facing * 380.0, hazard_position + beam_facing * 380.0, Color(energy, 0.34 * ttl_ratio), hazard_radius * 1.55, true)
				draw_line(hazard_position - beam_facing * 380.0, hazard_position + beam_facing * 380.0, Color("F7FFFF", 0.92 * ttl_ratio), 16.0, true)
			"shockwave_ring":
				draw_arc(hazard_position, hazard_radius * progress, 0.0, TAU, 64, Color(warning, ttl_ratio), 10.0 * ttl_ratio + 2.0)
			"lightning_strike":
				var bolt := PackedVector2Array()
				for bolt_index in 7:
					bolt.append(hazard_position + Vector2((float((bolt_index * 17) % 9) - 4.0) * 3.0, -190.0 + float(bolt_index) * 31.0))
				draw_polyline(bolt, Color("F7FFFF", ttl_ratio), 7.0, true)
				draw_polyline(bolt, Color(energy, ttl_ratio), 3.0, true)
				draw_circle(hazard_position, hazard_radius * (0.45 + progress), Color(energy, 0.16 * ttl_ratio))
			"rift_dash":
				for dash_ray_index in 8:
					var dash_ray := Vector2.from_angle(float(dash_ray_index) * TAU / 8.0 + game_time)
					draw_line(hazard_position + dash_ray * 18.0, hazard_position + dash_ray * hazard_radius * (0.5 + progress * 0.5), Color(rift, ttl_ratio), 5.0)
			"total_annihilation_pre", "total_annihilation":
				draw_circle(hazard_position, hazard_radius * (0.45 + progress * 0.55), Color(core, 0.16 * ttl_ratio))
				draw_arc(hazard_position, hazard_radius * (0.45 + progress * 0.55), 0.0, TAU, 64, Color(warning, ttl_ratio), 8.0)
			"summon_monster_flare":
				draw_circle(hazard_position, hazard_radius * (1.0 - progress * 0.45), Color(rift, 0.25 * ttl_ratio))
				draw_arc(hazard_position, hazard_radius, game_time * 2.0, game_time * 2.0 + PI * 1.6, 28, Color(core, ttl_ratio), 4.0)
			"defeat":
				for defeat_ray_index in 10:
					var defeat_ray := Vector2.from_angle(float(defeat_ray_index) * TAU / 10.0 + game_time * 0.2)
					draw_line(hazard_position, hazard_position + defeat_ray * hazard_radius * progress, Color(energy, ttl_ratio), 6.0)
			_:
				draw_circle(hazard_position, hazard_radius * (0.30 + progress * 0.70), Color(core, 0.10 * ttl_ratio))
				draw_arc(hazard_position, hazard_radius * (0.30 + progress * 0.70), 0.0, TAU, 40, Color(rift, 0.72 * ttl_ratio), 3.0)


func _draw_aionis_ground_effects() -> void:
	if not timeless_gate_unlocked:
		return
	var gold := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["gold"])
	var time_color := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["time"])
	var warning := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["warning"])
	var safe := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["safe"])
	var core := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["core"])
	var void_color := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["void"])
	if aionis_boss != null and not aionis_boss.is_defeated():
		var snapshot: Dictionary = aionis_boss.render_snapshot()
		var text_state: Dictionary = aionis_boss.get_text_state()
		if str(snapshot.get("state", "")) == "TELEGRAPH":
			var telegraph: Dictionary = Dictionary(snapshot.get("telegraph", {}))
			var skill := str(snapshot.get("telegraph_skill", ""))
			var target := _world_to_screen(Vector2(snapshot.get("telegraph_position", _aionis_boss_position())))
			var origin := _world_to_screen(Vector2(snapshot.get("position", _aionis_boss_position())))
			var radius := maxf(72.0, float(telegraph.get("radius", 180.0)))
			var total := maxf(0.01, float(telegraph.get("telegraph", 0.7)))
			var remaining := clampf(float(text_state.get("telegraph_timer", 0.0)) / total, 0.0, 1.0)
			var pulse := 0.55 + 0.45 * sin(game_time * 10.0)
			match skill:
				"clock_sever":
					draw_line(origin, target, Color(warning, 0.18 + pulse * 0.10), 58.0, true)
					draw_line(origin, target, Color(gold, 0.90), 5.0)
					for slash_index in 3:
						var slash_angle := (target - origin).angle() + (float(slash_index) - 1.0) * 0.20
						draw_line(origin + Vector2.from_angle(slash_angle) * 40.0, origin + Vector2.from_angle(slash_angle) * radius, Color(warning, 0.62), 3.0)
				"causal_hunt":
					draw_circle(target, radius * 0.62, Color(warning, 0.10))
					draw_arc(target, radius * 0.62, -game_time * 1.5, TAU - game_time * 1.5, 44, Color(warning, 0.92), 4.0)
					draw_arc(target, radius * 0.62 * remaining, 0.0, TAU, 36, time_color, 3.0)
					draw_line(origin, target, Color(gold, 0.65), 2.0)
					for arrow_index in 4:
						var arrow_pos := origin.lerp(target, 0.25 + float(arrow_index) * 0.17)
						draw_circle(arrow_pos, 5.0, core)
				"chrono_prison":
					draw_circle(target, radius * 0.36, Color(warning, 0.09))
					for prison_ring in 3:
						draw_arc(target, radius * (0.18 + float(prison_ring) * 0.09), game_time * (0.8 + prison_ring * 0.2), game_time * (0.8 + prison_ring * 0.2) + PI * 1.65, 34, Color(gold, 0.84), 4.0)
					for bar_index in 8:
						var bar_angle := TAU * float(bar_index) / 8.0
						draw_line(target + Vector2.from_angle(bar_angle) * radius * 0.18, target + Vector2.from_angle(bar_angle) * radius * 0.38, Color(time_color, 0.72), 4.0)
				"rewind_rebirth":
					for spiral_index in 4:
						var spiral_radius := radius * (0.20 + float(spiral_index) * 0.17)
						draw_arc(target, spiral_radius, -game_time * (0.8 + spiral_index * 0.16), -game_time * (0.8 + spiral_index * 0.16) + PI * 1.45, 40, Color(gold, 0.76 - float(spiral_index) * 0.10), 4.0)
					draw_circle(target, 18.0 + pulse * 5.0, Color(core, 0.70))
				"parallel_legion":
					for portal_index in 4:
						var portal_angle := TAU * float(portal_index) / 4.0 + game_time * 0.22
						var portal := target + Vector2.from_angle(portal_angle) * radius * 0.50
						draw_circle(portal, 34.0, Color(void_color, 0.80))
						draw_arc(portal, 34.0, -game_time, TAU - game_time, 26, gold, 4.0)
						_draw_polygon_shape(portal, [Vector2(0, -15), Vector2(12, 10), Vector2(-12, 10)], 0.0, Color(core, 0.70), time_color, 2.0)
				"rift_board":
					var board_size := radius * 1.46
					var cell := board_size / 6.0
					var board_origin := target - Vector2.ONE * board_size * 0.5
					for board_y in 6:
						for board_x in 6:
							var danger := (board_x + board_y + int(game_time * 2.0)) % 2 == 0
							var cell_rect := Rect2(board_origin + Vector2(float(board_x), float(board_y)) * cell, Vector2.ONE * (cell - 2.0))
							draw_rect(cell_rect, Color(warning if danger else safe, 0.16 if danger else 0.10))
							draw_rect(cell_rect, Color(warning if danger else safe, 0.62), false, 1.5)
					draw_rect(Rect2(board_origin, Vector2.ONE * board_size), gold, false, 4.0)
				"star_gate_barrage":
					for gate_index in 8:
						var gate_angle := TAU * float(gate_index) / 8.0 + 0.2
						var gate := target + Vector2.from_angle(gate_angle) * radius * 0.58
						var star_points := [Vector2(0, -18), Vector2(5, -6), Vector2(17, -5), Vector2(8, 3), Vector2(11, 16), Vector2(0, 9), Vector2(-11, 16), Vector2(-8, 3), Vector2(-17, -5), Vector2(-5, -6)]
						_draw_polygon_shape(gate, star_points, gate_angle + game_time * 0.2, Color(void_color, 0.82), gold, 2.5)
						draw_line(gate, target, Color(warning, 0.22), 3.0)
				"army_judgment":
					draw_circle(target, radius, Color(warning, 0.10))
					draw_arc(target, radius, 0.0, TAU, 56, warning, 4.0)
					draw_arc(target, radius * remaining, 0.0, TAU, 44, gold, 4.0)
					draw_line(target - Vector2(radius, 0.0), target + Vector2(radius, 0.0), Color(core, 0.72), 3.0)
					draw_line(target - Vector2(0.0, radius), target + Vector2(0.0, radius), Color(core, 0.72), 3.0)
				"causal_mirror":
					for mirror_index in 3:
						var mirror_angle := -0.8 + float(mirror_index) * 0.8 + game_time * 0.14
						var mirror_center := target + Vector2.from_angle(mirror_angle) * radius * 0.30
						draw_arc(mirror_center, radius * 0.22, mirror_angle - 1.0, mirror_angle + 1.0, 28, Color("D7E6F5"), 8.0)
						draw_arc(mirror_center, radius * 0.18, mirror_angle - 1.0, mirror_angle + 1.0, 24, time_color, 3.0)
				"twelfth_bell":
					draw_circle(target, radius, Color(warning, 0.14 + pulse * 0.05))
					draw_arc(target, radius, 0.0, TAU, 72, warning, 6.0)
					var safe_index := int(game_time * 1.8) % 12
					for bell_index in 12:
						var bell_angle := -PI * 0.5 + TAU * float(bell_index) / 12.0
						var bell_color := safe if bell_index == safe_index else warning
						draw_line(target + Vector2.from_angle(bell_angle) * 52.0, target + Vector2.from_angle(bell_angle) * radius, Color(bell_color, 0.72), 5.0 if bell_index == safe_index else 3.0)
					_draw_screen_sector(target, radius, -PI * 0.5 + TAU * float(safe_index) / 12.0, TAU / 12.0, Color(safe, 0.18), Color(safe, 0.88))
				_:
					draw_circle(target, radius, Color(warning, 0.12))
					draw_arc(target, radius, 0.0, TAU, 48, warning, 4.0)
			if not skill.is_empty():
				_draw_text(_aionis_skill_name(skill), target + Vector2(0.0, -radius - 20.0), 15, Color("FFF1D0"), HORIZONTAL_ALIGNMENT_CENTER, 280.0)

	for hazard_value in aionis_runtime_hazards:
		var hazard: Dictionary = Dictionary(hazard_value)
		var p := _world_to_screen(Vector2(hazard.get("pos", Vector2.ZERO)))
		var radius := float(hazard.get("radius", 64.0))
		if not _on_screen(p, radius + 100.0):
			continue
		var kind := str(hazard.get("kind", ""))
		var ttl_ratio := clampf(float(hazard.get("ttl", 0.0)) / maxf(0.01, float(hazard.get("max_ttl", 1.0))), 0.0, 1.0)
		var progress := 1.0 - ttl_ratio
		if kind == "reflect_field":
			draw_arc(p, radius * 0.36, -1.25, 1.25, 34, Color("D7E6F5", 0.85 * ttl_ratio), 9.0)
			draw_arc(p, radius * 0.31, -1.25, 1.25, 30, Color(time_color, 0.72 * ttl_ratio), 3.0)
			continue
		if not kind.begins_with("effect_"):
			var hazard_color := core if "twelfth" in kind else warning
			if kind == "rift_board_node":
				draw_rect(Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color(hazard_color, 0.15))
				draw_rect(Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color(hazard_color, 0.84), false, 3.0)
			else:
				draw_circle(p, radius, Color(hazard_color, 0.10 + 0.04 * sin(game_time * 8.0)))
				draw_arc(p, radius, game_time * 0.4, TAU + game_time * 0.4, 44, Color(hazard_color, 0.78), 3.0)
				draw_arc(p, radius * ttl_ratio, 0.0, TAU, 38, Color(gold, 0.66), 2.0)
			continue
		var effect_kind := kind.trim_prefix("effect_")
		match effect_kind:
			"time_anchor_hit", "anchor_broken":
				for ray_index in 8:
					var ray := Vector2.from_angle(TAU * float(ray_index) / 8.0)
					draw_line(p + ray * 8.0, p + ray * radius * progress, Color(time_color, ttl_ratio), 5.0)
			"clock_sever", "line_hit":
				draw_line(p - Vector2(radius * 2.2, radius * 0.4), p + Vector2(radius * 2.2, radius * 0.4), Color(gold, ttl_ratio), 8.0)
			"combo":
				for combo_ring in maxi(2, int(hazard.get("count", 2))):
					draw_arc(p, radius * (0.35 + progress * 0.45 + float(combo_ring) * 0.08), 0.0, TAU, 52, Color(core if combo_ring % 2 == 0 else time_color, ttl_ratio), 5.0)
			"twelfth_bell_cast", "aionis_dead", "aionis_defeat":
				draw_circle(p, radius * (0.25 + progress * 0.75), Color(core, 0.13 * ttl_ratio))
				draw_arc(p, radius * (0.25 + progress * 0.75), 0.0, TAU, 64, Color(gold, ttl_ratio), 8.0)
			_:
				draw_circle(p, radius * (0.28 + progress * 0.72), Color(time_color, 0.08 * ttl_ratio))
				draw_arc(p, radius * (0.28 + progress * 0.72), 0.0, TAU, 34, Color(gold, 0.62 * ttl_ratio), 3.0)


func _draw_aionis_projectiles() -> void:
	var gold := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["gold"])
	var time_color := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["time"])
	var core := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["core"])
	for projectile_value in aionis_runtime_projectiles:
		var projectile: Dictionary = Dictionary(projectile_value)
		var p := _world_to_screen(Vector2(projectile.get("pos", Vector2.ZERO)))
		if not _on_screen(p, 90.0):
			continue
		var kind := str(projectile.get("kind", "aionis_orb"))
		var velocity := Vector2(projectile.get("vel", Vector2.ZERO))
		var direction := velocity.normalized() if velocity.length_squared() > 0.01 else Vector2.RIGHT
		var radius := maxf(7.0, float(projectile.get("radius", 14.0)))
		match kind:
			"aionis_causal_missile":
				draw_line(p - direction * 38.0, p - direction * 10.0, Color(core, 0.52), 9.0)
				_draw_polygon_shape(p, [Vector2(-14, -7), Vector2(10, -6), Vector2(20, 0), Vector2(10, 6), Vector2(-14, 7)], direction.angle(), Color("16213B"), gold, 2.0)
				draw_circle(p + direction * 10.0, 5.0, time_color)
			"aionis_star_gate":
				var star_points := [Vector2(0, -radius), Vector2(radius * 0.35, -radius * 0.28), Vector2(radius, -radius * 0.2), Vector2(radius * 0.48, radius * 0.2), Vector2(radius * 0.62, radius), Vector2(0, radius * 0.48), Vector2(-radius * 0.62, radius), Vector2(-radius * 0.48, radius * 0.2), Vector2(-radius, -radius * 0.2), Vector2(-radius * 0.35, -radius * 0.28)]
				_draw_polygon_shape(p, star_points, game_time * 2.1, Color(core, 0.70), gold, 2.0)
				draw_line(p - direction * 32.0, p, Color(time_color, 0.58), 5.0)
			"aionis_twelfth_bell":
				draw_line(p - direction * 48.0, p, Color(core, 0.58), radius * 0.60)
				draw_circle(p, radius, Color("10182D"))
				draw_arc(p, radius, 0.0, TAU, 24, gold, 4.0)
				for tick_index in 4:
					draw_line(p + Vector2.from_angle(float(tick_index) * PI * 0.5) * 5.0, p + Vector2.from_angle(float(tick_index) * PI * 0.5) * (radius - 3.0), time_color, 2.0)
			"aionis_reflected_shot":
				draw_line(p - direction * 30.0, p, Color(core, 0.74), 7.0)
				draw_circle(p, radius, Color("D7E6F5"))
				draw_circle(p, radius * 0.48, core)
			"aionis_rewind_fragment":
				_draw_polygon_shape(p, [Vector2(0, -radius), Vector2(radius * 0.75, 0), Vector2(0, radius), Vector2(-radius * 0.75, 0)], -game_time * 1.6, Color(time_color, 0.52), gold, 2.0)
			"aionis_clock_blade":
				draw_line(p - Vector2(radius * 3.2, 0.0), p + Vector2(radius * 3.2, 0.0), Color(gold, 0.86), 7.0)
			_:
				draw_line(p - direction * 24.0, p, Color(time_color, 0.45), 5.0)
				draw_circle(p, radius * 0.70, core)
				draw_circle(p, radius * 0.30, gold)


func _aionis_skill_name(skill_id: String) -> String:
	for skill_value in Array(GameConfig.AIONIS_BOSS_CONFIG.get("skills", [])):
		var skill: Dictionary = Dictionary(skill_value)
		if str(skill.get("id", "")) == skill_id:
			return str(skill.get("name", skill_id))
	return skill_id


func _draw_chaos_projectiles() -> void:
	var core := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["core"])
	var energy := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["energy"])
	for projectile_value in chaos_runtime_projectiles:
		var projectile: Dictionary = Dictionary(projectile_value)
		var p := _world_to_screen(Vector2(projectile.get("pos", Vector2.ZERO)))
		if not _on_screen(p, 90.0):
			continue
		var kind := str(projectile.get("kind", "chaos_orb"))
		var velocity := Vector2(projectile.get("vel", Vector2.ZERO))
		var direction := velocity.normalized() if velocity.length_squared() > 0.01 else Vector2.RIGHT
		var radius := maxf(6.0, float(projectile.get("radius", 14.0)))
		match kind:
			"meteor":
				draw_line(p - direction * 92.0, p - direction * 18.0, Color(core, 0.38), radius * 1.25, true)
				draw_circle(p, radius + sin(game_time * 10.0) * 3.0, Color("4C173E"))
				draw_arc(p, radius, 0.0, TAU, 28, Color("FF8A5B"), 5.0)
				draw_circle(p - Vector2(7.0, 8.0), radius * 0.35, Color("FFF2C0"))
			"homing_missile":
				draw_line(p - direction * 31.0, p - direction * 9.0, Color(core, 0.62), 8.0)
				_draw_polygon_shape(p, [Vector2(-15, -7), Vector2(10, -6), Vector2(19, 0), Vector2(10, 6), Vector2(-15, 7)], direction.angle(), Color("71315F"), Color("190B21"), 2.0)
				draw_circle(p + direction * 11.0, 5.0, energy)
			"annihilation_fragment":
				draw_line(p - direction * 28.0, p, Color(core, 0.64), 6.0)
				_draw_polygon_shape(p, [Vector2(-13, -8), Vector2(12, 0), Vector2(-13, 8), Vector2(-5, 0)], direction.angle(), core, Color("240D2E"), 2.0)
			"destruction_beam":
				pass
			_:
				draw_line(p - direction * 25.0, p, Color(core, 0.44), radius * 0.65, true)
				draw_circle(p, radius * 0.62, Color(core, 0.88))
				draw_circle(p, radius * 0.28, energy)


func _chaos_skill_name(skill_id: String) -> String:
	for skill_value in Array(GameConfig.CHAOS_BOSS_CONFIG.get("skills", [])):
		var skill: Dictionary = Dictionary(skill_value)
		if str(skill.get("id", "")) == skill_id:
			return str(skill.get("name", skill_id))
	return skill_id


func _draw_screen_sector(center: Vector2, radius: float, direction: float, angle: float, fill: Color, edge: Color) -> void:
	var points := PackedVector2Array([center])
	var steps := 28
	for index in range(steps + 1):
		var sample_angle := direction - angle * 0.5 + angle * float(index) / float(steps)
		points.append(center + Vector2.from_angle(sample_angle) * radius)
	draw_colored_polygon(points, fill)
	draw_arc(center, radius, direction - angle * 0.5, direction + angle * 0.5, steps, edge, 2.5)
	draw_line(center, center + Vector2.from_angle(direction - angle * 0.5) * radius, edge, 2.0)
	draw_line(center, center + Vector2.from_angle(direction + angle * 0.5) * radius, edge, 2.0)


func _draw_screen_annular_sector(center: Vector2, inner_radius: float, outer_radius: float, start_angle: float, arc: float, fill: Color, edge: Color) -> void:
	var points := PackedVector2Array()
	var steps := 40
	for index in range(steps + 1):
		points.append(center + Vector2.from_angle(start_angle + arc * float(index) / float(steps)) * outer_radius)
	for index in range(steps, -1, -1):
		points.append(center + Vector2.from_angle(start_angle + arc * float(index) / float(steps)) * inner_radius)
	draw_colored_polygon(points, fill)
	draw_arc(center, outer_radius, start_angle, start_angle + arc, steps, edge, 2.8)
	draw_arc(center, inner_radius, start_angle, start_angle + arc, steps, Color(edge, edge.a * 0.75), 2.0)
	draw_line(center + Vector2.from_angle(start_angle) * inner_radius, center + Vector2.from_angle(start_angle) * outer_radius, edge, 2.0)
	draw_line(center + Vector2.from_angle(start_angle + arc) * inner_radius, center + Vector2.from_angle(start_angle + arc) * outer_radius, edge, 2.0)


func _draw_hazards() -> void:
	for hazard in hazards:
		var p := _world_to_screen(hazard["pos"])
		if str(hazard.get("kind", "fire")) == "ufo_beam":
			var beam_radius := float(hazard["radius"])
			var warmup := float(hazard.get("warmup", 0.0))
			if warmup > 0.0:
				var warmup_ratio: float = clampf(warmup / maxf(0.01, float(hazard.get("initial_warmup", 0.68))), 0.0, 1.0)
				draw_circle(p, beam_radius, Color(0.25, 1.0, 0.92, 0.07 + (1.0 - warmup_ratio) * 0.08))
				draw_arc(p, beam_radius, 0, TAU, 48, Color("75FFF0"), 2.5)
				draw_arc(p, beam_radius * (0.28 + warmup_ratio * 0.72), 0, TAU, 36, Color("D5FFFA"), 3.0)
				draw_line(p + Vector2(0, -270), p, Color(0.65, 1.0, 0.96, 0.25), 4.0)
			else:
				var beam_top_left := p + Vector2(-beam_radius * 0.44, -300)
				var beam_top_right := p + Vector2(beam_radius * 0.44, -300)
				var beam_points := PackedVector2Array([beam_top_left, beam_top_right, p + Vector2(beam_radius, 0), p + Vector2(-beam_radius, 0)])
				draw_colored_polygon(beam_points, Color(0.30, 1.0, 0.92, 0.20))
				draw_line(beam_top_left, p - Vector2(beam_radius, 0), Color(0.65, 1.0, 0.96, 0.78), 3.0)
				draw_line(beam_top_right, p + Vector2(beam_radius, 0), Color(0.65, 1.0, 0.96, 0.78), 3.0)
				draw_circle(p, beam_radius, Color(0.28, 1.0, 0.90, 0.20))
				draw_arc(p, beam_radius, 0, TAU, 48, Color("D5FFFA"), 4.0)
				draw_circle(p, 18.0 + sin(game_time * 13.0) * 4.0, Color("E8FFFC"))
				_draw_text("UFO 光柱", p + Vector2(0, beam_radius + 22.0), 11, Color("B9FFF8"), HORIZONTAL_ALIGNMENT_CENTER, 100.0)
			continue
		var alpha: float = clamp(float(hazard["ttl"]) / 1.0, 0.0, 0.28)
		draw_circle(p, float(hazard["radius"]), Color(FIRE_ORANGE, alpha * 0.55))
		draw_arc(p, float(hazard["radius"]), 0, TAU, 44, Color(1.0, 0.55, 0.2, alpha + 0.2), 2.0)


func _draw_drops_and_tombstones() -> void:
	for drop in drops:
		var p := _world_to_screen(drop["pos"])
		draw_circle(p, 7.0 + sin(game_time * 7.0 + int(drop["gold"])) * 1.4, GOLD)
		draw_arc(p, 10.0, 0, TAU, 16, Color(1.0, 0.95, 0.55, 0.55), 1.5)
	for tomb in tombstones:
		var p := _world_to_screen(tomb["pos"])
		draw_rect(Rect2(p + Vector2(-9, -13), Vector2(18, 25)), Color("C5CDD3"))
		draw_rect(Rect2(p + Vector2(-9, -13), Vector2(18, 25)), INK, false, 1.5)
		draw_circle(p + Vector2(0, -13), 9.0, Color("C5CDD3"))
		draw_arc(p + Vector2(0, -13), 9.0, PI, TAU, 10, INK, 1.5)
		draw_arc(p, 17.0 + sin(game_time * 3.0) * 2.0, 0, TAU, 24, Color(1.0, 0.84, 0.35, 0.35), 1.5)


func _draw_particles_and_floaters() -> void:
	for particle in particles:
		var p := _world_to_screen(particle["pos"])
		if not _on_screen(p, 160): continue
		var ratio: float = clamp(float(particle["ttl"]) / max(0.001, float(particle["max_ttl"])), 0.0, 1.0)
		var color := Color(Color(particle["color"]), ratio)
		if not particle["effect"]:
			draw_circle(p, float(particle["size"]) * (0.45 + ratio * 0.55), color)
			continue
		var progress: float = 1.0 - ratio
		match str(particle["kind"]):
			"hit":
				for i in 5: draw_line(p, p + Vector2.from_angle(i * TAU / 5.0) * (8.0 + progress * 18.0), color, 2.0)
			"slash":
				draw_arc(p, float(particle["size"]) * (0.75 + progress * 0.45), -1.3, 1.3, 18, color, 7.0 * ratio + 1.0)
			"explosion":
				draw_circle(p, float(particle["size"]) * progress * 2.4, Color(color, ratio * 0.34))
				draw_arc(p, float(particle["size"]) * progress * 2.5, 0, TAU, 28, color, 5.0 * ratio + 1.0)
			"level_up", "capture", "revive":
				draw_arc(p, float(particle["size"]) * (0.6 + progress * 2.6), 0, TAU, 36, color, 3.0)
				for i in 8: draw_line(p + Vector2.from_angle(i * TAU / 8.0) * 18.0, p + Vector2.from_angle(i * TAU / 8.0) * (42.0 + progress * 34.0), color, 2.0)
			"fan":
				for i in 7: draw_line(p, p + Vector2.RIGHT.rotated(lerp(-0.42, 0.42, float(i) / 6.0)) * (35.0 + progress * 28.0), color, 2.0)
			_:
				draw_circle(p, float(particle["size"]) * (1.0 + progress), Color(color, ratio * 0.25))
				draw_arc(p, float(particle["size"]) * (1.0 + progress), 0, TAU, 24, color, 2.0)
	for floater in floaters:
		var p := _world_to_screen(floater["pos"]) + Vector2(0, -float(floater["offset"]))
		var alpha: float = clamp(float(floater["ttl"]) / float(floater["max_ttl"]), 0.0, 1.0)
		_draw_text(str(floater["text"]), p, 15, Color(Color(floater["color"]), alpha), HORIZONTAL_ALIGNMENT_CENTER, 150)


func _draw_hud() -> void:
	# 左上：玩家狀態。
	draw_rect(Rect2(18, 18, 315, 126), Color(0.025, 0.045, 0.06, 0.90))
	draw_rect(Rect2(18, 18, 315, 126), PANEL_EDGE, false, 2.0)
	var hero_class_name: String = str(GameConfig.HERO_CLASSES[str(player["class_id"])]["name"])
	_draw_text("Lv.%d  %s" % [int(player["level"]), hero_class_name], Vector2(34, 45), 19, Color("EAF6FF"))
	_draw_text("$ %d" % int(player["money"]), Vector2(220, 45), 18, GOLD)
	_draw_bar(Vector2(34, 57), Vector2(280, 17), float(player["hp"]) / max(1.0, float(player["max_hp"])), Color("E05858"), Color("321C22"))
	_draw_text("生命 %d / %d" % [int(player["hp"]), int(player["max_hp"])], Vector2(174, 71), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 220)
	_draw_bar(Vector2(34, 84), Vector2(280, 10), float(player["xp"]) / max(1.0, float(player["xp_need"])), Color("5BA8E8"), Color("172A38"))
	_draw_text("XP %d / %d" % [int(player["xp"]), int(player["xp_need"])], Vector2(34, 115), 13, Color("B9DDF4"))
	_draw_text("技能點 %d" % int(player["skill_points"]), Vector2(220, 115), 13, GOLD if int(player["skill_points"]) > 0 else Color("7893A3"))
	_draw_text("擊殺 %d　城堡 %d" % [int(player["kills"]), int(player["captured"])], Vector2(34, 136), 12, Color("8FA8B7"))

	_draw_minimap(Rect2(screen_size.x - 230, 18, 212, 158), false)
	if not _is_touch_scheme():
		var notice_toggle := _notification_toggle_rect()
		var notice_color := Color("557A66") if notifications_hidden else Color("466B76")
		_draw_button(notice_toggle, "顯示通知（N）" if notifications_hidden else "隱藏通知（N）", notice_color)
		_draw_button(_cheat_toggle_rect(), "輸入作弊碼（T）", Color("654C75"))
		_draw_button(_soldier_upgrade_toggle_rect(), "Troop Upgrades (K)" if language == "en" else "強化士兵（K）", Color("356E83"))
	if _aionis_boss_hud_should_show():
		_draw_aionis_boss_hud()
	elif _chaos_boss_hud_should_show():
		_draw_chaos_boss_hud()
	else:
		_draw_python_boss_hud()

	# 下方 HUD 會依最後使用的輸入裝置自動切換版型。
	if _is_touch_scheme():
		var army_panel := Rect2(screen_size.x * 0.5 - 176.0, screen_size.y - 54.0, 352.0, 36.0)
		draw_rect(army_panel, Color(0.025, 0.045, 0.06, 0.88))
		draw_rect(army_panel, PANEL_EDGE, false, 1.5)
		_draw_text("軍隊 %d / %d　命令：%s" % [soldiers.size(), _army_limit(), _soldier_command_display()], army_panel.position + Vector2(army_panel.size.x * 0.5, 24.0), 13, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, army_panel.size.x - 16.0)
	else:
		draw_rect(Rect2(18, screen_size.y - 78, 610, 60), Color(0.025, 0.045, 0.06, 0.90))
		draw_rect(Rect2(18, screen_size.y - 78, 610, 60), PANEL_EDGE, false, 2.0)
		_draw_text("軍隊 %d / %d　命令：%s" % [soldiers.size(), _army_limit(), _soldier_command_display()], Vector2(32, screen_size.y - 50), 15, Color("EAF6FF"))
		_draw_text("1 跟隨　2 防守　3 攻擊　4 撤退　5 駐守　6 攻城", Vector2(32, screen_size.y - 27), 13, Color("8FB7CC"))

		# 桌面版右下顯示滑鼠技能鍵；觸控版改由大型按鈕呈現。
		var skill_base := Vector2(screen_size.x - 190, screen_size.y - 94)
		_draw_skill_icon(Rect2(skill_base, Vector2(72, 72)), "左鍵", str(GameConfig.NORMAL_ATTACKS[str(player["class_id"])]["name"]), float(player["attack_cd"]), max(0.01, 1.0 / float(player["attack_rate"])), FRIEND_BLUE, true)
		var unlocked := int(player["level"]) >= 10
		var special_name := str(GameConfig.SPECIAL_ATTACKS[str(player["class_id"])]["name"])
		_draw_skill_icon(Rect2(skill_base + Vector2(84, 0), Vector2(72, 72)), "右鍵", special_name if unlocked else "Lv.10 解鎖", float(player["special_cd"]) if unlocked else 1.0, float(GameConfig.SPECIAL_ATTACKS[str(player["class_id"])]["cooldown"]) if unlocked else 1.0, GOLD if unlocked else Color("56636B"), unlocked)

	if _is_near_recruitment() and active_panel == "" and not _is_touch_scheme():
		var prompt_rect := Rect2(screen_size.x * 0.5 - 175, screen_size.y - 118, 350, 38)
		draw_rect(prompt_rect, Color(0.02, 0.05, 0.07, 0.88))
		draw_rect(prompt_rect, HEAL_GREEN, false, 2.0)
		_draw_text("按 E 或 B 開啟招募介面", prompt_rect.position + Vector2(prompt_rect.size.x * 0.5, 25), 15, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, prompt_rect.size.x - 16)

	for i in notifications.size():
		var notice: Dictionary = notifications[notifications.size() - 1 - i]
		var alpha: float = clamp(float(notice["ttl"]) / min(0.4, float(notice["max_ttl"])), 0.0, 1.0)
		var boss_hud_visible := _python_boss_hud_should_show() or _chaos_boss_hud_should_show() or _aionis_boss_hud_should_show()
		var notice_y := 112.0 if boss_hud_visible else 22.0
		var notice_width := minf(760.0, maxf(320.0, screen_size.x - 80.0))
		var notice_x := screen_size.x * 0.5 - notice_width * 0.5
		var notice_height := 34.0
		var notice_pitch := 42.0
		var notice_font := 15
		if _is_touch_scheme():
			# Keep warnings below the two utility rows and horizontally between the
			# move pad and the special button. Notifications must never hide a control.
			var scale := touch_ui_coordinate_scale
			var utility_bottom := 0.0
			for utility_value in _touch_utility_rects().values():
				utility_bottom = maxf(utility_bottom, Rect2(utility_value).end.y)
			var safe_left := _touch_move_center().x + (TOUCH_STICK_RADIUS + 12.0) * scale
			var safe_right := _touch_special_rect().position.x - 12.0 * scale
			notice_x = safe_left
			notice_width = maxf(180.0 * scale, safe_right - safe_left)
			notice_y = utility_bottom + 10.0 * scale
			notice_height = 34.0 * scale
			notice_pitch = 42.0 * scale
			notice_font = roundi(14.0 * scale)
		var rect := Rect2(notice_x, notice_y + i * notice_pitch, notice_width, notice_height)
		draw_rect(rect, Color(0.015, 0.03, 0.045, 0.76 * alpha))
		_draw_text(str(notice["text"]), rect.position + Vector2(notice_width * 0.5, notice_height * 0.68), notice_font, Color(Color(notice["color"]), alpha), HORIZONTAL_ALIGNMENT_CENTER, notice_width - 20.0 * (touch_ui_coordinate_scale if _is_touch_scheme() else 1.0))

	if tutorial_visible and mode == GameMode.PLAYING and active_panel == "":
		var tutorial := _tutorial_panel_rect()
		draw_rect(tutorial, Color(0.03, 0.055, 0.07, 0.85))
		draw_rect(tutorial, Color("668B9E"), false, 1.5)
		if _is_touch_scheme():
			_draw_text("新手指南（點 × 隱藏）", tutorial.position + Vector2(14, 25), 15, GOLD)
			var close_rect := _tutorial_close_rect()
			draw_rect(close_rect, Color(0.025, 0.045, 0.06, 0.86))
			draw_rect(close_rect, PANEL_EDGE, false, 1.5)
			_draw_text("×", close_rect.get_center() + Vector2(0.0, 7.0), 22, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x)
			_draw_text("左搖桿移動　右搖桿瞄準並攻擊", tutorial.position + Vector2(14, 50), 13, Color("C8DBE5"))
			_draw_text("技能鈕施放絕招；上方按鈕開啟功能", tutorial.position + Vector2(14, 72), 13, Color("C8DBE5"))
			_draw_text("靠近據點後點擊招募；能力可分配技能點", tutorial.position + Vector2(14, 94), 13, Color("C8DBE5"))
			_draw_text("軍令鈕可選跟隨、防守、攻擊、撤退、駐守與攻城", tutorial.position + Vector2(14, 116), 12, Color("C8DBE5"))
			_draw_text("兵強→特殊：購買後重新招募，戰鬥時自動觸發", tutorial.position + Vector2(14, 138), 12, Color("A9D9E7"))
		else:
			_draw_text("新手指南（H 隱藏）", tutorial.position + Vector2(14, 25), 15, GOLD)
			_draw_text("WASD 移動　滑鼠瞄準", tutorial.position + Vector2(14, 50), 13, Color("C8DBE5"))
			_draw_text("左鍵攻擊；擊殺獲得金錢與 XP", tutorial.position + Vector2(14, 72), 13, Color("C8DBE5"))
			_draw_text("靠近據點按 E 招募；C 分配技能點", tutorial.position + Vector2(14, 94), 13, Color("C8DBE5"))
			_draw_text("10 級右鍵技能；攻破城堡後留在圈內", tutorial.position + Vector2(14, 116), 13, Color("C8DBE5"))
			_draw_text("M 大地圖　Esc 暫停　F5 儲存", tutorial.position + Vector2(14, 138), 13, Color("C8DBE5"))


func _aionis_boss_hud_should_show() -> bool:
	if not timeless_gate_unlocked or aionis_boss == null or aionis_boss.is_defeated():
		return false
	var state: Dictionary = aionis_boss.get_text_state()
	return bool(state.get("engaged", false)) or Vector2(player.get("pos", HOUSE_POS)).distance_to(_aionis_boss_position()) <= 1520.0


func _draw_aionis_boss_hud() -> void:
	if not _aionis_boss_hud_should_show():
		return
	var state: Dictionary = aionis_boss.get_text_state()
	var width := minf(700.0, maxf(520.0, screen_size.x - 980.0)) if _is_touch_scheme() else minf(780.0, maxf(500.0, screen_size.x - 650.0))
	# The centre of the top edge is clear of the player card and minimap on
	# phones; putting the panel here also leaves the utility-button row free.
	var panel_y := 14.0
	var panel := Rect2(screen_size.x * 0.5 - width * 0.5, panel_y, width, 104.0)
	var gold := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["gold"])
	var time_color := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["time"])
	var core := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["core"])
	draw_rect(panel, Color("071020", 0.96))
	draw_rect(panel, Color(gold, 0.94), false, 3.0)
	_draw_text(str(state.get("name", "諸界終時者・艾歐尼斯")), panel.position + Vector2(panel.size.x * 0.5, 22.0), 19, Color("FFF5D9"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 34.0)
	var hp_ratio := clampf(float(state.get("hp_ratio", 0.0)), 0.0, 1.0)
	var bar_position := panel.position + Vector2(20.0, 34.0)
	var bar_size := Vector2(panel.size.x - 40.0, 22.0)
	_draw_bar(bar_position, bar_size, hp_ratio, core if int(state.get("phase", 1)) >= 4 else gold, Color("10182B"))
	for threshold in [0.25, 0.50, 0.75]:
		var marker_x := bar_position.x + bar_size.x * float(threshold)
		draw_line(Vector2(marker_x, bar_position.y - 3.0), Vector2(marker_x, bar_position.y + bar_size.y + 3.0), time_color, 2.0)
	_draw_text("%d / %d" % [int(state.get("hp", 0.0)), int(state.get("max_hp", 0.0))], bar_position + Vector2(bar_size.x * 0.5, 15.0), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 240.0)
	var phase_number := int(state.get("phase", 1))
	_draw_text("第 %d 階段・%s" % [phase_number, str(state.get("phase_name", "時脈初啟"))], panel.position + Vector2(20.0, 78.0), 13, Color("FFF0C1"))
	var broken := int(state.get("anchors_broken", 0))
	for anchor_index in 4:
		var anchor_center := panel.position + Vector2(panel.size.x * 0.5 - 45.0 + float(anchor_index) * 30.0, 75.0)
		var anchor_broken := anchor_index < broken
		draw_circle(anchor_center, 8.0, Color(time_color if anchor_broken else gold, 0.82))
		draw_arc(anchor_center, 10.0, 0.0, TAU, 16, Color("E8E0C9"), 1.5)
	var breach := float(state.get("time_anchor_breach", 0.0))
	if breach > 0.0:
		_draw_text("破防 %.1fs" % breach, panel.position + Vector2(panel.size.x * 0.5, 99.0), 12, Color("8AF6D0"), HORIZONTAL_ALIGNMENT_CENTER, 150.0)
	else:
		_draw_text("時間錨 %d / 4" % (4 - broken), panel.position + Vector2(panel.size.x * 0.5, 99.0), 12, time_color, HORIZONTAL_ALIGNMENT_CENTER, 150.0)
	var state_id := str(state.get("state", "CHASE"))
	var status_text := "追獵中"
	match state_id:
		"IDLE": status_text = "沉睡於無時之庭"
		"TELEGRAPH": status_text = "高危因果預警"
		"RECOVERY": status_text = "時脈重整"
		"RETURNING": status_text = "返回無時之庭"
	var active_skill := str(state.get("telegraph_skill", state.get("active_skill", "")))
	if not active_skill.is_empty():
		status_text = "%s　%s" % [status_text, _aionis_skill_name(active_skill)]
	_draw_text(status_text, panel.position + Vector2(panel.size.x - 20.0, 78.0), 13, Color("FFB0A6") if state_id == "TELEGRAPH" else time_color, HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x * 0.45)


func _chaos_boss_hud_should_show() -> bool:
	if chaos_boss == null or chaos_boss.is_defeated():
		return false
	var state: Dictionary = chaos_boss.get_text_state()
	return bool(state.get("engaged", false)) or Vector2(player.get("pos", HOUSE_POS)).distance_to(_chaos_boss_position()) <= 1420.0


func _draw_chaos_boss_hud() -> void:
	if not _chaos_boss_hud_should_show():
		return
	var state: Dictionary = chaos_boss.get_text_state()
	var width := minf(700.0, maxf(450.0, screen_size.x - 660.0))
	var panel := Rect2(screen_size.x * 0.5 - width * 0.5, 14.0, width, 92.0)
	var core := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["core"])
	var energy := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["energy"])
	var rift := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["rift"])
	draw_rect(panel, Color(0.020, 0.010, 0.035, 0.96))
	draw_rect(panel, Color(rift, 0.94), false, 3.0)
	_draw_text(str(state.get("name", "萬象崩滅者・卡厄隆")), panel.position + Vector2(panel.size.x * 0.5, 23.0), 19, Color("F8EFFF"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 32.0)
	var hp_ratio := clampf(float(state.get("hp_ratio", 0.0)), 0.0, 1.0)
	var bar_position := panel.position + Vector2(20.0, 36.0)
	var bar_size := Vector2(panel.size.x - 40.0, 21.0)
	_draw_bar(bar_position, bar_size, hp_ratio, core if int(state.get("phase", 1)) < 3 else Color("FF315F"), Color("1C0B25"))
	for threshold in [0.35, 0.70]:
		var marker_x := bar_position.x + bar_size.x * float(threshold)
		draw_line(Vector2(marker_x, bar_position.y - 3.0), Vector2(marker_x, bar_position.y + bar_size.y + 3.0), energy, 2.0)
	_draw_text("%d / %d" % [int(state.get("hp", 0.0)), int(state.get("max_hp", 0.0))], bar_position + Vector2(bar_size.x * 0.5, 15.0), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 220.0)
	var phase_number := int(state.get("phase", 1))
	var phase_names := ["裂界甦醒", "星滅狂潮", "萬象歸零"]
	var phase_name := str(phase_names[clampi(phase_number - 1, 0, phase_names.size() - 1)])
	_draw_text("第 %d 階段・%s" % [phase_number, phase_name], panel.position + Vector2(20.0, 80.0), 13, Color("E8CFFF"))
	var state_id := str(state.get("state", "CHASE"))
	var status_text := "追獵中"
	match state_id:
		"IDLE": status_text = "沉睡於混沌祭壇"
		"TELEGRAPH": status_text = "危險預警"
		"RECOVERY": status_text = "技能後搖"
		"RETURNING": status_text = "返回混沌祭壇"
	var active_skill := str(state.get("active_skill", ""))
	if not active_skill.is_empty():
		status_text = "%s　%s" % [status_text, _chaos_skill_name(active_skill)]
	_draw_text(status_text, panel.position + Vector2(panel.size.x - 20.0, 80.0), 13, Color("FFD2EF") if state_id == "TELEGRAPH" else Color("BFF8FF"), HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x * 0.62)


func _python_boss_hud_should_show() -> bool:
	if python_boss == null:
		return false
	var state: Dictionary = python_boss.get_text_state()
	if not bool(state.get("discovered", false)):
		return false
	var state_id := str(state.get("state", "IDLE"))
	var near_nest := Vector2(player["pos"]).distance_to(_python_boss_position()) <= 900.0
	if not bool(state.get("engaged", false)) and state_id != "RETURNING" and not near_nest:
		return false
	if state_id == "DEAD":
		return false
	return true


func _draw_python_boss_hud() -> void:
	if not _python_boss_hud_should_show():
		return
	var state: Dictionary = python_boss.get_text_state()
	var state_id := str(state.get("state", "IDLE"))
	var width: float = minf(640.0, maxf(430.0, screen_size.x - 700.0))
	var panel := Rect2(screen_size.x * 0.5 - width * 0.5, 14.0, width, 86.0)
	var poison := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["poison_color"])
	draw_rect(panel, Color(0.025, 0.018, 0.035, 0.94))
	draw_rect(panel, Color(poison.lightened(0.25), 0.92), false, 2.5)
	_draw_text(str(state.get("name", "腐沼蟒皇・薩迦")), panel.position + Vector2(panel.size.x * 0.5, 23), 18, Color("F4EFFF"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 30.0)
	var hp_ratio: float = clampf(float(state.get("hp_ratio", 0.0)), 0.0, 1.0)
	var bar_position := panel.position + Vector2(18, 34)
	var bar_size := Vector2(panel.size.x - 36, 20)
	_draw_bar(bar_position, bar_size, hp_ratio, Color("8E3159") if int(state.get("phase", 1)) < 3 else poison, Color("241421"))
	for threshold in [0.35, 0.70]:
		var marker_x := bar_position.x + bar_size.x * float(threshold)
		draw_line(Vector2(marker_x, bar_position.y - 3), Vector2(marker_x, bar_position.y + bar_size.y + 3), Color("F4D7A1"), 2.0)
	_draw_text("%d / %d" % [int(state.get("hp", 0.0)), int(state.get("max_hp", 0.0))], bar_position + Vector2(bar_size.x * 0.5, 15), 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 180)
	var phase_text := "第 %d 階段・%s" % [int(state.get("phase", 1)), str(state.get("phase_name", "狩獵"))]
	var status_text := ""
	match state_id:
		"RETURNING": status_text = "正在返回巢穴・逐漸恢復生命"
		"STUNNED": status_text = "暈眩破綻・頭部傷害 +20%"
		"PHASE_CHANGE": status_text = "階段轉換・高額減傷"
		"TELEGRAPH": status_text = "危險預警"
		"RECOVERY": status_text = "技能後搖"
	var active_skill := str(state.get("active_skill", ""))
	if active_skill != "" and GameConfig.PYTHON_BOSS_CONFIG["skills"].has(active_skill):
		status_text = "%s　%s" % [status_text, str(GameConfig.PYTHON_BOSS_CONFIG["skills"][active_skill]["name"])] if status_text != "" else str(GameConfig.PYTHON_BOSS_CONFIG["skills"][active_skill]["name"])
	_draw_text(phase_text, panel.position + Vector2(18, 76), 13, Color("E8CFFF"))
	_draw_text(status_text, panel.position + Vector2(panel.size.x - 18, 76), 13, Color("FFD17A") if state_id == "STUNNED" else Color("E6B8F7"), HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x * 0.60)

	var player_status: Dictionary = python_boss.get_unit_status("player", 0)
	var badge_x := 34.0
	var badge_y := 154.0
	var poison_stacks := int(player_status.get("poison_stacks", 0))
	if poison_stacks > 0:
		var poison_badge := Rect2(badge_x, badge_y, 96, 25)
		draw_rect(poison_badge, Color(0.20, 0.05, 0.26, 0.92))
		draw_rect(poison_badge, poison, false, 1.5)
		_draw_text("毒素 ×%d" % poison_stacks, poison_badge.position + Vector2(48, 18), 12, Color("F0CFFF"), HORIZONTAL_ALIGNMENT_CENTER, 88)
		badge_x += 103.0
	if float(player_status.get("pool_slow_ttl", 0.0)) > 0.0:
		var slow_badge := Rect2(badge_x, badge_y, 82, 25)
		draw_rect(slow_badge, Color(0.12, 0.07, 0.16, 0.92))
		draw_rect(slow_badge, Color("B985D6"), false, 1.5)
		_draw_text("毒潭減速", slow_badge.position + Vector2(41, 18), 12, Color("E8D1F4"), HORIZONTAL_ALIGNMENT_CENTER, 76)
		badge_x += 89.0
	if float(player_status.get("control_immunity", 0.0)) > 0.0:
		var immune_badge := Rect2(badge_x, badge_y, 92, 25)
		draw_rect(immune_badge, Color(0.15, 0.13, 0.04, 0.92))
		draw_rect(immune_badge, GOLD, false, 1.5)
		_draw_text("纏繞免疫", immune_badge.position + Vector2(46, 18), 12, Color("FFF2B6"), HORIZONTAL_ALIGNMENT_CENTER, 86)

	if float(player_status.get("constricted", 0.0)) > 0.0:
		var break_max: float = float(GameConfig.PYTHON_BOSS_CONFIG["skills"]["constrict"]["break_gauge"])
		var remaining: float = float(state.get("break_gauge", 0.0))
		var break_panel := Rect2(screen_size.x * 0.5 - 210.0, screen_size.y - 164.0, 420.0, 58.0)
		draw_rect(break_panel, Color(0.10, 0.02, 0.13, 0.94))
		draw_rect(break_panel, Color("F06AD8"), false, 2.5)
		var escape_hint := "連點右側攻擊區掙脫" if _is_touch_scheme() else "連點左鍵掙脫"
		_draw_text("遭到絞蟒纏縛！%s／友軍攻擊發光蛇身" % escape_hint, break_panel.position + Vector2(210, 23), 14, Color("FFE6FB"), HORIZONTAL_ALIGNMENT_CENTER, 400)
		_draw_bar(break_panel.position + Vector2(18, 34), Vector2(384, 12), 1.0 - clampf(remaining / maxf(break_max, 1.0), 0.0, 1.0), Color("F06AD8"), Color("351035"))


func _draw_skill_icon(rect: Rect2, key_name: String, label: String, cooldown: float, max_cooldown: float, color: Color, enabled: bool) -> void:
	draw_rect(rect, Color(0.025, 0.045, 0.06, 0.94))
	draw_rect(rect, color, false, 2.0)
	_draw_text(key_name, rect.position + Vector2(rect.size.x * 0.5, 21), 13, color, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8)
	_draw_text(label, rect.position + Vector2(rect.size.x * 0.5, 47), 12, Color("EAF6FF") if enabled else Color("7B878D"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 6)
	if cooldown > 0.0:
		var ratio: float = clamp(cooldown / max(max_cooldown, 0.01), 0.0, 1.0)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y * (1.0 - ratio)), Vector2(rect.size.x, rect.size.y * ratio)), Color(0.0, 0.0, 0.0, 0.58))
		_draw_text("%.1f" % cooldown, rect.position + Vector2(rect.size.x * 0.5, 67), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_language_toggle() -> void:
	var rect := _language_toggle_rect()
	_draw_button(rect, "EN" if language != "en" else "中文", Color("5B6F8F"))


func _draw_touch_round_button(rect: Rect2, label: String, color: Color, pressed: bool = false, enabled: bool = true) -> void:
	var scale := touch_ui_coordinate_scale
	var center := rect.get_center()
	var radius := minf(rect.size.x, rect.size.y) * 0.5
	var base_color := color if enabled else Color("596168")
	draw_circle(center + Vector2(0.0, 3.0 * scale), radius, Color(0.015, 0.025, 0.035, 0.72))
	draw_circle(center, radius - 2.0 * scale, Color(base_color.darkened(0.60), 0.82 if enabled else 0.62))
	if pressed:
		draw_circle(center, radius - 7.0 * scale, Color(base_color, 0.34))
	draw_arc(center, radius - 2.0 * scale, 0.0, TAU, 32, Color(base_color.lightened(0.22), 0.95), 2.8 * scale, true)
	_draw_text(label, center + Vector2(0.0, 6.0 * scale), maxi(12, roundi(14.0 * scale)), Color("F5FAFF") if enabled else Color("A2ABB0"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8.0 * scale)


func _draw_touch_joystick(center: Vector2, vector: Vector2, label: String, color: Color, active: bool) -> void:
	var scale := touch_ui_coordinate_scale
	var radius := TOUCH_STICK_RADIUS * scale
	var alpha := 0.72 if active else 0.48
	draw_circle(center + Vector2(0.0, 5.0 * scale), radius + 6.0 * scale, Color(0.01, 0.02, 0.025, 0.50))
	draw_circle(center, radius, Color(0.025, 0.055, 0.07, alpha))
	draw_arc(center, radius, 0.0, TAU, 42, Color(color, 0.74 if active else 0.45), 3.0 * scale, true)
	for direction_value in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		var direction := Vector2(direction_value)
		var marker_center: Vector2 = center + direction * 52.0 * scale
		var perpendicular := Vector2(-direction.y, direction.x)
		var selected := active and vector.length_squared() > 0.04 and vector.normalized().dot(direction) > 0.55
		draw_circle(marker_center, 12.0 * scale, Color(color.darkened(0.62), 0.84 if selected else 0.58))
		draw_arc(marker_center, 12.0 * scale, 0.0, TAU, 20, Color(color, 0.95 if selected else 0.62), 1.8 * scale, true)
		var arrow := PackedVector2Array([
			marker_center + direction * 8.0 * scale,
			marker_center - direction * 5.0 * scale + perpendicular * 6.0 * scale,
			marker_center - direction * 5.0 * scale - perpendicular * 6.0 * scale,
		])
		draw_colored_polygon(arrow, Color("F5FAFF") if selected else Color(color.lightened(0.30), 0.92))
	var knob_position := center + vector.limit_length(1.0) * (radius * 0.62)
	draw_circle(knob_position + Vector2(0.0, 3.0 * scale), 29.0 * scale, Color(0.01, 0.02, 0.03, 0.62))
	draw_circle(knob_position, 27.0 * scale, Color(color.darkened(0.42), 0.96))
	draw_arc(knob_position, 27.0 * scale, 0.0, TAU, 28, Color(color.lightened(0.25), 0.95), 2.5 * scale, true)
	_draw_text(label, center + Vector2(0.0, -radius - 12.0 * scale), maxi(11, roundi(13.0 * scale)), Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, 130.0 * scale)


func _draw_touch_controls() -> void:
	if mode != GameMode.PLAYING:
		return
	if active_panel != "":
		var close_rect := _touch_panel_close_rect()
		if close_rect.size.x > 0.0:
			var close_scale := touch_ui_coordinate_scale
			draw_rect(close_rect, Color(0.025, 0.045, 0.06, 0.96))
			draw_rect(close_rect, Color("E6B8F7") if _touch_feedback_active("close") else PANEL_EDGE, false, 2.0 * close_scale)
			_draw_text("Close" if language == "en" else "關閉", close_rect.get_center() + Vector2(0.0, 6.0 * close_scale), maxi(12, roundi(14.0 * close_scale)), Color("F5FAFF"), HORIZONTAL_ALIGNMENT_CENTER, close_rect.size.x - 8.0 * close_scale)
		return

	_draw_touch_joystick(_touch_move_center(), touch_move_vector, "Move" if language == "en" else "移動", FRIEND_BLUE, touch_move_pointer >= 0)
	_draw_touch_joystick(_touch_aim_center(), touch_aim_vector, "Aim & Attack" if language == "en" else "瞄準攻擊", FIRE_ORANGE, touch_aim_pointer >= 0)

	var unlocked := int(player.get("level", 1)) >= 10
	var special_rect := _touch_special_rect()
	var special_label := ("Skill" if language == "en" else "技能") if unlocked else "Lv.10"
	_draw_touch_round_button(special_rect, special_label, GOLD, _touch_feedback_active("special"), unlocked)
	if unlocked and float(player.get("special_cd", 0.0)) > 0.0:
		var cooldown_scale := touch_ui_coordinate_scale
		_draw_text("%.1f" % float(player["special_cd"]), special_rect.get_center() + Vector2(0.0, 28.0 * cooldown_scale), maxi(10, roundi(12.0 * cooldown_scale)), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, special_rect.size.x)

	var utility_rects := _touch_utility_rects()
	var labels := {"guide": "說明", "map": "地圖", "skills": "能力", "upgrades": "兵強", "recruit": "招募", "command": "軍令", "notices": "通知開" if notifications_hidden else "通知關", "cheat": "作弊", "fullscreen": "全螢", "pause": "暫停"}
	if language == "en":
		labels = {"guide": "Help", "map": "Map", "skills": "Hero", "upgrades": "Troops", "recruit": "Recruit", "command": "Orders", "notices": "Show" if notifications_hidden else "Hide", "cheat": "Cheat", "fullscreen": "Full", "pause": "Pause"}
	var colors := {"guide": Color("7893A3"), "map": MAGIC_PURPLE, "skills": FRIEND_BLUE, "upgrades": Color("48A0BF"), "recruit": HEAL_GREEN, "command": GOLD, "notices": Color("557A66") if notifications_hidden else Color("6B7188"), "cheat": Color("76528D"), "fullscreen": Color("4E7693"), "pause": Color("D36D68")}
	for action_value in utility_rects.keys():
		var action := str(action_value)
		var enabled := action != "recruit" or _is_near_recruitment()
		_draw_touch_round_button(Rect2(utility_rects[action]), str(labels[action]), Color(colors[action]), _touch_feedback_active(action), enabled)


func _draw_python_nest_map_icon(position: Vector2, large: bool, engaged: bool, defeated: bool) -> void:
	var icon_scale := 1.28 if large else 0.86
	var radius := 10.0 * icon_scale
	var poison := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["poison_color"])
	var warning := Color(GameConfig.PYTHON_BOSS_CONFIG["vfx"]["warning"])
	if engaged and not defeated:
		var pulse := 0.5 + 0.5 * sin(game_time * 7.0)
		draw_circle(position, radius + (4.0 + pulse * 2.5) * icon_scale, Color(warning, 0.08 + pulse * 0.12))
		draw_arc(position, radius + (3.0 + pulse * 2.0) * icon_scale, 0.0, TAU, 24, Color(poison.lightened(0.34), 0.58 + pulse * 0.36), 1.7 * icon_scale, true)

	# 巢穴底座與黑色洞口提供在綠色地圖上的高明度／輪廓對比。
	draw_circle(position + Vector2(0.0, 1.5 * icon_scale), radius + 2.8 * icon_scale, Color(0.025, 0.018, 0.03, 0.94))
	draw_circle(position, radius + 1.1 * icon_scale, Color("67452F") if not defeated else Color("4F5156"))
	draw_arc(position, radius, -2.85, 2.45, 24, Color(poison, 0.92) if not defeated else Color("898A91"), 2.0 * icon_scale, true)
	draw_circle(position, radius * 0.62, Color(0.018, 0.012, 0.025, 0.98))

	if defeated:
		draw_arc(position, radius * 0.56, -2.35, 2.35, 18, Color("8F939A"), 2.0 * icon_scale, true)
		var cross_size := 5.0 * icon_scale
		draw_line(position - Vector2(cross_size, cross_size), position + Vector2(cross_size, cross_size), Color("D1C4D8"), 2.1 * icon_scale, true)
		draw_line(position + Vector2(-cross_size, cross_size), position + Vector2(cross_size, -cross_size), Color("D1C4D8"), 2.1 * icon_scale, true)
		return

	# 由內向外的盤蛇曲線；末端加上有眼睛的蛇首，避免看起來只像一般螺旋。
	var coil_points := PackedVector2Array()
	var start_angle := -PI * 0.72
	for index in 20:
		var progress := float(index) / 19.0
		var angle := start_angle + progress * TAU * 1.32
		var coil_radius := lerpf(radius * 0.16, radius * 0.77, progress)
		coil_points.append(position + Vector2.from_angle(angle) * coil_radius)
	draw_polyline(coil_points, Color("101A13"), 4.2 * icon_scale, true)
	draw_polyline(coil_points, Color("55A56B"), 2.35 * icon_scale, true)
	var head_center := coil_points[coil_points.size() - 1]
	var head_angle := (head_center - coil_points[coil_points.size() - 2]).angle()
	var head_points := [Vector2(4.2, 0.0), Vector2(-2.4, -3.2), Vector2(-4.0, 0.0), Vector2(-2.4, 3.2)]
	_draw_polygon_shape(head_center, head_points, head_angle, Color("2E7145"), Color("EBD9F2"), 1.0 * icon_scale, icon_scale)
	var forward := Vector2.from_angle(head_angle)
	var eye_side := Vector2.from_angle(head_angle - PI * 0.5)
	draw_circle(head_center + forward * (1.05 * icon_scale) + eye_side * (1.0 * icon_scale), maxf(0.75, 0.78 * icon_scale), Color("FFE56A"))


func _draw_satellite_nest_map_icon(position: Vector2, large: bool, level: int, cleared: bool = false) -> void:
	var scale := 1.15 if large else 0.78
	var radius := 8.5 * scale
	draw_circle(position + Vector2(0, 1.5) * scale, radius + 3.0 * scale, Color(0.02, 0.025, 0.018, 0.92))
	draw_circle(position, radius + 1.0 * scale, Color("55595A") if cleared else Color("7A5A3C"))
	draw_circle(position, radius * 0.56, Color("202223") if cleared else Color("171713"))
	if cleared:
		var cross := radius * 0.48
		draw_line(position - Vector2(cross, cross), position + Vector2(cross, cross), Color("D1D5D6"), 2.0 * scale, true)
		draw_line(position + Vector2(-cross, cross), position + Vector2(cross, -cross), Color("D1D5D6"), 2.0 * scale, true)
		if large:
			_draw_text("此巢穴已清除", position + Vector2(0, 22), 10, Color("C8CED0"), HORIZONTAL_ALIGNMENT_CENTER, 92.0)
		return
	var trail := PackedVector2Array()
	for index in 11:
		var t := float(index) / 10.0
		trail.append(position + Vector2(-radius * 0.62 + t * radius * 1.24, sin(t * TAU) * radius * 0.33))
	draw_polyline(trail, Color("65B879"), 2.2 * scale, true)
	var head := trail[trail.size() - 1]
	draw_circle(head, 2.2 * scale, Color("4C9C61"))
	draw_circle(head + Vector2(0.8, -0.7) * scale, 0.65 * scale, GOLD)
	if large:
		_draw_text("Boss 巢穴 %d" % level, position + Vector2(0, 22), 10, Color("D8E7C8"), HORIZONTAL_ALIGNMENT_CENTER, 86.0)


func _draw_aionis_map_icon(position: Vector2, large: bool, engaged: bool, defeated: bool, locked: bool = false, offscreen: bool = false, direction_angle: float = 0.0) -> void:
	var scale := 1.28 if large else 0.86
	var gold := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["gold"])
	var time_color := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["time"])
	var core := Color(GameConfig.AIONIS_BOSS_CONFIG["vfx"]["core"])
	var disabled := Color("858A94")
	var accent := disabled if defeated else (Color("B9A66C") if locked else gold)
	var face_color := Color("3B3F48") if defeated else (Color("262A32") if locked else Color("121D35"))
	var pulse := 0.5 + 0.5 * sin(game_time * (3.0 if locked else 5.5))
	var glow_alpha := 0.08 + pulse * (0.05 if locked else 0.11)
	if not defeated:
		draw_circle(position, (21.0 + pulse * (2.0 if locked else 4.0)) * scale, Color(accent, glow_alpha + (0.06 if engaged else 0.0)))
	# The four-point beacon gives Aionis the same instant map readability as the
	# Chaos diamond, while the clock face keeps the two bosses unmistakable.
	var beacon := [Vector2(0, -20), Vector2(7, -13), Vector2(20, 0), Vector2(7, 13), Vector2(0, 20), Vector2(-7, 13), Vector2(-20, 0), Vector2(-7, -13)]
	_draw_polygon_shape(position, beacon, 0.0, Color("30323A") if locked or defeated else Color("263452"), Color(accent, 0.96), 2.0 * scale, scale)
	for ray_angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var ray_start := position + Vector2.from_angle(ray_angle) * 20.0 * scale
		var ray_end := position + Vector2.from_angle(ray_angle) * (23.0 + pulse * 2.0) * scale
		draw_line(ray_start, ray_end, Color(accent, 0.72), 2.0 * scale, true)
	draw_circle(position, 14.0 * scale, face_color)
	draw_arc(position, 14.0 * scale, 0.0, TAU, 28, accent, 2.6 * scale)
	for tick_index in 12:
		var angle := -PI * 0.5 + TAU * float(tick_index) / 12.0
		var inner := position + Vector2.from_angle(angle) * (8.0 if tick_index % 3 == 0 else 10.0) * scale
		var outer := position + Vector2.from_angle(angle) * 13.0 * scale
		draw_line(inner, outer, time_color if not defeated and not locked else Color("777B82"), (2.0 if tick_index % 3 == 0 else 1.2) * scale)
	if locked and not defeated:
		draw_arc(position + Vector2(0, -1.5) * scale, 4.5 * scale, PI, TAU, 12, Color("E4D7AC"), 2.1 * scale)
		draw_rect(Rect2(position + Vector2(-5.0, -1.0) * scale, Vector2(10.0, 8.0) * scale), Color("B9A66C"))
		draw_circle(position + Vector2(0.0, 2.2) * scale, 1.35 * scale, Color("2D3037"))
	else:
		draw_line(position, position + Vector2.from_angle(-PI * 0.5 + game_time * 0.06) * 8.0 * scale, core if not defeated else Color("98999C"), 2.2 * scale)
		draw_circle(position, 2.8 * scale, core if not defeated else Color("A0A1A5"))
	if defeated:
		draw_line(position - Vector2(8, 8) * scale, position + Vector2(8, 8) * scale, Color("D7D8DB"), 2.5 * scale)
		draw_line(position + Vector2(-8, 8) * scale, position + Vector2(8, -8) * scale, Color("D7D8DB"), 2.5 * scale)
	if offscreen:
		var pointer := Vector2.from_angle(direction_angle)
		var pointer_tip := position + pointer * 29.0 * scale
		var pointer_base := position + pointer * 22.0 * scale
		var pointer_side := pointer.rotated(PI * 0.5) * 4.5 * scale
		draw_colored_polygon(PackedVector2Array([pointer_tip, pointer_base + pointer_side, pointer_base - pointer_side]), Color(accent, 0.95))


func _draw_aionis_map_label(rect: Rect2, center: Vector2, marker: Vector2, large: bool, locked: bool, defeated: bool, distance_km: float) -> void:
	var color := Color("AEB4BD") if defeated else (Color("D5C89D") if locked else Color("FFE8A0"))
	if large:
		var label := "無時之庭・已擊破" if defeated else ("無時之門・擊破混沌 Boss 解鎖" if locked else "艾歐尼斯・無時之庭　%.1f km" % distance_km)
		var label_width := 286.0 if locked else 224.0
		var baseline := marker + Vector2(0.0, 34.0 if marker.y < center.y else -28.0)
		baseline.x = clampf(baseline.x, rect.position.x + label_width * 0.5 + 4.0, rect.end.x - label_width * 0.5 - 4.0)
		baseline.y = clampf(baseline.y, rect.position.y + 17.0, rect.end.y - 6.0)
		var badge := Rect2(baseline - Vector2(label_width * 0.5, 14.0), Vector2(label_width, 20.0))
		draw_rect(badge, Color(0.025, 0.035, 0.06, 0.92))
		draw_rect(badge, Color(color, 0.58), false, 1.0)
		_draw_text(label, baseline, 11, color, HORIZONTAL_ALIGNMENT_CENTER, label_width)
		return
	var inward := (center - marker).normalized()
	if inward.length_squared() < 0.001:
		inward = Vector2.DOWN
	var small_width := 72.0
	var small_baseline := marker + inward * 36.0 + Vector2(0.0, 3.0)
	small_baseline.x = clampf(small_baseline.x, rect.position.x + small_width * 0.5 + 3.0, rect.end.x - small_width * 0.5 - 3.0)
	small_baseline.y = clampf(small_baseline.y, rect.position.y + 13.0, rect.end.y - 5.0)
	var small_badge := Rect2(small_baseline - Vector2(small_width * 0.5, 12.0), Vector2(small_width, 17.0))
	draw_rect(small_badge, Color(0.025, 0.035, 0.06, 0.90))
	_draw_text("無時之門" if locked else "艾歐尼斯", small_baseline, 9, color, HORIZONTAL_ALIGNMENT_CENTER, small_width)


func _draw_chaos_map_icon(position: Vector2, large: bool, engaged: bool, defeated: bool, offscreen: bool = false) -> void:
	var scale := 1.28 if large else 0.86
	var rift := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["rift"])
	var core := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["core"])
	var energy := Color(GameConfig.CHAOS_BOSS_CONFIG["vfx"]["energy"])
	var pulse := 0.5 + 0.5 * sin(game_time * 6.0)
	if engaged and not defeated:
		draw_circle(position, (18.0 + pulse * 4.0) * scale, Color(core, 0.10 + pulse * 0.10))
	var diamond := [Vector2(0, -13), Vector2(13, 0), Vector2(0, 13), Vector2(-13, 0)]
	_draw_polygon_shape(position, diamond, 0.0, Color("3A1F53") if not defeated else Color("4B4A50"), Color(rift, 0.95) if not defeated else Color("87858B"), 2.2 * scale, scale)
	draw_circle(position, 4.5 * scale, core if not defeated else Color("9A999D"))
	for blade_index in 3:
		var blade_angle := float(blade_index) * TAU / 3.0 - 0.4
		var blade_pos := position + Vector2.from_angle(blade_angle) * 18.0 * scale
		draw_line(blade_pos - Vector2.from_angle(blade_angle + 0.7) * 4.0 * scale, blade_pos + Vector2.from_angle(blade_angle + 0.7) * 4.0 * scale, energy if not defeated else Color("77777B"), 2.5 * scale)
	if defeated:
		draw_line(position - Vector2(7, 7) * scale, position + Vector2(7, 7) * scale, Color("D7D4DC"), 2.5 * scale)
		draw_line(position + Vector2(-7, 7) * scale, position + Vector2(7, -7) * scale, Color("D7D4DC"), 2.5 * scale)
	if offscreen:
		draw_arc(position, 22.0 * scale, -2.2, 0.9, 18, Color(core, 0.82), 2.0 * scale)


func _draw_castle_map_icon(position: Vector2, castle: Dictionary, large: bool) -> void:
	var tier := GameConfig.castle_tier_for_level(int(castle.get("level", 1)))
	var scale := 1.25 if large else 0.86
	var nation: Dictionary = Dictionary(castle.get("nation", {}))
	var base_color := Color(str(nation.get("color_hex", "3B82F6" if bool(castle.get("owned", false)) else "B84032")))
	var accent := Color("B97843")
	if tier >= 30: accent = Color("E2A24C")
	if tier >= 35: accent = Color("9BA8AC")
	if tier >= 40: accent = Color("FFD166")
	if tier >= 45: accent = Color("A9DEFF")
	if tier >= 50: accent = Color("75FFF0")
	if tier >= 40:
		var wall_size := 10.0 * scale
		draw_rect(Rect2(position - Vector2.ONE * wall_size, Vector2.ONE * wall_size * 2.0), Color(accent, 0.16))
		draw_rect(Rect2(position - Vector2.ONE * wall_size, Vector2.ONE * wall_size * 2.0), accent, false, 1.8 * scale)
	_draw_polygon_shape(position, [Vector2(-6, 5), Vector2(-6, -5), Vector2(0, -9), Vector2(6, -5), Vector2(6, 5)], 0.0, base_color, Color("17262D"), 1.2 * scale, scale)
	match tier:
		20:
			draw_circle(position + Vector2(-2, 1) * scale, 2.2 * scale, accent)
			draw_line(position, position + Vector2(7, -4) * scale, accent, 2.0 * scale)
		30:
			for slit in [-2.5, 2.5]: draw_line(position + Vector2(slit, -3) * scale, position + Vector2(slit, 3) * scale, accent, 1.6 * scale)
		35:
			draw_rect(Rect2(position + Vector2(-6, -2) * scale, Vector2(12, 5) * scale), accent)
			draw_line(position, position + Vector2(7, -4) * scale, Color("E8EFEF"), 2.0 * scale)
		40:
			draw_rect(Rect2(position + Vector2(-3, -4) * scale, Vector2(6, 8) * scale), accent, false, 1.5 * scale)
		45:
			draw_line(position + Vector2(-12, 0) * scale, position + Vector2(-5, 0) * scale, accent, 2.0 * scale)
			draw_line(position + Vector2(5, 0) * scale, position + Vector2(12, 0) * scale, accent, 2.0 * scale)
		50:
			draw_arc(position, 12.0 * scale, 0, TAU, 24, Color(accent, 0.82), 2.0 * scale)
			draw_circle(position, 2.5 * scale, Color("D7FFFA"))
	if large:
		_draw_text("Lv.%d" % int(castle.get("level", 1)), position + Vector2(0, 24), 10, accent, HORIZONTAL_ALIGNMENT_CENTER, 60.0)


func _draw_minimap(rect: Rect2, large: bool) -> void:
	draw_rect(rect, Color(0.025, 0.055, 0.055, 0.94))
	draw_rect(rect, Color("587D82"), false, 2.0)
	var scale := (0.055 if large else 0.032)
	var center := rect.get_center()
	# 已探索 Chunk。
	for key in discovered_chunks.keys():
		var parts := str(key).split(",")
		if parts.size() != 2: continue
		var chunk_center := Vector2(float(parts[0]) * WorldGenerator.CHUNK_SIZE + WorldGenerator.CHUNK_SIZE * 0.5, float(parts[1]) * WorldGenerator.CHUNK_SIZE + WorldGenerator.CHUNK_SIZE * 0.5)
		var p := center + (chunk_center - Vector2(player["pos"])) * scale
		if rect.grow(-3).has_point(p): draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.32, 0.52, 0.35, 0.55))
	var house_p := center + (HOUSE_POS - Vector2(player["pos"])) * scale
	if rect.has_point(house_p): draw_rect(Rect2(house_p - Vector2(4, 4), Vector2(8, 8)), Color("EAF6FF"))
	for castle in castles.values():
		var p := center + (Vector2(castle["pos"]) - Vector2(player["pos"])) * scale
		if rect.has_point(p):
			_draw_castle_map_icon(p, castle, large)
	var aionis_home := Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"])
	var aionis_raw := center + (aionis_home - Vector2(player["pos"])) * scale
	var aionis_bounds := rect.grow(-39.0 if large else -27.0)
	var aionis_offscreen := not aionis_bounds.has_point(aionis_raw)
	var aionis_marker := Vector2(
		clampf(aionis_raw.x, aionis_bounds.position.x, aionis_bounds.end.x),
		clampf(aionis_raw.y, aionis_bounds.position.y, aionis_bounds.end.y)
	)
	var chaos_home := Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"])
	var chaos_raw := center + (chaos_home - Vector2(player["pos"])) * scale
	var chaos_bounds := rect.grow(-31.0 if large else -21.0)
	var chaos_offscreen := not chaos_bounds.has_point(chaos_raw)
	var chaos_marker := Vector2(
		clampf(chaos_raw.x, chaos_bounds.position.x, chaos_bounds.end.x),
		clampf(chaos_raw.y, chaos_bounds.position.y, chaos_bounds.end.y)
	)
	# Separate distant boss beacons that clamp to the same edge or corner.
	if aionis_marker.distance_to(chaos_marker) < (54.0 if large else 40.0):
		var radial := (aionis_marker - center).normalized()
		if radial.length_squared() < 0.001:
			radial = Vector2.RIGHT
		var tangent := Vector2(-radial.y, radial.x)
		var separation := 58.0 if large else 44.0
		var candidate_a := aionis_marker + tangent * separation
		var candidate_b := aionis_marker - tangent * separation
		candidate_a = Vector2(clampf(candidate_a.x, aionis_bounds.position.x, aionis_bounds.end.x), clampf(candidate_a.y, aionis_bounds.position.y, aionis_bounds.end.y))
		candidate_b = Vector2(clampf(candidate_b.x, aionis_bounds.position.x, aionis_bounds.end.x), clampf(candidate_b.y, aionis_bounds.position.y, aionis_bounds.end.y))
		aionis_marker = candidate_a if candidate_a.distance_to(chaos_marker) >= candidate_b.distance_to(chaos_marker) else candidate_b
	var aionis_engaged: bool = aionis_boss != null and bool(aionis_boss.is_engaged())
	var aionis_defeated: bool = aionis_boss_defeated or (aionis_boss != null and bool(aionis_boss.is_defeated()))
	var aionis_locked := not timeless_gate_unlocked
	var aionis_direction := aionis_home - Vector2(player["pos"])
	_draw_aionis_map_icon(aionis_marker, large, aionis_engaged, aionis_defeated, aionis_locked, aionis_offscreen, aionis_direction.angle())
	_draw_aionis_map_label(rect, center, aionis_marker, large, aionis_locked, aionis_defeated, aionis_direction.length() / 1000.0)
	var chaos_engaged: bool = chaos_boss != null and chaos_boss.is_engaged()
	var chaos_defeated: bool = final_boss_defeated or (chaos_boss != null and chaos_boss.is_defeated())
	_draw_chaos_map_icon(chaos_marker, large, chaos_engaged, chaos_defeated, chaos_offscreen)
	if large:
		var distance_km := Vector2(player["pos"]).distance_to(chaos_home) / 1000.0
		var chaos_label := "混沌祭壇・已擊破" if chaos_defeated else "混沌祭壇　%.1f km" % distance_km
		_draw_text(chaos_label, chaos_marker + Vector2(0.0, 31.0), 11, Color("BFBAC4") if chaos_defeated else Color("F0CFFF"), HORIZONTAL_ALIGNMENT_CENTER, 168.0)
	if active_python_boss_lair_id != MAIN_PYTHON_BOSS_LAIR_ID or python_boss == null:
		var main_home := Vector2(GameConfig.PYTHON_BOSS_CONFIG["home_position"])
		var main_p := center + (main_home - Vector2(player["pos"])) * scale
		var main_margin := 17.0 if large else 11.0
		if rect.grow(-main_margin).has_point(main_p):
			_draw_python_nest_map_icon(main_p, large, false, main_python_boss_lair_cleared)
			if large and rect.grow(-42.0).has_point(main_p):
				_draw_text("蟒蛇 Boss 主巢", main_p + Vector2(0.0, 27.0), 11, Color("C9BED0") if main_python_boss_lair_cleared else Color("E8D1F4"), HORIZONTAL_ALIGNMENT_CENTER, 128.0)
	for nest in snake_nests.values():
		if not bool(nest.get("discovered", true)):
			continue
		if str(nest.get("id", "")) == active_python_boss_lair_id and python_boss != null:
			continue
		var nest_p := center + (Vector2(nest["pos"]) - Vector2(player["pos"])) * scale
		var nest_margin := 15.0 if large else 10.0
		if rect.grow(-nest_margin).has_point(nest_p):
			_draw_satellite_nest_map_icon(nest_p, large, int(nest["level"]), bool(nest.get("cleared", false)))
	if python_boss != null:
		var boss_state: Dictionary = python_boss.get_text_state()
		if bool(boss_state.get("discovered", false)):
			var nest_home := _python_boss_lair_home(active_python_boss_lair_id)
			var nest_p := center + (nest_home - Vector2(player["pos"])) * scale
			var marker_margin := 17.0 if large else 11.0
			if rect.grow(-marker_margin).has_point(nest_p):
				_draw_python_nest_map_icon(nest_p, large, bool(boss_state.get("engaged", false)), bool(boss_state.get("defeated", false)))
				if large and rect.grow(-42.0).has_point(nest_p):
					var marker_label := "蟒蛇 Boss 主巢" if active_python_boss_lair_id == MAIN_PYTHON_BOSS_LAIR_ID else "腐沼蟒皇・薩迦"
					_draw_text(marker_label, nest_p + Vector2(0.0, 27.0), 11, Color("E8D1F4"), HORIZONTAL_ALIGNMENT_CENTER, 128.0)
	for soldier in soldiers:
		var p := center + (Vector2(soldier["pos"]) - Vector2(player["pos"])) * scale
		if rect.has_point(p): draw_circle(p, 1.5, Color("9DD8FF"))
	draw_circle(center, 5.0, GOLD)
	draw_line(center, center + Vector2(player["facing"]) * 12.0, Color("EAF6FF"), 2.0)
	_draw_text("地圖  M", rect.position + Vector2(8, 18), 12, Color("B9D6D7"))


func _draw_command_panel() -> void:
	var panel := _command_panel_rect()
	draw_rect(panel, PANEL_BG)
	draw_rect(panel, PANEL_EDGE, false, 3.0)
	_draw_text("軍令中心", panel.position + Vector2(panel.size.x * 0.5, 35.0), 25, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 40.0)
	_draw_text("選擇命令；駐守與攻城會自動鎖定距離玩家最近的對應城堡", panel.position + Vector2(panel.size.x * 0.5, 61.0), 13, Color("AFC7D6"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 40.0)
	var commands := ["跟隨", "防守", "攻擊", "撤退", "駐守", "攻城"]
	var descriptions := ["跟隨玩家並保持隊形", "守住目前位置", "清除指定方向的敵軍", "脫離戰鬥返回玩家", "進入友方城堡防守", "先清守軍，再拆城牆與主城"]
	var colors := [FRIEND_BLUE, Color("4F83A1"), ENEMY_RED, Color("70828E"), HEAL_GREEN, FIRE_ORANGE]
	for index in commands.size():
		var rect := _command_button_rect(index, panel)
		var selected := soldier_command == str(commands[index])
		draw_rect(rect, Color(colors[index]).darkened(0.62))
		draw_rect(rect, GOLD if selected else Color(colors[index]), false, 3.0 if selected else 2.0)
		_draw_text("%d　%s" % [index + 1, commands[index]], rect.position + Vector2(rect.size.x * 0.5, 31.0), 18, Color("F5FAFF"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 14.0)
		_draw_text(str(descriptions[index]), rect.position + Vector2(rect.size.x * 0.5, 57.0), 12, Color("C5D7E0"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16.0)


func _draw_skills_panel() -> void:
	var panel := _skills_panel_rect()
	draw_rect(panel, PANEL_BG)
	draw_rect(panel, PANEL_EDGE, false, 3.0)
	_draw_text("角色能力", panel.position + Vector2(26, 37), 25, Color("EAF6FF"))
	_draw_text("剩餘技能點：%d" % int(player["skill_points"]), panel.position + Vector2(panel.size.x - 200, 36), 18, GOLD)
	var stats := ["attack", "defense", "max_hp", "speed", "attack_speed"]
	var labels := ["攻擊", "防禦", "生命", "速度", "攻擊速度"]
	var details := ["每點 +5% 傷害", "每點 +2 防禦（最高減傷 70%）", "每點 +8% 最大生命", "每點 +2.5%（上限 +30%）", "每點 +6% 攻速（最低冷卻 0.16 秒）"]
	for i in stats.size():
		var y := panel.position.y + 102 + i * 53
		draw_rect(Rect2(panel.position.x + 24, y - 24, panel.size.x - 48, 45), Color(0.07, 0.11, 0.14, 0.82))
		_draw_text("%s　Lv.%d" % [labels[i], int(player["upgrades"][stats[i]])], Vector2(panel.position.x + 38, y + 3), 16, Color("EAF6FF"))
		_draw_text(details[i], Vector2(panel.position.x + 190, y + 2), 13, Color("9BB4C3"))
		_draw_button(Rect2(panel.end.x - 72, y - 24, 42, 36), "+", FRIEND_BLUE)
	var stat_y := panel.end.y - 86
	_draw_text("目前：攻擊 %.0f　防禦 %.0f　移速 %.0f　軍隊上限 %d" % [_player_damage(1.0), _player_defense(), _player_move_speed(), _army_limit()], Vector2(panel.position.x + 28, stat_y), 14, Color("C8DBE5"))
	var special_text := "已解鎖：%s　冷卻 %.1f 秒" % [GameConfig.SPECIAL_ATTACKS[str(player["class_id"])]["name"], float(player["special_cd"])] if int(player["level"]) >= 10 else "特殊技能將於等級 10 解鎖"
	_draw_text(special_text, Vector2(panel.position.x + 28, stat_y + 30), 14, GOLD)


func _draw_soldier_upgrade_panel() -> void:
	var panel := _soldier_upgrade_panel_rect()
	var scale := touch_ui_coordinate_scale if _is_touch_scheme() else 1.0
	draw_rect(panel, PANEL_BG)
	draw_rect(panel, Color("62B7D6"), false, 2.0 * scale)
	var compact := _is_touch_scheme() or panel.size.y < 470.0
	var selected_type := _selected_soldier_upgrade_type()
	var soldier_cfg: Dictionary = GameConfig.SOLDIERS.get(selected_type, {})
	var type_name := str(soldier_cfg.get("name", selected_type))
	if language == "en":
		type_name = GameLocalization.translate(type_name, "en")
	var unlocked := _soldier_type_is_unlocked(selected_type)
	var title := "Permanent Troop Upgrades" if language == "en" else "士兵永久強化"
	var subtitle := "Only troops recruited or revived after purchase receive these abilities." if language == "en" else "購買後才招募或復活的此兵種會取得能力；現有士兵不變。"
	_draw_text(title, panel.position + Vector2(18.0, 28.0) * scale, roundi(float(19 if compact else 23) * scale), Color("DDF7FF"), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 100.0 * scale)
	if not compact:
		_draw_text(subtitle, panel.position + Vector2(panel.size.x * 0.5, 28.0 * scale), roundi(12.0 * scale), Color("92B8C8"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x * 0.62)
	var controls := _soldier_upgrade_control_rects(panel)
	var button_font := roundi(15.0 * scale)
	_draw_button(Rect2(controls["type_prev"]), "◀", Color("39758A"), button_font, 2.0 * scale)
	_draw_button(Rect2(controls["type_next"]), "▶", Color("39758A"), button_font, 2.0 * scale)
	var type_line := "%s  ×%.2f%s" % [type_name, SoldierUpgradeCatalog.soldier_multiplier(selected_type), "  LOCKED" if not unlocked and language == "en" else ("  未解鎖" if not unlocked else "")]
	_draw_text(type_line, Vector2(panel.get_center().x, panel.position.y + 73.0 * scale), roundi(float(16 if compact else 18) * scale), Color("FFB08D") if not unlocked else Color("F1FBFF"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 170.0 * scale)
	var base_selected := soldier_upgrade_category == "base"
	_draw_button(Rect2(controls["base_tab"]), "Base Stats" if language == "en" else "基礎強化", Color("4F9BB5") if base_selected else Color("475A64"), button_font, 2.0 * scale)
	_draw_button(Rect2(controls["special_tab"]), "Special Abilities" if language == "en" else "特殊能力", MAGIC_PURPLE if not base_selected else Color("4B485B"), button_font, 2.0 * scale)

	var option_ids := _soldier_upgrade_option_ids(selected_type)
	var rows_per_page := _soldier_upgrade_rows_per_page(panel)
	var page_count := _soldier_upgrade_page_count(panel)
	soldier_upgrade_page = clampi(soldier_upgrade_page, 0, page_count - 1)
	var first_index := soldier_upgrade_page * rows_per_page
	for row_index in rows_per_page:
		var option_index := first_index + row_index
		if option_index >= option_ids.size():
			break
		var upgrade_id := str(option_ids[option_index])
		var row := _soldier_upgrade_row_rect(row_index, panel)
		var rank := SoldierUpgradeCatalog.current_rank(selected_type, upgrade_id, soldier_research)
		var max_rank := SoldierUpgradeCatalog.max_rank(upgrade_id)
		var cost := SoldierUpgradeCatalog.next_rank_cost(selected_type, upgrade_id, soldier_research)
		var preview := SoldierUpgradeCatalog.purchase_preview(selected_type, upgrade_id, soldier_research, int(player.get("money", 0)), unlocked)
		var allowed := bool(preview.get("allowed", false))
		var row_color := Color("173B4A") if allowed else (Color("3A3434") if cost >= 0 else Color("31434A"))
		draw_rect(row, row_color)
		draw_rect(row, Color("63BCD7") if allowed else Color("596A72"), false, 1.5 * scale)
		var cost_text := "MAX" if cost < 0 else "$%s" % _format_integer(cost)
		var display_rank := rank if rank >= max_rank else rank + 1
		var effect_text := SoldierUpgradeCatalog.localized_effect_text(upgrade_id, display_rank, language)
		if effect_text.is_empty():
			effect_text = SoldierUpgradeCatalog.localized_summary(upgrade_id, language)
		var name_text := "%s  Rank %d/%d" % [SoldierUpgradeCatalog.localized_name(upgrade_id, language), rank, max_rank] if language == "en" else "%s  階級 %d/%d" % [SoldierUpgradeCatalog.localized_name(upgrade_id, language), rank, max_rank]
		_draw_text(name_text, row.position + Vector2(10.0, 19.0) * scale, roundi(float(12 if compact else 14) * scale), Color("E9F7FC"), HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 142.0 * scale)
		_draw_text(cost_text, row.position + Vector2(row.size.x - 112.0 * scale, 19.0 * scale), roundi(float(13 if compact else 15) * scale), GOLD if allowed or cost < 0 else Color("D99A7A"), HORIZONTAL_ALIGNMENT_RIGHT, 100.0 * scale)
		var effect_color := Color("A9D9E7") if allowed or cost < 0 else Color("B8A9A3")
		_draw_text(effect_text, row.position + Vector2(10.0, 41.0) * scale, roundi(float(10 if compact else 11) * scale), effect_color, HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 20.0 * scale)

	_draw_button(Rect2(controls["page_prev"]), "◀ Prev" if language == "en" else "◀ 上頁", Color("4A6673"), button_font, 2.0 * scale)
	_draw_button(Rect2(controls["page_next"]), "Next ▶" if language == "en" else "下頁 ▶", Color("4A6673"), button_font, 2.0 * scale)
	if _is_touch_scheme():
		var touch_hint := "Specials trigger automatically · recruit this troop again after purchase" if language == "en" else "特殊能力會自動觸發；購買後請重新招募此兵種"
		_draw_text(touch_hint, Vector2(panel.get_center().x, panel.end.y - 78.0 * scale), roundi(11.0 * scale), Color("A9D9E7"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 48.0 * scale)
	var page_text := "Page %d/%d · Gold $%s" % [soldier_upgrade_page + 1, page_count, _format_integer(int(player.get("money", 0)))] if language == "en" else "第 %d/%d 頁・金幣 $%s" % [soldier_upgrade_page + 1, page_count, _format_integer(int(player.get("money", 0)))]
	_draw_text(page_text, Vector2(panel.get_center().x, panel.end.y - 17.0 * scale), roundi(12.0 * scale), GOLD, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 240.0 * scale)


func _draw_recruit_panel() -> void:
	var panel := _recruit_panel_rect()
	var ui_scale := touch_ui_coordinate_scale if _is_touch_scheme() else 1.0
	draw_rect(panel, PANEL_BG)
	draw_rect(panel, PANEL_EDGE, false, 3.0 * ui_scale)
	var touch_compact := _is_touch_scheme()
	_draw_text("據點招募", panel.position + Vector2(26.0, 30.0 if touch_compact else 35.0) * ui_scale, roundi(float(22 if touch_compact else 24) * ui_scale), Color("EAF6FF"))
	var buy_hint := "金幣 %d　軍隊 %d / %d" % [int(player["money"]), soldiers.size(), _army_limit()] if touch_compact else "金幣 %d　軍隊 %d / %d　Shift 點擊可購買 5 名" % [int(player["money"]), soldiers.size(), _army_limit()]
	_draw_text(buy_hint, panel.position + Vector2(26.0, 53.0 if touch_compact else 61.0) * ui_scale, roundi(float(13 if touch_compact else 14) * ui_scale), GOLD)
	var roster := _recruitable_soldier_order()
	var three_columns := roster.size() > 12
	for i in roster.size():
		var type_id: String = str(roster[i])
		var cfg: Dictionary = GameConfig.SOLDIERS[type_id]
		var combat: Dictionary = cfg["combat"]
		var recruit_cost := _soldier_recruit_cost(type_id)
		var base_recruit_cost := int(cfg["recruit_cost"]["gold"])
		var item := _recruit_item_rect(i, panel)
		var compact_row := item.size.y / ui_scale < 48.0
		draw_rect(item, Color(0.065, 0.10, 0.13, 0.90))
		draw_rect(item, Color(cfg["color"]).lightened(0.08), false, 1.5 * ui_scale)
		var icon_center := item.position + Vector2(22.0 * ui_scale, item.size.y * 0.5)
		if touch_compact:
			draw_set_transform(icon_center, 0.0, Vector2.ONE * ui_scale)
			_draw_recruit_icon(type_id, Vector2.ZERO)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_draw_recruit_icon(type_id, icon_center)
		var price_marker := "$%d" % recruit_cost
		if recruit_cost < base_recruit_cost:
			price_marker += "↓"
		var title_text := str(cfg["name"]) if three_columns else "%s　%s" % [cfg["name"], price_marker]
		var detail_text := "%s　已有 %d　HP %d" % [price_marker, _count_soldier_type(type_id), int(combat["hp"])] if three_columns else "已有 %d　HP %d　傷害 %d　射程 %d" % [_count_soldier_type(type_id), int(combat["hp"]), int(combat["attack"]), int(combat["range"])]
		_draw_text(title_text, item.position + Vector2(43.0, 16.0 if compact_row else 21.0) * ui_scale, roundi(float(11 if three_columns else (12 if compact_row else 14)) * ui_scale), Color("EAF6FF"), HORIZONTAL_ALIGNMENT_LEFT, item.size.x - 128.0 * ui_scale)
		# 三欄終局名單把價格放到第二行最前面，長英文名稱也不會蓋住金額。
		_draw_text(detail_text, item.position + Vector2(43.0, 33.0 if compact_row else 43.0) * ui_scale, roundi(float(9 if compact_row or three_columns else 11) * ui_scale), Color("AFC7D6"), HORIZONTAL_ALIGNMENT_LEFT, item.size.x - 126.0 * ui_scale)
		_draw_button(_recruit_buy_rect(i, panel), "招募", HEAL_GREEN if int(player["money"]) >= recruit_cost else Color("56636B"), roundi(12.0 * ui_scale), 2.0 * ui_scale)


func _draw_recruit_icon(type_id: String, center: Vector2) -> void:
	var accent := Color(GameConfig.SOLDIERS[type_id]["color"])
	draw_circle(center, 15.0, Color("172630"))
	draw_circle(center, 14.0, accent.darkened(0.18))
	match type_id:
		"swordsman":
			draw_line(center + Vector2(-6, 7), center + Vector2(8, -8), Color("F1F5F7"), 3.0)
			draw_line(center + Vector2(-1, 1), center + Vector2(6, 8), GOLD, 2.0)
		"healer":
			draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), HEAL_GREEN, 4.0)
			draw_line(center + Vector2(0, -7), center + Vector2(0, 7), HEAL_GREEN, 4.0)
		"archer":
			draw_arc(center + Vector2(3, 0), 9.0, -1.25, 1.25, 12, Color("D2A15F"), 2.0)
			draw_line(center + Vector2(-8, 0), center + Vector2(10, 0), Color("EAF6FF"), 1.5)
		"roller":
			draw_circle(center + Vector2(3, 1), 9.0, Color("82909B"))
			draw_arc(center + Vector2(3, 1), 6.0, 0.2, 4.0, 10, Color("CBD7DE"), 1.5)
		"mage":
			draw_line(center + Vector2(-7, 9), center + Vector2(5, -8), Color("B77C45"), 3.0)
			draw_circle(center + Vector2(6, -9), 5.0, MAGIC_PURPLE)
		"heavy":
			_draw_polygon_shape(center, [Vector2(-10, -10), Vector2(9, -8), Vector2(11, 4), Vector2(0, 12), Vector2(-11, 4)], 0.0, Color("A7B2BE"), FRIEND_DARK, 2.0)
		"priest":
			draw_arc(center, 10.0, PI, TAU, 14, GOLD, 3.0)
			draw_line(center + Vector2(0, -7), center + Vector2(0, 8), Color("F7E7A7"), 2.0)
		"cannon":
			draw_circle(center + Vector2(-8, 7), 5.0, INK)
			draw_circle(center + Vector2(8, 7), 5.0, INK)
			draw_rect(Rect2(center + Vector2(-11, -5), Vector2(20, 10)), FRIEND_BLUE)
			draw_line(center + Vector2(3, -3), center + Vector2(14, -9), Color("D5E7EF"), 5.0)
		"musketeer":
			draw_line(center + Vector2(-11, 6), center + Vector2(12, -7), Color("845832"), 4.0)
			draw_line(center + Vector2(-5, 2), center + Vector2(15, -9), Color("E3E8EB"), 1.8)
			draw_arc(center + Vector2(-3, -5), 7.0, PI, TAU, 10, Color("6A4930"), 3.0)
		"rifleman":
			draw_circle(center + Vector2(-3, -6), 6.0, Color("7DAE92"))
			draw_line(center + Vector2(-10, 5), center + Vector2(13, -5), Color("DDE6E8"), 4.0)
			draw_rect(Rect2(center + Vector2(0, 2), Vector2(5, 8)), Color("273035"))
		"tank":
			draw_rect(Rect2(center + Vector2(-13, -8), Vector2(26, 16)), Color("29332A"))
			draw_rect(Rect2(center + Vector2(-11, -5), Vector2(22, 10)), accent)
			draw_circle(center, 6.0, Color("98A77E"))
			draw_line(center + Vector2(3, -2), center + Vector2(15, -7), Color("D8E1D3"), 4.0)
		"rocket":
			draw_circle(center + Vector2(-8, 8), 4.0, INK)
			draw_circle(center + Vector2(8, 8), 4.0, INK)
			for lane in [-1.0, 0.0, 1.0]:
				draw_line(center + Vector2(-9, lane * 5.0), center + Vector2(10, -8.0 + lane * 5.0), Color("CBD3D5"), 3.0)
				draw_circle(center + Vector2(11, -9.0 + lane * 5.0), 2.5, FIRE_ORANGE)
		"gatling":
			draw_circle(center + Vector2(-6, 5), 7.0, Color("355D75"))
			for lane in [-2.0, -1.0, 0.0, 1.0, 2.0]:
				draw_line(center + Vector2(0, lane * 2.2), center + Vector2(13, lane * 2.2), Color("D6EEF6"), 1.7)
		"helicopter":
			_draw_polygon_shape(center, [Vector2(-11, -6), Vector2(8, -7), Vector2(13, 0), Vector2(8, 7), Vector2(-11, 6)], 0.0, Color("6CB8D4"), FRIEND_DARK, 1.5)
			draw_line(center + Vector2(-10, 0), center + Vector2(-16, 0), Color("BCEEFF"), 3.0)
			draw_line(center + Vector2(-13, 0), center + Vector2(13, 0), Color("EAFBFF"), 1.5)
		"bomber":
			_draw_polygon_shape(center, [Vector2(-12, -4), Vector2(-2, -4), Vector2(1, -13), Vector2(6, -11), Vector2(7, -4), Vector2(14, 0), Vector2(7, 4), Vector2(6, 11), Vector2(1, 13), Vector2(-2, 4), Vector2(-12, 4)], 0.0, Color("8AA8D0"), FRIEND_DARK, 1.3)
		"ufo":
			draw_arc(center, 12.0, 0.15, PI - 0.15, 18, Color("8DF7FF"), 4.0)
			draw_circle(center + Vector2(0, -4), 6.0, Color("BFFBFF"))
			draw_line(center + Vector2(-12, 3), center + Vector2(12, 3), FRIEND_BLUE, 3.0)


func _draw_map_panel() -> void:
	var panel := _map_panel_rect()
	draw_rect(panel, PANEL_BG)
	draw_rect(panel, PANEL_EDGE, false, 3.0)
	_draw_text("遠征地圖（M 關閉）", panel.position + Vector2(26, 38), 23, Color("EAF6FF"))
	_draw_minimap(Rect2(panel.position + Vector2(26, 58), panel.size - Vector2(52, 86)), true)


func _draw_pause_menu() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.0, 0.0, 0.0, 0.58))
	var center := screen_size * 0.5
	var panel := _pause_panel_rect()
	var ui_scale := touch_ui_coordinate_scale if _is_touch_scheme() else 1.0
	draw_rect(panel, PANEL_BG)
	draw_rect(panel, PANEL_EDGE, false, 3.0 * ui_scale)
	if _is_touch_scheme():
		_draw_text("遊戲暫停", Vector2(panel.get_center().x, panel.position.y + 31.0 * ui_scale), roundi(22.0 * ui_scale), Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 24.0 * ui_scale)
	else:
		_draw_text("遊戲暫停", center + Vector2(0, -218), 28, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, 300)
	var action_labels := {
		"resume": "繼續遊戲", "save": "儲存遊戲", "load": "讀取遊戲",
		"summon_chaos": "召喚混沌 Boss", "summon_aionis": "召喚艾歐尼斯", "restart": "重新開始",
	}
	var actions := _pause_actions()
	for index in actions.size():
		var action := str(actions[index])
		var label := str(action_labels[action])
		var color := Color("8B4B45") if action == "restart" else (Color("7B6224") if action == "summon_aionis" else (Color("6D3FA0") if action == "summon_chaos" else Color("466B76")))
		_draw_button(_pause_button_rect(index), label, color, roundi(14.0 * ui_scale), 2.0 * ui_scale)
	_draw_button(_pause_language_rect(), "English" if language != "en" else "中文", Color("5B6F8F"), roundi(14.0 * ui_scale), 2.0 * ui_scale)
	var volume_label_position := Vector2(panel.get_center().x, panel.position.y + 270.0 * ui_scale) if _is_touch_scheme() else center + Vector2(0, 207)
	_draw_text("音量 %d%%" % int(master_volume * 100.0), volume_label_position, roundi(15.0 * ui_scale), Color("C8DBE5"), HORIZONTAL_ALIGNMENT_CENTER, 150.0 * ui_scale)
	_draw_button(_pause_volume_rect("down"), "−", Color("466B76"), roundi(16.0 * ui_scale), 2.0 * ui_scale)
	_draw_button(_pause_volume_rect("up"), "+", Color("466B76"), roundi(16.0 * ui_scale), 2.0 * ui_scale)
	_draw_button(_pause_volume_rect("mute"), "靜音" if not sound_muted else "取消靜音", Color("5A6870"), roundi(14.0 * ui_scale), 2.0 * ui_scale)
	var footer := "點擊按鈕操作" if _is_touch_scheme() else "Esc 返回　F 全螢幕"
	var footer_position := Vector2(panel.get_center().x, panel.end.y - 10.0 * ui_scale) if _is_touch_scheme() else center + Vector2(0, 255)
	_draw_text(footer, footer_position, roundi(12.0 * ui_scale), Color("7893A3"), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 24.0 * ui_scale if _is_touch_scheme() else 260.0)


func _draw_death_overlay() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0.16, 0.01, 0.02, 0.55))
	var center := screen_size * 0.5
	_draw_text("遠征失敗", center + Vector2(0, -40), 40, Color("FFB0A9"), HORIZONTAL_ALIGNMENT_CENTER, 500)
	_draw_text("將在 %.1f 秒後於最近的友方據點復活" % max(0.0, death_timer), center + Vector2(0, 8), 18, Color("EAF6FF"), HORIZONTAL_ALIGNMENT_CENTER, 620)
	_draw_text("已扣除目前金幣的 10%，等級與存檔進度不受影響", center + Vector2(0, 40), 14, Color("C8B8B5"), HORIZONTAL_ALIGNMENT_CENTER, 620)


func _draw_confirm_restart() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color(0, 0, 0, 0.66))
	var center := screen_size * 0.5
	var panel := Rect2(center - Vector2(190, 100), Vector2(380, 200))
	draw_rect(panel, PANEL_BG)
	draw_rect(panel, Color("A65A52"), false, 3.0)
	_draw_text("確定重新開始？", center + Vector2(0, -47), 25, Color("FFCEC8"), HORIZONTAL_ALIGNMENT_CENTER, 320)
	_draw_text("未儲存的進度將遺失。", center + Vector2(0, -12), 14, Color("C8B8B5"), HORIZONTAL_ALIGNMENT_CENTER, 320)
	_draw_button(Rect2(center.x - 125, center.y + 42, 115, 44), "確定", Color("9A4D45"))
	_draw_button(Rect2(center.x + 10, center.y + 42, 115, 44), "取消", Color("466B76"))


func _count_soldier_type(type_id: String) -> int:
	var count := 0
	for soldier in soldiers:
		if soldier["type"] == type_id: count += 1
	return count


func _format_integer(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


func _draw_text(text: String, baseline: Vector2, size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var draw_position := baseline
	if width > 0.0:
		if alignment == HORIZONTAL_ALIGNMENT_CENTER:
			draw_position.x -= width * 0.5
		elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			draw_position.x -= width
	draw_string(ui_font, draw_position, _localized(text), alignment, width, size, color)


func _draw_button(rect: Rect2, label: String, color: Color, text_size: int = 15, border_width: float = 2.0) -> void:
	draw_rect(rect, color.darkened(0.55), true)
	draw_rect(rect, color, false, border_width)
	_draw_text(label, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.67), text_size, Color("F5FAFF"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x)


func _draw_bar(position: Vector2, size: Vector2, ratio: float, fill_color: Color, background: Color) -> void:
	ratio = clamp(ratio, 0.0, 1.0)
	draw_rect(Rect2(position, size), background)
	if ratio > 0.0: draw_rect(Rect2(position + Vector2(1, 1), Vector2((size.x - 2) * ratio, max(0.0, size.y - 2))), fill_color)
	draw_rect(Rect2(position, size), Color(0.04, 0.08, 0.10, 0.9), false, 1.0)


func _draw_polygon_shape(center: Vector2, points: Array, rotation: float, fill_color: Color, outline_color: Color, outline_width: float, scale: float = 1.0) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(center + Vector2(point).rotated(rotation) * scale)
	if transformed.size() >= 3: draw_colored_polygon(transformed, fill_color)
	if outline_width > 0.0 and outline_color.a > 0.0 and transformed.size() >= 2:
		var closed := PackedVector2Array(transformed)
		closed.append(transformed[0])
		draw_polyline(closed, outline_color, outline_width, true)


func _draw_ellipse_shadow(center: Vector2, radii: Vector2) -> void:
	var points := PackedVector2Array()
	for i in 18:
		var angle := TAU * float(i) / 18.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, Color(0.09, 0.15, 0.12, 0.35))


func _draw_flag(position: Vector2, color: Color, hostile: bool, scale: float) -> void:
	draw_line(position, position + Vector2(0, 50) * scale, INK, 3.0 * scale)
	var points: Array
	if hostile:
		points = [Vector2(0, 0), Vector2(31, 5), Vector2(24, 13), Vector2(34, 22), Vector2(0, 18)]
	else:
		points = [Vector2(0, 0), Vector2(34, 5), Vector2(27, 13), Vector2(34, 21), Vector2(0, 18)]
	_draw_polygon_shape(position, points, 0.0, color, INK, 1.6 * scale, scale)


func _on_screen(position: Vector2, margin: float = 0.0) -> bool:
	return Rect2(Vector2(-margin, -margin), screen_size + Vector2(margin * 2.0, margin * 2.0)).has_point(position)


# -----------------------------------------------------------------------------
# 內建 deterministic smoke/self-test
# -----------------------------------------------------------------------------

func _run_self_test() -> void:
	_self_test_passed = 0
	_self_test_failed = 0
	var test_path := "/tmp/infinite_legion_self_test.json"
	GameSaveManager.delete_save(test_path)

	var wg := WorldGenerator.new(20260731)
	_test_assert(wg.world_to_chunk(Vector2(-0.1, -960.1)) == Vector2i(-1, -2), "negative_chunk_floor")
	var origin_a := wg.generate_chunk(Vector2i.ZERO)
	var origin_b := wg.generate_chunk(Vector2i.ZERO)
	_test_assert(str(origin_a) == str(origin_b), "deterministic_chunk")
	_test_assert(origin_a["house"] != null and origin_a["enemy_spawns"].is_empty(), "origin_safe_zone")
	var castle_chunk := wg.generate_chunk(Vector2i(5, 5))
	_test_assert(castle_chunk["castle"] != null, "irregular_castle_milestone_anchor")
	var milestone_levels := [20, 30, 35, 40, 45, 50]
	var milestone_coords := [Vector2i(5, 5), Vector2i(9, 9), Vector2i(13, 13), Vector2i(17, 17), Vector2i(21, 21), Vector2i(25, 25)]
	var milestone_generation_ok := true
	for milestone_index in milestone_levels.size():
		var milestone_chunk := wg.generate_chunk(milestone_coords[milestone_index])
		if milestone_chunk["castle"] == null or int(milestone_chunk["castle"]["level"]) != int(milestone_levels[milestone_index]):
			milestone_generation_ok = false
			break
	_test_assert(milestone_generation_ok, "all_six_castle_milestones_generate_in_infinite_world")
	var nest_chunk := wg.generate_chunk(Vector2i(3, 2))
	_test_assert(nest_chunk.get("snake_nest") != null and str(nest_chunk["snake_nest"]["id"]).begins_with("python_boss_lair_"), "python_boss_lairs_generate_deterministically")
	var generated_lair_spawn_clear := true
	var generated_lair_position := Vector2(nest_chunk["snake_nest"]["position"])
	for generated_lair_obstacle in Array(nest_chunk.get("obstacles", [])):
		if generated_lair_position.distance_to(Vector2(generated_lair_obstacle["position"])) < WorldGenerator.SNAKE_NEST_BOSS_CLEAR_RADIUS + float(generated_lair_obstacle["radius"]):
			generated_lair_spawn_clear = false
			break
	_test_assert(generated_lair_spawn_clear, "python_boss_lair_has_clear_saga_spawn_area")
	var sparse_lair_count := 0
	for lair_y in range(-22, 23):
		for lair_x in range(-22, 23):
			if wg.generate_chunk(Vector2i(lair_x, lair_y)).get("snake_nest") != null:
				sparse_lair_count += 1
	_test_assert(sparse_lair_count > 0 and sparse_lair_count <= 25 and WorldGenerator.SNAKE_NEST_SPACING_X >= 9 and WorldGenerator.SNAKE_NEST_SPACING_Y >= 9, "python_boss_lairs_are_sparse")
	var original_world_generator := world_generator
	world_generator = wg
	var current_lair_descriptor: Dictionary = Dictionary(nest_chunk["snake_nest"])
	var current_lair_position := Vector2(current_lair_descriptor["position"])
	var old_dense_only_position := Vector2(8 * WorldGenerator.CHUNK_SIZE + WorldGenerator.CHUNK_SIZE * 0.5, 2 * WorldGenerator.CHUNK_SIZE + WorldGenerator.CHUNK_SIZE * 0.5)
	var legacy_lair_markers := {
		"snake_nest_3,2": {"id": "snake_nest_3,2", "pos": current_lair_position, "level": 2, "discovered": false, "nest_cleared": true},
		"python_boss_lair_3,2": {"id": "python_boss_lair_3,2", "pos": current_lair_position, "level": 4, "discovered": true, "cleared": false},
		"snake_nest_8,2": {"id": "snake_nest_8,2", "pos": old_dense_only_position, "level": 3, "discovered": true},
	}
	var migrated_lairs := _migrate_loaded_python_boss_lairs(legacy_lair_markers)
	var canonical_lair_id := str(current_lair_descriptor["id"])
	var canonical_lair: Dictionary = Dictionary(migrated_lairs.get(canonical_lair_id, {}))
	_test_assert(migrated_lairs.size() == 1 and not canonical_lair.is_empty() and bool(canonical_lair.get("discovered", false)) and bool(canonical_lair.get("cleared", false)), "legacy_dense_lairs_migrate_to_one_sparse_canonical_marker")
	var migrated_twice := _migrate_loaded_python_boss_lairs(migrated_lairs)
	_test_assert(str(migrated_twice) == str(migrated_lairs), "python_boss_lair_migration_is_idempotent")
	snake_nests = migrated_lairs.duplicate(true)
	_register_snake_nest(current_lair_descriptor)
	_test_assert(snake_nests.size() == 1 and bool(snake_nests[canonical_lair_id].get("cleared", false)), "chunk_activation_cannot_duplicate_migrated_python_boss_lair")
	snake_nests.clear()
	world_generator = original_world_generator
	var generated_positions_clear := true
	for check_coord in [Vector2i(1, 1), Vector2i(2, 0), Vector2i(-2, 3), Vector2i(4, -1)]:
		if not _chunk_generated_positions_are_clear(wg.generate_chunk(check_coord)):
			generated_positions_clear = false
			break
	_test_assert(generated_positions_clear, "generated_positions_avoid_obstacles")
	_test_assert(GameConfig.HERO_CLASSES.size() == 3 and GameConfig.SOLDIERS.size() == 16 and GameConfig.ENEMIES.size() == 16 and GameConfig.CHAOS_UNLOCK_SOLDIER_ORDER.size() == 4, "expanded_content_counts")
	_test_assert(GameConfig.CASTLE_TIERS.size() == 6 and GameConfig.SOLDIER_ORDER.size() == 12, "castle_tier_and_recruit_rosters")
	_test_assert(str(GameConfig.SOLDIERS["cannon"]["name"]) == "重型大砲" and str(GameConfig.ENEMIES["cannon"]["name"]) == "普通大砲", "player_and_enemy_cannon_names_are_distinct")
	_test_assert(float(GameConfig.SOLDIERS["cannon"]["combat"]["attack"]) > float(GameConfig.ENEMIES["cannon"]["combat"]["attack"]), "purchasable_heavy_cannon_outdamages_ordinary_cannon")
	var legacy_cannon := {"type": "cannon", "attack": 72.0}
	player["level"] = 1
	_normalize_loaded_soldier(legacy_cannon)
	_test_assert(is_equal_approx(float(legacy_cannon["attack"]), 112.0), "legacy_cannon_save_migrates_to_heavy_cannon_damage")
	var charge_showcase_ok := _web_force_heavy_cannon_combat_showcase_for_test(["charge", false, "zh_TW"])
	_test_assert(charge_showcase_ok and soldiers.size() == 1 and enemies.size() == 1 and str(soldiers[0]["type"]) == "cannon" and str(enemies[0]["type"]) == "cannon" and str(soldiers[0]["state"]) == "charge" and float(soldiers[0]["charge"]) > 0.0 and projectiles.is_empty(), "heavy_cannon_showcase_has_isolated_charge_phase")
	_web_advance_time([16.6667])
	_test_assert(str(soldiers[0]["state"]) == "charge" and float(soldiers[0]["charge"]) > 0.0 and _web_manual_time_hold > 4.0, "showcase_manual_step_preserves_phase_hold")
	var shell_showcase_ok := _web_force_heavy_cannon_combat_showcase_for_test(["shell", false, "zh_TW"])
	_test_assert(shell_showcase_ok and projectiles.size() == 1 and str(projectiles[0]["kind"]) == "cannonball" and str(projectiles[0]["source_kind"]) == "cannon" and is_equal_approx(float(enemies[0]["hp"]), float(enemies[0]["max_hp"])), "heavy_cannon_showcase_shell_precedes_damage")
	var impact_showcase_ok := _web_force_heavy_cannon_combat_showcase_for_test(["impact", false, "zh_TW"])
	_test_assert(impact_showcase_ok and projectiles.is_empty() and is_equal_approx(float(enemies[0]["max_hp"]) - float(enemies[0]["hp"]), 112.0), "heavy_cannon_showcase_impact_damages_standard_cannon")
	var showcase_explosion_visible := false
	for impact_particle in particles:
		if bool(impact_particle.get("effect", false)) and str(impact_particle.get("kind", "")) == "explosion" and float(impact_particle.get("ttl", 0.0)) > 0.0 and float(impact_particle.get("ttl", 0.0)) < float(impact_particle.get("max_ttl", 0.0)):
			showcase_explosion_visible = true
			break
	_test_assert(showcase_explosion_visible, "heavy_cannon_impact_showcase_freezes_visible_explosion")
	_update_active_chunks(false)
	_test_assert(enemies.size() == 1 and not active_chunks.is_empty() and chunk_states.is_empty() and pending_chunk_spawns.is_empty(), "heavy_cannon_showcase_streaming_remains_isolated")
	_test_assert(_web_test_showcase_active and not _can_persist_to_path(GameSaveManager.SAVE_PATH), "web_showcase_cannot_overwrite_default_save")
	input_scheme = InputScheme.TOUCH
	touch_move_pointer = 7
	touch_move_vector = Vector2.RIGHT
	attack_held = true
	var touch_showcase_ok := _web_force_heavy_cannon_combat_showcase_for_test(["impact", true, "en"])
	_test_assert(touch_showcase_ok and language == "en" and input_scheme == InputScheme.TOUCH and touch_move_pointer == -1 and touch_move_vector.is_zero_approx() and not attack_held and camera_shake_offset.is_zero_approx(), "heavy_cannon_touch_showcase_resets_transient_input")
	_start_new_game("warrior")
	_test_assert(not _web_test_showcase_active and is_zero_approx(_web_manual_time_hold), "normal_game_clears_web_showcase_guards")
	_test_assert(int(GameConfig.SPECIAL_ATTACKS["archer"]["projectile_count"]) == 7, "scatter_has_seven_arrows")
	_test_assert(GameConfig.STAT_UPGRADES.has("attack_speed"), "attack_speed_upgrade")
	_test_assert(_calculate_damage(1.0, 9999.0) >= 1.0, "minimum_damage")
	_test_assert(_world_difficulty(HOUSE_POS + Vector2(7200, 0)) > _world_difficulty(HOUSE_POS), "distance_increases_difficulty")
	var prediction_test := _predict_intercept_position(Vector2.ZERO, Vector2(100, 0), Vector2(900, 0), 200.0, 0.1, 0.8, 180.0)
	_test_assert(is_equal_approx(prediction_test.x, 244.0) and is_zero_approx(prediction_test.y), "prediction_leads_motion_with_speed_and_distance_caps")
	player["pos"] = HOUSE_POS + Vector2(2200, 0)
	player["vel"] = Vector2(180, 0)
	enemies.clear()
	soldiers.clear()
	var predicting_enemy_id := _spawn_enemy("archer", Vector2(player["pos"]) - Vector2(260, 0), 5, Vector2(player["pos"]) - Vector2(260, 0))
	var predicting_enemy: Variant = _find_enemy_by_id(predicting_enemy_id)
	if predicting_enemy != null:
		predicting_enemy["cooldown"] = 0.0
		_update_single_enemy(predicting_enemy, 0.08)
	_test_assert(predicting_enemy != null and str(predicting_enemy["state"]) == "telegraph" and Vector2(predicting_enemy["pending_pos"]).x > Vector2(player["pos"]).x, "enemy_telegraph_locks_predicted_player_path")
	var follower_id := _spawn_soldier("archer", Vector2(player["pos"]) - Vector2(120, 0))
	var follower: Variant = _find_soldier_by_id(follower_id)
	var formation_without_lead := Vector2(player["pos"]) + _local_formation_offset(follower)
	_test_assert(follower != null and _formation_position(follower).x > formation_without_lead.x, "recruited_soldiers_predict_player_formation_path")
	projectiles.clear()
	enemies.clear()
	var moving_target_id := _spawn_enemy("grunt", Vector2(follower["pos"]) + Vector2(300, 0), 4, Vector2(follower["pos"]) + Vector2(300, 0))
	var moving_target: Variant = _find_enemy_by_id(moving_target_id)
	if moving_target != null:
		moving_target["vel"] = Vector2(0, 200)
	_fire_soldier_attack(follower, moving_target_id)
	var soldier_lead_projectile_ok := not projectiles.is_empty() and Vector2(projectiles.back().get("vel", Vector2.ZERO)).y > 0.0
	_test_assert(soldier_lead_projectile_ok, "recruited_ranged_soldiers_lead_moving_targets")
	var stale_enemy_velocity := {"vel": Vector2(900, 400)}
	var stale_soldier_velocity := {"vel": Vector2(-800, 300), "aim_dir": Vector2.RIGHT, "structure_target": "", "type": "swordsman"}
	_normalize_loaded_enemy(stale_enemy_velocity)
	_normalize_loaded_soldier(stale_soldier_velocity)
	_test_assert(Vector2(stale_enemy_velocity["vel"]).is_zero_approx() and Vector2(stale_soldier_velocity["vel"]).is_zero_approx(), "loaded_units_clear_stale_prediction_velocity")
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	var terrain_rule_result := _self_test_terrain_rules()
	_test_assert(bool(terrain_rule_result["tree_blocks"]) and bool(terrain_rule_result["scenery_passable"]), "rocks_and_bushes_are_passable_while_trees_block")
	_test_assert(bool(terrain_rule_result["soldier_escaped_tree"]), "soldier_automatically_escapes_and_avoids_tree")
	_test_assert(_self_test_enemy_motion_smoothing(), "enemy_motion_advances_smoothly_every_frame")

	var boss_skills: Dictionary = GameConfig.PYTHON_BOSS_CONFIG["skills"]
	var expected_boss_skill_names := ["絞蟒纏縛", "蛇影裂地衝", "腐牙噬咬", "腐沼毒潭", "裂骨巨尾"]
	var actual_boss_skill_names: Array[String] = []
	for boss_skill_id in ["constrict", "dash", "bite", "poison_pool", "tail_sweep"]:
		actual_boss_skill_names.append(str(boss_skills[boss_skill_id]["name"]))
	_test_assert(boss_skills.size() == 5 and actual_boss_skill_names == expected_boss_skill_names, "python_boss_exactly_five_skills")
	_test_assert(PythonBossControllerScript.STATE_NAMES.size() == 11, "python_boss_has_eleven_fsm_states")
	var scaled_boss: Variant = PythonBossControllerScript.new()
	scaled_boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 2, 12, 90210)
	var scaled_state: Dictionary = scaled_boss.get_text_state()
	_test_assert(is_equal_approx(float(scaled_state["max_hp"]), 12672.0) and is_equal_approx(float(scaled_state["damage"]), 115.4), "python_boss_scaling_formula_and_caps")
	var far_tier_boss: Variant = PythonBossControllerScript.new()
	far_tier_boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 99, 12, 90211)
	_test_assert(int(far_tier_boss.serialize()["world_tier"]) == int(GameConfig.PYTHON_BOSS_CONFIG["scaling"]["max_world_tier"]), "far_python_boss_lair_serializes_capped_world_tier")
	var boss_movement_result := _self_test_python_boss_home_movement()
	_test_assert(bool(boss_movement_result["home_clear"]), "python_boss_home_is_clear_of_blocking_trees")
	_test_assert(bool(boss_movement_result["moved"]), "python_boss_moves_after_engaging_player")
	var lair_lifecycle_result := _self_test_python_boss_lair_lifecycle()
	_test_assert(bool(lair_lifecycle_result["same_saga"]), "procedural_lair_spawns_exact_corrupt_python_emperor_saga")
	_test_assert(bool(lair_lifecycle_result["same_controller"]), "python_boss_lairs_reuse_one_controller")
	_test_assert(bool(lair_lifecycle_result["idle_handoff"]), "nearer_lair_hysteresis_does_not_block_saga_spawn")
	_test_assert(bool(lair_lifecycle_result["engaged_lock"]), "engaged_saga_cannot_be_stolen_by_another_lair")
	_test_assert(bool(lair_lifecycle_result["clear_and_next"]), "defeated_lair_clears_and_next_lair_can_spawn_saga")
	_test_assert(bool(lair_lifecycle_result["text_contract"]), "render_state_identifies_active_saga_lair")
	_test_assert(bool(lair_lifecycle_result["main_marker_persists"]), "main_saga_lair_marker_persists_during_satellite_encounter")
	mode = GameMode.PLAYING
	player["pos"] = HOUSE_POS + Vector2(2600, 0)
	player["hp"] = player["max_hp"]
	player["invuln"] = 0.0
	player["hit_grace"] = 0.0
	var ordinary_hit_hp_before := float(player["hp"])
	var ordinary_first_hit := _damage_player(10.0, player["pos"] - Vector2(40, 0), false)
	var ordinary_hp_after_first := float(player["hp"])
	var ordinary_second_hit := _damage_player(10.0, player["pos"] - Vector2(40, 0), false)
	_test_assert(ordinary_first_hit and not ordinary_second_hit and ordinary_hp_after_first < ordinary_hit_hp_before and is_equal_approx(float(player["hp"]), ordinary_hp_after_first) and is_zero_approx(float(player["invuln"])) and float(player["hit_grace"]) > 0.0, "player_hit_grace_blocks_only_repeated_ordinary_impacts")
	player["hp"] = player["max_hp"]
	player["hit_grace"] = 0.0
	var boss_combo_hp_before := float(player["hp"])
	_apply_python_boss_event({"type": "damage", "target": "player:0", "amount": 10.0, "kind": "pool_tick_1", "source_pos": player["pos"] - Vector2(40, 0)})
	_apply_python_boss_event({"type": "damage", "target": "player:0", "amount": 40.0, "kind": "dash", "source_pos": player["pos"] - Vector2(40, 0)})
	_test_assert(boss_combo_hp_before - float(player["hp"]) >= 35.0, "python_boss_distinct_same_frame_hits_are_not_swallowed_by_hit_grace")
	player["hp"] = player["max_hp"]
	player["invuln"] = 0.26
	player["hit_grace"] = 0.0
	var dash_invulnerability_hp := float(player["hp"])
	_apply_python_boss_event({"type": "damage", "target": "player:0", "amount": 40.0, "kind": "dash", "source_pos": player["pos"] - Vector2(40, 0)})
	_test_assert(is_equal_approx(float(player["hp"]), dash_invulnerability_hp), "python_boss_damage_respects_dash_and_respawn_invulnerability")
	player["invuln"] = 0.05
	_apply_python_boss_event({"type": "damage", "target": "player:0", "amount": 40.0, "kind": "dash", "source_pos": player["pos"] - Vector2(40, 0)})
	_test_assert(is_equal_approx(float(player["hp"]), dash_invulnerability_hp), "python_boss_respects_final_milliseconds_of_full_invulnerability")
	player["invuln"] = 0.20
	player["hit_grace"] = 0.14
	_update_player(0.05)
	_test_assert(is_equal_approx(float(player["invuln"]), 0.15) and is_equal_approx(float(player["hit_grace"]), 0.09), "player_invulnerability_and_hit_grace_tick_independently")
	player["invuln"] = 0.0
	player["hit_grace"] = 0.0
	_apply_python_boss_event({"type": "damage", "target": "player:0", "amount": 99999.0, "kind": "tail_sweep", "source_pos": player["pos"] - Vector2(40, 0)})
	_test_assert(bool(player["alive"]) and float(player["hp"]) > 0.0, "python_boss_single_telegraphed_hit_cannot_one_shot_full_health_player")
	player["hp"] = player["max_hp"]
	player["invuln"] = 0.0
	player["hit_grace"] = 0.0
	_test_assert(int(scaled_state["segments"]) == 18 and scaled_boss.body_snapshot().size() == 18, "python_boss_segmented_body_count")
	var technology_threat_boss: Variant = PythonBossControllerScript.new()
	technology_threat_boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 424242)
	var technology_threat_home: Vector2 = GameConfig.PYTHON_BOSS_CONFIG["home_position"]
	technology_threat_boss.add_threat("musketeer", 42, 1000.0)
	technology_threat_boss.update(FIXED_STEP, {"units": [{"kind": "soldier", "id": 42, "type": "musketeer", "pos": technology_threat_home + Vector2(120, 0), "vel": Vector2.ZERO, "radius": 11.0, "alive": true, "safe": false}]})
	_test_assert(str(technology_threat_boss.get_text_state()["target"]) == "soldier:42", "new_technology_units_map_to_valid_boss_threat_targets")

	var hit_boss: Variant = PythonBossControllerScript.new()
	hit_boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 4242)
	var hit_segments: Array = hit_boss.body_snapshot()
	var head_hit: Dictionary = hit_boss.receive_hit("part_head", "player", 0, 100.0, Vector2(hit_segments[0]["pos"]), "test", 0.0)
	var duplicate_hit: Dictionary = hit_boss.receive_hit("part_head", "player", 0, 100.0, Vector2(hit_segments[0]["pos"]), "test", 0.0)
	var body_hit: Dictionary = hit_boss.receive_hit("part_body", "player", 0, 100.0, Vector2(hit_segments[8]["pos"]), "test", 0.0)
	var tail_hit: Dictionary = hit_boss.receive_hit("part_tail", "player", 0, 100.0, Vector2(hit_segments[-1]["pos"]), "test", 0.0)
	_test_assert(bool(head_hit["accepted"]) and not bool(duplicate_hit["accepted"]), "python_boss_attack_id_deduplicates")
	_test_assert(float(head_hit["damage"]) > float(body_hit["damage"]) and float(body_hit["damage"]) > float(tail_hit["damage"]), "python_boss_head_body_tail_multipliers")
	var boss_home: Vector2 = GameConfig.PYTHON_BOSS_CONFIG["home_position"]
	var swept_boss_hit: Dictionary = hit_boss.projectile_intersection(boss_home + Vector2(120, 0), boss_home - Vector2(120, 0), 4.0)
	_test_assert(bool(swept_boss_hit["hit"]), "python_boss_swept_projectile_collision")
	var collision_segment: Dictionary = Dictionary(hit_segments[7])
	var embedded_point: Vector2 = Vector2(collision_segment["pos"])
	var resolved_point: Vector2 = hit_boss.resolve_body_collision(embedded_point, 14.0)
	_test_assert(resolved_point.distance_to(embedded_point) > 1.0, "python_boss_body_blocks_units")

	var phase_boss: Variant = PythonBossControllerScript.new()
	phase_boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 31337)
	phase_boss.debug_set_hp_ratio(0.69)
	phase_boss.update(FIXED_STEP, {"units": [], "safe_zones": []})
	_test_assert(int(phase_boss.get_text_state()["phase"]) == 2 and str(phase_boss.get_text_state()["state"]) == "PHASE_CHANGE", "python_boss_phase_threshold")
	var all_boss_skills_telegraph := true
	for boss_skill_id in ["constrict", "dash", "bite", "poison_pool", "tail_sweep"]:
		if not _boss_test_forced_skill(str(boss_skill_id)):
			all_boss_skills_telegraph = false
			break
	_test_assert(all_boss_skills_telegraph, "python_boss_all_five_skills_reachable")
	var all_boss_skills_damage := true
	for damaging_boss_skill_id in ["constrict", "dash", "bite", "poison_pool", "tail_sweep"]:
		if not _boss_test_forced_skill_damage(str(damaging_boss_skill_id)):
			all_boss_skills_damage = false
			break
	_test_assert(all_boss_skills_damage, "python_boss_all_five_skills_deal_damage")
	var chaos_skill_result := _self_test_chaos_boss_skills()
	_test_assert(bool(chaos_skill_result.get("exact_ten", false)), "chaos_boss_has_exactly_ten_named_skills")
	_test_assert(bool(chaos_skill_result.get("all_selected", false)), "chaos_boss_all_ten_skills_are_reachable")
	_test_assert(bool(chaos_skill_result.get("all_harmful", false)), "chaos_boss_all_ten_skills_have_harmful_payloads")
	_test_assert(bool(chaos_skill_result.get("missiles_expire", false)), "chaos_homing_missiles_expire_between_four_and_six_seconds")
	_test_assert(bool(chaos_skill_result.get("moves", false)) and bool(chaos_skill_result.get("phase_three", false)), "chaos_boss_moves_and_reaches_hard_phase_three")
	_test_assert(bool(chaos_skill_result.get("death_once", false)), "chaos_boss_defeat_emits_single_completion_reward")
	var aionis_result := _self_test_aionis_boss()
	_test_assert(bool(aionis_result.get("exact_ten", false)), "aionis_boss_has_exactly_ten_named_skills")
	_test_assert(bool(aionis_result.get("all_selected", false)), "aionis_boss_all_ten_skills_are_reachable")
	_test_assert(bool(aionis_result.get("all_harmful", false)), "aionis_boss_all_ten_skills_have_harmful_payloads")
	_test_assert(bool(aionis_result.get("star_gate_converges", false)), "aionis_star_gate_projectiles_cross_the_locked_target")
	_test_assert(bool(aionis_result.get("four_phases", false)), "aionis_boss_reaches_exactly_four_phases")
	_test_assert(bool(aionis_result.get("anchor_gate", false)), "aionis_four_anchors_are_all_required_for_exposure")
	_test_assert(bool(aionis_result.get("anchor_reduction", false)), "aionis_anchor_protection_and_five_second_exposure_are_effective")
	_test_assert(bool(aionis_result.get("anchor_refresh", false)), "aionis_time_anchors_refresh_each_phase")
	_test_assert(bool(aionis_result.get("combo_two", false)), "aionis_phase_three_executes_two_skills_in_one_cycle")
	_test_assert(bool(aionis_result.get("combo_three", false)), "aionis_phase_four_executes_three_skills_in_one_cycle")
	_test_assert(bool(aionis_result.get("save_restore", false)), "aionis_save_restore_returns_to_safe_idle_state")
	_test_assert(bool(aionis_result.get("moves", false)), "aionis_boss_moves_after_engaging_player")
	_test_assert(bool(aionis_result.get("death_once", false)), "aionis_boss_defeat_reward_is_emitted_once")
	_test_assert(bool(aionis_result.get("victory_cleanup", false)), "aionis_victory_clears_all_hostile_runtime_payloads")
	var poison_ticks_small_step := _boss_test_poison_tick_count(FIXED_STEP)
	var poison_ticks_large_step := _boss_test_poison_tick_count(0.10)
	_test_assert(poison_ticks_small_step >= 6 and poison_ticks_small_step == poison_ticks_large_step, "python_boss_poison_is_frame_rate_independent")
	var reward_boss: Variant = PythonBossControllerScript.new()
	reward_boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 999)
	var death_result: Dictionary = reward_boss.receive_hit("lethal", "player", 0, 999999.0, boss_home, "test", 0.0)
	var reward_events := 0
	for death_event_value in Array(death_result.get("events", [])):
		if death_event_value is Dictionary and str(death_event_value.get("type", "")) == "reward":
			reward_events += 1
	var repeated_death: Dictionary = reward_boss.receive_hit("lethal_again", "player", 0, 999999.0, boss_home, "test", 0.0)
	for death_event_value in Array(repeated_death.get("events", [])):
		if death_event_value is Dictionary and str(death_event_value.get("type", "")) == "reward":
			reward_events += 1
	var reward_save: Dictionary = reward_boss.serialize()
	var restored_reward_boss: Variant = PythonBossControllerScript.new()
	restored_reward_boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 999)
	restored_reward_boss.restore(reward_save)
	_test_assert(reward_events == 1 and restored_reward_boss.is_defeated() and bool(restored_reward_boss.get_text_state()["reward_claimed"]), "python_boss_death_reward_once_and_persists")

	_start_new_game("archer")
	player["pos"] = boss_home + Vector2(420, 0)
	enemies.clear()
	projectiles.clear()
	_initialize_python_boss(true)
	python_boss.force_engage()
	var screen_enemy_id := _spawn_enemy("grunt", boss_home + Vector2(105, 0), 1, boss_home + Vector2(105, 0))
	var boss_hp_before_ordering := float(python_boss.get_text_state()["hp"])
	_spawn_projectile({
		"team": "friendly", "kind": "arrow", "pos": boss_home + Vector2(220, 0), "vel": Vector2(-900, 0),
		"damage": 80.0, "range": 500.0, "radius": 5.0, "pierce": 1, "aoe": 0.0, "color": Color.WHITE,
	})
	_update_projectiles(0.25)
	var screen_enemy: Variant = _find_enemy_by_id(screen_enemy_id)
	var screen_enemy_was_hit := screen_enemy == null or float(screen_enemy["hp"]) < float(screen_enemy["max_hp"])
	_test_assert(screen_enemy_was_hit and is_equal_approx(float(python_boss.get_text_state()["hp"]), boss_hp_before_ordering), "projectile_hits_nearest_enemy_before_boss")
	enemies.clear()
	projectiles.clear()
	var boss_hp_before_cannon := float(python_boss.get_text_state()["hp"])
	_spawn_projectile({
		"team": "friendly", "kind": "cannonball", "source_kind": "cannon", "source_id": 77,
		"pos": boss_home + Vector2(240, 0), "vel": Vector2(-900, 0), "damage": 220.0,
		"range": 600.0, "radius": 12.0, "pierce": 1, "aoe": 132.0, "color": Color("40484E"),
	})
	_update_projectiles(0.30)
	var cannon_damage_to_boss := boss_hp_before_cannon - float(python_boss.get_text_state()["hp"])
	_test_assert(cannon_damage_to_boss > 0.0 and cannon_damage_to_boss <= 220.0, "cannon_aoe_hits_segmented_boss_once")

	_start_new_game("archer")
	player["pos"] = HOUSE_POS + Vector2(0, 360)
	camera_pos = player["pos"]
	enemies.clear()
	projectiles.clear()
	var enemy_id := _spawn_enemy("grunt", player["pos"] + Vector2(180, 0), 1, player["pos"] + Vector2(180, 0))
	var enemy_before := float(_find_enemy_by_id(enemy_id)["hp"])
	_try_player_attack(player["pos"] + Vector2(300, 0))
	for _i in 45: _update_projectiles(FIXED_STEP)
	var enemy_after_obj: Variant = _find_enemy_by_id(enemy_id)
	var enemy_after: float = 0.0 if enemy_after_obj == null else float(enemy_after_obj["hp"])
	_test_assert(enemy_after < enemy_before, "archer_projectile_damage")

	projectiles.clear()
	player["level"] = 9
	player["special_cd"] = 0.0
	_try_player_special(player["pos"] + Vector2(300, 0))
	_test_assert(projectiles.is_empty(), "special_locked_before_level_10")
	player["level"] = 10
	player["special_cd"] = 0.0
	_try_player_special(player["pos"] + Vector2(300, 0))
	_test_assert(projectiles.size() == 7, "special_unlocks_at_level_10")

	projectiles.clear()
	enemies.clear()
	var swept_enemy_id := _spawn_enemy("heavy", player["pos"] + Vector2(55, 0), 1, player["pos"] + Vector2(55, 0))
	var swept_hp_before := float(_find_enemy_by_id(swept_enemy_id)["hp"])
	_spawn_projectile({
		"team": "friendly", "kind": "scatter_arrow", "pos": player["pos"], "vel": Vector2(940, 0),
		"damage": 20.0, "range": 400.0, "radius": 4.0, "pierce": 1, "aoe": 0.0, "color": Color.WHITE,
		"slow_factor": 0.3, "slow_duration": 2.0,
	})
	_update_projectiles(0.10)
	var swept_enemy: Variant = _find_enemy_by_id(swept_enemy_id)
	_test_assert(swept_enemy != null and float(swept_enemy["hp"]) < swept_hp_before, "swept_projectile_collision")
	_test_assert(swept_enemy != null and float(swept_enemy["slow"]) > 0.0, "scatter_applies_slow")

	_start_new_game("warrior")
	player["pos"] = HOUSE_POS + Vector2(360, 0)
	var attack_before_growth := float(player["attack"])
	var hp_before_growth := float(player["max_hp"])
	_gain_xp(int(player["xp_need"]))
	_test_assert(float(player["attack"]) > attack_before_growth and float(player["max_hp"]) > hp_before_growth, "class_growth_applies_on_level")
	enemies.clear()
	var melee_enemy_id := _spawn_enemy("heavy", player["pos"] + Vector2(70, 0), 1, player["pos"] + Vector2(70, 0))
	var melee_enemy_pos := Vector2(_find_enemy_by_id(melee_enemy_id)["pos"])
	_try_player_attack(player["pos"] + Vector2(200, 0))
	var melee_enemy: Variant = _find_enemy_by_id(melee_enemy_id)
	_test_assert(melee_enemy != null and Vector2(melee_enemy["pos"]).x > melee_enemy_pos.x, "warrior_heavy_slash_knockback")
	player["level"] = 10
	player["special_cd"] = 0.0
	_try_player_special(player["pos"] + Vector2(200, 0))
	_damage_enemies_along_dash(Vector2(melee_enemy["pos"]))
	_test_assert(float(melee_enemy.get("armor_break", 0.0)) > 0.0, "warrior_dash_applies_armor_break")
	camps.clear()
	_register_camp({"id": "melee_crate", "position": player["pos"] + Vector2(82, 0), "level": 1})
	enemies.clear()
	var melee_camp: Dictionary = camps["melee_crate"]
	var melee_crate_hp := float(melee_camp["crate_hp"])
	_player_melee_attack(112.0, deg_to_rad(112.0), 25.0, false, 18.0)
	_test_assert(float(melee_camp["crate_hp"]) < melee_crate_hp, "warrior_melee_damages_supply_crate")
	camps.clear()

	player["pos"] = HOUSE_POS + Vector2(0, 100)
	player["hp"] = player["max_hp"]
	player["invuln"] = 0.0
	var safe_hp_before := float(player["hp"])
	_damage_player(999.0, HOUSE_POS + Vector2(300, 0))
	_test_assert(is_equal_approx(float(player["hp"]), safe_hp_before), "house_safe_zone_blocks_damage")
	soldiers.clear()
	_spawn_soldier("swordsman", HOUSE_POS + Vector2(0, 110))
	var safe_soldier: Dictionary = soldiers[0]
	var safe_soldier_hp := float(safe_soldier["hp"])
	_damage_soldier(safe_soldier, 999.0, HOUSE_POS + Vector2(300, 0), "projectile")
	_test_assert(is_equal_approx(float(safe_soldier["hp"]), safe_soldier_hp), "house_safe_zone_protects_soldiers")

	_start_new_game("archer")
	player["pos"] = HOUSE_POS + Vector2(0, 120)
	soldiers.clear()
	player["money"] = 10000
	recruit_anchor = HOUSE_POS
	for type_id in GameConfig.SOLDIER_ORDER:
		_recruit_soldier(type_id, 1)
	_test_assert(soldiers.size() == 12 and _count_soldier_type("cannon") == 1, "recruit_all_twelve_soldiers_including_heavy_cannon")
	var heavy_cannon_count_before_purchase := _count_soldier_type("cannon")
	var heavy_cannon_money_before_purchase := int(player["money"])
	var heavy_cannon_bought := _recruit_soldier("cannon", 1)
	_test_assert(heavy_cannon_bought == 1 and heavy_cannon_money_before_purchase - int(player["money"]) == 520 and _count_soldier_type("cannon") == heavy_cannon_count_before_purchase + 1, "heavy_cannon_purchase_costs_exactly_520")
	if not soldiers.is_empty() and str(soldiers.back()["type"]) == "cannon": soldiers.pop_back()
	var recruit_panel := _recruit_panel_rect()
	var last_recruit_button := _recruit_buy_rect(GameConfig.SOLDIER_ORDER.size() - 1, recruit_panel)
	_test_assert(recruit_panel.encloses(last_recruit_button) and last_recruit_button.position.x > recruit_panel.get_center().x, "two_column_recruit_panel_contains_last_technology_unit")
	var desktop_screen_size := screen_size
	input_scheme = InputScheme.TOUCH
	screen_size = Vector2(844, 390)
	var mobile_recruit_panel := _recruit_panel_rect()
	var mobile_recruit_layout_ok := true
	for mobile_recruit_index in GameConfig.SOLDIER_ORDER.size():
		var mobile_item := _recruit_item_rect(mobile_recruit_index, mobile_recruit_panel)
		var mobile_buy_hit := _recruit_buy_rect(mobile_recruit_index, mobile_recruit_panel).grow(5.0)
		if not mobile_recruit_panel.encloses(mobile_item) or not mobile_recruit_panel.encloses(_recruit_buy_rect(mobile_recruit_index, mobile_recruit_panel)) or mobile_buy_hit.size.y < 44.0:
			mobile_recruit_layout_ok = false
			break
	_test_assert(mobile_recruit_layout_ok, "mobile_landscape_all_twelve_recruit_rows_fit_with_touch_targets")
	screen_size = desktop_screen_size
	active_panel = "recruit"
	var rockets_before_touch_buy := _count_soldier_type("rocket")
	recruit_panel = _recruit_panel_rect()
	last_recruit_button = _recruit_buy_rect(GameConfig.SOLDIER_ORDER.size() - 1, recruit_panel)
	_handle_ui_click(last_recruit_button.get_center())
	_test_assert(_count_soldier_type("rocket") == rockets_before_touch_buy + 1, "touch_recruit_button_buys_rocket_launcher")
	if not soldiers.is_empty() and str(soldiers.back()["type"]) == "rocket": soldiers.pop_back()
	var cannon_button_index := GameConfig.SOLDIER_ORDER.find("cannon")
	var cannon_touch_button := _recruit_buy_rect(cannon_button_index, recruit_panel)
	var cannons_before_duplicate_touch := _count_soldier_type("cannon")
	var money_before_duplicate_touch := int(player["money"])
	last_recruit_purchase_msec = -10000
	last_recruit_purchase_type = ""
	_handle_ui_click(cannon_touch_button.get_center())
	_handle_ui_click(cannon_touch_button.get_center())
	_test_assert(_count_soldier_type("cannon") == cannons_before_duplicate_touch + 1 and money_before_duplicate_touch - int(player["money"]) == 520, "web_touch_compatibility_click_cannot_double_buy_heavy_cannon")
	if not soldiers.is_empty() and str(soldiers.back()["type"]) == "cannon": soldiers.pop_back()
	input_scheme = InputScheme.KEYBOARD_MOUSE
	active_panel = ""

	var friendly_weapon_kinds := {"musketeer": "musket_ball", "rifleman": "rifle_round", "tank": "tank_shell", "rocket": "rocket", "cannon": "cannonball"}
	var friendly_weapon_tests_ok := true
	enemies.clear()
	var friendly_weapon_target_id := _spawn_enemy("heavy", player["pos"] + Vector2(260, 0), 8, player["pos"] + Vector2(260, 0))
	for weapon_type in friendly_weapon_kinds:
		var weapon_soldier: Variant = null
		for recruit in soldiers:
			if str(recruit["type"]) == str(weapon_type):
				weapon_soldier = recruit
				break
		projectiles.clear()
		if weapon_soldier == null:
			friendly_weapon_tests_ok = false
			break
		_fire_soldier_attack(weapon_soldier, friendly_weapon_target_id)
		if projectiles.is_empty() or str(projectiles.back()["kind"]) != str(friendly_weapon_kinds[weapon_type]):
			friendly_weapon_tests_ok = false
			break
	_test_assert(friendly_weapon_tests_ok, "all_five_purchasable_technology_weapons_fire_distinct_projectiles")
	_test_assert(_soldier_charge_seconds("cannon") > _soldier_charge_seconds("tank") and _soldier_charge_seconds("rocket") > 0.0, "heavy_weapons_use_visible_charge_timing")
	var rifle_recruit: Variant = null
	var musket_recruit: Variant = null
	var heavy_cannon_recruit: Variant = null
	for recruit in soldiers:
		if str(recruit["type"]) == "rifleman": rifle_recruit = recruit
		elif str(recruit["type"]) == "musketeer": musket_recruit = recruit
		elif str(recruit["type"]) == "cannon": heavy_cannon_recruit = recruit
	_test_assert(rifle_recruit != null and musket_recruit != null and _soldier_attack_cooldown(rifle_recruit) < _soldier_attack_cooldown(musket_recruit), "rifleman_runtime_fire_rate_is_faster_than_musketeer")
	projectiles.clear()
	enemies.clear()
	var charge_completion_target_id := _spawn_enemy("heavy", player["pos"] + Vector2(240, 0), 8, player["pos"] + Vector2(240, 0))
	if heavy_cannon_recruit != null:
		heavy_cannon_recruit["target_id"] = charge_completion_target_id
		heavy_cannon_recruit["charge"] = 0.01
		heavy_cannon_recruit["state"] = "charge"
		_update_single_soldier(heavy_cannon_recruit, 0.02)
	_test_assert(heavy_cannon_recruit != null and is_zero_approx(float(heavy_cannon_recruit["charge"])) and str(heavy_cannon_recruit["state"]) == "attack" and not projectiles.is_empty(), "heavy_weapon_charge_finishes_in_attack_state")
	projectiles.clear()
	enemies.clear()
	castles.clear()
	_register_castle({"id": "friendly_siege_projectile_castle", "position": player["pos"] + Vector2(520, 0), "level": 20})
	var friendly_siege_castle: Dictionary = castles["friendly_siege_projectile_castle"]
	var friendly_siege_hp_before := float(friendly_siege_castle["hp"])
	if heavy_cannon_recruit != null:
		_attack_castle_with_soldier(heavy_cannon_recruit, friendly_siege_castle)
	var siege_projectile_spawned := not projectiles.is_empty() and str(projectiles.back()["kind"]) == "cannonball" and is_equal_approx(float(friendly_siege_castle["hp"]), friendly_siege_hp_before)
	for _siege_projectile_step in 150:
		_update_projectiles(FIXED_STEP)
		if projectiles.is_empty(): break
	_test_assert(siege_projectile_spawned and float(friendly_siege_castle["hp"]) < friendly_siege_hp_before, "heavy_cannon_siege_uses_visible_projectile_before_damage")
	projectiles.clear()
	castles.clear()
	var recruits_outside_structures := true
	for recruit in soldiers:
		if _position_hits_obstacle(recruit["pos"], float(recruit["radius"])):
			recruits_outside_structures = false
			break
	_test_assert(recruits_outside_structures, "recruits_spawn_outside_structures")
	var recruit_count_before_remote := soldiers.size()
	player["pos"] = HOUSE_POS + Vector2(900, 0)
	recruit_anchor = HOUSE_POS
	_test_assert(_recruit_soldier("swordsman", 1) == 0 and soldiers.size() == recruit_count_before_remote, "recruitment_revalidates_distance")
	player["pos"] = HOUSE_POS + Vector2(360, 0)
	castles.clear()
	enemies.clear()
	_register_castle({"id": "cap_owned_20", "position": player["pos"] + Vector2(620, 0), "level": 20})
	castles["cap_owned_20"]["owned"] = true
	_register_castle({"id": "cap_owned_35", "position": player["pos"] + Vector2(1200, 0), "level": 35})
	castles["cap_owned_35"]["owned"] = true
	_register_castle({"id": "cap_hostile_50", "position": player["pos"] + Vector2(1900, 0), "level": 50})
	enemies.clear()
	_test_assert(_owned_castle_level_total() == 55 and _army_limit() == 77, "army_limit_is_fifty_plus_half_all_owned_castle_levels")
	castles["cap_owned_35"]["owned"] = false
	_test_assert(_army_limit() == 60, "army_limit_updates_when_a_city_is_lost")
	castles["cap_owned_35"]["owned"] = true
	while soldiers.size() < 77:
		_spawn_soldier("swordsman", player["pos"] + Vector2(400.0 + float(soldiers.size()) * 3.0, 0.0))
	var unique_garrison_slots: Dictionary = {}
	for formation_soldier in soldiers:
		var formation_position := _garrison_formation_position(formation_soldier, castles["cap_owned_20"])
		unique_garrison_slots["%.3f,%.3f" % [formation_position.x, formation_position.y]] = true
	_test_assert(unique_garrison_slots.size() == soldiers.size(), "garrison_slots_remain_unique_above_fifty_units")
	var stable_siege_soldier: Dictionary = soldiers[0]
	var stable_siege_original_position := Vector2(stable_siege_soldier["pos"])
	var stable_siege_slot_before := _siege_formation_position(stable_siege_soldier, castles["cap_hostile_50"])
	stable_siege_soldier["pos"] = stable_siege_original_position + Vector2(250.0, -170.0)
	var stable_siege_slot_after := _siege_formation_position(stable_siege_soldier, castles["cap_hostile_50"])
	stable_siege_soldier["pos"] = stable_siege_original_position
	_test_assert(stable_siege_slot_before.is_equal_approx(stable_siege_slot_after), "siege_staging_slot_is_stable_while_moving")

	for command in ["跟隨", "防守", "攻擊", "撤退"]:
		_set_soldier_command(command)
	input_scheme = InputScheme.TOUCH
	player["pos"] = Vector2(castles["cap_owned_20"]["pos"]) - Vector2(180, 0)
	_set_soldier_command("駐守")
	var garrison_selected := soldier_command == "駐守" and command_castle_id == "cap_owned_20"
	player["pos"] = Vector2(castles["cap_hostile_50"]["pos"]) - Vector2(180, 0)
	_set_soldier_command("攻城")
	var siege_selected := soldier_command == "攻城" and command_castle_id == "cap_hostile_50"
	_test_assert(garrison_selected and siege_selected, "all_six_army_commands_select_valid_targets")
	input_scheme = InputScheme.KEYBOARD_MOUSE

	var defender: Dictionary = soldiers[0]
	player["pos"] = HOUSE_POS + Vector2(360, 0)
	defender["pos"] = Vector2(player["pos"]) + Vector2(1200, 0)
	soldier_command = "防守"
	command_point = defender["pos"]
	_move_soldier_toward(defender, Vector2(defender["pos"]) + Vector2(30, 0), 0.1)
	_test_assert(Vector2(defender["pos"]).distance_to(player["pos"]) > 1000.0, "defenders_do_not_teleport_to_player")

	var garrison_castle: Dictionary = castles["cap_owned_20"]
	var garrison_start := Vector2(garrison_castle["pos"]) + Vector2(-900, 0)
	defender["pos"] = garrison_start
	soldier_command = "駐守"
	command_castle_id = "cap_owned_20"
	command_point = garrison_castle["pos"]
	enemies.clear()
	var ignored_outsider_id := _spawn_enemy("grunt", garrison_start + Vector2(40, 0), 3, garrison_start + Vector2(40, 0))
	var ignored_outsider: Variant = _find_enemy_by_id(ignored_outsider_id)
	var garrison_ignores_outsider := _select_soldier_enemy_target(defender) == -1
	var distance_before_garrison_move := Vector2(defender["pos"]).distance_to(garrison_castle["pos"])
	_update_single_soldier(defender, 0.08)
	var garrison_moves_to_city := Vector2(defender["pos"]).distance_to(garrison_castle["pos"]) < distance_before_garrison_move
	enemies.clear()
	var city_attacker_id := _spawn_enemy("grunt", Vector2(garrison_castle["pos"]) + Vector2(360, 0), 3, Vector2(garrison_castle["pos"]) + Vector2(360, 0))
	var garrison_targets_city_attacker := _select_soldier_enemy_target(defender) == city_attacker_id
	_test_assert(ignored_outsider != null and garrison_ignores_outsider and garrison_moves_to_city and garrison_targets_city_attacker, "garrison_holds_city_and_only_engages_local_attackers")

	var siege_castle: Dictionary = castles["cap_hostile_50"]
	var siege_center := Vector2(siege_castle["pos"])
	soldier_command = "攻城"
	command_castle_id = "cap_hostile_50"
	command_point = siege_center
	defender["pos"] = siege_center + Vector2(230, 0)
	defender["cooldown"] = 0.0
	enemies.clear()
	var siege_guard_id := _spawn_enemy("grunt", siege_center + Vector2(270, 0), 50, siege_center, "cap_hostile_50")
	var wall_before_defender_phase := float(siege_castle["wall_hp"])
	var siege_selects_guard := _select_soldier_enemy_target(defender) == siege_guard_id
	_update_single_soldier(defender, 0.08)
	var wall_untouched_while_guard_lives := is_equal_approx(float(siege_castle["wall_hp"]), wall_before_defender_phase)
	enemies.clear()
	defender["cooldown"] = 0.0
	_update_single_soldier(defender, 0.08)
	var wall_hit_after_clear := float(siege_castle["wall_hp"]) < wall_before_defender_phase
	_test_assert(siege_selects_guard and wall_untouched_while_guard_lives and wall_hit_after_clear, "siege_clears_defenders_before_outer_wall_and_core")

	# Explosive siege units must not damage the structure in the same blast that
	# clears the final guard.
	enemies.clear()
	projectiles.clear()
	var spill_guard_id := _spawn_enemy("grunt", siege_center + Vector2(270, 0), 50, siege_center, "cap_hostile_50")
	var spill_guard: Variant = _find_enemy_by_id(spill_guard_id)
	spill_guard["hp"] = 1.0
	var wall_before_locked_blast := float(siege_castle["wall_hp"])
	_spawn_projectile({
		"team": "friendly", "kind": "rocket", "source_kind": "rocket", "source_id": defender["id"],
		"pos": spill_guard["pos"], "vel": Vector2.ZERO, "damage": 9999.0, "range": 1.0,
		"radius": 11.0, "pierce": 1, "aoe": 190.0, "color": FIRE_ORANGE, "siege": 2.0,
	})
	_explode_projectile(projectiles.back())
	var final_guard_cleared_without_spill := _find_enemy_by_id(spill_guard_id) == null and is_equal_approx(float(siege_castle["wall_hp"]), wall_before_locked_blast)
	projectiles.clear()
	_test_assert(final_guard_cleared_without_spill, "siege_explosion_cannot_spill_into_wall_while_clearing_final_guard")

	# A piercing recruited projectile also snapshots the defender phase before
	# resolving its enemy hit, so it cannot continue into the city on that frame.
	var pierce_guard_id := _spawn_enemy("grunt", siege_center + Vector2(270, 0), 50, siege_center, "cap_hostile_50")
	var pierce_guard: Variant = _find_enemy_by_id(pierce_guard_id)
	pierce_guard["hp"] = 9999.0
	var pierce_guard_hp_before := float(pierce_guard["hp"])
	var wall_before_piercing_guard := float(siege_castle["wall_hp"])
	_spawn_projectile({
		"team": "friendly", "kind": "rolling_rock", "source_kind": "roller", "source_id": defender["id"],
		"pos": siege_center + Vector2(370, 0), "vel": Vector2.LEFT * 620.0, "damage": 90.0, "range": 500.0,
		"radius": 11.0, "pierce": 5, "aoe": 0.0, "color": Color("A7B2BE"), "falloff": 0.82,
	})
	_update_projectiles(0.55)
	_test_assert(float(pierce_guard["hp"]) < pierce_guard_hp_before and is_equal_approx(float(siege_castle["wall_hp"]), wall_before_piercing_guard), "siege_piercing_shot_cannot_pass_defender_into_wall")
	projectiles.clear()

	# Charged structure shots are cancelled if reinforcements arrive before the
	# charge completes.
	var original_defender_type := str(defender["type"])
	defender["type"] = "rocket"
	defender["charge"] = 0.01
	defender["target_id"] = -int(abs(str(siege_castle["id"]).hash()))
	defender["structure_target"] = str(siege_castle["id"])
	var wall_before_reinforced_charge := float(siege_castle["wall_hp"])
	_update_single_soldier(defender, 0.02)
	var reinforced_charge_cancelled := projectiles.is_empty() and str(defender["structure_target"]).is_empty() and is_equal_approx(float(siege_castle["wall_hp"]), wall_before_reinforced_charge)
	defender["type"] = original_defender_type
	defender["charge"] = 0.0
	enemies.clear()
	_test_assert(reinforced_charge_cancelled, "siege_charge_revalidates_reinforcements_before_firing")

	# Once the ruined target is captured, the siege force automatically becomes
	# its garrison; losing that city recalls the army instead of trapping it.
	siege_castle["destroyed"] = true
	siege_castle["hp"] = 0.0
	siege_castle["capture"] = float(GameConfig.CASTLE_SETTINGS["capture_seconds"])
	player["pos"] = siege_center
	enemies.clear()
	_update_castle_capture(siege_castle, 0.0)
	var siege_becomes_garrison := bool(siege_castle["owned"]) and soldier_command == "駐守" and command_castle_id == "cap_hostile_50"
	_lose_castle(siege_castle)
	_test_assert(siege_becomes_garrison and soldier_command == "跟隨" and command_castle_id.is_empty(), "captured_siege_garrisons_and_lost_city_recalls_army")

	var raid_city_position := Vector2(15000, 15000)
	_register_castle({"id": "enemy_city_target_test", "position": raid_city_position, "level": 20})
	castles["enemy_city_target_test"]["owned"] = true
	enemies.clear()
	var raider_id := _spawn_enemy("grunt", raid_city_position + Vector2(200, 0), 12, raid_city_position + Vector2(200, 0))
	var raider: Variant = _find_enemy_by_id(raider_id)
	var city_target := _choose_friendly_target(raider)
	var raid_city: Dictionary = castles["enemy_city_target_test"]
	var raid_hp_before := float(raid_city["hp"])
	_enemy_melee_attack(raider, Vector2.LEFT)
	_test_assert(str(city_target.get("kind", "")) == "castle" and float(raid_city["hp"]) < raid_hp_before, "enemies_seek_and_damage_friendly_cities")
	var raid_player_position_before := Vector2(player["pos"])
	var raid_player_hp_before := float(player["hp"])
	player["pos"] = raid_city_position
	player["hp"] = float(player["max_hp"])
	player["invuln"] = 0.0
	player["hit_grace"] = 0.0
	var castle_defender_hp_before := float(player["hp"])
	_damage_player(18.0, raid_city_position + Vector2.RIGHT * 60.0, false)
	_test_assert(float(player["hp"]) < castle_defender_hp_before, "friendly_castle_heals_without_invulnerable_defenders")
	player["pos"] = raid_player_position_before
	player["hp"] = raid_player_hp_before
	player["hit_grace"] = 0.0
	castles.erase("enemy_city_target_test")
	enemies.clear()

	while soldiers.size() < _army_limit():
		_spawn_soldier("swordsman", player["pos"] + Vector2(400 + soldiers.size() * 3, 0))
	var full_army_size := soldiers.size()
	var cap_tomb := {"id": next_entity_id, "type": "cannon", "pos": player["pos"] + Vector2(80, 0), "ttl": 10.0, "cost": 450}
	next_entity_id += 1
	tombstones.append(cap_tomb)
	_revive_tombstone(cap_tomb)
	_test_assert(soldiers.size() == full_army_size, "priest_revive_respects_army_limit")
	soldiers.clear()
	_spawn_soldier("swordsman", player["pos"] + Vector2(300, 0))
	_spawn_soldier("swordsman", player["pos"] + Vector2(320, 0))
	for test_soldier in soldiers: test_soldier["hp"] = 1.0
	_enemy_area_attack(player["pos"] + Vector2(310, 0), 80.0, 9999.0)
	_test_assert(soldiers.is_empty(), "enemy_area_attack_hits_all_soldiers")

	enemies.clear()
	camps.clear()
	_register_camp({"id": "remote_test_camp", "position": player["pos"] + Vector2(9000, 0), "level": 1})
	enemies.clear()
	var remote_camp: Dictionary = camps["remote_test_camp"]
	_update_castles_and_camps(0.1)
	_test_assert(not bool(remote_camp["cleared"]), "inactive_camp_not_auto_cleared")
	remote_camp["cleared"] = true
	var crate_hp_before := float(remote_camp["crate_hp"])
	_damage_camp_crate(remote_camp, 10.0)
	_test_assert(float(remote_camp["crate_hp"]) < crate_hp_before, "cleared_camp_crate_breakable")
	camps.clear()

	castles.clear()
	_register_castle({"id": "self_test_castle", "position": player["pos"] + Vector2(300, 0), "level": 1})
	enemies.clear()
	var test_castle: Dictionary = castles["self_test_castle"]
	projectiles.clear()
	test_castle["tower_cd"] = 0.0
	_castle_tower_attack(test_castle)
	_update_projectiles(FIXED_STEP)
	_test_assert(not projectiles.is_empty(), "castle_arrow_clears_own_wall")
	projectiles.clear()
	test_castle["hp"] = test_castle["max_hp"]
	var aoe_castle_hp_before := float(test_castle["hp"])
	_spawn_projectile({
		"team": "friendly", "kind": "fireball", "pos": Vector2(test_castle["pos"]) - Vector2(250, 0),
		"vel": Vector2(1000, 0), "damage": 100.0, "range": 500.0, "radius": 12.0,
		"pierce": 1, "aoe": 155.0, "color": FIRE_ORANGE,
	})
	_update_projectiles(0.25)
	_test_assert(is_equal_approx(aoe_castle_hp_before - float(test_castle["hp"]), 62.0), "aoe_castle_damage_applies_once")
	projectiles.clear()
	test_castle["hp"] = 1.0
	_damage_castle(test_castle, 100.0)
	player["pos"] = Vector2(test_castle["pos"]) + Vector2(0, 140)
	_update_active_chunks(true)
	enemies.clear()
	for _i in 60: _update_castles_and_camps(0.1)
	_test_assert(bool(test_castle["owned"]), "castle_destroy_capture")
	var money_before_income := int(player["money"])
	test_castle["level"] = 20
	test_castle["income_timer"] = 0.01
	_update_castles_and_camps(0.1)
	_test_assert(int(player["money"]) - money_before_income == 10 and is_equal_approx(float(test_castle["income_timer"]), 10.0), "castle_income_every_ten_seconds_level_halved")
	castles.clear()
	enemies.clear()
	projectiles.clear()
	_register_castle({"id": "level_20_artillery_test", "position": player["pos"] + Vector2(640, 0), "level": 20})
	var artillery_castle: Dictionary = castles["level_20_artillery_test"]
	var artillery_count := 0
	var test_enemy_cannon: Variant = null
	for artillery_guard in enemies:
		if str(artillery_guard["type"]) == "cannon":
			artillery_count += 1
			test_enemy_cannon = artillery_guard
	_test_assert(int(artillery_castle["level"]) == 20 and enemies.size() == 20 and artillery_count >= 2, "level_20_castle_has_twenty_guards_and_cannons")
	if test_enemy_cannon != null:
		test_enemy_cannon["pending_pos"] = Vector2(test_enemy_cannon["pos"]) + Vector2(300, 0)
		_execute_enemy_attack(test_enemy_cannon)
	var enemy_cannon_fired := false
	for artillery_projectile in projectiles:
		if str(artillery_projectile["kind"]) == "enemy_cannonball" and float(artillery_projectile["aoe"]) >= 110.0:
			enemy_cannon_fired = true
			break
	_test_assert(enemy_cannon_fired, "enemy_cannon_fires_slow_aoe_shell")
	projectiles.clear()
	enemies.clear()
	castles.clear()
	_register_castle({"id": "level_30_firearms_test", "position": player["pos"] + Vector2(720, 0), "level": 30})
	var firearm_castle: Dictionary = castles["level_30_firearms_test"]
	var musketeer_count := 0
	var rifleman_count := 0
	var test_musketeer: Variant = null
	var test_rifleman: Variant = null
	for firearm_guard in enemies:
		if str(firearm_guard["type"]) == "musketeer":
			musketeer_count += 1
			test_musketeer = firearm_guard
		elif str(firearm_guard["type"]) == "rifleman":
			rifleman_count += 1
			test_rifleman = firearm_guard
	_test_assert(int(firearm_castle["level"]) == 30 and enemies.size() == 26 and musketeer_count >= 2 and rifleman_count >= 4, "level_30_castle_has_linear_garrison_and_firearm_units")
	projectiles.clear()
	for firearm_test_unit in [test_musketeer, test_rifleman]:
		if firearm_test_unit != null:
			firearm_test_unit["pending_pos"] = Vector2(firearm_test_unit["pos"]) + Vector2(320, 0)
			_execute_enemy_attack(firearm_test_unit)
	var musket_fired := false
	var rifle_fired := false
	for firearm_projectile in projectiles:
		musket_fired = musket_fired or str(firearm_projectile["kind"]) == "enemy_musket_ball"
		rifle_fired = rifle_fired or str(firearm_projectile["kind"]) == "enemy_rifle_round"
	_test_assert(musket_fired and rifle_fired and float(GameConfig.ENEMIES["musketeer"]["combat"]["attack_speed"]) < float(GameConfig.ENEMIES["rifleman"]["combat"]["attack_speed"]), "musket_slow_powerful_and_rifle_fast")
	projectiles.clear()
	enemies.clear()
	castles.clear()
	_register_castle({"id": "level_35_vehicle_test", "position": player["pos"] + Vector2(760, 0), "level": 35})
	var vehicle_castle: Dictionary = castles["level_35_vehicle_test"]
	var tank_count := 0
	var rocket_count := 0
	var test_tank: Variant = null
	var test_rocket: Variant = null
	for vehicle_guard in enemies:
		if str(vehicle_guard["type"]) == "tank":
			tank_count += 1
			test_tank = vehicle_guard
		elif str(vehicle_guard["type"]) == "rocket":
			rocket_count += 1
			test_rocket = vehicle_guard
	_test_assert(int(vehicle_castle["level"]) == 35 and enemies.size() == 30 and tank_count >= 3 and rocket_count >= 3, "level_35_castle_has_thirty_guards_tanks_and_rockets")
	projectiles.clear()
	for vehicle_test_unit in [test_tank, test_rocket]:
		if vehicle_test_unit != null:
			vehicle_test_unit["pending_pos"] = Vector2(vehicle_test_unit["pos"]) + Vector2(360, 0)
			_execute_enemy_attack(vehicle_test_unit)
	var tank_shell_fired := false
	var rocket_fired := false
	for vehicle_projectile in projectiles:
		tank_shell_fired = tank_shell_fired or str(vehicle_projectile["kind"]) == "enemy_tank_shell"
		rocket_fired = rocket_fired or (str(vehicle_projectile["kind"]) == "enemy_rocket" and float(vehicle_projectile["aoe"]) >= 175.0)
	_test_assert(tank_shell_fired and rocket_fired and float(GameConfig.ENEMIES["tank"]["combat"]["hp"]) >= 600.0 and float(GameConfig.ENEMIES["rocket"]["combat"]["attack"]) >= 140.0, "tank_is_heavy_and_rocket_is_extreme_wide_damage")
	projectiles.clear()
	enemies.clear()
	castles.clear()
	_register_castle({"id": "level_40_wall_test", "position": player["pos"] + Vector2(800, 0), "level": 40})
	var wall_castle: Dictionary = castles["level_40_wall_test"]
	var gatling_count := 0
	var test_gatling: Variant = null
	for wall_guard in enemies:
		if str(wall_guard["type"]) == "gatling":
			gatling_count += 1
			test_gatling = wall_guard
	_test_assert(int(wall_castle["level"]) == 40 and enemies.size() == 34 and gatling_count >= 5 and float(wall_castle["wall_max_hp"]) > 18000.0, "level_40_castle_has_wall_gatlings_and_linear_garrison")
	var core_hp_before_wall_hit := float(wall_castle["hp"])
	var wall_hp_before_hit := float(wall_castle["wall_hp"])
	_damage_castle(wall_castle, 100.0)
	_test_assert(float(wall_castle["wall_hp"]) < wall_hp_before_hit and is_equal_approx(float(wall_castle["hp"]), core_hp_before_wall_hit) and not bool(wall_castle["wall_breached"]), "level_40_wall_blocks_all_core_damage")
	wall_castle["wall_hp"] = 1.0
	_damage_castle(wall_castle, 100.0)
	var core_hp_after_breach := float(wall_castle["hp"])
	_damage_castle(wall_castle, 100.0)
	_test_assert(bool(wall_castle["wall_breached"]) and is_equal_approx(core_hp_after_breach - float(wall_castle["hp"]), 62.0) and is_equal_approx(_castle_damage_radius(wall_castle), 132.0), "core_only_takes_damage_after_wall_breach")
	projectiles.clear()
	if test_gatling != null:
		test_gatling["pending_pos"] = Vector2(test_gatling["pos"]) + Vector2(340, 0)
		_execute_enemy_attack(test_gatling)
	var gatling_fired := false
	for gatling_projectile in projectiles:
		if str(gatling_projectile["kind"]) == "enemy_gatling_round":
			gatling_fired = true
			break
	_test_assert(gatling_fired and float(GameConfig.ENEMIES["gatling"]["combat"]["attack_speed"]) >= 5.0, "gatling_uses_fast_moderate_damage_fire")
	projectiles.clear()
	enemies.clear()
	castles.clear()
	var active_chunks_before_passage_test := active_chunks
	active_chunks = {}
	var passage_castle_position := Vector2(120480, 120480)
	_register_castle({"id": "owned_wall_passage_test", "position": passage_castle_position, "level": 40})
	enemies.clear()
	var passage_castle: Dictionary = castles["owned_wall_passage_test"]
	passage_castle["wall_hp"] = 0.0
	passage_castle["wall_breached"] = true
	passage_castle["hp"] = 0.0
	passage_castle["destroyed"] = true
	passage_castle["capture"] = float(GameConfig.CASTLE_SETTINGS["capture_seconds"]) - 0.05
	player["pos"] = passage_castle_position + Vector2(0, 140)
	var passage_chunk_coord := world_generator.world_to_chunk(passage_castle_position)
	var passage_chunk_key := world_generator.chunk_key(passage_chunk_coord)
	active_chunks[passage_chunk_key] = {
		"obstacles": [],
		"castle": {"id": "owned_wall_passage_test", "position": passage_castle_position},
	}
	_update_castle_capture(passage_castle, 0.10)
	var captured_start: Vector2 = player["pos"]
	var captured_escape := _move_with_collision(captured_start, Vector2(0, 26), PLAYER_RADIUS, true)
	var all_friendly_sides_open := true
	var all_hostile_sides_closed := true
	var core_boundary_exact := true
	for passage_direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		for passage_radius in [17.0, 29.0]:
			all_friendly_sides_open = all_friendly_sides_open and not _position_hits_obstacle(passage_castle_position + passage_direction * 185.0, passage_radius, true)
			all_hostile_sides_closed = all_hostile_sides_closed and _position_hits_obstacle(passage_castle_position + passage_direction * 185.0, passage_radius, false)
			core_boundary_exact = core_boundary_exact and _position_hits_obstacle(passage_castle_position + passage_direction * (CASTLE_CORE_COLLISION_RADIUS + passage_radius - 0.5), passage_radius, true)
			core_boundary_exact = core_boundary_exact and not _position_hits_obstacle(passage_castle_position + passage_direction * (CASTLE_CORE_COLLISION_RADIUS + passage_radius + 0.5), passage_radius, true)
	_test_assert(bool(passage_castle["owned"]) and captured_escape.distance_to(passage_castle_position) > captured_start.distance_to(passage_castle_position) and all_friendly_sides_open and all_hostile_sides_closed and core_boundary_exact, "captured_walled_castle_opens_friendly_gate_on_all_sides")
	var soldiers_before_wall_fall := soldiers.duplicate(true)
	soldiers.clear()
	_spawn_soldier("tank", passage_castle_position + Vector2(0, 140))
	var trapped_tank: Dictionary = soldiers[0]
	player["pos"] = passage_castle_position + Vector2(35, 0)
	_lose_castle(passage_castle)
	var wall_fall_evacuation_ok := Vector2(player["pos"]).distance_to(passage_castle_position) > CASTLE_OUTER_COLLISION_RADIUS + PLAYER_RADIUS and Vector2(trapped_tank["pos"]).distance_to(passage_castle_position) > CASTLE_OUTER_COLLISION_RADIUS + float(trapped_tank["radius"])
	wall_fall_evacuation_ok = wall_fall_evacuation_ok and not _position_hits_obstacle(Vector2(player["pos"]), PLAYER_RADIUS, false) and not _position_hits_obstacle(Vector2(trapped_tank["pos"]), float(trapped_tank["radius"]), false)
	_test_assert(wall_fall_evacuation_ok, "losing_walled_castle_evacuates_player_and_garrison")
	soldiers = soldiers_before_wall_fall
	active_chunks = active_chunks_before_passage_test
	castles.clear()
	_register_castle({"id": "level_45_air_test", "position": player["pos"] + Vector2(840, 0), "level": 45})
	var air_castle: Dictionary = castles["level_45_air_test"]
	var helicopter_count := 0
	var bomber_count := 0
	var test_helicopter: Variant = null
	var test_bomber: Variant = null
	for air_guard in enemies:
		if str(air_guard["type"]) == "helicopter":
			helicopter_count += 1
			test_helicopter = air_guard
		elif str(air_guard["type"]) == "bomber":
			bomber_count += 1
			test_bomber = air_guard
	_test_assert(int(air_castle["level"]) == 45 and enemies.size() == 38 and helicopter_count >= 6 and bomber_count >= 3 and _enemy_is_air(test_helicopter) and _enemy_is_air(test_bomber), "level_45_castle_has_air_garrison_and_linear_scaling")
	var air_move_start := Vector2(test_helicopter["pos"])
	test_helicopter["pos"] = air_castle["pos"]
	_move_enemy(test_helicopter, Vector2.RIGHT, 0.1)
	_test_assert(Vector2(test_helicopter["pos"]).x > float(Vector2(air_castle["pos"]).x) + 5.0, "air_units_ignore_castle_and_terrain_collision")
	enemies.clear()
	var isolated_air_id := _spawn_enemy("helicopter", player["pos"] + Vector2(250, 0), 45, player["pos"] + Vector2(250, 0))
	var isolated_air: Variant = _find_enemy_by_id(isolated_air_id)
	player["pos"] = Vector2(isolated_air["pos"]) - Vector2(45, 0)
	player["facing"] = Vector2.RIGHT
	var air_hp_before_melee := float(isolated_air["hp"])
	_player_melee_attack(120.0, PI, 9999.0, false)
	var melee_blocked_air := is_equal_approx(float(isolated_air["hp"]), air_hp_before_melee)
	soldiers.clear()
	_spawn_soldier("swordsman", player["pos"] + Vector2(0, 50))
	_spawn_soldier("archer", player["pos"] + Vector2(0, -50))
	python_boss = null
	soldier_command = "跟隨"
	command_point = player["pos"]
	var swordsman_air_target := _select_soldier_enemy_target(soldiers[0])
	var archer_air_target := _select_soldier_enemy_target(soldiers[1])
	projectiles.clear()
	_spawn_projectile({"team": "friendly", "kind": "ally_arrow", "pos": Vector2(isolated_air["pos"]) - Vector2(220, 0), "vel": Vector2(1100, 0), "damage": 90.0, "range": 500.0, "radius": 5.0, "pierce": 1, "aoe": 0.0, "color": Color.WHITE})
	_update_projectiles(0.22)
	_test_assert(melee_blocked_air, "player_melee_cannot_damage_air")
	_test_assert(swordsman_air_target == -1, "melee_soldier_cannot_target_air")
	_test_assert(archer_air_target == isolated_air_id, "ranged_soldier_can_target_air")
	_test_assert(float(isolated_air["hp"]) < air_hp_before_melee, "ranged_projectile_can_damage_air")
	projectiles.clear()
	enemies.clear()
	var isolated_bomber_id := _spawn_enemy("bomber", player["pos"] + Vector2(360, 0), 45, player["pos"] + Vector2(360, 0))
	var isolated_bomber: Variant = _find_enemy_by_id(isolated_bomber_id)
	isolated_bomber["pending_pos"] = player["pos"]
	player["max_hp"] = 5000.0
	player["hp"] = 5000.0
	player["invuln"] = 0.0
	_execute_enemy_attack(isolated_bomber)
	var bomber_drop_count := projectiles.size()
	_update_projectiles(0.20)
	var hp_before_bomb_impact := float(player["hp"])
	_update_projectiles(1.0)
	_test_assert(bomber_drop_count == 3 and is_equal_approx(hp_before_bomb_impact, 5000.0) and float(player["hp"]) < hp_before_bomb_impact, "bomber_drops_three_delayed_high_damage_bombs")
	projectiles.clear()
	enemies.clear()
	hazards.clear()
	castles.clear()
	_register_castle({"id": "level_50_ufo_test", "position": player["pos"] + Vector2(900, 0), "level": 50})
	var ufo_castle: Dictionary = castles["level_50_ufo_test"]
	var ufo_count := 0
	var test_ufo: Variant = null
	for ufo_guard in enemies:
		if str(ufo_guard["type"]) == "ufo":
			ufo_count += 1
			test_ufo = ufo_guard
	_test_assert(int(ufo_castle["level"]) == 50 and enemies.size() == 42 and ufo_count >= 6 and float(ufo_castle["wall_max_hp"]) > 30000.0, "level_50_castle_has_ufo_garrison_max_scaling_and_strongest_wall")
	player["pos"] = HOUSE_POS + Vector2(1100, 900)
	player["max_hp"] = 100.0
	player["hp"] = 100.0
	player["invuln"] = 0.0
	player["hit_grace"] = 0.0
	test_ufo["pending_pos"] = player["pos"]
	_execute_enemy_attack(test_ufo)
	var ufo_beam_created := hazards.size() == 1 and str(hazards[0]["kind"]) == "ufo_beam"
	_update_hazards(0.70)
	_test_assert(ufo_beam_created and float(player["hp"]) < 100.0 and float(player["hp"]) > 70.0 and player["alive"], "ufo_beam_hurts_without_instant_death")
	hazards.clear()
	ufo_castle["owned"] = true
	test_ufo["pending_pos"] = ufo_castle["pos"]
	var ufo_city_durability_before := float(ufo_castle["hp"]) + float(ufo_castle["wall_hp"])
	_execute_enemy_attack(test_ufo)
	_update_hazards(0.70)
	var ufo_city_durability_after := float(ufo_castle["hp"]) + float(ufo_castle["wall_hp"])
	_test_assert(ufo_city_durability_after < ufo_city_durability_before, "ufo_beam_damages_owned_city")
	hazards.clear()
	enemies.clear()
	var generated_castle: Dictionary = castle_chunk["castle"]
	var generated_castle_id := str(generated_castle["id"])
	_register_castle(generated_castle)
	enemies.clear()
	castles[generated_castle_id]["spawn_timer"] = 12.0
	var generated_castle_key := str(castle_chunk["key"])
	active_chunks.erase(generated_castle_key)
	_activate_chunk(Vector2i(5, 5))
	_test_assert(_enemies_with_guard(generated_castle_id) == 0, "castle_reactivation_respects_spawn_timer")

	_start_new_game("archer")
	player["pos"] = HOUSE_POS + Vector2(0, 360)
	enemies.clear()
	var stored_enemy_pos := Vector2(5 * WorldGenerator.CHUNK_SIZE + 480.0, 5 * WorldGenerator.CHUNK_SIZE + 480.0)
	var stored_enemy_id := _spawn_enemy("grunt", stored_enemy_pos, 3, stored_enemy_pos)
	_update_active_chunks(true)
	var stored_enemy_key := world_generator.chunk_key(world_generator.world_to_chunk(stored_enemy_pos))
	_test_assert(_find_enemy_by_id(stored_enemy_id) == null and chunk_states.has(stored_enemy_key), "inactive_enemy_state_is_preserved")
	player["pos"] = stored_enemy_pos
	_update_active_chunks(true)
	_test_assert(_find_enemy_by_id(stored_enemy_id) != null, "inactive_enemy_state_restores_on_return")
	for i in range(MAX_STREAM_HISTORY_CHUNKS + 12):
		discovered_chunks["%d,%d" % [10000 + i, 10000]] = true
	for i in range(MAX_INACTIVE_ENEMY_CHUNKS + 5):
		chunk_states["%d,%d" % [-10000 - i, -10000]] = []
	_trim_streaming_history(world_generator.world_to_chunk(player["pos"]))
	_test_assert(discovered_chunks.size() <= MAX_STREAM_HISTORY_CHUNKS and chunk_states.size() <= MAX_INACTIVE_ENEMY_CHUNKS, "streaming_history_is_bounded")

	soldiers.clear()
	for saved_technology_type in ["cannon", "musketeer", "rifleman", "tank", "rocket"]:
		_spawn_soldier(saved_technology_type, player["pos"] + Vector2(-180.0 + float(soldiers.size()) * 90.0, 110.0))
	var preserved_enemy_id := _spawn_enemy("archer", player["pos"] + Vector2(520, 0), 4, player["pos"] + Vector2(520, 0))
	var expected_next_entity_id := next_entity_id
	var saved_money := int(player["money"])
	drops.append({"kind": "loot", "pos": player["pos"] + Vector2(90, 0), "gold": 77, "xp": 33, "ttl": 18.0})
	_register_castle({"id": "saved_garrison_castle", "position": player["pos"] + Vector2(760, 0), "level": 20})
	castles["saved_garrison_castle"]["owned"] = true
	for saved_guard_index in range(enemies.size() - 1, -1, -1):
		if str(enemies[saved_guard_index].get("guard_castle", "")) == "saved_garrison_castle":
			enemies.remove_at(saved_guard_index)
	soldier_command = "駐守"
	command_castle_id = "saved_garrison_castle"
	command_point = castles["saved_garrison_castle"]["pos"]
	var saved_lair_chunk := world_generator.generate_chunk(Vector2i(3, 2))
	var saved_lair_descriptor: Dictionary = Dictionary(saved_lair_chunk["snake_nest"])
	var saved_lair_id := str(saved_lair_descriptor["id"])
	var saved_lair_home := Vector2(saved_lair_descriptor["position"])
	_register_snake_nest(saved_lair_descriptor)
	_activate_python_boss_lair(saved_lair_id, true)
	python_boss.force_engage()
	python_boss.debug_set_hp_ratio(0.62)
	var save_ok := _save_game(false, test_path)
	player["money"] = 0
	drops.clear()
	var load_ok := _load_game(test_path)
	_test_assert(save_ok and load_ok and int(player["money"]) == saved_money, "save_round_trip")
	var resummoned_chaos_save := GameSaveManager.load_game(test_path)
	var resummoned_controller: ChaosBossController = ChaosBossControllerScript.new()
	resummoned_controller.initialize(GameConfig.CHAOS_BOSS_CONFIG, int(player.get("level", 1)), 2048)
	resummoned_chaos_save["chaos_boss"] = resummoned_controller.serialize()
	var resummoned_aionis_controller: AionisBossController = AionisBossControllerScript.new()
	resummoned_aionis_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, int(player.get("level", 1)), 4096)
	resummoned_chaos_save["aionis_boss"] = resummoned_aionis_controller.serialize()
	resummoned_chaos_save["progression"] = {"final_boss_defeated": false, "ending_seen": true, "all_soldiers_unlocked": true, "timeless_gate_unlocked": true, "aionis_defeated": false, "kaeron_ending_completed": true}
	_test_assert(_is_valid_save_data(resummoned_chaos_save), "resummoned_chaos_boss_save_remains_loadable_after_ending")
	_test_assert(_find_enemy_by_id(preserved_enemy_id) != null, "save_preserves_active_enemies")
	_test_assert(next_entity_id >= expected_next_entity_id, "save_preserves_entity_id_sequence")
	_test_assert(drops.size() == 1 and int(drops[0]["gold"]) == 77, "save_preserves_uncollected_drops")
	_test_assert(soldier_command == "駐守" and command_castle_id == "saved_garrison_castle", "save_preserves_garrison_command_target")
	_test_assert(str(Dictionary(Dictionary(castles["saved_garrison_castle"]).get("nation", {})).get("id", "")) == NationCatalog.PLAYER_NATION_ID, "save_preserves_player_castle_nation_and_flag")
	var loaded_technology_types: Array[String] = []
	var loaded_rocket: Variant = null
	for loaded_recruit in soldiers:
		loaded_technology_types.append(str(loaded_recruit["type"]))
		if str(loaded_recruit["type"]) == "rocket": loaded_rocket = loaded_recruit
	loaded_technology_types.sort()
	var expected_technology_types: Array[String] = ["cannon", "musketeer", "rifleman", "rocket", "tank"]
	_test_assert(loaded_technology_types == expected_technology_types and loaded_rocket != null and Vector2(loaded_rocket.get("aim_dir", Vector2.ZERO)).length_squared() > 0.0, "save_preserves_all_five_player_technology_units")
	projectiles.clear()
	if loaded_rocket != null: _fire_soldier_attack(loaded_rocket, preserved_enemy_id)
	_test_assert(not projectiles.is_empty() and str(projectiles.back()["kind"]) == "rocket", "loaded_technology_unit_can_resume_combat")
	projectiles.clear()
	var loaded_boss_state: Dictionary = python_boss.get_text_state()
	_test_assert(bool(loaded_boss_state["discovered"]) and str(loaded_boss_state["state"]) == "IDLE" and is_equal_approx(float(loaded_boss_state["hp"]), float(loaded_boss_state["max_hp"])), "save_resets_active_boss_safely_at_nest")
	_test_assert(active_python_boss_lair_id == saved_lair_id and _python_boss_position().distance_to(saved_lair_home) < 0.2 and snake_nests.has(saved_lair_id), "save_preserves_active_procedural_saga_lair")
	var invalid_path := "/tmp/infinite_legion_invalid_test.json"
	var dash_overshoot_save := GameSaveManager.load_game(test_path)
	dash_overshoot_save["boss"]["engaged"] = true
	dash_overshoot_save["boss"]["position"] = saved_lair_home + Vector2(1400.0, 0.0)
	GameSaveManager.save_game(dash_overshoot_save, invalid_path)
	var dash_overshoot_load_ok := _load_game(invalid_path)
	_test_assert(dash_overshoot_load_ok and active_python_boss_lair_id == saved_lair_id and _python_boss_position().distance_to(saved_lair_home) < 0.2 and str(python_boss.get_text_state()["state"]) == "IDLE", "boss_dash_leash_overshoot_save_loads_safely_at_active_lair")
	var stale_lair_id_save := GameSaveManager.load_game(test_path)
	var stale_lair_id := "snake_nest_3,2"
	var stale_lair_record: Dictionary = Dictionary(stale_lair_id_save["snake_nests"][saved_lair_id])
	stale_lair_id_save["snake_nests"].erase(saved_lair_id)
	stale_lair_record["id"] = stale_lair_id
	stale_lair_id_save["snake_nests"][stale_lair_id] = stale_lair_record
	stale_lair_id_save["boss_lair_state"]["active_lair_id"] = stale_lair_id
	GameSaveManager.save_game(stale_lair_id_save, invalid_path)
	var stale_lair_load_ok := _load_game(invalid_path)
	_test_assert(stale_lair_load_ok and active_python_boss_lair_id == saved_lair_id and snake_nests.has(saved_lair_id) and not snake_nests.has(stale_lair_id), "stale_python_boss_lair_id_canonicalizes_before_restore")
	var defeated_overshoot_save := GameSaveManager.load_game(test_path)
	defeated_overshoot_save["boss"]["engaged"] = false
	defeated_overshoot_save["boss"]["defeated"] = true
	defeated_overshoot_save["boss"]["hp"] = 0.0
	defeated_overshoot_save["boss"]["nest_cleared"] = true
	defeated_overshoot_save["boss"]["reward_claimed"] = true
	defeated_overshoot_save["boss"]["position"] = saved_lair_home + Vector2(1400.0, 0.0)
	defeated_overshoot_save["snake_nests"][saved_lair_id]["cleared"] = true
	GameSaveManager.save_game(defeated_overshoot_save, invalid_path)
	var defeated_overshoot_load_ok := _load_game(invalid_path)
	_test_assert(defeated_overshoot_load_ok and python_boss.is_defeated() and bool(snake_nests[saved_lair_id]["cleared"]) and _python_boss_position().distance_to(saved_lair_home) < 0.2, "defeated_dash_overshoot_save_loads_as_cleared_active_lair")
	GameSaveManager.save_game({"schema": SAVE_SCHEMA, "player": {"class_id": "archer"}}, invalid_path)
	var money_before_invalid_load := int(player["money"])
	_test_assert(not _load_game(invalid_path) and int(player["money"]) == money_before_invalid_load, "invalid_save_does_not_mutate_session")
	var malformed_structure_save := GameSaveManager.load_game(test_path)
	malformed_structure_save["castles"] = {"broken": {"pos": Vector2.ZERO, "hp": 10.0, "max_hp": 10.0, "level": 1, "capture": 0.0, "income_timer": 1.0, "spawn_timer": 1.0, "tower_cd": 1.0, "under_attack": 0.0}}
	GameSaveManager.save_game(malformed_structure_save, invalid_path)
	_test_assert(not _load_game(invalid_path) and int(player["money"]) == money_before_invalid_load, "malformed_structure_save_is_rejected")
	var malformed_boss_save := GameSaveManager.load_game(test_path)
	malformed_boss_save["boss"]["phase"] = 99
	GameSaveManager.save_game(malformed_boss_save, invalid_path)
	_test_assert(not _load_game(invalid_path) and int(player["money"]) == money_before_invalid_load, "malformed_boss_save_is_rejected")
	var malformed_lair_binding_save := GameSaveManager.load_game(test_path)
	malformed_lair_binding_save["boss_lair_state"]["active_lair_id"] = "missing_python_boss_lair"
	GameSaveManager.save_game(malformed_lair_binding_save, invalid_path)
	_test_assert(not _load_game(invalid_path) and int(player["money"]) == money_before_invalid_load, "malformed_boss_lair_binding_is_rejected")
	var contradictory_lair_save := GameSaveManager.load_game(test_path)
	contradictory_lair_save["snake_nests"][saved_lair_id]["cleared"] = true
	GameSaveManager.save_game(contradictory_lair_save, invalid_path)
	_test_assert(not _load_game(invalid_path) and int(player["money"]) == money_before_invalid_load, "cleared_lair_cannot_restore_live_saga")
	var missing_v4_binding_save := GameSaveManager.load_game(test_path)
	missing_v4_binding_save.erase("boss_lair_state")
	GameSaveManager.save_game(missing_v4_binding_save, invalid_path)
	_test_assert(not _load_game(invalid_path) and int(player["money"]) == money_before_invalid_load, "schema_four_requires_boss_lair_binding")
	var malformed_command_save := GameSaveManager.load_game(test_path)
	malformed_command_save["command"]["point"] = "not-a-vector"
	GameSaveManager.save_game(malformed_command_save, invalid_path)
	_test_assert(not _load_game(invalid_path) and int(player["money"]) == money_before_invalid_load, "malformed_command_save_is_rejected")

	# Gameplay-systems update regression coverage.
	notifications.clear()
	notifications_hidden = true
	_add_notification("hidden income", GOLD, 2.0)
	upgrade_effects = [{"pos": Vector2.ZERO, "radius": 40.0, "ttl": 1.0, "warmup": 0.5, "color": Color.RED}]
	_test_assert(notifications.is_empty() and upgrade_effects.size() == 1, "notification_toggle_hides_banners_but_preserves_combat_telegraphs")
	notifications_hidden = false
	_initialize_empty_player()
	player["class_id"] = "archer"
	soldier_research = SoldierUpgradeCatalog.create_empty_research()
	var research_before_full_upgrade := soldier_research.duplicate(true)
	var soldiers_before_full_upgrade := soldiers.duplicate(true)
	_apply_full_hero_upgrade()
	_test_assert(int(player["level"]) == HERO_LEVEL_CAP and soldier_research == research_before_full_upgrade and soldiers == soldiers_before_full_upgrade, "full_upgrade_never_upgrades_soldiers")
	player["money"] = 100000
	var base_attack_cost := SoldierUpgradeCatalog.next_rank_cost("archer", "attack_or_healing", soldier_research)
	var upgrade_purchase_ok := _purchase_soldier_upgrade("archer", "attack_or_healing")
	var upgraded_archer_snapshot := SoldierUpgradeCatalog.snapshot_for_type("archer", soldier_research)
	_test_assert(upgrade_purchase_ok and int(player["money"]) == 100000 - base_attack_cost and float(Dictionary(upgraded_archer_snapshot["base_effects"])["attack_or_healing_bonus"]) > 0.0, "soldier_upgrade_purchase_uses_catalog_price_and_effect")
	var recruited_archer_id := _spawn_soldier("archer", Vector2(640.0, 480.0))
	var recruited_archer: Variant = _find_soldier_by_id(recruited_archer_id)
	_test_assert(recruited_archer != null and Dictionary(recruited_archer).has("upgrade_snapshot") and float(Dictionary(Dictionary(recruited_archer)["upgrade_snapshot"])["base_effects"]["attack_or_healing_bonus"]) > 0.0, "future_recruits_receive_permanent_upgrade_snapshot")
	var legacy_research := SoldierUpgradeCatalog.sanitize_research({})
	_test_assert(SoldierUpgradeCatalog.research_is_valid(legacy_research), "legacy_save_migrates_to_valid_empty_soldier_research")
	var catalog_test := SoldierUpgradeCatalog.catalog_self_test()
	var runtime_test := SoldierUpgradeRuntime.self_test()
	_test_assert(bool(catalog_test.get("ok", false)) and int(catalog_test.get("soldier_types", 0)) == 16 and int(catalog_test.get("base_upgrades", 0)) == 8 and int(catalog_test.get("special_abilities", 0)) == 57, "soldier_upgrade_catalog_has_16_types_8_base_and_57_specials")
	_test_assert(bool(runtime_test.get("ok", false)) and int(runtime_test.get("catalog_ids", 0)) == 57, "soldier_upgrade_runtime_covers_all_57_specials")
	var catalog_price_effects_ok := true
	for special_id_value in SoldierUpgradeCatalog.SPECIAL_ABILITY_ORDER:
		var special_id := str(special_id_value)
		var definition := SoldierUpgradeCatalog.definition_for(special_id)
		if int(definition.get("base_price", 0)) <= 0 or SoldierUpgradeCatalog.localized_effect_text(special_id, 1, "zh_TW").is_empty() or SoldierUpgradeCatalog.localized_effect_text(special_id, 1, "en").is_empty():
			catalog_price_effects_ok = false
			break
	_test_assert(catalog_price_effects_ok, "all_57_specials_expose_positive_prices_and_bilingual_effects")

	# Existing soldiers retain their immutable research snapshot. Only recruits
	# created after a purchase inherit the new permanent rank.
	soldiers.clear()
	soldier_research = SoldierUpgradeCatalog.create_empty_research()
	player["level"] = 20
	player["money"] = 1000000
	var old_archer_id := _spawn_soldier("archer", Vector2(1850.0, 1850.0))
	var old_archer: Variant = _find_soldier_by_id(old_archer_id)
	var old_attack_bonus := float(Dictionary(Dictionary(old_archer)["upgrade_snapshot"])["base_effects"].get("attack_or_healing_bonus", 0.0))
	_purchase_soldier_upgrade("archer", "attack_or_healing")
	var new_archer_id := _spawn_soldier("archer", Vector2(1900.0, 1850.0))
	var new_archer: Variant = _find_soldier_by_id(new_archer_id)
	var old_bonus_after_purchase := float(Dictionary(Dictionary(old_archer)["upgrade_snapshot"])["base_effects"].get("attack_or_healing_bonus", 0.0))
	var new_attack_bonus := float(Dictionary(Dictionary(new_archer)["upgrade_snapshot"])["base_effects"].get("attack_or_healing_bonus", 0.0))
	_test_assert(is_zero_approx(old_attack_bonus) and is_zero_approx(old_bonus_after_purchase) and new_attack_bonus > 0.0, "soldier_upgrade_snapshot_changes_only_future_recruits")

	var research_roundtrip_path := "/tmp/infinite_legion_research_roundtrip.json"
	GameSaveManager.delete_save(research_roundtrip_path)
	var research_roundtrip_saved := GameSaveManager.save_game({"soldier_research": soldier_research}, research_roundtrip_path)
	var research_roundtrip_loaded := GameSaveManager.load_game(research_roundtrip_path)
	_test_assert(research_roundtrip_saved and SoldierUpgradeCatalog.research_is_valid(research_roundtrip_loaded.get("soldier_research", {})), "soldier_research_json_roundtrip_accepts_integral_float_ranks")
	GameSaveManager.delete_save(research_roundtrip_path)

	# Full schema-8 roundtrip preserves the research wallet and each historical
	# soldier snapshot. A newly recruited unit after loading receives current
	# research, while the pre-purchase unit remains unchanged.
	var full_research_roundtrip_path := "/tmp/infinite_legion_research_full_roundtrip.json"
	GameSaveManager.delete_save(full_research_roundtrip_path)
	var full_research_saved := _save_game(false, full_research_roundtrip_path)
	soldier_research = SoldierUpgradeCatalog.create_empty_research()
	soldiers.clear()
	var full_research_loaded := _load_game(full_research_roundtrip_path)
	var roundtrip_old_archer: Variant = _find_soldier_by_id(old_archer_id)
	var roundtrip_new_archer: Variant = _find_soldier_by_id(new_archer_id)
	var post_load_archer_id := _spawn_soldier("archer", Vector2(1940.0, 1850.0))
	var post_load_archer: Variant = _find_soldier_by_id(post_load_archer_id)
	var roundtrip_snapshots_ok := (
		full_research_saved
		and full_research_loaded
		and SoldierUpgradeCatalog.current_rank("archer", "attack_or_healing", soldier_research) == 1
		and roundtrip_old_archer != null
		and roundtrip_new_archer != null
		and post_load_archer != null
		and is_zero_approx(float(Dictionary(Dictionary(roundtrip_old_archer)["upgrade_snapshot"])["base_effects"].get("attack_or_healing_bonus", 0.0)))
		and float(Dictionary(Dictionary(roundtrip_new_archer)["upgrade_snapshot"])["base_effects"].get("attack_or_healing_bonus", 0.0)) > 0.0
		and float(Dictionary(Dictionary(post_load_archer)["upgrade_snapshot"])["base_effects"].get("attack_or_healing_bonus", 0.0)) > 0.0
	)
	_test_assert(roundtrip_snapshots_ok, "save_load_preserves_research_and_historical_future_recruit_snapshots")
	GameSaveManager.delete_save(full_research_roundtrip_path)

	# Schema-7 stored special effects only in `active_specials`. Verify that a real
	# save/load migrates that array to the combat lookup map without consulting the
	# current research tree.
	var schema7_snapshot_path := "/tmp/infinite_legion_schema7_snapshot.json"
	GameSaveManager.delete_save(schema7_snapshot_path)
	var schema7_snapshot_save := GameSaveManager.load_game(test_path)
	schema7_snapshot_save["schema"] = 7
	var schema7_soldiers: Array = schema7_snapshot_save.get("soldiers", [])
	var schema7_soldier: Dictionary = Dictionary(schema7_soldiers[0]).duplicate(true)
	var schema7_soldier_id := int(schema7_soldier["id"])
	schema7_soldier["type"] = "swordsman"
	schema7_soldier["attack"] = 8.0
	schema7_soldier["upgrade_snapshot"] = {
		"type": "swordsman",
		"base_effects": {},
		"active_specials": [{
			"id": "burning_sword", "rank": 1,
			"effect": {"duration": 3.0, "total_burn_ratio": 0.24, "source_target_proc_cooldown": 0.6},
		}],
	}
	schema7_soldier.erase("special_runtime")
	schema7_soldier.erase("upgrade_cooldowns")
	schema7_soldier.erase("upgrade_counters")
	schema7_soldiers[0] = schema7_soldier
	schema7_snapshot_save["soldiers"] = schema7_soldiers
	var schema7_file_saved := GameSaveManager.save_game(schema7_snapshot_save, schema7_snapshot_path)
	var schema7_loaded := _load_game(schema7_snapshot_path)
	var migrated_schema7_soldier: Variant = _find_soldier_by_id(schema7_soldier_id)
	var schema7_map_ok := false
	var schema7_combat_ok := false
	if migrated_schema7_soldier != null:
		var migrated_schema7_snapshot: Dictionary = Dictionary(migrated_schema7_soldier["upgrade_snapshot"])
		var migrated_schema7_specials: Dictionary = Dictionary(migrated_schema7_snapshot.get("special_effects", {}))
		schema7_map_ok = migrated_schema7_specials.has("burning_sword")
		enemies.clear()
		var legacy_target_position := Vector2(migrated_schema7_soldier["pos"]) + Vector2(36.0, 0.0)
		var legacy_target_id := _spawn_enemy("heavy", legacy_target_position, 40, legacy_target_position)
		var legacy_target_index := _enemy_index_by_id(legacy_target_id)
		_resolve_soldier_enemy_hit(legacy_target_index, 8.0, migrated_schema7_soldier["pos"], "melee", schema7_soldier_id, migrated_schema7_specials)
		var legacy_target: Variant = _find_enemy_by_id(legacy_target_id)
		schema7_combat_ok = legacy_target != null and float(legacy_target.get("soldier_burn_ttl", 0.0)) > 0.0
	_test_assert(schema7_file_saved, "schema7_active_special_fixture_saves")
	_test_assert(schema7_loaded, "schema7_active_special_fixture_loads")
	_test_assert(schema7_map_ok, "schema7_active_special_snapshot_builds_lookup_map")
	_test_assert(schema7_combat_ok, "schema7_active_special_snapshot_remains_combat_effective")
	GameSaveManager.delete_save(schema7_snapshot_path)
	_test_assert(_load_game(test_path), "schema7_snapshot_test_restores_canonical_save")
	var malformed_snapshot_path := "/tmp/infinite_legion_malformed_snapshot.json"
	GameSaveManager.delete_save(malformed_snapshot_path)
	var malformed_snapshot_save := GameSaveManager.load_game(test_path)
	malformed_snapshot_save["soldiers"][0]["upgrade_snapshot"] = "corrupt"
	GameSaveManager.save_game(malformed_snapshot_save, malformed_snapshot_path)
	var snapshot_rejection_money := int(player["money"])
	_test_assert(not _load_game(malformed_snapshot_path) and int(player["money"]) == snapshot_rejection_money, "schema8_rejects_malformed_soldier_upgrade_snapshot_without_mutation")
	GameSaveManager.delete_save(malformed_snapshot_path)

	var cheat_money_before := int(player["money"])
	_on_cheat_code_submitted("  GOLD   coins ")
	_test_assert(int(player["money"]) == cheat_money_before + 100000, "gold_coins_cheat_adds_exactly_100000")
	var change_money := int(player["money"])
	var change_level := int(player["level"])
	var change_soldier_count := soldiers.size()
	var change_research := soldier_research.duplicate(true)
	_on_cheat_code_submitted("change")
	class_select_pointer_guard_until_msec = -10000
	_change_player_class("mage")
	_test_assert(str(player["class_id"]) == "mage" and int(player["money"]) == change_money and int(player["level"]) == change_level and soldiers.size() == change_soldier_count and soldier_research == change_research, "change_cheat_preserves_money_level_soldiers_and_research")

	var player_nation := NationCatalog.player_metadata()
	var foreign_nation := NationCatalog.metadata_for_castle(world_seed, "nation_test_foreign", Vector2(20000.0, 20000.0))
	_test_assert(NationCatalog.is_valid_metadata(player_nation) and NationCatalog.are_hostile(player_nation, foreign_nation), "nation_metadata_defines_player_flag_and_hostility")
	var support_source := {"level": 20, "hp": 100.0, "max_hp": 100.0, "destroyed": false}
	var support_target := {"level": 20, "hp": 40.0, "max_hp": 100.0, "destroyed": false}
	_reinforce_nation_castle(support_source, support_target, 2.0)
	_test_assert(float(support_target["hp"]) > 40.0, "same_nation_castles_send_support")
	var annex_attacker := {"level": 30, "nation": foreign_nation}
	var annex_defender := {"destroyed": true, "nation": player_nation, "max_hp": 1000.0, "hp": 0.0, "wall_max_hp": 400.0, "wall_hp": 0.0}
	_apply_nation_siege(annex_attacker, annex_defender, 2.0)
	_test_assert(not bool(annex_defender["destroyed"]) and str(Dictionary(annex_defender["nation"])["id"]) == str(foreign_nation["id"]), "hostile_nation_annexes_defeated_castle")
	var json_shaped_nation := foreign_nation.duplicate(true)
	json_shaped_nation["version"] = float(json_shaped_nation["version"])
	json_shaped_nation["capital_chunk_x"] = float(json_shaped_nation["capital_chunk_x"])
	json_shaped_nation["capital_chunk_y"] = float(json_shaped_nation["capital_chunk_y"])
	var missing_nation_coordinate := json_shaped_nation.duplicate(true)
	missing_nation_coordinate.erase("capital_chunk_x")
	_test_assert(NationCatalog.is_valid_metadata(json_shaped_nation) and not NationCatalog.is_valid_metadata(missing_nation_coordinate), "nation_validator_accepts_integral_json_numbers_and_requires_all_fields")

	# AI-to-AI ownership must survive a real JSON save. The current owner is not
	# required to match the geographic nation stored in `original_nation`.
	var nation_roundtrip_path := "/tmp/infinite_legion_nation_roundtrip.json"
	GameSaveManager.delete_save(nation_roundtrip_path)
	var nation_roundtrip_save := GameSaveManager.load_game(test_path)
	var nation_castles: Dictionary = Dictionary(nation_roundtrip_save.get("castles", {}))
	var nation_castle: Dictionary = Dictionary(nation_castles["saved_garrison_castle"]).duplicate(true)
	var geographic_nation := NationCatalog.metadata_for_castle(int(nation_roundtrip_save.get("world_seed", world_seed)), str(nation_castle["id"]), nation_castle["pos"])
	var annex_owner_nation := geographic_nation
	for owner_search_index in range(1, 40):
		var owner_candidate := NationCatalog.metadata_for_castle(int(nation_roundtrip_save.get("world_seed", world_seed)), "annex_owner_%d" % owner_search_index, Vector2(nation_castle["pos"]) + Vector2(float(owner_search_index) * NationCatalog.CHUNK_SIZE * 13.0, NationCatalog.CHUNK_SIZE * 7.0))
		if str(owner_candidate["id"]) != str(geographic_nation["id"]):
			annex_owner_nation = owner_candidate
			break
	nation_castle["owned"] = false
	nation_castle["original_nation"] = geographic_nation
	nation_castle["nation"] = NationCatalog.conquest_metadata(annex_owner_nation)
	nation_castles["saved_garrison_castle"] = nation_castle
	nation_roundtrip_save["castles"] = nation_castles
	var nation_file_saved := GameSaveManager.save_game(nation_roundtrip_save, nation_roundtrip_path)
	var nation_file_loaded := _load_game(nation_roundtrip_path)
	var loaded_annex_castle: Dictionary = Dictionary(castles.get("saved_garrison_castle", {}))
	var ai_annex_persisted := (
		nation_file_saved
		and nation_file_loaded
		and str(annex_owner_nation["id"]) != str(geographic_nation["id"])
		and str(Dictionary(loaded_annex_castle.get("nation", {})).get("id", "")) == str(annex_owner_nation["id"])
		and str(Dictionary(loaded_annex_castle.get("original_nation", {})).get("id", "")) == str(geographic_nation["id"])
	)
	_test_assert(ai_annex_persisted, "save_load_preserves_ai_annexed_castle_nation")
	GameSaveManager.delete_save(nation_roundtrip_path)
	_test_assert(_load_game(test_path), "nation_roundtrip_test_restores_canonical_save")

	# Touch layout includes a dedicated, non-overlapping troop-upgrade button and
	# all in-panel actions meet the minimum 44 px touch target.
	var stored_screen_size := screen_size
	var stored_input_scheme := input_scheme
	var stored_touch_ui_coordinate_scale := touch_ui_coordinate_scale
	touch_ui_coordinate_scale = 1.0
	screen_size = Vector2(844.0, 390.0)
	_set_input_scheme(InputScheme.TOUCH)
	mode = GameMode.PLAYING
	active_panel = ""
	var touch_utility := _touch_utility_rects()
	var touch_upgrade_rect := Rect2(touch_utility["upgrades"])
	var left_stick_bounds := Rect2(_touch_move_center() - Vector2.ONE * TOUCH_STICK_RADIUS, Vector2.ONE * TOUCH_STICK_RADIUS * 2.0)
	var right_stick_bounds := Rect2(_touch_aim_center() - Vector2.ONE * TOUCH_STICK_RADIUS, Vector2.ONE * TOUCH_STICK_RADIUS * 2.0)
	var touch_upgrade_geometry_ok := touch_upgrade_rect.size.x >= 44.0 and touch_upgrade_rect.size.y >= 44.0 and not touch_upgrade_rect.intersects(left_stick_bounds) and not touch_upgrade_rect.intersects(right_stick_bounds) and not touch_upgrade_rect.intersects(_touch_special_rect())
	_handle_touch_action_at(touch_upgrade_rect.get_center())
	var touch_upgrade_opened := active_panel == "soldier_upgrades"
	var touch_upgrade_panel := _soldier_upgrade_panel_rect()
	var touch_upgrade_controls := _soldier_upgrade_control_rects(touch_upgrade_panel)
	var touch_targets_large := true
	for control_value in touch_upgrade_controls.values():
		var control_rect := Rect2(control_value)
		if control_rect.size.x < 44.0 or control_rect.size.y < 44.0:
			touch_targets_large = false
			break
	var close_does_not_overlap_next := not Rect2(touch_upgrade_controls["type_next"]).intersects(_touch_panel_close_rect())
	soldier_upgrade_type_index = SoldierUpgradeCatalog.SOLDIER_ORDER.find("archer")
	soldier_upgrade_category = "base"
	soldier_upgrade_page = 0
	soldier_research = SoldierUpgradeCatalog.create_empty_research()
	player["money"] = 1000000
	var touch_rank_before := SoldierUpgradeCatalog.current_rank("archer", "recruit_discount", soldier_research)
	_handle_ui_click(_soldier_upgrade_row_rect(0, touch_upgrade_panel).get_center())
	var touch_rank_after := SoldierUpgradeCatalog.current_rank("archer", "recruit_discount", soldier_research)
	_handle_ui_click(Rect2(touch_upgrade_controls["special_tab"]).get_center())
	var touch_special_tab_works := soldier_upgrade_category == "special"
	_handle_touch_action_at(_touch_panel_close_rect().get_center())
	var web_touch_scale := 720.0 / 390.0
	touch_ui_coordinate_scale = web_touch_scale
	screen_size = Vector2(844.0 * web_touch_scale, 720.0)
	active_panel = ""
	var web_screen_bounds := Rect2(Vector2.ZERO, screen_size)
	var web_stick_radius := TOUCH_STICK_RADIUS * web_touch_scale
	var web_move_bounds := Rect2(_touch_move_center() - Vector2.ONE * web_stick_radius, Vector2.ONE * web_stick_radius * 2.0)
	var web_attack_bounds := Rect2(_touch_aim_center() - Vector2.ONE * web_stick_radius, Vector2.ONE * web_stick_radius * 2.0)
	var web_special_bounds := _touch_special_rect()
	var web_touch_utility := _touch_utility_rects()
	var web_virtual_rects: Array[Rect2] = [web_move_bounds, web_attack_bounds, web_special_bounds]
	var web_virtual_layout_ok := web_touch_utility.size() == 10
	for web_utility_value in web_touch_utility.values():
		web_virtual_rects.append(Rect2(web_utility_value))
	for web_control_index in web_virtual_rects.size():
		var web_control_rect := web_virtual_rects[web_control_index]
		var web_control_css_size := web_control_rect.size / web_touch_scale
		if web_control_css_size.x < 44.0 or web_control_css_size.y < 44.0 or not web_screen_bounds.encloses(web_control_rect):
			web_virtual_layout_ok = false
			break
		for web_previous_index in web_control_index:
			if web_control_rect.intersects(web_virtual_rects[web_previous_index]):
				web_virtual_layout_ok = false
				break
		if not web_virtual_layout_ok:
			break
	_test_assert(web_virtual_layout_ok, "web_touch_ten_utilities_dual_sticks_and_special_are_large_visible_and_disjoint")

	var web_panel_targets_ok := true
	var web_layout_unlock_before := all_soldiers_unlocked
	all_soldiers_unlocked = true
	active_panel = "recruit"
	var web_recruit_panel := _recruit_panel_rect()
	for web_recruit_index in _recruitable_soldier_order().size():
		var web_recruit_buy := _recruit_buy_rect(web_recruit_index, web_recruit_panel)
		var web_recruit_css_size := web_recruit_buy.size / web_touch_scale
		if web_recruit_css_size.x < 44.0 or web_recruit_css_size.y < 44.0 or not web_screen_bounds.encloses(web_recruit_buy):
			web_panel_targets_ok = false
			break
	for web_panel_name in ["skills", "recruit", "map", "command"]:
		active_panel = str(web_panel_name)
		var web_close_rect := _touch_panel_close_rect()
		var web_close_css_size := web_close_rect.size / web_touch_scale
		if web_close_css_size.x < 44.0 or web_close_css_size.y < 44.0 or not web_screen_bounds.encloses(web_close_rect):
			web_panel_targets_ok = false
			break
	active_panel = ""
	mode = GameMode.PAUSED
	var web_pause_panel := _pause_panel_rect()
	for web_pause_index in _pause_actions().size():
		var web_pause_action := _pause_button_rect(web_pause_index)
		var web_pause_action_css_size := web_pause_action.size / web_touch_scale
		if web_pause_action_css_size.x < 44.0 or web_pause_action_css_size.y < 44.0 or not web_pause_panel.encloses(web_pause_action) or not web_screen_bounds.encloses(web_pause_action):
			web_panel_targets_ok = false
			break
	var web_pause_language := _pause_language_rect()
	var web_pause_language_css_size := web_pause_language.size / web_touch_scale
	if web_pause_language_css_size.x < 44.0 or web_pause_language_css_size.y < 44.0 or not web_pause_panel.encloses(web_pause_language) or not web_screen_bounds.encloses(web_pause_language):
		web_panel_targets_ok = false
	for web_volume_action in ["down", "mute", "up"]:
		var web_pause_volume := _pause_volume_rect(str(web_volume_action))
		var web_pause_volume_css_size := web_pause_volume.size / web_touch_scale
		if web_pause_volume_css_size.x < 44.0 or web_pause_volume_css_size.y < 44.0 or not web_pause_panel.encloses(web_pause_volume) or not web_screen_bounds.encloses(web_pause_volume):
			web_panel_targets_ok = false
			break
	_test_assert(web_panel_targets_ok, "web_touch_recruit_close_and_pause_targets_are_at_least_44_css_pixels")
	mode = GameMode.PLAYING
	active_panel = ""
	all_soldiers_unlocked = web_layout_unlock_before
	var web_upgrade_rect := Rect2(_touch_utility_rects()["upgrades"])
	var web_upgrade_css_size := web_upgrade_rect.size / web_touch_scale
	var web_upgrade_css_center := web_upgrade_rect.get_center() / web_touch_scale
	_handle_touch_action_at(web_upgrade_rect.get_center())
	var web_panel := _soldier_upgrade_panel_rect()
	var web_controls := _soldier_upgrade_control_rects(web_panel)
	var web_stretch_targets_ok := active_panel == "soldier_upgrades" and web_upgrade_css_size.x >= 44.0 and web_upgrade_css_size.y >= 44.0 and web_upgrade_css_center.distance_to(Vector2(480.0, 108.0)) < 1.0
	for web_control_value in web_controls.values():
		var web_control_css_size := Rect2(web_control_value).size / web_touch_scale
		if web_control_css_size.x < 44.0 or web_control_css_size.y < 44.0:
			web_stretch_targets_ok = false
			break
	web_stretch_targets_ok = web_stretch_targets_ok and not Rect2(web_controls["type_next"]).intersects(_touch_panel_close_rect())
	_handle_touch_action_at(_touch_panel_close_rect().get_center())
	_test_assert(touch_upgrade_geometry_ok and touch_upgrade_opened and touch_targets_large and close_does_not_overlap_next and touch_rank_after == touch_rank_before + 1 and touch_special_tab_works and active_panel.is_empty() and web_stretch_targets_ok, "touch_troop_upgrade_button_panel_purchase_and_close")
	screen_size = stored_screen_size
	touch_ui_coordinate_scale = stored_touch_ui_coordinate_scale
	_set_input_scheme(stored_input_scheme)

	# Representative real-combat coverage for status payloads, split/echo
	# generation guards, bounded persistent effects, shields and summons.
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	upgrade_effects.clear()
	var status_enemy_id := _spawn_enemy("heavy", Vector2(2200.0, 2200.0), 18, Vector2(2200.0, 2200.0))
	var status_enemy_index := _enemy_index_by_id(status_enemy_id)
	var status_snapshot := {"base_effects": {}, "special_effects": {
		"burning_ammo": {"total_burn_ratio": 0.30, "duration": 3.0},
		"toxic_payload": {"total_poison_ratio": 0.30, "duration": 5.0, "max_stacks": 3},
		"frost_arrow": {"slow_ratio": 0.25, "duration": 2.0},
		"corrosion": {"armor_reduction": 5.0, "duration": 4.0, "max_stacks": 2},
		"void_mark": {"soldier_damage_taken_bonus": 0.06, "duration": 4.0},
		"focus_mark": {"other_ally_damage_bonus": 0.07, "effect_duration": 4.0},
		"lifesteal": {"lifesteal_ratio": 0.05, "max_hp_heal_cap_per_second_ratio": 0.06},
	}}
	var status_soldier_id := _spawn_soldier("archer", Vector2(2120.0, 2200.0))
	var status_soldier: Variant = _find_soldier_by_id(status_soldier_id)
	status_soldier["upgrade_snapshot"] = status_snapshot
	status_soldier["special_runtime"] = SoldierUpgradeRuntime.create_state(status_snapshot, float(status_soldier["max_hp"]))
	status_soldier["hp"] = float(status_soldier["max_hp"]) * 0.5
	var status_hp_before := float(status_soldier["hp"])
	_resolve_soldier_enemy_hit(status_enemy_index, 80.0, status_soldier["pos"], "projectile", status_soldier_id, Dictionary(status_snapshot["special_effects"]))
	var status_enemy: Variant = _find_enemy_by_id(status_enemy_id)
	_test_assert(status_enemy != null and float(status_enemy.get("soldier_burn_ttl", 0.0)) > 0.0 and not Dictionary(status_enemy.get("soldier_poison_sources", {})).is_empty() and float(status_enemy.get("armor_break", 0.0)) > 0.0 and float(status_enemy.get("slow", 0.0)) > 0.0 and float(status_soldier["hp"]) > status_hp_before, "soldier_projectile_applies_dot_control_armor_break_marks_and_lifesteal")

	projectiles.clear()
	upgrade_effects.clear()
	var split_snapshot := {"base_effects": {}, "special_effects": {
		"split_shot": {"extra_projectiles": 2, "spread_degrees": 14.0, "damage_ratio": 0.20},
		"temporal_echo": {"every_attacks": 1, "echo_delay": 0.35, "echo_damage_ratio": 0.50},
	}}
	status_soldier["upgrade_snapshot"] = split_snapshot
	status_soldier["special_runtime"] = SoldierUpgradeRuntime.create_state(split_snapshot, float(status_soldier["max_hp"]))
	var split_context := _begin_soldier_attack(status_soldier, {"hp": 100.0, "max_hp": 100.0}, status_enemy_id, Vector2(2200.0, 2200.0))
	_spawn_projectile({"team": "friendly", "kind": "ally_arrow", "source_kind": "archer", "source_id": status_soldier_id, "target_id": status_enemy_id, "pos": Vector2(2120.0, 2200.0), "vel": Vector2.RIGHT * 720.0, "damage": 25.0, "range": 500.0, "radius": 4.0, "pierce": 1, "aoe": 0.0, "color": Color("A9D8FF"), "soldier_attack_context": split_context})
	_test_assert(projectiles.size() == 3 and _upgrade_effect_count("temporal_echo") == 1 and not bool(projectiles[1].get("allow_special_generation", true)) and not bool(projectiles[2].get("allow_special_generation", true)), "split_shot_and_temporal_echo_are_bounded_and_non_recursive")

	upgrade_effects.clear()
	for mine_index in 30:
		_add_upgrade_runtime_effect({"kind": "mine", "source_id": mine_index, "pos": Vector2(float(mine_index), 0.0), "ttl": 5.0, "team_cap": 24})
	var mine_cap_ok := _upgrade_effect_count("mine") == MAX_UPGRADE_MINES_PER_TEAM
	upgrade_effects.clear()
	for lingering_index in 20:
		_add_upgrade_runtime_effect({"kind": "lingering", "source_id": lingering_index, "pos": Vector2(float(lingering_index), 0.0), "ttl": 5.0, "team_cap": 16})
	var lingering_cap_ok := _upgrade_effect_count("lingering") == MAX_UPGRADE_LINGERING_PER_TEAM
	upgrade_effects.clear()
	for summon_index in 8:
		var summon_kind: String = ["guardian", "auto_turret", "repair_drone"][summon_index % 3]
		_add_upgrade_runtime_effect({"kind": summon_kind, "source_id": summon_index, "pos": Vector2(float(summon_index), 0.0), "ttl": 5.0, "team_cap": 5})
	_test_assert(mine_cap_ok and lingering_cap_ok and _upgrade_summon_count() == MAX_UPGRADE_SUMMONS_PER_TEAM, "persistent_upgrade_effect_caps_are_enforced")

	projectiles.clear()
	upgrade_effects.clear()
	var mine_enemy_id := _spawn_enemy("heavy", Vector2(2400.0, 2400.0), 18, Vector2(2400.0, 2400.0))
	var mine_enemy_before := float(Dictionary(_find_enemy_by_id(mine_enemy_id))["hp"])
	_add_upgrade_runtime_effect({"kind": "mine", "source_id": status_soldier_id, "source_kind": "archer", "pos": Vector2(2400.0, 2400.0), "ttl": 2.0, "warmup": 0.0, "scan": 0.0, "radius": 90.0, "damage": 120.0, "color": FIRE_ORANGE})
	_update_upgrade_effects(0.11)
	var mine_enemy_after: Variant = _find_enemy_by_id(mine_enemy_id)
	_test_assert(mine_enemy_after != null and float(mine_enemy_after["hp"]) < mine_enemy_before and _upgrade_effect_count("mine") == 0, "armed_mine_detects_enemy_and_explodes")

	var shield_test_soldier := {"id": 99001, "type": "swordsman", "pos": Vector2(2600.0, 2600.0), "hp": 100.0, "max_hp": 100.0, "defense": 0.0, "radius": 12.0, "invuln": 0.0, "upgrade_snapshot": {"base_effects": {}, "special_effects": {}}, "special_runtime": SoldierUpgradeRuntime.create_state({}, 100.0), "support_shield": 40.0, "support_shield_ttl": 4.0}
	soldiers.append(shield_test_soldier)
	_damage_soldier(shield_test_soldier, 25.0, shield_test_soldier["pos"] + Vector2.LEFT, "projectile")
	_test_assert(is_equal_approx(float(shield_test_soldier["hp"]), 100.0) and float(shield_test_soldier["support_shield"]) < 40.0, "holy_and_overheal_support_shields_absorb_damage")

	var summon_enemy_id := _spawn_enemy("heavy", Vector2(2800.0, 2800.0), 18, Vector2(2800.0, 2800.0))
	var summon_enemy_before := float(Dictionary(_find_enemy_by_id(summon_enemy_id))["hp"])
	upgrade_effects.clear()
	status_soldier["pos"] = Vector2(2760.0, 2800.0)
	_add_upgrade_runtime_effect({"kind": "guardian", "source_id": status_soldier_id, "source_kind": "archer", "pos": Vector2(2760.0, 2800.0), "ttl": 2.0, "warmup": 0.0, "shot_cd": 0.0, "owner_attack": 100.0, "effect": {"attack_ratio": 0.8, "attack_range": 280.0, "attack_interval": 1.0}, "color": Color("9BD7FF")})
	_update_upgrade_effects(0.11)
	var summon_enemy_after: Variant = _find_enemy_by_id(summon_enemy_id)
	_test_assert(summon_enemy_after != null and float(summon_enemy_after["hp"]) < summon_enemy_before, "guardian_summon_has_real_combat_attack")

	upgrade_effects.clear()
	var repair_target := {"id": 99002, "type": "tank", "domain": "ground", "pos": Vector2(2810.0, 2800.0), "hp": 200.0, "max_hp": 400.0}
	soldiers.append(repair_target)
	_add_upgrade_runtime_effect({"kind": "repair_drone", "source_id": status_soldier_id, "source_kind": "archer", "pos": Vector2(2790.0, 2800.0), "ttl": 2.0, "warmup": 0.0, "owner_attack": 100.0, "effect": {"max_hp_heal_per_second": 0.10, "healing_range": 360.0}, "color": HEAL_GREEN})
	_update_upgrade_effects(1.0)
	_test_assert(float(repair_target["hp"]) > 200.0, "repair_drone_restores_damaged_vehicle_health")

	var saved_cleanse_boss: Variant = python_boss
	var cleanse_controller: Variant = PythonBossControllerScript.new()
	cleanse_controller.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 73191)
	python_boss = cleanse_controller
	var cleanse_snapshot := {"base_effects": {}, "special_effects": {"cleanse": {"cooldown": 10.0}}}
	status_soldier["upgrade_snapshot"] = cleanse_snapshot
	status_soldier["upgrade_cooldowns"] = {}
	status_soldier["burn_ttl"] = 2.0
	status_soldier["slow_ttl"] = 2.0
	status_soldier["paralysis_ttl"] = 2.0
	cleanse_controller.debug_set_unit_status("soldier", status_soldier_id, {"poison_stacks": 2, "poison_ttl": 5.0, "pool_slow": 0.40, "pool_slow_ttl": 3.0, "off_balance": 0.4})
	_update_soldier_passive_upgrades(status_soldier, 0.0)
	var cleansed_boss_status: Dictionary = cleanse_controller.get_unit_status("soldier", status_soldier_id)
	_test_assert(cleansed_boss_status.is_empty() and is_zero_approx(float(status_soldier.get("burn_ttl", 0.0))) and is_zero_approx(float(status_soldier.get("slow_ttl", 0.0))) and is_zero_approx(float(status_soldier.get("paralysis_ttl", 0.0))) and float(Dictionary(status_soldier.get("upgrade_cooldowns", {})).get("cleanse", 0.0)) > 0.0, "cleanse_removes_real_python_boss_and_local_statuses")
	python_boss = saved_cleanse_boss

	var saved_chaos_projectiles := chaos_runtime_projectiles.duplicate(true)
	var saved_aionis_projectiles := aionis_runtime_projectiles.duplicate(true)
	chaos_runtime_projectiles.clear()
	aionis_runtime_projectiles.clear()
	var flare_snapshot := {"base_effects": {}, "special_effects": {"air_flares": {"cooldown": 14.0}}}
	status_soldier["upgrade_snapshot"] = flare_snapshot
	status_soldier["upgrade_cooldowns"] = {}
	chaos_runtime_projectiles.append({"kind": "homing_missile", "pos": Vector2(status_soldier["pos"]) + Vector2(80.0, 0.0), "homing": true, "ttl": 4.5})
	_update_soldier_passive_upgrades(status_soldier, 0.0)
	var chaos_flare_ok := chaos_runtime_projectiles.is_empty() and float(Dictionary(status_soldier.get("upgrade_cooldowns", {})).get("air_flares", 0.0)) > 0.0
	status_soldier["upgrade_cooldowns"] = {}
	aionis_runtime_projectiles.append({"kind": "aionis_reflected_shot", "pos": Vector2(status_soldier["pos"]) + Vector2(90.0, 0.0), "homing": true, "ttl": 3.2})
	_update_soldier_passive_upgrades(status_soldier, 0.0)
	var aionis_flare_ok := aionis_runtime_projectiles.is_empty() and float(Dictionary(status_soldier.get("upgrade_cooldowns", {})).get("air_flares", 0.0)) > 0.0
	_test_assert(chaos_flare_ok and aionis_flare_ok, "air_flares_intercepts_real_chaos_and_aionis_homing_projectiles")
	chaos_runtime_projectiles.append_array(saved_chaos_projectiles)
	aionis_runtime_projectiles.append_array(saved_aionis_projectiles)

	var boss_upgrade_paths := _self_test_soldier_boss_execution_and_lifesteal()
	_test_assert(bool(boss_upgrade_paths.get("python", false)) and bool(boss_upgrade_paths.get("chaos", false)) and bool(boss_upgrade_paths.get("aionis", false)), "execution_and_lifesteal_cover_all_three_boss_paths")

	enemies.clear()
	var lethal_primary_id := _spawn_enemy("grunt", Vector2(3200.0, 3200.0), 1, Vector2(3200.0, 3200.0))
	var chain_target_id := _spawn_enemy("heavy", Vector2(3260.0, 3200.0), 1, Vector2(3260.0, 3200.0))
	var ricochet_target_id := _spawn_enemy("heavy", Vector2(3320.0, 3200.0), 1, Vector2(3320.0, 3200.0))
	var lethal_primary: Variant = _find_enemy_by_id(lethal_primary_id)
	lethal_primary["hp"] = 1.0
	var chain_hp_before := float(Dictionary(_find_enemy_by_id(chain_target_id))["hp"])
	var ricochet_hp_before := float(Dictionary(_find_enemy_by_id(ricochet_target_id))["hp"])
	var lethal_followups := {"chain_lightning": {"jumps": 1, "jump_range": 180.0, "jump_damage_ratio": 0.50}, "ricochet": {"extra_targets": 1, "ricochet_range": 180.0, "ricochet_damage_ratio": 0.50}}
	_resolve_soldier_enemy_hit(_enemy_index_by_id(lethal_primary_id), 120.0, Vector2(3200.0, 3200.0), "projectile", status_soldier_id, lethal_followups, 0.0, true)
	_test_assert(_find_enemy_by_id(lethal_primary_id) == null and float(Dictionary(_find_enemy_by_id(chain_target_id))["hp"]) < chain_hp_before and float(Dictionary(_find_enemy_by_id(ricochet_target_id))["hp"]) < ricochet_hp_before, "chain_and_ricochet_continue_after_lethal_primary_hit")

	enemies.clear()
	var expiry_enemy_id := _spawn_enemy("heavy", Vector2(3500.0, 3500.0), 1, Vector2(3500.0, 3500.0))
	var expiry_enemy: Variant = _find_enemy_by_id(expiry_enemy_id)
	expiry_enemy["slow"] = 0.01
	expiry_enemy["slow_factor"] = 0.55
	expiry_enemy["armor_break"] = 0.01
	expiry_enemy["armor_reduction"] = 18.0
	expiry_enemy["soldier_corrosion_stacks"] = 3
	_update_enemies(0.02)
	var expiry_reset_ok := is_zero_approx(float(expiry_enemy.get("slow_factor", -1.0))) and is_zero_approx(float(expiry_enemy.get("armor_reduction", -1.0))) and int(expiry_enemy.get("soldier_corrosion_stacks", -1)) == 0
	upgrade_effects.clear()
	expiry_enemy["defense"] = 15.0
	expiry_enemy["hp"] = 100.0
	var lingering_projectile := {"allow_special_generation": true, "upgrade_impact_triggered": false, "source_id": status_soldier_id, "source_kind": "archer", "damage": 100.0, "armor_penetration": 7.0, "radius": 4.0, "color": Color.WHITE, "soldier_specials": {"lingering_projectile": {"first_hit_ratio": 0.70, "linger_duration": 2.0, "tick_interval": 0.5, "tick_damage_ratio": 0.12, "max_per_unit": 2, "team_cap": 16}}}
	_trigger_soldier_projectile_impact_effects(lingering_projectile, Vector2(expiry_enemy["pos"]), expiry_enemy_id)
	_apply_lingering_first_hit_damage(lingering_projectile)
	var lingering_effect: Dictionary = upgrade_effects[0]
	var lingering_hp_before := float(expiry_enemy["hp"])
	_update_single_upgrade_effect(lingering_effect, 0.01)
	var lingering_tick_damage := lingering_hp_before - float(expiry_enemy["hp"])
	var expected_lingering_tick := _calculate_damage(12.0, 15.0 - 7.0)
	var lingering_ok := is_equal_approx(float(lingering_projectile["damage"]), 70.0) and is_equal_approx(float(lingering_effect.get("armor_penetration", -1.0)), 7.0) and is_equal_approx(lingering_tick_damage, expected_lingering_tick) and not is_equal_approx(lingering_tick_damage, _calculate_damage(12.0, 15.0))
	var gravity_fine := {"pull_distance": 70.0, "pull_duration": 2.5, "pull_elapsed": 0.0}
	var gravity_coarse := gravity_fine.duplicate(true)
	var fine_total := 0.0
	for _gravity_tick in 25:
		fine_total += _gravity_pull_step(gravity_fine, 0.1)
	var coarse_total := 0.0
	for _gravity_tick in 5:
		coarse_total += _gravity_pull_step(gravity_coarse, 0.5)
	_test_assert(expiry_reset_ok and lingering_ok and is_equal_approx(fine_total, 70.0) and is_equal_approx(coarse_total, 70.0), "expiration_lingering_and_gravity_numeric_semantics")

	upgrade_effects.clear()
	var guardian_snapshot := {"base_effects": {}, "special_effects": {"guardian": {"ttl": 14.0, "hp_ratio": 1.60, "attack_ratio": 0.45, "attack_range": 280.0, "attack_interval": 1.10, "max_per_owner": 2, "team_summon_cap": 5}}}
	status_soldier["upgrade_snapshot"] = guardian_snapshot
	status_soldier["upgrade_cooldowns"] = {}
	_try_spawn_soldier_upgrade_summon(status_soldier, "guardian")
	var guardian_effect: Dictionary = upgrade_effects[0]
	var guardian_expected_hp := float(status_soldier["max_hp"]) * 1.60
	var guardian_spawn_ok := is_equal_approx(float(guardian_effect.get("hp", 0.0)), guardian_expected_hp) and is_equal_approx(float(guardian_effect.get("max_hp", 0.0)), guardian_expected_hp)
	_damage_guardians_in_area(Vector2(guardian_effect["pos"]), 30.0, 25.0)
	var guardian_damage_ok := is_equal_approx(float(guardian_effect["hp"]), guardian_expected_hp - 25.0)
	_damage_guardian(guardian_effect, guardian_expected_hp * 2.0, Vector2(guardian_effect["pos"]))
	var guardian_death_ok := bool(guardian_effect.get("defeated", false)) and is_zero_approx(float(guardian_effect.get("hp", 1.0))) and is_zero_approx(float(guardian_effect.get("ttl", 1.0)))
	_test_assert(guardian_spawn_ok and guardian_damage_ok and guardian_death_ok and bool(boss_upgrade_paths.get("priest_marks", false)), "guardian_health_damage_death_and_priest_marks_all_bosses")

	_test_assert(GameLocalization.translate("開始遠征", "en") == "Start Expedition" and GameLocalization.translate("腐沼蟒皇・薩迦", "en") == "Corrupt Python Emperor · Saga" and GameLocalization.translate("實戰比較：重型大砲 112 傷害 ＞ 普通大砲 72 傷害", "en") == "Live-fire comparison: Heavy Cannon 112 damage > Standard Cannon 72 damage" and GameLocalization.translate("測試場景不會覆寫玩家存檔。", "en") == "Test showcases never overwrite your player save.", "english_localization_core_terms")
	var technology_name_translations := {
		"重型大砲": "Heavy Cannon", "普通大砲": "Standard Cannon", "火槍手": "Musketeer",
		"突擊步槍手": "Assault Rifleman", "坦克": "Tank", "火箭炮": "Rocket Artillery",
		"加特林": "Gatling Gun", "直升機": "Helicopter", "轟炸機": "Bomber", "UFO": "UFO",
	}
	var technology_english_ok := true
	for technology_name in technology_name_translations:
		if GameLocalization.translate(str(technology_name), "en") != str(technology_name_translations[technology_name]):
			technology_english_ok = false
			break
	_test_assert(technology_english_ok, "english_localization_all_new_technology_names")
	var castle_tier_english_ok := GameLocalization.translate("砲兵要塞", "en") == "Artillery Citadel" and GameLocalization.translate("星界終焉城", "en") == "Astral Final Citadel"
	_test_assert(castle_tier_english_ok and GameLocalization.translate("外牆已突破", "en") == "Outer Wall Breached", "english_localization_castle_tiers_and_outer_wall")
	_test_assert(GameLocalization.translate("駐守", "en") == "Garrison" and GameLocalization.translate("攻城", "en") == "Siege" and GameLocalization.translate("軍令中心", "en") == "Command Center" and GameLocalization.translate("1 跟隨　2 防守　3 攻擊　4 撤退　5 駐守　6 攻城", "en") == "1 Follow   2 Defend   3 Attack   4 Retreat   5 Garrison   6 Siege", "english_localization_all_six_army_commands")
	_test_assert(GameLocalization.translate("重型大砲　$520", "en") == "Heavy Cannon · $520" and GameLocalization.translate("已有 1　HP 190　傷害 112　射程 650", "en") == "Owned 1 · HP 190 · Damage 112 · Range 650", "english_recruit_rows_have_no_mixed_chinese_labels")
	_test_assert(GameLocalization.translate("蟒蛇 Boss 巢穴 Lv.12", "en") == "Python Boss Lair Lv.12" and GameLocalization.translate("腐沼蟒皇・薩迦棲息中", "en") == "Corrupt Python Emperor · Saga Dwells Here" and int(GameConfig.SNAKE_NEST_SETTINGS["spacing_x"]) == 11, "python_boss_lair_name_and_density_are_bilingual")
	_initialize_empty_player()
	mode = GameMode.TITLE
	var emulated_title_press := InputEventMouseButton.new()
	emulated_title_press.device = InputEvent.DEVICE_ID_EMULATION
	emulated_title_press.button_index = MOUSE_BUTTON_LEFT
	emulated_title_press.pressed = true
	emulated_title_press.position = screen_size * 0.5 + Vector2(0, 82)
	_input(emulated_title_press)
	_test_assert(mode == GameMode.TITLE and str(player["class_id"]).is_empty(), "touch_compatibility_mouse_press_is_ignored")
	_initialize_empty_player()
	mode = GameMode.TITLE
	class_select_pointer_guard_until_msec = -10000
	var title_start_point := screen_size * 0.5 + Vector2(0, 82)
	_handle_ui_click(title_start_point)
	_handle_ui_click(title_start_point)
	_test_assert(mode == GameMode.CLASS_SELECT and str(player["class_id"]).is_empty(), "title_touch_cannot_fall_through_to_center_mage_card")
	var selected_touch_classes: Array[String] = []
	var select_card_width: float = min(330.0, (screen_size.x - 110.0) / 3.0)
	var select_card_total: float = select_card_width * 3.0 + 24.0 * 2.0
	var select_card_start_x: float = (screen_size.x - select_card_total) * 0.5
	for select_index in 3:
		_initialize_empty_player()
		mode = GameMode.CLASS_SELECT
		class_select_pointer_guard_until_msec = -10000
		var select_point := Vector2(select_card_start_x + float(select_index) * (select_card_width + 24.0) + select_card_width * 0.5, screen_size.y * 0.45)
		_handle_ui_click(select_point)
		selected_touch_classes.append(str(player["class_id"]))
	_test_assert(selected_touch_classes == ["archer", "mage", "warrior"] and touch_move_pointer < 0 and touch_aim_pointer < 0 and not attack_held, "touch_can_select_each_class_without_residual_action")
	_start_new_game("warrior")
	_set_input_scheme(InputScheme.KEYBOARD_MOUSE)
	var touch_move_press := InputEventScreenTouch.new()
	touch_move_press.index = 41
	touch_move_press.pressed = true
	touch_move_press.position = _touch_move_center() + Vector2(TOUCH_STICK_RADIUS, 0.0)
	_input(touch_move_press)
	_test_assert(_is_touch_scheme() and touch_move_pointer == 41 and touch_move_vector.x > 0.95, "touch_event_selects_virtual_joystick")
	var touch_move_start: Vector2 = player["pos"]
	_update_player(0.20)
	_test_assert(Vector2(player["pos"]).x > touch_move_start.x + 10.0, "virtual_joystick_moves_player")
	var touch_move_release := InputEventScreenTouch.new()
	touch_move_release.index = 41
	touch_move_release.pressed = false
	touch_move_release.position = touch_move_press.position
	_input(touch_move_release)
	var keyboard_event := InputEventKey.new()
	keyboard_event.keycode = KEY_W
	keyboard_event.pressed = true
	_input(keyboard_event)
	_test_assert(input_scheme == InputScheme.KEYBOARD_MOUSE and touch_move_pointer < 0 and touch_move_vector == Vector2.ZERO, "keyboard_event_restores_desktop_controls")
	player["level"] = 10
	player["special_cd"] = 0.0
	_set_input_scheme(InputScheme.TOUCH)
	var touch_special := InputEventScreenTouch.new()
	touch_special.index = 42
	touch_special.pressed = true
	touch_special.position = _touch_special_rect().get_center()
	_input(touch_special)
	_test_assert(float(player["special_cd"]) > 0.0, "touch_special_button_casts_skill")

	var touch_flow_screen_before := screen_size
	var touch_flow_scale_before := touch_ui_coordinate_scale
	var touch_flow_scheme_before := input_scheme
	var touch_flow_tutorial_before := tutorial_visible
	var touch_flow_command_before := soldier_command
	var touch_flow_command_point_before := command_point
	var touch_flow_command_target_before := command_target_id
	var touch_flow_command_castle_before := command_castle_id
	touch_ui_coordinate_scale = web_touch_scale
	screen_size = Vector2(844.0 * web_touch_scale, 720.0)
	_set_input_scheme(InputScheme.TOUCH)
	_reset_touch_inputs()
	mode = GameMode.PLAYING
	active_panel = ""
	tutorial_visible = false

	player["attack_cd"] = 0.0
	player["dash_timer"] = 0.0
	var touch_attack_press := InputEventScreenTouch.new()
	touch_attack_press.index = 51
	touch_attack_press.pressed = true
	touch_attack_press.position = _touch_aim_center() + Vector2.UP * TOUCH_STICK_RADIUS * web_touch_scale
	_input(touch_attack_press)
	var touch_attack_pressed_state_value: Variant = JSON.parse_string(render_game_to_text())
	var touch_attack_pressed_input := Dictionary(Dictionary(touch_attack_pressed_state_value).get("input", {})) if touch_attack_pressed_state_value is Dictionary else {}
	var touch_attack_pressed_controls := Dictionary(touch_attack_pressed_input.get("virtual_controls", {}))
	var touch_attack_pressed_control := Dictionary(touch_attack_pressed_controls.get("attack", {}))
	var touch_attack_render_pressed_ok := bool(touch_attack_pressed_input.get("attack_held", false)) and bool(touch_attack_pressed_control.get("held", false)) and int(touch_attack_pressed_control.get("pointer", -1)) == 51 and Dictionary(touch_attack_pressed_controls.get("utility", {})).size() == 10
	var touch_attack_aim_ok := attack_held and touch_aim_pointer == 51 and touch_aim_vector.is_equal_approx(Vector2.UP)
	_update_player(0.02)
	var touch_attack_executed := float(player["attack_cd"]) > 0.0 and Vector2(player["facing"]).dot(Vector2.UP) > 0.99
	var touch_attack_release := InputEventScreenTouch.new()
	touch_attack_release.index = 51
	touch_attack_release.pressed = false
	touch_attack_release.position = touch_attack_press.position
	_input(touch_attack_release)
	var touch_attack_released_state_value: Variant = JSON.parse_string(render_game_to_text())
	var touch_attack_released_input := Dictionary(Dictionary(touch_attack_released_state_value).get("input", {})) if touch_attack_released_state_value is Dictionary else {}
	var touch_attack_released_control := Dictionary(Dictionary(touch_attack_released_input.get("virtual_controls", {})).get("attack", {}))
	player["attack_cd"] = 0.0
	_update_player(0.02)
	var touch_attack_stopped := not attack_held and touch_aim_pointer < 0 and not bool(touch_attack_released_input.get("attack_held", true)) and not bool(touch_attack_released_control.get("held", true)) and is_zero_approx(float(player["attack_cd"]))
	_test_assert(touch_attack_render_pressed_ok and touch_attack_aim_ok and touch_attack_executed and touch_attack_stopped, "touch_attack_stick_holds_aims_attacks_and_stops_on_release")

	var touch_command_entry := InputEventScreenTouch.new()
	touch_command_entry.index = 52
	touch_command_entry.pressed = true
	touch_command_entry.position = Rect2(_touch_utility_rects()["command"]).get_center()
	_input(touch_command_entry)
	var touch_command_opened := active_panel == "command"
	var touch_command_panel := _command_panel_rect()
	var touch_command_choice := InputEventScreenTouch.new()
	touch_command_choice.index = 53
	touch_command_choice.pressed = true
	touch_command_choice.position = _command_button_rect(1, touch_command_panel).get_center()
	_input(touch_command_choice)
	_test_assert(touch_command_opened and soldier_command == "防守" and active_panel.is_empty(), "touch_command_utility_opens_and_selects_order")

	var touch_recruit_position_before: Vector2 = Vector2(player["pos"])
	var touch_recruit_money_before := int(player["money"])
	var touch_recruit_count_before := soldiers.size()
	player["pos"] = Vector2(999999.0, 999999.0)
	var touch_recruit_far_state_value: Variant = JSON.parse_string(render_game_to_text())
	var touch_recruit_far_input := Dictionary(Dictionary(touch_recruit_far_state_value).get("input", {})) if touch_recruit_far_state_value is Dictionary else {}
	var touch_recruit_far_utility := Dictionary(Dictionary(touch_recruit_far_input.get("virtual_controls", {})).get("utility", {}))
	var touch_recruit_far_disabled := not bool(Dictionary(touch_recruit_far_utility.get("recruit", {})).get("enabled", true))
	player["pos"] = HOUSE_POS
	player["money"] = 100000
	active_panel = ""
	last_recruit_purchase_msec = -10000
	last_recruit_purchase_type = ""
	var touch_recruit_entry := InputEventScreenTouch.new()
	touch_recruit_entry.index = 54
	touch_recruit_entry.pressed = true
	touch_recruit_entry.position = Rect2(_touch_utility_rects()["recruit"]).get_center()
	_input(touch_recruit_entry)
	var touch_recruit_opened := active_panel == "recruit"
	var touch_recruit_state_value: Variant = JSON.parse_string(render_game_to_text())
	var touch_recruit_state_input := Dictionary(Dictionary(touch_recruit_state_value).get("input", {})) if touch_recruit_state_value is Dictionary else {}
	var touch_recruit_state_controls := Dictionary(touch_recruit_state_input.get("virtual_controls", {}))
	var touch_recruit_enabled_state := bool(Dictionary(Dictionary(touch_recruit_state_controls.get("utility", {})).get("recruit", {})).get("enabled", false)) and Array(touch_recruit_state_controls.get("recruit_buy", [])).size() == _recruitable_soldier_order().size()
	var touch_recruit_type := str(_recruitable_soldier_order()[0])
	var touch_recruit_type_before := _count_soldier_type(touch_recruit_type)
	var touch_recruit_cost := _soldier_recruit_cost(touch_recruit_type)
	var touch_recruit_buy := InputEventScreenTouch.new()
	touch_recruit_buy.index = 55
	touch_recruit_buy.pressed = true
	touch_recruit_buy.position = _recruit_buy_rect(0, _recruit_panel_rect()).get_center()
	_input(touch_recruit_buy)
	var touch_recruit_bought := _count_soldier_type(touch_recruit_type) == touch_recruit_type_before + 1 and int(player["money"]) == 100000 - touch_recruit_cost
	_test_assert(touch_recruit_far_disabled and touch_recruit_opened and touch_recruit_enabled_state and touch_recruit_bought, "touch_recruit_utility_reports_availability_opens_and_buys")
	if soldiers.size() > touch_recruit_count_before:
		soldiers.resize(touch_recruit_count_before)
	player["pos"] = touch_recruit_position_before
	player["money"] = touch_recruit_money_before
	active_panel = ""

	var touch_pause_entry := InputEventScreenTouch.new()
	touch_pause_entry.index = 56
	touch_pause_entry.pressed = true
	touch_pause_entry.position = Rect2(_touch_utility_rects()["pause"]).get_center()
	_input(touch_pause_entry)
	var touch_pause_state_value: Variant = JSON.parse_string(render_game_to_text())
	var touch_pause_state := Dictionary(touch_pause_state_value) if touch_pause_state_value is Dictionary else {}
	var touch_pause_input := Dictionary(touch_pause_state.get("input", {}))
	var touch_pause_controls_state := Dictionary(touch_pause_input.get("virtual_controls", {}))
	var touch_pause_opened := mode == GameMode.PAUSED and str(touch_pause_state.get("mode", "")) == "paused" and Array(touch_pause_controls_state.get("pause_actions", [])).size() == _pause_actions().size()
	var touch_resume := InputEventScreenTouch.new()
	touch_resume.index = 57
	touch_resume.pressed = true
	touch_resume.position = _pause_button_rect(_pause_actions().find("resume")).get_center()
	_input(touch_resume)
	_test_assert(touch_pause_opened and mode == GameMode.PLAYING, "touch_pause_utility_opens_menu_and_resume_returns_to_play")

	soldier_command = touch_flow_command_before
	command_point = touch_flow_command_point_before
	command_target_id = touch_flow_command_target_before
	command_castle_id = touch_flow_command_castle_before
	tutorial_visible = touch_flow_tutorial_before
	screen_size = touch_flow_screen_before
	touch_ui_coordinate_scale = touch_flow_scale_before
	_set_input_scheme(touch_flow_scheme_before)
	_reset_touch_inputs()
	active_panel = "map"
	var touch_close := InputEventScreenTouch.new()
	touch_close.index = 43
	touch_close.pressed = true
	touch_close.position = _touch_panel_close_rect().get_center()
	_input(touch_close)
	_test_assert(active_panel == "", "touch_panel_close_button")
	active_panel = "command"
	touch_close.index = 45
	touch_close.position = _touch_panel_close_rect().get_center()
	_input(touch_close)
	_test_assert(active_panel == "", "touch_command_panel_close_button")
	var dynamic_phase_en := GameLocalization.translate("蟒皇進入第 3 階段：狂暴蟒皇", "en")
	_test_assert(dynamic_phase_en == "Python Emperor entered Phase 3: Frenzied Python Emperor", "english_localization_dynamic_boss_phase")
	var ending_mode_before_test := mode
	var ending_elapsed_before_test := ending_elapsed
	mode = GameMode.ENDING
	ending_elapsed = 2.5
	var title_ending_state := _ending_state()
	ending_elapsed = 6.75
	var caviar_ending_state := _ending_state()
	ending_elapsed = 9.6
	var finished_ending_state := _ending_state()
	_test_assert(float(title_ending_state["title_alpha"]) == 1.0 and float(title_ending_state["caviar_alpha"]) == 0.0 and float(caviar_ending_state["title_alpha"]) == 0.0 and float(caviar_ending_state["caviar_alpha"]) == 1.0 and float(finished_ending_state["caviar_alpha"]) == 0.0, "ending_title_and_caviar_timeline_is_deterministic")
	mode = ending_mode_before_test
	ending_elapsed = ending_elapsed_before_test
	var landscape_screen := screen_size
	var unlock_before_mobile_layout := all_soldiers_unlocked
	all_soldiers_unlocked = true
	screen_size = Vector2(844.0, 390.0)
	_set_input_scheme(InputScheme.TOUCH)
	var unlocked_mobile_panel := _recruit_panel_rect()
	var mobile_last_recruit := _recruit_item_rect(_recruitable_soldier_order().size() - 1, unlocked_mobile_panel)
	_test_assert(_recruitable_soldier_order().size() == 16 and mobile_last_recruit.end.x <= unlocked_mobile_panel.end.x + 0.1 and mobile_last_recruit.end.y <= unlocked_mobile_panel.end.y + 0.1 and _recruit_buy_rect(15, unlocked_mobile_panel).size.y >= 36.0, "mobile_landscape_all_sixteen_unlocked_recruits_fit")
	all_soldiers_unlocked = unlock_before_mobile_layout
	screen_size = Vector2(720.0, 1280.0)
	_test_assert(_needs_landscape_rotation(), "portrait_touch_requests_landscape_rotation")
	screen_size = landscape_screen
	tutorial_visible = false
	var touch_guide := InputEventScreenTouch.new()
	touch_guide.index = 44
	touch_guide.pressed = true
	touch_guide.position = Rect2(_touch_utility_rects()["guide"]).get_center()
	_input(touch_guide)
	_test_assert(tutorial_visible, "touch_guide_button_reopens_tutorial")
	mode = GameMode.PAUSED
	var touch_pause_css_scale := maxf(1.0, touch_ui_coordinate_scale)
	_test_assert(_pause_button_rect(0).size.y / touch_pause_css_scale >= 44.0 and _pause_language_rect().size.y / touch_pause_css_scale >= 44.0, "touch_pause_targets_are_enlarged")
	mode = GameMode.PLAYING
	GameSaveManager.delete_save(invalid_path)
	GameSaveManager.delete_save(test_path)

	var result := {"passed": _self_test_passed, "failed": _self_test_failed}
	print("SELF_TEST_RESULT=" + JSON.stringify(result))
	if _self_test_failed == 0:
		print("SELF_TEST_PASS")
	else:
		print("SELF_TEST_FAIL")
	get_tree().quit(0 if _self_test_failed == 0 else 1)


func _chunk_generated_positions_are_clear(chunk: Dictionary) -> bool:
	for obstacle in chunk["obstacles"]:
		if chunk["castle"] != null and Vector2(obstacle["position"]).distance_to(chunk["castle"]["position"]) < float(obstacle["radius"]) + 185.0:
			return false
		if chunk["camp"] != null and Vector2(obstacle["position"]).distance_to(chunk["camp"]["position"]) < float(obstacle["radius"]) + 92.0:
			return false
	for spawn in chunk["enemy_spawns"]:
		for obstacle in chunk["obstacles"]:
			if Vector2(spawn["position"]).distance_to(obstacle["position"]) < float(obstacle["radius"]) + 24.0:
				return false
		if chunk["castle"] != null and Vector2(spawn["position"]).distance_to(chunk["castle"]["position"]) < 205.0:
			return false
		if chunk["camp"] != null and Vector2(spawn["position"]).distance_to(chunk["camp"]["position"]) < 125.0:
			return false
	return true


func _test_assert(condition: bool, label: String) -> void:
	if condition:
		_self_test_passed += 1
		print("[PASS] " + label)
	else:
		_self_test_failed += 1
		push_error("[FAIL] " + label)


func _self_test_soldier_boss_execution_and_lifesteal() -> Dictionary:
	var saved_enemies := enemies.duplicate(true)
	var saved_python_boss: Variant = python_boss
	var saved_chaos_boss: Variant = chaos_boss
	var saved_aionis_boss: Variant = aionis_boss
	var saved_final_boss_defeated := final_boss_defeated
	var saved_timeless_gate_unlocked := timeless_gate_unlocked
	var saved_aionis_boss_defeated := aionis_boss_defeated
	var saved_aionis_hazards := aionis_runtime_hazards.duplicate(true)
	var saved_boss_debuffs := soldier_boss_debuffs.duplicate(true)
	var test_id := 99103
	var snapshot := {"base_effects": {}, "special_effects": {
		"execution_protocol": {"target_hp_threshold": 0.35, "damage_bonus_ratio": 0.50},
		"lifesteal": {"lifesteal_ratio": 0.20, "max_hp_heal_cap_per_second_ratio": 0.20},
	}}
	var test_soldier := {
		"id": test_id, "type": "swordsman", "pos": Vector2.ZERO,
		"hp": 50.0, "max_hp": 100.0, "upgrade_snapshot": snapshot,
		"special_runtime": SoldierUpgradeRuntime.create_state(snapshot, 100.0),
		"lifesteal_window": -1, "lifesteal_used": 0.0,
	}
	soldiers.append(test_soldier)
	var priest_id := 99104
	var priest_snapshot := {"base_effects": {}, "special_effects": {"void_mark": {"duration": 4.0, "soldier_damage_taken_bonus": 0.06}, "focus_mark": {"effect_duration": 4.0, "other_ally_damage_bonus": 0.08, "boss_multiplier": 0.5}}}
	var test_priest := {"id": priest_id, "type": "priest", "pos": Vector2.ZERO, "hp": 100.0, "max_hp": 100.0, "support_range": 520.0, "upgrade_snapshot": priest_snapshot, "upgrade_cooldowns": {}, "special_runtime": SoldierUpgradeRuntime.create_state(priest_snapshot, 100.0)}
	soldiers.append(test_priest)
	var results := {"python": false, "chaos": false, "aionis": false, "priest_marks": false, "priest_python": false, "priest_chaos": false, "priest_aionis": false}
	var all_priest_marks := true
	enemies.clear()
	aionis_runtime_hazards.clear()
	soldier_boss_debuffs = {}

	var python_controller: Variant = PythonBossControllerScript.new()
	python_controller.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 73192)
	python_controller.debug_set_hp_ratio(0.20)
	python_controller.force_engage()
	python_boss = python_controller
	chaos_boss = null
	aionis_boss = null
	final_boss_defeated = false
	timeless_gate_unlocked = false
	aionis_boss_defeated = false
	var python_proxy := _active_boss_target_proxy()
	test_priest["pos"] = Vector2(python_proxy["pos"])
	test_priest["upgrade_cooldowns"] = {}
	soldier_boss_debuffs = {}
	var python_priest_cast := _try_priest_combat_mark(test_priest)
	var python_priest_mark := python_priest_cast and float(soldier_boss_debuffs.get("void_ttl", 0.0)) > 0.0 and float(soldier_boss_debuffs.get("focus_ttl", 0.0)) > 0.0
	results["priest_python"] = python_priest_mark
	all_priest_marks = all_priest_marks and python_priest_mark
	var python_context := _begin_soldier_attack(test_soldier, python_proxy, BOSS_ENTITY_ID, Vector2(python_proxy["pos"]))
	var python_hit := _receive_active_boss_hit("upgrade_path_python", "swordsman", test_id, 240.0 * float(python_context["damage_multiplier"]), Vector2(python_proxy["pos"]), "melee")
	results["python"] = bool(python_context.get("execution_triggered", false)) and bool(python_hit.get("accepted", false)) and float(test_soldier["hp"]) > 50.0

	var chaos_controller: Variant = ChaosBossControllerScript.new()
	chaos_controller.initialize(GameConfig.CHAOS_BOSS_CONFIG, 60, 73193)
	chaos_controller.debug_set_hp_ratio(0.20)
	chaos_controller.force_engage(Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"]) + Vector2(300.0, 0.0))
	python_boss = null
	chaos_boss = chaos_controller
	test_soldier["hp"] = 50.0
	test_soldier["lifesteal_window"] = -1
	test_soldier["lifesteal_used"] = 0.0
	test_soldier["special_runtime"] = SoldierUpgradeRuntime.create_state(snapshot, 100.0)
	var chaos_proxy := _active_boss_target_proxy()
	test_priest["pos"] = Vector2(chaos_proxy["pos"])
	test_priest["upgrade_cooldowns"] = {}
	soldier_boss_debuffs = {}
	var chaos_priest_cast := _try_priest_combat_mark(test_priest)
	var chaos_priest_mark := chaos_priest_cast and float(soldier_boss_debuffs.get("void_ttl", 0.0)) > 0.0 and float(soldier_boss_debuffs.get("focus_ttl", 0.0)) > 0.0
	results["priest_chaos"] = chaos_priest_mark
	all_priest_marks = all_priest_marks and chaos_priest_mark
	var chaos_context := _begin_soldier_attack(test_soldier, chaos_proxy, BOSS_ENTITY_ID, Vector2(chaos_proxy["pos"]))
	var chaos_hit := _receive_active_boss_hit("upgrade_path_chaos", "swordsman", test_id, 240.0 * float(chaos_context["damage_multiplier"]), Vector2(chaos_proxy["pos"]), "melee")
	results["chaos"] = bool(chaos_context.get("execution_triggered", false)) and bool(chaos_hit.get("accepted", false)) and float(test_soldier["hp"]) > 50.0

	var aionis_controller: Variant = AionisBossControllerScript.new()
	aionis_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 73194)
	aionis_controller.debug_set_hp_ratio(0.18)
	aionis_controller.force_engage(Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"]) + Vector2(340.0, 0.0))
	chaos_boss = null
	aionis_boss = aionis_controller
	timeless_gate_unlocked = true
	test_soldier["hp"] = 50.0
	test_soldier["lifesteal_window"] = -1
	test_soldier["lifesteal_used"] = 0.0
	test_soldier["special_runtime"] = SoldierUpgradeRuntime.create_state(snapshot, 100.0)
	var aionis_proxy := _active_boss_target_proxy()
	test_priest["pos"] = Vector2(aionis_proxy["pos"])
	test_priest["upgrade_cooldowns"] = {}
	soldier_boss_debuffs = {}
	var aionis_priest_cast := _try_priest_combat_mark(test_priest)
	var aionis_priest_mark := aionis_priest_cast and float(soldier_boss_debuffs.get("void_ttl", 0.0)) > 0.0 and float(soldier_boss_debuffs.get("focus_ttl", 0.0)) > 0.0
	results["priest_aionis"] = aionis_priest_mark
	all_priest_marks = all_priest_marks and aionis_priest_mark
	var aionis_context := _begin_soldier_attack(test_soldier, aionis_proxy, BOSS_ENTITY_ID, Vector2(aionis_proxy["pos"]))
	var aionis_hit := _receive_active_boss_hit("upgrade_path_aionis", "swordsman", test_id, 240.0 * float(aionis_context["damage_multiplier"]), Vector2(aionis_proxy["pos"]), "melee")
	results["aionis"] = bool(aionis_context.get("execution_triggered", false)) and bool(aionis_hit.get("accepted", false)) and float(test_soldier["hp"]) > 50.0
	results["priest_marks"] = all_priest_marks

	for soldier_index in range(soldiers.size() - 1, -1, -1):
		if int(soldiers[soldier_index].get("id", -1)) in [test_id, priest_id]:
			soldiers.remove_at(soldier_index)
	python_boss = saved_python_boss
	chaos_boss = saved_chaos_boss
	aionis_boss = saved_aionis_boss
	final_boss_defeated = saved_final_boss_defeated
	timeless_gate_unlocked = saved_timeless_gate_unlocked
	aionis_boss_defeated = saved_aionis_boss_defeated
	aionis_runtime_hazards.clear()
	aionis_runtime_hazards.append_array(saved_aionis_hazards)
	soldier_boss_debuffs = saved_boss_debuffs
	enemies.clear()
	enemies.append_array(saved_enemies)
	return results


func _self_test_chaos_boss_skills() -> Dictionary:
	var expected: Array[String] = [
		"meteor", "destruction_beam", "energy_barrage", "shockwave", "black_hole",
		"summon_monsters", "homing_missiles", "lightning", "rift_dash", "total_annihilation",
	]
	var configured_ids: Array[String] = []
	for skill_value in Array(GameConfig.CHAOS_BOSS_CONFIG.get("skills", [])):
		configured_ids.append(str(Dictionary(skill_value).get("id", "")))
	var exact_ten := configured_ids == expected and ChaosBossControllerScript.SKILL_IDS == expected
	var all_selected := true
	var all_harmful := true
	var missiles_expire := false
	var moved := false
	var phase_three := false
	var home := Vector2(GameConfig.CHAOS_BOSS_CONFIG["home_position"])
	var test_context := {
		"player": {"id": 0, "pos": home + Vector2(310.0, 0.0), "vel": Vector2(42.0, 0.0), "hp": 9000.0, "max_hp": 9000.0, "radius": PLAYER_RADIUS, "alive": true},
		"soldiers": [],
	}
	for skill_index in expected.size():
		var skill_id := str(expected[skill_index])
		var controller: ChaosBossController = ChaosBossControllerScript.new()
		controller.initialize(GameConfig.CHAOS_BOSS_CONFIG, 60, 7300 + skill_index)
		controller.debug_set_hp_ratio(0.22)
		controller.force_engage(Vector2(test_context["player"]["pos"]))
		controller.debug_force_skill(skill_id)
		var skill_events: Array[Dictionary] = []
		for _step in 14:
			skill_events.append_array(controller.update(0.20, test_context))
		var selected := str(controller.get_text_state().get("active_skill", "")) == skill_id
		var harmful := false
		for event in skill_events:
			var event_type := str(event.get("type", ""))
			if event_type == "audio" and str(event.get("cue", "")) == "chaos_%s_charge" % skill_id:
				selected = true
			if event_type == "damage" and float(event.get("amount", 0.0)) > 0.0:
				harmful = true
			elif event_type in ["projectile", "hazard"] and float(event.get("damage", 0.0)) > 0.0:
				harmful = true
			elif event_type == "summon":
				harmful = true
			if skill_id == "homing_missiles" and event_type == "projectile":
				var lifetime := float(event.get("lifetime", 0.0))
				missiles_expire = missiles_expire or (lifetime >= 4.0 and lifetime <= 6.0)
		all_selected = all_selected and selected
		all_harmful = all_harmful and harmful
		moved = moved or controller.get_position().distance_to(home) > 1.0
		phase_three = phase_three or int(controller.get_text_state().get("phase", 1)) == 3
	var death_controller: ChaosBossController = ChaosBossControllerScript.new()
	death_controller.initialize(GameConfig.CHAOS_BOSS_CONFIG, 60, 9991)
	var death_result := death_controller.receive_hit(9999999.0, "player:0", home, "true")
	var reward_count := 0
	for event_value in Array(death_result.get("events", [])):
		if str(Dictionary(event_value).get("type", "")) == "reward":
			reward_count += 1
	var pending_events := death_controller.update(0.1, test_context)
	var defeated_count := 0
	for pending_event in pending_events:
		if str(pending_event.get("type", "")) == "defeated":
			defeated_count += 1
	var second_pending := death_controller.update(0.1, test_context)
	var death_once := bool(death_result.get("defeated", false)) and reward_count == 1 and defeated_count == 1 and second_pending.is_empty()
	return {
		"exact_ten": exact_ten, "all_selected": all_selected, "all_harmful": all_harmful,
		"missiles_expire": missiles_expire, "moves": moved, "phase_three": phase_three,
		"death_once": death_once,
	}


func _self_test_aionis_boss() -> Dictionary:
	var expected: Array[String] = [
		"clock_sever", "causal_hunt", "chrono_prison", "rewind_rebirth", "parallel_legion",
		"rift_board", "star_gate_barrage", "army_judgment", "causal_mirror", "twelfth_bell",
	]
	var configured_ids: Array[String] = []
	for skill_value in Array(GameConfig.AIONIS_BOSS_CONFIG.get("skills", [])):
		configured_ids.append(str(Dictionary(skill_value).get("id", "")))
	var exact_ten := configured_ids == expected and AionisBossControllerScript.SKILL_IDS == expected
	var home := Vector2(GameConfig.AIONIS_BOSS_CONFIG["home_position"])
	var test_context := {
		"player": {"id": 0, "pos": home + Vector2(340.0, 0.0), "vel": Vector2(38.0, -12.0), "hp": 16000.0, "max_hp": 16000.0, "radius": PLAYER_RADIUS, "alive": true, "attack": 900.0, "attack_rate": 7.0, "domain": "ground"},
		"soldiers": [
			{"id": 81, "type": "ufo", "pos": home + Vector2(285.0, 145.0), "vel": Vector2(-20.0, 5.0), "hp": 8000.0, "max_hp": 8000.0, "radius": 22.0, "alive": true, "attack": 820.0, "attack_rate": 4.0, "domain": "air"},
		],
	}
	var all_selected := true
	var all_harmful := true
	var star_gate_shots := 0
	var star_gate_target_hits := 0
	for skill_index in expected.size():
		var skill_id := str(expected[skill_index])
		var controller: AionisBossController = AionisBossControllerScript.new()
		controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9100 + skill_index)
		controller.debug_set_hp_ratio(0.18)
		controller.force_engage(Vector2(test_context["player"]["pos"]))
		controller.debug_force_skill(skill_id)
		var selected := false
		var harmful := false
		for _step in 32:
			var events: Array[Dictionary] = controller.update(0.12, test_context)
			for event in events:
				var event_type := str(event.get("type", ""))
				if event_type == "audio" and str(event.get("cue", "")) in ["aionis_%s_charge" % skill_id, "aionis_%s_warning" % skill_id]:
					selected = true
				if event_type == "damage" and float(event.get("amount", 0.0)) > 0.0:
					harmful = true
				elif event_type in ["projectile", "hazard"] and float(event.get("damage", 0.0)) > 0.0:
					harmful = true
				if skill_id == "star_gate_barrage" and event_type == "projectile" and str(event.get("kind", "")) == "aionis_star_gate":
					star_gate_shots += 1
					var shot_from := Vector2(event.get("pos", home))
					var shot_to := shot_from + Vector2(event.get("velocity", Vector2.ZERO)) * 0.25
					var target_pos := Vector2(Dictionary(test_context["player"]).get("pos", home))
					if _segment_circle_hit_time(shot_from, shot_to, target_pos, PLAYER_RADIUS + float(event.get("radius", 0.0))) <= 1.0:
						star_gate_target_hits += 1
				elif event_type == "summon" and str(event.get("kind", "")) == "aionis_parallel_legion":
					harmful = true
		all_selected = all_selected and selected
		all_harmful = all_harmful and harmful

	var phase_controller: AionisBossController = AionisBossControllerScript.new()
	phase_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9301)
	var observed_phases: Array[int] = []
	for ratio in [0.92, 0.70, 0.45, 0.18]:
		phase_controller.debug_set_hp_ratio(float(ratio))
		observed_phases.append(int(phase_controller.get_text_state().get("phase", 0)))
	var four_phases := observed_phases == [1, 2, 3, 4] and float(phase_controller.get_text_state().get("max_hp", 0.0)) == 260000.0

	var anchor_controller: AionisBossController = AionisBossControllerScript.new()
	anchor_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9302)
	anchor_controller.debug_set_hp_ratio(0.70)
	var anchors := anchor_controller.get_anchor_targets()
	var first_three_still_guarded := anchors.size() == 4
	for anchor_index in 3:
		anchor_controller.receive_anchor_hit(str(anchors[anchor_index]["id"]), 99999.0, "player:0")
		first_three_still_guarded = first_three_still_guarded and float(anchor_controller.get_text_state().get("time_anchor_breach", 0.0)) <= 0.0
	anchor_controller.receive_anchor_hit(str(anchors[3]["id"]), 99999.0, "player:0")
	var breach_started := float(anchor_controller.get_text_state().get("time_anchor_breach", 0.0)) >= 4.99 and int(anchor_controller.get_text_state().get("anchors_broken", 0)) == 4
	anchor_controller.update(4.9, test_context)
	var breach_persists := float(anchor_controller.get_text_state().get("time_anchor_breach", 0.0)) > 0.0
	anchor_controller.update(0.2, test_context)
	var breach_expires := float(anchor_controller.get_text_state().get("time_anchor_breach", 0.0)) <= 0.0
	var reformed_anchors := anchor_controller.get_anchor_targets()
	var anchors_reformed := reformed_anchors.size() == 4 and int(anchor_controller.get_text_state().get("anchors_broken", 0)) == 0
	for reformed_anchor in reformed_anchors:
		anchors_reformed = anchors_reformed and not bool(reformed_anchor.get("broken", true)) and float(reformed_anchor.get("hp", 0.0)) == float(reformed_anchor.get("max_hp", -1.0))
	var anchor_gate := first_three_still_guarded and breach_started and breach_persists and breach_expires and anchors_reformed

	var protected_controller: AionisBossController = AionisBossControllerScript.new()
	protected_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9303)
	protected_controller.debug_set_hp_ratio(0.70)
	var protected_hit := protected_controller.receive_hit(1000.0, "player:0", protected_controller.get_position(), "normal")
	var exposed_controller: AionisBossController = AionisBossControllerScript.new()
	exposed_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9303)
	exposed_controller.debug_set_hp_ratio(0.70)
	for exposed_anchor in exposed_controller.get_anchor_targets():
		exposed_controller.receive_anchor_hit(str(exposed_anchor["id"]), 99999.0, "player:0")
	var exposed_hit := exposed_controller.receive_hit(1000.0, "player:0", exposed_controller.get_position(), "normal")
	exposed_controller.update(5.1, test_context)
	var reprotected_hit := exposed_controller.receive_hit(1000.0, "player:0", exposed_controller.get_position(), "normal")
	var anchor_reduction := float(protected_hit.get("damage", 0.0)) < float(exposed_hit.get("damage", 0.0)) * 0.60 and float(reprotected_hit.get("damage", 0.0)) < float(exposed_hit.get("damage", 0.0)) * 0.60
	exposed_controller.debug_set_hp_ratio(0.45)
	var refreshed_anchors := exposed_controller.get_anchor_targets()
	var anchor_refresh := refreshed_anchors.size() == 4 and int(exposed_controller.get_text_state().get("anchors_broken", 0)) == 0
	for refreshed_anchor in refreshed_anchors:
		anchor_refresh = anchor_refresh and not bool(refreshed_anchor.get("broken", true)) and float(refreshed_anchor.get("hp", 0.0)) == float(refreshed_anchor.get("max_hp", -1.0))

	var combo_two_controller: AionisBossController = AionisBossControllerScript.new()
	combo_two_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9402)
	combo_two_controller.debug_set_hp_ratio(0.45)
	combo_two_controller.force_engage(Vector2(test_context["player"]["pos"]))
	combo_two_controller.debug_force_combo(["chrono_prison", "star_gate_barrage"])
	var combo_two := false
	for _step in 24:
		for event in combo_two_controller.update(0.14, test_context):
			if str(event.get("type", "")) == "combo" and int(event.get("count", 0)) == 2:
				combo_two = true
	var combo_three_controller: AionisBossController = AionisBossControllerScript.new()
	combo_three_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9403)
	combo_three_controller.debug_set_hp_ratio(0.18)
	combo_three_controller.force_engage(Vector2(test_context["player"]["pos"]))
	combo_three_controller.debug_force_combo(["rift_board", "causal_mirror", "twelfth_bell"])
	var combo_three := false
	for _step in 24:
		for event in combo_three_controller.update(0.14, test_context):
			if str(event.get("type", "")) == "combo" and int(event.get("count", 0)) == 3:
				combo_three = true

	var save_controller: AionisBossController = AionisBossControllerScript.new()
	save_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9501)
	save_controller.debug_set_hp_ratio(0.18)
	save_controller.force_engage(Vector2(test_context["player"]["pos"]))
	save_controller.debug_force_skill("twelfth_bell")
	save_controller.update(0.10, test_context)
	var saved_state := save_controller.serialize()
	var restored_controller: AionisBossController = AionisBossControllerScript.new()
	restored_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9501)
	var restored_ok := restored_controller.restore(saved_state)
	var restored_state := restored_controller.get_text_state()
	var save_restore := restored_ok and str(restored_state.get("state", "")) == "IDLE" and int(restored_state.get("phase", 0)) == 4 and restored_controller.get_position().distance_to(home) <= 0.1 and restored_controller.get_anchor_targets().size() == 4

	var move_controller: AionisBossController = AionisBossControllerScript.new()
	move_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9601)
	move_controller.force_engage(Vector2(test_context["player"]["pos"]))
	move_controller.update(0.25, test_context)
	var moves := move_controller.get_position().distance_to(home) > 1.0
	var death_controller: AionisBossController = AionisBossControllerScript.new()
	death_controller.initialize(GameConfig.AIONIS_BOSS_CONFIG, 80, 9701)
	var death_result := death_controller.receive_hit(9999999.0, "player:0", home, "true")
	var reward_count := 0
	for death_event in Array(death_result.get("events", [])):
		if str(Dictionary(death_event).get("type", "")) == "reward":
			reward_count += 1
	var defeated_count := 0
	for pending_event in death_controller.update(0.1, test_context):
		if str(pending_event.get("type", "")) == "defeated":
			defeated_count += 1
	var death_once := bool(death_result.get("defeated", false)) and reward_count == 1 and defeated_count == 1 and death_controller.update(0.1, test_context).is_empty()
	var saved_aionis_projectiles := aionis_runtime_projectiles.duplicate(true)
	var saved_aionis_hazards := aionis_runtime_hazards.duplicate(true)
	var saved_aionis_enemies := enemies.duplicate(true)
	aionis_runtime_projectiles.append({"kind": "qa_hostile_projectile", "ttl": 2.0})
	aionis_runtime_hazards.append({"kind": "qa_hostile_hazard", "ttl": 2.0})
	enemies.append({"aionis_summon": true})
	_clear_aionis_combat_runtime()
	var victory_cleanup := aionis_runtime_projectiles.is_empty() and aionis_runtime_hazards.is_empty()
	for remaining_enemy in enemies:
		victory_cleanup = victory_cleanup and not bool(remaining_enemy.get("aionis_summon", false))
	aionis_runtime_projectiles.append_array(saved_aionis_projectiles)
	aionis_runtime_hazards.append_array(saved_aionis_hazards)
	enemies = saved_aionis_enemies
	return {
		"exact_ten": exact_ten, "all_selected": all_selected, "all_harmful": all_harmful,
		"star_gate_converges": star_gate_shots > 0 and star_gate_target_hits == star_gate_shots,
		"four_phases": four_phases, "anchor_gate": anchor_gate, "anchor_reduction": anchor_reduction,
		"anchor_refresh": anchor_refresh, "combo_two": combo_two, "combo_three": combo_three,
		"save_restore": save_restore, "moves": moves, "death_once": death_once, "victory_cleanup": victory_cleanup,
	}


func _self_test_terrain_rules() -> Dictionary:
	var test_coord := Vector2i(40, 40)
	var test_key := world_generator.chunk_key(test_coord)
	var previous_chunk: Variant = active_chunks.get(test_key)
	var center := Vector2(test_coord) * WorldGenerator.CHUNK_SIZE + Vector2(260.0, 260.0)
	active_chunks[test_key] = {
		"key": test_key, "chunk": test_coord, "obstacles": [
			{"type": "tree", "position": center, "radius": 26.0},
			{"type": "rock", "position": center + Vector2(190.0, 0.0), "radius": 24.0},
			{"type": "bush", "position": center + Vector2(380.0, 0.0), "radius": 22.0},
		],
		"castle": null, "camp": null, "house": null, "enemy_spawns": [], "decorations": [],
	}
	var tree_blocks := _position_hits_obstacle(center, 11.0)
	var scenery_passable := not _position_hits_obstacle(center + Vector2(190.0, 0.0), 11.0) and not _position_hits_obstacle(center + Vector2(380.0, 0.0), 11.0)
	var saved_soldiers := soldiers.duplicate(true)
	var saved_next_entity_id := next_entity_id
	soldiers.clear()
	var trapped_id := _spawn_soldier("swordsman", center)
	var trapped: Variant = _find_soldier_by_id(trapped_id)
	if trapped != null:
		_move_soldier_toward(trapped, center + Vector2(320.0, 0.0), 0.1)
	var escaped := trapped != null and not _position_hits_tree(Vector2(trapped["pos"]), float(trapped["radius"]))
	soldiers = saved_soldiers
	next_entity_id = saved_next_entity_id
	if previous_chunk == null:
		active_chunks.erase(test_key)
	else:
		active_chunks[test_key] = previous_chunk
	return {"tree_blocks": tree_blocks, "scenery_passable": scenery_passable, "soldier_escaped_tree": escaped}


func _self_test_enemy_motion_smoothing() -> bool:
	var test_coord := Vector2i(41, 40)
	var test_key := world_generator.chunk_key(test_coord)
	var previous_chunk: Variant = active_chunks.get(test_key)
	active_chunks[test_key] = {
		"key": test_key, "chunk": test_coord, "obstacles": [], "castle": null,
		"camp": null, "house": null, "enemy_spawns": [], "decorations": [],
	}
	var saved_enemies := enemies.duplicate(true)
	var saved_next_entity_id := next_entity_id
	enemies.clear()
	var start := Vector2(test_coord) * WorldGenerator.CHUNK_SIZE + Vector2(280.0, 280.0)
	var enemy_id := _spawn_enemy("grunt", start, 1, start)
	var enemy: Variant = _find_enemy_by_id(enemy_id)
	var moving_frames := 0
	var maximum_step := 0.0
	if enemy != null:
		_set_enemy_move_intent(enemy, Vector2.RIGHT)
		for _frame in 12:
			var before := Vector2(enemy["pos"])
			_advance_enemy_motion(enemy, FIXED_STEP)
			var step_distance := before.distance_to(enemy["pos"])
			if step_distance > 0.001:
				moving_frames += 1
			maximum_step = maxf(maximum_step, step_distance)
	var smooth := enemy != null and moving_frames >= 10 and maximum_step <= float(enemy["speed"]) * FIXED_STEP * 1.05
	enemies = saved_enemies
	next_entity_id = saved_next_entity_id
	if previous_chunk == null:
		active_chunks.erase(test_key)
	else:
		active_chunks[test_key] = previous_chunk
	return smooth


func _self_test_python_boss_home_movement() -> Dictionary:
	var saved_player := player.duplicate(true)
	var saved_chunks := active_chunks.duplicate(true)
	var saved_castles := castles.duplicate(true)
	var home: Vector2 = GameConfig.PYTHON_BOSS_CONFIG["home_position"]
	var home_coord := world_generator.world_to_chunk(home)
	var home_data := world_generator.generate_chunk(home_coord)
	_clear_python_boss_home_trees(home_data)
	active_chunks.clear()
	active_chunks[str(home_data["key"])] = home_data
	castles.clear()
	var head_radius := float(GameConfig.PYTHON_BOSS_CONFIG["body"]["head_radius"])
	var home_clear := not _python_boss_position_blocked(home, head_radius)
	player["pos"] = home + Vector2(430.0, 0.0)
	player["vel"] = Vector2.ZERO
	player["alive"] = true
	_initialize_python_boss(true)
	python_boss.force_engage()
	var start := _python_boss_position()
	for _frame in 18:
		_update_python_boss(FIXED_STEP)
	var moved := _python_boss_position().distance_to(start) > 0.25
	player = saved_player
	active_chunks = saved_chunks
	castles = saved_castles
	_initialize_python_boss(true)
	return {"home_clear": home_clear, "moved": moved}


func _self_test_python_boss_lair_lifecycle() -> Dictionary:
	var saved_player := player.duplicate(true)
	var saved_chunks := active_chunks.duplicate(true)
	var saved_nests := snake_nests.duplicate(true)
	var saved_active_lair_id := active_python_boss_lair_id
	var saved_main_cleared := main_python_boss_lair_cleared
	var saved_activation_timer := python_boss_lair_activation_timer
	var saved_boss_state: Dictionary = {} if python_boss == null else python_boss.serialize()

	var first_chunk := world_generator.generate_chunk(Vector2i(3, 2))
	var second_chunk := world_generator.generate_chunk(Vector2i(14, 2))
	var first_descriptor: Dictionary = Dictionary(first_chunk.get("snake_nest", {}))
	var second_descriptor: Dictionary = Dictionary(second_chunk.get("snake_nest", {}))
	if first_descriptor.is_empty() or second_descriptor.is_empty():
		return {"same_saga": false, "same_controller": false, "engaged_lock": false, "clear_and_next": false, "text_contract": false}

	snake_nests.clear()
	_register_snake_nest(first_descriptor)
	_register_snake_nest(second_descriptor)
	active_chunks.clear()
	active_chunks[str(first_chunk["key"])] = first_chunk
	active_python_boss_lair_id = MAIN_PYTHON_BOSS_LAIR_ID
	main_python_boss_lair_cleared = false
	_initialize_python_boss(true)
	var controller_instance_id: int = int(python_boss.get_instance_id())
	var first_id := str(first_descriptor["id"])
	var second_id := str(second_descriptor["id"])
	var first_home := Vector2(first_descriptor["position"])
	var second_home := Vector2(second_descriptor["position"])
	var main_home := Vector2(GameConfig.PYTHON_BOSS_CONFIG["home_position"])
	var main_idle_state: Dictionary = python_boss.serialize()
	main_idle_state["discovered"] = true
	main_idle_state["engaged"] = false
	main_idle_state["position"] = main_home
	python_boss.restore(main_idle_state)
	player["pos"] = first_home.lerp(main_home, 0.4)
	player["alive"] = true
	python_boss_lair_activation_timer = 0.0
	_update_python_boss_lair_activation(0.25)
	var idle_handoff := active_python_boss_lair_id == first_id
	player["pos"] = first_home
	python_boss_lair_activation_timer = 0.0
	_update_python_boss_lair_activation(0.25)
	var first_state: Dictionary = python_boss.get_text_state()
	var same_saga := (
		active_python_boss_lair_id == first_id
		and str(first_state.get("id", "")) == "corrupt_python_emperor_saga"
		and str(first_state.get("name", "")) == "腐沼蟒皇・薩迦"
		and Vector2(float(first_state["x"]), float(first_state["y"])).distance_to(first_home) < 0.2
		and int(first_state.get("segments", 0)) == 18
		and int(first_state.get("world_tier", -1)) == clampi(int(first_descriptor.get("level", 1)) - 1, 0, int(GameConfig.PYTHON_BOSS_CONFIG["scaling"]["max_world_tier"]))
		and Dictionary(GameConfig.PYTHON_BOSS_CONFIG["skills"]).size() == 5
	)
	var same_controller: bool = int(python_boss.get_instance_id()) == controller_instance_id

	python_boss.force_engage()
	active_chunks.clear()
	active_chunks[str(second_chunk["key"])] = second_chunk
	player["pos"] = second_home
	python_boss_lair_activation_timer = 0.0
	_update_python_boss_lair_activation(0.25)
	var engaged_lock := active_python_boss_lair_id == first_id

	player["pos"] = first_home
	active_chunks.clear()
	active_chunks[str(first_chunk["key"])] = first_chunk
	python_boss.receive_hit("lair_lifecycle_lethal", "player", 0, 9999999.0, _python_boss_position(), "test", 9999.0)
	python_boss_lair_activation_timer = 0.0
	_update_python_boss_lair_activation(0.25)
	var first_cleared: bool = bool(Dictionary(snake_nests[first_id]).get("cleared", false)) and bool(python_boss.is_defeated())

	player["pos"] = second_home
	active_chunks.clear()
	active_chunks[str(second_chunk["key"])] = second_chunk
	python_boss_lair_activation_timer = 0.0
	_update_python_boss_lair_activation(0.25)
	var second_state: Dictionary = python_boss.get_text_state()
	var clear_and_next: bool = (
		first_cleared
		and active_python_boss_lair_id == second_id
		and int(python_boss.get_instance_id()) == controller_instance_id
		and not bool(Dictionary(snake_nests[second_id]).get("cleared", false))
		and not python_boss.is_defeated()
		and str(second_state.get("id", "")) == "corrupt_python_emperor_saga"
		and str(second_state.get("name", "")) == "腐沼蟒皇・薩迦"
		and Vector2(float(second_state["x"]), float(second_state["y"])).distance_to(second_home) < 0.2
	)
	var rendered_boss: Dictionary = _boss_text_state()
	var rendered_lairs := _snake_nest_text_state(second_home)
	var main_lair_state := _snake_nest_text_state(main_home)
	var text_contract := str(rendered_boss.get("active_lair_id", "")) == second_id and str(rendered_boss.get("name", "")) == "腐沼蟒皇・薩迦"
	var rendered_active_lair_found := false
	var main_marker_persists := false
	for rendered_lair in main_lair_state:
		if str(rendered_lair.get("id", "")) == MAIN_PYTHON_BOSS_LAIR_ID:
			main_marker_persists = bool(rendered_lair.get("is_main", false)) and not bool(rendered_lair.get("active", true)) and not bool(rendered_lair.get("boss_present", true))
			break
	for rendered_lair in rendered_lairs:
		if str(rendered_lair.get("id", "")) == second_id:
			rendered_active_lair_found = true
			text_contract = text_contract and bool(rendered_lair.get("active", false)) and bool(rendered_lair.get("boss_present", false)) and str(rendered_lair.get("boss_name", "")) == "腐沼蟒皇・薩迦"
			break
	text_contract = text_contract and rendered_active_lair_found

	player = saved_player
	active_chunks = saved_chunks
	snake_nests = saved_nests
	active_python_boss_lair_id = saved_active_lair_id
	main_python_boss_lair_cleared = saved_main_cleared
	python_boss_lair_activation_timer = saved_activation_timer
	python_boss = PythonBossControllerScript.new()
	_initialize_python_boss(true)
	if not saved_boss_state.is_empty():
		python_boss.restore(saved_boss_state)
	return {
		"same_saga": same_saga,
		"same_controller": same_controller and python_boss != null,
		"idle_handoff": idle_handoff,
		"engaged_lock": engaged_lock,
		"clear_and_next": clear_and_next,
		"text_contract": text_contract,
		"main_marker_persists": main_marker_persists,
	}


func _boss_test_context(target_offset: Vector2) -> Dictionary:
	var home: Vector2 = GameConfig.PYTHON_BOSS_CONFIG["home_position"]
	return {
		"units": [{
			"kind": "player", "id": 0, "type": "warrior",
			"pos": home + target_offset, "vel": Vector2.ZERO,
			"radius": PLAYER_RADIUS, "alive": true, "safe": false,
		}],
		"safe_zones": [],
	}


func _boss_test_forced_skill(skill_id: String) -> bool:
	var target_offset := Vector2(180, 0)
	match skill_id:
		"dash": target_offset = Vector2(390, 0)
		"bite": target_offset = Vector2(95, 0)
		"poison_pool": target_offset = Vector2(260, 70)
		"tail_sweep": target_offset = Vector2(-180, 0)
	var boss: Variant = PythonBossControllerScript.new()
	boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 7000 + skill_id.hash())
	boss.force_engage()
	boss.debug_force_skill(skill_id)
	var context := _boss_test_context(target_offset)
	for _step in 150:
		boss.update(FIXED_STEP, context)
		var state: Dictionary = boss.get_text_state()
		if str(state.get("active_skill", "")) == skill_id and str(state.get("state", "")) in ["TELEGRAPH", "CASTING"]:
			return true
	return false


func _boss_test_forced_skill_damage(skill_id: String) -> bool:
	var target_offset := Vector2(180, 0)
	match skill_id:
		"dash": target_offset = Vector2(390, 0)
		"bite": target_offset = Vector2(95, 0)
		"poison_pool": target_offset = Vector2(260, 70)
		"tail_sweep": target_offset = Vector2(-180, 0)
	var boss: Variant = PythonBossControllerScript.new()
	boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 8100 + skill_id.hash())
	boss.force_engage()
	boss.debug_force_skill(skill_id)
	var context := _boss_test_context(target_offset)
	for _step in 300:
		var events_value: Variant = boss.update(FIXED_STEP, context)
		if not events_value is Array:
			continue
		for event_value in Array(events_value):
			if event_value is Dictionary and str(event_value.get("type", "")) == "damage" and float(event_value.get("amount", 0.0)) > 0.0:
				return true
	return false


func _boss_test_poison_tick_count(step: float) -> int:
	var boss: Variant = PythonBossControllerScript.new()
	boss.initialize(GameConfig.PYTHON_BOSS_CONFIG, 0, 10, 5150)
	boss.force_engage()
	boss.debug_force_skill("bite")
	var context := _boss_test_context(Vector2(95, 0))
	var poisoned := false
	for _setup_step in 180:
		boss.update(FIXED_STEP, context)
		if int(boss.get_unit_status("player", 0).get("poison_stacks", 0)) > 0:
			poisoned = true
			break
	if not poisoned:
		return -1
	var empty_context := {"units": [], "safe_zones": []}
	var count := 0
	for _tick_step in int(ceil(7.2 / step)):
		var events_value: Variant = boss.update(step, empty_context)
		if not events_value is Array:
			continue
		for event_value in Array(events_value):
			if event_value is Dictionary and str(event_value.get("type", "")) == "damage" and str(event_value.get("kind", "")).begins_with("poison_"):
				count += 1
	return count


# Native renderer smoke capture used by the visual QA pass. The same gameplay
# state is also useful after a Web export because it exercises every draw layer.
func _run_visual_smoke() -> void:
	mode = GameMode.CLASS_SELECT
	tutorial_visible = true
	queue_redraw()
	var class_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-class-select.png")
	_set_input_scheme(InputScheme.TOUCH)
	queue_redraw()
	var touch_class_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-touch-class-choice.png")
	_set_input_scheme(InputScheme.KEYBOARD_MOUSE)

	_start_new_game("mage")
	player["level"] = 10
	player["xp"] = 420
	player["xp_need"] = GameConfig.xp_needed(10)
	player["money"] = 2400
	player["skill_points"] = 4

	var showcase_castle: Variant = null
	for castle in castles.values():
		if not bool(castle["owned"]):
			showcase_castle = castle
			break
	if showcase_castle == null:
		_register_castle({"id": "visual_castle", "position": HOUSE_POS + Vector2(900, 780), "level": 2})
		showcase_castle = castles["visual_castle"]

	player["pos"] = Vector2(showcase_castle["pos"]) + Vector2(-210, 30)
	camera_pos = player["pos"]
	camera_target = camera_pos
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	hazards.clear()
	particles.clear()
	floaters.clear()
	var showcase_types := ["swordsman", "healer", "archer", "roller", "mage", "heavy", "priest", "cannon"]
	for i in showcase_types.size():
		var soldier_pos := Vector2(player["pos"]) + Vector2.from_angle(TAU * float(i) / float(showcase_types.size())) * 72.0
		_spawn_soldier(showcase_types[i], soldier_pos)
	notifications.clear()
	_add_notification("蠻族城堡攻防戰：摧毀後留在範圍內完成佔領", GOLD, 4.0)
	var enemy_types := ["grunt", "archer", "thrower", "berserker", "heavy", "shaman", "chief"]
	for i in enemy_types.size():
		var angle := -1.1 + float(i) * 0.31
		var enemy_pos := Vector2(showcase_castle["pos"]) + Vector2.from_angle(angle) * (170.0 + float(i % 3) * 32.0)
		_spawn_enemy(enemy_types[i], enemy_pos, 3, Vector2(showcase_castle["pos"]))
	hazards.append({"kind": "fire", "pos": Vector2(showcase_castle["pos"]) + Vector2(-90, 35), "radius": 92.0, "ttl": 5.0, "tick": 0.0, "damage": 8.0})
	_spawn_effect("explosion", Vector2(showcase_castle["pos"]) + Vector2(-82, 25), FIRE_ORANGE, 1.2)
	_spawn_effect("level_up", player["pos"], MAGIC_PURPLE, 0.9)
	for i in 18:
		var particle_angle := TAU * float(i) / 18.0
		_spawn_particle(Vector2(showcase_castle["pos"]) + Vector2(-82, 25), Vector2.from_angle(particle_angle) * 92.0, FIRE_ORANGE, 0.8, 4.0, 1)
	_set_input_scheme(InputScheme.TOUCH)
	tutorial_visible = false
	touch_move_pointer = 71
	touch_aim_pointer = 72
	touch_move_vector = Vector2(-0.72, -0.69)
	touch_aim_vector = Vector2(0.78, -0.63)
	queue_redraw()
	var touch_controls_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-touch-virtual-controls.png")
	_reset_touch_inputs()
	_set_input_scheme(InputScheme.KEYBOARD_MOUSE)
	queue_redraw()
	var battle_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-battle.png")

	# Milestone capture: exact ten-second income formula plus one deliberately
	# sparse Python Boss lair landmark in the explored map region.
	language = "zh_TW"
	player["pos"] = HOUSE_POS + Vector2(840, 420)
	camera_pos = player["pos"]
	camera_target = camera_pos
	castles.clear()
	camps.clear()
	_register_castle({"id": "income_showcase_castle", "position": Vector2(player["pos"]) + Vector2(760, 0), "level": 20})
	enemies.clear()
	var income_castle: Dictionary = castles["income_showcase_castle"]
	income_castle["owned"] = true
	income_castle["income_timer"] = 0.01
	notifications.clear()
	_update_castles_and_camps(0.02)
	snake_nests.clear()
	_register_snake_nest({
		"id": "visual_python_boss_lair",
		"position": Vector2(player["pos"]) + Vector2.from_angle(-2.25) * 1850.0,
		"level": 8,
	})
	active_panel = "map"
	queue_redraw()
	var sparse_lairs_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-sparse-boss-lairs.png")
	# Large-map integration: every requested late-game tier has a distinct
	# miniature glyph and an exact level label, while serpent nests keep their
	# separate coiled-snake marker.
	castles.clear()
	enemies.clear()
	var map_tier_levels := [20, 30, 35, 40, 45, 50]
	for map_tier_index in map_tier_levels.size():
		var map_tier_angle := -PI * 0.5 + TAU * float(map_tier_index) / float(map_tier_levels.size())
		_register_castle({"id": "map_tier_%d" % int(map_tier_levels[map_tier_index]), "position": Vector2(player["pos"]) + Vector2.from_angle(map_tier_angle) * 2700.0, "level": int(map_tier_levels[map_tier_index])})
		enemies.clear()
	queue_redraw()
	var map_tiers_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-map-tech-tiers.png")
	active_panel = ""

	# Level 20 milestone: artillery fortress, identifiable cannon crews, muzzle
	# smoke and a live shell are composed inside the real gameplay renderer.
	castles.clear()
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	hazards.clear()
	particles.clear()
	floaters.clear()
	snake_nests.clear()
	python_boss = null
	var level_20_position := HOUSE_POS + Vector2(100, 720)
	_register_castle({"id": "visual_castle_l20", "position": level_20_position, "level": 20})
	enemies.clear()
	player["pos"] = level_20_position + Vector2(-365, 72)
	player["hp"] = player["max_hp"]
	camera_pos = level_20_position + Vector2(-55, 18)
	camera_target = camera_pos
	var level_20_types := ["heavy", "cannon", "grunt", "cannon", "archer", "cannon", "chief"]
	var first_visual_cannon: Variant = null
	for level_20_index in level_20_types.size():
		var guard_angle := -1.1 + float(level_20_index) * 0.39
		var guard_position := level_20_position + Vector2.from_angle(guard_angle) * (225.0 + float(level_20_index % 2) * 50.0)
		var guard_id := _spawn_enemy(str(level_20_types[level_20_index]), guard_position, 20, level_20_position, "visual_castle_l20")
		var guard: Variant = _find_enemy_by_id(guard_id)
		if guard != null:
			guard["aim_dir"] = (Vector2(player["pos"]) - Vector2(guard["pos"])).normalized()
			if first_visual_cannon == null and str(guard["type"]) == "cannon": first_visual_cannon = guard
	if first_visual_cannon != null:
		first_visual_cannon["pending_pos"] = player["pos"] + Vector2(80, -35)
		_execute_enemy_attack(first_visual_cannon)
		_update_projectiles(0.07)
	notifications.clear()
	_add_notification("20 級砲兵要塞：20 名守軍・普通大砲已部署", Color("FFD08A"), 5.0)
	queue_redraw()
	var castle_20_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-castle-l20.png")

	# Level 30 milestone: long musket silhouette versus compact magazine-fed rifle.
	castles.clear()
	enemies.clear()
	projectiles.clear()
	particles.clear()
	floaters.clear()
	camps.clear()
	var level_30_position := level_20_position
	_register_castle({"id": "visual_castle_l30", "position": level_30_position, "level": 30})
	enemies.clear()
	player["pos"] = level_30_position + Vector2(-365, 72)
	player["hp"] = player["max_hp"]
	camera_pos = level_30_position + Vector2(-55, 18)
	camera_target = camera_pos
	var level_30_types := ["musketeer", "rifleman", "heavy", "rifleman", "musketeer", "rifleman", "cannon", "chief"]
	var visual_musketeer: Variant = null
	var visual_rifleman: Variant = null
	for level_30_index in level_30_types.size():
		var firearm_angle := -1.25 + float(level_30_index) * 0.34
		var firearm_position := level_30_position + Vector2.from_angle(firearm_angle) * (225.0 + float(level_30_index % 3) * 35.0)
		var firearm_id := _spawn_enemy(str(level_30_types[level_30_index]), firearm_position, 30, level_30_position, "visual_castle_l30")
		var firearm_unit: Variant = _find_enemy_by_id(firearm_id)
		if firearm_unit != null:
			firearm_unit["aim_dir"] = (Vector2(player["pos"]) - Vector2(firearm_unit["pos"])).normalized()
			if visual_musketeer == null and str(firearm_unit["type"]) == "musketeer": visual_musketeer = firearm_unit
			if visual_rifleman == null and str(firearm_unit["type"]) == "rifleman": visual_rifleman = firearm_unit
	if visual_musketeer != null:
		visual_musketeer["pending_pos"] = player["pos"] + Vector2(120, -34)
		visual_musketeer["state"] = "telegraph"
		visual_musketeer["telegraph"] = 0.48
	if visual_rifleman != null:
		visual_rifleman["pending_pos"] = player["pos"] + Vector2(100, 30)
		_execute_enemy_attack(visual_rifleman)
		_update_projectiles(0.05)
	notifications.clear()
	_add_notification("30 級火器堡壘：重傷害火槍手・高速突擊步槍手", Color("FFE0A3"), 5.0)
	_web_manual_time_hold = 1.0
	queue_redraw()
	var castle_30_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-castle-l30.png")

	# Level 35 milestone: heavy tracked armor and a multi-rail rocket launcher.
	castles.clear()
	enemies.clear()
	projectiles.clear()
	particles.clear()
	floaters.clear()
	camps.clear()
	var level_35_position := level_20_position
	_register_castle({"id": "visual_castle_l35", "position": level_35_position, "level": 35})
	enemies.clear()
	player["pos"] = level_35_position + Vector2(-365, 72)
	player["hp"] = player["max_hp"]
	camera_pos = level_35_position + Vector2(-55, 18)
	camera_target = camera_pos
	var level_35_types := ["tank", "rocket", "rifleman", "tank", "rocket", "musketeer", "cannon", "chief"]
	var visual_tank: Variant = null
	var visual_rocket: Variant = null
	for level_35_index in level_35_types.size():
		var vehicle_angle := -1.30 + float(level_35_index) * 0.35
		var vehicle_position := level_35_position + Vector2.from_angle(vehicle_angle) * (245.0 + float(level_35_index % 2) * 54.0)
		var vehicle_id := _spawn_enemy(str(level_35_types[level_35_index]), vehicle_position, 35, level_35_position, "visual_castle_l35")
		var vehicle_unit: Variant = _find_enemy_by_id(vehicle_id)
		if vehicle_unit != null:
			vehicle_unit["aim_dir"] = (Vector2(player["pos"]) - Vector2(vehicle_unit["pos"])).normalized()
			if visual_tank == null and str(vehicle_unit["type"]) == "tank": visual_tank = vehicle_unit
			if visual_rocket == null and str(vehicle_unit["type"]) == "rocket": visual_rocket = vehicle_unit
	if visual_tank != null:
		visual_tank["pending_pos"] = player["pos"] + Vector2(105, -28)
		visual_tank["state"] = "telegraph"
		visual_tank["telegraph"] = 0.54
	if visual_rocket != null:
		visual_rocket["pending_pos"] = player["pos"] + Vector2(95, 38)
		_execute_enemy_attack(visual_rocket)
		_update_projectiles(0.11)
	notifications.clear()
	_add_notification("35 級鋼鐵軍城：重甲坦克・極高範圍火箭炮", Color("FFD08A"), 5.0)
	_web_manual_time_hold = 1.0
	queue_redraw()
	var castle_35_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-castle-l35.png")

	# Level 40 milestone: an independent outer-wall health layer plus Gatling crews.
	castles.clear()
	enemies.clear()
	projectiles.clear()
	particles.clear()
	floaters.clear()
	camps.clear()
	var level_40_position := level_20_position
	_register_castle({"id": "visual_castle_l40", "position": level_40_position, "level": 40})
	enemies.clear()
	var visual_wall_castle: Dictionary = castles["visual_castle_l40"]
	visual_wall_castle["wall_hp"] = float(visual_wall_castle["wall_max_hp"]) * 0.64
	visual_wall_castle["wall_breached"] = false
	player["pos"] = level_40_position + Vector2(-410, 58)
	player["hp"] = player["max_hp"]
	camera_pos = level_40_position + Vector2(-42, 12)
	camera_target = camera_pos
	var level_40_types := ["gatling", "heavy", "gatling", "rifleman", "tank", "gatling", "rocket", "chief"]
	var visual_gatling: Variant = null
	for level_40_index in level_40_types.size():
		var wall_guard_angle := -1.34 + float(level_40_index) * 0.37
		var wall_guard_position := level_40_position + Vector2.from_angle(wall_guard_angle) * (285.0 + float(level_40_index % 2) * 48.0)
		var wall_guard_id := _spawn_enemy(str(level_40_types[level_40_index]), wall_guard_position, 40, level_40_position, "visual_castle_l40")
		var wall_guard_unit: Variant = _find_enemy_by_id(wall_guard_id)
		if wall_guard_unit != null:
			wall_guard_unit["aim_dir"] = (Vector2(player["pos"]) - Vector2(wall_guard_unit["pos"])).normalized()
			if visual_gatling == null and str(wall_guard_unit["type"]) == "gatling": visual_gatling = wall_guard_unit
	if visual_gatling != null:
		visual_gatling["pending_pos"] = player["pos"] + Vector2(100, -20)
		_execute_enemy_attack(visual_gatling)
		_update_projectiles(0.045)
	notifications.clear()
	_add_notification("40 級巨壁機關城：必須先摧毀外牆・高速加特林", Color("FFE3A0"), 5.0)
	_web_manual_time_hold = 1.0
	queue_redraw()
	var castle_40_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-castle-l40.png")
	visual_wall_castle["wall_hp"] = 1.0
	notifications.clear()
	_damage_castle(visual_wall_castle, 100.0)
	_web_manual_time_hold = 1.0
	queue_redraw()
	var castle_40_breached_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-castle-l40-breached.png")
	visual_wall_castle["owned"] = true
	visual_wall_castle["destroyed"] = false
	visual_wall_castle["hp"] = float(visual_wall_castle["max_hp"]) * 0.45
	visual_wall_castle["wall_hp"] = float(visual_wall_castle["wall_max_hp"]) * 0.35
	visual_wall_castle["wall_breached"] = false
	enemies.clear()
	soldiers.clear()
	player["pos"] = level_40_position + Vector2(0, 150)
	for friendly_gate_index in 4:
		_spawn_soldier(["heavy", "rifleman", "cannon", "rocket"][friendly_gate_index], level_40_position + Vector2(-150.0 + float(friendly_gate_index) * 100.0, 175.0 + float(friendly_gate_index % 2) * 42.0))
	notifications.clear()
	_add_notification("城堡佔領完成：友方城門已開放，玩家與招募士兵不會被卡住", Color("9DD8FF"), 5.0)
	queue_redraw()
	var friendly_gate_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-castle-friendly-gate.png")
	soldier_command = "駐守"
	command_castle_id = "visual_castle_l40"
	command_point = level_40_position
	for garrison_unit in soldiers:
		garrison_unit["pos"] = _garrison_formation_position(garrison_unit, visual_wall_castle)
	notifications.clear()
	_add_notification("駐守軍令：士兵進入城市防線，優先攔截附近來襲敵軍", Color("9FE8FF"), 5.0)
	queue_redraw()
	var city_garrison_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-city-garrison.png")
	visual_wall_castle["owned"] = false
	visual_wall_castle["wall_hp"] = float(visual_wall_castle["wall_max_hp"]) * 0.72
	visual_wall_castle["wall_breached"] = false
	player["pos"] = level_40_position + Vector2(-410, 58)
	soldier_command = "攻城"
	command_castle_id = "visual_castle_l40"
	command_point = level_40_position
	for siege_friend_index in soldiers.size():
		soldiers[siege_friend_index]["pos"] = level_40_position + Vector2(-365.0, -105.0 + float(siege_friend_index) * 70.0)
	enemies.clear()
	for siege_guard_index in 6:
		var siege_guard_angle := -0.95 + float(siege_guard_index) * 0.38
		_spawn_enemy(str(["heavy", "gatling", "rifleman"][siege_guard_index % 3]), level_40_position + Vector2.from_angle(siege_guard_angle) * 285.0, 40, level_40_position, "visual_castle_l40")
	notifications.clear()
	_add_notification("攻城軍令：先清除城市附近守軍，再攻擊外牆與主城", Color("FFD08A"), 5.0)
	queue_redraw()
	var siege_order_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-siege-order.png")

	# Level 45 milestone: airborne silhouettes, separated shadows, helipads and bomb sequence.
	castles.clear()
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	particles.clear()
	floaters.clear()
	camps.clear()
	python_boss = null
	var level_45_position := level_20_position
	_register_castle({"id": "visual_castle_l45", "position": level_45_position, "level": 45})
	enemies.clear()
	player["pos"] = level_45_position + Vector2(-420, 58)
	player["max_hp"] = maxf(float(player["max_hp"]), 500.0)
	player["hp"] = player["max_hp"]
	camera_pos = level_45_position + Vector2(-38, 12)
	camera_target = camera_pos
	var level_45_types := ["helicopter", "bomber", "gatling", "helicopter", "rifleman", "bomber", "rocket", "chief"]
	var visual_helicopter: Variant = null
	var visual_bomber: Variant = null
	for level_45_index in level_45_types.size():
		var air_angle := -1.36 + float(level_45_index) * 0.38
		var air_position := level_45_position + Vector2.from_angle(air_angle) * (310.0 + float(level_45_index % 2) * 52.0)
		var air_id := _spawn_enemy(str(level_45_types[level_45_index]), air_position, 45, level_45_position, "visual_castle_l45")
		var air_unit: Variant = _find_enemy_by_id(air_id)
		if air_unit != null:
			air_unit["aim_dir"] = (Vector2(player["pos"]) - Vector2(air_unit["pos"])).normalized()
			if visual_helicopter == null and str(air_unit["type"]) == "helicopter": visual_helicopter = air_unit
			if visual_bomber == null and str(air_unit["type"]) == "bomber": visual_bomber = air_unit
	if visual_helicopter != null:
		visual_helicopter["pending_pos"] = player["pos"] + Vector2(115, -35)
		_execute_enemy_attack(visual_helicopter)
	if visual_bomber != null:
		visual_bomber["pending_pos"] = player["pos"] + Vector2(105, 15)
		_execute_enemy_attack(visual_bomber)
	_update_projectiles(0.26)
	notifications.clear()
	_add_notification("45 級天空戰爭堡：遠程才能命中・直升機與連續轟炸", Color("CDEEFF"), 5.0)
	_web_manual_time_hold = 1.0
	queue_redraw()
	var castle_45_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-castle-l45.png")

	# Level 50 milestone: alien fortress pylons and a capped, sustained vertical beam.
	castles.clear()
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	hazards.clear()
	particles.clear()
	floaters.clear()
	camps.clear()
	python_boss = null
	var level_50_position := level_20_position
	_register_castle({"id": "visual_castle_l50", "position": level_50_position, "level": 50})
	enemies.clear()
	player["pos"] = level_50_position + Vector2(-420, 58)
	player["max_hp"] = maxf(float(player["max_hp"]), 500.0)
	player["hp"] = player["max_hp"]
	player["invuln"] = 0.0
	camera_pos = level_50_position + Vector2(-38, 12)
	camera_target = camera_pos
	var level_50_types := ["ufo", "bomber", "helicopter", "ufo", "rocket", "gatling", "ufo", "chief"]
	var visual_ufo: Variant = null
	for level_50_index in level_50_types.size():
		var alien_angle := -1.37 + float(level_50_index) * 0.38
		var alien_position := level_50_position + Vector2.from_angle(alien_angle) * (315.0 + float(level_50_index % 2) * 56.0)
		var alien_id := _spawn_enemy(str(level_50_types[level_50_index]), alien_position, 50, level_50_position, "visual_castle_l50")
		var alien_unit: Variant = _find_enemy_by_id(alien_id)
		if alien_unit != null:
			alien_unit["aim_dir"] = (Vector2(player["pos"]) - Vector2(alien_unit["pos"])).normalized()
			if visual_ufo == null and str(alien_unit["type"]) == "ufo": visual_ufo = alien_unit
	if visual_ufo != null:
		visual_ufo["pending_pos"] = player["pos"] + Vector2(105, 10)
		_execute_enemy_attack(visual_ufo)
		_update_hazards(0.78)
	notifications.clear()
	_add_notification("50 級星界終焉城：UFO 垂直光柱・碰觸受傷但不會秒殺", Color("B9FFF8"), 5.0)
	_web_manual_time_hold = 1.0
	queue_redraw()
	var castle_50_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-castle-l50.png")

	# Bounded lead prediction is shown as a fixed red target marker. It is locked
	# at telegraph start, so the player can read and evade it instead of facing
	# invisible homing.
	_start_new_game("warrior")
	player["pos"] = HOUSE_POS + Vector2(1180, 760)
	player["vel"] = Vector2(220, 0)
	player["facing"] = Vector2.RIGHT
	camera_pos = player["pos"] + Vector2(30, 0)
	camera_target = camera_pos
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	hazards.clear()
	particles.clear()
	var prediction_enemy_id := _spawn_enemy("cannon", Vector2(player["pos"]) + Vector2(-310, -35), 30, Vector2(player["pos"]) + Vector2(-310, -35))
	var prediction_enemy: Variant = _find_enemy_by_id(prediction_enemy_id)
	if prediction_enemy != null:
		prediction_enemy["state"] = "telegraph"
		prediction_enemy["telegraph"] = 0.72
		prediction_enemy["telegraph_duration"] = 0.82
		prediction_enemy["pending_pos"] = Vector2(player["pos"]) + Vector2(150, 0)
		prediction_enemy["aim_dir"] = (Vector2(prediction_enemy["pending_pos"]) - Vector2(prediction_enemy["pos"])).normalized()
	for prediction_friend_index in 4:
		var prediction_friend_id := _spawn_soldier(["archer", "rifleman", "tank", "rocket"][prediction_friend_index], Vector2(player["pos"]) + Vector2(-170.0 + float(prediction_friend_index) * 75.0, 105.0 + float(prediction_friend_index % 2) * 46.0))
		var prediction_friend: Variant = _find_soldier_by_id(prediction_friend_id)
		if prediction_friend != null:
			prediction_friend["aim_dir"] = Vector2.RIGHT
	notifications.clear()
	_add_notification("敵我 AI 會預測移動方向；紅色標記是已鎖定、可以閃避的攻擊落點", Color("FFD08A"), 5.0)
	queue_redraw()
	var prediction_ai_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-prediction-ai.png")

	# Terrain contract capture: the hero visibly overlaps the rock, a recruited
	# unit overlaps the bush, and the tree remains a solid routed-around landmark.
	_start_new_game("warrior")
	var terrain_coord := Vector2i(-5, -5)
	var terrain_origin := Vector2(terrain_coord) * WorldGenerator.CHUNK_SIZE
	var terrain_center := terrain_origin + Vector2(WorldGenerator.CHUNK_SIZE * 0.5, WorldGenerator.CHUNK_SIZE * 0.5)
	var terrain_tree := terrain_center + Vector2(-245, 0)
	var terrain_rock := terrain_center
	var terrain_bush := terrain_center + Vector2(245, 0)
	active_chunks.clear()
	active_chunks[world_generator.chunk_key(terrain_coord)] = {
		"key": world_generator.chunk_key(terrain_coord), "chunk": terrain_coord,
		"grass_color": {"r": 0.27, "g": 0.48, "b": 0.25}, "decorations": [],
		"obstacles": [
			{"type": "tree", "position": terrain_tree, "radius": 32.0},
			{"type": "rock", "position": terrain_rock, "radius": 28.0},
			{"type": "bush", "position": terrain_bush, "radius": 27.0},
		],
		"castle": null, "camp": null, "house": null, "enemy_spawns": [],
	}
	castles.clear()
	camps.clear()
	snake_nests.clear()
	enemies.clear()
	soldiers.clear()
	projectiles.clear()
	hazards.clear()
	particles.clear()
	floaters.clear()
	python_boss = null
	player["pos"] = terrain_rock
	player["facing"] = Vector2.RIGHT
	camera_pos = terrain_center
	camera_target = camera_pos
	_spawn_soldier("swordsman", terrain_bush)
	_spawn_soldier("archer", terrain_tree + Vector2(-92, 82))
	_add_floater(terrain_tree + Vector2(0, -75), "樹木：仍會阻擋", Color("FFF0DA"), 5.0)
	_add_floater(terrain_rock + Vector2(0, -72), "石頭：可直接穿越", Color("9FE8FF"), 5.0)
	_add_floater(terrain_bush + Vector2(0, -72), "草叢：可直接穿越", Color("B7F3A5"), 5.0)
	notifications.clear()
	_add_notification("地形修正：石頭與草叢可穿越；樹木仍阻擋，士兵會自動繞開", Color("D7F4C7"), 5.0)
	queue_redraw()
	var terrain_rules_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-terrain-passability.png")

	_web_force_boss_for_test([])
	tutorial_visible = false
	notifications.clear()
	_add_notification("腐沼蟒皇・薩迦已在蟒蛇 Boss 巢穴現身！", Color("F2A8FF"), 5.0)
	queue_redraw()
	var saga_lair_ok: bool = await _capture_visual_frame("res://output/infinite-legion-saga-lair.png")
	python_boss.debug_force_skill("dash")
	notifications.clear()
	_add_notification("強化蟒皇：更高傷害、更快追擊；每一招皆有實際傷害與清楚預警", Color("F2A8FF"), 5.0)
	for _boss_step in 20:
		_simulate_game(FIXED_STEP)
		_update_camera(FIXED_STEP)
	queue_redraw()
	var boss_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-python-boss.png")
	for _boss_damage_step in 55:
		_simulate_game(FIXED_STEP)
		_update_camera(FIXED_STEP)
	player["invuln"] = 0.0
	_apply_python_boss_event({
		"type": "damage", "target": "player:0", "amount": float(GameConfig.PYTHON_BOSS_CONFIG["base"]["damage"]) * float(GameConfig.PYTHON_BOSS_CONFIG["skills"]["dash"]["damage_multiplier"]),
		"kind": "dash", "source_pos": _python_boss_position(),
	})
	queue_redraw()
	var boss_damage_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-python-boss-damage.png")

	# Recruit milestone: the real two-column shop plus the five purchasable
	# technology units, including the stronger blue-armored heavy cannon.
	_start_new_game("warrior")
	player["level"] = 24
	player["money"] = 12000
	player["pos"] = HOUSE_POS + Vector2(0, 145)
	player["facing"] = Vector2.RIGHT
	camera_pos = player["pos"]
	camera_target = camera_pos
	recruit_anchor = HOUSE_POS
	soldiers.clear()
	enemies.clear()
	projectiles.clear()
	particles.clear()
	var recruit_showcase_types := ["cannon", "musketeer", "rifleman", "tank", "rocket"]
	for recruit_index in recruit_showcase_types.size():
		var recruit_type: String = str(recruit_showcase_types[recruit_index])
		var soldier_position := Vector2(player["pos"]) + Vector2(-300.0 + float(recruit_index) * 150.0, 95.0 + absf(float(recruit_index) - 2.0) * 32.0)
		var recruit_id := _spawn_soldier(recruit_type, soldier_position)
		var recruit_unit: Variant = _find_soldier_by_id(recruit_id)
		if recruit_unit != null:
			recruit_unit["aim_dir"] = Vector2(0.95, -0.30).normalized()
	notifications.clear()
	_add_notification("玩家科技招募：重型大砲傷害 112 ＞ 普通大砲傷害 72", Color("C9EDFF"), 5.0)
	active_panel = ""
	queue_redraw()
	var recruit_field_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-recruits-field.png")
	active_panel = "recruit"
	queue_redraw()
	var recruit_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-recruits-expanded.png")
	language = "en"
	queue_redraw()
	var recruit_english_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-recruits-expanded-en.png")
	language = "zh_TW"
	active_panel = "command"
	soldier_command = "攻城"
	notifications.clear()
	queue_redraw()
	var command_panel_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-command-panel.png")
	language = "en"
	queue_redraw()
	var command_panel_english_ok: bool = await _capture_visual_frame("/tmp/infinite-legion-command-panel-en.png")
	language = "zh_TW"
	var all_visual_ok := class_ok and touch_class_ok and touch_controls_ok and battle_ok and sparse_lairs_ok and map_tiers_ok and castle_20_ok and castle_30_ok and castle_35_ok and castle_40_ok and castle_40_breached_ok and friendly_gate_ok and city_garrison_ok and siege_order_ok and castle_45_ok and castle_50_ok and prediction_ai_ok and terrain_rules_ok and saga_lair_ok and boss_ok and boss_damage_ok and recruit_field_ok and recruit_ok and recruit_english_ok and command_panel_ok and command_panel_english_ok
	if all_visual_ok:
		print("VISUAL_SMOKE_PASS")
	else:
		push_error("VISUAL_SMOKE_FAIL")
	get_tree().quit(0 if all_visual_ok else 1)


func _capture_visual_frame(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	return image.save_png(path) == OK

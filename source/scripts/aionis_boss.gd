class_name AionisBossController
extends RefCounted

## 終局 Boss「諸界終時者・艾歐尼斯」控制器。
## 事件驅動、可序列化、可回放，與主程式以事件字典溝通。

enum State {
	IDLE,
	CHASE,
	TELEGRAPH,
	RECOVERY,
	RETURNING,
	DEAD,
}

const STATE_NAMES := ["IDLE", "CHASE", "TELEGRAPH", "RECOVERY", "RETURNING", "DEAD"]
const SOURCE_ID := "aionis_boss"
const BOSS_ENTITY_ID := -990002
const SAVE_VERSION := 3
const TELEGRAPH_MIN_SECONDS := 0.28
const THREAT_DECAY_PER_SECOND := 8.2
const TIME_ANCHOR_COUNT := 4
const ANCHOR_BREAK_WINDOW := 5.0
const ANCHOR_MAX_HP := 240.0

const SKILL_IDS: Array[String] = [
	"clock_sever",
	"causal_hunt",
	"chrono_prison",
	"rewind_rebirth",
	"parallel_legion",
	"rift_board",
	"star_gate_barrage",
	"army_judgment",
	"causal_mirror",
	"twelfth_bell",
]

const DEFAULT_SKILL_DATA: Dictionary = {
	"clock_sever": {
		"name": "時針斬界",
		"phase": [0, 3],
		"weight": [1.40, 1.28, 1.16, 1.30],
		"cooldown": [4.9, 4.4, 3.9, 3.5],
		"telegraph": [0.52, 0.48, 0.45, 0.41],
		"recovery": [0.94, 0.90, 0.82, 0.76],
		"damage": [2300.0, 2800.0, 3400.0, 4100.0],
		"radius": [150.0, 170.0, 195.0, 220.0],
		"width": [24.0, 25.0, 27.0, 29.0],
	},
	"causal_hunt": {
		"name": "因果追獵",
		"phase": [0, 3],
		"weight": [1.10, 1.20, 1.25, 1.38],
		"cooldown": [6.8, 6.2, 5.6, 5.1],
		"telegraph": [0.46, 0.43, 0.40, 0.36],
		"recovery": [1.00, 0.92, 0.86, 0.81],
		"damage": [1000.0, 1240.0, 1500.0, 1860.0],
		"projectile_count": [4, 5, 6, 7],
		"radius": [14.0, 15.0, 16.0, 18.0],
		"lifetime": [4.1, 4.6, 5.0, 5.5],
	},
	"chrono_prison": {
		"name": "時牢封軍",
		"phase": [1, 3],
		"weight": [0.85, 1.00, 1.18, 1.34],
		"cooldown": [10.4, 9.2, 8.3, 7.7],
		"telegraph": [0.66, 0.60, 0.55, 0.50],
		"recovery": [1.36, 1.22, 1.14, 1.08],
		"damage": [1180.0, 1420.0, 1760.0, 2120.0],
		"radius": [225.0, 255.0, 290.0, 320.0],
		"count": [2, 3, 4, 4],
		"anchor_duration": [3.2, 3.6, 4.0, 4.4],
	},
	"rewind_rebirth": {
		"name": "逆時回生",
		"phase": [1, 3],
		"weight": [0.86, 1.01, 1.22, 1.43],
		"cooldown": [11.8, 10.4, 9.2, 8.4],
		"telegraph": [0.58, 0.54, 0.50, 0.46],
		"recovery": [1.48, 1.34, 1.24, 1.12],
		"damage": [1500.0, 1700.0, 1960.0, 2330.0],
		"radius": [280.0, 305.0, 330.0, 365.0],
		"rings": [2, 3, 3, 4],
		"jump_count": [2, 2, 3, 4],
	},
	"parallel_legion": {
		"name": "平行軍團",
		"phase": [1, 3],
		"weight": [0.95, 1.08, 1.22, 1.44],
		"cooldown": [14.6, 13.2, 12.0, 11.0],
		"telegraph": [0.50, 0.46, 0.43, 0.40],
		"recovery": [1.18, 1.08, 1.00, 0.94],
		"damage": [930.0, 1120.0, 1320.0, 1580.0],
		"count": [2, 3, 3, 4],
		"radius": [220.0, 235.0, 255.0, 285.0],
	},
	"rift_board": {
		"name": "斷界棋盤",
		"phase": [1, 3],
		"weight": [1.03, 1.11, 1.22, 1.38],
		"cooldown": [10.2, 9.5, 8.5, 7.8],
		"telegraph": [0.62, 0.56, 0.50, 0.44],
		"recovery": [1.24, 1.14, 1.06, 0.98],
		"damage": [1500.0, 1760.0, 2010.0, 2380.0],
		"radius": [150.0, 170.0, 194.0, 220.0],
		"segments": [4, 5, 6, 6],
		"reflect": [0.25, 0.30, 0.36, 0.45],
	},
	"star_gate_barrage": {
		"name": "星門炮列",
		"phase": [2, 3],
		"weight": [0.0, 1.14, 1.24, 1.40],
		"cooldown": [0.0, 8.1, 7.2, 6.7],
		"telegraph": [0.0, 0.48, 0.44, 0.40],
		"recovery": [0.0, 1.02, 0.94, 0.88],
		"damage": [0.0, 760.0, 940.0, 1120.0],
		"projectile_count": [0, 14, 16, 19],
		"radius": [16.0, 16.5, 17.8, 18.6],
		"lifetime": [0.0, 2.4, 2.2, 2.0],
	},
	"army_judgment": {
		"name": "軍勢審判",
		"phase": [1, 3],
		"weight": [0.98, 1.12, 1.24, 1.33],
		"cooldown": [9.5, 8.8, 8.0, 7.2],
		"telegraph": [0.70, 0.64, 0.58, 0.52],
		"recovery": [1.28, 1.14, 1.06, 0.97],
		"damage": [2520.0, 2980.0, 3500.0, 4200.0],
		"radius": [225.0, 248.0, 278.0, 312.0],
		"chain": [3, 4, 5, 6],
		"drop": [0.16, 0.18, 0.21, 0.24],
	},
	"causal_mirror": {
		"name": "逆因果鏡",
		"phase": [2, 3],
		"weight": [0.0, 1.16, 1.31, 1.47],
		"cooldown": [0.0, 7.2, 6.4, 5.9],
		"telegraph": [0.0, 0.52, 0.47, 0.41],
		"recovery": [0.0, 1.06, 0.98, 0.90],
		"damage": [0.0, 1680.0, 1930.0, 2320.0],
		"radius": [290.0, 310.0, 340.0, 372.0],
		"mirror_count": [0, 1, 2, 3],
		"lifetime": [0.0, 2.3, 2.6, 2.9],
	},
	"twelfth_bell": {
		"name": "十二刻終焉",
		"phase": [3, 3],
		"weight": [0.0, 0.0, 0.0, 1.0],
		"cooldown": [0.0, 0.0, 0.0, 13.2],
		"telegraph": [0.0, 0.0, 0.0, 0.86],
		"recovery": [0.0, 0.0, 0.0, 1.72],
		"damage": [0.0, 0.0, 0.0, 11600.0],
		"radius": [0.0, 0.0, 0.0, 470.0],
		"projectile_count": [0, 0, 0, 18],
		"lifetime": [0.0, 0.0, 0.0, 4.6],
	},
}

const SKILL_NAME_ZH := {
	"clock_sever": "時針斬界",
	"causal_hunt": "因果追獵",
	"chrono_prison": "時牢封軍",
	"rewind_rebirth": "逆時回生",
	"parallel_legion": "平行軍團",
	"rift_board": "斷界棋盤",
	"star_gate_barrage": "星門炮列",
	"army_judgment": "軍勢審判",
	"causal_mirror": "逆因果鏡",
	"twelfth_bell": "十二刻終焉",
}

const PHASE_NAMES := ["時脈初啟", "時脈裂隙", "因果湧流", "終末鐘響"]

var _config: Dictionary = {}
var _seed := 20260802
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _player_level := 1

var _state: int = State.IDLE
var _state_timer := 0.0
var _active_skill := ""
var _telegraph_skill := ""
var _telegraph_target := ""
var _telegraph_position := Vector2.ZERO
var _telegraph_data: Dictionary = {}
var _telegraph_warning_announced := false
var _combo_queue: Array[String] = []
var _combo_window_timer := 0.0
var _forced_combo: Array[String] = []

var _skill_profiles: Dictionary = {}
var _cooldowns: Dictionary = {}

var _position := Vector2.ZERO
var _home_position := Vector2.ZERO
var _velocity := Vector2.ZERO
var _facing := Vector2.RIGHT
var _radius := 105.0
var _move_speed := 198.0
var _turn_speed := 3.3
var _leash_distance := 1160.0
var _engage_distance := 1440.0
var _return_threshold := 44.0

var _hp := 260000.0
var _max_hp := 260000.0
var _defense := 114.0
var _phase := 0
var _phase_threshold_two := 0.72
var _phase_threshold_three := 0.46
var _phase_threshold_four := 0.20
var _phase_attack_multiplier := 1.0
var _phase_transitioned := false

var _reward_min_gold := 4200
var _reward_max_gold := 7600
var _reward_min_xp := 6200
var _reward_max_xp := 10200
var _reward_given := false
var _pending_defeat_event := false
var _anchor_count := TIME_ANCHOR_COUNT
var _anchor_damage_reduction := 0.48
var _anchor_exposed_seconds := ANCHOR_BREAK_WINDOW

var _is_player_alive := true
var _is_force_engaged := false
var _forced_engage_position: Vector2 = Vector2.INF

var _latest_player: Dictionary = {}
var _latest_soldiers: Array[Dictionary] = []
var _units_by_key: Dictionary = {}
var _target_key := ""
var _target_position := Vector2.ZERO
var _target_velocity := Vector2.ZERO
var _threat: Dictionary = {}
var _threat_seen: Dictionary = {}

var _position_blocked: Callable = Callable()
var _pending_anchor_events: Array[Dictionary] = []

var _telegraph_anchor := ""
var _time_anchors: Dictionary = {}
var _anchor_breach_timer := 0.0
var _anchor_pulse_timer := 0.0
var _anchor_decay_timer := 0.0

func initialize(config: Dictionary, player_level: int, seed: int) -> void:
	_config = config.duplicate(true)
	_player_level = maxi(1, player_level)
	_seed = seed
	_rng.seed = _seed
	_apply_config()
	_reset_runtime(true)

func _apply_config() -> void:
	_hp = float(_config.get("max_hp", 260000.0))
	_hp = clampf(_hp, 1.0, 260000.0)
	_max_hp = _hp

	_home_position = _to_vector2(_config.get("home_position", Vector2(24960.0, 14400.0)), Vector2.ZERO)
	_radius = maxf(42.0, float(_config.get("radius", 105.0)))
	_move_speed = maxf(120.0, float(_config.get("move_speed", 198.0)))
	_turn_speed = maxf(1.2, float(_config.get("turn_speed", 3.4)))
	_defense = maxf(18.0, float(_config.get("defense", 114.0)))
	_leash_distance = maxf(500.0, float(_config.get("leash_distance", 1180.0)))
	_engage_distance = maxf(500.0, float(_config.get("engage_distance", 1460.0)))
	_return_threshold = maxf(16.0, float(_config.get("return_threshold", 42.0)))

	var phase_cfg: Dictionary = Dictionary(_config.get("phase_thresholds", {}))
	_phase_threshold_two = clampf(float(phase_cfg.get("two", 0.72)), 0.5, 0.95)
	_phase_threshold_three = clampf(float(phase_cfg.get("three", 0.46)), 0.28, _phase_threshold_two - 0.08)
	_phase_threshold_four = clampf(float(phase_cfg.get("four", 0.20)), 0.10, _phase_threshold_three - 0.07)

	var reward_cfg: Dictionary = Dictionary(_config.get("rewards", {}))
	_reward_min_gold = maxi(1200, int(reward_cfg.get("gold_min", _reward_min_gold)))
	_reward_max_gold = maxi(_reward_min_gold, int(reward_cfg.get("gold_max", _reward_max_gold)))
	_reward_min_xp = maxi(1800, int(reward_cfg.get("xp_min", _reward_min_xp)))
	_reward_max_xp = maxi(_reward_min_xp, int(reward_cfg.get("xp_max", _reward_max_xp)))
	var anchors_cfg: Dictionary = Dictionary(_config.get("anchors", {}))
	_anchor_count = clampi(int(anchors_cfg.get("count", TIME_ANCHOR_COUNT)), 1, TIME_ANCHOR_COUNT)
	_anchor_damage_reduction = clampf(float(anchors_cfg.get("damage_reduction", 0.48)), 0.0, 1.0)
	_anchor_exposed_seconds = maxf(0.2, float(anchors_cfg.get("exposed_seconds", ANCHOR_BREAK_WINDOW)))

	_skill_profiles.clear()
	for skill_id in SKILL_IDS:
		var merged: Dictionary = DEFAULT_SKILL_DATA.get(skill_id, {}).duplicate(true)
		_skill_profiles[skill_id] = merged

	var raw_profiles: Array = Array(_config.get("skills", []))
	for item in raw_profiles:
		if not item is Dictionary:
			continue
		var sid := str(Dictionary(item).get("id", ""))
		if sid.is_empty() or not _skill_profiles.has(sid):
			continue
		var merged2: Dictionary = Dictionary(_skill_profiles.get(sid, {})).duplicate(true)
		for key in Dictionary(item).keys():
			merged2[key] = Dictionary(item).get(key)
		_skill_profiles[sid] = merged2

	for sid in _config.get("blocked_skills", []):
		if sid is String and _skill_profiles.has(sid):
			_skill_profiles.erase(sid)

	_skill_profiles = _ensure_default_phases(_skill_profiles)
	for sid in SKILL_IDS:
		if _skill_profiles.has(sid):
			_cooldowns[sid] = float(_value_for_phase(_skill_profiles[sid], "cooldown", 1.0))

func _ensure_default_phases(profiles: Dictionary) -> Dictionary:
	for sid in profiles.keys():
		var p := Dictionary(profiles[sid])
		var phase_range := Array(p.get("phase", []))
		if phase_range.is_empty():
			p["min_phase"] = int(p.get("min_phase", 0))
			p["max_phase"] = int(p.get("max_phase", 3))
		elif phase_range.size() >= 2:
			p["min_phase"] = int(phase_range[0])
			p["max_phase"] = int(phase_range[1])
		profiles[sid] = p
	return profiles

func _reset_runtime(reset_home: bool = true) -> void:
	if reset_home:
		_position = _home_position
	_state = State.IDLE
	_state_timer = 0.0
	_active_skill = ""
	_telegraph_skill = ""
	_telegraph_target = ""
	_telegraph_position = _home_position
	_telegraph_data.clear()
	_telegraph_warning_announced = false
	_combo_queue.clear()
	_combo_window_timer = 0.0
	_forced_combo.clear()
	_phase = 0
	_phase_attack_multiplier = 1.0
	_phase_transitioned = false
	_reward_given = false
	_pending_defeat_event = false
	_velocity = Vector2.ZERO
	_facing = Vector2.RIGHT
	_is_force_engaged = false
	_forced_engage_position = Vector2.INF
	_telegraph_anchor = ""
	_is_player_alive = true
	_target_key = ""
	_target_position = _home_position
	_target_velocity = Vector2.ZERO
	_threat.clear()
	_threat_seen.clear()
	_units_by_key.clear()
	_latest_player.clear()
	_latest_soldiers.clear()
	_position_blocked = Callable()
	_pending_anchor_events.clear()
	_anchor_breach_timer = 0.0
	_anchor_decay_timer = 0.0
	_anchor_pulse_timer = 0.0
	_time = 0.0

	for sid in SKILL_IDS:
		if _skill_profiles.has(sid):
			_cooldowns[sid] = float(_value_for_phase(_skill_profiles.get(sid, {}), "cooldown", 4.0))
	_build_time_anchors(true)

func update(delta: float, context: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	delta = maxf(0.0, delta)
	if _state == State.DEAD:
		if _pending_defeat_event:
			events.append({"type": "defeated", "source": SOURCE_ID, "gold": 0, "xp": 0})
			_pending_defeat_event = false
		return events

	_time += delta
	var anchor_breach_was_active := _anchor_breach_timer > 0.0
	if anchor_breach_was_active:
		_anchor_breach_timer = maxf(0.0, _anchor_breach_timer - delta)
	# Destroying all four anchors opens exactly one five-second damage window.
	# Once it closes, the shield cycle begins again instead of leaving the Boss
	# permanently unprotected with four visually broken anchors.
	if anchor_breach_was_active and _anchor_breach_timer <= 0.0 and _all_time_anchors_broken():
		_build_time_anchors(true)
		events.append(_notice("5秒破防結束，4個時間錨重新構成。"))
		events.append({"type": "effect", "kind": "time_anchor_reform", "pos": _home_position, "radius": 310.0, "duration": 0.86})
		events.append({"type": "audio", "cue": "aionis_anchor_reform"})

	_read_context(context)
	_tick_cooldowns(delta)
	_decay_threat(delta)
	_update_phase_if_needed(events)
	_update_anchor_system(delta, events)
	_update_target_preference()
	_advance_mode(events)

	if not _pending_anchor_events.is_empty():
		events.append_array(_pending_anchor_events)
		_pending_anchor_events.clear()

	match _state:
		State.IDLE:
			_update_idle(delta, events)
		State.CHASE:
			_update_chase(delta, events)
		State.TELEGRAPH:
			_update_telegraph(delta, events)
		State.RECOVERY:
			_update_recovery(delta, events)
		State.RETURNING:
			_update_returning(delta, events)

	if _pending_defeat_event:
		events.append({"type": "reward", "gold": _reward_drop_gold(), "xp": _reward_drop_xp()})
		events.append(_notice("諸界終時者・艾歐尼斯被擊碎，時脈正在崩散。"))
		events.append({"type": "effect", "kind": "aionis_defeat", "pos": _position, "radius": 240.0, "duration": 2.6})
		events.append({"type": "audio", "cue": "aionis_defeated"})
		_pending_defeat_event = false

	if _phase_transitioned:
		_phase_transitioned = false
		events.append(_notice("諸界終時者進入「%s」。" % PHASE_NAMES[_phase]))
		events.append({"type": "audio", "cue": "aionis_phase_%d" % (_phase + 1)})
		events.append({"type": "phase", "phase": _phase + 1, "name": PHASE_NAMES[_phase]})

	return events

func receive_hit(damage: float, source_id: String, source_pos: Vector2, damage_type: String = "normal") -> Dictionary:
	var result: Dictionary = {
		"accepted": false,
		"damage": 0.0,
		"hp": _hp,
		"max_hp": _max_hp,
		"defeated": false,
		"events": [],
	}
	if _state == State.DEAD or damage <= 0.0:
		return result

	var raw := maxf(0.0, damage)
	var defense_factor := _compute_defense_factor()
	if damage_type == "true":
		defense_factor = 0.0
	var mitigated := maxf(1.0, roundf(raw * (1.0 - defense_factor)))
	# 活著的時間錨提供的是額外 48% 傷害減免，而不是把防禦係數縮小。
	# 四錨全破後的 5 秒破防則由 _compute_defense_factor() 幾乎移除防禦。
	if damage_type != "true" and _phase >= 1 and _anchor_count > 0 and not _all_time_anchors_broken():
		mitigated = maxf(1.0, roundf(mitigated * (1.0 - _anchor_damage_reduction)))
	var final_damage := mitigated
	_hp = maxf(0.0, _hp - final_damage)
	result["accepted"] = true
	result["damage"] = final_damage
	result["hp"] = _hp
	result["max_hp"] = _max_hp

	var events: Array[Dictionary] = []
	events.append({
		"type": "damage",
		"target": SOURCE_ID,
		"amount": final_damage,
		"source": source_id,
		"source_id": BOSS_ENTITY_ID,
		"skill": "player_hit",
		"source_skill": source_id,
	})

	if source_pos.is_finite():
		_apply_anchor_damage(source_pos, final_damage)

	if source_id != "":
		_record_threat(source_id, final_damage * 1.1)
	if bool(source_id != ""):
		_is_force_engaged = true
		if _state == State.IDLE:
			_state = State.CHASE

	if _hp <= 0.0:
		_die(events)
		result["defeated"] = true

	result["events"] = events
	return result


func get_anchor_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for anchor_id in _time_anchors.keys():
		var anchor := Dictionary(_time_anchors[anchor_id])
		result.append({
			"id": str(anchor_id),
			"position": Vector2(anchor.get("pos", _home_position)),
			"radius": float(anchor.get("radius", 58.0)),
			"hp": float(anchor.get("hp", 0.0)),
			"max_hp": float(anchor.get("max_hp", ANCHOR_MAX_HP)),
			"broken": bool(anchor.get("broken", false)),
		})
	return result


func receive_anchor_hit(anchor_id: String, damage: float, source_id: String = "") -> Dictionary:
	var result := {"accepted": false, "damage": 0.0, "anchor_id": anchor_id, "broken": false, "events": []}
	if _state == State.DEAD or damage <= 0.0 or not _time_anchors.has(anchor_id):
		return result
	var anchor := Dictionary(_time_anchors[anchor_id])
	if bool(anchor.get("broken", false)):
		return result
	var dealt := minf(maxf(1.0, damage), float(anchor.get("hp", ANCHOR_MAX_HP)))
	anchor["hp"] = maxf(0.0, float(anchor.get("hp", ANCHOR_MAX_HP)) - dealt)
	if float(anchor["hp"]) <= 0.0:
		anchor["broken"] = true
		_time_anchors[anchor_id] = anchor
		_time_anchor_destroyed(anchor_id)
	else:
		_time_anchors[anchor_id] = anchor
	if not source_id.is_empty():
		_record_threat(source_id, dealt * 0.75)
	_is_force_engaged = true
	if _state == State.IDLE:
		_state = State.CHASE
	var hit_events: Array[Dictionary] = [{
		"type": "effect", "kind": "time_anchor_hit",
		"pos": Vector2(anchor.get("pos", _home_position)), "radius": float(anchor.get("radius", 58.0)), "duration": 0.24,
	}]
	if bool(anchor.get("broken", false)):
		hit_events.append({"type": "effect", "kind": "anchor_broken", "pos": Vector2(anchor.get("pos", _home_position)), "radius": 78.0, "duration": 0.86})
	result["accepted"] = true
	result["damage"] = dealt
	result["broken"] = bool(anchor.get("broken", false))
	result["events"] = hit_events
	return result

func force_engage(player_pos: Vector2) -> void:
	_is_force_engaged = true
	_forced_engage_position = player_pos
	_state = State.CHASE
	_target_key = "player:0"

func debug_force_skill(skill_id: String) -> void:
	if not SKILL_IDS.has(skill_id) or not _skill_profiles.has(skill_id):
		return
	_cooldowns[skill_id] = 0.0
	_forced_skill(skill_id)

func debug_force_combo(skills: Array[String]) -> void:
	_combo_queue.clear()
	for raw_id in skills:
		if typeof(raw_id) != TYPE_STRING:
			continue
		var skill_id := String(raw_id).strip_edges()
		if skill_id.is_empty():
			continue
		if not SKILL_IDS.has(skill_id):
			continue
		if not _skill_profiles.has(skill_id):
			continue
		_cooldowns[skill_id] = 0.0
		_combo_queue.append(skill_id)
	if _combo_queue.is_empty():
		return
	# Force directly consumed by next Chase cycle.
	var forced: Array[String] = []
	forced.assign(_combo_queue)
	_forced_combo = forced.duplicate(true)
	_combo_queue.clear()

func _forced_skill(value: String) -> void:
	_forced_skill_value = value

var _forced_skill_value := ""

func _release_forced_skill() -> String:
	if _forced_skill_value == "":
		return ""
	var v := _forced_skill_value
	_forced_skill_value = ""
	return v

func debug_set_hp_ratio(ratio: float) -> void:
	_hp = clampf(ratio, 0.0, 1.0) * _max_hp
	_update_phase_if_needed([])

func is_engaged() -> bool:
	return _state != State.IDLE and _state != State.RETURNING and _state != State.DEAD

func is_damageable() -> bool:
	return _state != State.DEAD

func is_defeated() -> bool:
	return _state == State.DEAD

func is_locked_by_skill() -> bool:
	return _state == State.TELEGRAPH or _state == State.RECOVERY

func get_position() -> Vector2:
	return _position

func get_radius() -> float:
	return _radius * (1.0 + float(_phase) * 0.06)

func get_text_state() -> Dictionary:
	return {
		"id": String(_config.get("id", "aionis_boss")),
		"name": String(_config.get("name", "諸界終時者・艾歐尼斯")),
		"state": STATE_NAMES[clampi(_state, 0, STATE_NAMES.size() - 1)],
		"phase": _phase + 1,
		"phase_name": PHASE_NAMES[_phase],
		"hp": snappedf(_hp, 0.1),
		"max_hp": snappedf(_max_hp, 0.1),
		"hp_ratio": snappedf(_hp / maxf(_max_hp, 1.0), 0.001),
		"defeated": is_defeated(),
		"engaged": is_engaged(),
		"active_skill": _active_skill,
		"telegraph_skill": _telegraph_skill,
		"telegraph_timer": snappedf(_state_timer, 0.01),
		"telegraph_x": snappedf(_telegraph_position.x, 0.1),
		"telegraph_y": snappedf(_telegraph_position.y, 0.1),
		"x": snappedf(_position.x, 0.1),
		"y": snappedf(_position.y, 0.1),
		"velocity_x": snappedf(_velocity.x, 0.1),
		"velocity_y": snappedf(_velocity.y, 0.1),
		"target": _target_key,
		"combo_queue": _combo_queue.duplicate(true),
		"combo_size": _combo_queue.size(),
		"combo_skills": _combo_queue.duplicate(true),
		"time_anchor_breach": snappedf(_anchor_breach_timer, 0.01),
		"anchors_total": _time_anchors.size(),
		"anchors_broken": _broken_anchor_count(),
		"anchor_damage_reduction": _anchor_damage_reduction,
		"anchor_exposed_seconds": _anchor_exposed_seconds,
		"rng": int(_rng.state),
	}

func render_snapshot() -> Dictionary:
	var anchors: Array[Dictionary] = []
	for anchor_id in _time_anchors.keys():
		var anchor := Dictionary(_time_anchors[anchor_id])
		anchors.append({
			"id": String(anchor_id),
			"x": anchor.get("pos", Vector2.ZERO).x,
			"y": anchor.get("pos", Vector2.ZERO).y,
			"hp": float(anchor.get("hp", 0.0)),
			"max_hp": float(anchor.get("max_hp", 0.0)),
			"broken": bool(anchor.get("broken", false)),
		})
	return {
		"position": _position,
		"radius": get_radius(),
		"state": STATE_NAMES[clampi(_state, 0, STATE_NAMES.size() - 1)],
		"phase": _phase + 1,
		"hp_ratio": _hp / maxf(_max_hp, 1.0),
		"facing": _facing,
		"active_skill": _active_skill,
		"telegraph": _telegraph_data.duplicate(true),
		"telegraph_position": _telegraph_position,
		"telegraph_skill": _telegraph_skill,
		"time_anchors": anchors,
	}

func serialize() -> Dictionary:
	var cooldowns := {}
	for sid in _cooldowns.keys():
		cooldowns[str(sid)] = float(_cooldowns[sid])
	var anchors: Array[Dictionary] = []
	for anchor_id in _time_anchors.keys():
		var anchor := Dictionary(_time_anchors[anchor_id])
		anchors.append({
			"id": str(anchor.get("id", anchor_id)),
			"x": float(anchor.get("pos", Vector2.ZERO).x),
			"y": float(anchor.get("pos", Vector2.ZERO).y),
			"radius": float(anchor.get("radius", 56.0)),
			"max_hp": float(anchor.get("max_hp", ANCHOR_MAX_HP)),
			"hp": float(anchor.get("hp", ANCHOR_MAX_HP)),
			"broken": bool(anchor.get("broken", false)),
		})
	return {
		"version": SAVE_VERSION,
		"state": _state,
		"phase": _phase,
		"hp": _hp,
		"max_hp": _max_hp,
		"position": _position,
		"home_position": _home_position,
		"radius": _radius,
		"player_level": _player_level,
		"seed": _seed,
		"rng_state": int(_rng.state),
		"cooldowns": cooldowns,
		"target_key": _target_key,
		"telegraph_skill": _telegraph_skill,
		"telegraph_target": _telegraph_target,
		"telegraph_position": _telegraph_position,
		"telegraph_data": _telegraph_data,
		"telegraph_warning_announced": _telegraph_warning_announced,
		"state_timer": _state_timer,
		"reward_given": _reward_given,
		"combo_queue": _combo_queue,
		"time_anchors": anchors,
		"anchor_breach_timer": _anchor_breach_timer,
		"defeated": is_defeated(),
	}

func restore(data: Dictionary) -> bool:
	if data.is_empty() or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	_state = int(data.get("state", State.IDLE))
	_state = clampi(_state, State.IDLE, State.DEAD)
	_phase = clampi(int(data.get("phase", 0)), 0, 3)
	_phase_attack_multiplier = 1.0 + float(_phase) * 0.12
	_hp = maxf(0.0, float(data.get("hp", _max_hp)))
	_max_hp = maxf(1.0, float(data.get("max_hp", _max_hp)))
	_position = _to_vector2(data.get("position", _home_position), _home_position)
	_home_position = _to_vector2(data.get("home_position", _home_position), _home_position)
	_player_level = int(data.get("player_level", _player_level))
	_seed = int(data.get("seed", _seed))
	_rng.seed = _seed
	_rng.state = int(data.get("rng_state", _rng.state))
	_reward_given = bool(data.get("reward_given", false))
	_target_key = str(data.get("target_key", ""))
	_telegraph_skill = str(data.get("telegraph_skill", ""))
	_telegraph_target = str(data.get("telegraph_target", ""))
	_telegraph_position = _to_vector2(data.get("telegraph_position", _position), _position)
	_telegraph_data = Dictionary(data.get("telegraph_data", {}))
	_telegraph_warning_announced = bool(data.get("telegraph_warning_announced", false))
	_state_timer = float(data.get("state_timer", 0.0))
	_combo_queue = []
	for sid in Array(data.get("combo_queue", [])):
		_combo_queue.append(str(sid))
	_anchor_breach_timer = float(data.get("anchor_breach_timer", 0.0))
	_time_anchors.clear()
	for item in Array(data.get("time_anchors", [])):
		if not item is Dictionary:
			continue
		var anchor := Dictionary(item)
		var aid := str(anchor.get("id", ""))
		if aid.is_empty():
			continue
		_time_anchors[aid] = {
			"id": aid,
			"pos": Vector2(float(anchor.get("x", _home_position.x)), float(anchor.get("y", _home_position.y))),
			"radius": float(anchor.get("radius", 56.0)),
			"max_hp": float(anchor.get("max_hp", ANCHOR_MAX_HP)),
			"hp": float(anchor.get("hp", anchor.get("max_hp", ANCHOR_MAX_HP))),
			"broken": bool(anchor.get("broken", false)),
		}
	var saved_cds: Dictionary = Dictionary(data.get("cooldowns", {}))
	for sid in SKILL_IDS:
		if not _skill_profiles.has(sid):
			continue
		_cooldowns[sid] = float(saved_cds.get(sid, _value_for_phase(_skill_profiles[sid], "cooldown", 1.0)))
	if _hp <= 0.0:
		_state = State.DEAD
		_reward_given = true
	if _state != State.DEAD:
		_state = State.IDLE
		_position = _home_position
		_state_timer = 0.0
		_active_skill = ""
		_telegraph_skill = ""
		_telegraph_target = ""
		_telegraph_position = _position
		_telegraph_data.clear()
		_telegraph_warning_announced = false
		_combo_queue.clear()
		_forced_combo.clear()
		_forced_skill_value = ""
	return true

func _advance_mode(events: Array[Dictionary]) -> void:
	if _state == State.DEAD or is_locked_by_skill():
		return
	if _state == State.IDLE:
		if _is_force_engaged or (_latest_player.get("alive", false) and _position.distance_to(Vector2(_latest_player.get("pos", _position))) <= _engage_distance):
			_state = State.CHASE
			events.append(_notice("艾歐尼斯已發現威脅，拉開戰鬥節奏。"))
	elif _state == State.CHASE:
		if _should_return_home():
			_state = State.RETURNING
			events.append(_notice("艾歐尼斯遠離戰區準備重整。"))

func _update_idle(delta: float, events: Array[Dictionary]) -> void:
	_active_skill = ""
	_telegraph_skill = ""
	_velocity = Vector2.ZERO
	if _position.distance_to(_home_position) > _return_threshold:
		_move_toward(_home_position, delta, 0.8)
	if _is_force_engaged:
		_state = State.CHASE
		_is_force_engaged = false
		events.append(_notice("艾歐尼斯重新進入追擊節奏。"))

func _update_chase(delta: float, events: Array[Dictionary]) -> void:
	if _target_key.is_empty():
		_update_target_preference()
	if _target_key.is_empty():
		if _is_force_engaged:
			_target_position = _forced_engage_position
		else:
			_state = State.RETURNING
			return
	var target_pos := _resolve_target_position(_target_key)
	_move_toward(target_pos, delta, 1.1)
	if _state_timer > 0.0:
		return
	if not _can_cast_skill():
		return
	if _combo_queue.is_empty():
		_prepare_combo_if_needed()
	if _combo_queue.is_empty():
		return
	var skill_id := String(_combo_queue[0])
	if skill_id == "":
		return
	if float(_cooldowns.get(skill_id, 0.0)) > 0.0:
		_combo_queue.clear()
		return
	_begin_skill(skill_id, target_pos, events)

func _update_telegraph(delta: float, events: Array[Dictionary]) -> void:
	if _state_timer <= 0.0:
		_execute_skill(events)
		return
	_state_timer = maxf(0.0, _state_timer - delta)
	if not _telegraph_warning_announced:
		var name := String(SKILL_NAME_ZH.get(_telegraph_skill, _telegraph_skill))
		events.append(_notice("艾歐尼斯釋放：%s。" % name))
		events.append({"type": "audio", "cue": "aionis_%s_warning" % _telegraph_skill})
		events.append({
			"type": "effect",
			"kind": "telegraph_%s" % _telegraph_skill,
			"pos": _telegraph_position,
			"radius": float(_telegraph_data.get("radius", _radius)),
			"duration": float(_telegraph_data.get("telegraph", TELEGRAPH_MIN_SECONDS)),
		})
		if _telegraph_anchor != "":
			events.append({
				"type": "effect",
				"kind": "time_anchor_focus",
				"pos": _get_anchor_pos(_telegraph_anchor),
				"radius": 58.0,
				"duration": 0.72,
			})
		_telegraph_warning_announced = true

func _update_recovery(delta: float, events: Array[Dictionary]) -> void:
	if _state_timer <= 0.0:
		_state = State.CHASE
		_state_timer = 0.0
		_telegraph_warning_announced = false
		return
	_state_timer = maxf(0.0, _state_timer - delta)
	events.append(_passive_loop_state_event())
	if _should_return_home():
		_state = State.RETURNING

func _update_returning(delta: float, events: Array[Dictionary]) -> void:
	_move_toward(_home_position, delta, 1.25)
	if _position.distance_to(_home_position) <= _return_threshold:
		_position = _home_position
		_state = State.IDLE
		_is_force_engaged = false
		events.append(_notice("艾歐尼斯回到核心區域。"))

func _tick_cooldowns(delta: float) -> void:
	for sid in _cooldowns.keys():
		_cooldowns[sid] = maxf(0.0, float(_cooldowns[sid]) - delta)

func _decay_threat(delta: float) -> void:
	for key in _threat.keys():
		var current := float(_threat[key]) - THREAT_DECAY_PER_SECOND * delta
		if current <= 0.0:
			_threat.erase(key)
			_threat_seen.erase(key)
		else:
			_threat[key] = current

func _read_context(context: Dictionary) -> void:
	var player_data: Dictionary = Dictionary(context.get("player", {}))
	var soldiers: Array = context.get("soldiers", [])
	if not soldiers is Array:
		soldiers = []
	_latest_player = player_data.duplicate(true)
	_latest_player["kind"] = "player"
	_units_by_key.clear()
	_latest_soldiers.clear()
	if not _latest_player.is_empty():
		var pid := int(_latest_player.get("id", 0))
		var key := "player:%d" % pid
		_units_by_key[key] = _latest_player.duplicate(true)
		_units_by_key[key]["alive"] = bool(_latest_player.get("alive", true))
		_record_seen(key)
		_record_base_threat(key, 2.4)
	for item in soldiers:
		if not item is Dictionary:
			continue
		var soldier := Dictionary(item)
		var sid := "soldier:%d" % int(soldier.get("id", -1))
		_units_by_key[sid] = soldier.duplicate(true)
		_latest_soldiers.append(soldier)
		_record_seen(sid)
		_record_base_threat(sid, 1.2)
	var callable_candidate: Variant = context.get("position_blocked", Callable())
	if callable_candidate is Callable and callable_candidate.is_valid():
		_position_blocked = callable_candidate
	_is_player_alive = bool(_latest_player.get("alive", true))

func _update_phase_if_needed(events: Array[Dictionary]) -> void:
	var ratio := _hp / maxf(_max_hp, 1.0)
	var target_phase := 0
	if ratio <= _phase_threshold_four:
		target_phase = 3
	elif ratio <= _phase_threshold_three:
		target_phase = 2
	elif ratio <= _phase_threshold_two:
		target_phase = 1
	if target_phase > _phase:
		_phase = target_phase
		_phase_attack_multiplier = 1.0 + float(_phase) * 0.12
		_phase_transitioned = true
		_build_time_anchors(true)

func _should_return_home() -> bool:
	return _position.distance_to(_home_position) > _leash_distance

func _can_cast_skill() -> bool:
	return _state_timer <= 0.0 and not is_locked_by_skill()

func _prepare_combo_if_needed() -> void:
	if not _forced_combo.is_empty():
		_combo_queue = _forced_combo.duplicate(true)
		_forced_combo.clear()
		return
	var forced := _release_forced_skill()
	if forced != "":
		_combo_queue.append(forced)
		return
	var needed := 1
	if _phase == 2:
		needed = 2
	elif _phase >= 3:
		needed = 3
	var candidates := _available_skills()
	if candidates.is_empty():
		return
	while _combo_queue.size() < needed and candidates.size() > 0:
		var next_skill := _pick_weighted_skill(candidates)
		if next_skill == "":
			break
		_combo_queue.append(next_skill)
		candidates.erase(next_skill)
	if _combo_queue.is_empty() and needed > 0:
		var fallback := _pick_weighted_skill(_available_skills())
		if fallback != "":
			_combo_queue.append(fallback)

func _available_skills() -> Array[String]:
	var result: Array[String] = []
	for sid in SKILL_IDS:
		if not _skill_profiles.has(sid):
			continue
		if float(_cooldowns.get(sid, 0.0)) > 0.0:
			continue
		if not _is_skill_allowed_by_phase(sid):
			continue
		result.append(sid)
	return result

func _is_skill_allowed_by_phase(skill_id: String) -> bool:
	if not _skill_profiles.has(skill_id):
		return false
	var p := Dictionary(_skill_profiles[skill_id])
	var pmin := int(p.get("min_phase", 0))
	var pmax := int(p.get("max_phase", 3))
	return _phase >= pmin and _phase <= pmax

func _pick_weighted_skill(candidates: Array[String]) -> String:
	if candidates.is_empty():
		return ""
	var weighted: Array[Array] = []
	var total_weight := 0.0
	for sid in candidates:
		if not _skill_profiles.has(sid):
			continue
		var profile := Dictionary(_skill_profiles[sid])
		var w := float(_value_for_phase(profile, "weight", 1.0))
		if w <= 0.0:
			continue
		weighted.append([sid, w])
		total_weight += w
	if weighted.is_empty():
		return str(candidates[0])
	var roll := _rng.randf() * total_weight
	var acc := 0.0
	for e in weighted:
		var sid := String(e[0])
		var w := float(e[1])
		acc += w
		if roll <= acc:
			return sid
	return String(weighted[-1][0])

func _begin_skill(skill_id: String, target_pos: Vector2, events: Array[Dictionary]) -> void:
	_active_skill = skill_id
	_telegraph_skill = skill_id
	_state = State.TELEGRAPH
	_telegraph_warning_announced = false
	var profile := Dictionary(_skill_profiles.get(skill_id, {}))
	var telegraph_time := maxf(float(_value_for_phase(profile, "telegraph", TELEGRAPH_MIN_SECONDS)), TELEGRAPH_MIN_SECONDS)
	_state_timer = telegraph_time
	_telegraph_target = _target_key if not _target_key.is_empty() else "player:0"
	_target_position = _resolve_target_position(_target_key)
	_telegraph_position = _choose_telegraph_position(target_pos)
	_telegraph_data = {
		"skill": skill_id,
		"telegraph": telegraph_time,
		"phase": _phase,
		"radius": float(_value_for_phase(profile, "radius", _radius * 1.2)),
		"recovery": float(_value_for_phase(profile, "recovery", 1.0)),
	}
	_telegraph_anchor = ""
	if _phase >= 1:
		var live_anchors: Array[String] = []
		for anchor_id in _time_anchors.keys():
			if not bool(Dictionary(_time_anchors[anchor_id]).get("broken", false)):
				live_anchors.append(String(anchor_id))
		if not live_anchors.is_empty():
			_telegraph_anchor = live_anchors[_rng.randi_range(0, live_anchors.size() - 1)]
	if _telegraph_anchor != "":
		events.append({
			"type": "effect",
			"kind": "time_anchor_focus",
			"pos": _get_anchor_pos(_telegraph_anchor),
			"radius": 58.0,
			"duration": telegraph_time,
		})
	events.append({"type": "audio", "cue": "aionis_%s_charge" % skill_id})

func _execute_skill(events: Array[Dictionary]) -> void:
	if _telegraph_skill == "" and not _combo_queue.is_empty():
		_telegraph_skill = String(_combo_queue[0])
	var skills_payload := _combo_queue.duplicate(true)
	if skills_payload.is_empty() and _telegraph_skill != "":
		skills_payload.append(_telegraph_skill)
	if skills_payload.is_empty():
		_state = State.CHASE
		_state_timer = 0.0
		_telegraph_skill = ""
		_telegraph_warning_announced = false
		return
	var combo_lead := ""
	var executed_skills: Array[String] = []
	var combo_recovery := 0.0
	var executed_any := false
	for sid in skills_payload:
		var skill_id := String(sid).strip_edges()
		if skill_id == "" or not SKILL_IDS.has(skill_id):
			continue
		if float(_cooldowns.get(skill_id, 0.0)) > 0.0:
			continue
		_execute_single_skill(skill_id, events)
		var sid_profile := Dictionary(_skill_profiles.get(skill_id, {}))
		var sid_recovery := float(_value_for_phase(sid_profile, "recovery", 1.0))
		combo_recovery = maxf(combo_recovery, sid_recovery)
		executed_any = true
		if combo_lead == "":
			combo_lead = skill_id
		executed_skills.append(skill_id)
	_combo_queue.clear()
	if not executed_any:
		_state = State.CHASE
		_state_timer = 0.0
		_telegraph_data.clear()
		_telegraph_warning_announced = false
		_combo_queue.clear()
		_telegraph_skill = ""
		return
	if executed_skills.size() > 1:
		events.append({"type": "combo", "skills": executed_skills, "count": executed_skills.size(), "lead": combo_lead})
	combo_recovery = maxf(combo_recovery, 0.72)
	_active_skill = combo_lead
	_telegraph_skill = combo_lead
	_state = State.RECOVERY
	_state_timer = combo_recovery
	_telegraph_warning_announced = false
	_telegraph_skill = ""
	_telegraph_anchor = ""
	_telegraph_data.clear()

func _execute_single_skill(skill_id: String, events: Array[Dictionary]) -> void:
	_telegraph_skill = skill_id
	var profile := Dictionary(_skill_profiles.get(skill_id, {}))
	_cooldowns[skill_id] = _value_for_phase(profile, "cooldown", 3.0)
	match skill_id:
		"clock_sever":
			_cast_clock_sever(events)
		"causal_hunt":
			_cast_causal_hunt(events)
		"chrono_prison":
			_cast_chrono_prison(events)
		"rewind_rebirth":
			_cast_rewind_rebirth(events)
		"parallel_legion":
			_cast_parallel_legion(events)
		"rift_board":
			_cast_rift_board(events)
		"star_gate_barrage":
			_cast_star_gate_barrage(events)
		"army_judgment":
			_cast_army_judgment(events)
		"causal_mirror":
			_cast_causal_mirror(events)
		"twelfth_bell":
			_cast_twelfth_bell(events)
		_:
			pass

func _cast_clock_sever(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["clock_sever"])
	var damage := float(_value_for_phase(p, "damage", 2600.0)) * _phase_damage_multiplier()
	var width := float(_value_for_phase(p, "width", 25.0))
	var radius := float(_value_for_phase(p, "radius", 190.0))
	var dir := (_telegraph_position - _position).normalized()
	if dir == Vector2.ZERO:
		dir = _facing
	var from := _position + dir * 16.0
	# The fight can engage across most of the arena. Extend the blade to the
	# locked telegraph point so this close-looking skill never becomes a harmless
	# animation merely because the scheduler selected it at long range.
	var reach := clampf(_position.distance_to(_telegraph_position) + width, radius, _engage_distance + width)
	var to := _position + dir * reach
	events.append({
		"type": "projectile",
		"kind": "aionis_clock_blade",
		"pos": from,
		"velocity": Vector2.ZERO,
		"radius": width,
		"damage": damage,
		"lifetime": 0.55,
		"aoe": reach,
		"target_id": _telegraph_target,
		"homing": false,
	})
	emit_line_damage(events, from, to, width, damage, "clock_sever")
	events.append({"type": "effect", "kind": "clock_sever", "pos": to, "radius": width * 1.3, "duration": 0.42})
	events.append({"type": "audio", "cue": "aionis_clock_sever"})
	events.append(_notice("時針斬界展開長刃，形成可持續割裂地帶。"))

func _cast_causal_hunt(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["causal_hunt"])
	var damage := float(_value_for_phase(p, "damage", 1200.0)) * _phase_damage_multiplier()
	var count := int(_value_for_phase(p, "projectile_count", 5))
	var radius := float(_value_for_phase(p, "radius", 16.0))
	var life := float(_value_for_phase(p, "lifetime", 4.5))
	for index in count:
		var target := _telegraph_target
		var candidates := _units_in_radius(_telegraph_position, 950.0, true)
		if not candidates.is_empty():
			target = str(candidates[_rng.randi_range(0, candidates.size() - 1)])
		var target_pos := _resolve_target_position(target)
		var aim_dir := (target_pos - _position).normalized()
		if aim_dir == Vector2.ZERO:
			aim_dir = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
		var spawn := _position + aim_dir * 44.0 + Vector2.from_angle(_rng.randf() * TAU) * 22.0
		events.append({
			"type": "projectile",
			"kind": "aionis_causal_missile",
			"pos": spawn,
			"velocity": aim_dir * 560.0,
			"radius": radius,
			"damage": damage,
			"lifetime": life,
			"aoe": radius * 3.2,
			"target_id": target,
			"homing": true,
		})
		events.append({"type": "effect", "kind": "causal_hunt", "pos": spawn, "radius": radius * 1.4, "duration": 0.22})
	events.append({"type": "audio", "cue": "aionis_causal_hunt"})
	events.append(_notice("因果追獵啟動，追蹤彈尋找目標。"))

func _cast_chrono_prison(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["chrono_prison"])
	var count := int(_value_for_phase(p, "count", 3))
	var damage := float(_value_for_phase(p, "damage", 1500.0)) * _phase_damage_multiplier()
	var radius := float(_value_for_phase(p, "radius", 260.0))
	var anchors := _time_anchors.keys()
	if anchors.is_empty():
		anchors = [""]
	for index in range(mini(count, anchors.size())):
		var anchor_id := String(anchors[index])
		var center := _telegraph_position
		if _time_anchors.has(anchor_id):
			center = Vector2(Dictionary(_time_anchors[anchor_id]).get("pos", _telegraph_position))
		events.append({
			"type": "hazard",
			"kind": "chrono_prison_ring",
			"pos": center,
			"radius": radius * 0.34,
			"duration": 4.2,
			"damage": damage * 0.30,
			"tick": 0.27,
		})
		events.append({"type": "effect", "kind": "chrono_prison", "pos": center, "radius": radius * 0.34, "duration": 0.6})
		emit_area_damage(events, center, radius * 0.34, damage * 0.65, "chrono_prison", "", false, 0.8)
		events.append({"type": "summon", "kind": "chrono_prison_anchor", "pos": center, "count": 1})
		events.append({"type": "reflect", "target": "area", "source": SOURCE_ID, "duration": 2.6, "skill": "chrono_prison", "radius": radius * 0.34})
	events.append({"type": "audio", "cue": "aionis_chrono_prison"})
	events.append(_notice("時牢封軍啟動，空間節點快速聚攏。"))

func _cast_rewind_rebirth(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["rewind_rebirth"])
	var rings := int(_value_for_phase(p, "rings", 3))
	var jumps := int(_value_for_phase(p, "jump_count", 2))
	var damage := float(_value_for_phase(p, "damage", 1800.0)) * _phase_damage_multiplier()
	var radius := float(_value_for_phase(p, "radius", 320.0))
	for ring_index in rings:
		var ratio := float(ring_index + 1) / float(maxi(1, rings))
		var ring_center := _telegraph_position + Vector2.from_angle(_time * 0.7 + ratio * PI) * (radius * ratio)
		events.append({"type": "effect", "kind": "rewind_rebirth_ring", "pos": ring_center, "radius": 46.0 + ratio * 24.0, "duration": 0.45})
		for jump in jumps:
			var frag_pos := ring_center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(35.0, 115.0)
			events.append({
				"type": "projectile",
				"kind": "aionis_rewind_fragment",
				"pos": frag_pos,
				"velocity": Vector2.ZERO,
				"radius": 20.0,
				"damage": damage * 0.30,
				"lifetime": 1.3,
				"aoe": 52.0,
				"target_id": _telegraph_target,
				"homing": false,
			})
	emit_area_damage(events, _telegraph_position, 290.0, damage * 0.8, "rewind_rebirth", "", false, 1.0)
	events.append({"type": "audio", "cue": "aionis_rewind_rebirth"})
	events.append(_notice("逆時回生施放，時間殘片向周圍反噬。"))

func _cast_parallel_legion(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["parallel_legion"])
	var count := int(_value_for_phase(p, "count", 2))
	var base_damage := float(_value_for_phase(p, "damage", 1100.0))
	var area := float(_value_for_phase(p, "radius", 240.0))
	for index in count:
		var angle := TAU * float(index) / float(maxi(1, count)) + _rng.randf_range(-0.2, 0.2)
		var summon_pos := _telegraph_position + Vector2.from_angle(angle) * (area * 0.56)
		events.append({"type": "summon", "kind": "aionis_parallel_legion", "pos": summon_pos, "count": 1})
		events.append({"type": "effect", "kind": "aionis_legion_spawn", "pos": summon_pos, "radius": 34.0, "duration": 0.5})
		emit_area_damage(events, summon_pos, 60.0, base_damage * 0.28, "parallel_legion", "", false, 0.75)
	events.append({"type": "audio", "cue": "aionis_parallel_legion"})
	events.append(_notice("平行軍團分裂重疊，持續對戰場造成壓迫。"))

func _cast_rift_board(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["rift_board"])
	var segments := int(_value_for_phase(p, "segments", 5))
	var radius := float(_value_for_phase(p, "radius", 180.0))
	var damage := float(_value_for_phase(p, "damage", 1800.0)) * _phase_damage_multiplier()
	var reflect_ratio := float(_value_for_phase(p, "reflect", 0.35))
	for index in segments:
		var angle := TAU * float(index) / float(maxi(1, segments)) + _time * 0.4
		var pos := _telegraph_position + Vector2.from_angle(angle) * radius
		events.append({
			"type": "hazard",
			"kind": "rift_board_node",
			"pos": pos,
			"radius": 46.0,
			"duration": 2.2,
			"damage": damage * 0.22,
			"tick": 0.18,
		})
		events.append({"type": "effect", "kind": "rift_board", "pos": pos, "radius": 46.0, "duration": 0.4})
		events.append({
			"type": "reflect",
			"target": "area",
			"kind": "rift_board_reflect",
			"source": SOURCE_ID,
			"ratio": reflect_ratio,
			"duration": 1.6,
		})
		emit_area_damage(events, pos, 46.0, damage * 0.25, "rift_board", "", false, 0.74)
	events.append({"type": "audio", "cue": "aionis_rift_board"})
	events.append(_notice("斷界棋盤展開，近戰傷害將延遲反射。"))

func _cast_star_gate_barrage(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["star_gate_barrage"])
	var count := int(_value_for_phase(p, "projectile_count", 16))
	var damage := float(_value_for_phase(p, "damage", 940.0)) * _phase_damage_multiplier()
	var life := float(_value_for_phase(p, "lifetime", 2.2))
	var radius := float(_value_for_phase(p, "radius", 17.0))
	for shot in count:
		var angle := TAU * float(shot) / float(maxi(1, count)) + _rng.randf_range(-0.16, 0.16)
		var origin := _telegraph_position + Vector2.from_angle(angle) * 74.0
		# Gates form outside the victim and fire inward through the locked point.
		# The previous outward vector made every shot diverge away from an isolated
		# target even though the projectile carried non-zero damage.
		var inward := (_telegraph_position - origin).normalized()
		var dir := inward.rotated(_rng.randf_range(-0.18, 0.18))
		events.append({
			"type": "projectile",
			"kind": "aionis_star_gate",
			"pos": origin,
			"velocity": dir * 760.0,
			"radius": radius,
			"damage": damage,
			"lifetime": life,
			"aoe": radius * 3.1,
			"target_id": _telegraph_target,
			"homing": false,
		})
	events.append({"type": "audio", "cue": "aionis_star_gate"})
	events.append(_notice("星門炮列從四方轟射，覆蓋面擴大。"))

func _cast_army_judgment(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["army_judgment"])
	var radius := float(_value_for_phase(p, "radius", 270.0))
	var base_damage := float(_value_for_phase(p, "damage", 3500.0)) * _phase_damage_multiplier()
	var chain := int(_value_for_phase(p, "chain", 4))
	var drop := float(_value_for_phase(p, "drop", 0.2))
	var targets := _units_in_radius(_telegraph_position, radius, true)
	var hit_count := 0
	for key in targets:
		if hit_count >= chain:
			break
		if not _is_unit_alive_unit(key):
			continue
		var damage := maxf(1.0, base_damage * (1.0 - float(hit_count) * drop))
		events.append(_damage_event(key, damage, "army_judgment", "army_judgment"))
		events.append({"type": "effect", "kind": "army_judgment_mark", "pos": Vector2(Dictionary(_units_by_key[key]).get("pos", _telegraph_position)), "radius": 18.0, "duration": 0.2})
		hit_count += 1
	if hit_count == 0:
		emit_area_damage(events, _telegraph_position, radius, base_damage * 0.5, "army_judgment", "", true, 0.66)
	events.append({"type": "effect", "kind": "army_judgment", "pos": _telegraph_position, "radius": radius, "duration": 0.7})
	events.append({"type": "audio", "cue": "aionis_army_judgment"})
	events.append(_notice("軍勢審判進入多目標鏈式打擊。"))

func _cast_causal_mirror(events: Array[Dictionary]) -> void:
	var p := Dictionary(_skill_profiles["causal_mirror"])
	var count := int(_value_for_phase(p, "mirror_count", 2))
	var radius := float(_value_for_phase(p, "radius", 320.0))
	var damage := float(_value_for_phase(p, "damage", 1900.0)) * _phase_damage_multiplier()
	var life := float(_value_for_phase(p, "lifetime", 2.6))
	for index in count:
		var angle := _rng.randf() * TAU
		var mirror_pos := _telegraph_position + Vector2.from_angle(angle) * (radius * 0.35)
		events.append({
			"type": "hazard",
			"kind": "causal_mirror_field",
			"pos": mirror_pos,
			"radius": radius * 0.25,
			"duration": life,
			"damage": damage * 0.28,
			"tick": 0.2,
		})
		events.append({"type": "effect", "kind": "causal_mirror", "pos": mirror_pos, "radius": radius * 0.25, "duration": 0.33})
		events.append({"type": "reflect", "target": "area", "source": SOURCE_ID, "duration": life, "angle": angle})
		emit_area_damage(events, mirror_pos, radius * 0.25, damage * 0.6, "causal_mirror", "", false, 0.9)
	events.append({"type": "audio", "cue": "aionis_causal_mirror"})
	events.append(_notice("逆因果鏡展開，部分傷害將被折返。"))

func _cast_twelfth_bell(events: Array[Dictionary]) -> void:
	if _phase < 3:
		return
	var p := Dictionary(_skill_profiles["twelfth_bell"])
	var damage := float(_value_for_phase(p, "damage", 11600.0)) * _phase_damage_multiplier()
	var radius := float(_value_for_phase(p, "radius", 470.0))
	var count := int(_value_for_phase(p, "projectile_count", 18))
	var life := float(_value_for_phase(p, "lifetime", 4.6))
	events.append({"type": "effect", "kind": "twelfth_bell_cast", "pos": _telegraph_position, "radius": radius, "duration": 1.0})
	events.append({
		"type": "hazard",
		"kind": "twelfth_bell_core",
		"pos": _telegraph_position,
		"radius": radius,
		"duration": life,
		"damage": damage * 0.28,
		"tick": 0.18,
	})
	emit_area_damage(events, _telegraph_position, radius, damage * 0.4, "twelfth_bell", "", false, 1.0)
	for i in count:
		var angle := TAU * float(i) / float(maxi(1, count))
		var dir := Vector2.from_angle(angle + _rng.randf_range(-0.06, 0.06))
		var start := _telegraph_position + dir * (radius * 0.22)
		events.append({
			"type": "projectile",
			"kind": "aionis_twelfth_bell",
			"pos": start,
			"velocity": dir * 620.0,
			"radius": 25.0,
			"damage": damage * 0.06,
			"lifetime": life,
			"aoe": 66.0,
			"target_id": _telegraph_target,
			"homing": false,
		})
	events.append({"type": "audio", "cue": "aionis_twelfth_bell"})
	events.append(_notice("十二刻終焉降臨，時空核心進入斷裂階段。"))

func _update_anchor_system(delta: float, events: Array[Dictionary]) -> void:
	if _phase < 1:
		return
	if _time_anchors.is_empty():
		_build_time_anchors(true)
	_anchor_decay_timer += delta
	_anchor_pulse_timer += delta
	if _anchor_decay_timer < 0.18:
		return
	_anchor_decay_timer = 0.0
	var player_anchor_pressure := 0.0
	if bool(_latest_player.get("alive", false)) and not _time_anchors.is_empty():
		var player_pos := Vector2(_latest_player.get("pos", _home_position))
		for anchor_id in _time_anchors.keys():
			var anchor := Dictionary(_time_anchors[anchor_id])
			if bool(anchor.get("broken", false)):
				continue
			var dist := player_pos.distance_to(Vector2(anchor.get("pos", _home_position)))
			if dist <= float(anchor.get("radius", 56.0)) * 1.6:
				player_anchor_pressure += 1.0
				anchor["hp"] = maxf(0.0, float(anchor.get("hp", ANCHOR_MAX_HP)) - 1.9)
				if float(anchor.get("hp", 1.0)) <= 0.0:
					anchor["broken"] = true
					_time_anchor_destroyed(anchor_id)
				_time_anchors[anchor_id] = anchor
	for s in _latest_soldiers:
		if float(s.get("hp", 0.0)) <= 0.0:
			continue
		var sp := Vector2(s.get("pos", _home_position))
		for anchor_id in _time_anchors.keys():
			var anchor := Dictionary(_time_anchors[anchor_id])
			if bool(anchor.get("broken", false)):
				continue
			if sp.distance_to(Vector2(anchor.get("pos", _home_position))) <= float(anchor.get("radius", 56.0)) * 1.35:
				anchor["hp"] = maxf(0.0, float(anchor.get("hp", ANCHOR_MAX_HP)) - 0.82)
				if float(anchor.get("hp", 1.0)) <= 0.0:
					anchor["broken"] = true
					_time_anchor_destroyed(anchor_id)
				_time_anchors[anchor_id] = anchor
	for anchor_id in _time_anchors.keys():
		var anchor := Dictionary(_time_anchors[anchor_id])
		if bool(anchor.get("broken", false)):
			continue
		if _anchor_pulse_timer >= 1.6 and _rng.randf() < 0.07 + player_anchor_pressure * 0.02:
			anchor["hp"] = maxf(0.0, float(anchor.get("hp", ANCHOR_MAX_HP)) - 1.0)
			if float(anchor.get("hp", 1.0)) <= 0.0:
				anchor["broken"] = true
				_time_anchor_destroyed(anchor_id)
			_time_anchors[anchor_id] = anchor
		if _anchor_pulse_timer >= 1.6:
			events.append({"type": "effect", "kind": "time_anchor", "pos": Vector2(anchor.get("pos", _home_position)), "radius": float(anchor.get("radius", 56.0)), "duration": 0.2})
	if _anchor_pulse_timer >= 1.6:
		_anchor_pulse_timer = 0.0

func _build_time_anchors(force: bool = false) -> void:
	if not force and _time_anchors.size() >= _anchor_count:
		return
	_time_anchors.clear()
	_anchor_breach_timer = 0.0
	_anchor_pulse_timer = 0.0
	_anchor_decay_timer = 0.0
	var configured := Array(_config.get("time_anchor_positions", []))
	for index in _anchor_count:
		var angle := TAU * float(index) / float(maxi(1, _anchor_count)) + _rng.randf_range(-0.24, 0.24)
		var radius := maxf(200.0, float(_config.get("time_anchor_orbit", 245.0)))
		var pos := _home_position + Vector2.from_angle(angle) * radius
		if index < configured.size() and configured[index] is Dictionary:
			var d := Dictionary(configured[index])
			pos = Vector2(float(d.get("x", pos.x)), float(d.get("y", pos.y)))
		_time_anchors["anchor_%d" % index] = {
			"id": "anchor_%d" % index,
			"pos": pos,
			"radius": 58.0,
			"max_hp": ANCHOR_MAX_HP + float(index * 12),
			"hp": ANCHOR_MAX_HP + float(index * 12),
			"broken": false,
		}

func _time_anchor_destroyed(anchor_id: String) -> void:
	if _all_time_anchors_broken() and _anchor_breach_timer <= 0.0:
		_anchor_breach_timer = _anchor_exposed_seconds
		_pending_anchor_events.append(_notice("4 個時間錨全部毀壞，艾歐尼斯進入5秒破防。"))
		_pending_anchor_events.append({
			"type": "effect",
			"kind": "anchor_broken",
			"pos": _get_anchor_pos(anchor_id),
			"radius": 72.0,
			"duration": 0.86,
		})
		_pending_anchor_events.append({"type": "audio", "cue": "aionis_anchor_broken"})

func _apply_anchor_damage(hit_pos: Vector2, amount: float) -> void:
	if not hit_pos.is_finite():
		return
	var threshold := get_radius() * 1.5
	for anchor_id in _time_anchors.keys():
		var anchor := Dictionary(_time_anchors[anchor_id])
		if bool(anchor.get("broken", false)):
			continue
		if hit_pos.distance_to(Vector2(anchor.get("pos", _home_position))) <= float(anchor.get("radius", 58.0)) * 1.5:
			anchor["hp"] = maxf(0.0, float(anchor.get("hp", ANCHOR_MAX_HP)) - amount * 0.45)
			if float(anchor.get("hp", 0.0)) <= 0.0:
				anchor["broken"] = true
				_time_anchor_destroyed(anchor_id)
			_time_anchors[anchor_id] = anchor

func _all_time_anchors_broken() -> bool:
	if _anchor_count <= 0:
		return false
	if _time_anchors.is_empty():
		return false
	for anchor_id in _time_anchors.keys():
		if not bool(Dictionary(_time_anchors[anchor_id]).get("broken", false)):
			return false
	return true

func _broken_anchor_count() -> int:
	var count := 0
	for anchor_id in _time_anchors.keys():
		if bool(Dictionary(_time_anchors[anchor_id]).get("broken", false)):
			count += 1
	return count

func _get_anchor_pos(anchor_id: String) -> Vector2:
	if _time_anchors.has(anchor_id):
		return Vector2(Dictionary(_time_anchors[anchor_id]).get("pos", _home_position))
	for key in _time_anchors.keys():
		return Vector2(Dictionary(_time_anchors[key]).get("pos", _home_position))
	return _home_position

func _choose_telegraph_position(fallback: Vector2) -> Vector2:
	if _telegraph_anchor != "":
		return _get_anchor_pos(_telegraph_anchor)
	if _is_target_locked():
		return _resolve_target_position(_telegraph_target)
	return fallback + Vector2.from_angle(_time + 0.6) * 78.0

func _update_target_preference() -> void:
	var best_key := ""
	var best_score := -INF
	for key in _units_by_key.keys():
		if not _is_unit_alive_unit(key):
			continue
		var unit := Dictionary(_units_by_key[key])
		var unit_pos := Vector2(unit.get("pos", _position))
		var alive_bonus := 6.0 if str(key).begins_with("player:") else 1.2
		var dist := maxf(30.0, _position.distance_to(unit_pos))
		var threat_score := float(_threat.get(key, 0.0)) * 1.6
		var distance_score := 40.0 / (dist + 160.0)
		var recency: float = maxf(0.0, 1.0 - ((_time - float(_threat_seen.get(key, _time))) / 5.5)) * 10.0
		var hp_ratio := 1.0 - (float(unit.get("hp", 1.0)) / maxf(1.0, float(unit.get("max_hp", 1.0))))
		var score: float = threat_score + alive_bonus + distance_score * 25.0 + recency * 8.0 + hp_ratio * 9.0
		if score > best_score:
			best_score = score
			best_key = key
	if best_key != "":
		_target_key = best_key
		_target_position = Vector2(Dictionary(_units_by_key[best_key]).get("pos", _position))
		_target_velocity = Vector2(Dictionary(_units_by_key[best_key]).get("vel", Vector2.ZERO))

func _is_target_locked() -> bool:
	if _telegraph_target == "":
		return false
	return _units_by_key.has(_telegraph_target) and _is_unit_alive_unit(_telegraph_target)

func _resolve_target_position(key: String) -> Vector2:
	if key == "player:0" and not _latest_player.is_empty():
		return Vector2(_latest_player.get("pos", _position))
	if _units_by_key.has(key):
		return Vector2(Dictionary(_units_by_key[key]).get("pos", _position))
	return _position

func _move_toward(destination: Vector2, delta: float, speed_factor: float) -> void:
	var dir := (destination - _position)
	if dir.length() <= _return_threshold:
		_velocity = Vector2.ZERO
		return
	dir = dir.normalized()
	_facing = dir
	var move_speed := _move_speed * _phase_attack_multiplier * speed_factor
	var next_pos := _position + dir * minf(move_speed * delta, (destination - _position).length())
	if _is_blocked(next_pos, get_radius()):
		next_pos = _resolve_around_obstacle(destination)
	_velocity = (next_pos - _position) / maxf(delta, 0.0001)
	_position = next_pos

func _is_blocked(pos: Vector2, radius: float) -> bool:
	if _position_blocked is Callable and _position_blocked.is_valid():
		var blocked: bool = bool(_position_blocked.call(pos, radius))
		return blocked
	return false

func _resolve_around_obstacle(destination: Vector2) -> Vector2:
	var search_dirs := [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2(0.71, 0.71).normalized(),
		Vector2(-0.71, 0.71).normalized(),
		Vector2(0.71, -0.71).normalized(),
		Vector2(-0.71, -0.71).normalized(),
	]
	for d in search_dirs:
		var candidate: Vector2 = _position + d * 48.0
		if not _is_blocked(candidate, get_radius()):
			return candidate
	return _position

func emit_area_damage(events: Array[Dictionary], center: Vector2, radius: float, base_damage: float, source_skill: String, fallback_target: String = "", force_player_only: bool = false, multiplier: float = 1.0) -> void:
	var target_keys := _units_in_radius(center, radius, true)
	if force_player_only:
		target_keys.clear()
		if bool(_latest_player.get("alive", false)) and Vector2(_latest_player.get("pos", center)).distance_to(center) <= radius:
			target_keys.append("player:%d" % int(_latest_player.get("id", 0)))
	if target_keys.is_empty() and fallback_target != "":
		target_keys.append(_target_or_player_key(fallback_target))
	for target_key in target_keys:
		if not _is_unit_alive_unit(target_key):
			continue
		var unit_pos := Vector2(Dictionary(_units_by_key[target_key]).get("pos", center))
		var dist := center.distance_to(unit_pos)
		var falloff := 1.0 - minf(0.95, dist / maxf(radius, 1.0))
		events.append(_damage_event(target_key, maxf(1.0, base_damage * falloff * multiplier), source_skill, source_skill))

func emit_line_damage(events: Array[Dictionary], from: Vector2, to: Vector2, width: float, base_damage: float, source_skill: String) -> void:
	for key in _units_by_key.keys():
		if not _is_unit_alive_unit(key):
			continue
		var unit_pos := Vector2(Dictionary(_units_by_key[key]).get("pos", from))
		var dist := _distance_point_segment(unit_pos, from, to)
		if dist <= width:
			var amount := maxf(1.0, base_damage * (1.0 - minf(0.9, dist / maxf(width, 1.0))))
			events.append(_damage_event(key, amount, source_skill, source_skill))
		events.append({"type": "effect", "kind": "line_hit", "pos": unit_pos, "radius": 9.0, "duration": 0.14})

func _units_in_radius(center: Vector2, radius: float, prefer_alive_only: bool = true) -> Array[String]:
	var result: Array[String] = []
	for key in _units_by_key.keys():
		var unit := Dictionary(_units_by_key[key])
		if prefer_alive_only and not bool(unit.get("alive", true)):
			continue
		if Vector2(unit.get("pos", _position)).distance_to(center) <= radius:
			result.append(String(key))
	return result

func _target_or_player_key(value: String) -> String:
	if value == "":
		return "player:%d" % int(_latest_player.get("id", 0))
	return value

func _is_unit_alive_unit(key: String) -> bool:
	if key == "":
		return false
	if not _units_by_key.has(key):
		return false
	return bool(Dictionary(_units_by_key[key]).get("alive", true))

func _distance_point_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var line := b - a
	var len_sq := line.length_squared()
	if len_sq <= 0.00001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(line) / len_sq, 0.0, 1.0)
	return point.distance_to(a + line * t)

func _record_seen(key: String) -> void:
	_threat_seen[key] = _time

func _record_base_threat(key: String, amount: float) -> void:
	if key == "":
		return
	_threat[key] = float(_threat.get(key, 0.0)) + amount

func _record_threat(key: String, amount: float) -> void:
	if key == "":
		return
	_threat[key] = float(_threat.get(key, 0.0)) + amount
	_record_seen(key)

func _damage_event(target_key: String, amount: float, skill: String, source_skill: String) -> Dictionary:
	return {
		"type": "damage",
		"target": target_key,
		"amount": amount,
		"source": SOURCE_ID,
		"source_id": BOSS_ENTITY_ID,
		"skill": skill,
		"source_skill": source_skill,
	}

func _compute_defense_factor() -> float:
	var defense := _defense
	if _anchor_breach_timer > 0.0:
		return 0.02
	return defense / (defense + 260.0)

func _phase_damage_multiplier() -> float:
	return _phase_attack_multiplier

func _die(events: Array[Dictionary]) -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	_hp = 0.0
	_reward_given = true
	_pending_defeat_event = true
	events.append({"type": "reward", "gold": _reward_drop_gold(), "xp": _reward_drop_xp()})
	events.append(_notice("諸界終時者・艾歐尼斯被完全擊破。"))
	events.append({"type": "audio", "cue": "aionis_defeated"})
	events.append({"type": "effect", "kind": "aionis_dead", "pos": _position, "radius": 240.0, "duration": 2.5})

func _reward_drop_gold() -> int:
	var bonus := int(maxf(0.0, _max_hp / 14000.0))
	return clampi(_reward_min_gold + bonus, _reward_min_gold, _reward_max_gold)

func _reward_drop_xp() -> int:
	var bonus := int(500.0 + float(_phase) * 360.0)
	return clampi(_reward_min_xp + bonus, _reward_min_xp, _reward_max_xp)

func _to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var d := Dictionary(value)
		return Vector2(float(d.get("x", fallback.x)), float(d.get("y", fallback.y)))
	return fallback

func _value_for_phase(profile: Dictionary, key: String, default_value: Variant) -> Variant:
	if profile.is_empty():
		return default_value
	var value: Variant = profile.get(key, default_value)
	if value is Array:
		if Array(value).is_empty():
			return default_value
		return Array(value)[clampi(_phase, 0, Array(value).size() - 1)]
	return value

func _passive_loop_state_event() -> Dictionary:
	return {"type": "effect", "kind": "aionis_beat", "pos": _position, "radius": get_radius(), "duration": 0.13}

func _notice(text: String) -> Dictionary:
	return {"type": "notice", "text": text}

class_name ChaosBossController
extends RefCounted

## Final boss controller for a deterministic "Chaos" boss encounter.
## No external nodes/assets are required; controller outputs event dictionaries
## and is driven by update(context).

enum State {
	IDLE,
	CHASE,
	TELEGRAPH,
	RECOVERY,
	RETURNING,
	DEAD,
}

const STATE_NAMES := [
	"IDLE",
	"CHASE",
	"TELEGRAPH",
	"RECOVERY",
	"RETURNING",
	"DEAD",
]

const SAVE_VERSION := 1
const SOURCE_ID := "chaos_boss"
const BOSS_ENTITY_ID := -990001
const TELEGRAPH_MIN_SECONDS := 0.35
const THREAT_DECAY_PER_SECOND := 9.0
const PHASE_HP_THRESHOLDS := { "two": 0.70, "three": 0.35 }

const SKILL_IDS: Array[String] = [
	"meteor",
	"destruction_beam",
	"energy_barrage",
	"shockwave",
	"black_hole",
	"summon_monsters",
	"homing_missiles",
	"lightning",
	"rift_dash",
	"total_annihilation",
]

const DEFAULT_SKILL_DATA: Dictionary = {
	"meteor": {
		"name": "Meteor",
		"min_phase": 0, "max_phase": 2,
		"weight": [1.45, 1.24, 1.02],
		"cooldown": [8.1, 7.2, 6.4],
		"telegraph": [0.68, 0.61, 0.54],
		"recovery": [1.28, 1.08, 0.95],
		"damage": [4200.0, 5200.0, 6600.0],
		"radius": [150.0, 165.0, 180.0],
		"lifetime": 4.0,
		"count": 1,
	},
	"destruction_beam": {
		"name": "Destruction Beam",
		"min_phase": 0, "max_phase": 2,
		"weight": [1.1, 1.2, 1.3],
		"cooldown": [7.8, 6.9, 6.1],
		"telegraph": [0.75, 0.65, 0.58],
		"recovery": [1.08, 1.0, 0.98],
		"damage": [3300.0, 3900.0, 4700.0],
		"radius": [90.0, 100.0, 115.0],
		"lifetime": 0.75,
	},
	"energy_barrage": {
		"name": "Energy Barrage",
		"min_phase": 0, "max_phase": 2,
		"weight": [1.34, 1.11, 1.05],
		"cooldown": [9.5, 8.7, 8.2],
		"telegraph": [0.56, 0.50, 0.45],
		"recovery": [1.0, 0.92, 0.88],
		"damage": [1800.0, 2200.0, 2700.0],
		"radius": [48.0, 52.0, 58.0],
		"projectile_count": [5, 6, 7],
	},
	"shockwave": {
		"name": "Shockwave",
		"min_phase": 0, "max_phase": 2,
		"weight": [1.24, 1.27, 1.39],
		"cooldown": [7.0, 6.4, 5.8],
		"telegraph": [0.58, 0.52, 0.45],
		"recovery": [1.12, 1.03, 0.92],
		"damage": [2600.0, 3300.0, 4200.0],
		"radius": [290.0, 312.0, 335.0],
		"knockback": [220.0, 246.0, 275.0],
	},
	"black_hole": {
		"name": "Black Hole",
		"min_phase": 1, "max_phase": 2,
		"weight": [0.78, 1.05, 1.28],
		"cooldown": [12.0, 10.8, 10.1],
		"telegraph": [0.62, 0.57, 0.52],
		"recovery": [1.8, 1.6, 1.45],
		"damage": [900.0, 1130.0, 1320.0],
		"radius": [190.0, 205.0, 225.0],
		"lifetime": [4.8, 5.6, 6.2],
		"tick": [0.40, 0.36, 0.32],
	},
	"summon_monsters": {
		"name": "Summon Monsters",
		"min_phase": 0, "max_phase": 2,
		"weight": [0.82, 1.00, 1.16],
		"cooldown": [14.0, 12.7, 11.4],
		"telegraph": [0.52, 0.47, 0.43],
		"recovery": [1.22, 1.10, 0.99],
		"count": [3, 4, 5],
		"radius": [120.0, 120.0, 120.0],
	},
	"homing_missiles": {
		"name": "Homing Missiles",
		"min_phase": 1, "max_phase": 2,
		"weight": [0.92, 1.11, 1.31],
		"cooldown": [10.4, 9.4, 8.6],
		"telegraph": [0.63, 0.55, 0.50],
		"recovery": [1.16, 1.04, 0.95],
		"damage": [1150.0, 1400.0, 1680.0],
		"radius": [22.0, 26.0, 30.0],
		"projectile_count": [4, 5, 6],
		"lifetime": [4.6, 5.1, 5.6],
	},
	"lightning": {
		"name": "Lightning Storm",
		"min_phase": 1, "max_phase": 2,
		"weight": [0.95, 1.24, 1.39],
		"cooldown": [9.2, 8.3, 7.7],
		"telegraph": [0.44, 0.40, 0.36],
		"recovery": [1.02, 0.95, 0.92],
		"damage": [1500.0, 1900.0, 2300.0],
		"radius": [24.0, 28.0, 32.0],
		"projectile_count": [4, 5, 7],
	},
	"rift_dash": {
		"name": "Rift Dash",
		"min_phase": 2, "max_phase": 2,
		"weight": [0.0, 0.0, 1.46],
		"cooldown": [0.0, 0.0, 7.8],
		"telegraph": [0.0, 0.0, 0.40],
		"recovery": [0.0, 0.0, 1.25],
		"damage": [4700.0, 5300.0, 6200.0],
		"knockback": [0.0, 0.0, 360.0],
		"radius": [190.0, 190.0, 220.0],
	},
	"total_annihilation": {
		"name": "Total Annihilation",
		"min_phase": 2, "max_phase": 2,
		"weight": [0.0, 0.0, 1.0],
		"cooldown": [0.0, 0.0, 14.2],
		"telegraph": [0.0, 0.0, 1.18],
		"recovery": [0.0, 0.0, 2.8],
		"damage": [0.0, 0.0, 9800.0],
		"radius": [330.0, 330.0, 360.0],
	},
}

var _config: Dictionary = {}
var _seed := 20260802
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _player_level := 1

var _state := State.IDLE
var _state_timer := 0.0
var _active_skill := ""
var _telegraph_skill := ""
var _telegraph_target := ""
var _telegraph_position := Vector2.ZERO
var _telegraph_data: Dictionary = {}
var _cooldowns: Dictionary = {}

var _position := Vector2.ZERO
var _home_position := Vector2.ZERO
var _velocity := Vector2.ZERO
var _radius := 95.0
var _move_speed := 200.0
var _turn_speed := 3.2
var _facing := Vector2.RIGHT
var _leash_distance := 980.0
var _engage_distance := 1500.0
var _return_threshold := 38.0

var _hp := 110000.0
var _max_hp := 110000.0
var _defense := 82.0
var _phase := 0
var _phase_notice_timer := 0.0
var _reward_given := false

var _is_force_engaged := false
var _forced_engage_position: Vector2 = Vector2.INF
var _forced_skill := ""

var _target_key := ""
var _target_position := Vector2.ZERO
var _target_velocity := Vector2.ZERO
var _threat: Dictionary = {}
var _threat_seen: Dictionary = {}
var _units_by_key: Dictionary = {}
var _latest_player: Dictionary = {}
var _latest_soldiers: Array[Dictionary] = []
var _position_blocked: Callable = Callable()
var _is_player_alive := true

var _pending_defeat_event := false
var _telegraph_warning_announced := false

func initialize(config: Dictionary, player_level: int, seed: int) -> void:
	_config = config.duplicate(true)
	_seed = seed if seed is int else 20260802
	_rng.seed = _seed
	_player_level = maxi(1, player_level)
	_apply_config()
	_reset_runtime(true)

func _apply_config() -> void:
	var cfg_max_hp: float = float(_config.get("max_hp", 98000.0))
	var cfg_move: float = float(_config.get("move_speed", 196.0))
	var cfg_home: Variant = _config.get("home_position", Vector2.ZERO)
	var cfg_radius: float = float(_config.get("radius", 95.0))
	var cfg_defense: float = float(_config.get("defense", 82.0))
	var cfg_leash: float = float(_config.get("leash_distance", 980.0))
	_radius = maxf(40.0, cfg_radius)
	_move_speed = maxf(110.0, cfg_move)
	_turn_speed = maxf(1.0, float(_config.get("turn_speed", _turn_speed)))
	_leash_distance = maxf(560.0, cfg_leash)
	_engage_distance = maxf(700.0, float(_config.get("engage_distance", _engage_distance)))
	_home_position = _to_vector2(cfg_home, Vector2.ZERO)
	_defense = maxf(8.0, cfg_defense)
	var level_scale := 1.0 + (float(_player_level - 1) * 0.018)
	var reward_cap_hp := 120000.0
	_max_hp = minf((cfg_max_hp * level_scale), reward_cap_hp)
	_max_hp = maxf(_max_hp, 42000.0)
	_hp = _max_hp
	_position = _home_position
	var thresholds := Dictionary(_config.get("phase_thresholds", {}))
	var p_two: float = float(thresholds.get("two", PHASE_HP_THRESHOLDS["two"]))
	var p_three: float = float(thresholds.get("three", PHASE_HP_THRESHOLDS["three"]))
	_phase_threshold_two = clampf(p_two, 0.40, 0.95)
	_phase_threshold_three = clampf(p_three, 0.20, 0.75)
	var rewards: Dictionary = Dictionary(_config.get("rewards", {}))
	_reward_min_gold = maxi(0, int(rewards.get("gold_min", _reward_min_gold)))
	_reward_max_gold = maxi(_reward_min_gold, int(rewards.get("gold_max", _reward_max_gold)))
	_reward_min_xp = maxi(0, int(rewards.get("xp_min", _reward_min_xp)))
	_reward_max_xp = maxi(_reward_min_xp, int(rewards.get("xp_max", _reward_max_xp)))

	var base_cooldowns: Dictionary = _config.get("skill_cooldowns", {})
	for skill_id in SKILL_IDS:
		if DEFAULT_SKILL_DATA.has(skill_id):
			var profile := Dictionary(_config.get(skill_id, {}))
			var merged: Dictionary = DEFAULT_SKILL_DATA[skill_id].duplicate(true)
			for key in profile.keys():
				merged[key] = profile[key]
			_skill_profiles[skill_id] = merged
	for skill_id in _config.get("blocked_skills", []):
		if skill_id is String and skill_id in _skill_profiles:
			_skill_profiles.erase(skill_id)

	for skill_id in SKILL_IDS:
		var profile: Dictionary = _skill_profiles.get(skill_id, DEFAULT_SKILL_DATA.get(skill_id, {}))
		_cooldowns[skill_id] = float(_value_for_phase(profile, "cooldown", 0))

var _phase_threshold_two := 0.70
var _phase_threshold_three := 0.35
var _phase_transitioned := false
var _skill_profiles: Dictionary = {}
var _reward_min_gold := 2200
var _reward_max_gold := 3600
var _reward_min_xp := 3200
var _reward_max_xp := 5200
var _telegraph_center_offset := 0.0
var _phase_attack_multiplier := 1.0
var _return_target_position := Vector2.ZERO

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
	_velocity = Vector2.ZERO
	_facing = Vector2.RIGHT
	_phase = 0
	_phase_transitioned = false
	_phase_notice_timer = 0.0
	_reward_given = false
	_is_force_engaged = false
	_forced_engage_position = Vector2.INF
	_forced_skill = ""
	_target_key = ""
	_target_position = _home_position
	_target_velocity = Vector2.ZERO
	_threat.clear()
	_threat_seen.clear()
	_units_by_key.clear()
	_latest_player.clear()
	_latest_soldiers.clear()
	_position_blocked = Callable()
	_pending_defeat_event = false
	_telegraph_warning_announced = false
	_time = 0.0
	_phase_attack_multiplier = 1.0
	_return_target_position = _home_position
	for skill_id in SKILL_IDS:
		_cooldowns[skill_id] = maxf(0.0, float(_value_for_phase(Dictionary(_skill_profiles.get(skill_id, DEFAULT_SKILL_DATA[skill_id])), "cooldown", 1.0)))

func update(delta: float, context: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	delta = maxf(0.0, delta)
	_time += delta
	if _state == State.DEAD:
		if _pending_defeat_event:
			events.append({"type":"defeated","source":SOURCE_ID,"gold":0,"xp":0})
			events.append({"type":"notice","text":"Chaos has fallen."})
			_pending_defeat_event = false
		return events
	_read_context(context)
	_tick_cooldowns(delta)
	_update_position_blocker(context)
	_update_phase_if_needed(events)
	_decay_threat(delta)
	_update_target_preference()
	_advance_phase_behaviour(events)
	match _state:
		State.IDLE:
			_move_idle(delta, events)
		State.CHASE:
			_update_chase(delta, events)
		State.TELEGRAPH:
			_update_telegraph(delta, events)
		State.RECOVERY:
			_update_recovery(delta, events)
		State.RETURNING:
			_update_returning(delta, events)
	if _pending_defeat_event:
		events.append({"type":"defeated","source":SOURCE_ID,"gold":_reward_drop_gold(),"xp":_reward_drop_xp()})
		_pending_defeat_event = false
	if _phase_transitioned:
		_phase_transitioned = false
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
	var raw: float = maxf(0.0, damage)
	if raw <= 0.0:
		return result
	var resistance := _defense / (_defense + 160.0)
	if damage_type == "true":
		resistance = 0.0
	elif damage_type == "critical":
		resistance *= 0.70
	var mitigated := maxf(1.0, roundf(raw * (1.0 - resistance)))
	# Later phases harden the core instead of amplifying incoming player damage.
	# This keeps the encounter difficult for a maxed build without changing HP
	# dynamically after combat begins.
	var phase_resistance := 1.0 - 0.10 * float(_phase)
	var final_damage := roundf(mitigated * phase_resistance)
	_hp = maxf(0.0, _hp - final_damage)
	if source_id != "":
		_record_threat(source_id, final_damage * 1.5)
		_position_breath_if_player(source_id, source_pos)
	result["accepted"] = true
	result["damage"] = final_damage
	result["hp"] = _hp
	result["max_hp"] = _max_hp
	var events: Array[Dictionary] = []
	var source := source_id
	events.append({
		"type":"damage",
		"target": SOURCE_ID,
		"amount": final_damage,
		"source": source,
		"skill": "player_hit",
	})
	if _hp <= 0.0:
		_die(events)
		result["defeated"] = true
	result["events"] = events
	return result

func force_engage(player_pos: Vector2) -> void:
	_forced_engage_position = player_pos
	_is_force_engaged = true
	_state = State.CHASE if _state != State.DEAD else State.DEAD
	_target_position = player_pos
	if _target_key.is_empty():
		_target_key = "player:0"

func debug_force_skill(skill_id: String) -> void:
	if not SKILL_IDS.has(skill_id):
		return
	if not _skill_profiles.has(skill_id):
		return
	_forced_skill = skill_id
	_cooldowns[skill_id] = 0.0

func debug_set_hp_ratio(ratio: float) -> void:
	_hp = clampf(ratio, 0.0, 1.0) * _max_hp
	_update_phase_if_needed([])

func is_engaged() -> bool:
	return _state != State.DEAD and _state != State.IDLE and _state != State.RETURNING

func is_damageable() -> bool:
	return _state != State.DEAD

func is_defeated() -> bool:
	return _state == State.DEAD

func get_position() -> Vector2:
	return _position

func get_radius() -> float:
	return _radius * (1.0 + float(_phase) * 0.06)

func get_text_state() -> Dictionary:
	return {
		"id": String(_config.get("id", "chaos_boss")),
		"name": String(_config.get("name", "Chaos Warden")),
		"state": STATE_NAMES[clampi(_state, 0, STATE_NAMES.size() - 1)],
		"phase": _phase + 1,
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
		"rng": int(_rng.state),
	}

func render_snapshot() -> Dictionary:
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
		"target": _target_key,
	}

func serialize() -> Dictionary:
	var cooldowns_serialized := {}
	for key in _cooldowns.keys():
		cooldowns_serialized[str(key)] = float(_cooldowns[key])
	return {
		"version": SAVE_VERSION,
		"state": _state,
		"phase": _phase,
		"hp": _hp,
		"max_hp": _max_hp,
		"position": _position,
		"home_position": _home_position,
		"engaged": is_engaged(),
		"radius": _radius,
		"player_level": _player_level,
		"seed": _seed,
		"rng_state": int(_rng.state),
		"cooldowns": cooldowns_serialized,
		"target_key": _target_key,
		"telegraph_skill": _telegraph_skill,
		"state_timer": _state_timer,
		"reward_given": _reward_given,
		"defeated": is_defeated(),
	}

func restore(data: Dictionary) -> bool:
	if data.is_empty() or int(data.get("version", 0)) > SAVE_VERSION:
		return false
	if int(data.get("version", SAVE_VERSION)) != SAVE_VERSION:
		return false
	_state = int(data.get("state", State.IDLE))
	_state = clampi(_state, State.IDLE, State.DEAD)
	_phase = clampi(int(data.get("phase", 0)), 0, 2)
	_hp = maxf(1.0, float(data.get("hp", _max_hp)))
	_max_hp = maxf(1.0, float(data.get("max_hp", _max_hp)))
	_position = _to_vector2(data.get("position", _home_position), _home_position)
	_home_position = _to_vector2(data.get("home_position", _home_position), _home_position)
	_reward_given = bool(data.get("reward_given", false))
	_seed = int(data.get("seed", _seed))
	_rng.seed = _seed
	_rng.state = int(data.get("rng_state", _rng.state))
	_player_level = int(data.get("player_level", _player_level))
	_target_key = str(data.get("target_key", ""))
	_telegraph_skill = str(data.get("telegraph_skill", ""))
	_state_timer = float(data.get("state_timer", 0.0))
	var saved_cooldowns: Dictionary = Dictionary(data.get("cooldowns", {}))
	for key in SKILL_IDS:
		var fallback_profile := Dictionary(_skill_profiles.get(key, DEFAULT_SKILL_DATA.get(key, {})))
		var value := float(saved_cooldowns.get(key, _value_for_phase(fallback_profile, "cooldown", 1.0)))
		_cooldowns[key] = maxf(0.0, value)
	if is_defeated() or float(data.get("hp", 1.0)) <= 0.0:
		_state = State.DEAD
		_hp = 0.0
		if bool(data.get("reward_given", false)):
			_reward_given = true
	return true

func is_locked_by_skill() -> bool:
	return _state == State.TELEGRAPH or _state == State.RECOVERY

func _advance_phase_behaviour(events: Array[Dictionary]) -> void:
	if _state == State.DEAD:
		return
	if is_locked_by_skill():
		return
	if _state == State.IDLE and (_is_force_engaged or (_latest_player.get("alive", false) and _position.distance_to(Vector2(_latest_player.get("pos", _position))) <= _engage_distance)):
		_state = State.CHASE
		_phase_attack_multiplier = 1.0 + float(_phase) * 0.06
		events.append(_notice("Chaos wakes and engages the battlefield."))
	if _state == State.CHASE:
		if _hp > 0.0 and _should_return_home():
			_state = State.RETURNING
			events.append(_notice("Chaos is too far from its nexus and is returning."))

func _move_idle(delta: float, events: Array[Dictionary]) -> void:
	_velocity = Vector2.ZERO
	_telegraph_skill = ""
	_active_skill = ""
	_active_skill = ""
	_return_target_position = _home_position
	_move_toward(_home_position, delta, 0.35)
	if _is_force_engaged:
		_state = State.CHASE
		events.append(_notice("Chaos force-engage override."))
		_is_force_engaged = false

func _update_chase(delta: float, events: Array[Dictionary]) -> void:
	if _target_key.is_empty():
		_update_target_preference()
	if _target_key.is_empty():
		if _is_force_engaged:
			_target_position = _forced_engage_position
		else:
			_state = State.RETURNING
			return
	var target_pos: Vector2 = _resolve_target_position(_target_key)
	if not target_pos.is_finite():
		target_pos = _forced_engage_position if _forced_engage_position.is_finite() else _home_position
	_move_toward(target_pos, delta, 1.0)
	var can_act := _state_timer <= 0.0 and _distance_to(_latest_player) > 25.0
	if not can_act:
		return
	if _can_cast_skill():
		var selected := _select_skill()
		if selected != "":
			_begin_skill(selected, target_pos, events)
		else:
			_state_timer = 0.15
			_state = State.RECOVERY

func _update_returning(delta: float, events: Array[Dictionary]) -> void:
	_active_skill = ""
	_telegraph_skill = ""
	_telegraph_target = ""
	_telegraph_data.clear()
	_move_toward(_home_position, delta, 1.2)
	if _position.distance_to(_home_position) <= _return_threshold:
		_position = _home_position
		_state = State.IDLE
		_is_force_engaged = false
		events.append(_notice("Chaos has returned to its origin."))

func _update_telegraph(delta: float, events: Array[Dictionary]) -> void:
	if _state_timer <= 0.0:
		_execute_skill(events)
		return
	_state_timer -= delta
	if not _telegraph_warning_announced:
		var name := str(_skill_profiles.get(_telegraph_skill, {}).get("name", _telegraph_skill))
		events.append({"type":"notice","text":"Chaos starts %s telegraph." % name})
		events.append({"type":"audio","cue":"chaos_%s_warning" % _telegraph_skill})
		events.append({"type":"effect","kind":"telegraph_%s" % _telegraph_skill,"pos":_telegraph_position,"radius":float(_telegraph_data.get("radius", _radius)),"duration":float(_telegraph_data.get("telegraph", TELEGRAPH_MIN_SECONDS))})
		_telegraph_warning_announced = true
		if _telegraph_skill == "rift_dash":
			_telegraph_data["dash_preview"] = true

func _update_recovery(delta: float, events: Array[Dictionary]) -> void:
	if _state_timer <= 0.0:
		_state = State.CHASE
		_state_timer = 0.0
		_telegraph_warning_announced = false
		return
	_state_timer -= delta
	events.append(_passive_loop_state_event())
	if _should_return_home() and _state != State.RETURNING:
		_state = State.RETURNING

func _tick_cooldowns(delta: float) -> void:
	for key in _cooldowns.keys():
		_cooldowns[key] = maxf(0.0, float(_cooldowns[key]) - delta)

func _decay_threat(delta: float) -> void:
	for key in _threat.keys():
		var current: float = float(_threat[key])
		current = maxf(0.0, current - THREAT_DECAY_PER_SECOND * delta)
		if current <= 0.0:
			_threat.erase(key)
			_threat_seen.erase(key)
		else:
			_threat[key] = current

func _read_context(context: Dictionary) -> void:
	var player_data: Dictionary = Dictionary(context.get("player", {}))
	var soldiers_value: Variant = context.get("soldiers", [])
	var soldiers: Array = soldiers_value if soldiers_value is Array else []
	_latest_player = player_data.duplicate(true)
	_latest_soldiers.clear()
	_units_by_key.clear()
	if not _latest_player.is_empty():
		var player_id := int(_latest_player.get("id", 0))
		var player_key := "player:%d" % player_id
		_latest_player["kind"] = "player"
		_units_by_key[player_key] = _latest_player.duplicate(true)
		_record_seen(player_key)
		_record_base_threat(player_key, 2.6)
	for soldier_data in soldiers:
		if not soldier_data is Dictionary:
			continue
		var soldier: Dictionary = Dictionary(soldier_data)
		var soldier_id := int(soldier.get("id", -1))
		var soldier_key := "soldier:%d" % soldier_id
		_units_by_key[soldier_key] = soldier.duplicate(true)
		_latest_soldiers.append(soldier.duplicate(true))
		_record_seen(soldier_key)
		_record_base_threat(soldier_key, 1.2)
	_position_blocked = context.get("position_blocked", Callable())
	_is_player_alive = bool(_latest_player.get("alive", true))
	if _latest_player.is_empty():
		_is_player_alive = false

func _update_position_blocker(context: Dictionary) -> void:
	var callable_candidate: Variant = context.get("position_blocked", Callable())
	if callable_candidate is Callable and callable_candidate.is_valid():
		_position_blocked = callable_candidate

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

func _position_breath_if_player(_source_id: String, source_pos: Vector2) -> void:
	if _source_id == "":
		return
	if source_pos.is_finite():
		_telegraph_position = source_pos

func _update_target_preference() -> void:
	var best_key := ""
	var best_score := -INF
	for key in _units_by_key.keys():
		var unit: Dictionary = Dictionary(_units_by_key[key])
		if unit.get("alive", true) == false:
			continue
		var threat_score := float(_threat.get(key, 0.0))
		var pos := Vector2(unit.get("pos", _home_position))
		var dist := maxf(20.0, _position.distance_to(pos))
		var distance_score := 1.0 / (dist / 360.0 + 0.35)
		var alive_bonus := 5.0 if str(key).begins_with("player:") else 1.8
		var hp := float(unit.get("hp", 1.0))
		var max_hp := maxf(1.0, float(unit.get("max_hp", hp if hp > 0.0 else 1.0)))
		var hp_ratio := 1.0 - (hp / max_hp)
		var seen := float(_time - float(_threat_seen.get(key, _time)))
		var recency := 1.0 / (1.0 + seen * 0.25)
		var score := threat_score + alive_bonus + (distance_score * 30.0) + (hp_ratio * 10.0) + (recency * 8.0)
		if str(key).begins_with("player:"):
			score += 8.0
		if score > best_score:
			best_score = score
			best_key = key
	if best_key != "":
		_target_key = best_key
		_target_position = Vector2(Dictionary(_units_by_key.get(best_key, {})).get("pos", _position))
		_target_velocity = Vector2(Dictionary(_units_by_key.get(best_key, {})).get("vel", Vector2.ZERO))
func _should_return_home() -> bool:
	return _position.distance_to(_home_position) > _leash_distance

func _can_cast_skill() -> bool:
	if _state == State.TELEGRAPH or _state == State.RECOVERY:
		return false
	return _state_timer <= 0.0

func _select_skill() -> String:
	var available := []
	var total_weight := 0.0
	for skill_id in SKILL_IDS:
		if not _skill_profiles.has(skill_id):
			continue
		if _state != State.DEAD and float(_cooldowns.get(skill_id, 0.0)) > 0.0:
			continue
		var profile := Dictionary(_skill_profiles.get(skill_id))
		var min_phase := int(profile.get("min_phase", 0))
		var max_phase := int(profile.get("max_phase", 2))
		if _phase < min_phase or _phase > max_phase:
			continue
		var weight := float(_value_for_phase(profile, "weight", 1.0))
		if weight <= 0.0:
			continue
		available.append([skill_id, weight])
		total_weight += weight
	if _forced_skill != "":
		for entry in available:
			if String(entry[0]) == _forced_skill:
				var forced_skill := _forced_skill
				_forced_skill = ""
				return forced_skill
	if available.is_empty():
		_forced_skill = ""
		return ""
	var roll := _rng.randf() * total_weight
	var cumulative := 0.0
	for entry in available:
		var sid: String = String(entry[0])
		var w: float = float(entry[1])
		cumulative += w
		if roll <= cumulative:
			if _forced_skill == sid:
				_forced_skill = ""
			return sid
	_forced_skill = ""
	return String(available[-1][0])

func _begin_skill(skill_id: String, target_pos: Vector2, events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get(skill_id, {}))
	_active_skill = skill_id
	_telegraph_skill = skill_id
	_state = State.TELEGRAPH
	_telegraph_warning_announced = false
	var telegraph := maxf(float(_value_for_phase(profile, "telegraph", TELEGRAPH_MIN_SECONDS)), TELEGRAPH_MIN_SECONDS)
	_state_timer = telegraph
	_cooldowns[skill_id] = _value_for_phase(profile, "cooldown", 5.0)
	_telegraph_position = target_pos
	_telegraph_target = _target_key
	_telegraph_data = {
		"skill": skill_id,
		"telegraph": telegraph,
		"phase": _phase,
		"radius": float(_value_for_phase(profile, "radius", _radius * 1.3)),
		"position": target_pos,
	}
	events.append({"type":"audio","cue":"chaos_%s_charge" % skill_id})

func _execute_skill(events: Array[Dictionary]) -> void:
	if _telegraph_skill == "":
		_state = State.RECOVERY
		_state_timer = 0.2
		return
	var skill_id := _telegraph_skill
	match skill_id:
		"meteor": _cast_meteor(events)
		"destruction_beam": _cast_destruction_beam(events)
		"energy_barrage": _cast_energy_barrage(events)
		"shockwave": _cast_shockwave(events)
		"black_hole": _cast_black_hole(events)
		"summon_monsters": _cast_summon_monsters(events)
		"homing_missiles": _cast_homing_missiles(events)
		"lightning": _cast_lightning(events)
		"rift_dash": _cast_rift_dash(events)
		"total_annihilation": _cast_total_annihilation(events)
		_:
			pass
	var profile := Dictionary(_skill_profiles.get(skill_id, {}))
	var recovery := maxf(0.7, float(_value_for_phase(profile, "recovery", 1.0)))
	_state = State.RECOVERY
	_state_timer = recovery
	_telegraph_data.clear()
	_telegraph_warning_announced = false
	_active_skill = skill_id

func _cast_meteor(events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get("meteor", {}))
	var base_damage := float(_value_for_phase(profile, "damage", 4000.0))
	var radius := float(_value_for_phase(profile, "radius", 150.0))
	var target_pos := _choose_telegraph_center()
	target_pos += Vector2(_rng.randf_range(-30.0, 30.0), _rng.randf_range(-26.0, 26.0))
	var projectile_pos := target_pos - Vector2(0.0, 850.0)
	events.append({"type":"effect","kind":"telegraph_meteor","pos":target_pos,"radius":radius * 1.10,"duration":0.5})
	events.append({
		"type":"projectile",
		"kind":"meteor",
		"pos":projectile_pos,
		"velocity":Vector2(0.0, 620.0),
		"radius":maxf(22.0, radius * 0.30),
		"damage":base_damage * _phase_damage_multiplier(),
		"lifetime":4.4,
		"aoe":radius * 1.10,
		"target_id":_telegraph_target,
		"homing":false,
	})
	events.append({"type":"audio","cue":"chaos_meteor_impact"})
	emit_area_damage(events, target_pos, radius, base_damage * _phase_damage_multiplier(), "meteor", _telegraph_target)

func _cast_destruction_beam(events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get("destruction_beam", {}))
	var damage := float(_value_for_phase(profile, "damage", 3000.0))
	var width := float(_value_for_phase(profile, "radius", 100.0))
	var radius := float(_value_for_phase(profile, "radius", 100.0))
	var target_pos := _telegraph_position
	var direction := (target_pos - _position).normalized()
	if direction == Vector2.ZERO:
		direction = _facing
	var end_pos := _position + direction * 760.0
	events.append({
		"type":"projectile",
		"kind":"destruction_beam",
		"pos":_position,
		"velocity":direction * 0.0,
		"radius":width,
		"damage":damage * _phase_damage_multiplier(),
		"lifetime":0.4,
		"aoe":radius * 1.8,
		"target_id":_telegraph_target,
		"homing":false,
	})
	events.append({"type":"effect","kind":"destruction_beam","pos":(_position + end_pos) * 0.5,"radius":radius,"duration":0.42})
	events.append({"type":"audio","cue":"chaos_destruction_beam"})
	emit_line_damage(events, _position, end_pos, radius, damage * _phase_damage_multiplier(), "destruction_beam")

func _cast_energy_barrage(events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get("energy_barrage", {}))
	var damage := float(_value_for_phase(profile, "damage", 1800.0))
	var radius := float(_value_for_phase(profile, "radius", 52.0))
	var count := int(_value_for_phase(profile, "projectile_count", 5))
	var target_center := _telegraph_position
	for index in count:
		var angle := (_telegraph_position - _position).angle() + _rng.randf_range(-0.55, 0.55)
		var spread := _rng.randf_range(260.0, 720.0)
		var direction := Vector2.from_angle(angle)
		var spawn_pos := _position + direction * 40.0
		events.append({
			"type":"projectile",
			"kind":"energy_shot",
			"pos":spawn_pos,
			"velocity":direction * spread,
			"radius":radius,
			"damage":damage * _phase_damage_multiplier(),
			"lifetime":0.92,
			"aoe":radius * 2.0,
			"target_id":_telegraph_target,
			"homing":false,
		})
		var impact := _predict_position(target_center, direction, spread * 0.06)
		emit_area_damage(events, impact, radius * 1.25, damage * 0.62 * _phase_damage_multiplier(), "energy_barrage", _telegraph_target)
	events.append({"type":"audio","cue":"chaos_energy_barrage"})

func _cast_shockwave(events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get("shockwave", {}))
	var damage := float(_value_for_phase(profile, "damage", 2800.0))
	var radius := float(_value_for_phase(profile, "radius", 300.0))
	var knockback := float(_value_for_phase(profile, "knockback", 240.0))
	var target_pos := _telegraph_position
	events.append({"type":"effect","kind":"shockwave_ring","pos":_position,"radius":radius,"duration":0.78})
	events.append({"type":"audio","cue":"chaos_shockwave"})
	for key in _units_by_key.keys():
		if not _is_unit_alive_unit(key):
			continue
		var unit_pos := Vector2(Dictionary(_units_by_key[key]).get("pos", target_pos))
		var distance := unit_pos.distance_to(target_pos)
		if distance <= radius:
			var scaled := damage * _phase_damage_multiplier() * (1.0 - distance / (radius * 1.05))
			events.append(_damage_event(_target_or_player_key(key), scaled, "shockwave", key))
			var knock := (unit_pos - target_pos).normalized() * (knockback * (1.0 - distance / radius))
			events.append({"type":"knockback","target":key,"origin":target_pos,"force":knock})

func _cast_black_hole(events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get("black_hole", {}))
	var radius := float(_value_for_phase(profile, "radius", 200.0))
	var damage := float(_value_for_phase(profile, "damage", 980.0))
	var duration := float(_value_for_phase(profile, "lifetime", 5.4))
	var tick := float(_value_for_phase(profile, "tick", 0.38))
	var target_pos := _telegraph_position
	events.append({
		"type":"hazard",
		"kind":"black_hole",
		"pos":target_pos,
		"radius":radius,
		"duration":duration,
		"damage":damage * _phase_damage_multiplier(),
		"tick":tick,
	})
	events.append({"type":"audio","cue":"chaos_black_hole"})
	emit_area_damage(events, target_pos, radius, damage * _phase_damage_multiplier(), "black_hole", "", true)
	events.append({"type":"effect","kind":"black_hole_vortex","pos":target_pos,"radius":radius * 1.06,"duration":duration})

func _cast_summon_monsters(events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get("summon_monsters", {}))
	var count := int(_value_for_phase(profile, "count", 4))
	var center := _telegraph_position
	for index in count:
		var angle := _rng.randf_range(0.0, TAU)
		var radius := 120.0 + _rng.randf_range(18.0, 60.0)
		var pos := center + Vector2.from_angle(angle) * radius
		events.append({"type":"summon","kind":"chaos_minion","pos":pos,"count":1})
		events.append({"type":"effect","kind":"summon_monster_flare","pos":pos,"radius":34.0,"duration":0.7})
	events.append({"type":"audio","cue":"chaos_summon_monsters"})
	events.append({"type":"notice","text":"Additional guardians have entered the field."})

func _cast_homing_missiles(events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get("homing_missiles", {}))
	var count := int(_value_for_phase(profile, "projectile_count", 5))
	var damage := float(_value_for_phase(profile, "damage", 1300.0))
	var radius := float(_value_for_phase(profile, "radius", 26.0))
	var base_target := _telegraph_target
	for index in count:
		var launch_angle := TAU * float(index) / float(maxi(1, count)) + _rng.randf_range(-0.18, 0.18)
		var spawn := _position + Vector2.from_angle(launch_angle) * (_radius + 34.0)
		var vel := (_telegraph_position - spawn).normalized() * 380.0
		events.append({
			"type":"projectile",
			"kind":"homing_missile",
			"pos":spawn,
			"velocity":vel,
			"radius":radius,
			"damage":damage * _phase_damage_multiplier(),
			"lifetime":_rng.randf_range(4.0, 6.0),
			"aoe":radius * 2.8,
			"target_id":base_target,
			"homing":true,
		})
	events.append({"type":"audio","cue":"chaos_homing_missiles"})
	events.append({"type":"notice","text":"Homing missiles converging."})

func _cast_lightning(events: Array[Dictionary]) -> void:
	var profile := Dictionary(_skill_profiles.get("lightning", {}))
	var damage := float(_value_for_phase(profile, "damage", 1700.0))
	var hops := int(_value_for_phase(profile, "projectile_count", 5))
	var anchor := _resolve_target_position(_telegraph_target)
	var chain_targets := _units_in_radius(anchor, 430.0, true)
	var strike_idx := 0
	for key in chain_targets:
		if not _is_unit_alive_unit(key):
			continue
		if strike_idx >= hops:
			break
		var unit := Vector2(Dictionary(_units_by_key[key]).get("pos", anchor))
		var jump_damage := damage * _phase_damage_multiplier() * (1.0 - float(strike_idx) * 0.12)
		events.append({"type":"effect","kind":"lightning_strike","pos":unit,"radius":28.0,"duration":0.25})
		events.append(_damage_event(key, jump_damage, "lightning", _telegraph_skill))
		emit_chain_knockback(events, unit, anchor, 140.0 * _phase_damage_multiplier())
		strike_idx += 1
		anchor = unit
	events.append({"type":"audio","cue":"chaos_lightning"})

func _cast_rift_dash(events: Array[Dictionary]) -> void:
	if _phase < 2:
		return
	var profile := Dictionary(_skill_profiles.get("rift_dash", {}))
	var damage := float(_value_for_phase(profile, "damage", 5600.0))
	var knockback := float(_value_for_phase(profile, "knockback", 360.0))
	var radius := float(_value_for_phase(profile, "radius", 220.0))
	var target := _resolve_target_position(_telegraph_target)
	var dash_vec := (target - _position)
	if dash_vec == Vector2.ZERO:
		dash_vec = _facing
	dash_vec = dash_vec.normalized()
	var next_pos := _position + dash_vec * 320.0
	next_pos = _resolve_path(next_pos)
	_position = next_pos
	events.append({"type":"effect","kind":"rift_dash","pos":_position,"radius":radius,"duration":0.35})
	events.append({"type":"audio","cue":"chaos_rift_dash"})
	for key in _units_by_key.keys():
		if not _is_unit_alive_unit(key):
			continue
		var unit_pos := Vector2(Dictionary(_units_by_key[key]).get("pos", _position))
		if unit_pos.distance_to(_position) <= radius:
			events.append(_damage_event(key, damage * _phase_damage_multiplier(), "rift_dash", _telegraph_skill))
			var dir := (unit_pos - _position).normalized()
			events.append({"type":"knockback","target":key,"origin":_position,"force":dir * knockback})
	events.append({"type":"notice","text":"Chaos tears space and repositions."})

func _cast_total_annihilation(events: Array[Dictionary]) -> void:
	if _phase < 2:
		return
	var profile := Dictionary(_skill_profiles.get("total_annihilation", {}))
	var radius := float(_value_for_phase(profile, "radius", 360.0))
	var base_damage := float(_value_for_phase(profile, "damage", 9800.0))
	var impact_pos := _telegraph_position
	events.append({"type":"effect","kind":"total_annihilation_pre","pos":impact_pos,"radius":radius,"duration":1.2})
	events.append({"type":"audio","cue":"chaos_total_annihilation"}
)
	events.append({"type":"notice","text":"Total Annihilation! No safe ground remains."})
	emit_area_damage(events, impact_pos, radius, base_damage * _phase_damage_multiplier(), "total_annihilation", _telegraph_target, false, 0.62)
	for index in 12:
		var angle := _rng.randf() * TAU + _rng.randf_range(-0.15, 0.15)
		var velocity := Vector2.from_angle(angle) * _rng.randf_range(560.0, 780.0)
		var spawn := impact_pos + velocity.normalized() * 35.0
		var projectile_damage := (base_damage * _phase_damage_multiplier()) * 0.35
		events.append({
			"type":"projectile",
			"kind":"annihilation_fragment",
			"pos":spawn,
			"velocity":velocity,
			"radius":24.0,
			"damage":projectile_damage,
			"lifetime":1.4,
			"aoe":68.0,
			"target_id":_telegraph_target,
			"homing":false,
		})
	events.append({"type":"effect","kind":"total_annihilation","pos":impact_pos,"radius":radius * 1.1,"duration":0.35})

func _emit_area_damage(events: Array[Dictionary], center: Vector2, radius: float, base_damage: float, source_skill: String, fallback_target: String = "", force_player_only: bool = false, multiplier: float = 1.0) -> void:
	var target_keys := _units_in_radius(center, radius, true)
	if force_player_only:
		target_keys.clear()
		if _latest_player.get("alive", false) and Vector2(_latest_player.get("pos", center)).distance_to(center) <= radius:
			target_keys = ["player:" + str(int(_latest_player.get("id", 0)))]
	if not target_keys.is_empty():
		for key in target_keys:
			if not _is_unit_alive_unit(key):
				continue
			var unit := Dictionary(_units_by_key[key])
			var u_pos := Vector2(unit.get("pos", center))
			var falloff := 1.0 - minf(0.95, center.distance_to(u_pos) / maxf(radius, 1.0))
			var amount := maxf(1.0, base_damage * multiplier * falloff)
			events.append(_damage_event(key, amount, source_skill, _telegraph_skill))
	elif _units_by_key.is_empty() and not fallback_target.is_empty():
		var fallback := _target_or_player_key(fallback_target)
		events.append(_damage_event(fallback, base_damage * multiplier, source_skill, _telegraph_skill))

func _emit_circle_chain(events: Array[Dictionary], center: Vector2, radius: float) -> void:
	events.append({"type":"effect","kind":"area_circle","pos":center,"radius":radius,"duration":0.35})

func emit_area_damage(events: Array[Dictionary], center: Vector2, radius: float, base_damage: float, source_skill: String, fallback_target: String = "", force_player_only: bool = false, multiplier: float = 1.0) -> void:
	_emit_area_damage(events, center, radius, base_damage, source_skill, fallback_target, force_player_only, multiplier)

func emit_line_damage(events: Array[Dictionary], from: Vector2, to: Vector2, width: float, base_damage: float, source_skill: String) -> void:
	for key in _units_by_key.keys():
		if not _is_unit_alive_unit(key):
			continue
		var unit_pos := Vector2(Dictionary(_units_by_key[key]).get("pos", from))
		var line_distance := _distance_point_segment(unit_pos, from, to)
		if line_distance <= width:
			var ratio := 1.0 - minf(0.9, line_distance / width)
			events.append(_damage_event(key, base_damage * ratio * _phase_damage_multiplier(), source_skill, _telegraph_skill))
			events.append({"type":"effect","kind":"line_hit","pos":unit_pos,"radius":8.0,"duration":0.2})

func emit_chain_knockback(events: Array[Dictionary], from: Vector2, to: Vector2, force: float) -> void:
	var vector := (to - from).normalized()
	for key in _units_in_radius(to, 260.0, true):
		events.append({"type":"knockback","target":key,"origin":from,"force":vector * force})

func _units_in_radius(center: Vector2, radius: float, prefer_alive_only: bool = true) -> Array[String]:
	var keys: Array[String] = []
	for key in _units_by_key.keys():
		var unit := Dictionary(_units_by_key[key])
		if prefer_alive_only and not bool(unit.get("alive", true)):
			continue
		if Vector2(unit.get("pos", _position)).distance_to(center) <= radius:
			keys.append(str(key))
	return keys

func _target_or_player_key(key: String) -> String:
	if key.is_empty():
		return "player:%d" % int(_latest_player.get("id", 0))
	return key

func _damage_event(target_key: String, amount: float, skill: String, source_skill: String) -> Dictionary:
	return {
		"type":"damage",
		"target": target_key,
		"amount": amount,
		"source": SOURCE_ID,
		"source_id": BOSS_ENTITY_ID,
		"skill": skill,
		"source_skill": source_skill,
	}

func _is_unit_alive_unit(key: String) -> bool:
	if key == "":
		return false
	if not _units_by_key.has(key):
		return false
	var unit := Dictionary(_units_by_key[key])
	return bool(unit.get("alive", true))

func _move_toward(destination: Vector2, delta: float, urgency: float) -> void:
	var wanted := destination - _position
	var distance := wanted.length()
	if distance <= _return_threshold:
		_velocity = Vector2.ZERO
		return
	var target_dir := wanted.normalized()
	_facing = target_dir
	var speed := _move_speed * _phase_attack_multiplier * urgency
	var step := target_dir * minf(distance, speed * delta)
	var next_pos := _position + step
	if _is_blocked(next_pos, get_radius()):
		next_pos = _resolve_around_obstacle(next_pos, destination)
	_velocity = (next_pos - _position) / maxf(delta, 0.0001)
	_position = next_pos

func _is_blocked(position: Vector2, radius: float) -> bool:
	if _position_blocked is Callable and _position_blocked.is_valid():
		var result: Variant = _position_blocked.call(position, radius)
		return bool(result)
	return false

func _resolve_around_obstacle(fallback: Vector2, destination: Vector2) -> Vector2:
	var dirs := [
		Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT,
		Vector2(0.7, -0.7).normalized(), Vector2(-0.7, 0.7).normalized(),
		Vector2(0.7, 0.7).normalized(), Vector2(-0.7, -0.7).normalized(),
	]
	for direction in dirs:
		var candidate: Vector2 = destination + direction * 52.0
		if not _is_blocked(candidate, get_radius()):
			return candidate
	return _position

func _resolve_path(position: Vector2) -> Vector2:
	if not _is_blocked(position, get_radius()):
		return position
	return _resolve_around_obstacle(position, position)

func _update_phase_if_needed(events: Array[Dictionary]) -> void:
	var ratio := _hp / maxf(_max_hp, 1.0)
	var target_phase := 0
	if ratio <= _phase_threshold_three:
		target_phase = 2
	elif ratio <= _phase_threshold_two:
		target_phase = 1
	if target_phase > _phase:
		_phase = target_phase
		_phase_attack_multiplier = 1.0 + float(_phase) * 0.10
		_phase_transitioned = true
		events.append(_notice("Chaos rises to Phase %d." % (_phase + 1)))
		var phase_names := ["裂界甦醒", "星滅狂潮", "萬象歸零"]
		events.append({"type":"phase", "phase":_phase + 1, "name":phase_names[_phase]})
		events.append({"type":"audio","cue":"chaos_phase_%d" % (_phase + 1)})

func _distance_point_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var line := b - a
	var len_sq := line.length_squared()
	if len_sq <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(line) / len_sq, 0.0, 1.0)
	return point.distance_to(a + line * t)

func _choose_telegraph_center() -> Vector2:
	var target_pos := _telegraph_position
	if _is_target_locked():
		target_pos = _telegraph_position
	else:
		var fallback := _position + _facing * 360.0
		target_pos = fallback
	return target_pos

func _is_target_locked() -> bool:
	if _telegraph_target == "":
		return false
	return _units_by_key.has(_telegraph_target) and _is_unit_alive_unit(_telegraph_target)

func _resolve_target_position(key: String) -> Vector2:
	if key == "":
		if _forced_engage_position.is_finite():
			return _forced_engage_position
		return _position
	if key == "player:0" and not _latest_player.is_empty():
		return Vector2(_latest_player.get("pos", _position))
	if _units_by_key.has(key):
		return Vector2(Dictionary(_units_by_key[key]).get("pos", _position))
	return _position

func _current_target_position() -> Vector2:
	return _resolve_target_position(_target_key)

func _value_for_phase(profile: Dictionary, key: String, default_value: Variant) -> Variant:
	var value: Variant = profile.get(key, default_value)
	if value is Array:
		return value[clampi(_phase, 0, value.size() - 1)]
	return value

func _phase_damage_multiplier() -> float:
	return 1.0 + float(_phase) * 0.22

func _predict_position(center: Vector2, direction: Vector2, time: float) -> Vector2:
	return center + direction.normalized() * direction.length() * time

func _distance_to(target: Variant) -> float:
	if target is Vector2:
		return _position.distance_to(target)
	if target is Dictionary:
		return _position.distance_to(Vector2(target.get("pos", _position)))
	if target is String:
		return _position.distance_to(_resolve_target_position(target))
	return 1e18

func _die(events: Array[Dictionary]) -> void:
	if _state == State.DEAD:
		return
	_state = State.DEAD
	_hp = 0.0
	_reward_given = true
	var gold := _reward_drop_gold()
	var xp := _reward_drop_xp()
	events.append({"type":"reward","gold":gold,"xp":xp})
	events.append({"type":"audio","cue":"chaos_defeated"})
	events.append({"type":"notice","text":"Chaos has been defeated."})
	events.append({"type":"effect","kind":"defeat","pos":_position,"radius":220.0,"duration":2.6})
	_pending_defeat_event = true

func _reward_drop_gold() -> int:
	var bonus := int(maxf(0.0, _max_hp / 12000.0))
	return clampi(_reward_min_gold + bonus, _reward_min_gold, _reward_max_gold)

func _reward_drop_xp() -> int:
	var bonus := int(maxf(0.0, _phase * 260.0))
	return clampi(_reward_min_xp + bonus, _reward_min_xp, _reward_max_xp)

func _to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Dictionary:
		var d := Dictionary(value)
		return Vector2(float(d.get("x", fallback.x)), float(d.get("y", fallback.y)))
	return fallback

func _passive_loop_state_event() -> Dictionary:
	return {"type":"effect","kind":"chaos_idle_loop","pos":_position,"radius":get_radius(),"duration":0.16}

func _notice(text: String) -> Dictionary:
	return {"type":"notice","text":text}

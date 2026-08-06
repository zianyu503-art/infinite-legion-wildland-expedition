class_name PythonBossController
extends RefCounted

## 「腐沼蟒皇・薩迦」的獨立資料／AI 控制器。
## 主遊戲只需提供友軍快照與障礙查詢；控制器回傳事件，不直接持有場景節點。

const GameConfig = preload("res://scripts/game_config.gd")

enum State {
	IDLE,
	ALERT,
	CHASE,
	REPOSITION,
	TELEGRAPH,
	CASTING,
	RECOVERY,
	STUNNED,
	RETURNING,
	PHASE_CHANGE,
	DEAD,
}

const SKILL_IDS: Array[String] = ["constrict", "dash", "bite", "poison_pool", "tail_sweep"]
const STATE_NAMES: Array[String] = [
	"IDLE", "ALERT", "CHASE", "REPOSITION", "TELEGRAPH", "CASTING",
	"RECOVERY", "STUNNED", "RETURNING", "PHASE_CHANGE", "DEAD",
]
const SAVE_VERSION := 2
const BOSS_ENTITY_ID := -9001
const MAX_ATTACK_CACHE := 192
const ATTACK_CACHE_TTL := 4.0

var _config: Dictionary = {}
var _base: Dictionary = {}
var _body_config: Dictionary = {}
var _skill_config: Dictionary = {}
var _phase_config: Array = []
var _threat_config: Dictionary = {}
var _performance_config: Dictionary = {}
var _rng := RandomNumberGenerator.new()

var _world_tier := 0
var _player_level := 1
var _seed := 20260802

var _state := State.IDLE
var _state_timer := 0.0
var _age := 0.0
var _discovered := false
var _nest_cleared := false
var _reward_claimed := false
var _death_elapsed := 0.0

var _home := Vector2.ZERO
var _position := Vector2.ZERO
var _velocity := Vector2.ZERO
var _facing := Vector2.RIGHT
var _max_hp := 6000.0
var _hp := 6000.0
var _damage := 55.0
var _defense := 22.0
var _move_speed := 105.0
var _turn_speed := 2.8

var _phase := 0
var _pending_phase := -1
var _phase_wave_fired := false
var _flash_timer := 0.0
var _stun_timer := 0.0

var _target_key := ""
var _target: Dictionary = {}
var _target_lock_timer := 0.0
var _no_target_timer := 0.0
var _threat: Dictionary = {}
var _decision_timer := 0.0
var _idle_think_timer := 0.0
var _reposition_side := 1.0
var _avoid_direction := Vector2.ZERO
var _avoid_timer := 0.0
var _avoid_side := 1.0
var _blocked_move_frames := 0

var _active_skill := ""
var _telegraph: Dictionary = {}
var _cast_timer := 0.0
var _cast_elapsed := 0.0
var _recovery_timer := 0.0
var _global_skill_gap := 0.0
var _cooldowns: Dictionary = {}
var _recent_skills: Array[String] = []
var _control_lockout := 0.0
var _cast_hit_set: Dictionary = {}
var _forced_skill := ""
var _second_bite_pending := false
var _dash_distance := 0.0
var _dash_trail_distance := 0.0
var _tail_previous_angle := 0.0
var _bubble_audio_timer := 0.0

var _constrict_key := ""
var _constrict_timer := 0.0
var _constrict_tick_timer := 0.0
var _constrict_break_gauge := 0.0
var _constrict_anchor := Vector2.ZERO

var _path_history: Array[Vector2] = []
var _segments: Array[Dictionary] = []
var _attack_cache: Dictionary = {}
var _unit_statuses: Dictionary = {}
var _queued_events: Array[Dictionary] = []

var _unit_grid: Dictionary = {}
var _units_by_key: Dictionary = {}
var _grid_cell_size := 160.0
var _position_blocked := Callable()
var _safe_zones: Array = []

# 固定槽位物件池；暖機後不再建立毒液球或毒潭 Dictionary。
var _glob_slots: Array[Dictionary] = []
var _pool_slots: Array[Dictionary] = []


func initialize(config: Dictionary, world_tier: int, player_level: int, seed: int = 20260802) -> void:
	_config = config.duplicate(true) if not config.is_empty() else GameConfig.PYTHON_BOSS_CONFIG.duplicate(true)
	_base = Dictionary(_config.get("base", {}))
	_body_config = Dictionary(_config.get("body", {}))
	_skill_config = Dictionary(_config.get("skills", {}))
	_phase_config = Array(_config.get("phases", []))
	_threat_config = Dictionary(_config.get("threat", {}))
	_performance_config = Dictionary(_config.get("performance", {}))
	_world_tier = world_tier
	_player_level = player_level
	_seed = seed
	_rng.seed = seed
	_grid_cell_size = float(_performance_config.get("spatial_hash_cell", 160.0))
	_home = Vector2(_config.get("home_position", Vector2(2400.0, 1440.0)))
	_load_scaled_stats()
	_reset_runtime(true)


func reset_encounter(world_tier: int = -1, player_level: int = -1, seed: int = -1) -> void:
	if world_tier >= 0:
		_world_tier = world_tier
	if player_level >= 1:
		_player_level = player_level
	if seed >= 0:
		_seed = seed
		_rng.seed = seed
	_load_scaled_stats()
	_reset_runtime(true)


func refresh_scaling(world_tier: int, player_level: int) -> void:
	if _state != State.IDLE or is_defeated():
		return
	var tier_cap: int = int(Dictionary(_config.get("scaling", {})).get("max_world_tier", 6))
	var normalized_world_tier := clampi(world_tier, 0, tier_cap)
	if normalized_world_tier == _world_tier and player_level == _player_level:
		return
	var hp_ratio: float = _hp / maxf(_max_hp, 1.0)
	_world_tier = normalized_world_tier
	_player_level = player_level
	_load_scaled_stats()
	_hp = _max_hp if hp_ratio >= 0.999 else _max_hp * hp_ratio


func _load_scaled_stats() -> void:
	var scaling: Dictionary = Dictionary(_config.get("scaling", {}))
	var tier_cap: int = int(scaling.get("max_world_tier", 6))
	var level_cap: int = int(scaling.get("max_player_level_bonus", 12))
	var level_start: int = int(scaling.get("player_level_start", 8))
	_world_tier = clampi(_world_tier, 0, tier_cap)
	var tier: int = _world_tier
	var level_delta: int = clampi(_player_level - level_start, 0, level_cap)
	var hp_scale: float = 1.0 + float(tier) * float(scaling.get("world_tier_hp", 0.30)) + float(level_delta) * float(scaling.get("player_level_hp", 0.04))
	var damage_scale: float = 1.0 + float(tier) * float(scaling.get("world_tier_damage", 0.15)) + float(level_delta) * float(scaling.get("player_level_damage", 0.025))
	_max_hp = float(_base.get("max_hp", 6000.0)) * hp_scale
	_hp = _max_hp
	_damage = float(_base.get("damage", 55.0)) * damage_scale
	_defense = float(_base.get("defense", 22.0))
	_move_speed = float(_base.get("move_speed", 105.0))
	_turn_speed = float(_base.get("turn_speed", 2.8))


func _reset_runtime(reset_world_flags: bool) -> void:
	_state = State.IDLE
	_state_timer = 0.0
	_age = 0.0
	_position = _home
	_velocity = Vector2.ZERO
	_facing = Vector2.RIGHT
	_hp = _max_hp
	_phase = 0
	_pending_phase = -1
	_phase_wave_fired = false
	_flash_timer = 0.0
	_stun_timer = 0.0
	_target_key = ""
	_target.clear()
	_target_lock_timer = 0.0
	_no_target_timer = 0.0
	_threat.clear()
	_decision_timer = 0.0
	_idle_think_timer = 0.0
	_reposition_side = 1.0
	_avoid_direction = Vector2.ZERO
	_avoid_timer = 0.0
	_avoid_side = 1.0
	_blocked_move_frames = 0
	_active_skill = ""
	_telegraph.clear()
	_cast_timer = 0.0
	_cast_elapsed = 0.0
	_recovery_timer = 0.0
	_global_skill_gap = 0.0
	_cooldowns.clear()
	for skill_id in SKILL_IDS:
		_cooldowns[skill_id] = 0.0
	_recent_skills.clear()
	_control_lockout = 0.0
	_cast_hit_set.clear()
	_forced_skill = ""
	_second_bite_pending = false
	_dash_distance = 0.0
	_dash_trail_distance = 0.0
	_tail_previous_angle = 0.0
	_bubble_audio_timer = 0.0
	_constrict_key = ""
	_constrict_timer = 0.0
	_constrict_tick_timer = 0.0
	_constrict_break_gauge = 0.0
	_constrict_anchor = Vector2.ZERO
	_attack_cache.clear()
	_unit_statuses.clear()
	_queued_events.clear()
	_unit_grid.clear()
	_units_by_key.clear()
	_safe_zones.clear()
	_position_blocked = Callable()
	if reset_world_flags:
		_discovered = false
		_nest_cleared = false
		_reward_claimed = false
		_death_elapsed = 0.0
	_initialize_object_pools()
	_reset_body_history()


func _initialize_object_pools() -> void:
	_glob_slots.clear()
	_pool_slots.clear()
	var glob_cap: int = int(_performance_config.get("max_poison_projectiles", 8))
	var pool_cap: int = int(_performance_config.get("max_poison_pools", 6)) + int(_performance_config.get("max_aux_poison_areas", 10))
	for index in glob_cap:
		_glob_slots.append({"slot": index, "active": false})
	for index in pool_cap:
		_pool_slots.append({"slot": index, "active": false})


func _reset_body_history() -> void:
	_path_history.clear()
	var history_step: float = float(_body_config.get("history_step", 5.0))
	var segment_count: int = int(_body_config.get("segment_count", 18))
	var spacing: float = float(_body_config.get("segment_spacing", 28.0))
	var needed: int = int(ceil((float(segment_count) * spacing + 200.0) / maxf(history_step, 1.0)))
	for index in needed:
		_path_history.append(_position - _facing * history_step * float(index))
	_rebuild_segments()


func update(delta: float, context: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_drain_queued_events(events)
	if delta <= 0.0:
		return events
	_age += delta
	_flash_timer = maxf(0.0, _flash_timer - delta)
	if _state == State.DEAD:
		_death_elapsed += delta
		return events

	_read_context(context)
	_rebuild_unit_grid(context)
	_tick_cooldowns(delta)
	_tick_attack_cache(delta)
	_tick_unit_statuses(delta, events)
	_update_poison_globs(delta, events)
	_update_poison_pools(delta, events)
	_update_discovery()
	_update_threat_and_target(delta)
	_validate_locked_telegraph_target(events)
	_validate_constrict_target(events)

	if _position.distance_to(_home) > float(_base.get("leash_distance", 1000.0)) and _state != State.RETURNING:
		_enter_returning(events, "越過巢穴界線")

	if _pending_phase > _phase and _state in [State.IDLE, State.ALERT, State.CHASE, State.REPOSITION]:
		_enter_phase_change(events)

	match _state:
		State.IDLE:
			_update_idle(delta, events)
		State.ALERT:
			_update_alert(delta, events)
		State.CHASE:
			_update_chase(delta, events)
		State.REPOSITION:
			_update_reposition(delta, events)
		State.TELEGRAPH:
			_update_telegraph(delta, events)
		State.CASTING:
			_update_casting(delta, events)
		State.RECOVERY:
			_update_recovery(delta, events)
		State.STUNNED:
			_update_stunned(delta, events)
		State.RETURNING:
			_update_returning(delta, events)
		State.PHASE_CHANGE:
			_update_phase_change(delta, events)
		State.DEAD:
			pass

	_rebuild_segments()
	return events


func _read_context(context: Dictionary) -> void:
	var blocked_value: Variant = context.get("position_blocked", Callable())
	_position_blocked = blocked_value if blocked_value is Callable else Callable()
	var safe_value: Variant = context.get("safe_zones", [])
	_safe_zones = Array(safe_value) if safe_value is Array else []


func _drain_queued_events(events: Array[Dictionary]) -> void:
	for event in _queued_events:
		events.append(event)
	_queued_events.clear()


func _tick_cooldowns(delta: float) -> void:
	_global_skill_gap = maxf(0.0, _global_skill_gap - delta)
	_control_lockout = maxf(0.0, _control_lockout - delta)
	_target_lock_timer = maxf(0.0, _target_lock_timer - delta)
	_decision_timer = maxf(0.0, _decision_timer - delta)
	for skill_id in SKILL_IDS:
		_cooldowns[skill_id] = maxf(0.0, float(_cooldowns.get(skill_id, 0.0)) - delta)


func _tick_attack_cache(delta: float) -> void:
	var expired: Array = []
	for key in _attack_cache.keys():
		var remaining: float = float(_attack_cache[key]) - delta
		if remaining <= 0.0:
			expired.append(key)
		else:
			_attack_cache[key] = remaining
	for key in expired:
		_attack_cache.erase(key)


func _rebuild_unit_grid(context: Dictionary) -> void:
	_unit_grid.clear()
	_units_by_key.clear()
	var units_value: Variant = context.get("units", [])
	if not units_value is Array:
		return
	for unit_value in Array(units_value):
		if not unit_value is Dictionary:
			continue
		var unit: Dictionary = Dictionary(unit_value).duplicate(true)
		if not bool(unit.get("alive", true)):
			continue
		unit["kind"] = str(unit.get("kind", "soldier"))
		unit["id"] = int(unit.get("id", -1))
		unit["type"] = str(unit.get("type", ""))
		unit["pos"] = Vector2(unit.get("pos", Vector2.ZERO))
		unit["vel"] = Vector2(unit.get("vel", Vector2.ZERO))
		unit["radius"] = float(unit.get("radius", 12.0))
		unit["safe"] = bool(unit.get("safe", false))
		var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
		_units_by_key[key] = unit
		var cell: Vector2i = _grid_cell(Vector2(unit["pos"]))
		var cell_key: String = _cell_key(cell)
		if not _unit_grid.has(cell_key):
			_unit_grid[cell_key] = []
		var members: Array = Array(_unit_grid[cell_key])
		members.append(key)
		_unit_grid[cell_key] = members


func _grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / _grid_cell_size), floori(position.y / _grid_cell_size))


func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


func _units_in_radius(center: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var padded_radius: float = radius + float(_performance_config.get("unit_query_padding", 48.0))
	var minimum: Vector2i = _grid_cell(center - Vector2.ONE * padded_radius)
	var maximum: Vector2i = _grid_cell(center + Vector2.ONE * padded_radius)
	for cell_y in range(minimum.y, maximum.y + 1):
		for cell_x in range(minimum.x, maximum.x + 1):
			var members_value: Variant = _unit_grid.get(_cell_key(Vector2i(cell_x, cell_y)), [])
			if not members_value is Array:
				continue
			for key_value in Array(members_value):
				var key: String = str(key_value)
				if seen.has(key) or not _units_by_key.has(key):
					continue
				seen[key] = true
				var unit: Dictionary = Dictionary(_units_by_key[key])
				if center.distance_to(Vector2(unit["pos"])) <= radius + float(unit["radius"]):
					result.append(unit)
	return result


func _update_discovery() -> void:
	if _discovered:
		return
	for unit in _units_in_radius(_home, float(_base.get("arena_radius", 850.0)) + 180.0):
		if str(unit["kind"]) == "player":
			_discovered = true
			_queued_events.append({"type": "notice", "kind": "boss_discovered", "text": "發現腐沼蟒皇・薩迦的巢穴"})
			return


func _update_threat_and_target(delta: float) -> void:
	var decay_rate: float = float(_threat_config.get("decay_per_second", 0.05))
	var decay_multiplier: float = exp(-decay_rate * delta)
	for key in _threat.keys():
		_threat[key] = float(_threat[key]) * decay_multiplier

	for unit in _units_by_key.values():
		var unit_data: Dictionary = Dictionary(unit)
		var key: String = _unit_key(str(unit_data["kind"]), int(unit_data["id"]))
		if str(unit_data["kind"]) == "player":
			_threat[key] = float(_threat.get(key, 80.0)) + float(_threat_config.get("player_base_per_second", 5.0)) * delta
		elif str(unit_data["type"]) == "heavy" and _position.distance_to(Vector2(unit_data["pos"])) <= 220.0:
			_threat[key] = float(_threat.get(key, 10.0)) + float(_threat_config.get("heavy_taunt_per_second", 25.0)) * delta
		elif not _threat.has(key):
			_threat[key] = 10.0

	if _state in [State.TELEGRAPH, State.CASTING, State.RECOVERY, State.PHASE_CHANGE, State.RETURNING, State.DEAD]:
		if _target_key != "" and _units_by_key.has(_target_key):
			_target = Dictionary(_units_by_key[_target_key])
		return

	if _target_key != "" and _target_lock_timer > 0.0 and _is_valid_target_key(_target_key, true):
		_target = Dictionary(_units_by_key[_target_key])
		_no_target_timer = 0.0
		return

	var candidates: Array[Dictionary] = []
	var search_radius: float = float(_base.get("alert_range", 650.0)) if _state == State.IDLE else float(_base.get("arena_radius", 850.0))
	for unit in _units_in_radius(_position, search_radius):
		var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
		if not _is_valid_target_key(key, false):
			continue
		var distance_score: float = 25.0 * (1.0 - clampf(_position.distance_to(Vector2(unit["pos"])) / maxf(search_radius, 1.0), 0.0, 1.0))
		var score: float = float(_threat.get(key, 0.0)) + distance_score
		candidates.append({"key": key, "score": score})
	if candidates.is_empty():
		_target.clear()
		_target_key = ""
		_no_target_timer += delta
		return
	candidates.sort_custom(Callable(self, "_sort_score_desc"))
	if candidates.size() > 2:
		candidates.resize(2)
	var total: float = 0.0
	for entry in candidates:
		total += maxf(1.0, float(entry["score"]))
	var roll: float = _rng.randf_range(0.0, total)
	var cursor: float = 0.0
	var chosen_key: String = str(candidates[0]["key"])
	for entry in candidates:
		cursor += maxf(1.0, float(entry["score"]))
		if roll <= cursor:
			chosen_key = str(entry["key"])
			break
	_target_key = chosen_key
	_target = Dictionary(_units_by_key[chosen_key])
	_target_lock_timer = _rng.randf_range(float(_base.get("target_lock_min", 1.5)), float(_base.get("target_lock_max", 3.0)))
	_no_target_timer = 0.0


func _is_valid_target_key(key: String, allow_far: bool) -> bool:
	if not _units_by_key.has(key):
		return false
	var unit: Dictionary = Dictionary(_units_by_key[key])
	if bool(unit.get("safe", false)):
		return false
	var max_distance: float = float(_base.get("leash_distance", 1000.0)) if allow_far else float(_base.get("arena_radius", 850.0))
	return _home.distance_to(Vector2(unit["pos"])) <= max_distance


func _validate_locked_telegraph_target(events: Array[Dictionary]) -> void:
	if _state != State.TELEGRAPH:
		return
	if _target_key != "" and _is_valid_target_key(_target_key, true):
		return
	var cancelled_skill := _active_skill
	_active_skill = ""
	_telegraph.clear()
	_cast_hit_set.clear()
	_target.clear()
	_target_key = ""
	_state = State.RECOVERY
	_recovery_timer = 0.30
	_global_skill_gap = maxf(_global_skill_gap, 0.60)
	events.append({"type": "recovery", "skill": cancelled_skill, "duration": _recovery_timer, "cancelled": true})


func _unit_is_attackable(unit: Dictionary) -> bool:
	return bool(unit.get("alive", true)) and not bool(unit.get("safe", false))


func _sort_score_desc(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("score", 0.0)) > float(b.get("score", 0.0))


func _update_idle(delta: float, events: Array[Dictionary]) -> void:
	_velocity = Vector2.ZERO
	_idle_think_timer -= delta
	if _idle_think_timer > 0.0:
		return
	_idle_think_timer = float(_performance_config.get("far_update_interval", 0.25))
	if not _target.is_empty():
		_state = State.ALERT
		_state_timer = 0.45
		_discovered = true
		events.append({"type": "audio", "kind": "hiss"})
		events.append({"type": "notice", "kind": "boss_alert", "text": str(_config.get("name", "腐沼蟒皇・薩迦"))})


func _update_alert(delta: float, _events: Array[Dictionary]) -> void:
	_velocity = Vector2.ZERO
	_state_timer -= delta
	if _state_timer <= 0.0:
		_state = State.CHASE if not _target.is_empty() else State.RETURNING
		_decision_timer = 0.0


func _update_chase(delta: float, events: Array[Dictionary]) -> void:
	if _target.is_empty():
		_no_target_timer += delta
		if _no_target_timer >= 3.0:
			_enter_returning(events, "失去目標")
		return
	var target_pos: Vector2 = Vector2(_target["pos"])
	var distance: float = _position.distance_to(target_pos)
	if distance < 118.0:
		_state = State.REPOSITION
		_state_timer = 0.72
		_reposition_side = -1.0 if _rng.randf() < 0.5 else 1.0
	else:
		var arrive: float = clampf((distance - 105.0) / 180.0, 0.20, 1.0)
		_move_head_toward(target_pos, _move_speed * _phase_move_multiplier() * arrive, delta, true)
	if _decision_timer <= 0.0 and _global_skill_gap <= 0.0:
		_decision_timer = 0.10
		var skill_id: String = _choose_skill()
		if skill_id != "":
			_begin_telegraph(skill_id, events, false)


func _update_reposition(delta: float, events: Array[Dictionary]) -> void:
	if _target.is_empty():
		_enter_returning(events, "失去目標")
		return
	_state_timer -= delta
	var to_target: Vector2 = Vector2(_target["pos"]) - _position
	var tangent: Vector2 = Vector2(-to_target.y, to_target.x).normalized() * _reposition_side
	var desired: Vector2 = _position + (tangent + to_target.normalized() * 0.18).normalized() * 180.0
	_move_head_toward(desired, _move_speed * _phase_move_multiplier() * 0.78, delta, true)
	if _decision_timer <= 0.0 and _global_skill_gap <= 0.0:
		_decision_timer = 0.10
		var skill_id: String = _choose_skill()
		if skill_id != "":
			_begin_telegraph(skill_id, events, false)
			return
	if _state_timer <= 0.0:
		_state = State.CHASE


func _move_head_toward(destination: Vector2, speed: float, delta: float, serpentine: bool) -> void:
	var desired: Vector2 = destination - _position
	if desired.length_squared() <= 0.001:
		_velocity = Vector2.ZERO
		return
	desired = desired.normalized()
	if serpentine:
		desired = desired.rotated(sin(_age * 2.4) * 0.14)
	_avoid_timer = maxf(0.0, _avoid_timer - delta)
	var head_radius := float(_body_config.get("head_radius", 40.0))
	var probe_distance := maxf(maxf(96.0, head_radius * 2.7), speed * delta * 8.0)
	var steering := desired
	if _avoid_timer > 0.0 and _avoid_direction.length_squared() > 0.01 and _path_is_clear(_position, _position + _avoid_direction * probe_distance, head_radius):
		steering = _avoid_direction
	elif not _path_is_clear(_position, _position + desired * probe_distance, head_radius):
		var found_detour := false
		# Try the remembered side first and include perpendicular/backward arcs. A
		# head-on tree can block every shallow candidate, which was the old hard-lock.
		for signed_angle in [
			0.62 * _avoid_side, 1.08 * _avoid_side, 1.57 * _avoid_side, 2.05 * _avoid_side,
			-0.62 * _avoid_side, -1.08 * _avoid_side, -1.57 * _avoid_side, -2.05 * _avoid_side,
		]:
			var candidate_direction := desired.rotated(float(signed_angle)).normalized()
			if not _path_is_clear(_position, _position + candidate_direction * probe_distance, head_radius):
				continue
			steering = candidate_direction
			_avoid_direction = candidate_direction
			_avoid_timer = 0.85
			found_detour = true
			break
		if not found_detour:
			_avoid_side *= -1.0
			steering = desired.rotated(_avoid_side * PI * 0.5).normalized()
			_avoid_direction = steering
			_avoid_timer = 0.42
	else:
		_avoid_direction = Vector2.ZERO
	_facing = _turn_toward(_facing, steering, _turn_speed * delta * (1.8 if _avoid_timer > 0.0 else 1.0))
	var old_position: Vector2 = _position
	var proposed: Vector2 = _position + _facing * speed * delta
	if _is_blocked(proposed, head_radius):
		var found := false
		for angle in [0.65 * _avoid_side, -0.65 * _avoid_side, 1.15 * _avoid_side, -1.15 * _avoid_side, 1.57 * _avoid_side, -1.57 * _avoid_side, 2.15 * _avoid_side, -2.15 * _avoid_side]:
			var alternate_dir: Vector2 = _facing.rotated(float(angle))
			var alternate: Vector2 = _position + alternate_dir * speed * delta
			if not _is_blocked(alternate, head_radius):
				_facing = alternate_dir
				proposed = alternate
				_avoid_direction = alternate_dir
				_avoid_timer = maxf(_avoid_timer, 0.65)
				found = true
				break
		if not found:
			proposed = _position
			_blocked_move_frames += 1
			# Saves created by an older build can restore the head inside a trunk.
			# After several rejected frames, search deterministic open endpoints and
			# extract it instead of remaining permanently motionless.
			if _blocked_move_frames >= 8:
				for escape_ring in [head_radius * 2.5, head_radius * 3.5, head_radius * 5.0]:
					for escape_step in 12:
						var escape_angle := desired.angle() + _avoid_side * TAU * float(escape_step) / 12.0
						var escape_candidate := _position + Vector2.from_angle(escape_angle) * float(escape_ring)
						if _is_blocked(escape_candidate, head_radius):
							continue
						proposed = escape_candidate
						_facing = (proposed - _position).normalized()
						_avoid_direction = _facing
						_avoid_timer = 0.9
						found = true
						break
					if found:
						break
	else:
		_blocked_move_frames = 0
	if proposed != _position:
		_blocked_move_frames = 0
	_position = proposed
	_velocity = (_position - old_position) / maxf(delta, 0.0001)
	_append_history_motion(old_position, _position)


func _turn_toward(current: Vector2, desired: Vector2, maximum_angle: float) -> Vector2:
	if desired.length_squared() <= 0.0001:
		return current
	if current.length_squared() <= 0.0001:
		return desired.normalized()
	var angle: float = current.angle_to(desired.normalized())
	return current.normalized().rotated(clampf(angle, -maximum_angle, maximum_angle))


func _is_blocked(position: Vector2, radius: float) -> bool:
	return _position_blocked.is_valid() and bool(_position_blocked.call(position, radius))


func _path_is_clear(from: Vector2, to: Vector2, radius: float) -> bool:
	var distance: float = from.distance_to(to)
	var checks: int = maxi(1, int(ceil(distance / 36.0)))
	for index in range(1, checks + 1):
		if _is_blocked(from.lerp(to, float(index) / float(checks)), radius):
			return false
	return true


func _phase_move_multiplier() -> float:
	if _phase < _phase_config.size():
		return float(Dictionary(_phase_config[_phase]).get("move_speed", 1.0))
	return 1.0


func _phase_attack_multiplier() -> float:
	if _phase < _phase_config.size():
		return float(Dictionary(_phase_config[_phase]).get("attack_speed", 1.0))
	return 1.0


func _phase_cooldown_multiplier() -> float:
	if _phase < _phase_config.size():
		return maxf(0.58, float(Dictionary(_phase_config[_phase]).get("cooldown", 1.0)))
	return 1.0


func _choose_skill() -> String:
	var scored: Array[Dictionary] = []
	for skill_id in SKILL_IDS:
		if _forced_skill != "" and skill_id != _forced_skill:
			continue
		if float(_cooldowns.get(skill_id, 0.0)) > 0.0:
			continue
		if _recent_skills.size() >= 2 and _recent_skills[-1] == skill_id and _recent_skills[-2] == skill_id:
			continue
		var score: float = _score_skill(skill_id)
		if score > 0.0:
			score *= _rng.randf_range(0.90, 1.10)
			scored.append({"id": skill_id, "score": clampf(score, 0.0, 100.0)})
	_forced_skill = ""
	if scored.is_empty():
		return ""
	scored.sort_custom(Callable(self, "_sort_score_desc"))
	if float(scored[0]["score"]) < 20.0:
		return ""
	if scored.size() > 3:
		scored.resize(3)
	var total: float = 0.0
	for entry in scored:
		var weight: float = float(entry["score"])
		total += weight * weight
	var roll: float = _rng.randf_range(0.0, total)
	var cursor: float = 0.0
	for entry in scored:
		var weight: float = float(entry["score"])
		cursor += weight * weight
		if roll <= cursor:
			return str(entry["id"])
	return str(scored[0]["id"])


func _score_skill(skill_id: String) -> float:
	if _target.is_empty():
		return 0.0
	var target_pos: Vector2 = Vector2(_target["pos"])
	var distance: float = _position.distance_to(target_pos)
	var target_speed: float = Vector2(_target.get("vel", Vector2.ZERO)).length()
	var nearby: Array[Dictionary] = _units_in_radius(_position, 330.0)
	var melee_count := 0
	var ranged_count := 0
	var cannon_count := 0
	for unit in nearby:
		var unit_type: String = str(unit["type"])
		if unit_type in ["swordsman", "heavy", "warrior"] or str(unit["kind"]) == "player" and _player_level < 10:
			melee_count += 1
		else:
			ranged_count += 1
		if unit_type == "cannon":
			cannon_count += 1
	var recent_penalty := 0.0
	if not _recent_skills.is_empty() and _recent_skills[-1] == skill_id:
		recent_penalty = 20.0
	match skill_id:
		"constrict":
			var cfg: Dictionary = Dictionary(_skill_config[skill_id])
			var min_range: float = float(cfg.get("min_range", 100.0))
			var max_range: float = float(cfg.get("max_range", 280.0))
			if distance < min_range or distance > max_range or _is_vehicle_type(str(_target["type"])) or _control_lockout > 0.0:
				return 0.0
			if _status_value(_target_key, "control_immunity") > 0.0:
				return 0.0
			if not _path_is_clear(_position, target_pos, float(_body_config.get("head_radius", 40.0)) * 0.55):
				return 0.0
			var band: float = 1.0 - absf(distance - 190.0) / 90.0
			return 15.0 + 30.0 * clampf(band, 0.0, 1.0) + 30.0 / float(maxi(1, nearby.size())) + (10.0 if target_speed < 25.0 else 0.0) + (15.0 if _phase == 1 else 8.0 if _phase == 2 else 0.0) - float(melee_count) * 6.0 - recent_penalty
		"dash":
			var cfg: Dictionary = Dictionary(_skill_config[skill_id])
			if distance < 150.0:
				return 0.0
			var path_dir: Vector2 = (target_pos - _position).normalized()
			if _is_blocked(_position + path_dir * 70.0, float(_body_config.get("head_radius", 40.0))):
				return 0.0
			return 18.0 + clampf(distance / float(cfg.get("max_distance", 520.0)), 0.0, 1.0) * 42.0 + float(ranged_count) * 4.0 + float(cannon_count) * 14.0 - recent_penalty
		"bite":
			var cfg: Dictionary = Dictionary(_skill_config[skill_id])
			var bite_reach := float(cfg.get("range", 135.0)) + float(_target.get("radius", 0.0))
			if distance > bite_reach or _constrict_key == _target_key:
				return 0.0
			var facing_score: float = 1.0 - clampf(absf(_facing.angle_to((target_pos - _position).normalized())) / PI, 0.0, 1.0)
			var poison_stacks: float = _status_value(_target_key, "poison_stacks")
			return 30.0 + 38.0 * (1.0 - distance / maxf(bite_reach, 1.0)) + facing_score * 20.0 - poison_stacks * 7.0 - recent_penalty
		"poison_pool":
			var cfg: Dictionary = Dictionary(_skill_config[skill_id])
			var spawn_count: int = _phase_pool_count()
			if _active_pool_count() + spawn_count > int(cfg.get("max_pools", 6)):
				return 0.0
			return 18.0 + float(nearby.size()) * 5.0 + float(cannon_count) * 16.0 + (10.0 if target_speed < 22.0 else -minf(12.0, target_speed * 0.035)) + (20.0 if _phase == 1 else 15.0 if _phase == 2 else 0.0) - recent_penalty
		"tail_sweep":
			var cfg: Dictionary = Dictionary(_skill_config[skill_id])
			var tail_pivot: Vector2 = _tail_pivot()
			var pivot_distance := tail_pivot.distance_to(target_pos)
			var inner := float(cfg.get("inner_radius", 90.0))
			var outer := float(cfg.get("outer_radius", 280.0)) + float(_target.get("radius", 0.0))
			if pivot_distance < inner or pivot_distance > outer:
				return 0.0
			var close_tail: int = _units_in_radius(tail_pivot, outer).size()
			var target_offset: Vector2 = target_pos - _position
			var target_is_side_or_back := absf(_facing.angle_to(target_offset.normalized())) >= deg_to_rad(70.0)
			if (close_tail < 2 and not target_is_side_or_back) or _control_lockout > 0.0:
				return 0.0
			return 20.0 + float(close_tail) * 14.0 + float(melee_count) * 8.0 + (24.0 if target_is_side_or_back else 0.0) - recent_penalty
	return 0.0


func _status_value(key: String, property: String) -> float:
	if not _unit_statuses.has(key):
		return 0.0
	return float(Dictionary(_unit_statuses[key]).get(property, 0.0))


func _begin_telegraph(skill_id: String, events: Array[Dictionary], secondary_bite: bool) -> void:
	if not _skill_config.has(skill_id):
		return
	_active_skill = skill_id
	_cast_hit_set.clear()
	_second_bite_pending = false
	var cfg: Dictionary = Dictionary(_skill_config[skill_id])
	var target_pos: Vector2 = Vector2(_target.get("pos", _position + _facing * 160.0))
	var target_vel: Vector2 = Vector2(_target.get("vel", Vector2.ZERO))
	var direction: Vector2 = (target_pos - _position).normalized()
	if direction.length_squared() <= 0.001:
		direction = _facing
	var duration: float = float(cfg.get("telegraph", 0.5))
	_telegraph = {
		"skill": skill_id,
		"origin": _position,
		"target_key": _target_key,
		"target_pos": target_pos,
		"direction": direction,
		"duration": duration,
		"remaining": duration,
		"secondary": secondary_bite,
	}
	match skill_id:
		"constrict":
			_telegraph["shape"] = "circle"
			_telegraph["center"] = target_pos
			_telegraph["radius"] = 50.0
		"dash":
			var prediction: float = clampf(_position.distance_to(target_pos) / float(cfg.get("speed", 760.0)), float(cfg.get("prediction_min", 0.35)), float(cfg.get("prediction_max", 0.55)))
			var predicted: Vector2 = target_pos + (target_vel.limit_length(300.0) * prediction).limit_length(150.0)
			direction = (predicted - _position).normalized()
			if direction.length_squared() <= 0.001:
				direction = _facing
			_telegraph["direction"] = direction
			_telegraph["shape"] = "capsule"
			_telegraph["end"] = _position + direction * float(cfg.get("max_distance", 520.0))
			_telegraph["width"] = float(cfg.get("width", 85.0))
		"bite":
			if secondary_bite:
				duration = float(cfg.get("second_telegraph", 0.35))
				direction = direction.rotated(-0.52)
				_telegraph["duration"] = duration
				_telegraph["remaining"] = duration
				_telegraph["direction"] = direction
			_telegraph["shape"] = "sector"
			_telegraph["range"] = float(cfg.get("range", 135.0))
			_telegraph["angle"] = deg_to_rad(float(cfg.get("angle_degrees", 70.0)))
		"poison_pool":
			_telegraph["shape"] = "multi_circle"
			_telegraph["destinations"] = _choose_pool_destinations(_phase_pool_count())
			_telegraph["radius"] = float(cfg.get("radius", 95.0))
		"tail_sweep":
			var angles: Array = Array(cfg.get("angles", [210.0, 240.0, 270.0]))
			var phase_index: int = clampi(_phase, 0, angles.size() - 1)
			var pivot: Vector2 = _tail_pivot()
			var outer_radius: float = float(cfg.get("outer_radius", 280.0))
			var tail_arc: float = deg_to_rad(float(angles[phase_index]))
			# Start at the physical tail direction, then sweep through the announced
			# arc so the visible tail and the damaging sector stay aligned.
			var preliminary_start: float = (_tail_position() - pivot).angle()
			var blocked_samples := 0
			for fraction in [0.12, 0.50, 0.88]:
				var probe_angle := preliminary_start + tail_arc * float(fraction)
				if _is_blocked(pivot + Vector2.from_angle(probe_angle) * outer_radius * 0.72, 22.0):
					blocked_samples += 1
			if blocked_samples >= 2:
				tail_arc *= 0.82
			_telegraph["shape"] = "annular_sector"
			_telegraph["pivot"] = pivot
			_telegraph["inner_radius"] = float(cfg.get("inner_radius", 90.0))
			_telegraph["outer_radius"] = outer_radius
			_telegraph["arc"] = tail_arc
			_telegraph["start_angle"] = (_tail_position() - _tail_pivot()).angle()
	_state = State.TELEGRAPH
	_state_timer = duration
	_velocity = Vector2.ZERO
	events.append({"type": "telegraph", "skill": skill_id, "data": _telegraph.duplicate(true)})
	events.append({"type": "audio", "kind": skill_id})


func _update_telegraph(delta: float, events: Array[Dictionary]) -> void:
	_velocity = Vector2.ZERO
	_state_timer -= delta
	_telegraph["remaining"] = maxf(0.0, _state_timer)
	if _state_timer > 0.0:
		return
	_state = State.CASTING
	_cast_elapsed = 0.0
	_cast_hit_set.clear()
	_dash_distance = 0.0
	_dash_trail_distance = 0.0
	_tail_previous_angle = float(_telegraph.get("start_angle", 0.0))
	var cfg: Dictionary = Dictionary(_skill_config[_active_skill])
	match _active_skill:
		"constrict":
			_cast_timer = float(cfg.get("max_range", 280.0)) / float(cfg.get("lunge_speed", 520.0)) + float(cfg.get("duration", 2.7))
		"dash":
			_cast_timer = float(cfg.get("max_distance", 520.0)) / float(cfg.get("speed", 760.0))
		"bite":
			_cast_timer = 0.10
		"poison_pool":
			_cast_timer = float(cfg.get("projectile_flight", 0.62))
		"tail_sweep":
			_cast_timer = float(cfg.get("sweep_duration", 0.46)) / _phase_attack_multiplier()
	events.append({"type": "effect", "kind": "%s_cast" % _active_skill, "position": _position})


func _update_casting(delta: float, events: Array[Dictionary]) -> void:
	_cast_elapsed += delta
	_cast_timer -= delta
	match _active_skill:
		"constrict":
			_update_constrict_cast(delta, events)
		"dash":
			_update_dash_cast(delta, events)
		"bite":
			_update_bite_cast(events)
		"poison_pool":
			_update_pool_cast(events)
		"tail_sweep":
			_update_tail_cast(events)
	if _state != State.CASTING:
		return
	if _cast_timer <= 0.0:
		_finish_cast(events)


func _update_bite_cast(events: Array[Dictionary]) -> void:
	if _cast_hit_set.has("bite_resolved"):
		return
	_cast_hit_set["bite_resolved"] = true
	var cfg: Dictionary = Dictionary(_skill_config["bite"])
	var origin: Vector2 = Vector2(_telegraph.get("origin", _position))
	var direction: Vector2 = Vector2(_telegraph.get("direction", _facing))
	var attack_range: float = float(cfg.get("range", 135.0))
	var half_angle: float = deg_to_rad(float(cfg.get("angle_degrees", 70.0))) * 0.5
	var secondary: bool = bool(_telegraph.get("secondary", false))
	var damage_multiplier: float = float(cfg.get("second_damage_multiplier", 0.75)) if secondary else float(cfg.get("damage_multiplier", 1.0))
	for unit in _units_in_radius(origin, attack_range + 30.0):
		if not _unit_is_attackable(unit):
			continue
		var offset: Vector2 = Vector2(unit["pos"]) - origin
		if offset.length() > attack_range + float(unit["radius"]) or absf(direction.angle_to(offset.normalized())) > half_angle:
			continue
		var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
		if _cast_hit_set.has(key):
			continue
		_cast_hit_set[key] = true
		events.append(_damage_event("bite_secondary" if secondary else "bite", key, _damage * damage_multiplier, origin))
		_apply_poison_status(key, cfg)
	if not secondary and _phase == 2 and _rng.randf() <= float(cfg.get("second_bite_chance", 0.62)) and _constrict_key != _target_key:
		_second_bite_pending = true
	events.append({"type": "audio", "kind": "bite"})
	events.append({"type": "effect", "kind": "bite", "position": origin, "direction": direction})


func _apply_poison_status(key: String, cfg: Dictionary) -> void:
	var status: Dictionary = _status_for(key)
	status["poison_stacks"] = mini(int(cfg.get("poison_max_stacks", 3)), int(status.get("poison_stacks", 0)) + 1)
	status["poison_ttl"] = float(cfg.get("poison_duration", 7.0))
	status["poison_tick"] = minf(float(status.get("poison_tick", 1.0)), 1.0)
	status["poison_sequence"] = int(status.get("poison_sequence", 0))
	_unit_statuses[key] = status


func _update_dash_cast(delta: float, events: Array[Dictionary]) -> void:
	var cfg: Dictionary = Dictionary(_skill_config["dash"])
	var direction: Vector2 = Vector2(_telegraph.get("direction", _facing)).normalized()
	var speed: float = float(cfg.get("speed", 760.0))
	var remaining_distance: float = minf(speed * delta, float(cfg.get("max_distance", 520.0)) - _dash_distance)
	var substep: float = float(_performance_config.get("dash_substep", 18.0))
	while remaining_distance > 0.001:
		var distance_step: float = minf(substep, remaining_distance)
		var from: Vector2 = _position
		var to: Vector2 = from + direction * distance_step
		if _is_blocked(to, float(_body_config.get("head_radius", 40.0))):
			_enter_stunned(float(cfg.get("wall_stun", 1.8)), events)
			events.append({"type": "audio", "kind": "impact"})
			events.append({"type": "effect", "kind": "wall_impact", "position": from})
			return
		_position = to
		_facing = direction
		_velocity = direction * speed
		_append_history_motion(from, to)
		_dash_distance += distance_step
		_dash_trail_distance += distance_step
		_dash_hit_units(from, to, events)
		if _phase == 2 and _dash_trail_distance >= 42.0:
			_dash_trail_distance = 0.0
			_spawn_pool(from, 17.0, float(cfg.get("phase_three_trail_duration", 2.5)), _damage * 0.035, 0.10, "trail")
		remaining_distance -= distance_step
	if _dash_distance >= float(cfg.get("max_distance", 520.0)) - 0.1:
		_cast_timer = 0.0


func _dash_hit_units(from: Vector2, to: Vector2, events: Array[Dictionary]) -> void:
	var cfg: Dictionary = Dictionary(_skill_config["dash"])
	var width: float = float(cfg.get("width", 85.0)) * 0.5
	var center: Vector2 = (from + to) * 0.5
	for unit in _units_in_radius(center, from.distance_to(to) * 0.5 + width + 30.0):
		if not _unit_is_attackable(unit):
			continue
		var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
		if _cast_hit_set.has(key):
			continue
		if _distance_point_segment(Vector2(unit["pos"]), from, to) > width + float(unit["radius"]):
			continue
		_cast_hit_set[key] = true
		events.append(_damage_event("dash", key, _damage * float(cfg.get("damage_multiplier", 1.35)), to))
		var push: Vector2 = (Vector2(unit["pos"]) - to).normalized() * float(cfg.get("knockback", 110.0))
		events.append({"type": "knockback", "target": key, "vector": push, "kind": "dash"})


func _update_constrict_cast(delta: float, events: Array[Dictionary]) -> void:
	var cfg: Dictionary = Dictionary(_skill_config["constrict"])
	var lunge_duration: float = float(cfg.get("max_range", 280.0)) / float(cfg.get("lunge_speed", 520.0))
	if _constrict_key == "" and _cast_elapsed <= lunge_duration:
		var from: Vector2 = _position
		var direction: Vector2 = Vector2(_telegraph.get("direction", _facing)).normalized()
		var to: Vector2 = from + direction * float(cfg.get("lunge_speed", 520.0)) * delta
		if not _is_blocked(to, float(_body_config.get("head_radius", 40.0))):
			_position = to
			_facing = direction
			_append_history_motion(from, to)
		var intended: String = str(_telegraph.get("target_key", ""))
		for unit in _units_in_radius(_position, float(_body_config.get("head_radius", 40.0)) + 34.0):
			if not _unit_is_attackable(unit):
				continue
			var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
			if key != intended or _is_vehicle_type(str(unit["type"])) or _status_value(key, "control_immunity") > 0.0:
				continue
			_start_constrict(key, unit, cfg, events)
			break
	if _constrict_key != "":
		_constrict_timer = maxf(0.0, _constrict_timer - delta)
		_constrict_tick_timer -= delta
		var anchor_radius := 18.0
		if _units_by_key.has(_constrict_key):
			anchor_radius = float(Dictionary(_units_by_key[_constrict_key]).get("radius", 18.0))
		var anchor_candidates := [
			_position + _facing.rotated(PI * 0.5) * 34.0,
			_position + _facing.rotated(-PI * 0.5) * 34.0,
			_position - _facing * 42.0,
		]
		var anchor_found := false
		for anchor_candidate in anchor_candidates:
			if not _is_blocked(Vector2(anchor_candidate), anchor_radius):
				_constrict_anchor = Vector2(anchor_candidate)
				anchor_found = true
				break
		if not anchor_found:
			_release_constrict(events, "地形中斷")
			_cast_timer = 0.0
			return
		events.append({"type": "anchor", "target": _constrict_key, "position": _constrict_anchor})
		while _constrict_tick_timer <= 0.0 and _constrict_timer > 0.0:
			_constrict_tick_timer += float(cfg.get("damage_tick", 0.6))
			var target_unit: Dictionary = Dictionary(_units_by_key.get(_constrict_key, {}))
			var heavy_scale: float = 0.80 if str(target_unit.get("type", "")) == "heavy" else 1.0
			events.append(_damage_event("constrict", _constrict_key, _damage * float(cfg.get("damage_multiplier", 0.35)) * heavy_scale, _position))
		if _constrict_timer <= 0.0:
			_release_constrict(events, "時間結束")
			_cast_timer = 0.0
	elif _cast_elapsed >= lunge_duration:
		_cast_timer = 0.0


func _start_constrict(key: String, unit: Dictionary, cfg: Dictionary, events: Array[Dictionary]) -> void:
	_constrict_key = key
	_constrict_timer = float(cfg.get("duration", 2.7))
	_constrict_tick_timer = float(cfg.get("damage_tick", 0.6))
	_constrict_break_gauge = float(cfg.get("break_gauge", 210.0)) * (1.30 if str(unit["type"]) == "heavy" else 1.0)
	var status: Dictionary = _status_for(key)
	status["constricted"] = _constrict_timer
	status["break_gauge"] = _constrict_break_gauge
	_unit_statuses[key] = status
	var heavy_scale: float = 0.80 if str(unit.get("type", "")) == "heavy" else 1.0
	# Landing the lunge now always has an immediate, visible damage result. The
	# later half-second ticks remain escapable through break clicks or ally hits.
	events.append(_damage_event("constrict_impact", key, _damage * float(cfg.get("initial_damage_multiplier", 0.65)) * heavy_scale, _position))
	events.append({"type": "effect", "kind": "constrict_hit", "position": Vector2(unit.get("pos", _position))})
	events.append({"type": "status", "kind": "constrict_start", "target": key, "duration": _constrict_timer, "break_gauge": _constrict_break_gauge})
	events.append({"type": "audio", "kind": "constrict"})


func _validate_constrict_target(events: Array[Dictionary]) -> void:
	if _constrict_key == "":
		return
	if not _units_by_key.has(_constrict_key):
		_release_constrict(events, "目標失效")
		return
	var unit: Dictionary = Dictionary(_units_by_key[_constrict_key])
	if _position.distance_to(Vector2(unit["pos"])) > 190.0 or _state in [State.STUNNED, State.RETURNING, State.DEAD]:
		_release_constrict(events, "纏繞中斷")


func _release_constrict(events: Array[Dictionary], reason: String) -> void:
	if _constrict_key == "":
		return
	var released_key: String = _constrict_key
	var cfg: Dictionary = Dictionary(_skill_config.get("constrict", {}))
	var status: Dictionary = _status_for(released_key)
	status["constricted"] = 0.0
	status["break_gauge"] = 0.0
	status["control_immunity"] = float(cfg.get("control_immunity", 5.0))
	_unit_statuses[released_key] = status
	if reason != "蟒皇死亡" and _units_by_key.has(released_key):
		var released_unit: Dictionary = Dictionary(_units_by_key[released_key])
		var release_direction: Vector2 = (Vector2(released_unit["pos"]) - _position).normalized()
		if release_direction.length_squared() <= 0.001:
			release_direction = -_facing
		events.append({
			"type": "knockback", "target": released_key,
			"vector": release_direction * float(cfg.get("release_knockback", 80.0)),
			"kind": "constrict_release",
		})
	_constrict_key = ""
	_constrict_timer = 0.0
	_constrict_tick_timer = 0.0
	_constrict_break_gauge = 0.0
	events.append({"type": "status", "kind": "constrict_end", "target": released_key, "reason": reason, "immunity": float(cfg.get("control_immunity", 5.0))})


func register_break_click(attack_power: float = 32.0) -> void:
	if _constrict_key == "":
		return
	var cfg: Dictionary = Dictionary(_skill_config.get("constrict", {}))
	var break_power: float = maxf(18.0, attack_power * float(cfg.get("click_power_multiplier", 1.10)))
	_constrict_break_gauge = maxf(0.0, _constrict_break_gauge - break_power)
	var status: Dictionary = _status_for(_constrict_key)
	status["break_gauge"] = _constrict_break_gauge
	_unit_statuses[_constrict_key] = status
	if _constrict_break_gauge <= 0.0:
		_release_constrict(_queued_events, "掙脫成功")


func damage_constrict_coils(amount: float) -> void:
	if _constrict_key == "":
		return
	_constrict_break_gauge = maxf(0.0, _constrict_break_gauge - maxf(4.0, amount * 0.5))
	if _constrict_break_gauge <= 0.0:
		_release_constrict(_queued_events, "友軍救援")


func _update_pool_cast(events: Array[Dictionary]) -> void:
	if _cast_hit_set.has("pool_spawned"):
		return
	_cast_hit_set["pool_spawned"] = true
	var destinations: Array = Array(_telegraph.get("destinations", []))
	var cfg: Dictionary = Dictionary(_skill_config["poison_pool"])
	for destination_value in destinations:
		_spawn_glob(Vector2(destination_value), cfg)
	events.append({"type": "audio", "kind": "poison"})
	events.append({"type": "effect", "kind": "poison_launch", "position": _position, "count": destinations.size()})


func _choose_pool_destinations(count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var candidates: Array[Vector2] = []
	if not _target.is_empty():
		var predicted_target := Vector2(_target["pos"]) + (Vector2(_target.get("vel", Vector2.ZERO)).limit_length(260.0) * 0.45).limit_length(110.0)
		candidates.append(predicted_target)
		# The first pool truthfully threatens the locked prediction point. The
		# remaining pools preserve an outward escape corridor, so a stationary
		# target is hit while a reacting player still has a clear dodge route.
		if _is_valid_pool_point(predicted_target):
			result.append(predicted_target)
	var all_units: Array[Dictionary] = _units_in_radius(_position, float(_base.get("arena_radius", 850.0)))
	var soldier_sum := Vector2.ZERO
	var soldier_count := 0
	for unit in all_units:
		if str(unit["kind"]) == "soldier":
			soldier_sum += Vector2(unit["pos"])
			soldier_count += 1
		if str(unit["type"]) == "cannon":
			candidates.append(Vector2(unit["pos"]))
	if soldier_count > 0:
		candidates.append(soldier_sum / float(soldier_count))
	for index in count * 3:
		var base_pos: Vector2 = candidates[index % candidates.size()] if not candidates.is_empty() else _position + Vector2.from_angle(float(index) * 2.399) * 210.0
		var angle: float = float(index) * 2.399 + _rng.randf_range(-0.28, 0.28)
		var candidate: Vector2 = base_pos + Vector2.from_angle(angle) * (34.0 + float(index % 3) * 42.0)
		if _is_valid_pool_point(candidate) and not _blocks_escape_corridor(candidate) and not _point_overlaps_destinations(candidate, result, 105.0):
			result.append(candidate)
			if result.size() >= count:
				break
	var fallback_attempt := 0
	while result.size() < count and fallback_attempt < count * 16:
		var fallback_angle := TAU * float(fallback_attempt) / float(maxi(count * 4, 1)) + 0.31
		var fallback: Vector2 = _position + Vector2.from_angle(fallback_angle) * (220.0 + float(fallback_attempt % 3) * 72.0)
		if _is_valid_pool_point(fallback) and not _blocks_escape_corridor(fallback) and not _point_overlaps_destinations(fallback, result, 105.0):
			result.append(fallback)
		fallback_attempt += 1
	return result


func _point_overlaps_destinations(point: Vector2, destinations: Array[Vector2], minimum: float) -> bool:
	for destination in destinations:
		if destination.distance_to(point) < minimum:
			return true
	return false


func _blocks_escape_corridor(point: Vector2) -> bool:
	if _target.is_empty():
		return false
	var target_pos: Vector2 = Vector2(_target.get("pos", _position))
	var outward: Vector2 = (target_pos - _position).normalized()
	if outward.length_squared() <= 0.001:
		outward = _facing.rotated(PI * 0.5)
	var corridor_end: Vector2 = target_pos + outward * 360.0
	return _distance_point_segment(point, target_pos, corridor_end) < 125.0


func _is_valid_pool_point(point: Vector2) -> bool:
	if _is_blocked(point, 34.0):
		return false
	for zone_value in _safe_zones:
		if not zone_value is Dictionary:
			continue
		var zone: Dictionary = Dictionary(zone_value)
		if point.distance_to(Vector2(zone.get("pos", Vector2.ZERO))) <= float(zone.get("radius", 0.0)) + 30.0:
			return false
	return _home.distance_to(point) <= float(_base.get("arena_radius", 850.0))


func _spawn_glob(destination: Vector2, cfg: Dictionary) -> void:
	var slot_index: int = _acquire_glob_slot()
	if slot_index < 0:
		return
	var flight: float = float(cfg.get("projectile_flight", 0.62))
	_glob_slots[slot_index] = {
		"slot": slot_index,
		"active": true,
		"start": _position,
		"pos": _position,
		"destination": destination,
		"age": 0.0,
		"flight": flight,
		"radius": float(cfg.get("radius", 95.0)),
	}


func _acquire_glob_slot() -> int:
	for index in _glob_slots.size():
		if not bool(_glob_slots[index].get("active", false)):
			return index
	return -1


func _update_poison_globs(delta: float, events: Array[Dictionary]) -> void:
	for index in _glob_slots.size():
		var glob: Dictionary = _glob_slots[index]
		if not bool(glob.get("active", false)):
			continue
		glob["age"] = float(glob["age"]) + delta
		var progress: float = clampf(float(glob["age"]) / maxf(float(glob["flight"]), 0.01), 0.0, 1.0)
		glob["pos"] = Vector2(glob["start"]).lerp(Vector2(glob["destination"]), progress)
		_glob_slots[index] = glob
		if progress < 1.0:
			continue
		var destination: Vector2 = Vector2(glob["destination"])
		var cfg: Dictionary = Dictionary(_skill_config["poison_pool"])
		for unit in _units_in_radius(destination, float(glob["radius"])):
			if not _unit_is_attackable(unit):
				continue
			var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
			events.append(_damage_event("poison_impact", key, _damage * float(cfg.get("impact_damage_multiplier", 0.45)), destination))
		_spawn_or_merge_pool(destination, float(glob["radius"]), _phase_pool_duration(), _damage * float(cfg.get("tick_damage_multiplier", 0.09)), float(cfg.get("slow", 0.25)), "pool")
		events.append({"type": "effect", "kind": "poison_impact", "position": destination})
		events.append({"type": "audio", "kind": "poison"})
		_glob_slots[index] = {"slot": index, "active": false}


func _phase_pool_count() -> int:
	if _phase < _phase_config.size():
		return int(Dictionary(_phase_config[_phase]).get("pool_count", 2))
	return 2


func _phase_pool_duration() -> float:
	var cfg: Dictionary = Dictionary(_skill_config["poison_pool"])
	if _phase == 0:
		return float(cfg.get("duration_phase_one", 5.0))
	if _phase == 1:
		return float(cfg.get("duration_phase_two", 7.0))
	return float(cfg.get("duration_phase_three", 8.0))


func _spawn_pool(position: Vector2, radius: float, duration: float, damage: float, slow: float, kind: String) -> void:
	_spawn_or_merge_pool(position, radius, duration, damage, slow, kind)


func _spawn_or_merge_pool(position: Vector2, radius: float, duration: float, damage: float, slow: float, kind: String) -> void:
	var cfg: Dictionary = Dictionary(_skill_config["poison_pool"])
	var merge_distance: float = radius * 1.5
	for index in _pool_slots.size():
		var existing: Dictionary = _pool_slots[index]
		if not bool(existing.get("active", false)) or str(existing.get("kind", "pool")) != kind:
			continue
		if Vector2(existing["pos"]).distance_to(position) <= merge_distance:
			existing["pos"] = Vector2(existing["pos"]).lerp(position, 0.35)
			existing["radius"] = minf(float(cfg.get("radius", 95.0)) * float(cfg.get("merge_radius_multiplier", 1.30)), maxf(float(existing["radius"]), radius) * 1.08)
			existing["ttl"] = maxf(float(existing["ttl"]), duration)
			existing["duration"] = maxf(float(existing["duration"]), duration)
			existing["damage"] = maxf(float(existing["damage"]), damage)
			existing["slow"] = maxf(float(existing["slow"]), slow)
			_pool_slots[index] = existing
			return
	var slot_index: int = _acquire_pool_slot()
	if slot_index < 0:
		return
	_pool_slots[slot_index] = {
		"slot": slot_index,
		"active": true,
		"kind": kind,
		"pos": position,
		"radius": radius,
		"ttl": duration,
		"duration": duration,
		"tick": 0.5,
		"sequence": 0,
		"damage": damage,
		"slow": slow,
	}


func _acquire_pool_slot() -> int:
	for index in _pool_slots.size():
		if not bool(_pool_slots[index].get("active", false)):
			return index
	return -1


func _active_pool_count() -> int:
	var count := 0
	for pool in _pool_slots:
		if bool(pool.get("active", false)) and str(pool.get("kind", "pool")) == "pool":
			count += 1
	return count


func _update_poison_pools(delta: float, events: Array[Dictionary]) -> void:
	_bubble_audio_timer = maxf(0.0, _bubble_audio_timer - delta)
	var has_active_pool := false
	for index in _pool_slots.size():
		var pool: Dictionary = _pool_slots[index]
		if not bool(pool.get("active", false)):
			continue
		has_active_pool = true
		var ttl_before: float = maxf(0.0, float(pool["ttl"]))
		var active_delta: float = minf(delta, ttl_before)
		pool["tick"] = float(pool["tick"]) - active_delta
		while float(pool["tick"]) <= 0.0 and ttl_before > 0.0:
			pool["tick"] = float(pool["tick"]) + 0.5
			pool["sequence"] = int(pool["sequence"]) + 1
			for unit in _units_in_radius(Vector2(pool["pos"]), float(pool["radius"])):
				if not _unit_is_attackable(unit):
					continue
				var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
				events.append(_damage_event("%s_tick_%d" % [str(pool["kind"]), int(pool["sequence"])], key, float(pool["damage"]), Vector2(pool["pos"])))
				var status: Dictionary = _status_for(key)
				status["pool_slow"] = maxf(float(status.get("pool_slow", 0.0)), float(pool["slow"]))
				status["pool_slow_ttl"] = 0.65
				_unit_statuses[key] = status
		pool["ttl"] = maxf(0.0, ttl_before - delta)
		if float(pool["ttl"]) <= 0.0:
			_pool_slots[index] = {"slot": index, "active": false}
		else:
			_pool_slots[index] = pool
	if has_active_pool and _bubble_audio_timer <= 0.0:
		_bubble_audio_timer = 1.15
		events.append({"type": "audio", "kind": "bubble"})


func _update_tail_cast(events: Array[Dictionary]) -> void:
	var cfg: Dictionary = Dictionary(_skill_config["tail_sweep"])
	var duration: float = float(cfg.get("sweep_duration", 0.46)) / _phase_attack_multiplier()
	var progress: float = clampf(_cast_elapsed / maxf(duration, 0.01), 0.0, 1.0)
	var start_angle: float = float(_telegraph.get("start_angle", 0.0))
	var arc: float = float(_telegraph.get("arc", deg_to_rad(210.0)))
	var current_angle: float = start_angle + arc * progress
	var pivot: Vector2 = Vector2(_telegraph.get("pivot", _tail_pivot()))
	var inner: float = float(cfg.get("inner_radius", 90.0))
	var outer: float = float(cfg.get("outer_radius", 280.0))
	for unit in _units_in_radius(pivot, outer + 35.0):
		if not _unit_is_attackable(unit):
			continue
		var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
		if _cast_hit_set.has(key):
			continue
		var offset: Vector2 = Vector2(unit["pos"]) - pivot
		var distance: float = offset.length()
		if distance < inner or distance > outer + float(unit["radius"]):
			continue
		if not _path_is_clear(pivot, Vector2(unit["pos"]), minf(18.0, float(unit["radius"]))):
			continue
		if not _angle_between_sweep(offset.angle(), _tail_previous_angle, current_angle):
			continue
		_cast_hit_set[key] = true
		events.append(_damage_event("tail_sweep", key, _damage * float(cfg.get("damage_multiplier", 1.20)), pivot))
		var knock_scale: float = 0.45 if str(unit["type"]) == "heavy" else 1.0
		events.append({"type": "knockback", "target": key, "vector": offset.normalized() * float(cfg.get("knockback", 150.0)) * knock_scale, "kind": "tail_sweep"})
		var status: Dictionary = _status_for(key)
		status["off_balance"] = float(cfg.get("off_balance", 0.35))
		_unit_statuses[key] = status
	_tail_previous_angle = current_angle
	events.append({"type": "tail_progress", "pivot": pivot, "angle": current_angle})


func _angle_between_sweep(angle: float, previous: float, current: float) -> bool:
	var width := 0.10
	var relative: float = wrapf(angle - previous, -PI, PI)
	var sweep_delta: float = wrapf(current - previous, -PI, PI)
	if sweep_delta >= 0.0:
		return relative >= -width and relative <= sweep_delta + width
	return relative <= width and relative >= sweep_delta - width


func _finish_cast(events: Array[Dictionary]) -> void:
	if _active_skill == "bite" and _second_bite_pending and not bool(_telegraph.get("secondary", false)):
		_second_bite_pending = false
		_begin_telegraph("bite", events, true)
		return
	if _active_skill == "dash" and _phase >= 1:
		var cfg: Dictionary = Dictionary(_skill_config["poison_pool"])
		_spawn_pool(_position, 60.0, 2.0, _damage * 0.05, float(cfg.get("slow", 0.25)) * 0.6, "splash")
	var cfg: Dictionary = Dictionary(_skill_config.get(_active_skill, {}))
	_recovery_timer = float(cfg.get("recovery", 0.8)) / _phase_attack_multiplier()
	_cooldowns[_active_skill] = float(cfg.get("cooldown", 8.0)) * _phase_cooldown_multiplier()
	_global_skill_gap = _rng.randf_range(float(_base.get("global_skill_gap_min", 0.6)), float(_base.get("global_skill_gap_max", 1.0)))
	_recent_skills.append(_active_skill)
	while _recent_skills.size() > 3:
		_recent_skills.pop_front()
	if _active_skill in ["constrict", "tail_sweep"]:
		_control_lockout = 1.5
	_state = State.RECOVERY
	_velocity = Vector2.ZERO
	events.append({"type": "recovery", "skill": _active_skill, "duration": _recovery_timer})


func _update_recovery(delta: float, events: Array[Dictionary]) -> void:
	_velocity = Vector2.ZERO
	_recovery_timer -= delta
	if _recovery_timer > 0.0:
		return
	_active_skill = ""
	_telegraph.clear()
	_cast_hit_set.clear()
	if _pending_phase > _phase:
		_enter_phase_change(events)
	elif _target.is_empty():
		_enter_returning(events, "戰鬥結束")
	else:
		_state = State.CHASE


func _enter_stunned(duration: float, events: Array[Dictionary]) -> void:
	_release_constrict(events, "蟒皇暈眩")
	var interrupted_skill := _active_skill
	if interrupted_skill != "" and _skill_config.has(interrupted_skill):
		var interrupted_cfg: Dictionary = Dictionary(_skill_config[interrupted_skill])
		_cooldowns[interrupted_skill] = float(interrupted_cfg.get("cooldown", 8.0)) * _phase_cooldown_multiplier()
		_global_skill_gap = maxf(_global_skill_gap, float(_base.get("global_skill_gap_min", 0.6)))
		_recent_skills.append(interrupted_skill)
		while _recent_skills.size() > 3:
			_recent_skills.pop_front()
	_state = State.STUNNED
	_stun_timer = duration
	_state_timer = duration
	_active_skill = ""
	_telegraph.clear()
	_velocity = Vector2.ZERO
	events.append({"type": "status", "kind": "boss_stunned", "duration": duration})
	events.append({"type": "audio", "kind": "stun"})


func _update_stunned(delta: float, _events: Array[Dictionary]) -> void:
	_stun_timer = maxf(0.0, _stun_timer - delta)
	_state_timer = _stun_timer
	if _stun_timer <= 0.0:
		_state = State.RECOVERY
		_recovery_timer = 0.60


func _enter_returning(events: Array[Dictionary], reason: String) -> void:
	_release_constrict(events, "蟒皇返回巢穴")
	_state = State.RETURNING
	_active_skill = ""
	_telegraph.clear()
	_cast_hit_set.clear()
	_target.clear()
	_target_key = ""
	_velocity = Vector2.ZERO
	events.append({"type": "notice", "kind": "boss_returning", "text": "正在返回巢穴", "reason": reason})


func _update_returning(delta: float, _events: Array[Dictionary]) -> void:
	var distance: float = _position.distance_to(_home)
	if distance > 10.0:
		_move_head_toward(_home, _move_speed * 1.20, delta, false)
		return
	_position = _home
	_velocity = Vector2.ZERO
	_hp = minf(_max_hp, _hp + _max_hp * float(_base.get("return_heal_per_second", 0.05)) * delta)
	if _hp >= _max_hp - 0.5:
		_hp = _max_hp
		_state = State.IDLE
		_target.clear()
		_target_key = ""
		_threat.clear()


func _phase_for_hp() -> int:
	var ratio: float = _hp / maxf(_max_hp, 1.0)
	var phase_two_threshold := 0.70
	var phase_three_threshold := 0.35
	if _phase_config.size() >= 1:
		phase_two_threshold = float(Dictionary(_phase_config[0]).get("threshold", phase_two_threshold))
	if _phase_config.size() >= 2:
		phase_three_threshold = float(Dictionary(_phase_config[1]).get("threshold", phase_three_threshold))
	if ratio < phase_three_threshold:
		return 2
	if ratio <= phase_two_threshold:
		return 1
	return 0


func _enter_phase_change(events: Array[Dictionary]) -> void:
	_phase = maxi(_phase, _pending_phase)
	_pending_phase = -1
	_state = State.PHASE_CHANGE
	_state_timer = float(Dictionary(_config.get("phase_change", {})).get("duration", 1.0))
	_phase_wave_fired = false
	_velocity = Vector2.ZERO
	events.append({"type": "phase", "phase": _phase + 1, "name": _phase_name()})
	events.append({"type": "audio", "kind": "phase"})
	events.append({"type": "notice", "kind": "phase_change", "text": "蟒皇進入狂暴狀態" if _phase == 2 else "腐毒正在蔓延"})


func _update_phase_change(delta: float, events: Array[Dictionary]) -> void:
	_state_timer -= delta
	var phase_cfg: Dictionary = Dictionary(_config.get("phase_change", {}))
	var duration: float = float(phase_cfg.get("duration", 1.0))
	if not _phase_wave_fired and _state_timer <= duration * 0.65:
		_phase_wave_fired = true
		var radius: float = float(phase_cfg.get("knockback_radius", 230.0))
		for unit in _units_in_radius(_position, radius):
			if not _unit_is_attackable(unit):
				continue
			var key: String = _unit_key(str(unit["kind"]), int(unit["id"]))
			events.append(_damage_event("phase_wave", key, _damage * float(phase_cfg.get("damage_multiplier", 0.38)), _position))
			var push: Vector2 = (Vector2(unit["pos"]) - _position).normalized() * float(phase_cfg.get("knockback_distance", 72.0))
			events.append({"type": "knockback", "target": key, "vector": push, "kind": "phase_wave"})
		events.append({"type": "effect", "kind": "phase_wave", "position": _position, "radius": radius})
	if _state_timer <= 0.0:
		_state = State.CHASE if not _target.is_empty() else State.RETURNING


func _phase_name() -> String:
	if _phase < _phase_config.size():
		return str(Dictionary(_phase_config[_phase]).get("name", ""))
	return ""


func _tick_unit_statuses(delta: float, events: Array[Dictionary]) -> void:
	var remove_keys: Array = []
	for key_value in _unit_statuses.keys():
		var key: String = str(key_value)
		var status: Dictionary = Dictionary(_unit_statuses[key])
		status["control_immunity"] = maxf(0.0, float(status.get("control_immunity", 0.0)) - delta)
		status["off_balance"] = maxf(0.0, float(status.get("off_balance", 0.0)) - delta)
		status["pool_slow_ttl"] = maxf(0.0, float(status.get("pool_slow_ttl", 0.0)) - delta)
		if float(status["pool_slow_ttl"]) <= 0.0:
			status["pool_slow"] = 0.0
		if int(status.get("poison_stacks", 0)) > 0:
			var decay_scale: float = 2.0 if _unit_is_near_safe_zone(key) else 1.0
			var ttl_before: float = maxf(0.0, float(status.get("poison_ttl", 0.0)))
			var active_delta: float = minf(delta, ttl_before / maxf(decay_scale, 0.001))
			status["poison_tick"] = float(status.get("poison_tick", 1.0)) - active_delta
			while float(status["poison_tick"]) <= 0.0 and ttl_before > 0.0:
				status["poison_tick"] = float(status["poison_tick"]) + 1.0
				status["poison_sequence"] = int(status.get("poison_sequence", 0)) + 1
				var bite_cfg: Dictionary = Dictionary(_skill_config.get("bite", {}))
				var amount: float = _damage * float(bite_cfg.get("poison_damage_per_second", 0.05)) * float(status["poison_stacks"])
				events.append(_damage_event("poison_%d" % int(status["poison_sequence"]), key, amount, _position))
			status["poison_ttl"] = maxf(0.0, ttl_before - delta * decay_scale)
			if float(status["poison_ttl"]) <= 0.0:
				status["poison_stacks"] = 0
		if int(status.get("poison_stacks", 0)) <= 0 and float(status.get("control_immunity", 0.0)) <= 0.0 and float(status.get("off_balance", 0.0)) <= 0.0 and float(status.get("pool_slow_ttl", 0.0)) <= 0.0 and float(status.get("constricted", 0.0)) <= 0.0:
			remove_keys.append(key)
		else:
			_unit_statuses[key] = status
	for key in remove_keys:
		_unit_statuses.erase(key)


func _unit_is_near_safe_zone(key: String) -> bool:
	if not _units_by_key.has(key):
		return false
	var position: Vector2 = Vector2(Dictionary(_units_by_key[key])["pos"])
	for zone_value in _safe_zones:
		if zone_value is Dictionary:
			var zone: Dictionary = Dictionary(zone_value)
			if position.distance_to(Vector2(zone.get("pos", Vector2.ZERO))) <= float(zone.get("radius", 0.0)):
				return true
	return false


func _status_for(key: String) -> Dictionary:
	return Dictionary(_unit_statuses.get(key, {})).duplicate(true)


func _damage_event(kind: String, target_key: String, amount: float, source_position: Vector2) -> Dictionary:
	return {
		"type": "damage",
		"kind": kind,
		"source": "python_boss",
		"source_id": BOSS_ENTITY_ID,
		"target": target_key,
		"amount": amount,
		"source_pos": source_position,
	}


func receive_hit(attack_id: Variant, source_kind: String, source_id: int, raw_damage: float, hit_point: Vector2, damage_kind: String = "direct", armor_penetration: float = 0.0) -> Dictionary:
	var result: Dictionary = {"accepted": false, "damage": 0.0, "part": "none", "defeated": false, "events": []}
	if _state == State.DEAD or raw_damage <= 0.0:
		return result
	var key: String = str(attack_id)
	if key != "" and _attack_cache.has(key):
		result["reason"] = "duplicate_attack_id"
		return result
	if key != "":
		_attack_cache[key] = ATTACK_CACHE_TTL
		while _attack_cache.size() > MAX_ATTACK_CACHE:
			_attack_cache.erase(_attack_cache.keys()[0])
	var nearest: Dictionary = _nearest_segment(hit_point)
	var part: String = str(nearest.get("part", "body"))
	var part_table: Dictionary = Dictionary(_config.get("part_damage_multipliers", {}))
	var part_multiplier: float = float(part_table.get(part, 0.80))
	if _state == State.STUNNED and part == "head":
		part_multiplier *= float(part_table.get("stunned_head", 1.20))
	var effective_defense: float = maxf(0.0, _defense - armor_penetration)
	var reduction: float = minf(0.70, effective_defense / (effective_defense + 50.0))
	var damage: float = maxf(1.0, roundf(raw_damage * part_multiplier * (1.0 - reduction)))
	if _state == State.PHASE_CHANGE:
		var phase_reduction: float = float(Dictionary(_config.get("phase_change", {})).get("damage_reduction", 0.82))
		damage = maxf(1.0, roundf(damage * (1.0 - phase_reduction)))
	_hp = maxf(0.0, _hp - damage)
	_flash_timer = 0.12
	var threat_multiplier: float = float(_threat_config.get("cannon_multiplier", 2.2)) if source_kind == "cannon" else float(_threat_config.get("damage_multiplier", 1.0))
	add_threat(source_kind, source_id, damage * threat_multiplier)
	var events: Array[Dictionary] = []
	events.append({"type": "boss_hit", "damage": damage, "part": part, "position": hit_point, "source_kind": source_kind, "source_id": source_id, "damage_kind": damage_kind})
	var next_phase: int = _phase_for_hp()
	if next_phase > _phase:
		_pending_phase = maxi(_pending_phase, next_phase)
	if _hp <= 0.0:
		_die(events)
		result["defeated"] = true
	result["accepted"] = true
	result["damage"] = damage
	result["part"] = part
	result["events"] = events
	return result


func _die(events: Array[Dictionary]) -> void:
	_release_constrict(events, "蟒皇死亡")
	_unit_statuses.clear()
	_state = State.DEAD
	_hp = 0.0
	_velocity = Vector2.ZERO
	_active_skill = ""
	_telegraph.clear()
	_cast_hit_set.clear()
	_death_elapsed = 0.0
	_discovered = true
	_nest_cleared = true
	for index in _glob_slots.size():
		_glob_slots[index] = {"slot": index, "active": false}
	for index in _pool_slots.size():
		_pool_slots[index] = {"slot": index, "active": false}
	events.append({"type": "audio", "kind": "death"})
	events.append({"type": "effect", "kind": "boss_death", "position": _position})
	events.append({"type": "notice", "kind": "boss_defeated", "text": "腐沼蟒皇已被擊敗"})
	if not _reward_claimed:
		_reward_claimed = true
		var rewards: Dictionary = Dictionary(_config.get("rewards", {}))
		events.append({
			"type": "reward",
			"kind": "boss_clear",
			"gold": _rng.randi_range(int(rewards.get("gold_min", 800)), int(rewards.get("gold_max", 1200))),
			"xp": _rng.randi_range(int(rewards.get("xp_min", 900)), int(rewards.get("xp_max", 1400))),
		})


func add_threat(kind: String, id: int, amount: float) -> void:
	var soldier_types := ["healer", "priest", "heavy", "cannon", "archer", "mage", "roller", "swordsman", "musketeer", "rifleman", "tank", "rocket"]
	var key: String = _unit_key("soldier" if kind in soldier_types else kind, id)
	_threat[key] = float(_threat.get(key, 0.0)) + maxf(0.0, amount)


func _is_vehicle_type(type_id: String) -> bool:
	return type_id in ["cannon", "tank", "rocket"]


func projectile_intersection(from: Vector2, to: Vector2, radius: float) -> Dictionary:
	var result: Dictionary = {"hit": false, "time": 1.0, "position": to, "part": "none", "index": -1}
	if _state == State.DEAD:
		return result
	var distance: float = from.distance_to(to)
	var sample_step: float = maxf(4.0, float(_performance_config.get("dash_substep", 18.0)) * 0.5)
	var samples: int = maxi(1, int(ceil(distance / sample_step)))
	for sample_index in range(samples + 1):
		var t: float = float(sample_index) / float(samples)
		var point: Vector2 = from.lerp(to, t)
		var nearest: Dictionary = _nearest_segment(point)
		if float(nearest.get("distance", INF)) <= radius + float(nearest.get("radius", 0.0)):
			result["hit"] = true
			result["time"] = t
			result["position"] = point
			result["part"] = str(nearest["part"])
			result["index"] = int(nearest["index"])
			return result
	return result


func resolve_body_collision(position: Vector2, radius: float) -> Vector2:
	if _state == State.DEAD:
		return position
	var resolved: Vector2 = position
	for _pass in 3:
		var moved := false
		for segment in _segments:
			var center: Vector2 = Vector2(segment["pos"])
			var minimum: float = radius + float(segment["radius"])
			var offset: Vector2 = resolved - center
			var distance: float = offset.length()
			if distance >= minimum:
				continue
			var normal: Vector2 = offset / distance if distance > 0.001 else Vector2.UP
			var candidate := center + normal * minimum
			if _is_blocked(candidate, radius):
				var left_candidate := center + normal.rotated(0.72) * minimum
				var right_candidate := center + normal.rotated(-0.72) * minimum
				if not _is_blocked(left_candidate, radius):
					candidate = left_candidate
				elif not _is_blocked(right_candidate, radius):
					candidate = right_candidate
				else:
					continue
			resolved = candidate
			moved = true
		if not moved:
			break
	return resolved


func body_snapshot() -> Array:
	return _segments.duplicate(true)


func _nearest_segment(point: Vector2) -> Dictionary:
	var best: Dictionary = {"index": -1, "part": "body", "pos": _position, "radius": 0.0, "distance": INF, "surface_distance": INF}
	for segment in _segments:
		var distance: float = point.distance_to(Vector2(segment["pos"]))
		var surface_distance: float = distance - float(segment["radius"])
		if surface_distance < float(best["surface_distance"]):
			best = segment.duplicate(true)
			best["distance"] = distance
			best["surface_distance"] = surface_distance
	return best


func _append_history_motion(_from: Vector2, to: Vector2) -> void:
	var step: float = maxf(1.0, float(_body_config.get("history_step", 5.0)))
	if _path_history.is_empty():
		_reset_body_history()
		_path_history[0] = to
		return
	# 每次將「新頭部 + 舊路徑」重新取樣為固定間距；小於 history_step 的
	# 多幀移動也會累積，不會一直覆寫第一個點而把轉彎吃掉。
	var source: Array[Vector2] = [to]
	for old_point in _path_history:
		if source[-1].distance_to(old_point) > 0.001:
			source.append(old_point)
	var segment_count: int = int(_body_config.get("segment_count", 18))
	var spacing: float = float(_body_config.get("segment_spacing", 28.0))
	var max_points: int = int(ceil((float(segment_count) * spacing + float(_body_config.get("history_margin", 180.0))) / step))
	var resampled: Array[Vector2] = [to]
	var walked := 0.0
	var next_sample := step
	for source_index in range(source.size() - 1):
		var a: Vector2 = source[source_index]
		var b: Vector2 = source[source_index + 1]
		var length: float = a.distance_to(b)
		if length <= 0.001:
			continue
		while walked + length >= next_sample and resampled.size() < max_points:
			var t: float = (next_sample - walked) / length
			resampled.append(a.lerp(b, clampf(t, 0.0, 1.0)))
			next_sample += step
		walked += length
		if resampled.size() >= max_points:
			break
	if resampled.size() < max_points:
		resampled.append(source[-1])
	_path_history = resampled


func _rebuild_segments() -> void:
	_segments.clear()
	var count: int = clampi(int(_body_config.get("segment_count", 18)), 14, 20)
	var spacing: float = float(_body_config.get("segment_spacing", 28.0))
	var body_radius: float = float(_body_config.get("body_radius", 32.0))
	var tail_radius: float = float(_body_config.get("tail_radius", 14.0))
	for index in count:
		var t: float = float(index) / float(maxi(count - 1, 1))
		var part := "head" if index == 0 else "tail" if index >= count - 4 else "body"
		var radius: float = float(_body_config.get("head_radius", 40.0)) if index == 0 else lerpf(body_radius, tail_radius, pow(t, 1.35))
		_segments.append({"index": index, "pos": _history_point(spacing * float(index)), "radius": radius, "part": part})


func _history_point(path_distance: float) -> Vector2:
	if _path_history.is_empty():
		return _position
	var remaining: float = path_distance
	for index in range(_path_history.size() - 1):
		var a: Vector2 = _path_history[index]
		var b: Vector2 = _path_history[index + 1]
		var length: float = a.distance_to(b)
		if length <= 0.001:
			continue
		if remaining <= length:
			return a.lerp(b, remaining / length)
		remaining -= length
	return _path_history[-1]


func _tail_position() -> Vector2:
	return Vector2(_segments[-1]["pos"]) if not _segments.is_empty() else _position


func _tail_pivot() -> Vector2:
	if _segments.is_empty():
		return _position
	var index: int = clampi(int(floor(float(_segments.size()) * 0.68)), 1, _segments.size() - 1)
	return Vector2(_segments[index]["pos"])


func _distance_point_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var line: Vector2 = b - a
	var length_squared: float = line.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(line) / length_squared, 0.0, 1.0)
	return point.distance_to(a + line * t)


func get_speed_multiplier(kind: String, id: int = -1) -> float:
	var status: Dictionary = Dictionary(_unit_statuses.get(_unit_key(kind, id), {}))
	if float(status.get("constricted", 0.0)) > 0.0:
		return 0.0
	var multiplier := 1.0
	if int(status.get("poison_stacks", 0)) >= 3:
		multiplier *= 0.85
	if float(status.get("pool_slow_ttl", 0.0)) > 0.0:
		multiplier *= 1.0 - float(status.get("pool_slow", 0.0))
	if float(status.get("off_balance", 0.0)) > 0.0:
		multiplier *= 0.75
	return clampf(multiplier, 0.0, 1.0)


func is_rooted(kind: String, id: int = -1) -> bool:
	return _status_value(_unit_key(kind, id), "constricted") > 0.0


func force_engage() -> void:
	_discovered = true
	if _state in [State.IDLE, State.RETURNING]:
		_state = State.ALERT
		_state_timer = 0.08


func debug_force_skill(skill_id: String) -> void:
	if skill_id in SKILL_IDS:
		_forced_skill = skill_id
		_cooldowns[skill_id] = 0.0
		_global_skill_gap = 0.0
		_decision_timer = 0.0


func debug_set_hp_ratio(ratio: float) -> void:
	_hp = clampf(ratio, 0.0, 1.0) * _max_hp
	_pending_phase = maxi(_pending_phase, _phase_for_hp())


func is_damageable() -> bool:
	return _state != State.DEAD


func is_engaged() -> bool:
	return _state not in [State.IDLE, State.RETURNING, State.DEAD]


func is_defeated() -> bool:
	return _state == State.DEAD


func get_text_state() -> Dictionary:
	return {
		"id": str(_config.get("id", "corrupt_python_emperor_saga")),
		"name": str(_config.get("name", "腐沼蟒皇・薩迦")),
		"state": STATE_NAMES[clampi(_state, 0, STATE_NAMES.size() - 1)],
		"phase": _phase + 1,
		"phase_name": _phase_name(),
		"hp": snappedf(_hp, 0.1),
		"max_hp": snappedf(_max_hp, 0.1),
		"damage": snappedf(_damage, 0.1),
		"defense": snappedf(_defense, 0.1),
		"move_speed": snappedf(_move_speed * _phase_move_multiplier(), 0.1),
		"world_tier": _world_tier,
		"player_level_scale": _player_level,
		"hp_ratio": snappedf(_hp / maxf(_max_hp, 1.0), 0.001),
		"x": snappedf(_position.x, 0.1),
		"y": snappedf(_position.y, 0.1),
		"velocity_x": snappedf(_velocity.x, 0.1),
		"velocity_y": snappedf(_velocity.y, 0.1),
		"facing_x": snappedf(_facing.x, 0.001),
		"facing_y": snappedf(_facing.y, 0.001),
		"discovered": _discovered,
		"engaged": is_engaged(),
		"defeated": is_defeated(),
		"reward_claimed": _reward_claimed,
		"target": _target_key,
		"active_skill": _active_skill,
		"telegraph_remaining": snappedf(float(_telegraph.get("remaining", 0.0)), 0.01),
		"stun_remaining": snappedf(_stun_timer, 0.01),
		"constrict_target": _constrict_key,
		"break_gauge": snappedf(_constrict_break_gauge, 0.1),
		"poison_pools": _active_pool_count(),
		"segments": _segments.size(),
	}


func get_unit_status(kind: String, id: int) -> Dictionary:
	return _status_for(_unit_key(kind, id)).duplicate(true)


func cleanse_unit_status(kind: String, id: int) -> Dictionary:
	var key := _unit_key(kind, id)
	var status := _status_for(key)
	if status.is_empty():
		return {"cleansed": false, "removed": []}
	var removed: Array[String] = []
	if int(status.get("poison_stacks", 0)) > 0 or float(status.get("poison_ttl", 0.0)) > 0.0:
		status["poison_stacks"] = 0
		status["poison_ttl"] = 0.0
		status["poison_tick"] = 1.0
		removed.append("poison")
	if float(status.get("pool_slow_ttl", 0.0)) > 0.0 or float(status.get("pool_slow", 0.0)) > 0.0:
		status["pool_slow_ttl"] = 0.0
		status["pool_slow"] = 0.0
		removed.append("slow")
	if float(status.get("off_balance", 0.0)) > 0.0:
		status["off_balance"] = 0.0
		removed.append("off_balance")
	if (
		int(status.get("poison_stacks", 0)) <= 0
		and float(status.get("control_immunity", 0.0)) <= 0.0
		and float(status.get("off_balance", 0.0)) <= 0.0
		and float(status.get("pool_slow_ttl", 0.0)) <= 0.0
		and float(status.get("constricted", 0.0)) <= 0.0
	):
		_unit_statuses.erase(key)
	else:
		_unit_statuses[key] = status
	return {"cleansed": not removed.is_empty(), "removed": removed}


func debug_set_unit_status(kind: String, id: int, status: Dictionary) -> void:
	var key := _unit_key(kind, id)
	if status.is_empty():
		_unit_statuses.erase(key)
	else:
		_unit_statuses[key] = status.duplicate(true)


func render_snapshot() -> Dictionary:
	var globs: Array[Dictionary] = []
	for glob in _glob_slots:
		if bool(glob.get("active", false)):
			globs.append(glob.duplicate(true))
	var pools: Array[Dictionary] = []
	for pool in _pool_slots:
		if bool(pool.get("active", false)):
			pools.append(pool.duplicate(true))
	return {
		"position": _position,
		"facing": _facing,
		"state": STATE_NAMES[clampi(_state, 0, STATE_NAMES.size() - 1)],
		"phase": _phase + 1,
		"hp_ratio": _hp / maxf(_max_hp, 1.0),
		"active_skill": _active_skill,
		"cast_elapsed": _cast_elapsed,
		"tail_angle": _tail_previous_angle,
		"flash": _flash_timer,
		"death_elapsed": _death_elapsed,
		"segments": _segments.duplicate(true),
		"telegraph": _telegraph.duplicate(true),
		"globs": globs,
		"pools": pools,
		"constrict_key": _constrict_key,
		"constrict_anchor": _constrict_anchor,
		"break_gauge": _constrict_break_gauge,
	}


func serialize() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"discovered": _discovered,
		"position": _position,
		"engaged": _state not in [State.IDLE, State.DEAD],
		"defeated": is_defeated(),
		"hp": _hp,
		"phase": maxi(_phase, _phase_for_hp()) + 1,
		"pending_phase": _pending_phase + 1 if _pending_phase >= 0 else 0,
		"respawn_at": -1.0,
		"nest_cleared": _nest_cleared,
		"reward_claimed": _reward_claimed,
		"rng_state": _rng.state,
		"world_tier": _world_tier,
		"player_level": _player_level,
	}


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	_discovered = bool(data.get("discovered", false))
	_nest_cleared = bool(data.get("nest_cleared", false))
	_reward_claimed = bool(data.get("reward_claimed", false))
	_world_tier = maxi(_world_tier, int(data.get("world_tier", _world_tier)))
	_player_level = maxi(_player_level, int(data.get("player_level", _player_level)))
	_load_scaled_stats()
	var defeated: bool = bool(data.get("defeated", false))
	var was_engaged: bool = bool(data.get("engaged", false))
	_hp = 0.0 if defeated else (_max_hp if was_engaged else clampf(float(data.get("hp", _max_hp)), 1.0, _max_hp))
	_phase = 0 if was_engaged else clampi(maxi(int(data.get("phase", _phase_for_hp() + 1)) - 1, _phase_for_hp()), 0, 2)
	_pending_phase = -1 if was_engaged else clampi(int(data.get("pending_phase", 0)) - 1, -1, 2)
	_position = _home if was_engaged and not defeated else Vector2(data.get("position", _home))
	if _position.distance_to(_home) > float(_base.get("leash_distance", 1000.0)):
		_position = _home
	_velocity = Vector2.ZERO
	_facing = Vector2.RIGHT
	_state = State.DEAD if defeated else State.IDLE
	_death_elapsed = 2.6 if defeated else 0.0
	_rng.state = int(data.get("rng_state", _rng.state))
	_active_skill = ""
	_telegraph.clear()
	_cast_hit_set.clear()
	_constrict_key = ""
	_unit_statuses.clear()
	_attack_cache.clear()
	_initialize_object_pools()
	_reset_body_history()


func _unit_key(kind: String, id: int) -> String:
	return "%s:%d" % [kind, id]

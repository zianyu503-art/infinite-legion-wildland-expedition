class_name SoldierUpgradeRuntime
extends RefCounted

## Pure runtime helpers for permanent soldier research snapshots.
##
## This class owns no nodes and never reads scene state. Callers keep the returned
## dictionaries on their soldier/projectile records and remain responsible for
## movement, target selection, damage application, visuals, and saving.

const STATE_VERSION := 1
const MAX_REASONABLE_MULTIPLIER := 50.0

const CATALOG_IDS: Array[String] = [
	"burning_sword", "burning_ammo", "frost_arrow", "paralysis_arrow", "chain_lightning",
	"corrosion", "void_mark", "split_shot", "piercing_arrow", "penetrating_round", "ricochet",
	"lingering_projectile", "homing_guidance", "armor_piercing_core", "chain_explosion",
	"mine_round", "cluster_warhead", "burning_zone", "shockwave_round", "shrapnel_storm",
	"siege_warhead", "dash", "stomp", "sweeping_slash", "suppression", "taunt_guard",
	"focus_mark", "aerial_evade", "meteor", "guardian", "auto_turret", "repair_drone",
	"self_repair", "tactical_shield", "last_stand", "lifesteal", "reactive_armor",
	"evade_drill", "air_flares", "healing_mastery", "group_heal", "cleanse", "holy_shield",
	"resurrection_ritual", "soul_shelter", "guardian_aura", "battlefield_repair",
	"toxic_payload", "execution_protocol", "gravity_warhead", "temporal_echo",
	"overcharge_capacitor", "kinetic_barrier", "rally_beacon", "overheal_matrix",
	"vengeance_counter", "salvage_protocol",
]


static func special_effect(snapshot: Variant, ability_id: String) -> Dictionary:
	var snapshot_dictionary := _as_dictionary(snapshot)
	if snapshot_dictionary.is_empty() or ability_id.is_empty():
		return {}

	# New snapshots use an O(1) effect map. Values may either be the effect itself
	# or a catalog-style record containing an `effect` child dictionary.
	var special_effects := _as_dictionary(snapshot_dictionary.get("special_effects", {}))
	if special_effects.has(ability_id):
		var mapped_value := _as_dictionary(special_effects[ability_id])
		var mapped_effect := _as_dictionary(mapped_value.get("effect", mapped_value))
		if not mapped_effect.is_empty():
			return mapped_effect.duplicate(true)

	# Schema-7 snapshots originally exposed active specials as an Array. Keep that
	# format working so already-recruited and loaded soldiers retain their purchase.
	var active_specials_value: Variant = snapshot_dictionary.get("active_specials", [])
	if active_specials_value is Array:
		for entry_value in Array(active_specials_value):
			var entry := _as_dictionary(entry_value)
			if str(entry.get("id", "")) != ability_id:
				continue
			var active_effect := _as_dictionary(entry.get("effect", {}))
			if not active_effect.is_empty():
				return active_effect.duplicate(true)
	return {}


static func has_special(snapshot: Variant, ability_id: String) -> bool:
	return not special_effect(snapshot, ability_id).is_empty()


static func special_effect_map(snapshot: Variant) -> Dictionary:
	## Public migration-safe view of every purchased special. Schema-7 soldier
	## snapshots only stored `active_specials`; newer snapshots also carry the
	## O(1) `special_effects` map used by combat code.
	return _snapshot_special_map(snapshot).duplicate(true)


static func create_state(snapshot: Variant, max_hp: float) -> Dictionary:
	var safe_max_hp := maxf(1.0, _finite_float(max_hp, 1.0))
	var tactical_effect := special_effect(snapshot, "tactical_shield")
	var tactical_max := safe_max_hp * clampf(_first_number(
		tactical_effect,
		["shield_max_hp_ratio", "max_hp_ratio", "shield_ratio"],
		0.0
	), 0.0, 5.0)
	var kinetic_effect := special_effect(snapshot, "kinetic_barrier")
	var kinetic_max := safe_max_hp * clampf(_first_number(
		kinetic_effect,
		["barrier_max_hp_ratio", "shield_max_hp_ratio", "max_hp_ratio", "barrier_ratio"],
		0.0
	), 0.0, 5.0)
	return {
		"version": STATE_VERSION,
		"attack_sequence": 0,
		"healing_sequence": 0,
		"damage_sequence": 0,
		"last_stand_used": false,
		"reactive_armor_cooldown": 0.0,
		"evade_cooldown": 0.0,
		"aerial_evade_cooldown": 0.0,
		"air_flares_cooldown": 0.0,
		"overcharge_cooldown": 0.0,
		"temporal_echo_cooldown": 0.0,
		"vengeance_stacks": 0,
		"vengeance_damage_bank": 0.0,
		"tactical_shield": tactical_max,
		"tactical_shield_max": tactical_max,
		"tactical_shield_recharge": 0.0,
		"kinetic_barrier": 0.0,
		"kinetic_barrier_max": kinetic_max,
		"kinetic_barrier_distance": 0.0,
		"kinetic_barrier_ttl": 0.0,
	}


static func normalize_state(raw: Variant, snapshot: Variant, max_hp: float) -> Dictionary:
	var defaults := create_state(snapshot, max_hp)
	var raw_state := _as_dictionary(raw)
	if raw_state.is_empty():
		return defaults

	var normalized := defaults.duplicate(true)
	for sequence_key in ["attack_sequence", "healing_sequence", "damage_sequence"]:
		normalized[sequence_key] = clampi(_safe_int(raw_state.get(sequence_key, 0), 0), 0, 0x7FFFFFFF)
	normalized["last_stand_used"] = bool(raw_state.get("last_stand_used", false))

	for cooldown_key in [
		"reactive_armor_cooldown", "evade_cooldown", "aerial_evade_cooldown",
		"air_flares_cooldown", "overcharge_cooldown", "temporal_echo_cooldown",
		"tactical_shield_recharge", "kinetic_barrier_ttl",
	]:
		normalized[cooldown_key] = clampf(
			_finite_float(raw_state.get(cooldown_key, defaults[cooldown_key]), 0.0),
			0.0,
			1000000.0
		)

	var vengeance_effect := special_effect(snapshot, "vengeance_counter")
	var vengeance_max := maxi(0, _first_integer(vengeance_effect, ["hits_taken", "max_stacks", "counter_max", "stacks"], 10))
	normalized["vengeance_stacks"] = clampi(_safe_int(raw_state.get("vengeance_stacks", 0), 0), 0, vengeance_max)
	normalized["vengeance_damage_bank"] = clampf(
		_finite_float(raw_state.get("vengeance_damage_bank", 0.0), 0.0),
		0.0,
		maxf(1.0, _finite_float(max_hp, 1.0)) * 100.0
	)

	for shield_prefix in ["tactical_shield", "kinetic_barrier"]:
		var maximum_key := "%s_max" % shield_prefix
		var current_max := float(defaults[maximum_key])
		var default_current := float(defaults[shield_prefix])
		normalized[maximum_key] = current_max
		normalized[shield_prefix] = clampf(
			_finite_float(raw_state.get(shield_prefix, default_current), default_current),
			0.0,
			current_max
		)
	normalized["kinetic_barrier_distance"] = clampf(
		_finite_float(raw_state.get("kinetic_barrier_distance", 0.0), 0.0),
		0.0,
		1000000.0
	)
	normalized["version"] = STATE_VERSION
	return normalized


static func tick_state(soldier: Dictionary, delta: float) -> Dictionary:
	var snapshot := _soldier_snapshot(soldier)
	var state := normalize_state(
		soldier.get("special_runtime", {}),
		snapshot,
		_finite_float(soldier.get("max_hp", 1.0), 1.0)
	)
	var step := maxf(0.0, _finite_float(delta, 0.0))
	for cooldown_key in [
		"reactive_armor_cooldown", "evade_cooldown", "aerial_evade_cooldown",
		"air_flares_cooldown", "overcharge_cooldown", "temporal_echo_cooldown",
	]:
		state[cooldown_key] = maxf(0.0, float(state[cooldown_key]) - step)

	_tick_recharging_pool(state, "tactical_shield", step)
	state["kinetic_barrier_ttl"] = maxf(0.0, float(state["kinetic_barrier_ttl"]) - step)
	if float(state["kinetic_barrier_ttl"]) <= 0.0:
		state["kinetic_barrier"] = 0.0
	soldier["special_runtime"] = state
	return state.duplicate(true)


static func record_movement(soldier: Dictionary, traveled_distance: float) -> Dictionary:
	var snapshot := _soldier_snapshot(soldier)
	var state := normalize_state(
		soldier.get("special_runtime", {}),
		snapshot,
		_finite_float(soldier.get("max_hp", 1.0), 1.0)
	)
	var result := {"activated": false, "shield": float(state["kinetic_barrier"]), "ttl": float(state["kinetic_barrier_ttl"])}
	var kinetic := special_effect(snapshot, "kinetic_barrier")
	if kinetic.is_empty() or float(state["kinetic_barrier_max"]) <= 0.0:
		soldier["special_runtime"] = state
		return result
	if float(state["kinetic_barrier_ttl"]) > 0.0:
		soldier["special_runtime"] = state
		return result
	var required_distance := maxf(1.0, _first_number(kinetic, ["move_distance"], 300.0))
	state["kinetic_barrier_distance"] = float(state["kinetic_barrier_distance"]) + maxf(0.0, _finite_float(traveled_distance, 0.0))
	if float(state["kinetic_barrier_distance"]) >= required_distance:
		state["kinetic_barrier_distance"] = fmod(float(state["kinetic_barrier_distance"]), required_distance)
		state["kinetic_barrier"] = float(state["kinetic_barrier_max"])
		state["kinetic_barrier_ttl"] = maxf(0.01, _first_number(kinetic, ["duration"], 5.0))
		result["activated"] = true
		result["shield"] = float(state["kinetic_barrier"])
		result["ttl"] = float(state["kinetic_barrier_ttl"])
	soldier["special_runtime"] = state
	return result


static func begin_attack(soldier: Dictionary, target_hp_ratio: float) -> Dictionary:
	var snapshot := _soldier_snapshot(soldier)
	var state := normalize_state(
		soldier.get("special_runtime", {}),
		snapshot,
		_finite_float(soldier.get("max_hp", 1.0), 1.0)
	)
	state["attack_sequence"] = int(state["attack_sequence"]) + 1
	var sequence := int(state["attack_sequence"])
	var soldier_id := _safe_int(soldier.get("id", 0), 0)
	var target_ratio := clampf(_finite_float(target_hp_ratio, 1.0), 0.0, 1.0)
	var base_effects := _as_dictionary(snapshot.get("base_effects", {}))

	var damage_multiplier := 1.0
	var critical_roll := _deterministic_unit_roll(soldier_id, sequence, 0x45D9F3B)
	var critical_chance := clampf(_finite_float(base_effects.get("critical_chance", 0.0), 0.0), 0.0, 1.0)
	var critical_mode := str(base_effects.get("critical_mode", "damage"))
	var is_critical := critical_mode != "healing" and critical_chance > 0.0 and critical_roll < critical_chance
	if is_critical:
		damage_multiplier *= maxf(1.0, _finite_float(base_effects.get("critical_multiplier", 1.0), 1.0))

	var execution_triggered := false
	var execution := special_effect(snapshot, "execution_protocol")
	if not execution.is_empty():
		var execute_threshold := clampf(_first_number(
			execution,
			["target_hp_threshold", "execute_below_hp_ratio", "hp_threshold", "threshold"],
			0.30
		), 0.0, 1.0)
		if target_ratio <= execute_threshold:
			execution_triggered = true
			damage_multiplier *= _effect_multiplier(
				execution,
				["damage_multiplier", "execute_damage_multiplier"],
				["damage_bonus_ratio", "execute_damage_bonus", "damage_bonus"],
				1.0
			)

	var echo := false
	var echo_damage_ratio := 0.0
	var echo_delay := 0.0
	var temporal_echo := special_effect(snapshot, "temporal_echo")
	if not temporal_echo.is_empty() and float(state["temporal_echo_cooldown"]) <= 0.0:
		var echo_every := _first_integer(temporal_echo, ["trigger_every_attacks", "every_attacks", "attack_interval"], 0)
		var echo_chance := clampf(_first_number(temporal_echo, ["chance", "echo_chance"], 0.0), 0.0, 1.0)
		if echo_every > 0:
			echo = sequence % echo_every == 0
		elif echo_chance > 0.0:
			echo = _deterministic_unit_roll(soldier_id, sequence, 0x119DE1F3) < echo_chance
		else:
			echo = true
		if echo:
			echo_damage_ratio = clampf(_first_number(temporal_echo, ["echo_damage_ratio", "damage_ratio"], 0.35), 0.0, 10.0)
			echo_delay = maxf(0.0, _first_number(temporal_echo, ["delay", "echo_delay"], 0.18))
			state["temporal_echo_cooldown"] = maxf(0.0, _first_number(temporal_echo, ["cooldown"], 0.0))

	var overcharge_triggered := false
	var bonus_radius := 0.0
	var overcharge := special_effect(snapshot, "overcharge_capacitor")
	if not overcharge.is_empty() and float(state["overcharge_cooldown"]) <= 0.0:
		var overcharge_every := maxi(1, _first_integer(overcharge, ["trigger_every_attacks", "every_attacks", "attack_interval"], 1))
		if sequence % overcharge_every == 0:
			overcharge_triggered = true
			damage_multiplier *= _effect_multiplier(
				overcharge,
				["damage_multiplier", "overcharge_damage_multiplier"],
				["damage_bonus_ratio", "damage_bonus"],
				1.0
			)
			bonus_radius = maxf(0.0, _first_number(overcharge, ["bonus_radius", "radius_bonus", "aoe_bonus"], 0.0))
			state["overcharge_cooldown"] = maxf(0.0, _first_number(overcharge, ["cooldown"], 0.0))

	var vengeance_triggered := false
	var vengeance_stacks_used := 0
	var vengeance := special_effect(snapshot, "vengeance_counter")
	var vengeance_required_hits := maxi(1, _first_integer(vengeance, ["hits_taken", "max_stacks", "counter_max"], 1))
	if not vengeance.is_empty() and int(state["vengeance_stacks"]) >= vengeance_required_hits:
		vengeance_triggered = true
		vengeance_stacks_used = int(state["vengeance_stacks"])
		var vengeance_bonus := maxf(0.0, _first_number(
			vengeance,
			["next_attack_damage_bonus", "damage_bonus", "damage_bonus_ratio"],
			0.0
		))
		if vengeance.has("damage_bonus_per_stack") or vengeance.has("bonus_damage_per_stack") or vengeance.has("bonus_per_stack"):
			var per_stack := maxf(0.0, _first_number(vengeance, ["damage_bonus_per_stack", "bonus_damage_per_stack", "bonus_per_stack"], 0.0))
			vengeance_bonus += per_stack * float(vengeance_stacks_used)
		damage_multiplier *= 1.0 + vengeance_bonus
		if bool(vengeance.get("consume_on_attack", true)):
			state["vengeance_stacks"] = 0
			state["vengeance_damage_bank"] = 0.0

	damage_multiplier = clampf(damage_multiplier, 0.0, MAX_REASONABLE_MULTIPLIER)
	soldier["special_runtime"] = state
	return {
		"attack_sequence": sequence,
		"damage_multiplier": damage_multiplier,
		"is_critical": is_critical,
		"critical_roll": critical_roll,
		"echo": echo,
		"echo_damage_ratio": echo_damage_ratio,
		"echo_delay": echo_delay,
		"bonus_radius": bonus_radius,
		"execution_triggered": execution_triggered,
		"overcharge_triggered": overcharge_triggered,
		"vengeance_triggered": vengeance_triggered,
		"vengeance_stacks_used": vengeance_stacks_used,
		"special_generation": 0,
		"allow_special_generation": true,
	}


static func decorate_projectile(data: Dictionary, soldier: Dictionary, attack_context: Dictionary) -> Dictionary:
	var decorated := data.duplicate(true)
	var snapshot := _soldier_snapshot(soldier)
	var copied_specials := _snapshot_special_map(snapshot)
	var copied_context := attack_context.duplicate(true)
	var generation := maxi(0, _safe_int(decorated.get("special_generation", copied_context.get("special_generation", 0)), 0))
	var incoming_generation_allowed := bool(copied_context.get("allow_special_generation", true))

	decorated["source_id"] = _safe_int(decorated.get("source_id", soldier.get("id", 0)), 0)
	decorated["source_kind"] = str(decorated.get("source_kind", soldier.get("type", "soldier")))
	decorated["soldier_specials"] = copied_specials.duplicate(true)
	decorated["soldier_attack_context"] = copied_context
	decorated["special_generation"] = generation
	# Generated split/cluster/chain children may carry safe stat metadata, but they
	# are never allowed to generate another generation of child effects.
	decorated["allow_special_generation"] = generation == 0 and incoming_generation_allowed
	decorated["is_critical"] = bool(copied_context.get("is_critical", false))
	decorated["attack_sequence"] = _safe_int(copied_context.get("attack_sequence", 0), 0)

	if decorated.has("damage"):
		decorated["damage"] = maxf(0.0, _finite_float(decorated["damage"], 0.0)) * clampf(
			_finite_float(copied_context.get("damage_multiplier", 1.0), 1.0),
			0.0,
			MAX_REASONABLE_MULTIPLIER
		)
	if decorated.has("aoe"):
		decorated["aoe"] = maxf(0.0, _finite_float(decorated["aoe"], 0.0) + _finite_float(copied_context.get("bonus_radius", 0.0), 0.0))

	var armor_core := special_effect(snapshot, "armor_piercing_core")
	if not armor_core.is_empty():
		decorated["armor_penetration"] = maxf(0.0, _finite_float(decorated.get("armor_penetration", 0.0), 0.0)) + maxf(
			0.0,
			_first_number(armor_core, ["ignored_armor", "armor_penetration"], 0.0)
		)

	var added_pierce := 0
	var retained_damage := -1.0
	for piercing_id in ["piercing_arrow", "penetrating_round"]:
		var piercing := special_effect(snapshot, piercing_id)
		if piercing.is_empty():
			continue
		added_pierce += maxi(0, _first_integer(piercing, ["extra_pierce"], 0))
		retained_damage = maxf(retained_damage, clampf(_first_number(piercing, ["retained_damage_ratio"], 1.0), 0.0, 1.0))
	if added_pierce > 0:
		decorated["pierce"] = maxi(1, _safe_int(decorated.get("pierce", 1), 1)) + added_pierce
		decorated["falloff"] = retained_damage if retained_damage >= 0.0 else _finite_float(decorated.get("falloff", 1.0), 1.0)

	var homing := special_effect(snapshot, "homing_guidance")
	if not homing.is_empty():
		var turn_rate := maxf(0.0, _first_number(homing, ["turn_degrees_per_second", "turn_rate"], 0.0))
		decorated["homing"] = turn_rate > 0.0
		decorated["homing_turn_degrees_per_second"] = turn_rate
		decorated["homing_until_expiry"] = bool(homing.get("until_expiry", true))
		if not decorated.has("target_id") and copied_context.has("target_id"):
			decorated["target_id"] = copied_context["target_id"]
	return decorated


static func healing_multiplier(soldier: Dictionary, _target_hp_ratio: float) -> float:
	var snapshot := _soldier_snapshot(soldier)
	var state := normalize_state(
		soldier.get("special_runtime", {}),
		snapshot,
		_finite_float(soldier.get("max_hp", 1.0), 1.0)
	)
	state["healing_sequence"] = int(state["healing_sequence"]) + 1
	var sequence := int(state["healing_sequence"])
	var base_effects := _as_dictionary(snapshot.get("base_effects", {}))
	var multiplier := 1.0 + maxf(0.0, _finite_float(base_effects.get("attack_or_healing_bonus", 0.0), 0.0))
	var mastery := special_effect(snapshot, "healing_mastery")
	if not mastery.is_empty():
		multiplier *= 1.0 + maxf(0.0, _first_number(mastery, ["healing_bonus"], 0.0))

	var critical_mode := str(base_effects.get("critical_mode", "damage"))
	var critical_chance := clampf(_finite_float(base_effects.get("critical_chance", 0.0), 0.0), 0.0, 1.0)
	if critical_mode == "healing" and critical_chance > 0.0:
		var healing_roll := _deterministic_unit_roll(_safe_int(soldier.get("id", 0), 0), sequence, 0x2C9277B5)
		if healing_roll < critical_chance:
			multiplier *= maxf(1.0, _finite_float(base_effects.get("critical_multiplier", 1.0), 1.0))
	soldier["special_runtime"] = state
	return clampf(multiplier, 0.0, MAX_REASONABLE_MULTIPLIER)


static func incoming_damage_plan(soldier: Dictionary, damage_kind: String, raw_damage: float) -> Dictionary:
	var snapshot := _soldier_snapshot(soldier)
	var max_hp := maxf(1.0, _finite_float(soldier.get("max_hp", 1.0), 1.0))
	var state := normalize_state(soldier.get("special_runtime", {}), snapshot, max_hp)
	state["damage_sequence"] = int(state["damage_sequence"]) + 1
	var damage := maxf(0.0, _finite_float(raw_damage, 0.0))
	var original_damage := damage
	var evaded := false
	var evade_kind := ""
	var sidestep_distance := 0.0
	var invulnerability := 0.0
	var reactive_triggered := false
	var last_stand_triggered := false
	var absorbed := 0.0
	var support_absorbed := 0.0

	var evade := special_effect(snapshot, "evade_drill")
	if not evade.is_empty() and float(state["evade_cooldown"]) <= 0.0 and damage_kind in ["projectile", "homing_projectile"]:
		var excluded: Array = Array(evade.get("excluded_damage_kinds", []))
		if damage_kind not in excluded:
			evaded = true
			evade_kind = "evade_drill"
			sidestep_distance = maxf(0.0, _first_number(evade, ["sidestep_distance"], 0.0))
			invulnerability = maxf(invulnerability, _first_number(evade, ["invulnerability"], 0.0))
			state["evade_cooldown"] = maxf(0.0, _first_number(evade, ["cooldown"], 0.0))
			damage = 0.0

	var aerial := special_effect(snapshot, "aerial_evade")
	var is_air := str(soldier.get("domain", "ground")) == "air"
	if not evaded and is_air and not aerial.is_empty() and float(state["aerial_evade_cooldown"]) <= 0.0 and damage_kind in ["projectile", "homing_projectile", "area"]:
		evade_kind = "aerial_evade"
		sidestep_distance = maxf(0.0, _first_number(aerial, ["sidestep_distance"], 0.0))
		var aerial_reduction := clampf(_first_number(aerial, ["damage_reduction"], 0.0), 0.0, 1.0)
		damage *= 1.0 - aerial_reduction
		state["aerial_evade_cooldown"] = maxf(0.0, _first_number(aerial, ["cooldown"], 0.0))

	var taunt := special_effect(snapshot, "taunt_guard")
	if not taunt.is_empty():
		damage *= 1.0 - clampf(_first_number(taunt, ["self_damage_reduction"], 0.0), 0.0, 0.95)

	var reactive := special_effect(snapshot, "reactive_armor")
	if not reactive.is_empty() and float(state["reactive_armor_cooldown"]) <= 0.0 and damage_kind in ["projectile", "area"] and damage > 0.0:
		reactive_triggered = true
		damage *= 1.0 - clampf(_first_number(reactive, ["next_projectile_or_area_reduction", "damage_reduction"], 0.0), 0.0, 0.95)
		state["reactive_armor_cooldown"] = maxf(0.0, _first_number(reactive, ["cooldown"], 0.0))

	# Kinetic Barrier is consumed before the rechargeable general-purpose shield.
	if damage > 0.0:
		var kinetic_absorb := minf(damage, float(state["kinetic_barrier"]))
		if kinetic_absorb > 0.0:
			state["kinetic_barrier"] = float(state["kinetic_barrier"]) - kinetic_absorb
			damage -= kinetic_absorb
			absorbed += kinetic_absorb
	if damage > 0.0:
		var shield_absorb := minf(damage, float(state["tactical_shield"]))
		if shield_absorb > 0.0:
			state["tactical_shield"] = float(state["tactical_shield"]) - shield_absorb
			damage -= shield_absorb
			absorbed += shield_absorb
			var tactical_effect := special_effect(snapshot, "tactical_shield")
			state["tactical_shield_recharge"] = maxf(0.0, _first_number(tactical_effect, ["recharge_no_hit_time", "recharge_time"], 12.0))
	# Healing shields are real damage buffers too. Consume them before checking
	# Last Stand so a fully shielded hit cannot waste the one-time survival proc.
	if damage > 0.0:
		support_absorbed = minf(damage, maxf(0.0, _finite_float(soldier.get("support_shield", 0.0), 0.0)))
		if support_absorbed > 0.0:
			soldier["support_shield"] = maxf(0.0, float(soldier.get("support_shield", 0.0)) - support_absorbed)
			damage -= support_absorbed
			absorbed += support_absorbed

	var hp := maxf(0.0, _finite_float(soldier.get("hp", 0.0), 0.0))
	var survive_hp := 0.0
	var last_stand := special_effect(snapshot, "last_stand")
	if damage > 0.0 and damage >= hp and hp > 0.0 and not bool(state["last_stand_used"]) and not last_stand.is_empty():
		last_stand_triggered = true
		state["last_stand_used"] = true
		survive_hp = clampf(_first_number(last_stand, ["survive_hp"], 1.0), 1.0, hp)
		damage = maxf(0.0, hp - survive_hp)
		invulnerability = maxf(invulnerability, _first_number(last_stand, ["invulnerability"], 0.0))

	var vengeance := special_effect(snapshot, "vengeance_counter")
	if damage > 0.0 and not vengeance.is_empty():
		var max_stacks := maxi(1, _first_integer(vengeance, ["hits_taken", "max_stacks", "counter_max", "stacks"], 10))
		var stacks_per_hit := maxi(1, _first_integer(vengeance, ["stacks_per_hit", "counter_per_hit"], 1))
		state["vengeance_stacks"] = mini(max_stacks, int(state["vengeance_stacks"]) + stacks_per_hit)
		state["vengeance_damage_bank"] = float(state["vengeance_damage_bank"]) + damage

	soldier["special_runtime"] = state
	return {
		"raw_damage": original_damage,
		"damage": maxf(0.0, damage),
		"absorbed": absorbed,
		"support_absorbed": support_absorbed,
		"evaded": evaded,
		"evade_kind": evade_kind,
		"sidestep_distance": sidestep_distance,
		"invulnerability": invulnerability,
		"reactive_armor_triggered": reactive_triggered,
		"last_stand_triggered": last_stand_triggered,
		"survive_hp": survive_hp,
	}


static func catalog_ids_consumed() -> Array[String]:
	return CATALOG_IDS.duplicate()


static func self_test() -> Dictionary:
	var errors: Array[String] = []
	var snapshot := {
		"base_effects": {
			"critical_chance": 1.0,
			"critical_multiplier": 1.5,
			"critical_mode": "damage",
		},
		"special_effects": {
			"execution_protocol": {"target_hp_threshold": 0.30, "damage_bonus_ratio": 0.50},
			"temporal_echo": {"trigger_every_attacks": 1, "echo_damage_ratio": 0.40, "delay": 0.20},
			"overcharge_capacitor": {"trigger_every_attacks": 1, "damage_bonus_ratio": 0.25, "bonus_radius": 18.0},
			"vengeance_counter": {"hits_taken": 2, "next_attack_damage_bonus": 0.40},
			"armor_piercing_core": {"ignored_armor": 12.0},
			"piercing_arrow": {"extra_pierce": 2, "retained_damage_ratio": 0.84},
			"homing_guidance": {"turn_degrees_per_second": 150.0, "until_expiry": true},
			"kinetic_barrier": {"move_distance": 300.0, "shield_max_hp_ratio": 0.10, "duration": 5.0},
		},
	}
	var first_soldier := {"id": 77, "type": "archer", "hp": 100.0, "max_hp": 100.0, "upgrade_snapshot": snapshot}
	var second_soldier := first_soldier.duplicate(true)
	first_soldier["special_runtime"] = create_state(snapshot, 100.0)
	second_soldier["special_runtime"] = create_state(snapshot, 100.0)
	first_soldier["special_runtime"]["vengeance_stacks"] = 2
	second_soldier["special_runtime"]["vengeance_stacks"] = 2
	var first_attack := begin_attack(first_soldier, 0.20)
	var second_attack := begin_attack(second_soldier, 0.20)
	_assert_test(first_attack == second_attack, "deterministic_attack_context", errors)
	_assert_test(bool(first_attack["is_critical"]) and bool(first_attack["execution_triggered"]), "critical_and_execution", errors)
	_assert_test(bool(first_attack["echo"]) and bool(first_attack["overcharge_triggered"]) and is_equal_approx(float(first_attack["bonus_radius"]), 18.0), "echo_and_overcharge", errors)
	_assert_test(float(first_attack["damage_multiplier"]) > 2.0 and int(first_soldier["special_runtime"]["vengeance_stacks"]) == 0, "vengeance_consumed", errors)

	var projectile := decorate_projectile(
		{"team": "friendly", "kind": "ally_arrow", "damage": 20.0, "pierce": 1, "falloff": 1.0, "aoe": 0.0, "target_id": 9},
		first_soldier,
		first_attack
	)
	_assert_test(float(projectile["damage"]) > 40.0 and int(projectile["pierce"]) == 3, "projectile_damage_and_pierce", errors)
	_assert_test(is_equal_approx(float(projectile["armor_penetration"]), 12.0) and bool(projectile["homing"]), "projectile_armor_and_homing", errors)
	_assert_test(projectile.has("soldier_specials") and projectile.has("soldier_attack_context") and bool(projectile["allow_special_generation"]), "projectile_snapshot_copy", errors)
	var child_data := projectile.duplicate(true)
	child_data["special_generation"] = 1
	var child := decorate_projectile(child_data, first_soldier, first_attack)
	_assert_test(not bool(child["allow_special_generation"]), "generated_projectile_cannot_recurse", errors)

	var old_snapshot := {
		"active_specials": [{"id": "burning_sword", "rank": 1, "effect": {"duration": 3.0, "total_burn_ratio": 0.24}}],
	}
	_assert_test(is_equal_approx(float(special_effect(old_snapshot, "burning_sword").get("duration", 0.0)), 3.0), "old_snapshot_fallback", errors)
	var normalized := normalize_state({"attack_sequence": -20, "reactive_armor_cooldown": -5.0, "vengeance_stacks": 999}, snapshot, 100.0)
	_assert_test(int(normalized["attack_sequence"]) == 0 and is_zero_approx(float(normalized["reactive_armor_cooldown"])) and int(normalized["vengeance_stacks"]) == 2, "runtime_normalization", errors)
	var movement_soldier := {"id": 90, "hp": 100.0, "max_hp": 100.0, "upgrade_snapshot": snapshot, "special_runtime": create_state(snapshot, 100.0)}
	var movement_activation := record_movement(movement_soldier, 300.0)
	_assert_test(bool(movement_activation["activated"]) and is_equal_approx(float(movement_activation["shield"]), 10.0), "kinetic_barrier_movement_activation", errors)

	var last_stand_snapshot := {"base_effects": {}, "special_effects": {"last_stand": {"survive_hp": 1.0, "invulnerability": 2.0}}}
	var last_stand_soldier := {"id": 91, "hp": 50.0, "max_hp": 100.0, "support_shield": 80.0, "upgrade_snapshot": last_stand_snapshot, "special_runtime": create_state(last_stand_snapshot, 100.0)}
	var shielded_lethal_plan := incoming_damage_plan(last_stand_soldier, "projectile", 70.0)
	_assert_test(is_zero_approx(float(shielded_lethal_plan["damage"])) and not bool(shielded_lethal_plan["last_stand_triggered"]) and is_equal_approx(float(last_stand_soldier["support_shield"]), 10.0), "support_shield_precedes_last_stand", errors)
	var exposed_lethal_plan := incoming_damage_plan(last_stand_soldier, "projectile", 70.0)
	_assert_test(bool(exposed_lethal_plan["last_stand_triggered"]) and is_equal_approx(float(exposed_lethal_plan["damage"]), 49.0) and is_zero_approx(float(last_stand_soldier["support_shield"])), "last_stand_triggers_after_support_shield_breaks", errors)

	var id_seen: Dictionary = {}
	for ability_id in catalog_ids_consumed():
		id_seen[ability_id] = true
	_assert_test(CATALOG_IDS.size() == 57 and id_seen.size() == 57, "catalog_coverage_57", errors)
	return {"ok": errors.is_empty(), "errors": errors, "catalog_ids": CATALOG_IDS.size()}


static func _soldier_snapshot(soldier: Dictionary) -> Dictionary:
	return _as_dictionary(soldier.get("upgrade_snapshot", {}))


static func _snapshot_special_map(snapshot: Variant) -> Dictionary:
	var result: Dictionary = {}
	for ability_id in CATALOG_IDS:
		var effect := special_effect(snapshot, ability_id)
		if not effect.is_empty():
			result[ability_id] = effect
	return result


static func _tick_recharging_pool(state: Dictionary, prefix: String, delta: float) -> void:
	var maximum_key := "%s_max" % prefix
	var recharge_key := "%s_recharge" % prefix
	if float(state.get(maximum_key, 0.0)) <= 0.0:
		state[prefix] = 0.0
		state[recharge_key] = 0.0
		return
	state[recharge_key] = maxf(0.0, float(state.get(recharge_key, 0.0)) - delta)
	if float(state[recharge_key]) <= 0.0:
		state[prefix] = float(state[maximum_key])


static func _effect_multiplier(effect: Dictionary, total_keys: Array, bonus_keys: Array, fallback: float) -> float:
	for key_value in total_keys:
		var key := str(key_value)
		if effect.has(key):
			return clampf(_finite_float(effect[key], fallback), 0.0, MAX_REASONABLE_MULTIPLIER)
	for key_value in bonus_keys:
		var key := str(key_value)
		if effect.has(key):
			return clampf(1.0 + _finite_float(effect[key], 0.0), 0.0, MAX_REASONABLE_MULTIPLIER)
	return fallback


static func _first_number(source: Dictionary, keys: Array, fallback: float) -> float:
	for key_value in keys:
		var key := str(key_value)
		if source.has(key) and typeof(source[key]) in [TYPE_INT, TYPE_FLOAT]:
			return _finite_float(source[key], fallback)
	return fallback


static func _first_integer(source: Dictionary, keys: Array, fallback: int) -> int:
	for key_value in keys:
		var key := str(key_value)
		if source.has(key) and typeof(source[key]) in [TYPE_INT, TYPE_FLOAT]:
			return _safe_int(source[key], fallback)
	return fallback


static func _deterministic_unit_roll(entity_id: int, sequence: int, salt: int) -> float:
	var mixed := int(entity_id) * 73856093
	mixed = mixed ^ (int(sequence) * 19349663)
	mixed = mixed ^ int(salt)
	# Keep the value non-negative without calling abs(INT64_MIN).
	mixed = mixed & 0x7FFFFFFFFFFFFFFF
	return float(mixed % 1000000) / 1000000.0


static func _finite_float(value: Variant, fallback: float) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var converted := float(value)
	if is_nan(converted) or is_inf(converted):
		return fallback
	return converted


static func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var converted := _finite_float(value, float(fallback))
	if converted > float(0x7FFFFFFFFFFFFFFF):
		return 0x7FFFFFFFFFFFFFFF
	if converted < -float(0x7FFFFFFFFFFFFFFF):
		return -0x7FFFFFFFFFFFFFFF
	return int(converted)


static func _as_dictionary(value: Variant) -> Dictionary:
	return Dictionary(value) if value is Dictionary else {}


static func _assert_test(condition: bool, label: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(label)

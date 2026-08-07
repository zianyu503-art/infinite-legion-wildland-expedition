class_name ArenaController
extends RefCounted

## Pure, deterministic top-down arena setup and battle simulation.
##
## The controller owns no Nodes and never mutates the campaign wallet, permanent
## research, world soldiers, or enemies. Main only needs to forward setup input,
## call update(), and draw the public units/projectiles/effects arrays.

const GameConfig = preload("res://scripts/game_config.gd")
const SoldierUpgradeCatalog = preload("res://scripts/soldier_upgrade_catalog.gd")
const SoldierUpgradeRuntime = preload("res://scripts/soldier_upgrade_runtime.gd")
const SoldierUpgradeVfxCatalog = preload("res://scripts/soldier_upgrade_vfx_catalog.gd")

const MODES: Array[String] = ["challenge", "spectator"]
const PHASES: Array[String] = ["mode", "types", "counts", "upgrades", "battle", "result"]
const TEAMS: Array[String] = ["blue", "red"]
const UPGRADE_CATEGORIES: Array[String] = ["base", "special"]

const MIN_COUNT_PER_TYPE := 1
const MAX_COUNT_PER_TYPE := 30
const MAX_COUNT_PER_TEAM := 120
const DEFAULT_UPGRADE_PAGE_SIZE := 6
const FIXED_STEP := 1.0 / 60.0
const MAX_SUBSTEPS := 8
const TARGET_SCAN_INTERVAL := 0.30
const TARGET_SCAN_BUCKETS := 6
const PROJECTILE_RADIUS := 5.0
const DEFAULT_PROJECTILE_SPEED := 720.0
const RESULT_DELAY := 0.75
const MAX_BATTLE_UNITS := 250
const MAX_SUMMONS_PER_TEAM := 5
const MAX_PROJECTILES := 640
const MAX_EFFECTS := 768
const DEFAULT_ARENA_RECT := Rect2(Vector2(-480.0, -300.0), Vector2(960.0, 600.0))
const STATUS_KEYS: Array[String] = ["burn", "poison", "corrosion", "frost", "paralysis", "suppression", "void_mark", "focus_mark", "gravity"]

## Explicit arena semantics for every catalog special. Several handlers delegate
## their numerical core to SoldierUpgradeRuntime; the remainder are simplified,
## arena-appropriate versions of the campaign effect.
const SPECIAL_BEHAVIORS: Dictionary = {
	"burning_sword": "burn", "burning_ammo": "burn", "frost_arrow": "frost",
	"paralysis_arrow": "paralysis", "chain_lightning": "chain", "corrosion": "corrosion",
	"void_mark": "void_mark", "split_shot": "split", "piercing_arrow": "runtime_projectile",
	"penetrating_round": "runtime_projectile", "ricochet": "ricochet",
	"lingering_projectile": "lingering", "homing_guidance": "runtime_projectile",
	"armor_piercing_core": "runtime_projectile", "chain_explosion": "chain_explosion",
	"mine_round": "mine", "cluster_warhead": "cluster", "burning_zone": "burning_zone",
	"shockwave_round": "shockwave", "shrapnel_storm": "shrapnel",
	"siege_warhead": "large_target", "dash": "dash", "stomp": "stomp",
	"sweeping_slash": "sweep", "suppression": "suppression", "taunt_guard": "runtime_defense",
	"focus_mark": "focus_mark", "aerial_evade": "runtime_defense", "meteor": "meteor",
	"guardian": "guardian", "auto_turret": "turret", "repair_drone": "repair_drone",
	"self_repair": "self_repair", "tactical_shield": "runtime_defense",
	"last_stand": "runtime_defense", "lifesteal": "lifesteal",
	"reactive_armor": "runtime_defense", "evade_drill": "runtime_defense",
	"air_flares": "air_flares", "healing_mastery": "runtime_healing",
	"group_heal": "group_heal", "cleanse": "cleanse", "holy_shield": "holy_shield",
	"resurrection_ritual": "resurrection", "soul_shelter": "soul_shelter",
	"guardian_aura": "guardian_aura", "battlefield_repair": "battlefield_repair",
	"toxic_payload": "poison", "execution_protocol": "runtime_attack",
	"gravity_warhead": "gravity", "temporal_echo": "runtime_attack",
	"overcharge_capacitor": "runtime_attack", "kinetic_barrier": "runtime_movement",
	"rally_beacon": "rally", "overheal_matrix": "overheal",
	"vengeance_counter": "runtime_attack_defense", "salvage_protocol": "salvage",
}

var mode := "challenge"
var phase := "mode"
var active_team := "red"
var upgrade_category := "base"
var upgrade_page := 0
var selected_types: Dictionary = {}
var counts: Dictionary = {}
var team_research: Dictionary = {}
var upgrade_type_indices: Dictionary = {}

## Public battle collections. The renderer must treat their dictionaries as
## read-only; update() mutates records in place to avoid per-frame deep copies.
var units: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var hero: Dictionary = {}
var arena_rect := DEFAULT_ARENA_RECT
var winner := ""
var battle_time := 0.0

var _next_entity_id := 1
var _fixed_accumulator := 0.0
var _result_timer := 0.0
var _last_hero_template: Dictionary = {}
var _unit_by_id: Dictionary = {}
var _team_unit_ids: Dictionary = {"blue": [], "red": []}
var _alive_counts: Dictionary = {"blue": 0, "red": 0}
var _summon_counts: Dictionary = {"blue": 0, "red": 0}
var _team_shared_cooldowns: Dictionary = {"blue": {}, "red": {}}


func _init() -> void:
	reset_setup()


func reset_setup() -> void:
	mode = "challenge"
	phase = "mode"
	active_team = "red"
	upgrade_category = "base"
	upgrade_page = 0
	selected_types = {"blue": [], "red": []}
	counts = {"blue": {}, "red": {}}
	team_research = {
		"blue": SoldierUpgradeCatalog.create_empty_research(),
		"red": SoldierUpgradeCatalog.create_empty_research(),
	}
	upgrade_type_indices = {"blue": 0, "red": 0}
	_clear_battle()


func choose_mode(value: String) -> bool:
	if value not in MODES or phase not in ["mode", "types"]:
		return false
	mode = value
	phase = "types"
	active_team = "red" if mode == "challenge" else "blue"
	return true


func set_active_team(team: String) -> bool:
	if team not in TEAMS:
		return false
	active_team = team
	upgrade_page = 0
	return true


func toggle_type(type_id: String, team: String = "") -> bool:
	var chosen_team := _resolved_team(team)
	if phase != "types" or chosen_team.is_empty() or not SoldierUpgradeCatalog.has_soldier_type(type_id):
		return false
	var choices: Array = selected_types[chosen_team]
	var team_counts: Dictionary = counts[chosen_team]
	if type_id in choices:
		choices.erase(type_id)
		team_counts.erase(type_id)
	else:
		choices.append(type_id)
		team_counts[type_id] = MIN_COUNT_PER_TYPE
	selected_types[chosen_team] = choices
	counts[chosen_team] = team_counts
	upgrade_type_indices[chosen_team] = clampi(int(upgrade_type_indices[chosen_team]), 0, maxi(0, choices.size() - 1))
	return true


func confirm_types() -> bool:
	if phase != "types":
		return false
	if Array(selected_types["red"]).is_empty():
		return false
	if mode == "spectator" and Array(selected_types["blue"]).is_empty():
		return false
	phase = "counts"
	return true


func adjust_count(type_id: String, delta: int, team: String = "") -> int:
	var chosen_team := _resolved_team(team)
	if phase != "counts" or chosen_team.is_empty() or type_id not in Array(selected_types[chosen_team]):
		return -1
	var team_counts: Dictionary = counts[chosen_team]
	var current := int(team_counts.get(type_id, MIN_COUNT_PER_TYPE))
	var desired := clampi(current + delta, MIN_COUNT_PER_TYPE, MAX_COUNT_PER_TYPE)
	if desired > current:
		desired = mini(desired, current + maxi(0, MAX_COUNT_PER_TEAM - team_total(chosen_team)))
	team_counts[type_id] = desired
	counts[chosen_team] = team_counts
	return desired


func confirm_counts() -> bool:
	if phase != "counts":
		return false
	for team_value in TEAMS:
		var team := str(team_value)
		if team == "blue" and mode == "challenge" and Array(selected_types[team]).is_empty():
			continue
		if team_total(team) <= 0 or team_total(team) > MAX_COUNT_PER_TEAM:
			return false
		for type_value in Array(selected_types[team]):
			var amount := count_for(team, str(type_value))
			if amount < MIN_COUNT_PER_TYPE or amount > MAX_COUNT_PER_TYPE:
				return false
	phase = "upgrades"
	upgrade_page = 0
	return true


func cycle_upgrade_type(direction: int = 1, team: String = "") -> String:
	var chosen_team := _resolved_team(team)
	if chosen_team.is_empty():
		return ""
	var choices: Array = selected_types[chosen_team]
	if choices.is_empty():
		return ""
	var step := 1 if direction >= 0 else -1
	upgrade_type_indices[chosen_team] = posmod(int(upgrade_type_indices[chosen_team]) + step, choices.size())
	upgrade_page = 0
	return str(choices[int(upgrade_type_indices[chosen_team])])


func current_upgrade_type(team: String = "") -> String:
	var chosen_team := _resolved_team(team)
	if chosen_team.is_empty():
		return ""
	var choices: Array = selected_types[chosen_team]
	if choices.is_empty():
		return ""
	var index := clampi(int(upgrade_type_indices[chosen_team]), 0, choices.size() - 1)
	return str(choices[index])


func set_upgrade_category(category: String) -> bool:
	if category not in UPGRADE_CATEGORIES:
		return false
	upgrade_category = category
	upgrade_page = 0
	return true


func set_upgrade_page(page: int, page_size: int = DEFAULT_UPGRADE_PAGE_SIZE) -> int:
	var page_count := upgrade_page_count(page_size)
	upgrade_page = clampi(page, 0, maxi(0, page_count - 1))
	return upgrade_page


func upgrade_ids(team: String = "", type_id: String = "", category: String = "") -> Array[String]:
	var chosen_team := _resolved_team(team)
	var chosen_type := type_id if not type_id.is_empty() else current_upgrade_type(chosen_team)
	var chosen_category := category if category in UPGRADE_CATEGORIES else upgrade_category
	if chosen_team.is_empty() or chosen_type.is_empty():
		return []
	if chosen_category == "base":
		return SoldierUpgradeCatalog.compatible_base_ids(chosen_type)
	return SoldierUpgradeCatalog.compatible_special_ids(chosen_type)


func upgrade_page_count(page_size: int = DEFAULT_UPGRADE_PAGE_SIZE, team: String = "", type_id: String = "", category: String = "") -> int:
	var safe_page_size := maxi(1, page_size)
	var ids := upgrade_ids(team, type_id, category)
	return maxi(1, ceili(float(ids.size()) / float(safe_page_size)))


func upgrade_options(page_size: int = DEFAULT_UPGRADE_PAGE_SIZE, team: String = "", type_id: String = "", category: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var chosen_team := _resolved_team(team)
	var chosen_type := type_id if not type_id.is_empty() else current_upgrade_type(chosen_team)
	var chosen_category := category if category in UPGRADE_CATEGORIES else upgrade_category
	if chosen_team.is_empty() or chosen_type.is_empty():
		return result
	var ids := upgrade_ids(chosen_team, chosen_type, chosen_category)
	var safe_page_size := maxi(1, page_size)
	var first := clampi(upgrade_page, 0, maxi(0, upgrade_page_count(safe_page_size, chosen_team, chosen_type, chosen_category) - 1)) * safe_page_size
	var last := mini(ids.size(), first + safe_page_size)
	for index in range(first, last):
		var upgrade_id := str(ids[index])
		var definition := SoldierUpgradeCatalog.definition_for(upgrade_id)
		definition["id"] = upgrade_id
		definition["category"] = chosen_category
		definition["rank"] = SoldierUpgradeCatalog.current_rank(chosen_type, upgrade_id, team_research[chosen_team])
		definition["max_rank"] = SoldierUpgradeCatalog.max_rank(upgrade_id)
		definition["visual"] = SoldierUpgradeVfxCatalog.descriptor(upgrade_id) if chosen_category == "special" else {}
		result.append(definition)
	return result


func adjust_upgrade(upgrade_id: String, delta: int, team: String = "", type_id: String = "") -> int:
	var chosen_team := _resolved_team(team)
	var chosen_type := type_id if not type_id.is_empty() else current_upgrade_type(chosen_team)
	if phase != "upgrades" or chosen_team.is_empty() or chosen_type.is_empty():
		return -1
	if chosen_type not in Array(selected_types[chosen_team]) or not SoldierUpgradeCatalog.is_compatible(chosen_type, upgrade_id):
		return -1
	var category := SoldierUpgradeCatalog.category_for(upgrade_id)
	if category.is_empty():
		return -1
	var research: Dictionary = team_research[chosen_team]
	var current := SoldierUpgradeCatalog.current_rank(chosen_type, upgrade_id, research)
	var target := clampi(current + delta, 0, SoldierUpgradeCatalog.max_rank(upgrade_id))
	if target == current:
		return current
	if category == "special" and target > current:
		var prerequisite := SoldierUpgradeCatalog.prerequisite_for_rank(chosen_type, upgrade_id, target)
		var base_id := str(prerequisite.get("base_upgrade", ""))
		var required_rank := int(prerequisite.get("base_rank", 0))
		if not base_id.is_empty():
			_set_raw_research_rank(research, chosen_type, "base", base_id, maxi(required_rank, SoldierUpgradeCatalog.current_rank(chosen_type, base_id, research)))
	_set_raw_research_rank(research, chosen_type, category, upgrade_id, target)
	team_research[chosen_team] = SoldierUpgradeCatalog.sanitize_research(research)
	return SoldierUpgradeCatalog.current_rank(chosen_type, upgrade_id, team_research[chosen_team])


func selected_types_for(team: String) -> Array:
	return Array(selected_types.get(team, []))


func count_for(team: String, type_id: String) -> int:
	return int(Dictionary(counts.get(team, {})).get(type_id, 0))


func team_total(team: String) -> int:
	if team not in TEAMS:
		return 0
	var total := 0
	var team_counts: Dictionary = counts[team]
	for type_value in Array(selected_types[team]):
		total += int(team_counts.get(str(type_value), 0))
	return total


func start_battle(hero_template: Dictionary = {}) -> bool:
	if phase not in ["upgrades", "result"]:
		return false
	if Array(selected_types["red"]).is_empty() or team_total("red") <= 0:
		return false
	if mode == "spectator" and (Array(selected_types["blue"]).is_empty() or team_total("blue") <= 0):
		return false
	_last_hero_template = hero_template.duplicate(true)
	_initialize_battle(_last_hero_template)
	return true


func restart_battle() -> bool:
	if phase not in ["battle", "result"]:
		return false
	_initialize_battle(_last_hero_template)
	return true


## Leaves a running/completed match without destroying its setup choices.
## A subsequent start_battle() creates a fresh simulation from the preserved
## mode, selected types, counts, and arena-only research.
func return_to_setup() -> bool:
	if phase not in ["battle", "result"]:
		return false
	_clear_battle()
	_last_hero_template = {}
	phase = "upgrades"
	return true


func update(delta: float, hero_input: Dictionary = {}) -> void:
	if phase != "battle":
		return
	_fixed_accumulator = minf(_fixed_accumulator + clampf(delta, 0.0, 0.25), FIXED_STEP * float(MAX_SUBSTEPS))
	var substeps := 0
	while _fixed_accumulator >= FIXED_STEP and substeps < MAX_SUBSTEPS:
		_step_battle(FIXED_STEP, hero_input)
		_fixed_accumulator -= FIXED_STEP
		substeps += 1


func render_state() -> Dictionary:
	return {
		"mode": mode,
		"phase": phase,
		"stage": phase,
		"active_team": active_team,
		"upgrade_category": upgrade_category,
		"upgrade_page": upgrade_page,
		"selected_types": selected_types,
		"counts": counts,
		"team_research": team_research,
		"teams": {
			"blue": {"types": selected_types["blue"], "counts": counts["blue"], "research": team_research["blue"], "alive": int(_alive_counts["blue"])},
			"red": {"types": selected_types["red"], "counts": counts["red"], "research": team_research["red"], "alive": int(_alive_counts["red"])},
		},
		"arena": arena_rect,
		"bounds": arena_rect,
		"units": units,
		"projectiles": projectiles,
		"effects": effects,
		"hero": hero,
		"no_player": hero.is_empty(),
		"winner": winner,
		"battle_time": battle_time,
	}


static func soldier_radius(type_id: String) -> float:
	match type_id:
		"archer": return 9.0
		"healer", "mage": return 10.0
		"heavy": return 15.0
		"musketeer": return 11.0
		"rifleman": return 12.0
		"cannon": return 19.0
		"tank": return 29.0
		"rocket": return 22.0
		"gatling": return 18.0
		"helicopter": return 30.0
		"bomber": return 35.0
		"ufo": return 38.0
		_: return 11.0


func _resolved_team(team: String) -> String:
	var result := active_team if team.is_empty() else team
	return result if result in TEAMS else ""


func _set_raw_research_rank(research: Dictionary, type_id: String, category: String, upgrade_id: String, rank: int) -> void:
	var all_types: Dictionary = research.get("types", {})
	var type_research: Dictionary = all_types.get(type_id, {})
	var ranks: Dictionary = type_research.get(category, {})
	ranks[upgrade_id] = rank
	type_research[category] = ranks
	all_types[type_id] = type_research
	research["types"] = all_types


func _clear_battle() -> void:
	units.clear()
	projectiles.clear()
	effects.clear()
	hero = {}
	arena_rect = DEFAULT_ARENA_RECT
	winner = ""
	battle_time = 0.0
	_next_entity_id = 1
	_fixed_accumulator = 0.0
	_result_timer = 0.0
	_unit_by_id.clear()
	_team_unit_ids = {"blue": [], "red": []}
	_alive_counts = {"blue": 0, "red": 0}
	_summon_counts = {"blue": 0, "red": 0}
	_team_shared_cooldowns = {"blue": {}, "red": {}}


func _initialize_battle(hero_template: Dictionary) -> void:
	_clear_battle()
	arena_rect = _calculate_arena_rect()
	for team_value in TEAMS:
		_spawn_team(str(team_value))
	if mode == "challenge":
		hero = _create_hero(hero_template)
	else:
		hero = {}
	phase = "battle"


func _calculate_arena_rect() -> Rect2:
	var total := team_total("blue") + team_total("red")
	if mode == "challenge":
		total += 1
	var maximum_radius := 11.0
	var footprint_area := 0.0
	for team_value in TEAMS:
		var team := str(team_value)
		for type_value in Array(selected_types[team]):
			var type_id := str(type_value)
			var radius := soldier_radius(type_id)
			maximum_radius = maxf(maximum_radius, radius)
			var padded_diameter := radius * 2.0 + 18.0
			footprint_area += float(count_for(team, type_id)) * padded_diameter * padded_diameter
	var packed_side := sqrt(maxf(1.0, footprint_area))
	var width := maxf(960.0, packed_side * 1.62 + maximum_radius * 8.0)
	var height := maxf(600.0, packed_side * 0.96 + maximum_radius * 6.0)
	# Keep extreme 240-unit galleries bounded while retaining a radius-aware margin.
	width = minf(width, 3200.0)
	height = minf(height, 2000.0)
	var size := Vector2(ceilf(width / 16.0) * 16.0, ceilf(height / 16.0) * 16.0)
	return Rect2(-size * 0.5, size)


func _spawn_team(team: String) -> void:
	var total := team_total(team)
	if total <= 0:
		return
	var max_radius := 11.0
	for type_value in Array(selected_types[team]):
		max_radius = maxf(max_radius, soldier_radius(str(type_value)))
	var spacing := maxf(34.0, max_radius * 2.0 + 16.0)
	var depth_count := maxi(1, ceili(sqrt(float(total) * 0.72)))
	var lane_count := maxi(1, ceili(float(total) / float(depth_count)))
	var direction := 1.0 if team == "blue" else -1.0
	var front_x := arena_rect.get_center().x - direction * minf(arena_rect.size.x * 0.27, 480.0)
	var index := 0
	for type_value in Array(selected_types[team]):
		var type_id := str(type_value)
		for _count_index in count_for(team, type_id):
			var depth := index % depth_count
			var lane := index / depth_count
			var lane_offset := (float(lane) - float(lane_count - 1) * 0.5) * spacing
			var position := Vector2(front_x - direction * float(depth) * spacing, arena_rect.get_center().y + lane_offset)
			var unit := _create_unit(type_id, team, _clamp_to_arena(position, soldier_radius(type_id)))
			units.append(unit)
			_unit_by_id[int(unit["id"])] = unit
			var ids: Array = _team_unit_ids[team]
			ids.append(int(unit["id"]))
			_team_unit_ids[team] = ids
			_alive_counts[team] = int(_alive_counts[team]) + 1
			index += 1


func _create_unit(type_id: String, team: String, position: Vector2) -> Dictionary:
	var config: Dictionary = GameConfig.SOLDIERS[type_id]
	var combat: Dictionary = config["combat"]
	var snapshot := SoldierUpgradeCatalog.snapshot_for_type(type_id, team_research[team])
	var base_effects: Dictionary = snapshot.get("base_effects", {})
	var hp_bonus := maxf(0.0, float(base_effects.get("max_hp_bonus", 0.0)))
	var output_bonus := maxf(0.0, float(base_effects.get("attack_or_healing_bonus", 0.0)))
	var speed_bonus := maxf(0.0, float(base_effects.get("move_speed_bonus", 0.0)))
	var rate_bonus := maxf(0.0, float(base_effects.get("attack_or_support_speed_bonus", 0.0)))
	var range_bonus_ratio := maxf(0.0, float(base_effects.get("range_bonus_ratio", 0.0)))
	var range_bonus_px := maxf(0.0, float(base_effects.get("range_bonus_px", 0.0)))
	var maximum_hp := maxf(1.0, float(combat.get("hp", 100.0)) * (1.0 + hp_bonus))
	var attack_range := maxf(20.0, float(combat.get("range", 60.0)) * (1.0 + range_bonus_ratio) + range_bonus_px)
	var entity_id := _take_entity_id()
	var domain := str(combat.get("domain", "ground"))
	var unit := {
		"id": entity_id,
		"type": type_id,
		"team": team,
		"pos": position,
		"vel": Vector2.ZERO,
		"hp": maximum_hp,
		"max_hp": maximum_hp,
		"attack": maxf(1.0, float(combat.get("attack", 10.0)) * (1.0 + output_bonus)),
		"defense": maxf(0.0, float(combat.get("armor", 0.0)) + float(base_effects.get("armor_bonus", 0.0))),
		"speed": maxf(1.0, float(combat.get("movement_speed", 100.0)) * (1.0 + speed_bonus)),
		"range": attack_range,
		"attack_rate": maxf(0.05, float(combat.get("attack_speed", 1.0)) * (1.0 + rate_bonus)),
		"radius": soldier_radius(type_id),
		"domain": domain,
		"altitude": 28.0 if domain == "air" else 0.0,
		"cooldown": 0.15 + float(entity_id % 7) * 0.035,
		"state": "idle",
		"target_id": -1,
		"target_kind": "",
		"target_scan_timer": float(entity_id % TARGET_SCAN_BUCKETS) * TARGET_SCAN_INTERVAL / float(TARGET_SCAN_BUCKETS),
		"flash": 0.0,
		"charge": 0.0,
		"aim_dir": Vector2.RIGHT if team == "blue" else Vector2.LEFT,
		"upgrade_snapshot": snapshot,
		"special_runtime": {},
		"upgrade_cooldowns": {},
		"support_shield": 0.0,
		"holy_shield": 0.0,
		"holy_shield_ttl": 0.0,
		"holy_shield_cooldowns": {},
		"overheal_shield": 0.0,
		"overheal_shield_ttl": 0.0,
		"invulnerability": 0.0,
		"last_damage_time": -1000.0,
		"last_stand_recovery_ttl": 0.0,
		"last_stand_recovery_per_second": 0.0,
		"post_revive_reduction": 0.0,
		"post_revive_reduction_ttl": 0.0,
		"dash_damage_reduction": 0.0,
		"dash_reduction_ttl": 0.0,
		"statuses": {},
		"arena_hit_counters": {},
		"arena_proc_cooldowns": {},
		"summoned": false,
		"summon_ttl": -1.0,
		"summon_owner_id": -1,
		"arena_aura_damage": 1.0,
		"arena_aura_attack_speed": 1.0,
		"arena_aura_move_speed": 1.0,
		"arena_aura_damage_taken": 1.0,
		"combat": combat,
	}
	unit["special_runtime"] = SoldierUpgradeRuntime.create_state(snapshot, maximum_hp)
	return unit


func _create_hero(template: Dictionary) -> Dictionary:
	var maximum_hp := maxf(1.0, float(template.get("max_hp", template.get("hp", 360.0))))
	var radius := clampf(float(template.get("radius", 15.0)), 8.0, 48.0)
	var requested_class := str(template.get("class_id", "archer"))
	var class_id := requested_class if requested_class in ["archer", "mage", "warrior"] else "archer"
	var result := template.duplicate(true)
	result["id"] = 0
	result["kind"] = "hero"
	result["class_id"] = class_id
	result["attack_kind"] = "melee" if class_id == "warrior" else ("arrow" if class_id == "archer" else "magic")
	result["team"] = "blue"
	result["pos"] = _clamp_to_arena(Vector2(arena_rect.position.x + arena_rect.size.x * 0.20, arena_rect.get_center().y), radius)
	result["vel"] = Vector2.ZERO
	result["max_hp"] = maximum_hp
	result["hp"] = clampf(float(template.get("hp", maximum_hp)), 1.0, maximum_hp)
	result["attack"] = maxf(1.0, float(template.get("attack", template.get("damage", 34.0))))
	result["defense"] = maxf(0.0, float(template.get("defense", template.get("armor", 8.0))))
	result["speed"] = maxf(1.0, float(template.get("speed", template.get("move_speed", 180.0))))
	result["range"] = maxf(30.0, float(template.get("range", 390.0)))
	result["attack_rate"] = maxf(0.1, float(template.get("attack_rate", template.get("attack_speed", 1.7))))
	result["radius"] = radius
	result["cooldown"] = 0.0
	result["flash"] = 0.0
	result["aim_dir"] = Vector2.RIGHT
	result["target_id"] = -1
	result["target_kind"] = "unit"
	result["support_shield"] = 0.0
	result["holy_shield"] = 0.0
	result["holy_shield_ttl"] = 0.0
	result["holy_shield_cooldowns"] = {}
	result["overheal_shield"] = 0.0
	result["overheal_shield_ttl"] = 0.0
	result["last_stand_recovery_ttl"] = 0.0
	result["last_stand_recovery_per_second"] = 0.0
	result["post_revive_reduction_ttl"] = 0.0
	result["post_revive_reduction"] = 0.0
	return result


func _take_entity_id() -> int:
	var result := _next_entity_id
	_next_entity_id += 1
	return result


func _clamp_to_arena(position: Vector2, radius: float) -> Vector2:
	var minimum := arena_rect.position + Vector2.ONE * radius
	var maximum := arena_rect.end - Vector2.ONE * radius
	return Vector2(clampf(position.x, minimum.x, maximum.x), clampf(position.y, minimum.y, maximum.y))


func _step_battle(delta: float, hero_input: Dictionary) -> void:
	battle_time += delta
	_tick_team_shared_cooldowns(delta)
	_update_hero(delta, hero_input)
	for unit in units:
		if float(unit.get("hp", 0.0)) > 0.0:
			_update_unit(unit, delta)
	_update_projectiles(delta)
	_update_effects(delta)
	_cleanup_dead_units()
	if projectiles.size() > MAX_PROJECTILES:
		projectiles.resize(MAX_PROJECTILES)
	if effects.size() > MAX_EFFECTS:
		effects.resize(MAX_EFFECTS)
	_check_battle_result(delta)


func _update_hero(delta: float, input: Dictionary) -> void:
	if hero.is_empty() or float(hero.get("hp", 0.0)) <= 0.0:
		return
	hero["flash"] = maxf(0.0, float(hero.get("flash", 0.0)) - delta)
	hero["cooldown"] = maxf(0.0, float(hero.get("cooldown", 0.0)) - delta)
	_tick_temporary_recovery_and_shields(hero, delta)
	var movement_value: Variant = input.get("move", input.get("move_dir", Vector2.ZERO))
	var movement: Vector2 = movement_value if movement_value is Vector2 else Vector2.ZERO
	if movement.length_squared() > 1.0:
		movement = movement.normalized()
	var velocity: Vector2 = movement * float(hero["speed"])
	hero["vel"] = velocity
	if velocity.length_squared() > 0.001:
		hero["pos"] = _clamp_to_arena(Vector2(hero["pos"]) + velocity * delta, float(hero["radius"]))
	var aim_value: Variant = input.get("aim", input.get("aim_dir", Vector2.ZERO))
	var aim: Vector2 = aim_value if aim_value is Vector2 else Vector2.ZERO
	if aim.length_squared() > 0.001:
		hero["aim_dir"] = aim.normalized()
	var wants_attack := bool(input.get("attack", input.get("attack_pressed", false)))
	if not wants_attack or float(hero["cooldown"]) > 0.0:
		return
	var class_id := str(hero.get("class_id", "archer"))
	var target_range := float(hero["range"])
	if class_id == "warrior":
		target_range += float(hero["radius"]) + 28.0
	else:
		target_range += 80.0
	var target := _nearest_opposing_unit("blue", Vector2(hero["pos"]), target_range, true)
	if target.is_empty():
		return
	var target_delta := Vector2(target["pos"]) - Vector2(hero["pos"])
	if target_delta.length_squared() > 0.001:
		hero["aim_dir"] = target_delta.normalized()
	if class_id == "warrior":
		_perform_hero_melee(target)
	else:
		_spawn_hero_projectile(target, class_id)
	hero["cooldown"] = 1.0 / float(hero["attack_rate"])


func _perform_hero_melee(target: Dictionary) -> void:
	var visual_id := "hero_warrior_slash"
	var normal: Dictionary = GameConfig.NORMAL_ATTACKS["warrior"]
	_damage_unit(target, float(hero["attack"]), "melee", hero, 0.0, [visual_id])
	var offset := Vector2(target["pos"]) - Vector2(hero["pos"])
	var knockback := maxf(0.0, float(Dictionary(normal.get("effects", {})).get("knockback", 18.0)))
	if offset.length_squared() > 0.001 and float(target.get("hp", 0.0)) > 0.0:
		target["pos"] = _clamp_to_arena(Vector2(target["pos"]) + offset.normalized() * knockback, float(target["radius"]))
	hero["last_attack_kind"] = "melee"
	_add_visual_effect(visual_id, Vector2(hero["pos"]) + Vector2(hero["aim_dir"]) * 38.0, "blue", "hero_melee", 0.32)


func _spawn_hero_projectile(target: Dictionary, class_id: String) -> void:
	var normal: Dictionary = GameConfig.NORMAL_ATTACKS[class_id]
	var effects_data: Dictionary = normal.get("effects", {})
	var is_archer := class_id == "archer"
	var projectile_kind := "hero_arrow" if is_archer else "hero_magic"
	var visual_id := "hero_archer_arrow" if is_archer else "hero_mage_magic"
	var vfx_id := "piercing_arrow" if is_archer else "burning_zone"
	var before_count := projectiles.size()
	_spawn_basic_projectile(
		0,
		"hero",
		"blue",
		Vector2(hero["pos"]),
		int(target["id"]),
		"unit",
		float(hero["attack"]),
		float(hero["range"]),
		[visual_id],
		{},
		{}
	)
	if projectiles.size() <= before_count:
		return
	var projectile: Dictionary = projectiles[projectiles.size() - 1]
	var direction := Vector2(projectile["vel"]).normalized()
	var speed := maxf(1.0, float(normal.get("projectile_speed", DEFAULT_PROJECTILE_SPEED)))
	projectile["vel"] = direction * speed
	projectile["kind"] = projectile_kind
	projectile["attack_kind"] = "arrow" if is_archer else "magic"
	projectile["visual_id"] = visual_id
	projectile["ability_ids"] = [visual_id]
	projectile["vfx_layers"] = [vfx_id]
	projectile["color"] = Color(normal.get("projectile_color", Color.WHITE))
	projectile["aoe"] = 0.0 if is_archer else maxf(0.0, float(effects_data.get("blast_radius", 78.0)))
	projectile["armor_penetration"] = maxf(0.0, float(effects_data.get("armor_penetration", 0.0)))
	projectile["ttl"] = maxf(1.0, float(hero["range"]) / speed + 1.0)
	hero["last_attack_kind"] = projectile["attack_kind"]


func _update_unit(unit: Dictionary, delta: float) -> void:
	if float(unit.get("summon_ttl", -1.0)) >= 0.0:
		unit["summon_ttl"] = float(unit["summon_ttl"]) - delta
		if float(unit["summon_ttl"]) <= 0.0:
			unit["hp"] = 0.0
			_on_unit_killed(unit, {}, [str(unit.get("summon_ability_id", "guardian"))])
			return
	unit["flash"] = maxf(0.0, float(unit.get("flash", 0.0)) - delta)
	unit["cooldown"] = maxf(0.0, float(unit.get("cooldown", 0.0)) - delta)
	unit["invulnerability"] = maxf(0.0, float(unit.get("invulnerability", 0.0)) - delta)
	unit["target_scan_timer"] = float(unit.get("target_scan_timer", 0.0)) - delta
	_tick_runtime_state_in_place(unit, delta)
	_tick_temporary_recovery_and_shields(unit, delta)
	_tick_statuses(unit, delta)
	_tick_periodic_specials(unit, delta)
	if float(unit.get("hp", 0.0)) <= 0.0:
		return

	if _is_support_type(str(unit["type"])) and float(unit["cooldown"]) <= 0.0 and _perform_support_action(unit):
		unit["vel"] = Vector2.ZERO
		unit["state"] = "support"
		return

	if not _cached_target_is_valid(unit) or float(unit["target_scan_timer"]) <= 0.0:
		_refresh_unit_target(unit)
	if not _cached_target_is_valid(unit):
		unit["vel"] = Vector2.ZERO
		unit["state"] = "idle"
		return

	var target := _target_record(str(unit.get("target_kind", "unit")), int(unit.get("target_id", -1)))
	if target.is_empty():
		return
	var position := Vector2(unit["pos"])
	var target_position := Vector2(target["pos"])
	var offset := target_position - position
	var distance := offset.length()
	var direction := offset / distance if distance > 0.001 else Vector2.ZERO
	if direction.length_squared() > 0.001:
		unit["aim_dir"] = direction
	var target_radius := float(target.get("radius", 14.0))
	var attack_distance := float(unit["range"]) + target_radius
	if distance <= attack_distance:
		unit["vel"] = Vector2.ZERO
		unit["state"] = "attack"
		if float(unit["cooldown"]) <= 0.0 and not _status_active(unit, "paralysis"):
			_perform_unit_attack(unit, target, str(unit["target_kind"]))
		return

	var stop_distance := maxf(float(unit["radius"]) + target_radius + 4.0, attack_distance * 0.82)
	var arrival := clampf((distance - stop_distance) / 120.0, 0.22, 1.0)
	var speed_factor := _unit_movement_factor(unit)
	var velocity := direction * float(unit["speed"]) * speed_factor * arrival
	var before := position
	unit["pos"] = _clamp_to_arena(position + velocity * delta, float(unit["radius"]))
	unit["vel"] = velocity
	unit["state"] = "move"
	_record_runtime_movement_in_place(unit, before.distance_to(Vector2(unit["pos"])))


func _cached_target_is_valid(unit: Dictionary) -> bool:
	var kind := str(unit.get("target_kind", ""))
	var target_id := int(unit.get("target_id", -1))
	if kind == "hero":
		return mode == "challenge" and str(unit.get("team", "")) == "red" and not hero.is_empty() and float(hero.get("hp", 0.0)) > 0.0
	if kind != "unit" or not _unit_by_id.has(target_id):
		return false
	var target: Dictionary = _unit_by_id[target_id]
	return float(target.get("hp", 0.0)) > 0.0 and str(target.get("team", "")) != str(unit.get("team", "")) and _can_target_domain(unit, target)


func _refresh_unit_target(unit: Dictionary) -> void:
	var team := str(unit["team"])
	var opposing_team := "red" if team == "blue" else "blue"
	var position := Vector2(unit["pos"])
	var best_id := -1
	var best_kind := ""
	var best_score := INF
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if not _unit_by_id.has(target_id):
			continue
		var candidate: Dictionary = _unit_by_id[target_id]
		if float(candidate.get("hp", 0.0)) <= 0.0 or not _can_target_domain(unit, candidate):
			continue
		var score := position.distance_squared_to(Vector2(candidate["pos"]))
		var taunt := _special(candidate, "taunt_guard")
		if not taunt.is_empty() and position.distance_to(Vector2(candidate["pos"])) <= maxf(1.0, float(taunt.get("radius", 160.0))):
			score *= 0.35
		if score < best_score or (is_equal_approx(score, best_score) and target_id < best_id):
			best_score = score
			best_id = target_id
			best_kind = "unit"
	if team == "red" and mode == "challenge" and not hero.is_empty() and float(hero.get("hp", 0.0)) > 0.0:
		var hero_score := position.distance_squared_to(Vector2(hero["pos"]))
		if hero_score < best_score:
			best_id = 0
			best_kind = "hero"
	unit["target_id"] = best_id
	unit["target_kind"] = best_kind
	_refresh_unit_auras(unit)
	unit["target_scan_timer"] = TARGET_SCAN_INTERVAL + float(int(unit["id"]) % TARGET_SCAN_BUCKETS) * 0.006


func _target_record(kind: String, target_id: int) -> Dictionary:
	if kind == "hero":
		return hero
	if kind == "unit" and _unit_by_id.has(target_id):
		return _unit_by_id[target_id]
	return {}


func _can_target_domain(attacker: Dictionary, target: Dictionary) -> bool:
	if str(target.get("domain", "ground")) != "air":
		return true
	if str(attacker.get("domain", "ground")) == "air":
		return bool(Dictionary(attacker.get("combat", {})).get("can_target_air", true))
	return bool(Dictionary(attacker.get("combat", {})).get("can_target_air", false))


func _nearest_opposing_unit(team: String, position: Vector2, maximum_range: float = INF, ignore_domain: bool = false, attacker: Dictionary = {}) -> Dictionary:
	var opposing_team := "red" if team == "blue" else "blue"
	var best: Dictionary = {}
	var best_distance_squared := maximum_range * maximum_range
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if not _unit_by_id.has(target_id):
			continue
		var candidate: Dictionary = _unit_by_id[target_id]
		if float(candidate.get("hp", 0.0)) <= 0.0:
			continue
		if not ignore_domain and not attacker.is_empty() and not _can_target_domain(attacker, candidate):
			continue
		var distance_squared := position.distance_squared_to(Vector2(candidate["pos"]))
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = candidate
	return best


func _is_support_type(type_id: String) -> bool:
	return type_id in SoldierUpgradeCatalog.SUPPORT_TYPES


func _is_ranged(unit: Dictionary) -> bool:
	return float(unit.get("range", 0.0)) > 150.0 or Dictionary(unit.get("combat", {})).has("attack_style")


func _unit_movement_factor(unit: Dictionary) -> float:
	var factor := 1.0
	var statuses: Dictionary = unit.get("statuses", {})
	if statuses.has("frost"):
		factor *= 1.0 - clampf(float(Dictionary(statuses["frost"]).get("strength", 0.25)), 0.0, 0.8)
	if statuses.has("gravity"):
		factor *= 1.0 - clampf(float(Dictionary(statuses["gravity"]).get("strength", 0.25)), 0.0, 0.8)
	if statuses.has("suppression"):
		factor *= 1.0 - clampf(float(Dictionary(statuses["suppression"]).get("move_reduction", 0.2)), 0.0, 0.75)
	if statuses.has("paralysis"):
		factor = 0.0
	return factor * _rally_move_speed_multiplier(unit)


func _unit_attack_rate_factor(unit: Dictionary) -> float:
	var factor := 1.0
	var statuses: Dictionary = unit.get("statuses", {})
	if statuses.has("suppression"):
		factor *= 1.0 - clampf(float(Dictionary(statuses["suppression"]).get("attack_speed_reduction", 0.1)), 0.0, 0.75)
	if statuses.has("paralysis"):
		factor = 0.25
	return factor


func _perform_unit_attack(unit: Dictionary, target: Dictionary, target_kind: String) -> void:
	var target_hp_ratio := float(target.get("hp", 0.0)) / maxf(1.0, float(target.get("max_hp", 1.0)))
	var attack_context := SoldierUpgradeRuntime.begin_attack(unit, target_hp_ratio)
	attack_context["target_id"] = int(target.get("id", 0))
	var trigger_ids := _attack_context_ids(attack_context)
	var rate := float(unit["attack_rate"]) * _unit_attack_rate_factor(unit) * _rally_attack_speed_multiplier(unit)
	unit["cooldown"] = 1.0 / maxf(0.05, rate)
	unit["charge"] = minf(unit["cooldown"], float(Dictionary(unit.get("combat", {})).get("charge_seconds", 0.0)))

	if not _is_ranged(unit):
		var dash_damage_multiplier := _trigger_melee_mobility(unit, target)
		var damage := float(unit["attack"]) * float(attack_context.get("damage_multiplier", 1.0)) * _rally_damage_multiplier(unit) * dash_damage_multiplier
		var dealt := _damage_target(target_kind, target, damage, "melee", unit, 0.0, trigger_ids)
		_apply_lifesteal(unit, dealt)
		_apply_melee_specials(unit, target, dealt)
	else:
		_spawn_unit_projectiles(unit, target, target_kind, attack_context, trigger_ids)

	if bool(attack_context.get("echo", false)):
		var echo_ratio := maxf(0.0, float(attack_context.get("echo_damage_ratio", 0.0)))
		if echo_ratio > 0.0:
			_add_delayed_target_effect(
				"temporal_echo",
				str(unit["team"]),
				int(unit["id"]),
				target_kind,
				int(target.get("id", 0)),
				float(unit["attack"]) * echo_ratio,
				maxf(0.01, float(attack_context.get("echo_delay", 0.18)))
			)
	for ability_id in trigger_ids:
		_add_visual_effect(str(ability_id), Vector2(unit["pos"]), str(unit["team"]), "attack", 0.45)


func _attack_context_ids(context: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if bool(context.get("is_critical", false)):
		result.append("critical")
	if bool(context.get("execution_triggered", false)):
		result.append("execution_protocol")
	if bool(context.get("overcharge_triggered", false)):
		result.append("overcharge_capacitor")
	if bool(context.get("vengeance_triggered", false)):
		result.append("vengeance_counter")
	if bool(context.get("echo", false)):
		result.append("temporal_echo")
	return result


func _spawn_unit_projectiles(unit: Dictionary, target: Dictionary, target_kind: String, attack_context: Dictionary, trigger_ids: Array[String]) -> void:
	var snapshot: Dictionary = unit["upgrade_snapshot"]
	var ability_ids := SoldierUpgradeVfxCatalog.active_ids(snapshot, "projectile", 57)
	for trigger_id in trigger_ids:
		if trigger_id not in ability_ids:
			ability_ids.append(trigger_id)
	var split_effect := _special(unit, "split_shot")
	var extra_projectiles := 0
	var spread_degrees := 12.0
	if not split_effect.is_empty():
		extra_projectiles = clampi(int(split_effect.get("extra_projectiles", 2)), 0, 4)
		spread_degrees = maxf(1.0, float(split_effect.get("spread_degrees", 12.0)))
	var projectile_count := 1 + extra_projectiles
	var target_direction := (Vector2(target["pos"]) - Vector2(unit["pos"])).normalized()
	if target_direction.length_squared() < 0.001:
		target_direction = Vector2(unit["aim_dir"])
	for projectile_index in projectile_count:
		if projectiles.size() >= MAX_PROJECTILES:
			break
		var centered_index := float(projectile_index) - float(projectile_count - 1) * 0.5
		var direction := target_direction.rotated(deg_to_rad(spread_degrees * centered_index))
		var split_damage_multiplier := 1.0
		if projectile_count > 1 and projectile_index != projectile_count / 2:
			split_damage_multiplier = clampf(float(split_effect.get("damage_ratio", 0.12)), 0.0, 1.0)
		var data := {
			"id": _take_entity_id(),
			"pos": Vector2(unit["pos"]) + direction * (float(unit["radius"]) + 5.0),
			"vel": direction * _projectile_speed_for_type(str(unit["type"])),
			"team": str(unit["team"]),
			"source_id": int(unit["id"]),
			"source_kind": "soldier",
			"target_id": int(target.get("id", 0)),
			"target_kind": target_kind,
			"damage": float(unit["attack"]) * _rally_damage_multiplier(unit) * split_damage_multiplier,
			"range": float(unit["range"]),
			"radius": PROJECTILE_RADIUS,
			"ttl": maxf(1.0, float(unit["range"]) / maxf(1.0, _projectile_speed_for_type(str(unit["type"]))) + 1.0),
			"aoe": float(Dictionary(unit.get("combat", {})).get("aoe_radius", 0.0)),
			"pierce": maxi(1, int(Dictionary(unit.get("combat", {})).get("pierce", 1))),
			"remaining_hits": maxi(1, int(Dictionary(unit.get("combat", {})).get("pierce", 1))),
			"falloff": 1.0 - clampf(float(Dictionary(unit.get("combat", {})).get("damage_falloff", 0.0)), 0.0, 0.95),
			"hit_ids": {},
			"ability_ids": ability_ids.duplicate(),
			"vfx_layers": ability_ids.duplicate(),
		}
		var decorated := SoldierUpgradeRuntime.decorate_projectile(data, unit, attack_context)
		decorated["remaining_hits"] = maxi(1, int(decorated.get("pierce", decorated.get("remaining_hits", 1))))
		projectiles.append(decorated)


func _spawn_basic_projectile(
	source_id: int,
	source_kind: String,
	team: String,
	position: Vector2,
	target_id: int,
	target_kind: String,
	damage: float,
	attack_range: float,
	ability_ids: Array[String],
	specials: Dictionary,
	attack_context: Dictionary
) -> void:
	if projectiles.size() >= MAX_PROJECTILES:
		return
	var target := _target_record(target_kind, target_id)
	if target.is_empty():
		return
	var direction := (Vector2(target["pos"]) - position).normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT if team == "blue" else Vector2.LEFT
	projectiles.append({
		"id": _take_entity_id(), "pos": position, "vel": direction * DEFAULT_PROJECTILE_SPEED,
		"team": team, "source_id": source_id, "source_kind": source_kind,
		"target_id": target_id, "target_kind": target_kind, "damage": damage,
		"range": attack_range, "radius": PROJECTILE_RADIUS, "ttl": attack_range / DEFAULT_PROJECTILE_SPEED + 1.0,
		"aoe": 0.0, "pierce": 1, "remaining_hits": 1, "falloff": 1.0, "hit_ids": {},
		"ability_ids": ability_ids.duplicate(), "vfx_layers": ability_ids.duplicate(),
		"soldier_specials": specials, "soldier_attack_context": attack_context,
		"armor_penetration": 0.0, "homing": false,
	})


func _projectile_speed_for_type(type_id: String) -> float:
	if type_id in ["cannon", "tank", "rocket", "bomber"]:
		return 500.0
	if type_id in ["musketeer", "rifleman", "gatling", "helicopter"]:
		return 940.0
	if type_id == "ufo":
		return 1100.0
	return DEFAULT_PROJECTILE_SPEED


func _perform_support_action(unit: Dictionary) -> bool:
	var team := str(unit["team"])
	var position := Vector2(unit["pos"])
	var support_range := maxf(140.0, float(unit["range"]) + 120.0)
	var target: Dictionary = {}
	var best_missing := 0.0
	for ally_id_value in Array(_team_unit_ids[team]):
		var ally_id := int(ally_id_value)
		if not _unit_by_id.has(ally_id):
			continue
		var ally: Dictionary = _unit_by_id[ally_id]
		var missing := float(ally.get("max_hp", 0.0)) - float(ally.get("hp", 0.0))
		var needs_cleanse := _target_has_cleanse_status(unit, ally)
		if (missing > best_missing or (target.is_empty() and needs_cleanse)) and position.distance_to(Vector2(ally["pos"])) <= support_range:
			best_missing = missing
			target = ally
	if team == "blue" and mode == "challenge" and not hero.is_empty():
		var hero_missing := float(hero["max_hp"]) - float(hero["hp"])
		if hero_missing > best_missing and position.distance_to(Vector2(hero["pos"])) <= support_range:
			best_missing = hero_missing
			target = hero
	if target.is_empty():
		return _try_resurrection(unit)

	var combat: Dictionary = unit["combat"]
	var base_healing_per_second := float(combat.get("healing_per_second", maxf(8.0, float(unit["attack"]))))
	var interval := 1.0 / maxf(0.05, float(unit["attack_rate"]) * _rally_attack_speed_multiplier(unit))
	var multiplier := SoldierUpgradeRuntime.healing_multiplier(unit, float(target["hp"]) / maxf(1.0, float(target["max_hp"])))
	var healing := base_healing_per_second * interval * multiplier
	var repair := _special(unit, "battlefield_repair")
	if not repair.is_empty() and target.has("type"):
		var target_type := str(target["type"])
		if target_type in ["roller", "cannon", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"]:
			healing *= 1.0 + maxf(0.0, float(repair.get("vehicle_air_healing_bonus", repair.get("healing_bonus", 0.25))))
			_add_visual_effect("battlefield_repair", Vector2(target["pos"]), team, "repair", 0.55)
	var primary_heal_ability := "healing_mastery" if _has_special(unit, "healing_mastery") else "arena_heal"
	var restored := _heal_target(unit, target, healing, primary_heal_ability)
	unit["cooldown"] = interval

	var group_heal := _special(unit, "group_heal")
	var healing_sequence := int(Dictionary(unit.get("special_runtime", {})).get("healing_sequence", 0))
	if not group_heal.is_empty() and healing_sequence % maxi(1, int(group_heal.get("trigger_every_heals", 3))) == 0:
		var additional := maxi(1, int(group_heal.get("allies", 2)))
		var ratio := clampf(float(group_heal.get("healing_ratio", 0.45)), 0.0, 2.0)
		_heal_additional_allies(unit, target, healing * ratio, additional, support_range)
		_add_visual_effect("group_heal", Vector2(unit["pos"]), team, "support", 0.65)

	_try_cleanse(unit, target)
	_apply_support_shields(unit, target, healing, restored)
	return true


func _target_has_cleanse_status(source: Dictionary, target: Dictionary) -> bool:
	var cleanse := _special(source, "cleanse")
	if cleanse.is_empty() or not target.has("statuses"):
		return false
	var cooldowns: Dictionary = source.get("upgrade_cooldowns", {})
	if float(cooldowns.get("cleanse", 0.0)) > 0.0:
		return false
	var statuses: Dictionary = target["statuses"]
	for status_id_value in Array(cleanse.get("removes", [])):
		var status_id := "frost" if str(status_id_value) == "slow" else str(status_id_value)
		if statuses.has(status_id):
			return true
	return false


func _try_cleanse(source: Dictionary, target: Dictionary) -> bool:
	var cleanse := _special(source, "cleanse")
	if cleanse.is_empty() or not target.has("statuses"):
		return false
	var cooldowns: Dictionary = source["upgrade_cooldowns"]
	if float(cooldowns.get("cleanse", 0.0)) > 0.0:
		return false
	var statuses: Dictionary = target["statuses"]
	var removed_any := false
	for status_id_value in Array(cleanse.get("removes", [])):
		var catalog_status := str(status_id_value)
		var arena_status := "frost" if catalog_status == "slow" else catalog_status
		if statuses.erase(arena_status):
			removed_any = true
	if not removed_any:
		return false
	target["statuses"] = statuses
	cooldowns["cleanse"] = maxf(0.1, float(cleanse.get("cooldown", 10.0)))
	source["upgrade_cooldowns"] = cooldowns
	_add_visual_effect("cleanse", Vector2(target["pos"]), str(source["team"]), "support", 0.65)
	return true


func _heal_target(source: Dictionary, target: Dictionary, amount: float, ability_id: String) -> float:
	var before := float(target.get("hp", 0.0))
	var maximum := maxf(1.0, float(target.get("max_hp", 1.0)))
	target["hp"] = minf(maximum, before + maxf(0.0, amount))
	var restored := float(target["hp"]) - before
	if restored > 0.0:
		_add_visual_effect(ability_id, Vector2(target["pos"]), str(source["team"]), "heal", 0.55)
	return restored


func _heal_additional_allies(source: Dictionary, primary: Dictionary, amount: float, limit: int, maximum_range: float) -> void:
	var healed := 0
	for ally_id_value in Array(_team_unit_ids[str(source["team"])]):
		if healed >= limit:
			break
		var ally_id := int(ally_id_value)
		if not _unit_by_id.has(ally_id):
			continue
		var ally: Dictionary = _unit_by_id[ally_id]
		if ally == primary or float(ally["hp"]) >= float(ally["max_hp"]):
			continue
		if Vector2(source["pos"]).distance_to(Vector2(ally["pos"])) > maximum_range:
			continue
		_heal_target(source, ally, amount, "group_heal")
		healed += 1


func _apply_support_shields(source: Dictionary, target: Dictionary, attempted_healing: float, restored_healing: float) -> void:
	var holy := _special(source, "holy_shield")
	if not holy.is_empty():
		var per_source_cooldowns: Dictionary = target.get("holy_shield_cooldowns", {})
		var source_id := int(source["id"])
		if float(per_source_cooldowns.get(source_id, 0.0)) <= 0.0:
			var ratio := clampf(float(holy.get("shield_max_hp_ratio", holy.get("max_hp_ratio", 0.08))), 0.0, 1.0)
			target["holy_shield"] = maxf(float(target.get("holy_shield", 0.0)), float(target["max_hp"]) * ratio)
			target["holy_shield_ttl"] = maxf(0.1, float(holy.get("duration", 4.0)))
			per_source_cooldowns[source_id] = maxf(0.1, float(holy.get("target_cooldown", 10.0)))
			target["holy_shield_cooldowns"] = per_source_cooldowns
			_add_visual_effect("holy_shield", Vector2(target["pos"]), str(source["team"]), "shield", 0.75)
	var matrix := _special(source, "overheal_matrix")
	if not matrix.is_empty():
		var overheal := maxf(0.0, attempted_healing - restored_healing)
		var conversion := clampf(float(matrix.get("overheal_to_shield_ratio", 0.5)), 0.0, 2.0)
		var cap := float(target["max_hp"]) * clampf(float(matrix.get("shield_target_max_hp_ratio", 0.20)), 0.0, 2.0)
		if overheal > 0.0:
			target["overheal_shield"] = minf(cap, float(target.get("overheal_shield", 0.0)) + overheal * conversion)
			target["overheal_shield_ttl"] = maxf(0.1, float(matrix.get("duration", 6.0)))
			_add_visual_effect("overheal_matrix", Vector2(target["pos"]), str(source["team"]), "shield", 0.75)
	_refresh_support_shield(target)


func _consume_support_shield_sources(target: Dictionary, amount: float) -> void:
	var remaining := maxf(0.0, amount)
	var holy_consumed := minf(remaining, float(target.get("holy_shield", 0.0)))
	target["holy_shield"] = maxf(0.0, float(target.get("holy_shield", 0.0)) - holy_consumed)
	remaining -= holy_consumed
	if remaining > 0.0:
		target["overheal_shield"] = maxf(0.0, float(target.get("overheal_shield", 0.0)) - remaining)
	_refresh_support_shield(target)


func _tick_runtime_state_in_place(unit: Dictionary, delta: float) -> void:
	var state: Dictionary = unit.get("special_runtime", {})
	for cooldown_key in [
		"reactive_armor_cooldown", "evade_cooldown", "aerial_evade_cooldown",
		"air_flares_cooldown", "overcharge_cooldown", "temporal_echo_cooldown",
	]:
		state[cooldown_key] = maxf(0.0, float(state.get(cooldown_key, 0.0)) - delta)
	var tactical_max := float(state.get("tactical_shield_max", 0.0))
	if tactical_max > 0.0:
		state["tactical_shield_recharge"] = maxf(0.0, float(state.get("tactical_shield_recharge", 0.0)) - delta)
		if float(state["tactical_shield_recharge"]) <= 0.0:
			state["tactical_shield"] = tactical_max
	state["kinetic_barrier_ttl"] = maxf(0.0, float(state.get("kinetic_barrier_ttl", 0.0)) - delta)
	if float(state["kinetic_barrier_ttl"]) <= 0.0:
		state["kinetic_barrier"] = 0.0
	unit["special_runtime"] = state
	var timers: Dictionary = unit.get("upgrade_cooldowns", {})
	for timer_key in timers.keys():
		timers[timer_key] = maxf(0.0, float(timers[timer_key]) - delta)
	unit["upgrade_cooldowns"] = timers


func _tick_team_shared_cooldowns(delta: float) -> void:
	for team_value in TEAMS:
		var team := str(team_value)
		var timers: Dictionary = _team_shared_cooldowns[team]
		for ability_id_value in timers.keys():
			var ability_id := str(ability_id_value)
			timers[ability_id] = maxf(0.0, float(timers[ability_id]) - delta)
		_team_shared_cooldowns[team] = timers


func _tick_temporary_recovery_and_shields(unit: Dictionary, delta: float) -> void:
	var recovery_ttl := maxf(0.0, float(unit.get("last_stand_recovery_ttl", 0.0)))
	if recovery_ttl > 0.0:
		var recovery_delta := minf(maxf(0.0, delta), recovery_ttl)
		unit["hp"] = minf(float(unit["max_hp"]), float(unit["hp"]) + float(unit.get("last_stand_recovery_per_second", 0.0)) * recovery_delta)
	unit["last_stand_recovery_ttl"] = maxf(0.0, recovery_ttl - delta)
	if float(unit["last_stand_recovery_ttl"]) <= 0.0:
		unit["last_stand_recovery_per_second"] = 0.0
	unit["post_revive_reduction_ttl"] = maxf(0.0, float(unit.get("post_revive_reduction_ttl", 0.0)) - delta)
	if float(unit["post_revive_reduction_ttl"]) <= 0.0:
		unit["post_revive_reduction"] = 0.0
	unit["dash_reduction_ttl"] = maxf(0.0, float(unit.get("dash_reduction_ttl", 0.0)) - delta)
	if float(unit["dash_reduction_ttl"]) <= 0.0:
		unit["dash_damage_reduction"] = 0.0

	unit["holy_shield_ttl"] = maxf(0.0, float(unit.get("holy_shield_ttl", 0.0)) - delta)
	if float(unit["holy_shield_ttl"]) <= 0.0:
		unit["holy_shield"] = 0.0
	unit["overheal_shield_ttl"] = maxf(0.0, float(unit.get("overheal_shield_ttl", 0.0)) - delta)
	if float(unit["overheal_shield_ttl"]) <= 0.0:
		unit["overheal_shield"] = 0.0
	var holy_cooldowns: Dictionary = unit.get("holy_shield_cooldowns", {})
	for source_id_value in holy_cooldowns.keys():
		holy_cooldowns[source_id_value] = maxf(0.0, float(holy_cooldowns[source_id_value]) - delta)
	unit["holy_shield_cooldowns"] = holy_cooldowns
	var proc_cooldowns: Dictionary = unit.get("arena_proc_cooldowns", {})
	for proc_key_value in proc_cooldowns.keys():
		proc_cooldowns[proc_key_value] = maxf(0.0, float(proc_cooldowns[proc_key_value]) - delta)
	unit["arena_proc_cooldowns"] = proc_cooldowns
	_refresh_support_shield(unit)


func _refresh_support_shield(unit: Dictionary) -> void:
	unit["support_shield"] = maxf(0.0, float(unit.get("holy_shield", 0.0))) + maxf(0.0, float(unit.get("overheal_shield", 0.0)))


func _record_runtime_movement_in_place(unit: Dictionary, distance: float) -> void:
	var kinetic := _special(unit, "kinetic_barrier")
	if kinetic.is_empty() or distance <= 0.0:
		return
	var state: Dictionary = unit["special_runtime"]
	if float(state.get("kinetic_barrier_ttl", 0.0)) > 0.0:
		return
	var required := maxf(1.0, float(kinetic.get("move_distance", 300.0)))
	state["kinetic_barrier_distance"] = float(state.get("kinetic_barrier_distance", 0.0)) + distance
	if float(state["kinetic_barrier_distance"]) >= required:
		state["kinetic_barrier_distance"] = fmod(float(state["kinetic_barrier_distance"]), required)
		state["kinetic_barrier"] = float(state.get("kinetic_barrier_max", float(unit["max_hp"]) * 0.1))
		state["kinetic_barrier_ttl"] = maxf(0.1, float(kinetic.get("duration", 5.0)))
		_add_visual_effect("kinetic_barrier", Vector2(unit["pos"]), str(unit["team"]), "shield", 0.65)
	unit["special_runtime"] = state


func _tick_statuses(unit: Dictionary, delta: float) -> void:
	var statuses: Dictionary = unit.get("statuses", {})
	for status_id in STATUS_KEYS:
		if not statuses.has(status_id):
			continue
		var status: Dictionary = statuses[status_id]
		if status_id == "poison" and status.has("stacks"):
			var stacks: Array = status["stacks"]
			var combined_damage_per_second := 0.0
			var maximum_ttl := 0.0
			for stack_index in range(stacks.size() - 1, -1, -1):
				var stack: Dictionary = stacks[stack_index]
				stack["ttl"] = float(stack.get("ttl", 0.0)) - delta
				if float(stack["ttl"]) <= 0.0:
					stacks.remove_at(stack_index)
					continue
				stacks[stack_index] = stack
				combined_damage_per_second += maxf(0.0, float(stack.get("damage_per_second", 0.0)))
				maximum_ttl = maxf(maximum_ttl, float(stack["ttl"]))
			status["stacks"] = stacks
			status["damage_per_second"] = combined_damage_per_second
			status["ttl"] = maximum_ttl + delta
		status["ttl"] = float(status.get("ttl", 0.0)) - delta
		if status_id in ["burn", "poison", "corrosion"]:
			var damage_per_second := maxf(0.0, float(status.get("damage_per_second", 0.0)))
			status["tick_timer"] = float(status.get("tick_timer", 0.0)) - delta
			if damage_per_second > 0.0 and float(status["tick_timer"]) <= 0.0:
				status["tick_timer"] = 0.25
				_damage_unit(unit, damage_per_second * 0.25, "status", {}, 9999.0, [str(status.get("ability_id", status_id))])
		if float(status["ttl"]) <= 0.0:
			statuses.erase(status_id)
		else:
			statuses[status_id] = status
	unit["statuses"] = statuses


func _status_active(unit: Dictionary, status_id: String) -> bool:
	return Dictionary(unit.get("statuses", {})).has(status_id)


func _apply_status(target: Dictionary, status_id: String, duration: float, strength: float, damage_per_second: float, ability_id: String, source_id: int = -1) -> void:
	if target.is_empty() or not target.has("statuses"):
		return
	var statuses: Dictionary = target["statuses"]
	var existing: Dictionary = statuses.get(status_id, {})
	existing["ttl"] = maxf(float(existing.get("ttl", 0.0)), maxf(0.05, duration))
	existing["strength"] = maxf(float(existing.get("strength", 0.0)), strength)
	existing["damage_per_second"] = maxf(float(existing.get("damage_per_second", 0.0)), damage_per_second)
	existing["ability_id"] = ability_id
	if source_id >= 0:
		existing["source_id"] = source_id
	if damage_per_second > 0.0 and not existing.has("tick_timer"):
		existing["tick_timer"] = 0.0
	statuses[status_id] = existing
	target["statuses"] = statuses
	_add_visual_effect(ability_id, Vector2(target["pos"]), str(target["team"]), "status", 0.55)


func _tick_periodic_specials(unit: Dictionary, _delta: float) -> void:
	var cooldowns: Dictionary = unit["upgrade_cooldowns"]
	var self_repair := _special(unit, "self_repair")
	if not self_repair.is_empty() and battle_time - float(unit.get("last_damage_time", -1000.0)) >= maxf(0.0, float(self_repair.get("no_hit_delay", 4.0))):
		var heal_per_second := float(unit["max_hp"]) * maxf(0.0, float(self_repair.get("max_hp_heal_per_second", 0.01)))
		if float(unit["hp"]) < float(unit["max_hp"]):
			unit["hp"] = minf(float(unit["max_hp"]), float(unit["hp"]) + heal_per_second * FIXED_STEP)
			if not cooldowns.has("self_repair_vfx") or float(cooldowns["self_repair_vfx"]) <= 0.0:
				_add_visual_effect("self_repair", Vector2(unit["pos"]), str(unit["team"]), "repair", 0.6)
				cooldowns["self_repair_vfx"] = 1.0

	var meteor := _special(unit, "meteor")
	var team_shared: Dictionary = _team_shared_cooldowns[str(unit["team"])]
	if not meteor.is_empty() and float(team_shared.get("meteor", 0.0)) <= 0.0:
		var target := _nearest_opposing_unit(str(unit["team"]), Vector2(unit["pos"]), INF, true)
		if not target.is_empty():
			_spawn_meteor(unit, target, meteor)
			team_shared["meteor"] = maxf(1.0, float(meteor.get("army_shared_cooldown", 16.0)))
			_team_shared_cooldowns[str(unit["team"])] = team_shared

	var guardian := _special(unit, "guardian")
	if not guardian.is_empty() and float(cooldowns.get("guardian", 0.0)) <= 0.0:
		if _spawn_guardian(unit, guardian):
			cooldowns["guardian"] = 0.75
		else:
			cooldowns["guardian"] = 0.35

	var turret := _special(unit, "auto_turret")
	if not turret.is_empty() and float(cooldowns.get("auto_turret", 0.0)) <= 0.0:
		if _spawn_turret_effect(unit, turret):
			cooldowns["auto_turret"] = 0.75
		else:
			cooldowns["auto_turret"] = 0.35

	var repair_drone := _special(unit, "repair_drone")
	if not repair_drone.is_empty() and float(cooldowns.get("repair_drone", 0.0)) <= 0.0:
		if _spawn_repair_drone_effect(unit, repair_drone):
			cooldowns["repair_drone"] = 0.75
		else:
			cooldowns["repair_drone"] = 0.35

	var flares := _special(unit, "air_flares")
	if not flares.is_empty() and float(cooldowns.get("air_flares", 0.0)) <= 0.0:
		if _intercept_homing_projectile(unit):
			cooldowns["air_flares"] = maxf(1.0, float(flares.get("cooldown", 10.0)))
	unit["upgrade_cooldowns"] = cooldowns


func _spawn_meteor(source: Dictionary, target: Dictionary, effect: Dictionary) -> void:
	var warning := maxf(0.2, float(effect.get("warning_time", 0.8)))
	effects.append({
		"id": _take_entity_id(), "kind": "meteor", "ability_id": "meteor", "ability_ids": ["meteor"],
		"team": str(source["team"]), "source_id": int(source["id"]), "pos": Vector2(target["pos"]),
		"ttl": warning, "timer": warning, "initial_warning": warning, "progress": 0.0, "fall_progress": 0.0,
		"damage": float(source["attack"]) * maxf(0.1, float(effect.get("damage_ratio", 1.6))),
		"radius": maxf(30.0, float(effect.get("radius", 130.0))), "triggered": false,
	})


func _spawn_guardian(source: Dictionary, effect: Dictionary) -> bool:
	var team := str(source["team"])
	var per_owner := 0
	for unit in units:
		if bool(unit.get("summoned", false)) and str(unit.get("summon_ability_id", "")) == "guardian" and int(unit.get("summon_owner_id", -1)) == int(source["id"]) and float(unit.get("hp", 0.0)) > 0.0:
			per_owner += 1
	var owner_cap := maxi(1, int(effect.get("max_per_owner", 2)))
	var team_cap := mini(MAX_SUMMONS_PER_TEAM, maxi(1, int(effect.get("team_summon_cap", MAX_SUMMONS_PER_TEAM))))
	if units.size() >= MAX_BATTLE_UNITS or per_owner >= owner_cap or _team_active_summons(team) >= team_cap:
		return false
	var position := _clamp_to_arena(Vector2(source["pos"]) + Vector2(0.0, float(source["radius"]) + 28.0), soldier_radius("swordsman"))
	var guardian := _create_unit("swordsman", team, position)
	guardian["hp"] = float(source["max_hp"]) * maxf(0.1, float(effect.get("hp_ratio", 0.45)))
	guardian["max_hp"] = guardian["hp"]
	guardian["attack"] = float(source["attack"]) * maxf(0.1, float(effect.get("attack_ratio", 0.45)))
	guardian["range"] = maxf(20.0, float(effect.get("attack_range", 280.0)))
	guardian["attack_rate"] = 1.0 / maxf(0.05, float(effect.get("attack_interval", 1.10)))
	guardian["summoned"] = true
	guardian["summon_ability_id"] = "guardian"
	guardian["summon_owner_id"] = int(source["id"])
	guardian["summon_ttl"] = maxf(0.1, float(effect.get("ttl", 14.0)))
	# Summons carry base stats but cannot recursively summon more helpers.
	var empty_snapshot := SoldierUpgradeCatalog.snapshot_for_type("swordsman", SoldierUpgradeCatalog.create_empty_research())
	guardian["upgrade_snapshot"] = empty_snapshot
	guardian["special_runtime"] = SoldierUpgradeRuntime.create_state(empty_snapshot, float(guardian["max_hp"]))
	units.append(guardian)
	_unit_by_id[int(guardian["id"])] = guardian
	var ids: Array = _team_unit_ids[team]
	ids.append(int(guardian["id"]))
	_team_unit_ids[team] = ids
	_alive_counts[team] = int(_alive_counts[team]) + 1
	_summon_counts[team] = int(_summon_counts[team]) + 1
	_add_visual_effect("guardian", position, team, "summon", 0.9)
	return true


func _spawn_turret_effect(source: Dictionary, effect: Dictionary) -> bool:
	var team := str(source["team"])
	if _persistent_effect_count("turret", team, int(source["id"])) >= maxi(1, int(effect.get("max_per_owner", 2))) or _team_active_summons(team) >= maxi(1, int(effect.get("team_summon_cap", MAX_SUMMONS_PER_TEAM))):
		return false
	effects.append({
		"id": _take_entity_id(), "kind": "turret", "ability_id": "auto_turret", "ability_ids": ["auto_turret"],
		"team": str(source["team"]), "source_id": int(source["id"]), "pos": Vector2(source["pos"]),
		"ttl": maxf(2.0, float(effect.get("ttl", effect.get("duration", 8.0)))), "timer": 0.1,
		"range": maxf(120.0, float(effect.get("attack_range", 360.0))),
		"damage": float(source["attack"]) * maxf(0.05, float(effect.get("shot_damage_ratio", 0.25))),
		"interval": 1.0 / maxf(0.2, float(effect.get("shots_per_second", 2.0))),
	})
	_add_visual_effect("auto_turret", Vector2(source["pos"]), str(source["team"]), "summon", 0.8)
	return true


func _spawn_repair_drone_effect(source: Dictionary, effect: Dictionary) -> bool:
	var team := str(source["team"])
	if _persistent_effect_count("repair_drone", team, int(source["id"])) >= maxi(1, int(effect.get("max_per_owner", 2))) or _team_active_summons(team) >= maxi(1, int(effect.get("team_summon_cap", MAX_SUMMONS_PER_TEAM))):
		return false
	effects.append({
		"id": _take_entity_id(), "kind": "repair_drone", "ability_id": "repair_drone", "ability_ids": ["repair_drone"],
		"team": str(source["team"]), "source_id": int(source["id"]), "pos": Vector2(source["pos"]),
		"ttl": maxf(2.0, float(effect.get("duration", 6.0))), "timer": 0.1,
		"range": maxf(120.0, float(effect.get("healing_range", 380.0))),
		"heal_ratio": maxf(0.001, float(effect.get("max_hp_heal_per_second", 0.025))),
	})
	_add_visual_effect("repair_drone", Vector2(source["pos"]), str(source["team"]), "summon", 0.8)
	return true


func _team_active_summons(team: String) -> int:
	var total := int(_summon_counts[team])
	for effect in effects:
		if str(effect.get("team", "")) == team and str(effect.get("kind", "")) in ["turret", "repair_drone"] and float(effect.get("ttl", 0.0)) > 0.0:
			total += 1
	return total


func _intercept_homing_projectile(unit: Dictionary) -> bool:
	for projectile in projectiles:
		if str(projectile.get("team", "")) == str(unit["team"]) or not bool(projectile.get("homing", false)):
			continue
		if Vector2(projectile["pos"]).distance_to(Vector2(unit["pos"])) <= maxf(120.0, float(unit["range"])):
			projectile["ttl"] = 0.0
			_add_visual_effect("air_flares", Vector2(projectile["pos"]), str(unit["team"]), "intercept", 0.6)
			return true
	return false


func _update_projectiles(delta: float) -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[index]
		projectile["ttl"] = float(projectile.get("ttl", 0.0)) - delta
		if float(projectile["ttl"]) <= 0.0:
			projectiles.remove_at(index)
			continue
		var target := _target_record(str(projectile.get("target_kind", "unit")), int(projectile.get("target_id", -1)))
		if target.is_empty() or float(target.get("hp", 0.0)) <= 0.0:
			target = _projectile_next_target(projectile)
			if target.is_empty():
				projectiles.remove_at(index)
				continue
			projectile["target_kind"] = "unit"
			projectile["target_id"] = int(target["id"])
		if bool(projectile.get("homing", false)):
			var desired := (Vector2(target["pos"]) - Vector2(projectile["pos"])).normalized()
			var velocity := Vector2(projectile["vel"])
			var speed := velocity.length()
			var current_angle := velocity.angle()
			var desired_angle := desired.angle()
			var turn_rate := deg_to_rad(maxf(1.0, float(projectile.get("homing_turn_degrees_per_second", 180.0))))
			var new_angle := current_angle + clampf(wrapf(desired_angle - current_angle, -PI, PI), -turn_rate * delta, turn_rate * delta)
			projectile["vel"] = Vector2.from_angle(new_angle) * speed
		var before := Vector2(projectile["pos"])
		var after := before + Vector2(projectile["vel"]) * delta
		projectile["pos"] = after
		var collision_radius := float(projectile.get("radius", PROJECTILE_RADIUS)) + float(target.get("radius", 14.0))
		if _distance_squared_to_segment(Vector2(target["pos"]), before, after) <= collision_radius * collision_radius:
			_impact_projectile(projectile, target, str(projectile.get("target_kind", "unit")))
			if int(projectile.get("remaining_hits", 0)) <= 0:
				projectiles.remove_at(index)
				continue
			var next_target := _projectile_next_target(projectile)
			if next_target.is_empty():
				projectiles.remove_at(index)
				continue
			projectile["target_kind"] = "unit"
			projectile["target_id"] = int(next_target["id"])
		if not arena_rect.grow(120.0).has_point(Vector2(projectile["pos"])):
			projectiles.remove_at(index)


func _projectile_next_target(projectile: Dictionary) -> Dictionary:
	var team := str(projectile.get("team", "blue"))
	var opposing_team := "red" if team == "blue" else "blue"
	var hit_ids: Dictionary = projectile.get("hit_ids", {})
	var best: Dictionary = {}
	var best_distance_squared := INF
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if hit_ids.has(target_id) or not _unit_by_id.has(target_id):
			continue
		var candidate: Dictionary = _unit_by_id[target_id]
		if float(candidate.get("hp", 0.0)) <= 0.0:
			continue
		var distance_squared := Vector2(projectile["pos"]).distance_squared_to(Vector2(candidate["pos"]))
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best = candidate
	if best.is_empty() and team == "red" and mode == "challenge" and not hero.is_empty() and not hit_ids.has(0) and float(hero.get("hp", 0.0)) > 0.0:
		return hero
	return best


func _impact_projectile(projectile: Dictionary, target: Dictionary, target_kind: String) -> void:
	var hit_ids: Dictionary = projectile.get("hit_ids", {})
	hit_ids[int(target.get("id", 0))] = true
	projectile["hit_ids"] = hit_ids
	var specials: Dictionary = projectile.get("soldier_specials", {})
	var source := _source_record(projectile)
	var ability_ids: Array = projectile.get("ability_ids", [])

	var damage := float(projectile.get("damage", 0.0))
	if specials.has("lingering_projectile"):
		damage *= clampf(float(Dictionary(specials["lingering_projectile"]).get("first_hit_ratio", 0.70)), 0.0, 1.0)
	if specials.has("cluster_warhead"):
		damage *= clampf(float(Dictionary(specials["cluster_warhead"]).get("main_damage_ratio", 0.70)), 0.0, 1.0)
	if specials.has("mine_round"):
		damage *= clampf(float(Dictionary(specials["mine_round"]).get("impact_damage_ratio", 0.30)), 0.0, 1.0)
	if specials.has("siege_warhead") and float(target.get("radius", 0.0)) >= 22.0:
		var siege: Dictionary = specials["siege_warhead"]
		damage *= 1.0 + maxf(0.0, float(siege.get("structure_damage_bonus", siege.get("damage_bonus", 0.35))))
	var dealt := _damage_target(
		target_kind,
		target,
		damage,
		"homing_projectile" if bool(projectile.get("homing", false)) else "projectile",
		source,
		float(projectile.get("armor_penetration", 0.0)),
		ability_ids
	)
	if not source.is_empty():
		_apply_lifesteal(source, dealt)
	_apply_projectile_specials(projectile, target, target_kind, dealt)
	if specials.has("mine_round"):
		_spawn_mine_effect(projectile, Vector2(target["pos"]), Dictionary(specials["mine_round"]))
		projectile["remaining_hits"] = 0
		return

	var aoe := maxf(0.0, float(projectile.get("aoe", 0.0)))
	if aoe > 0.0:
		_damage_area(str(projectile["team"]), Vector2(target["pos"]), aoe, damage * 0.62, source, ability_ids, int(target.get("id", -1)))
	projectile["remaining_hits"] = int(projectile.get("remaining_hits", 1)) - 1
	projectile["damage"] = damage * clampf(float(projectile.get("falloff", 1.0)), 0.0, 1.0)


func _source_record(payload: Dictionary) -> Dictionary:
	var source_id := int(payload.get("source_id", -1))
	if str(payload.get("source_kind", "")) == "hero" and source_id == 0:
		return hero
	if _unit_by_id.has(source_id):
		return _unit_by_id[source_id]
	return {}


func _damage_target(
	target_kind: String,
	target: Dictionary,
	damage: float,
	damage_kind: String,
	source: Dictionary,
	armor_penetration: float,
	ability_ids: Array
) -> float:
	if target_kind == "hero":
		return _damage_hero(damage, source, ability_ids)
	return _damage_unit(target, damage, damage_kind, source, armor_penetration, ability_ids)


func _damage_hero(amount: float, source: Dictionary, ability_ids: Array) -> float:
	if hero.is_empty() or float(hero.get("hp", 0.0)) <= 0.0:
		return 0.0
	var mitigated := maxf(1.0, maxf(0.0, amount) - float(hero.get("defense", 0.0)) * 0.45)
	_refresh_support_shield(hero)
	var shield_absorbed := minf(mitigated, float(hero.get("support_shield", 0.0)))
	if shield_absorbed > 0.0:
		_consume_support_shield_sources(hero, shield_absorbed)
		mitigated -= shield_absorbed
	var before := float(hero["hp"])
	hero["hp"] = maxf(0.0, before - mitigated)
	hero["flash"] = 0.12
	if float(hero["hp"]) <= 0.0:
		hero["vel"] = Vector2.ZERO
		_add_visual_effect(_first_visual_id(ability_ids, "impact"), Vector2(hero["pos"]), "red", "hero_defeated", 0.9)
	return before - float(hero["hp"])


func _damage_unit(unit: Dictionary, amount: float, damage_kind: String, source: Dictionary, armor_penetration: float, ability_ids: Array) -> float:
	if amount <= 0.0 or unit.is_empty() or float(unit.get("hp", 0.0)) <= 0.0 or float(unit.get("invulnerability", 0.0)) > 0.0:
		return 0.0
	var statuses: Dictionary = unit.get("statuses", {})
	var incoming_multiplier := 1.0
	if statuses.has("void_mark") and not source.is_empty() and source.has("upgrade_snapshot"):
		incoming_multiplier *= 1.0 + maxf(0.0, float(Dictionary(statuses["void_mark"]).get("strength", 0.12)))
	if statuses.has("focus_mark"):
		var focus: Dictionary = statuses["focus_mark"]
		if not source.is_empty() and int(source.get("id", -1)) != int(focus.get("source_id", -1)):
			incoming_multiplier *= 1.0 + maxf(0.0, float(focus.get("strength", 0.05)))
	var effective_defense := maxf(0.0, float(unit.get("defense", 0.0)) - maxf(0.0, armor_penetration))
	if statuses.has("corrosion"):
		effective_defense = maxf(0.0, effective_defense - maxf(0.0, float(Dictionary(statuses["corrosion"]).get("strength", 0.0))))
	var mitigated := maxf(0.5, maxf(0.0, amount) * incoming_multiplier - effective_defense * 0.45)
	mitigated *= _ally_damage_taken_multiplier(unit)
	if float(unit.get("post_revive_reduction_ttl", 0.0)) > 0.0:
		mitigated *= 1.0 - clampf(float(unit.get("post_revive_reduction", 0.0)), 0.0, 0.9)
	if float(unit.get("dash_reduction_ttl", 0.0)) > 0.0:
		mitigated *= 1.0 - clampf(float(unit.get("dash_damage_reduction", 0.0)), 0.0, 0.9)
	var runtime_before: Dictionary = unit.get("special_runtime", {})
	var kinetic_before := float(runtime_before.get("kinetic_barrier", 0.0))
	var tactical_before := float(runtime_before.get("tactical_shield", 0.0))
	_refresh_support_shield(unit)
	var support_before := float(unit.get("support_shield", 0.0))
	var plan := SoldierUpgradeRuntime.incoming_damage_plan(unit, damage_kind, mitigated)
	var final_damage := maxf(0.0, float(plan.get("damage", mitigated)))
	var evade_kind := str(plan.get("evade_kind", ""))
	if bool(plan.get("evaded", false)) or (evade_kind == "aerial_evade" and float(plan.get("sidestep_distance", 0.0)) > 0.0):
		var side_sign := -1.0 if int(unit["id"]) % 2 == 0 else 1.0
		var facing := Vector2(unit.get("aim_dir", Vector2.RIGHT)).normalized()
		var side := Vector2(-facing.y, facing.x) * side_sign
		unit["pos"] = _clamp_to_arena(Vector2(unit["pos"]) + side * float(plan.get("sidestep_distance", 0.0)), float(unit["radius"]))
		_add_visual_effect(evade_kind if not evade_kind.is_empty() else "evade_drill", Vector2(unit["pos"]), str(unit["team"]), "evade", 0.55)
	if bool(plan.get("reactive_armor_triggered", false)):
		_add_visual_effect("reactive_armor", Vector2(unit["pos"]), str(unit["team"]), "shield", 0.55)
	var runtime_after: Dictionary = unit.get("special_runtime", {})
	var kinetic_consumed := maxf(0.0, kinetic_before - float(runtime_after.get("kinetic_barrier", 0.0)))
	var tactical_consumed := maxf(0.0, tactical_before - float(runtime_after.get("tactical_shield", 0.0)))
	var support_consumed := maxf(0.0, support_before - float(unit.get("support_shield", 0.0)))
	if support_consumed > 0.0:
		_consume_support_shield_sources(unit, support_consumed)
	if kinetic_consumed > 0.0:
		_add_visual_effect("kinetic_barrier", Vector2(unit["pos"]), str(unit["team"]), "shield", 0.45)
	elif tactical_consumed > 0.0:
		_add_visual_effect("tactical_shield", Vector2(unit["pos"]), str(unit["team"]), "shield", 0.45)
	elif support_consumed > 0.0:
		var support_vfx := "holy_shield" if float(unit.get("holy_shield", 0.0)) > 0.0 else "overheal_matrix"
		_add_visual_effect(support_vfx, Vector2(unit["pos"]), str(unit["team"]), "shield", 0.45)
	if bool(plan.get("last_stand_triggered", false)):
		var last_stand := _special(unit, "last_stand")
		var recovery_duration := maxf(0.1, float(last_stand.get("recovery_duration", 3.0)))
		unit["last_stand_recovery_ttl"] = recovery_duration
		unit["last_stand_recovery_per_second"] = float(unit["max_hp"]) * clampf(float(last_stand.get("recovery_max_hp_ratio", 0.12)), 0.0, 1.0) / recovery_duration
		_add_visual_effect("last_stand", Vector2(unit["pos"]), str(unit["team"]), "survive", 0.9)
	unit["invulnerability"] = maxf(float(unit.get("invulnerability", 0.0)), float(plan.get("invulnerability", 0.0)))
	var before := float(unit["hp"])
	unit["hp"] = maxf(0.0, before - final_damage)
	unit["flash"] = 0.12
	unit["last_damage_time"] = battle_time
	var dealt := before - float(unit["hp"])
	if float(unit["hp"]) <= 0.0:
		_on_unit_killed(unit, source, ability_ids)
	return dealt


func _on_unit_killed(unit: Dictionary, source: Dictionary, ability_ids: Array) -> void:
	if bool(unit.get("death_processed", false)):
		return
	unit["death_processed"] = true
	unit["state"] = "dead"
	unit["vel"] = Vector2.ZERO
	var team := str(unit["team"])
	_alive_counts[team] = maxi(0, int(_alive_counts[team]) - 1)
	if bool(unit.get("summoned", false)):
		_summon_counts[team] = maxi(0, int(_summon_counts[team]) - 1)
	else:
		var shelter := _strongest_team_special(team, "soul_shelter")
		var grave_ttl := 9.0 + maxf(0.0, float(shelter.get("tombstone_bonus_seconds", 0.0)))
		effects.append({
			"id": _take_entity_id(), "kind": "grave", "ability_id": "grave", "ability_ids": [],
			"team": team, "pos": Vector2(unit["pos"]), "ttl": grave_ttl, "timer": grave_ttl,
			"unit_type": str(unit["type"]), "revived": false,
		})
	if not source.is_empty() and _has_special(source, "salvage_protocol"):
		var salvage := _special(source, "salvage_protocol")
		var heal_ratio := maxf(0.0, float(salvage.get("healing_ratio", salvage.get("bonus_gold_ratio", 0.05))))
		source["hp"] = minf(float(source["max_hp"]), float(source["hp"]) + float(source["max_hp"]) * heal_ratio)
		_add_visual_effect("salvage_protocol", Vector2(source["pos"]), str(source["team"]), "salvage", 0.75)
	_add_visual_effect(_first_visual_id(ability_ids, "impact"), Vector2(unit["pos"]), "red" if team == "blue" else "blue", "defeat", 0.65)


func _cleanup_dead_units() -> void:
	for index in range(units.size() - 1, -1, -1):
		var unit := units[index]
		if float(unit.get("hp", 0.0)) > 0.0:
			continue
		_unit_by_id.erase(int(unit["id"]))
		units.remove_at(index)


func _distance_squared_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_squared_to(start)
	var t := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_squared_to(start + segment * t)


func _apply_projectile_specials(projectile: Dictionary, target: Dictionary, target_kind: String, dealt: float) -> void:
	if target_kind != "unit" or target.is_empty():
		return
	var specials: Dictionary = projectile.get("soldier_specials", {})
	var triggered: Dictionary = projectile.get("triggered_specials", {})
	var source := _source_record(projectile)
	var base_damage := maxf(1.0, float(projectile.get("damage", dealt)))
	for ability_id_value in Array(projectile.get("ability_ids", [])):
		var ability_id := str(ability_id_value)
		if not specials.has(ability_id):
			continue
		var effect: Dictionary = specials[ability_id]
		match ability_id:
			"burning_ammo":
				var proc_cooldowns: Dictionary = target.get("arena_proc_cooldowns", {})
				var proc_key := "burning_ammo:%d" % int(projectile.get("source_id", -1))
				if float(proc_cooldowns.get(proc_key, 0.0)) <= 0.0:
					_apply_dot_from_total(target, "burn", ability_id, base_damage, effect, "total_burn_ratio", 0.18)
					proc_cooldowns[proc_key] = maxf(0.0, float(effect.get("source_target_proc_cooldown", 0.7)))
					target["arena_proc_cooldowns"] = proc_cooldowns
			"frost_arrow":
				_apply_status(target, "frost", float(effect.get("duration", 2.0)), float(effect.get("slow_ratio", 0.25)), 0.0, ability_id)
			"paralysis_arrow":
				var arrow_interval := maxi(1, int(effect.get("arrow_interval", 7)))
				if int(projectile.get("attack_sequence", 0)) % arrow_interval == 0:
					_apply_status(target, "paralysis", maxf(0.15, float(effect.get("normal_stun", 0.45))), 1.0, 0.0, ability_id)
			"corrosion":
				_apply_corrosion_stack(target, effect)
			"void_mark":
				_apply_status(target, "void_mark", float(effect.get("duration", 5.0)), float(effect.get("soldier_damage_taken_bonus", effect.get("damage_bonus", 0.12))), 0.0, ability_id)
			"suppression":
				_record_threshold_status(target, projectile, ability_id, effect)
			"focus_mark":
				_apply_status(target, "focus_mark", float(effect.get("effect_duration", 4.0)), float(effect.get("other_ally_damage_bonus", 0.05)), 0.0, ability_id, int(projectile.get("source_id", -1)))
			"toxic_payload":
				_apply_toxic_stack(target, projectile, base_damage, effect)
			"chain_lightning":
				if not triggered.has(ability_id):
					_chain_damage(projectile, target, effect, "chain_lightning")
					triggered[ability_id] = true
			"ricochet":
				if not triggered.has(ability_id):
					_chain_damage(projectile, target, effect, "ricochet")
					triggered[ability_id] = true
			"lingering_projectile":
				if not triggered.has(ability_id):
					_spawn_area_effect("lingering_projectile", str(projectile["team"]), Vector2(target["pos"]), source, effect, base_damage * float(effect.get("tick_damage_ratio", 0.22)), float(effect.get("linger_duration", 2.5)), maxf(20.0, float(effect.get("radius", 42.0))))
					triggered[ability_id] = true
			"chain_explosion":
				if not triggered.has(ability_id):
					var blasts := maxi(1, int(effect.get("extra_blasts", 2)))
					var blast_ratios: Array = effect.get("blast_damage_ratios", [])
					for blast_index in blasts:
						var blast_ratio := float(blast_ratios[blast_index]) if blast_index < blast_ratios.size() else maxf(0.1, 0.45 - float(blast_index) * 0.10)
						_add_delayed_area_effect("chain_explosion", str(projectile["team"]), Vector2(target["pos"]), source, base_damage * blast_ratio, 58.0 + float(blast_index) * 22.0, 0.12 * float(blast_index + 1))
					triggered[ability_id] = true
			"cluster_warhead":
				if not triggered.has(ability_id):
					var bomblets := clampi(int(effect.get("bomblets", 4)), 1, 8)
					for bomblet_index in bomblets:
						var offset := Vector2.from_angle(TAU * float(bomblet_index) / float(bomblets)) * (28.0 + float(bomblet_index % 2) * 22.0)
						_add_delayed_area_effect("cluster_warhead", str(projectile["team"]), Vector2(target["pos"]) + offset, source, base_damage * float(effect.get("bomblet_damage_ratio", 0.28)), 44.0, 0.18 + float(bomblet_index % 3) * 0.08)
					triggered[ability_id] = true
			"burning_zone":
				if not triggered.has(ability_id):
					_spawn_area_effect("burning_zone", str(projectile["team"]), Vector2(target["pos"]), source, effect, base_damage * float(effect.get("tick_damage_ratio", 0.18)), float(effect.get("zone_ttl", 4.0)), maxf(45.0, float(effect.get("radius", 95.0))))
					triggered[ability_id] = true
			"shockwave_round":
				if not triggered.has(ability_id):
					_apply_shockwave_control(projectile, Vector2(target["pos"]), effect)
					triggered[ability_id] = true
			"shrapnel_storm":
				if not triggered.has(ability_id):
					var shards := clampi(int(effect.get("shards", 5)), 1, 10)
					_chain_damage_fixed(projectile, target, shards, base_damage * float(effect.get("shard_damage_ratio", 0.20)), maxf(120.0, float(effect.get("radius", 260.0))), ability_id)
					triggered[ability_id] = true
			"gravity_warhead":
				if not triggered.has(ability_id):
					_spawn_gravity_effect(projectile, Vector2(target["pos"]), effect)
					triggered[ability_id] = true
	projectile["triggered_specials"] = triggered


func _apply_dot_from_total(target: Dictionary, status_id: String, ability_id: String, base_damage: float, effect: Dictionary, ratio_key: String, fallback_ratio: float) -> void:
	var duration := maxf(0.25, float(effect.get("duration", 3.0)))
	var total_ratio := maxf(0.0, float(effect.get(ratio_key, fallback_ratio)))
	_apply_status(target, status_id, duration, 0.0, base_damage * total_ratio / duration, ability_id)


func _record_threshold_status(target: Dictionary, projectile: Dictionary, ability_id: String, effect: Dictionary) -> void:
	var source_id := int(projectile.get("source_id", -1))
	var counters: Dictionary = target.get("arena_hit_counters", {})
	var counter_key := "%s:%d" % [ability_id, source_id]
	var count := int(counters.get(counter_key, 0)) + 1
	var threshold := maxi(1, int(effect.get("hit_threshold", 6)))
	if count >= threshold:
		count = 0
		_apply_status(target, "suppression", float(effect.get("effect_duration", 3.5)), 0.0, 0.0, ability_id, source_id)
		var statuses: Dictionary = target["statuses"]
		var suppression: Dictionary = statuses["suppression"]
		suppression["move_reduction"] = clampf(float(effect.get("move_reduction", 0.20)), 0.0, 0.75)
		suppression["attack_speed_reduction"] = clampf(float(effect.get("attack_speed_reduction", 0.10)), 0.0, 0.75)
		statuses["suppression"] = suppression
		target["statuses"] = statuses
	counters[counter_key] = count
	target["arena_hit_counters"] = counters


func _apply_corrosion_stack(target: Dictionary, effect: Dictionary) -> void:
	var statuses: Dictionary = target.get("statuses", {})
	var corrosion: Dictionary = statuses.get("corrosion", {})
	var stacks := mini(maxi(1, int(effect.get("max_stacks", 2))), int(corrosion.get("stacks", 0)) + 1)
	corrosion["stacks"] = stacks
	corrosion["strength"] = float(effect.get("armor_reduction", 3.0)) * float(stacks)
	corrosion["ttl"] = maxf(0.05, float(effect.get("duration", 4.0)))
	corrosion["damage_per_second"] = 0.0
	corrosion["ability_id"] = "corrosion"
	statuses["corrosion"] = corrosion
	target["statuses"] = statuses
	_add_visual_effect("corrosion", Vector2(target["pos"]), str(target["team"]), "status", 0.55)


func _apply_toxic_stack(target: Dictionary, projectile: Dictionary, base_damage: float, effect: Dictionary) -> void:
	var statuses: Dictionary = target.get("statuses", {})
	var poison: Dictionary = statuses.get("poison", {})
	var stacks: Array = poison.get("stacks", [])
	var maximum_stacks := maxi(1, int(effect.get("max_stacks", 3)))
	var duration := maxf(0.25, float(effect.get("duration", 5.0)))
	var damage_per_second := base_damage * maxf(0.0, float(effect.get("total_poison_ratio", 0.18))) / duration
	if stacks.size() < maximum_stacks:
		stacks.append({"ttl": duration, "damage_per_second": damage_per_second})
	elif not stacks.is_empty():
		# At cap, refresh the oldest stack without increasing the stack count or DPS.
		var oldest_index := 0
		var oldest_ttl := INF
		for index in stacks.size():
			var stack: Dictionary = stacks[index]
			if float(stack.get("ttl", 0.0)) < oldest_ttl:
				oldest_ttl = float(stack.get("ttl", 0.0))
				oldest_index = index
		stacks[oldest_index] = {"ttl": duration, "damage_per_second": damage_per_second}
	poison["stacks"] = stacks
	poison["ttl"] = duration
	poison["tick_timer"] = float(poison.get("tick_timer", 0.0))
	poison["ability_id"] = "toxic_payload"
	poison["source_id"] = int(projectile.get("source_id", -1))
	statuses["poison"] = poison
	target["statuses"] = statuses
	_add_visual_effect("toxic_payload", Vector2(target["pos"]), str(target["team"]), "status", 0.55)


func _apply_shockwave_control(projectile: Dictionary, position: Vector2, effect: Dictionary) -> void:
	var radius := maxf(1.0, float(projectile.get("aoe", 0.0)))
	var team := str(projectile["team"])
	var opposing_team := "red" if team == "blue" else "blue"
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if not _unit_by_id.has(target_id):
			continue
		var target: Dictionary = _unit_by_id[target_id]
		if position.distance_to(Vector2(target["pos"])) > radius + float(target["radius"]):
			continue
		if bool(effect.get("applies_slow", false)):
			_apply_status(target, "frost", maxf(0.05, float(effect.get("slow_duration", 1.5))), clampf(float(effect.get("slow_ratio", 0.20)), 0.0, 0.8), 0.0, "shockwave_round")
		var stun_duration := maxf(0.0, float(effect.get("normal_stun", 0.0)))
		if stun_duration > 0.0:
			_apply_status(target, "paralysis", stun_duration, 1.0, 0.0, "shockwave_round")
	_knockback_area(team, position, radius, maxf(0.0, float(effect.get("knockback", 60.0))))
	_add_visual_effect("shockwave_round", position, team, "control", 0.65)


func _spawn_gravity_effect(projectile: Dictionary, position: Vector2, effect: Dictionary) -> void:
	var duration := maxf(0.25, float(effect.get("duration", 2.5)))
	var interval := 0.25
	effects.append({
		"id": _take_entity_id(), "kind": "damage_area", "ability_id": "gravity_warhead", "ability_ids": ["gravity_warhead"],
		"team": str(projectile["team"]), "source_id": int(projectile.get("source_id", -1)), "pos": position,
		"ttl": duration, "timer": 0.0, "interval": interval, "damage": 0.0,
		"radius": maxf(1.0, float(effect.get("radius", 130.0))),
		"slow_ratio": clampf(float(effect.get("slow_ratio", 0.15)), 0.0, 0.8),
		"pull_per_tick": maxf(0.0, float(effect.get("pull_distance", 70.0))) * interval / duration,
	})
	_add_visual_effect("gravity_warhead", position, str(projectile["team"]), "area", 0.65)


func _chain_damage(projectile: Dictionary, primary: Dictionary, effect: Dictionary, ability_id: String) -> void:
	var count := maxi(1, int(effect.get("jumps", effect.get("extra_targets", 2))))
	var ratio := clampf(float(effect.get("jump_damage_ratio", effect.get("ricochet_damage_ratio", 0.55))), 0.0, 2.0)
	var maximum_range := maxf(80.0, float(effect.get("jump_range", effect.get("ricochet_range", 260.0))))
	_chain_damage_fixed(projectile, primary, count, float(projectile.get("damage", 0.0)) * ratio, maximum_range, ability_id)


func _chain_damage_fixed(projectile: Dictionary, primary: Dictionary, count: int, damage: float, maximum_range: float, ability_id: String) -> void:
	var team := str(projectile["team"])
	var opposing_team := "red" if team == "blue" else "blue"
	var candidates: Array[Dictionary] = []
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if not _unit_by_id.has(target_id) or target_id == int(primary["id"]):
			continue
		var candidate: Dictionary = _unit_by_id[target_id]
		if float(candidate["hp"]) > 0.0 and Vector2(primary["pos"]).distance_to(Vector2(candidate["pos"])) <= maximum_range:
			candidates.append(candidate)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := Vector2(primary["pos"]).distance_squared_to(Vector2(a["pos"]))
		var db := Vector2(primary["pos"]).distance_squared_to(Vector2(b["pos"]))
		return da < db or (is_equal_approx(da, db) and int(a["id"]) < int(b["id"]))
	)
	var source := _source_record(projectile)
	for index in mini(count, candidates.size()):
		var target := candidates[index]
		var dealt := _damage_unit(target, damage, "projectile", source, float(projectile.get("armor_penetration", 0.0)), [ability_id])
		if not source.is_empty():
			_apply_lifesteal(source, dealt)
		_add_visual_effect(ability_id, Vector2(target["pos"]), team, "chain", 0.55)


func _spawn_mine_effect(projectile: Dictionary, position: Vector2, effect: Dictionary) -> bool:
	var owner_cap := maxi(1, int(effect.get("max_per_unit", 2)))
	var team_cap := maxi(1, int(effect.get("team_cap", 24)))
	if _persistent_effect_count("mine", str(projectile["team"]), int(projectile.get("source_id", -1))) >= owner_cap or _persistent_effect_count("mine", str(projectile["team"]), -1) >= team_cap:
		return false
	effects.append({
		"id": _take_entity_id(), "kind": "mine", "ability_id": "mine_round", "ability_ids": ["mine_round"],
		"team": str(projectile["team"]), "source_id": int(projectile.get("source_id", -1)), "pos": position,
		"ttl": maxf(1.0, float(effect.get("mine_ttl", 10.0))), "timer": maxf(0.05, float(effect.get("arming_time", 0.7))),
		"damage": float(projectile.get("damage", 0.0)) * maxf(0.1, float(effect.get("trigger_damage_ratio", 1.0))),
		"radius": maxf(25.0, float(effect.get("trigger_radius", 75.0))), "armed": false,
	})
	_add_visual_effect("mine_round", position, str(projectile["team"]), "mine", 0.65)
	return true


func _spawn_area_effect(ability_id: String, team: String, position: Vector2, source: Dictionary, effect: Dictionary, damage: float, duration: float, radius: float) -> void:
	if ability_id == "lingering_projectile":
		var owner_cap := maxi(1, int(effect.get("max_per_unit", 2)))
		var team_cap := maxi(1, int(effect.get("team_cap", 16)))
		if _persistent_effect_count("damage_area", team, int(source.get("id", -1)), ability_id) >= owner_cap or _persistent_effect_count("damage_area", team, -1, ability_id) >= team_cap:
			return
	effects.append({
		"id": _take_entity_id(), "kind": "damage_area", "ability_id": ability_id, "ability_ids": [ability_id],
		"team": team, "source_id": int(source.get("id", -1)), "pos": position,
		"ttl": maxf(0.2, duration), "timer": 0.0, "interval": maxf(0.1, float(effect.get("tick_interval", 0.45))),
		"damage": maxf(0.0, damage), "radius": radius,
	})
	_add_visual_effect(ability_id, position, team, "area", 0.65)


func _persistent_effect_count(kind: String, team: String, source_id: int = -1, ability_id: String = "") -> int:
	var total := 0
	for effect in effects:
		if str(effect.get("kind", "")) != kind or str(effect.get("team", "")) != team or float(effect.get("ttl", 0.0)) <= 0.0:
			continue
		if source_id >= 0 and int(effect.get("source_id", -1)) != source_id:
			continue
		if not ability_id.is_empty() and str(effect.get("ability_id", "")) != ability_id:
			continue
		total += 1
	return total


func _add_delayed_area_effect(ability_id: String, team: String, position: Vector2, source: Dictionary, damage: float, radius: float, delay: float) -> void:
	effects.append({
		"id": _take_entity_id(), "kind": "delayed_area", "ability_id": ability_id, "ability_ids": [ability_id],
		"team": team, "source_id": int(source.get("id", -1)), "pos": position,
		"ttl": maxf(0.01, delay), "timer": maxf(0.01, delay), "damage": damage, "radius": radius, "triggered": false,
	})


func _add_delayed_target_effect(ability_id: String, team: String, source_id: int, target_kind: String, target_id: int, damage: float, delay: float) -> void:
	var target := _target_record(target_kind, target_id)
	if target.is_empty():
		return
	effects.append({
		"id": _take_entity_id(), "kind": "delayed_target", "ability_id": ability_id, "ability_ids": [ability_id],
		"team": team, "source_id": source_id, "target_kind": target_kind, "target_id": target_id,
		"pos": Vector2(target["pos"]), "ttl": maxf(0.01, delay), "timer": maxf(0.01, delay), "damage": damage, "triggered": false,
	})


func _damage_area(team: String, position: Vector2, radius: float, damage: float, source: Dictionary, ability_ids: Array, excluded_id: int = -1) -> void:
	var opposing_team := "red" if team == "blue" else "blue"
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if target_id == excluded_id or not _unit_by_id.has(target_id):
			continue
		var target: Dictionary = _unit_by_id[target_id]
		if float(target["hp"]) > 0.0 and position.distance_to(Vector2(target["pos"])) <= radius + float(target["radius"]):
			var dealt := _damage_unit(target, damage, "area", source, 0.0, ability_ids)
			if not source.is_empty():
				_apply_lifesteal(source, dealt)
	if team == "red" and mode == "challenge" and not hero.is_empty() and float(hero.get("hp", 0.0)) > 0.0:
		if position.distance_to(Vector2(hero["pos"])) <= radius + float(hero["radius"]):
			_damage_hero(damage, source, ability_ids)


func _knockback_area(team: String, position: Vector2, radius: float, distance: float) -> void:
	var opposing_team := "red" if team == "blue" else "blue"
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if not _unit_by_id.has(target_id):
			continue
		var target: Dictionary = _unit_by_id[target_id]
		var offset := Vector2(target["pos"]) - position
		if offset.length() <= radius + float(target["radius"]) and offset.length_squared() > 0.001:
			target["pos"] = _clamp_to_arena(Vector2(target["pos"]) + offset.normalized() * distance, float(target["radius"]))


func _trigger_melee_mobility(unit: Dictionary, target: Dictionary) -> float:
	var dash := _special(unit, "dash")
	var cooldowns: Dictionary = unit["upgrade_cooldowns"]
	var damage_multiplier := 1.0
	if not dash.is_empty() and float(cooldowns.get("dash", 0.0)) <= 0.0:
		var direction := (Vector2(target["pos"]) - Vector2(unit["pos"])).normalized()
		var distance := minf(float(dash.get("distance", 100.0)), maxf(0.0, Vector2(unit["pos"]).distance_to(Vector2(target["pos"])) - float(unit["radius"]) - float(target["radius"])))
		unit["pos"] = _clamp_to_arena(Vector2(unit["pos"]) + direction * distance, float(unit["radius"]))
		damage_multiplier = maxf(0.0, float(dash.get("damage_ratio", 1.20)))
		unit["dash_damage_reduction"] = clampf(float(dash.get("during_dash_damage_reduction", 0.50)), 0.0, 0.9)
		unit["dash_reduction_ttl"] = 0.20
		cooldowns["dash"] = maxf(0.5, float(dash.get("cooldown", 6.0)))
		_add_visual_effect("dash", Vector2(unit["pos"]), str(unit["team"]), "dash", 0.55)
	unit["upgrade_cooldowns"] = cooldowns
	return damage_multiplier


func _apply_melee_specials(unit: Dictionary, primary: Dictionary, _dealt: float) -> void:
	var burning := _special(unit, "burning_sword")
	if not burning.is_empty():
		_apply_dot_from_total(primary, "burn", "burning_sword", float(unit["attack"]), burning, "total_burn_ratio", 0.24)
	var cooldowns: Dictionary = unit["upgrade_cooldowns"]
	var stomp := _special(unit, "stomp")
	if not stomp.is_empty() and float(cooldowns.get("stomp", 0.0)) <= 0.0:
		var radius := maxf(45.0, float(stomp.get("radius", 110.0)))
		_damage_area(str(unit["team"]), Vector2(unit["pos"]), radius, float(unit["attack"]) * float(stomp.get("damage_ratio", 0.55)), unit, ["stomp"], int(primary["id"]))
		if bool(stomp.get("applies_short_stun", false)):
			_apply_area_simple_status(str(unit["team"]), Vector2(unit["pos"]), radius, "paralysis", maxf(0.05, float(stomp.get("stun_duration", 0.45))), 1.0, "stomp")
		cooldowns["stomp"] = maxf(1.0, float(stomp.get("cooldown", 7.0)))
		_add_visual_effect("stomp", Vector2(unit["pos"]), str(unit["team"]), "area", 0.7)
	var sweep := _special(unit, "sweeping_slash")
	if not sweep.is_empty() and float(cooldowns.get("sweeping_slash", 0.0)) <= 0.0:
		_damage_nearest_area_targets(str(unit["team"]), Vector2(unit["pos"]), maxf(40.0, float(unit["range"]) + 42.0), float(unit["attack"]) * float(sweep.get("sweep_damage_ratio", 0.60)), unit, "sweeping_slash", int(primary["id"]), maxi(1, int(sweep.get("extra_targets", 2))))
		cooldowns["sweeping_slash"] = maxf(0.8, float(sweep.get("cooldown", 4.0)))
		_add_visual_effect("sweeping_slash", Vector2(unit["pos"]), str(unit["team"]), "sweep", 0.55)
	unit["upgrade_cooldowns"] = cooldowns


func _apply_area_simple_status(team: String, position: Vector2, radius: float, status_id: String, duration: float, strength: float, ability_id: String) -> void:
	var opposing_team := "red" if team == "blue" else "blue"
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if not _unit_by_id.has(target_id):
			continue
		var target: Dictionary = _unit_by_id[target_id]
		if Vector2(target["pos"]).distance_to(position) <= radius + float(target["radius"]):
			_apply_status(target, status_id, duration, strength, 0.0, ability_id)


func _damage_nearest_area_targets(team: String, position: Vector2, radius: float, damage: float, source: Dictionary, ability_id: String, excluded_id: int, limit: int) -> void:
	var opposing_team := "red" if team == "blue" else "blue"
	var candidates: Array[Dictionary] = []
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if target_id == excluded_id or not _unit_by_id.has(target_id):
			continue
		var target: Dictionary = _unit_by_id[target_id]
		if float(target["hp"]) > 0.0 and Vector2(target["pos"]).distance_to(position) <= radius + float(target["radius"]):
			candidates.append(target)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := position.distance_squared_to(Vector2(a["pos"]))
		var db := position.distance_squared_to(Vector2(b["pos"]))
		return da < db or (is_equal_approx(da, db) and int(a["id"]) < int(b["id"]))
	)
	for index in mini(limit, candidates.size()):
		_damage_unit(candidates[index], damage, "melee", source, 0.0, [ability_id])


func _rally_damage_multiplier(unit: Dictionary) -> float:
	return 1.0


func _rally_attack_speed_multiplier(unit: Dictionary) -> float:
	return maxf(1.0, float(unit.get("arena_aura_attack_speed", 1.0)))


func _rally_move_speed_multiplier(unit: Dictionary) -> float:
	return maxf(1.0, float(unit.get("arena_aura_move_speed", 1.0)))


func _ally_damage_taken_multiplier(unit: Dictionary) -> float:
	return clampf(float(unit.get("arena_aura_damage_taken", 1.0)), 0.15, 1.0)


func _refresh_unit_auras(unit: Dictionary) -> void:
	var attack_speed_multiplier := 1.0
	var move_speed_multiplier := 1.0
	var strongest_guardian_reduction := 0.0
	for ally_id_value in Array(_team_unit_ids[str(unit["team"])]):
		var ally_id := int(ally_id_value)
		if not _unit_by_id.has(ally_id):
			continue
		var ally: Dictionary = _unit_by_id[ally_id]
		var distance := Vector2(ally["pos"]).distance_to(Vector2(unit["pos"]))
		var rally := _special(ally, "rally_beacon")
		if not rally.is_empty() and distance <= maxf(80.0, float(rally.get("radius", 230.0))):
			attack_speed_multiplier = maxf(attack_speed_multiplier, 1.0 + maxf(0.0, float(rally.get("ally_attack_speed_bonus", 0.12))))
			move_speed_multiplier = maxf(move_speed_multiplier, 1.0 + maxf(0.0, float(rally.get("ally_move_speed_bonus", 0.10))))
		var guardian_aura := _special(ally, "guardian_aura")
		if not guardian_aura.is_empty() and distance <= maxf(80.0, float(guardian_aura.get("radius", 220.0))):
			strongest_guardian_reduction = maxf(strongest_guardian_reduction, clampf(float(guardian_aura.get("ally_damage_reduction", 0.10)), 0.0, 0.7))
	unit["arena_aura_damage"] = 1.0
	unit["arena_aura_attack_speed"] = attack_speed_multiplier
	unit["arena_aura_move_speed"] = move_speed_multiplier
	unit["arena_aura_damage_taken"] = 1.0 - strongest_guardian_reduction


func _apply_lifesteal(source: Dictionary, dealt_damage: float) -> void:
	if source.is_empty() or dealt_damage <= 0.0 or not source.has("upgrade_snapshot"):
		return
	var lifesteal := _special(source, "lifesteal")
	if lifesteal.is_empty() or float(source.get("hp", 0.0)) <= 0.0:
		return
	var ratio := clampf(float(lifesteal.get("lifesteal_ratio", 0.08)), 0.0, 1.0)
	var state: Dictionary = source["special_runtime"]
	var window := int(floor(battle_time))
	if int(state.get("arena_lifesteal_window", -1)) != window:
		state["arena_lifesteal_window"] = window
		state["arena_lifesteal_spent"] = 0.0
	var cap := float(source["max_hp"]) * clampf(float(lifesteal.get("max_hp_heal_cap_per_second_ratio", 0.08)), 0.0, 1.0)
	var remaining := maxf(0.0, cap - float(state.get("arena_lifesteal_spent", 0.0)))
	var healing := minf(remaining, minf(dealt_damage * ratio, float(source["max_hp"]) - float(source["hp"])))
	if healing > 0.0:
		source["hp"] = float(source["hp"]) + healing
		state["arena_lifesteal_spent"] = float(state.get("arena_lifesteal_spent", 0.0)) + healing
		_add_visual_effect("lifesteal", Vector2(source["pos"]), str(source["team"]), "heal", 0.55)
	source["special_runtime"] = state


func _try_resurrection(unit: Dictionary) -> bool:
	var ritual := _special(unit, "resurrection_ritual")
	if ritual.is_empty() or units.size() >= MAX_BATTLE_UNITS:
		return false
	var cooldowns: Dictionary = unit["upgrade_cooldowns"]
	if float(cooldowns.get("resurrection_ritual", 0.0)) > 0.0:
		return false
	var grave: Dictionary = {}
	for candidate in effects:
		if str(candidate.get("kind", "")) == "grave" and str(candidate.get("team", "")) == str(unit["team"]) and not bool(candidate.get("revived", false)):
			grave = candidate
			break
	if grave.is_empty():
		return false
	grave["revived"] = true
	grave["ttl"] = 0.0
	var chant_time := maxf(0.05, float(ritual.get("chant_time", 2.3)))
	effects.append({
		"id": _take_entity_id(), "kind": "resurrection_chant", "ability_id": "resurrection_ritual", "ability_ids": ["resurrection_ritual"],
		"team": str(unit["team"]), "source_id": int(unit["id"]), "pos": Vector2(grave["pos"]),
		"ttl": chant_time, "timer": chant_time, "unit_type": str(grave.get("unit_type", "swordsman")),
		"revive_hp_ratio": clampf(float(ritual.get("revive_hp_ratio", 0.55)), 0.05, 1.0),
		"soul_shelter": _special(unit, "soul_shelter"), "triggered": false,
	})
	cooldowns["resurrection_ritual"] = maxf(0.1, float(ritual.get("cooldown", 12.0)))
	unit["upgrade_cooldowns"] = cooldowns
	_add_visual_effect("resurrection_ritual", Vector2(grave["pos"]), str(unit["team"]), "chant", chant_time)
	return true


func _complete_resurrection(effect: Dictionary) -> void:
	if units.size() >= MAX_BATTLE_UNITS:
		return
	var source_id := int(effect.get("source_id", -1))
	if not _unit_by_id.has(source_id) or float(Dictionary(_unit_by_id[source_id]).get("hp", 0.0)) <= 0.0:
		return
	var team := str(effect["team"])
	var type_id := str(effect.get("unit_type", "swordsman"))
	var revived := _create_unit(type_id, team, _clamp_to_arena(Vector2(effect["pos"]), soldier_radius(type_id)))
	revived["hp"] = float(revived["max_hp"]) * clampf(float(effect.get("revive_hp_ratio", 0.55)), 0.05, 1.0)
	var shelter: Dictionary = effect.get("soul_shelter", {})
	if not shelter.is_empty():
		revived["post_revive_reduction"] = clampf(float(shelter.get("revived_damage_reduction", 0.30)), 0.0, 0.9)
		revived["post_revive_reduction_ttl"] = maxf(0.05, float(shelter.get("reduction_duration", 3.0)))
	units.append(revived)
	_unit_by_id[int(revived["id"])] = revived
	var ids: Array = _team_unit_ids[team]
	ids.append(int(revived["id"]))
	_team_unit_ids[team] = ids
	_alive_counts[team] = int(_alive_counts[team]) + 1
	_add_visual_effect("resurrection_ritual", Vector2(revived["pos"]), team, "resurrect", 1.0)
	if not shelter.is_empty():
		_add_visual_effect("soul_shelter", Vector2(revived["pos"]), team, "protect", 0.9)


func _update_effects(delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		var effect := effects[index]
		var kind := str(effect.get("kind", "visual"))
		effect["ttl"] = float(effect.get("ttl", 0.0)) - delta
		match kind:
			"visual":
				pass
			"grave":
				pass
			"resurrection_chant":
				if float(effect["ttl"]) <= 0.0 and not bool(effect.get("triggered", false)):
					effect["triggered"] = true
					_complete_resurrection(effect)
			"meteor":
				var initial_warning := maxf(0.01, float(effect.get("initial_warning", effect.get("timer", 0.01))))
				effect["timer"] = maxf(0.0, float(effect["ttl"]))
				var fall_progress := clampf(1.0 - float(effect["timer"]) / initial_warning, 0.0, 1.0)
				effect["progress"] = fall_progress
				effect["fall_progress"] = fall_progress
				if float(effect["ttl"]) <= 0.0 and not bool(effect.get("triggered", false)):
					effect["triggered"] = true
					var source := _effect_source(effect)
					_damage_area(str(effect["team"]), Vector2(effect["pos"]), float(effect["radius"]), float(effect["damage"]), source, ["meteor"])
					_add_visual_effect("meteor", Vector2(effect["pos"]), str(effect["team"]), "impact", 0.9)
			"delayed_area":
				if float(effect["ttl"]) <= 0.0 and not bool(effect.get("triggered", false)):
					effect["triggered"] = true
					_damage_area(str(effect["team"]), Vector2(effect["pos"]), float(effect["radius"]), float(effect["damage"]), _effect_source(effect), [str(effect["ability_id"])])
					_add_visual_effect(str(effect["ability_id"]), Vector2(effect["pos"]), str(effect["team"]), "impact", 0.65)
			"delayed_target":
				var target := _target_record(str(effect.get("target_kind", "unit")), int(effect.get("target_id", -1)))
				if not target.is_empty():
					effect["pos"] = Vector2(target["pos"])
				if float(effect["ttl"]) <= 0.0 and not bool(effect.get("triggered", false)):
					effect["triggered"] = true
					if not target.is_empty():
						_damage_target(str(effect.get("target_kind", "unit")), target, float(effect["damage"]), "area", _effect_source(effect), 0.0, [str(effect["ability_id"])])
			"damage_area":
				effect["timer"] = float(effect.get("timer", 0.0)) - delta
				if float(effect["timer"]) <= 0.0:
					effect["timer"] = maxf(0.1, float(effect.get("interval", 0.45)))
					if float(effect.get("damage", 0.0)) > 0.0:
						_damage_area(str(effect["team"]), Vector2(effect["pos"]), float(effect["radius"]), float(effect["damage"]), _effect_source(effect), [str(effect["ability_id"])])
					_apply_area_status(effect)
			"mine":
				_update_mine_effect(effect, delta)
			"turret":
				_update_turret_effect(effect, delta)
			"repair_drone":
				_update_repair_drone_effect(effect, delta)
		if float(effect.get("ttl", 0.0)) <= 0.0:
			effects.remove_at(index)


func _effect_source(effect: Dictionary) -> Dictionary:
	var source_id := int(effect.get("source_id", -1))
	return _unit_by_id[source_id] if _unit_by_id.has(source_id) else {}


func _update_mine_effect(effect: Dictionary, delta: float) -> void:
	effect["timer"] = float(effect.get("timer", 0.0)) - delta
	if not bool(effect.get("armed", false)):
		if float(effect["timer"]) <= 0.0:
			effect["armed"] = true
			effect["timer"] = 0.1
		return
	if float(effect["timer"]) > 0.0:
		return
	effect["timer"] = 0.1
	var target := _nearest_opposing_unit(str(effect["team"]), Vector2(effect["pos"]), float(effect["radius"]), true)
	if target.is_empty():
		return
	_damage_area(str(effect["team"]), Vector2(effect["pos"]), float(effect["radius"]), float(effect["damage"]), _effect_source(effect), ["mine_round"])
	_add_visual_effect("mine_round", Vector2(effect["pos"]), str(effect["team"]), "impact", 0.75)
	effect["ttl"] = 0.0


func _update_turret_effect(effect: Dictionary, delta: float) -> void:
	effect["timer"] = float(effect.get("timer", 0.0)) - delta
	if float(effect["timer"]) > 0.0:
		return
	var target := _nearest_opposing_unit(str(effect["team"]), Vector2(effect["pos"]), float(effect["range"]), true)
	if target.is_empty():
		effect["timer"] = 0.15
		return
	_spawn_basic_projectile(int(effect["id"]), "turret", str(effect["team"]), Vector2(effect["pos"]), int(target["id"]), "unit", float(effect["damage"]), float(effect["range"]), ["auto_turret"], {}, {})
	effect["timer"] = float(effect["interval"])


func _update_repair_drone_effect(effect: Dictionary, delta: float) -> void:
	effect["timer"] = float(effect.get("timer", 0.0)) - delta
	if float(effect["timer"]) > 0.0:
		return
	effect["timer"] = 0.5
	var best: Dictionary = {}
	var best_ratio := 1.0
	for ally_id_value in Array(_team_unit_ids[str(effect["team"])]):
		var ally_id := int(ally_id_value)
		if not _unit_by_id.has(ally_id):
			continue
		var ally: Dictionary = _unit_by_id[ally_id]
		var type_id := str(ally["type"])
		var is_vehicle_or_air := type_id in ["roller", "cannon", "tank", "rocket", "gatling", "helicopter", "bomber", "ufo"]
		var ratio := float(ally["hp"]) / maxf(1.0, float(ally["max_hp"]))
		if is_vehicle_or_air and ratio < best_ratio and Vector2(effect["pos"]).distance_to(Vector2(ally["pos"])) <= float(effect["range"]):
			best_ratio = ratio
			best = ally
	if not best.is_empty():
		best["hp"] = minf(float(best["max_hp"]), float(best["hp"]) + float(best["max_hp"]) * float(effect["heal_ratio"]) * 0.5)
		_add_visual_effect("repair_drone", Vector2(best["pos"]), str(effect["team"]), "repair", 0.45)


func _apply_area_status(effect: Dictionary) -> void:
	var ability_id := str(effect.get("ability_id", ""))
	if ability_id not in ["gravity_warhead", "burning_zone"]:
		return
	var opposing_team := "red" if str(effect["team"]) == "blue" else "blue"
	for target_id_value in Array(_team_unit_ids[opposing_team]):
		var target_id := int(target_id_value)
		if not _unit_by_id.has(target_id):
			continue
		var target: Dictionary = _unit_by_id[target_id]
		if Vector2(effect["pos"]).distance_to(Vector2(target["pos"])) <= float(effect["radius"]):
			if ability_id == "gravity_warhead":
				var toward_center := Vector2(effect["pos"]) - Vector2(target["pos"])
				if toward_center.length_squared() > 0.001:
					target["pos"] = _clamp_to_arena(Vector2(target["pos"]) + toward_center.normalized() * minf(float(effect.get("pull_per_tick", 0.0)), toward_center.length()), float(target["radius"]))
				_apply_status(target, "gravity", maxf(0.05, float(effect.get("ttl", 0.05))), float(effect.get("slow_ratio", 0.15)), 0.0, ability_id)
			else:
				_apply_status(target, "burn", 0.8, 0.0, float(effect["damage"]) * 0.35, ability_id)


func _check_battle_result(delta: float) -> void:
	var blue_alive := int(_alive_counts["blue"]) + (1 if not hero.is_empty() and float(hero.get("hp", 0.0)) > 0.0 else 0)
	var red_alive := int(_alive_counts["red"])
	if winner.is_empty():
		if blue_alive <= 0 and red_alive <= 0:
			winner = "draw"
		elif red_alive <= 0:
			winner = "blue"
		elif blue_alive <= 0:
			winner = "red"
		if not winner.is_empty():
			_result_timer = RESULT_DELAY
	else:
		_result_timer = maxf(0.0, _result_timer - delta)
		if _result_timer <= 0.0:
			phase = "result"


func _add_visual_effect(ability_id: String, position: Vector2, team: String, kind: String, ttl: float) -> void:
	if effects.size() >= MAX_EFFECTS:
		return
	var safe_id := ability_id if not ability_id.is_empty() else "impact"
	effects.append({
		"id": _take_entity_id(), "kind": "visual", "event_kind": kind,
		"ability_id": safe_id, "ability_ids": [safe_id], "team": team, "pos": position,
		"ttl": maxf(0.05, ttl), "radius": 24.0,
		"color": SoldierUpgradeVfxCatalog.color_for(safe_id),
	})


func _first_visual_id(ability_ids: Array, fallback: String) -> String:
	for ability_id_value in ability_ids:
		var ability_id := str(ability_id_value)
		if SoldierUpgradeVfxCatalog.visual_index(ability_id) >= 0:
			return ability_id
	return fallback


func _special(unit: Dictionary, ability_id: String) -> Dictionary:
	var snapshot: Dictionary = unit.get("upgrade_snapshot", {})
	var specials: Dictionary = snapshot.get("special_effects", {})
	return specials.get(ability_id, {})


func _has_special(unit: Dictionary, ability_id: String) -> bool:
	return not _special(unit, ability_id).is_empty()


func _strongest_team_special(team: String, ability_id: String) -> Dictionary:
	var strongest: Dictionary = {}
	var strongest_rank := 0
	for ally_id_value in Array(_team_unit_ids[team]):
		var ally_id := int(ally_id_value)
		if not _unit_by_id.has(ally_id):
			continue
		var ally: Dictionary = _unit_by_id[ally_id]
		var snapshot: Dictionary = ally.get("upgrade_snapshot", {})
		var rank := int(Dictionary(snapshot.get("special_ranks", {})).get(ability_id, 0))
		if rank > strongest_rank:
			strongest_rank = rank
			strongest = _special(ally, ability_id)
	return strongest


static func self_test() -> Dictionary:
	var errors: Array[String] = []

	var setup := ArenaController.new()
	_assert_self_test(setup.phase == "mode", "setup_starts_at_mode", errors)
	_assert_self_test(setup.choose_mode("spectator") and setup.phase == "types", "mode_to_types", errors)
	setup.set_active_team("blue")
	setup.toggle_type("archer")
	setup.toggle_type("healer")
	setup.set_active_team("red")
	setup.toggle_type("swordsman")
	_assert_self_test(setup.confirm_types() and setup.phase == "counts", "types_to_counts_first_confirmation", errors)
	setup.set_active_team("blue")
	_assert_self_test(setup.adjust_count("archer", 2) == 3, "count_plus_stage", errors)
	_assert_self_test(setup.confirm_counts() and setup.phase == "upgrades", "counts_to_upgrades_second_confirmation", errors)
	setup.set_active_team("blue")
	var blue_attack_rank := setup.adjust_upgrade("attack_or_healing", 1, "blue", "archer")
	var blue_frost_rank := setup.adjust_upgrade("frost_arrow", 1, "blue", "archer")
	var blue_range_rank := SoldierUpgradeCatalog.current_rank("archer", "range", setup.team_research["blue"])
	var red_attack_rank := SoldierUpgradeCatalog.current_rank("archer", "attack_or_healing", setup.team_research["red"])
	_assert_self_test(blue_attack_rank == 1 and red_attack_rank == 0, "team_research_is_independent", errors)
	_assert_self_test(blue_frost_rank == 1 and blue_range_rank >= 2, "special_auto_satisfies_base_prerequisite", errors)

	var small := ArenaController.new()
	small.choose_mode("spectator")
	small.set_active_team("blue")
	small.toggle_type("swordsman")
	small.set_active_team("red")
	small.toggle_type("swordsman")
	small.confirm_types()
	small.confirm_counts()
	small.start_battle()
	var small_area := small.arena_rect.size.x * small.arena_rect.size.y

	var large := ArenaController.new()
	large.choose_mode("spectator")
	large.set_active_team("blue")
	large.toggle_type("ufo")
	large.set_active_team("red")
	large.toggle_type("ufo")
	large.confirm_types()
	large.set_active_team("blue")
	large.adjust_count("ufo", 29)
	large.set_active_team("red")
	large.adjust_count("ufo", 29)
	large.confirm_counts()
	large.start_battle()
	var large_area := large.arena_rect.size.x * large.arena_rect.size.y
	_assert_self_test(large_area > small_area, "arena_grows_with_count_and_radius", errors)

	_assert_self_test(setup.start_battle() and setup.hero.is_empty(), "spectator_has_no_hero", errors)
	for _frame in 240:
		setup.update(1.0 / 60.0, {})
	var spectator_has_hero_target := false
	for unit in setup.units:
		if str(unit.get("target_kind", "")) == "hero":
			spectator_has_hero_target = true
			break
	for projectile in setup.projectiles:
		if str(projectile.get("target_kind", "")) == "hero":
			spectator_has_hero_target = true
			break
	_assert_self_test(not spectator_has_hero_target, "spectator_never_targets_hero", errors)

	var challenge := ArenaController.new()
	challenge.choose_mode("challenge")
	challenge.set_active_team("red")
	challenge.toggle_type("archer")
	challenge.confirm_types()
	challenge.confirm_counts()
	_assert_self_test(challenge.start_battle({"max_hp": 500.0, "attack": 40.0}) and not challenge.hero.is_empty(), "challenge_creates_hero", errors)

	var handlers_cover_catalog := SPECIAL_BEHAVIORS.size() == SoldierUpgradeRuntime.CATALOG_IDS.size()
	for ability_id in SoldierUpgradeRuntime.CATALOG_IDS:
		if not SPECIAL_BEHAVIORS.has(ability_id) or SoldierUpgradeVfxCatalog.visual_index(ability_id) < 0:
			handlers_cover_catalog = false
			break
	for ability_id_value in SPECIAL_BEHAVIORS.keys():
		if str(ability_id_value) not in SoldierUpgradeRuntime.CATALOG_IDS:
			handlers_cover_catalog = false
			break
	_assert_self_test(handlers_cover_catalog, "all_57_specials_have_arena_behavior_and_vfx", errors)
	var capability_checks := _run_capability_self_tests(errors)

	return {
		"passed": errors.is_empty(),
		"ok": errors.is_empty(),
		"errors": errors,
		"special_behaviors": SPECIAL_BEHAVIORS.size(),
		"capability_checks": capability_checks,
	}


static func _assert_self_test(condition: bool, label: String, errors: Array[String]) -> void:
	if not condition:
		errors.append(label)


static func _make_test_arena(blue_types: Array[String], red_types: Array[String]) -> ArenaController:
	var arena := ArenaController.new()
	arena.choose_mode("spectator")
	for team in TEAMS:
		arena.set_active_team(team)
		var choices := blue_types if team == "blue" else red_types
		for type_id in choices:
			arena.toggle_type(type_id)
	arena.confirm_types()
	arena.confirm_counts()
	return arena


static func _make_challenge_test_arena(class_id: String) -> ArenaController:
	var arena := ArenaController.new()
	arena.choose_mode("challenge")
	arena.set_active_team("red")
	arena.toggle_type("swordsman")
	arena.confirm_types()
	arena.confirm_counts()
	var class_data: Dictionary = GameConfig.HERO_CLASSES[class_id]
	var stats: Dictionary = class_data["base_stats"]
	var normal: Dictionary = class_data["normal_attack"]
	arena.start_battle({
		"class_id": class_id,
		"max_hp": float(stats["hp"]),
		"hp": float(stats["hp"]),
		"attack": float(stats["attack"]),
		"defense": float(stats["defense"]),
		"speed": float(stats["speed"]),
		"range": float(normal["range"]),
		"attack_rate": float(normal["attack_speed"]),
	})
	return arena


static func _test_unit(arena: ArenaController, team: String, type_id: String, ordinal: int = 0) -> Dictionary:
	var seen := 0
	for unit in arena.units:
		if str(unit.get("team", "")) == team and str(unit.get("type", "")) == type_id:
			if seen == ordinal:
				return unit
			seen += 1
	return {}


static func _has_effect_id(arena: ArenaController, ability_id: String) -> bool:
	for effect in arena.effects:
		if str(effect.get("ability_id", "")) == ability_id:
			return true
	return false


static func _run_capability_self_tests(errors: Array[String]) -> int:
	var checks := 0

	# Split Shot: exactly one full-damage center projectile and two rank-scaled children.
	var split := _make_test_arena(["archer"], ["swordsman"])
	split.adjust_upgrade("split_shot", 1, "blue", "archer")
	split.start_battle()
	var split_archer := _test_unit(split, "blue", "archer")
	var split_target := _test_unit(split, "red", "swordsman")
	split.projectiles.clear()
	split._perform_unit_attack(split_archer, split_target, "unit")
	var full_projectiles := 0
	var child_projectiles := 0
	for projectile in split.projectiles:
		var ratio := float(projectile["damage"]) / float(split_archer["attack"])
		if is_equal_approx(ratio, 1.0): full_projectiles += 1
		if is_equal_approx(ratio, 0.12): child_projectiles += 1
	_assert_self_test(split.projectiles.size() == 3 and full_projectiles == 1 and child_projectiles == 2, "runtime_split_shot_ratio_and_count", errors)
	checks += 1

	# Paralysis Arrow: only the seventh rank-I attack applies the exact stun.
	var paralysis := _make_test_arena(["archer"], ["swordsman"])
	paralysis.adjust_upgrade("paralysis_arrow", 1, "blue", "archer")
	paralysis.start_battle()
	var paralysis_archer := _test_unit(paralysis, "blue", "archer")
	var paralysis_target := _test_unit(paralysis, "red", "swordsman")
	var paralysis_snapshot: Dictionary = paralysis_archer["upgrade_snapshot"]
	var paralysis_specials: Dictionary = paralysis_snapshot["special_effects"]
	for sequence in range(1, 7):
		paralysis._apply_projectile_specials({"team": "blue", "source_id": int(paralysis_archer["id"]), "source_kind": "soldier", "damage": 20.0, "attack_sequence": sequence, "ability_ids": ["paralysis_arrow"], "soldier_specials": paralysis_specials}, paralysis_target, "unit", 0.0)
	_assert_self_test(not Dictionary(paralysis_target["statuses"]).has("paralysis"), "runtime_paralysis_waits_for_interval", errors)
	paralysis._apply_projectile_specials({"team": "blue", "source_id": int(paralysis_archer["id"]), "source_kind": "soldier", "damage": 20.0, "attack_sequence": 7, "ability_ids": ["paralysis_arrow"], "soldier_specials": paralysis_specials}, paralysis_target, "unit", 0.0)
	var paralysis_status: Dictionary = Dictionary(paralysis_target["statuses"]).get("paralysis", {})
	_assert_self_test(is_equal_approx(float(paralysis_status.get("ttl", 0.0)), 0.45), "runtime_paralysis_seventh_exact_duration", errors)
	checks += 2

	# Meteor cooldown is shared by the whole blue army, not one timer per mage.
	var meteor := _make_test_arena(["mage"], ["swordsman"])
	# The helper has already reached upgrades; inject a second selected mage count before spawn.
	meteor.counts["blue"]["mage"] = 2
	meteor.adjust_upgrade("meteor", 1, "blue", "mage")
	meteor.start_battle()
	var meteor_mage_a := _test_unit(meteor, "blue", "mage", 0)
	var meteor_mage_b := _test_unit(meteor, "blue", "mage", 1)
	meteor.effects.clear()
	meteor._tick_periodic_specials(meteor_mage_a, 0.0)
	meteor._tick_periodic_specials(meteor_mage_b, 0.0)
	var meteor_count := 0
	var meteor_record: Dictionary = {}
	for effect in meteor.effects:
		if str(effect.get("kind", "")) == "meteor":
			meteor_count += 1
			meteor_record = effect
	_assert_self_test(meteor_count == 1 and is_equal_approx(float(Dictionary(meteor._team_shared_cooldowns["blue"]).get("meteor", 0.0)), 16.0), "runtime_meteor_army_shared_cooldown", errors)
	checks += 1
	var meteor_warning := float(meteor_record.get("initial_warning", 0.0))
	meteor._update_effects(meteor_warning * 0.25)
	var meteor_progress_ok := meteor_warning > 0.0 and is_equal_approx(float(meteor_record.get("timer", -1.0)), meteor_warning * 0.75) and is_equal_approx(float(meteor_record.get("progress", -1.0)), 0.25) and is_equal_approx(float(meteor_record.get("fall_progress", -1.0)), 0.25)
	_assert_self_test(meteor_progress_ok, "runtime_meteor_exposes_live_fall_progress", errors)
	checks += 1

	# Delayed target effects are born at the target and track it during the
	# countdown; they never spend visible warning time at world origin.
	var delayed := _make_test_arena(["archer"], ["swordsman"])
	delayed.start_battle()
	var delayed_source := _test_unit(delayed, "blue", "archer")
	var delayed_target := _test_unit(delayed, "red", "swordsman")
	delayed_target["pos"] = Vector2(170.0, 90.0)
	delayed.effects.clear()
	delayed._add_delayed_target_effect("temporal_echo", "blue", int(delayed_source["id"]), "unit", int(delayed_target["id"]), 20.0, 1.0)
	var delayed_record: Dictionary = delayed.effects[0] if delayed.effects.size() == 1 else {}
	var delayed_created_at_target := not delayed_record.is_empty() and Vector2(delayed_record.get("pos", Vector2.ZERO)) == Vector2(delayed_target["pos"]) and Vector2(delayed_record["pos"]) != Vector2.ZERO
	delayed_target["pos"] = Vector2(205.0, 66.0)
	delayed._update_effects(0.25)
	var delayed_followed := Vector2(delayed_record.get("pos", Vector2.ZERO)) == Vector2(delayed_target["pos"])
	var delayed_hp_before := float(delayed_target["hp"])
	delayed_target["pos"] = Vector2(231.0, 42.0)
	delayed._update_effects(0.75)
	var delayed_triggered_at_latest_position := Vector2(delayed_record.get("pos", Vector2.ZERO)) == Vector2(231.0, 42.0) and float(delayed_target["hp"]) < delayed_hp_before
	_assert_self_test(delayed_created_at_target and delayed_followed and delayed_triggered_at_latest_position, "runtime_delayed_target_tracks_current_position", errors)
	checks += 1

	# Guardian stats, owner cap, TTL, and non-recursive snapshot.
	var guardian_arena := _make_test_arena(["mage"], ["swordsman"])
	guardian_arena.adjust_upgrade("guardian", 1, "blue", "mage")
	guardian_arena.start_battle()
	var guardian_owner := _test_unit(guardian_arena, "blue", "mage")
	var guardian_effect := guardian_arena._special(guardian_owner, "guardian")
	var guardian_first := guardian_arena._spawn_guardian(guardian_owner, guardian_effect)
	var guardian_second := guardian_arena._spawn_guardian(guardian_owner, guardian_effect)
	var guardian_third := guardian_arena._spawn_guardian(guardian_owner, guardian_effect)
	var summoned_guardian: Dictionary = {}
	for unit in guardian_arena.units:
		if str(unit.get("summon_ability_id", "")) == "guardian": summoned_guardian = unit; break
	var guardian_stats_ok := not summoned_guardian.is_empty() and is_equal_approx(float(summoned_guardian["summon_ttl"]), 14.0) and is_equal_approx(float(summoned_guardian["range"]), 280.0) and is_equal_approx(float(summoned_guardian["attack_rate"]), 1.0 / 1.10) and not guardian_arena._has_special(summoned_guardian, "guardian")
	_assert_self_test(guardian_first and guardian_second and not guardian_third and guardian_stats_ok, "runtime_guardian_ttl_stats_caps_nonrecursive", errors)
	checks += 1

	# Aerial evade must both reduce damage and visibly sidestep on its ready hit.
	var aerial := _make_test_arena(["helicopter"], ["rifleman"])
	aerial.adjust_upgrade("aerial_evade", 1, "blue", "helicopter")
	aerial.start_battle()
	var air_unit := _test_unit(aerial, "blue", "helicopter")
	var air_attacker := _test_unit(aerial, "red", "rifleman")
	var air_before := Vector2(air_unit["pos"])
	aerial.effects.clear()
	aerial._damage_unit(air_unit, 100.0, "projectile", air_attacker, 0.0, ["aerial_evade"])
	_assert_self_test(Vector2(air_unit["pos"]).distance_to(air_before) >= 99.0 and _has_effect_id(aerial, "aerial_evade"), "runtime_aerial_evade_sidestep_and_vfx", errors)
	checks += 1

	# Challenge heroes retain class identity: warrior is true melee, while the
	# archer and mage expose distinct projectile records and visuals.
	var hero_classes_ok := true
	for hero_class_id in ["warrior", "archer", "mage"]:
		var hero_arena := _make_challenge_test_arena(hero_class_id)
		var hero_target := _test_unit(hero_arena, "red", "swordsman")
		hero_target["pos"] = Vector2(hero_arena.hero["pos"]) + Vector2(64.0, 0.0)
		var hero_target_hp := float(hero_target["hp"])
		hero_arena.projectiles.clear()
		hero_arena._update_hero(0.0, {"attack": true})
		if hero_class_id == "warrior":
			hero_classes_ok = hero_classes_ok and hero_arena.projectiles.is_empty() and float(hero_target["hp"]) < hero_target_hp and str(hero_arena.hero.get("last_attack_kind", "")) == "melee"
		else:
			if hero_arena.projectiles.size() != 1:
				hero_classes_ok = false
				continue
			var hero_projectile: Dictionary = hero_arena.projectiles[0]
			var expected_kind := "hero_arrow" if hero_class_id == "archer" else "hero_magic"
			var expected_visual := "hero_archer_arrow" if hero_class_id == "archer" else "hero_mage_magic"
			var aoe_is_correct := is_zero_approx(float(hero_projectile.get("aoe", 0.0))) if hero_class_id == "archer" else float(hero_projectile.get("aoe", 0.0)) > 0.0
			hero_classes_ok = hero_classes_ok and str(hero_projectile.get("kind", "")) == expected_kind and str(hero_projectile.get("visual_id", "")) == expected_visual and expected_visual in Array(hero_projectile.get("ability_ids", [])) and aoe_is_correct
	_assert_self_test(hero_classes_ok, "runtime_challenge_hero_class_attack_identity", errors)
	checks += 1

	# Suppression starts on the exact hit threshold and stores its two separate
	# reductions instead of collapsing them into one generic slow.
	var suppression := _make_test_arena(["rifleman"], ["swordsman"])
	suppression.adjust_upgrade("suppression", 1, "blue", "rifleman")
	suppression.start_battle()
	var suppression_source := _test_unit(suppression, "blue", "rifleman")
	var suppression_target := _test_unit(suppression, "red", "swordsman")
	var suppression_specials: Dictionary = Dictionary(suppression_source["upgrade_snapshot"])["special_effects"]
	var suppression_payload := {"team": "blue", "source_id": int(suppression_source["id"]), "source_kind": "soldier", "damage": 20.0, "ability_ids": ["suppression"], "soldier_specials": suppression_specials}
	for _hit in 5:
		suppression._apply_projectile_specials(suppression_payload, suppression_target, "unit", 0.0)
	var suppression_waited := not Dictionary(suppression_target["statuses"]).has("suppression")
	suppression._apply_projectile_specials(suppression_payload, suppression_target, "unit", 0.0)
	var suppression_status: Dictionary = Dictionary(suppression_target["statuses"]).get("suppression", {})
	_assert_self_test(suppression_waited and is_equal_approx(float(suppression_status.get("move_reduction", 0.0)), 0.20) and is_equal_approx(float(suppression_status.get("attack_speed_reduction", 0.0)), 0.10) and is_equal_approx(float(suppression_status.get("ttl", 0.0)), 3.5), "runtime_suppression_threshold_and_separate_reductions", errors)
	checks += 1

	# Toxic Payload caps at three independent five-second stacks and preserves
	# the catalog's total-damage ratio for each stack.
	var toxic := _make_test_arena(["archer"], ["swordsman"])
	toxic.adjust_upgrade("toxic_payload", 1, "blue", "archer")
	toxic.start_battle()
	var toxic_source := _test_unit(toxic, "blue", "archer")
	var toxic_target := _test_unit(toxic, "red", "swordsman")
	var toxic_specials: Dictionary = Dictionary(toxic_source["upgrade_snapshot"])["special_effects"]
	var toxic_payload := {"team": "blue", "source_id": int(toxic_source["id"]), "source_kind": "soldier", "damage": 20.0, "ability_ids": ["toxic_payload"], "soldier_specials": toxic_specials}
	for _hit in 4:
		toxic._apply_projectile_specials(toxic_payload, toxic_target, "unit", 0.0)
	var poison_status: Dictionary = Dictionary(toxic_target["statuses"]).get("poison", {})
	var poison_stacks: Array = poison_status.get("stacks", [])
	var poison_dps := 0.0
	for stack_value in poison_stacks:
		poison_dps += float(Dictionary(stack_value).get("damage_per_second", 0.0))
	_assert_self_test(poison_stacks.size() == 3 and is_equal_approx(poison_dps, 20.0 * 0.18 / 5.0 * 3.0), "runtime_toxic_payload_stack_cap_and_dps", errors)
	checks += 1

	# Resurrection is a real chant, Soul Shelter extends the grave lifetime,
	# and the revived unit receives the exact temporary mitigation.
	var soul := _make_test_arena(["priest", "swordsman"], ["swordsman"])
	soul.adjust_upgrade("resurrection_ritual", 1, "blue", "priest")
	soul.adjust_upgrade("soul_shelter", 1, "blue", "priest")
	soul.start_battle()
	var soul_priest := _test_unit(soul, "blue", "priest")
	var fallen_soldier := _test_unit(soul, "blue", "swordsman")
	var soul_attacker := _test_unit(soul, "red", "swordsman")
	soul._damage_unit(fallen_soldier, 999999.0, "melee", soul_attacker, 0.0, [])
	var soul_grave: Dictionary = {}
	for effect in soul.effects:
		if str(effect.get("kind", "")) == "grave":
			soul_grave = effect
			break
	var soul_grave_ok := not soul_grave.is_empty() and is_equal_approx(float(soul_grave.get("ttl", 0.0)), 15.0)
	soul._cleanup_dead_units()
	var soul_chant_started := soul._try_resurrection(soul_priest)
	var soul_chant: Dictionary = {}
	for effect in soul.effects:
		if str(effect.get("kind", "")) == "resurrection_chant":
			soul_chant = effect
			break
	var soul_chant_ok := soul_chant_started and not soul_chant.is_empty() and is_equal_approx(float(soul_chant.get("ttl", 0.0)), 2.3)
	soul._update_effects(2.3)
	var revived_soldier := _test_unit(soul, "blue", "swordsman")
	var soul_revive_ok := not revived_soldier.is_empty() and is_equal_approx(float(revived_soldier.get("post_revive_reduction", 0.0)), 0.30) and is_equal_approx(float(revived_soldier.get("post_revive_reduction_ttl", 0.0)), 3.0)
	_assert_self_test(soul_grave_ok and soul_chant_ok and soul_revive_ok, "runtime_resurrection_chant_and_soul_shelter", errors)
	checks += 1

	# Group Heal, Cleanse, Holy Shield, and Overheal Matrix use their precise
	# intervals, whitelist, independent cooldown, cap, and duration rules.
	var support := _make_test_arena(["healer", "swordsman"], ["swordsman"])
	for support_upgrade_id in ["group_heal", "cleanse", "holy_shield", "overheal_matrix"]:
		support.adjust_upgrade(support_upgrade_id, 1, "blue", "healer")
	support.start_battle()
	var support_healer := _test_unit(support, "blue", "healer")
	var support_ally := _test_unit(support, "blue", "swordsman")
	var group_first_two_quiet := true
	var group_third_triggered := false
	for heal_index in 3:
		support.effects.clear()
		support_healer["cooldown"] = 0.0
		support_ally["hp"] = float(support_ally["max_hp"]) - 30.0
		support._perform_support_action(support_healer)
		if heal_index < 2:
			group_first_two_quiet = group_first_two_quiet and not _has_effect_id(support, "group_heal")
		else:
			group_third_triggered = _has_effect_id(support, "group_heal")
	_assert_self_test(group_first_two_quiet and group_third_triggered, "runtime_group_heal_every_third_heal", errors)
	checks += 1

	support_healer["upgrade_cooldowns"] = {}
	support_ally["statuses"] = {
		"burn": {"ttl": 2.0}, "frost": {"ttl": 2.0}, "paralysis": {"ttl": 2.0}, "poison": {"ttl": 2.0},
	}
	var cleanse_first := support._try_cleanse(support_healer, support_ally)
	var cleansed_statuses: Dictionary = support_ally["statuses"]
	var cleanse_second := support._try_cleanse(support_healer, support_ally)
	_assert_self_test(cleanse_first and not cleanse_second and cleansed_statuses.keys() == ["poison"] and is_equal_approx(float(Dictionary(support_healer["upgrade_cooldowns"]).get("cleanse", 0.0)), 10.0), "runtime_cleanse_whitelist_and_cooldown", errors)
	checks += 1

	support_ally["holy_shield"] = 0.0
	support_ally["holy_shield_ttl"] = 0.0
	support_ally["holy_shield_cooldowns"] = {}
	support_ally["overheal_shield"] = 0.0
	support_ally["overheal_shield_ttl"] = 0.0
	support._apply_support_shields(support_healer, support_ally, 100.0, 20.0)
	var support_max_hp := float(support_ally["max_hp"])
	var holy_and_overheal_exact := is_equal_approx(float(support_ally["holy_shield"]), support_max_hp * 0.08) and is_equal_approx(float(support_ally["holy_shield_ttl"]), 4.0) and is_equal_approx(float(support_ally["overheal_shield"]), minf(support_max_hp * 0.08, 40.0)) and is_equal_approx(float(support_ally["overheal_shield_ttl"]), 6.0)
	support_ally["holy_shield"] = 0.0
	support._apply_support_shields(support_healer, support_ally, 100.0, 20.0)
	var holy_cooldown_blocks_repeat := is_zero_approx(float(support_ally["holy_shield"]))
	_assert_self_test(holy_and_overheal_exact and holy_cooldown_blocks_repeat, "runtime_holy_shield_and_overheal_exact_rules", errors)
	checks += 1

	# A normal healer must not emit the purchased Healing Mastery glyph.
	var normal_heal := _make_test_arena(["healer", "swordsman"], ["swordsman"])
	normal_heal.start_battle()
	var normal_healer := _test_unit(normal_heal, "blue", "healer")
	var normal_ally := _test_unit(normal_heal, "blue", "swordsman")
	normal_ally["hp"] = float(normal_ally["max_hp"]) - 30.0
	normal_heal.effects.clear()
	normal_heal._perform_support_action(normal_healer)
	_assert_self_test(not _has_effect_id(normal_heal, "healing_mastery") and _has_effect_id(normal_heal, "arena_heal"), "runtime_no_false_healing_mastery_vfx", errors)
	checks += 1

	# Last Stand restores the full catalog ratio over its entire three-second
	# window and remains strictly once per life.
	var last_stand := _make_test_arena(["swordsman"], ["swordsman"])
	last_stand.adjust_upgrade("last_stand", 1, "blue", "swordsman")
	last_stand.start_battle()
	var last_stand_unit := _test_unit(last_stand, "blue", "swordsman")
	var last_stand_attacker := _test_unit(last_stand, "red", "swordsman")
	last_stand._damage_unit(last_stand_unit, 999999.0, "melee", last_stand_attacker, 0.0, [])
	var last_stand_triggered := is_equal_approx(float(last_stand_unit["hp"]), 1.0) and is_equal_approx(float(last_stand_unit["invulnerability"]), 0.6)
	for _second in 3:
		last_stand._tick_temporary_recovery_and_shields(last_stand_unit, 1.0)
	var last_stand_recovered := is_equal_approx(float(last_stand_unit["hp"]), 1.0 + float(last_stand_unit["max_hp"]) * 0.12)
	last_stand_unit["invulnerability"] = 0.0
	last_stand._damage_unit(last_stand_unit, 999999.0, "melee", last_stand_attacker, 0.0, [])
	_assert_self_test(last_stand_triggered and last_stand_recovered and is_zero_approx(float(last_stand_unit["hp"])), "runtime_last_stand_full_recovery_once_per_life", errors)
	checks += 1

	# Control warheads perform their advertised displacement/status work without
	# inventing extra damage outside the projectile's normal impact.
	var control := _make_test_arena(["roller", "mage"], ["swordsman"])
	control.adjust_upgrade("shockwave_round", 1, "blue", "roller")
	control.adjust_upgrade("gravity_warhead", 1, "blue", "mage")
	control.start_battle()
	var roller := _test_unit(control, "blue", "roller")
	var mage := _test_unit(control, "blue", "mage")
	var control_target := _test_unit(control, "red", "swordsman")
	var control_hp := float(control_target["hp"])
	var control_before := Vector2(control_target["pos"])
	var shock_center := control_before - Vector2(20.0, 0.0)
	control._apply_shockwave_control({"team": "blue", "source_id": int(roller["id"]), "aoe": 100.0}, shock_center, control._special(roller, "shockwave_round"))
	var shock_status: Dictionary = Dictionary(control_target["statuses"]).get("frost", {})
	var shock_ok := Vector2(control_target["pos"]).distance_to(control_before) >= 59.0 and is_equal_approx(float(shock_status.get("strength", 0.0)), 0.20) and not Dictionary(control_target["statuses"]).has("paralysis") and is_equal_approx(float(control_target["hp"]), control_hp)
	var gravity_center := Vector2(control_target["pos"]) - Vector2(50.0, 0.0)
	control._spawn_gravity_effect({"team": "blue", "source_id": int(mage["id"])}, gravity_center, control._special(mage, "gravity_warhead"))
	var gravity_effect: Dictionary = {}
	for effect in control.effects:
		if str(effect.get("kind", "")) == "damage_area" and str(effect.get("ability_id", "")) == "gravity_warhead":
			gravity_effect = effect
			break
	var gravity_before := Vector2(control_target["pos"])
	control._apply_area_status(gravity_effect)
	var gravity_status: Dictionary = Dictionary(control_target["statuses"]).get("gravity", {})
	var gravity_ok := not gravity_effect.is_empty() and Vector2(control_target["pos"]).distance_to(gravity_before) > 0.0 and is_equal_approx(float(gravity_status.get("strength", 0.0)), 0.15) and is_equal_approx(float(control_target["hp"]), control_hp)
	_assert_self_test(shock_ok and gravity_ok, "runtime_shockwave_and_gravity_control_without_bonus_damage", errors)
	checks += 1

	# Returning to setup is a clean runtime boundary but leaves every choice the
	# player made in the three setup steps intact.
	var return_setup := ArenaController.new()
	return_setup.choose_mode("challenge")
	return_setup.set_active_team("red")
	return_setup.toggle_type("archer")
	return_setup.confirm_types()
	return_setup.adjust_count("archer", 2, "red")
	return_setup.confirm_counts()
	return_setup.adjust_upgrade("burning_ammo", 1, "red", "archer")
	var preserved_types := return_setup.selected_types.duplicate(true)
	var preserved_counts := return_setup.counts.duplicate(true)
	var preserved_rank := SoldierUpgradeCatalog.current_rank("archer", "burning_ammo", return_setup.team_research["red"])
	return_setup.start_battle({"class_id": "mage", "max_hp": 100.0})
	return_setup.battle_time = 8.0
	return_setup.winner = "red"
	return_setup.projectiles.append({"id": -1})
	return_setup.effects.append({"id": -1})
	var returned_to_setup := return_setup.return_to_setup()
	var setup_preserved := return_setup.selected_types == preserved_types and return_setup.counts == preserved_counts and SoldierUpgradeCatalog.current_rank("archer", "burning_ammo", return_setup.team_research["red"]) == preserved_rank
	var runtime_cleared := return_setup.phase == "upgrades" and return_setup.hero.is_empty() and return_setup.units.is_empty() and return_setup.projectiles.is_empty() and return_setup.effects.is_empty() and return_setup.winner.is_empty() and is_zero_approx(return_setup.battle_time) and return_setup._unit_by_id.is_empty() and return_setup.arena_rect == DEFAULT_ARENA_RECT and return_setup._last_hero_template.is_empty()
	_assert_self_test(returned_to_setup and setup_preserved and runtime_cleared, "runtime_return_to_setup_clears_battle_and_preserves_choices", errors)
	checks += 1

	return checks

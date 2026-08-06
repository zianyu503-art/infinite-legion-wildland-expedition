class_name EnemyEnhancementCatalog
extends RefCounted

## Deterministic castle-defender enhancement rolls.
##
## The odds are cumulative probabilities: at level 50, 90% of guards receive at
## least one point, 70% receive at least two, and 30% receive at least three.
## Points four through six each require another independent 5% success. A track
## can never skip ranks; every point either opens rank I or advances I -> II -> III.

const MAX_POINTS := 6
const EXTRA_POINT_CHANCE := 0.05

const ODDS_MILESTONES: Array[Dictionary] = [
	{"level": 1, "first": 0.10, "second": 0.05, "third": 0.00},
	{"level": 10, "first": 0.20, "second": 0.12, "third": 0.03},
	{"level": 20, "first": 0.35, "second": 0.25, "third": 0.08},
	{"level": 30, "first": 0.55, "second": 0.40, "third": 0.15},
	{"level": 35, "first": 0.65, "second": 0.48, "third": 0.20},
	{"level": 40, "first": 0.75, "second": 0.55, "third": 0.24},
	{"level": 45, "first": 0.85, "second": 0.63, "third": 0.28},
	{"level": 50, "first": 0.90, "second": 0.70, "third": 0.30},
]

const GENERAL_TRACKS: Array[String] = [
	"ferocity", "fortified", "rapid", "swift", "longshot", "regeneration", "critical",
]

const SPECIAL_TRACKS: Array[String] = [
	"flame", "frost", "paralysis", "split_shot", "piercing", "chain_explosion",
	"dash", "stomp", "lingering_projectile", "mine_round", "meteor", "lifesteal",
	"reactive_shield",
]

const TRACK_ORDER: Array[String] = [
	"ferocity", "fortified", "rapid", "swift", "longshot", "regeneration", "critical",
	"flame", "frost", "paralysis", "split_shot", "piercing", "chain_explosion",
	"dash", "stomp", "lingering_projectile", "mine_round", "meteor", "lifesteal",
	"reactive_shield",
]

const TRACKS: Dictionary = {
	"ferocity": {"zh": "狂暴", "en": "Ferocity", "special": false, "color": "FF6B55", "attack_pct": [0.12, 0.25, 0.42]},
	"fortified": {"zh": "鐵壁", "en": "Fortified", "special": false, "color": "AAB7C4", "hp_pct": [0.18, 0.40, 0.70], "armor": [2.0, 5.0, 9.0]},
	"rapid": {"zh": "急速", "en": "Rapid", "special": false, "color": "FFE36E", "attack_speed_pct": [0.10, 0.22, 0.38]},
	"swift": {"zh": "迅捷", "en": "Swift", "special": false, "color": "77E4C8", "move_pct": [0.08, 0.18, 0.30]},
	"longshot": {"zh": "遠射", "en": "Longshot", "special": false, "color": "83CAFF", "range_pct": [0.08, 0.16, 0.26]},
	"regeneration": {"zh": "再生", "en": "Regeneration", "special": false, "color": "72E58C", "regen_pct": [0.010, 0.018, 0.030]},
	"critical": {"zh": "致命", "en": "Critical", "special": false, "color": "FF8E8E", "crit_chance": [0.06, 0.10, 0.14], "crit_multiplier": [1.50, 1.65, 1.80]},
	"flame": {"zh": "烈焰", "en": "Flame", "special": true, "color": "FF7A38", "burn_ratio": [0.18, 0.28, 0.40], "burn_duration": [3.0, 3.0, 4.0]},
	"frost": {"zh": "霜凍", "en": "Frost", "special": true, "color": "8CEBFF", "slow": [0.20, 0.28, 0.36], "duration": [1.8, 2.3, 2.8]},
	"paralysis": {"zh": "麻痺", "en": "Paralysis", "special": true, "color": "E9DD68", "every": [8, 6, 5], "stun": [0.32, 0.50, 0.68]},
	"split_shot": {"zh": "分裂彈", "en": "Split Shot", "special": true, "color": "F8B4FF", "extra": [1, 2, 2], "angle": [10.0, 15.0, 20.0], "damage_ratio": [0.18, 0.22, 0.28]},
	"piercing": {"zh": "穿透彈", "en": "Piercing", "special": true, "color": "D8F6FF", "pierce": [1, 2, 3], "retain": [0.70, 0.76, 0.82]},
	"chain_explosion": {"zh": "連環爆炸", "en": "Chain Explosion", "special": true, "color": "FFAA54", "blasts": [1, 2, 3], "damage_ratio": [0.34, 0.40, 0.46]},
	"dash": {"zh": "突進", "en": "Dash", "special": true, "color": "FF5A73", "cooldown": [8.0, 6.5, 5.0], "distance": [100.0, 135.0, 170.0], "damage_ratio": [1.15, 1.35, 1.60]},
	"stomp": {"zh": "震地", "en": "Stomp", "special": true, "color": "D99B68", "radius": [90.0, 115.0, 140.0], "damage_ratio": [0.62, 0.82, 1.05]},
	"lingering_projectile": {"zh": "滯留彈", "en": "Lingering Shot", "special": true, "color": "B28BFF", "duration": [2.0, 3.0, 4.0], "tick_ratio": [0.10, 0.13, 0.16]},
	"mine_round": {"zh": "地雷彈", "en": "Mine Round", "special": true, "color": "FFBF69", "arm": [0.75, 0.58, 0.42], "ttl": [7.0, 9.0, 12.0], "damage_ratio": [1.10, 1.35, 1.65]},
	"meteor": {"zh": "隕石召喚", "en": "Meteor Call", "special": true, "rare": true, "color": "FF4E62", "cooldown": [22.0, 18.0, 15.0], "warning": [1.45, 1.25, 1.05], "radius": [105.0, 135.0, 165.0], "damage_ratio": [1.65, 2.10, 2.65]},
	"lifesteal": {"zh": "吸血", "en": "Lifesteal", "special": true, "color": "E15A8B", "ratio": [0.025, 0.040, 0.055]},
	"reactive_shield": {"zh": "反應護盾", "en": "Reactive Shield", "special": true, "color": "80C9FF", "cooldown": [9.0, 7.5, 6.0], "reduction": [0.30, 0.42, 0.55]},
}

const RANGED_TYPES: Array[String] = [
	"archer", "thrower", "shaman", "cannon", "musketeer", "rifleman", "tank",
	"rocket", "gatling", "helicopter", "bomber", "ufo",
]
const DIRECT_PROJECTILE_TYPES: Array[String] = [
	"archer", "thrower", "shaman", "cannon", "musketeer", "rifleman", "tank",
	"rocket", "gatling", "helicopter",
]
const EXPLOSIVE_TYPES: Array[String] = ["thrower", "cannon", "tank", "rocket", "bomber"]
const MELEE_TYPES: Array[String] = ["grunt", "berserker", "heavy", "chief"]


static func odds_for_level(castle_level: int) -> Dictionary:
	var level := clampi(castle_level, 1, 50)
	var lower: Dictionary = ODDS_MILESTONES[0]
	var upper: Dictionary = ODDS_MILESTONES[ODDS_MILESTONES.size() - 1]
	for milestone in ODDS_MILESTONES:
		if int(milestone["level"]) <= level:
			lower = milestone
		if int(milestone["level"]) >= level:
			upper = milestone
			break
	var span := maxi(1, int(upper["level"]) - int(lower["level"]))
	var weight := 0.0 if int(upper["level"]) == int(lower["level"]) else float(level - int(lower["level"])) / float(span)
	return {
		"level": castle_level,
		"first": lerpf(float(lower["first"]), float(upper["first"]), weight),
		"second": lerpf(float(lower["second"]), float(upper["second"]), weight),
		"third": lerpf(float(lower["third"]), float(upper["third"]), weight),
		"extra": EXTRA_POINT_CHANCE,
	}


static func roll_for_enemy(castle_level: int, seed_value: int, type_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = _normalized_seed(seed_value)
	var odds := odds_for_level(castle_level)
	var point_count := _roll_point_count(rng, odds)
	var tracks: Dictionary = {}
	for _point_index in point_count:
		_allocate_point(rng, tracks, castle_level, type_id)
	var result := {
		"version": 1,
		"castle_level": castle_level,
		"seed": seed_value,
		"points": point_count,
		"tracks": tracks,
		"special_count": _special_track_count(tracks),
	}
	result["summary_zh"] = summary(result, "zh_TW")
	result["summary_en"] = summary(result, "en")
	return result


static func _roll_point_count(rng: RandomNumberGenerator, odds: Dictionary) -> int:
	var first := clampf(float(odds["first"]), 0.0, 1.0)
	var second := clampf(float(odds["second"]), 0.0, first)
	var third := clampf(float(odds["third"]), 0.0, second)
	if rng.randf() >= first:
		return 0
	var points := 1
	# Convert cumulative target probabilities into conditional chances so a large
	# deterministic sample converges to the displayed 90/70/30 percentages.
	if first <= 0.0 or rng.randf() >= second / first:
		return points
	points = 2
	if second <= 0.0 or rng.randf() >= third / second:
		return points
	points = 3
	while points < MAX_POINTS and rng.randf() < EXTRA_POINT_CHANCE:
		points += 1
	return points


static func _allocate_point(rng: RandomNumberGenerator, tracks: Dictionary, castle_level: int, type_id: String) -> void:
	var eligible := eligible_tracks(type_id)
	var advanceable: Array[String] = []
	var unopened: Array[String] = []
	for track_id in eligible:
		var rank := int(tracks.get(track_id, 0))
		if rank > 0 and rank < 3:
			advanceable.append(track_id)
		elif rank == 0:
			unopened.append(track_id)
	if advanceable.is_empty() and unopened.is_empty():
		return
	var open_new := advanceable.is_empty() or (not unopened.is_empty() and rng.randf() < 0.46)
	if open_new:
		var selected := _pick_new_track(rng, unopened, castle_level)
		if not selected.is_empty():
			tracks[selected] = 1
			return
	var existing := advanceable[rng.randi_range(0, advanceable.size() - 1)]
	tracks[existing] = mini(3, int(tracks[existing]) + 1)


static func _pick_new_track(rng: RandomNumberGenerator, candidates: Array[String], castle_level: int) -> String:
	if candidates.is_empty():
		return ""
	var special_chance := lerpf(0.16, 0.42, clampf(float(castle_level - 1) / 49.0, 0.0, 1.0))
	var wants_special := rng.randf() < special_chance
	var pool: Array[String] = []
	for track_id in candidates:
		if bool(TRACKS[track_id].get("special", false)) == wants_special:
			pool.append(track_id)
	if pool.is_empty():
		pool = candidates.duplicate()
	var weighted: Array[String] = []
	for track_id in pool:
		var copies := 1 if bool(TRACKS[track_id].get("rare", false)) else 12
		for _copy in copies:
			weighted.append(track_id)
	return weighted[rng.randi_range(0, weighted.size() - 1)]


static func eligible_tracks(type_id: String) -> Array[String]:
	var result: Array[String] = GENERAL_TRACKS.duplicate()
	result.append("flame")
	result.append("lifesteal")
	result.append("reactive_shield")
	if type_id in ["archer", "shaman", "musketeer", "rifleman", "gatling", "helicopter"]:
		result.append("frost")
		result.append("paralysis")
	if type_id in DIRECT_PROJECTILE_TYPES:
		result.append("split_shot")
		result.append("piercing")
		result.append("lingering_projectile")
	if type_id in EXPLOSIVE_TYPES:
		result.append("chain_explosion")
		result.append("mine_round")
	if type_id in MELEE_TYPES:
		result.append("dash")
		result.append("stomp")
	if type_id in ["shaman", "rocket", "ufo", "chief"]:
		result.append("meteor")
	return result


static func apply_stat_enhancements(enemy: Dictionary, enhancement: Dictionary) -> void:
	var tracks: Dictionary = Dictionary(enhancement.get("tracks", {}))
	var original_hp_ratio := 1.0
	if float(enemy.get("max_hp", 0.0)) > 0.0:
		original_hp_ratio = clampf(float(enemy.get("hp", 0.0)) / float(enemy["max_hp"]), 0.0, 1.0)
	for track_id in tracks.keys():
		var rank := clampi(int(tracks[track_id]), 1, 3)
		var index := rank - 1
		var definition: Dictionary = TRACKS.get(track_id, {})
		match str(track_id):
			"ferocity": enemy["attack"] = float(enemy.get("attack", 1.0)) * (1.0 + float(definition["attack_pct"][index]))
			"fortified":
				enemy["max_hp"] = float(enemy.get("max_hp", 1.0)) * (1.0 + float(definition["hp_pct"][index]))
				enemy["hp"] = float(enemy["max_hp"]) * original_hp_ratio
				enemy["defense"] = float(enemy.get("defense", 0.0)) + float(definition["armor"][index])
			"rapid": enemy["attack_rate"] = float(enemy.get("attack_rate", 1.0)) * (1.0 + float(definition["attack_speed_pct"][index]))
			"swift": enemy["speed"] = float(enemy.get("speed", 1.0)) * (1.0 + float(definition["move_pct"][index]))
			"longshot": enemy["range"] = float(enemy.get("range", 1.0)) * (1.0 + float(definition["range_pct"][index]))
			"regeneration": enemy["enhancement_regen_pct"] = float(definition["regen_pct"][index])
			"critical":
				enemy["enhancement_crit_chance"] = float(definition["crit_chance"][index])
				enemy["enhancement_crit_multiplier"] = float(definition["crit_multiplier"][index])
			"lifesteal": enemy["enhancement_lifesteal"] = float(definition["ratio"][index])
			"reactive_shield":
				enemy["enhancement_reactive_cooldown"] = float(definition["cooldown"][index])
				enemy["enhancement_reactive_reduction"] = float(definition["reduction"][index])
	enemy["enhancement"] = enhancement.duplicate(true)
	enemy["enhancement_points"] = int(enhancement.get("points", 0))
	enemy["enhancement_cursor"] = int(enemy.get("enhancement_cursor", 0))
	enemy["enhancement_attack_sequence"] = int(enemy.get("enhancement_attack_sequence", 0))
	enemy["enhancement_reactive_timer"] = float(enemy.get("enhancement_reactive_timer", 0.0))


static func rank_for(enhancement: Dictionary, track_id: String) -> int:
	return clampi(int(Dictionary(enhancement.get("tracks", {})).get(track_id, 0)), 0, 3)


static func definition(track_id: String) -> Dictionary:
	return Dictionary(TRACKS.get(track_id, {}))


static func summary(enhancement: Dictionary, language: String = "zh_TW") -> String:
	var pieces: Array[String] = []
	var tracks: Dictionary = Dictionary(enhancement.get("tracks", {}))
	for track_id in TRACK_ORDER:
		var rank := int(tracks.get(track_id, 0))
		if rank <= 0:
			continue
		var definition_value: Dictionary = TRACKS[track_id]
		pieces.append("%s %s" % [str(definition_value["en"] if language == "en" else definition_value["zh"]), _roman(rank)])
	return " · ".join(pieces)


static func is_valid_roll(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var enhancement: Dictionary = value
	if typeof(enhancement.get("tracks")) != TYPE_DICTIONARY:
		return false
	var points := int(enhancement.get("points", -1))
	if points < 0 or points > MAX_POINTS:
		return false
	var counted := 0
	for track_id in Dictionary(enhancement["tracks"]).keys():
		if not TRACKS.has(track_id):
			return false
		var rank := int(enhancement["tracks"][track_id])
		if rank < 1 or rank > 3:
			return false
		counted += rank
	return counted == points


static func _special_track_count(tracks: Dictionary) -> int:
	var count := 0
	for track_id in tracks.keys():
		if bool(TRACKS.get(track_id, {}).get("special", false)):
			count += 1
	return count


static func _roman(rank: int) -> String:
	return ["", "I", "II", "III"][clampi(rank, 0, 3)]


static func _normalized_seed(seed_value: int) -> int:
	var mixed := int(seed_value) ^ 0x4E35A13D
	mixed = int((mixed * 1103515245 + 12345) & 0x7FFFFFFF)
	return maxi(1, mixed)

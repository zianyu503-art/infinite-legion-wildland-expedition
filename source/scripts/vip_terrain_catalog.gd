class_name VIPTerrainCatalog
extends RefCounted

## Canonical VIP-world terrain metadata.
##
## The generator blends these definitions at shared world-space vertices.  A
## renderer should use `color` from generated vertices instead of drawing hard
## tile boundaries; gameplay may consume the generated effective properties or
## ask this catalog for the unblended terrain definition.

const VERSION := 1

const TERRAIN_ORDER: Array[String] = [
	"ocean",
	"lake",
	"river",
	"mountain",
	"mine",
	"plateau",
	"desert",
	"forest",
	"swamp",
	"plains",
]

const DEFINITIONS: Dictionary = {
	"ocean": {
		"name_zh": "海洋",
		"name_en": "Ocean",
		"color": Color("1B5F93"),
		"movement_multiplier": 0.0,
		"blocked_ground": true,
		"defense_bonus": -0.10,
		"ranged_bonus": -0.15,
		"vision_multiplier": 1.15,
		"traversal": "naval",
		"resource_semantics": ["fish", "salt", "pearls"],
	},
	"lake": {
		"name_zh": "湖泊",
		"name_en": "Lake",
		"color": Color("2E8DC1"),
		"movement_multiplier": 0.0,
		"blocked_ground": true,
		"defense_bonus": -0.05,
		"ranged_bonus": -0.10,
		"vision_multiplier": 1.10,
		"traversal": "boat_or_bridge",
		"resource_semantics": ["fish", "reeds", "fresh_water"],
	},
	"river": {
		"name_zh": "河流",
		"name_en": "River",
		"color": Color("46A9D1"),
		"movement_multiplier": 0.52,
		"blocked_ground": false,
		"conditional_block": "deep_channel",
		"defense_bonus": -0.08,
		"ranged_bonus": -0.08,
		"vision_multiplier": 1.05,
		"traversal": "ford_bridge_or_boat",
		"resource_semantics": ["fish", "reeds", "clay"],
	},
	"mountain": {
		"name_zh": "山脈",
		"name_en": "Mountain",
		"color": Color("626A6B"),
		"movement_multiplier": 0.0,
		"blocked_ground": true,
		"defense_bonus": 0.35,
		"ranged_bonus": 0.25,
		"vision_multiplier": 1.35,
		"traversal": "mountain_pass_or_air",
		"resource_semantics": ["stone", "iron", "coal"],
	},
	"mine": {
		"name_zh": "礦山",
		"name_en": "Mine",
		"color": Color("806B55"),
		"movement_multiplier": 0.68,
		"blocked_ground": false,
		"defense_bonus": 0.18,
		"ranged_bonus": 0.08,
		"vision_multiplier": 0.90,
		"traversal": "rough_ground",
		"resource_semantics": ["iron", "gold", "coal", "crystal"],
	},
	"plateau": {
		"name_zh": "高原",
		"name_en": "Plateau",
		"color": Color("9A8757"),
		"movement_multiplier": 0.86,
		"blocked_ground": false,
		"defense_bonus": 0.16,
		"ranged_bonus": 0.18,
		"vision_multiplier": 1.25,
		"traversal": "slope_entry",
		"resource_semantics": ["stone", "copper", "grazing"],
	},
	"desert": {
		"name_zh": "沙漠",
		"name_en": "Desert",
		"color": Color("D8B86B"),
		"movement_multiplier": 0.80,
		"blocked_ground": false,
		"defense_bonus": -0.08,
		"ranged_bonus": 0.08,
		"vision_multiplier": 1.20,
		"recovery_multiplier": 0.72,
		"traversal": "sand",
		"resource_semantics": ["salt", "crystal", "oasis_water"],
	},
	"forest": {
		"name_zh": "森林",
		"name_en": "Forest",
		"color": Color("276B3A"),
		"movement_multiplier": 0.70,
		"blocked_ground": false,
		"defense_bonus": 0.20,
		"ranged_bonus": -0.18,
		"vision_multiplier": 0.62,
		"traversal": "woodland",
		"resource_semantics": ["wood", "herbs", "game"],
	},
	"swamp": {
		"name_zh": "沼澤",
		"name_en": "Swamp",
		"color": Color("536F4C"),
		"movement_multiplier": 0.48,
		"blocked_ground": false,
		"defense_bonus": 0.08,
		"ranged_bonus": -0.12,
		"vision_multiplier": 0.72,
		"recovery_multiplier": 0.78,
		"traversal": "bog",
		"resource_semantics": ["herbs", "peat", "venom"],
	},
	"plains": {
		"name_zh": "平原",
		"name_en": "Plains",
		"color": Color("69A94F"),
		"movement_multiplier": 1.0,
		"blocked_ground": false,
		"defense_bonus": 0.0,
		"ranged_bonus": 0.0,
		"vision_multiplier": 1.0,
		"traversal": "open_ground",
		"resource_semantics": ["grain", "livestock", "clay"],
	},
}


static func terrain_ids() -> Array[String]:
	return TERRAIN_ORDER.duplicate()


static func has_terrain(terrain_id: String) -> bool:
	return DEFINITIONS.has(terrain_id)


static func definition(terrain_id: String) -> Dictionary:
	var resolved := terrain_id if DEFINITIONS.has(terrain_id) else "plains"
	return Dictionary(DEFINITIONS[resolved]).duplicate(true)


static func color_for(terrain_id: String) -> Color:
	var resolved := terrain_id if DEFINITIONS.has(terrain_id) else "plains"
	return Color(Dictionary(DEFINITIONS[resolved]).get("color", Color.WHITE))


static func gameplay_properties(terrain_id: String) -> Dictionary:
	var data := definition(terrain_id)
	return {
		"movement_multiplier": float(data.get("movement_multiplier", 1.0)),
		"blocked_ground": bool(data.get("blocked_ground", false)),
		"conditional_block": str(data.get("conditional_block", "")),
		"defense_bonus": float(data.get("defense_bonus", 0.0)),
		"ranged_bonus": float(data.get("ranged_bonus", 0.0)),
		"vision_multiplier": float(data.get("vision_multiplier", 1.0)),
		"recovery_multiplier": float(data.get("recovery_multiplier", 1.0)),
		"traversal": str(data.get("traversal", "open_ground")),
		"resource_semantics": Array(data.get("resource_semantics", [])).duplicate(),
	}


static func blended_color(weights: Dictionary) -> Color:
	var result := Color(0.0, 0.0, 0.0, 0.0)
	var total := 0.0
	for terrain_id in TERRAIN_ORDER:
		var weight := maxf(0.0, float(weights.get(terrain_id, 0.0)))
		if weight <= 0.0:
			continue
		result += color_for(terrain_id) * weight
		total += weight
	if total <= 0.00001:
		return color_for("plains")
	result /= total
	result.a = 1.0
	return result


static func blended_properties(weights: Dictionary) -> Dictionary:
	var movement := 0.0
	var defense := 0.0
	var ranged := 0.0
	var vision := 0.0
	var recovery := 0.0
	var blocked_strength := 0.0
	var total := 0.0
	for terrain_id in TERRAIN_ORDER:
		var weight := maxf(0.0, float(weights.get(terrain_id, 0.0)))
		if weight <= 0.0:
			continue
		var data := Dictionary(DEFINITIONS[terrain_id])
		movement += float(data.get("movement_multiplier", 1.0)) * weight
		defense += float(data.get("defense_bonus", 0.0)) * weight
		ranged += float(data.get("ranged_bonus", 0.0)) * weight
		vision += float(data.get("vision_multiplier", 1.0)) * weight
		recovery += float(data.get("recovery_multiplier", 1.0)) * weight
		if bool(data.get("blocked_ground", false)):
			blocked_strength += weight
		total += weight
	if total <= 0.00001:
		return gameplay_properties("plains")
	return {
		"movement_multiplier": movement / total,
		"blocked_strength": blocked_strength / total,
		"blocked_ground": blocked_strength / total >= 0.52,
		"defense_bonus": defense / total,
		"ranged_bonus": ranged / total,
		"vision_multiplier": vision / total,
		"recovery_multiplier": recovery / total,
	}


static func catalog_self_test() -> Dictionary:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for terrain_id in TERRAIN_ORDER:
		if seen.has(terrain_id):
			errors.append("duplicate terrain id: %s" % terrain_id)
		seen[terrain_id] = true
		if not DEFINITIONS.has(terrain_id):
			errors.append("missing terrain definition: %s" % terrain_id)
			continue
		var data := Dictionary(DEFINITIONS[terrain_id])
		for key in ["name_zh", "name_en", "color", "movement_multiplier", "blocked_ground", "defense_bonus", "ranged_bonus", "vision_multiplier", "traversal", "resource_semantics"]:
			if not data.has(key):
				errors.append("%s missing %s" % [terrain_id, key])
		if not (data.get("color") is Color):
			errors.append("%s has invalid color" % terrain_id)
		if float(data.get("movement_multiplier", -1.0)) < 0.0:
			errors.append("%s has negative movement multiplier" % terrain_id)
		if not (data.get("resource_semantics", null) is Array):
			errors.append("%s has invalid resource semantics" % terrain_id)
	for terrain_id in DEFINITIONS.keys():
		if not seen.has(str(terrain_id)):
			errors.append("definition omitted from order: %s" % terrain_id)
	return {
		"passed": errors.is_empty(),
		"errors": errors,
		"terrain_count": TERRAIN_ORDER.size(),
	}

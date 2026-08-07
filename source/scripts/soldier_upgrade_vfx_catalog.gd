class_name SoldierUpgradeVfxCatalog
extends RefCounted

## Visual contract for every permanent soldier ability. Combat code owns the
## numbers; this catalog guarantees that every purchased ability has a stable,
## readable visual identity on projectiles, units, targets, triggers or areas.

const CHANNELS: Array[String] = ["projectile", "unit", "status", "trigger", "area"]

# Explicit ordering keeps per-frame lookups allocation-free and matches the
# gameplay catalog's stable 57-ability order.
const ORDER: Array[String] = [
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

const DESCRIPTORS: Dictionary = {
	"burning_sword": {"family": "fire", "shape": "flame_blade", "channels": ["unit", "status", "trigger"], "color": "FF6A2A", "accent": "FFE36E"},
	"burning_ammo": {"family": "fire", "shape": "flame_trail", "channels": ["projectile", "status"], "color": "FF5A24", "accent": "FFD166"},
	"frost_arrow": {"family": "frost", "shape": "frost_shard", "channels": ["projectile", "status"], "color": "65D9FF", "accent": "E8FBFF"},
	"paralysis_arrow": {"family": "lightning", "shape": "lightning_rune", "channels": ["projectile", "status", "trigger"], "color": "FFE25C", "accent": "FFF8C2"},
	"chain_lightning": {"family": "lightning", "shape": "lightning_chain", "channels": ["projectile", "trigger"], "color": "8EEBFF", "accent": "FFFFFF"},
	"corrosion": {"family": "toxic", "shape": "acid_drip", "channels": ["projectile", "status"], "color": "A8E85B", "accent": "E6FF9C"},
	"void_mark": {"family": "void", "shape": "void_eye", "channels": ["projectile", "status"], "color": "B56CFF", "accent": "F0C8FF"},
	"split_shot": {"family": "kinetic", "shape": "triple_fletching", "channels": ["projectile", "trigger"], "color": "71D7FF", "accent": "EAF8FF"},
	"piercing_arrow": {"family": "kinetic", "shape": "spear_tip", "channels": ["projectile"], "color": "D9F2FF", "accent": "FFFFFF"},
	"penetrating_round": {"family": "kinetic", "shape": "rail_core", "channels": ["projectile"], "color": "B7E7FF", "accent": "FFFFFF"},
	"ricochet": {"family": "kinetic", "shape": "ricochet_chevron", "channels": ["projectile", "trigger"], "color": "8BE8FF", "accent": "F4FFFF"},
	"lingering_projectile": {"family": "temporal", "shape": "time_orb", "channels": ["projectile", "area"], "color": "73F3DD", "accent": "D9FFF8"},
	"homing_guidance": {"family": "tech", "shape": "target_ring", "channels": ["projectile"], "color": "62E8FF", "accent": "FFFFFF"},
	"armor_piercing_core": {"family": "kinetic", "shape": "broken_armor", "channels": ["projectile", "unit", "trigger"], "color": "FFD27A", "accent": "FFF0C8"},
	"chain_explosion": {"family": "explosive", "shape": "cascade_ring", "channels": ["projectile", "area", "trigger"], "color": "FF8052", "accent": "FFE07A"},
	"mine_round": {"family": "explosive", "shape": "mine_warning", "channels": ["projectile", "area"], "color": "FFB34A", "accent": "FFF0A6"},
	"cluster_warhead": {"family": "explosive", "shape": "cluster_nodes", "channels": ["projectile", "area", "trigger"], "color": "FF9B54", "accent": "FFE58A"},
	"burning_zone": {"family": "fire", "shape": "fire_pool", "channels": ["projectile", "area", "status"], "color": "FF572E", "accent": "FFC857"},
	"shockwave_round": {"family": "kinetic", "shape": "shockwave", "channels": ["projectile", "area", "trigger"], "color": "8FD7FF", "accent": "FFFFFF"},
	"shrapnel_storm": {"family": "explosive", "shape": "shard_burst", "channels": ["projectile", "area", "trigger"], "color": "FFC46B", "accent": "FFF2CF"},
	"siege_warhead": {"family": "explosive", "shape": "castle_breaker", "channels": ["projectile", "trigger"], "color": "FF865E", "accent": "FFE1A3"},
	"dash": {"family": "kinetic", "shape": "speed_streak", "channels": ["unit", "trigger"], "color": "6DE4FF", "accent": "E8FDFF"},
	"stomp": {"family": "earth", "shape": "ground_crack", "channels": ["unit", "area", "trigger"], "color": "E0A56A", "accent": "FFF0C4"},
	"sweeping_slash": {"family": "kinetic", "shape": "wide_blade", "channels": ["unit", "trigger"], "color": "D8F4FF", "accent": "FFFFFF"},
	"suppression": {"family": "tech", "shape": "suppression_bars", "channels": ["projectile", "status"], "color": "FFB45D", "accent": "FFF0B8"},
	"taunt_guard": {"family": "guard", "shape": "taunt_shield", "channels": ["unit", "trigger"], "color": "72B8FF", "accent": "EAF6FF"},
	"focus_mark": {"family": "target", "shape": "crosshair", "channels": ["projectile", "status"], "color": "FF6B75", "accent": "FFD7DA"},
	"aerial_evade": {"family": "air", "shape": "wing_chevron", "channels": ["unit", "trigger"], "color": "87E9FF", "accent": "F1FFFF"},
	"meteor": {"family": "cosmic", "shape": "falling_star", "channels": ["unit", "area", "trigger"], "color": "FF7043", "accent": "FFF08A"},
	"guardian": {"family": "holy", "shape": "guardian_spirit", "channels": ["unit", "area", "trigger"], "color": "79C8FF", "accent": "FFF3B0"},
	"auto_turret": {"family": "tech", "shape": "turret", "channels": ["unit", "area", "trigger"], "color": "68D8FF", "accent": "EAFBFF"},
	"repair_drone": {"family": "repair", "shape": "repair_drone", "channels": ["unit", "area", "trigger"], "color": "67E8B2", "accent": "EAFFF7"},
	"self_repair": {"family": "repair", "shape": "repair_gears", "channels": ["unit", "trigger"], "color": "65DFA7", "accent": "E6FFF3"},
	"tactical_shield": {"family": "guard", "shape": "hex_shield", "channels": ["unit", "trigger"], "color": "62B8FF", "accent": "DDF4FF"},
	"last_stand": {"family": "holy", "shape": "phoenix_ring", "channels": ["unit", "trigger"], "color": "FFB149", "accent": "FFF0A6"},
	"lifesteal": {"family": "blood", "shape": "blood_orb", "channels": ["projectile", "unit", "trigger"], "color": "FF5470", "accent": "FFD0D8"},
	"reactive_armor": {"family": "guard", "shape": "armor_flash", "channels": ["unit", "trigger"], "color": "91C7DD", "accent": "F2FBFF"},
	"evade_drill": {"family": "air", "shape": "dodge_chevrons", "channels": ["unit", "trigger"], "color": "7EE6FF", "accent": "F0FFFF"},
	"air_flares": {"family": "fire", "shape": "flare_orbit", "channels": ["unit", "trigger"], "color": "FF8A45", "accent": "FFF28A"},
	"healing_mastery": {"family": "healing", "shape": "healing_star", "channels": ["unit", "trigger"], "color": "69E7A8", "accent": "ECFFF5"},
	"group_heal": {"family": "healing", "shape": "healing_links", "channels": ["unit", "trigger"], "color": "54DDA0", "accent": "E8FFF4"},
	"cleanse": {"family": "holy", "shape": "cleanse_wave", "channels": ["unit", "trigger"], "color": "D4F7FF", "accent": "FFFFFF"},
	"holy_shield": {"family": "holy", "shape": "holy_bubble", "channels": ["unit", "trigger"], "color": "FFE47A", "accent": "FFFBE0"},
	"resurrection_ritual": {"family": "holy", "shape": "soul_pillar", "channels": ["unit", "area", "trigger"], "color": "FFD870", "accent": "FFFFFF"},
	"soul_shelter": {"family": "soul", "shape": "soul_wings", "channels": ["unit", "trigger"], "color": "C69BFF", "accent": "F7EAFF"},
	"guardian_aura": {"family": "guard", "shape": "ward_ring", "channels": ["unit", "area"], "color": "78C7FF", "accent": "EAF7FF"},
	"battlefield_repair": {"family": "repair", "shape": "wrench_beam", "channels": ["unit", "trigger"], "color": "62E0B4", "accent": "EEFFF8"},
	"toxic_payload": {"family": "toxic", "shape": "poison_trail", "channels": ["projectile", "status"], "color": "83DC4A", "accent": "DCFF9B"},
	"execution_protocol": {"family": "target", "shape": "execute_cross", "channels": ["projectile", "trigger"], "color": "FF5266", "accent": "FFE1E5"},
	"gravity_warhead": {"family": "void", "shape": "gravity_well", "channels": ["projectile", "area", "status"], "color": "9A6CFF", "accent": "E8D5FF"},
	"temporal_echo": {"family": "temporal", "shape": "echo_ghost", "channels": ["projectile", "unit", "trigger"], "color": "66F0DD", "accent": "EAFFFB"},
	"overcharge_capacitor": {"family": "lightning", "shape": "electric_halo", "channels": ["projectile", "unit", "trigger"], "color": "62D9FF", "accent": "FFF58C"},
	"kinetic_barrier": {"family": "guard", "shape": "kinetic_hex", "channels": ["unit", "trigger"], "color": "63D5FF", "accent": "EBFCFF"},
	"rally_beacon": {"family": "command", "shape": "banner_aura", "channels": ["unit", "area"], "color": "FFD15B", "accent": "FFF5C5"},
	"overheal_matrix": {"family": "healing", "shape": "matrix_shield", "channels": ["unit", "trigger"], "color": "63F0C1", "accent": "EDFFF9"},
	"vengeance_counter": {"family": "blood", "shape": "vengeance_marks", "channels": ["unit", "trigger"], "color": "FF675E", "accent": "FFE0B2"},
	"salvage_protocol": {"family": "gold", "shape": "gold_gears", "channels": ["unit", "trigger"], "color": "FFD052", "accent": "FFF5B8"},
}


static func descriptor(ability_id: String) -> Dictionary:
	return Dictionary(DESCRIPTORS.get(ability_id, {})).duplicate(true)


static func color_for(ability_id: String) -> Color:
	return Color(str(Dictionary(DESCRIPTORS.get(ability_id, {})).get("color", "FFFFFF")))


static func accent_for(ability_id: String) -> Color:
	return Color(str(Dictionary(DESCRIPTORS.get(ability_id, {})).get("accent", "FFFFFF")))


static func shape_for(ability_id: String) -> String:
	return str(Dictionary(DESCRIPTORS.get(ability_id, {})).get("shape", ""))


static func family_for(ability_id: String) -> String:
	return str(Dictionary(DESCRIPTORS.get(ability_id, {})).get("family", "kinetic"))


static func has_channel(ability_id: String, channel: String) -> bool:
	return channel in Array(Dictionary(DESCRIPTORS.get(ability_id, {})).get("channels", []))


static func active_ids(source: Variant, channel: String = "", limit: int = 57, cycle_offset: int = 0) -> Array[String]:
	var available: Dictionary = {}
	if source is Dictionary:
		var dictionary := Dictionary(source)
		if dictionary.has("special_effects"):
			dictionary = Dictionary(dictionary.get("special_effects", {}))
		for key_value in dictionary.keys():
			available[str(key_value)] = true
	elif source is Array:
		for item_value in Array(source):
			if item_value is Dictionary:
				available[str(Dictionary(item_value).get("id", ""))] = true
			elif item_value is String:
				available[str(item_value)] = true
	var ordered: Array[String] = []
	for id_value in ORDER:
		var ability_id := str(id_value)
		if available.has(ability_id) and (channel.is_empty() or has_channel(ability_id, channel)):
			ordered.append(ability_id)
	if ordered.is_empty() or limit <= 0:
		return []
	var result: Array[String] = []
	var count := mini(limit, ordered.size())
	var start := posmod(cycle_offset, ordered.size())
	for index in count:
		result.append(ordered[(start + index) % ordered.size()])
	return result


static func visual_index(ability_id: String) -> int:
	return ORDER.find(ability_id)


static func self_test(expected_ids: Array[String]) -> Dictionary:
	var errors: Array[String] = []
	var expected: Dictionary = {}
	var seen_shapes: Dictionary = {}
	if ORDER != expected_ids:
		errors.append("order_mismatch")
	for ability_id in expected_ids:
		expected[ability_id] = true
		if not DESCRIPTORS.has(ability_id):
			errors.append("missing:%s" % ability_id)
			continue
		var visual := Dictionary(DESCRIPTORS[ability_id])
		var shape := str(visual.get("shape", ""))
		var channels := Array(visual.get("channels", []))
		if shape.is_empty() or channels.is_empty():
			errors.append("incomplete:%s" % ability_id)
		if seen_shapes.has(shape):
			errors.append("duplicate_shape:%s" % shape)
		seen_shapes[shape] = true
		for channel_value in channels:
			if str(channel_value) not in CHANNELS:
				errors.append("invalid_channel:%s:%s" % [ability_id, str(channel_value)])
		if not Color.html_is_valid(str(visual.get("color", ""))) or not Color.html_is_valid(str(visual.get("accent", ""))):
			errors.append("invalid_color:%s" % ability_id)
	for id_value in DESCRIPTORS.keys():
		if not expected.has(str(id_value)):
			errors.append("unknown:%s" % str(id_value))
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"count": DESCRIPTORS.size(),
		"unique_shapes": seen_shapes.size(),
	}

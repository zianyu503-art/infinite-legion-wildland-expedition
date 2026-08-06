class_name NationCatalog
extends RefCounted

## Deterministic nation metadata generator for castle ownership.
##
## The catalog provides:
## - Stable nation assignment from world_seed + castle world chunk (960px chunking)
## - 12x12 macro regions with jittered Voronoi-like boundaries (to reduce square-grid feel)
## - Player fixed nation metadata
## - Metadata validation, normalizing and helpers
const VERSION := 1

const CHUNK_SIZE := 960.0
const MACRO_CHUNK_SIZE := 12
const MACRO_CENTER_OFFSET := 6.0
const MACRO_JITTER := 2.5
const PLAYER_NATION_ID := "player"

const _NATION_LIBRARY: Array[Dictionary] = [
	{"name_zh": "皇家極光帝國", "name_en": "Aurora Crown Empire", "color_hex": "4A90E2"},
	{"name_zh": "赤焰軍團", "name_en": "Crimson Legion", "color_hex": "E53935"},
	{"name_zh": "晨星聯盟", "name_en": "Dawnstar Accord", "color_hex": "FBC02D"},
	{"name_zh": "蒼岩同盟", "name_en": "Azure Bastion Alliance", "color_hex": "0288D1"},
	{"name_zh": "銀月領地", "name_en": "Silvermoon Territories", "color_hex": "7E57C2"},
	{"name_zh": "黑檀王國", "name_en": "Ebony Kingdom", "color_hex": "37474F"},
	{"name_zh": "風暴港共和國", "name_en": "Stormport Republic", "color_hex": "00ACC1"},
	{"name_zh": "紅林邦聯", "name_en": "Crimsonwood Confederacy", "color_hex": "D81B60"},
	{"name_zh": "寒霜議會", "name_en": "Frost Council", "color_hex": "26A69A"},
	{"name_zh": "烈風公約", "name_en": "Blazewind Accord", "color_hex": "F57C00"},
	{"name_zh": "玄武聯軍", "name_en": "Dark Tortoise Front", "color_hex": "7CB342"},
	{"name_zh": "晨露衛國", "name_en": "Dewguard State", "color_hex": "00B0FF"},
	{"name_zh": "星隕商團", "name_en": "Meteorite Guild", "color_hex": "8E24AA"},
	{"name_zh": "青龍商團", "name_en": "Azure Wyrm League", "color_hex": "039BE5"},
	{"name_zh": "赤潮航團", "name_en": "Red Tide Company", "color_hex": "D50000"},
	{"name_zh": "霧林自治州", "name_en": "Mistwood Free State", "color_hex": "9CCC65"},
	{"name_zh": "銀河聯邦", "name_en": "Galactic Union", "color_hex": "6D4C41"},
	{"name_zh": "黃昏行省", "name_en": "Twilight Province", "color_hex": "5D4037"},
	{"name_zh": "雷鳴議會", "name_en": "Thunder Council", "color_hex": "4DD0E1"},
	{"name_zh": "翡翠王朝", "name_en": "Emerald Dynasty", "color_hex": "2E7D32"},
	{"name_zh": "獵鷹聯邦", "name_en": "Falcon Federation", "color_hex": "546E7A"},
	{"name_zh": "玄冰聯邦", "name_en": "Obsidian Ice Federation", "color_hex": "01579B"},
	{"name_zh": "燼火帝國", "name_en": "Emberfire Empire", "color_hex": "BF360C"},
	{"name_zh": "晨風自治盟", "name_en": "Zephyr Commune", "color_hex": "7E57C2"},
	{"name_zh": "黎明聯隊", "name_en": "Dawn Legion", "color_hex": "039BE5"},
	{"name_zh": "青嶺議會", "name_en": "Blue Ridge Assembly", "color_hex": "00ACC1"},
	{"name_zh": "鐵獅軍閥", "name_en": "Iron Lion Warlordry", "color_hex": "6A1B9A"},
	{"name_zh": "焰心同盟", "name_en": "Heartfire Pact", "color_hex": "F4511E"},
	{"name_zh": "星塵衛士", "name_en": "Stardust Guard", "color_hex": "8D6E63"},
	{"name_zh": "雷霆堡壘", "name_en": "Thunderforge Bastion", "color_hex": "C2185B"},
	{"name_zh": "深海商會", "name_en": "Abyss Trade League", "color_hex": "00796B"},
	{"name_zh": "翠谷邦聯", "name_en": "Verdant Valley Federation", "color_hex": "43A047"},
	{"name_zh": "鏽鐵聯盟", "name_en": "Rust Iron Alliance", "color_hex": "455A64"},
	{"name_zh": "晨光主權區", "name_en": "Aurora Commons", "color_hex": "1E88E5"},
	{"name_zh": "熾焰海軍", "name_en": "Blazing Navy", "color_hex": "D84315"},
	{"name_zh": "雪峰聯合王國", "name_en": "Snowpeak Kingdom", "color_hex": "1565C0"},
	{"name_zh": "白金衛隊", "name_en": "Platinum Guard", "color_hex": "546E7A"},
	{"name_zh": "雲渺商行", "name_en": "Cloudweave Syndicate", "color_hex": "2F4B7C"},
	{"name_zh": "碧海公社", "name_en": "Azure Sea Commune", "color_hex": "00897B"},
	{"name_zh": "火冠軍團", "name_en": "Pyre Crown Brigade", "color_hex": "C62828"},
	{"name_zh": "鐵血同盟", "name_en": "Ironblood Pact", "color_hex": "455A64"},
	{"name_zh": "雲鷹自治國", "name_en": "Cloud Eagle Commonwealth", "color_hex": "5E35B1"},
	{"name_zh": "黑曜騎團", "name_en": "Obsidian Riders", "color_hex": "424242"},
	{"name_zh": "晨潮聯盟", "name_en": "Morning Tide Coalition", "color_hex": "00838F"},
]

const _NATION_NAME := "國家"
const _PLAYER_NAME_ZH := "我方" + _NATION_NAME
const _PLAYER_NAME_EN := "Player Faction"
const _PLAYER_COLOR := "1E88E5"

const _HASH_A := 0x9E3779B9
const _HASH_B := 0x7F4A7C15
const _HASH_C := 0x6D2B79F5
const _HASH_D := 0x165667B1
const _MIX_MASK := 0x7FFFFFFF


static func player_metadata() -> Dictionary:
	return {
		"version": VERSION,
		"id": PLAYER_NATION_ID,
		"name_zh": _PLAYER_NAME_ZH,
		"name_en": _PLAYER_NAME_EN,
		"color_hex": _PLAYER_COLOR,
		"capital_chunk_x": 0,
		"capital_chunk_y": 0,
	}


static func metadata_for_castle(world_seed: int, castle_id: String, position: Variant) -> Dictionary:
	if int(world_seed) == 0 and castle_id == "origin_home":
		return player_metadata()

	var chunk := _chunk_from_position(position)
	var resolved := _nation_for_chunk(world_seed, chunk)
	var capital_chunk := resolved["capital_chunk"] as Vector2i
	var index := int(resolved["index"])
	var nation := _NATION_LIBRARY[index % _NATION_LIBRARY.size()]
	return {
		"version": VERSION,
		"id": resolved["id"],
		"name_zh": nation["name_zh"],
		"name_en": nation["name_en"],
		"color_hex": nation["color_hex"],
		"capital_chunk_x": capital_chunk.x,
		"capital_chunk_y": capital_chunk.y,
	}


static func display_name(metadata: Variant, language: String) -> String:
	if not is_valid_metadata(metadata):
		return ""
	var lang := language.to_lower()
	if lang.find("en") >= 0:
		return String(metadata.get("name_en", ""))
	return String(metadata.get("name_zh", ""))


static func normalized_or_generated(saved: Variant, world_seed: int, castle_id: String, position: Variant) -> Dictionary:
	if castle_id == "origin_home":
		return player_metadata()
	if not is_valid_metadata(saved):
		return metadata_for_castle(world_seed, castle_id, position)
	var normalized := Dictionary(saved)
	var generated := metadata_for_castle(world_seed, castle_id, position)
	var same_identity := String(normalized.get("id", "")) == String(generated.get("id"))
	var same_version := int(normalized.get("version", 0)) == VERSION
	if not same_version or not same_identity:
		var patched := generated.duplicate(true)
		# Keep owner intent only when this is player metadata loaded by older saves.
		if same_identity and String(normalized.get("id", "")) == PLAYER_NATION_ID:
			patched["id"] = PLAYER_NATION_ID
		return patched
	# Keep any extra legacy keys but force canonical required fields.
	normalized["version"] = VERSION
	normalized["id"] = String(generated["id"])
	normalized["name_zh"] = String(generated["name_zh"])
	normalized["name_en"] = String(generated["name_en"])
	normalized["color_hex"] = String(generated["color_hex"])
	normalized["capital_chunk_x"] = int(generated["capital_chunk_x"])
	normalized["capital_chunk_y"] = int(generated["capital_chunk_y"])
	return normalized


static func normalized_owner_or_generated(saved: Variant, world_seed: int, castle_id: String, position: Variant) -> Dictionary:
	## A castle's current owner is allowed to differ from the nation generated for
	## its location after an annexation. Keep that valid owner identity while
	## canonicalizing display metadata; fall back to the geographic nation only
	## when the saved owner is malformed.
	var generated := metadata_for_castle(world_seed, castle_id, position)
	if not is_valid_metadata(saved):
		return generated
	var stored: Dictionary = Dictionary(saved)
	var nation_id := str(stored["id"])
	var canonical: Dictionary
	if nation_id == PLAYER_NATION_ID:
		canonical = player_metadata()
	else:
		var index_text := nation_id.trim_prefix("nation_")
		if not index_text.is_valid_int():
			return generated
		var nation_index := int(index_text)
		if nation_index < 0 or nation_index >= _NATION_LIBRARY.size():
			return generated
		var nation: Dictionary = _NATION_LIBRARY[nation_index]
		canonical = {
			"version": VERSION,
			"id": nation_id,
			"name_zh": nation["name_zh"],
			"name_en": nation["name_en"],
			"color_hex": nation["color_hex"],
			"capital_chunk_x": int(stored["capital_chunk_x"]),
			"capital_chunk_y": int(stored["capital_chunk_y"]),
		}
	if bool(stored.get("conquered", false)):
		canonical["conquered"] = true
	return canonical


static func is_valid_metadata(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var v := Dictionary(value)
	for required_key in ["version", "id", "name_zh", "name_en", "color_hex", "capital_chunk_x", "capital_chunk_y"]:
		if not v.has(required_key):
			return false
	if not _is_integral_number(v["version"]) or int(v["version"]) != VERSION:
		return false
	var nation_id := str(v.get("id", ""))
	if nation_id.is_empty():
		return false
	if nation_id != PLAYER_NATION_ID:
		if not nation_id.begins_with("nation_"):
			return false
		var index_text := nation_id.trim_prefix("nation_")
		if not index_text.is_valid_int():
			return false
		var nation_index := int(index_text)
		if nation_index < 0 or nation_index >= _NATION_LIBRARY.size():
			return false
	if not _is_non_empty_string(v.get("name_zh", "")) or not _is_non_empty_string(v.get("name_en", "")):
		return false
	if not _is_valid_hex_color(v.get("color_hex", "")):
		return false
	if not _is_integral_number(v["capital_chunk_x"]) or not _is_integral_number(v["capital_chunk_y"]):
		return false
	if v.has("conquered") and not (v["conquered"] is bool):
		return false
	return true


static func are_hostile(a: Variant, b: Variant) -> bool:
	if not is_valid_metadata(a) or not is_valid_metadata(b):
		return false
	var aid := str(Dictionary(a).get("id", ""))
	var bid := str(Dictionary(b).get("id", ""))
	if aid.is_empty() or bid.is_empty():
		return false
	return aid != bid


static func conquest_metadata(winner: Variant) -> Dictionary:
	if winner is Dictionary and is_valid_metadata(winner):
		var result := Dictionary(winner).duplicate(true)
		result["version"] = VERSION
		result["conquered"] = true
		return result
	if winner is String and String(winner) == PLAYER_NATION_ID:
		var result := player_metadata()
		result["conquered"] = true
		return result
	return player_metadata()


static func _nation_for_chunk(world_seed: int, chunk: Vector2i) -> Dictionary:
	var macro := Vector2i(
		_floor_div(chunk.x, MACRO_CHUNK_SIZE),
		_floor_div(chunk.y, MACRO_CHUNK_SIZE),
	)
	var chunk_center := Vector2(float(chunk.x) + 0.5, float(chunk.y) + 0.5)
	var best_dist := INF
	var best_super := Vector2i.ZERO
	var best_seed := 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var anchor := Vector2i(macro.x + dx, macro.y + dy)
			var anchor_center := _macro_anchor_center(world_seed, anchor)
			var dist := chunk_center.distance_squared_to(anchor_center)
			if dist < best_dist:
				best_dist = dist
				best_super = anchor
				best_seed = _seed_for_super(world_seed, anchor)

	var nation_index := _u8_from_seed(best_seed)
	var nat_id := "nation_%d" % nation_index
	var capital_chunk := Vector2i(best_super.x * MACRO_CHUNK_SIZE, best_super.y * MACRO_CHUNK_SIZE) + Vector2i(MACRO_CHUNK_SIZE / 2, MACRO_CHUNK_SIZE / 2)
	return {
		"id": nat_id,
		"index": nation_index,
		"capital_chunk": capital_chunk,
		"macro_chunk": best_super,
	}


static func _macro_anchor_center(world_seed: int, macro_chunk: Vector2i) -> Vector2:
	var center_x := float(macro_chunk.x * MACRO_CHUNK_SIZE) + MACRO_CENTER_OFFSET
	var center_y := float(macro_chunk.y * MACRO_CHUNK_SIZE) + MACRO_CENTER_OFFSET
	var jitter_seed := _seed_for_super(world_seed, macro_chunk)
	var jitter_x := (_rand_float(jitter_seed ^ 0x13) * 2.0 - 1.0) * MACRO_JITTER
	var jitter_y := (_rand_float(jitter_seed ^ 0x37) * 2.0 - 1.0) * MACRO_JITTER
	return Vector2(center_x + jitter_x, center_y + jitter_y)


static func _seed_for_super(world_seed: int, macro_chunk: Vector2i) -> int:
	return _mix_int3(int(world_seed), macro_chunk.x, macro_chunk.y)


static func _u8_from_seed(seed: int) -> int:
	var value := _rand_float(seed)
	var span := _NATION_LIBRARY.size()
	return clampi(int(value * float(span)), 0, span - 1)


static func _chunk_from_position(position: Variant) -> Vector2i:
	if position is Vector2:
		var point := Vector2(position)
		return Vector2i(_float_to_chunk_coord(point.x), _float_to_chunk_coord(point.y))
	if position is Vector2i:
		return Vector2i(position)
	if position is Dictionary:
		var x_val := float(position.get("x", 0.0))
		var y_val := float(position.get("y", 0.0))
		return Vector2i(_float_to_chunk_coord(float(x_val)), _float_to_chunk_coord(float(y_val)))
	return Vector2i.ZERO


static func _float_to_chunk_coord(value: float) -> int:
	return int(floori(value / CHUNK_SIZE))


static func _floor_div(value: int, divisor: int) -> int:
	if divisor == 0:
		return 0
	if value >= 0:
		return value / divisor
	return -int(ceil(absf(float(value)) / float(divisor)))


static func _is_non_empty_string(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := String(value).strip_edges()
	return not text.is_empty()


static func _is_integral_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and is_equal_approx(number, roundf(number))


static func _is_valid_hex_color(value: Variant) -> bool:
	if not (value is String):
		return false
	var color := String(value).strip_edges()
	if color.begins_with("#"):
		color = color.substr(1)
	if color.length() != 6:
		return false
	for i in color.length():
		var code := color.unicode_at(i)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 70)
			or (code >= 97 and code <= 102)
		):
			return false
	return true


static func _mix_int3(a: int, b: int, c: int) -> int:
	var x := _to_u32(a)
	x ^= _to_u32(_to_u32(b) << 13)
	x = _to_u32(x * _HASH_A)
	x ^= _to_u32(x >> 17)
	x ^= _to_u32(_to_u32(c) * _HASH_B)
	x = _to_u32(x + _HASH_C)
	x ^= _to_u32(x << 5)
	return _to_u32(x + _HASH_D)


static func _rand_float(seed: int) -> float:
	var mixed := _mix_int3(seed, _HASH_D, _HASH_A)
	var value := float(mixed & _MIX_MASK)
	return value / float(_MIX_MASK)


static func _to_u32(value: int) -> int:
	return value & 0xFFFFFFFF

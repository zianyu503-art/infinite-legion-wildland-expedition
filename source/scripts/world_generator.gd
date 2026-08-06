extends RefCounted
class_name WorldGenerator

const CHUNK_SIZE: float = 960.0
const WORLD_SEED: int = 0x5A17
const ORIGIN_SAFE_RADIUS: float = 320.0

const CASTLE_GRID_SPACING: int = 4
const CASTLE_ANCHOR_RETAIN_THRESHOLD: float = 0.03
const CASTLE_EXTRA_DENSITY_THRESHOLD: float = 0.96
const CASTLE_EXTRA_SUPPORT_THRESHOLD: float = 0.58
const CASTLE_POSITION_PADDING: float = 240.0
const CASTLE_BLOCK_SALT_A: int = 0xA11CE
const CASTLE_ANCHOR_CHANCE_SALT: int = 31
const CASTLE_EXTRA_CHANCE_SALT: int = 53
const CASTLE_SUPPORT_SALT: int = 73

const CAMP_SPACING: int = 5
const CAMP_OFFSET_X: int = 2
const CAMP_OFFSET_Y: int = 3

const SNAKE_NEST_SPACING_X: int = 11
const SNAKE_NEST_SPACING_Y: int = 11
const SNAKE_NEST_OFFSET_X: int = 3
const SNAKE_NEST_OFFSET_Y: int = 2
const SNAKE_NEST_BOSS_CLEAR_RADIUS: float = 260.0
const SNAKE_NEST_ENEMY_CLEAR_RADIUS: float = 360.0
const SNAKE_NEST_POSITION_JITTER: float = 80.0

const BIOMES: Array[Dictionary] = [
	{
		"id": "meadow",
		"name": "Meadow",
		"grass_color": Color(0.33, 0.81, 0.32),
		"obstacle_pressure": 1.0,
		"danger": 0.35,
		"enemy_pool": ["grunt", "grunt", "archer"],
	},
	{
		"id": "forest",
		"name": "Woodland",
		"grass_color": Color(0.22, 0.59, 0.20),
		"obstacle_pressure": 1.45,
		"danger": 0.55,
		"enemy_pool": ["grunt", "berserker", "shaman"],
	},
	{
		"id": "hills",
		"name": "Highlands",
		"grass_color": Color(0.48, 0.67, 0.35),
		"obstacle_pressure": 1.15,
		"danger": 0.48,
		"enemy_pool": ["archer", "thrower", "heavy"],
	},
	{
		"id": "swamp",
		"name": "Swampland",
		"grass_color": Color(0.33, 0.58, 0.35),
		"obstacle_pressure": 1.25,
		"danger": 0.7,
		"enemy_pool": ["grunt", "heavy", "shaman"],
	},
	{
		"id": "desert",
		"name": "Scrub",
		"grass_color": Color(0.85, 0.74, 0.43),
		"obstacle_pressure": 0.85,
		"danger": 0.63,
		"enemy_pool": ["archer", "berserker", "thrower"],
	},
]

const _HASH_A: int = 374761393
const _HASH_B: int = 668265263
const _HASH_C: int = 1274126177
const _HASH_MASK: int = 0x7FFFFFFF

const _CASTLE_MILESTONES: Array[Vector2i] = [
	Vector2i(5, 5),
	Vector2i(9, 9),
	Vector2i(13, 13),
	Vector2i(17, 17),
	Vector2i(21, 21),
	Vector2i(25, 25),
]

var world_seed: int = WORLD_SEED


func _init(seed_value: int = WORLD_SEED) -> void:
	world_seed = seed_value


func world_to_chunk(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_position.x / CHUNK_SIZE)),
		int(floor(world_position.y / CHUNK_SIZE))
	)


func chunk_key(chunk_position: Vector2i) -> String:
	return str(chunk_position.x) + "," + str(chunk_position.y)


func generate_chunk(chunk_position: Vector2i) -> Dictionary:
	var seed: int = _chunk_seed(chunk_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	var origin = Vector2(chunk_position.x * CHUNK_SIZE, chunk_position.y * CHUNK_SIZE)
	var chunk_center = origin + Vector2(CHUNK_SIZE * 0.5, CHUNK_SIZE * 0.5)
	var key := chunk_key(chunk_position)

	var biome := _pick_biome(chunk_position)
	var biome_data := BIOMES[biome]

	var decorations: Array[Dictionary] = []
	var obstacles: Array[Dictionary] = []
	var enemy_spawns: Array[Dictionary] = []

	var castle_data: Variant = null
	var camp_data: Variant = null
	var snake_nest_data: Variant = null
	var house_data: Variant = null
	var safe_zone_data: Variant = null

	_populate_decorations_and_obstacles(origin, rng, biome_data, decorations, obstacles)

	var castle_position := _castle_position_for_chunk(chunk_position, origin, rng)
	var has_castle := _is_castle_chunk(chunk_position)
	if has_castle:
		castle_data = {
			"id": "castle_%s" % key,
			"position": castle_position,
			"level": _castle_level_for_chunk(chunk_position),
		}

	var is_origin_chunk := chunk_position == Vector2i.ZERO
	if is_origin_chunk:
		var house_position: Vector2 = chunk_center
		house_data = {
			"id": "origin_house",
			"position": house_position,
			"radius": 36.0,
		}
		safe_zone_data = {
			"position": house_position,
			"radius": ORIGIN_SAFE_RADIUS,
		}

	var can_have_camp := (
		!is_origin_chunk
		and !_is_castle_chunk(chunk_position)
		and _is_periodic_chunk(chunk_position.x, CAMP_SPACING, CAMP_OFFSET_X)
		and _is_periodic_chunk(chunk_position.y, CAMP_SPACING, CAMP_OFFSET_Y)
	)
	if can_have_camp and rng.randf() < 0.62:
		var local_position := _random_local_position(rng, origin, 140.0)
		camp_data = {
			"id": "camp_%s" % key,
			"position": local_position,
			"level": 1 + int(_value_from_biome(chunk_position, 31) * 3.0),
		}

	var can_have_snake_nest := (
		!is_origin_chunk
		and !has_castle
		and camp_data == null
		and _is_periodic_chunk(chunk_position.x, SNAKE_NEST_SPACING_X, SNAKE_NEST_OFFSET_X)
		and _is_periodic_chunk(chunk_position.y, SNAKE_NEST_SPACING_Y, SNAKE_NEST_OFFSET_Y)
	)
	if can_have_snake_nest:
		var nest_position := _snake_nest_position_for_chunk(chunk_position, origin)
		snake_nest_data = {
			"id": "python_boss_lair_%s" % key,
			"position": nest_position,
			"level": _snake_nest_level(chunk_position),
		}

	_remove_reserved_obstacle_overlaps(obstacles, house_data, castle_data, camp_data, snake_nest_data)

	_populate_enemy_spawns(
		chunk_position,
		origin,
		rng,
		biome_data,
		castle_data,
		camp_data,
		snake_nest_data,
		obstacles,
		enemy_spawns
	)

	if is_origin_chunk:
		enemy_spawns = []

	return {
		"chunk": chunk_position,
		"key": key,
		"size": CHUNK_SIZE,
		"biome": {
			"id": biome_data["id"],
			"name": biome_data["name"],
		},
		"grass_color": _color_to_dict(biome_data["grass_color"]),
		"decorations": decorations,
		"obstacles": obstacles,
		"camp": camp_data,
		"snake_nest": snake_nest_data,
		"castle": castle_data,
		"house": house_data,
		"safe_zone": safe_zone_data,
		"enemy_spawns": enemy_spawns,
	}


func _pick_biome(chunk_position: Vector2i) -> int:
	var temperature := _value_from_biome(chunk_position, 11)
	var humidity := _value_from_biome(chunk_position, 13)
	var roughness := _value_from_biome(chunk_position, 17)

	if humidity < 0.18:
		return 4  # desert
	if humidity < 0.33 and roughness < 0.22:
		return 3  # swamp
	if temperature > 0.64:
		return 0  # meadow
	if temperature > 0.46:
		return 2  # hills
	if roughness > 0.58:
		return 1  # forest
	return 0


func _populate_decorations_and_obstacles(
		origin: Vector2,
		rng: RandomNumberGenerator,
		biome_data: Dictionary,
		decorations: Array[Dictionary],
		obstacles: Array[Dictionary]
) -> void:
	var base_count: int = int(biome_data["obstacle_pressure"] * 7.0)
	var tree_count: int = int(base_count * 0.6 + rng.randi_range(0, 3))
	var rock_count: int = int(base_count * 0.2 + rng.randi_range(0, 2))
	var bush_count: int = int(base_count * 0.45 + rng.randi_range(0, 2))

	_add_obstacles_of_type(origin, rng, "tree", tree_count, 12.0, 24.0, obstacles)
	_add_obstacles_of_type(origin, rng, "rock", rock_count, 8.0, 18.0, obstacles)
	_add_obstacles_of_type(origin, rng, "bush", bush_count, 6.0, 13.0, obstacles)

	var deco_count: int = rng.randi_range(8, 24)
	for i in range(deco_count):
		var deco_type = _pick_decoration_type(rng, biome_data["id"])
		var pos := _random_local_position(rng, origin, 24.0)
		decorations.append({
			"type": deco_type,
			"position": pos,
		})


func _add_obstacles_of_type(origin: Vector2, rng: RandomNumberGenerator, obstacle_type: String, count: int, min_radius: float, max_radius: float, obstacles: Array[Dictionary]) -> void:
	for i in range(count):
		var pos := _random_local_position(rng, origin, 18.0)
		var radius := rng.randf_range(min_radius, max_radius)
		obstacles.append({
			"type": obstacle_type,
			"position": pos,
			"radius": radius,
		})


func _remove_reserved_obstacle_overlaps(obstacles: Array[Dictionary], house_data: Variant, castle_data: Variant, camp_data: Variant, snake_nest_data: Variant = null) -> void:
	for i in range(obstacles.size() - 1, -1, -1):
		var obstacle: Dictionary = obstacles[i]
		var pos: Vector2 = obstacle["position"]
		var radius := float(obstacle["radius"])
		var reserved := false
		if house_data != null and pos.distance_to(house_data["position"]) < radius + 95.0:
			reserved = true
		if castle_data != null and pos.distance_to(castle_data["position"]) < radius + 185.0:
			reserved = true
		if camp_data != null and pos.distance_to(camp_data["position"]) < radius + 92.0:
			reserved = true
		if snake_nest_data != null and pos.distance_to(snake_nest_data["position"]) < radius + SNAKE_NEST_BOSS_CLEAR_RADIUS:
			reserved = true
		if reserved:
			obstacles.remove_at(i)


func _pick_decoration_type(rng: RandomNumberGenerator, biome_id: String) -> String:
	match biome_id:
		"forest":
			return ["moss", "fern", "fallen_leaf", "mossy_stone"][rng.randi_range(0, 3)]
		"swamp":
			return ["reed", "moss", "marsh_flower", "vine"][rng.randi_range(0, 3)]
		"desert":
			return ["dune_grass", "stones", "cactus", "dry_shrub"][rng.randi_range(0, 3)]
		_:
			return ["wildflower", "grass_patch", "fern", "boulder_chip"][rng.randi_range(0, 3)]


func _populate_enemy_spawns(
		chunk_position: Vector2i,
		origin: Vector2,
		rng: RandomNumberGenerator,
		biome_data: Dictionary,
		castle_data: Variant,
		camp_data: Variant,
		snake_nest_data: Variant,
		obstacles: Array[Dictionary],
		enemy_spawns: Array[Dictionary]
) -> void:
	if chunk_position == Vector2i.ZERO:
		return

	var danger: float = biome_data["danger"]
	var spawn_budget := int(danger * 5.0) + rng.randi_range(0, 3)
	var pool: Array = biome_data["enemy_pool"]
	var local_chunk_center := origin + Vector2(CHUNK_SIZE * 0.5, CHUNK_SIZE * 0.5)
	var safe_center := Vector2(0.0, 0.0) + Vector2(CHUNK_SIZE * 0.5, CHUNK_SIZE * 0.5)
	var min_safe_sq := ORIGIN_SAFE_RADIUS * ORIGIN_SAFE_RADIUS

	if castle_data:
		spawn_budget += 2
	if camp_data:
		spawn_budget += 1
	spawn_budget = clamp(spawn_budget, 0, 14)

	for i in range(spawn_budget):
		for _attempt in 14:
			var pos := _random_local_position(rng, origin, 28.0)
			if pos.distance_squared_to(safe_center) < min_safe_sq:
				continue
			if not _enemy_spawn_position_is_clear(pos, obstacles, castle_data, camp_data, snake_nest_data, enemy_spawns):
				continue
			enemy_spawns.append({
				"id": "enemy_%s_%d" % [chunk_key(world_to_chunk(local_chunk_center)), i],
				"type": pool[rng.randi_range(0, pool.size() - 1)],
				"position": pos,
				"level": 1 + int((danger * 2.0) + rng.randf_range(-0.4, 1.8)),
			})
			break


func _enemy_spawn_position_is_clear(position: Vector2, obstacles: Array[Dictionary], castle_data: Variant, camp_data: Variant, snake_nest_data: Variant, enemy_spawns: Array[Dictionary]) -> bool:
	for obstacle in obstacles:
		if position.distance_to(obstacle["position"]) < float(obstacle["radius"]) + 24.0:
			return false
	if castle_data != null and position.distance_to(castle_data["position"]) < 205.0:
		return false
	if camp_data != null and position.distance_to(camp_data["position"]) < 125.0:
		return false
	if snake_nest_data != null and position.distance_to(snake_nest_data["position"]) < SNAKE_NEST_ENEMY_CLEAR_RADIUS:
		return false
	for spawn in enemy_spawns:
		if position.distance_to(spawn["position"]) < 38.0:
			return false
	return true


func _is_castle_chunk(chunk_position: Vector2i) -> bool:
	if chunk_position == Vector2i.ZERO:
		return false

	if _is_forced_castle_milestone(chunk_position):
		return true

	var block_position := _castle_block_position(chunk_position)
	var anchor_chunk := _castle_anchor_for_block(block_position)
	if chunk_position == anchor_chunk:
		return _value_from_biome(chunk_position, CASTLE_ANCHOR_CHANCE_SALT) > CASTLE_ANCHOR_RETAIN_THRESHOLD

	if _is_castle_cluster_extra(chunk_position):
		return _value_from_biome(chunk_position, CASTLE_EXTRA_CHANCE_SALT) > CASTLE_EXTRA_DENSITY_THRESHOLD

	return false


func _castle_position_for_chunk(chunk_position: Vector2i, origin: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var chunk_key_rng := _chunk_seed(chunk_position) ^ 0xBEEF
	var local := RandomNumberGenerator.new()
	local.seed = chunk_key_rng
	var padding := CASTLE_POSITION_PADDING
	return Vector2(
		origin.x + CHUNK_SIZE * 0.5 + local.randf_range(-padding, padding),
		origin.y + CHUNK_SIZE * 0.5 + local.randf_range(-padding, padding)
	)


func _castle_level_for_chunk(chunk_position: Vector2i) -> int:
	# Castle chunks occur every four coordinates. Each new ring introduces one
	# exact requested milestone, so all six tiers recur throughout the infinite map.
	var ring := maxi(abs(chunk_position.x), abs(chunk_position.y))
	if ring >= 25: return 50
	if ring >= 21: return 45
	if ring >= 17: return 40
	if ring >= 13: return 35
	if ring >= 9: return 30
	if ring >= 5: return 20
	return 1 + abs(int(chunk_position.x + chunk_position.y) % 4)


func _snake_nest_position_for_chunk(chunk_position: Vector2i, origin: Vector2) -> Vector2:
	var local := RandomNumberGenerator.new()
	local.seed = _chunk_seed(chunk_position) ^ 0x51A9E
	return origin + Vector2(
		CHUNK_SIZE * 0.5 + local.randf_range(-SNAKE_NEST_POSITION_JITTER, SNAKE_NEST_POSITION_JITTER),
		CHUNK_SIZE * 0.5 + local.randf_range(-SNAKE_NEST_POSITION_JITTER, SNAKE_NEST_POSITION_JITTER)
	)


func _snake_nest_level(chunk_position: Vector2i) -> int:
	var ring := maxi(abs(chunk_position.x), abs(chunk_position.y))
	return clampi(1 + int(floor(float(ring) / 4.0)), 1, 12)


func _castle_block_position(chunk_position: Vector2i) -> Vector2i:
	return Vector2i(
		_floor_div(chunk_position.x, CASTLE_GRID_SPACING),
		_floor_div(chunk_position.y, CASTLE_GRID_SPACING),
	)


func _castle_anchor_for_block(block_position: Vector2i) -> Vector2i:
	var seed := _chunk_seed(block_position) ^ CASTLE_BLOCK_SALT_A
	var block_rng := RandomNumberGenerator.new()
	block_rng.seed = seed
	var anchor_local_x := block_rng.randi_range(0, CASTLE_GRID_SPACING - 1)
	var anchor_local_y := block_rng.randi_range(0, CASTLE_GRID_SPACING - 1)
	return Vector2i(
		block_position.x * CASTLE_GRID_SPACING + anchor_local_x,
		block_position.y * CASTLE_GRID_SPACING + anchor_local_y,
	)


func _is_castle_cluster_extra(chunk_position: Vector2i) -> bool:
	var support := _castle_anchor_support(chunk_position)
	if support < CASTLE_EXTRA_SUPPORT_THRESHOLD:
		return false
	return _value_from_biome(chunk_position, CASTLE_SUPPORT_SALT) < support


func _castle_anchor_support(chunk_position: Vector2i) -> float:
	var block_position := _castle_block_position(chunk_position)
	var total := 0.0

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var neighbor_anchor := _castle_anchor_for_block(block_position + Vector2i(dx, dy))
			var chunk_distance := float(chunk_position.distance_to(neighbor_anchor))
			if chunk_distance < 2.0:
				total += 0.35
			elif chunk_distance < 3.2:
				total += 0.18
			elif chunk_distance < 4.4:
				total += 0.08

	return clampf(total, 0.0, 1.0)


func _is_forced_castle_milestone(chunk_position: Vector2i) -> bool:
	for milestone in _CASTLE_MILESTONES:
		if milestone == chunk_position:
			return true
	return false


func _floor_div(value: int, divisor: int) -> int:
	if value >= 0:
		return int(floor(float(value) / float(divisor)))
	return -int(ceil(float(-value) / float(divisor)))


func _random_local_position(rng: RandomNumberGenerator, origin: Vector2, margin: float) -> Vector2:
	var x := rng.randf_range(margin, CHUNK_SIZE - margin)
	var y := rng.randf_range(margin, CHUNK_SIZE - margin)
	return origin + Vector2(x, y)


func _is_periodic_chunk(value: int, period: int, offset: int) -> bool:
	var raw := (value - offset) % period
	if raw < 0:
		raw += period
	return raw == 0


func _value_from_biome(chunk_position: Vector2i, salt: int) -> float:
	var value := RandomNumberGenerator.new()
	value.seed = _chunk_seed(chunk_position) ^ (salt * 73856093)
	return value.randf()


func _chunk_seed(chunk_position: Vector2i) -> int:
	var seed := world_seed & _HASH_MASK
	seed = (seed ^ ((chunk_position.x & _HASH_MASK) * _HASH_A)) & _HASH_MASK
	seed = (seed ^ ((chunk_position.y & _HASH_MASK) * _HASH_B)) & _HASH_MASK
	seed = ((seed ^ (seed >> 13)) * _HASH_C) & _HASH_MASK
	seed = ((seed ^ (seed >> 16)) * _HASH_C) & _HASH_MASK
	return seed & _HASH_MASK


func _color_to_dict(value: Color) -> Dictionary:
	return {
		"r": value.r,
		"g": value.g,
		"b": value.b,
		"a": value.a,
	}

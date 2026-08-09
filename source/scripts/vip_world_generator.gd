class_name VIPWorldGenerator
extends RefCounted

## Deterministic, continuous terrain-data generator for the VIP world.
##
## Chunks are an invisible streaming/cache boundary only.  Every field is
## sampled from absolute world coordinates, so neighboring chunks share exact
## edge vertices.  Rendering data uses vertex colors and triangles to avoid
## visible square biome borders.  This class creates data only and is therefore
## safe to use in a worker when each worker owns its own generator instance.

const VIPTerrainCatalog = preload("res://scripts/vip_terrain_catalog.gd")

const VERSION := 1
const DEFAULT_WORLD_SEED := 0x5A17
const CHUNK_SIZE := 960.0
const GRID_CELLS := 12
const GRID_VERTICES := GRID_CELLS + 1
const SAMPLE_SPACING := CHUNK_SIZE / float(GRID_CELLS)
const FEATURE_CELL_SIZE := 160.0
const FEATURE_CELLS_PER_CHUNK := 6
const BLOCK_THRESHOLD := 0.52
const DEFAULT_CACHE_LIMIT := 81

const ORIGIN_SAFE_CENTER := Vector2(480.0, 480.0)
const ORIGIN_SAFE_RADIUS := 420.0
const ORIGIN_SAFE_TRANSITION_RADIUS := 760.0
const ORIGIN_FEATURE_CLEAR_RADIUS := 330.0

const _HASH_MASK := 0x7FFFFFFF
const _HASH_A := 374761393
const _HASH_B := 668265263
const _HASH_C := 1274126177
const _HASH_D := 69069

const _SALT_CONTINENT := 101
const _SALT_ELEVATION := 137
const _SALT_MOISTURE := 173
const _SALT_TEMPERATURE := 211
const _SALT_VEGETATION := 251
const _SALT_LAKE := 293
const _SALT_RIDGE := 337
const _SALT_ORE := 379
const _SALT_RIVER_A := 419
const _SALT_RIVER_B := 457
const _SALT_FEATURE_X := 503
const _SALT_FEATURE_Y := 541
const _SALT_FEATURE_KIND := 577
const _SALT_RESOURCE := 619

var world_seed: int = DEFAULT_WORLD_SEED
var max_cached_chunks: int = DEFAULT_CACHE_LIMIT

var _chunk_cache: Dictionary = {}
var _cache_order: Array[String] = []


func _init(seed_value: int = DEFAULT_WORLD_SEED, cache_limit: int = DEFAULT_CACHE_LIMIT) -> void:
	world_seed = seed_value
	max_cached_chunks = maxi(1, cache_limit)


func world_to_chunk(world_position: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_position.x / CHUNK_SIZE)),
		int(floor(world_position.y / CHUNK_SIZE))
	)


func chunk_key(chunk_position: Vector2i) -> String:
	return "%d,%d" % [chunk_position.x, chunk_position.y]


func cached_chunk_count() -> int:
	return _chunk_cache.size()


func has_cached_chunk(chunk_position: Vector2i) -> bool:
	return _chunk_cache.has(chunk_key(chunk_position))


func clear_cache() -> void:
	_chunk_cache.clear()
	_cache_order.clear()


func release_chunk(chunk_position: Vector2i) -> void:
	var key := chunk_key(chunk_position)
	_chunk_cache.erase(key)
	_cache_order.erase(key)


func set_cache_limit(value: int) -> void:
	max_cached_chunks = maxi(1, value)
	_trim_cache()


func generate_chunk(chunk_position: Vector2i) -> Dictionary:
	## Returns a cached read-only-by-contract dictionary.  Use
	## generate_chunk_copy() when the caller needs to mutate its copy.
	var key := chunk_key(chunk_position)
	if _chunk_cache.has(key):
		_touch_cache_key(key)
		return Dictionary(_chunk_cache[key])
	var data := build_chunk_data(chunk_position)
	_chunk_cache[key] = data
	_cache_order.append(key)
	_trim_cache()
	return data


func generate_chunk_copy(chunk_position: Vector2i) -> Dictionary:
	return generate_chunk(chunk_position).duplicate(true)


func build_chunk_data(chunk_position: Vector2i) -> Dictionary:
	## Pure chunk construction.  It does not touch the cache or the SceneTree.
	var origin := Vector2(chunk_position) * CHUNK_SIZE
	var key := chunk_key(chunk_position)
	var samples: Array[Dictionary] = []
	var world_vertices := PackedVector2Array()
	var local_vertices := PackedVector2Array()
	var vertex_colors := PackedColorArray()

	for grid_y in range(GRID_VERTICES):
		for grid_x in range(GRID_VERTICES):
			var local_position := Vector2(float(grid_x), float(grid_y)) * SAMPLE_SPACING
			var world_position := origin + local_position
			var sample := sample_world(world_position)
			sample["grid"] = Vector2i(grid_x, grid_y)
			sample["local_position"] = local_position
			samples.append(sample)
			world_vertices.append(world_position)
			local_vertices.append(local_position)
			vertex_colors.append(Color(sample["color"]))

	var cells: Array[Dictionary] = []
	var render_indices := PackedInt32Array()
	var collision_polygons: Array[Dictionary] = []
	for cell_y in range(GRID_CELLS):
		for cell_x in range(GRID_CELLS):
			var top_left := _vertex_index(cell_x, cell_y)
			var top_right := _vertex_index(cell_x + 1, cell_y)
			var bottom_left := _vertex_index(cell_x, cell_y + 1)
			var bottom_right := _vertex_index(cell_x + 1, cell_y + 1)
			var global_cell := Vector2i(
				chunk_position.x * GRID_CELLS + cell_x,
				chunk_position.y * GRID_CELLS + cell_y
			)
			var triangles: Array[PackedInt32Array] = []
			if ((global_cell.x + global_cell.y) & 1) == 0:
				triangles = [
					PackedInt32Array([top_left, top_right, bottom_right]),
					PackedInt32Array([top_left, bottom_right, bottom_left]),
				]
			else:
				triangles = [
					PackedInt32Array([top_left, top_right, bottom_left]),
					PackedInt32Array([top_right, bottom_right, bottom_left]),
				]

			for triangle in triangles:
				for vertex_index in triangle:
					render_indices.append(vertex_index)
				var blocked_polygon := _blocked_polygon_for_triangle(triangle, samples, origin)
				if blocked_polygon["world_polygon"].size() >= 3:
					collision_polygons.append({
						"id": "vip_block_%s_%d" % [key, collision_polygons.size()],
						"kind": "terrain_block",
						"blocks": ["ground"],
						"terrain": blocked_polygon["terrain"],
						"polygon": blocked_polygon["world_polygon"],
						"local_polygon": blocked_polygon["local_polygon"],
					})

			var corner_indices := PackedInt32Array([top_left, top_right, bottom_right, bottom_left])
			var cell_weights := _average_weights(corner_indices, samples)
			var cell_properties := VIPTerrainCatalog.blended_properties(cell_weights)
			var river_depth := 0.0
			for corner_index in corner_indices:
				river_depth += float(Dictionary(samples[corner_index]).get("river_depth", 0.0)) * 0.25
			var cell_blocked_strength := maxf(
				float(cell_properties.get("blocked_strength", 0.0)),
				_smoothstep(0.68, 0.94, river_depth)
			)
			cell_properties["blocked_strength"] = cell_blocked_strength
			cell_properties["blocked_ground"] = cell_blocked_strength >= BLOCK_THRESHOLD
			if cell_blocked_strength >= 0.86:
				cell_properties["movement_multiplier"] = 0.0
			var cell_origin := origin + Vector2(float(cell_x), float(cell_y)) * SAMPLE_SPACING
			cells.append({
				"grid": Vector2i(cell_x, cell_y),
				"global_grid": global_cell,
				"rect": Rect2(cell_origin, Vector2.ONE * SAMPLE_SPACING),
				"local_rect": Rect2(Vector2(float(cell_x), float(cell_y)) * SAMPLE_SPACING, Vector2.ONE * SAMPLE_SPACING),
				"center": cell_origin + Vector2.ONE * SAMPLE_SPACING * 0.5,
				"terrain": _primary_terrain(cell_weights),
				"transition_terrains": _meaningful_transitions(cell_weights),
				"weights": cell_weights,
				"color": VIPTerrainCatalog.blended_color(cell_weights),
				"properties": cell_properties,
				"river_depth": river_depth,
				"corner_indices": corner_indices,
				"triangle_indices": triangles,
			})

	var feature_nodes: Array[Dictionary] = []
	var resource_nodes: Array[Dictionary] = []
	_populate_feature_nodes(chunk_position, feature_nodes, resource_nodes)

	return {
		"version": VERSION,
		"seed": world_seed,
		"chunk": chunk_position,
		"key": key,
		"size": CHUNK_SIZE,
		"origin": origin,
		"bounds": Rect2(origin, Vector2.ONE * CHUNK_SIZE),
		"sample_spacing": SAMPLE_SPACING,
		"grid_cells": GRID_CELLS,
		"samples": samples,
		"cells": cells,
		"render_surface": {
			"world_vertices": world_vertices,
			"local_vertices": local_vertices,
			"vertex_colors": vertex_colors,
			"indices": render_indices,
			"primitive": "triangles",
		},
		"collision_polygons": collision_polygons,
		"feature_nodes": feature_nodes,
		"resource_nodes": resource_nodes,
		"origin_safe_zone": {
			"center": ORIGIN_SAFE_CENTER,
			"radius": ORIGIN_SAFE_RADIUS,
		} if chunk_position == Vector2i.ZERO else null,
	}


func sample_world(world_position: Vector2) -> Dictionary:
	## Analytic world-space query.  Streaming/rendering code should normally use
	## the precomputed `samples` and `cells` in generate_chunk().
	var fields := _world_fields(world_position)
	var weights := _terrain_weights(fields)
	var properties := VIPTerrainCatalog.blended_properties(weights)
	var river_depth := float(fields["river"])
	var deep_river_block := _smoothstep(0.68, 0.94, river_depth)
	var blocked_strength := maxf(float(properties.get("blocked_strength", 0.0)), deep_river_block)
	properties["blocked_strength"] = blocked_strength
	properties["blocked_ground"] = blocked_strength >= BLOCK_THRESHOLD
	if blocked_strength >= 0.86:
		properties["movement_multiplier"] = 0.0
	var color := VIPTerrainCatalog.blended_color(weights)
	var elevation_tint := clampf((float(fields["elevation"]) - 0.52) * 0.12, -0.035, 0.055)
	if elevation_tint >= 0.0:
		color = color.lightened(elevation_tint)
	else:
		color = color.darkened(-elevation_tint)
	return {
		"position": world_position,
		"terrain": _primary_terrain(weights),
		"weights": weights,
		"color": color,
		"properties": properties,
		"blocked_strength": blocked_strength,
		"blocked_ground": bool(properties["blocked_ground"]),
		"movement_multiplier": float(properties["movement_multiplier"]),
		"defense_bonus": float(properties["defense_bonus"]),
		"ranged_bonus": float(properties["ranged_bonus"]),
		"river_depth": river_depth,
		"fields": fields,
	}


func gameplay_at(world_position: Vector2) -> Dictionary:
	var sample := sample_world(world_position)
	return Dictionary(sample["properties"]).duplicate(true)


func terrain_at(world_position: Vector2) -> String:
	return str(sample_world(world_position)["terrain"])


func _world_fields(world_position: Vector2) -> Dictionary:
	var continent_noise := _fbm(world_position + Vector2(1040.0, -810.0), 6800.0, _SALT_CONTINENT, 5)
	var broad_continent := _fbm(world_position + Vector2(-2200.0, 1700.0), 18500.0, _SALT_CONTINENT + 17, 3)
	var elevation_detail := _fbm(world_position, 2100.0, _SALT_ELEVATION, 4)
	var elevation := clampf(0.50 + continent_noise * 0.27 + broad_continent * 0.17 + elevation_detail * 0.10, 0.0, 1.0)
	var moisture := clampf(0.52 + _fbm(world_position + Vector2(3800.0, 900.0), 4700.0, _SALT_MOISTURE, 4) * 0.43, 0.0, 1.0)
	var temperature_wave := sin((world_position.y + float(world_seed % 4096)) / 14500.0) * 0.09
	var temperature := clampf(0.58 + _fbm(world_position - Vector2(1400.0, 2800.0), 7200.0, _SALT_TEMPERATURE, 3) * 0.32 + temperature_wave, 0.0, 1.0)
	var vegetation := clampf(0.50 + _fbm(world_position + Vector2(-900.0, 2100.0), 1900.0, _SALT_VEGETATION, 4) * 0.46, 0.0, 1.0)
	var lake_basin := _value_noise(world_position + Vector2(1200.0, -2600.0), 2400.0, _SALT_LAKE)
	var ridge_noise := _fbm(world_position + Vector2(700.0, 1300.0), 3300.0, _SALT_RIDGE, 4)
	var ridge := clampf(1.0 - absf(ridge_noise), 0.0, 1.0)
	var ore := clampf(0.50 + _fbm(world_position + Vector2(2100.0, -500.0), 1050.0, _SALT_ORE, 3) * 0.50, 0.0, 1.0)
	var safe_amount := 1.0 - _smoothstep(ORIGIN_SAFE_RADIUS, ORIGIN_SAFE_TRANSITION_RADIUS, world_position.distance_to(ORIGIN_SAFE_CENTER))
	# The protected opening plain suppresses deep channels as well as their
	# visual terrain weight, so a river can never invisibly block the player.
	var river := _river_signal(world_position) * (1.0 - safe_amount)
	return {
		"elevation": elevation,
		"moisture": moisture,
		"temperature": temperature,
		"vegetation": vegetation,
		"lake_basin": lake_basin,
		"ridge": ridge,
		"ore": ore,
		"river": river,
		"safe_amount": clampf(safe_amount, 0.0, 1.0),
	}


func _terrain_weights(fields: Dictionary) -> Dictionary:
	var elevation := float(fields["elevation"])
	var moisture := float(fields["moisture"])
	var temperature := float(fields["temperature"])
	var vegetation := float(fields["vegetation"])
	var safe_amount := float(fields["safe_amount"])

	var ocean_signal := _inverse_smoothstep(0.43, 0.25, elevation)
	var land_signal := 1.0 - ocean_signal
	var lake_signal := (
		_smoothstep(0.70, 0.88, float(fields["lake_basin"]))
		* _inverse_smoothstep(0.61, 0.39, elevation)
		* land_signal
	)
	var river_signal := float(fields["river"]) * land_signal * (1.0 - lake_signal)
	var mountain_signal := (
		_smoothstep(0.67, 0.91, float(fields["ridge"]))
		* _smoothstep(0.48, 0.67, elevation)
		* land_signal
	)
	var plateau_signal := (
		_smoothstep(0.57, 0.76, elevation)
		* (1.0 - mountain_signal * 0.82)
		* land_signal
	)
	var mine_signal := (
		_smoothstep(0.65, 0.82, float(fields["ore"]))
		* maxf(mountain_signal, plateau_signal * 0.82)
		* land_signal
	)
	var desert_signal := (
		_smoothstep(0.52, 0.75, temperature)
		* _inverse_smoothstep(0.47, 0.21, moisture)
		* (1.0 - mountain_signal)
		* land_signal
	)
	var forest_signal := (
		_smoothstep(0.46, 0.72, moisture)
		* _smoothstep(0.44, 0.72, vegetation)
		* (1.0 - plateau_signal * 0.45)
		* land_signal
	)
	var water_nearby := maxf(lake_signal, river_signal * 0.88)
	var swamp_signal := (
		_smoothstep(0.64, 0.86, moisture)
		* _inverse_smoothstep(0.57, 0.36, elevation)
		* maxf(0.48, water_nearby)
		* land_signal
	)
	var plains_signal := land_signal * (
		0.45
		+ (1.0 - mountain_signal) * 0.20
		+ (1.0 - absf(moisture - 0.52) * 1.7) * 0.12
	)

	var hazard_scale := 1.0 - safe_amount
	var scores: Dictionary = {
		"ocean": (0.002 + ocean_signal * 4.8) * hazard_scale,
		"lake": (0.002 + lake_signal * 4.2) * hazard_scale,
		"river": (0.002 + river_signal * 3.8) * hazard_scale,
		"mountain": (0.003 + mountain_signal * 3.4) * hazard_scale,
		"mine": (0.002 + mine_signal * 4.5) * hazard_scale,
		"plateau": (0.008 + plateau_signal * 2.25) * hazard_scale,
		"desert": (0.008 + desert_signal * 2.65) * hazard_scale,
		"forest": (0.008 + forest_signal * 2.45) * hazard_scale,
		"swamp": (0.006 + swamp_signal * 3.0) * hazard_scale,
		"plains": plains_signal + safe_amount * 8.0,
	}
	return _normalize_scores(scores, 2.15)


func _river_signal(world_position: Vector2) -> float:
	## Two infinite, deterministic meandering channels.  They remain connected
	## because their center lines are functions of absolute X or Y only.
	var phase_a := float((_hash_int(world_seed, 0, _SALT_RIVER_A) % 6283)) / 1000.0
	var x_curve_noise := _value_noise(Vector2(world_position.x, 0.0), 5200.0, _SALT_RIVER_A) * 2.0 - 1.0
	var horizontal_center := 1500.0 + sin(world_position.x / 1750.0 + phase_a) * 430.0 + x_curve_noise * 760.0
	var horizontal_distance := absf(world_position.y - horizontal_center)
	var horizontal := 1.0 - _smoothstep(62.0, 205.0, horizontal_distance)

	var phase_b := float((_hash_int(0, world_seed, _SALT_RIVER_B) % 6283)) / 1000.0
	var y_curve_noise := _value_noise(Vector2(0.0, world_position.y), 6100.0, _SALT_RIVER_B) * 2.0 - 1.0
	var vertical_center := -2450.0 + sin(world_position.y / 2100.0 + phase_b) * 520.0 + y_curve_noise * 850.0
	var vertical_distance := absf(world_position.x - vertical_center)
	var vertical := 1.0 - _smoothstep(58.0, 190.0, vertical_distance)
	return clampf(maxf(horizontal, vertical), 0.0, 1.0)


func _populate_feature_nodes(chunk_position: Vector2i, feature_nodes: Array[Dictionary], resource_nodes: Array[Dictionary]) -> void:
	var global_feature_origin := chunk_position * FEATURE_CELLS_PER_CHUNK
	for local_y in range(FEATURE_CELLS_PER_CHUNK):
		for local_x in range(FEATURE_CELLS_PER_CHUNK):
			var feature_cell := global_feature_origin + Vector2i(local_x, local_y)
			var jitter := Vector2(
				lerpf(0.16, 0.84, _hash_unit(feature_cell.x, feature_cell.y, _SALT_FEATURE_X)),
				lerpf(0.16, 0.84, _hash_unit(feature_cell.x, feature_cell.y, _SALT_FEATURE_Y))
			)
			var position := (Vector2(feature_cell) + jitter) * FEATURE_CELL_SIZE
			if position.distance_to(ORIGIN_SAFE_CENTER) < ORIGIN_FEATURE_CLEAR_RADIUS:
				continue
			var sample := sample_world(position)
			var terrain_id := str(sample["terrain"])
			var feature_roll := _hash_unit(feature_cell.x, feature_cell.y, _SALT_FEATURE_KIND)
			var resource_roll := _hash_unit(feature_cell.x, feature_cell.y, _SALT_RESOURCE)
			var feature := _feature_for_terrain(terrain_id, feature_roll)
			if not feature.is_empty() and feature_roll <= float(feature["chance"]):
				feature_nodes.append({
					"id": "vip_feature_%d_%d" % [feature_cell.x, feature_cell.y],
					"type": feature["type"],
					"position": position,
					"terrain": terrain_id,
					"radius": float(feature["radius"]),
					"blocks_ground": bool(feature["blocks_ground"]),
					"collision_shape": "circle",
				})
			var resource := _resource_for_terrain(terrain_id, resource_roll)
			if not resource.is_empty() and resource_roll <= float(resource["chance"]):
				var resource_type := str(resource["type"])
				resource_nodes.append({
					"id": "vip_resource_%d_%d" % [feature_cell.x, feature_cell.y],
					"type": resource_type,
					"resource_id": resource_type,
					# The first VIP release stores eight broad resources.  The
					# semantic type remains available for future specialized recipes.
					"inventory_key": _inventory_key_for_resource(resource_type),
					"position": position,
					"terrain": terrain_id,
					"amount": int(resource["amount"]),
					"renewable": bool(resource["renewable"]),
					"interaction_radius": float(resource["interaction_radius"]),
				})


func _feature_for_terrain(terrain_id: String, roll: float) -> Dictionary:
	match terrain_id:
		"ocean": return {"type": "reef", "chance": 0.20, "radius": 22.0, "blocks_ground": false}
		"lake": return {"type": "reed_bed", "chance": 0.42, "radius": 16.0, "blocks_ground": false}
		"river": return {"type": "river_reeds", "chance": 0.34, "radius": 13.0, "blocks_ground": false}
		"mountain": return {"type": "mountain_crag", "chance": 0.58, "radius": 34.0, "blocks_ground": true}
		"mine": return {"type": "mine_entrance", "chance": 0.72, "radius": 28.0, "blocks_ground": true}
		"plateau": return {"type": "plateau_boulder", "chance": 0.34, "radius": 20.0, "blocks_ground": true}
		"desert": return {"type": "cactus", "chance": 0.44, "radius": 11.0, "blocks_ground": true}
		"forest": return {"type": "tree", "chance": 0.82, "radius": lerpf(18.0, 30.0, roll), "blocks_ground": true}
		"swamp": return {"type": "swamp_tree", "chance": 0.62, "radius": 19.0, "blocks_ground": true}
		"plains": return {"type": "grass_tuft", "chance": 0.26, "radius": 7.0, "blocks_ground": false}
	return {}


func _resource_for_terrain(terrain_id: String, roll: float) -> Dictionary:
	match terrain_id:
		"ocean": return _resource("fish", 0.24, 18 + int(roll * 18.0), true, 30.0)
		"lake": return _resource("freshwater_fish", 0.32, 14 + int(roll * 15.0), true, 26.0)
		"river": return _resource("clay", 0.24, 12 + int(roll * 14.0), true, 24.0)
		"mountain": return _resource("iron", 0.28, 22 + int(roll * 32.0), false, 28.0)
		"mine":
			var mineral := "iron"
			if roll < 0.08: mineral = "crystal"
			elif roll < 0.17: mineral = "gold"
			elif roll < 0.34: mineral = "coal"
			return _resource(mineral, 0.78, 34 + int(roll * 52.0), false, 30.0)
		"plateau": return _resource("copper", 0.22, 18 + int(roll * 26.0), false, 25.0)
		"desert":
			var desert_resource := "crystal" if roll < 0.10 else "salt"
			return _resource(desert_resource, 0.28, 16 + int(roll * 22.0), false, 24.0)
		"forest":
			var forest_resource := "herbs" if roll < 0.14 else "wood"
			return _resource(forest_resource, 0.38, 12 + int(roll * 24.0), true, 22.0)
		"swamp":
			var swamp_resource := "herbs" if roll < 0.17 else "peat"
			return _resource(swamp_resource, 0.36, 10 + int(roll * 19.0), true, 22.0)
		"plains": return _resource("grain", 0.20, 12 + int(roll * 18.0), true, 20.0)
	return {}


func _inventory_key_for_resource(resource_type: String) -> String:
	match resource_type:
		"fish", "freshwater_fish": return "fish"
		"iron", "coal", "copper": return "iron"
		"gold": return "gold"
		"crystal": return "crystal"
		"salt": return "salt"
		"wood", "peat": return "wood"
		"herbs", "grain": return "herbs"
		"clay": return "stone"
	return "stone"


func _resource(resource_type: String, chance: float, amount: int, renewable: bool, interaction_radius: float) -> Dictionary:
	return {
		"type": resource_type,
		"chance": chance,
		"amount": amount,
		"renewable": renewable,
		"interaction_radius": interaction_radius,
	}


func _blocked_polygon_for_triangle(indices: PackedInt32Array, samples: Array[Dictionary], chunk_origin: Vector2) -> Dictionary:
	var input: Array[Dictionary] = []
	var terrain_counts: Dictionary = {}
	for index in indices:
		var sample := samples[index]
		input.append({
			"position": Vector2(sample["position"]),
			"value": float(sample["blocked_strength"]),
		})
		var terrain_id := str(sample["terrain"])
		terrain_counts[terrain_id] = int(terrain_counts.get(terrain_id, 0)) + 1
	var clipped := _clip_scalar_polygon(input, BLOCK_THRESHOLD)
	var world_polygon := PackedVector2Array()
	var local_polygon := PackedVector2Array()
	for vertex in clipped:
		var position := Vector2(Dictionary(vertex)["position"])
		world_polygon.append(position)
		local_polygon.append(position - chunk_origin)
	var terrain := "mountain"
	var best_count := -1
	for terrain_id in terrain_counts:
		if int(terrain_counts[terrain_id]) > best_count:
			best_count = int(terrain_counts[terrain_id])
			terrain = str(terrain_id)
	return {
		"terrain": terrain,
		"world_polygon": world_polygon,
		"local_polygon": local_polygon,
	}


func _clip_scalar_polygon(input: Array[Dictionary], threshold: float) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if input.is_empty():
		return output
	var previous := input[input.size() - 1]
	var previous_inside := float(previous["value"]) >= threshold
	for current in input:
		var current_inside := float(current["value"]) >= threshold
		if current_inside != previous_inside:
			var previous_value := float(previous["value"])
			var current_value := float(current["value"])
			var denominator := current_value - previous_value
			var amount := 0.5 if absf(denominator) <= 0.000001 else (threshold - previous_value) / denominator
			output.append({
				"position": Vector2(previous["position"]).lerp(Vector2(current["position"]), clampf(amount, 0.0, 1.0)),
				"value": threshold,
			})
		if current_inside:
			output.append(current)
		previous = current
		previous_inside = current_inside
	return output


func _average_weights(indices: PackedInt32Array, samples: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
		result[terrain_id] = 0.0
	for index in indices:
		var weights := Dictionary(samples[index]["weights"])
		for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
			result[terrain_id] = float(result[terrain_id]) + float(weights.get(terrain_id, 0.0)) / float(indices.size())
	return result


func _meaningful_transitions(weights: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
		if float(weights.get(terrain_id, 0.0)) >= 0.09:
			result.append(terrain_id)
	result.sort_custom(func(a: String, b: String) -> bool: return float(weights[a]) > float(weights[b]))
	return result


func _primary_terrain(weights: Dictionary) -> String:
	var best_id := "plains"
	var best_weight := -1.0
	for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
		var weight := float(weights.get(terrain_id, 0.0))
		if weight > best_weight:
			best_weight = weight
			best_id = terrain_id
	return best_id


func _normalize_scores(scores: Dictionary, sharpness: float) -> Dictionary:
	var result: Dictionary = {}
	var total := 0.0
	for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
		var sharpened := pow(maxf(0.0, float(scores.get(terrain_id, 0.0))), sharpness)
		result[terrain_id] = sharpened
		total += sharpened
	if total <= 0.000001:
		for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
			result[terrain_id] = 1.0 if terrain_id == "plains" else 0.0
		return result
	for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
		result[terrain_id] = float(result[terrain_id]) / total
	return result


func _value_noise(world_position: Vector2, wavelength: float, salt: int) -> float:
	var scaled := world_position / maxf(1.0, wavelength)
	var x0 := int(floor(scaled.x))
	var y0 := int(floor(scaled.y))
	var x1 := x0 + 1
	var y1 := y0 + 1
	var tx := _smootherstep01(scaled.x - float(x0))
	var ty := _smootherstep01(scaled.y - float(y0))
	var top := lerpf(_hash_unit(x0, y0, salt), _hash_unit(x1, y0, salt), tx)
	var bottom := lerpf(_hash_unit(x0, y1, salt), _hash_unit(x1, y1, salt), tx)
	return lerpf(top, bottom, ty)


func _fbm(world_position: Vector2, base_wavelength: float, salt: int, octaves: int) -> float:
	var value := 0.0
	var amplitude := 1.0
	var amplitude_sum := 0.0
	var wavelength := base_wavelength
	for octave in range(maxi(1, octaves)):
		value += (_value_noise(world_position, wavelength, salt + octave * 29) * 2.0 - 1.0) * amplitude
		amplitude_sum += amplitude
		amplitude *= 0.5
		wavelength *= 0.5
	return value / maxf(amplitude_sum, 0.00001)


func _hash_unit(x: int, y: int, salt: int) -> float:
	return float(_hash_int(x, y, salt)) / float(_HASH_MASK)


func _hash_int(x: int, y: int, salt: int) -> int:
	var value := (
		(x & _HASH_MASK) * _HASH_A
		+ (y & _HASH_MASK) * _HASH_B
		+ (world_seed & _HASH_MASK) * _HASH_D
		+ (salt & _HASH_MASK) * 104729
	) & _HASH_MASK
	value = ((value ^ (value >> 13)) * _HASH_C) & _HASH_MASK
	value = ((value ^ (value >> 16)) * _HASH_A) & _HASH_MASK
	return value & _HASH_MASK


func _vertex_index(grid_x: int, grid_y: int) -> int:
	return grid_y * GRID_VERTICES + grid_x


func _touch_cache_key(key: String) -> void:
	_cache_order.erase(key)
	_cache_order.append(key)


func _trim_cache() -> void:
	while _cache_order.size() > max_cached_chunks:
		var oldest: String = _cache_order.pop_front()
		_chunk_cache.erase(oldest)


func _smoothstep(edge_a: float, edge_b: float, value: float) -> float:
	if is_equal_approx(edge_a, edge_b):
		return 1.0 if value >= edge_b else 0.0
	var t := clampf((value - edge_a) / (edge_b - edge_a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _inverse_smoothstep(high_edge: float, low_edge: float, value: float) -> float:
	return 1.0 - _smoothstep(low_edge, high_edge, value)


func _smootherstep01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func validate_chunk_data(data: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (data is Dictionary):
		return {"passed": false, "errors": ["chunk data is not a dictionary"]}
	var chunk := Dictionary(data)
	for required_key in ["version", "seed", "chunk", "key", "size", "origin", "bounds", "samples", "cells", "render_surface", "collision_polygons", "feature_nodes", "resource_nodes"]:
		if not chunk.has(required_key):
			errors.append("missing chunk key: %s" % required_key)
	if chunk.has("samples") and Array(chunk["samples"]).size() != GRID_VERTICES * GRID_VERTICES:
		errors.append("unexpected sample count")
	if chunk.has("cells") and Array(chunk["cells"]).size() != GRID_CELLS * GRID_CELLS:
		errors.append("unexpected cell count")
	if chunk.has("render_surface") and chunk["render_surface"] is Dictionary:
		var surface := Dictionary(chunk["render_surface"])
		if not (surface.get("world_vertices") is PackedVector2Array):
			errors.append("render vertices are not packed")
		if not (surface.get("vertex_colors") is PackedColorArray):
			errors.append("render colors are not packed")
		if not (surface.get("indices") is PackedInt32Array):
			errors.append("render indices are not packed")
		elif PackedInt32Array(surface["indices"]).size() != GRID_CELLS * GRID_CELLS * 6:
			errors.append("unexpected render index count")
	return {"passed": errors.is_empty(), "errors": errors}


func core_self_test() -> Dictionary:
	var errors: Array[String] = []
	var catalog_result := VIPTerrainCatalog.catalog_self_test()
	if not bool(catalog_result["passed"]):
		errors.append_array(Array(catalog_result["errors"]))

	var origin_sample := sample_world(ORIGIN_SAFE_CENTER)
	if str(origin_sample["terrain"]) != "plains":
		errors.append("origin is not plains")
	if bool(origin_sample["blocked_ground"]):
		errors.append("origin blocks ground movement")

	var center_chunk := build_chunk_data(Vector2i.ZERO)
	var validation := validate_chunk_data(center_chunk)
	if not bool(validation["passed"]):
		errors.append_array(Array(validation["errors"]))

	var left := build_chunk_data(Vector2i.ZERO)
	var right := build_chunk_data(Vector2i(1, 0))
	var left_samples := Array(left["samples"])
	var right_samples := Array(right["samples"])
	for grid_y in range(GRID_VERTICES):
		var a := Dictionary(left_samples[_vertex_index(GRID_CELLS, grid_y)])
		var b := Dictionary(right_samples[_vertex_index(0, grid_y)])
		if Vector2(a["position"]) != Vector2(b["position"]):
			errors.append("neighbor positions do not share edge at row %d" % grid_y)
			continue
		if str(a["terrain"]) != str(b["terrain"]) or not is_equal_approx(float(a["blocked_strength"]), float(b["blocked_strength"])):
			errors.append("neighbor fields do not share edge at row %d" % grid_y)

	var found: Dictionary = {}
	for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
		found[terrain_id] = false
	for scan_y in range(-28, 29):
		for scan_x in range(-28, 29):
			var terrain_id := terrain_at(Vector2(float(scan_x) * 660.0 + 37.0, float(scan_y) * 660.0 + 83.0))
			found[terrain_id] = true
	var missing: Array[String] = []
	for terrain_id in VIPTerrainCatalog.TERRAIN_ORDER:
		if not bool(found.get(terrain_id, false)):
			missing.append(terrain_id)
	if not missing.is_empty():
		errors.append("terrain coverage missing: %s" % ", ".join(missing))

	return {
		"passed": errors.is_empty(),
		"errors": errors,
		"terrain_found": found,
		"catalog": catalog_result,
	}

class_name CampaignVisualRenderer
extends RefCounted

## Shared procedural art used by the campaign and Arena presentation layers.
##
## Every draw method must be called while `canvas` is handling its `_draw()`
## notification. The renderer does not mutate CanvasItem transforms, simulation
## state, save data, or upgrade data.

const GameConfig = preload("res://scripts/game_config.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")

const PROFILE_ID := "campaign"
const SOLDIER_RENDERER_ID := "campaign_soldier_v1"
const HERO_RENDERER_ID := "campaign_hero_v1"
const MAP_RENDERER_ID := "campaign_wildland_v1"

const BLUE := Color("3B82F6")
const BLUE_DARK := Color("12365A")
const RED := Color("D94C42")
const RED_DARK := Color("4A1714")
const INK := Color("1B2930")
const GOLD := Color("FFD166")
const HEAL_GREEN := Color("55D98A")
const MAGIC_PURPLE := Color("A78BFA")
const FIRE_ORANGE := Color("FF7A38")
const FLASH_COLOR := Color("EAF6FF")

const SUPPORTED_SOLDIER_TYPES: Array[String] = [
	"swordsman", "healer", "archer", "roller", "mage", "heavy",
	"priest", "cannon", "musketeer", "rifleman", "tank", "rocket",
	"gatling", "helicopter", "bomber", "ufo",
]


static func radius_for(type_id: String) -> float:
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


static func supported_soldier_types() -> Array[String]:
	var result: Array[String] = []
	result.append_array(SUPPORTED_SOLDIER_TYPES)
	return result


static func draw_soldier(
	canvas: CanvasItem,
	soldier: Dictionary,
	ground_screen_position: Vector2,
	time_seconds: float,
	team: String = "blue",
	visual_scale: float = 1.0,
	draw_shadow: bool = true
) -> bool:
	if canvas == null:
		return false
	var type_id := str(soldier.get("type", ""))
	if type_id not in SUPPORTED_SOLDIER_TYPES or not GameConfig.SOLDIERS.has(type_id):
		return false
	var scale := maxf(0.01, visual_scale)
	var base_radius := maxf(1.0, float(soldier.get("radius", radius_for(type_id))))
	var radius := base_radius * scale
	var entity_id := int(soldier.get("id", 0))
	var primary := _team_primary(team)
	var dark := _team_dark(team)
	var color := FLASH_COLOR if float(soldier.get("flash", 0.0)) > 0.0 else Color(GameConfig.SOLDIERS[type_id]["color"])
	var airborne := str(soldier.get("domain", "ground")) == "air"
	var position := ground_screen_position
	if airborne:
		position -= Vector2(0.0, 14.0 + sin(time_seconds * 3.4 + float(entity_id)) * 2.5) * scale
	if draw_shadow:
		if airborne:
			_draw_ellipse_shadow(canvas, ground_screen_position + Vector2(16.0, 25.0) * scale, Vector2(base_radius * 1.2, base_radius * 0.48) * scale)
		else:
			_draw_ellipse_shadow(canvas, position + Vector2(4.0, 7.0) * scale, Vector2(base_radius, base_radius * 0.45) * scale)

	if type_id == "cannon":
		var facing := _unit_facing(soldier, team)
		var side := Vector2(-facing.y, facing.x)
		for wheel_side in [-1.0, 1.0]:
			var wheel_center: Vector2 = position - facing * 8.0 * scale + side * float(wheel_side) * 15.0 * scale
			canvas.draw_circle(wheel_center, 9.0 * scale, INK)
			canvas.draw_arc(wheel_center, 9.0 * scale, 0.0, TAU, 16, Color("79A6C1"), 2.0 * scale)
		_draw_polygon_shape(canvas, position - facing * 4.0 * scale, [Vector2(-20, -13), Vector2(16, -13), Vector2(21, 12), Vector2(-20, 12)], facing.angle(), Color("7D9FB2"), dark, 2.8 * scale, scale)
		_draw_polygon_shape(canvas, position, [Vector2(-14, -8), Vector2(14, -8), Vector2(17, 7), Vector2(-14, 7)], facing.angle(), primary, Color("B9E0F4"), 2.0 * scale, scale)
		canvas.draw_line(position + facing * 2.0 * scale, position + facing * 39.0 * scale, Color("D5E7EF"), 12.0 * scale)
		canvas.draw_line(position + facing * 34.0 * scale, position + facing * 44.0 * scale, Color("202A30"), 15.0 * scale)
		canvas.draw_circle(position - facing * 10.0 * scale, 7.0 * scale, GOLD)
	elif type_id == "tank":
		var facing := _unit_facing(soldier, team)
		var side := Vector2(-facing.y, facing.x)
		for track_side in [-1.0, 1.0]:
			var track_center: Vector2 = position + side * float(track_side) * 18.0 * scale
			_draw_polygon_shape(canvas, track_center, [Vector2(-27, -7), Vector2(27, -7), Vector2(27, 7), Vector2(-27, 7)], facing.angle(), Color("263238"), dark, 2.0 * scale, scale)
			for tread_index in 6:
				var tread_center: Vector2 = track_center + facing * (-21.0 + float(tread_index) * 8.5) * scale
				canvas.draw_line(tread_center - side * 5.0 * scale, tread_center + side * 5.0 * scale, Color("8EB1BD"), 1.5 * scale)
		_draw_polygon_shape(canvas, position, [Vector2(-25, -15), Vector2(20, -15), Vector2(27, 0), Vector2(20, 15), Vector2(-25, 15)], facing.angle(), Color("70875B"), dark, 3.0 * scale, scale)
		canvas.draw_circle(position, 14.0 * scale, Color("86A66A"))
		canvas.draw_arc(position, 14.0 * scale, 0.0, TAU, 20, Color("CDE7D0"), 2.2 * scale)
		canvas.draw_line(position + facing * 5.0 * scale, position + facing * 43.0 * scale, Color("C8D8CF"), 10.0 * scale)
		canvas.draw_circle(position + facing * 43.0 * scale, 5.5 * scale, Color("233137"))
		canvas.draw_rect(Rect2(position - Vector2(5.0, 5.0) * scale, Vector2(10.0, 10.0) * scale), primary)
	elif type_id == "rocket":
		var facing := _unit_facing(soldier, team)
		var side := Vector2(-facing.y, facing.x)
		for wheel_side in [-1.0, 1.0]:
			canvas.draw_circle(position - facing * 8.0 * scale + side * wheel_side * 15.0 * scale, 8.0 * scale, INK)
		_draw_polygon_shape(canvas, position - facing * 7.0 * scale, [Vector2(-19, -14), Vector2(17, -14), Vector2(21, 14), Vector2(-19, 14)], facing.angle(), Color("55788C"), dark, 2.5 * scale, scale)
		for lane in [-1.0, 0.0, 1.0]:
			var launcher_offset: Vector2 = side * float(lane) * 8.0 * scale
			canvas.draw_line(position - facing * 3.0 * scale + launcher_offset, position + facing * 33.0 * scale + launcher_offset, Color("C7D9E1"), 7.0 * scale)
			_draw_polygon_shape(canvas, position + facing * 36.0 * scale + launcher_offset, [Vector2(-7, -5), Vector2(6, 0), Vector2(-7, 5)], facing.angle(), FIRE_ORANGE, Color("743224"), 1.2 * scale, scale)
		canvas.draw_rect(Rect2(position - Vector2(6.0, 6.0) * scale, Vector2(12.0, 12.0) * scale), primary)
	elif type_id == "gatling":
		var facing := _unit_facing(soldier, team)
		var side := Vector2(-facing.y, facing.x)
		_draw_polygon_shape(canvas, position - facing * 7.0 * scale, [Vector2(-18, -14), Vector2(16, -12), Vector2(20, 12), Vector2(-18, 14)], facing.angle(), Color("4D7894"), dark, 2.6 * scale, scale)
		canvas.draw_circle(position, 12.0 * scale, Color("B8DDEC"))
		for barrel_lane in [-2.0, -1.0, 0.0, 1.0, 2.0]:
			var barrel_offset: Vector2 = side * float(barrel_lane) * 3.0 * scale
			canvas.draw_line(position + facing * 6.0 * scale + barrel_offset, position + facing * (36.0 - absf(barrel_lane)) * scale + barrel_offset, Color("D6EEF6"), 3.2 * scale)
		canvas.draw_circle(position + facing * 37.0 * scale, 6.0 * scale, Color("83E8FF"), false, 2.0 * scale)
	elif type_id == "helicopter":
		var facing := _unit_facing(soldier, team)
		_draw_polygon_shape(canvas, position, [Vector2(-24, -14), Vector2(17, -16), Vector2(29, 0), Vector2(17, 16), Vector2(-24, 14), Vector2(-31, 0)], facing.angle(), Color("4F9AB8"), dark, 3.0 * scale, scale)
		canvas.draw_circle(position + facing * 13.0 * scale, 11.0 * scale, Color("B8F2FF"))
		canvas.draw_line(position - facing * 20.0 * scale, position - facing * 55.0 * scale, Color("426E83"), 8.0 * scale)
		_draw_polygon_shape(canvas, position - facing * 57.0 * scale, [Vector2(-9, -13), Vector2(8, 0), Vector2(-9, 13)], facing.angle(), primary, dark, 2.0 * scale, scale)
		var rotor_direction := Vector2.from_angle(time_seconds * 12.0 + float(entity_id))
		canvas.draw_line(position - rotor_direction * 43.0 * scale, position + rotor_direction * 43.0 * scale, Color(0.75, 0.95, 1.0, 0.76), 3.0 * scale)
		canvas.draw_line(position - rotor_direction.rotated(PI * 0.5) * 36.0 * scale, position + rotor_direction.rotated(PI * 0.5) * 36.0 * scale, Color(0.75, 0.95, 1.0, 0.48), 2.0 * scale)
		canvas.draw_line(position + facing * 17.0 * scale, position + facing * 38.0 * scale, Color("D6EEF6"), 5.0 * scale)
	elif type_id == "bomber":
		var facing := _unit_facing(soldier, team)
		var side := Vector2(-facing.y, facing.x)
		_draw_polygon_shape(canvas, position, [Vector2(-35, -13), Vector2(-13, -12), Vector2(-3, -48), Vector2(14, -43), Vector2(21, -13), Vector2(40, 0), Vector2(21, 13), Vector2(14, 43), Vector2(-3, 48), Vector2(-13, 12), Vector2(-35, 13)], facing.angle(), Color("718DB6"), dark, 3.0 * scale, scale)
		_draw_polygon_shape(canvas, position + facing * 4.0 * scale, [Vector2(-28, -7), Vector2(30, 0), Vector2(-28, 7)], facing.angle(), Color("A9D8FF"), Color.TRANSPARENT, 0.0, scale)
		for engine_side in [-1.0, 1.0]:
			var engine_center: Vector2 = position - facing * 3.0 * scale + side * float(engine_side) * 22.0 * scale
			canvas.draw_circle(engine_center, 8.0 * scale, Color("263B4B"))
			canvas.draw_circle(engine_center - facing * 3.0 * scale, 4.0 * scale, Color("83E8FF"))
		canvas.draw_rect(Rect2(position - Vector2(9.0, 5.0) * scale, Vector2(18.0, 10.0) * scale), primary)
	elif type_id == "ufo":
		var pulse := 0.5 + 0.5 * sin(time_seconds * 5.5 + float(entity_id))
		canvas.draw_circle(position + Vector2(0.0, 9.0) * scale, (38.0 + pulse * 4.0) * scale, Color(0.25, 0.88, 1.0, 0.12 + pulse * 0.08))
		_draw_polygon_shape(canvas, position, [Vector2(-43, -4), Vector2(-31, -13), Vector2(-16, -18), Vector2(16, -18), Vector2(31, -13), Vector2(43, -4), Vector2(37, 8), Vector2(20, 15), Vector2(-20, 15), Vector2(-37, 8)], 0.0, Color("5D91A8"), dark, 3.0 * scale, scale)
		canvas.draw_circle(position + Vector2(0.0, -10.0) * scale, 17.0 * scale, Color("A8FBFF"))
		canvas.draw_arc(position + Vector2(0.0, 1.0) * scale, 35.0 * scale, 0.1, PI - 0.1, 28, Color("75E8FF"), 4.0 * scale)
		for light_index in 5:
			canvas.draw_circle(position + Vector2(-24.0 + float(light_index) * 12.0, 10.0) * scale, (3.5 + pulse) * scale, GOLD if light_index % 2 == 0 else Color("75E8FF"))
		canvas.draw_circle(position + Vector2(0.0, 18.0) * scale, (10.0 + pulse * 3.0) * scale, Color(0.35, 0.9, 1.0, 0.42))
	else:
		var points := [Vector2(-base_radius, 4), Vector2(-base_radius * 0.7, -base_radius * 0.75), Vector2(0, -base_radius), Vector2(base_radius * 0.8, -base_radius * 0.55), Vector2(base_radius, 5), Vector2(0, base_radius)]
		_draw_polygon_shape(canvas, position, points, 0.0, color, dark, 2.0 * scale, scale)
		match type_id:
			"swordsman":
				canvas.draw_line(position + Vector2(6, 3) * scale, position + Vector2(17, -9) * scale, FLASH_COLOR, 2.5 * scale)
				canvas.draw_line(position + Vector2(3, 0) * scale, position + Vector2(10, 7) * scale, GOLD, 2.0 * scale)
			"healer":
				canvas.draw_line(position + Vector2(-5, 0) * scale, position + Vector2(5, 0) * scale, HEAL_GREEN, 3.0 * scale)
				canvas.draw_line(position + Vector2(0, -5) * scale, position + Vector2(0, 5) * scale, HEAL_GREEN, 3.0 * scale)
			"archer":
				canvas.draw_arc(position + Vector2(7, 0) * scale, 8.0 * scale, -1.1, 1.1, 10, Color("8B5A2B"), 1.6 * scale)
			"roller":
				canvas.draw_circle(position + Vector2(11, -2) * scale, 7.0 * scale, Color("778493"))
				canvas.draw_line(position + Vector2(8, -5) * scale, position + Vector2(14, 1) * scale, Color("BFD0DA"), 1.0 * scale)
			"mage":
				canvas.draw_line(position + Vector2(4, 8) * scale, position + Vector2(11, -9) * scale, Color("8B5A2B"), 2.0 * scale)
				canvas.draw_circle(position + Vector2(11, -9) * scale, 3.0 * scale, MAGIC_PURPLE)
			"heavy":
				_draw_polygon_shape(canvas, position + Vector2(-10, 0) * scale, [Vector2(-7, -10), Vector2(6, -9), Vector2(9, 5), Vector2(0, 11), Vector2(-8, 5)], 0.0, Color("A7B2BE"), dark, 1.6 * scale, scale)
			"priest":
				canvas.draw_arc(position, radius + 3.0 * scale, PI, TAU, 16, GOLD, 2.0 * scale)
				canvas.draw_line(position + Vector2(8, 7) * scale, position + Vector2(14, -9) * scale, GOLD, 2.0 * scale)
			"musketeer":
				var facing := _unit_facing(soldier, team)
				canvas.draw_line(position - facing * 8.0 * scale, position + facing * 31.0 * scale, Color("875B36"), 5.0 * scale)
				canvas.draw_line(position + facing * 3.0 * scale, position + facing * 37.0 * scale, Color("E1E9ED"), 2.4 * scale)
				canvas.draw_line(position + facing * 33.0 * scale, position + facing * 41.0 * scale, Color("FFFFFF"), 1.5 * scale)
				canvas.draw_arc(position + Vector2(0, -8) * scale, 9.0 * scale, PI, TAU, 12, Color("725039"), 4.0 * scale)
			"rifleman":
				var facing := _unit_facing(soldier, team)
				var side := Vector2(-facing.y, facing.x)
				canvas.draw_circle(position + Vector2(0, -8) * scale, 7.0 * scale, Color("5D8E76"))
				canvas.draw_line(position - facing * 7.0 * scale, position + facing * 31.0 * scale, Color("263136"), 5.0 * scale)
				canvas.draw_line(position + facing * 6.0 * scale, position + facing * 35.0 * scale, Color("DCE8EA"), 1.8 * scale)
				_draw_polygon_shape(canvas, position + facing * 4.0 * scale + side * 5.0 * scale, [Vector2(-3, -2), Vector2(4, -2), Vector2(6, 8), Vector2(-1, 9)], facing.angle(), Color("20282C"), dark, 1.0 * scale, scale)
	return true


static func draw_hero(
	canvas: CanvasItem,
	hero: Dictionary,
	ground_screen_position: Vector2,
	_time_seconds: float = 0.0,
	team: String = "blue",
	visual_scale: float = 1.0,
	draw_shadow: bool = true
) -> bool:
	if canvas == null:
		return false
	var class_id := str(hero.get("class_id", ""))
	if class_id not in ["archer", "mage", "warrior"] or not GameConfig.HERO_CLASSES.has(class_id):
		return false
	var scale := maxf(0.01, visual_scale)
	var facing := Vector2(hero.get("aim_dir", hero.get("facing", Vector2.RIGHT))).normalized()
	if facing.length_squared() < 0.001:
		facing = Vector2.RIGHT if team != "red" else Vector2.LEFT
	var rotation := facing.angle()
	var dark := _team_dark(team)
	var main_color := FLASH_COLOR if float(hero.get("flash", 0.0)) > 0.0 else Color(GameConfig.HERO_CLASSES[class_id]["color"])
	if draw_shadow:
		_draw_ellipse_shadow(canvas, ground_screen_position + Vector2(5, 9) * scale, Vector2(17, 7) * scale)
	match class_id:
		"archer":
			_draw_polygon_shape(canvas, ground_screen_position, [Vector2(-12, 0), Vector2(-8, -8), Vector2(2, -10), Vector2(12, 0), Vector2(2, 10), Vector2(-8, 8)], rotation, main_color, dark, 2.5 * scale, scale)
			var bow_base := ground_screen_position + Vector2(0, -12).rotated(rotation) * scale
			canvas.draw_arc(bow_base, 13.0 * scale, rotation - 1.1, rotation + 1.1, 12, Color("8B5A2B"), 2.2 * scale)
			canvas.draw_line(ground_screen_position + Vector2(2, -24).rotated(rotation) * scale, ground_screen_position + Vector2(2, 0).rotated(rotation) * scale, FLASH_COLOR, 1.0 * scale)
		"mage":
			_draw_polygon_shape(canvas, ground_screen_position, [Vector2(-11, 9), Vector2(-13, -2), Vector2(-5, -12), Vector2(8, -10), Vector2(14, 2), Vector2(9, 11)], rotation, main_color, dark, 2.5 * scale, scale)
			_draw_polygon_shape(canvas, ground_screen_position + Vector2(0, -12).rotated(rotation) * scale, [Vector2(-9, 4), Vector2(4, -14), Vector2(11, 5)], rotation, Color("6E58A8"), dark, 2.0 * scale, scale)
			var orb := ground_screen_position + Vector2(18, -7).rotated(rotation) * scale
			canvas.draw_line(ground_screen_position + Vector2(9, 7).rotated(rotation) * scale, orb, Color("8B5A2B"), 2.0 * scale)
			canvas.draw_circle(orb, 4.0 * scale, MAGIC_PURPLE)
		"warrior":
			_draw_polygon_shape(canvas, ground_screen_position, [Vector2(-14, 9), Vector2(-15, -8), Vector2(-7, -13), Vector2(9, -12), Vector2(15, -5), Vector2(14, 10)], rotation, main_color, dark, 2.5 * scale, scale)
			var shield := ground_screen_position + Vector2(-13, 0).rotated(rotation) * scale
			_draw_polygon_shape(canvas, shield, [Vector2(-6, -10), Vector2(7, -8), Vector2(9, 3), Vector2(0, 12), Vector2(-8, 4)], rotation, Color("A7B2BE"), dark, 2.0 * scale, scale)
			var sword_a := ground_screen_position + Vector2(8, 4).rotated(rotation) * scale
			var sword_b := ground_screen_position + Vector2(23, -10).rotated(rotation) * scale
			canvas.draw_line(sword_a, sword_b, FLASH_COLOR, 3.0 * scale)
			canvas.draw_line(ground_screen_position + Vector2(5, 0).rotated(rotation) * scale, ground_screen_position + Vector2(14, 8).rotated(rotation) * scale, GOLD, 2.0 * scale)
	return true


static func draw_wildland_chunk(
	canvas: CanvasItem,
	chunk: Dictionary,
	camera_world_position: Vector2,
	screen_center: Vector2,
	zoom: float,
	viewport_rect: Rect2
) -> Dictionary:
	var biome_data: Dictionary = Dictionary(chunk.get("biome", {}))
	var result := {
		"key": str(chunk.get("key", "")),
		"biome": str(biome_data.get("id", "unknown")),
		"decoration_count": Array(chunk.get("decorations", [])).size(),
		"obstacle_count": Array(chunk.get("obstacles", [])).size(),
		"decorations_drawn": 0,
		"obstacles_drawn": 0,
		"visible": false,
	}
	if canvas == null or zoom <= 0.0:
		return result
	var chunk_coord: Vector2i = chunk.get("chunk", Vector2i.ZERO)
	var origin_world := Vector2(chunk_coord) * WorldGenerator.CHUNK_SIZE
	var origin_screen := _world_to_screen(origin_world, camera_world_position, screen_center, zoom)
	var chunk_screen_rect := Rect2(origin_screen - Vector2.ONE, Vector2.ONE * (WorldGenerator.CHUNK_SIZE * zoom + 2.0))
	if not chunk_screen_rect.intersects(viewport_rect, true):
		return result
	result["visible"] = true
	var grass_color := _chunk_grass_color(chunk).lerp(Color("607D52"), 0.22)
	canvas.draw_rect(chunk_screen_rect, grass_color)

	var decoration_cull := viewport_rect.grow(30.0 * zoom)
	for decoration_value in Array(chunk.get("decorations", [])):
		if not decoration_value is Dictionary:
			continue
		var decoration: Dictionary = decoration_value
		var position := _world_to_screen(Vector2(decoration.get("position", origin_world)), camera_world_position, screen_center, zoom)
		if not decoration_cull.has_point(position):
			continue
		var kind := str(decoration.get("type", ""))
		if kind in ["wildflower", "marsh_flower"]:
			for petal in 4:
				canvas.draw_circle(position + Vector2.from_angle(float(petal) * PI * 0.5) * 3.2 * zoom, 2.1 * zoom, Color("EFE7F6"))
			canvas.draw_circle(position, 1.6 * zoom, GOLD)
		elif kind in ["stones", "boulder_chip", "mossy_stone"]:
			_draw_polygon_shape(canvas, position, [Vector2(-6, 2), Vector2(-3, -4), Vector2(4, -5), Vector2(7, 1), Vector2(2, 5)], 0.0, Color("778493"), Color("50606A"), 1.0 * zoom, zoom)
		else:
			for blade in 3:
				var x := float(blade - 1) * 4.0
				canvas.draw_line(position + Vector2(x, 4) * zoom, position + Vector2(x + sin(float(blade) * 2.1) * 3.0, -7.0 - float(blade) * 2.0) * zoom, Color(0.17, 0.38, 0.20, 0.55), 1.5 * zoom)
		result["decorations_drawn"] = int(result["decorations_drawn"]) + 1

	var obstacle_cull := viewport_rect.grow(80.0 * zoom)
	for obstacle_value in Array(chunk.get("obstacles", [])):
		if not obstacle_value is Dictionary:
			continue
		var obstacle: Dictionary = obstacle_value
		var position := _world_to_screen(Vector2(obstacle.get("position", origin_world)), camera_world_position, screen_center, zoom)
		if not obstacle_cull.has_point(position):
			continue
		var base_radius := maxf(1.0, float(obstacle.get("radius", 8.0)))
		var radius := base_radius * zoom
		match str(obstacle.get("type", "")):
			"tree":
				_draw_ellipse_shadow(canvas, position + Vector2(6, 10) * zoom, Vector2(base_radius * 1.35, base_radius * 0.55) * zoom)
				canvas.draw_rect(Rect2(position + Vector2(-4, -4) * zoom, Vector2(8.0, base_radius + 13.0) * zoom), Color("795130"))
				canvas.draw_circle(position + Vector2(0.0, -base_radius * 0.52) * zoom, base_radius * 1.18 * zoom, Color("315D3B"))
				canvas.draw_circle(position + Vector2(-base_radius * 0.35, -base_radius * 0.72) * zoom, base_radius * 0.75 * zoom, Color("477B48"))
				canvas.draw_arc(position + Vector2(0.0, -base_radius * 0.52) * zoom, base_radius * 1.18 * zoom, 0.0, TAU, 20, INK, 2.0 * zoom)
			"rock":
				_draw_ellipse_shadow(canvas, position + Vector2(5, 7) * zoom, Vector2(base_radius, base_radius * 0.45) * zoom)
				_draw_polygon_shape(canvas, position, [Vector2(-base_radius, base_radius * 0.35), Vector2(-base_radius * 0.7, -base_radius * 0.5), Vector2(base_radius * 0.15, -base_radius * 0.78), Vector2(base_radius, -base_radius * 0.05), Vector2(base_radius * 0.55, base_radius * 0.62)], 0.0, Color("778493"), INK, 2.0 * zoom, zoom)
			_:
				_draw_ellipse_shadow(canvas, position + Vector2(4, 7) * zoom, Vector2(base_radius * 1.1, base_radius * 0.5) * zoom)
				canvas.draw_circle(position, radius, Color("45754B"))
				canvas.draw_circle(position + Vector2(-base_radius * 0.45, -base_radius * 0.2) * zoom, base_radius * 0.65 * zoom, Color("5B8D54"))
				canvas.draw_arc(position, radius, 0.0, TAU, 18, INK, 1.7 * zoom)
		result["obstacles_drawn"] = int(result["obstacles_drawn"]) + 1
	return result


static func _team_primary(team: String) -> Color:
	return RED if team == "red" else BLUE


static func _team_dark(team: String) -> Color:
	return RED_DARK if team == "red" else BLUE_DARK


static func _unit_facing(unit: Dictionary, team: String) -> Vector2:
	var facing := Vector2(unit.get("aim_dir", unit.get("vel", Vector2.ZERO))).normalized()
	if facing.length_squared() < 0.001:
		return Vector2.LEFT if team == "red" else Vector2.RIGHT
	return facing


static func _world_to_screen(world_position: Vector2, camera_world_position: Vector2, screen_center: Vector2, zoom: float) -> Vector2:
	return (world_position - camera_world_position) * zoom + screen_center


static func _chunk_grass_color(chunk: Dictionary) -> Color:
	var value: Variant = chunk.get("grass_color", Color("527B4A"))
	if value is Color:
		return value
	if value is Dictionary:
		var data: Dictionary = value
		return Color(float(data.get("r", 0.33)), float(data.get("g", 0.55)), float(data.get("b", 0.31)), float(data.get("a", 1.0)))
	return Color("527B4A")


static func _draw_polygon_shape(canvas: CanvasItem, center: Vector2, points: Array, rotation: float, fill_color: Color, outline_color: Color, outline_width: float, scale: float = 1.0) -> void:
	var transformed := PackedVector2Array()
	for point_value in points:
		transformed.append(center + Vector2(point_value).rotated(rotation) * scale)
	if transformed.size() >= 3:
		canvas.draw_colored_polygon(transformed, fill_color)
	if outline_width > 0.0 and outline_color.a > 0.0 and transformed.size() >= 2:
		var closed := PackedVector2Array(transformed)
		closed.append(transformed[0])
		canvas.draw_polyline(closed, outline_color, outline_width, true)


static func _draw_ellipse_shadow(canvas: CanvasItem, center: Vector2, radii: Vector2) -> void:
	var points := PackedVector2Array()
	for index in 18:
		var angle := TAU * float(index) / 18.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	canvas.draw_colored_polygon(points, Color(0.09, 0.15, 0.12, 0.35))

class_name CampaignVisualRenderer
extends RefCounted

## Shared procedural art used by the campaign and Arena presentation layers.
##
## Every draw method must be called while `canvas` is handling its `_draw()`
## notification. The renderer does not mutate CanvasItem transforms, simulation
## state, save data, or upgrade data.

const GameConfig = preload("res://scripts/game_config.gd")
const WorldGenerator = preload("res://scripts/world_generator.gd")
const WILDLAND_GROUND_TEXTURE = preload("res://assets/environment/textures/wildland_meadow.png")

const PROFILE_ID := "campaign"
const SOLDIER_RENDERER_ID := "campaign_soldier_v2"
const HERO_RENDERER_ID := "campaign_hero_v2"
const MAP_RENDERER_ID := "campaign_wildland_v2"
const STICK_ANIMATION_PROFILE_ID := "procedural_upright_stick_motion_v2"
const HUMANOID_MODEL_ID := "readable_stick_army_v2"
const HUMANOID_BASE_DISPLAY_SCALE := 1.24

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

const HUMANOID_SOLDIER_TYPES: Array[String] = [
	"swordsman", "healer", "archer", "roller", "mage", "heavy", "priest",
	"musketeer", "rifleman",
]

const HUMANOID_ENEMY_TYPES: Array[String] = [
	"grunt", "archer", "thrower", "berserker", "heavy", "shaman",
	"chief", "musketeer", "rifleman",
]

const HUMANOID_SUPPORT_STATES: Array[String] = [
	"heal", "support", "revive_cast", "mark",
]

const HUMANOID_ATTACK_STATES: Array[String] = [
	"attack", "charge", "charge_castle", "aim", "siege_attack", "telegraph", "recover",
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


static func humanoid_animation_contract(
	unit: Dictionary,
	time_seconds: float,
	is_hero: bool = false,
	visual_scale: float = 1.0
) -> Dictionary:
	## Read-only QA contract produced by the same articulated pose used to draw.
	var facing := Vector2(unit.get("aim_dir", unit.get("facing", Vector2.RIGHT))).normalized()
	if facing.length_squared() < 0.001:
		facing = Vector2.RIGHT
	var pose := _humanoid_pose(unit, Vector2.ZERO, facing, time_seconds, maxf(0.01, visual_scale), is_hero)
	var joints := {}
	for joint_name in ["pelvis", "chest", "head", "left_hand", "right_hand", "left_foot", "right_foot"]:
		var point := Vector2(pose[joint_name])
		joints[joint_name] = {"x": snappedf(point.x, 0.001), "y": snappedf(point.y, 0.001)}
	return {
		"profile_id": STICK_ANIMATION_PROFILE_ID,
		"model_id": HUMANOID_MODEL_ID,
		"upright": true,
		"action": str(pose["action"]),
		"phase": snappedf(float(pose["phase"]), 0.001),
		"joints": joints,
	}


static func humanoid_role_contract(role: String, team: String = "blue") -> Dictionary:
	var equipment_ids := {
		"swordsman": "crest_buckler_sword", "healer": "hood_cross_staff_satchel",
		"archer": "hood_longbow_quiver", "roller": "headband_boulder_harness",
		"mage": "wide_hat_orb_staff_robe", "heavy": "plate_tower_shield_hammer",
		"priest": "halo_mantle_crozier", "musketeer": "tricorn_bandolier_musket",
		"rifleman": "helmet_vest_magazine_rifle", "warrior": "hero_crest_kite_shield_broadsword",
		"enemy_grunt": "ragged_helmet_spear_chipped_buckler",
		"enemy_archer": "jagged_hood_shortbow_quiver",
		"enemy_thrower": "goggles_sling_bomb_pouch",
		"enemy_berserker": "horns_dual_axes_scarf",
		"enemy_heavy": "spiked_plate_slab_shield_mace",
		"enemy_shaman": "antler_mask_forked_staff_fringe",
		"enemy_chief": "horned_crown_command_cape_giant_axe",
		"enemy_musketeer": "raider_hat_bandolier_musket",
		"enemy_rifleman": "raider_helmet_vest_magazine_rifle",
	}
	return {
		"model_id": HUMANOID_MODEL_ID,
		"role": role,
		"equipment_id": str(equipment_ids.get(role, "unarmed_stick_rig")),
		"team_marker": "red_diamond" if team == "red" else "blue_roundel",
		"upright": true,
	}


static func soldier_visual_extent(type_id: String, base_radius: float, visual_scale: float = 1.0) -> float:
	if type_id not in HUMANOID_SOLDIER_TYPES:
		return maxf(1.0, base_radius * visual_scale)
	var model_height := 30.0
	match type_id:
		"mage": model_height = 36.0
		"archer", "priest": model_height = 34.0
		"swordsman": model_height = 33.0
		"heavy", "musketeer", "rifleman": model_height = 32.0
	return model_height * maxf(0.01, visual_scale) * HUMANOID_BASE_DISPLAY_SCALE * clampf(base_radius / 11.0, 0.88, 1.45)


static func enemy_visual_extent(type_id: String, base_radius: float, visual_scale: float = 1.0) -> float:
	if type_id not in HUMANOID_ENEMY_TYPES:
		return maxf(1.0, base_radius * visual_scale)
	var role_scale := clampf(base_radius / 11.0, 0.92, 1.72)
	var model_height := 30.0
	match type_id:
		"shaman", "chief": model_height = 35.0
		"berserker", "heavy": model_height = 34.0
		"archer": model_height = 33.0
		"musketeer", "rifleman": model_height = 32.0
	return model_height * maxf(0.01, visual_scale) * HUMANOID_BASE_DISPLAY_SCALE * role_scale


static func hero_visual_extent(visual_scale: float = 1.0) -> float:
	# Mage is the tallest hero because of the wide pointed hat. Using the tallest
	# legal silhouette keeps the shared Arena health bar clear for every class.
	return 36.0 * maxf(0.01, visual_scale) * 1.52


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
	elif type_id in HUMANOID_SOLDIER_TYPES:
		var facing := _unit_facing(soldier, team)
		var humanoid_scale := scale * HUMANOID_BASE_DISPLAY_SCALE * clampf(base_radius / 11.0, 0.88, 1.45)
		_draw_humanoid_character(canvas, soldier, position, facing, type_id, color, primary, dark, time_seconds, humanoid_scale, false)
	else:
		var points := [Vector2(-base_radius, 4), Vector2(-base_radius * 0.7, -base_radius * 0.75), Vector2(0, -base_radius), Vector2(base_radius * 0.8, -base_radius * 0.55), Vector2(base_radius, 5), Vector2(0, base_radius)]
		_draw_polygon_shape(canvas, position, points, 0.0, color, dark, 2.0 * scale, scale)
		match type_id:
			"roller":
				canvas.draw_circle(position + Vector2(11, -2) * scale, 7.0 * scale, Color("778493"))
				canvas.draw_line(position + Vector2(8, -5) * scale, position + Vector2(14, 1) * scale, Color("BFD0DA"), 1.0 * scale)
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
	var dark := _team_dark(team)
	var primary := _team_primary(team)
	var main_color := FLASH_COLOR if float(hero.get("flash", 0.0)) > 0.0 else Color(GameConfig.HERO_CLASSES[class_id]["color"])
	if draw_shadow:
		_draw_ellipse_shadow(canvas, ground_screen_position + Vector2(5, 9) * scale, Vector2(17, 7) * scale)
	_draw_humanoid_character(canvas, hero, ground_screen_position, facing, class_id, main_color, primary, dark, _time_seconds, scale * 1.52, true)
	return true


static func draw_enemy_humanoid(
	canvas: CanvasItem,
	enemy: Dictionary,
	ground_screen_position: Vector2,
	time_seconds: float,
	visual_scale: float = 1.0,
	draw_shadow: bool = true
) -> bool:
	if canvas == null:
		return false
	var type_id := str(enemy.get("type", ""))
	if type_id not in HUMANOID_ENEMY_TYPES or not GameConfig.ENEMIES.has(type_id):
		return false
	var scale := maxf(0.01, visual_scale)
	var base_radius := maxf(1.0, float(enemy.get("radius", 11.0)))
	var role_scale := clampf(base_radius / 11.0, 0.92, 1.72)
	var model_scale := scale * HUMANOID_BASE_DISPLAY_SCALE * role_scale
	var facing := _unit_facing(enemy, "red")
	var body_color := FLASH_COLOR if float(enemy.get("flash", 0.0)) > 0.0 else Color(GameConfig.ENEMIES[type_id]["color"])
	if draw_shadow:
		_draw_ellipse_shadow(
			canvas,
			ground_screen_position + Vector2(4.0, 4.0) * scale,
			Vector2(maxf(base_radius, 11.0) * 1.18, maxf(base_radius * 0.48, 5.0)) * scale
		)
	_draw_humanoid_character(
		canvas, enemy, ground_screen_position, facing, "enemy_%s" % type_id,
		body_color, RED, RED_DARK, time_seconds, model_scale, false
	)
	return true


static func _draw_humanoid_character(
	canvas: CanvasItem,
	unit: Dictionary,
	center: Vector2,
	facing: Vector2,
	role: String,
	body_color: Color,
	team_color: Color,
	outline_color: Color,
	time_seconds: float,
	scale: float,
	is_hero: bool
) -> void:
	var pose := _humanoid_pose(unit, center, facing, time_seconds, scale, is_hero)
	var action := str(pose["action"])
	var pelvis: Vector2 = pose["pelvis"]
	var chest: Vector2 = pose["chest"]
	var head: Vector2 = pose["head"]
	var left_shoulder: Vector2 = pose["left_shoulder"]
	var right_shoulder: Vector2 = pose["right_shoulder"]
	var left_elbow: Vector2 = pose["left_elbow"]
	var right_elbow: Vector2 = pose["right_elbow"]
	var left_hand: Vector2 = pose["left_hand"]
	var right_hand: Vector2 = pose["right_hand"]
	var left_knee: Vector2 = pose["left_knee"]
	var right_knee: Vector2 = pose["right_knee"]
	var left_foot: Vector2 = pose["left_foot"]
	var right_foot: Vector2 = pose["right_foot"]
	var line_width := (2.75 if is_hero else 2.25) * scale
	var joint_radius := (1.75 if is_hero else 1.48) * scale
	var phase := float(pose["phase"])
	var detailed := scale >= 0.68
	var hostile_team := team_color.r > team_color.b * 1.08

	# The whole body is screen-upright. Aim only drives hands, eyes and equipment,
	# so aiming north/south can never rotate or overturn the character.
	if action == "dash":
		for trail_index in 3:
			var spread := float(trail_index - 1) * 3.0 * scale
			var trail_start := pelvis - facing * (7.0 + float(trail_index) * 3.0) * scale + Vector2.RIGHT * spread
			var trail_end := trail_start - facing * (9.0 + float(trail_index) * 2.0) * scale
			canvas.draw_line(trail_start, trail_end, Color(team_color, 0.62 - float(trail_index) * 0.13), maxf(1.0, (2.4 - float(trail_index) * 0.45) * scale), true)
	_draw_humanoid_back_accessory(canvas, role, pose, facing, team_color, outline_color, scale, is_hero)
	if is_hero:
		var cape_points := PackedVector2Array([
			left_shoulder + Vector2(-1.0, 1.0) * scale,
			pelvis + Vector2(-5.4, 7.7) * scale,
			pelvis + Vector2(0.0, 10.0) * scale,
			pelvis + Vector2(5.4, 7.7) * scale,
			right_shoulder + Vector2(1.0, 1.0) * scale,
		])
		canvas.draw_colored_polygon(cape_points, Color(outline_color, 0.78))
		canvas.draw_polyline(PackedVector2Array([cape_points[0], cape_points[1], cape_points[2], cape_points[3], cape_points[4]]), Color(team_color, 0.74), 1.15 * scale, true)
	if action == "support":
		var support_color := GOLD if role == "priest" else (MAGIC_PURPLE if role == "mage" else HEAL_GREEN)
		var support_pulse := 0.5 + 0.5 * sin(phase * 1.35)
		if role == "enemy_shaman":
			support_color = Color("9BE564")
		canvas.draw_arc(chest, (8.5 + support_pulse * 2.8) * scale, 0.0, TAU, 18, Color(support_color, 0.34 + support_pulse * 0.28), 1.7 * scale, true)

	_draw_stick_bone(canvas, pelvis, left_knee, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, left_knee, left_foot, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, pelvis, right_knee, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, right_knee, right_foot, body_color, outline_color, line_width)
	_draw_stick_joint(canvas, left_knee, body_color, outline_color, joint_radius)
	_draw_stick_joint(canvas, right_knee, body_color, outline_color, joint_radius)
	_draw_stick_joint(canvas, left_foot, outline_color.lightened(0.10), outline_color, joint_radius * 1.12)
	_draw_stick_joint(canvas, right_foot, outline_color.lightened(0.10), outline_color, joint_radius * 1.12)

	# A broad tapered tabard is still visibly a stick figure, but survives the
	# browser camera's overview zoom much better than a one-pixel torso line.
	var torso_points := PackedVector2Array([
		left_shoulder,
		pelvis + Vector2(-2.9, 0.8) * scale,
		pelvis + Vector2(2.9, 0.8) * scale,
		right_shoulder,
	])
	canvas.draw_colored_polygon(torso_points, body_color)
	var closed_torso := PackedVector2Array(torso_points)
	closed_torso.append(torso_points[0])
	canvas.draw_polyline(closed_torso, outline_color, maxf(1.2, 1.55 * scale), true)
	_draw_humanoid_torso_details(canvas, role, pose, body_color, team_color, outline_color, scale, detailed, hostile_team)
	_draw_stick_bone(canvas, left_shoulder, left_elbow, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, left_elbow, left_hand, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, right_shoulder, right_elbow, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, right_elbow, right_hand, body_color, outline_color, line_width)
	_draw_stick_joint(canvas, left_elbow, body_color, outline_color, joint_radius)
	_draw_stick_joint(canvas, right_elbow, body_color, outline_color, joint_radius)
	_draw_stick_joint(canvas, left_hand, body_color.lightened(0.12), outline_color, joint_radius * 0.92)
	_draw_stick_joint(canvas, right_hand, body_color.lightened(0.12), outline_color, joint_radius * 0.92)

	canvas.draw_line(pelvis + Vector2(-3.0, 0.0) * scale, pelvis + Vector2(3.0, 0.0) * scale, team_color, maxf(1.2, 1.7 * scale), true)
	var head_radius := (4.45 if is_hero else 3.82) * scale
	canvas.draw_circle(head, head_radius + 1.0 * scale, outline_color)
	canvas.draw_circle(head, head_radius, body_color.lightened(0.16))
	var look_offset := facing.limit_length(1.0) * 0.72 * scale
	if detailed:
		var eye_spread := Vector2.RIGHT * 1.25 * scale
		canvas.draw_circle(head + look_offset - eye_spread, maxf(0.62, 0.68 * scale), outline_color)
		canvas.draw_circle(head + look_offset + eye_spread, maxf(0.62, 0.68 * scale), outline_color)
	_draw_humanoid_headgear(canvas, role, head, facing, body_color, team_color, outline_color, scale, is_hero, hostile_team)

	_draw_humanoid_equipment(canvas, role, pose, facing, body_color, team_color, outline_color, time_seconds, scale, is_hero)

	if action == "hurt":
		for spark_side in [-1.0, 1.0]:
			var spark_center := head - facing * 1.5 * scale + Vector2.RIGHT * float(spark_side) * 5.8 * scale
			canvas.draw_line(spark_center - facing * 2.0 * scale, spark_center + facing * 2.0 * scale, Color("FFF2B6"), 1.2 * scale, true)
			canvas.draw_line(spark_center - Vector2.RIGHT * 1.8 * scale, spark_center + Vector2.RIGHT * 1.8 * scale, Color("FFF2B6"), 1.2 * scale, true)


static func _humanoid_pose(unit: Dictionary, center: Vector2, facing: Vector2, time_seconds: float, scale: float, is_hero: bool) -> Dictionary:
	var aim := facing.normalized()
	if aim.length_squared() < 0.001:
		aim = Vector2.RIGHT
	var aim_side := Vector2(-aim.y, aim.x)
	var entity_id := int(unit.get("id", 0))
	var seed := float(abs(entity_id % 997)) * 0.071
	var velocity := Vector2(unit.get("vel", Vector2.ZERO))
	var speed_phase := clampf(velocity.length() / 70.0, 0.0, 4.0)
	var phase := time_seconds * (5.5 + speed_phase) + seed
	var state := str(unit.get("state", "idle")).to_lower()
	var forced_action := str(unit.get("animation_action", "")).to_lower()
	var forced_action_ttl := maxf(0.0, float(unit.get("animation_action_ttl", 0.0)))
	var flash := maxf(0.0, float(unit.get("flash", 0.0)))
	var dash_time := maxf(float(unit.get("dash_timer", 0.0)), float(unit.get("dash_reduction_ttl", 0.0)))
	var hero_attack_time := maxf(float(unit.get("attack_cd", 0.0)), float(unit.get("cooldown", 0.0))) if is_hero else 0.0
	var action := "idle"
	if flash > 0.0:
		action = "hurt"
	elif dash_time > 0.0 or state.contains("dash"):
		action = "dash"
	elif forced_action_ttl > 0.0 and forced_action in ["attack", "support", "walk"]:
		action = forced_action
	elif state in HUMANOID_SUPPORT_STATES:
		action = "support"
	elif state in HUMANOID_ATTACK_STATES or hero_attack_time > 0.0:
		action = "attack"
	elif velocity.length_squared() > 9.0 or state in ["move", "approach", "retreat", "heal_move", "revive_move", "patrol", "chase", "return", "keep_range"]:
		action = "walk"

	var stride := 0.0
	var arm_swing := 0.0
	var lean_strength := 0.0
	var lateral_sway := 0.0
	var bob := 0.0
	var strike := 0.5 + 0.5 * sin(phase * 1.42)
	match action:
		"walk":
			stride = sin(phase) * 3.15
			arm_swing = -sin(phase) * 2.1
			lateral_sway = cos(phase) * 0.48
			bob = absf(sin(phase)) * 0.82
		"attack":
			lean_strength = 1.1 + strike * 1.4
			lateral_sway = (strike - 0.5) * 1.3
			bob = sin(phase * 1.42) * 0.28
		"support":
			lean_strength = 0.35
			bob = 0.45 + sin(phase * 1.35) * 0.55
		"hurt":
			lean_strength = -2.2
			lateral_sway = 1.8 if entity_id % 2 == 0 else -1.8
			stride = 1.4
		"dash":
			lean_strength = 3.4
			stride = sin(phase * 1.3) * 1.4
			bob = 0.6
		_:
			bob = sin(time_seconds * 2.15 + seed) * 0.34

	# `center` is the ground point. These vertical screen-space offsets never use
	# aim rotation; a north-facing attack therefore remains an upright person.
	var lean_offset := Vector2(aim.x * lean_strength, aim.y * lean_strength * 0.24) * scale
	var pelvis := center + Vector2(lateral_sway * 0.35, -8.0 - bob) * scale + lean_offset * 0.30
	var chest := pelvis + Vector2(lateral_sway * 0.38, -7.35) * scale + lean_offset * 0.54
	var breath := sin(time_seconds * 2.15 + seed) * 0.22
	var head := chest + Vector2(aim.x * 0.45, -7.15 - breath) * scale
	var left_shoulder := chest + Vector2(-4.15, -0.15) * scale
	var right_shoulder := chest + Vector2(4.15, -0.15) * scale

	var walk_wave := sin(phase)
	var left_foot := center + Vector2(-3.6 + stride * 0.54, -maxf(0.0, walk_wave) * 1.75) * scale
	var right_foot := center + Vector2(3.6 - stride * 0.54, -maxf(0.0, -walk_wave) * 1.75) * scale
	if action == "dash":
		var dash_sign := 1.0 if aim.x >= 0.0 else -1.0
		left_foot = center + Vector2(-4.8 * dash_sign, -1.2) * scale
		right_foot = center + Vector2(5.8 * dash_sign, 0.0) * scale
	elif action == "hurt":
		left_foot = center + Vector2(-5.3, -0.6) * scale
		right_foot = center + Vector2(4.5, 0.0) * scale
	var left_knee := pelvis.lerp(left_foot, 0.53) + Vector2(-1.15, 0.25) * scale
	var right_knee := pelvis.lerp(right_foot, 0.53) + Vector2(1.15, 0.25) * scale

	var left_hand := left_shoulder + Vector2(-1.45, 5.0 + arm_swing) * scale
	var right_hand := right_shoulder + Vector2(1.45, 5.0 - arm_swing) * scale
	if action == "attack":
		left_hand = chest + aim * (3.2 + strike * 1.4) * scale - aim_side * (2.6 - strike * 0.8) * scale
		right_hand = chest + aim * (5.2 + strike * 3.2) * scale + aim_side * (2.8 - strike * 1.4) * scale
	elif action == "support":
		left_hand = chest + Vector2(-5.0, -4.2 - sin(phase * 1.35) * 0.8) * scale
		right_hand = chest + Vector2(5.0, -4.2 - cos(phase * 1.35) * 0.8) * scale
	elif action == "hurt":
		left_hand = chest + Vector2(-6.8, 0.8) * scale
		right_hand = chest + Vector2(6.4, 2.2) * scale
	elif action == "dash":
		left_hand = chest - aim * 3.3 * scale + Vector2(-3.2, 1.0) * scale
		right_hand = chest + aim * 6.5 * scale + Vector2(2.2, -0.5) * scale
	var left_elbow := left_shoulder.lerp(left_hand, 0.5) + Vector2(-1.15, 0.5) * scale
	var right_elbow := right_shoulder.lerp(right_hand, 0.5) + Vector2(1.15, 0.5) * scale
	var swing_angle := lerpf(-0.72, 0.66, strike)
	var weapon_dir := aim.rotated(swing_angle if action == "attack" else -0.16)

	return {
		"action": action, "phase": phase, "strike": strike,
		"pelvis": pelvis, "chest": chest, "head": head,
		"left_shoulder": left_shoulder, "right_shoulder": right_shoulder,
		"left_elbow": left_elbow, "right_elbow": right_elbow,
		"left_hand": left_hand, "right_hand": right_hand,
		"left_knee": left_knee, "right_knee": right_knee,
		"left_foot": left_foot, "right_foot": right_foot,
		"weapon_dir": weapon_dir, "aim": aim,
	}


static func _draw_humanoid_back_accessory(
	canvas: CanvasItem,
	role: String,
	pose: Dictionary,
	facing: Vector2,
	team_color: Color,
	outline_color: Color,
	scale: float,
	_is_hero: bool
) -> void:
	var chest: Vector2 = pose["chest"]
	var pelvis: Vector2 = pose["pelvis"]
	var head: Vector2 = pose["head"]
	var look_sign := -1.0 if facing.x < -0.08 else 1.0
	match role:
		"archer", "enemy_archer":
			var quiver := chest + Vector2(-5.4 * look_sign, 2.8) * scale
			canvas.draw_line(quiver + Vector2(0.0, 4.8) * scale, quiver + Vector2(1.5 * look_sign, -6.8) * scale, outline_color, 4.2 * scale, true)
			canvas.draw_line(quiver + Vector2(0.0, 4.2) * scale, quiver + Vector2(1.5 * look_sign, -6.5) * scale, Color("A66C35"), 2.4 * scale, true)
			for arrow_index in 3:
				var arrow_x := float(arrow_index - 1) * 1.5
				var arrow_top := quiver + Vector2(arrow_x, -8.0 - float(arrow_index % 2)) * scale
				canvas.draw_line(quiver + Vector2(arrow_x * 0.35, -1.0) * scale, arrow_top, Color("E9EEF0"), maxf(0.75, 0.85 * scale), true)
				_draw_polygon_shape(canvas, arrow_top, [Vector2(-1.6, 1.5), Vector2(0.0, -2.2), Vector2(1.6, 1.5)], 0.0, team_color, outline_color, 0.45 * scale, scale)
		"healer":
			var satchel := pelvis + Vector2(-5.0 * look_sign, 0.4) * scale
			canvas.draw_line(chest + Vector2(3.4 * look_sign, -1.5) * scale, satchel, Color("8C6844"), 1.7 * scale, true)
			_draw_polygon_shape(canvas, satchel, [Vector2(-3.2, -2.3), Vector2(3.2, -2.3), Vector2(3.6, 2.8), Vector2(-3.6, 2.8)], 0.0, Color("E8F7ED"), outline_color, 0.8 * scale, scale)
		"roller":
			var basket := pelvis + Vector2(-5.2 * look_sign, -1.0) * scale
			canvas.draw_circle(basket, 5.2 * scale, outline_color)
			canvas.draw_circle(basket, 4.0 * scale, Color("6F7B80"))
			canvas.draw_line(chest + Vector2(-3.0 * look_sign, -1.0) * scale, basket, Color("B98A50"), 2.0 * scale, true)
		"mage", "priest", "enemy_shaman":
			var robe_color := MAGIC_PURPLE.darkened(0.20) if role == "mage" else (GOLD.darkened(0.36) if role == "priest" else Color("55733F"))
			var tails := PackedVector2Array([
				chest + Vector2(-3.7, 2.0) * scale,
				pelvis + Vector2(-4.7, 7.4) * scale,
				pelvis + Vector2(0.0, 5.0) * scale,
				pelvis + Vector2(4.7, 7.4) * scale,
				chest + Vector2(3.7, 2.0) * scale,
			])
			canvas.draw_colored_polygon(tails, Color(robe_color, 0.88))
			canvas.draw_polyline(tails, outline_color, maxf(0.9, 1.0 * scale), true)
		"musketeer", "enemy_musketeer":
			canvas.draw_line(chest + Vector2(-4.0, -2.5) * scale, pelvis + Vector2(4.0, 2.2) * scale, Color("C89B54"), 2.0 * scale, true)
			for cartridge in 3:
				canvas.draw_circle(chest + Vector2(-2.4 + float(cartridge) * 2.3, -0.2 + float(cartridge) * 1.6) * scale, 1.05 * scale, Color("E7C779"))
		"rifleman", "enemy_rifleman":
			var pack := chest + Vector2(-5.2 * look_sign, 2.0) * scale
			_draw_polygon_shape(canvas, pack, [Vector2(-3.2, -4.0), Vector2(3.2, -4.0), Vector2(4.0, 4.2), Vector2(-4.0, 4.2)], 0.0, Color("43584D"), outline_color, 0.9 * scale, scale)
		"enemy_thrower":
			var pouch := pelvis + Vector2(-5.6 * look_sign, -0.2) * scale
			canvas.draw_circle(pouch, 4.2 * scale, outline_color)
			canvas.draw_circle(pouch, 3.1 * scale, Color("8D5D38"))
			canvas.draw_line(chest + Vector2(3.0 * look_sign, -1.0) * scale, pouch, Color("C28B53"), 1.8 * scale, true)
		"enemy_berserker":
			var scarf_start := head + Vector2(-2.0 * look_sign, 2.0) * scale
			canvas.draw_line(scarf_start, scarf_start + Vector2(-8.5 * look_sign, 5.2) * scale, Color("E4493F"), 3.0 * scale, true)
			canvas.draw_line(scarf_start, scarf_start + Vector2(-6.5 * look_sign, 8.0) * scale, Color("A9272D"), 2.1 * scale, true)
		"enemy_chief":
			var command_cape := PackedVector2Array([
				chest + Vector2(-4.8, -1.0) * scale,
				pelvis + Vector2(-7.0, 9.0) * scale,
				pelvis + Vector2(0.0, 6.5) * scale,
				pelvis + Vector2(7.0, 9.0) * scale,
				chest + Vector2(4.8, -1.0) * scale,
			])
			canvas.draw_colored_polygon(command_cape, Color("7B1F2D"))
			canvas.draw_polyline(command_cape, GOLD.darkened(0.15), 1.6 * scale, true)


static func _draw_humanoid_torso_details(
	canvas: CanvasItem,
	role: String,
	pose: Dictionary,
	body_color: Color,
	team_color: Color,
	outline_color: Color,
	scale: float,
	detailed: bool,
	hostile_team: bool
) -> void:
	var chest: Vector2 = pose["chest"]
	var pelvis: Vector2 = pose["pelvis"]
	var badge := chest.lerp(pelvis, 0.42)
	if role in ["heavy", "warrior", "enemy_heavy", "enemy_chief"]:
		for shoulder_x in [-1.0, 1.0]:
			var shoulder_center := chest + Vector2(shoulder_x * 4.2, -0.1) * scale
			canvas.draw_circle(shoulder_center, (3.1 if role in ["warrior", "enemy_chief"] else 2.7) * scale, outline_color)
			canvas.draw_circle(shoulder_center, (2.2 if role in ["warrior", "enemy_chief"] else 1.9) * scale, Color("BBC7CC") if not role.begins_with("enemy_") else Color("766E64"))
		var plate := PackedVector2Array([
			chest + Vector2(-3.5, 0.2) * scale,
			chest + Vector2(0.0, 4.4) * scale,
			chest + Vector2(3.5, 0.2) * scale,
			chest + Vector2(0.0, -2.6) * scale,
		])
		canvas.draw_colored_polygon(plate, Color("AEBBC1") if not role.begins_with("enemy_") else Color("665F58"))
		canvas.draw_polyline(PackedVector2Array([plate[0], plate[1], plate[2], plate[3], plate[0]]), outline_color, 1.0 * scale, true)
	elif role in ["mage", "priest", "healer", "enemy_shaman"]:
		canvas.draw_line(chest + Vector2(-3.3, 1.2) * scale, pelvis + Vector2(0.0, 2.0) * scale, body_color.lightened(0.28), 1.4 * scale, true)
		canvas.draw_line(chest + Vector2(3.3, 1.2) * scale, pelvis + Vector2(0.0, 2.0) * scale, body_color.lightened(0.28), 1.4 * scale, true)
	elif role in ["musketeer", "rifleman", "enemy_musketeer", "enemy_rifleman"]:
		canvas.draw_line(chest + Vector2(-3.3, -2.2) * scale, pelvis + Vector2(3.0, 1.0) * scale, Color("D4B36B"), 1.8 * scale, true)
	elif role == "enemy_berserker":
		canvas.draw_line(chest + Vector2(-4.0, 1.0) * scale, chest + Vector2(4.0, 1.0) * scale, Color("EF4B42"), 2.6 * scale, true)

	if detailed:
		match role:
			"healer":
				canvas.draw_line(badge + Vector2(-2.2, 0.0) * scale, badge + Vector2(2.2, 0.0) * scale, HEAL_GREEN, 1.5 * scale, true)
				canvas.draw_line(badge + Vector2(0.0, -2.2) * scale, badge + Vector2(0.0, 2.2) * scale, HEAL_GREEN, 1.5 * scale, true)
			"mage":
				_draw_polygon_shape(canvas, badge, [Vector2(0, -2.8), Vector2(2.5, 0), Vector2(0, 2.8), Vector2(-2.5, 0)], 0.0, MAGIC_PURPLE, FLASH_COLOR, 0.5 * scale, scale)
			"priest":
				canvas.draw_circle(badge, 2.2 * scale, Color(GOLD, 0.38))
				canvas.draw_line(badge + Vector2(0.0, -2.4) * scale, badge + Vector2(0.0, 2.4) * scale, GOLD, 1.2 * scale, true)
			"roller", "enemy_thrower":
				canvas.draw_arc(badge, 2.4 * scale, 0.0, TAU, 10, Color("D6C18A"), 1.2 * scale, true)
			"enemy_shaman":
				canvas.draw_circle(badge, 2.0 * scale, Color("9BE564"))

	# Enemy clothing can inherit colors shared with friendly classes, so every
	# hostile humanoid also wears a large red sash and a ragged waist pennant.
	# The marker stays attached to the upright torso while only the weapon aims.
	if hostile_team:
		var sash_start := chest + Vector2(-3.8, -2.1) * scale
		var sash_end := pelvis + Vector2(3.4, 1.8) * scale
		canvas.draw_line(sash_start, sash_end, outline_color, 3.8 * scale, true)
		canvas.draw_line(sash_start, sash_end, team_color, 2.3 * scale, true)
		var rag_position := pelvis + Vector2(3.8, 1.8) * scale
		_draw_polygon_shape(
			canvas,
			rag_position,
			[Vector2(-1.0, -1.5), Vector2(5.0, 0.0), Vector2(2.8, 2.0), Vector2(5.6, 4.2), Vector2(-1.0, 3.0)],
			0.0,
			team_color,
			outline_color,
			0.7 * scale,
			scale
		)

	# A circle for the blue faction and a diamond for the red faction remain
	# distinguishable even when the player cannot rely on color alone.
	var marker := chest.lerp(pelvis, 0.72)
	if hostile_team:
		_draw_polygon_shape(canvas, marker, [Vector2(0, -2.5), Vector2(2.5, 0), Vector2(0, 2.5), Vector2(-2.5, 0)], 0.0, team_color, Color("FFE3D8"), 0.55 * scale, scale)
	else:
		canvas.draw_circle(marker, 2.35 * scale, outline_color)
		canvas.draw_circle(marker, 1.65 * scale, team_color)


static func _draw_humanoid_headgear(
	canvas: CanvasItem,
	role: String,
	head: Vector2,
	facing: Vector2,
	body_color: Color,
	team_color: Color,
	outline_color: Color,
	scale: float,
	is_hero: bool,
	_hostile_team: bool
) -> void:
	var look_sign := -1.0 if facing.x < -0.08 else 1.0
	match role:
		"swordsman", "warrior":
			canvas.draw_arc(head + Vector2(0.0, 0.5) * scale, (4.2 if is_hero else 3.8) * scale, PI, TAU, 14, Color("BFD2DA"), 2.2 * scale, true)
			canvas.draw_line(head + Vector2(0.0, -4.0) * scale, head + Vector2(0.0, -7.5 if is_hero else -6.6) * scale, team_color, 2.2 * scale, true)
			canvas.draw_line(head + Vector2(0.0, -7.0) * scale, head + Vector2(3.6 * look_sign, -5.7) * scale, GOLD, 1.7 * scale, true)
		"healer":
			canvas.draw_arc(head, 4.4 * scale, PI * 0.82, TAU + PI * 0.18, 14, Color("E7FFF4"), 2.3 * scale, true)
			var hood_mark := head + Vector2(0.0, -4.8) * scale
			canvas.draw_line(hood_mark + Vector2(-1.7, 0.0) * scale, hood_mark + Vector2(1.7, 0.0) * scale, HEAL_GREEN, 1.1 * scale, true)
			canvas.draw_line(hood_mark + Vector2(0.0, -1.7) * scale, hood_mark + Vector2(0.0, 1.7) * scale, HEAL_GREEN, 1.1 * scale, true)
		"archer":
			_draw_polygon_shape(canvas, head + Vector2(0.0, -1.0) * scale, [Vector2(-4.7, 1.8), Vector2(0, -5.2), Vector2(4.7, 1.8), Vector2(3.1, 4.0), Vector2(-3.1, 4.0)], 0.0, Color("4E7658") if not is_hero else Color("397A66"), outline_color, 1.0 * scale, scale)
			canvas.draw_line(head + Vector2(-1.0 * look_sign, -5.7) * scale, head + Vector2(4.5 * look_sign, -8.6) * scale, Color("E8D17B"), 1.3 * scale, true)
		"roller":
			canvas.draw_line(head + Vector2(-4.1, -1.0) * scale, head + Vector2(4.1, -1.0) * scale, Color("E1B54E"), 2.3 * scale, true)
			canvas.draw_line(head + Vector2(-3.3 * look_sign, -0.6) * scale, head + Vector2(-6.5 * look_sign, 2.6) * scale, Color("E1B54E"), 1.5 * scale, true)
		"mage":
			canvas.draw_line(head + Vector2(-5.8, -2.0) * scale, head + Vector2(5.8, -2.0) * scale, outline_color, 2.8 * scale, true)
			_draw_polygon_shape(canvas, head + Vector2(0.0, -5.2) * scale, [Vector2(-4.5, 3.4), Vector2(0.6, -7.0), Vector2(5.0, 3.4)], 0.0, Color("7055A6"), outline_color, 1.0 * scale, scale)
		"heavy":
			canvas.draw_arc(head + Vector2(0.0, 0.6) * scale, 4.4 * scale, PI, TAU, 14, Color("B7C0C5"), 3.0 * scale, true)
			canvas.draw_line(head + Vector2(-4.0, -0.2) * scale, head + Vector2(4.0, -0.2) * scale, outline_color, 2.0 * scale, true)
			for visor_x in [-2.0, 0.0, 2.0]:
				canvas.draw_line(head + Vector2(visor_x, -1.0) * scale, head + Vector2(visor_x, 1.4) * scale, outline_color, 0.8 * scale, true)
		"priest":
			canvas.draw_arc(head + Vector2(0.0, -5.8) * scale, 4.4 * scale, 0.0, TAU, 18, Color(GOLD, 0.90), 1.25 * scale, true)
			_draw_polygon_shape(canvas, head + Vector2(0.0, -2.7) * scale, [Vector2(-3.7, 2.5), Vector2(0, -4.8), Vector2(3.7, 2.5), Vector2(2.8, 4.0), Vector2(-2.8, 4.0)], 0.0, Color("E9E2F5"), outline_color, 0.9 * scale, scale)
		"musketeer", "enemy_musketeer":
			var hat_color := Color("76513A") if role == "musketeer" else Color("4D3028")
			canvas.draw_line(head + Vector2(-6.0, -2.0) * scale, head + Vector2(6.0, -2.0) * scale, outline_color, 3.0 * scale, true)
			_draw_polygon_shape(canvas, head + Vector2(0.0, -4.0) * scale, [Vector2(-4.5, 2.2), Vector2(-2.0, -2.8), Vector2(0, -0.5), Vector2(2.0, -2.8), Vector2(4.5, 2.2)], 0.0, hat_color, outline_color, 1.0 * scale, scale)
			canvas.draw_line(head + Vector2(-4.5, -1.4) * scale, head + Vector2(4.5, -1.4) * scale, team_color, 1.2 * scale, true)
		"rifleman", "enemy_rifleman":
			var helmet_color := Color("617E69") if role == "rifleman" else Color("4E5147")
			canvas.draw_arc(head + Vector2(0.0, 0.4) * scale, 4.3 * scale, PI, TAU, 14, helmet_color, 3.2 * scale, true)
			canvas.draw_line(head + Vector2(-4.8, -0.1) * scale, head + Vector2(4.8, -0.1) * scale, outline_color, 1.6 * scale, true)
			canvas.draw_rect(Rect2(head + Vector2(-3.3, -1.0) * scale, Vector2(6.6, 2.1) * scale), Color("253038"), true)
		"enemy_grunt":
			_draw_polygon_shape(canvas, head + Vector2(0.0, -2.2) * scale, [Vector2(-4.2, 2.6), Vector2(-2.5, -2.5), Vector2(0, -4.0), Vector2(3.7, -1.4), Vector2(4.2, 2.6)], 0.0, Color("646D6C"), outline_color, 1.0 * scale, scale)
			canvas.draw_line(head + Vector2(0.0, -4.8) * scale, head + Vector2(1.5 * look_sign, 1.5) * scale, Color("B9C1BD"), 1.2 * scale, true)
		"enemy_archer":
			_draw_polygon_shape(canvas, head + Vector2(0.0, -1.0) * scale, [Vector2(-4.8, 2.0), Vector2(-1.5, -5.0), Vector2(4.0, -2.5), Vector2(4.5, 3.3), Vector2(-3.0, 4.0)], 0.0, Color("3E4557"), outline_color, 1.0 * scale, scale)
			canvas.draw_line(head + Vector2(-1.0 * look_sign, -5.2) * scale, head + Vector2(5.0 * look_sign, -7.0) * scale, Color("C4473F"), 1.6 * scale, true)
		"enemy_thrower":
			canvas.draw_arc(head, 4.2 * scale, PI, TAU, 14, Color("80573A"), 2.6 * scale, true)
			canvas.draw_line(head + Vector2(-4.4, -1.5) * scale, head + Vector2(4.4, -1.5) * scale, Color("D5964E"), 1.6 * scale, true)
			for lens_x in [-1.8, 1.8]:
				canvas.draw_circle(head + Vector2(lens_x, -1.2) * scale, 1.25 * scale, outline_color)
				canvas.draw_circle(head + Vector2(lens_x, -1.2) * scale, 0.65 * scale, Color("F4B35B"))
		"enemy_berserker":
			canvas.draw_line(head + Vector2(-4.2, -2.0) * scale, head + Vector2(4.2, -2.0) * scale, Color("B52E32"), 2.5 * scale, true)
			_draw_polygon_shape(canvas, head + Vector2(-4.4, -4.0) * scale, [Vector2(-3, 1.5), Vector2(0, -4.0), Vector2(2.4, 2.0)], -0.25, Color("E1D0A1"), outline_color, 0.8 * scale, scale)
			_draw_polygon_shape(canvas, head + Vector2(4.4, -4.0) * scale, [Vector2(-2.4, 2.0), Vector2(0, -4.0), Vector2(3, 1.5)], 0.25, Color("E1D0A1"), outline_color, 0.8 * scale, scale)
		"enemy_heavy":
			_draw_polygon_shape(canvas, head + Vector2(0.0, -1.5) * scale, [Vector2(-4.8, 2.8), Vector2(-3.5, -3.2), Vector2(0, -4.6), Vector2(3.5, -3.2), Vector2(4.8, 2.8)], 0.0, Color("6E675E"), outline_color, 1.1 * scale, scale)
			for spike_x in [-3.0, 3.0]:
				_draw_polygon_shape(canvas, head + Vector2(spike_x, -5.0) * scale, [Vector2(-1.5, 1.5), Vector2(0, -3.0), Vector2(1.5, 1.5)], 0.0, Color("B5A88F"), outline_color, 0.5 * scale, scale)
		"enemy_shaman":
			canvas.draw_circle(head + Vector2(0.0, -0.6) * scale, 4.2 * scale, Color("D2C49B"))
			canvas.draw_arc(head + Vector2(0.0, -0.6) * scale, 4.2 * scale, 0.0, TAU, 14, outline_color, 1.3 * scale, true)
			for antler_sign in [-1.0, 1.0]:
				var antler_root := head + Vector2(antler_sign * 3.0, -4.0) * scale
				canvas.draw_line(antler_root, antler_root + Vector2(antler_sign * 3.0, -5.0) * scale, Color("8B653D"), 1.7 * scale, true)
				canvas.draw_line(antler_root + Vector2(antler_sign * 1.5, -2.5) * scale, antler_root + Vector2(antler_sign * 4.3, -2.8) * scale, Color("8B653D"), 1.2 * scale, true)
		"enemy_chief":
			_draw_polygon_shape(canvas, head + Vector2(0.0, -3.5) * scale, [Vector2(-5, 3), Vector2(-4, -3), Vector2(-1.5, 0), Vector2(0, -5), Vector2(1.5, 0), Vector2(4, -3), Vector2(5, 3)], 0.0, Color("D3A743"), outline_color, 1.2 * scale, scale)
			canvas.draw_line(head + Vector2(-5.0, -0.5) * scale, head + Vector2(5.0, -0.5) * scale, Color("7D1E2C"), 2.0 * scale, true)
		_:
			canvas.draw_line(head + Vector2(-3.7, -1.8) * scale, head + Vector2(3.7, -1.8) * scale, team_color, 1.4 * scale, true)


static func _draw_humanoid_equipment(
	canvas: CanvasItem,
	role: String,
	pose: Dictionary,
	facing: Vector2,
	_body_color: Color,
	team_color: Color,
	outline_color: Color,
	time_seconds: float,
	scale: float,
	is_hero: bool
) -> void:
	var aim := facing.normalized()
	if aim.length_squared() < 0.001:
		aim = Vector2.RIGHT
	var side := Vector2(-aim.y, aim.x)
	var action := str(pose["action"])
	var strike := float(pose["strike"])
	var phase := float(pose["phase"])
	var chest: Vector2 = pose["chest"]
	var left_hand: Vector2 = pose["left_hand"]
	var right_hand: Vector2 = pose["right_hand"]
	var weapon_dir: Vector2 = pose["weapon_dir"]
	match role:
		"swordsman", "warrior":
			var blade_length := (17.0 if is_hero else 13.0) * scale
			var blade_end := right_hand + weapon_dir * blade_length
			canvas.draw_line(right_hand - weapon_dir * 2.0 * scale, blade_end, outline_color, (4.8 if is_hero else 4.0) * scale, true)
			canvas.draw_line(right_hand, blade_end, FLASH_COLOR, (2.5 if is_hero else 2.0) * scale, true)
			canvas.draw_line(right_hand - side * 2.6 * scale, right_hand + side * 2.6 * scale, GOLD, 1.5 * scale, true)
			if role == "warrior":
				_draw_humanoid_shield(canvas, left_hand, aim, side, team_color, outline_color, scale * 1.28)
			else:
				_draw_round_shield(canvas, left_hand, team_color, outline_color, scale * 0.88, false)
			if action == "attack":
				canvas.draw_arc(chest + aim * 5.0 * scale, (13.0 if is_hero else 10.0) * scale, aim.angle() - 0.95, aim.angle() + 0.78, 14, Color(FLASH_COLOR, 0.35 + strike * 0.45), 2.0 * scale, true)
		"enemy_grunt":
			var spear_tip := right_hand + aim * 17.0 * scale
			canvas.draw_line(right_hand - aim * 7.5 * scale, spear_tip, outline_color, 3.4 * scale, true)
			canvas.draw_line(right_hand - aim * 6.8 * scale, spear_tip - aim * 2.0 * scale, Color("9A693C"), 1.9 * scale, true)
			_draw_polygon_shape(canvas, spear_tip, [Vector2(-3.0, -2.1), Vector2(4.2, 0), Vector2(-3.0, 2.1)], aim.angle(), Color("C9D0CC"), outline_color, 0.7 * scale, scale)
			_draw_round_shield(canvas, left_hand, Color("7C3C34"), outline_color, scale * 0.92, true)
		"heavy", "enemy_heavy":
			var enemy_heavy := role == "enemy_heavy"
			if enemy_heavy:
				_draw_polygon_shape(canvas, left_hand, [Vector2(-5.5, -7.0), Vector2(5.5, -6.0), Vector2(6.5, 5.0), Vector2(0, 8.0), Vector2(-6.5, 5.0)], 0.0, Color("71685E"), outline_color, 1.4 * scale, scale)
				for spike_x in [-4.0, 0.0, 4.0]:
					_draw_polygon_shape(canvas, left_hand + Vector2(spike_x, -7.0) * scale, [Vector2(-1.4, 1.2), Vector2(0, -2.7), Vector2(1.4, 1.2)], 0.0, Color("C1B79F"), outline_color, 0.4 * scale, scale)
			else:
				_draw_humanoid_shield(canvas, left_hand, aim, side, Color("A7B2BE"), outline_color, scale * 1.32)
			var hammer_end := right_hand + weapon_dir * (11.5 if enemy_heavy else 10.0) * scale
			canvas.draw_line(right_hand - weapon_dir * 4.0 * scale, hammer_end, Color("795130"), 2.8 * scale, true)
			if enemy_heavy:
				canvas.draw_circle(hammer_end, 4.6 * scale, outline_color)
				canvas.draw_circle(hammer_end, 3.5 * scale, Color("887E72"))
				for spike_dir in 4:
					var spike_direction := Vector2.from_angle(float(spike_dir) * PI * 0.5)
					canvas.draw_line(hammer_end + spike_direction * 3.0 * scale, hammer_end + spike_direction * 6.0 * scale, Color("BFC4C1"), 1.3 * scale, true)
			else:
				_draw_polygon_shape(canvas, hammer_end, [Vector2(-3.8, -5.0), Vector2(3.8, -5.0), Vector2(3.8, 5.0), Vector2(-3.8, 5.0)], weapon_dir.angle(), Color("B9C8D0"), outline_color, 1.0 * scale, scale)
			if action == "attack":
				canvas.draw_arc(chest + aim * 3.0 * scale, 11.0 * scale, aim.angle() - 0.9, aim.angle() + 0.72, 12, Color(GOLD, 0.58), 2.2 * scale, true)
		"archer", "enemy_archer":
			var hostile_archer := role == "enemy_archer"
			var bow_center := left_hand + aim * 0.8 * scale
			var bow_radius := (9.2 if is_hero else (6.8 if hostile_archer else 7.5)) * scale
			var bow_start_angle := aim.angle() - 1.18
			var bow_end_angle := aim.angle() + 1.18
			var bow_a := bow_center + Vector2.from_angle(bow_start_angle) * bow_radius
			var bow_b := bow_center + Vector2.from_angle(bow_end_angle) * bow_radius
			canvas.draw_arc(bow_center, bow_radius, bow_start_angle, bow_end_angle, 14, Color("6D462C") if hostile_archer else Color("A96D34"), 2.2 * scale, true)
			canvas.draw_line(bow_a, right_hand, Color("EAF6FF"), maxf(0.7, 0.8 * scale), true)
			canvas.draw_line(right_hand, bow_b, Color("EAF6FF"), maxf(0.7, 0.8 * scale), true)
			var arrow_tip := right_hand + aim * (15.0 if action == "attack" else 11.0) * scale
			canvas.draw_line(right_hand - aim * 3.0 * scale, arrow_tip, Color("D9F4FF"), 1.2 * scale, true)
			_draw_polygon_shape(canvas, arrow_tip, [Vector2(-2.2, -1.5), Vector2(3.0, 0.0), Vector2(-2.2, 1.5)], aim.angle(), Color("FFB1A0") if hostile_archer else FLASH_COLOR, outline_color, 0.5 * scale, scale)
		"roller":
			var boulder_center := right_hand + aim * 5.0 * scale
			canvas.draw_circle(boulder_center, 6.2 * scale, outline_color)
			canvas.draw_circle(boulder_center, 5.0 * scale, Color("7D898E"))
			canvas.draw_line(boulder_center + Vector2(-3.0, -1.5) * scale, boulder_center + Vector2(1.0, 1.0) * scale, Color("BCC5C7"), 1.1 * scale, true)
			canvas.draw_line(left_hand, boulder_center - side * 3.0 * scale, Color("C99955"), 1.7 * scale, true)
			if action == "attack":
				canvas.draw_arc(boulder_center, 8.5 * scale, -phase * 0.2, -phase * 0.2 + 4.8, 14, Color(GOLD, 0.50), 1.5 * scale, true)
		"enemy_thrower":
			var bomb_center := right_hand + aim * 3.5 * scale
			canvas.draw_circle(bomb_center, 5.3 * scale, outline_color)
			canvas.draw_circle(bomb_center, 4.1 * scale, Color("555D5E"))
			canvas.draw_line(bomb_center - aim * 1.0 * scale, bomb_center + aim * 5.0 * scale + side * 1.5 * scale, Color("C79753"), 1.5 * scale, true)
			var fuse_tip := bomb_center + aim * 5.0 * scale + side * 1.5 * scale
			canvas.draw_circle(fuse_tip, (1.4 + 0.5 * sin(phase * 2.0)) * scale, FIRE_ORANGE)
			canvas.draw_line(left_hand - side * 3.3 * scale, left_hand + side * 3.3 * scale, Color("B17B42"), 1.7 * scale, true)
		"enemy_berserker":
			var axe_end_a := right_hand + weapon_dir * 10.5 * scale
			var second_dir := aim.rotated(-0.82 if action == "attack" else 0.28)
			var axe_end_b := left_hand + second_dir * 10.0 * scale
			_draw_humanoid_axe(canvas, right_hand, axe_end_a, weapon_dir, Color("B9C1C1"), outline_color, scale * 1.08)
			_draw_humanoid_axe(canvas, left_hand, axe_end_b, second_dir, Color("C89B8C"), outline_color, scale)
			if action == "attack":
				canvas.draw_arc(chest, 12.0 * scale, aim.angle() - 1.0, aim.angle() + 0.95, 15, Color("FF5D4F", 0.65), 2.2 * scale, true)
		"mage":
			var staff_tip := right_hand + aim * (12.0 if action != "hurt" else 8.0) * scale
			canvas.draw_line(right_hand - aim * 6.0 * scale, staff_tip, outline_color, 3.3 * scale, true)
			canvas.draw_line(right_hand - aim * 5.5 * scale, staff_tip, Color("815632"), 2.0 * scale, true)
			var orb_pulse := 0.55 + 0.45 * sin(time_seconds * 6.0 + phase * 0.17)
			canvas.draw_circle(staff_tip, (4.4 + orb_pulse * 1.3) * scale, Color(MAGIC_PURPLE, 0.22 + orb_pulse * 0.25))
			canvas.draw_arc(staff_tip, (3.1 + orb_pulse * 0.5) * scale, phase * 0.14, phase * 0.14 + 5.0, 14, FLASH_COLOR, 1.2 * scale, true)
			canvas.draw_circle(staff_tip, (2.2 + orb_pulse * 0.55) * scale, MAGIC_PURPLE)
		"healer":
			var healer_tip := right_hand + aim * 10.5 * scale
			canvas.draw_line(right_hand - aim * 5.0 * scale, healer_tip, outline_color, 3.1 * scale, true)
			canvas.draw_line(right_hand - aim * 4.8 * scale, healer_tip, Color("7C5A38"), 1.9 * scale, true)
			canvas.draw_circle(healer_tip, 4.0 * scale, Color(HEAL_GREEN, 0.26))
			canvas.draw_line(healer_tip - side * 2.5 * scale, healer_tip + side * 2.5 * scale, HEAL_GREEN, 1.7 * scale, true)
			canvas.draw_line(healer_tip - aim * 2.5 * scale, healer_tip + aim * 2.5 * scale, HEAL_GREEN, 1.7 * scale, true)
			if action == "support":
				for hand_position in [left_hand, right_hand]:
					canvas.draw_circle(Vector2(hand_position), (1.8 + 0.7 * sin(phase * 1.35)) * scale, Color("D9FFF0"))
		"priest":
			var priest_tip := right_hand + aim * 11.0 * scale
			canvas.draw_line(right_hand - aim * 5.0 * scale, priest_tip, outline_color, 3.1 * scale, true)
			canvas.draw_line(right_hand - aim * 4.8 * scale, priest_tip, Color("8B653D"), 1.9 * scale, true)
			canvas.draw_arc(priest_tip - side * 1.4 * scale, 4.0 * scale, aim.angle() - 0.2, aim.angle() + PI + 0.2, 12, GOLD, 2.0 * scale, true)
			if action == "support":
				canvas.draw_circle(left_hand, (2.1 + strike) * scale, Color(GOLD, 0.48))
		"enemy_shaman":
			var shaman_tip := right_hand + aim * 11.5 * scale
			canvas.draw_line(right_hand - aim * 6.0 * scale, shaman_tip, outline_color, 3.3 * scale, true)
			canvas.draw_line(right_hand - aim * 5.5 * scale, shaman_tip, Color("705037"), 2.0 * scale, true)
			for fork_sign in [-1.0, 1.0]:
				canvas.draw_line(shaman_tip, shaman_tip + aim * 4.0 * scale + side * fork_sign * 3.0 * scale, Color("A7D76B"), 1.7 * scale, true)
			canvas.draw_circle(shaman_tip + aim * 2.0 * scale, (2.4 + 0.5 * sin(phase)) * scale, Color("9BE564", 0.70))
		"enemy_chief":
			var chief_axe_end := right_hand + weapon_dir * 15.0 * scale
			_draw_humanoid_axe(canvas, right_hand, chief_axe_end, weapon_dir, GOLD.lightened(0.12), outline_color, scale * 1.42)
			_draw_humanoid_shield(canvas, left_hand, aim, side, Color("8A2531"), outline_color, scale * 1.35)
			if action == "attack":
				canvas.draw_arc(chest + aim * 3.0 * scale, 15.0 * scale, aim.angle() - 1.05, aim.angle() + 0.85, 16, Color(GOLD, 0.72), 2.8 * scale, true)
		"musketeer", "rifleman", "enemy_musketeer", "enemy_rifleman":
			var rifle_role := role in ["rifleman", "enemy_rifleman"]
			var recoil := (1.7 * strike if action == "attack" else 0.0) * scale
			var stock_start := chest - aim * 6.5 * scale + side * 0.8 * scale
			var barrel_end := chest + aim * ((19.0 if rifle_role else 18.0) * scale - recoil)
			canvas.draw_line(stock_start, barrel_end, outline_color, (4.8 if rifle_role else 4.4) * scale, true)
			canvas.draw_line(stock_start, chest + aim * 6.0 * scale, Color("855A35") if not rifle_role else Color("384247"), (3.0 if not rifle_role else 2.7) * scale, true)
			canvas.draw_line(chest + aim * 4.0 * scale, barrel_end, Color("DCE8EA"), 1.65 * scale, true)
			if rifle_role:
				var magazine_center := chest + aim * 2.0 * scale + side * 3.0 * scale
				_draw_polygon_shape(canvas, magazine_center, [Vector2(-2.2, -1.8), Vector2(2.2, -1.8), Vector2(3.4, 4.0), Vector2(-1.4, 4.4)], aim.angle(), Color("252D31"), outline_color, 0.6 * scale, scale)
			canvas.draw_circle(left_hand, 1.25 * scale, team_color)
			canvas.draw_circle(right_hand, 1.25 * scale, team_color)
			if action == "attack" and strike > 0.68:
				var flash_tip := barrel_end + aim * 2.4 * scale
				_draw_polygon_shape(canvas, flash_tip, [Vector2(-3.8, -2.0), Vector2(4.8, 0.0), Vector2(-3.8, 2.0)], aim.angle(), Color("FFF0A8"), FIRE_ORANGE, 0.7 * scale, scale)


static func _draw_humanoid_axe(canvas: CanvasItem, handle_start: Vector2, axe_end: Vector2, direction: Vector2, fill_color: Color, outline_color: Color, scale: float) -> void:
	canvas.draw_line(handle_start - direction * 3.0 * scale, axe_end, outline_color, 3.4 * scale, true)
	canvas.draw_line(handle_start - direction * 2.7 * scale, axe_end, Color("785035"), 1.9 * scale, true)
	_draw_polygon_shape(canvas, axe_end, [Vector2(-1.5, -5.0), Vector2(4.8, -4.2), Vector2(6.4, 0), Vector2(4.8, 4.2), Vector2(-1.5, 5.0)], direction.angle(), fill_color, outline_color, 1.0 * scale, scale)


static func _draw_round_shield(canvas: CanvasItem, center: Vector2, fill_color: Color, outline_color: Color, scale: float, chipped: bool) -> void:
	if chipped:
		_draw_polygon_shape(canvas, center, [Vector2(-5.2, -3.8), Vector2(-1.0, -5.2), Vector2(4.8, -3.1), Vector2(5.3, 1.8), Vector2(1.6, 5.2), Vector2(-4.7, 3.4)], 0.0, fill_color, outline_color, 1.2 * scale, scale)
	else:
		canvas.draw_circle(center, 5.1 * scale, outline_color)
		canvas.draw_circle(center, 4.0 * scale, fill_color)
	canvas.draw_circle(center, 1.45 * scale, GOLD if not chipped else Color("B9A783"))


static func _draw_humanoid_shield(canvas: CanvasItem, center: Vector2, facing: Vector2, side: Vector2, fill_color: Color, outline_color: Color, scale: float) -> void:
	var points := PackedVector2Array([
		center + facing * 4.5 * scale,
		center + side * 4.0 * scale,
		center - facing * 3.3 * scale + side * 2.8 * scale,
		center - facing * 4.5 * scale,
		center - facing * 3.3 * scale - side * 2.8 * scale,
		center - side * 4.0 * scale,
	])
	canvas.draw_colored_polygon(points, fill_color)
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	canvas.draw_polyline(closed, outline_color, maxf(1.0, 1.2 * scale), true)
	canvas.draw_line(center - side * 2.2 * scale, center + side * 2.2 * scale, FLASH_COLOR, maxf(0.8, 0.9 * scale), true)


static func _draw_stick_bone(canvas: CanvasItem, from: Vector2, to: Vector2, fill_color: Color, outline_color: Color, width: float) -> void:
	canvas.draw_line(from, to, outline_color, width + maxf(1.1, width * 0.72), true)
	canvas.draw_line(from, to, fill_color, width, true)


static func _draw_stick_joint(canvas: CanvasItem, center: Vector2, fill_color: Color, outline_color: Color, radius: float) -> void:
	canvas.draw_circle(center, radius + maxf(0.7, radius * 0.48), outline_color)
	canvas.draw_circle(center, radius, fill_color)


static func draw_wildland_chunk(
	canvas: CanvasItem,
	chunk: Dictionary,
	camera_world_position: Vector2,
	screen_center: Vector2,
	zoom: float,
	viewport_rect: Rect2,
	draw_ground: bool = true
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
	var biome_id := str(biome_data.get("id", "meadow"))
	# Every streamed chunk starts from the same continuous wildland material.
	# Biome identity is layered back as irregular low-alpha soil patches and props
	# below, avoiding any visible rectangular cache boundary.
	var grass_color := Color("557A45")
	if draw_ground:
		canvas.draw_rect(chunk_screen_rect, grass_color)
		# Generated top-down ground material adds fine natural grain; a restrained
		# alpha keeps projectiles, stick figures and warning telegraphs dominant.
		canvas.draw_texture_rect(WILDLAND_GROUND_TEXTURE, chunk_screen_rect, false, Color(1.0, 1.0, 1.0, 0.22))
		_draw_ground_finish(canvas, chunk_coord, chunk_screen_rect, biome_id, zoom)

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
				_draw_ellipse_shadow(canvas, position + Vector2(8, 12) * zoom, Vector2(base_radius * 1.55, base_radius * 0.62) * zoom)
				canvas.draw_rect(Rect2(position + Vector2(-4.5, -3) * zoom, Vector2(9.0, base_radius + 15.0) * zoom), Color("5D3B27"))
				canvas.draw_line(position + Vector2(-1.5, 0) * zoom, position + Vector2(-1.5, base_radius + 9.0) * zoom, Color("A27247"), 2.0 * zoom)
				var crown := position + Vector2(0.0, -base_radius * 0.58) * zoom
				canvas.draw_circle(crown + Vector2(base_radius * 0.28, base_radius * 0.10) * zoom, base_radius * 0.90 * zoom, Color("24472F"))
				canvas.draw_circle(crown + Vector2(-base_radius * 0.42, base_radius * 0.02) * zoom, base_radius * 0.83 * zoom, Color("315F39"))
				canvas.draw_circle(crown + Vector2(0.0, -base_radius * 0.35) * zoom, base_radius * 0.92 * zoom, Color("3E7443"))
				canvas.draw_circle(crown + Vector2(-base_radius * 0.22, -base_radius * 0.58) * zoom, base_radius * 0.43 * zoom, Color("649359"))
				canvas.draw_arc(crown, base_radius * 1.24 * zoom, 0.0, TAU, 24, Color("172D21"), 2.2 * zoom)
			"rock":
				_draw_ellipse_shadow(canvas, position + Vector2(6, 8) * zoom, Vector2(base_radius * 1.16, base_radius * 0.48) * zoom)
				var rock_points := [Vector2(-base_radius, base_radius * 0.35), Vector2(-base_radius * 0.7, -base_radius * 0.5), Vector2(base_radius * 0.15, -base_radius * 0.78), Vector2(base_radius, -base_radius * 0.05), Vector2(base_radius * 0.55, base_radius * 0.62)]
				_draw_polygon_shape(canvas, position, rock_points, 0.0, Color("66727A"), INK, 2.0 * zoom, zoom)
				_draw_polygon_shape(canvas, position + Vector2(-base_radius * 0.10, -base_radius * 0.18) * zoom, [Vector2(-base_radius * 0.55, base_radius * 0.15), Vector2(-base_radius * 0.32, -base_radius * 0.34), Vector2(base_radius * 0.12, -base_radius * 0.45), Vector2(base_radius * 0.48, -base_radius * 0.04), Vector2(base_radius * 0.18, base_radius * 0.22)], 0.0, Color("9AA3A5"), Color.TRANSPARENT, 0.0, zoom)
				canvas.draw_line(position + Vector2(-base_radius * 0.05, -base_radius * 0.62) * zoom, position + Vector2(base_radius * 0.62, -base_radius * 0.08) * zoom, Color("C2C6BE"), 1.2 * zoom)
			_:
				_draw_ellipse_shadow(canvas, position + Vector2(4, 7) * zoom, Vector2(base_radius * 1.18, base_radius * 0.5) * zoom)
				canvas.draw_circle(position + Vector2(base_radius * 0.22, 0.0) * zoom, radius * 0.86, Color("315E38"))
				canvas.draw_circle(position + Vector2(-base_radius * 0.42, -base_radius * 0.18) * zoom, base_radius * 0.72 * zoom, Color("5B8D54"))
				canvas.draw_circle(position + Vector2(base_radius * 0.05, -base_radius * 0.46) * zoom, base_radius * 0.64 * zoom, Color("487B45"))
				canvas.draw_arc(position, radius, 0.0, TAU, 18, INK, 1.7 * zoom)
		result["obstacles_drawn"] = int(result["obstacles_drawn"]) + 1
	return result


static func _draw_ground_finish(canvas: CanvasItem, chunk_coord: Vector2i, rect: Rect2, biome_id: String, zoom: float) -> void:
	var soil := Color("765C39")
	var cool := Color("254B35")
	match biome_id:
		"desert":
			soil = Color("B49155")
			cool = Color("8B783D")
		"swamp":
			soil = Color("3F5138")
			cool = Color("244A43")
		"forest":
			soil = Color("51452F")
			cool = Color("173B29")
		"hills":
			soil = Color("7F744A")
			cool = Color("43583B")
	# Broad translucent patches break the flat chunk fill without exposing the
	# cache grid or adding collision-relevant geometry.
	for patch_index in 12:
		var seed := float(chunk_coord.x * 173 + chunk_coord.y * 311 + patch_index * 97)
		var local_x := fposmod(sin(seed * 0.017) * 43871.0, WorldGenerator.CHUNK_SIZE)
		var local_y := fposmod(cos(seed * 0.023) * 25163.0, WorldGenerator.CHUNK_SIZE)
		var radius := (42.0 + fposmod(absf(sin(seed)) * 113.0, 92.0)) * zoom
		var center := rect.position + Vector2(local_x, local_y) * zoom
		canvas.draw_circle(center, radius, Color(soil if patch_index % 3 == 0 else cool, 0.035 + float(patch_index % 4) * 0.008))
	# Sparse grass strokes provide scale and direction while remaining below the
	# silhouette density of units and combat VFX.
	for fleck_index in 28:
		var seed := float(chunk_coord.x * 419 + chunk_coord.y * 233 + fleck_index * 61)
		var local := Vector2(fposmod(sin(seed * 0.031) * 17117.0, WorldGenerator.CHUNK_SIZE), fposmod(cos(seed * 0.037) * 19319.0, WorldGenerator.CHUNK_SIZE))
		var start := rect.position + local * zoom
		var length := (3.0 + float(fleck_index % 4)) * zoom
		canvas.draw_line(start, start + Vector2(1.2, -length), Color(cool.lightened(0.18), 0.20), maxf(0.8, zoom))


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

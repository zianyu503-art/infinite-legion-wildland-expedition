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
const STICK_ANIMATION_PROFILE_ID := "procedural_stick_motion_v1"

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
	"swordsman", "healer", "archer", "mage", "heavy", "priest",
	"musketeer", "rifleman",
]

const HUMANOID_SUPPORT_STATES: Array[String] = [
	"heal", "support", "revive_cast", "mark",
]

const HUMANOID_ATTACK_STATES: Array[String] = [
	"attack", "charge", "charge_castle", "aim", "siege_attack",
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
		"action": str(pose["action"]),
		"phase": snappedf(float(pose["phase"]), 0.001),
		"joints": joints,
	}


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
		var humanoid_scale := scale * clampf(base_radius / 11.0, 0.82, 1.42)
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
	_draw_humanoid_character(canvas, hero, ground_screen_position, facing, class_id, main_color, primary, dark, _time_seconds, scale * 1.38, true)
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
	var side := Vector2(-facing.y, facing.x)
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
	var line_width := (2.35 if is_hero else 1.85) * scale
	var joint_radius := (1.55 if is_hero else 1.22) * scale
	var phase := float(pose["phase"])

	# Motion reads from the silhouette first: dash trails, a compact hero cape,
	# and support rings all sit behind the articulated body.
	if action == "dash":
		for trail_index in 3:
			var spread := float(trail_index - 1) * 3.2 * scale
			var trail_start := pelvis - facing * (8.0 + float(trail_index) * 3.0) * scale + side * spread
			var trail_end := trail_start - facing * (9.0 + float(trail_index) * 2.0) * scale
			canvas.draw_line(trail_start, trail_end, Color(team_color, 0.62 - float(trail_index) * 0.13), maxf(1.0, (2.4 - float(trail_index) * 0.45) * scale), true)
	if is_hero:
		var cape_points := PackedVector2Array([
			left_shoulder - facing * 1.8 * scale,
			pelvis - facing * 6.5 * scale + side * 4.7 * scale,
			pelvis - facing * 9.0 * scale,
			pelvis - facing * 6.5 * scale - side * 4.7 * scale,
			right_shoulder - facing * 1.8 * scale,
		])
		canvas.draw_colored_polygon(cape_points, Color(outline_color, 0.78))
		canvas.draw_polyline(PackedVector2Array([cape_points[0], cape_points[1], cape_points[2], cape_points[3], cape_points[4]]), Color(team_color, 0.74), 1.15 * scale, true)
	if action == "support":
		var support_color := GOLD if role == "priest" else (MAGIC_PURPLE if role == "mage" else HEAL_GREEN)
		var support_pulse := 0.5 + 0.5 * sin(phase * 1.35)
		canvas.draw_arc(chest, (7.5 + support_pulse * 2.5) * scale, 0.0, TAU, 18, Color(support_color, 0.34 + support_pulse * 0.28), 1.5 * scale, true)

	_draw_stick_bone(canvas, pelvis, left_knee, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, left_knee, left_foot, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, pelvis, right_knee, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, right_knee, right_foot, body_color, outline_color, line_width)
	_draw_stick_joint(canvas, left_knee, body_color, outline_color, joint_radius)
	_draw_stick_joint(canvas, right_knee, body_color, outline_color, joint_radius)

	# A tapered torso keeps the character readable as a stick figure without
	# becoming a featureless line at the browser game's normal zoom level.
	var torso_points := PackedVector2Array([
		left_shoulder,
		pelvis + side * 2.3 * scale,
		pelvis - side * 2.3 * scale,
		right_shoulder,
	])
	canvas.draw_colored_polygon(torso_points, body_color)
	var closed_torso := PackedVector2Array(torso_points)
	closed_torso.append(torso_points[0])
	canvas.draw_polyline(closed_torso, outline_color, maxf(1.0, 1.35 * scale), true)
	_draw_stick_bone(canvas, left_shoulder, left_elbow, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, left_elbow, left_hand, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, right_shoulder, right_elbow, body_color, outline_color, line_width)
	_draw_stick_bone(canvas, right_elbow, right_hand, body_color, outline_color, line_width)
	_draw_stick_joint(canvas, left_elbow, body_color, outline_color, joint_radius)
	_draw_stick_joint(canvas, right_elbow, body_color, outline_color, joint_radius)

	# Team belt and headband remain visible even when class colors overlap.
	canvas.draw_line(pelvis + side * 2.6 * scale, pelvis - side * 2.6 * scale, team_color, maxf(1.0, 1.5 * scale), true)
	var head_radius := (3.25 if is_hero else 2.7) * scale
	canvas.draw_circle(head, head_radius + 1.0 * scale, outline_color)
	canvas.draw_circle(head, head_radius, body_color.lightened(0.12))
	canvas.draw_line(head + side * head_radius * 0.86 - facing * 0.2 * scale, head - side * head_radius * 0.86 - facing * 0.2 * scale, team_color, maxf(1.0, 1.1 * scale), true)
	canvas.draw_circle(head + facing * head_radius * 0.62 - side * head_radius * 0.28, maxf(0.55, 0.62 * scale), FLASH_COLOR)
	canvas.draw_circle(head + facing * head_radius * 0.62 + side * head_radius * 0.28, maxf(0.55, 0.62 * scale), FLASH_COLOR)

	_draw_humanoid_equipment(canvas, role, pose, facing, body_color, team_color, outline_color, time_seconds, scale, is_hero)

	if action == "hurt":
		for spark_side in [-1.0, 1.0]:
			var spark_center := head - facing * 1.5 * scale + side * float(spark_side) * 5.8 * scale
			canvas.draw_line(spark_center - facing * 2.0 * scale, spark_center + facing * 2.0 * scale, Color("FFF2B6"), 1.2 * scale, true)
			canvas.draw_line(spark_center - side * 1.8 * scale, spark_center + side * 1.8 * scale, Color("FFF2B6"), 1.2 * scale, true)


static func _humanoid_pose(unit: Dictionary, center: Vector2, facing: Vector2, time_seconds: float, scale: float, is_hero: bool) -> Dictionary:
	var side := Vector2(-facing.y, facing.x)
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
	elif velocity.length_squared() > 9.0 or state in ["move", "approach", "retreat", "heal_move", "revive_move"]:
		action = "walk"

	var stride := 0.0
	var arm_swing := 0.0
	var lean := 0.0
	var lateral_sway := 0.0
	var bob := 0.0
	var strike := 0.5 + 0.5 * sin(phase * 1.42)
	match action:
		"walk":
			stride = sin(phase) * 2.7
			arm_swing = -stride * 0.82
			lateral_sway = cos(phase) * 0.52
			bob = absf(sin(phase)) * 0.72
		"attack":
			lean = 1.5 + strike * 1.6
			lateral_sway = (strike - 0.5) * 1.3
			bob = sin(phase * 1.42) * 0.28
		"support":
			lean = 0.65
			bob = 0.45 + sin(phase * 1.35) * 0.55
		"hurt":
			lean = -3.2
			lateral_sway = 1.8 if entity_id % 2 == 0 else -1.8
			stride = 1.4
		"dash":
			lean = 4.7
			stride = sin(phase * 1.3) * 1.4
			bob = 0.6
		_:
			bob = sin(time_seconds * 2.15 + seed) * 0.34

	var body_center := center - Vector2(0.0, bob * scale)
	var pelvis := body_center + facing * (-1.8 + lean) * scale + side * lateral_sway * 0.35 * scale
	var chest := body_center + facing * (2.0 + lean) * scale + side * lateral_sway * scale
	var breath := sin(time_seconds * 2.15 + seed) * 0.22
	var head := chest + facing * (5.2 + breath) * scale
	var left_shoulder := chest + side * 3.25 * scale
	var right_shoulder := chest - side * 3.25 * scale

	var left_foot := pelvis + facing * (-5.7 + stride) * scale + side * 3.25 * scale
	var right_foot := pelvis + facing * (-5.7 - stride) * scale - side * 3.25 * scale
	if action == "dash":
		left_foot = pelvis - facing * 8.2 * scale + side * 4.0 * scale
		right_foot = pelvis - facing * 10.5 * scale - side * 2.8 * scale
	elif action == "hurt":
		left_foot = pelvis - facing * 4.2 * scale + side * 5.4 * scale
		right_foot = pelvis - facing * 6.5 * scale - side * 4.5 * scale
	var left_knee := pelvis.lerp(left_foot, 0.53) + side * 0.85 * scale
	var right_knee := pelvis.lerp(right_foot, 0.53) - side * 0.85 * scale

	var left_hand := chest - facing * (2.1 - arm_swing) * scale + side * 5.2 * scale
	var right_hand := chest - facing * (2.1 + arm_swing) * scale - side * 5.2 * scale
	if action == "attack":
		left_hand = chest + facing * (2.6 + strike * 1.4) * scale + side * (3.3 - strike * 1.1) * scale
		right_hand = chest + facing * (4.8 + strike * 3.4) * scale - side * (4.6 - strike * 2.0) * scale
	elif action == "support":
		left_hand = chest + facing * (4.3 + sin(phase * 1.35) * 0.7) * scale + side * 4.6 * scale
		right_hand = chest + facing * (4.3 + cos(phase * 1.35) * 0.7) * scale - side * 4.6 * scale
	elif action == "hurt":
		left_hand = chest - facing * 4.0 * scale + side * 6.3 * scale
		right_hand = chest - facing * 2.2 * scale - side * 6.6 * scale
	elif action == "dash":
		left_hand = chest - facing * 3.3 * scale + side * 3.7 * scale
		right_hand = chest + facing * 6.5 * scale - side * 2.2 * scale
	var left_elbow := left_shoulder.lerp(left_hand, 0.5) + side * 1.0 * scale
	var right_elbow := right_shoulder.lerp(right_hand, 0.5) - side * 1.0 * scale
	var swing_angle := lerpf(-0.72, 0.66, strike)
	var weapon_dir := facing.rotated(swing_angle)

	return {
		"action": action, "phase": phase, "strike": strike,
		"pelvis": pelvis, "chest": chest, "head": head,
		"left_shoulder": left_shoulder, "right_shoulder": right_shoulder,
		"left_elbow": left_elbow, "right_elbow": right_elbow,
		"left_hand": left_hand, "right_hand": right_hand,
		"left_knee": left_knee, "right_knee": right_knee,
		"left_foot": left_foot, "right_foot": right_foot,
		"weapon_dir": weapon_dir,
	}


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
	var side := Vector2(-facing.y, facing.x)
	var action := str(pose["action"])
	var strike := float(pose["strike"])
	var phase := float(pose["phase"])
	var chest: Vector2 = pose["chest"]
	var head: Vector2 = pose["head"]
	var left_hand: Vector2 = pose["left_hand"]
	var right_hand: Vector2 = pose["right_hand"]
	var weapon_dir: Vector2 = pose["weapon_dir"]
	match role:
		"swordsman", "warrior":
			var blade_length := (14.5 if is_hero else 11.5) * scale
			var blade_end := right_hand + weapon_dir * blade_length
			canvas.draw_line(right_hand - weapon_dir * 1.8 * scale, blade_end, outline_color, (4.3 if is_hero else 3.5) * scale, true)
			canvas.draw_line(right_hand, blade_end, FLASH_COLOR, (2.1 if is_hero else 1.7) * scale, true)
			canvas.draw_line(right_hand - side * 2.6 * scale, right_hand + side * 2.6 * scale, GOLD, 1.5 * scale, true)
			if role == "warrior":
				_draw_humanoid_shield(canvas, left_hand, facing, side, team_color, outline_color, scale * 1.08)
			if action == "attack":
				canvas.draw_arc(chest + facing * 5.0 * scale, (11.0 if is_hero else 8.5) * scale, facing.angle() - 0.88, facing.angle() + 0.72, 12, Color(FLASH_COLOR, 0.35 + strike * 0.45), 1.7 * scale, true)
		"heavy":
			_draw_humanoid_shield(canvas, left_hand, facing, side, Color("A7B2BE"), outline_color, scale * 1.18)
			var hammer_end := right_hand + weapon_dir * 9.0 * scale
			canvas.draw_line(right_hand - weapon_dir * 3.0 * scale, hammer_end, Color("795130"), 2.4 * scale, true)
			_draw_polygon_shape(canvas, hammer_end, [Vector2(-3.2, -4.4), Vector2(3.2, -4.4), Vector2(3.2, 4.4), Vector2(-3.2, 4.4)], weapon_dir.angle(), Color("B9C8D0"), outline_color, 1.0 * scale, scale)
			if action == "attack":
				canvas.draw_arc(chest + facing * 3.0 * scale, 9.5 * scale, facing.angle() - 0.8, facing.angle() + 0.6, 11, Color(GOLD, 0.58), 2.0 * scale, true)
		"archer":
			var bow_center := left_hand + facing * 0.8 * scale
			var bow_radius := (8.0 if is_hero else 6.2) * scale
			var bow_start_angle := facing.angle() - 1.18
			var bow_end_angle := facing.angle() + 1.18
			var bow_a := bow_center + Vector2.from_angle(bow_start_angle) * bow_radius
			var bow_b := bow_center + Vector2.from_angle(bow_end_angle) * bow_radius
			canvas.draw_arc(bow_center, bow_radius, bow_start_angle, bow_end_angle, 12, Color("9A642F"), 1.8 * scale, true)
			canvas.draw_line(bow_a, right_hand, Color("EAF6FF"), maxf(0.7, 0.8 * scale), true)
			canvas.draw_line(right_hand, bow_b, Color("EAF6FF"), maxf(0.7, 0.8 * scale), true)
			var arrow_tip := right_hand + facing * (13.0 if action == "attack" else 9.5) * scale
			canvas.draw_line(right_hand - facing * 3.0 * scale, arrow_tip, Color("D9F4FF"), 1.1 * scale, true)
			_draw_polygon_shape(canvas, arrow_tip, [Vector2(-2.2, -1.5), Vector2(3.0, 0.0), Vector2(-2.2, 1.5)], facing.angle(), FLASH_COLOR, outline_color, 0.5 * scale, scale)
		"mage":
			var staff_tip := right_hand + facing * (10.5 if action != "hurt" else 7.0) * scale
			canvas.draw_line(right_hand - facing * 5.0 * scale, staff_tip, Color("815632"), 2.2 * scale, true)
			var orb_pulse := 0.55 + 0.45 * sin(time_seconds * 6.0 + phase * 0.17)
			canvas.draw_circle(staff_tip, (3.5 + orb_pulse * 1.2) * scale, Color(MAGIC_PURPLE, 0.22 + orb_pulse * 0.25))
			canvas.draw_circle(staff_tip, (2.2 + orb_pulse * 0.55) * scale, MAGIC_PURPLE)
			_draw_polygon_shape(canvas, head - facing * 0.7 * scale, [Vector2(-4.2, 2.8), Vector2(1.0, -6.8), Vector2(5.0, 3.0)], facing.angle(), Color("6E58A8"), outline_color, 0.9 * scale, scale)
		"healer":
			var healer_tip := right_hand + facing * 9.0 * scale
			canvas.draw_line(right_hand - facing * 5.0 * scale, healer_tip, Color("7C5A38"), 2.0 * scale, true)
			canvas.draw_circle(healer_tip, 3.6 * scale, Color(HEAL_GREEN, 0.26))
			canvas.draw_line(healer_tip - side * 2.5 * scale, healer_tip + side * 2.5 * scale, HEAL_GREEN, 1.7 * scale, true)
			canvas.draw_line(healer_tip - facing * 2.5 * scale, healer_tip + facing * 2.5 * scale, HEAL_GREEN, 1.7 * scale, true)
			if action == "support":
				for hand_position in [left_hand, right_hand]:
					canvas.draw_circle(Vector2(hand_position), (1.8 + 0.7 * sin(phase * 1.35)) * scale, Color("D9FFF0"))
		"priest":
			var priest_tip := right_hand + facing * 10.0 * scale
			canvas.draw_line(right_hand - facing * 5.0 * scale, priest_tip, Color("8B653D"), 2.1 * scale, true)
			canvas.draw_arc(priest_tip - side * 1.4 * scale, 3.5 * scale, facing.angle() - 0.2, facing.angle() + PI + 0.2, 10, GOLD, 1.8 * scale, true)
			canvas.draw_arc(head, (4.5 + sin(phase * 0.8) * 0.35) * scale, 0.0, TAU, 16, Color(GOLD, 0.84), 1.2 * scale, true)
			if action == "support":
				canvas.draw_circle(left_hand, (2.1 + strike) * scale, Color(GOLD, 0.48))
		"musketeer", "rifleman":
			var recoil := (1.7 * strike if action == "attack" else 0.0) * scale
			var stock_start := chest - facing * 6.0 * scale + side * 0.8 * scale
			var barrel_end := chest + facing * ((17.5 if role == "rifleman" else 16.0) * scale - recoil)
			canvas.draw_line(stock_start, barrel_end, outline_color, (4.5 if role == "rifleman" else 4.0) * scale, true)
			canvas.draw_line(stock_start, chest + facing * 6.0 * scale, Color("855A35"), (2.9 if role == "musketeer" else 2.4) * scale, true)
			canvas.draw_line(chest + facing * 4.0 * scale, barrel_end, Color("DCE8EA"), 1.55 * scale, true)
			canvas.draw_circle(left_hand, 1.25 * scale, team_color)
			canvas.draw_circle(right_hand, 1.25 * scale, team_color)
			if role == "musketeer":
				canvas.draw_arc(head - facing * 0.7 * scale, 4.3 * scale, facing.angle() + 0.18, facing.angle() + PI - 0.18, 10, Color("725039"), 2.2 * scale, true)
			else:
				canvas.draw_arc(head - facing * 0.4 * scale, 4.0 * scale, facing.angle(), facing.angle() + PI, 10, Color("5D8E76"), 2.5 * scale, true)
			if action == "attack" and strike > 0.68:
				var flash_tip := barrel_end + facing * 2.4 * scale
				_draw_polygon_shape(canvas, flash_tip, [Vector2(-3.8, -2.0), Vector2(4.8, 0.0), Vector2(-3.8, 2.0)], facing.angle(), Color("FFF0A8"), FIRE_ORANGE, 0.7 * scale, scale)


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
	var grass_color := _chunk_grass_color(chunk).lerp(Color("607D52"), 0.22)
	if draw_ground:
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

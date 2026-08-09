class_name VIPTerrainRenderer
extends RefCounted

## Batched CanvasItem renderer for the continuous VIP terrain data.
##
## Each invisible streaming chunk becomes one colored triangle mesh. Shared
## edge vertices come from absolute world-space samples, so the visible world
## remains continuous while the browser only submits one ground draw per chunk.

const VIPTerrainCatalog = preload("res://scripts/vip_terrain_catalog.gd")

const RENDERER_ID := "vip_continuous_terrain_v1"
const PROFILE_ID := "vip_continuous_world"


static func prepare_chunk(raw_chunk: Dictionary) -> Dictionary:
	var chunk := raw_chunk.duplicate(false)
	var surface: Dictionary = Dictionary(chunk.get("render_surface", {}))
	var local_vertices := PackedVector2Array(surface.get("local_vertices", PackedVector2Array()))
	var colors := PackedColorArray(surface.get("vertex_colors", PackedColorArray()))
	var indices := PackedInt32Array(surface.get("indices", PackedInt32Array()))
	var vertices_3d := PackedVector3Array()
	vertices_3d.resize(local_vertices.size())
	for index in local_vertices.size():
		var point := local_vertices[index]
		vertices_3d[index] = Vector3(point.x, point.y, 0.0)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices_3d
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not vertices_3d.is_empty() and colors.size() == vertices_3d.size() and not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	chunk["render_mesh"] = mesh
	var terrain_set: Dictionary = {}
	for cell_value in Array(chunk.get("cells", [])):
		if cell_value is Dictionary:
			terrain_set[str(Dictionary(cell_value).get("terrain", "plains"))] = true
	var terrain_types: Array = terrain_set.keys()
	terrain_types.sort()
	chunk["terrain_types"] = terrain_types
	chunk["triangle_count"] = int(indices.size() / 3)
	return chunk


static func draw_chunk(
	canvas: CanvasItem,
	chunk: Dictionary,
	camera_world_position: Vector2,
	screen_center: Vector2,
	zoom: float,
	viewport_rect: Rect2,
	resource_remaining: Dictionary = {},
	draw_ground: bool = true,
	draw_props: bool = true
) -> Dictionary:
	var result := {
		"visible": false,
		"feature_count": 0,
		"resource_count": 0,
		"terrain_types": [],
	}
	if canvas == null or zoom <= 0.0:
		return result
	var bounds := Rect2(chunk.get("bounds", Rect2()))
	var screen_origin := _world_to_screen(bounds.position, camera_world_position, screen_center, zoom)
	var screen_bounds := Rect2(screen_origin - Vector2.ONE, bounds.size * zoom + Vector2.ONE * 2.0)
	if not screen_bounds.intersects(viewport_rect, true):
		return result
	var mesh: ArrayMesh = chunk.get("render_mesh") as ArrayMesh
	if draw_ground and (mesh == null or mesh.get_surface_count() <= 0):
		return result
	result["visible"] = true
	if draw_ground:
		var transform := Transform2D(Vector2(zoom, 0.0), Vector2(0.0, zoom), screen_origin)
		canvas.draw_mesh(mesh, null, transform)

	result["terrain_types"] = Array(chunk.get("terrain_types", []))
	if not draw_props:
		return result

	var cull := viewport_rect.grow(72.0 * zoom)
	for feature_value in Array(chunk.get("feature_nodes", [])):
		if not feature_value is Dictionary:
			continue
		var feature: Dictionary = feature_value
		var position := _world_to_screen(Vector2(feature.get("position", bounds.position)), camera_world_position, screen_center, zoom)
		if not cull.has_point(position):
			continue
		_draw_feature(canvas, feature, position, zoom)
		result["feature_count"] = int(result["feature_count"]) + 1

	for resource_value in Array(chunk.get("resource_nodes", [])):
		if not resource_value is Dictionary:
			continue
		var resource: Dictionary = resource_value
		var resource_id := str(resource.get("id", ""))
		var default_amount := maxi(0, int(resource.get("amount", 0)))
		var remaining := maxi(0, int(resource_remaining.get(resource_id, default_amount)))
		if remaining <= 0:
			continue
		var position := _world_to_screen(Vector2(resource.get("position", bounds.position)), camera_world_position, screen_center, zoom)
		if not cull.has_point(position):
			continue
		_draw_resource(canvas, resource, position, zoom)
		result["resource_count"] = int(result["resource_count"]) + 1
	return result


static func _draw_feature(canvas: CanvasItem, feature: Dictionary, position: Vector2, zoom: float) -> void:
	var radius := maxf(4.0, float(feature.get("radius", 10.0))) * zoom
	match str(feature.get("type", "")):
		"tree", "swamp_tree":
			var swamp := str(feature.get("type", "")) == "swamp_tree"
			canvas.draw_circle(position + Vector2(5.0, 8.0) * zoom, radius * 0.72, Color(0.04, 0.10, 0.08, 0.26))
			canvas.draw_line(position + Vector2(0.0, 7.0) * zoom, position + Vector2(0.0, -radius * 0.65), Color("5A3E2B"), maxf(2.0, 6.0 * zoom))
			canvas.draw_circle(position - Vector2(0.0, radius * 0.55), radius, Color("355A3A") if swamp else Color("245E35"))
			canvas.draw_circle(position + Vector2(-radius * 0.42, -radius * 0.70), radius * 0.60, Color("496B43") if swamp else Color("3E8248"))
			canvas.draw_arc(position - Vector2(0.0, radius * 0.55), radius, 0.0, TAU, 18, Color("173B28"), maxf(1.0, 2.0 * zoom))
		"mountain_crag", "plateau_boulder":
			var crag_color := Color("697073") if str(feature.get("type", "")) == "mountain_crag" else Color("8E805E")
			var points := PackedVector2Array([
				position + Vector2(-radius, radius * 0.55),
				position + Vector2(-radius * 0.55, -radius * 0.70),
				position + Vector2(radius * 0.10, -radius),
				position + Vector2(radius, radius * 0.50),
			])
			canvas.draw_colored_polygon(points, crag_color)
			canvas.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color("30383B"), maxf(1.0, 2.0 * zoom))
			canvas.draw_line(points[1], position + Vector2(radius * 0.12, radius * 0.15), Color("B7B3A4"), maxf(1.0, 1.5 * zoom))
		"mine_entrance":
			canvas.draw_circle(position, radius, Color("4B4138"))
			canvas.draw_arc(position, radius, PI, TAU, 20, Color("B08B58"), maxf(2.0, 4.0 * zoom))
			canvas.draw_rect(Rect2(position + Vector2(-radius * 0.58, -radius * 0.05), Vector2(radius * 1.16, radius * 0.75)), Color("15191B"))
			for support_x in [-0.48, 0.48]:
				canvas.draw_line(position + Vector2(radius * support_x, -radius * 0.12), position + Vector2(radius * support_x, radius * 0.72), Color("835F39"), maxf(2.0, 4.0 * zoom))
		"cactus":
			canvas.draw_line(position + Vector2(0.0, radius), position - Vector2(0.0, radius), Color("2F7D49"), maxf(3.0, 7.0 * zoom))
			canvas.draw_line(position, position + Vector2(radius * 0.65, -radius * 0.15), Color("3D9558"), maxf(2.0, 5.0 * zoom))
			canvas.draw_line(position + Vector2(radius * 0.62, -radius * 0.15), position + Vector2(radius * 0.62, -radius * 0.65), Color("3D9558"), maxf(2.0, 5.0 * zoom))
		"reef", "reed_bed", "river_reeds":
			for blade in 5:
				var offset := Vector2((float(blade) - 2.0) * 3.5, 4.0) * zoom
				canvas.draw_line(position + offset, position + offset + Vector2(sin(float(blade) * 1.8) * 5.0, -13.0 - float(blade % 2) * 5.0) * zoom, Color("9DBB5D") if str(feature.get("type", "")) != "reef" else Color("5CC2A3"), maxf(1.0, 1.8 * zoom))
		_:
			canvas.draw_circle(position, maxf(2.0, radius * 0.45), Color("B9C96A"))


static func _draw_resource(canvas: CanvasItem, resource: Dictionary, position: Vector2, zoom: float) -> void:
	var type_id := str(resource.get("type", ""))
	var color := _resource_color(type_id)
	var pulse_radius := maxf(4.0, 7.0 * zoom)
	canvas.draw_circle(position + Vector2(3.0, 4.0) * zoom, pulse_radius * 1.15, Color(0.02, 0.04, 0.05, 0.34))
	if type_id in ["fish", "freshwater_fish"]:
		var fish := PackedVector2Array([position + Vector2(-8, 0) * zoom, position + Vector2(1, -5) * zoom, position + Vector2(8, 0) * zoom, position + Vector2(1, 5) * zoom])
		canvas.draw_colored_polygon(fish, color)
		canvas.draw_line(position + Vector2(-8, 0) * zoom, position + Vector2(-13, -5) * zoom, color, maxf(1.0, 2.0 * zoom))
		canvas.draw_line(position + Vector2(-8, 0) * zoom, position + Vector2(-13, 5) * zoom, color, maxf(1.0, 2.0 * zoom))
	elif type_id in ["wood", "herbs", "grain"]:
		canvas.draw_line(position + Vector2(0, 8) * zoom, position + Vector2(0, -8) * zoom, color, maxf(2.0, 3.5 * zoom))
		canvas.draw_line(position, position + Vector2(-7, -5) * zoom, color.lightened(0.16), maxf(1.0, 2.5 * zoom))
		canvas.draw_line(position + Vector2(0, -3) * zoom, position + Vector2(7, -8) * zoom, color.lightened(0.16), maxf(1.0, 2.5 * zoom))
	else:
		var crystal := PackedVector2Array([position + Vector2(0, -10) * zoom, position + Vector2(7, -2) * zoom, position + Vector2(4, 9) * zoom, position + Vector2(-6, 7) * zoom, position + Vector2(-8, -2) * zoom])
		canvas.draw_colored_polygon(crystal, color)
		canvas.draw_polyline(PackedVector2Array([crystal[0], crystal[1], crystal[2], crystal[3], crystal[4], crystal[0]]), color.lightened(0.35), maxf(1.0, 1.5 * zoom))
	canvas.draw_arc(position, pulse_radius + 4.0 * zoom, 0.0, TAU, 16, Color(color, 0.55), maxf(1.0, 1.2 * zoom))


static func _resource_color(type_id: String) -> Color:
	match type_id:
		"wood": return Color("9A6A3B")
		"herbs": return Color("74D66D")
		"fish", "freshwater_fish": return Color("8FE9F4")
		"iron", "coal": return Color("9BA4AA")
		"gold": return Color("FFD166")
		"crystal": return Color("B995FF")
		"salt", "clay", "peat": return Color("E6D6BC")
		"copper": return Color("D98755")
		"grain": return Color("EACB67")
		_: return Color("D4E1E5")


static func _world_to_screen(world_position: Vector2, camera_world_position: Vector2, screen_center: Vector2, zoom: float) -> Vector2:
	return (world_position - camera_world_position) * zoom + screen_center

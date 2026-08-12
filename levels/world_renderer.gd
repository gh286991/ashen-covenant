@tool
class_name AshenWorldRenderer
extends Node2D

const MAP_SIZE := Vector2(2200, 1400)
const WORLD_COLLISION_LAYER := 1
const ELLIPSE_COLLISION_SEGMENTS := 48
const MOTION_SAMPLE_STEP := 4.0
const DUNGEON_BASE_TEXTURE := preload("res://assets/map/ashen_catacombs-base.png")
const SOUL_ANCHOR_TEXTURE := preload("res://assets/props/soul_anchor/single-1.png")
const IRON_FENCE_TEXTURE := preload("res://assets/props/dungeon/iron-fence/prop.png")
const SPIKE_TRAP_TEXTURE := preload("res://assets/props/dungeon/spike-trap/prop.png")

var layout: Dictionary = {}
var anchors: Array[Dictionary] = []
var chests: Array[Dictionary] = []
var breakables: Array[Dictionary] = []
var scene_boss_gate: Dictionary = {}
var scene_shortcuts: Array[Dictionary] = []
var scene_hazards: Array[Dictionary] = []
var scene_decor_props: Array[Dictionary] = []
var scene_features_configured := false
var gate_open := false
var boss_awake := false
var elapsed := 0.0
var world_collision: StaticBody2D
var collision_rebuild_queued := false

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	z_index = -20
	_ensure_world_collision()
	_request_collision_rebuild()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	elapsed += delta
	queue_redraw()

func configure_layout(layout_data: Dictionary) -> void:
	layout = layout_data
	if not Engine.is_editor_hint():
		_request_collision_rebuild()
	queue_redraw()

func set_interactables(chest_data: Array[Dictionary], breakable_data: Array[Dictionary]) -> void:
	chests = chest_data
	breakables = breakable_data
	if not Engine.is_editor_hint():
		_request_collision_rebuild()
	queue_redraw()

func update_world(anchor_data: Array[Dictionary], opened: bool, boss_active: bool) -> void:
	anchors = anchor_data
	gate_open = opened
	boss_awake = boss_active
	if not Engine.is_editor_hint():
		_request_collision_rebuild()
	queue_redraw()

func set_scene_features(boss_gate_data: Dictionary, shortcut_data: Array[Dictionary], hazard_data: Array[Dictionary], decor_prop_data: Array[Dictionary]) -> void:
	scene_boss_gate = boss_gate_data
	scene_shortcuts = shortcut_data
	scene_hazards = hazard_data
	scene_decor_props = decor_prop_data
	scene_features_configured = true
	if not Engine.is_editor_hint():
		_request_collision_rebuild()
	queue_redraw()

func resolve_motion(from: Vector2, to: Vector2, actor_radius: float = 16.0) -> Vector2:
	if from.is_equal_approx(to):
		return from
	var distance := from.distance_to(to)
	var steps := maxi(1, int(ceil(distance / MOTION_SAMPLE_STEP)))
	var step_motion := (to - from) / float(steps)
	var resolved := from
	for _step in steps:
		var desired := resolved + step_motion
		if is_motion_walkable(resolved, desired, actor_radius):
			resolved = desired
			continue
		var x_first := _resolve_axis_step(resolved, desired, actor_radius, true)
		var y_first := _resolve_axis_step(resolved, desired, actor_radius, false)
		var x_progress := resolved.distance_squared_to(x_first)
		var y_progress := resolved.distance_squared_to(y_first)
		var axis_resolved := x_first if x_progress >= y_progress else y_first
		if not axis_resolved.is_equal_approx(resolved):
			resolved = axis_resolved
			continue
		resolved = _furthest_walkable_point(resolved, desired, actor_radius)
	return resolved

func is_motion_walkable(from: Vector2, to: Vector2, actor_radius: float = 16.0) -> bool:
	var distance := from.distance_to(to)
	var steps := maxi(1, int(ceil(distance / MOTION_SAMPLE_STEP)))
	for i in range(1, steps + 1):
		var point := from.lerp(to, float(i) / float(steps))
		if not is_point_walkable(point, actor_radius):
			return false
	return true

func is_point_walkable(point: Vector2, actor_radius: float = 16.0) -> bool:
	if layout.is_empty():
		return Rect2(64, 64, MAP_SIZE.x - 128, MAP_SIZE.y - 128).grow(-actor_radius).has_point(point)
	var inside_walkable := false
	for shape: Dictionary in layout.get("walkables", []):
		if _shape_contains_point(shape, point, actor_radius):
			inside_walkable = true
			break
	if not inside_walkable:
		return false
	if not gate_open and _boss_gate_rect().grow(actor_radius).has_point(point):
		return false
	for shortcut: Dictionary in _shortcuts():
		if not _anchor_is_alive(String(shortcut.get("anchor", ""))):
			continue
		if _shortcut_gate_rect(shortcut).grow(actor_radius).has_point(point):
			return false
	for prop: Dictionary in _decor_props():
		var blocker_rect := _decor_blocker_rect(prop)
		if blocker_rect.has_area() and blocker_rect.grow(actor_radius).has_point(point):
			return false
	for chest: Dictionary in chests:
		if point.distance_to(_position_from_data(chest)) < actor_radius + 27.0:
			return false
	for breakable: Dictionary in breakables:
		if bool(breakable.get("alive", true)) and point.distance_to(_position_from_data(breakable)) < actor_radius + 20.0:
			return false
	return true

func room_at_point(point: Vector2) -> Dictionary:
	var best_room: Dictionary = {}
	var best_area := INF
	for room: Dictionary in layout.get("rooms", []):
		if _shape_contains_point(room, point, 0.0):
			var area := float(room.get("w", float(room.get("rx", 1.0)) * 2.0)) * float(room.get("h", float(room.get("ry", 1.0)) * 2.0))
			if area < best_area:
				best_area = area
				best_room = room
	return best_room

func _shape_contains_point(shape: Dictionary, point: Vector2, margin: float) -> bool:
	if String(shape.get("shape", "rect")) == "ellipse":
		var radius_x := maxf(1.0, float(shape.get("rx", 1.0)) - margin)
		var radius_y := maxf(1.0, float(shape.get("ry", 1.0)) - margin)
		var delta := point - Vector2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0)))
		return delta.x * delta.x / (radius_x * radius_x) + delta.y * delta.y / (radius_y * radius_y) <= 1.0
	return _rect_from_data(shape).grow(-margin).has_point(point)

func _resolve_axis_step(from: Vector2, to: Vector2, actor_radius: float, x_first: bool) -> Vector2:
	var resolved := from
	var first := Vector2(to.x, from.y) if x_first else Vector2(from.x, to.y)
	if is_motion_walkable(resolved, first, actor_radius):
		resolved = first
	var second := Vector2(resolved.x, to.y) if x_first else Vector2(to.x, resolved.y)
	if is_motion_walkable(resolved, second, actor_radius):
		resolved = second
	return resolved

func _furthest_walkable_point(from: Vector2, to: Vector2, actor_radius: float) -> Vector2:
	var low := 0.0
	var high := 1.0
	for _iteration in 8:
		var middle := (low + high) * 0.5
		var candidate := from.lerp(to, middle)
		if is_motion_walkable(from, candidate, actor_radius):
			low = middle
		else:
			high = middle
	return from.lerp(to, low)

func _rect_from_data(data: Dictionary) -> Rect2:
	return Rect2(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("w", 0.0)), float(data.get("h", 0.0)))

func _position_from_data(data: Dictionary) -> Vector2:
	if data.has("position"):
		var value: Dictionary = data.position
		return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))
	return Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))

func _boss_gate_rect() -> Rect2:
	return _rect_from_data(_boss_gate_data())

func _boss_gate_render_rect() -> Rect2:
	var gate := _boss_gate_data()
	var position_data: Dictionary = gate.get("position", {})
	var size_data: Dictionary = gate.get("renderSize", {})
	var gate_position := Vector2(float(position_data.get("x", 1100.0)), float(position_data.get("y", 447.0)))
	var gate_size := Vector2(float(size_data.get("w", 220.0)), float(size_data.get("h", 92.0)))
	return Rect2(gate_position - Vector2(gate_size.x * 0.5, gate_size.y), gate_size)

func _boss_gate_data() -> Dictionary:
	return scene_boss_gate if scene_features_configured else layout.get("bossGate", {})

func _shortcuts() -> Array[Dictionary]:
	return scene_shortcuts if scene_features_configured else layout.get("shortcuts", [])

func _hazards() -> Array[Dictionary]:
	return scene_hazards if scene_features_configured else layout.get("hazards", [])

func _decor_props() -> Array[Dictionary]:
	return scene_decor_props if scene_features_configured else layout.get("decorProps", [])

func _shortcut_gate_rect(shortcut: Dictionary) -> Rect2:
	var render_rect := _shortcut_gate_render_rect(shortcut)
	return Rect2(
		Vector2(render_rect.position.x, render_rect.position.y + render_rect.size.y * 0.45),
		Vector2(render_rect.size.x, render_rect.size.y * 0.35)
	)

func _shortcut_gate_render_rect(shortcut: Dictionary) -> Rect2:
	var gate_data: Dictionary = shortcut.get("gatePosition", {})
	var size_data: Dictionary = shortcut.get("renderSize", {})
	var gate_position := Vector2(float(gate_data.get("x", 0.0)), float(gate_data.get("y", 0.0)))
	var gate_size := Vector2(float(size_data.get("w", 150.0)), float(size_data.get("h", 74.0)))
	return Rect2(gate_position - Vector2(gate_size.x * 0.5, gate_size.y), gate_size)

func _decor_blocker_rect(prop: Dictionary) -> Rect2:
	var blocker: Dictionary = prop.get("blocker", {})
	return _rect_from_data(blocker) if not blocker.is_empty() else Rect2()

func _ensure_world_collision() -> void:
	if is_instance_valid(world_collision):
		return
	world_collision = get_node_or_null("WorldCollision") as StaticBody2D
	if world_collision == null:
		world_collision = StaticBody2D.new()
		world_collision.name = "WorldCollision"
		add_child(world_collision)
	world_collision.collision_layer = WORLD_COLLISION_LAYER
	world_collision.collision_mask = 0

func _request_collision_rebuild() -> void:
	if not is_inside_tree() or collision_rebuild_queued:
		return
	collision_rebuild_queued = true
	call_deferred(&"_rebuild_world_colliders")

func _rebuild_world_colliders() -> void:
	collision_rebuild_queued = false
	_ensure_world_collision()
	for child in world_collision.get_children():
		world_collision.remove_child(child)
		child.queue_free()
	if layout.is_empty():
		return
	var boundary_index := 0
	for polygon in _merged_walkable_polygons():
		if polygon.size() < 3:
			continue
		var boundary := CollisionPolygon2D.new()
		boundary.name = "WalkableBoundary_%d" % boundary_index
		boundary.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		boundary.polygon = polygon
		world_collision.add_child(boundary)
		boundary_index += 1
	if not gate_open:
		_add_rect_blocker("BossGate", _boss_gate_rect())
	for shortcut: Dictionary in _shortcuts():
		if _anchor_is_alive(String(shortcut.get("anchor", ""))):
			_add_rect_blocker("ShortcutGate_%s" % String(shortcut.get("id", "gate")), _shortcut_gate_rect(shortcut))
	for prop: Dictionary in _decor_props():
		var blocker_rect := _decor_blocker_rect(prop)
		if blocker_rect.has_area():
			_add_rect_blocker("Decor_%s" % String(prop.get("id", "blocker")), blocker_rect)
	for chest: Dictionary in chests:
		_add_circle_blocker("Chest_%s" % String(chest.get("id", "chest")), _position_from_data(chest), 27.0)
	for breakable: Dictionary in breakables:
		if bool(breakable.get("alive", true)):
			_add_circle_blocker("Breakable_%s" % String(breakable.get("id", "breakable")), _position_from_data(breakable), 20.0)

func _shape_to_polygon(shape: Dictionary) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	if String(shape.get("shape", "rect")) == "ellipse":
		var center := Vector2(float(shape.get("x", 0.0)), float(shape.get("y", 0.0)))
		var radii := Vector2(float(shape.get("rx", 1.0)), float(shape.get("ry", 1.0)))
		for i in ELLIPSE_COLLISION_SEGMENTS:
			var angle := TAU * float(i) / float(ELLIPSE_COLLISION_SEGMENTS)
			polygon.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		return polygon
	var rect := _rect_from_data(shape)
	polygon.append(rect.position)
	polygon.append(Vector2(rect.end.x, rect.position.y))
	polygon.append(rect.end)
	polygon.append(Vector2(rect.position.x, rect.end.y))
	return polygon

func _merged_walkable_polygons() -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for shape: Dictionary in layout.get("walkables", []):
		var polygon := _shape_to_polygon(shape)
		if polygon.size() >= 3:
			polygons.append(polygon)
	var merged_any := true
	while merged_any:
		merged_any = false
		for i in polygons.size():
			if merged_any:
				break
			for j in range(i + 1, polygons.size()):
				var merged := Geometry2D.merge_polygons(polygons[i], polygons[j])
				if merged.size() == 1:
					polygons[i] = merged[0]
					polygons.remove_at(j)
					merged_any = true
					break
	return polygons

func _add_rect_blocker(node_name: String, rect: Rect2) -> void:
	if not rect.has_area():
		return
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var shape_node := CollisionShape2D.new()
	shape_node.name = node_name
	shape_node.position = rect.get_center()
	shape_node.shape = shape
	world_collision.add_child(shape_node)

func _add_circle_blocker(node_name: String, center: Vector2, radius: float) -> void:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var shape_node := CollisionShape2D.new()
	shape_node.name = node_name
	shape_node.position = center
	shape_node.shape = shape
	world_collision.add_child(shape_node)

func _anchor_is_alive(anchor_id: String) -> bool:
	for anchor: Dictionary in anchors:
		if String(anchor.get("id", "")) == anchor_id:
			return bool(anchor.get("alive", true))
	return true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color("07060b"))
	draw_texture_rect(DUNGEON_BASE_TEXTURE, Rect2(Vector2.ZERO, MAP_SIZE), false, Color.WHITE)
	if Engine.is_editor_hint():
		return
	_draw_hazards()
	_draw_anchors()
	_draw_shortcuts()
	_draw_gate()

func _draw_hazards() -> void:
	for hazard: Dictionary in _hazards():
		var p := _position_from_data(hazard)
		var radius := float(hazard.get("radius", 44.0))
		var pulse := 0.5 + sin(elapsed * 4.8 + p.x * 0.01) * 0.5
		draw_texture_rect(SPIKE_TRAP_TEXTURE, Rect2(p - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), false, Color(0.78, 0.76, 0.78, 0.78))
		draw_arc(p, radius + 4.0 + pulse * 3.0, 0.0, TAU, 28, Color(0.72, 0.13, 0.18, 0.24 + pulse * 0.18), 2.0)

func _draw_anchors() -> void:
	for anchor: Dictionary in anchors:
		var p: Vector2 = anchor.get("position", Vector2.ZERO)
		var alive: bool = anchor.get("alive", true)
		if alive:
			var hp_ratio: float = anchor.get("health", 1.0) / maxf(1.0, anchor.get("max_health", 1.0))
			draw_set_transform(p + Vector2(0, 10), 0.0, Vector2(1.35, 0.48))
			draw_circle(Vector2.ZERO, 44.0, Color(0.0, 0.0, 0.0, 0.52))
			draw_set_transform(Vector2.ZERO)
			draw_circle(p, 42.0 + sin(elapsed * 2.0) * 3.0, Color(0.45, 0.06, 0.16, 0.12))
			draw_arc(p, 36.0, elapsed * 0.4, elapsed * 0.4 + TAU, 6, Color("a73253"), 4.0)
			draw_texture_rect(SOUL_ANCHOR_TEXTURE, Rect2(p + Vector2(-64, -113), Vector2(128, 128)), false, Color.WHITE)
			draw_rect(Rect2(p + Vector2(-45, 30), Vector2(90, 7)), Color("1b141c"))
			draw_rect(Rect2(p + Vector2(-44, 31), Vector2(88 * hp_ratio, 5)), Color("d43d5c"))
		else:
			for i in 7:
				var angle := TAU * float(i) / 7.0
				draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(angle) * 12.0, p + Vector2.from_angle(angle + 0.2) * 32.0, p + Vector2.from_angle(angle - 0.2) * 25.0]), Color("4c3239"))

func _draw_shortcuts() -> void:
	for shortcut: Dictionary in _shortcuts():
		var anchor_id := String(shortcut.get("anchor", ""))
		var render_rect := _shortcut_gate_render_rect(shortcut)
		var p := Vector2(render_rect.get_center().x, render_rect.end.y)
		if _anchor_is_alive(anchor_id):
			draw_texture_rect(IRON_FENCE_TEXTURE, render_rect, false, Color(0.74, 0.61, 0.64, 0.96))
			draw_circle(p - Vector2(0, render_rect.size.y * 0.35), 28.0 + sin(elapsed * 3.0) * 3.0, Color(0.55, 0.05, 0.12, 0.12))
		else:
			draw_arc(p - Vector2(0, 15), 34.0 + sin(elapsed * 3.5) * 3.0, 0.0, TAU, 30, Color(0.40, 0.55, 0.82, 0.38), 3.0)

func _draw_gate() -> void:
	if layout.is_empty():
		return
	var render_rect := _boss_gate_render_rect()
	var p := Vector2(render_rect.get_center().x, render_rect.end.y)
	if not gate_open:
		draw_texture_rect(IRON_FENCE_TEXTURE, render_rect, false, Color(0.80, 0.54, 0.58, 1.0))
		draw_rect(Rect2(p.x - 104, p.y + 5, 208, 7), Color("160e16"))
		draw_string(ThemeDB.fallback_font, p + Vector2(-86, 28), "SOUL GATE SEALED", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c77b8e"))
	else:
		draw_arc(p - Vector2(0, 28), 58.0 + sin(elapsed * 2.4) * 5.0, PI, TAU, 34, Color(0.85, 0.31, 0.17, 0.48 if boss_awake else 0.26), 5.0)

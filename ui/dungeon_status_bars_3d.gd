class_name DungeonStatusBars3D
extends Node3D

## Minimal stacked world-space health and mana bars for the 3D dungeon player.

const BAR_WIDTH := 1.25
const BAR_HEIGHT := 0.07
const HEALTH_Y := 0.035
const MANA_Y := -0.035

var _bar_stack: Node3D
var _health_fill: MeshInstance3D
var _mana_fill: MeshInstance3D
var _camera: Camera3D


func setup(actor: DungeonPlayer3D) -> void:
	_bar_stack = Node3D.new()
	_bar_stack.name = "BarStack"
	add_child(_bar_stack)
	_camera = get_viewport().get_camera_3d()
	_sync_stack_orientation()
	_build_bar("Health", HEALTH_Y, Color("60d96a"))
	_build_bar("Mana", MANA_Y, Color("419bf3"))
	if not actor.health_changed.is_connected(_on_health_changed):
		actor.health_changed.connect(_on_health_changed)
	if not actor.mana_changed.is_connected(_on_mana_changed):
		actor.mana_changed.connect(_on_mana_changed)
	_on_health_changed(actor.health, actor.max_health)
	_on_mana_changed(actor.mana, actor.max_mana)


func _physics_process(_delta: float) -> void:
	_sync_stack_orientation()


func _sync_stack_orientation() -> void:
	if _bar_stack == null:
		return
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	var stack_transform := _bar_stack.global_transform
	stack_transform.basis = _camera.global_transform.basis
	_bar_stack.global_transform = stack_transform


func _build_bar(kind: String, y: float, fill_color: Color) -> void:
	var fill := _create_fill(kind + "Fill", fill_color)
	fill.position = Vector3(0.0, y, 0.0)
	_bar_stack.add_child(fill)
	if kind == "Health":
		_health_fill = fill
	else:
		_mana_fill = fill


func _create_fill(fill_name: String, fill_color: Color) -> MeshInstance3D:
	var fill := MeshInstance3D.new()
	fill.name = fill_name
	var quad := QuadMesh.new()
	quad.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var material := StandardMaterial3D.new()
	material.albedo_color = fill_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# BarStack itself faces the camera, so its local Y axis is the screen's
	# vertical axis and the two bars stay visually attached.
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	fill.mesh = quad
	return fill


func _on_health_changed(current: float, maximum: float) -> void:
	_update_bar(_health_fill, current, maximum)


func _on_mana_changed(current: float, maximum: float) -> void:
	_update_bar(_mana_fill, current, maximum)


func _update_bar(fill: MeshInstance3D, current: float, maximum: float) -> void:
	if fill == null:
		return
	var ratio := clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	var quad := fill.mesh as QuadMesh
	if quad != null:
		quad.size.x = maxf(BAR_WIDTH * ratio, 0.001)
		# Keep the left edge fixed while the bar shrinks from the right.
		fill.position.x = -BAR_WIDTH * 0.5 + quad.size.x * 0.5

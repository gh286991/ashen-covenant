class_name MonsterHealthBar3D
extends Node3D

## Billboard health bar that stays below a 3D monster and follows its health.

const BAR_WIDTH := 0.9
const BAR_HEIGHT := 0.075
const BAR_OFFSET_Y := 1.52

var _background: MeshInstance3D
var _fill: MeshInstance3D
var _monster: DungeonMonster3D


func _ready() -> void:
	# The monster root is placed at floor level, so the bar must sit above the
	# body rather than at the root's local origin where it can be hidden by the
	# floor or the monster mesh.
	position.y = BAR_OFFSET_Y
	_monster = get_parent() as DungeonMonster3D
	_build_bar()
	if _monster == null:
		return
	if not _monster.health_changed.is_connected(_on_health_changed):
		_monster.health_changed.connect(_on_health_changed)
	_on_health_changed(_monster.get_health(), _monster.max_health)


func _build_bar() -> void:
	_background = _create_bar(Color(0.035, 0.02, 0.025, 0.92), 0)
	_fill = _create_bar(Color(0.18, 0.92, 0.32, 1.0), 1)
	_fill.position.z = 0.012


func _create_bar(color: Color, render_priority: int) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	mesh_instance.mesh = quad

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = render_priority
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance


func _on_health_changed(current: float, maximum: float) -> void:
	if _fill == null:
		return
	var ratio := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	_fill.scale.x = ratio
	# Keep the left edge fixed while the green fill shrinks.
	_fill.position.x = -BAR_WIDTH * 0.5 * (1.0 - ratio)
	_fill.visible = ratio > 0.0

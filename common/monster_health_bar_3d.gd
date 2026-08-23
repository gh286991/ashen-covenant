class_name MonsterHealthBar3D
extends Node3D

## Simple billboard health bar that stays below a 3D monster and follows its health.

const BAR_WIDTH := 1.1
const BAR_HEIGHT := 0.07
const BAR_OFFSET_XZ := 0.72
const BAR_OFFSET_Y := -0.25

var _fill: MeshInstance3D
var _monster: DungeonMonster3D


func _ready() -> void:
	# Match the player's world-space bars: equal X/Z offset keeps the bar
	# centred below the monster in the isometric camera.
	position = Vector3(BAR_OFFSET_XZ, BAR_OFFSET_Y, BAR_OFFSET_XZ)
	visible = false
	_monster = get_parent() as DungeonMonster3D
	_build_bar()
	if _monster == null:
		return
	if not _monster.health_changed.is_connected(_on_health_changed):
		_monster.health_changed.connect(_on_health_changed)
	_on_health_changed(_monster.get_health(), _monster.max_health)


func _build_bar() -> void:
	_fill = _create_bar(Color("60d96a"))


func _create_bar(color: Color) -> MeshInstance3D:
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
	material.render_priority = 1
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return mesh_instance


func _on_health_changed(current: float, maximum: float) -> void:
	if _fill == null:
		return
	var ratio := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	var quad := _fill.mesh as QuadMesh
	if quad == null:
		return
	quad.size.x = maxf(BAR_WIDTH * ratio, 0.001)
	# Keep the left edge fixed while the green fill shrinks.
	_fill.position.x = -BAR_WIDTH * 0.5 * (1.0 - ratio)
	_fill.visible = ratio > 0.0

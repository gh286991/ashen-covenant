class_name CovenantHUD
extends CanvasLayer

signal skill_selected(id: String)
signal skill_tree_requested

var surface: CovenantHUDSurface

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = CovenantHUDSurface.new()
	surface.name = "HUDSurface"
	add_child(surface)
	surface.skill_selected.connect(_on_skill_selected)
	surface.skill_tree_requested.connect(_on_skill_tree_requested)

func update_snapshot(data: Dictionary) -> void:
	if surface:
		surface.update_snapshot(data)

func play_screen_flash(color: Color, intensity: float = 0.3, duration: float = 0.14) -> void:
	if surface:
		surface.play_screen_flash(color, intensity, duration)

func play_level_up_notice(level: int, points_awarded: int) -> void:
	if surface:
		surface.play_level_up_notice(level, points_awarded)

func blocks_world_pointer(viewport_position: Vector2) -> bool:
	return surface != null and surface.blocks_world_pointer(viewport_position)

func _on_skill_selected(id: String) -> void:
	skill_selected.emit(id)

func _on_skill_tree_requested() -> void:
	skill_tree_requested.emit()

class_name CovenantHUD
extends CanvasLayer

signal upgrade_selected(id: String)

var surface: CovenantHUDSurface

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = CovenantHUDSurface.new()
	surface.name = "HUDSurface"
	add_child(surface)
	surface.upgrade_selected.connect(_on_upgrade_selected)

func update_snapshot(data: Dictionary) -> void:
	if surface:
		surface.update_snapshot(data)

func play_screen_flash(color: Color, intensity: float = 0.3, duration: float = 0.14) -> void:
	if surface:
		surface.play_screen_flash(color, intensity, duration)

func blocks_world_pointer(viewport_position: Vector2) -> bool:
	return surface != null and surface.blocks_world_pointer(viewport_position)

func _on_upgrade_selected(id: String) -> void:
	upgrade_selected.emit(id)

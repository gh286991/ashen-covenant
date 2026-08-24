extends Node

## Bundled Traditional Chinese font fallback. Keeping this in the project makes
## UI and Label3D text deterministic on desktop and in Web exports, where a
## browser/system CJK font may not be available.
const CJK_FONT: Font = preload("res://assets/fonts/NotoSansTC-runtime.ttf")


func _enter_tree() -> void:
	ThemeDB.fallback_font = CJK_FONT

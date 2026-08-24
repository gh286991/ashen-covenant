extends Node3D

## Lightweight 3D title scene. The existing Control menu stays in a CanvasLayer
## so keyboard focus, CJK font fallback, and menu flow remain unchanged.

@onready var camera: Camera3D = $Camera3D
@onready var hero: Node3D = $Hero

var _elapsed := 0.0


func _ready() -> void:
	camera.look_at(Vector3(0.0, 1.65, 0.0), Vector3.UP)
	var warrior := hero as DungeonWarrior3D
	if warrior != null:
		warrior.set_animation_state(&"Idle", Vector3.FORWARD)


func _process(delta: float) -> void:
	_elapsed += delta
	# A very slow parallax drift keeps the title scene alive without adding
	# particles, post-processing, or a second gameplay world to the Web build.
	camera.position.x = sin(_elapsed * 0.18) * 0.42
	camera.position.y = 3.7 + sin(_elapsed * 0.24) * 0.06
	camera.look_at(Vector3(0.0, 1.65, 0.0), Vector3.UP)
	if is_instance_valid(hero):
		hero.rotation.y = deg_to_rad(168.0) + sin(_elapsed * 0.2) * 0.035

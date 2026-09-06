class_name TorchFlicker3D
extends Node3D

@export var base_energy := 3.2
@export var flicker_intensity := 0.65
@export var speed := 14.0

@onready var light: OmniLight3D = get_node_or_null("Light") as OmniLight3D
@onready var fire: Node3D = get_node_or_null("Flame") as Node3D

var _clock := randf() * 100.0

func _process(delta: float) -> void:
	_clock += delta * speed
	var noise := sin(_clock) * 0.5 + sin(_clock * 2.3) * 0.3 + sin(_clock * 4.7) * 0.2
	if light != null:
		light.light_energy = base_energy + noise * flicker_intensity
	if fire != null:
		var s := 1.0 + noise * 0.12
		fire.scale = Vector3(s, 1.0 + noise * 0.2, s)

class_name LightFlicker3D
extends OmniLight3D

@export var base_energy := 4.5
@export var flicker_range := 0.65
@export var flicker_speed := 14.0

var _time := 0.0
var _seed := 0.0

func _ready() -> void:
	_seed = randf() * 100.0
	base_energy = light_energy

func _process(delta: float) -> void:
	_time += delta * flicker_speed
	var noise := sin(_time + _seed) * 0.5 + sin(_time * 2.3 + _seed * 1.7) * 0.3 + sin(_time * 5.1) * 0.2
	light_energy = base_energy + noise * flicker_range

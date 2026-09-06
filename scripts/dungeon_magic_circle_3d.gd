class_name DungeonMagicCircle3D
extends Node3D

@export var circle_color: Color = Color(0.25, 0.65, 1.0, 0.85)
@export var rotation_speed: float = 0.15
@export var pulse_speed: float = 2.0
@export var base_light_energy: float = 1.8
@export var light_range: float = 5.5

@onready var _circle_mesh: MeshInstance3D = $CircleMesh
@onready var _light: OmniLight3D = $OmniLight3D
@onready var _particles: CPUParticles3D = get_node_or_null("Particles") as CPUParticles3D

var _material: StandardMaterial3D
var _time := 0.0

func _ready() -> void:
	if _circle_mesh != null:
		var orig = _circle_mesh.get_active_material(0)
		if orig is StandardMaterial3D:
			_material = orig.duplicate() as StandardMaterial3D
			_circle_mesh.set_surface_override_material(0, _material)
		elif _circle_mesh.material_override is StandardMaterial3D:
			_material = _circle_mesh.material_override.duplicate() as StandardMaterial3D
			_circle_mesh.material_override = _material
	_apply_color()

func _apply_color() -> void:
	if _light != null:
		_light.light_color = circle_color
		_light.light_energy = base_light_energy
		_light.omni_range = light_range
	if _material != null:
		_material.albedo_color = circle_color
		_material.emission = circle_color
	if _particles != null:
		_particles.color = circle_color

func _process(delta: float) -> void:
	_time += delta
	if _circle_mesh != null:
		_circle_mesh.rotation.y += rotation_speed * delta
	
	var pulse := 0.5 + 0.5 * sin(_time * pulse_speed)
	if _light != null:
		_light.light_energy = base_light_energy * (0.8 + pulse * 0.4)
	if _material != null:
		_material.emission_energy_multiplier = 1.8 + pulse * 1.2

class_name DungeonLevelUpCelebration3D
extends Node3D

signal celebration_finished

const BASE_BURST_SCALE := Vector3.ONE * 0.0011
const PEAK_BURST_SCALE := Vector3.ONE * 0.0032
const BASE_LABEL_POSITION := Vector3(0.0, 2.4, 0.0)
const PEAK_LABEL_POSITION := Vector3(0.0, 2.95, 0.0)

@onready var burst: Sprite3D = %Burst
@onready var level_label: Label3D = %LevelLabel
@onready var reward_label: Label3D = %RewardLabel
@onready var sparkles: GPUParticles3D = %Sparkles
@onready var halo_one: MeshInstance3D = %HaloOne
@onready var halo_two: MeshInstance3D = %HaloTwo
@onready var flash_light: OmniLight3D = %FlashLight

var _animation: Tween


func _ready() -> void:
	_reset_visuals()
	visible = false


func play(new_level: int, attribute_points_awarded: int, skill_points_awarded: int) -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	visible = true
	_reset_visuals()
	level_label.text = "LEVEL UP!  LV.%02d" % new_level
	reward_label.text = "能力點 +%d　技能點 +%d" % [attribute_points_awarded, skill_points_awarded]
	sparkles.restart()

	_animation = create_tween().bind_node(self)
	_animation.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animation.set_parallel(true)
	_animation.tween_property(burst, "scale", PEAK_BURST_SCALE, 0.48).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_animation.tween_property(burst, "modulate:a", 0.0, 0.72).set_delay(1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.tween_property(level_label, "position", PEAK_LABEL_POSITION, 1.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_property(level_label, "modulate:a", 0.0, 0.55).set_delay(1.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.tween_property(reward_label, "position:y", 2.33, 1.4).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_property(reward_label, "modulate:a", 0.0, 0.52).set_delay(1.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.tween_property(halo_one, "scale", Vector3.ONE * 1.95, 0.78).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_animation.tween_property(halo_two, "scale", Vector3.ONE * 2.6, 1.05).set_delay(0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_animation.tween_property(flash_light, "light_energy", 1.85, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_animation.tween_property(flash_light, "light_energy", 0.0, 0.85).set_delay(0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_animation.chain().tween_interval(0.12)
	_animation.chain().tween_callback(_finish)


func is_playing() -> bool:
	return visible and _animation != null and _animation.is_running()


func _reset_visuals() -> void:
	burst.scale = BASE_BURST_SCALE
	burst.modulate = Color(1.0, 0.89, 0.48, 0.94)
	level_label.position = BASE_LABEL_POSITION
	level_label.modulate = Color(1.0, 0.9, 0.48, 1.0)
	reward_label.position = Vector3(0.0, 1.85, 0.0)
	reward_label.modulate = Color(1.0, 0.97, 0.82, 1.0)
	halo_one.scale = Vector3.ONE * 0.18
	halo_two.scale = Vector3.ONE * 0.12
	flash_light.light_energy = 0.0
	sparkles.emitting = false


func _finish() -> void:
	visible = false
	celebration_finished.emit()

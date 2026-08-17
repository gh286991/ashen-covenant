class_name CombatFeedback3D
extends Node3D

## World-space damage numbers with a small pop, upward drift, and fade-out.

const FLOAT_DISTANCE := 0.62
const FLOAT_DURATION := 0.7
const POP_DURATION := 0.13
const POP_SCALE := 1.18


func show_damage(world_position: Vector3, amount: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = str(maxi(1, roundi(amount)))
	label.font_size = 48
	label.pixel_size = 0.004
	label.outline_size = 9
	label.outline_modulate = Color(0.015, 0.01, 0.02, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	label.position = world_position + Vector3(0.0, 0.34, 0.0)
	label.scale = Vector3.ONE * 0.72
	add_child(label)

	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + FLOAT_DISTANCE, FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * POP_SCALE, POP_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE, 0.12).set_delay(POP_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION - 0.15).set_delay(0.15)
	tween.finished.connect(label.queue_free)

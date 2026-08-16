@tool
class_name DungeonMapFeature
extends Node2D

enum FeatureType { SOUL_ANCHOR, SPIKE_TRAP, SHORTCUT_GATE, BOSS_GATE }

const SOUL_ANCHOR_TEXTURE := preload("res://assets/props/soul_anchor/single-1.png")
const IRON_FENCE_TEXTURE := preload("res://assets/old_prison/runtime/prison_gate.png")
const SPIKE_TRAP_TEXTURE := preload("res://assets/old_prison/runtime/pit_spike.png")

@export_category("Feature")
@export var feature_type: FeatureType = FeatureType.SOUL_ANCHOR:
	set(value):
		feature_type = value
		queue_redraw()
@export var feature_id: StringName = &"feature"
@export var linked_anchor_id: StringName = &""

@export_category("Layout")
@export var render_size := Vector2(96, 96):
	set(value):
		render_size = value
		queue_redraw()
@export var trigger_offset := Vector2.ZERO
@export var trigger_size := Vector2.ZERO
@export var target_position := Vector2.ZERO
@export var collision_offset := Vector2.ZERO
@export var collision_size := Vector2.ZERO

@export_category("Gameplay")
@export var max_health := 100.0
@export var damage := 12.0
@export var period := 1.0
@export var radius := 44.0

var anchor_health := 100.0
var anchor_alive := true
var gate_open := false
var elapsed := 0.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
	anchor_health = max_health
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	elapsed += delta

func reset_runtime_state() -> void:
	anchor_health = max_health
	anchor_alive = true
	gate_open = false
	queue_redraw()

func set_anchor_state(health: float, alive: bool) -> void:
	anchor_health = health
	anchor_alive = alive
	queue_redraw()

func set_gate_open(value: bool) -> void:
	gate_open = value
	queue_redraw()

func anchor_data() -> Dictionary:
	return {
		"id": feature_id,
		"position": global_position,
		"max_health": max_health,
		"health": anchor_health,
		"alive": anchor_alive
	}

func hazard_data() -> Dictionary:
	return {
		"id": feature_id,
		"x": global_position.x,
		"y": global_position.y,
		"radius": radius,
		"damage": damage,
		"period": period
	}

func shortcut_data() -> Dictionary:
	return {
		"id": feature_id,
		"anchor": String(linked_anchor_id),
		"trigger": {
			"x": global_position.x + trigger_offset.x,
			"y": global_position.y + trigger_offset.y,
			"w": trigger_size.x,
			"h": trigger_size.y
		},
		"target": {"x": target_position.x, "y": target_position.y},
		"gatePosition": {"x": global_position.x, "y": global_position.y},
		"renderSize": {"w": render_size.x, "h": render_size.y}
	}

func boss_gate_data() -> Dictionary:
	return {
		"id": feature_id,
		"x": global_position.x + collision_offset.x,
		"y": global_position.y + collision_offset.y,
		"w": collision_size.x,
		"h": collision_size.y,
		"position": {"x": global_position.x, "y": global_position.y},
		"renderSize": {"w": render_size.x, "h": render_size.y}
	}

func _draw() -> void:
	match feature_type:
		FeatureType.SOUL_ANCHOR:
			_draw_soul_anchor()
		FeatureType.SPIKE_TRAP:
			_draw_spike_trap()
		FeatureType.SHORTCUT_GATE:
			_draw_shortcut_gate()
		FeatureType.BOSS_GATE:
			_draw_boss_gate()

func _draw_soul_anchor() -> void:
	var hp_ratio := anchor_health / maxf(1.0, max_health)
	if anchor_alive:
		draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.35, 0.48))
		draw_circle(Vector2.ZERO, 44.0, Color(0.0, 0.0, 0.0, 0.52))
		draw_set_transform(Vector2.ZERO)
		draw_circle(Vector2.ZERO, 42.0, Color(0.45, 0.06, 0.16, 0.12))
		draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 6, Color("a73253"), 4.0)
		draw_texture_rect(SOUL_ANCHOR_TEXTURE, Rect2(-Vector2(64, 113), Vector2(128, 128)), false, Color.WHITE)
		draw_rect(Rect2(-Vector2(45, -30), Vector2(90, 7)), Color("1b141c"))
		draw_rect(Rect2(Vector2(-44, 31), Vector2(88 * hp_ratio, 5)), Color("d43d5c"))
	else:
		for i in 7:
			var angle := TAU * float(i) / 7.0
			draw_colored_polygon(PackedVector2Array([Vector2.from_angle(angle) * 12.0, Vector2.from_angle(angle + 0.2) * 32.0, Vector2.from_angle(angle - 0.2) * 25.0]), Color("4c3239"))

func _draw_spike_trap() -> void:
	draw_texture_rect(SPIKE_TRAP_TEXTURE, Rect2(-Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)), false, Color(0.78, 0.76, 0.78, 0.78))
	draw_arc(Vector2.ZERO, radius + 5.0, 0.0, TAU, 28, Color(0.72, 0.13, 0.18, 0.36), 2.0)

func _draw_shortcut_gate() -> void:
	var rect := Rect2(Vector2(-render_size.x * 0.5, -render_size.y), render_size)
	if gate_open:
		draw_arc(Vector2(0, -15), 34.0, 0.0, TAU, 30, Color(0.40, 0.55, 0.82, 0.38), 3.0)
		return
	draw_texture_rect(IRON_FENCE_TEXTURE, rect, false, Color(0.74, 0.61, 0.64, 0.96))
	draw_circle(Vector2(0, -render_size.y * 0.35), 28.0, Color(0.55, 0.05, 0.12, 0.12))

func _draw_boss_gate() -> void:
	if gate_open:
		draw_arc(Vector2(0, -28), 58.0, PI, TAU, 34, Color(0.85, 0.31, 0.17, 0.26), 5.0)
		return
	var rect := Rect2(Vector2(-render_size.x * 0.5, -render_size.y), render_size)
	draw_texture_rect(IRON_FENCE_TEXTURE, rect, false, Color(0.80, 0.54, 0.58, 1.0))
	draw_rect(Rect2(-Vector2(104, -5), Vector2(208, 7)), Color("160e16"))
	draw_string(ThemeDB.fallback_font, Vector2(-86, 28), "SOUL GATE SEALED", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("c77b8e"))

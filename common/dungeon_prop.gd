@tool
class_name DungeonProp
extends Node2D

const TEXTURES := {
	"closed-chest": preload("res://assets/props/dungeon/closed-chest/prop.png"),
	"open-chest": preload("res://assets/props/dungeon/open-chest/prop.png"),
	"sarcophagus": preload("res://assets/props/dungeon/sarcophagus/prop.png"),
	"ritual-brazier": preload("res://assets/props/dungeon/ritual-brazier/prop.png"),
	"funerary-urns": preload("res://assets/props/dungeon/funerary-urns/prop.png"),
	"bone-pile": preload("res://assets/props/dungeon/bone-pile/prop.png"),
	"collapsed-column": preload("res://assets/props/dungeon/collapsed-column/prop.png"),
}

@export_category("Dungeon Prop")
@export var prop_id: StringName = &"prop"
@export_enum("Decoration", "Chest", "Breakable") var gameplay_role := "Decoration"
@export var prop_kind := "funerary-urns":
	set(value):
		prop_kind = value
		queue_redraw()
@export var render_size := Vector2(80, 80):
	set(value):
		render_size = value
		queue_redraw()
@export var blocker_offset := Vector2.ZERO
@export var blocker_size := Vector2.ZERO
var opened := false
var destroyed := false
var highlight := false
var elapsed := 0.0

func setup(data: Dictionary) -> DungeonProp:
	prop_id = StringName(String(data.get("id", "prop")))
	prop_kind = String(data.get("kind", "closed-chest"))
	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	render_size = Vector2(float(data.get("w", 80.0)), float(data.get("h", 80.0)))
	opened = bool(data.get("opened", false))
	return self

func _ready() -> void:
	queue_redraw()

func reset_runtime_state() -> void:
	opened = false
	destroyed = false
	highlight = false
	visible = true
	queue_redraw()

func gameplay_data() -> Dictionary:
	var data := {
		"id": String(prop_id),
		"kind": prop_kind,
		"x": global_position.x,
		"y": global_position.y,
		"w": render_size.x,
		"h": render_size.y
	}
	if blocker_size.x > 0.0 and blocker_size.y > 0.0:
		data["blocker"] = {
			"x": global_position.x + blocker_offset.x,
			"y": global_position.y + blocker_offset.y,
			"w": blocker_size.x,
			"h": blocker_size.y
		}
	return data

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	elapsed += delta
	if prop_kind == "ritual-brazier" or highlight:
		queue_redraw()

func set_opened(value: bool) -> void:
	opened = value
	highlight = false
	queue_redraw()

func set_destroyed(value: bool) -> void:
	destroyed = value
	visible = not destroyed
	queue_redraw()

func _draw() -> void:
	if destroyed:
		return
	var texture_key := "open-chest" if prop_kind == "closed-chest" and opened else prop_kind
	var texture: Texture2D = TEXTURES.get(texture_key)
	if texture == null:
		return
	if prop_kind not in ["bone-pile", "collapsed-column"]:
		draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.25, 0.38))
		draw_circle(Vector2.ZERO, render_size.x * 0.30, Color(0, 0, 0, 0.34))
		draw_set_transform(Vector2.ZERO)
	draw_texture_rect(texture, Rect2(Vector2(-render_size.x * 0.5, -render_size.y), render_size), false, Color.WHITE)
	if prop_kind == "ritual-brazier":
		var glow := 18.0 + sin(elapsed * 7.0 + position.x * 0.01) * 3.0
		draw_circle(Vector2(0, -render_size.y * 0.72), glow, Color(1.0, 0.28, 0.06, 0.08))
	if highlight and not opened:
		draw_arc(Vector2(0, -render_size.y * 0.35), render_size.x * 0.58 + sin(elapsed * 4.0) * 3.0, 0.0, TAU, 28, Color(0.95, 0.72, 0.26, 0.6), 2.0)

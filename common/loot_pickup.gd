class_name LootPickup
extends Node2D

signal collected(pickup: LootPickup)

enum PickupKind { ITEM, GOLD, POTION }

var kind: PickupKind = PickupKind.GOLD
var item: LootItem
var amount: int = 1
var target: Node2D
var age := 0.0
var base_y := 0.0

func setup_item(value: LootItem, player: Node2D) -> LootPickup:
	kind = PickupKind.ITEM
	item = value
	target = player
	return self

func setup_currency(pickup_kind: PickupKind, value: int, player: Node2D) -> LootPickup:
	kind = pickup_kind
	amount = maxi(1, value)
	target = player
	return self

func _ready() -> void:
	base_y = position.y
	z_index = 8

func _physics_process(delta: float) -> void:
	age += delta
	queue_redraw()
	if not is_instance_valid(target):
		return
	var distance := global_position.distance_to(target.global_position)
	if distance < 150.0:
		global_position = global_position.move_toward(target.global_position, (190.0 + (150.0 - distance) * 5.0) * delta)
	if distance < 25.0:
		collected.emit(self)
		queue_free()

func pickup_color() -> Color:
	match kind:
		PickupKind.ITEM: return item.rarity_color() if item else Color.WHITE
		PickupKind.POTION: return Color("e54b63")
		_: return Color("f1c75b")

func _draw() -> void:
	var c := pickup_color()
	var bob := sin(age * 3.6) * 4.0
	if kind == PickupKind.ITEM:
		draw_line(Vector2(0, 15), Vector2(0, -48 - absf(sin(age * 2.0)) * 12.0), Color(c, 0.45), 4.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -10 + bob), Vector2(11, bob), Vector2(0, 10 + bob), Vector2(-11, bob)]), c)
	else:
		draw_circle(Vector2(0, bob), 9.0, c)
		draw_arc(Vector2(0, bob), 12.0, 0.0, TAU, 20, Color(c, 0.55), 2.0)


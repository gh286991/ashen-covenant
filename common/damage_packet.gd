class_name DamagePacket
extends RefCounted

enum DamageKind { PHYSICAL, ASH, VOID }

var amount: float
var source: Node
var origin: Vector2
var knockback: Vector2
var kind: DamageKind
var is_critical: bool

func _init(
	value: float,
	from: Node = null,
	from_position: Vector2 = Vector2.ZERO,
	push: Vector2 = Vector2.ZERO,
	damage_kind: DamageKind = DamageKind.PHYSICAL,
	critical: bool = false
) -> void:
	amount = maxf(1.0, value)
	source = from
	origin = from_position
	knockback = push
	kind = damage_kind
	is_critical = critical


class_name EnemyProjectile
extends Node2D

signal impacted(position: Vector2, color: Color)

var velocity := Vector2.ZERO
var damage := 12.0
var lifetime := 4.0
var target: Node2D
var projectile_color := Color("e25b77")
var radius := 9.0
var age := 0.0
var kind: DamagePacket.DamageKind = DamagePacket.DamageKind.VOID
var movement_filter: Callable

func setup(direction: Vector2, speed: float, value: float, player: Node2D, color: Color = Color("e25b77")) -> EnemyProjectile:
	velocity = direction.normalized() * speed
	damage = value
	target = player
	projectile_color = color
	return self

func _ready() -> void:
	z_index = 16

func _physics_process(delta: float) -> void:
	age += delta
	lifetime -= delta
	var previous_position := global_position
	global_position += velocity * delta
	queue_redraw()
	if movement_filter.is_valid() and not bool(movement_filter.call(previous_position, global_position, radius)):
		impacted.emit(global_position, projectile_color)
		queue_free()
		return
	if lifetime <= 0.0:
		queue_free()
		return
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= radius + 17.0:
		var push := velocity.normalized() * 150.0
		if target.has_method(&"take_damage"):
			target.call(&"take_damage", DamagePacket.new(damage, self, global_position, push, kind))
		impacted.emit(global_position, projectile_color)
		queue_free()

func _draw() -> void:
	var pulse := 1.0 + sin(age * 12.0) * 0.16
	draw_circle(-velocity.normalized() * 10.0, radius * 1.4, Color(projectile_color, 0.14))
	draw_circle(Vector2.ZERO, radius * pulse, projectile_color)
	draw_circle(Vector2.ZERO, radius * 0.45, Color("fff2dd"))

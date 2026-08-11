class_name CombatFX
extends Node2D

enum FXType { SLASH, NOVA, HIT, DEATH, ANCHOR, LEVEL_UP, TELEGRAPH, TEXT, PICKUP }

var fx_type: FXType = FXType.HIT
var fx_color := Color.WHITE
var duration := 0.45
var radius := 42.0
var text_value := ""
var elapsed := 0.0
var direction := Vector2.RIGHT
var swing_side := 1.0
var swing_intensity := 1.0

func setup(type: FXType, color: Color, life: float = 0.45, size: float = 42.0, label_text: String = "") -> CombatFX:
	fx_type = type
	fx_color = color
	duration = maxf(0.05, life)
	radius = size
	text_value = label_text
	z_index = 30
	return self

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var fade := 1.0 - t
	var c := fx_color
	c.a *= fade
	var fx_direction := direction.normalized()
	if fx_direction == Vector2.ZERO:
		fx_direction = Vector2.RIGHT
	match fx_type:
		FXType.SLASH:
			# A slash starts close to the weapon hand, sweeps across the target, then
			# exits quickly. This reads as a hit instead of a static arc on the floor.
			var swing_t := clampf(t * 1.34, 0.0, 1.0)
			swing_t = 1.0 - pow(1.0 - swing_t, 2.2)
			var side := 1.0 if swing_side >= 0.0 else -1.0
			var arc_span := 1.38 + swing_intensity * 0.20
			var start_angle := fx_direction.angle() - side * arc_span * 0.62
			var lead_angle := start_angle + side * arc_span * swing_t
			var tail_angle := lead_angle - side * (0.46 + (1.0 - swing_t) * 0.58)
			var pivot := fx_direction * radius * 0.12
			var reach := radius * lerpf(0.28, 0.98 + swing_intensity * 0.06, swing_t)
			var outer_points := PackedVector2Array()
			var inner_points := PackedVector2Array()
			for i in 12:
				var p := float(i) / 11.0
				var a := lerpf(tail_angle, lead_angle, p)
				var outer_reach := reach * (0.9 + sin(p * PI) * 0.1)
				outer_points.append(pivot + Vector2.from_angle(a) * outer_reach)
				inner_points.append(pivot + Vector2.from_angle(a) * maxf(0.0, outer_reach - radius * (0.105 + swing_intensity * 0.012)))
			var fade_out := clampf((1.0 - t) * 2.6, 0.0, 1.0)
			var glow := Color(c, c.a * 0.32 * fade_out)
			var edge := Color(1.0, 0.96, 0.84, minf(1.0, fade * 0.92) * fade_out)
			draw_polyline(outer_points, glow, (15.0 + swing_intensity * 2.0) * fade_out, true)
			draw_polyline(outer_points, c, (6.0 + swing_intensity) * fade_out, true)
			draw_polyline(inner_points, edge, 2.0 * fade_out, true)
			var tip := outer_points[outer_points.size() - 1]
			var tip_direction := Vector2.from_angle(lead_angle)
			draw_line(tip - tip_direction * radius * 0.10, tip + tip_direction * radius * 0.13, edge, 3.0 * fade_out)
			draw_circle(tip, (3.8 + swing_intensity) * fade_out, edge)
		FXType.NOVA:
			draw_arc(Vector2.ZERO, radius * (0.2 + t), 0.0, TAU, 64, c, 9.0 * fade, true)
			draw_arc(Vector2.ZERO, radius * (0.05 + t * 0.75), 0.0, TAU, 48, Color(c, c.a * 0.5), 3.0, true)
		FXType.HIT:
			var core_position := fx_direction * radius * 0.08
			draw_circle(core_position, radius * 0.42 * fade, Color(c, c.a * 0.22))
			draw_circle(core_position, radius * 0.2 * fade, Color(1.0, 0.96, 0.86, fade))
			draw_line(-fx_direction * radius * 0.18, fx_direction * radius * (0.42 + t * 0.72), Color(c, c.a * 0.38), 8.0 * fade)
			for i in 7:
				var spread := lerpf(-0.9, 0.9, float(i) / 6.0)
				var shard_direction := fx_direction.rotated(spread)
				var shard_length := radius * (0.48 + float((i * 3) % 4) * 0.13)
				var start := shard_direction * radius * (0.08 + t * 0.2)
				var finish := shard_direction * shard_length * (0.5 + t * 0.72)
				draw_line(start, finish, c, (4.0 if i == 3 else 2.6) * fade)
				if i % 2 == 0:
					draw_circle(finish, 2.8 * fade, Color(1.0, 0.92, 0.76, fade))
		FXType.DEATH:
			draw_circle(Vector2.ZERO, radius * (0.2 + t), Color(c, 0.18 * fade))
			for i in 8:
				var a := TAU * float(i) / 8.0 + 0.25
				draw_circle(Vector2.from_angle(a) * radius * t, 4.0 * fade, c)
		FXType.ANCHOR:
			draw_arc(Vector2.ZERO, radius * (0.35 + t), -PI * 0.5, PI * 1.5, 48, c, 6.0 * fade, true)
			for i in 6:
				var a := TAU * float(i) / 6.0 + elapsed * 3.0
				draw_circle(Vector2.from_angle(a) * radius * (0.4 + t * 0.8), 5.0 * fade, c)
		FXType.LEVEL_UP:
			for i in 12:
				var a := TAU * float(i) / 12.0
				draw_line(Vector2.from_angle(a) * radius * 0.2, Vector2.from_angle(a) * radius * (0.4 + t), c, 4.0 * fade)
		FXType.TELEGRAPH:
			draw_circle(Vector2.ZERO, radius, Color(c, 0.08 + 0.12 * sin(elapsed * 16.0)))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 56, c, 3.0, true)
		FXType.TEXT:
			var font := ThemeDB.fallback_font
			var size := 26 if radius < 50.0 else 34
			draw_string(font, Vector2(-font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5, -t * 48.0), text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
		FXType.PICKUP:
			draw_arc(Vector2.ZERO, radius * (0.4 + t), 0.0, TAU, 32, c, 4.0 * fade, true)

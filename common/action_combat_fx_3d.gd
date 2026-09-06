class_name ActionCombatFX3D
extends CombatFeedback3D

var _slash_shader: Shader


func _ready() -> void:
	pass


func show_slash(origin: Vector3, direction: Vector3, combo_step: int, heavy: bool, sweep_duration: float = -1.0) -> void:
	var step := clampi(combo_step, 1, 3)
	var colors := [Color("ffd15a"), Color("59d8ff"), Color("ff6338")]
	var outer_radii := [2.15, 2.35, 2.7]
	var arc_degrees := [112.0, 142.0, 176.0]
	var tint: Color = Color("ff351f") if heavy else colors[step - 1]
	var outer_radius: float = 3.0 if heavy else outer_radii[step - 1]
	var degrees: float = 200.0 if heavy else arc_degrees[step - 1]
	var inner_radius := 1.4 if heavy else 1.0
	var fallback_duration: float = 0.42 if heavy else [0.23, 0.16, 0.36][step - 1]
	var synced_duration := clampf(sweep_duration if sweep_duration > 0.0 else fallback_duration, 0.14, 0.58)

	# Broad, low-opacity afterimage gives volume without becoming a solid fan.
	_spawn_slash_layer(origin, direction, step, tint, inner_radius * 0.78, outer_radius + 0.16, degrees + 8.0, 0.18, 2.2, 0.4, 1.14, synced_duration * 1.12, 0.82)
	# Main ribbon fades from the hilt side toward its sharpened outer edge.
	_spawn_slash_layer(origin, direction, step, tint, inner_radius, outer_radius, degrees, 0.62, 3.8, 0.47, 1.0, synced_duration, 1.0)
	# A narrow near-white edge makes the sweep read as a fast blade.
	var edge_tint := tint.lerp(Color.WHITE, 0.72)
	_spawn_slash_layer(origin, direction, step, edge_tint, outer_radius - 0.09, outer_radius + 0.025, degrees - 4.0, 0.94, 6.5, 0.51, 1.04, synced_duration * 0.78, 1.16)


func _spawn_slash_layer(origin: Vector3, direction: Vector3, step: int, tint: Color, inner_radius: float, outer_radius: float, arc_degrees: float, opacity: float, glow: float, start_scale: float, end_scale: float, duration: float, sweep_multiplier: float) -> void:
	var arc := MeshInstance3D.new()
	arc.mesh = _build_arc_mesh(inner_radius, outer_radius, arc_degrees, 0.025, opacity)
	arc.material_override = _make_slash_material(Color(tint, 1.0), glow)
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(arc)
	arc.global_position = origin + Vector3.UP * (0.88 if step == 3 else 0.12 + step * 0.035)
	arc.rotation.y = atan2(direction.x, direction.z) + PI
	if step == 3:
		arc.rotation.x = PI * 0.5
		arc.rotation.z = -0.5
	arc.scale = Vector3.ONE * start_scale
	var tween := arc.create_tween()
	tween.set_parallel(true)
	tween.tween_property(arc, ^"scale", Vector3.ONE * end_scale, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if step == 3:
		tween.tween_property(arc, ^"rotation:z", 0.38 * sweep_multiplier, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	else:
		var sweep := (-0.52 if step == 2 else 0.4) * sweep_multiplier
		tween.tween_property(arc, ^"rotation:y", arc.rotation.y + sweep, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(arc, ^"transparency", 1.0, duration * 0.72).set_delay(duration * 0.28)
	tween.finished.connect(arc.queue_free)


func show_dash(origin: Vector3, direction: Vector3) -> void:
	for index in range(4):
		var streak := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.035, 1.25 + index * 0.22)
		streak.mesh = box
		streak.material_override = _make_glow_material(Color("39c8ff"), 4.0)
		add_child(streak)
		streak.global_position = origin - direction * (0.35 + index * 0.18) + Vector3((index - 1.5) * 0.12, 0.02, 0.0)
		streak.rotation.y = atan2(direction.x, direction.z)
		var tween := streak.create_tween()
		tween.set_parallel(true)
		tween.tween_property(streak, "global_position", streak.global_position - direction * 0.8, 0.18)
		tween.tween_property(streak, "transparency", 1.0, 0.22).set_delay(index * 0.012)
		tween.finished.connect(streak.queue_free)


func show_hit(position: Vector3, direction: Vector3 = Vector3.FORWARD, combo_step: int = 1, heavy: bool = false, defeated: bool = false) -> void:
	var step := clampi(combo_step, 1, 3)
	var step_colors := [Color("ffd45a"), Color("63dcff"), Color("ff5435")]
	var color: Color = Color("fff0c2") if defeated else (Color("ff3b24") if heavy else step_colors[step - 1])
	var impact_direction := direction.normalized() if direction.length_squared() > 0.01 else Vector3.FORWARD
	_spawn_impact_core(position, color, heavy, defeated)
	_spawn_impact_ring(position, impact_direction, color, heavy, defeated)
	_spawn_ground_shards(position, impact_direction, color, heavy or defeated)
	for index in range(14 if heavy or defeated else 7 + step * 2):
		var spark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.028, 0.028, (0.46 if heavy else 0.27 + step * 0.045) * randf_range(0.72, 1.18))
		spark.mesh = box
		spark.material_override = _make_glow_material(color.lerp(Color.WHITE, randf_range(0.0, 0.45)), 6.5 if heavy else 5.2)
		add_child(spark)
		spark.global_position = position
		spark.rotation = Vector3(randf_range(-0.8, 0.8), randf_range(0.0, TAU), randf_range(-0.4, 0.4))
		var scatter := Vector3(randf_range(-0.72, 0.72), randf_range(0.12, 0.92), randf_range(-0.72, 0.72))
		var spark_direction := (impact_direction * randf_range(0.48, 1.0) + scatter).normalized()
		var tween := spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", position + spark_direction * (1.28 if heavy or defeated else 0.62 + step * 0.12), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "transparency", 1.0, 0.2).set_delay(0.04)
		tween.finished.connect(spark.queue_free)


func _spawn_impact_core(position: Vector3, color: Color, heavy: bool, defeated: bool) -> void:
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	sphere.radial_segments = 12
	sphere.rings = 6
	core.mesh = sphere
	core.material_override = _make_glow_material(color.lerp(Color.WHITE, 0.72), 9.0 if heavy or defeated else 7.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	core.global_position = position
	core.scale = Vector3.ONE * 0.12
	var tween := core.create_tween()
	tween.set_parallel(true)
	tween.tween_property(core, ^"scale", Vector3.ONE * (3.2 if heavy or defeated else 2.25), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, ^"transparency", 1.0, 0.13).set_delay(0.025)
	tween.finished.connect(core.queue_free)


func _spawn_impact_ring(position: Vector3, direction: Vector3, color: Color, heavy: bool, defeated: bool) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.205
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _make_glow_material(color, 7.5 if heavy or defeated else 5.8)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = position
	ring.look_at(position + direction, Vector3.UP)
	ring.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	ring.scale = Vector3.ONE * 0.2
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, ^"scale", Vector3.ONE * (5.2 if heavy or defeated else 3.5), 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, ^"transparency", 1.0, 0.18).set_delay(0.025)
	tween.finished.connect(ring.queue_free)


func _spawn_ground_shards(position: Vector3, direction: Vector3, color: Color, strong: bool) -> void:
	var ground_position := Vector3(position.x, 0.075, position.z)
	for index in range(6 if strong else 3):
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.055, randf_range(0.12, 0.24), randf_range(0.16, 0.32))
		shard.mesh = box
		shard.material_override = _make_glow_material(color.darkened(0.18), 3.4)
		add_child(shard)
		var side := direction.cross(Vector3.UP).normalized() * randf_range(-0.75, 0.75)
		var travel := (direction * randf_range(0.15, 0.65) + side).normalized()
		shard.global_position = ground_position + travel * randf_range(0.08, 0.25)
		shard.rotation = Vector3(randf_range(-0.4, 0.4), randf_range(0.0, TAU), randf_range(-0.35, 0.35))
		var destination := shard.global_position + travel * randf_range(0.35, 0.72) + Vector3.UP * randf_range(0.1, 0.32)
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, ^"global_position", destination, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, ^"scale", Vector3(0.2, 0.2, 0.2), 0.26).set_delay(0.06)
		tween.tween_property(shard, ^"transparency", 1.0, 0.18).set_delay(0.1)
		tween.finished.connect(shard.queue_free)


func show_damage(position: Vector3, amount: float, heavy_or_color: Variant = false) -> void:
	var color := Color("ffe07a")
	if heavy_or_color is Color:
		color = heavy_or_color as Color
	elif heavy_or_color is bool and heavy_or_color:
		color = Color("ff7448")
	super.show_damage(position, amount, color)


func show_perfect_dodge(position: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _make_glow_material(Color("55e8ff"), 6.0)
	add_child(ring)
	ring.global_position = position - Vector3.UP * 0.62
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 3.8, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "transparency", 1.0, 0.28).set_delay(0.03)
	tween.finished.connect(ring.queue_free)
	show_callout(position + Vector3.UP * 0.8, "完美閃避", Color("62efff"))


func show_callout(position: Vector3, text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 54
	label.pixel_size = 0.006
	label.outline_size = 10
	label.outline_modulate = Color(0.01, 0.015, 0.03, 0.95)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = color
	add_child(label)
	label.global_position = position
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", position.y + 0.9, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * 1.2, 0.13).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.32)
	tween.finished.connect(label.queue_free)


func _build_arc_mesh(inner_radius: float, outer_radius: float, arc_degrees: float, inner_alpha: float, outer_alpha: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	var segments := 36
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var progress0 := float(index) / segments
		var progress1 := float(index + 1) / segments
		var a0 := lerpf(-half_arc, half_arc, progress0)
		var a1 := lerpf(-half_arc, half_arc, progress1)
		var end_fade0 := pow(maxf(0.0, sin(PI * progress0)), 0.58)
		var end_fade1 := pow(maxf(0.0, sin(PI * progress1)), 0.58)
		var inner0 := Vector3(sin(a0) * inner_radius, 0.0, -cos(a0) * inner_radius)
		var outer0 := Vector3(sin(a0) * outer_radius, 0.0, -cos(a0) * outer_radius)
		var inner1 := Vector3(sin(a1) * inner_radius, 0.0, -cos(a1) * inner_radius)
		var outer1 := Vector3(sin(a1) * outer_radius, 0.0, -cos(a1) * outer_radius)
		mesh.surface_set_color(Color(1.0, 1.0, 1.0, inner_alpha * end_fade0))
		mesh.surface_add_vertex(inner0)
		mesh.surface_set_color(Color(1.0, 1.0, 1.0, outer_alpha * end_fade0))
		mesh.surface_add_vertex(outer0)
		mesh.surface_set_color(Color(1.0, 1.0, 1.0, outer_alpha * end_fade1))
		mesh.surface_add_vertex(outer1)
		mesh.surface_set_color(Color(1.0, 1.0, 1.0, inner_alpha * end_fade0))
		mesh.surface_add_vertex(inner0)
		mesh.surface_set_color(Color(1.0, 1.0, 1.0, outer_alpha * end_fade1))
		mesh.surface_add_vertex(outer1)
		mesh.surface_set_color(Color(1.0, 1.0, 1.0, inner_alpha * end_fade1))
		mesh.surface_add_vertex(inner1)
	mesh.surface_end()
	return mesh


func _make_slash_material(tint: Color, glow: float) -> ShaderMaterial:
	if _slash_shader == null:
		_slash_shader = Shader.new()
		_slash_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0);
uniform float glow = 4.0;

void fragment() {
	vec4 energy = tint * COLOR;
	ALBEDO = energy.rgb;
	EMISSION = energy.rgb * glow;
	ALPHA = energy.a;
}
"""
	var material := ShaderMaterial.new()
	material.shader = _slash_shader
	material.set_shader_parameter(&"tint", tint)
	material.set_shader_parameter(&"glow", glow)
	return material


func _make_glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

class_name Warrior3DVisual
extends Node2D

const MODEL_PATH := "res://assets/models/animated/fantasy_warrior_gameplay_head_level.glb"
const VIEWPORT_SIZE := Vector2i(512, 512)
const DISPLAY_SCALE := 0.25
# The player uses the requested 128x128 gameplay footprint while keeping
# the rendered boots aligned with the CharacterBody2D origin.
const DISPLAY_OFFSET := Vector2(0.0, -24.0)
const FRONT_TARGET := Vector3(0.0, 0.72, 0.0)

var _viewport: SubViewport
var _pivot: Node3D
var _animation_player: AnimationPlayer
var _display: Sprite2D
var _active_animation := StringName()
var _available := false

func _ready() -> void:
	_build_viewport()
	_available = _build_model()

func is_available() -> bool:
	return _available

func get_display_sprite() -> Sprite2D:
	return _display

func set_animation_state(state: StringName, facing: Vector2) -> void:
	if not _available:
		return
	if facing.length_squared() > 0.001:
		# The viewport's camera reverses the vertical screen axis relative to the
		# model's ground plane. Keep horizontal mapping, but swap up/down here.
		_pivot.rotation.y = atan2(facing.x, facing.y)
	var animation_name := _resolve_animation(state)
	if animation_name.is_empty() or animation_name == _active_animation:
		return
	_animation_player.play(animation_name, 0.08)
	_active_animation = animation_name

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "Warrior3DViewport"
	_viewport.size = VIEWPORT_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.world_3d = World3D.new()
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.82, 0.86, 1.0)
	environment.ambient_light_energy = 0.78
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	_pivot = Node3D.new()
	_pivot.name = "WarriorPivot"
	_viewport.add_child(_pivot)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = 1.6
	key_light.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	_viewport.add_child(key_light)
	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_color = Color(0.63, 0.72, 1.0)
	fill_light.light_energy = 0.45
	fill_light.rotation_degrees = Vector3(-28.0, 145.0, 0.0)
	_viewport.add_child(fill_light)

	var camera := Camera3D.new()
	camera.name = "WarriorCamera"
	camera.position = Vector3(1.7, 1.28, 3.65)
	camera.fov = 26.0
	camera.near = 0.01
	_viewport.add_child(camera)
	camera.look_at(FRONT_TARGET, Vector3.UP)
	camera.current = true

	_display = Sprite2D.new()
	_display.name = "Warrior3DDisplay"
	_display.texture = _viewport.get_texture()
	_display.position = DISPLAY_OFFSET
	_display.scale = Vector2.ONE * DISPLAY_SCALE
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_display)

func _build_model() -> bool:
	# Parse the GLB directly so a fresh project can use the model before Godot's
	# editor-side importer has generated its cached PackedScene.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var load_error := document.append_from_file(MODEL_PATH, state)
	if load_error != OK:
		push_warning("3D warrior GLB could not be parsed: %s" % MODEL_PATH)
		return false
	var warrior := document.generate_scene(state) as Node3D
	if warrior == null:
		push_warning("3D warrior GLB did not generate a Node3D scene")
		return false
	warrior.name = "FantasyWarrior"
	_pivot.add_child(warrior)
	_animation_player = warrior.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player == null:
		push_warning("3D warrior GLB has no AnimationPlayer")
		return false
	for looping_animation in [&"Idle", &"Walk", &"Run"]:
		var resolved := _resolve_animation(looping_animation)
		if not resolved.is_empty():
			var clip := _animation_player.get_animation(resolved)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
	set_animation_state(&"Idle", Vector2.UP)
	return true

func _resolve_animation(requested: StringName) -> StringName:
	if _animation_player == null:
		return StringName()
	if _animation_player.has_animation(requested):
		return requested
	var expected := String(requested).to_lower()
	for candidate in _animation_player.get_animation_list():
		var normalized := String(candidate).to_lower()
		if normalized == expected or normalized.begins_with(expected + "."):
			return candidate
	return StringName()

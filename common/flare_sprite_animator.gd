class_name FlareSpriteAnimator
extends Node2D

## Renders the packed, directional sprite sheets shipped with Flare's bestiary.
## The source data already describes every cropped frame and its foot anchor, so
## this node keeps the original animation fidelity instead of flattening it into
## a single idle portrait.

var sprite: Sprite2D

var _frames_by_action: Dictionary = {}
var _action_durations: Dictionary = {}
var _action_loops: Dictionary = {}
var _sheet_paths: Dictionary = {}
var _sheet_textures: Dictionary = {}
var _current_action: StringName = &""
var _current_direction := 0
var _elapsed := 0.0


func setup(definition_path: String, source_root: String, display_scale: float) -> void:
	_ensure_sprite()
	scale = Vector2.ONE * display_scale
	_parse_definition(definition_path, source_root)
	set_animation(&"stance", Vector2.DOWN, 0.0)


func fit_to_max_dimension(target_size: float) -> void:
	var max_dimension := _max_idle_frame_dimension()
	if max_dimension <= 0.0:
		return
	var fitted_scale := target_size / max_dimension
	if fitted_scale < scale.x:
		scale = Vector2.ONE * fitted_scale


func _max_idle_frame_dimension() -> float:
	var max_dimension := 0.0
	for action in [&"stance", &"run"]:
		var directions: Dictionary = _frames_by_action.get(action, {})
		for frame_list_variant in directions.values():
			var frame_list: Array = frame_list_variant
			for frame_variant in frame_list:
				var frame_texture := (frame_variant as Dictionary).get("texture") as Texture2D
				if frame_texture != null:
					var frame_size := frame_texture.get_size()
					max_dimension = maxf(max_dimension, maxf(frame_size.x, frame_size.y))
	return max_dimension


func set_animation(requested_action: StringName, facing: Vector2, delta: float, desired_duration: float = 0.0) -> void:
	var action := _resolve_action(requested_action)
	var direction := _direction_for(facing)
	if action != _current_action:
		_current_action = action
		_elapsed = 0.0
	_current_direction = direction
	var source_duration := float(_action_durations.get(_current_action, 0.4))
	var speed_scale := source_duration / desired_duration if desired_duration > 0.001 else 1.0
	_elapsed += maxf(0.0, delta) * speed_scale
	_apply_current_frame()


func current_animation() -> StringName:
	return _current_action


func current_direction() -> int:
	return _current_direction


func _ensure_sprite() -> void:
	if is_instance_valid(sprite):
		return
	sprite = Sprite2D.new()
	sprite.name = "ArtSprite"
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)


func _parse_definition(definition_path: String, source_root: String) -> void:
	var file := FileAccess.open(definition_path, FileAccess.READ)
	if file == null:
		push_error("Could not load Flare animation definition: %s" % definition_path)
		return
	var current_action: StringName = &""
	for raw_line in file.get_as_text().split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("image="):
			_register_sheet(line.trim_prefix("image="), source_root)
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current_action = StringName(line.trim_prefix("[").trim_suffix("]"))
			_frames_by_action[current_action] = {}
			continue
		if current_action == &"":
			continue
		if line.begins_with("duration="):
			_action_durations[current_action] = _duration_from_line(line)
			continue
		if line.begins_with("type="):
			_action_loops[current_action] = line.trim_prefix("type=") != "play_once"
			continue
		if line.begins_with("frame="):
			_register_frame(current_action, line.trim_prefix("frame="))
	for action: StringName in _frames_by_action:
		var directions: Dictionary = _frames_by_action[action]
		for direction: int in directions:
			var frames: Array = directions[direction]
			frames.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.index) < int(b.index))
			if not _action_durations.has(action):
				_action_durations[action] = 0.4
			if not _action_loops.has(action):
				_action_loops[action] = true


func _register_sheet(source: String, source_root: String) -> void:
	var parts := source.split(",", false, 1)
	var source_path := parts[0]
	var alias: StringName = StringName(parts[1]) if parts.size() > 1 else &"default"
	var local_path := source_path.trim_prefix("images/enemies/")
	_sheet_paths[alias] = source_root.path_join(local_path)


func _register_frame(action: StringName, source: String) -> void:
	var values := source.split(",", false)
	if values.size() < 8:
		return
	var sequence_index := int(values[0])
	var direction_index := int(values[1])
	var sheet_alias: StringName = StringName(values[8]) if values.size() > 8 else &"default"
	var image_path := String(_sheet_paths.get(sheet_alias, ""))
	if image_path.is_empty():
		image_path = String(_sheet_paths.get(&"default", ""))
	if image_path.is_empty():
		push_error("Flare frame is missing an image sheet for %s" % action)
		return
	var texture := _get_sheet_texture(image_path)
	if texture == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(float(values[2]), float(values[3]), float(values[4]), float(values[5]))
	var directions: Dictionary = _frames_by_action.get(action, {})
	var frames: Array = directions.get(direction_index, [])
	frames.append({
		"index": sequence_index,
		"texture": atlas,
		"anchor": Vector2(float(values[6]), float(values[7])),
	})
	directions[direction_index] = frames
	_frames_by_action[action] = directions


func _get_sheet_texture(image_path: String) -> Texture2D:
	if _sheet_textures.has(image_path):
		return _sheet_textures[image_path] as Texture2D
	var texture := load(image_path) as Texture2D
	if texture == null:
		push_error("Could not load Flare sprite sheet: %s" % image_path)
		return null
	_sheet_textures[image_path] = texture
	return texture


func _duration_from_line(line: String) -> float:
	var raw_value := line.trim_prefix("duration=").trim_suffix("ms")
	return maxf(0.001, float(raw_value) / 1000.0)


func _resolve_action(requested_action: StringName) -> StringName:
	if _frames_by_action.has(requested_action):
		return requested_action
	if _frames_by_action.has(&"stance"):
		return &"stance"
	for action: StringName in _frames_by_action:
		return action
	return &""


func _direction_for(facing: Vector2) -> int:
	if facing.length_squared() <= 0.001:
		return _current_direction
	# Godot's sectors begin at east and advance clockwise (E, SE, S ...).
	# Flare's packed sheets begin at southwest (SW, W, NW, N, NE, E, SE, S).
	# Their offset is five sectors, so converting the movement vector avoids
	# selecting the rear-facing frame while an enemy advances.
	return posmod(roundi(facing.angle() / (TAU / 8.0)) + 5, 8)


func _apply_current_frame() -> void:
	if _current_action == &"" or not is_instance_valid(sprite):
		return
	var directions: Dictionary = _frames_by_action.get(_current_action, {})
	var frames: Array = directions.get(_current_direction, [])
	if frames.is_empty():
		frames = directions.get(0, [])
	if frames.is_empty():
		return
	var duration := float(_action_durations.get(_current_action, 0.4))
	var looping := bool(_action_loops.get(_current_action, true))
	var progress := fposmod(_elapsed, duration) / duration if looping else clampf(_elapsed / duration, 0.0, 0.99999)
	var frame_index := mini(int(floor(progress * frames.size())), frames.size() - 1)
	var frame: Dictionary = frames[frame_index]
	sprite.texture = frame.texture as Texture2D
	sprite.position = -(frame.anchor as Vector2)

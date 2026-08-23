class_name AshenDungeon3D
extends Node3D

const AudioDirectorScript := preload("res://common/audio_director.gd")
const DungeonStatusBarsScript := preload("res://ui/dungeon_status_bars_3d.gd")

const CAMERA_OFFSET := Vector3(6.0, 10.0, 6.0)
const CAMERA_PITCH := -47.0
const CAMERA_YAW := 45.0
const CAMERA_FOLLOW_SPEED := 12.0
const CAMERA_SNAP_DISTANCE := 6.0
const CAMERA_ZOOM_MIN_DISTANCE := 5.5
const CAMERA_ZOOM_MAX_DISTANCE := 22.0
const CAMERA_ZOOM_STEP := 1.25
const CAMERA_ZOOM_SMOOTH_SPEED := 14.0

@onready var player: DungeonPlayer3D = %Player
@onready var camera: Camera3D = %Camera3D
@onready var door_prompt: Label = %DoorPrompt
@onready var player_health_label: Label = %PlayerHealthLabel
@onready var player_health_bar: ProgressBar = %PlayerHealthBar
@onready var combat_feedback: CombatFeedback3D = %CombatFeedback3D
@onready var level_up_celebration: DungeonLevelUpCelebration3D = %LevelUpCelebration3D

var _prompt_owner: Node
var _camera_anchor := Vector3.ZERO
var _camera_distance := CAMERA_OFFSET.length()
var _camera_target_distance := CAMERA_OFFSET.length()
var audio: AshenAudioDirector


func _ready() -> void:
	_audio_setup()
	door_prompt.visible = false
	player_health_label.visible = false
	player_health_bar.visible = false
	var legacy_instructions := get_node_or_null("HUD/Instructions") as Control
	if legacy_instructions != null:
		legacy_instructions.visible = false
	if player != null:
		var jrpg_hud := get_node_or_null("HUD/JrpgHud")
		if jrpg_hud != null and jrpg_hud.has_method(&"setup"):
			jrpg_hud.call(&"setup", player.progression)
		if player.progression != null and not player.progression.leveled_up.is_connected(_on_player_leveled_up):
			player.progression.leveled_up.connect(_on_player_leveled_up)
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
		if not player.damaged.is_connected(_on_player_damaged):
			player.damaged.connect(_on_player_damaged)
		if not player.attack_started.is_connected(_on_player_attack_started):
			player.attack_started.connect(_on_player_attack_started)
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		_on_player_health_changed(player.health, player.max_health)
		var status_bars: Node3D = DungeonStatusBarsScript.new() as Node3D
		status_bars.name = "WorldStatusBars"
		# Offset equally on X/Z so the isometric camera keeps the bars centred
		# below the hero instead of drifting sideways on screen.
		status_bars.position = Vector3(0.72, -0.35, 0.72)
		player.add_child(status_bars)
		status_bars.call("setup", player)
	for monster_node in get_tree().get_nodes_in_group(&"dungeon_monsters"):
		var monster := monster_node as DungeonMonster3D
		if monster == null:
			continue
		if not monster.damaged.is_connected(_on_monster_damaged.bind(monster)):
			monster.damaged.connect(_on_monster_damaged.bind(monster))
		if not monster.attack_started.is_connected(_on_monster_attack_started):
			monster.attack_started.connect(_on_monster_attack_started)
		var died_callback := _on_monster_died.bind(monster)
		if not monster.died.is_connected(died_callback):
			monster.died.connect(died_callback)
	camera.current = true
	_camera_anchor = _get_player_horizontal_position()
	camera.global_position = _camera_anchor + _get_camera_offset()
	# The dungeon is a fixed top-down view. Keeping the pitch fixed prevents
	# tiny physics-floor corrections from becoming visible camera shake.
	camera.rotation_degrees = Vector3(CAMERA_PITCH, CAMERA_YAW, 0.0)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	var desired_anchor := _get_player_horizontal_position()
	if _camera_anchor.distance_to(desired_anchor) > CAMERA_SNAP_DISTANCE:
		_camera_anchor = desired_anchor
	else:
		var follow_weight := 1.0 - exp(-CAMERA_FOLLOW_SPEED * delta)
		_camera_anchor = _camera_anchor.lerp(desired_anchor, follow_weight)
	var zoom_weight := 1.0 - exp(-CAMERA_ZOOM_SMOOTH_SPEED * delta)
	_camera_distance = lerpf(_camera_distance, _camera_target_distance, zoom_weight)
	camera.global_position = _camera_anchor + _get_camera_offset()


func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(camera):
		return
	if event is not InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_camera_zoom(_camera_target_distance - CAMERA_ZOOM_STEP)
		get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_camera_zoom(_camera_target_distance + CAMERA_ZOOM_STEP)
		get_viewport().set_input_as_handled()


func _set_camera_zoom(distance: float) -> void:
	_camera_target_distance = clampf(
		distance,
		CAMERA_ZOOM_MIN_DISTANCE,
		CAMERA_ZOOM_MAX_DISTANCE
	)


func _get_camera_offset() -> Vector3:
	return CAMERA_OFFSET.normalized() * _camera_distance


func _get_player_horizontal_position() -> Vector3:
	return Vector3(player.global_position.x, 0.0, player.global_position.z)


func show_door_prompt(text: String, source_door: Node) -> void:
	_prompt_owner = source_door
	var jrpg_hud := get_node_or_null("HUD/JrpgHud")
	if jrpg_hud != null and jrpg_hud.has_method("show_door_prompt"):
		jrpg_hud.call("show_door_prompt", text)
		return
	door_prompt.text = text
	door_prompt.visible = true


func hide_door_prompt(source_door: Node) -> void:
	if source_door != _prompt_owner:
		return
	_prompt_owner = null
	var jrpg_hud := get_node_or_null("HUD/JrpgHud")
	if jrpg_hud != null and jrpg_hud.has_method("hide_door_prompt"):
		jrpg_hud.call("hide_door_prompt")
		return
	door_prompt.visible = false


func transition_player(spawn: Node3D, _door: Node) -> void:
	if audio != null:
		audio.play_transition()
	player.global_position = spawn.global_position
	player.velocity = Vector3.ZERO
	player.clear_move_target()
	_camera_anchor = _get_player_horizontal_position()
	camera.global_position = _camera_anchor + _get_camera_offset()


func _on_player_health_changed(current: float, maximum: float) -> void:
	player_health_bar.max_value = maximum
	player_health_bar.value = current
	player_health_label.text = "生命 %d / %d" % [roundi(current), roundi(maximum)]


func _on_player_damaged(amount: float, _source: Node) -> void:
	if audio != null:
		audio.play_heavy_hurt()
	combat_feedback.show_damage(player.global_position + Vector3(0.0, 0.88, 0.0), amount, Color("ff6b5f"))


func _on_monster_damaged(amount: float, _source: Node, monster: DungeonMonster3D) -> void:
	if audio != null:
		audio.play_heavy_hit()
	combat_feedback.show_damage(monster.global_position + Vector3(0.0, 0.92, 0.0), amount, Color("ffd166"))


func _on_player_attack_started(_direction: Vector3) -> void:
	if audio != null:
		audio.play_heavy_swing(false)


func _on_monster_attack_started(_direction: Vector3) -> void:
	if audio != null:
		audio.play_heavy_swing(true)


func _audio_setup() -> void:
	audio = AudioDirectorScript.new() as AshenAudioDirector
	audio.name = "AudioDirector"
	add_child(audio)
	audio.set_music_state(AshenAudioDirector.MusicState.EXPLORE)


func _on_monster_died(monster: DungeonMonster3D) -> void:
	if audio != null:
		audio.play_heavy_death()
	if player != null and player.progression != null and is_instance_valid(monster):
		player.progression.add_experience(monster.experience_reward)


func _on_player_leveled_up(new_level: int, attribute_points: int, skill_points: int) -> void:
	if audio != null:
		audio.play_level_up()
	if level_up_celebration != null:
		level_up_celebration.play(new_level, attribute_points, skill_points)


func _on_player_died() -> void:
	if audio != null:
		audio.play_defeat()

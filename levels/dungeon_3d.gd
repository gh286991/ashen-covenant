class_name AshenDungeon3D
extends Node3D

const AudioDirectorScript := preload("res://common/audio_director.gd")

const CAMERA_OFFSET := Vector3(6.0, 10.0, 6.0)
const CAMERA_PITCH := -47.0
const CAMERA_YAW := 45.0
const CAMERA_FOLLOW_SPEED := 12.0
const CAMERA_SNAP_DISTANCE := 6.0

@onready var player: DungeonPlayer3D = %Player
@onready var camera: Camera3D = %Camera3D
@onready var door_prompt: Label = %DoorPrompt
@onready var player_health_label: Label = %PlayerHealthLabel
@onready var player_health_bar: ProgressBar = %PlayerHealthBar
@onready var combat_feedback: CombatFeedback3D = %CombatFeedback3D

var _prompt_owner: Node
var _camera_anchor := Vector3.ZERO
var audio: AshenAudioDirector


func _ready() -> void:
	_audio_setup()
	door_prompt.visible = false
	if player != null:
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
		if not player.damaged.is_connected(_on_player_damaged):
			player.damaged.connect(_on_player_damaged)
		if not player.attack_started.is_connected(_on_player_attack_started):
			player.attack_started.connect(_on_player_attack_started)
		if not player.died.is_connected(_on_player_died):
			player.died.connect(_on_player_died)
		_on_player_health_changed(player.health, player.max_health)
	for monster_node in get_tree().get_nodes_in_group(&"dungeon_monsters"):
		var monster := monster_node as DungeonMonster3D
		if monster == null:
			continue
		if not monster.damaged.is_connected(_on_monster_damaged.bind(monster)):
			monster.damaged.connect(_on_monster_damaged.bind(monster))
		if not monster.attack_started.is_connected(_on_monster_attack_started):
			monster.attack_started.connect(_on_monster_attack_started)
		if not monster.died.is_connected(_on_monster_died):
			monster.died.connect(_on_monster_died)
	camera.current = true
	_camera_anchor = _get_player_horizontal_position()
	camera.global_position = _camera_anchor + CAMERA_OFFSET
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
	camera.global_position = _camera_anchor + CAMERA_OFFSET


func _get_player_horizontal_position() -> Vector3:
	return Vector3(player.global_position.x, 0.0, player.global_position.z)


func show_door_prompt(text: String, source_door: Node) -> void:
	_prompt_owner = source_door
	door_prompt.text = text
	door_prompt.visible = true


func hide_door_prompt(source_door: Node) -> void:
	if source_door != _prompt_owner:
		return
	_prompt_owner = null
	door_prompt.visible = false


func transition_player(spawn: Node3D, _door: Node) -> void:
	if audio != null:
		audio.play_transition()
	player.global_position = spawn.global_position
	player.velocity = Vector3.ZERO
	player.clear_move_target()
	_camera_anchor = _get_player_horizontal_position()
	camera.global_position = _camera_anchor + CAMERA_OFFSET


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


func _on_monster_died() -> void:
	if audio != null:
		audio.play_heavy_death()


func _on_player_died() -> void:
	if audio != null:
		audio.play_defeat()

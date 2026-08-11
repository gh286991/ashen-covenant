extends Node

const TARGET_SCENE: PackedScene = preload("res://levels/main.tscn")
const CAPTURE_DURATION := 18.5

var target: AshenCovenantGame
var player: CovenantPlayer
var elapsed := 0.0
var demo_started := false
var entry_cache_opened := false
var west_entered := false
var west_anchor_broken := false
var shortcut_used := false
var east_entered := false
var east_anchor_broken := false
var court_entered := false
var north_anchor_broken := false
var sanctum_entered := false
var boss_phase_two := false
var boss_defeated := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	seed(0xA55E2026)
	target = TARGET_SCENE.instantiate() as AshenCovenantGame
	add_child(target)
	player = target.get_node("Actors/Player") as CovenantPlayer

func _process(delta: float) -> void:
	elapsed += delta
	if not demo_started and elapsed >= 1.15:
		_begin_demo()
	if demo_started and not entry_cache_opened and elapsed >= 1.85:
		entry_cache_opened = true
		target._hit_interactables(Vector2(1010, 1185), 18.0)
	if not west_entered and elapsed >= 2.75:
		_enter_west_crypt()
	if west_entered and not west_anchor_broken and elapsed >= 4.85:
		west_anchor_broken = true
		_break_anchor("west")
	if west_anchor_broken and not shortcut_used and elapsed >= 5.75:
		_use_west_shortcut()
	if shortcut_used and not east_entered and elapsed >= 6.55:
		_enter_east_ossuary()
	if east_entered and not east_anchor_broken and elapsed >= 8.55:
		east_anchor_broken = true
		_break_anchor("east")
	if east_anchor_broken and not court_entered and elapsed >= 9.25:
		_enter_ritual_court()
	if court_entered and not north_anchor_broken and elapsed >= 10.15:
		north_anchor_broken = true
		_break_anchor("north")
	if north_anchor_broken and not sanctum_entered and elapsed >= 10.85:
		_enter_sanctum()
	if sanctum_entered and not boss_phase_two and elapsed >= 14.15:
		target.playtest_damage_boss(470.0)
		boss_phase_two = true
	if boss_phase_two and not boss_defeated and elapsed >= 16.25:
		target.playtest_damage_boss(99999.0)
		boss_defeated = true
	_drive_inputs()
	if elapsed >= CAPTURE_DURATION:
		_release_inputs()
		get_tree().quit(0)

func _begin_demo() -> void:
	demo_started = true
	target.start_new_game()
	player.base_max_health = 4000.0
	player.health = player.max_health()
	player.global_position = Vector2(1100, 1250)
	target._show_announcement("DESCEND INTO THE ASHEN CATACOMBS", Color("e49967"), 1.7)


func _enter_west_crypt() -> void:
	west_entered = true
	_release_inputs()
	player.global_position = Vector2(390, 770)
	player.health = player.max_health()
	target._update_exploration(0.1)


func _break_anchor(anchor_id: String) -> void:
	var anchor := target._anchor_by_id(anchor_id)
	if not anchor.is_empty():
		target._damage_anchor(anchor, float(anchor.get("health", 0.0)) + 1.0)


func _use_west_shortcut() -> void:
	shortcut_used = true
	_release_inputs()
	player.global_position = Vector2(460, 910)
	target.shortcut_cooldown = 0.0
	target._update_shortcuts()


func _enter_east_ossuary() -> void:
	east_entered = true
	_release_inputs()
	player.global_position = Vector2(1810, 770)
	player.health = player.max_health()
	target._update_exploration(0.1)


func _enter_ritual_court() -> void:
	court_entered = true
	_release_inputs()
	player.global_position = Vector2(1100, 735)
	player.health = player.max_health()
	target._update_exploration(0.1)


func _enter_sanctum() -> void:
	sanctum_entered = true
	_release_inputs()
	player.global_position = Vector2(1100, 365)
	player.facing = Vector2.UP
	player.last_move_direction = Vector2.UP
	player.health = player.max_health()
	target._update_exploration(0.1)

func _drive_inputs() -> void:
	_set_action(&"move_up", _between(1.30, 2.45) or _between(3.15, 4.45) or _between(7.05, 8.25) or _between(11.00, 12.00))
	_set_action(&"move_left", _between(1.30, 1.72) or _between(7.10, 7.85) or _between(12.75, 13.35))
	_set_action(&"move_right", _between(3.20, 3.95) or _between(9.38, 9.88) or _between(14.70, 15.28))
	_set_action(&"move_down", _between(4.10, 4.52) or _between(8.05, 8.35))
	_set_action(&"attack", _in_any_window([
		[1.72, 1.84], [2.12, 2.24],
		[3.18, 3.30], [3.62, 3.74], [4.10, 4.22],
		[7.10, 7.22], [7.55, 7.67], [8.00, 8.12],
		[9.52, 9.64],
		[11.58, 11.70], [12.10, 12.22], [12.66, 12.78], [13.30, 13.42], [14.52, 14.64], [15.16, 15.28]
	]))
	_set_action(&"skill_nova", _in_any_window([[4.32, 4.46], [7.82, 7.96], [9.72, 9.86], [12.95, 13.10], [15.45, 15.60]]))
	_set_action(&"dash", _in_any_window([[3.82, 3.96], [7.42, 7.56], [11.25, 11.40], [14.82, 14.96]]))

func _between(start: float, finish: float) -> bool:
	return elapsed >= start and elapsed < finish

func _in_any_window(windows: Array) -> bool:
	for window: Array in windows:
		if _between(float(window[0]), float(window[1])):
			return true
	return false

func _set_action(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _release_inputs() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right", &"attack", &"skill_nova", &"dash"]:
		Input.action_release(action)

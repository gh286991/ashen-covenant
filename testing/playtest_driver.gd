extends Node

const TARGET_SCENE: PackedScene = preload("res://levels/main.tscn")
const CAPTURE_DURATION := 23.0

var target: AshenCovenantGame
var elapsed := 0.0
var prepared_encounter := false
var level_triggered := false
var upgrade_chosen := false
var upgrade_seen_at := -1.0
var upgrade_count := 0
var boss_triggered := false
var boss_softened := false
var victory_triggered := false
var sheet_opened := false
var sheet_closed := false
var gate_collision_staged := false
var first_enemy_clicked := false
var second_enemy_clicked := false
var ground_clicked := false
var boss_clicked := false
var active_actions: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size = Vector2i(1280, 720)
	seed(0xA55E2026)
	target = TARGET_SCENE.instantiate() as AshenCovenantGame
	add_child(target)

func _process(delta: float) -> void:
	elapsed += delta
	_drive_playtest()
	if elapsed >= CAPTURE_DURATION:
		_release_inputs()
		print("[RECORDING] complete state=", JSON.stringify(target.get_playtest_state()))
		get_tree().quit(0)

func _drive_playtest() -> void:
	if elapsed >= 2.0 and target.phase == AshenCovenantGame.GamePhase.TITLE:
		target.start_new_game()
	if elapsed >= 2.1 and not prepared_encounter and target.phase == AshenCovenantGame.GamePhase.PLAYING:
		prepared_encounter = true
		target.player.global_position = Vector2(1100, 1090)
		var offsets := [Vector2(100, -20), Vector2(145, 68), Vector2(-115, 28), Vector2(20, -135)]
		for i in mini(offsets.size(), target.enemies.size()):
			target.enemies[i].global_position = target.player.global_position + offsets[i]

	_set_action(&"skill_nova", _pulse([4.28, 13.0, 17.65], 0.14))
	_set_action(&"dash", _pulse([4.72, 13.48, 16.2], 0.12))
	if elapsed >= 2.3 and prepared_encounter and not first_enemy_clicked:
		first_enemy_clicked = true
		_click_enemy(0)
	if elapsed >= 3.55 and first_enemy_clicked and not second_enemy_clicked:
		second_enemy_clicked = true
		_click_enemy(1)
	if elapsed >= 4.45 and second_enemy_clicked and not ground_clicked:
		ground_clicked = true
		target.issue_pointer_command(target.player.global_position + Vector2(-150, -70))

	if elapsed >= 5.15 and not level_triggered and target.phase == AshenCovenantGame.GamePhase.PLAYING:
		level_triggered = true
		var remaining := maxi(1, target.player.experience_required() - target.player.experience)
		target.player.add_experience(remaining)
	if target.phase == AshenCovenantGame.GamePhase.UPGRADE:
		if upgrade_seen_at < 0.0:
			upgrade_seen_at = elapsed
		var hold_time := 2.15 if upgrade_count == 0 else 0.65
		if elapsed - upgrade_seen_at >= hold_time:
			target.choose_upgrade("executioner" if upgrade_count % 2 == 0 else "iron_oath")
			upgrade_count += 1
			upgrade_chosen = true
			upgrade_seen_at = -1.0
	if elapsed >= 7.55 and upgrade_chosen and not sheet_opened:
		sheet_opened = true
		_send_ui_action(&"toggle_sheet")
	if elapsed >= 9.7 and sheet_opened and not sheet_closed:
		sheet_closed = true
		_send_ui_action(&"toggle_sheet")
	if elapsed >= 9.9 and sheet_closed and not gate_collision_staged:
		gate_collision_staged = true
		target.player.global_position = Vector2(1100, 520)
		target.player.velocity = Vector2.ZERO
		target.player.locomotion_velocity = Vector2.ZERO
		target.player.facing = Vector2.UP
		target.player.last_move_direction = Vector2.UP
		target.issue_pointer_command(Vector2(1100, 350))
	if elapsed >= 10.9 and gate_collision_staged and not boss_triggered:
		boss_triggered = true
		target.playtest_break_all_anchors()
		target.player.global_position = Vector2(1100, 510)
		target.player.facing = Vector2.UP
		target.player.last_move_direction = Vector2.UP
	if elapsed >= 11.1 and boss_triggered and not boss_clicked and is_instance_valid(target.boss):
		boss_clicked = true
		target.issue_pointer_command(target.boss.global_position)
	if elapsed >= 17.0 and boss_triggered and not boss_softened:
		boss_softened = true
		target.playtest_damage_boss(650.0)
	if elapsed >= 20.3 and boss_triggered and not victory_triggered:
		victory_triggered = true
		target.playtest_damage_boss(99999.0)
	if target.phase == AshenCovenantGame.GamePhase.PLAYING and target.player.health < 62.0 and target.player.potions > 0:
		target.player.use_potion()

func _between(start_time: float, end_time: float) -> bool:
	return elapsed >= start_time and elapsed < end_time

func _pulse(times: Array, width: float) -> bool:
	for start_time in times:
		if _between(float(start_time), float(start_time) + width):
			return true
	return false

func _set_action(action: StringName, pressed: bool) -> void:
	var was_pressed := bool(active_actions.get(action, false))
	if pressed == was_pressed:
		return
	active_actions[action] = pressed
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _send_ui_action(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)

func _click_enemy(index: int) -> void:
	if index < 0 or index >= target.enemies.size():
		return
	var enemy := target.enemies[index]
	if is_instance_valid(enemy) and enemy.health > 0.0:
		target.issue_pointer_command(enemy.global_position)

func _release_inputs() -> void:
	for action in active_actions:
		Input.action_release(action)
	active_actions.clear()

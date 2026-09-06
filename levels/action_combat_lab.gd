class_name ActionCombatLab
extends Node3D

const EnemyScene := preload("res://entities/enemies/action_combat_enemy_3d.tscn")
const HoundScene := preload("res://entities/enemies/ashen_hound_enemy_3d.tscn")
const SkeletonScene := preload("res://entities/enemies/skeleton_warrior_enemy_3d.tscn")
const SkeletonArcherScene := preload("res://entities/enemies/skeleton_archer_enemy_3d.tscn")
const AudioDirectorScript := preload("res://common/audio_director.gd")

@onready var player: ActionCombatPlayer3D = %Player
@onready var enemies: Node3D = %Enemies
@onready var camera: Camera3D = %Camera3D
@onready var fx: ActionCombatFX3D = %ActionCombatFX3D
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var dash_label: Label = %DashLabel
@onready var combo_label: Label = %ComboLabel
@onready var rank_label: Label = %RankLabel
@onready var score_label: Label = %ScoreLabel
@onready var wave_label: Label = %WaveLabel
@onready var banner_label: Label = %BannerLabel
@onready var vignette: ColorRect = %Vignette
@onready var impact_flash: ColorRect = %ImpactFlash

var _wave := 0
var _living_enemies := 0
var _score := 0
var _style := 0.0
var _camera_home := Vector3(0.0, 14.2, 12.0)
var _camera_shake := 0.0
var _camera_impulse := Vector3.ZERO
var _camera_base_fov := 48.0
var _wave_transitioning := false
var _time_effect_serial := 0
var _audio: AshenAudioDirector


func _ready() -> void:
	Engine.time_scale = 1.0
	_setup_audio()
	_connect_player()
	_update_health(player.health, player.max_health)
	_update_dash(3, 3)
	_update_combo(0)
	_update_style_ui()
	_start_next_wave()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	_style = maxf(0.0, _style - delta * (4.0 if _living_enemies > 0 else 10.0))
	_update_style_ui()
	_camera_shake = maxf(0.0, _camera_shake - delta * 14.0)
	_camera_impulse = _camera_impulse.move_toward(Vector3.ZERO, delta * 5.5)
	var shake_offset := Vector3(randf_range(-1.0, 1.0), randf_range(-0.45, 0.45), randf_range(-1.0, 1.0)) * _camera_shake
	camera.global_position = camera.global_position.lerp(_camera_home + _camera_impulse + shake_offset, minf(1.0, delta * 24.0))
	camera.fov = lerpf(camera.fov, _camera_base_fov, minf(1.0, delta * 9.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"use_potion"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()


func _connect_player() -> void:
	player.health_changed.connect(_update_health)
	player.dash_changed.connect(_update_dash)
	player.combo_changed.connect(_update_combo)
	player.slash_requested.connect(_on_slash_requested)
	player.dash_requested.connect(_on_dash_requested)
	player.hit_confirmed.connect(_on_hit_confirmed)
	player.perfect_dodged.connect(_on_perfect_dodge)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)


func _start_next_wave() -> void:
	if _wave_transitioning:
		return
	_wave_transitioning = true
	_wave += 1
	wave_label.text = "WAVE  %02d" % _wave
	banner_label.text = "第 %d 波" % _wave
	banner_label.visible = true
	var banner_tween := banner_label.create_tween()
	banner_label.modulate.a = 0.0
	banner_tween.tween_property(banner_label, "modulate:a", 1.0, 0.18)
	banner_tween.tween_interval(0.42)
	banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.28)
	banner_tween.finished.connect(func() -> void: banner_label.visible = false)
	await get_tree().create_timer(0.55).timeout
	var count := mini(4 + (_wave - 1), 7)
	_living_enemies = count
	for index in range(count):
		var angle := TAU * float(index) / count + _wave * 0.37
		var radius := 6.2 + float(index % 2) * 1.5
		var spawn_position := Vector3(cos(angle) * radius, 0.04, sin(angle) * radius)
		var is_hound := index == 0
		var is_skeleton := index == 1
		var is_archer := index == 3
		_spawn_enemy(spawn_position, index == count - 1 and _wave % 2 == 0, is_hound, is_skeleton, is_archer)
	_wave_transitioning = false


func _spawn_enemy(spawn_position: Vector3, brute: bool, hound: bool, skeleton: bool, skeleton_archer: bool = false) -> void:
	var enemy_scene := HoundScene if hound else (SkeletonScene if skeleton else (SkeletonArcherScene if skeleton_archer else EnemyScene))
	var enemy := enemy_scene.instantiate() as ActionCombatEnemy3D
	enemy.position = spawn_position
	enemy.brute = brute
	enemy.max_health = (88.0 + _wave * 8.0) if hound else ((52.0 + _wave * 5.0) if skeleton else ((46.0 + _wave * 5.0) if skeleton_archer else (120.0 + _wave * 12.0 if brute else 62.0 + _wave * 7.0)))
	enemy.accent_color = Color("ff4a32") if brute else [Color("ca46ff"), Color("3edcff"), Color("ff3d8b"), Color("1ae0ff")][_living_enemies % 4]
	enemies.add_child(enemy)
	enemy.damaged.connect(_on_enemy_damaged)
	enemy.died.connect(_on_enemy_died)
	enemy.strike_landed.connect(_on_enemy_strike_landed)


func _on_slash_requested(position: Vector3, direction: Vector3, combo_step: int, heavy: bool, sweep_duration: float) -> void:
	fx.show_slash(position, direction, combo_step, heavy, sweep_duration)
	if _audio != null:
		if heavy:
			_audio.play_heavy_swing(false)
		else:
			_audio.play_player_swing(combo_step, combo_step == 3)


func _on_dash_requested(position: Vector3, direction: Vector3) -> void:
	fx.show_dash(position, direction)
	_camera_shake = maxf(_camera_shake, 0.055)


func _on_hit_confirmed(position: Vector3, amount: float, heavy: bool, direction: Vector3, combo_step: int, defeated: bool) -> void:
	fx.show_hit(position, direction, combo_step, heavy, defeated)
	var impact_strength: float = 0.3 if defeated else (0.24 if heavy else [0.1, 0.145, 0.21][clampi(combo_step, 1, 3) - 1])
	_camera_shake = maxf(_camera_shake, impact_strength)
	_camera_impulse += -direction.normalized() * impact_strength * 0.75 + Vector3.UP * impact_strength * 0.32
	camera.fov = _camera_base_fov - (2.3 if heavy or defeated else 0.55 + combo_step * 0.32)
	_flash_impact(heavy, defeated)
	_score += roundi(amount * (1.5 if heavy else 1.0))
	_style = minf(100.0, _style + (18.0 if heavy else 9.0))
	if _audio != null:
		_audio.play_combo_hit(combo_step, heavy, defeated)
	_hit_stop(0.07 if defeated else (0.056 if heavy else [0.024, 0.032, 0.046][clampi(combo_step, 1, 3) - 1]))


func _on_enemy_damaged(position: Vector3, amount: float, finisher: bool) -> void:
	fx.show_damage(position, amount, finisher)


func _on_enemy_died(_enemy: ActionCombatEnemy3D) -> void:
	_living_enemies = maxi(0, _living_enemies - 1)
	_score += 150
	_style = minf(100.0, _style + 14.0)
	if _audio != null:
		_audio.play_heavy_death()
	if _living_enemies == 0 and not _wave_transitioning:
		_wave_transitioning = true
		fx.show_callout(player.global_position + Vector3.UP * 1.7, "清場！", Color("ffd35c"))
		await get_tree().create_timer(1.15).timeout
		_wave_transitioning = false
		_start_next_wave()


func _on_enemy_strike_landed(position: Vector3) -> void:
	fx.show_hit(position, Vector3.ZERO, 3, true, false)
	_camera_shake = 0.3
	vignette.color.a = 0.34
	var tween := vignette.create_tween()
	tween.tween_property(vignette, "color:a", 0.0, 0.3)


func _flash_impact(heavy: bool, defeated: bool) -> void:
	impact_flash.color = Color(1.0, 0.96 if defeated else 0.82, 0.72 if defeated else 0.42, 0.22 if defeated else (0.15 if heavy else 0.065))
	var tween := impact_flash.create_tween()
	tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(impact_flash, ^"color:a", 0.0, 0.11 if heavy or defeated else 0.075)


func _on_perfect_dodge(position: Vector3) -> void:
	fx.show_perfect_dodge(position)
	_score += 90
	_style = minf(100.0, _style + 22.0)
	_camera_shake = 0.12
	_slow_motion(0.32, 0.22)


func _on_player_damaged(_amount: float, _source: Node) -> void:
	_style = maxf(0.0, _style - 28.0)
	_camera_shake = 0.28
	if _audio != null:
		_audio.play_heavy_hurt()


func _on_player_died() -> void:
	banner_label.text = "試煉失敗\n按 R 重新開始"
	banner_label.modulate.a = 1.0
	banner_label.visible = true
	if _audio != null:
		_audio.play_defeat()


func _update_health(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "%03d / %03d" % [roundi(current), roundi(maximum)]


func _update_dash(charges: int, maximum: int) -> void:
	var pips := ""
	for index in range(maximum):
		pips += "◆" if index < charges else "◇"
	dash_label.text = "閃避  " + pips


func _update_combo(step: int) -> void:
	combo_label.text = "連段  %d / 3" % step if step > 0 else "連段  READY"


func _update_style_ui() -> void:
	var rank := "D"
	var color := Color("a6b0c3")
	if _style >= 85.0:
		rank = "S"
		color = Color("ff4a32")
	elif _style >= 65.0:
		rank = "A"
		color = Color("ffb13b")
	elif _style >= 42.0:
		rank = "B"
		color = Color("d86cff")
	elif _style >= 20.0:
		rank = "C"
		color = Color("52d9ff")
	rank_label.text = rank
	rank_label.modulate = color
	score_label.text = "STYLE  %05d" % _score


func _hit_stop(duration: float) -> void:
	_time_effect_serial += 1
	var serial := _time_effect_serial
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	if serial == _time_effect_serial:
		Engine.time_scale = 1.0


func _slow_motion(scale: float, duration: float) -> void:
	_time_effect_serial += 1
	var serial := _time_effect_serial
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if serial == _time_effect_serial:
		Engine.time_scale = 1.0


func _setup_audio() -> void:
	_audio = AudioDirectorScript.new() as AshenAudioDirector
	_audio.name = "AudioDirector"
	add_child(_audio)
	_audio.set_music_state(AshenAudioDirector.MusicState.BOSS)

class_name AshenAudioDirector
extends Node

## CC0 audio playback for Ashen Covenant. Sources and licensing are recorded in
## res://assets/audio/ATTRIBUTION.md.

enum MusicState { TITLE, EXPLORE, BOSS, VICTORY, DEFEAT }

const MUSIC_VOLUME_DB := -13.0
const MUSIC_DUCK_VOLUME_DB := -19.0
const MUSIC_CROSSFADE_SECONDS := 0.7
const SFX_POOL_SIZE := 14

var music_players: Array[AudioStreamPlayer] = []
var sfx_players: Array[AudioStreamPlayer] = []
var explore_music: AudioStream
var boss_music: AudioStream
var sword_swings: Array[AudioStream] = []
var sword_hits: Array[AudioStream] = []
var ability_learn: AudioStream
var item_pickup: AudioStream
var level_up: AudioStream
var ui_confirm: AudioStream
var transition: AudioStream
var current_music_index := 0
var music_state := MusicState.TITLE
var menu_ducked := false
var next_sfx_index := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 0xA0D10_2026
	_load_audio_assets()
	for index in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % (index + 1)
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = -60.0
		add_child(player)
		music_players.append(player)
		player.finished.connect(_loop_music.bind(player))
	for index in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "SFX%d" % (index + 1)
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		sfx_players.append(player)
	set_music_state(MusicState.TITLE)

func _exit_tree() -> void:
	for player in music_players:
		player.stop()
		player.stream = null
	for player in sfx_players:
		player.stop()
		player.stream = null
	music_players.clear()
	sfx_players.clear()
	sword_swings.clear()
	sword_hits.clear()
	explore_music = null
	boss_music = null
	ability_learn = null
	item_pickup = null
	level_up = null
	ui_confirm = null
	transition = null

func _load_audio_assets() -> void:
	explore_music = load("res://assets/audio/music/ancient_caverns.ogg") as AudioStream
	boss_music = load("res://assets/audio/music/boss_battle.ogg") as AudioStream
	sword_swings = [
		load("res://assets/audio/sfx/sword_swing_01.ogg") as AudioStream,
		load("res://assets/audio/sfx/sword_swing_02.ogg") as AudioStream,
		load("res://assets/audio/sfx/sword_swing_03.ogg") as AudioStream,
	]
	sword_hits = [
		load("res://assets/audio/sfx/sword_hit_01.ogg") as AudioStream,
		load("res://assets/audio/sfx/sword_hit_02.ogg") as AudioStream,
		load("res://assets/audio/sfx/sword_hit_03.ogg") as AudioStream,
	]
	ability_learn = load("res://assets/audio/sfx/ability_learn.mp3") as AudioStream
	item_pickup = load("res://assets/audio/sfx/item_pickup.mp3") as AudioStream
	level_up = load("res://assets/audio/sfx/level_up.mp3") as AudioStream
	ui_confirm = load("res://assets/audio/sfx/ui_confirm.mp3") as AudioStream
	transition = load("res://assets/audio/sfx/transition.mp3") as AudioStream

func set_music_state(next_state: MusicState) -> void:
	var next_stream := _stream_for_music_state(next_state)
	var active_player := music_players[current_music_index]
	if music_state == next_state and active_player.playing and active_player.stream == next_stream:
		return
	music_state = next_state
	var incoming_index := 1 - current_music_index
	var incoming_player := music_players[incoming_index]
	var outgoing_player := active_player
	incoming_player.stop()
	incoming_player.stream = next_stream
	incoming_player.volume_db = -60.0
	incoming_player.play()
	current_music_index = incoming_index
	var target_volume := _music_volume_for_state(next_state)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel()
	tween.tween_property(incoming_player, "volume_db", target_volume, MUSIC_CROSSFADE_SECONDS)
	if outgoing_player.playing:
		tween.tween_property(outgoing_player, "volume_db", -60.0, MUSIC_CROSSFADE_SECONDS)

func set_menu_ducked(ducked: bool) -> void:
	menu_ducked = ducked
	if not music_players.is_empty():
		music_players[current_music_index].volume_db = _music_volume_for_state(music_state)

func is_music_playing() -> bool:
	return not music_players.is_empty() and music_players[current_music_index].playing

func active_effect_count() -> int:
	var active := 0
	for player in sfx_players:
		if player.playing:
			active += 1
	return active

func play_player_swing(combo: int, critical: bool = false) -> void:
	var pitch := 1.13 if combo >= 3 else (1.04 if combo == 2 else 0.96)
	_play_sfx(_random_stream(sword_swings), -4.0 if critical else -5.0, pitch)

func play_hit(critical: bool = false) -> void:
	_play_sfx(_random_stream(sword_hits), -3.0 if critical else -5.0, 1.08 if critical else 1.0)

func play_dash() -> void:
	_play_sfx(transition, -8.0, 1.35)

func play_nova() -> void:
	_play_sfx(ability_learn, -4.5, 0.88)

func play_enemy_attack(boss_attack: bool = false) -> void:
	_play_sfx(_random_stream(sword_swings), -8.0 if boss_attack else -10.0, 0.73 if boss_attack else 0.82)

func play_enemy_cast() -> void:
	_play_sfx(ability_learn, -10.0, 0.72)

func play_hurt() -> void:
	_play_sfx(_random_stream(sword_hits), -7.0, 0.72)

func play_enemy_death(boss_death: bool = false) -> void:
	_play_sfx(transition if boss_death else _random_stream(sword_hits), -4.0 if boss_death else -9.0, 0.65 if boss_death else 0.72)

func play_anchor_hit(destroyed: bool = false) -> void:
	_play_sfx(transition if destroyed else _random_stream(sword_hits), -5.0 if destroyed else -9.0, 0.78 if destroyed else 0.86)

func play_pickup(rare: bool = false) -> void:
	_play_sfx(ability_learn if rare else item_pickup, -7.0 if rare else -9.0, 1.0)

func play_level_up() -> void:
	_play_sfx(level_up, -3.5, 1.0)

func play_potion() -> void:
	_play_sfx(item_pickup, -8.0, 0.82)

func play_chest() -> void:
	_play_sfx(ability_learn, -6.0, 0.86)

func play_boss_arrival() -> void:
	_play_sfx(transition, -3.5, 0.70)

func play_victory() -> void:
	_play_sfx(level_up, -2.5, 1.06)

func play_defeat() -> void:
	_play_sfx(transition, -4.0, 0.58)

func play_ui_confirm() -> void:
	_play_sfx(ui_confirm, -10.0, 1.0)

func play_ui_back() -> void:
	_play_sfx(ui_confirm, -12.0, 0.74)

func _stream_for_music_state(state: MusicState) -> AudioStream:
	return boss_music if state == MusicState.BOSS else explore_music

func _music_volume_for_state(state: MusicState) -> float:
	var base_volume := MUSIC_VOLUME_DB + (2.0 if state == MusicState.BOSS else 0.0)
	return MUSIC_DUCK_VOLUME_DB if menu_ducked else base_volume

func _loop_music(player: AudioStreamPlayer) -> void:
	if player == music_players[current_music_index] and player.stream != null:
		player.play()

func _random_stream(streams: Array) -> AudioStream:
	return streams[rng.randi_range(0, streams.size() - 1)] as AudioStream

func _play_sfx(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null or sfx_players.is_empty():
		return
	var player := sfx_players[next_sfx_index]
	next_sfx_index = (next_sfx_index + 1) % sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()

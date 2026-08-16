class_name AshenCovenantGame
extends Node2D

enum GamePhase { TITLE, PLAYING, SHEET, SKILL_TREE, PAUSED, VICTORY, DEFEAT }

const EnemyScript := preload("res://entities/enemies/enemy.gd")
const ProjectileScript := preload("res://entities/projectiles/projectile.gd")
const PickupScript := preload("res://common/loot_pickup.gd")
const FXScript := preload("res://common/combat_fx.gd")
const SpriteFXScript := preload("res://common/sprite_sequence_fx.gd")
const AudioDirectorScript := preload("res://common/audio_director.gd")
const DUNGEON_LAYOUT_PATH := "res://data/ashen_catacombs_layout.json"
const POINTER_GRID_CELL_SIZE := 32.0
const POINTER_ACTOR_RADIUS := 15.0
const POINTER_GRID_SIZE := Vector2i(60, 40)
const GAMEPLAY_CAMERA_ZOOM := 1.5

@onready var world_renderer: AshenWorldRenderer = %WorldRenderer
@onready var actors: Node2D = %Actors
@onready var effects: Node2D = %Effects
@onready var loot_layer: Node2D = %LootLayer
@onready var player: CovenantPlayer = %Player
@onready var hud: CovenantHUD = %HUD
@onready var dungeon_props_layer: Node2D = %DungeonProps
@onready var dungeon_features_layer: Node2D = %DungeonFeatures

var audio: AshenAudioDirector

var phase := GamePhase.TITLE
var anchors: Array[Dictionary] = []
var enemies: Array[CovenantEnemy] = []
var boss: CovenantEnemy
var rng := RandomNumberGenerator.new()
var objective := "Break the soul anchors"
var sheet_open := false
var announcement := ""
var announcement_color := Color.WHITE
var announcement_timer := 0.0
var run_time := 0.0
var anchors_destroyed := 0
var continued_run := false
var last_attack_debug: Dictionary = {}
var dungeon_layout: Dictionary = {}
var chests: Array[Dictionary] = []
var breakables: Array[Dictionary] = []
var dungeon_props: Dictionary = {}
var discovered_rooms: Array[String] = []
var current_room := ""
var hazard_timers: Dictionary = {}
var shortcut_cooldown := 0.0
var combat_camera: Camera2D
var camera_trauma := 0.0
var camera_noise_time := 0.0
var hit_stop_generation := 0
var screen_shake_enabled := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 0xD1AB10
	audio = AudioDirectorScript.new() as AshenAudioDirector
	audio.name = "AudioDirector"
	add_child(audio)
	audio.set_music_state(AshenAudioDirector.MusicState.TITLE)
	SpriteFXScript.warm_gameplay_effects()
	_load_dungeon_layout()
	world_renderer.configure_layout(dungeon_layout)
	_initialize_anchors()
	_initialize_interactables()
	_configure_scene_features()
	_rebuild_dungeon_props()
	_connect_player()
	_configure_camera()
	if not hud.skill_selected.is_connected(purchase_skill):
		hud.skill_selected.connect(purchase_skill)
	if not hud.skill_tree_requested.is_connected(open_skill_tree):
		hud.skill_tree_requested.connect(open_skill_tree)
	if not hud.title_new_game_requested.is_connected(_on_title_new_game_requested):
		hud.title_new_game_requested.connect(_on_title_new_game_requested)
	if not hud.title_continue_requested.is_connected(_on_title_continue_requested):
		hud.title_continue_requested.connect(_on_title_continue_requested)
	if not hud.title_exit_requested.is_connected(_on_title_exit_requested):
		hud.title_exit_requested.connect(_on_title_exit_requested)
	if not hud.screen_shake_setting_changed.is_connected(_on_screen_shake_setting_changed):
		hud.screen_shake_setting_changed.connect(_on_screen_shake_setting_changed)
	player.set_collision_mask_value(1, true)
	player.gameplay_enabled = false
	_refresh_world_state()
	_update_hud()
	print("[ASHEN] PLAYTEST_READY phase=TITLE")

func _process(delta: float) -> void:
	var unscaled_delta := delta / maxf(Engine.time_scale, 0.01)
	_update_camera_feedback(unscaled_delta)
	if phase == GamePhase.PLAYING:
		run_time += delta
		_update_exploration(delta)
	else:
		shortcut_cooldown = maxf(0.0, shortcut_cooldown - delta)
	announcement_timer = maxf(0.0, announcement_timer - delta)
	_update_hud()

func _load_dungeon_layout() -> void:
	var file := FileAccess.open(DUNGEON_LAYOUT_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not load dungeon layout: %s" % DUNGEON_LAYOUT_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("Dungeon layout JSON is invalid")
		return
	dungeon_layout = json.data

func _position_from_data(data: Dictionary, key: String = "") -> Vector2:
	var source: Dictionary = data
	if not key.is_empty():
		source = data.get(key, {})
	return Vector2(float(source.get("x", 0.0)), float(source.get("y", 0.0)))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (not event.pressed or event.echo):
		return
	match phase:
		GamePhase.TITLE:
			if event.is_action_pressed(&"confirm"):
				start_new_game()
			elif event is InputEventKey and event.physical_keycode == KEY_C and _save_service().has_save():
				continue_game()
		GamePhase.PLAYING:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if not hud.blocks_world_pointer(event.position):
					issue_pointer_command(_viewport_to_world(event.position))
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed(&"toggle_sheet"):
				sheet_open = true
				_set_phase(GamePhase.SHEET)
			elif event.is_action_pressed(&"toggle_skills"):
				open_skill_tree()
			elif event.is_action_pressed(&"pause"):
				_set_phase(GamePhase.PAUSED)
		GamePhase.SHEET:
			if event.is_action_pressed(&"toggle_sheet") or event.is_action_pressed(&"pause"):
				sheet_open = false
				_set_phase(GamePhase.PLAYING)
		GamePhase.SKILL_TREE:
			if event.is_action_pressed(&"toggle_skills") or event.is_action_pressed(&"pause"):
				_set_phase(GamePhase.PLAYING)
		GamePhase.PAUSED:
			if event.is_action_pressed(&"pause"):
				_set_phase(GamePhase.PLAYING)
		GamePhase.VICTORY, GamePhase.DEFEAT:
			if event.is_action_pressed(&"confirm"):
				start_new_game()

func _viewport_to_world(viewport_position: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * viewport_position

func issue_pointer_command(world_position: Vector2) -> bool:
	if phase != GamePhase.PLAYING or not is_instance_valid(player):
		return false
	# The player always faces the actual click; pathfinding must not replace it
	# with a nearby navigable cell when the clicked point is behind an obstacle.
	player.set_model_facing_at(world_position)
	var enemy := _enemy_at_pointer(world_position)
	if is_instance_valid(enemy):
		var enemy_path := _build_pointer_path(player.global_position, enemy.global_position)
		if player.command_attack_target(enemy, enemy_path):
			_spawn_fx(enemy.global_position, CombatFX.FXType.PICKUP, Color("e46a57"), 0.32, 24.0)
			return true
	var anchor := _anchor_at_pointer(world_position)
	if not anchor.is_empty():
		var anchor_position: Vector2 = anchor.position
		var anchor_path := _build_pointer_path(player.global_position, anchor_position)
		if player.command_attack_point(anchor_position, anchor_path):
			_spawn_fx(anchor_position, CombatFX.FXType.PICKUP, Color("db4f72"), 0.32, 24.0)
			return true
	var move_path := _build_pointer_path(player.global_position, world_position)
	if not player.command_move_path(move_path):
		return false
	_spawn_fx(move_path[move_path.size() - 1], CombatFX.FXType.PICKUP, Color("d8bb82"), 0.28, 18.0)
	return true

func _enemy_at_pointer(world_position: Vector2) -> CovenantEnemy:
	var selected: CovenantEnemy
	var best_score := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.health <= 0.0:
			continue
		var half_width := 62.0 if enemy.is_boss else (43.0 if enemy.enemy_kind == &"brute" else 31.0)
		var height := 166.0 if enemy.is_boss else (128.0 if enemy.enemy_kind == &"brute" else 102.0)
		var local := world_position - enemy.global_position
		if absf(local.x) > half_width or local.y > 28.0 or local.y < -height:
			continue
		var score := absf(local.x) + absf(local.y + height * 0.34) * 0.24
		if score < best_score:
			best_score = score
			selected = enemy
	return selected

func _anchor_at_pointer(world_position: Vector2) -> Dictionary:
	for anchor: Dictionary in anchors:
		if not bool(anchor.get("alive", false)):
			continue
		var local := world_position - Vector2(anchor.position)
		if absf(local.x) <= 42.0 and local.y >= -112.0 and local.y <= 28.0:
			return anchor
	return {}

func _build_pointer_path(from: Vector2, destination: Vector2) -> PackedVector2Array:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, POINTER_GRID_SIZE)
	grid.cell_size = Vector2.ONE * POINTER_GRID_CELL_SIZE
	grid.offset = Vector2.ONE * (POINTER_GRID_CELL_SIZE * 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in POINTER_GRID_SIZE.y:
		for x in POINTER_GRID_SIZE.x:
			var cell := Vector2i(x, y)
			var sample := grid.get_point_position(cell)
			grid.set_point_solid(cell, not world_renderer.is_point_walkable(sample, POINTER_ACTOR_RADIUS))
	var start_id := _nearest_open_pointer_cell(grid, _pointer_cell_for_world(from))
	var end_id := _nearest_open_pointer_cell(grid, _pointer_cell_for_world(destination))
	if start_id.x < 0 or end_id.x < 0:
		return PackedVector2Array()
	var raw_path := grid.get_point_path(start_id, end_id, true)
	if raw_path.is_empty():
		return PackedVector2Array()
	if world_renderer.is_motion_walkable(raw_path[raw_path.size() - 1], destination, POINTER_ACTOR_RADIUS):
		raw_path.append(destination)
	return _smooth_pointer_path(from, raw_path)

func _pointer_cell_for_world(world_position: Vector2) -> Vector2i:
	var offset := Vector2.ONE * (POINTER_GRID_CELL_SIZE * 0.5)
	var id := Vector2i(
		roundi((world_position.x - offset.x) / POINTER_GRID_CELL_SIZE),
		roundi((world_position.y - offset.y) / POINTER_GRID_CELL_SIZE)
	)
	return Vector2i(clampi(id.x, 0, POINTER_GRID_SIZE.x - 1), clampi(id.y, 0, POINTER_GRID_SIZE.y - 1))

func _nearest_open_pointer_cell(grid: AStarGrid2D, center: Vector2i) -> Vector2i:
	for radius in 10:
		for y in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				if x < 0 or y < 0 or x >= POINTER_GRID_SIZE.x or y >= POINTER_GRID_SIZE.y:
					continue
				if maxi(absi(x - center.x), absi(y - center.y)) != radius:
					continue
				var candidate := Vector2i(x, y)
				if not grid.is_point_solid(candidate):
					return candidate
	return Vector2i(-1, -1)

func _smooth_pointer_path(from: Vector2, raw_path: PackedVector2Array) -> PackedVector2Array:
	var smoothed := PackedVector2Array()
	var anchor := from
	var index := 0
	while index < raw_path.size():
		var furthest := index
		for candidate in range(raw_path.size() - 1, index - 1, -1):
			if world_renderer.is_motion_walkable(anchor, raw_path[candidate], POINTER_ACTOR_RADIUS):
				furthest = candidate
				break
		var point := raw_path[furthest]
		if anchor.distance_to(point) > 2.0:
			smoothed.append(point)
		anchor = point
		index = furthest + 1
	return smoothed

func _initialize_anchors() -> void:
	anchors.clear()
	for feature in _map_features_of_type(DungeonMapFeature.FeatureType.SOUL_ANCHOR):
		feature.reset_runtime_state()
		anchors.append(feature.anchor_data())
	anchors_destroyed = 0

func _initialize_interactables() -> void:
	chests.clear()
	breakables.clear()
	dungeon_props.clear()
	discovered_rooms.clear()
	current_room = ""
	hazard_timers.clear()
	for hazard in _map_features_of_type(DungeonMapFeature.FeatureType.SPIKE_TRAP):
		var hazard_data := hazard.hazard_data()
		hazard_timers[String(hazard_data.get("id", "hazard"))] = 0.0
	for prop in _scene_dungeon_props():
		prop.reset_runtime_state()
		dungeon_props[String(prop.prop_id)] = prop
		var prop_data := prop.gameplay_data()
		if prop.gameplay_role == "Chest":
			chests.append(prop_data)
		elif prop.gameplay_role == "Breakable":
			breakables.append(prop_data)
	shortcut_cooldown = 0.0
	world_renderer.set_interactables(chests, breakables)

func _rebuild_dungeon_props() -> void:
	dungeon_props.clear()
	for prop in _scene_dungeon_props():
		dungeon_props[String(prop.prop_id)] = prop
	for chest: Dictionary in chests:
		var chest_prop := dungeon_props.get(String(chest.get("id", ""))) as DungeonProp
		if is_instance_valid(chest_prop):
			chest_prop.set_opened(bool(chest.get("opened", false)))
			chest_prop.highlight = not bool(chest.get("hidden", false)) and not bool(chest.get("opened", false))
	for breakable: Dictionary in breakables:
		var breakable_prop := dungeon_props.get(String(breakable.get("id", ""))) as DungeonProp
		if is_instance_valid(breakable_prop):
			breakable_prop.set_destroyed(not bool(breakable.get("alive", true)))

func _scene_dungeon_props() -> Array[DungeonProp]:
	var result: Array[DungeonProp] = []
	for child in dungeon_props_layer.get_children():
		if child is DungeonProp:
			result.append(child)
	return result

func _map_features_of_type(feature_type: int) -> Array[DungeonMapFeature]:
	var result: Array[DungeonMapFeature] = []
	for child in dungeon_features_layer.get_children():
		if child is DungeonMapFeature and child.feature_type == feature_type:
			result.append(child)
	return result

func _configure_scene_features() -> void:
	var boss_gate_data: Dictionary = {}
	var shortcut_data: Array[Dictionary] = []
	var hazard_data: Array[Dictionary] = []
	for child in dungeon_features_layer.get_children():
		var feature := child as DungeonMapFeature
		if feature == null:
			continue
		match feature.feature_type:
			DungeonMapFeature.FeatureType.BOSS_GATE:
				boss_gate_data = feature.boss_gate_data()
			DungeonMapFeature.FeatureType.SHORTCUT_GATE:
				shortcut_data.append(feature.shortcut_data())
			DungeonMapFeature.FeatureType.SPIKE_TRAP:
				hazard_data.append(feature.hazard_data())
	var decor_prop_data: Array[Dictionary] = []
	for prop in _scene_dungeon_props():
		if prop.gameplay_role == "Decoration":
			decor_prop_data.append(prop.gameplay_data())
	world_renderer.set_scene_features(boss_gate_data, shortcut_data, hazard_data, decor_prop_data)

func _refresh_world_state() -> void:
	world_renderer.set_interactables(chests, breakables)
	world_renderer.update_world(anchors, anchors_destroyed >= anchors.size(), is_instance_valid(boss))
	for feature in _map_features_of_type(DungeonMapFeature.FeatureType.SOUL_ANCHOR):
		var anchor := _anchor_by_id(String(feature.feature_id))
		if not anchor.is_empty():
			feature.set_anchor_state(float(anchor.get("health", feature.max_health)), bool(anchor.get("alive", true)))
	for feature in _map_features_of_type(DungeonMapFeature.FeatureType.SHORTCUT_GATE):
		var anchor := _anchor_by_id(String(feature.linked_anchor_id))
		feature.set_gate_open(not anchor.is_empty() and not bool(anchor.get("alive", true)))
	for feature in _map_features_of_type(DungeonMapFeature.FeatureType.BOSS_GATE):
		feature.set_gate_open(anchors_destroyed >= anchors.size())

func _connect_player() -> void:
	player.attack_requested.connect(_on_player_attack)
	player.nova_requested.connect(_on_player_nova)
	player.dash_requested.connect(_on_player_dash)
	player.level_up_requested.connect(_on_level_up)
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	player.potion_used.connect(_on_player_potion_used)
	player.action_feedback.connect(_show_announcement)

func _configure_camera() -> void:
	var camera := player.get_node_or_null("Camera") as Camera2D
	if not camera:
		return
	combat_camera = camera
	camera.enabled = true
	# The camera is a child of Player, so zero local position keeps the player
	# at the exact viewport center. Do not use a drag dead-zone here: this is an
	# action RPG view, not a platformer camera.
	camera.position = Vector2.ZERO
	camera.zoom = Vector2.ONE * GAMEPLAY_CAMERA_ZOOM
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false
	camera.position_smoothing_enabled = false
	# Extend the limits by half a viewport so the player can remain centered at
	# the edge of the authored 2200x1400 dungeon instead of being clamped inward.
	camera.limit_left = -640
	camera.limit_top = -360
	camera.limit_right = 2560
	camera.limit_bottom = 1640
	camera.limit_smoothed = true

func start_new_game() -> void:
	_clear_dynamic_nodes()
	_save_service().delete_save()
	continued_run = false
	run_time = 0.0
	_initialize_anchors()
	_initialize_interactables()
	_rebuild_dungeon_props()
	player.reset_progress()
	player.global_position = _position_from_data(dungeon_layout, "spawn")
	_spawn_anchor_encounters()
	objective = "Break the soul anchors  (0 / 3)"
	sheet_open = false
	current_room = "entry_hall"
	discovered_rooms.append(current_room)
	_refresh_world_state()
	_set_phase(GamePhase.PLAYING)
	_show_announcement("THE COVENANT STIRS", Color("e49967"), 2.4)
	print("[ASHEN] GAME_STARTED mode=new enemies=%d" % enemies.size())

func continue_game() -> void:
	var data: Dictionary = _save_service().load_game()
	if data.is_empty():
		start_new_game()
		return
	_clear_dynamic_nodes()
	_initialize_anchors()
	_initialize_interactables()
	continued_run = true
	player.load_save_dict(data.get("player", {}))
	anchors_destroyed = clampi(int(data.get("anchors_destroyed", 0)), 0, anchors.size())
	for i in anchors.size():
		if i < anchors_destroyed:
			anchors[i]["alive"] = false
			anchors[i]["health"] = 0.0
	var opened_chests: Array = data.get("opened_chests", [])
	for chest: Dictionary in chests:
		if String(chest.get("id", "")) in opened_chests:
			chest["opened"] = true
	discovered_rooms.assign(data.get("discovered_rooms", ["entry_hall"]))
	_rebuild_dungeon_props()
	player.global_position = _position_from_data(dungeon_layout, "continueSpawn")
	_spawn_anchor_encounters()
	if anchors_destroyed >= anchors.size():
		_spawn_boss()
	else:
		objective = "Break the soul anchors  (%d / 3)" % anchors_destroyed
	_refresh_world_state()
	_set_phase(GamePhase.PLAYING)
	_show_announcement("THE COVENANT REMEMBERS", Color("8fb5c9"), 2.2)
	print("[ASHEN] GAME_STARTED mode=continue anchors=%d" % anchors_destroyed)

func _clear_dynamic_nodes() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy): enemy.queue_free()
	enemies.clear()
	boss = null
	for parent in [effects, loot_layer]:
		for child in parent.get_children(): child.queue_free()
	for child in actors.get_children():
		if child != player and child != dungeon_props_layer: child.queue_free()
	dungeon_props.clear()

func _spawn_anchor_encounters() -> void:
	for encounter: Dictionary in dungeon_layout.get("encounters", []):
		var anchor := _anchor_by_id(String(encounter.get("anchor", "")))
		if anchor.is_empty() or not bool(anchor.get("alive", true)):
			continue
		for spawn: Dictionary in encounter.get("spawns", []):
			_spawn_enemy(StringName(String(spawn.get("kind", "ghoul"))), _position_from_data(spawn), player.level)

func _anchor_by_id(anchor_id: String) -> Dictionary:
	for anchor: Dictionary in anchors:
		if String(anchor.get("id", "")) == anchor_id:
			return anchor
	return {}

func _spawn_enemy(kind: StringName, spawn_position: Vector2, level_value: int, boss_enemy: bool = false) -> CovenantEnemy:
	var enemy := EnemyScript.new() as CovenantEnemy
	enemy.setup(kind, level_value, player, boss_enemy)
	enemy.global_position = spawn_position
	actors.add_child(enemy)
	enemy.set_collision_mask_value(1, true)
	enemies.append(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy.attack_requested.connect(_on_enemy_attack)
	enemy.projectile_requested.connect(_on_projectile_requested)
	enemy.summon_requested.connect(_on_summon_requested)
	enemy.damaged.connect(_on_enemy_damaged)
	return enemy

func _spawn_boss() -> void:
	if is_instance_valid(boss):
		return
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_boss:
			enemy.queue_free()
	enemies.clear()
	boss = _spawn_enemy(&"boss", _position_from_data(dungeon_layout, "bossSpawn"), maxi(1, player.level), true)
	objective = "Slay the Ashen Warden"
	_refresh_world_state()
	_show_announcement("THE ASHEN WARDEN AWAKENS", Color("ff7454"), 3.0)
	_spawn_fx(boss.global_position, CombatFX.FXType.ANCHOR, Color("ff6a47"), 1.1, 150.0)
	_spawn_sprite_fx(boss.global_position, SpriteFXScript.EffectID.FIRE_RUNE, Color("ff7a52"), 1.15)
	audio.set_music_state(AshenAudioDirector.MusicState.BOSS)
	audio.play_boss_arrival()
	print("[ASHEN] BOSS_SPAWNED hp=%d" % int(boss.max_health))

func _on_player_attack(origin: Vector2, direction: Vector2, radius: float, packet: DamagePacket, combo: int) -> void:
	audio.play_player_swing(combo, packet.is_critical)
	var fx := _spawn_fx(origin, CombatFX.FXType.SLASH, Color("f2d6ae") if not packet.is_critical else Color("fff0b8"), 0.15 if combo < 3 else 0.19, radius * (1.02 if combo < 3 else 1.18))
	fx.direction = direction
	fx.swing_side = -1.0 if combo != 2 else 1.0
	fx.swing_intensity = 1.0 + (0.20 if combo == 2 else (0.48 if combo >= 3 else 0.0)) + (0.16 if packet.is_critical else 0.0)
	var hits := 0
	var minimum_dot := cos(deg_to_rad(82.0 if combo == 3 else 65.0))
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy): continue
		var offset: Vector2 = enemy.global_position - origin
		if offset.length() <= radius and (offset.length() < 28.0 or offset.normalized().dot(direction) >= minimum_dot):
			if enemy.take_damage(packet):
				hits += 1
				player.total_damage += int(packet.amount)
	for anchor in anchors:
		if bool(anchor.alive) and Vector2(anchor.position).distance_to(origin) <= radius + 20.0:
			_damage_anchor(anchor, packet.amount)
			hits += 1
	hits += _hit_interactables(origin, radius + 18.0)
	if hits > 0:
		_request_hit_stop(0.06 if packet.is_critical or combo == 3 else 0.035)
		_add_camera_trauma(0.28 if packet.is_critical or combo == 3 else 0.16)
		hud.play_screen_flash(Color("ffd58a") if packet.is_critical else Color.WHITE, 0.085 if packet.is_critical else 0.035, 0.09)
	if hits > 0 and combo == 3:
		_show_announcement("SUNDERING CLEAVE", Color("f0b26b"), 0.8)
	last_attack_debug = {"origin": origin, "direction": direction, "radius": radius, "hits": hits, "amount": packet.amount}

func _on_player_nova(origin: Vector2, radius: float, packet: DamagePacket) -> void:
	audio.play_nova()
	_spawn_fx(origin, CombatFX.FXType.NOVA, Color("a85ee5"), 0.68, radius)
	_spawn_sprite_fx(origin, SpriteFXScript.EffectID.ENERGY_BALL, Color("b983ff"), 2.45, 1.1)
	var hit_count := 0
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy): continue
		var offset: Vector2 = enemy.global_position - origin
		if offset.length() <= radius:
			var push: Vector2 = offset.normalized() * 285.0
			var nova_packet := DamagePacket.new(packet.amount, player, origin, push, packet.kind, packet.is_critical)
			if enemy.take_damage(nova_packet):
				enemy.apply_ashbound(0.58 if enemy.is_boss else 1.25)
				hit_count += 1
				player.total_damage += int(packet.amount)
	for anchor in anchors:
		if bool(anchor.alive) and Vector2(anchor.position).distance_to(origin) <= radius:
			_damage_anchor(anchor, packet.amount * 0.75)
			hit_count += 1
	hit_count += _hit_interactables(origin, radius)
	if hit_count > 0:
		_request_hit_stop(0.055)
		_add_camera_trauma(0.30)
		hud.play_screen_flash(Color("b86cff"), 0.07, 0.14)
	_show_announcement("ASH NOVA  •  %d HIT%s  •  ASHBOUND" % [hit_count, "S" if hit_count != 1 else ""], Color("c88cff"), 1.0)

func _hit_interactables(center: Vector2, radius: float) -> int:
	var hits := 0
	for chest: Dictionary in chests:
		if not bool(chest.get("opened", false)) and _position_from_data(chest).distance_to(center) <= radius + 30.0:
			_open_chest(chest)
			hits += 1
	for breakable: Dictionary in breakables:
		if bool(breakable.get("alive", true)) and _position_from_data(breakable).distance_to(center) <= radius + 20.0:
			_break_dungeon_prop(breakable)
			hits += 1
	if hits > 0:
		_refresh_world_state()
	return hits

func _open_chest(chest: Dictionary) -> void:
	chest["opened"] = true
	var chest_id := String(chest.get("id", "chest"))
	var prop := dungeon_props.get(chest_id) as DungeonProp
	if is_instance_valid(prop):
		prop.set_opened(true)
	var chest_position := _position_from_data(chest)
	var item := LootItem.roll(player.level + 2, rng)
	item.rarity = maxi(item.rarity, LootItem.Rarity.MAGIC) as LootItem.Rarity
	_spawn_item_pickup(chest_position + Vector2(0, -12), item)
	_spawn_currency_pickup(chest_position + Vector2(-24, 8), LootPickup.PickupKind.GOLD, rng.randi_range(18, 34))
	if rng.randf() < 0.55:
		_spawn_currency_pickup(chest_position + Vector2(24, 8), LootPickup.PickupKind.POTION, 1)
	_spawn_fx(chest_position, CombatFX.FXType.PICKUP, Color("f0bd57"), 0.7, 58.0)
	audio.play_chest()
	_show_announcement("HIDDEN CACHE OPENED", Color("f0c86a"), 1.6)

func _break_dungeon_prop(prop_data: Dictionary) -> void:
	prop_data["alive"] = false
	var prop_id := String(prop_data.get("id", "breakable"))
	var prop := dungeon_props.get(prop_id) as DungeonProp
	if is_instance_valid(prop):
		prop.set_destroyed(true)
	var prop_position := _position_from_data(prop_data)
	_spawn_fx(prop_position, CombatFX.FXType.DEATH, Color("ad8066"), 0.44, 34.0)
	audio.play_enemy_death(false)
	_spawn_currency_pickup(prop_position, LootPickup.PickupKind.GOLD, rng.randi_range(2, 8))
	if rng.randf() < 0.16:
		_spawn_currency_pickup(prop_position + Vector2(15, 0), LootPickup.PickupKind.POTION, 1)

func _damage_anchor(anchor: Dictionary, amount: float) -> void:
	anchor.health = maxf(0.0, float(anchor.health) - amount)
	audio.play_anchor_hit(float(anchor.health) <= 0.0 and bool(anchor.alive))
	_spawn_fx(anchor.position, CombatFX.FXType.HIT, Color("e74767"), 0.3, 28.0)
	_spawn_sprite_fx(Vector2(anchor.position), SpriteFXScript.EffectID.FIRE_RUNE, Color("ef5c76"), 0.34)
	if float(anchor.health) <= 0.0 and bool(anchor.alive):
		anchor.alive = false
		if player.is_attacking_pointer_point(Vector2(anchor.position)):
			player.cancel_pointer_command()
		anchors_destroyed += 1
		_spawn_fx(anchor.position, CombatFX.FXType.ANCHOR, Color("ed4262"), 0.9, 110.0)
		_spawn_sprite_fx(Vector2(anchor.position), SpriteFXScript.EffectID.EATER_FIRE, Color("ff6680"), 0.95)
		_spawn_guaranteed_relic(anchor.position)
		objective = "Break the soul anchors  (%d / 3)" % anchors_destroyed
		var anchor_id := String(anchor.get("id", ""))
		var suffix := "  •  SHORTCUT UNSEALED" if anchor_id in ["west", "east"] else ""
		_show_announcement("SOUL ANCHOR SHATTERED  •  %d / 3%s" % [anchors_destroyed, suffix], Color("ff6c84"), 2.2)
		_save_checkpoint()
		print("[ASHEN] ANCHOR_DESTROYED count=%d" % anchors_destroyed)
		if anchors_destroyed >= anchors.size():
			_spawn_boss()
	_refresh_world_state()

func _on_enemy_attack(enemy: CovenantEnemy, center: Vector2, radius: float, raw_damage: float, color: Color) -> void:
	audio.play_enemy_attack(enemy.is_boss)
	_spawn_fx(center, CombatFX.FXType.NOVA, color, 0.35, radius)
	_spawn_sprite_fx(center, SpriteFXScript.EffectID.FIRE_RUNE, color, clampf(radius / 135.0, 0.42, 1.18))
	var attack_direction := (player.global_position - enemy.global_position).normalized()
	if attack_direction == Vector2.ZERO:
		attack_direction = Vector2.DOWN
	var enemy_slash := _spawn_fx(enemy.global_position, CombatFX.FXType.SLASH, color, 0.17 if not enemy.is_boss else 0.22, radius * (0.82 if not enemy.is_boss else 1.05))
	enemy_slash.direction = attack_direction
	enemy_slash.swing_side = 1.0 if enemy.is_boss else -1.0
	enemy_slash.swing_intensity = 1.0 if not enemy.is_boss else 1.52
	if player.global_position.distance_to(center) <= radius + 15.0:
		var direction := (player.global_position - enemy.global_position).normalized()
		player.take_damage(DamagePacket.new(raw_damage, enemy, center, direction * 190.0, DamagePacket.DamageKind.PHYSICAL))

func _on_projectile_requested(origin: Vector2, direction: Vector2, speed: float, raw_damage: float, color: Color) -> void:
	audio.play_enemy_cast()
	var projectile := ProjectileScript.new() as EnemyProjectile
	projectile.setup(direction, speed, raw_damage, player, color)
	projectile.movement_filter = Callable(world_renderer, "is_motion_walkable")
	projectile.global_position = origin
	actors.add_child(projectile)
	projectile.impacted.connect(func(p: Vector2, c: Color) -> void:
		audio.play_hit()
		_spawn_fx(p, CombatFX.FXType.HIT, c, 0.28, 34.0)
		_spawn_sprite_fx(p, SpriteFXScript.EffectID.EATER_FIRE, c, 0.42)
	)

func _on_summon_requested(origin: Vector2, count: int) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count)
		_spawn_enemy(&"ghoul", origin + Vector2.from_angle(angle) * 145.0, player.level + 1)
	_show_announcement("THE WARDEN CALLS THE DEAD", Color("d55d58"), 1.5)

func _on_enemy_damaged(fx_position: Vector2, amount: int, critical: bool, impact_direction: Vector2) -> void:
	audio.play_hit(critical)
	var color := Color("ffd166") if critical else Color("f1e8d6")
	var label := "%d%s" % [amount, "!" if critical else ""]
	var hit_fx := _spawn_fx(fx_position, CombatFX.FXType.HIT, color, 0.24, 34.0 if critical else 26.0)
	hit_fx.direction = impact_direction if impact_direction != Vector2.ZERO else Vector2.UP
	var blade_impact := _spawn_sprite_fx(fx_position, SpriteFXScript.EffectID.BLADE_CRIT if critical else SpriteFXScript.EffectID.BLADE_IMPACT, color, 0.92 if critical else 0.70, 1.12 if critical else 1.0)
	blade_impact.rotation = hit_fx.direction.angle()
	if critical:
		var crit_fx := _spawn_sprite_fx(fx_position, SpriteFXScript.EffectID.FIRE_SCISSORS, Color("ffd56a"), 0.38)
		crit_fx.rotation = hit_fx.direction.angle() - PI * 0.5
	_spawn_fx(fx_position - Vector2(0, 28), CombatFX.FXType.TEXT, color, 0.72, 65.0 if critical else 35.0, label)

func _on_player_damaged(fx_position: Vector2, amount: int, impact_direction: Vector2) -> void:
	audio.play_hurt()
	var hit_fx := _spawn_fx(fx_position, CombatFX.FXType.HIT, Color("ff6b6b"), 0.28, 32.0)
	hit_fx.direction = impact_direction if impact_direction != Vector2.ZERO else Vector2.DOWN
	var blade_impact := _spawn_sprite_fx(fx_position, SpriteFXScript.EffectID.BLADE_IMPACT, Color("ff7770"), 0.78)
	blade_impact.rotation = hit_fx.direction.angle()
	var hurt_fx := _spawn_sprite_fx(fx_position, SpriteFXScript.EffectID.FIRE_SCISSORS, Color("ff6b6b"), 0.32)
	hurt_fx.rotation = hit_fx.direction.angle() - PI * 0.5
	_spawn_fx(fx_position - Vector2(0, 35), CombatFX.FXType.TEXT, Color("ff8a8a"), 0.7, 40.0, "-%d" % amount)
	_request_hit_stop(0.045)
	_add_camera_trauma(0.34)
	hud.play_screen_flash(Color("e52f48"), 0.18, 0.18)

func _on_player_potion_used() -> void:
	audio.play_potion()

func _on_enemy_died(enemy: CovenantEnemy, xp_reward: int, was_boss: bool) -> void:
	audio.play_enemy_death(was_boss)
	var death_position := enemy.global_position
	enemies.erase(enemy)
	if was_boss and boss == enemy:
		boss = null
	player.kills += 1
	player.gold += rng.randi_range(3, 9) * (3 if was_boss else 1)
	_spawn_fx(death_position, CombatFX.FXType.DEATH, Color("b55762") if not was_boss else Color("ff784e"), 0.72, 72.0 if was_boss else 42.0)
	_spawn_sprite_fx(death_position, SpriteFXScript.EffectID.EATER_FIRE, Color("c66b73") if not was_boss else Color("ff8a58"), 0.62 if not was_boss else 1.25)
	if not was_boss:
		player.add_experience(xp_reward)
		_roll_enemy_loot(death_position)
	else:
		player.add_experience(xp_reward)
		_on_victory()

func _roll_enemy_loot(drop_position: Vector2) -> void:
	if rng.randf() < 0.32:
		_spawn_item_pickup(drop_position + Vector2(rng.randf_range(-16, 16), rng.randf_range(-8, 8)), LootItem.roll(player.level, rng))
	if rng.randf() < 0.13:
		_spawn_currency_pickup(drop_position + Vector2(20, 0), LootPickup.PickupKind.POTION, 1)
	_spawn_currency_pickup(drop_position + Vector2(-12, 4), LootPickup.PickupKind.GOLD, rng.randi_range(4, 13))

func _spawn_guaranteed_relic(drop_position: Vector2) -> void:
	var slots: Array[StringName] = [&"weapon", &"armor", &"charm"]
	var item := LootItem.roll(player.level + anchors_destroyed, rng, slots[clampi(anchors_destroyed - 1, 0, 2)])
	item.rarity = maxi(item.rarity, LootItem.Rarity.RARE) as LootItem.Rarity
	_spawn_item_pickup(drop_position, item)

func _spawn_item_pickup(drop_position: Vector2, item: LootItem) -> void:
	var pickup := PickupScript.new() as LootPickup
	pickup.setup_item(item, player)
	pickup.global_position = drop_position
	loot_layer.add_child(pickup)
	pickup.collected.connect(_on_pickup_collected)

func _spawn_currency_pickup(drop_position: Vector2, kind: LootPickup.PickupKind, amount: int) -> void:
	var pickup := PickupScript.new() as LootPickup
	pickup.setup_currency(kind, amount, player)
	pickup.global_position = drop_position
	loot_layer.add_child(pickup)
	pickup.collected.connect(_on_pickup_collected)

func _on_pickup_collected(pickup: LootPickup) -> void:
	match pickup.kind:
		LootPickup.PickupKind.ITEM:
			var equipped_now := player.equip_loot(pickup.item)
			var suffix := "  •  EQUIPPED" if equipped_now else "  •  STORED"
			_show_announcement("%s%s" % [pickup.item.display_name.to_upper(), suffix], pickup.item.rarity_color(), 2.2)
		LootPickup.PickupKind.POTION:
			player.potions = clampi(player.potions + pickup.amount, 0, 9)
			player.potions_changed.emit(player.potions)
			_show_announcement("HEALTH POTION +%d" % pickup.amount, Color("e6596d"), 1.2)
		LootPickup.PickupKind.GOLD:
			player.gold += pickup.amount
			_show_announcement("%d GOLD" % pickup.amount, Color("f1c75b"), 0.7)
	audio.play_pickup(pickup.kind == LootPickup.PickupKind.ITEM)
	_spawn_fx(player.global_position, CombatFX.FXType.PICKUP, pickup.pickup_color(), 0.42, 34.0)

func _update_exploration(delta: float) -> void:
	shortcut_cooldown = maxf(0.0, shortcut_cooldown - delta)
	for hazard_id in hazard_timers.keys():
		hazard_timers[hazard_id] = maxf(0.0, float(hazard_timers[hazard_id]) - delta)
	var room := world_renderer.room_at_point(player.global_position)
	if not room.is_empty():
		var room_id := String(room.get("id", ""))
		if room_id != current_room:
			current_room = room_id
			if room_id not in discovered_rooms:
				discovered_rooms.append(room_id)
				_show_announcement(String(room.get("name", room_id)).to_upper(), Color("cdb99f"), 1.35)
	_update_hazards()
	_update_shortcuts()

func _update_hazards() -> void:
	for hazard_feature in _map_features_of_type(DungeonMapFeature.FeatureType.SPIKE_TRAP):
		var hazard := hazard_feature.hazard_data()
		var hazard_id := String(hazard.get("id", "hazard"))
		if float(hazard_timers.get(hazard_id, 0.0)) > 0.0:
			continue
		var hazard_position := _position_from_data(hazard)
		if player.global_position.distance_to(hazard_position) > float(hazard.get("radius", 44.0)):
			continue
		var push_direction := (player.global_position - hazard_position).normalized()
		if push_direction == Vector2.ZERO:
			push_direction = Vector2.DOWN
		var packet := DamagePacket.new(float(hazard.get("damage", 12.0)), self, hazard_position, push_direction * 125.0, DamagePacket.DamageKind.PHYSICAL)
		if player.take_damage(packet):
			_spawn_fx(hazard_position, CombatFX.FXType.HIT, Color("cf4151"), 0.35, 46.0)
			_show_announcement("SPIKE TRAP", Color("e76868"), 0.75)
		hazard_timers[hazard_id] = float(hazard.get("period", 1.0))

func _update_shortcuts() -> void:
	if shortcut_cooldown > 0.0:
		return
	for shortcut_feature in _map_features_of_type(DungeonMapFeature.FeatureType.SHORTCUT_GATE):
		var shortcut := shortcut_feature.shortcut_data()
		var anchor := _anchor_by_id(String(shortcut.get("anchor", "")))
		if anchor.is_empty() or bool(anchor.get("alive", true)):
			continue
		var trigger: Dictionary = shortcut.get("trigger", {})
		var trigger_rect := Rect2(float(trigger.get("x", 0.0)), float(trigger.get("y", 0.0)), float(trigger.get("w", 0.0)), float(trigger.get("h", 0.0)))
		if not trigger_rect.has_point(player.global_position):
			continue
		var target_position := _position_from_data(shortcut, "target")
		_spawn_fx(player.global_position, CombatFX.FXType.NOVA, Color("728bc4"), 0.5, 56.0)
		player.global_position = target_position
		player.velocity = Vector2.ZERO
		shortcut_cooldown = 1.2
		_spawn_fx(target_position, CombatFX.FXType.NOVA, Color("728bc4"), 0.5, 56.0)
		_show_announcement("CRYPT SHORTCUT", Color("91add5"), 1.2)
		break

func _on_level_up(new_level: int) -> void:
	if phase == GamePhase.PLAYING:
		audio.play_level_up()
		_spawn_fx(player.global_position, CombatFX.FXType.LEVEL_UP, Color("ffd16a"), 1.0, 100.0)
		hud.play_level_up_notice(new_level, 1)
		_show_announcement("LEVEL %d  •  SKILL POINT +1" % new_level, Color("ffd16a"), 2.0)
	print("[ASHEN] LEVEL_UP level=%d" % new_level)

func open_skill_tree() -> void:
	if phase == GamePhase.PLAYING:
		audio.play_ui_confirm()
		_set_phase(GamePhase.SKILL_TREE)

func purchase_skill(skill_id: String) -> void:
	if phase != GamePhase.SKILL_TREE:
		return
	if not player.purchase_skill(StringName(skill_id)):
		return
	var skill_rank := player.get_skill_rank(StringName(skill_id))
	audio.play_ui_confirm()
	_show_announcement("%s  •  RANK %d" % [skill_id.replace("_", " ").to_upper(), skill_rank], Color("f0cc77"), 1.7)

func _on_player_died() -> void:
	_set_phase(GamePhase.DEFEAT)
	audio.play_defeat()
	_spawn_fx(player.global_position, CombatFX.FXType.DEATH, Color("d33d50"), 1.1, 120.0)
	_spawn_sprite_fx(player.global_position, SpriteFXScript.EffectID.EATER_FIRE, Color("e45765"), 1.0)
	print("[ASHEN] PLAYER_DEFEATED time=%.1f" % run_time)

func _on_victory() -> void:
	_set_phase(GamePhase.VICTORY)
	audio.play_victory()
	_save_service().delete_save()
	objective = "Covenant broken"
	print("[ASHEN] VICTORY level=%d kills=%d gold=%d time=%.1f" % [player.level, player.kills, player.gold, run_time])

func _set_phase(new_phase: GamePhase) -> void:
	phase = new_phase
	match phase:
		GamePhase.TITLE:
			audio.set_music_state(AshenAudioDirector.MusicState.TITLE)
		GamePhase.PLAYING:
			audio.set_music_state(AshenAudioDirector.MusicState.BOSS if is_instance_valid(boss) else AshenAudioDirector.MusicState.EXPLORE)
		GamePhase.VICTORY:
			audio.set_music_state(AshenAudioDirector.MusicState.VICTORY)
		GamePhase.DEFEAT:
			audio.set_music_state(AshenAudioDirector.MusicState.DEFEAT)
	audio.set_menu_ducked(phase in [GamePhase.SHEET, GamePhase.SKILL_TREE, GamePhase.PAUSED])
	player.gameplay_enabled = phase == GamePhase.PLAYING
	if phase != GamePhase.PLAYING:
		player.velocity = Vector2.ZERO
		player.cancel_pointer_command()
	if phase in [GamePhase.TITLE, GamePhase.VICTORY, GamePhase.DEFEAT]:
		_restore_time_scale()

func _on_title_new_game_requested() -> void:
	if phase == GamePhase.TITLE:
		audio.play_ui_confirm()
		start_new_game()

func _on_title_continue_requested() -> void:
	if phase == GamePhase.TITLE and _save_service().has_save():
		audio.play_ui_confirm()
		continue_game()

func _on_title_exit_requested() -> void:
	if phase == GamePhase.TITLE:
		get_tree().quit()

func _on_screen_shake_setting_changed(enabled: bool) -> void:
	audio.play_ui_confirm()
	screen_shake_enabled = enabled
	if not screen_shake_enabled:
		camera_trauma = 0.0
		if is_instance_valid(combat_camera):
			combat_camera.offset = Vector2.ZERO

func _show_announcement(message: String, color: Color = Color.WHITE, duration: float = 1.1) -> void:
	announcement = message
	announcement_color = color
	announcement_timer = duration

func _spawn_fx(fx_position: Vector2, type: CombatFX.FXType, color: Color, life: float, radius: float, label_text: String = "") -> CombatFX:
	var fx := FXScript.new() as CombatFX
	fx.setup(type, color, life, radius, label_text)
	fx.global_position = fx_position
	effects.add_child(fx)
	return fx

func _spawn_sprite_fx(fx_position: Vector2, type: int, color: Color, scale_factor: float, speed: float = 1.0) -> Node2D:
	var fx = SpriteFXScript.new()
	fx.setup(type, color, scale_factor, speed)
	fx.global_position = fx_position
	effects.add_child(fx)
	return fx

func _on_player_dash(origin: Vector2, direction: Vector2) -> void:
	audio.play_dash()
	var packet := player.create_shadow_step_packet(origin, direction)
	var hits := 0
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.global_position.distance_to(origin) > 64.0:
			continue
		if enemy.take_damage(packet):
			hits += 1
	if hits > 0:
		_spawn_fx(origin, CombatFX.FXType.HIT, Color("a987ff"), 0.28, 52.0)
		_add_camera_trauma(0.16)
		_show_announcement("SHADOW STEP  •  PHASE REND", Color("b7a0ff"), 0.75)
	var dash_fx := _spawn_sprite_fx(origin - direction * 12.0, SpriteFXScript.EffectID.BLUE_TOP, Color("a987ff"), 0.36, 1.35)
	dash_fx.rotation = direction.angle() + PI * 0.5

func _request_hit_stop(duration: float) -> void:
	if phase != GamePhase.PLAYING or duration <= 0.0:
		return
	hit_stop_generation += 1
	var generation := hit_stop_generation
	Engine.time_scale = 0.10
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void:
		if generation == hit_stop_generation:
			Engine.time_scale = 1.0
	)

func _restore_time_scale() -> void:
	hit_stop_generation += 1
	Engine.time_scale = 1.0

func _add_camera_trauma(amount: float) -> void:
	if not screen_shake_enabled:
		return
	camera_trauma = clampf(maxf(camera_trauma, amount), 0.0, 1.0)

func _update_camera_feedback(delta: float) -> void:
	if not is_instance_valid(combat_camera):
		return
	camera_noise_time += delta
	camera_trauma = maxf(0.0, camera_trauma - delta * 2.8)
	if camera_trauma <= 0.001:
		combat_camera.offset = combat_camera.offset.lerp(Vector2.ZERO, clampf(delta * 22.0, 0.0, 1.0))
		return
	var strength := camera_trauma * camera_trauma * 13.0
	combat_camera.offset = Vector2(
		sin(camera_noise_time * 79.0 + 0.7),
		cos(camera_noise_time * 91.0 + 1.9)
	) * strength

func _exit_tree() -> void:
	_restore_time_scale()
	if is_instance_valid(combat_camera):
		combat_camera.offset = Vector2.ZERO

func _save_checkpoint() -> void:
	var opened_chests: Array[String] = []
	for chest: Dictionary in chests:
		if bool(chest.get("opened", false)):
			opened_chests.append(String(chest.get("id", "")))
	_save_service().save_game({
		"anchors_destroyed": anchors_destroyed,
		"player": player.to_save_dict(),
		"run_time": run_time,
		"opened_chests": opened_chests,
		"discovered_rooms": discovered_rooms.duplicate()
	})

func _update_hud() -> void:
	if not hud or not player:
		return
	var equipment_display: Array[Dictionary] = []
	for slot in [&"weapon", &"armor", &"charm"]:
		var item := player.equipped.get(slot) as LootItem
		equipment_display.append({
			"slot": String(slot).to_upper(),
			"name": item.display_name if item else "Empty",
			"color": item.rarity_color() if item else Color("716971")
		})
	var loot_display: Array[Dictionary] = []
	for item in player.loot_history:
		loot_display.append({"name": item.display_name, "color": item.rarity_color()})
	var stats_display: Array[String] = [
		"Life           %d / %d" % [int(player.health), int(player.max_health())],
		"Essence        %d / %d" % [int(player.mana), int(player.max_mana())],
		"Weapon Damage  %d - %d" % [int(player.base_damage + player.gear_damage()), int((player.base_damage + player.gear_damage()) * 1.45)],
		"Armor          %d" % int(player.armor_total()),
		"Critical       %.1f%%" % (player.crit_chance() * 100.0)
	]
	hud.update_snapshot({
		"phase": GamePhase.keys()[phase], "has_save": _save_service().has_save(),
		"health": player.health, "health_max": player.max_health(), "health_ratio": player.health / player.max_health(),
		"mana": player.mana, "mana_max": player.max_mana(), "mana_ratio": player.mana / player.max_mana(),
		"xp_ratio": float(player.experience) / float(maxi(1, player.experience_required())),
		"xp_current": player.experience, "xp_required": player.experience_required(),
		"level": player.level, "kills": player.kills, "gold": player.gold, "potions": player.potions,
		"skill_points": player.skill_points, "skills": player.get_skill_tree_snapshot(),
		"anchors_destroyed": anchors_destroyed, "anchors_total": anchors.size(), "objective": objective,
		"attack_cd": player.cooldown_ratio(&"attack"), "nova_cd": player.cooldown_ratio(&"nova"), "dash_cd": player.cooldown_ratio(&"dash"),
		"boss_visible": is_instance_valid(boss), "boss_ratio": boss.health_ratio() if is_instance_valid(boss) else 0.0,
		"message": announcement if announcement_timer > 0.0 else "",
		"message_alpha": clampf(announcement_timer * 1.5, 0.0, 1.0), "message_color": announcement_color,
		"sheet_open": sheet_open, "stats": stats_display, "equipment": equipment_display, "loot": loot_display,
		"player_position": player.global_position, "current_room": current_room,
		"discovered_rooms": discovered_rooms.duplicate(), "minimap_rooms": dungeon_layout.get("rooms", []),
		"minimap_anchors": anchors, "minimap_chests": chests,
		"gate_open": anchors_destroyed >= anchors.size()
	})

func get_playtest_state() -> Dictionary:
	var opened_count := 0
	for chest: Dictionary in chests:
		if bool(chest.get("opened", false)):
			opened_count += 1
	return {
		"phase": GamePhase.keys()[phase], "player_health": player.health,
		"player_level": player.level, "enemy_count": enemies.size(),
		"anchors_destroyed": anchors_destroyed, "boss_alive": is_instance_valid(boss),
		"kills": player.kills, "gold": player.gold,
		"current_room": current_room, "discovered_rooms": discovered_rooms.size(),
		"opened_chests": opened_count
	}

func _save_service() -> Node:
	return get_node("/root/SaveManager")

func playtest_start() -> void:
	start_new_game()

func playtest_break_all_anchors() -> void:
	if phase == GamePhase.TITLE:
		start_new_game()
	for anchor in anchors:
		if bool(anchor.alive):
			_damage_anchor(anchor, float(anchor.health) + 1.0)

func playtest_damage_boss(amount: float) -> void:
	if is_instance_valid(boss):
		boss.take_damage(DamagePacket.new(amount, player, player.global_position, Vector2.ZERO, DamagePacket.DamageKind.ASH, true))

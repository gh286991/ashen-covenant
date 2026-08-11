class_name CovenantHUDSurface
extends Control

signal upgrade_selected(id: String)

const ICON_CLEAVE := preload("res://assets/ui/ability_icons/single-1.png")
const ICON_NOVA := preload("res://assets/ui/ability_icons/single-2.png")
const ICON_STEP := preload("res://assets/ui/ability_icons/single-3.png")
const ICON_POTION := preload("res://assets/ui/ability_icons/single-4.png")
const GOTHIC_HUD_FRAME := preload("res://assets/ui/gothic_hud/gothic-hud-frame.png")
const VIRTUAL_SIZE := Vector2(1280.0, 720.0)
const GOTHIC_HUD_SOURCE := Rect2(0.0, 205.0, 1672.0, 530.0)
const GOTHIC_HUD_RECT := Rect2(115.0, 385.0, 1050.0, 333.0)
const LIFE_ORB_CENTER := Vector2(314.0, 603.0)
const ESSENCE_ORB_CENTER := Vector2(966.0, 603.0)
const UPGRADE_IDS: Array[String] = ["iron_oath", "executioner", "blood_rush"]

var snapshot: Dictionary = {}
var _canvas_scale := 1.0
var _canvas_offset := Vector2.ZERO
var _upgrade_hovered := -1
var _upgrade_focused := 0
var _upgrade_mode := false
var _upgrade_selection_locked := false
var _flash_color := Color.TRANSPARENT
var _flash_intensity := 0.0
var _flash_started_msec := 0
var _flash_duration_msec := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_NONE
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func update_snapshot(data: Dictionary) -> void:
	var next_upgrade_mode := String(data.get("phase", "TITLE")) == "UPGRADE"
	snapshot = data
	if next_upgrade_mode != _upgrade_mode:
		_set_upgrade_mode(next_upgrade_mode)
	queue_redraw()

func play_screen_flash(color: Color, intensity: float = 0.3, duration: float = 0.14) -> void:
	_flash_color = color
	_flash_intensity = clampf(intensity, 0.0, 1.0)
	_flash_started_msec = Time.get_ticks_msec()
	_flash_duration_msec = maxi(1, int(maxf(duration, 0.01) * 1000.0))
	queue_redraw()

func _process(_delta: float) -> void:
	if _flash_duration_msec <= 0:
		return
	if Time.get_ticks_msec() - _flash_started_msec >= _flash_duration_msec:
		_flash_duration_msec = 0
	queue_redraw()

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	_update_virtual_canvas(viewport_size)
	_draw_screen_flash(viewport_size)
	draw_set_transform(_canvas_offset, 0.0, Vector2.ONE * _canvas_scale)
	var canvas_size := VIRTUAL_SIZE
	_draw_vignette(canvas_size)
	var phase := String(snapshot.get("phase", "TITLE"))
	if phase == "TITLE":
		_draw_title(canvas_size)
	else:
		var boss_visible := bool(snapshot.get("boss_visible", false))
		var sheet_open := bool(snapshot.get("sheet_open", false))
		_draw_top_hud(canvas_size)
		if not boss_visible and not sheet_open:
			_draw_minimap(canvas_size)
		_draw_bottom_hud(canvas_size)
		_draw_boss_bar(canvas_size)
		_draw_message(canvas_size)
		if sheet_open:
			_draw_character_sheet(canvas_size)
		match phase:
			"UPGRADE": _draw_upgrade(canvas_size)
			"PAUSED": _draw_modal(canvas_size, "PAUSED", "Press Esc to return to the hunt", Color("d9c7ac"))
			"VICTORY": _draw_victory(canvas_size)
			"DEFEAT": _draw_modal(canvas_size, "YOU HAVE FALLEN", "Press Enter to rise again", Color("d95858"))
	draw_set_transform(Vector2.ZERO)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _update_virtual_canvas(viewport_size: Vector2) -> void:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_canvas_scale = 1.0
		_canvas_offset = Vector2.ZERO
		return
	_canvas_scale = minf(viewport_size.x / VIRTUAL_SIZE.x, viewport_size.y / VIRTUAL_SIZE.y)
	_canvas_offset = (viewport_size - VIRTUAL_SIZE * _canvas_scale) * 0.5

func _viewport_to_virtual(viewport_position: Vector2) -> Vector2:
	_update_virtual_canvas(get_viewport_rect().size)
	return (viewport_position - _canvas_offset) / maxf(_canvas_scale, 0.001)

func blocks_world_pointer(viewport_position: Vector2) -> bool:
	var point := _viewport_to_virtual(viewport_position)
	if not Rect2(Vector2.ZERO, VIRTUAL_SIZE).has_point(point):
		return true
	if Rect2(40, 40, 390, 82).has_point(point):
		return true
	if Rect2(VIRTUAL_SIZE.x - 272, 40, 232, 236).has_point(point):
		return true
	if bool(snapshot.get("boss_visible", false)) and Rect2(262, 126, 756, 66).has_point(point):
		return true
	if Rect2(115, 385, 305, 335).has_point(point) or Rect2(860, 385, 305, 335).has_point(point):
		return true
	return Rect2(405, 535, 470, 185).has_point(point)

func _draw_screen_flash(viewport_size: Vector2) -> void:
	if _flash_duration_msec <= 0:
		return
	var elapsed := float(Time.get_ticks_msec() - _flash_started_msec)
	var progress := clampf(elapsed / float(_flash_duration_msec), 0.0, 1.0)
	var flash := _flash_color
	flash.a *= _flash_intensity * pow(1.0 - progress, 2.0)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), flash)

func _draw_vignette(canvas_size: Vector2) -> void:
	var edge := Color(0.01, 0.005, 0.015, 0.42)
	draw_rect(Rect2(0, 0, canvas_size.x, 22), edge)
	draw_rect(Rect2(0, 0, 18, canvas_size.y), edge)
	draw_rect(Rect2(canvas_size.x - 18, 0, 18, canvas_size.y), edge)

func _draw_title(canvas_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.015, 0.008, 0.02, 0.76))
	var center := canvas_size * 0.5
	for i in 4:
		draw_arc(center - Vector2(0, 54), 132.0 + i * 19.0, 0.0, TAU, 5, Color(0.42, 0.08, 0.12, 0.18 - i * 0.03), 3.0)
	_center_text("ASHEN COVENANT", center.y - 92.0, 54, Color("e6d4b8"), canvas_size.x)
	_center_text("A DARK ACTION RPG DEMO", center.y - 34.0, 18, Color("b9655f"), canvas_size.x)
	_center_text("Three soul anchors bind the Ashen Warden.", center.y + 36.0, 20, Color("c5b9ac"), canvas_size.x)
	_center_text("Break them. Claim their relics. End the covenant.", center.y + 66.0, 20, Color("c5b9ac"), canvas_size.x)
	_center_text("Press Enter to begin", center.y + 142.0 + sin(Time.get_ticks_msec() * 0.004) * 4.0, 24, Color("f0b75e"), canvas_size.x)
	if bool(snapshot.get("has_save", false)):
		_center_text("Press C to continue from the last broken anchor", center.y + 184.0, 17, Color("8fb5c9"), canvas_size.x)
	_center_text("Left Click Move / Attack  •  Right Click Ash Nova  •  Space Shadow Step  •  R Potion", canvas_size.y - 64.0, 16, Color("91858d"), canvas_size.x)

func _draw_top_hud(canvas_size: Vector2) -> void:
	_panel(Rect2(40, 40, 390, 82), Color(0.035, 0.025, 0.04, 0.88), Color("6d4a50"))
	_text("COVENANT OF ASH", Vector2(60, 67), 17, Color("d5b895"))
	_text(_fit_text(String(snapshot.get("objective", "Find the soul anchors")), 17, 286.0), Vector2(60, 94), 17, Color("e8e1d8"))
	var done := int(snapshot.get("anchors_destroyed", 0))
	var total := int(snapshot.get("anchors_total", 3))
	for i in total:
		var c := Color("d94c68") if i < done else Color("3b303c")
		draw_colored_polygon(PackedVector2Array([Vector2(365 + i * 20, 64), Vector2(372 + i * 20, 75), Vector2(365 + i * 20, 86), Vector2(358 + i * 20, 75)]), c)
	if bool(snapshot.get("boss_visible", false)):
		return
	_panel(Rect2(canvas_size.x - 272, 40, 232, 82), Color(0.035, 0.025, 0.04, 0.88), Color("6d4a50"))
	_text("LEVEL %d" % int(snapshot.get("level", 1)), Vector2(canvas_size.x - 250, 67), 18, Color("d5b895"))
	_text("Kills  %d" % int(snapshot.get("kills", 0)), Vector2(canvas_size.x - 250, 94), 16, Color("aaa0a4"))
	_text("Gold  %d" % int(snapshot.get("gold", 0)), Vector2(canvas_size.x - 147, 94), 16, Color("f1c75b"))

func _draw_minimap(canvas_size: Vector2) -> void:
	var panel_rect := Rect2(canvas_size.x - 272, 134, 232, 142)
	_panel(panel_rect, Color(0.025, 0.018, 0.03, 0.91), Color("59444f"))
	var inner := Rect2(panel_rect.position + Vector2(14, 25), Vector2(204, 102))
	draw_rect(inner, Color(0.015, 0.012, 0.02, 0.88))
	var scale_x := inner.size.x / 2200.0
	var scale_y := inner.size.y / 1400.0
	var discovered: Array = snapshot.get("discovered_rooms", [])
	var rooms: Array = snapshot.get("minimap_rooms", [])
	var current_id := String(snapshot.get("current_room", ""))
	var current_label := "CATACOMBS"
	for room_variant in rooms:
		var room: Dictionary = room_variant
		var room_id := String(room.get("id", ""))
		if room_id == current_id:
			current_label = String(room.get("name", "CATACOMBS"))
		if room_id not in discovered:
			continue
		var fill := Color("684851") if room_id == current_id else Color("342b39")
		if String(room.get("shape", "rect")) == "ellipse":
			var center := inner.position + Vector2(float(room.get("x", 0.0)) * scale_x, float(room.get("y", 0.0)) * scale_y)
			var radii := Vector2(float(room.get("rx", 1.0)) * scale_x, float(room.get("ry", 1.0)) * scale_y)
			draw_colored_polygon(_ellipse_polygon(center, radii), fill)
		else:
			var room_rect := Rect2(inner.position + Vector2(float(room.get("x", 0.0)) * scale_x, float(room.get("y", 0.0)) * scale_y), Vector2(float(room.get("w", 0.0)) * scale_x, float(room.get("h", 0.0)) * scale_y))
			draw_rect(room_rect, fill)
	for anchor_variant in snapshot.get("minimap_anchors", []):
		var anchor: Dictionary = anchor_variant
		if not bool(anchor.get("alive", true)):
			continue
		var anchor_position: Vector2 = anchor.get("position", Vector2.ZERO)
		var p := inner.position + Vector2(anchor_position.x * scale_x, anchor_position.y * scale_y)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), Color("df4b67"))
	for chest_variant in snapshot.get("minimap_chests", []):
		var chest: Dictionary = chest_variant
		if bool(chest.get("hidden", false)) and not bool(chest.get("opened", false)):
			continue
		var p := inner.position + Vector2(float(chest.get("x", 0.0)) * scale_x, float(chest.get("y", 0.0)) * scale_y)
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), Color("d7b65e") if not bool(chest.get("opened", false)) else Color("696057"))
	var player_position: Vector2 = snapshot.get("player_position", Vector2.ZERO)
	var player_dot := inner.position + Vector2(player_position.x * scale_x, player_position.y * scale_y)
	draw_circle(player_dot, 3.5, Color("f2e8d7"))
	draw_arc(player_dot, 5.5, 0.0, TAU, 16, Color("9c384b"), 1.5)
	_text(_fit_text(current_label, 13, 204.0), panel_rect.position + Vector2(14, 19), 13, Color("cdb99f"))

func _draw_bottom_hud(canvas_size: Vector2) -> void:
	var health := int(snapshot.get("health", 0))
	var mana := int(snapshot.get("mana", 0))
	var health_max := maxi(health, int(snapshot.get("health_max", health)))
	var mana_max := maxi(mana, int(snapshot.get("mana_max", mana)))
	_draw_gothic_orb_fill(LIFE_ORB_CENTER, 66.0, float(snapshot.get("health_ratio", 1.0)), Color("b71f35"))
	_draw_gothic_orb_fill(ESSENCE_ORB_CENTER, 66.0, float(snapshot.get("mana_ratio", 1.0)), Color("245ab8"))
	draw_texture_rect_region(GOTHIC_HUD_FRAME, GOTHIC_HUD_RECT, GOTHIC_HUD_SOURCE)
	var skills := [
		{"key": "LMB", "name": "CLEAVE", "icon": ICON_CLEAVE, "color": Color("c97755"), "cooldown": snapshot.get("attack_cd", 0.0)},
		{"key": "RMB", "name": "ASH NOVA", "icon": ICON_NOVA, "color": Color("985ccb"), "cooldown": snapshot.get("nova_cd", 0.0)},
		{"key": "SPACE", "name": "STEP", "icon": ICON_STEP, "color": Color("6572b8"), "cooldown": snapshot.get("dash_cd", 0.0)},
		{"key": "R", "name": "POTION %d" % int(snapshot.get("potions", 0)), "icon": ICON_POTION, "color": Color("ba3f55"), "cooldown": 0.0}
	]
	for i in skills.size():
		_draw_gothic_skill(Vector2(441.0 + i * 100.5, 573.0), skills[i])
	_draw_gothic_orb_text(LIFE_ORB_CENTER, "LIFE", health, health_max, Color("fff2e4"))
	_draw_gothic_orb_text(ESSENCE_ORB_CENTER, "ESSENCE", mana, mana_max, Color("e6efff"))
	var xp_ratio := clampf(float(snapshot.get("xp_ratio", 0.0)), 0.0, 1.0)
	var level := int(snapshot.get("level", 1))
	var xp_current := maxi(0, int(snapshot.get("xp_current", roundi(float(snapshot.get("xp_required", 0)) * xp_ratio))))
	var xp_required := maxi(1, int(snapshot.get("xp_required", 1)))
	var xp_rect := Rect2(435.0, 688.0, 410.0, 7.0)
	draw_rect(xp_rect, Color("09090c"))
	draw_rect(Rect2(xp_rect.position + Vector2(2, 2), Vector2((xp_rect.size.x - 4.0) * xp_ratio, 3.0)), Color("c79a43"))
	draw_rect(xp_rect, Color("79603b"), false, 1.0)
	_center_text("LEVEL %d   %d / %d XP" % [level, xp_current, xp_required], 710.0, 12, Color("d8c394"), canvas_size.x)

func _draw_gothic_orb_fill(center: Vector2, radius: float, ratio: float, color: Color) -> void:
	draw_circle(center, radius + 1.0, Color(0.015, 0.012, 0.018, 0.98))
	draw_circle(center, radius, Color(color.darkened(0.62), 0.92))
	var fill_ratio := clampf(ratio, 0.0, 1.0)
	var fill_polygon := _circle_segment_polygon(center, radius - 2.0, fill_ratio)
	if fill_polygon.size() >= 3:
		draw_colored_polygon(fill_polygon, Color(color, 0.94))
		if fill_ratio > 0.0 and fill_ratio < 1.0:
			var water_y := center.y + radius - radius * 2.0 * fill_ratio
			var chord_half_width := sqrt(maxf(0.0, radius * radius - pow(water_y - center.y, 2.0)))
			draw_line(Vector2(center.x - chord_half_width, water_y), Vector2(center.x + chord_half_width, water_y), Color(color.lightened(0.38), 0.95), 2.0)
	draw_arc(center - Vector2(8, 7), radius - 11.0, PI * 1.12, PI * 1.56, 18, Color(1.0, 1.0, 1.0, 0.18), 3.0)
	draw_circle(center + Vector2(17, 19), 13.0, Color(color.darkened(0.52), 0.2))

func _draw_gothic_orb_text(center: Vector2, label: String, current: int, maximum: int, color: Color) -> void:
	_center_text_at(label, center + Vector2(0, -9), 12, Color(color, 0.86))
	_center_text_at("%d / %d" % [current, maximum], center + Vector2(0, 13), 17, color)

func _draw_gothic_skill(draw_position: Vector2, data: Dictionary) -> void:
	var rect := Rect2(draw_position, Vector2(84, 86))
	var color: Color = data.color
	draw_rect(rect.grow(-4.0), Color(color, 0.07))
	var icon: Texture2D = data.icon
	draw_texture_rect(icon, Rect2(draw_position + Vector2(13, 5), Vector2(58, 58)), false, Color(1.0, 1.0, 1.0, 0.96))
	var cd := clampf(float(data.cooldown), 0.0, 1.0)
	if cd > 0.0:
		draw_rect(Rect2(draw_position.x + 7, draw_position.y + 7 + 70.0 * (1.0 - cd), 70, 70.0 * cd), Color(0.01, 0.008, 0.012, 0.78))
	var key_label := String(data.key)
	var key_width := 36.0 if key_label.length() >= 3 else 26.0
	draw_rect(Rect2(draw_position + Vector2(5, 4), Vector2(key_width, 17)), Color(0.018, 0.014, 0.02, 0.92))
	draw_rect(Rect2(draw_position + Vector2(5, 4), Vector2(key_width, 17)), Color("9b7a4d"), false, 1.0)
	_text(key_label, draw_position + Vector2(8, 17), 11, Color("fff0d8"))
	_center_text_at(String(data.name), draw_position + Vector2(42, 73), 11, Color("dfd2c3"))
	draw_rect(rect.grow(-2.0), Color(color, 0.42), false, 1.0)

func _draw_skill(draw_position: Vector2, data: Dictionary) -> void:
	var rect := Rect2(draw_position, Vector2(82, 57))
	draw_rect(rect, Color("17131d"))
	draw_rect(rect.grow(-3), Color(data.color, 0.28))
	var icon: Texture2D = data.icon
	draw_texture_rect(icon, Rect2(draw_position + Vector2(20, 3), Vector2(42, 42)), false, Color(1.0, 1.0, 1.0, 0.96))
	draw_rect(rect, Color("75616a"), false, 2.0)
	var cd := clampf(float(data.cooldown), 0.0, 1.0)
	if cd > 0.0:
		draw_rect(Rect2(draw_position.x + 3, draw_position.y + 3 + 51 * (1.0 - cd), 76, 51 * cd), Color(0.02, 0.01, 0.025, 0.74))
	draw_rect(Rect2(draw_position + Vector2(3, 3), Vector2(38 if String(data.key) == "SPACE" else 28, 18)), Color(0.04, 0.025, 0.05, 0.9))
	_text(String(data.key), draw_position + Vector2(6, 17), 12, Color("f1e4d1"))
	_center_text_at(String(data.name), draw_position + Vector2(41, 47), 13, Color("d8cbc0"))

func _draw_boss_bar(canvas_size: Vector2) -> void:
	if not bool(snapshot.get("boss_visible", false)):
		return
	var width := 720.0
	var x := canvas_size.x * 0.5 - width * 0.5
	_panel(Rect2(x - 18, 126, width + 36, 66), Color(0.025, 0.012, 0.018, 0.94), Color("8b534f"))
	_center_text("THE ASHEN WARDEN", 150, 21, Color("f3caa2"), canvas_size.x)
	var boss_ratio := clampf(float(snapshot.get("boss_ratio", 1.0)), 0.0, 1.0)
	draw_rect(Rect2(x, 160, width, 22), Color("160f14"))
	draw_rect(Rect2(x + 4, 164, (width - 8) * boss_ratio, 14), Color("bd3d38"))
	draw_rect(Rect2(x, 160, width, 22), Color("9a6259"), false, 2.0)
	_center_text_at("%d%%" % roundi(boss_ratio * 100.0), Vector2(canvas_size.x * 0.5, 171), 13, Color("f7ddd2"))

func _draw_message(canvas_size: Vector2) -> void:
	var message := String(snapshot.get("message", ""))
	if message.is_empty(): return
	var alpha := float(snapshot.get("message_alpha", 1.0))
	var c: Color = snapshot.get("message_color", Color.WHITE)
	c.a *= alpha
	var y := canvas_size.y * (0.29 if bool(snapshot.get("boss_visible", false)) else 0.24)
	_center_text(message, y, 24, c, canvas_size.x)

func _draw_character_sheet(canvas_size: Vector2) -> void:
	var rect := Rect2(canvas_size.x - 460, 132, 420, 464)
	_panel(rect, Color(0.025, 0.018, 0.03, 0.97), Color("80635d"))
	_text("CHARACTER & RELICS", rect.position + Vector2(24, 35), 23, Color("e2c59c"))
	var stats: Array = snapshot.get("stats", [])
	for i in mini(5, stats.size()):
		_draw_stat_row(String(stats[i]), rect.position + Vector2(24, 69 + i * 22), rect.size.x - 48.0)
	_text("EQUIPPED", rect.position + Vector2(24, 194), 17, Color("b8947c"))
	var equipped_items: Array = snapshot.get("equipment", [])
	for i in mini(3, equipped_items.size()):
		var item: Dictionary = equipped_items[i]
		_text(String(item.get("slot", "RELIC")), rect.position + Vector2(24, 222 + i * 29), 14, Color("a3959a"))
		_text(_fit_text(String(item.get("name", "Empty")), 15, 270.0), rect.position + Vector2(114, 222 + i * 29), 15, item.get("color", Color("8f878f")))
	_text("RECENT FINDS", rect.position + Vector2(24, 322), 17, Color("b8947c"))
	var loot: Array = snapshot.get("loot", [])
	for i in mini(4, loot.size()):
		var entry: Dictionary = loot[i]
		_text(_fit_text(String(entry.get("name", "Unknown")), 15, rect.size.x - 48.0), rect.position + Vector2(24, 349 + i * 23), 15, entry.get("color", Color.WHITE))
	_right_text("TAB / ESC  CLOSE", rect.position + Vector2(rect.size.x - 24, rect.size.y - 18), 14, Color("a99ca2"))

func _draw_upgrade(canvas_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.01, 0.005, 0.015, 0.72))
	_center_text("POWER AWAKENS", 134, 36, Color("f0cc77"), canvas_size.x)
	_center_text("Choose one covenant boon", 172, 19, Color("c8b8ae"), canvas_size.x)
	var choices := [
		{"key": "1", "title": "IRON OATH", "body": "+32 Life  •  +5 Armor", "color": Color("b55d55")},
		{"key": "2", "title": "EXECUTIONER", "body": "+5 Damage  •  +4.5% Critical", "color": Color("d49a49")},
		{"key": "3", "title": "BLOOD RUSH", "body": "+18 Essence  •  Faster Ash Nova", "color": Color("845db8")}
	]
	for i in choices.size():
		var rect := _upgrade_rect(i)
		var selected := i == (_upgrade_hovered if _upgrade_hovered >= 0 else _upgrade_focused)
		var fill := Color(0.075, 0.045, 0.08, 0.99) if selected else Color(0.045, 0.027, 0.05, 0.97)
		_panel(rect, fill, choices[i].color)
		if selected:
			draw_rect(rect.grow(5.0), Color(choices[i].color, 0.24))
			draw_rect(rect.grow(3.0), choices[i].color.lightened(0.2), false, 3.0)
		_center_text_at(choices[i].key, rect.position + Vector2(120, 44), 28, Color("f4ead8"))
		_center_text_at(choices[i].title, rect.position + Vector2(120, 91), 21, choices[i].color)
		_center_text_at(choices[i].body, rect.position + Vector2(120, 134), 15, Color("d8cdc7"))
	_center_text("Click a boon  •  1 / 2 / 3  •  Arrow keys + Enter", 476, 16, Color("a99da1"), canvas_size.x)

func _draw_victory(canvas_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.015, 0.008, 0.018, 0.82))
	_center_text("COVENANT BROKEN", canvas_size.y * 0.34, 46, Color("efc66f"), canvas_size.x)
	_center_text("The Ashen Warden is no more.", canvas_size.y * 0.42, 21, Color("d7ccc1"), canvas_size.x)
	_center_text("Level %d   •   %d kills   •   %d gold" % [snapshot.get("level", 1), snapshot.get("kills", 0), snapshot.get("gold", 0)], canvas_size.y * 0.52, 20, Color("bcaeaa"), canvas_size.x)
	_center_text("Press Enter to begin a new hunt", canvas_size.y * 0.65, 22, Color("e78f5e"), canvas_size.x)

func _draw_modal(canvas_size: Vector2, title: String, subtitle: String, color: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.01, 0.005, 0.015, 0.76))
	_center_text(title, canvas_size.y * 0.43, 44, color, canvas_size.x)
	_center_text(subtitle, canvas_size.y * 0.54, 19, Color("c9bec0"), canvas_size.x)

func _panel(rect: Rect2, fill: Color, border: Color) -> void:
	var points := _chamfered_rect_points(rect, 9.0)
	draw_colored_polygon(points, fill)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, border, 2.0, true)
	draw_line(rect.position + Vector2(18, 8), rect.position + Vector2(rect.size.x - 18, 8), Color(border, 0.5), 1.0)
	draw_colored_polygon(PackedVector2Array([
		rect.position + Vector2(rect.size.x * 0.5, 4),
		rect.position + Vector2(rect.size.x * 0.5 + 5, 9),
		rect.position + Vector2(rect.size.x * 0.5, 14),
		rect.position + Vector2(rect.size.x * 0.5 - 5, 9),
	]), Color(border, 0.72))

func _chamfered_rect_points(rect: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position + Vector2(cut, 0),
		rect.position + Vector2(rect.size.x - cut, 0),
		rect.position + Vector2(rect.size.x, cut),
		rect.position + Vector2(rect.size.x, rect.size.y - cut),
		rect.position + Vector2(rect.size.x - cut, rect.size.y),
		rect.position + Vector2(cut, rect.size.y),
		rect.position + Vector2(0, rect.size.y - cut),
		rect.position + Vector2(0, cut),
	])

func _text(value: String, draw_position: Vector2, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, draw_position, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _center_text(value: String, y: float, font_size: int, color: Color, width: float) -> void:
	var text_width := ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(value, Vector2((width - text_width) * 0.5, y), font_size, color)

func _center_text_at(value: String, center: Vector2, font_size: int, color: Color) -> void:
	var dimensions := ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_text(value, center + Vector2(-dimensions.x * 0.5, dimensions.y * 0.32), font_size, color)

func _right_text(value: String, draw_position: Vector2, font_size: int, color: Color) -> void:
	var text_width := ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(value, draw_position - Vector2(text_width, 0.0), font_size, color)

func _draw_stat_row(value: String, draw_position: Vector2, row_width: float) -> void:
	var separator := value.find("  ")
	if separator < 0:
		_text(_fit_text(value, 15, row_width), draw_position, 15, Color("d3cbd0"))
		return
	var label := value.substr(0, separator).strip_edges()
	var stat_value := value.substr(separator).strip_edges()
	_text(_fit_text(label, 15, row_width * 0.62), draw_position, 15, Color("b3a9ae"))
	_right_text(_fit_text(stat_value, 15, row_width * 0.38), draw_position + Vector2(row_width, 0.0), 15, Color("e4dce0"))

func _fit_text(value: String, font_size: int, max_width: float) -> String:
	if ThemeDB.fallback_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
		return value
	var fitted := value
	while fitted.length() > 1:
		fitted = fitted.left(fitted.length() - 1)
		var candidate := fitted.strip_edges() + "…"
		if ThemeDB.fallback_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			return candidate
	return "…"

func _ellipse_polygon(center: Vector2, radii: Vector2, segments: int = 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points

func _circle_segment_polygon(center: Vector2, radius: float, ratio: float, segments: int = 64) -> PackedVector2Array:
	if ratio <= 0.0:
		return PackedVector2Array()
	var circle := PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		circle.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if ratio >= 1.0:
		return circle
	var water_y := center.y + radius - radius * 2.0 * ratio
	var clipped := PackedVector2Array()
	for i in circle.size():
		var current := circle[i]
		var next := circle[(i + 1) % circle.size()]
		var current_inside := current.y >= water_y
		var next_inside := next.y >= water_y
		if current_inside:
			clipped.append(current)
		if current_inside != next_inside:
			var delta_y := next.y - current.y
			if not is_zero_approx(delta_y):
				var weight := (water_y - current.y) / delta_y
				clipped.append(current.lerp(next, weight))
	return clipped

func _upgrade_rect(index: int) -> Rect2:
	return Rect2(VIRTUAL_SIZE.x * 0.5 - 390.0 + index * 270.0, 232.0, 240.0, 190.0)

func _upgrade_index_at(viewport_position: Vector2) -> int:
	var virtual_position := _viewport_to_virtual(viewport_position)
	for i in UPGRADE_IDS.size():
		if _upgrade_rect(i).has_point(virtual_position):
			return i
	return -1

func _set_upgrade_mode(enabled: bool) -> void:
	_upgrade_mode = enabled
	_upgrade_hovered = -1
	_upgrade_focused = 0
	_upgrade_selection_locked = false
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		grab_focus()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		release_focus()
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not _upgrade_mode or _upgrade_selection_locked:
		return
	if event is InputEventMouseMotion:
		var next_hovered := _upgrade_index_at(event.position)
		if next_hovered != _upgrade_hovered:
			_upgrade_hovered = next_hovered
			if next_hovered >= 0:
				_upgrade_focused = next_hovered
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if next_hovered >= 0 else Control.CURSOR_ARROW
			queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked := _upgrade_index_at(event.position)
		if clicked >= 0:
			_select_upgrade(clicked)
			accept_event()
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
		_upgrade_hovered = -1
		_upgrade_focused = wrapi(_upgrade_focused - 1, 0, UPGRADE_IDS.size())
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_focus_next"):
		_upgrade_hovered = -1
		_upgrade_focused = wrapi(_upgrade_focused + 1, 0, UPGRADE_IDS.size())
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		_select_upgrade(_upgrade_focused)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _select_upgrade(0)
			KEY_2: _select_upgrade(1)
			KEY_3: _select_upgrade(2)
			_: return
		accept_event()

func _select_upgrade(index: int) -> void:
	if index < 0 or index >= UPGRADE_IDS.size() or _upgrade_selection_locked:
		return
	_upgrade_selection_locked = true
	upgrade_selected.emit(UPGRADE_IDS[index])
	queue_redraw()

func _on_mouse_exited() -> void:
	if _upgrade_hovered == -1:
		return
	_upgrade_hovered = -1
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

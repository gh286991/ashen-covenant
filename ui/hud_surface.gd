class_name CovenantHUDSurface
extends Control

signal skill_selected(id: String)
signal skill_tree_requested
signal title_new_game_requested
signal title_continue_requested
signal title_exit_requested
signal screen_shake_setting_changed(enabled: bool)

const ICON_CLEAVE := preload("res://assets/ui/ability_icons/single-1.png")
const ICON_NOVA := preload("res://assets/ui/ability_icons/single-2.png")
const ICON_STEP := preload("res://assets/ui/ability_icons/single-3.png")
const ICON_POTION := preload("res://assets/ui/ability_icons/single-4.png")
const GOTHIC_HUD_FRAME := preload("res://assets/ui/gothic_hud/gothic-hud-frame.png")
const TITLE_BACKGROUND := preload("res://assets/ui/main_menu/ashen_covenant-title-bg-v1.png")
const VIRTUAL_SIZE := Vector2(1280.0, 720.0)
const HUD_SCALE := 0.70
const SKILL_TREE_SCALE := 0.80
const GOTHIC_HUD_SOURCE := Rect2(0.0, 205.0, 1672.0, 530.0)
const GOTHIC_HUD_RECT := Rect2(115.0, 385.0, 1050.0, 333.0)
const LIFE_ORB_CENTER := Vector2(314.0, 603.0)
const ESSENCE_ORB_CENTER := Vector2(966.0, 603.0)
const HOTBAR_SLOT_COUNT := 4
const SKILL_SLOT_SIZE := Vector2(84.0, 92.0)
const SKILL_SLOT_GAP := 16.5
const SKILL_ICON_SIZE := Vector2(58.0, 58.0)
const SKILL_ICON_TOP := 5.0
const LIQUID_REFRESH_MSEC := 33
const LIQUID_SURFACE_SEGMENTS := 22
const SKILL_NODE_SIZE := Vector2(250.0, 78.0)
const SKILL_BRANCH_X := [295.0, 640.0, 985.0]
const SKILL_RANK_Y := [310.0, 415.0, 520.0]
const SKILL_COLORS := [Color("b55d55"), Color("d49a49"), Color("845db8")]
const SKILL_BADGE_RECT := Rect2(785.0, 40.0, 112.0, 82.0)
const LEVEL_UP_NOTICE_DURATION_MSEC := 2600
const TITLE_REFRESH_MSEC := 33
const TITLE_MENU_ORIGIN := Vector2(92.0, 308.0)
const TITLE_MENU_SIZE := Vector2(350.0, 51.0)
const TITLE_MENU_GAP := 11.0
const TITLE_DETAIL_RECT := Rect2(500.0, 214.0, 630.0, 356.0)
const TITLE_TOGGLE_RECT := Rect2(528.0, 421.0, 574.0, 49.0)
const TITLE_BACK_RECT := Rect2(528.0, 500.0, 574.0, 45.0)

enum TitleMenuAction { NEW_GAME, CONTINUE, CONTROLS, SETTINGS, QUIT }

var snapshot: Dictionary = {}
var _canvas_scale := 1.0
var _canvas_offset := Vector2.ZERO
var _skill_hovered := -1
var _skill_focused := 0
var _skill_tree_mode := false
var _flash_color := Color.TRANSPARENT
var _flash_intensity := 0.0
var _flash_started_msec := 0
var _flash_duration_msec := 0
var _last_liquid_redraw_msec := 0
var _level_up_notice_level := 0
var _level_up_notice_points := 0
var _level_up_notice_started_msec := 0
var _level_up_notice_duration_msec := 0
var _last_title_redraw_msec := 0
var _title_hovered := -1
var _title_focused := 0
var _title_panel := &"main"
var _screen_shake_enabled := true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	process_mode = Node.PROCESS_MODE_ALWAYS
	focus_mode = Control.FOCUS_NONE
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func update_snapshot(data: Dictionary) -> void:
	var next_skill_tree_mode := String(data.get("phase", "TITLE")) == "SKILL_TREE"
	var is_title_screen := String(data.get("phase", "TITLE")) == "TITLE"
	snapshot = data
	if next_skill_tree_mode != _skill_tree_mode:
		_set_skill_tree_mode(next_skill_tree_mode)
	_set_title_mode(is_title_screen)
	queue_redraw()

func play_screen_flash(color: Color, intensity: float = 0.3, duration: float = 0.14) -> void:
	_flash_color = color
	_flash_intensity = clampf(intensity, 0.0, 1.0)
	_flash_started_msec = Time.get_ticks_msec()
	_flash_duration_msec = maxi(1, int(maxf(duration, 0.01) * 1000.0))
	queue_redraw()

func play_level_up_notice(level: int, points_awarded: int) -> void:
	_level_up_notice_level = level
	_level_up_notice_points = points_awarded
	_level_up_notice_started_msec = Time.get_ticks_msec()
	_level_up_notice_duration_msec = LEVEL_UP_NOTICE_DURATION_MSEC
	queue_redraw()

func has_level_up_notice() -> bool:
	return _level_up_notice_duration_msec > 0

func _process(_delta: float) -> void:
	var now_msec := Time.get_ticks_msec()
	var needs_redraw := false
	if _flash_duration_msec > 0:
		if now_msec - _flash_started_msec >= _flash_duration_msec:
			_flash_duration_msec = 0
		needs_redraw = true
	if _level_up_notice_duration_msec > 0:
		if now_msec - _level_up_notice_started_msec >= _level_up_notice_duration_msec:
			_level_up_notice_duration_msec = 0
		needs_redraw = true
	if String(snapshot.get("phase", "TITLE")) == "TITLE" and now_msec - _last_title_redraw_msec >= TITLE_REFRESH_MSEC:
		_last_title_redraw_msec = now_msec
		needs_redraw = true
	if String(snapshot.get("phase", "TITLE")) != "TITLE" and now_msec - _last_liquid_redraw_msec >= LIQUID_REFRESH_MSEC:
		_last_liquid_redraw_msec = now_msec
		needs_redraw = true
	if needs_redraw:
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
		_set_virtual_draw_scale(Vector2(40.0, 40.0), HUD_SCALE)
		_draw_quest_hud()
		_set_virtual_canvas_transform()
		_set_virtual_draw_scale(Vector2(canvas_size.x - 40.0, 40.0), HUD_SCALE)
		_draw_skill_badge()
		_set_virtual_canvas_transform()
		if not boss_visible:
			_set_virtual_draw_scale(Vector2(canvas_size.x - 40.0, 40.0), HUD_SCALE)
			_draw_status_hud(canvas_size)
			_set_virtual_canvas_transform()
		if not boss_visible and not sheet_open:
			_set_virtual_draw_scale(Vector2(canvas_size.x - 40.0, 134.0), HUD_SCALE)
			_draw_minimap(canvas_size)
			_set_virtual_canvas_transform()
		_set_virtual_draw_scale(Vector2(canvas_size.x * 0.5, canvas_size.y), HUD_SCALE)
		_draw_bottom_hud(canvas_size)
		_set_virtual_canvas_transform()
		if boss_visible:
			_set_virtual_draw_scale(Vector2(canvas_size.x * 0.5, 126.0), HUD_SCALE)
		_draw_boss_bar(canvas_size)
		_set_virtual_canvas_transform()
		_draw_message(canvas_size)
		_draw_level_up_notice(canvas_size)
		if sheet_open:
			_set_virtual_draw_scale(Vector2(canvas_size.x - 40.0, 132.0), HUD_SCALE)
			_draw_character_sheet(canvas_size)
			_set_virtual_canvas_transform()
		match phase:
			"SKILL_TREE":
				_draw_skill_tree_backdrop(canvas_size)
				_set_virtual_draw_scale(canvas_size * 0.5, SKILL_TREE_SCALE)
				_draw_skill_tree(canvas_size)
				_set_virtual_canvas_transform()
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

func _set_virtual_canvas_transform() -> void:
	draw_set_transform(_canvas_offset, 0.0, Vector2.ONE * _canvas_scale)

func _set_virtual_draw_scale(pivot: Vector2, scale_factor: float) -> void:
	var clamped_scale := maxf(scale_factor, 0.01)
	var offset := _canvas_offset + (pivot - pivot * clamped_scale) * _canvas_scale
	draw_set_transform(offset, 0.0, Vector2.ONE * _canvas_scale * clamped_scale)

func _scaled_rect(rect: Rect2, pivot: Vector2, scale_factor: float) -> Rect2:
	return Rect2(pivot + (rect.position - pivot) * scale_factor, rect.size * scale_factor)

func _viewport_to_virtual(viewport_position: Vector2) -> Vector2:
	_update_virtual_canvas(get_viewport_rect().size)
	return (viewport_position - _canvas_offset) / maxf(_canvas_scale, 0.001)

func blocks_world_pointer(viewport_position: Vector2) -> bool:
	if String(snapshot.get("phase", "TITLE")) == "TITLE":
		return true
	if String(snapshot.get("phase", "TITLE")) == "SKILL_TREE":
		return true
	var point := _viewport_to_virtual(viewport_position)
	if not Rect2(Vector2.ZERO, VIRTUAL_SIZE).has_point(point):
		return true
	if _scaled_rect(Rect2(40, 40, 390, 82), Vector2(40, 40), HUD_SCALE).has_point(point):
		return true
	var boss_visible := bool(snapshot.get("boss_visible", false))
	if _skill_badge_rect().has_point(point):
		return true
	if not boss_visible and _scaled_rect(Rect2(VIRTUAL_SIZE.x - 272, 40, 232, 82), Vector2(VIRTUAL_SIZE.x - 40, 40), HUD_SCALE).has_point(point):
		return true
	if not boss_visible and not bool(snapshot.get("sheet_open", false)) and _scaled_rect(Rect2(VIRTUAL_SIZE.x - 272, 134, 232, 142), Vector2(VIRTUAL_SIZE.x - 40, 134), HUD_SCALE).has_point(point):
		return true
	if boss_visible and _scaled_rect(Rect2(262, 126, 756, 66), Vector2(VIRTUAL_SIZE.x * 0.5, 126), HUD_SCALE).has_point(point):
		return true
	var bottom_pivot := Vector2(VIRTUAL_SIZE.x * 0.5, VIRTUAL_SIZE.y)
	if _scaled_rect(Rect2(115, 385, 305, 335), bottom_pivot, HUD_SCALE).has_point(point) or _scaled_rect(Rect2(860, 385, 305, 335), bottom_pivot, HUD_SCALE).has_point(point):
		return true
	if _scaled_rect(Rect2(405, 535, 470, 185), bottom_pivot, HUD_SCALE).has_point(point):
		return true
	if bool(snapshot.get("sheet_open", false)):
		var sheet_rect := Rect2(VIRTUAL_SIZE.x - 460, 132, 420, 464)
		return _scaled_rect(sheet_rect, Vector2(VIRTUAL_SIZE.x - 40, 132), HUD_SCALE).has_point(point)
	return false

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
	draw_texture_rect(TITLE_BACKGROUND, Rect2(Vector2.ZERO, canvas_size), false)
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.005, 0.004, 0.009, 0.24))
	draw_rect(Rect2(0.0, 0.0, 530.0, canvas_size.y), Color(0.008, 0.006, 0.014, 0.62))
	draw_rect(Rect2(0.0, 0.0, canvas_size.x, 27.0), Color(0.005, 0.003, 0.008, 0.42))
	_draw_title_left_ornament()
	_draw_title_brand()
	if _title_panel == &"main":
		_draw_title_menu()
	else:
		_draw_title_detail_panel()
	_draw_title_footer(canvas_size)

func _draw_title_left_ornament() -> void:
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.0024) * 0.5
	var ember := Color(0.86, 0.22, 0.18, 0.28 + pulse * 0.22)
	draw_line(Vector2(72.0, 75.0), Vector2(72.0, 651.0), Color("5c3a42"), 1.0)
	draw_line(Vector2(78.0, 75.0), Vector2(78.0, 651.0), Color(ember, 0.66), 1.0)
	for y in [96.0, 260.0, 467.0, 630.0]:
		draw_circle(Vector2(75.0, y), 4.0, Color("150d16"))
		draw_arc(Vector2(75.0, y), 7.0, 0.0, TAU, 12, ember, 1.2)

func _draw_title_brand() -> void:
	var x := 103.0
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.0024) * 0.5
	_text("ASHEN", Vector2(x, 123.0), 48, Color("e9d4b0"))
	_text("COVENANT", Vector2(x, 175.0), 48, Color("e9d4b0"))
	draw_line(Vector2(x, 195.0), Vector2(x + 304.0, 195.0), Color("8f3d3e"), 2.0)
	draw_line(Vector2(x + 4.0, 200.0), Vector2(x + 252.0, 200.0), Color(0.90, 0.46, 0.27, 0.42 + pulse * 0.20), 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 311.0, 190.0), Vector2(x + 317.0, 196.0),
		Vector2(x + 311.0, 202.0), Vector2(x + 305.0, 196.0)
	]), Color("d89956"))
	_text("A DARK ACTION RPG", Vector2(x + 2.0, 228.0), 16, Color("bc8e78"))
	_text("Break the covenant. Claim what remains.", Vector2(x + 2.0, 258.0), 15, Color("b5a7a7"))

func _draw_title_menu() -> void:
	var entries := _title_menu_entries()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		_draw_title_menu_button(_title_button_rect(i), i, String(entry.label), String(entry.hint), bool(entry.disabled), bool(entry.danger))
	if bool(snapshot.get("has_save", false)):
		_text("A saved hunt awaits at the last broken anchor.", TITLE_MENU_ORIGIN + Vector2(4.0, 5.0 * (TITLE_MENU_SIZE.y + TITLE_MENU_GAP) + 4.0), 13, Color("89aebf"))

func _draw_title_menu_button(rect: Rect2, index: int, label: String, hint: String, disabled: bool, danger: bool) -> void:
	var active := index == _title_hovered or index == _title_focused
	var border := Color("8b554d")
	var fill := Color(0.045, 0.026, 0.043, 0.90)
	var text_color := Color("e3d5c4")
	if disabled:
		border = Color("443943")
		fill = Color(0.022, 0.017, 0.028, 0.72)
		text_color = Color("716973")
	elif danger:
		border = Color("79414b") if not active else Color("c75b55")
		text_color = Color("cbb6b5") if not active else Color("ffd2ca")
	elif active:
		border = Color("d7915b")
		fill = Color(0.16, 0.065, 0.057, 0.95)
		text_color = Color("fff0cf")
	_panel(rect, fill, border)
	if active and not disabled:
		draw_rect(rect.grow(4.0), Color(border, 0.13), false, 1.0)
		draw_colored_polygon(PackedVector2Array([
			rect.position + Vector2(14.0, 18.0), rect.position + Vector2(23.0, 25.5), rect.position + Vector2(14.0, 33.0)
		]), Color("f0a35f"))
	_text(label, rect.position + Vector2(38.0, 32.0), 18, text_color)
	_right_text(hint, rect.position + Vector2(rect.size.x - 17.0, 31.0), 12, Color("c28e74") if active and not disabled else Color("8b7b82"))

func _draw_title_detail_panel() -> void:
	_panel(TITLE_DETAIL_RECT, Color(0.025, 0.017, 0.031, 0.95), Color("855a55"))
	if _title_panel == &"controls":
		_draw_title_controls_panel()
	else:
		_draw_title_settings_panel()
	_draw_title_back_button()

func _draw_title_controls_panel() -> void:
	var origin := TITLE_DETAIL_RECT.position + Vector2(30.0, 44.0)
	_text("HOW TO PLAY", origin, 26, Color("f0c891"))
	_text("THE COVENANT DEMANDS DECISIVE ACTION.", origin + Vector2(0.0, 28.0), 13, Color("ae8a83"))
	var controls := [
		["LEFT CLICK", "Move, pursue, and attack"],
		["F", "Cleave: three-hit execution combo"],
		["RIGHT CLICK / Q", "Ash Nova: burst and slow enemies"],
		["SPACE", "Shadow Step: evade and phase rend"],
		["R", "Blood Vial: restore life from charges"],
		["TAB / K", "Open character sheet / disciplines"]
	]
	for i in controls.size():
		var row_y := 125.0 + float(i) * 42.0
		var key_rect := Rect2(TITLE_DETAIL_RECT.position + Vector2(30.0, row_y), Vector2(164.0, 28.0))
		draw_rect(key_rect, Color("16101b"))
		draw_rect(key_rect, Color("6e4c50"), false, 1.0)
		_text(String(controls[i][0]), key_rect.position + Vector2(12.0, 20.0), 13, Color("e5bd87"))
		_text(String(controls[i][1]), key_rect.position + Vector2(185.0, 20.0), 15, Color("d5c8c6"))

func _draw_title_settings_panel() -> void:
	var origin := TITLE_DETAIL_RECT.position + Vector2(30.0, 44.0)
	_text("SETTINGS", origin, 26, Color("f0c891"))
	_text("COMFORT OPTIONS", origin + Vector2(0.0, 28.0), 13, Color("ae8a83"))
	_text("SCREEN SHAKE", TITLE_TOGGLE_RECT.position + Vector2(17.0, 31.0), 18, Color("e3d5c4"))
	var toggle_active := _screen_shake_enabled
	var toggle_color := Color("e5a65e") if toggle_active else Color("65585d")
	var switch_rect := Rect2(TITLE_TOGGLE_RECT.end - Vector2(112.0, 35.0), Vector2(85.0, 24.0))
	_panel(TITLE_TOGGLE_RECT, Color(0.047, 0.028, 0.046, 0.92), toggle_color)
	draw_rect(switch_rect, Color("17111a"))
	draw_rect(switch_rect, toggle_color, false, 1.0)
	draw_circle(Vector2(switch_rect.position.x + (68.0 if toggle_active else 17.0), switch_rect.get_center().y), 9.0, toggle_color)
	_right_text("ON" if toggle_active else "OFF", TITLE_TOGGLE_RECT.end - Vector2(17.0, 16.0), 12, Color("fff0d5") if toggle_active else Color("aaa0a4"))
	_text("Keeps combat impacts comfortable without changing gameplay.", TITLE_TOGGLE_RECT.position + Vector2(1.0, 85.0), 14, Color("b8a8aa"))

func _draw_title_back_button() -> void:
	var hover := TITLE_BACK_RECT.has_point(_viewport_to_virtual(get_local_mouse_position()))
	_panel(TITLE_BACK_RECT, Color(0.05, 0.03, 0.046, 0.94), Color("c38d61") if hover else Color("72565a"))
	_center_text_at("RETURN TO MENU", TITLE_BACK_RECT.get_center(), 15, Color("fff0d5") if hover else Color("d4c5c4"))

func _draw_title_footer(canvas_size: Vector2) -> void:
	_text("ASHEN COVENANT  •  DEMO BUILD 1.0.0", Vector2(92.0, canvas_size.y - 34.0), 12, Color("8f8188"))
	var prompt := "ENTER  SELECT     ↑ ↓  NAVIGATE" if _title_panel == &"main" else "ESC  RETURN TO MENU"
	_right_text(prompt, Vector2(canvas_size.x - 52.0, canvas_size.y - 34.0), 12, Color("9c8c8d"))

func _title_menu_entries() -> Array[Dictionary]:
	var has_save := bool(snapshot.get("has_save", false))
	return [
		{"label": "BEGIN NEW COVENANT", "hint": "ENTER", "disabled": false, "danger": false},
		{"label": "CONTINUE THE HUNT", "hint": "C", "disabled": not has_save, "danger": false},
		{"label": "HOW TO PLAY", "hint": "", "disabled": false, "danger": false},
		{"label": "SETTINGS", "hint": "", "disabled": false, "danger": false},
		{"label": "QUIT DESKTOP", "hint": "", "disabled": false, "danger": true}
	]

func _title_button_rect(index: int) -> Rect2:
	return Rect2(TITLE_MENU_ORIGIN + Vector2(0.0, float(index) * (TITLE_MENU_SIZE.y + TITLE_MENU_GAP)), TITLE_MENU_SIZE)

func _title_action_at(viewport_position: Vector2) -> int:
	var virtual_position := _viewport_to_virtual(viewport_position)
	for i in _title_menu_entries().size():
		if _title_button_rect(i).has_point(virtual_position):
			return i
	return -1

func _set_title_mode(enabled: bool) -> void:
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		if not has_focus():
			call_deferred("grab_focus")
		return
	if not _skill_tree_mode:
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE
		release_focus()
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	_title_hovered = -1
	_title_focused = 0
	_title_panel = &"main"

func _draw_quest_hud() -> void:
	_panel(Rect2(40, 40, 390, 82), Color(0.035, 0.025, 0.04, 0.88), Color("6d4a50"))
	_text("COVENANT OF ASH", Vector2(60, 67), 17, Color("d5b895"))
	_text(_fit_text(String(snapshot.get("objective", "Find the soul anchors")), 17, 286.0), Vector2(60, 94), 17, Color("e8e1d8"))
	var done := int(snapshot.get("anchors_destroyed", 0))
	var total := int(snapshot.get("anchors_total", 3))
	for i in total:
		var c := Color("d94c68") if i < done else Color("3b303c")
		draw_colored_polygon(PackedVector2Array([Vector2(365 + i * 20, 64), Vector2(372 + i * 20, 75), Vector2(365 + i * 20, 86), Vector2(358 + i * 20, 75)]), c)

func _draw_status_hud(canvas_size: Vector2) -> void:
	_panel(Rect2(canvas_size.x - 272, 40, 232, 82), Color(0.035, 0.025, 0.04, 0.88), Color("6d4a50"))
	_text("LEVEL %d" % int(snapshot.get("level", 1)), Vector2(canvas_size.x - 250, 67), 18, Color("d5b895"))
	_text("Kills  %d" % int(snapshot.get("kills", 0)), Vector2(canvas_size.x - 250, 94), 16, Color("aaa0a4"))
	_text("Gold  %d" % int(snapshot.get("gold", 0)), Vector2(canvas_size.x - 147, 94), 16, Color("f1c75b"))

func _draw_skill_badge() -> void:
	var points := int(snapshot.get("skill_points", 0))
	var has_points := points > 0
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.006) * 0.5
	var border := Color("e7bd5c") if has_points else Color("6d5e70")
	var fill := Color("402e39", 0.98) if has_points else Color("241c29", 0.94)
	_panel(SKILL_BADGE_RECT, fill, border)
	if has_points:
		draw_rect(SKILL_BADGE_RECT.grow(4.0), Color(border, 0.12 + pulse * 0.16), false, 2.0)
	var icon_center := SKILL_BADGE_RECT.position + Vector2(25.0, 39.0)
	for radius in [16.0, 11.0]:
		draw_arc(icon_center, radius, 0.0, TAU, 18, Color(border, 0.82), 1.5)
	for offset in [Vector2(0, -13), Vector2(-12, 8), Vector2(12, 8)]:
		draw_line(icon_center, icon_center + offset, Color(border, 0.85), 1.5)
		draw_circle(icon_center + offset, 3.4, Color("241923"))
		draw_arc(icon_center + offset, 3.4, 0.0, TAU, 10, border, 1.1)
	draw_circle(icon_center, 5.0, border)
	_text("SKILLS", SKILL_BADGE_RECT.position + Vector2(50, 31), 16, Color("f5dfad") if has_points else Color("c1b7c0"))
	_text("K  •  %d POINT%s" % [points, "" if points == 1 else "S"], SKILL_BADGE_RECT.position + Vector2(50, 54), 12, border)

func _draw_level_up_notice(canvas_size: Vector2) -> void:
	if _level_up_notice_duration_msec <= 0:
		return
	var elapsed := float(Time.get_ticks_msec() - _level_up_notice_started_msec)
	var progress := clampf(elapsed / float(_level_up_notice_duration_msec), 0.0, 1.0)
	var fade := sin(progress * PI)
	var center := Vector2(canvas_size.x * 0.5, 164.0)
	for i in 4:
		draw_arc(center, 68.0 + i * 19.0 + progress * 48.0, 0.0, TAU, 32, Color(0.95, 0.71, 0.25, fade * (0.28 - i * 0.05)), 2.0)
	var rect := Rect2(center - Vector2(205.0, 51.0), Vector2(410.0, 102.0))
	_panel(rect, Color(0.10, 0.055, 0.09, 0.96 * fade), Color(0.94, 0.71, 0.31, fade))
	_center_text_at("LEVEL %d" % _level_up_notice_level, center + Vector2(0.0, -20.0), 29, Color(1.0, 0.83, 0.43, fade))
	_center_text_at("SKILL POINT +%d" % _level_up_notice_points, center + Vector2(0.0, 10.0), 18, Color(0.94, 0.83, 0.72, fade))
	_center_text_at("Click SKILLS or press K to spend it", center + Vector2(0.0, 34.0), 13, Color(0.83, 0.75, 0.79, fade))

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
		{"key": "F", "name": "CLEAVE", "role": "COMBO", "icon": ICON_CLEAVE, "color": Color("c97755"), "cooldown": snapshot.get("attack_cd", 0.0)},
		{"key": "Q", "name": "ASH NOVA", "role": "AREA SLOW", "icon": ICON_NOVA, "color": Color("985ccb"), "cooldown": snapshot.get("nova_cd", 0.0)},
		{"key": "SPACE", "name": "SHADOW STEP", "role": "DASH REND", "icon": ICON_STEP, "color": Color("6572b8"), "cooldown": snapshot.get("dash_cd", 0.0)},
		{"key": "R", "name": "BLOOD VIAL", "role": "HEAL  ×%d" % int(snapshot.get("potions", 0)), "icon": ICON_POTION, "color": Color("ba3f55"), "cooldown": 0.0}
	]
	for i in mini(HOTBAR_SLOT_COUNT, skills.size()):
		_draw_gothic_skill(hotbar_slot_rect(i).position, skills[i])
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
	var inner_radius := radius - 2.0
	var liquid_phase := Time.get_ticks_msec() * 0.0022 + center.x * 0.017
	var fill_polygon := _liquid_orb_polygon(center, inner_radius, fill_ratio, liquid_phase)
	if fill_polygon.size() >= 3:
		draw_colored_polygon(fill_polygon, Color(color.darkened(0.06), 0.96))
		var deep_ratio := clampf((fill_ratio - 0.16) / 0.84, 0.0, 1.0)
		if deep_ratio > 0.0:
			var deep_polygon := _liquid_orb_polygon(center + Vector2(0.0, 2.5), inner_radius - 5.0, deep_ratio, liquid_phase * 0.82 + 1.2)
			if deep_polygon.size() >= 3:
				draw_colored_polygon(deep_polygon, Color(color.darkened(0.34), 0.36))
		if fill_ratio > 0.0 and fill_ratio < 1.0:
			var surface := _liquid_surface_points(center, inner_radius, fill_ratio, liquid_phase)
			draw_polyline(surface, Color(color.lightened(0.58), 0.88), 1.7, true)
			draw_polyline(_offset_points(surface, Vector2(0.0, 2.0)), Color(color.lightened(0.18), 0.30), 0.8, true)
			_draw_liquid_bubbles(center, inner_radius, fill_ratio, liquid_phase, color)
	draw_arc(center - Vector2(8, 7), radius - 11.0, PI * 1.12, PI * 1.56, 18, Color(1.0, 1.0, 1.0, 0.18), 3.0)
	draw_circle(center + Vector2(17, 19), 13.0, Color(color.darkened(0.52), 0.2))

func _skill_row_start() -> Vector2:
	var total_width := SKILL_SLOT_SIZE.x * HOTBAR_SLOT_COUNT + SKILL_SLOT_GAP * (HOTBAR_SLOT_COUNT - 1)
	return Vector2(VIRTUAL_SIZE.x * 0.5 - total_width * 0.5, LIFE_ORB_CENTER.y - SKILL_SLOT_SIZE.y * 0.5)

func hotbar_slot_count() -> int:
	return HOTBAR_SLOT_COUNT

func hotbar_slot_rect(index: int) -> Rect2:
	var clamped_index := clampi(index, 0, HOTBAR_SLOT_COUNT - 1)
	return Rect2(_skill_row_start() + Vector2(clamped_index * (SKILL_SLOT_SIZE.x + SKILL_SLOT_GAP), 0.0), SKILL_SLOT_SIZE)

func _liquid_surface_points(center: Vector2, radius: float, ratio: float, phase: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	if ratio <= 0.0 or ratio >= 1.0:
		return points
	var water_y := center.y + radius - radius * 2.0 * ratio
	var chord_half_width := sqrt(maxf(0.0, radius * radius - pow(water_y - center.y, 2.0)))
	for i in range(LIQUID_SURFACE_SEGMENTS + 1):
		var t := float(i) / float(LIQUID_SURFACE_SEGMENTS)
		var envelope := sin(PI * t)
		var wave := (sin(t * TAU * 1.35 + phase) * 1.5 + sin(t * TAU * 2.8 - phase * 0.72) * 0.65) * envelope
		points.append(Vector2(center.x + lerpf(-chord_half_width, chord_half_width, t), water_y + wave))
	return points

func _liquid_orb_polygon(center: Vector2, radius: float, ratio: float, phase: float) -> PackedVector2Array:
	if ratio <= 0.0:
		return PackedVector2Array()
	if ratio >= 1.0:
		return _circle_segment_polygon(center, radius, 1.0)
	var points := _liquid_surface_points(center, radius, ratio, phase)
	var water_y := center.y + radius - radius * 2.0 * ratio
	var vertical := clampf((water_y - center.y) / radius, -0.999, 0.999)
	var right_angle := asin(vertical)
	var left_angle := PI - right_angle
	for i in range(1, 33):
		var t := float(i) / 32.0
		var angle := lerpf(right_angle, left_angle, t)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var shifted := PackedVector2Array()
	for point in points:
		shifted.append(point + offset)
	return shifted

func _draw_liquid_bubbles(center: Vector2, radius: float, ratio: float, phase: float, color: Color) -> void:
	if ratio < 0.34:
		return
	var water_y := center.y + radius - radius * 2.0 * ratio
	var offsets := [Vector2(-20.0, 22.0), Vector2(14.0, 31.0), Vector2(25.0, 12.0)]
	for i in offsets.size():
		var bubble: Vector2 = center + offsets[i] + Vector2(sin(phase * 0.64 + i) * 1.3, cos(phase * 0.48 + i * 1.7) * 1.8)
		if bubble.y <= water_y + 3.0 or bubble.distance_to(center) >= radius - 3.0:
			continue
		var bubble_radius := 1.1 + float(i) * 0.28
		draw_arc(bubble, bubble_radius, 0.0, TAU, 10, Color(color.lightened(0.60), 0.33), 0.7, true)

func _draw_gothic_orb_text(center: Vector2, label: String, current: int, maximum: int, color: Color) -> void:
	_center_text_at(label, center + Vector2(0, -9), 12, Color(color, 0.86))
	_center_text_at("%d / %d" % [current, maximum], center + Vector2(0, 13), 17, color)

func _draw_gothic_skill(draw_position: Vector2, data: Dictionary) -> void:
	var rect := Rect2(draw_position, SKILL_SLOT_SIZE)
	var color: Color = data.color
	draw_rect(rect.grow(-4.0), Color(color, 0.07))
	var icon: Texture2D = data.icon
	var icon_position := draw_position + Vector2((SKILL_SLOT_SIZE.x - SKILL_ICON_SIZE.x) * 0.5, SKILL_ICON_TOP)
	draw_texture_rect(icon, Rect2(icon_position, SKILL_ICON_SIZE), false, Color(1.0, 1.0, 1.0, 0.96))
	var cd := clampf(float(data.cooldown), 0.0, 1.0)
	if cd > 0.0:
		draw_rect(Rect2(draw_position.x + 7, draw_position.y + 7 + 70.0 * (1.0 - cd), 70, 70.0 * cd), Color(0.01, 0.008, 0.012, 0.78))
	var key_label := String(data.key)
	var key_width := 36.0 if key_label.length() >= 3 else 26.0
	draw_rect(Rect2(draw_position + Vector2(5, 4), Vector2(key_width, 17)), Color(0.018, 0.014, 0.02, 0.92))
	draw_rect(Rect2(draw_position + Vector2(5, 4), Vector2(key_width, 17)), Color("9b7a4d"), false, 1.0)
	_text(key_label, draw_position + Vector2(8, 17), 11, Color("fff0d8"))
	_center_text_at(String(data.name), draw_position + Vector2(42, 72), 10, Color("dfd2c3"))
	_center_text_at(String(data.get("role", "")), draw_position + Vector2(42, 84), 9, color.lightened(0.22))
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
	_center_text(message, y, 20, c, canvas_size.x)

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

func _draw_skill_tree_backdrop(canvas_size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.01, 0.005, 0.015, 0.80))
	for i in 5:
		draw_arc(canvas_size * 0.5 - Vector2(0.0, 62.0), 164.0 + i * 32.0, 0.0, TAU, 40, Color(0.40, 0.11, 0.16, 0.12 - i * 0.018), 2.0)

func _draw_skill_tree(canvas_size: Vector2) -> void:
	var skill_points := int(snapshot.get("skill_points", 0))
	var skills: Array = snapshot.get("skills", [])
	_center_text("COVENANT DISCIPLINES", 105, 35, Color("f0cc77"), canvas_size.x)
	_center_text("Spend points when you choose your moment", 139, 18, Color("c8b8ae"), canvas_size.x)
	var point_text := "SKILL POINTS  %d" % skill_points
	var point_color := Color("f0cc77") if skill_points > 0 else Color("91878b")
	_center_text(point_text, 182, 21, point_color, canvas_size.x)
	var root := Vector2(canvas_size.x * 0.5, 226.0)
	draw_circle(root, 28.0, Color("20151c"))
	draw_arc(root, 28.0, 0.0, TAU, 32, Color("d9b566"), 2.0)
	_center_text_at("✦", root, 22, Color("f0cc77"))
	for i in skills.size():
		var skill: Dictionary = skills[i]
		var skill_color: Color = SKILL_COLORS[i % SKILL_COLORS.size()]
		var rank := int(skill.get("rank", 0))
		var max_rank := maxi(1, int(skill.get("max_rank", 1)))
		for rank_index in max_rank:
			var center := _skill_node_center(i, rank_index)
			var previous := root if rank_index == 0 else _skill_node_center(i, rank_index - 1)
			var purchased := rank_index < rank
			var next_rank := rank_index == rank and bool(skill.get("available", false))
			var connector_color := Color(skill_color, 0.78) if purchased else (Color(skill_color, 0.5) if next_rank else Color("4c414b"))
			draw_line(previous, center, connector_color, 3.0)
			_draw_skill_node(_skill_node_rect(i, rank_index), skill, rank_index, purchased, next_rank, i == (_skill_hovered if _skill_hovered >= 0 else _skill_focused), skill_color)
	_center_text("Click the highlighted next rank  •  ← / → + Enter  •  K / Esc close", 641, 16, Color("a99da1"), canvas_size.x)

func _draw_skill_node(rect: Rect2, skill: Dictionary, rank_index: int, purchased: bool, next_rank: bool, focused: bool, color: Color) -> void:
	var fill := Color("37212b") if purchased else (Color("2c2433") if next_rank else Color("18131c"))
	var border := color if purchased or next_rank else Color("514653")
	_panel(rect, fill, border)
	if next_rank and focused:
		draw_rect(rect.grow(5.0), Color(color, 0.22))
		draw_rect(rect.grow(3.0), color.lightened(0.24), false, 2.0)
	var state := "MASTERED" if purchased else ("AVAILABLE" if next_rank else "LOCKED")
	var state_color := Color("f0cc77") if purchased else (color.lightened(0.25) if next_rank else Color("817783"))
	_text(String(skill.get("title", "DISCIPLINE")), rect.position + Vector2(15, 27), 17, color if purchased or next_rank else Color("a095a1"))
	_right_text("RANK %d" % (rank_index + 1), rect.position + Vector2(rect.size.x - 14, 27), 13, Color("d7cbd0"))
	_text(String(skill.get("summary", "")), rect.position + Vector2(15, 51), 13, Color("d6c9cd") if purchased or next_rank else Color("807783"))
	_right_text(state, rect.position + Vector2(rect.size.x - 14, 67), 11, state_color)

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

func _skill_node_center(skill_index: int, rank_index: int) -> Vector2:
	var x: float = float(SKILL_BRANCH_X[clampi(skill_index, 0, SKILL_BRANCH_X.size() - 1)])
	var y: float = float(SKILL_RANK_Y[clampi(rank_index, 0, SKILL_RANK_Y.size() - 1)])
	return Vector2(x, y)

func _skill_node_rect(skill_index: int, rank_index: int) -> Rect2:
	return Rect2(_skill_node_center(skill_index, rank_index) - SKILL_NODE_SIZE * 0.5, SKILL_NODE_SIZE)

func _skill_badge_rect() -> Rect2:
	return _scaled_rect(SKILL_BADGE_RECT, Vector2(VIRTUAL_SIZE.x - 40.0, 40.0), HUD_SCALE)

func _skill_index_at(viewport_position: Vector2) -> int:
	var virtual_position := _viewport_to_virtual(viewport_position)
	var pivot := VIRTUAL_SIZE * 0.5
	virtual_position = pivot + (virtual_position - pivot) / SKILL_TREE_SCALE
	var skills: Array = snapshot.get("skills", [])
	for i in skills.size():
		var skill: Dictionary = skills[i]
		if not bool(skill.get("available", false)):
			continue
		var rank := int(skill.get("rank", 0))
		if _skill_node_rect(i, rank).has_point(virtual_position):
			return i
	return -1

func _set_skill_tree_mode(enabled: bool) -> void:
	_skill_tree_mode = enabled
	_skill_hovered = -1
	_skill_focused = 0
	if enabled:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		grab_focus()
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE
		release_focus()
		mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if String(snapshot.get("phase", "TITLE")) == "TITLE":
		_handle_title_input(event)
		return
	if not _skill_tree_mode:
		if String(snapshot.get("phase", "TITLE")) != "PLAYING":
			return
		if event is InputEventMouseMotion:
			var virtual_position := _viewport_to_virtual(event.position)
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _skill_badge_rect().has_point(virtual_position) else Control.CURSOR_ARROW
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _skill_badge_rect().has_point(_viewport_to_virtual(event.position)):
				skill_tree_requested.emit()
				accept_event()
		return
	if event is InputEventMouseMotion:
		var next_hovered := _skill_index_at(event.position)
		if next_hovered != _skill_hovered:
			_skill_hovered = next_hovered
			if next_hovered >= 0:
				_skill_focused = next_hovered
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if next_hovered >= 0 else Control.CURSOR_ARROW
			queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked := _skill_index_at(event.position)
		if clicked >= 0:
			_select_skill(clicked)
			accept_event()
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
		_skill_hovered = -1
		_skill_focused = wrapi(_skill_focused - 1, 0, 3)
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_focus_next"):
		_skill_hovered = -1
		_skill_focused = wrapi(_skill_focused + 1, 0, 3)
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		_select_skill(_skill_focused)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1: _select_skill(0)
			KEY_2: _select_skill(1)
			KEY_3: _select_skill(2)
			_: return
		accept_event()

func _handle_title_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pointer := _viewport_to_virtual(event.position)
		if _title_panel == &"main":
			var next_hovered := _title_action_at(event.position)
			if next_hovered != _title_hovered:
				_title_hovered = next_hovered
				if next_hovered >= 0:
					_title_focused = next_hovered
				queue_redraw()
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if next_hovered >= 0 else Control.CURSOR_ARROW
		else:
			var is_interactive := TITLE_BACK_RECT.has_point(pointer) or (_title_panel == &"settings" and TITLE_TOGGLE_RECT.has_point(pointer))
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_interactive else Control.CURSOR_ARROW
			queue_redraw()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var click_position := _viewport_to_virtual(event.position)
		if _title_panel == &"main":
			var action := _title_action_at(event.position)
			if action >= 0:
				_activate_title_menu_action(action)
				accept_event()
		elif _title_panel == &"settings" and TITLE_TOGGLE_RECT.has_point(click_position):
			_screen_shake_enabled = not _screen_shake_enabled
			screen_shake_setting_changed.emit(_screen_shake_enabled)
			queue_redraw()
			accept_event()
		elif TITLE_BACK_RECT.has_point(click_position):
			_title_panel = &"main"
			mouse_default_cursor_shape = Control.CURSOR_ARROW
			queue_redraw()
			accept_event()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _title_panel != &"main":
		if event.is_action_pressed(&"ui_cancel") or event.physical_keycode == KEY_ESCAPE:
			_title_panel = &"main"
			queue_redraw()
			accept_event()
		elif _title_panel == &"settings" and (event.is_action_pressed(&"ui_accept") or event.physical_keycode == KEY_SPACE):
			_screen_shake_enabled = not _screen_shake_enabled
			screen_shake_setting_changed.emit(_screen_shake_enabled)
			queue_redraw()
			accept_event()
		return
	if event.is_action_pressed(&"ui_up"):
		_title_focused = wrapi(_title_focused - 1, 0, _title_menu_entries().size())
		_title_hovered = -1
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_down"):
		_title_focused = wrapi(_title_focused + 1, 0, _title_menu_entries().size())
		_title_hovered = -1
		queue_redraw()
		accept_event()
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"confirm"):
		_activate_title_menu_action(_title_focused)
		accept_event()
	elif event.physical_keycode == KEY_C:
		_activate_title_menu_action(TitleMenuAction.CONTINUE)
		accept_event()

func _activate_title_menu_action(action: int) -> void:
	var entries := _title_menu_entries()
	if action < 0 or action >= entries.size() or bool(entries[action].disabled):
		return
	match action:
		TitleMenuAction.NEW_GAME:
			title_new_game_requested.emit()
		TitleMenuAction.CONTINUE:
			title_continue_requested.emit()
		TitleMenuAction.CONTROLS:
			_title_panel = &"controls"
			_title_hovered = -1
		TitleMenuAction.SETTINGS:
			_title_panel = &"settings"
			_title_hovered = -1
		TitleMenuAction.QUIT:
			title_exit_requested.emit()
	queue_redraw()

func _select_skill(index: int) -> void:
	var skills: Array = snapshot.get("skills", [])
	if index < 0 or index >= skills.size():
		return
	var skill: Dictionary = skills[index]
	if not bool(skill.get("available", false)):
		return
	skill_selected.emit(String(skill.get("id", "")))
	queue_redraw()

func _on_mouse_exited() -> void:
	if _skill_hovered != -1:
		_skill_hovered = -1
		queue_redraw()
	mouse_default_cursor_shape = Control.CURSOR_ARROW

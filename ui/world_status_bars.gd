class_name CovenantWorldStatusBars
extends Node2D

const HUD_SHEET := preload("res://assets/ui/jp_hud/simple-jp-hud-sheet.png")
const HEALTH_FRAME_SOURCE := Rect2(72.0, 65.0, 1390.0, 270.0)
const MANA_FRAME_SOURCE := Rect2(72.0, 355.0, 1390.0, 245.0)
const BAR_RECT := Rect2(-70.0, 0.0, 140.0, 22.0)
const FILL_RECT := Rect2(-42.0, 8.0, 97.0, 7.0)
const BAR_GAP := 25.0

var health_ratio := 1.0
var mana_ratio := 1.0
var health_current := 0.0
var health_maximum := 1.0
var mana_current := 0.0
var mana_maximum := 1.0
var _health_fill: StyleBoxFlat
var _mana_fill: StyleBoxFlat

func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_health_fill = _make_fill(Color("e77d78"))
	_mana_fill = _make_fill(Color("78a9d6"))
	var actor := get_parent()
	if actor == null:
		return
	if actor.has_signal(&"health_changed"):
		actor.health_changed.connect(_on_health_changed)
	if actor.has_signal(&"mana_changed"):
		actor.mana_changed.connect(_on_mana_changed)
	call_deferred("_sync_from_actor")

func _sync_from_actor() -> void:
	var actor := get_parent()
	if actor == null:
		return
	if actor.has_method(&"max_health"):
		_on_health_changed(float(actor.get("health")), float(actor.max_health()))
	if actor.has_method(&"max_mana"):
		_on_mana_changed(float(actor.get("mana")), float(actor.max_mana()))

func _on_health_changed(current: float, maximum: float) -> void:
	health_current = current
	health_maximum = maxf(maximum, 1.0)
	health_ratio = clampf(current / health_maximum, 0.0, 1.0)
	queue_redraw()

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_current = current
	mana_maximum = maxf(maximum, 1.0)
	mana_ratio = clampf(current / mana_maximum, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	_draw_bar(0.0, health_ratio, HEALTH_FRAME_SOURCE, _health_fill, health_current, health_maximum)
	_draw_bar(BAR_GAP, mana_ratio, MANA_FRAME_SOURCE, _mana_fill, mana_current, mana_maximum)

func _draw_bar(offset_y: float, ratio: float, source: Rect2, fill: StyleBoxFlat, current: float, maximum: float) -> void:
	var frame_rect := BAR_RECT
	frame_rect.position.y += offset_y
	var fill_rect := FILL_RECT
	fill_rect.position.y += offset_y
	fill_rect.size.x *= clampf(ratio, 0.0, 1.0)
	if fill_rect.size.x > 0.0:
		draw_style_box(fill, fill_rect)
	draw_texture_rect_region(HUD_SHEET, frame_rect, source)
	var label_rect := Rect2(-40.0, offset_y + 5.0, 94.0, 12.0)
	draw_string(
		ThemeDB.fallback_font,
		label_rect.position + Vector2(0.0, 7.0),
		"%d / %d" % [roundi(current), roundi(maximum)],
		HORIZONTAL_ALIGNMENT_CENTER,
		label_rect.size.x,
		7,
		Color("5b4039")
	)

func _make_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

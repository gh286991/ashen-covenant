class_name AshenPrologueDialogue
extends CanvasLayer

signal finished

const DIALOGUE_LINES: Array[String] = [
	"……這裡，就是灰燼地牢。",
	"這股氣息……和夢裡一模一樣。",
	"別怕。只要繼續前進，一定能找到答案。",
]

const EXPRESSION_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/prologue/ashen_covenant-prologue-front-alert-v2.png"),
	preload("res://assets/ui/prologue/ashen_covenant-prologue-front-worried-v2.png"),
	preload("res://assets/ui/prologue/ashen_covenant-prologue-front-determined-v2.png"),
]

@export_range(1.0, 120.0, 1.0) var characters_per_second := 30.0

@onready var screen: Control = %Screen
@onready var advance_surface: Button = %AdvanceSurface
@onready var skip_button: Button = %SkipButton
@onready var character_art: TextureRect = %CharacterArt
@onready var character_art_next: TextureRect = %CharacterArtNext
@onready var dialogue_panel: PanelContainer = %DialoguePanel
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var line_counter: Label = %LineCounter
@onready var continue_prompt: Label = %ContinuePrompt

var _line_index := -1
var _visible_character_float := 0.0
var _target_character_count := 0
var _typing := false
var _closing := false
var _tree_paused_by_dialogue := false
var _prompt_tween: Tween
var _expression_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	advance_surface.pressed.connect(_advance_dialogue)
	skip_button.pressed.connect(_finish_dialogue)
	character_art.modulate.a = 0.0
	character_art_next.modulate.a = 0.0
	dialogue_panel.modulate.a = 0.0
	continue_prompt.modulate.a = 0.4
	var character_target := character_art.position
	character_art.position.x += 46.0
	character_art_next.position = character_art.position
	get_tree().paused = true
	_tree_paused_by_dialogue = true
	var intro := create_tween().bind_node(self).set_parallel(true)
	intro.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	intro.tween_property(character_art, "position", character_target, 0.42)
	intro.tween_property(character_art_next, "position", character_target, 0.42)
	intro.tween_property(character_art, "modulate:a", 1.0, 0.32)
	intro.tween_property(dialogue_panel, "modulate:a", 1.0, 0.24)
	_start_prompt_pulse()
	_show_line(0)


func _exit_tree() -> void:
	if _tree_paused_by_dialogue and is_instance_valid(get_tree()):
		get_tree().paused = false


func _process(delta: float) -> void:
	if not _typing or _closing:
		return
	_visible_character_float += characters_per_second * delta
	dialogue_text.visible_characters = mini(floori(_visible_character_float), _target_character_count)
	if dialogue_text.visible_characters >= _target_character_count:
		_typing = false
		continue_prompt.text = "點擊或按 Enter 繼續　◆"


func _unhandled_input(event: InputEvent) -> void:
	if _closing:
		return
	if event.is_action_pressed(&"ui_accept"):
		_advance_dialogue()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		_finish_dialogue()
		get_viewport().set_input_as_handled()


func _advance_dialogue() -> void:
	if _closing:
		return
	if _typing:
		_reveal_current_line()
		return
	var next_index := _line_index + 1
	if next_index >= DIALOGUE_LINES.size():
		_finish_dialogue()
		return
	_show_line(next_index)


func _show_line(index: int) -> void:
	_line_index = clampi(index, 0, DIALOGUE_LINES.size() - 1)
	var line := DIALOGUE_LINES[_line_index]
	_set_expression(_line_index)
	dialogue_text.text = line
	dialogue_text.visible_characters = 0
	_target_character_count = line.length()
	_visible_character_float = 0.0
	_typing = true
	line_counter.text = "%02d / %02d" % [_line_index + 1, DIALOGUE_LINES.size()]
	continue_prompt.text = "正在說話……"


func _set_expression(index: int) -> void:
	var next_texture := EXPRESSION_TEXTURES[index]
	if character_art.texture == next_texture:
		return
	if _expression_tween != null and _expression_tween.is_valid():
		_expression_tween.kill()
		if character_art_next.modulate.a > character_art.modulate.a:
			character_art.texture = character_art_next.texture
		character_art.modulate.a = 1.0
		character_art_next.modulate.a = 0.0
	character_art_next.texture = next_texture
	character_art_next.modulate.a = 0.0
	_expression_tween = create_tween().bind_node(self).set_parallel(true)
	_expression_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_expression_tween.tween_property(character_art, "modulate:a", 0.0, 0.18)
	_expression_tween.tween_property(character_art_next, "modulate:a", 1.0, 0.18)
	_expression_tween.finished.connect(_commit_expression.bind(next_texture), CONNECT_ONE_SHOT)


func _commit_expression(texture: Texture2D) -> void:
	character_art.texture = texture
	character_art.modulate.a = 1.0
	character_art_next.modulate.a = 0.0


func _reveal_current_line() -> void:
	_visible_character_float = float(_target_character_count)
	dialogue_text.visible_characters = _target_character_count
	_typing = false
	continue_prompt.text = "點擊或按 Enter 繼續　◆"


func _start_prompt_pulse() -> void:
	_prompt_tween = create_tween().bind_node(self).set_loops()
	_prompt_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(continue_prompt, "modulate:a", 1.0, 0.65)
	_prompt_tween.tween_property(continue_prompt, "modulate:a", 0.4, 0.65)


func _finish_dialogue() -> void:
	if _closing:
		return
	_closing = true
	advance_surface.disabled = true
	skip_button.disabled = true
	if _prompt_tween != null and _prompt_tween.is_valid():
		_prompt_tween.kill()
	if _expression_tween != null and _expression_tween.is_valid():
		_expression_tween.kill()
		if character_art_next.modulate.a > character_art.modulate.a:
			character_art.texture = character_art_next.texture
		character_art.modulate.a = 1.0
		character_art_next.modulate.a = 0.0
	var outro := create_tween().bind_node(self).set_parallel(true)
	outro.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	outro.tween_property(screen, "modulate:a", 0.0, 0.28)
	outro.tween_property(character_art, "position:x", character_art.position.x + 30.0, 0.28)
	outro.tween_property(character_art_next, "position:x", character_art_next.position.x + 30.0, 0.28)
	await outro.finished
	if _tree_paused_by_dialogue:
		get_tree().paused = false
		_tree_paused_by_dialogue = false
	finished.emit()
	queue_free()

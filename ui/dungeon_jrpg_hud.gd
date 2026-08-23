class_name DungeonJrpgHud
extends Control

## Editor-authored JRPG HUD for the 3D dungeon.
## HP/MP deliberately remain owned by DungeonStatusBars3D beside the player.

enum MenuPage { CHARACTER, INVENTORY, SKILLS }

@export_category("Editor Preview Data")
@export_range(1, 99, 1) var preview_level: int = 1
@export_range(0.0, 100.0, 1.0) var preview_exp_percent: float = 0.0

const SKILL_ICONS := {
	&"ash_slash": preload("res://assets/ui/ability_icons/single-1.png"),
	&"soul_orb": preload("res://assets/ui/ability_icons/single-2.png"),
	&"shadow_step": preload("res://assets/ui/ability_icons/single-3.png"),
}
const SKILL_NAMES := {
	&"ash_slash": "灰燼斬",
	&"soul_orb": "靈魂星火",
	&"shadow_step": "影步",
}

@onready var level_label: Label = %LevelLabel
@onready var exp_bar: ProgressBar = %ExpBar
@onready var exp_value: Label = %ExpValue
@onready var door_prompt: PanelContainer = %DoorPrompt
@onready var door_prompt_label: Label = %DoorPromptLabel
@onready var modal: Control = %Modal
@onready var character_page: Control = %CharacterPage
@onready var inventory_page: Control = %InventoryPage
@onready var skills_page: Control = %SkillsPage
@onready var character_tab: Button = %CharacterTab
@onready var inventory_tab: Button = %InventoryTab
@onready var skills_tab: Button = %SkillsTab
@onready var character_shortcut: Button = %CharacterShortcut
@onready var inventory_shortcut: Button = %InventoryShortcut
@onready var skills_shortcut: Button = %SkillsShortcut
@onready var close_button: Button = %CloseButton
@onready var skill_slots: Array[Button] = [%Skill1, %Skill2, %Skill3, %Skill4]
@onready var quick_item: Button = %QuickItem
@onready var menu_toggle: Button = %MenuToggle
@onready var menu_dropdown: PanelContainer = %MenuDropdown

var _menu_open := false
var _tree_was_paused := false
var _current_page := MenuPage.CHARACTER
var _progression: DungeonProgression


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	level_label.text = "LV. %02d" % preview_level
	exp_bar.value = preview_exp_percent
	exp_value.text = "EXP %d / 100" % roundi(preview_exp_percent)
	menu_toggle.toggled.connect(_on_menu_toggle)
	character_shortcut.pressed.connect(open_character_page)
	inventory_shortcut.pressed.connect(open_inventory_page)
	skills_shortcut.pressed.connect(open_skills_page)
	character_tab.pressed.connect(open_character_page)
	inventory_tab.pressed.connect(open_inventory_page)
	skills_tab.pressed.connect(open_skills_page)
	close_button.pressed.connect(close_menu)
	for slot in skill_slots:
		slot.pressed.connect(open_skills_page)
	quick_item.pressed.connect(open_inventory_page)
	if character_page.has_signal(&"attribute_spend_requested"):
		character_page.connect(&"attribute_spend_requested", _on_attribute_spend_requested)
	if skills_page.has_signal(&"skill_unlock_requested"):
		skills_page.connect(&"skill_unlock_requested", _on_skill_unlock_requested)
	if skills_page.has_signal(&"skill_equip_requested"):
		skills_page.connect(&"skill_equip_requested", _on_skill_equip_requested)
	_show_page(MenuPage.CHARACTER)
	modal.hide()
	menu_dropdown.hide()


func setup(progression: DungeonProgression) -> void:
	if _progression != null and _progression.progression_changed.is_connected(_apply_progression):
		_progression.progression_changed.disconnect(_apply_progression)
	_progression = progression
	if _progression == null:
		return
	if not _progression.progression_changed.is_connected(_apply_progression):
		_progression.progression_changed.connect(_apply_progression)
	_apply_progression(_progression.get_snapshot())


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	var key := key_event.keycode if key_event.keycode != KEY_NONE else key_event.physical_keycode
	if key == KEY_ESCAPE and (_menu_open or menu_dropdown.visible):
		if _menu_open:
			close_menu()
		else:
			menu_toggle.button_pressed = false
		get_viewport().set_input_as_handled()
		return
	if not _menu_open and get_tree().paused:
		return
	match key:
		KEY_C:
			_toggle_page(MenuPage.CHARACTER)
		KEY_I:
			_toggle_page(MenuPage.INVENTORY)
		KEY_K:
			_toggle_page(MenuPage.SKILLS)
		KEY_TAB:
			_toggle_page(MenuPage.CHARACTER)
		_:
			return
	get_viewport().set_input_as_handled()


func open_character_page() -> void:
	open_menu(MenuPage.CHARACTER)


func open_inventory_page() -> void:
	open_menu(MenuPage.INVENTORY)


func open_skills_page() -> void:
	open_menu(MenuPage.SKILLS)


func open_menu(page: MenuPage = MenuPage.CHARACTER) -> void:
	menu_toggle.button_pressed = false
	if not _menu_open:
		_tree_was_paused = get_tree().paused
		_menu_open = true
		modal.show()
		get_tree().paused = true
	_show_page(page)
	close_button.grab_focus()


func close_menu() -> void:
	if not _menu_open:
		return
	_menu_open = false
	modal.hide()
	get_tree().paused = _tree_was_paused
	menu_toggle.grab_focus()


func show_door_prompt(text: String) -> void:
	door_prompt_label.text = "E　" + text
	door_prompt.show()


func hide_door_prompt() -> void:
	door_prompt.hide()


func _on_attribute_spend_requested(attribute: StringName) -> void:
	if _progression != null:
		_progression.spend_attribute_point(attribute)


func _on_skill_unlock_requested(skill_id: StringName) -> void:
	if _progression != null:
		_progression.unlock_skill(skill_id)


func _on_skill_equip_requested(slot_index: int, skill_id: StringName) -> void:
	if _progression != null:
		_progression.equip_skill(slot_index, skill_id)


func _apply_progression(snapshot: Dictionary) -> void:
	level_label.text = "LV. %02d" % int(snapshot.get("level", 1))
	exp_bar.value = float(snapshot.get("experience_ratio", 0.0)) * 100.0
	exp_value.text = "EXP %d / %d" % [
		int(snapshot.get("experience", 0)),
		int(snapshot.get("experience_required", 100)),
	]
	if character_page.has_method(&"apply_progression"):
		character_page.call(&"apply_progression", snapshot)
	if skills_page.has_method(&"apply_progression"):
		skills_page.call(&"apply_progression", snapshot)
	_apply_skill_loadout(Array(snapshot.get("skill_loadout", [])))


func _apply_skill_loadout(loadout: Array) -> void:
	for index in skill_slots.size():
		var slot := skill_slots[index]
		var skill_id := StringName(str(loadout[index])) if index < loadout.size() else &""
		if skill_id == &"" or not SKILL_NAMES.has(skill_id):
			slot.disabled = true
			slot.icon = null
			slot.text = str(index + 1)
			slot.tooltip_text = "空的技能欄位"
			continue
		slot.disabled = false
		slot.icon = SKILL_ICONS[skill_id]
		slot.text = str(index + 1)
		slot.tooltip_text = "%s／已裝備" % SKILL_NAMES[skill_id]


func _on_menu_toggle(expanded: bool) -> void:
	menu_dropdown.visible = expanded
	if expanded:
		character_shortcut.grab_focus()


func _toggle_page(page: MenuPage) -> void:
	if _menu_open and _current_page == page:
		close_menu()
	else:
		open_menu(page)


func _show_page(page: MenuPage) -> void:
	_current_page = page
	character_page.visible = page == MenuPage.CHARACTER
	inventory_page.visible = page == MenuPage.INVENTORY
	skills_page.visible = page == MenuPage.SKILLS
	character_tab.button_pressed = page == MenuPage.CHARACTER
	inventory_tab.button_pressed = page == MenuPage.INVENTORY
	skills_tab.button_pressed = page == MenuPage.SKILLS


func _exit_tree() -> void:
	if _menu_open and is_instance_valid(get_tree()):
		get_tree().paused = _tree_was_paused

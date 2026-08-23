class_name JrpgSkillsPage
extends PanelContainer

signal skill_unlock_requested(skill_id: StringName)
signal skill_equip_requested(slot_index: int, skill_id: StringName)

const SKILLS := {
	&"ash_slash": {
		"name": "灰燼斬",
		"type": "主動戰技／近距離",
		"description": "以誓約之火纏繞刀刃，對前方敵人造成物理與火焰傷害。",
		"cost": "MP 8　／　冷卻 2.4 秒",
		"icon": preload("res://assets/ui/ability_icons/single-1.png"),
	},
	&"soul_orb": {
		"name": "靈魂星火",
		"type": "主動術式／遠距離",
		"description": "向指定方向釋放凝聚魔力，命中後引發小範圍靈魂爆發。",
		"cost": "MP 16　／　冷卻 5.0 秒",
		"icon": preload("res://assets/ui/ability_icons/single-2.png"),
	},
	&"shadow_step": {
		"name": "影步",
		"type": "移動戰技／迴避",
		"description": "瞬間踏出一段距離，並在短時間內提高迴避能力。",
		"cost": "MP 6　／　冷卻 3.2 秒",
		"icon": preload("res://assets/ui/ability_icons/single-3.png"),
	},
}

@onready var skill_points_label: Label = %SkillPoints
@onready var ash_slash: Button = %AshSlash
@onready var soul_orb: Button = %SoulOrb
@onready var shadow_step: Button = %ShadowStep
@onready var detail_icon: TextureRect = %DetailIcon
@onready var detail_name: Label = %DetailName
@onready var detail_type: Label = %DetailType
@onready var detail_description: Label = %DetailDescription
@onready var detail_cost: Label = %DetailCost
@onready var learn_button: Button = %LearnButton
@onready var equipped_slots: Array[Button] = [%Equipped1, %Equipped2, %Equipped3, %Equipped4]

var _selected_skill: StringName = &"ash_slash"
var _snapshot := {
	"skill_points": 1,
	"unlocked_skills": ["ash_slash"],
	"skill_loadout": ["ash_slash", "", "", ""],
	"skill_rules": {
		"ash_slash": {"point_cost": 0, "prerequisite": "", "unlocked": true, "can_unlock": false},
		"soul_orb": {"point_cost": 1, "prerequisite": "ash_slash", "unlocked": false, "can_unlock": true},
		"shadow_step": {"point_cost": 1, "prerequisite": "ash_slash", "unlocked": false, "can_unlock": true},
	},
}


func _ready() -> void:
	ash_slash.pressed.connect(_select_skill.bind(&"ash_slash"))
	soul_orb.pressed.connect(_select_skill.bind(&"soul_orb"))
	shadow_step.pressed.connect(_select_skill.bind(&"shadow_step"))
	learn_button.pressed.connect(_request_unlock)
	for index in equipped_slots.size():
		equipped_slots[index].pressed.connect(_request_equip.bind(index))
	apply_progression(_snapshot)


func apply_progression(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	skill_points_label.text = "SP　%d" % int(_snapshot.get("skill_points", 0))
	_refresh_tree_nodes()
	_refresh_loadout()
	_select_skill(_selected_skill)


func get_skill_presentation(skill_id: StringName) -> Dictionary:
	return SKILLS.get(skill_id, {})


func _select_skill(skill_id: StringName) -> void:
	if not SKILLS.has(skill_id):
		return
	_selected_skill = skill_id
	var skill: Dictionary = SKILLS[skill_id]
	detail_icon.texture = skill.icon
	detail_name.text = skill.name
	detail_type.text = skill.type
	detail_description.text = skill.description
	detail_cost.text = skill.cost
	ash_slash.button_pressed = skill_id == &"ash_slash"
	soul_orb.button_pressed = skill_id == &"soul_orb"
	shadow_step.button_pressed = skill_id == &"shadow_step"
	_refresh_learn_button()


func _request_unlock() -> void:
	if _can_learn(_selected_skill):
		skill_unlock_requested.emit(_selected_skill)


func _request_equip(slot_index: int) -> void:
	if not _is_unlocked(_selected_skill):
		learn_button.grab_focus()
		return
	skill_equip_requested.emit(slot_index, _selected_skill)


func _refresh_tree_nodes() -> void:
	var node_by_skill := {
		&"ash_slash": ash_slash,
		&"soul_orb": soul_orb,
		&"shadow_step": shadow_step,
	}
	for skill_id: StringName in node_by_skill:
		var node: Button = node_by_skill[skill_id]
		var skill: Dictionary = SKILLS[skill_id]
		var rule := _get_skill_rule(skill_id)
		var unlocked := _is_unlocked(skill_id)
		node.modulate = Color.WHITE if unlocked else Color(0.66, 0.68, 0.74, 0.9)
		node.text = String(skill.name) if unlocked else "%s\n未習得 SP %d" % [skill.name, int(rule.get("point_cost", 0))]
		node.tooltip_text = "已習得／點擊查看" if unlocked else "點擊查看並使用技能點習得"


func _refresh_loadout() -> void:
	var loadout: Array = _snapshot.get("skill_loadout", ["ash_slash", "", "", ""])
	for index in equipped_slots.size():
		var slot := equipped_slots[index]
		var skill_id := StringName(str(loadout[index])) if index < loadout.size() else &""
		var skill: Dictionary = SKILLS.get(skill_id, {})
		if skill.is_empty():
			slot.icon = null
			slot.text = "%d　空欄位" % (index + 1)
		else:
			slot.icon = skill.icon
			slot.text = "%d　%s" % [index + 1, skill.name]


func _refresh_learn_button() -> void:
	if _is_unlocked(_selected_skill):
		learn_button.text = "已習得"
		learn_button.disabled = true
		return
	var rule := _get_skill_rule(_selected_skill)
	var prerequisite := StringName(str(rule.get("prerequisite", "")))
	if prerequisite != &"" and not _is_unlocked(prerequisite):
		learn_button.text = "需要前置技能"
		learn_button.disabled = true
		return
	var cost := int(rule.get("point_cost", 0))
	learn_button.text = "習得技能　SP %d" % cost
	learn_button.disabled = not bool(rule.get("can_unlock", false))


func _can_learn(skill_id: StringName) -> bool:
	if _is_unlocked(skill_id) or not SKILLS.has(skill_id):
		return false
	return bool(_get_skill_rule(skill_id).get("can_unlock", false))


func _is_unlocked(skill_id: StringName) -> bool:
	return String(skill_id) in Array(_snapshot.get("unlocked_skills", []))


func _get_skill_rule(skill_id: StringName) -> Dictionary:
	var rules: Dictionary = _snapshot.get("skill_rules", {})
	return rules.get(String(skill_id), {})

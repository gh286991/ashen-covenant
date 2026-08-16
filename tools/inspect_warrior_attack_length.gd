extends SceneTree

func _init() -> void:
	var packed := load("res://assets/models/animated/fantasy_warrior_gameplay_head_level.glb") as PackedScene
	var root := packed.instantiate()
	var animation_player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip := animation_player.get_animation(&"Sword_Attack") if animation_player else null
	print("ATTACK_LENGTH ", clip.length if clip else -1.0)
	root.free()
	quit()

extends SceneTree

const DUNGEON_SCENE := preload("res://levels/dungeon_3d.tscn")
const OUTPUT_PATH := "/tmp/ashen-level-up-celebration.png"


func _init() -> void:
	call_deferred(&"_capture")


func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var dungeon := DUNGEON_SCENE.instantiate()
	root.add_child(dungeon)
	var prologue := dungeon.get_node_or_null("PrologueDialogue") as CanvasLayer
	if prologue != null:
		prologue.visible = false
	for _frame in 8:
		await process_frame
	var progression := dungeon.get_node("Player/Progression") as DungeonProgression
	progression.add_experience(progression.experience_required())
	await create_timer(0.48).timeout
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Unable to save celebration capture: %s" % error_string(error))
		quit(1)
		return
	print("LEVEL_UP_CAPTURE_OK %s" % OUTPUT_PATH)
	dungeon.free()
	quit(0)

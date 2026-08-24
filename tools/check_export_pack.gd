extends SceneTree

func _init() -> void:
	var roots := [
		"res://levels/main_menu_3d.tscn",
		"res://levels/main_menu.tscn",
		"res://levels/boot.tscn",
		"res://levels/dungeon_3d.tscn",
	]
	var failures: Array[String] = []
	for path in roots:
		var packed := load(path) as PackedScene
		if packed == null:
			failures.append(path)
			continue
		var instance := packed.instantiate()
		if instance == null:
			failures.append(path + " (instantiate)")
			continue
		instance.queue_free()
	print("EXPORT_PACK_CHECK %s failures=%s" % ["OK" if failures.is_empty() else "FAIL", failures])
	quit(0 if failures.is_empty() else 1)

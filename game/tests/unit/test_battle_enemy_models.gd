extends TestCase
## Every enemy's `model` path in battle/enemies.json points at a model that exists, so the data and the stage agree.


func test_every_enemy_model_path_exists() -> void:
	var db: Node = tree.root.get_node("DataDB")
	var enemies: Variant = db.get_json("battle/enemies").get("enemies", {})
	var entries: Array = (enemies as Dictionary).values() if enemies is Dictionary else enemies as Array
	assert_gt(entries.size(), 0, "enemies.json has enemies")
	for entry: Variant in entries:
		var enemy: Dictionary = entry as Dictionary
		var path: String = str(enemy.get("model", ""))
		assert_true(path != "" and ResourceLoader.exists(path), "%s model missing: '%s'" % [enemy.get("id", "?"), path])

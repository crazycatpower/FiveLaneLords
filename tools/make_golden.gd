extends SceneTree
# Rewrites tools/golden_matches.json from the current rules. Only run this when a gameplay change is
# intended, and commit the new file together with that change (see tools/golden.gd).
const Golden = preload("res://tools/golden.gd")

func _initialize() -> void:
	var rows: Array = []
	for seed_value: int in Golden.SEEDS: rows.append(Golden.fingerprint(seed_value))
	var file := FileAccess.open(Golden.PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	file.close()
	print("wrote %d golden matches to %s" % [rows.size(),Golden.PATH])
	quit()

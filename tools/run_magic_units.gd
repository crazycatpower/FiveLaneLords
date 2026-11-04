extends "res://tools/quick_test.gd"
# Dedicated suite: card validation and magic/arrow boundary cases only.
func run() -> void:
	check(B.validate().is_empty(),"card data validates")
	preload("res://tools/test_magic_units.gd").run(self)
	check(finished.get("magic_units",false),"magic tests completed")
	print("MAGIC: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)

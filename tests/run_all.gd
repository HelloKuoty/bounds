extends SceneTree
## Minimal test runner. Invoke via:
##   godot --headless --script res://tests/run_all.gd --path .
##
## Discovers `tests/test_*.gd`, instantiates each, and calls every `func test_*`
## method. Failures continue so the report shows all problems at once.
## Exit code 0 = all green, 1 = any failure.

const TEST_DIR := "res://tests/"

var _pass: int = 0
var _fail: int = 0
var _failures: Array = []


func _init() -> void:
	# Wait one frame so autoloads finish their _ready hooks.
	await process_frame
	_run_all()
	print("\n=== TESTS COMPLETE ===")
	print("PASS: %d   FAIL: %d" % [_pass, _fail])
	for f in _failures:
		print("  - %s" % f)
	quit(0 if _fail == 0 else 1)


func _run_all() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		push_error("Could not open tests dir: %s" % TEST_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.begins_with("test_") and fname.ends_with(".gd"):
			_run_file(TEST_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _run_file(path: String) -> void:
	print("\n--- %s ---" % path)
	var script: Script = load(path)
	if script == null:
		_fail += 1
		_failures.append("%s — load failed" % path)
		return
	var inst = script.new()
	if not (inst is Object):
		_fail += 1
		_failures.append("%s — instance creation failed" % path)
		return
	var methods: Array = inst.get_method_list()
	for m in methods:
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		var rep := _run_method(inst, name)
		if rep.is_empty():
			_pass += 1
			print("  PASS %s" % name)
		else:
			_fail += 1
			_failures.append("%s::%s — %s" % [path, name, rep])
			print("  FAIL %s — %s" % [name, rep])


func _run_method(inst: Object, name: String) -> String:
	if inst.has_method("setup"):
		inst.call("setup")
	# Use real methods (has_method only sees methods, not `var` properties).
	if inst.has_method("_reset_failure"):
		inst.call("_reset_failure")
	inst.call(name)
	var err := ""
	if inst.has_method("_get_failure"):
		err = str(inst.call("_get_failure"))
	if inst.has_method("teardown"):
		inst.call("teardown")
	return err

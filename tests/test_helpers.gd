extends RefCounted
class_name TestHelpers
## Tiny assertion helpers. Tests extend this and call assert_eq / fail.

var _failure_message: String = ""


func _reset_failure() -> void:
	_failure_message = ""


func _get_failure() -> String:
	return _failure_message


func fail(msg: String) -> void:
	if _failure_message == "":
		_failure_message = msg


func assert_eq(actual, expected, label: String = "") -> void:
	if actual != expected:
		fail("%s expected %s got %s" % [label, str(expected), str(actual)])


func assert_true(cond: bool, label: String = "") -> void:
	if not cond:
		fail("%s expected true" % label)


func assert_false(cond: bool, label: String = "") -> void:
	if cond:
		fail("%s expected false" % label)


func assert_not_null(obj, label: String = "") -> void:
	if obj == null:
		fail("%s expected non-null" % label)


func assert_in(needle, haystack, label: String = "") -> void:
	if not (needle in haystack):
		fail("%s expected %s to contain %s" % [label, str(haystack), str(needle)])

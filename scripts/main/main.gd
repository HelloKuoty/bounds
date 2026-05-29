extends Node
## Boot entry point + a minimal playable sequence: the four territories in order,
## so a playtest experiences every verb (wall → bundle → translator → the boss).
## Full menu / province-map routing lands later; the run logic already exists.

# Ordered so each verb is taught once, then its guidance fades on later visits —
# by the last two territories every verb is only a nudge, so you must read the
# board yourself.
const SEQUENCE := [
	"the_crossing",       # learn: wall
	"two_faced",          # wall (faded) + the "one clever cut clears two" idea
	"the_counting_house", # learn: bundle
	"the_two_tongues",    # wall (faded) + learn: translator
	"scroll_bond",        # all three, faded — read it yourself
	"the_sprawl",         # the boss: everything at once
]

var _index := 0
var _view: TerritoryView


func _ready() -> void:
	print("=== 界 / Bounds ===")
	_load_territory(0)


func _load_territory(i: int) -> void:
	_index = i
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	var t := TerritoryDatabase.get_territory(SEQUENCE[i])
	var board := BoardState.new()
	board.load_territory(t)
	_view = preload("res://scenes/territory/TerritoryView.tscn").instantiate()
	add_child(_view)
	_view.setup(board, GameState.taught)
	_view.continue_pressed.connect(_on_continue)
	_view.retry_pressed.connect(_on_retry)
	print("[Main] %s (%d/%d)" % [t.name, i + 1, SEQUENCE.size()])


func _on_continue() -> void:
	if _index + 1 < SEQUENCE.size():
		_load_territory(_index + 1)
	else:
		_view.show_finale()


func _on_retry() -> void:
	_load_territory(_index)

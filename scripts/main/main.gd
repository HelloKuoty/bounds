class_name BoundsMain extends Node
## Boot + run flow. An opening premise, then a province map you navigate: pick a
## node, solve its territory (or pass a waypoint), return to the map, on to the
## heartland. Narration bookends and punctuates the journey.

const UI_TEXTS := ["界", "启程", "继续"]

var _view: TerritoryView
var _map: RunMapView
var _screen: Control       # generic centered message overlay
var _pending: Callable
var _narr_i := 0


func _ready() -> void:
	print("=== 界 / Bounds ===")
	_show_message("界", Narrative.PREMISE, "启程", _on_start)


func _on_start() -> void:
	GameState.start_new_run()
	_show_map()


# --- screens ----------------------------------------------------------------

func _show_map() -> void:
	_clear_screens()
	_map = preload("res://scenes/run/RunMapView.tscn").instantiate()
	add_child(_map)
	_map.setup()
	_map.node_chosen.connect(_enter_node)


func _enter_node(node_id: String) -> void:
	GameState.enter_node(node_id)
	var node := RunManager.node(node_id)
	if node["territory_id"] == "":
		# a waypoint — a quiet line, then onward
		_show_message("", _next_narration(), "继续", _show_map)
	else:
		_open_territory(node_id)


func _open_territory(node_id: String) -> void:
	_clear_screens()
	var t := TerritoryDatabase.get_territory(RunManager.node(node_id)["territory_id"])
	var board := BoardState.new()
	board.load_territory(t)
	_view = preload("res://scenes/territory/TerritoryView.tscn").instantiate()
	add_child(_view)
	_view.setup(board, GameState.taught, _next_narration())
	_view.continue_pressed.connect(_on_territory_cleared.bind(node_id))
	_view.retry_pressed.connect(_open_territory.bind(node_id))
	print("[Main] %s" % t.name)


func _on_territory_cleared(node_id: String) -> void:
	if node_id == RunManager.boss_id:
		_view.show_finale(Narrative.ENDING)
	else:
		_show_map()


# --- generic message overlay ------------------------------------------------

func _show_message(title: String, body: String, btn_text: String, cb: Callable) -> void:
	_clear_screens()
	_pending = cb
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)

	var bg := ColorRect.new()
	bg.color = Color("0d0e13")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 24)
	vb.custom_minimum_size = Vector2(680, 0)
	center.add_child(vb)

	if title != "":
		var t := Label.new()
		t.text = title
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_font_size_override("font_size", 64)
		vb.add_child(t)

	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("font_color", Color("aab0c0"))
	vb.add_child(b)

	var btn := Button.new()
	btn.text = btn_text
	btn.custom_minimum_size = Vector2(160, 48)
	btn.pressed.connect(_on_screen_btn)
	vb.add_child(btn)


func _on_screen_btn() -> void:
	var cb := _pending
	_pending = Callable()
	if is_instance_valid(_screen):
		_screen.queue_free()
		_screen = null
	if cb.is_valid():
		cb.call()


func _clear_screens() -> void:
	for n in [_view, _map, _screen]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_view = null
	_map = null
	_screen = null


func _next_narration() -> String:
	var line: String = Narrative.NARRATION[_narr_i % Narrative.NARRATION.size()]
	_narr_i += 1
	return line

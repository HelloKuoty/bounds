class_name BoundsMain extends Node
## Boot + run flow. An opening premise, then a province map you navigate: pick a
## node, solve its territory (or pass a waypoint), return to the map, on to the
## heartland. Narration bookends and punctuates the journey.

const UI_TEXTS := ["界", "启程", "继续", "心法", "试炼之地 · 择一而入,各有取舍。",
	"博观", "持重", "通变", "局面大 · 心力宽", "局面小 · 零容错", "多一道令要接通"]

var _view: TerritoryView
var _map: RunMapView
var _screen: Control       # generic centered message overlay
var _pending: Callable
var _narr_i := 0
var _trial_mind := ""  # chosen 心法 for the current trial ("" = not yet chosen this visit)


func _ready() -> void:
	print("=== 界 / Bounds ===")
	_show_opening()


func _show_opening() -> void:
	_show_message("界", Narrative.HOOK, "启程", _on_start)  # 短钩子,不拿大段前言挡路


func _on_start() -> void:
	GameState.start_new_run()  # also resets what's been "taught"
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
	var tid: String = RunManager.node(node_id)["territory_id"]
	if TerritoryDatabase.has_territory(tid):
		_open_board(node_id, TerritoryDatabase.get_territory(tid))
	elif _trial_mind != "":
		# a seeded trial of the chosen 心法 — fresh & solvable, stable on retry this visit
		_open_board(node_id, TerritoryGen.make((hash(node_id) ^ GameState.run_seed) + hash(_trial_mind), _trial_mind))
	else:
		_show_trial_choice(node_id)  # first pick your 心法 — a build, not a difficulty slider


func _open_board(node_id: String, t: TerritoryData) -> void:
	_clear_screens()
	var board := BoardState.new()
	board.load_territory(t)
	_view = preload("res://scenes/territory/TerritoryView.tscn").instantiate()
	add_child(_view)
	_view.setup(board, GameState.taught, _next_narration())
	_view.continue_pressed.connect(_on_territory_cleared.bind(node_id))
	_view.retry_pressed.connect(_open_territory.bind(node_id))
	_view.restart_pressed.connect(_on_restart)
	print("[Main] %s" % t.name)


## 试炼之地: pick your 心法 — how deep a challenge. Each maps to a generator depth
## (1/2/3 troubles), always solvable by construction. A real, safe roguelike choice.
func _show_trial_choice(node_id: String) -> void:
	_clear_screens()
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
	vb.add_theme_constant_override("separation", 22)
	vb.custom_minimum_size = Vector2(600, 0)
	center.add_child(vb)
	var t := Label.new()
	t.text = "心法"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 56)
	vb.add_child(t)
	var b := Label.new()
	b.text = "试炼之地 · 择一而入,各有取舍。"
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_color_override("font_color", Color("aab0c0"))
	vb.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	for opt in [{"m": "broad", "t": "博观\n局面大 · 心力宽"}, {"m": "precise", "t": "持重\n局面小 · 零容错"}, {"m": "adaptive", "t": "通变\n多一道令要接通"}]:
		var btn := Button.new()
		btn.text = String(opt["t"])
		btn.custom_minimum_size = Vector2(150, 66)
		btn.pressed.connect(_on_trial_pick.bind(String(opt["m"]), node_id))
		row.add_child(btn)


func _on_trial_pick(mind: String, node_id: String) -> void:
	_trial_mind = mind
	_open_territory(node_id)


func _on_territory_cleared(node_id: String) -> void:
	_trial_mind = ""  # leaving this territory; a future trial picks its 心法 anew
	if node_id == RunManager.boss_id:
		_view.show_finale(Narrative.ENDING)
	else:
		_show_map()


func _on_restart() -> void:
	# After the ending: back to the very beginning, fresh.
	_narr_i = 0
	_show_opening()


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

class_name RunMapView extends Control
## Code-built province map: nodes laid out by layer, reachable ones lit and
## clickable, visited ones checked, the rest dimmed. Emits node_chosen when the
## steward picks where to go next. (Reads RunManager / GameState at runtime.)

signal node_chosen(node_id: String)

const UI_TEXTS := [
	"行省图", "选一处可去之地", "土地", "险地", "静室", "集市", "腹地 · 蔓沼", "✓ ",
]
const TYPE_NAMES := {
	"territory": "土地", "elite": "险地", "sanctum": "静室",
	"bazaar": "集市", "heartland": "腹地 · 蔓沼",
}


func setup() -> void:
	_build()


func _build() -> void:
	for c in get_children():
		c.free()
	set_anchors_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("0d0e13")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.text = "行省图"
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	var hint := Label.new()
	hint.text = "选一处可去之地"
	hint.add_theme_color_override("font_color", Color("8fd0e0"))
	col.add_child(hint)

	var by_layer: Dictionary = {}
	for nid in RunManager.nodes:
		var ly: int = RunManager.nodes[nid]["layer"]
		if not by_layer.has(ly):
			by_layer[ly] = []
		by_layer[ly].append(nid)

	var layers := by_layer.keys()
	layers.sort()
	var reachable := RunManager.reachable_from(GameState.current_node_id)
	for ly in layers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		for nid in by_layer[ly]:
			row.add_child(_node_button(nid, reachable))


func _node_button(nid: String, reachable: Array) -> Button:
	var n: Dictionary = RunManager.nodes[nid]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(128, 54)
	var visited: bool = RunManager.visited.has(nid)
	var is_reach: bool = nid in reachable
	var label: String = TYPE_NAMES.get(n["type"], n["type"])
	btn.text = ("✓ " if visited else "") + label
	if is_reach:
		btn.pressed.connect(_on_node_pressed.bind(nid))
	else:
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.6 if visited else 0.32)
	return btn


func _on_node_pressed(nid: String) -> void:
	node_chosen.emit(nid)

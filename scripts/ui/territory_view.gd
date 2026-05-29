class_name TerritoryView extends Control
## Code-built view of one territory. Renders pieces grouped by region, highlights
## instabilities in red, shows the order/rot clocks, and wires the steward's
## verbs (wall / bundle / translator / end turn) to the board.
##
## Built entirely in code (no hand-authored .tscn tree) so it constructs the same
## way in the editor, at runtime, and in a detached test instance.
##
## ALL player-visible text is listed in UI_TEXTS and scanned by test_no_jargon.

const UI_TEXTS := [
	"画界(分出所选)", "成束(所选 · 首个为守门人)", "拆束(把所选从一束分出)",
	"立译者石(连接两片所选区域)", "誊本(把筹码誊往另一区)", "共享(把活物借给另一区)",
	"结束回合", "秩序", "陈腐", "回合", "心力",
	"秩序重临 — 此地已净", "土地塌陷",
	"先选中要分出的棋子", "先选中要收束的棋子", "需选中跨越两片区域的棋子",
	"旷野", "继续 →", "重试", "四境皆清 · 国土重归秩序",
	"心力已尽 —— 切得太多了",
	"选中同属一束的几样,再分出去", "这些还没成束,无从拆起", "得给原束留一些",
	"誊本只对筹码;请先选一枚筹码", "再选一样在目标区域里的东西", "共享请先选一样活物",
	"再走一程",
]
const PALETTE := [
	Color("23303f"), Color("3a2f23"), Color("23402f"), Color("3a2336"), Color("2f2f44"), Color("403a23"),
]
const TINT_UNSTABLE := Color(1.0, 0.5, 0.5)
const TINT_CORRUPT := Color(0.55, 0.42, 0.55)

# Contextual guidance — speaks only in the world's own terms, never the concepts.
const G_OVERLOAD_SELECT := "红光处:两样东西都唤作「%s」,土地却认得它们并非一物。先点选其中一样。"
const G_OVERLOAD_ACT := "很好。按「画界」,把所选分到界外 —— 同一个名,在两片地各表一意,便不再相争。"
const G_CLUSTER_SELECT := "红光的这几样本该是一体,如今各自飘散。把它们全部点选。"
const G_CLUSTER_ACT := "按「成束」,让它们归于一束 —— 头一个所选,便是看门的。"
const G_CLASH_SELECT := "两片地被界隔开,却仍要彼此往来。从这两片地里各点一样。"
const G_CLASH_ACT := "按「立译者石」,在两片地之间架起一座通路。"
const G_SETTLED := "土地已然安宁。按「结束回合」,静观其变。"
const G_CLEARED := "此地已净。"
# Faded guidance — once a verb is learned, only point at the trouble, don't tell.
const G_NUDGE_OVERLOAD := "「%s」处,红光仍在相争。"
const G_NUDGE_CLUSTER := "几样泛红之物,本该是一体。"
const G_NUDGE_CLASH := "界的两边,还差一座通路。"
const G_BLOAT := "一束揽得太多了。从中点选几样,按「拆束」分出去,各有所守。"
const G_BLOAT_NUDGE := "一束揽得太多,分一些出去。"
const G_SHORTAGE := "此地缺一样东西。把别处的筹码点上,再点此地一样,按「誊本」誊来;若是活物,则用「共享」。"
const G_SHORTAGE_NUDGE := "此地还缺一样东西。"
const G_EXPOSED := "红斑要漫过来了!选中近旁的好东西,按「画界」把它们围到界外。"
const G_EXPOSED_NUDGE := "红斑近了 —— 把好东西围走。"

signal continue_pressed
signal retry_pressed
signal restart_pressed

var board: BoardState
var taught: Dictionary = {}           # verb -> true; drives fading guidance
var _selected: Dictionary = {}       # piece_id -> true
var _piece_widgets: Dictionary = {}  # piece_id -> Button
var _verb_btns: Dictionary = {}      # verb -> Button (lit only when applicable)
var _title: Label
var _intro: Label
var _narration: Label
var _narration_text := ""
var _guide: Label
var _regions_box: HFlowContainer
var _concord_bar: ProgressBar
var _blight_bar: ProgressBar
var _status: Label
var _hint: Label
var _overlay: Control
var _overlay_label: Label
var _overlay_btn: Button
var _overlay_mode := "clear"
var _built := false


func setup(b: BoardState, p_taught: Dictionary = {}, p_narration: String = "") -> void:
	board = b
	taught = p_taught
	_narration_text = p_narration
	if not _built:
		_build_chrome()
		_built = true
	board.concord_changed.connect(_on_meter_changed)
	board.blight_changed.connect(_on_meter_changed)
	board.territory_cleared.connect(_on_cleared)
	board.territory_failed.connect(_on_failed)
	board.action_refused.connect(_on_action_refused)
	_rebuild()


func _build_chrome() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("0f1016")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	col.add_child(_title)

	_intro = Label.new()
	_intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro.add_theme_color_override("font_color", Color("9aa0b0"))
	col.add_child(_intro)

	_narration = Label.new()
	_narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration.add_theme_color_override("font_color", Color("6a7080"))
	col.add_child(_narration)

	_guide = Label.new()
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide.add_theme_font_size_override("font_size", 18)
	_guide.add_theme_color_override("font_color", Color("8fd0e0"))
	col.add_child(_guide)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	_regions_box = HFlowContainer.new()
	_regions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_regions_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_regions_box)

	body.add_child(_build_hud())

	_overlay = CenterContainer.new()
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	var obox := VBoxContainer.new()
	obox.add_theme_constant_override("separation", 18)
	_overlay.add_child(obox)
	_overlay_label = Label.new()
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 44)
	obox.add_child(_overlay_label)
	_overlay_btn = Button.new()
	_overlay_btn.custom_minimum_size = Vector2(160, 44)
	_overlay_btn.pressed.connect(_on_overlay_btn)
	obox.add_child(_overlay_btn)


func _build_hud() -> Control:
	var hud := VBoxContainer.new()
	hud.custom_minimum_size = Vector2(280, 0)
	hud.add_theme_constant_override("separation", 8)

	hud.add_child(_label("秩序", Color("9fe0a0")))
	_concord_bar = ProgressBar.new()
	_concord_bar.show_percentage = false
	hud.add_child(_concord_bar)

	hud.add_child(_label("陈腐", Color("e08a8a")))
	_blight_bar = ProgressBar.new()
	_blight_bar.show_percentage = false
	hud.add_child(_blight_bar)

	_status = Label.new()
	hud.add_child(_status)

	_verb_btns["wall"] = _button("画界(分出所选)", _on_wall)
	_verb_btns["bundle"] = _button("成束(所选 · 首个为守门人)", _on_bundle)
	_verb_btns["split"] = _button("拆束(把所选从一束分出)", _on_split)
	_verb_btns["translator"] = _button("立译者石(连接两片所选区域)", _on_translator)
	_verb_btns["copy"] = _button("誊本(把筹码誊往另一区)", _on_copy)
	_verb_btns["share"] = _button("共享(把活物借给另一区)", _on_share)
	for key in ["wall", "bundle", "split", "translator", "copy", "share"]:
		hud.add_child(_verb_btns[key])
	hud.add_child(_button("结束回合", _on_end_turn))

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color("c8b878"))
	hud.add_child(_hint)

	return hud


func _rebuild() -> void:
	_selected.clear()
	_piece_widgets.clear()
	for c in _regions_box.get_children():
		c.free()

	var by_region: Dictionary = {}
	for pid in board.pieces:
		var r: int = board.pieces[pid]["region"]
		if not by_region.has(r):
			by_region[r] = []
		by_region[r].append(pid)

	var region_ids := by_region.keys()
	region_ids.sort()
	for r in region_ids:
		_regions_box.add_child(_build_region_panel(r, by_region[r]))

	_refresh_meters()
	_highlight_instabilities()
	_update_guide()
	_update_verb_buttons()


func _build_region_panel(region: int, piece_ids: Array) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PALETTE[region % PALETTE.size()]
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	sb.border_color = Color("0f1016")
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = board.region_names.get(region, "界域 %d" % region)
	name_lbl.add_theme_color_override("font_color", Color("cdd2dc"))
	vb.add_child(name_lbl)

	var flow := HFlowContainer.new()
	vb.add_child(flow)
	for pid in piece_ids:
		var btn := _make_piece_button(pid)
		_piece_widgets[pid] = btn
		flow.add_child(btn)

	return panel


func _make_piece_button(pid: String) -> Button:
	var p: Dictionary = board.pieces[pid]
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(92, 76)
	btn.clip_text = true
	btn.text = "%s\n%s" % [p["glyph"], p["label"]]
	btn.add_theme_font_size_override("font_size", 13)
	btn.toggled.connect(_on_piece_toggled.bind(pid))
	return btn


# --- verbs ------------------------------------------------------------------

func _on_piece_toggled(pressed: bool, pid: String) -> void:
	if pressed:
		_selected[pid] = true
	else:
		_selected.erase(pid)
	_update_guide()


func _on_wall() -> void:
	var ids := _selected.keys()
	if ids.is_empty():
		_set_hint("先选中要分出的棋子")
		return
	board.draw_wall(ids)
	taught["wall"] = true
	_set_hint("")
	_rebuild()


func _on_bundle() -> void:
	var ids := _selected.keys()
	if ids.is_empty():
		_set_hint("先选中要收束的棋子")
		return
	board.bundle(ids, ids[0])
	taught["bundle"] = true
	_set_hint("")
	_rebuild()


func _on_translator() -> void:
	var regions: Array = []
	for pid in _selected.keys():
		var r: int = board.region_of(pid)
		if not (r in regions):
			regions.append(r)
	if regions.size() < 2:
		_set_hint("需选中跨越两片区域的棋子")
		return
	board.place_translator(regions[0], regions[1])
	taught["translator"] = true
	_set_hint("")
	_rebuild()


func _on_split() -> void:
	var ids := _selected.keys()
	if ids.is_empty():
		_set_hint("选中同属一束的几样,再分出去")
		return
	var bid := board.bundle_of(ids[0])
	if bid == -1:
		_set_hint("这些还没成束,无从拆起")
		return
	for pid in ids:
		if board.bundle_of(pid) != bid:
			_set_hint("选中同属一束的几样,再分出去")
			return
	if ids.size() >= board.bundles[bid]["members"].size():
		_set_hint("得给原束留一些")
		return
	board.split_bundle(bid, ids)
	taught["split"] = true
	_set_hint("")
	_rebuild()


func _on_copy() -> void:
	var token := ""
	for pid in _selected.keys():
		if board.pieces[pid]["kind"] == "token":
			token = pid
			break
	if token == "":
		_set_hint("誊本只对筹码;请先选一枚筹码")
		return
	var target := -1
	for pid in _selected.keys():
		if board.region_of(pid) != board.region_of(token):
			target = board.region_of(pid)
			break
	if target == -1:
		_set_hint("再选一样在目标区域里的东西")
		return
	board.copy_token(token, target)
	taught["copy"] = true
	_set_hint("")
	_rebuild()


func _on_share() -> void:
	var src := ""
	for pid in _selected.keys():
		if board.pieces[pid]["kind"] == "living":
			src = pid
			break
	if src == "":
		_set_hint("共享请先选一样活物")
		return
	var target := -1
	for pid in _selected.keys():
		if board.region_of(pid) != board.region_of(src):
			target = board.region_of(pid)
			break
	if target == -1:
		_set_hint("再选一样在目标区域里的东西")
		return
	board.share(src, target)
	taught["share"] = true
	_set_hint("")
	_rebuild()


func _on_end_turn() -> void:
	board.advance_turn()
	_rebuild()


# --- refresh / feedback -----------------------------------------------------

func _highlight_instabilities() -> void:
	for inst in board.instabilities():
		match inst["type"]:
			"name_overload":
				for pid in board.pieces:
					var p: Dictionary = board.pieces[pid]
					if p["region"] == inst["region"] and p["glyph"] == inst["glyph"]:
						_tint(pid)
			"unguarded_cluster":
				for c in board.clusters:
					if c["id"] == inst["cluster"]:
						for m in c["members"]:
							_tint(m)
			"clash":
				for l in board.links:
					if l["id"] == inst["link"]:
						_tint(l["a"])
						_tint(l["b"])
			"bloated_bundle":
				if board.bundles.has(inst["bundle"]):
					for m in board.bundles[inst["bundle"]]["members"]:
						_tint(m)
			"shortage":
				for d in board.demands:
					if d["id"] == inst["demand"]:
						_tint(d["anchor"])
			"exposed":
				_tint(inst["piece"])
	# corruption reads darker than the red of a mere instability
	for pid in board.pieces:
		if board.pieces[pid].get("corrupted", false) and _piece_widgets.has(pid):
			_piece_widgets[pid].modulate = TINT_CORRUPT


func _tint(pid: String) -> void:
	if _piece_widgets.has(pid):
		_piece_widgets[pid].modulate = TINT_UNSTABLE


func _refresh_meters() -> void:
	_title.text = board.territory_name
	_intro.text = board.territory_intro
	_narration.text = _narration_text
	_concord_bar.max_value = max(1, board.concord_target)
	_concord_bar.value = board.concord
	_blight_bar.max_value = max(1, board.blight_max)
	_blight_bar.value = board.rot
	_status.text = "回合 %d    心力 %d" % [board.turn, board.insight]


func _update_guide() -> void:
	if board.cleared:
		_guide.text = G_CLEARED
		return
	var insts := board.instabilities()
	if insts.is_empty():
		_guide.text = G_SETTLED
		return
	var inst: Dictionary = insts[0]
	var sel := _selected.size()
	match inst["type"]:
		"name_overload":
			if taught.get("wall", false):
				_guide.text = G_NUDGE_OVERLOAD % inst["glyph"]
			else:
				_guide.text = G_OVERLOAD_SELECT % inst["glyph"] if sel == 0 else G_OVERLOAD_ACT
		"unguarded_cluster":
			if taught.get("bundle", false):
				_guide.text = G_NUDGE_CLUSTER
			else:
				_guide.text = G_CLUSTER_SELECT if sel == 0 else G_CLUSTER_ACT
		"clash":
			if taught.get("translator", false):
				_guide.text = G_NUDGE_CLASH
			else:
				var regions := {}
				for pid in _selected.keys():
					regions[board.region_of(pid)] = true
				_guide.text = G_CLASH_SELECT if regions.size() < 2 else G_CLASH_ACT
		"bloated_bundle":
			_guide.text = G_BLOAT_NUDGE if taught.get("split", false) else G_BLOAT
		"shortage":
			var knows: bool = taught.get("copy", false) or taught.get("share", false)
			_guide.text = G_SHORTAGE_NUDGE if knows else G_SHORTAGE
		"exposed":
			_guide.text = G_EXPOSED_NUDGE if taught.get("wall", false) else G_EXPOSED


## A verb button lights up only when the board currently has a problem it solves
## — so each action teaches its own purpose, and the rarely-needed ones (誊本/
## 共享) stop being confusing always-on noise.
func _update_verb_buttons() -> void:
	var types := {}
	for inst in board.instabilities():
		types[inst["type"]] = true
	var has_fresh_token := false
	for pid in board.pieces:
		var p: Dictionary = board.pieces[pid]
		if p["kind"] == "token" and not p.get("stale", false):
			has_fresh_token = true
			break
	_set_verb("wall", types.has("name_overload") or types.has("exposed"))
	_set_verb("bundle", types.has("unguarded_cluster"))
	_set_verb("split", types.has("bloated_bundle"))
	_set_verb("translator", types.has("clash"))
	_set_verb("copy", types.has("shortage") and has_fresh_token)
	_set_verb("share", types.has("shortage"))


func _set_verb(key: String, enabled: bool) -> void:
	if not _verb_btns.has(key):
		return
	var b: Button = _verb_btns[key]
	b.disabled = not enabled
	b.modulate = Color(1, 1, 1, 1.0) if enabled else Color(1, 1, 1, 0.32)


func _on_meter_changed(_v: int) -> void:
	_refresh_meters()


func _on_cleared() -> void:
	_overlay_mode = "clear"
	_overlay_label.text = "秩序重临 — 此地已净"
	_overlay_label.modulate = Color("9fe0a0")
	_overlay_btn.text = "继续 →"
	_overlay_btn.visible = true
	_overlay.visible = true


func _on_failed() -> void:
	_overlay_mode = "fail"
	_overlay_label.text = "土地塌陷"
	_overlay_label.modulate = Color("e08a8a")
	_overlay_btn.text = "重试"
	_overlay_btn.visible = true
	_overlay.visible = true


func _on_action_refused(_reason: String) -> void:
	# Out of care with the land still unsettled — offer an immediate restart.
	_overlay_mode = "fail"
	_overlay_label.text = "心力已尽 —— 切得太多了"
	_overlay_label.modulate = Color("e0b070")
	_overlay_btn.text = "重试"
	_overlay_btn.visible = true
	_overlay.visible = true


func _on_overlay_btn() -> void:
	match _overlay_mode:
		"clear":
			continue_pressed.emit()
		"finale":
			restart_pressed.emit()
		_:
			retry_pressed.emit()


## Called by the orchestrator after the final territory is cleared.
func show_finale(text: String = "四境皆清 · 国土重归秩序") -> void:
	_overlay_mode = "finale"
	_overlay_label.text = text
	_overlay_label.modulate = Color("e8d8a0")
	_overlay_btn.text = "再走一程"
	_overlay_btn.visible = true
	_overlay.visible = true


func _set_hint(t: String) -> void:
	_hint.text = t


# --- small builders ---------------------------------------------------------

func _label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b

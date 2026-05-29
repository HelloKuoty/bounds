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
	"再走一程", "灰的动作 = 此刻用不上", "形色相同 · 本是一物",
]
const PALETTE := [
	# Warm aged-map tones (sepia / ochre / terracotta / khaki / dusty-rose / moss),
	# all red-biased — an old map, not a cold debugger canvas. (顾屿, iter-07)
	Color("3a2c1c"), Color("33301c"), Color("3d271a"), Color("2c2a1a"), Color("382824"), Color("2e2e1a"),
]
const TINT_UNSTABLE := Color(1.0, 0.5, 0.5)
const TINT_CORRUPT := Color(0.55, 0.42, 0.55)
# A piece's hidden essence (其 真意), shown as an abstract badge — colour + shape,
# never the word. Same badge = the same thing; same name but a different badge = a
# name that secretly means two things (the clash). Read the board without reading
# the glyphs. Shape is the colour-blind-safe channel. (阿May / 周棠, iter-08)
const MEANING_COLORS := [
	Color("4fc3b0"), Color("e0a85a"), Color("e07a8f"), Color("8f9ae0"), Color("9fcf6a"),
]
const MEANING_SHAPES := ["circle", "square", "diamond", "triangle", "cross", "ring"]

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
var _ordered_pieces: Array = []      # stable order, for number-key selection
var _verb_btns: Dictionary = {}      # verb -> Button (lit only when applicable)
var _meaning_index: Dictionary = {}  # meaning -> stable int (drives badge colour/shape)
var _icon_cache: Dictionary = {}     # index -> ImageTexture (one badge per essence)
var _unstable_widgets: Array = []    # buttons currently trembling with distress (林晚)
var _anim_t := 0.0
var _flash: ColorRect                # warm release-flash layer — the exhale (林晚, iter-12)
var _flash_tween: Tween
var _last_concord := 0               # to detect "order won back" and exhale on it
var _pang_layer: ColorRect           # cold dark pain-flash — the wince (林晚, iter-15)
var _pang_tween: Tween
var _title: Label
var _intro: Label
var _narration: Label
var _narration_text := ""
var _guide: Label
var _regions_box: HFlowContainer
var _concord_label: Label
var _blight_label: Label
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
	_last_concord = b.concord
	if not _built:
		_build_chrome()
		_built = true
	board.concord_changed.connect(_on_meter_changed)
	board.blight_changed.connect(_on_meter_changed)
	board.territory_cleared.connect(_on_cleared)
	board.territory_failed.connect(_on_failed)
	board.action_refused.connect(_on_action_refused)
	# placeholder SFX on key events (AudioManager is silent-safe in headless)
	board.region_split.connect(func(_r, _n): AudioManager.play("wall"))
	board.bundle_formed.connect(func(_g): AudioManager.play("bundle"))
	board.translator_placed.connect(func(_a, _b): AudioManager.play("translator"))
	board.territory_cleared.connect(func(): AudioManager.play("clear"))
	board.territory_failed.connect(func(): AudioManager.play("fail"))
	board.action_refused.connect(func(_r): AudioManager.play("error"))
	_rebuild()


func _build_chrome() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color("17120b")  # warm fallback if the shader can't load
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = _parchment_material()  # procedural aged parchment (顾屿, iter-16)
	add_child(bg)

	# A soft warm vignette behind the content — darkened corners read as an aged
	# map. Pure code (radial gradient, no texture asset), so it ships on the web.
	var vignette := TextureRect.new()
	vignette.texture = _make_vignette()
	vignette.set_anchors_preset(PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

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
	_intro.add_theme_color_override("font_color", Color("b3a585"))
	col.add_child(_intro)

	_narration = Label.new()
	_narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration.add_theme_color_override("font_color", Color("8c8266"))
	col.add_child(_narration)

	_guide = Label.new()
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide.add_theme_font_size_override("font_size", 18)
	_guide.add_theme_color_override("font_color", Color("e6d3a3"))  # warm cream, not cold cyan
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

	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.95, 0.78, 0.0)  # warm light; alpha blooms briefly on release
	_flash.set_anchors_preset(PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_pang_layer = ColorRect.new()
	_pang_layer.color = Color(0.05, 0.05, 0.09, 0.0)  # cold dark; wells up briefly when the land founders
	_pang_layer.set_anchors_preset(PRESET_FULL_RECT)
	_pang_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pang_layer)

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

	_concord_label = _label("秩序", Color("9fe0a0"))
	hud.add_child(_concord_label)
	_concord_bar = ProgressBar.new()
	_concord_bar.show_percentage = false
	hud.add_child(_concord_bar)

	_blight_label = _label("陈腐", Color("e08a8a"))
	hud.add_child(_blight_label)
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

	var legend := _label("灰的动作 = 此刻用不上", Color("8c8266"))
	legend.add_theme_font_size_override("font_size", 12)
	hud.add_child(legend)

	var legend2 := _label("形色相同 · 本是一物", Color("8c8266"))
	legend2.add_theme_font_size_override("font_size", 12)
	hud.add_child(legend2)

	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color", Color("c8b878"))
	hud.add_child(_hint)

	return hud


func _rebuild() -> void:
	_selected.clear()
	_piece_widgets.clear()
	_ordered_pieces.clear()
	for c in _regions_box.get_children():
		c.free()
	_index_meanings()

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
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	sb.border_color = Color("4a3a24")  # warm sepia ink line — a plot on an old map
	sb.set_border_width_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 3
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = board.region_names.get(region, "界域 %d" % region)
	name_lbl.add_theme_color_override("font_color", Color("dac9a6"))
	vb.add_child(name_lbl)

	var flow := HFlowContainer.new()
	vb.add_child(flow)
	for pid in piece_ids:
		var btn := _make_piece_button(pid)
		_piece_widgets[pid] = btn
		_ordered_pieces.append(pid)
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
	# A selected piece wears a thick bright ring. The cue is border *thickness*,
	# not hue — so it survives colour-blindness and keyboard-only play. (周棠, iter-07)
	btn.add_theme_stylebox_override("normal", _piece_box(Color("33291a"), Color("1b1308"), 2))
	btn.add_theme_stylebox_override("hover", _piece_box(Color("40331f"), Color("2a1e0e"), 2))
	var ring := _piece_box(Color("4a3a22"), Color("f0d89a"), 3)
	btn.add_theme_stylebox_override("pressed", ring)
	btn.add_theme_stylebox_override("focus", ring)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(st, Color("ece0c4"))  # warm ink, like a stamped mark
	btn.icon = _meaning_icon(p["meaning"])  # the essence badge — read the board, not the glyphs
	btn.add_theme_constant_override("h_separation", 5)
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
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


# --- keyboard play (accessibility) ------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key((event as InputEventKey).keycode)


## Number keys 1–9 select pieces in order; Q/W/E/R/T/Y trigger the six actions;
## Space ends the turn. Directly callable (no real key event) so it's testable.
func _handle_key(keycode: int) -> void:
	if keycode >= KEY_1 and keycode <= KEY_9:
		var idx := keycode - KEY_1
		if idx < _ordered_pieces.size():
			_toggle_piece(_ordered_pieces[idx])
		return
	match keycode:
		KEY_SPACE: _on_end_turn()
		KEY_Q: _on_wall()
		KEY_W: _on_bundle()
		KEY_E: _on_split()
		KEY_R: _on_translator()
		KEY_T: _on_copy()
		KEY_Y: _on_share()


func _toggle_piece(pid: String) -> void:
	if _piece_widgets.has(pid):
		var b: Button = _piece_widgets[pid]
		b.button_pressed = not b.button_pressed  # emits toggled → updates _selected + guide
		if b.is_inside_tree():
			b.grab_focus()  # keyboard users see where they are (engine focus outline)


# --- refresh / feedback -----------------------------------------------------

func _highlight_instabilities() -> void:
	_unstable_widgets.clear()
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
	# corruption reads darker than a mere instability — plus a distinct mark
	for pid in board.pieces:
		if board.pieces[pid].get("corrupted", false) and _piece_widgets.has(pid):
			var b: Button = _piece_widgets[pid]
			b.modulate = TINT_CORRUPT
			if not b.text.begins_with("×"):
				b.text = "×" + b.text.trim_prefix("！")


func _tint(pid: String) -> void:
	if not _piece_widgets.has(pid):
		return
	var b: Button = _piece_widgets[pid]
	b.modulate = TINT_UNSTABLE
	if not _unstable_widgets.has(b):
		_unstable_widgets.append(b)  # the world reacts: this piece will tremble (林晚, iter-09)
	if not b.text.begins_with("！") and not b.text.begins_with("×"):
		b.text = "！" + b.text  # non-colour cue: a mark, not just red (for colour-blind play)


## The world reacts to trouble: an unstable piece trembles and breathes — alive and
## in distress. The feedback IS the piece, not a label pinned on it; the "！" mark
## stays as a still, colour-blind-safe backup. (林晚, iter-09)
func _process(delta: float) -> void:
	if _unstable_widgets.is_empty():
		return
	_anim_t += delta
	var intensity := _distress_intensity()
	for i in _unstable_widgets.size():
		var b: Button = _unstable_widgets[i]
		if not is_instance_valid(b):
			continue
		var tr := _distress_transform(_anim_t, i * 1.3, intensity)
		b.pivot_offset = b.size * 0.5
		b.rotation = tr["rotation"]
		b.scale = tr["scale"]


## How violently the land trembles — grows as rot nears collapse. A non-colour
## reading of "how close to death" (the danger meter for colour-blind play, since
## a red bar's brightness is exactly what colour-blindness can't read). (周棠, iter-11)
func _distress_intensity() -> float:
	if board == null or board.blight_max <= 0:
		return 1.0
	return 1.0 + clampf(float(board.rot) / float(board.blight_max), 0.0, 1.0) * 1.6


## Pure (testable) distress transform: a quick small tremble + a slow breath,
## amplified by `intensity` (1.0 = calm … ~2.6 = near collapse).
func _distress_transform(t: float, phase: float, intensity: float = 1.0) -> Dictionary:
	var rot := sin(t * 17.0 + phase) * 0.045 * intensity
	var sc := 1.0 + sin(t * 5.0 + phase) * 0.035 * intensity
	return {"rotation": rot, "scale": Vector2(sc, sc)}


func _refresh_meters() -> void:
	_title.text = board.territory_name
	_intro.text = board.territory_intro
	_narration.text = _narration_text
	_concord_label.text = "秩序  %d / %d" % [board.concord, board.concord_target]
	_blight_label.text = "陈腐  %d / %d" % [board.rot, board.blight_max]
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
	if board.concord > _last_concord:
		_release_bloom(0.16)  # a small exhale each time a little order is won back
	_last_concord = board.concord
	_refresh_meters()


## A warm exhale of light — the land breathing out as order returns. The "release"
## that closes pain → insight → relief. Re-entrant-safe; no-op when detached so it
## never touches headless or crashes a test. (林晚, iter-12)
func _release_bloom(strength: float) -> void:
	if _flash == null or not is_inside_tree():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash.color.a = 0.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", strength, 0.12)
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.45)


## A cold, dark wince — warmth draining as the land founders. The "pain" pole that
## answers the warm release, so the loop has both poles (pain → insight → relief).
## Slower fall than the release — pain lingers. Detached-safe. (林晚, iter-15)
func _pang(strength: float) -> void:
	if _pang_layer == null or not is_inside_tree():
		return
	if _pang_tween != null and _pang_tween.is_valid():
		_pang_tween.kill()
	_pang_layer.color.a = 0.0
	_pang_tween = create_tween()
	_pang_tween.tween_property(_pang_layer, "color:a", strength, 0.10)
	_pang_tween.tween_property(_pang_layer, "color:a", 0.0, 0.60)


func _on_cleared() -> void:
	_release_bloom(0.42)  # the big exhale — the land is whole again
	_overlay_mode = "clear"
	_overlay_label.text = "秩序重临 — 此地已净"
	_overlay_label.modulate = Color("9fe0a0")
	_overlay_btn.text = "继续 →"
	_overlay_btn.visible = true
	_overlay.visible = true


func _on_failed() -> void:
	_pang(0.5)  # the wince — warmth drains as the land founders
	_overlay_mode = "fail"
	_overlay_label.text = "土地塌陷"
	_overlay_label.modulate = Color("e08a8a")
	_overlay_btn.text = "重试"
	_overlay_btn.visible = true
	_overlay.visible = true


func _on_action_refused(_reason: String) -> void:
	# Out of care with the land still unsettled — offer an immediate restart.
	_pang(0.34)
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
	_release_bloom(0.5)
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


func _piece_box(bg: Color, border: Color, w: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(w)
	sb.set_corner_radius_all(14)  # a rounded seal/token, not a debug rectangle (顾屿, iter-14)
	sb.set_content_margin_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.33)  # a little depth — the chip sits on the map
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(1, 2)
	return sb


## A radial gradient — clear centre, warm-dark edges — for the aged-map vignette.
func _make_vignette() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([
		Color(0.04, 0.03, 0.015, 0.0),
		Color(0.04, 0.03, 0.015, 0.0),
		Color(0.03, 0.02, 0.01, 0.5),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


## Assign each distinct essence a stable index (sorted, so badges don't shuffle
## between rebuilds). Copies share their source's essence, so the set is stable.
func _index_meanings() -> void:
	var seen := {}
	for pid in board.pieces:
		seen[board.pieces[pid]["meaning"]] = true
	var ms := seen.keys()
	ms.sort()
	_meaning_index.clear()
	for i in ms.size():
		_meaning_index[ms[i]] = i


func _meaning_icon(meaning: String) -> Texture2D:
	var idx: int = _meaning_index.get(meaning, 0)
	if _icon_cache.has(idx):
		return _icon_cache[idx]
	var color: Color = MEANING_COLORS[idx % MEANING_COLORS.size()]
	var shape: String = MEANING_SHAPES[idx % MEANING_SHAPES.size()]
	var tex := _draw_shape(color, shape)
	_icon_cache[idx] = tex
	return tex


## Rasterise a small filled shape (no asset files — ships on the web). The shape
## carries essence for colour-blind play; the colour for everyone else.
func _draw_shape(color: Color, shape: String) -> ImageTexture:
	var s := 20
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := s / 2.0 - 0.5
	var cy := s / 2.0 - 0.5
	var r := s * 0.42
	for y in s:
		for x in s:
			var dx: float = x - cx
			var dy: float = y - cy
			var inside := false
			match shape:
				"circle":
					inside = dx * dx + dy * dy <= r * r
				"square":
					inside = absf(dx) <= r * 0.9 and absf(dy) <= r * 0.9
				"diamond":
					inside = absf(dx) + absf(dy) <= r * 1.15
				"triangle":
					var t := (dy + r) / (2.0 * r)
					inside = dy <= r and dy >= -r and absf(dx) <= r * t
				"cross":
					inside = (absf(dx) <= r * 0.34 and absf(dy) <= r) or (absf(dy) <= r * 0.34 and absf(dx) <= r)
				"ring":
					var d2 := dx * dx + dy * dy
					inside = d2 <= r * r and d2 >= (r * 0.55) * (r * 0.55)
				_:
					inside = dx * dx + dy * dy <= r * r
			if inside:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


## Procedural aged-parchment backdrop material (shader, no texture asset). Returns
## null if the shader can't load, leaving the flat warm fallback colour. (顾屿, iter-16)
func _parchment_material() -> ShaderMaterial:
	var sh := load("res://shaders/parchment.gdshader") as Shader
	if sh == null:
		return null
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

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
	"再走一程", "灰的动作 = 此刻用不上", "形色相同 · 本是一物", "减弱动效",
	"净化此地", "速净", "一气呵成", "秩序重临",
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
const STAR_NAMES := {1: "净化此地", 2: "速净", 3: "一气呵成"}  # mastery, shown only on clear (iter-27)

# Guidance teaches the TOOL and HOW TO DIAGNOSE — never which pieces. The first time
# a trouble appears, teach what the verb does + the heuristic to look for; once the
# verb is learned the guide goes quiet (G_LOOK) and diagnosis is the player's job —
# the red / ！/ tremble are feedback, not the answer. (去保姆化, iter-25)
const G_TEACH_WALL := "一个『名』,两样各表一意,土地便乱。【画界】把同名异意的分到两片地 —— 自己找:何处名同、形色却不同?"
const G_TEACH_BUNDLE := "有几样本是一体,却各自飘散。【成束】把它们收拢、立一个看门的 —— 自己认:哪些形色相同、本该同束?"
const G_TEACH_SPLIT := "一束揽得太多,便守不住。【拆束】把其中几样分出去,各有所守 —— 看看哪一束太满。"
const G_TEACH_TRANSLATOR := "界隔开了两片地,有些事仍要往来。【立译者石】在两片地间架一座通路 —— 找那对隔界相望、却还连着的。"
const G_TEACH_SHORTAGE := "此地缺一味。筹码可【誊本】誊来一份;独一份的活物只能【共享】(有代价) —— 看缺的是什么。"
const G_TEACH_EXPOSED := "腐斑要漫开了。【画界】把近旁的好东西围到界外 —— 趁它还没沾上。"
const G_TEACH_HERALD := "一道令要顺着信使一环环传到头,半路被界隔断了 —— 在断处【立译者石】,让令接着传过去。"
const G_LOOK := "土地不安 —— 细看名与形,自寻其谬。"
const G_SETTLED := "土地已然安宁。按「结束回合」,静观其变。"
const G_CLEARED := "此地已净。"

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
static var reduce_motion := false     # accessibility: turn off the tremble (周棠, iter-17)
var _content: MarginContainer        # the inset content — shaken on an epiphany (小鹿, iter-18)
var _shake_tween: Tween
var _herald_line: Line2D             # the thread a 令 runs along (传令链, iter-32)
var _herald_dot: ColorRect           # the travelling signal; stops at a break
var _herald_t := 0.0
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

	_content = MarginContainer.new()
	_content.set_anchors_preset(PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		_content.add_theme_constant_override(side, 24)
	add_child(_content)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_content.add_child(col)

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

	# 传令链 viz: a warm thread the 令 runs along + a travelling signal dot (iter-32)
	_herald_line = Line2D.new()
	_herald_line.width = 3.0
	_herald_line.default_color = Color(0.95, 0.85, 0.55, 0.5)
	_herald_line.visible = false
	add_child(_herald_line)
	_herald_dot = ColorRect.new()
	_herald_dot.color = Color(1.0, 0.96, 0.74)
	_herald_dot.size = Vector2(12, 12)
	_herald_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_herald_dot.visible = false
	add_child(_herald_dot)

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

	var motion := CheckButton.new()
	motion.text = "减弱动效"
	motion.button_pressed = reduce_motion
	motion.add_theme_font_size_override("font_size", 12)
	motion.toggled.connect(func(on: bool): TerritoryView.reduce_motion = on)
	hud.add_child(motion)

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
	var kin := _unites_hidden_kin(ids)  # uniting same-essence / different-name pieces = seeing through the name
	board.bundle(ids, ids[0])
	taught["bundle"] = true
	_set_hint("")
	if kin:
		_epiphany()
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
	var fixing_herald := false
	for inst in board.instabilities():
		if inst["type"] == "severed_chain":
			fixing_herald = true
	board.place_translator(regions[0], regions[1])
	taught["translator"] = true
	if fixing_herald:
		taught["herald"] = true
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
			b.text = "×" + _strip_marks(b.text)


func _tint(pid: String) -> void:
	if not _piece_widgets.has(pid):
		return
	var b: Button = _piece_widgets[pid]
	b.modulate = TINT_UNSTABLE
	if not _unstable_widgets.has(b):
		_unstable_widgets.append(b)  # the world reacts: this piece will tremble (林晚, iter-09)
	# graded non-colour cue: !/!!/!!! by how near collapse — a nameable severity that
	# needs neither colour nor animation to read (周棠, iter-17)
	b.text = _severity_marks() + _strip_marks(b.text)


## The world reacts to trouble: an unstable piece trembles and breathes — alive and
## in distress. The feedback IS the piece, not a label pinned on it; the "！" mark
## stays as a still, colour-blind-safe backup. (林晚, iter-09)
func _process(delta: float) -> void:
	_update_herald_viz(delta)
	if _unstable_widgets.is_empty():
		return
	if reduce_motion:  # vestibular-safe: hold pieces still; the !/!!/!!! marks carry severity
		for b in _unstable_widgets:
			if is_instance_valid(b):
				b.rotation = 0.0
				b.scale = Vector2.ONE
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


## How far a 令 carries along a chain: the index of the last piece the signal reaches
## before a hop crosses an unbridged border (where it stops). Pure & testable. (iter-32)
func _herald_reach(chain: Array) -> int:
	var reach := 0
	for i in range(chain.size() - 1):
		var a: String = chain[i]
		var b: String = chain[i + 1]
		if not board.pieces.has(a) or not board.pieces.has(b):
			break
		var ra: int = board.region_of(a)
		var rb: int = board.region_of(b)
		if ra != rb and not board.bridged(ra, rb):
			break
		reach = i + 1
	return reach


## Draw the chain as a thread and run a glowing signal along the part it can reach —
## it visibly stops at the break (both the new "ripple" feel and a where-to-bridge cue).
func _update_herald_viz(delta: float) -> void:
	if _herald_line == null:
		return
	if board == null or board.heralds.is_empty() or not is_inside_tree():
		_herald_line.visible = false
		_herald_dot.visible = false
		return
	var chain: Array = board.heralds[0]["chain"]
	var pts: Array = []
	for pid in chain:
		if _piece_widgets.has(pid) and is_instance_valid(_piece_widgets[pid]):
			var b: Button = _piece_widgets[pid]
			pts.append(b.global_position + b.size * 0.5)
	if pts.size() < 2:
		_herald_line.visible = false
		_herald_dot.visible = false
		return
	_herald_line.points = PackedVector2Array(pts)
	_herald_line.visible = true
	if reduce_motion:
		_herald_dot.visible = false
		return
	var reach: int = _herald_reach(chain)
	_herald_t += delta * 0.9
	var span: float = float(maxi(1, reach))
	var u: float = fmod(_herald_t, span)
	var idx: int = clampi(int(floor(u)), 0, pts.size() - 2)
	var p: Vector2 = (pts[idx] as Vector2).lerp(pts[idx + 1] as Vector2, u - float(idx))
	_herald_dot.global_position = p - _herald_dot.size * 0.5
	_herald_dot.visible = true


## Severity as a nameable, colour-free, motion-free mark: !/!!/!!! by how near
## the land is to collapse. The discrete read周棠 asked for. (iter-17)
func _severity_marks() -> String:
	if board == null or board.blight_max <= 0:
		return "！"
	var r := float(board.rot) / float(board.blight_max)
	if r >= 0.66:
		return "！！！"
	elif r >= 0.33:
		return "！！"
	return "！"


func _strip_marks(t: String) -> String:
	var s := t
	while s.begins_with("！") or s.begins_with("×"):
		s = s.substr(1)
	return s


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
	# Teach the tool + how to diagnose the first time a trouble appears — never which
	# pieces. Once the verb is learned, go quiet and let the player read the board.
	match insts[0]["type"]:
		"name_overload":
			_guide.text = G_LOOK if taught.get("wall", false) else G_TEACH_WALL
		"unguarded_cluster":
			_guide.text = G_LOOK if taught.get("bundle", false) else G_TEACH_BUNDLE
		"bloated_bundle":
			_guide.text = G_LOOK if taught.get("split", false) else G_TEACH_SPLIT
		"clash":
			_guide.text = G_LOOK if taught.get("translator", false) else G_TEACH_TRANSLATOR
		"shortage":
			_guide.text = G_LOOK if (taught.get("copy", false) or taught.get("share", false)) else G_TEACH_SHORTAGE
		"exposed":
			_guide.text = G_LOOK if taught.get("wall", false) else G_TEACH_EXPOSED
		"severed_chain":
			_guide.text = G_LOOK if taught.get("herald", false) else G_TEACH_HERALD


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
	_set_verb("translator", types.has("clash") or types.has("severed_chain"))
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


## True when bundling these ids unites ≥2 pieces of the SAME essence under DIFFERENT
## names — the "seeing through the name" moment (the hidden kin of 名障镇). (小鹿, iter-18)
func _unites_hidden_kin(ids: Array) -> bool:
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Dictionary = board.pieces[ids[i]]
			var b: Dictionary = board.pieces[ids[j]]
			if a["meaning"] == b["meaning"] and a["glyph"] != b["glyph"]:
				return true
	return false


## The epiphany beat: a brighter exhale + a short shake — distinct from an ordinary
## resolve, so recognising kin under two names lands as a moment. Detached-safe.
func _epiphany() -> void:
	_release_bloom(0.6)
	if _content == null or not is_inside_tree():
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for amt in [9.0, -6.0, 4.0, -2.0, 0.0]:
		_shake_tween.tween_property(_content, "position:x", amt, 0.05)


func _on_cleared() -> void:
	_release_bloom(0.42)  # the big exhale — the land is whole again
	var s := board.stars()
	GameState.record_stars(board.territory_id, s)  # best is remembered; revealed only here, never hinted
	_overlay_mode = "clear"
	_overlay_label.text = "%s\n秩序重临 · %s" % ["★".repeat(s), STAR_NAMES.get(s, "净化此地")]
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

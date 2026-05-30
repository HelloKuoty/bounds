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
const G_TEACH_SHORTAGE := "此地缺一味。可誊的(无名筹码)就【誊本】补一份 —— 但誊本会走味,搁几手便不顶用;独一份的活物誊不得,只能【共享】 —— 可两处一旦合用,便从此一同渗坏,越拖越重。看缺的是什么,再定怎么补。"
# Cost feedback the moment you copy / share — so the tradeoff is felt, not hidden
# (林晚"试哪个亮" / 老陈"共享要有耦合代价", iter-39). 誊本走味 ≠ 共享渗坏.
const G_COPIED := "誊了一份过去 —— 这份会走味,搁几手便不顶用,趁早把局面收清。"
const G_SHARED := "两处合用了一样 —— 自此一同渗坏,越拖越重,早些理清才好。"
const G_TEACH_EXPOSED := "腐斑要漫开了。【画界】把近旁的好东西围到界外 —— 趁它还没沾上。"
const G_TEACH_HERALD := "一道令要顺着信使一环环传到头,半路被界隔断了 —— 在断处【立译者石】,让令接着传过去。"
# Stuck-safety net (阿May, iter-36): after a stretch with no progress, the de-hand-hold
# guide softens to a TYPE hint — it names the trouble + the fix verb, but STILL never
# which pieces. Any action or selection resets the timer.
const STUCK_SECS := 30.0
const SETTLE_DUR := 0.6   # the length of the "归位呼吸" the board takes when the land settles (顾屿, iter-51)
const G_HINT_WALL := "卡住了?此地有两样同名异意 —— 用「画界」把它们分到两片地。"
const G_HINT_BUNDLE := "卡住了?有几样本是一体却各自散着 —— 用「成束」把它们收拢。"
const G_HINT_SPLIT := "卡住了?有一束揽得太多 —— 用「拆束」分一些出去。"
const G_HINT_TRANSLATOR := "卡住了?界的两边有该往来的 —— 用「立译者石」架一座通路。"
const G_HINT_HERALD := "卡住了?一道令被界隔断了 —— 在断处「立译者石」接上。"
const G_HINT_SHORTAGE := "卡住了?此地缺一样东西 —— 「誊本」誊来,或「共享」借用。"
const G_HINT_EXPOSED := "卡住了?腐斑要漫开 —— 用「画界」把好东西围到界外。"
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
var _herald_trail: Line2D            # comet tail behind the signal (顾屿, iter-35)
var _herald_break_mark: Label        # ✕ where the 令 can't cross (林晚, iter-35)
var _herald_trail_pts: Array = []
var _idle_t := 0.0                   # seconds since last progress; drives the stuck hint (阿May, iter-36)
var _prev_inst := -1                 # trouble count before the last move; a non-reducing move surfaces the hint (小鹿, iter-42)
var _fumbles := 0                    # consecutive no-progress moves; the hint waits for the 2nd (林晚, iter-46)
var _settle_t := -1.0                # >=0 while the board plays its one "settle breath" on clear (顾屿, iter-51)
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
var _overlay_subtext: Label
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
	board.shared.connect(func(_p, _r): AudioManager.play("share"))
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
	_herald_trail = Line2D.new()
	_herald_trail.width = 7.0
	var tgrad := Gradient.new()
	tgrad.offsets = PackedFloat32Array([0.0, 1.0])
	tgrad.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 0.0), Color(1.0, 0.95, 0.7, 0.7)])
	_herald_trail.gradient = tgrad
	_herald_trail.visible = false
	add_child(_herald_trail)
	_herald_dot = ColorRect.new()
	_herald_dot.color = Color(1.0, 0.96, 0.74)
	_herald_dot.size = Vector2(12, 12)
	_herald_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_herald_dot.visible = false
	add_child(_herald_dot)
	_herald_break_mark = Label.new()
	_herald_break_mark.text = "✕"
	_herald_break_mark.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	# A dark outline makes the ✕ shape unmistakable on any background — the break reads by
	# SHAPE, not by its red hue, so a colour-blind player isn't relying on "the red one". (周棠, iter-42)
	_herald_break_mark.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	_herald_break_mark.add_theme_constant_override("outline_size", 5)
	_herald_break_mark.add_theme_font_size_override("font_size", 22)
	_herald_break_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_herald_break_mark.visible = false
	add_child(_herald_break_mark)

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
	_overlay_subtext = Label.new()   # closing micro-line (情感 + 复盘), shown under the stars
	_overlay_subtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_subtext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_subtext.custom_minimum_size = Vector2(520, 0)
	_overlay_subtext.add_theme_font_size_override("font_size", 18)
	_overlay_subtext.add_theme_color_override("font_color", Color("cdbb92"))
	obox.add_child(_overlay_subtext)
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
	_idle_t = 0.0   # a board change = progress; restart the stuck-hint clock
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
	# 小鹿(iter-42) + 林晚(iter-46): a move that didn't reduce the trouble count counts as a
	# fumble — but ONE fumble is just trial-and-error (which IS the puzzle), so stay quiet.
	# Only a SECOND no-progress move in a row surfaces the type-hint (genuinely stuck, not
	# merely trying). The hint still only names the KIND of trouble + the verb, never pieces.
	var now_inst := board.instabilities().size()
	if _prev_inst >= 0 and not board.cleared:
		if now_inst >= _prev_inst:
			_fumbles += 1
		else:
			_fumbles = 0
		if _fumbles >= 2:
			var fumble_hint := _stuck_hint_text()
			if fumble_hint != "":
				_guide.text = fumble_hint
	_prev_inst = now_inst


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
	btn.add_theme_stylebox_override("normal", _box_normal())
	btn.add_theme_stylebox_override("hover", _box_hover())
	var ring := _box_selected()
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
	_idle_t = 0.0   # the player is engaging; they're not stuck
	_refresh_name_kin()
	_update_guide()


## Pieces sharing this one's name (same 字形), regardless of meaning — a perception
## aid only: same-name may be a clash (act) OR perfectly fine (same meaning), so this
## never points at the answer, it just lets non-readers see name-groups. (Mira, iter-40)
func _name_kin(pid: String) -> Array:
	var out: Array = []
	if not board.pieces.has(pid):
		return out
	var g: String = board.pieces[pid]["glyph"]
	for other in board.pieces:
		if other != pid and board.pieces[other]["glyph"] == g:
			out.append(other)
	return out


## Light up every piece that shares a name with anything currently selected.
func _refresh_name_kin() -> void:
	var selected_glyphs := {}
	for pid in _selected:
		if board.pieces.has(pid):
			selected_glyphs[board.pieces[pid]["glyph"]] = true
	for pid in _piece_widgets:
		var b: Button = _piece_widgets[pid]
		if not is_instance_valid(b):
			continue
		var kin: bool = (not _selected.has(pid)) and selected_glyphs.has(board.pieces[pid]["glyph"])
		b.add_theme_stylebox_override("normal", _box_kin() if kin else _box_normal())
		b.add_theme_stylebox_override("hover", _box_kin_hover() if kin else _box_hover())


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
	AudioManager.play("split")   # a distinct "parting" note (split rides bundle's signal otherwise)
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
	AudioManager.play("copy")   # a light paper tick (copy has no distinct board signal)
	taught["copy"] = true
	_rebuild()
	_set_hint(G_COPIED)   # name the price: a copy drifts stale (誊本走味)


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
	_rebuild()
	_set_hint(G_SHARED)   # name the price: coupling bleeds rot every turn (共享渗坏)


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
	# graded non-colour cue: an ink "病灶" creeps in from the edges, deeper the nearer
	# collapse — organic (顾屿) yet still readable without colour OR motion, by how far the
	# stain has spread (3 discrete stages keep it a nameable severity for 周棠). (iter-45)
	_apply_stain(b, _severity_level())


## The world reacts to trouble: an unstable piece trembles and breathes — alive and
## in distress. The feedback IS the piece, not a label pinned on it; the "！" mark
## stays as a still, colour-blind-safe backup. (林晚, iter-09)
func _process(delta: float) -> void:
	_update_herald_viz(delta)
	# Stuck-safety net (阿May): no progress for a while → soften the guide to a TYPE hint.
	if board != null and not board.cleared:
		_idle_t += delta
		if _idle_t >= STUCK_SECS:
			var h := _stuck_hint_text()
			if h != "" and _guide.text != h:
				_guide.text = h
	# The "归位呼吸": when the land settles, the whole board takes one gentle breath in unison
	# — a felt "理顺了" beside the 磬 and the closing line. (顾屿, iter-51)
	if _settle_t >= 0.0:
		_settle_t += delta
		var sc := 1.0 if reduce_motion else _settle_transform(_settle_t)
		for pid in _piece_widgets:
			var pb: Button = _piece_widgets[pid]
			if is_instance_valid(pb):
				pb.pivot_offset = pb.size * 0.5
				pb.scale = Vector2(sc, sc)
		if _settle_t >= SETTLE_DUR:
			_settle_t = -1.0
	if _unstable_widgets.is_empty():
		return
	if reduce_motion:  # vestibular-safe: hold pieces still; the static ink stain carries severity
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


## A single gentle "settle breath" the pieces take in unison when the land is made whole —
## contract a touch at mid, then ease back to rest. Pure & testable; reduce_motion skips it.
func _settle_transform(t: float) -> float:
	var f := clampf(t / SETTLE_DUR, 0.0, 1.0)
	return 1.0 - sin(PI * f) * 0.06


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


## The two pieces flanking the first break in a chain ([before, after]), or [] if the
## 令 carries to the end. The break is the player's OWN wall, so marking it is a
## consequence cue ("your 界 blocks the 令 here, bridge it"), not a spoiler. (iter-35)
func _herald_break_pair(chain: Array) -> Array:
	for i in range(chain.size() - 1):
		var a: String = chain[i]
		var b: String = chain[i + 1]
		if not board.pieces.has(a) or not board.pieces.has(b):
			continue
		var ra: int = board.region_of(a)
		var rb: int = board.region_of(b)
		if ra != rb and not board.bridged(ra, rb):
			return [a, b]
	return []


func _herald_hide() -> void:
	if _herald_line != null:
		_herald_line.visible = false
	if _herald_dot != null:
		_herald_dot.visible = false
	if _herald_trail != null:
		_herald_trail.visible = false
	if _herald_break_mark != null:
		_herald_break_mark.visible = false


## Draw the chain as a thread, run a glowing (trailing) signal along the part it can
## reach, mark the break with a ✕. The new "ripple" feel + a where-to-bridge cue.
func _update_herald_viz(delta: float) -> void:
	if _herald_line == null:
		return
	if board == null or board.heralds.is_empty() or not is_inside_tree():
		_herald_hide()
		return
	var chain: Array = board.heralds[0]["chain"]
	var pts: Array = []
	for pid in chain:
		if _piece_widgets.has(pid) and is_instance_valid(_piece_widgets[pid]):
			var b: Button = _piece_widgets[pid]
			pts.append(b.global_position + b.size * 0.5)
	if pts.size() < 2:
		_herald_hide()
		return
	_herald_line.points = PackedVector2Array(pts)
	_herald_line.visible = true
	# mark the break with a ✕ between the two pieces the 令 can't cross (林晚: 看得见为什么停)
	var brk := _herald_break_pair(chain)
	if brk.size() == 2 and _piece_widgets.has(brk[0]) and _piece_widgets.has(brk[1]):
		var ba: Button = _piece_widgets[brk[0]]
		var bb: Button = _piece_widgets[brk[1]]
		var mid: Vector2 = (ba.global_position + ba.size * 0.5 + bb.global_position + bb.size * 0.5) * 0.5
		_herald_break_mark.global_position = mid - _herald_break_mark.size * 0.5
		_herald_break_mark.visible = true
	else:
		_herald_break_mark.visible = false
	if reduce_motion:
		_herald_dot.visible = false
		_herald_trail.visible = false
		return
	var reach: int = _herald_reach(chain)
	_herald_t += delta * 0.9
	var span: float = float(maxi(1, reach))
	var u: float = fmod(_herald_t, span)
	var idx: int = clampi(int(floor(u)), 0, pts.size() - 2)
	var p: Vector2 = (pts[idx] as Vector2).lerp(pts[idx + 1] as Vector2, u - float(idx))
	_herald_dot.global_position = p - _herald_dot.size * 0.5
	_herald_dot.visible = true
	_herald_trail_pts.append(p)  # comet trail (顾屿): a fading tail behind the signal
	while _herald_trail_pts.size() > 8:
		_herald_trail_pts.pop_front()
	_herald_trail.points = PackedVector2Array(_herald_trail_pts)
	_herald_trail.visible = _herald_trail_pts.size() >= 2


## Severity as a nameable, colour-free, motion-free reading: 1/2/3 by how near the land
## is to collapse. Rendered as a 3-stage ink stain (顾屿's "病灶" in place of !/!!/!!!), it
## stays readable by SPREAD alone — no colour, no motion needed. (周棠 iter-17 → 顾屿 iter-45)
func _severity_level() -> int:
	if board == null or board.blight_max <= 0:
		return 1
	var r := float(board.rot) / float(board.blight_max)
	if r >= 0.66:
		return 3
	elif r >= 0.33:
		return 2
	return 1


## A procedural ink stain that creeps in from the edges — clear centre so the name still
## reads, darker and wider the higher the severity. No asset files; ships on the web. (顾屿)
func _make_stain_tex(level: int) -> GradientTexture2D:
	var starts := {1: 0.82, 2: 0.60, 3: 0.36}   # where the ink begins creeping inward
	var alphas := {1: 0.5, 2: 0.66, 3: 0.82}     # how dark it gets at the rim
	var start: float = starts.get(level, 0.6)
	var a: float = alphas.get(level, 0.66)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, start, 1.0])
	g.colors = PackedColorArray([
		Color(0.10, 0.05, 0.05, 0.0),
		Color(0.10, 0.05, 0.05, 0.0),
		Color(0.10, 0.05, 0.05, a),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.04, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


## Lay (or deepen) the stain over a piece. Clear centre keeps the glyph legible; the
## overlay ignores the mouse so it never eats a click.
func _apply_stain(b: Button, level: int) -> void:
	var old := b.get_node_or_null("Stain")
	if old != null:
		old.free()
	var stain := TextureRect.new()
	stain.name = "Stain"
	stain.texture = _make_stain_tex(level)
	stain.set_anchors_preset(Control.PRESET_FULL_RECT)
	stain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stain.stretch_mode = TextureRect.STRETCH_SCALE
	b.add_child(stain)


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


## After a stretch with no progress (_process tracks _idle_t), the de-hand-hold guide
## softens to a TYPE hint for the first trouble — it names the trouble and the fix verb,
## but STILL never which pieces. The "find which" challenge stays the player's. (阿May)
func _stuck_hint_text() -> String:
	if board == null or board.cleared:
		return ""
	var insts := board.instabilities()
	if insts.is_empty():
		return ""
	match insts[0]["type"]:
		"name_overload":
			return G_HINT_WALL
		"unguarded_cluster":
			return G_HINT_BUNDLE
		"bloated_bundle":
			return G_HINT_SPLIT
		"clash":
			return G_HINT_TRANSLATOR
		"severed_chain":
			return G_HINT_HERALD
		"shortage":
			return G_HINT_SHORTAGE
		"exposed":
			return G_HINT_EXPOSED
	return ""


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
	_settle_t = 0.0       # the whole board takes one gentle "settle breath" (顾屿, iter-51)
	var s := board.stars()
	GameState.record_stars(board.territory_id, s)  # best is remembered; revealed only here, never hinted
	_overlay_mode = "clear"
	_overlay_label.text = "%s\n秩序重临 · %s" % ["★".repeat(s), STAR_NAMES.get(s, "净化此地")]
	_overlay_label.modulate = Color("9fe0a0")
	# A closing micro-line: the small "咯噔" of order returning, and a wordless replay of
	# what the move was for. (苏窈 + 马教练, iter-41) Generated trials fall back to a generic line.
	_overlay_subtext.text = board.territory_clear_line if board.territory_clear_line != "" else "这一片,归位了。"
	_overlay_subtext.visible = true
	_overlay_btn.text = "继续 →"
	_overlay_btn.visible = true
	_overlay.visible = true


func _on_failed() -> void:
	_pang(0.5)  # the wince — warmth drains as the land founders
	_overlay_mode = "fail"
	_overlay_label.text = "土地塌陷"
	_overlay_label.modulate = Color("e08a8a")
	_overlay_subtext.visible = false   # no closing line on collapse
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


func _box_normal() -> StyleBoxFlat:
	return _piece_box(Color("33291a"), Color("1b1308"), 2)


func _box_hover() -> StyleBoxFlat:
	return _piece_box(Color("40331f"), Color("2a1e0e"), 2)


## Name-kin highlight: a piece sharing the SELECTED one's name lights with a thicker,
## cool-edged ring (border *thickness* 2→3 carries it for colour-blind play; the cool
## hue distinguishes it from the warm gold selection ring). So a player who can't read
## the 字 still SEES which pieces share a name — without being told which to act on. (Mira, iter-40)
func _box_kin() -> StyleBoxFlat:
	return _piece_box(Color("2a2f3a"), Color("7f9ad6"), 3)


func _box_kin_hover() -> StyleBoxFlat:
	return _piece_box(Color("333a48"), Color("9db4ea"), 3)


## The SELECTED piece wears the strongest frame: the THICKEST border (4) AND the lightest
## fill. It's told apart from the name-kin ring by border *width* (4 vs 3) and fill *value*
## (brighter), not by hue — so a colour-blind player never confuses "selected" with "kin"
## even when the warm/cool tints are invisible. (周棠, iter-46)
func _box_selected() -> StyleBoxFlat:
	return _piece_box(Color("5a4830"), Color("f0d89a"), 4)


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

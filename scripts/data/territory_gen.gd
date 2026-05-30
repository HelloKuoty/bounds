class_name TerritoryGen
## Procedurally builds a SOLVABLE territory from a seed: a few name-clashes (same
## glyph, two meanings) and sometimes a scattered kin-cluster (one shared essence,
## different names) — surface (glyph / label / essence) drawn from in-world pools.
##
## Solvable BY CONSTRUCTION: every clash is fixed by one 画界, the cluster by one
## 成束; care budget = troubles + 1. A test re-solves many seeds with the generic
## greedy solver as a guarantee, and scans them for jargon. (iter-28)
##
## Same seed → same board (so a retry is fair); a run mixes in its own seed so each
## run's trial differs. No Date/random at module load — randomness is seed-driven.

const GLYPHS := [
	"账", "钱", "契", "印", "钟", "灯", "火", "册", "页", "银",
	"市", "井", "邻", "簿", "笔", "卷", "档", "谷", "布", "器",
]
const DIRS := ["东", "西", "南", "北", "左", "右", "前", "后"]
## 心法 — a HORIZONTAL build choice (not a difficulty slider): each shapes a
## different KIND of trial, all solvable by construction. (K哥, iter-34)
const MINDS := ["broad", "precise", "adaptive"]


static func make(seed: int, mind := "broad") -> TerritoryData:
	return TerritoryData.from_dict(make_dict(seed, mind))


## A territories.json-shaped dict. Glyphs are drawn distinct across the board, so
## the ONLY same-glyph repeats are the intended clash pairs — no stray instability.
static func make_dict(seed: int, mind := "broad") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var glyphs := GLYPHS.duplicate()
	_shuffle(glyphs, rng)
	var gi := 0
	var pieces: Array = []
	var clusters: Array = []
	var heralds: Array = []

	var pairs := 2
	var cluster := false
	var care_bonus := 1
	var herald := false
	match mind:
		"broad":     # 博观:局面大、心力宽 —— 看得多,但管够
			pairs = 3; cluster = true; care_bonus = 2
		"precise":   # 持重:局面小、心力紧 —— 零容错,一步错就清不掉
			pairs = 2; cluster = false; care_bonus = 0
		"adaptive":  # 通变:少几处名争,但多一道「令」要接通(传令链入随机)
			pairs = 1; cluster = false; care_bonus = 1; herald = true
		_:
			pairs = 2; cluster = true; care_bonus = 1

	for p in range(pairs):
		var gl: String = glyphs[gi]
		gi += 1
		var dirs := DIRS.duplicate()
		_shuffle(dirs, rng)
		pieces.append({"id": "p%d_a" % p, "label": "%s边的%s" % [dirs[0], gl], "glyph": gl, "meaning": "clash%d_a" % p, "kind": "living"})
		pieces.append({"id": "p%d_b" % p, "label": "%s边的%s" % [dirs[1], gl], "glyph": gl, "meaning": "clash%d_b" % p, "kind": "living"})
	var troubles := pairs

	if cluster:  # a scattered kin-cluster: one essence, different names → must bundle
		var members: Array = []
		for m in range(2):
			var gl2: String = glyphs[gi]
			gi += 1
			members.append("c%d" % m)
			pieces.append({"id": "c%d" % m, "label": "%s边的%s" % [DIRS[rng.randi() % DIRS.size()], gl2], "glyph": gl2, "meaning": "one_kin", "kind": "living"})
		clusters.append({"id": "kin", "label": "本是一体", "members": members})
		troubles += 1

	if herald:  # a relay whose two bell-ends share a name — splitting the clash severs
		var hg: String = glyphs[gi]  # the clashing glyph at both ends
		gi += 1
		var cg: String = glyphs[gi]  # the courier's own glyph
		gi += 1
		pieces.append({"id": "h0", "label": "起令的%s" % hg, "glyph": hg, "meaning": "decree_start", "kind": "living"})
		pieces.append({"id": "hc", "label": "传令的%s" % cg, "glyph": cg, "meaning": "decree_relay", "kind": "living"})
		pieces.append({"id": "h1", "label": "应令的%s" % hg, "glyph": hg, "meaning": "decree_end", "kind": "living"})
		heralds.append({"id": "decree", "label": "这道令", "chain": ["h0", "hc", "h1"]})
		troubles += 1  # the h0/h1 name-clash

	return {
		"id": "trial",
		"name": "试炼之地",
		"intro": "此地由命数布成,名实交错。看清形色,各归其位。",
		"concord_target": troubles,
		"blight_max": 30,
		"insight": troubles + care_bonus,
		"pieces": pieces,
		"clusters": clusters,
		"heralds": heralds,
	}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

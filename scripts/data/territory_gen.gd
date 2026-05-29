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


static func make(seed: int, depth: int = 2) -> TerritoryData:
	return TerritoryData.from_dict(make_dict(seed, depth))


## A territories.json-shaped dict. Glyphs are drawn distinct across the board, so
## the ONLY same-glyph repeats are the intended clash pairs — no stray instability.
static func make_dict(seed: int, depth: int = 2) -> Dictionary:
	depth = clampi(depth, 1, 3)  # 心法:浅 / 中 / 深
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var glyphs := GLYPHS.duplicate()
	_shuffle(glyphs, rng)
	var gi := 0
	var pieces: Array = []
	var clusters: Array = []

	var pairs := depth  # 浅/中/深 → 1/2/3 name-clashes
	for p in range(pairs):
		var gl: String = glyphs[gi]
		gi += 1
		var dirs := DIRS.duplicate()
		_shuffle(dirs, rng)
		pieces.append({"id": "p%d_a" % p, "label": "%s边的%s" % [dirs[0], gl], "glyph": gl, "meaning": "clash%d_a" % p, "kind": "living"})
		pieces.append({"id": "p%d_b" % p, "label": "%s边的%s" % [dirs[1], gl], "glyph": gl, "meaning": "clash%d_b" % p, "kind": "living"})

	var troubles := pairs
	if depth >= 2:  # 中 / 深 add a scattered kin-cluster
		var k := depth  # 2–3 kin
		var members: Array = []
		for m in range(k):
			var gl2: String = glyphs[gi]
			gi += 1
			members.append("c%d" % m)
			# one shared essence (same badge), different names → "异名同心", must bundle
			pieces.append({"id": "c%d" % m, "label": "%s边的%s" % [DIRS[rng.randi() % DIRS.size()], gl2], "glyph": gl2, "meaning": "one_kin", "kind": "living"})
		clusters.append({"id": "kin", "label": "本是一体", "members": members})
		troubles += 1

	return {
		"id": "trial",
		"name": "试炼之地",
		"intro": "此地由命数布成,名实交错。看清形色,各归其位。",
		"concord_target": troubles,
		"blight_max": 30,
		"insight": troubles + 1,
		"pieces": pieces,
		"clusters": clusters,
	}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

extends Node
## Loads all territory definitions from data/territories.json at startup.
## Validation is strict: a malformed file crashes loudly rather than loading
## half the territories (the JSON ids are a contract).

const DATA_PATH := "res://data/territories.json"

var _by_id: Dictionary = {}  # id -> TerritoryData


func _ready() -> void:
	_load()


func _load() -> void:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	assert(f != null, "Cannot open %s" % DATA_PATH)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	assert(typeof(parsed) == TYPE_DICTIONARY, "territories.json must be an object")
	var arr: Array = parsed.get("territories", [])
	assert(arr.size() > 0, "territories.json has no territories")
	for raw in arr:
		var t := TerritoryData.from_dict(raw)
		assert(t.id != "", "territory missing id")
		assert(not _by_id.has(t.id), "duplicate territory id: %s" % t.id)
		for p in t.pieces:
			assert(p.is_valid(), "invalid piece '%s' in territory '%s'" % [p.id, t.id])
		_by_id[t.id] = t
	print("[TerritoryDatabase] loaded %d territories" % _by_id.size())


func get_territory(id: String) -> TerritoryData:
	assert(_by_id.has(id), "unknown territory: %s" % id)
	return _by_id[id]


func has_territory(id: String) -> bool:
	return _by_id.has(id)


func all_ids() -> Array:
	return _by_id.keys()

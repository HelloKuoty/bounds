extends Node
## Run-scope state: where the steward is in the province and how blighted it has
## become. Persists across nodes within a run; cleared on victory/defeat.

const SAVE_PATH := "user://save.dat"
const PROVINCE_BLIGHT_CAP := 30  # too much accumulated rot ends the run

var province_id: String = "province_1"
var current_node_id: String = ""
var province_blight: int = 0
var taught: Dictionary = {}  # verb -> true; drives the fading in-game guidance
var best_stars: Dictionary = {}  # territory_id -> best stars (meta; persists across runs)
var run_seed: int = 0  # mixes into seeded territories so each run's trial differs


func start_new_run() -> void:
	province_id = "province_1"
	current_node_id = ""
	province_blight = 0
	run_seed = randi()
	taught.clear()
	RunManager.generate_map(province_id)
	EventBus.run_started.emit()


func enter_node(node_id: String) -> void:
	current_node_id = node_id
	RunManager.visited[node_id] = true
	EventBus.node_entered.emit(node_id, RunManager.node(node_id)["type"])
	save()  # auto-save on every node entry


func add_province_blight(amount: int) -> void:
	province_blight += amount


## Keep the best (highest) star rating ever earned on a territory — a replay hook.
func record_stars(territory_id: String, n: int) -> void:
	if n > int(best_stars.get(territory_id, 0)):
		best_stars[territory_id] = n


func run_lost() -> bool:
	return province_blight >= PROVINCE_BLIGHT_CAP


# --- Save / load ------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save() -> void:
	var data := {
		"province_id": province_id,
		"current_node_id": current_node_id,
		"province_blight": province_blight,
		"visited": RunManager.visited.keys(),
		"taught": taught.keys(),
		"best_stars": best_stars,
		"run_seed": run_seed,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Failed to open save file for write")
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_save() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	province_id = parsed.get("province_id", "province_1")
	current_node_id = parsed.get("current_node_id", "")
	province_blight = int(parsed.get("province_blight", 0))
	run_seed = int(parsed.get("run_seed", 0))
	RunManager.generate_map(province_id)
	for vid in parsed.get("visited", []):
		RunManager.visited[str(vid)] = true
	taught.clear()
	for verb in parsed.get("taught", []):
		taught[str(verb)] = true
	best_stars.clear()
	var bs = parsed.get("best_stars", {})
	if typeof(bs) == TYPE_DICTIONARY:
		for k in bs:
			best_stars[str(k)] = int(bs[k])
	return true


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

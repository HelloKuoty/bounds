extends SceneTree
## Full-run smoke: start a province, walk a path to the heartland, and solve
## every territory along the way with a generic solver. The solver doubles as a
## guarantee that each authored territory actually has a solution.
##   godot --headless --script res://tests/smoke_full_run.gd --path .
##
## NOTE: a top-level --script can't see autoload *global identifiers* at compile
## time, so we fetch the singletons via the tree root at runtime. (Global
## class_names like BoardState are fine.)

func _init() -> void:
	await process_frame
	var ok := _run()
	print("\n=== FULL RUN SMOKE ===")
	if ok:
		print("OK — reached and cleared the heartland")
		quit(0)
	else:
		print("FAILED")
		quit(1)


func _run() -> bool:
	var gs = root.get_node("GameState")
	var rm = root.get_node("RunManager")
	var tdb = root.get_node("TerritoryDatabase")
	gs.start_new_run()
	var current := ""
	var solved := 0
	var steps := 0
	while steps < 64:
		steps += 1
		var options: Array = rm.reachable_from(current)
		if options.is_empty():
			break
		var nxt: String = options[0]
		var node: Dictionary = rm.node(nxt)
		gs.enter_node(nxt)
		current = nxt
		if node["territory_id"] != "":
			var t := tdb.get_territory(node["territory_id"]) as TerritoryData
			var board := BoardState.new()
			board.load_territory(t)
			if not _auto_solve(board):
				print("  could not solve %s at node %s" % [node["territory_id"], nxt])
				return false
			solved += 1
			print("  cleared %s (%s)" % [node["territory_id"], node["type"]])
		if rm.is_terminal(current):
			break
	var at_boss: bool = current == rm.boss_id
	print("  solved %d territories; ended at %s (boss=%s)" % [solved, current, rm.boss_id])
	return at_boss and solved >= 1


## Generic solver: repeatedly take the first instability and apply the matching
## verb until the territory clears. Proves the puzzle is solvable.
func _auto_solve(board: BoardState) -> bool:
	for _i in range(60):
		if board.cleared:
			return true
		var insts: Array = board.instabilities()
		if insts.is_empty():
			return board.cleared
		var inst: Dictionary = insts[0]
		match inst["type"]:
			"name_overload":
				var keep = inst["meanings"][0]
				var move_ids: Array = []
				for pid in board.pieces:
					var p: Dictionary = board.pieces[pid]
					if p["region"] == inst["region"] and p["glyph"] == inst["glyph"] and p["meaning"] != keep:
						move_ids.append(pid)
				if move_ids.is_empty():
					return false
				board.draw_wall(move_ids)
			"unguarded_cluster":
				var members := _cluster_members(board, inst["cluster"])
				if members.is_empty():
					return false
				board.bundle(members, members[0])
			"clash":
				var lk := _link(board, inst["link"])
				if lk.is_empty():
					return false
				board.place_translator(board.region_of(lk["a"]), board.region_of(lk["b"]))
			"bloated_bundle":
				var bid: int = inst["bundle"]
				var members: Array = board.bundles[bid]["members"]
				var guardian: String = board.bundles[bid]["guardian"]
				var excess: int = members.size() - BoardState.MAX_BUNDLE
				var to_move: Array = []
				for m in members:
					if m == guardian:
						continue
					if to_move.size() >= excess:
						break
					to_move.append(m)
				if to_move.is_empty():
					return false
				board.split_bundle(bid, to_move)
			"shortage":
				var d := _demand(board, inst["demand"])
				if d.is_empty():
					return false
				var r: int = board.region_of(d["anchor"])
				var src := ""
				for pid in board.pieces:
					var p: Dictionary = board.pieces[pid]
					if p["kind"] == "token" and p["glyph"] == d["glyph"] and p["meaning"] == d["meaning"] and not p.get("stale", false):
						src = pid
						break
				if src != "":
					board.copy_token(src, r)  # tokens: just copy
				else:
					# the need is for a living thing — can't copy; share it (at a cost)
					var living := ""
					for pid in board.pieces:
						var p2: Dictionary = board.pieces[pid]
						if p2["glyph"] == d["glyph"] and p2["meaning"] == d["meaning"]:
							living = pid
							break
					if living == "":
						return false
					board.share(living, r)
			"exposed":
				# wall every still-clean piece into one fresh region, away from the rot
				var clean: Array = []
				for pid in board.pieces:
					if not board.pieces[pid].get("corrupted", false):
						clean.append(pid)
				if clean.is_empty():
					return false
				board.draw_wall(clean)
			_:
				return false
	return board.cleared


func _cluster_members(board: BoardState, cid: String) -> Array:
	for c in board.clusters:
		if c["id"] == cid:
			return c["members"]
	return []


func _link(board: BoardState, lid: String) -> Dictionary:
	for l in board.links:
		if l["id"] == lid:
			return l
	return {}


func _demand(board: BoardState, did: String) -> Dictionary:
	for d in board.demands:
		if d["id"] == did:
			return d
	return {}

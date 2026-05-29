extends TestHelpers
## The de-hand-holding red lines (Roguelike-lite, iter-25/26): the guide no longer
## hands you the answer, care (心力) is tight, and naive / undiagnosed play must LOSE.
## If these pass while the guide still pointed at pieces, the puzzle never moved out
## of the tutorial — so these are the spine that keeps "傻瓜" from creeping back.


func test_naive_wrong_verb_loses_on_a_tight_level() -> void:
	# 阿May red-line: on tight 名障镇, the obvious-wrong instinct ("two 钟, same name →
	# bundle them") wastes care and dooms the run. You must DIAGNOSE (same name but
	# different essence → WALL), not pattern-match the name.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("two_names"))
	board.bundle(["gong", "goblet"], "gong")  # naive: same name → bundle (resolves nothing)
	board.draw_wall(["goblet"])               # then try the real fix…
	board.bundle(["lamp", "fire"], "lamp")    # …but care has run out
	assert_false(board.cleared, "a wasted, undiagnosed move on a tight level loses")


func test_diagnosis_clears_the_same_tight_level() -> void:
	# The diagnosed line (wall the same-name clash, unite the hidden kin) fits exactly.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("two_names"))
	board.draw_wall(["goblet"])
	board.bundle(["lamp", "fire"], "lamp")
	assert_true(board.cleared, "correct diagnosis fits the tight care budget")


func test_boss_decoy_tempts_but_is_no_real_problem() -> void:
	# A same-name / same-essence decoy (two 酒) reads identical by badge — a player who
	# diagnoses (not pattern-matches the name) does NOT waste care walling it apart.
	var board := BoardState.new()
	board.load_territory(TerritoryDatabase.get_territory("the_sprawl"))
	assert_eq(board.pieces["s_jar_a"]["meaning"], board.pieces["s_jar_b"]["meaning"], "the decoy pair is truly one essence")
	assert_eq(board.instabilities().size(), 3, "the boss still has exactly its three real troubles; the decoy is a temptation, not a problem")

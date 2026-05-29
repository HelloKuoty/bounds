extends TestHelpers
## The narrative content exists and is wired for the bookends. (Jargon is checked
## by test_no_jargon, which scans Narrative.all_strings().)

func test_premise_and_ending_present() -> void:
	assert_true(Narrative.PREMISE.length() > 20, "an opening premise exists")
	assert_true(Narrative.ENDING.length() > 20, "a closing reflection exists")


func test_four_chapters_and_some_narration() -> void:
	assert_eq(Narrative.CHAPTERS.size(), 4, "four chapter framings")
	assert_true(Narrative.NARRATION.size() >= 6, "a pool of atmospheric lines")


func test_all_strings_collects_everything() -> void:
	# hook + premise + ending + (4 chapters * 2) + narration
	var expected := 3 + Narrative.CHAPTERS.size() * 2 + Narrative.NARRATION.size()
	assert_eq(Narrative.all_strings().size(), expected, "all_strings gathers every line")

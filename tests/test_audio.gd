extends TestHelpers
## The ambient bed: a quiet, seamlessly-looping atmosphere (no dead silence),
## synthesised at runtime — no asset files, silent-safe in headless. (顾屿, iter-10)


func test_drone_is_a_seamless_loop() -> void:
	var w := AudioManager._drone(1.0)
	assert_true(w is AudioStreamWAV, "the ambient bed is an audio stream")
	assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, "it loops — no gap of dead silence")
	assert_true(w.data.size() > 0, "the bed actually has audio data")


func test_ambience_is_silent_safe_in_headless() -> void:
	# Headless has no audio device; starting ambience must be a no-op, never a leak.
	AudioManager.start_ambience()
	assert_true(AudioManager._silent, "headless is detected as silent")
	assert_false(AudioManager._bed.playing, "no playback is started in headless")


func test_teardown_stops_the_bed() -> void:
	# Regression (iter-23, caught in a real windowed run): a still-looping ambient
	# bed leaks its playback at exit; teardown must stop it.
	AudioManager._exit_tree()
	assert_false(AudioManager._bed.playing, "the bed is not left playing at teardown")


# --- iter-49: one-shot SFX for every key event (procedural, no asset files) -----

const EVENTS := ["wall", "bundle", "split", "translator", "copy", "share", "clear", "fail", "error"]


func test_every_event_has_a_synthesised_sfx_with_data() -> void:
	for name in EVENTS:
		assert_true(AudioManager._sfx.has(name), "sfx '%s' exists" % name)
		var w: AudioStreamWAV = AudioManager._sfx[name]
		assert_true(w != null, "sfx '%s' is a real stream" % name)
		assert_true(w.data.size() > 0, "sfx '%s' carries audio data" % name)


func test_split_copy_share_have_their_own_voice() -> void:
	# iter-49 (顾屿): split must not just reuse bundle's blip; 誊本/共享 must not be silent.
	assert_true(AudioManager._sfx["split"].data != AudioManager._sfx["bundle"].data, "split has its own voice, not bundle's")
	assert_true(AudioManager._sfx["copy"].data.size() > 0, "誊本 is not silent")
	assert_true(AudioManager._sfx["share"].data.size() > 0, "共享 is not silent")


func test_play_is_silent_safe_for_every_event_and_unknowns() -> void:
	for name in EVENTS:
		AudioManager.play(name)          # must never crash (headless no-ops)
	AudioManager.play("does_not_exist")  # an unknown name must be safe too
	assert_true(true, "play() never crashes, known or unknown")

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

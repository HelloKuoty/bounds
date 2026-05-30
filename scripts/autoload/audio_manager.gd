extends Node
## Tiny placeholder SFX, synthesised at runtime (no asset files, works in the web
## build, silent-safe in headless). A controller calls play(name) on key events.
## Real audio is a later polish; this just removes the "dead silent" hole.

const SR := 22050

var _sfx: Dictionary = {}  # name -> AudioStreamWAV
var _player: AudioStreamPlayer
var _bed: AudioStreamPlayer  # the looping ambient bed
var _silent := false


func _ready() -> void:
	_silent = DisplayServer.get_name() == "headless"  # no audio device — don't play (avoids leaked playback)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_sfx["wall"] = _tone([880.0], 0.07)            # crisp tick — a line drawn
	_sfx["bundle"] = _tone([294.0], 0.12)          # low thunk — gathered
	_sfx["split"] = _tone([392.0, 311.0], 0.09)    # two notes parting — split apart
	_sfx["translator"] = _tone([587.0, 784.0], 0.10)  # two-note — a bridge
	_sfx["copy"] = _tone([784.0], 0.045)           # light paper tick — a copy taken
	_sfx["share"] = _tone([440.0, 660.0], 0.16)    # a held fifth — the one thing, used by two
	# A struck 磬 that rings out — the "settled / returned to place" payoff, not a chord blip. (顾屿, iter-49)
	_sfx["clear"] = _bell([528.0, 792.0, 1408.0], 0.85)
	_sfx["fail"] = _tone([196.0, 147.0], 0.30)     # low fall — collapse
	_sfx["error"] = _tone([140.0], 0.10)           # short buzz — refused
	# A quiet, seamlessly-looping ambient bed — atmosphere beyond one-shot blips.
	# (顾屿: "不死寂 ≠ 有氛围, 缺持续环境声床", iter-10)
	_bed = AudioStreamPlayer.new()
	_bed.stream = _drone(4.0)
	_bed.volume_db = -7.0
	add_child(_bed)
	start_ambience()


func play(name: String) -> void:
	if _silent or not _sfx.has(name):
		return
	# one reusable player — no per-call nodes to leak (placeholder SFX may interrupt)
	_player.stream = _sfx[name]
	_player.play()


## Begin the ambient bed (loops until stopped). Silent-safe in headless.
func start_ambience() -> void:
	if _silent or _bed == null or _bed.playing:
		return
	_bed.play()


func stop_ambience() -> void:
	if _bed != null and _bed.playing:
		_bed.stop()


## Stop the looping bed before teardown — a still-playing loop leaks its playback
## (AudioStreamPlaybackWAV) at exit. Headless never plays it; only real runs hit this.
func _exit_tree() -> void:
	# Stop the looping bed on teardown (correct hygiene; covers a normal window-close).
	# Note: an abrupt quit may still print a benign "AudioStreamPlayback leaked at exit"
	# — the audio server releases playback async with no frame left to flush; it has no
	# runtime impact (the OS reclaims memory on exit) and the player never sees it.
	if is_instance_valid(_bed):
		_bed.stop()
		_bed.stream = null


## Synthesise a short decaying tone (sum of sines), 16-bit mono.
func _tone(freqs: Array, dur: float) -> AudioStreamWAV:
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / SR
		var env := 1.0 - float(i) / float(n)  # linear decay to silence
		var s := 0.0
		for f in freqs:
			s += sin(TAU * f * t)
		s = (s / freqs.size()) * env * 0.5
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	return w


## Synthesise a struck-bell / 磬 tone: a soft attack, then a long exponential resonance
## with upper partials — a "settled, returned to place" ring rather than a flat blip. (顾屿)
func _bell(freqs: Array, dur: float) -> AudioStreamWAV:
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var amps := [1.0, 0.5, 0.28, 0.16]
	for i in range(n):
		var t := float(i) / SR
		var frac := float(i) / float(n)
		var env := exp(-frac * 5.0)                 # exponential decay — struck, then rings out
		var attack := clampf(t / 0.006, 0.0, 1.0)   # ~6ms soft attack — struck, not clicked
		var s := 0.0
		for j in freqs.size():
			var a: float = amps[j] if j < amps.size() else 0.12
			s += a * sin(TAU * freqs[j] * t)
		s = (s / 2.0) * env * attack * 0.5
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	return w


## A low, warm, seamlessly-looping drone. Every partial completes a whole number
## of cycles over `dur` (and the tremolo too), so the loop has no click or gap.
func _drone(dur: float) -> AudioStreamWAV:
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var partials := [55.0, 110.0, 165.0, 220.0]  # stacked octaves + fifth — warm, consonant
	var amps := [1.0, 0.6, 0.35, 0.2]
	for i in range(n):
		var t := float(i) / SR
		var lfo := 0.85 + 0.15 * sin(TAU * 0.25 * t)  # slow breath, 1 cycle over 4s
		var s := 0.0
		for j in partials.size():
			s += amps[j] * sin(TAU * partials[j] * t)
		s = (s / 2.15) * lfo * 0.22  # normalised, kept quiet — it's a bed, not a melody
		data.encode_s16(i * 2, int(clamp(s, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	w.data = data
	return w

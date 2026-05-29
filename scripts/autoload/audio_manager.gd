extends Node
## Tiny placeholder SFX, synthesised at runtime (no asset files, works in the web
## build, silent-safe in headless). A controller calls play(name) on key events.
## Real audio is a later polish; this just removes the "dead silent" hole.

const SR := 22050

var _sfx: Dictionary = {}  # name -> AudioStreamWAV
var _player: AudioStreamPlayer
var _silent := false


func _ready() -> void:
	_silent = DisplayServer.get_name() == "headless"  # no audio device — don't play (avoids leaked playback)
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_sfx["wall"] = _tone([880.0], 0.07)            # crisp tick — a line drawn
	_sfx["bundle"] = _tone([294.0], 0.12)          # low thunk — gathered
	_sfx["translator"] = _tone([587.0, 784.0], 0.10)  # two-note — a bridge
	_sfx["clear"] = _tone([523.0, 659.0, 784.0], 0.42)  # rising chord — order
	_sfx["fail"] = _tone([196.0, 147.0], 0.30)     # low fall — collapse
	_sfx["error"] = _tone([140.0], 0.10)           # short buzz — refused


func play(name: String) -> void:
	if _silent or not _sfx.has(name):
		return
	# one reusable player — no per-call nodes to leak (placeholder SFX may interrupt)
	_player.stream = _sfx[name]
	_player.play()


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

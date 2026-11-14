extends Node
var ambient: AudioStreamPlayer
var cue: AudioStreamPlayer
var cache: Dictionary = {}
var zone = "town"
func _ready():
	ambient = AudioStreamPlayer.new()
	cue = AudioStreamPlayer.new()
	add_child(ambient)
	add_child(cue)
func wave(echo: bool, effect: bool = false) -> AudioStreamWAV:
	var key=zone+str(echo)+str(effect)
	if cache.has(key): return cache[key]
	var rate = 16000
	var length = 0.12 if effect else 4.0
	var data = PackedByteArray()
	data.resize(int(length * rate) * 2)
	for i in range(int(length * rate)):
		var t = float(i) / rate
		var base={"town":110.0,"library":82.0,"forest":66.0}.get(zone,110.0)
		var f = 220.0 if effect else base*(0.667 if echo else 1.0)
		var value = sin(TAU*f*t)*0.14 + sin(TAU*f*1.5*t)*0.045 + sin(TAU*f*2.003*t)*0.025
		value *= pow(maxf(0, 1.0-t/length), 2) if effect else pow(sin(PI*t/length),2)
		data.encode_s16(i*2, int(value*15000))
	var result = AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = rate
	result.data = data
	if not effect:
		result.loop_mode = AudioStreamWAV.LOOP_FORWARD
		result.loop_begin = 0
		result.loop_end = data.size()/2
	cache[key]=result
	return result
func set_scene(echo: bool, volume: float, location: String="town"):
	ambient.stop()
	ambient.stream=null
	zone=location
	ambient.stream = wave(echo)
	ambient.volume_db = linear_to_db(maxf(volume*0.28,0.0001))
	ambient.play()
func ping(volume: float):
	cue.stop()
	cue.stream=null
	cue.stream = wave(false,true)
	cue.volume_db = linear_to_db(maxf(volume*0.3,0.0001))
	cue.play()
func shutdown():
	ambient.stop()
	cue.stop()
	ambient.stream=null
	cue.stream=null
	cache.clear()
func _exit_tree():
	shutdown()

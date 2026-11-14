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
		var f = 660.0 if effect else base*(0.667 if echo else 1.0)
		var value = sin(TAU*f*t)*0.07 + sin(TAU*f*2*t)*0.012
		value *= minf(1.0,t/.012)
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
	# Exploration and menus are quiet; only short interaction cues play.
func ping(volume: float):
	cue.stop()
	cue.stream=null
	cue.stream = wave(false,true)
	cue.volume_db = linear_to_db(maxf(volume*0.18,0.0001))
	cue.play()
func shutdown():
	ambient.stop()
	cue.stop()
	ambient.stream=null
	cue.stream=null
	cache.clear()
func scene_cue(kind: String, volume: float):
	# Short musical phrase; never loops and never plays on a menu.
	var tones=[261.63,329.63,392.0] if kind!="boss" else [196.0,233.08,293.66]
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=16000
	var samples=PackedByteArray()
	samples.resize(19200*2)
	for i in range(19200):
		var time=float(i)/16000
		var part=mini(2,int(time/.4))
		var local=fmod(time,.4)
		var envelope=sin(PI*local/.4)*exp(-local*5)
		samples.encode_s16(i*2,int(sin(TAU*tones[part]*time)*envelope*1800))
	stream.data=samples
	cue.stop();cue.stream=stream
	cue.volume_db=linear_to_db(maxf(volume*.24,.0001))
	cue.play()
func _exit_tree():
	shutdown()

extends Node

const RATE=16000
var music: AudioStreamPlayer
var music_level = .45
var duck_score = false
var effects_level = 1.0
var music_gain = 0.0
var music_key = ""
var score_cache: Dictionary = {}
var ambient: AudioStreamPlayer
var cue: AudioStreamPlayer
var world_voice: AudioStreamPlayer2D
var cache: Dictionary={}
var zone="town"
var echo_mode=false
var listening=false
var master_volume=.5
var ambient_gain=0.0
var ambient_key=""
var sequence=0

func _ready():
	music = AudioStreamPlayer.new()
	add_child(music)
	ambient=AudioStreamPlayer.new()
	cue=AudioStreamPlayer.new()
	world_voice=AudioStreamPlayer2D.new()
	world_voice.max_distance=720
	world_voice.attenuation=.65
	world_voice.max_polyphony=2
	add_child(ambient)
	add_child(cue)
	add_child(world_voice)

func set_scene(echo: bool,volume: float,location: String="town"):
	zone=location
	echo_mode=echo
	master_volume=clampf(volume,0.0,1.0)

func set_mix(music_volume: float, effects_volume: float):
	music_level = clampf(music_volume,0.0,1.0)
	effects_level = clampf(effects_volume,0.0,1.0)

func set_listening(active: bool):
	listening=active

func _process(dt: float):
	_update_score(dt)
	var wanted=zone+str(echo_mode) if listening and master_volume>0 and effects_level>0 else ""
	var target=master_volume*effects_level*.16 if ambient_key==wanted and not wanted.is_empty() else 0.0
	ambient_gain=move_toward(ambient_gain,target,dt*.23)
	ambient.volume_db=linear_to_db(maxf(ambient_gain,.0001))
	if target==0.0 and ambient_gain==0.0 and ambient_key!=wanted:
		ambient.stop()
		ambient.stream=null
		ambient_key=wanted
		if not wanted.is_empty():
			var family="surf" if zone in ["harbor","tide_station"] else "room" if zone.begins_with("home_") or zone in ["shop","library","closed_post","records_annex","signal_cellar","listening_archive","pump_chamber"] else "wind"
			ambient.stream=_sample(family,1 if echo_mode else 0)
			ambient.play()

func _update_score(dt: float):
	var family = "inside" if zone in ["library","records_annex","listening_archive","closed_post","signal_cellar","pump_chamber"] or zone.begins_with("home_") else "shore" if zone in ["harbor","tide_station","forest","bracken_clearing"] else "courtyard"
	var wanted = family if listening and master_volume > 0 and music_level > 0 else ""
	var target = master_volume * music_level * (.12 if duck_score else .32) if wanted == music_key and not wanted.is_empty() else 0.0
	music_gain = move_toward(music_gain,target,dt*.20)
	music.volume_db = linear_to_db(maxf(.0001,music_gain))
	if music_gain!=0.0 or wanted==music_key: return
	music.stop()
	music.stream = null
	music_key = wanted
	if wanted.is_empty(): return
	if not score_cache.has(wanted):
		var track: AudioStreamWAV = load("res://after_silence/assets/score090/"+wanted+".wav").duplicate()
		track.loop_mode = AudioStreamWAV.LOOP_FORWARD
		track.loop_end = int(track.get_length()*track.mix_rate)
		score_cache[wanted] = track
	music.stream = score_cache[wanted]
	music.play()

func ping(volume: float):
	_play_ui("click",volume*.20)

func trial_move(mode: String, accepted: bool, volume: float):
	const CUES = {
		"letter_press":"paper", "footprints":"paper", "balance":"ratchet", "signal_grid":"chime",
		"railway":"ratchet", "echo_tuning":"chime", "tubes":"drop", "pairs":"paper",
		"seeds":"drop", "lights":"chime", "shelves":"ratchet", "reality":"chime"
	}
	_play_ui(CUES.get(mode,"click") if accepted else "blocked", volume * .23)

func touch(at: Vector2,volume: float):
	_play_world("touch",at,volume*.18)

func footstep(at: Vector2,surface: String,running: bool,volume: float):
	_play_world(surface,at,volume*(.31 if running else .23))

func landing(at: Vector2,volume: float):
	_play_world("land",at,volume*.29)

func door(at: Vector2,volume: float):
	_play_world("door",at,volume*.24)

func scene_cue(kind: String,volume: float):
	_play_ui("danger" if kind=="boss" else "memory",volume*.24)

func case_signal(tones: Array,volume: float):
	volume *= effects_level
	if volume<=0 or tones.is_empty(): return
	var key="case_signal:"+str(tones)
	if not cache.has(key):
		var stream=AudioStreamWAV.new()
		stream.format=AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate=RATE
		var count=roundi(RATE*.32)
		var data=PackedByteArray()
		data.resize(count*tones.size()*2)
		for note in tones.size():
			for sample in count:
				var t=float(sample)/RATE
				var envelope=clampf(minf(t*75.0,(.23-t)*23.0),0.0,1.0)
				var value=sin(TAU*float(tones[note])*t)*envelope*.28
				data.encode_s16((note*count+sample)*2,roundi(value*32760))
		stream.data=data
		cache[key]=stream
	cue.stream=cache[key]
	cue.volume_db=linear_to_db(volume*.34)
	cue.play()

func _play_ui(kind: String,gain: float):
	gain *= effects_level
	if gain<=0: return
	cue.stream=_sample(kind,0)
	cue.volume_db=linear_to_db(gain)
	cue.play()

func _play_world(kind: String,at: Vector2,gain: float):
	gain *= effects_level
	if gain<=0: return
	sequence=(sequence+1)%3
	world_voice.position=at
	world_voice.stream=_sample(kind,sequence)
	world_voice.volume_db=linear_to_db(gain)
	world_voice.play()

func _sample(kind: String,variant: int) -> AudioStreamWAV:
	var key=kind+str(variant)
	if cache.has(key): return cache[key]
	var is_bed=kind in ["wind","surf","room"]
	var is_phrase=kind in ["memory","danger"]
	var length=4.8 if is_bed else 1.2 if is_phrase else .27 if kind=="door" else .15
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=RATE
	var count=int(length*RATE)
	var samples=PackedByteArray()
	samples.resize(count*2)
	var rng=RandomNumberGenerator.new()
	rng.seed=key.hash()
	var low=0.0
	var slow=0.0
	var pitch=1.0+variant*.077
	var tones=[196.0,233.08,293.66] if kind=="danger" else [261.63,329.63,392.0]
	for i in range(count):
		var time=float(i)/RATE
		var noise=rng.randf_range(-1.0,1.0)
		low=lerpf(low,noise,.16)
		slow=lerpf(slow,noise,.024)
		var value=0.0
		if is_bed:
			var wave=.65+.23*sin(TAU*time/length)
			value=(slow*.62+low*.10)*wave if kind=="surf" else slow*.49 if kind=="wind" else slow*.17
			value*=minf(1.0,minf(time,length-time)/.22)
		elif is_phrase:
			var local=fmod(time,.4)
			value=sin(TAU*tones[mini(2,int(time/.4))]*time)*sin(PI*local/.4)*exp(-local*5.0)*.22
		else:
			var envelope=minf(1.0,time/.006)*pow(1.0-time/length,2.6)
			match kind:
				"click": value=sin(TAU*528.0*time)*.23+sin(TAU*792.0*time)*.06
				"paper": value=noise * .12 + low * .46
				"ratchet": value=low * .31 + sin(TAU * 162.0 * time) * .28
				"chime": value=sin(TAU * 659.0 * time) * .20 + sin(TAU * 980.0 * time) * .08
				"drop": value=sin(TAU * (455.0 + time * 1150.0) * time) * .30
				"blocked": value=sin(TAU * (196.0 - time * 200.0) * time) * .17 + low * .15
				"touch": value=low*.32+sin(TAU*324.0*pitch*time)*.15
				"wood": value=low*.37+sin(TAU*118.0*pitch*time)*.31
				"stone": value=noise*.25+low*.45+sin(TAU*186.0*pitch*time)*.11
				"door": value=low*.34+sin(TAU*(93.0+time*64.0)*pitch*time)*.23
				"land": value=low*.69+sin(TAU*76.0*pitch*time)*.22
				_: value=low*.65+slow*.18
			value*=envelope
		samples.encode_s16(i*2,roundi(clampf(value,-1.0,1.0)*32760))
	stream.data=samples
	if is_bed:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin=0
		stream.loop_end=count
	cache[key]=stream
	return stream

func shutdown():
	if is_instance_valid(music): music.stop();music.stream=null
	music_gain=0.0
	music_key=""
	score_cache.clear()
	if is_instance_valid(ambient): ambient.stop();ambient.stream=null
	if is_instance_valid(cue): cue.stop();cue.stream=null
	if is_instance_valid(world_voice): world_voice.stop();world_voice.stream=null
	ambient_gain=0.0
	ambient_key=""
	listening=false
	cache.clear()

func _exit_tree():
	shutdown()

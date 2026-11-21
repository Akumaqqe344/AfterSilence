extends GutTest

const Audio=preload("res://after_silence/core/audio_manager.gd")
var mixer

func before_each():
	mixer=Audio.new()
	add_child_autofree(mixer)

func test_surface_variants_are_distinct_and_cached():
	var wood=mixer._sample("wood",0)
	var stone=mixer._sample("stone",0)
	assert_ne(wood.data,stone.data)
	assert_ne(wood.data,mixer._sample("wood",1).data)
	assert_same(wood,mixer._sample("wood",0))
	assert_eq(wood.data.decode_s16(0),0)
	assert_eq(wood.loop_mode,AudioStreamWAV.LOOP_DISABLED)

func test_ambient_loop_has_a_silent_seam():
	var surf=mixer._sample("surf",0)
	assert_eq(surf.loop_mode,AudioStreamWAV.LOOP_FORWARD)
	assert_eq(surf.loop_end,surf.data.size()/2)
	assert_eq(surf.data.decode_s16(0),0)
	assert_lt(absi(surf.data.decode_s16(surf.data.size()-2)),8)
	assert_ne(surf.data,mixer._sample("room",0).data)

func test_muted_steps_leave_world_voice_idle():
	mixer.footstep(Vector2(5,10),"earth",false,0.0)
	assert_null(mixer.world_voice.stream)
	assert_false(mixer.world_voice.playing)

func test_scene_audio_fades_up_and_stops_when_exploration_ends():
	mixer.set_scene(false,.5,"harbor")
	mixer.set_listening(true)
	mixer._process(.05)
	assert_true(mixer.ambient.playing)
	assert_eq(mixer.ambient_gain,0.0)
	mixer._process(.12)
	assert_gt(mixer.ambient_gain,0.0)
	mixer.set_listening(false)
	mixer._process(.5)
	assert_false(mixer.ambient.playing)
	assert_eq(mixer.ambient_gain,0.0)

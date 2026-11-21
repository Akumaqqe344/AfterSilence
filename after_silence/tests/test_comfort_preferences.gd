extends GutTest
const Preferences=preload("res://after_silence/ui/comfort_preferences.gd")
var preferences

func before_each():
	preferences=Preferences.new()
	preferences.path="user://qa_comfort_unit_"+str(Time.get_ticks_usec())+".cfg"

func after_each():
	if FileAccess.file_exists(preferences.path): DirAccess.remove_absolute(preferences.path)

func test_preferences_round_trip_without_story_save():
	preferences.large_text=true;preferences.reduce_motion=true;preferences.instant_text=true
	preferences.route_guide=false
	preferences.language="en";preferences.volume=.7;preferences.fullscreen=true
	assert_eq(preferences.save_preferences(),OK)
	var restored=Preferences.new();restored.path=preferences.path;restored.load_preferences()
	assert_true(restored.available)
	assert_true(restored.large_text)
	assert_true(restored.reduce_motion)
	assert_false(restored.route_guide)
	assert_true(restored.instant_text)
	assert_true(restored.fullscreen)
	assert_eq(restored.language,"en")
	assert_almost_eq(restored.volume,.7,.001)

func test_missing_file_keeps_defaults():
	preferences.load_preferences()
	assert_false(preferences.available)
	assert_false(preferences.large_text)
	assert_true(preferences.route_guide)
	assert_false(FileAccess.file_exists(preferences.path))

func test_invalid_values_use_safe_bounds():
	var config=ConfigFile.new()
	config.set_value("comfort","volume",5.0)
	config.set_value("comfort","language","unknown")
	config.set_value("comfort","large_text","false")
	assert_eq(config.save(preferences.path),OK)
	preferences.load_preferences()
	assert_eq(preferences.volume,1.0)
	assert_eq(preferences.language,"ru")
	assert_false(preferences.large_text)
	config.set_value("comfort","volume","invalid")
	assert_eq(config.save(preferences.path),OK)
	preferences.load_preferences()
	assert_eq(preferences.volume,.5)

func test_unknown_section_is_preserved_on_read():
	var file=FileAccess.open(preferences.path,FileAccess.WRITE)
	file.store_string("[unknown]\nvalue=1\n");file.close()
	preferences.load_preferences()
	assert_true(preferences.available)
	assert_false(preferences.large_text)
	assert_eq(FileAccess.get_file_as_string(preferences.path),"[unknown]\nvalue=1\n")

extends Node
var game
var talk: NPCTalkKit
func _ready():
	talk=NPCTalkKit.new()
	add_child(talk)
	var template=TalkBoxTemplate.new()
	template.font=game.ui.theme.default_font
	template.name_font=template.font
	template.text_size=12
	template.name_size=15
	template.text_min_size=Vector2(430,52)
	template.visual_size=Vector2(42,42)
	template.visual_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	template.continue_text="E"
	template.typewriter_speed=35
	var wood=StyleBoxTexture.new()
	wood.texture=load("res://after_silence/assets/art100/floor.png")
	wood.modulate_color=Color("554737")
	wood.texture_margin_left=6;wood.texture_margin_right=6
	wood.texture_margin_top=6;wood.texture_margin_bottom=6
	template.base.visual_source=TalkBoxLayer.Source.RESOURCE
	template.base.style=wood
	template.base.padding_mode=TalkBoxLayer.PaddingMode.CUSTOM
	template.base.padding=Vector4(14,12,14,12)
	talk.quick_say_dialogue_box=template
	var anchor=TalkAnchor.new()
	anchor.box_size=Vector2(550,120)
	talk.quick_say_placement=anchor
	var speaker=TalkSpeaker.new()
	speaker.display_name=game.t("Надя","Nadia")
	speaker.voice_enabled=false
	var visual=TalkDialogueVisual.new()
	var atlas=AtlasTexture.new()
	atlas.atlas=load("res://after_silence/assets/pechatai/npc/lora.png")
	var bounds=atlas.atlas.get_image().get_region(Rect2i(0,0,64,96)).get_used_rect()
	atlas.region=Rect2(bounds.position,Vector2(bounds.size.x,bounds.size.y*.52))
	visual.texture=atlas
	speaker.visual=visual
	talk.quick_say_speaker=speaker
	talk.request_player_lock.connect(func(locked):
		game.modal=locked
		if is_instance_valid(game.player): game.player.enabled=not locked)
	talk.event_blocked.connect(func(_id,_payload):
		talk.stop()
		game._dialog("nadia_pilot",game.named("nadia"),game.t("Завтра встретимся у колодца?","Meet by the well tomorrow?"),[game.choice("yes","Приду!","I will!",func():game.state.set_flag("nadia_meeting");game.npcs.change_relation("nadia",1);game._close()),game.choice("later","Позже","Later",game._close)],false))
func play():
	game._close()
	var line=TalkLine.new()
	line.text=game.t("У каждого дома есть своя история.\nСпасибо, что помогаешь её сохранить.","Every home holds a story.\nThank you for keeping it safe.")
	line.event_id="meeting"
	line.event_blocking=true
	talk.say(line)
func _input(event):
	if not is_instance_valid(talk) or talk.state==NPCTalkKit.State.IDLE: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_E: talk.advance();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_ESCAPE: talk.stop();game._close();get_viewport().set_input_as_handled()

extends Node2D
const STRIP=preload("res://after_silence/assets/minigames0310/success.png")
var animate=true

func _ready():
	var frames=SpriteFrames.new()
	frames.set_animation_loop("default",false)
	frames.set_animation_speed("default",15)
	for i in 8:
		var tile=AtlasTexture.new()
		tile.atlas=STRIP
		tile.region=Rect2(i*48,0,48,48)
		frames.add_frame("default",tile)
	$Emblem.sprite_frames=frames
	if animate:
		$Emblem.play()
		$AnimationPlayer.play("reveal")
		await $AnimationPlayer.animation_finished
	else:
		$Emblem.frame=7
		await get_tree().create_timer(.55).timeout
	queue_free()

extends AnimatedSprite2D

var comfort
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_frames=preload("res://after_silence/assets/remaster0290/pennants.tres")
	scale=Vector2(2,2)
	centered=false
	z_index=2
func _process(_delta: float):
	if comfort==null or comfort.reduce_motion:
		if is_playing(): stop()
		frame=0
	elif not is_playing():
		play()

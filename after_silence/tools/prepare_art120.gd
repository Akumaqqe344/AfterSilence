extends SceneTree
func _initialize():
	var source=Image.load_from_file("res://after_silence/assets/art120/source.png")
	var catalog={"shop_front":[88,80],"well":[40,44],"gazebo":[64,60],"village_board":[32,34]}
	var index=0
	for id in catalog:
		var w=source.get_width()/2
		var h=source.get_height()/2
		var image=source.get_region(Rect2i((index%2)*w,(index/2)*h,w,h))
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var c=image.get_pixel(x,y)
				c.a=1 if c.a>.65 else 0
				image.set_pixel(x,y,c)
		image=image.get_region(image.get_used_rect())
		image.resize(catalog[id][0],catalog[id][1],Image.INTERPOLATE_NEAREST)
		image.save_png("res://after_silence/assets/art120/"+id+".png")
		index+=1
	quit()

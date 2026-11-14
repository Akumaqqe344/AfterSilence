extends SceneTree
# Asset preparation only: split the generated atlas, crop alpha, snap to game pixels.
func _initialize():
	var sheet=Image.load_from_file("res://after_silence/assets/props091/source.png")
	assert(sheet!=null and not sheet.is_empty())
	var names=["street_lamp","way_lamp","noticeboard","chest","relay","signpost","book","photo"]
	var sizes=[Vector2i(26,72),Vector2i(34,64),Vector2i(42,44),Vector2i(34,26),Vector2i(30,40),Vector2i(28,42),Vector2i(34,28),Vector2i(22,28)]
	for i in range(names.size()):
		var left=int((i%4)*sheet.get_width()/4.0)
		var right=int((i%4+1)*sheet.get_width()/4.0)
		var top=int((i/4)*sheet.get_height()/2.0)
		var bottom=int((i/4+1)*sheet.get_height()/2.0)
		var cell=sheet.get_region(Rect2i(left,top,right-left,bottom-top))
		# Discard faint alpha fringe; sprites have fully opaque square pixels.
		for y in range(cell.get_height()):
			for x in range(cell.get_width()):
				var color=cell.get_pixel(x,y)
				color.a=1.0 if color.a>=.5 else 0.0
				cell.set_pixel(x,y,color)
		var crop=cell.get_used_rect()
		assert(crop.has_area())
		cell=cell.get_region(crop)
		var fit=minf(float(sizes[i].x)/cell.get_width(),float(sizes[i].y)/cell.get_height())
		cell.resize(maxi(1,roundi(cell.get_width()*fit)),maxi(1,roundi(cell.get_height()*fit)),Image.INTERPOLATE_NEAREST)
		assert(cell.save_png("res://after_silence/assets/props091/"+names[i]+".png")==OK)
		print(names[i]," ",cell.get_size())
	var lantern=sheet.get_region(Rect2i(677,145,110,143))
	for y in range(lantern.get_height()):
		for x in range(lantern.get_width()):
			var color=lantern.get_pixel(x,y)
			color.a=1.0 if color.a>=.5 else 0.0
			lantern.set_pixel(x,y,color)
	lantern=lantern.get_region(lantern.get_used_rect())
	lantern.resize(18,24,Image.INTERPOLATE_NEAREST)
	assert(lantern.save_png("res://after_silence/assets/props091/wall_lamp.png")==OK)
	quit()

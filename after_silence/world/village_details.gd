extends Node2D
## Original pixel ornaments. No collision or navigation obstacles are added.
var world
var zone="town"
var entries: Array=[]
func _ready():
	if world==null: return
	for child in world.sorter.get_children():
		if not child.has_meta("building"): continue
		var garden=get_script().new()
		garden.zone=world.zone
		garden.entries=[[Vector2(0,-12),child.variant]]
		garden.position=child.position+Vector2(0,12)
		world.sorter.add_child(garden)
func _draw():
	for entry in entries:
		var p: Vector2=entry[0]
		var flowers=[Color("d5aa91"),Color("b9becd"),Color("d8c68e"),Color("acbc92")][posmod(entry[1],4)]
		for side in [-1,1]:
			var at=p+Vector2(side*51,6)
			if preload("res://after_silence/world/watercourse.gd").depth(zone,position+at)>-20: continue
			draw_rect(Rect2(at+Vector2(-12,-6),Vector2(24,10)),Color("6f5846"))
			draw_rect(Rect2(at+Vector2(-12,-6),Vector2(24,2)),Color("ad8b63"))
			for i in range(5):
				var root=at+Vector2(-9+i*4,-7)
				draw_rect(Rect2(root-Vector2(0,5),Vector2(1,6)),Color("526c40"))
				draw_rect(Rect2(root-Vector2(1,6+(i%2)*2),Vector2(3,3)),flowers)
				draw_rect(Rect2(root-Vector2(0,5+(i%2)*2),Vector2(1,1)),Color("e0cc95"))
		# A narrow welcome mat sits under the stairs, with the road behind it.
		draw_rect(Rect2(p+Vector2(-12,2),Vector2(24,9)),Color("71624b"))
		draw_rect(Rect2(p+Vector2(-10,3),Vector2(20,1)),Color("b79c6a"))
		for x in range(-8,10,4): draw_rect(Rect2(p+Vector2(x,5),Vector2(2,3)),Color("a18d5d"))

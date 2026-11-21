extends Button
const Art=preload("res://after_silence/ui/trial_stage_art.gd")

const COLORS=[Color("e6af89"),Color("acd0b1"),Color("aac0e1"),Color("d3a9c8"),Color("e4cf95"),Color("8fd0c9")]
const SYMBOLS=[
	["00100","01110","11111","01110","00100"],
	["01110","11111","11011","11111","01110"],
	["10001","01010","00100","01010","10001"],
	["00100","00100","11111","00100","00100"],
	["10001","11011","11111","01110","00100"],
	["00100","01010","10001","01010","00100"],
]

var kind=""
var tone=-1
var stack: Array=[]
var stage=0
var picked=false
var suggested=false
var lift=0.0
var bounce: Tween

func animate_change():
	if is_instance_valid(bounce): bounce.kill()
	lift=5
	bounce=create_tween()
	bounce.tween_method(_raise_art,5.0,0.0,.27).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _raise_art(value: float):
	lift=value
	queue_redraw()

func _draw() -> void:
	var center=(size*.5-Vector2(0,lift)).floor()
	if kind=="tubes":
		var bottle=Rect2(center-Vector2(13,26),Vector2(26,53))
		draw_rect(bottle,Color("282b3c"))
		draw_rect(bottle,Color("98a5aa"),false,2)
		draw_rect(Rect2(center-Vector2(16,28),Vector2(32,4)),Color("d1b59a"))
		draw_rect(Rect2(center-Vector2(10,22),Vector2(2,45)),Color("b9c5bd52"))
		draw_rect(Rect2(center+Vector2(9,-17),Vector2(1,34)),Color("c9d4cc47"))
		for i in range(stack.size()):
			var liquid=Rect2(center+Vector2(-10,22-i*13-12),Vector2(20,11))
			draw_rect(liquid,COLORS[stack[i]])
			draw_rect(Rect2(liquid.position,Vector2(20,2)),COLORS[stack[i]].lightened(.24))
			_symbol(liquid.get_center(),stack[i],1)
	elif kind=="seeds":
		if stage>=0:
			draw_rect(Rect2(center-Vector2(16,-2),Vector2(32,12)),Color("74584f"))
			draw_rect(Rect2(center-Vector2(16,-3),Vector2(32,2)),Color("aa8068"))
		if stage<=0:
			Art.stamp(self,7,center-Vector2(0,4),Vector2(24,24),Color("ffffff8f"))
		if stage>0:
			draw_rect(Rect2(center-Vector2(1,10),Vector2(3,17)),Color("9ab092"))
			draw_rect(Rect2(center-Vector2(7,3),Vector2(6,2)),Color("a7bc8e"))
			draw_rect(Rect2(center+Vector2(2,-5),Vector2(7,2)),Color("7fa282"))
		_symbol(center-Vector2(0,6),tone,3 if stage==2 else 2,stage==0)
	elif tone>=0:
		match kind:
			"pairs":
				draw_rect(Rect2(center-Vector2(22,15),Vector2(44,30)),Color("282739"))
				draw_rect(Rect2(center-Vector2(20,14),Vector2(40,27)),Color("765b67"))
				draw_rect(Rect2(center-Vector2(19,13),Vector2(38,25)),Color("a68680"))
				draw_rect(Rect2(center-Vector2(18,12),Vector2(36,23)),Color("c2a299"),false,1)
				draw_rect(Rect2(center-Vector2(16,10),Vector2(32,19)),COLORS[tone].darkened(.54))
				_symbol(center,tone,2)
			"lights":
				Art.stamp(self,1,center,Vector2(32,32),COLORS[tone].lerp(Color.WHITE,.46))
				_symbol(center+Vector2(0,2),tone,1)
			"shelves":
				draw_rect(Rect2(center+Vector2(-26,15),Vector2(52,4)),Color("987265"))
				draw_rect(Rect2(center+Vector2(-26,19),Vector2(52,2)),Color("2c2839"))
				Art.stamp(self,13,center,Vector2(32,32),COLORS[tone].lerp(Color.WHITE,.58))
				_symbol(center+Vector2(0,4),tone,1)
	if suggested: draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color("e4cf95"),false,2)
	if picked: draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),Color("c2ddc8"),false,2)

func _symbol(at: Vector2,i: int,dot: int,muted=false) -> void:
	var tint=COLORS[i].darkened(.28) if muted else COLORS[i].lightened(.48)
	if dot==1: tint=Color("353041")
	var start=(at-Vector2.ONE*dot*2.5).floor()
	for y in range(5):
		for x in range(5):
			if SYMBOLS[i][y][x]=="1": draw_rect(Rect2(start+Vector2(x,y)*dot,Vector2.ONE*dot),tint)

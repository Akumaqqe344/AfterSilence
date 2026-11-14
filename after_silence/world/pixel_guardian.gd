extends RefCounted

# Native pixel art: stone, roots and copper share the town's palette.
static func paint(canvas: CanvasItem, center: Vector2, kind: int, exposed: bool=false):
	var stone=Color("465b62") if kind==0 else Color("644b64") if kind==1 else Color("4c694e")
	var light=Color("91b6a0") if kind==0 else Color("b494b3") if kind==1 else Color("a7bc76")
	var glow=Color("f6d78b") if exposed else Color("75ccc1")
	var pattern=["    rrrr    ","  rrssssrr  "," rssssssssr "," rssllllssr ","rssgssgsssr ","rsssssssssr "," rssllsssr  ","  rssssr    "," rrsssssrr  ","rrssrrssrrr ","rssr  rsssr ","rrr    rrr  "]
	if kind==1: pattern=[" r        r "," rr  rr  rr "," rsssssssr  ","rssllllsssr ","rssgssgsssr "," rsssssssr  ","  rssssr    "," rrsssssrr  ","rssllsllssr "," rsssssssr  ","  rr  rr    ","  rr  rr    "]
	for y in range(pattern.size()):
		for x in range(pattern[y].length()):
			var p=pattern[y][x]
			if p==" ": continue
			var color=Color("23343c") if p=="r" else light if p=="l" else glow if p=="g" else stone
			canvas.draw_rect(Rect2(center+Vector2((x-6)*6,(y-6)*6),Vector2(6,6)),color)
			if p=="s" or p=="l":
				var grain=center+Vector2((x-6)*6,(y-6)*6)
				canvas.draw_rect(Rect2(grain,Vector2(4,2)),color.lightened(.12))
				canvas.draw_rect(Rect2(grain+Vector2(4,4),Vector2(2,2)),color.darkened(.22))
	if kind==0:
		for x in [-24,18]:
			canvas.draw_rect(Rect2(center+Vector2(x,-30),Vector2(6,35)),Color("bd956b"))
			canvas.draw_rect(Rect2(center+Vector2(x,-27),Vector2(3,29)),Color("e1bd85"))
	if kind==2:
		for i in range(5):
			canvas.draw_rect(Rect2(center+Vector2(-38+i*16,-41-abs(2-i)*4),Vector2(18,13)),light)

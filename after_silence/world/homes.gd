extends RefCounted
const IDS=["home_nadia","home_lev","home_pavel","home_sonya"]
const POSITIONS=[Vector2(260,300),Vector2(960,300),Vector2(260,740),Vector2(960,740)]
const NAMES=[["Дом Нади","Nadia's home"],["Мастерская Льва","Lev's workshop"],["Дом Павла","Pavel's home"],["Дом Сони","Sonya's home"]]
const HAMLET=[Vector2(1250,720),Vector2(1550,720),Vector2(1550,280),Vector2(360,1170),Vector2(950,1170)]
static func exteriors(zone: String, echo: bool) -> Array:
	var result=[]
	if zone=="town":
		for i in range(4):
			var p=POSITIONS[i]+(Vector2(40 if i%2 else -40,32) if echo else Vector2.ZERO)
			result.append([p,i,IDS[i],Vector2(clampf(p.x,260,1550),500 if i<2 else 840)])
		for i in range(HAMLET.size()):
			var p=HAMLET[i]
			result.append([p,int(p.x/10)%4,"hamlet_house_"+str(i),Vector2(p.x,500 if p.y<500 else 840 if p.y<1000 else 1200)])
	elif zone in ["orchard","harbor"]:
		for i in range(3):
			var p=Vector2([280,600,920][i],300)
			result.append([p,0 if zone=="orchard" else 2,"district_house_"+str(i),Vector2(p.x,500)])
	return result
static func door(id: String, echo: bool) -> Vector2:
	var i=IDS.find(id)
	if i<0: return Vector2(600,200)
	return POSITIONS[i]+(Vector2(40 if i%2 else -40,32) if echo else Vector2.ZERO)+Vector2(0,28)
static func approaches(zone: String, echo: bool) -> Array:
	var result=exteriors(zone,echo)
	if zone=="town":
		result.append([Vector2(350,440),0,"visit_shop",Vector2(350,500)])
		result.append([Vector2(600,145),0,"to_library",Vector2(600,500)])
		result.append([Vector2(1270,950),0,"riverside_rest",Vector2(1190,840)])
	return result
const WALLS=[Rect2(64,64,512,16),Rect2(64,80,16,352),Rect2(560,80,16,352),Rect2(80,432,208,16),Rect2(352,432,208,16)]
const COMMON=[
	["window",Rect2(272,89,96,43)],
	["rug",Rect2(245,266,150,133)],
	["table",Rect2(262,144,76,31)],
	["chair",Rect2(229,162,23,24)],
	["chair",Rect2(348,153,23,24)],
	["storage",Rect2(208,351,31,23)]
]
const ROOMS={
	"home_nadia":[["medicine",Rect2(420,104,125,47)],["bed",Rect2(97,205,102,111)],["stool",Rect2(212,278,24,24)],["wash",Rect2(428,205,103,31)],["blanket",Rect2(99,129,111,34)],["plant",Rect2(502,350,36,32)]],
	"home_lev":[["tools",Rect2(418,103,124,48)],["forge",Rect2(96,106,107,63)],["bed",Rect2(94,264,100,108)],["bench",Rect2(429,212,110,52)],["wood",Rect2(94,197,102,36)],["toolbox",Rect2(447,320,84,42)]],
	"home_pavel":[["rack",Rect2(412,90,132,21)],["bed",Rect2(100,210,104,110)],["chest",Rect2(99,134,111,36)],["stove",Rect2(465,202,74,46)],["boots",Rect2(468,331,68,33)],["stool",Rect2(215,273,24,24)]],
	"home_sonya":[["books",Rect2(420,100,126,46)],["bed",Rect2(100,207,104,106)],["desk",Rect2(430,204,103,28)],["sofa",Rect2(414,338,126,42)],["plant",Rect2(98,127,37,33)],["art",Rect2(152,127,64,35)]]
}
const PERSONAL_SURFACES={
	"home_nadia":{"medicine":"medicine","album":"table"},
	"home_lev":{"tools":"bench","plan":"table"},
	"home_pavel":{"medal":"rack","log":"table"},
	"home_sonya":{"drawing":"table","letter":"desk"}
}
const ACCENTS={
	"home_nadia":Color("72937e"),"home_lev":Color("9b8259"),
	"home_pavel":Color("718b9a"),"home_sonya":Color("a5798a")
}
const Furnishing=preload("res://after_silence/world/home_furnishing.gd")

static func surface(zone: String,id: String) -> Rect2:
	var kind=PERSONAL_SURFACES.get(zone,{}).get(id,"")
	for item in COMMON+ROOMS.get(zone,[]):
		if item[0]==kind: return item[1]
	return Rect2()

static func build(world):
	for rect in WALLS: world.boundary(rect)
	world.spot("leave_home",Vector2(320,422),"trace")
	world.spot("home_memory",Vector2(480,258),"none")
	world.spot("hotspot_window",Vector2(320,135),"none")
	world.spot("hotspot_furniture",Vector2(130,190),"none")
	for item in COMMON+ROOMS.get(world.zone,[]):
		var piece=Furnishing.new()
		piece.kind=item[0]
		var area: Rect2=item[1]
		piece.position=Vector2(area.get_center().x,area.end.y)
		piece.extent=area.size
		piece.tint=ACCENTS.get(world.zone,Color("8f8b72"))
		piece.name="Furniture_"+piece.kind
		world.sorter.add_child(piece,true)
		if not piece.solid():
			piece.z_index=-1
			continue
		world.boundary(area)

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
static func build(world):
	for rect in [Rect2(64,64,512,16),Rect2(64,80,16,352),Rect2(560,80,16,352),Rect2(80,432,208,16),Rect2(352,432,208,16)]: world.boundary(rect)
	world.spot("leave_home",Vector2(320,422),"trace")
	world.spot("home_memory",Vector2(480,258),"none")
	world.spot("hotspot_window",Vector2(320,135),"none")
	world.spot("hotspot_furniture",Vector2(130,190),"none")
	for item in [["window",Vector2(320,110)],["rug",Vector2(320,365)],["shelf",Vector2(130,170)],["desk",Vector2(480,220)],["plant",Vector2(520,400)],["bed",Vector2(140,360)],["table",Vector2(300,220)],["chair",Vector2(300,270)]]: world.prop(item[0],item[1])
	for rect in [Rect2(100,330,70,25),Rect2(450,202,60,18),Rect2(265,202,70,18)]: world.boundary(rect)
	if world.zone=="home_lev": world.prop("workbench",Vector2(480,330));world.boundary(Rect2(445,310,70,20))
	if world.zone=="home_pavel": world.prop("shelf",Vector2(480,160))

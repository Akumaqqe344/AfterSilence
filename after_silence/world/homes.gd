extends RefCounted
const IDS=["home_nadia","home_lev","home_pavel","home_sonya"]
const POSITIONS=[Vector2(260,300),Vector2(960,300),Vector2(260,740),Vector2(960,740)]
const NAMES=[["Дом Нади","Nadia's home"],["Мастерская Льва","Lev's workshop"],["Дом Павла","Pavel's home"],["Дом Сони","Sonya's home"]]
static func door(id: String, echo: bool) -> Vector2:
	var i=IDS.find(id)
	if i<0: return Vector2(600,200)
	return POSITIONS[i]+(Vector2(40 if i%2 else -40,32) if echo else Vector2.ZERO)+Vector2(0,28)
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

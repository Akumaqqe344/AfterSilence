extends RefCounted

const Fixture=preload("res://after_silence/world/district_fixture.gd")

const SITES={
	"market":{"zone":"town","point":Vector2(734,638),"name":["Рыночная площадь","Market square"],"note":["У прилавков оставляют корзины для соседей.","Neighbors leave baskets at the market stalls."]},
	"pond":{"zone":"town","point":Vector2(1062,66),"name":["Пруд у библиотеки","Library pond"],"note":["Сюда приходят читать после закрытия библиотеки.","Readers come here after the library closes."]},
	"terrace":{"zone":"orchard","point":Vector2(600,628),"name":["Садовые террасы","Orchard terraces"],"note":["Канавки между грядками собирают дождевую воду.","Channels between the beds collect rainwater."]},
	"ruins":{"zone":"forest","point":Vector2(838,551),"name":["Каменное кольцо","Stone circle"],"note":["Камни обозначали поворот старой лесной тропы.","The stones marked a bend in the old forest trail."]},
	"siding":{"zone":"harbor","point":Vector2(780,609),"name":["Грузовая станция","Freight siding"],"note":["С этой платформы ящики отправляли в город.","Crates left this platform for town."]},
	"pier":{"zone":"harbor","point":Vector2(1101,752),"name":["Рыбацкий причал","Fishing pier"],"note":["На сваях видны отметки прилива.","The tide marks are still visible on the pilings."]}
}
const APPROACHES={
	"town":[[Vector2(600,622),Vector2(734,638),21.0],[Vector2(600,193),Vector2(858,193),15.0],[Vector2(858,193),Vector2(858,104),15.0],[Vector2(858,104),Vector2(1014,66),15.0],[Vector2(1014,66),Vector2(1062,66),14.0]],
	"orchard":[[Vector2(600,628),Vector2(489,628),13.0],[Vector2(600,628),Vector2(736,628),13.0]],
	"harbor":[[Vector2(600,589),Vector2(780,609),17.0],[Vector2(600,719),Vector2(851,720),17.0],[Vector2(851,720),Vector2(988,752),15.0]],
	"forest":[[Vector2(823,520),Vector2(838,551),15.0]]
}
const FEATURES={
	"town":[["stone",Rect2(486,514,277,151)],["stone",Rect2(1032,47,65,38)]],
	"orchard":[["soil",Rect2(375,552,180,162)],["soil",Rect2(665,552,172,162)]],
	"harbor":[["rail",Rect2(705,557,299,37)],["plank",Rect2(711,599,277,47)]],
	"forest":[["rune",Rect2(755,458,165,124)]]
}
const FIXTURES={
	"town":[["stall",Vector2(753,566),0],["stall",Vector2(817,630),1],["bench",Vector2(1054,48),0],["bench",Vector2(492,566),0],["crate",Vector2(857,637),0],["trough",Vector2(426,530),0],["logpile",Vector2(1016,419),0]],
	"orchard":[["trellis",Vector2(384,563),0],["trellis",Vector2(826,563),1],["barrel",Vector2(568,571),0],["crate",Vector2(639,691),0],["barrow",Vector2(573,682),0],["trough",Vector2(859,604),0]],
	"harbor":[["wagon",Vector2(868,585),0],["crate",Vector2(963,619),1],["crate",Vector2(731,623),0],["barrel",Vector2(969,702),0],["buoys",Vector2(939,695),0],["bench",Vector2(889,659),0]],
	"forest":[["marker",Vector2(790,482),0],["marker",Vector2(877,465),1],["marker",Vector2(922,507),2],["marker",Vector2(920,560),1],["marker",Vector2(785,572),2],["logpile",Vector2(660,708),0],["bench",Vector2(745,770),0]]
}

static func add_paths(world):
	world.paths.append_array(APPROACHES.get(world.zone,[]))

static func for_zone(zone: String) -> Array[String]:
	var result: Array[String]=[]
	for id in SITES:
		if SITES[id].zone==zone: result.append(id)
	return result

static func build(world):
	var kinds=for_zone(world.zone)
	if kinds.is_empty(): return
	var scenery=preload("res://after_silence/world/district_art.gd")
	var layer=scenery.new()
	layer.features=FEATURES[world.zone]
	layer.zone=world.zone
	layer.show_pier=world.zone=="harbor"
	layer.z_index=-2
	layer.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	# The shore paints first, so the pier is visible over the same water it crosses.
	world.add_child(layer)
	if world.zone=="town":
		var pennants=preload("res://after_silence/world/district_pennants.gd").new()
		pennants.comfort=world.visual_comfort
		pennants.position=Vector2(656,515)
		world.add_child(pennants)
	for item in FIXTURES[world.zone]:
		var sprite=Fixture.new()
		sprite.kind=item[0]
		sprite.position=item[1]
		sprite.variant=item[2]
		world.sorter.add_child(sprite)
		world.boundary(Rect2(sprite.position+Vector2(-sprite.footprint()*.5,-9),Vector2(sprite.footprint(),11)))
	for id in kinds:
		var site=SITES[id]
		world.spot("landmark_"+id,site.point,"none")
		var sign=Fixture.new()
		sign.kind="sign"
		sign.position=site.point+Vector2(18,-8)
		world.sorter.add_child(sign)

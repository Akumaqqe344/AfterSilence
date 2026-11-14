extends RefCounted
var game
const GOODS={"bandage":2,"ribbon":2,"keepsake":3}
func _init(owner): game=owner
func buy(id: String) -> bool:
	if not GOODS.has(id) or game.state.tokens<GOODS[id] or game.state.item(id)>=9: return false
	if not game.state.give(id): return false
	game.state.tokens-=GOODS[id]
	game.state.set_flag("shop_purchase")
	game._save(false)
	return true
func open():
	var actions=[]
	for id in GOODS:
		var name=game.t(game.inventory.catalog[id].title[0],game.inventory.catalog[id].title[1])
		var label=name+" · "+str(GOODS[id])+game.t(" жет."," tokens")
		actions.append(game.choice(id,label,label,func():
			if not buy(id): game._notify(game.t("Не хватает жетонов или места в рюкзаке.","Not enough tokens or backpack space."))
			else: open()))
	actions.append(game.choice("hint","Подскажи, куда идти","Where should I go?",func(): game._dialog("",game.t("Совет лавочника","Shopkeeper's tip"),hint(),[game.choice("back","Спасибо","Thanks",open)],false)))
	actions.append(game.choice("close","До встречи","Goodbye",game._close))
	game._dialog("",game.t("Лавка у площади","Village shop"),game.t("Жетоны: ","Tokens: ")+str(game.state.tokens)+"\n"+game.t("Помогай жителям — получай жетоны для припасов.","Help residents to earn supply tokens."),actions,false)
func hint() -> String:
	if game.state.flag("event_campaign"):
		var director=game.events_controller
		return game.t("История завершена.","The story is complete.") if director.index>=director.events.size() else director.pair(director.events[director.index].context)
	if game.state.flag("rift_mode"):
		if game.state.flag("rift_finished"): return game.t("Помоги собрать письма на пристани. Загляни в дома друзей.","Collect harbor letters and visit your friends' homes.")
		var quest=game.Rift.QUESTS[game.rift.index]
		return game.t("На карте золотым отмечен огонёк. ","The golden map marker shows the light. ")+game.t(quest.short[0],quest.short[1]) if quest.short is Array else game.t("Иди к золотому огоньку в городе. J — журнал, M — карта.","Follow the golden light in town. J: journal, M: map.")
	return game.Story.pair(game.quests.objective(),game.state.language)
static func build(world):
	for r in [Rect2(64,64,512,16),Rect2(64,80,16,352),Rect2(560,80,16,352),Rect2(80,432,208,16),Rect2(352,432,208,16)]: world.boundary(r)
	for p in [Vector2(130,220),Vector2(510,220),Vector2(510,340)]: world.prop("shelf",p)
	world.prop("desk",Vector2(320,260))
	world.boundary(Rect2(284,240,72,20))
	world.prop("rug",Vector2(320,365))
	world.prop("window",Vector2(320,120))
	world.spot("shop_counter",Vector2(320,294),"none")
	world.spot("leave_shop",Vector2(320,422),"none")

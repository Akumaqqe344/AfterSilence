extends RefCounted
var game
func _init(owner): game=owner
func pair(value: Array) -> String: return game.t(value[0],value[1])
func inventory():
	var actions=[]
	for id in game.state.ITEMS:
		if game.state.item(id)==0: continue
		var entry=game.inventory.catalog[id]
		var label=pair(entry.title)+" ×"+str(game.state.item(id))
		actions.append(game.choice(id,label,label,func(): item(id)))
	actions.append(game.choice("craft","Сшить знак: лента + перевязка","Sew badge: ribbon + dressing",func():
		if game.inventory.craft_badge(): game._save(false);inventory()
		else: game._notify(game.t("Нужны лента и перевязка. Освободи место для знака.","Need ribbon, dressing and room for a badge."))))
	actions.append(game.choice("close","Закрыть","Close",game._close))
	game._dialog("",game.t("Рюкзак [I]","Backpack [I]"),game.t("Выбери предмет. В доме вещи можно оставить в сундуке.","Choose an item. Store things in a chest at home."),actions,false)
	for id in game.state.ITEMS:
		if not game.buttons.has(id): continue
		var button=game.buttons[id]
		var entry=game.inventory.catalog[id]
		button.icon=load("res://after_silence/assets/art100/"+entry.art+".png")
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",24)
		button.tooltip_text=pair(entry.category)+" · "+pair(entry.source)+"\n"+pair(entry.description)
func item(id: String):
	var entry=game.inventory.catalog[id]
	game._dialog("",pair(entry.title),pair(entry.category)+" · "+pair(entry.source)+"\n"+pair(entry.description),[game.choice("use","Использовать","Use",func(): game._item(id)),game.choice("back","Назад","Back",inventory)],false)
func storage():
	var actions=[]
	for id in game.state.ITEMS:
		var label=pair(game.inventory.catalog[id].title)
		if game.state.item(id)>0: actions.append(game.choice("put_"+id,"Оставить: "+label,"Store: "+label,func():game.inventory.transfer(id,true);game._save(false);storage()))
		if game.state.storage.get(id,0)>0: actions.append(game.choice("get_"+id,"Взять: "+label,"Take: "+label,func():game.inventory.transfer(id,false);game._save(false);storage()))
	actions.append(game.choice("close","Закрыть","Close",game._close))
	game._dialog("",game.t("Домашний сундук","Home chest"),game.t("Общий сундук во всех домах. Вещи сохраняются.","Shared across homes. Stored items are saved."),actions,false)
func routines():
	var lines=[]
	for id in game.npcs.PROFILE:
		var task=game.npcs.task(id)
		var next_task=game.npcs.routine.next(id,game.state.clock)
		lines.append("◇ "+game.named(id)+" · "+str(task[2])+" · "+game.npcs.behavior(id)+"\n   "+game.t("Смена через ","Next in ")+str(int(next_task.hours*60))+game.t(" мин."," min."))
	game._dialog("",game.t("Жители и время","Residents and time"),"\n".join(lines),[game.choice("back","В журнал","Journal",game._journal)],false)
func slots():
	var actions=[]
	var base="qa_slot" if "--qa" in OS.get_cmdline_user_args() else "rift_slot" if game.state.flag("rift_mode") else "episode_slot"
	for slot in range(1,4):
		var target="user://"+base+("" if slot==1 else "_"+str(slot))+".json"
		actions.append(game.choice("save"+str(slot),"Записать в слот "+str(slot),"Save slot "+str(slot),func():game.saves.path=target;game._save();slots()))
		if FileAccess.file_exists(target) or FileAccess.file_exists(target+".bak"):
			actions.append(game.choice("load"+str(slot),"Загрузить слот "+str(slot),"Load slot "+str(slot),func():game.saves.path=target;game._load_game()))
	actions.append(game.choice("close","Назад","Back",game._pause))
	game._dialog("",game.t("Три сохранения","Three save slots"),game.t("Автосохранение использует выбранный слот.","Autosave uses the selected slot."),actions,false)

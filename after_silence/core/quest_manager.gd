extends RefCounted
var state
func _init(s): state = s
func stage() -> int:
	if state.flag("ending"): return 7
	if state.flag("returned"): return 6
	if state.flag("sonya_met"): return 5
	if state.flag("forest_power"): return 4
	if state.flag("catalog") and state.flag("clock_solved"): return 3
	if state.flag("nadia_met"): return 2
	return 1
func target_npc() -> String:
	if stage()==1: return "nadia"
	if stage()==2 and not state.flag("mara_met"): return "mara"
	if stage()==3 and not state.flag("fuse_given"): return "lev"
	if stage()==4: return "sonya"
	if stage()==6:
		if not state.flag("nadia_review"): return "nadia"
		if not "survival" in state.links: return ""
		if not state.flag("lev_review"): return "lev"
		if not state.flag("mara_review"): return "mara"
		if "coverup" in state.links and "witness" in state.links: return "pavel"
	return ""
func steps() -> Array:
	match stage():
		1: return [[state.flag("nadia_met"),"Узнать у Нади, кто помнит Алину","Ask Nadia who remembers Alina"]]
		2: return [[state.flag("mara_met"),"Получить доступ к архиву Мары","Gain access to Mara's archive"],["date" in state.links,"Связать афишу и часы","Link the poster and the clock"],[state.flag("catalog"),"Расшифровать порядок в каталоге","Decode the catalogue sequence"],[state.flag("clock_solved"),"Восстановить время отключения сигнала","Restore the time of the signal cut"]]
		3: return [[state.flag("boss_relay_defeated"),"Пережить атаки сторожа реле и открыть его контур","Survive the relay guardian and open its circuit"],[state.flag("fuse_given"),"Получить предохранитель у Льва","Get a fuse from Lev"],[state.flag("forest_power"),"Включить насос без тревожного звонка","Power the pump without ringing the bell"]]
		4: return [[state.echo,"Перейти в отголосок леса","Enter the forest echo"],[state.flag("sonya_met"),"Выслушать Соню и решить, защищать ли её имя","Hear Sonya and decide whether to protect her name"]]
		5: return [[state.flag("returned"),"Вернуться в город, разорвав преследование","Reach town and break the pursuit"]]
		6: return [[state.flag("nadia_review"),"Сверить рассказ Сони с карточкой Нади","Compare Sonya's story with Nadia's chart"],["survival" in state.links,"Проверить, что Алина пережила отключение","Establish that Alina survived the signal cut"],[state.flag("lev_review") and state.flag("mara_review"),"Записать версии Льва и Мары","Record Lev's and Mara's accounts"],["coverup" in state.links and "witness" in state.links,"Связать список, фотографию и подпись","Connect the register, photo and signature"],[state.flag("boss_watcher_defeated"),"Разорвать сигнал наблюдателя","Break the Watcher's signal"]]
		_: return [[state.flag("ending"),"История завершена; проверьте достижения","Story complete; review achievements"]]
func objective() -> Array:
	if stage()==3 and not state.flag("boss_relay_defeated"): return ["Сторож реле: избегайте подсвеченных атак, подойдите после третьей и нажмите E","Relay guardian: dodge marked attacks; after the third, approach and press E"]
	if stage()==6:
		if not state.flag("nadia_review"): return ["Покажите Наде рассказ Сони: проверьте утро после воды","Show Sonya's testimony to Nadia; verify the morning after"]
		if not "survival" in state.links: return ["Свяжите карточку 06:40 и часы в журнале","Connect the 06:40 medical chart with the clock"]
		if not state.flag("lev_review"): return ["Попросите Льва записать, как разделили две цепи","Ask Lev to record how the circuits were separated"]
		if not state.flag("mara_review"): return ["Вернитесь к Маре: узнайте о втором экземпляре","Return to Mara and ask about the second copy"]
		if not "signature" in state.evidence: return ["Исследуйте подпись в отголоске библиотеки","Find the signature in the library echo"]
		if not "coverup" in state.links: return ["Свяжите фотографию и список в журнале","Connect the photograph with the register"]
		if not "witness" in state.links: return ["Свяжите рассказ Сони и подпись; затем найдите Павла","Connect Sonya's testimony with the signature, then find Pavel"]
		if not state.flag("boss_watcher_defeated"): return ["Наблюдатель охраняет Павла: переживите три атаки и разорвите сигнал клавишей E","The Watcher guards Pavel: survive three attacks and break its signal with E"]
		return ["Выберите, что город узнает о пропавших","Choose what the town will learn about the missing"]
	if stage()==3 and not "signature" in state.evidence: return ["Проверьте чернила в отголоске библиотеки; затем реле в лесу","Check the library echo for hidden ink, then repair the forest relay"]
	return {1:["Поговорите с Надей у колодца", "Talk to Nadia at the well"],2:["Расшифруйте архив: соедините улики, откройте каталог и восстановите время", "Decode the archive: link clues, open the catalogue and restore the time"],3:["Настройте три контура реле и подайте питание без звонка", "Set the relay's three circuits and restore power without ringing the bell"],4:["Войдите в отголосок леса и найдите свидетеля", "Enter the forest echo and find the witness"],5:["Вернитесь в город, уклоняясь от преследователя и используя укрытия", "Return to town, dodging the pursuer and using cover"],6:["Проверьте показания жителей и соберите доказательство для Павла", "Challenge the residents' accounts and assemble proof for Pavel"],7:["Эпизод завершён. Поговорите с жителями снова", "Episode complete. Speak with the townspeople again"]}[stage()]

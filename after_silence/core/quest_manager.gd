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
func objective() -> Array:
	if stage()==6:
		if not state.flag("nadia_review"): return ["Покажите Наде рассказ Сони: проверьте утро после воды","Show Sonya's testimony to Nadia; verify the morning after"]
		if not "survival" in state.links: return ["Свяжите карточку 06:40 и часы в журнале","Connect the 06:40 medical chart with the clock"]
		if not state.flag("lev_review"): return ["Попросите Льва записать, как разделили две цепи","Ask Lev to record how the circuits were separated"]
		if not state.flag("mara_review"): return ["Вернитесь к Маре: узнайте о втором экземпляре","Return to Mara and ask about the second copy"]
		if not "signature" in state.evidence: return ["Исследуйте подпись в отголоске библиотеки","Find the signature in the library echo"]
		if not "coverup" in state.links: return ["Свяжите фотографию и список в журнале","Connect the photograph with the register"]
		if not "witness" in state.links: return ["Свяжите рассказ Сони и подпись; затем найдите Павла","Connect Sonya's testimony with the signature, then find Pavel"]
		return ["Обсудите доказательства с Павлом на востоке площади","Confront Pavel with the evidence east of the square"]
	if stage()==3 and not "signature" in state.evidence: return ["Проверьте чернила в отголоске библиотеки; затем реле в лесу","Check the library echo for hidden ink, then repair the forest relay"]
	return {1:["Поговорите с Надей у колодца", "Talk to Nadia at the well"],2:["Найдите архив: сопоставьте улики и откройте каталог", "Investigate the archive: connect evidence and unlock the catalogue"],3:["Почините реле в лесу: нужен предохранитель Льва", "Repair the forest relay using Lev's fuse"],4:["Войдите в отголосок леса и найдите свидетеля", "Enter the forest echo and find the witness"],5:["Вернитесь в город. Не ведите сущность к свидетелю", "Return to town. Keep the entity away from the witness"],6:["Сопоставьте свидетельство и подпись; спросите Павла", "Connect testimony and signature, then confront Pavel"],7:["Эпизод завершён. Поговорите с жителями снова", "Episode complete. Speak with the townspeople again"]}[stage()]

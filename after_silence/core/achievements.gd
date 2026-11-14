extends RefCounted
const ENTRIES={
	"first_clue":["Первый след","First trace"],
	"first_link":["Два свидетельства","Two witnesses"],
	"all_clues":["Полный архив","Complete archive"],
	"relay_guardian":["Тихий ток","Silent current"],
	"relay_flawless":["Без единой раны","Untouched"],
	"watcher":["Разорвать наблюдение","Break surveillance"],
	"protect_sonya":["Слово дано","A promise kept"],
	"public_end":["Право знать","The right to know"],
	"sealed_end":["Право молчать","The right to silence"],
	"rift_first":["Письмо принято","Letter received"],
	"rift_half":["Город меняется","Town in motion"],
	"rift_all":["Двенадцать событий","Twelve events"],
	"rift_trust":["Доверие Алины","Alina's trust"],
	"rift_close":["Тихий берег","Quiet shore"],
	"rift_both":["Два времени","Two eras"],
	"rift_child":["Хранительница","The keeper"],
	"rift_return":["Второй шанс","Second chance"]
}
static func unlock(state,id: String) -> bool:
	if not ENTRIES.has(id) or id in state.achievements: return false
	state.achievements.append(id)
	return true
static func evaluate(state) -> Array[String]:
	var earned: Array[String]=[]
	var conditions={"first_clue":not state.evidence.is_empty(),"first_link":not state.links.is_empty(),"all_clues":state.evidence.size()==state.CLUES.size(),"relay_guardian":state.flag("boss_relay_defeated"),"relay_flawless":state.flag("boss_relay_flawless"),"watcher":state.flag("boss_watcher_defeated"),"protect_sonya":state.flag("protect_sonya"),"public_end":state.flag("ending_public"),"sealed_end":state.flag("ending") and not state.flag("ending_public"),"rift_first":state.flag("rift_q01_done"),"rift_half":state.flag("rift_q06_done"),"rift_all":state.flag("rift_finished"),"rift_trust":state.flag("rift_choice_11_trust"),"rift_close":state.flag("rift_final_close"),"rift_both":state.flag("rift_final_both"),"rift_child":state.flag("rift_final_child"),"rift_return":state.flag("rift_final_return")}
	for id in conditions:
		if conditions[id] and unlock(state,id): earned.append(id)
	return earned

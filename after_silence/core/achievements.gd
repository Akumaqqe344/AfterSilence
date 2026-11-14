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
	"sealed_end":["Право молчать","The right to silence"]
}
static func unlock(state,id: String) -> bool:
	if not ENTRIES.has(id) or id in state.achievements: return false
	state.achievements.append(id)
	return true
static func evaluate(state) -> Array[String]:
	var earned: Array[String]=[]
	var conditions={"first_clue":not state.evidence.is_empty(),"first_link":not state.links.is_empty(),"all_clues":state.evidence.size()==state.CLUES.size(),"relay_guardian":state.flag("boss_relay_defeated"),"relay_flawless":state.flag("boss_relay_flawless"),"watcher":state.flag("boss_watcher_defeated"),"protect_sonya":state.flag("protect_sonya"),"public_end":state.flag("ending_public"),"sealed_end":state.flag("ending") and not state.flag("ending_public")}
	for id in conditions:
		if conditions[id] and unlock(state,id): earned.append(id)
	return earned

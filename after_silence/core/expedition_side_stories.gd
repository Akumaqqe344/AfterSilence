extends RefCounted

const AFTERWORD = {
	"thread": {"id":"thread_handover","kind":"note","zone":"town","at":[505,639],"art":"ribbon",
		"title":["Узел на спинке","Knot on the bench"],
		"body":["Надя пришила к ленте второй кусок ткани. Цвета разные, а узел один. Кто-то оставил ответ, пока Вера ходила за водой.","Nadia sewed a second piece of cloth to the ribbon. Different colors, one knot. Someone left a reply while Vera was fetching water."]},
	"counterweight": {"id":"weight_impression","kind":"note","zone":"home_lev","at":[455,326],"art":"gear",
		"title":["Вмятина от гири","The mark left by the weight"],
		"body":["На верстаке два одинаковых круга. В записке Лев просит оставить гирю на правом: левый весь год занимала чашка его помощника.","Two matching circles mark the bench. Lev asks Vera to leave the weight on the right: his assistant's cup spent the whole year on the left."]},
	"plant_labels": {"id":"plant_letter","kind":"note","zone":"orchard","at":[623,584],"art":"letter",
		"title":["Письмо под ящиком","Letter beneath the crate"],
		"body":["«Если сад снова затопит, раздай метки. Кто-нибудь посадит эти грядки у себя». Вера складывает письмо так, чтобы его можно было достать даже промокшими руками.","“If the orchard goes under again, hand out the markers. Somebody will plant these beds at home.” Vera folds the letter so it can be opened even with wet hands."]},
	"lamp_pattern": {"id":"lamp_sill","kind":"note","zone":"town","at":[779,667],"art":"bell",
		"title":["Свет с другой стороны","Light from the other side"],
		"body":["После проверки лампу ставят низко. С улицы свет попадает ровно на ступеньку, о которую Надя боялась споткнуться в темноте.","After the test they set the lamp low. From the street it lights the exact step Nadia was afraid to trip on in the dark."]},
	"last_window": {"id":"window_margin","kind":"note","zone":"library","at":[509,479],"art":"papers",
		"title":["Поле для поздних гостей","Margin for late arrivals"],
		"body":["На полях копии Вера рисует путь от крыльца. В следующий раз пришедший позже сможет найти окно по этому рисунку.","Vera draws the path from the porch in the margin. Next time a late visitor can use the drawing to find the window."]}
}

static func followups(id: String) -> Array:
	if not AFTERWORD.has(id):
		return []
	var step: Dictionary = AFTERWORD[id].duplicate(true)
	step["expansion"] = true
	return [step]

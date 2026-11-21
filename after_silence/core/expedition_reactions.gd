extends RefCounted
## Conjunction adapted to WorldState flags from CodingQuests' CompoundCondition (MIT).

const OBJECTS = {
	"case_hub_radio": {"zone":"town", "point":Vector2(714,595), "art":"reel", "flag":"case_choice_dispatch_named",
		"title":["Приёмник Льва","Lev's receiver"],
		"body":["Из динамика слышны обрывки адресов. Лев записал частоту на полоске ткани, чтобы её могли найти в сумерках.","Fragments of addresses come from the speaker. Lev wrote the frequency on a strip of cloth so people can find it at dusk."]},
	"case_hub_timeline": {"zone":"town", "point":Vector2(749,511), "art":"papers", "flag":"case_choice_archive_seal",
		"title":["Объявление Мары","Mara's notice"],
		"body":["Три строчки и три времени. Под каждой кто-то поставил галочку. Мара оставила место для тех, кто помнит иначе.","Three lines and three times. Someone has ticked each one. Mara left room for people who remember things differently."]},
	"case_hub_empty_line": {"zone":"town", "point":Vector2(725,647), "art":"letter", "flag":"case_choice_foam_tell",
		"title":["Свободная строка","Empty line"],
		"body":["Кто-то положил рядом заточенный карандаш. Строка пока пустая.","Someone left a sharpened pencil beside it. The line is still blank."]},
	"case_hub_roll_lamp": {"zone":"town", "point":Vector2(636,580), "art":"bell", "flag":"case_done_evening_roll",
		"title":["Фонарь отправления","Departure lantern"],
		"body":["Соня подняла фонарь над столом. Люди уступают друг другу место, чтобы его было видно с дороги.","Sonya lifted the lantern above the table. People make room for each other so it can be seen from the road."]}
}

const NPCS = {
	"lev": [{"flag":"case_choice_dispatch_named","title":["Частота","Frequency"],
		"body":["Я думал, моя просьба давно стёрлась. Если на площади услышишь имя, не сразу отвечай. Дай ему договорить.","I thought my message had worn away. If you hear a name in the square, wait a moment before you answer. Let them finish."]}],
	"mara": [{"flag":"case_choice_archive_joint","title":["Последняя подпись","The last signature"],
		"body":["Сегодня я поставила свою подпись рядом с твоей. Раньше всегда оставляла пустую графу. Даже когда была уверена.","I signed beside you today. Before this, I always left that field blank. Even when I knew."]}],
	"pavel": [{"flag":"case_choice_pier_line","title":["Новая вахта","The next watch"],
		"body":["Если я задержусь, канат бери сухими руками. Я поставил снизу дополнительную ступень. Пора было сделать это самому.","If I'm late, take the line with dry hands. I've put another step at the bottom. It was time I did that myself."]}],
	"alina": [{"flag":"case_choice_bracken_quiet","title":["За поваленным деревом","Past the fallen tree"],
		"body":["Без света слышно, как лес идёт кругами. Наш ствол скрипит два раза. Я по этому звуку и вернулась.","Without the light you can hear the forest circle. Our tree creaks twice. That's how I came back."]}],
	"sonya": [{"flag":"case_choice_roll_rendezvous","title":["Два времени","Two times"],
		"body":["Я перепроверила оба часа. Даже если здесь прозвучит один удар, я дочитаю до второго времени.","I checked both times. Even if we hear one stroke here, I will read through to the second time."]},
		{"flag":"case_choice_roll_relay","title":["Ответ с берега","An answer from shore"],
		"body":["Лев проверил приёмник. Если кто-то откликнется, я подниму фонарь над головой. С того берега его видно.","Lev checked the receiver. If anyone answers I'll raise the lantern above my head. They can see it from the other shore."]}]
}

static func matches(state, required_flags: Array) -> bool:
	for id in required_flags:
		if not state.flag(id):
			return false
	return true

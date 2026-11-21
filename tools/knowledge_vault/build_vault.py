"""Create the project notes and link them to source identifiers. Existing notes survive reruns."""
from argparse import ArgumentParser
from pathlib import Path
import json
import re

PEOPLE = {
    "vera": ("Вера", "Игрок ведёт Веру по городу и решает, кому доверить найденное. В финале она держит список, пока Соня дочитывает имена."),
    "sonya": ("Соня", "Свидетельница, которая просит беречь её имя. Она уточняет, что Алина открыла служебный проход. В основной кампании Соня участвует в перекличке и решении на последнем берегу."),
    "lev": ("Лев", "Подписал акт исправности и дал Вере предохранитель. Может взять вахту у приёмника после решения о найденной кассете."),
    "mara": ("Мара", "Переписала список, чтобы скрыть имена детей и адрес укрытия. Может подписать рассказ вместе с Верой или убрать имена под печать."),
    "pavel": ("Павел", "В рассказе Сони приказал выключить колокол. В основной кампании ведёт расписание причала и может взять вахту у поднятого настила."),
    "nadia": ("Надя", "Сохраняет сведения о состоянии Алины, отделяя наблюдения от догадок. При закрытой перекличке Вера оставляет у неё конверт с именами."),
    "child": ("Ребёнок Нади", "Участвует во встречах об открытках и саде. Связан с дополнительными делами о скамье и зимних грядках."),
    "alina": ("Алина", "По свидетельству Сони открыла служебный проход и осталась у ручного затвора. Дальнейший путь из старого архива остаётся неопределённым. В новой истории оставляет след на просеке."),
    "guest": ("Гость", "Так персонаж назван в таблице участников. Его след связан со встречей «Гость праздника». Другие сведения о личности не установлены.")
}
TRIALS = {
    "letter_press": ("Поворот четырёх обрывков до совпадения ориентаций.", "Все четыре фрагмента выровнены.", "Низкая. Сверяйте края и ориентацию. Мелкие штрихи требуют читаемого масштаба."),
    "footprints": ("Фильтрация следа по двум независимым признакам.", "Выбран верный след в четырёх раундах предрелизной раскладки.", "Низкая. Ошибка не меняет раунд, после неё можно сравнить метку и форму."),
    "reality": ("Пошаговая навигация по клеткам. Неверная арка отражает геометрию, успешная меняет этап.", "Пройдена последовательность из четырёх символов.", "Средняя. После отражения можно заново открыть записку. Сохраняются этап и клетка."),
    "tubes": ("Перенос верхнего цвета в пустую пробирку или к такому же цвету.", "Три полные одноцветные пробирки.", "Средняя. Переполненный сосуд блокирует ход. Подсказка использует обход достижимых состояний."),
    "balance": ("Каждый груз циклически перемещается между складом и чашами.", "Пять грузов на чашах, суммы равны.", "Средняя. Массы доступны в UI. Побочные гири используют другую раскладку."),
    "pairs": ("Выбор двух карточек с одинаковой меткой.", "Шесть пар сняты.", "Низкая. Неверная пара остаётся на доске. Сходство с полками проверяется на плейтесте."),
    "seeds": ("Выбор семени по знаку, затем отдельный полив ростка.", "Шесть грядок посажены и политы.", "Низкая. Есть текстовые метки. Различимость отметок при низком контрасте нужно проверить с игроком."),
    "signal_grid": ("Нонограмма 5×5. Проверяются группы свечения в строках и столбцах.", "Совпадают все десять наборов групп.", "Средняя. Тихая перекличка меняет цель. У скамьи отдельная версия."),
    "railway": ("Три стрелки задают выход дерева. Отправление проверяет указанную станцию.", "Поезд отправлен по четырём маршрутам.", "Средняя. Неправильное направление не расходует попытку."),
    "lights": ("Обмен соседей допустим, если новый ряд или столбец содержит тройку одинаковых огней.", "Четыре поля с правильным обменом.", "Средняя. Ошибочный обмен даёт пояснение. Тройки должны быть рядом."),
    "echo_tuning": ("Вера изменяет два параметра и сравнивает две кривые.", "Подтверждены четыре совпадения амплитуды и фазы.", "Средняя. Звук можно отключить. Кривые остаются основным источником информации."),
    "shelves": ("Снятие трёх предметов с общей меткой.", "Собраны четыре тройки.", "Низкая. Отличие от пар следует из размера группы. Семейные знаки используются в сцене Сони.")
}
TRIAL_FILES = {
    "reality": ["core/reality_maze.gd", "ui/reality_maze_panel.gd"],
    **{k: ["core/quiet_puzzle.gd", "ui/quiet_puzzle_panel.gd"] for k in ("tubes", "pairs", "seeds", "lights", "shelves")},
    **{k: ["core/journey_trials.gd", "ui/journey_trial_panel.gd"] for k in ("letter_press", "footprints", "balance", "signal_grid", "railway", "echo_tuning")}
}
RIFT_RULES = {
    "route": "Дойти до цели, учитывая препятствия и условие сопровождения или спасения. Движение, рывок и безопасность задаются индексом эпизода.",
    "rhythm": "Нажимать показанные направления в такт. В щадящем режиме окно шире.",
    "switch": "Сверить рисунок ламп и проверить выбранную конфигурацию. Несколько целевых масок зависят от этапа.",
    "circuit": "Поворачивать соединители до горизонтального положения. Состояние клетки хранится как четверть оборота.",
    "defense": "Выбирать полосу и вовремя включать защиту. Символ и траектория показывают следующую угрозу.",
    "memory": "Открывать плитки по две и находить совпадения. Неудачная пара закрывается после короткой паузы.",
    "herbs": "Выбрать три нужных листа по форме. Собранные клетки отмечаются.",
}
ARCHIVE = {
    "Каталог эвакуации": ("catalog", "Вложить три карточки в папку. Афиша на площади содержит порядок учебной тревоги.", "Порядок совпал, появляется переписанный список и линза."),
    "Остановленные часы": ("clock", "Связать афишу и часы в журнале. Ввести часы и минуты и сверить положение стрелок.", "02:17 и подтверждённая связь «date» открывают дорогу в лес."),
    "Аварийное реле": ("relay", "Повернуть три контакта, затем проверить две ветви насоса и колокол. Проверка не тратит предохранитель.", "Успешная цепь и предохранитель запускают насос. Неверную схему можно исправить."),
}


def read_data(repo, filename):
    return json.loads((repo / "after_silence/data" / filename).read_text(encoding="utf-8-sig"))


def title(value):
    return value[0] if isinstance(value, list) else value


def link(name, label=None):
    return f"[[{name}{'|' + label if label else ''}]]"


def valid_name(value):
    return re.sub(r'[<>:"/\\|?*]', " — ", value).rstrip(". ")


def names_for(items):
    names = {}
    used = set()
    for item in items:
        name = valid_name(title(item["title"]))
        if name in used: name += f" · {item['id']}"
        used.add(name)
        names[item["id"]] = name
    return names


def note(vault, path, ident, heading, text, *, tags=("project",), sources=()):
    target = vault / (path + ".md")
    if target.exists():
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    fields = {"id": ident, "tags": list(tags), "sources": list(sources)}
    header = "\n".join(f"{key}: {json.dumps(value, ensure_ascii=False)}" for key, value in fields.items())
    target.write_text(f"---\n{header}\n---\n# {heading}\n\n{text.strip()}\n", encoding="utf-8")


def write_once(target, text):
    target.parent.mkdir(parents=True, exist_ok=True)
    if not target.exists(): target.write_text(text.rstrip()+"\n",encoding="utf-8")


def build_campaign(repo, vault):
    base = read_data(repo, "investigations.json")
    expansion = read_data(repo, "expeditions_0330.json")
    cases = base["chapters"] + expansion["chapters"] + base["sides"] + expansion["sides"]
    events = read_data(repo, "npc_events.json")["events"]
    locations = read_data(repo, "locations.json")
    legacy_roles = read_data(repo, "npc_routines.json")["residents"]
    rooms = base["rooms"] | expansion["rooms"]
    case_names, event_names = names_for(cases), names_for(events)
    event_by_id = {event["id"]: event for event in events}
    # Keep basename links unique across notes, including place/event name collisions.
    loc_names = {key: valid_name(title(place["name"])) + (" · локация" if title(place["name"]) in set(case_names.values()) | set(event_names.values()) else "") for key, place in locations.items()}
    zone_names = {zone: valid_name(title(place["name"])) for zone, place in rooms.items()}
    trial_names = {event["mode"]: "Испытание · " + event_names[event["id"]] for event in events}
    zone_label = {"town":"Площадь","library":"Библиотека","forest":"Лес","harbor":"Пристань","orchard":"Сад","shop":"Лавка","home_lev":"Дом Льва","home_nadia":"Дом Нади","home_pavel":"Дом Павла","home_sonya":"Дом Сони"} | zone_names
    for key, place in locations.items():
        departures = [link(event_names[e["id"]]) for e in events if e["location"] == key]
        requirement = link(event_names[place["requires"]]) if place["requires"] in event_names else "Открыто в начале."
        note(vault, "03 Мир/Локации/"+loc_names[key], "place-"+key, loc_names[key],
             f"{title(place['description'])}\n\n{title(place['route'])}\n\nУсловие доступа — {requirement}\n\n"
             f"Зона движка — `{place['zone']}` (координаты `{place['point']}`).\n\n"
             f"Здесь встречаются {', '.join(link(PEOPLE[n][0]) for n in place['npcs'] if n in PEOPLE) or 'участники событий по расписанию'}.\n\n"
             f"{' · '.join(departures)} · [[Архитектура]]", tags=("place",), sources=("after_silence/data/locations.json","after_silence/world/journey.gd"))
    for zone, room in rooms.items():
        gates = [link(case_names[c["id"]]) for c in cases if any(s["id"] == room["gate"] for s in c["steps"])]
        note(vault, "03 Мир/Локации/"+zone_names[zone], "room-"+zone, zone_names[zone],
             f"Вход по действию `{room['gate']}` из зоны `{room['parent']}`. Вход и выход размещены в {room['entry']} и {room['exit']}.\n\n"
             "Комната задаёт геометрию и места взаимодействий. " + " · ".join(gates) + "\n\n[[Архитектура]]",
             tags=("place",), sources=(f"after_silence/scenes/{zone}.tscn","after_silence/world/investigation_director.gd"))
    for index, event in enumerate(events):
        active_cases = [link(case_names[c["id"]]) for c in cases if c["before"] == event["id"]]
        options = "\n".join(f"- **{o[1]}**. Флаг `event_choice_{event['id']}_{o[0]}`. Отношение {link(PEOPLE[o[3]][0])} {o[4]:+}." for o in event["choices"])
        name = event_names[event["id"]]
        prior = link(event_names[events[index-1]["id"]]) if index else "Новое путешествие"
        note(vault, "01 Сюжет/Главы/"+name, "meeting-"+event["id"], name,
             f"{title(event['context'])}\n\n**Открытие** — {prior}. Дела перед встречей — {' · '.join(active_cases) or 'без отдельного расследования'}.\n\n"
             f"{link(PEOPLE[event['npc']][0])} ждёт в {link(loc_names[event['location']])}. {link(trial_names[event['mode']])}\n\n## Решения\n\n{options}\n\n[[Основная история]] · [[Сюжетные развилки]]",
             tags=("chapter","meeting"), sources=("after_silence/data/npc_events.json","after_silence/world/npc_event_director.gd"))
        behavior, completion, grade = TRIALS[event["mode"]]
        note(vault, "04 Геймплей/Мини-игры/"+trial_names[event["mode"]], "trial-"+event["mode"], name,
             f"**Правило в игре** — {title(event['rule'])}\n\n**Алгоритм** — {behavior}\n\n**Победа** — {completion}\n\n"
             f"**Поражение и восстановление** — неудачный ход можно исправить. Работают повтор и возврат к сохранённой доске.\n\n**Сложность и риск** — {grade}\n\n"
             f"{link(name)} · {link(PEOPLE[event['npc']][0])} · [[QA Dashboard]] · [[Баланс]]",
             tags=("minigame",), sources=tuple("after_silence/"+path for path in TRIAL_FILES[event["mode"]]))
    for case in cases:
        name = case_names[case["id"]]
        before = link(event_names[case["before"]]) if case["before"] else ""
        after = link(event_names[case["after"]]) if case["after"] else ""
        requirement = f"Обязательное дело перед {before}." if before else (f"Необязательное дело после {after}." if after else "Необязательное дело.")
        if case.get("expansion"): requirement += " Доступно в расширенной новой игре."
        steps = []
        for step in case["steps"]:
            zone = link(zone_names[step["zone"]]) if step["zone"] in zone_names else zone_label.get(step["zone"],step["zone"])
            condition = step.get("if_branch") or step.get("unless_branch") or ""
            detail = f" Условие — `{condition}`." if condition else ""
            steps.append(f"- **{title(step['title'])}**. {zone}. {title(step['body'])}{detail}")
            if step["kind"] not in ("note", "door"):
                puzzle = valid_name(title(step["title"])) + " · устройство"
                steps[-1] += f" {link(puzzle)}"
                note(vault, "04 Геймплей/Головоломки/"+puzzle, "interaction-"+step["id"], title(step["title"]),
                     f"{title(step['body'])}\n\nРежим `{step['kind']}`. Встроен в {link(name)}. После корректного действия расследование сохраняет `case_read_{step['id']}`.\n\n[[Основные механики]]",
                     tags=("puzzle",), sources=("after_silence/world/investigation_director.gd","after_silence/data/expeditions_0330.json" if case.get("expansion") else "after_silence/data/investigations.json"))
        branches = "\n".join(f"- **{title(b['title'])}**. {title(b['result'])} Флаг `case_choice_{b['id']}`." for b in case["branches"])
        owner = link(PEOPLE[case["owner"]][0]) if case["owner"] in PEOPLE else link("Вера")
        note(vault, "01 Сюжет/Главы/"+name, "case-"+case["id"], name,
             f"{title(case['intro'])}\n\n{requirement} Участники — {link('Вера')}, {owner}.\n\n## Ход дела\n\n" + "\n".join(steps) +
             "\n\n## Последствия\n\n" + (branches or f"Игра отмечает `case_done_{case['id']}`, сохраняет результат в истории и открывает следующий этап.") +
             "\n\n[[Основная история]] · [[Сюжетные развилки]]",
             tags=("chapter", "main-case" if before else "side-case"), sources=("after_silence/world/investigation_director.gd","after_silence/data/expeditions_0330.json" if case.get("expansion") else "after_silence/data/investigations.json"))
    for key, (name, description) in PEOPLE.items():
        appearances = [link(event_names[e["id"]]) for e in events if e["npc"] == key]
        hosted = [link(case_names[c["id"]]) for c in cases if c["owner"] == key]
        notes = f"{description}\n\n"
        if key == "vera":
            notes += "Требование к канону — её решения фиксируются в сохранении. Мотивы можно читать по поступкам. Полная биография в исходниках не установлена.\n\n"
            appearances = [link("Город без адресов"),link("Лента поверх бумаги"),link("Перед общей перекличкой"),link("Финалы")]
        if key in legacy_roles: notes += "У персонажа есть расписание и переходы между районами.\n\n"
        notes += "\n".join(f"- {appearance}" for appearance in appearances+hosted) + "\n\n[[Основная история]] · [[Финалы]]"
        folder = "02 Персонажи/" + ("Остальные персонажи/" if key not in ("vera","sonya") else "")
        note(vault,folder+name,"character-"+key,name,notes,tags=("character",),sources=("after_silence/story.gd","after_silence/data/npc_events.json","after_silence/data/npc_routines.json"))
    case_order = "\n".join(f"{i+1}. {link(event_names[event['id']])}" + "".join(f" · {link(case_names[c['id']])}" for c in cases if c["before"]==event["id"]) for i,event in enumerate(events))
    optional = "\n".join(f"- {link(case_names[c['id']])}" for c in cases if not c["before"])
    note(vault,"01 Сюжет/Основная история","story","Основная история",
         "Порядок встреч считывается из данных кампании. Расследования перечислены рядом со встречами, которые они открывают.\n\n"
         + case_order + "\n\n## Дополнительные дела\n\n"+optional+"\n\n[[Хронология]] · [[Сюжетные развилки]] · [[Финалы]]",
         tags=("story",),sources=("after_silence/data/npc_events.json","after_silence/data/investigations.json","after_silence/data/expeditions_0330.json"))
    return case_names,event_names,trial_names

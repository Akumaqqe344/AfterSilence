# Открытые проекты: исследование для 0.14

Проверено 15.11.2026. Ниже архитектурные ориентиры; это не список новых
установленных плагинов. Реализация остаётся собственной, внутри существующих
Game / WorldState / NPCs / SaveManager, без внешнего сервера и новых autoload.
Чужие музыку, текстуры, персонажей и полные игровые сцены не переносили.

| Проект | Полезные файлы / устройство | Применение и границы переноса |
|---|---|---|
| [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | addons/dialogue_manager/dialogue_manager.gd, example_balloon, docs/Using_Dialogue.md | Отделение условий и эффектов от показа ответа. Наш JSON, WorldState и тёплый пиксельный диалог вместо второго runtime; текущая ветка требует Godot 4.6+ |
| [Dialogic](https://github.com/dialogic-godot/dialogic) | Timelines, события, подсистемы runtime | Короткая реплика → игровое действие → последствия. Не импортировать его timeline/editor/autoload параллельно существующему director; документация текущей ветки указывает Godot 4.5+ |
| [Официальные демо Godot](https://github.com/godotengine/godot-demo-projects) | viewport/gui_in_3d, gui_3d.gd, SubViewport и контейнер | Настоящий игровой мир внутри собственного окна; для 2D переподключается существующий world, не копируется 3D-input/demo-камера |
| [GDQuest platformer](https://github.com/gdquest-demos/godot-3-beginner-2d-platformer) | Разделение actors, взаимодействий и сцены уровня | Запрошенный старый адрес перенаправляет на Godot 3. Это ориентир структуры, не совместимый Godot 4 addon. KinematicBody и API ввода нельзя переносить прямо; сохраняется Pechatai CharacterBody2D |
| [bitbrain gamejam](https://github.com/bitbrain/godot-gamejam) | godot/; IngameScene, SaveGame.gd/Persist, UserSettings.gd, theme.tres | Жизненный цикл меню/игры/паузы, отдельные настройки. Запрошенный godot-gamejam-template возвращает 404; рабочий проект называется godot-gamejam. Не заменять им наши слоты и глобальные менеджеры |
| [NPC Routine Scheduler](https://github.com/grgy078033/godot-simulation-plugins/tree/main/npc-routine-scheduler) | Отдельное расписание и исполнитель занятия | Использован существующий NPCStateController с суточными JSON-маршрутами; активное событие временно владеет участником. Второй scheduler не подключается |
| [Questify](https://github.com/frepiso/godot-questify) | QuestResource, objective active/completed, сигналы quest_objective_completed и quest_completed | Явные travel/observe/ready/running/decision/failure/suspended. Результаты хранятся в наших флагах; ресурсный граф и singleton не смешиваются с SaveManager |
| [RPG Dialog System](https://github.com/fabvarisco/godot-rpg-dialog-system) | addons/rpg_dialog_system/dialog_manager.gd, dialog_scene.gd, CanvasLayer, entries JSON | Портрет, печать с мгновенным раскрытием, локализованные данные. Сохраняются наш шрифт, маршруты фокуса и собственный Game-dialog; не устанавливать второй DialogManager |
| [gd-rhythm](https://github.com/scenent/gd-rhythm) | main.gd / note.gd, временное окно нажатия | Ритм E и видимый сигнал без чужого MP3; подробная ревизия в RESEARCH_0130_RU.md |
| [Vision Cone 2D](https://github.com/d-bucur/godot-vision-cone) | addons/vision_cone_2d, лучи Physics2D | Отдельный движущийся гость, ограниченный стенами сектор, накопление тревоги. Используются наши world.sees/walkable |
| [Tower Defense Godot 4](https://github.com/quiver-dev/tower-defense-godot4) | entities/state_machine.gd, state.gd, hit states | Волны, предупреждение, защита и восстановление после ошибки. Башни, оружие и LFS-ассеты не нужны |
| [Ali0600 RPG Template](https://github.com/Ali0600/rpg-template) | Соединённые дверями карты, условия проходов и действия NPC | Сохранён реальный маршрут через мир; одинаковые guards у основных и дополнительных дверей. Не переносить его карту, фонари, пошаговые бои и генерацию спрайтов |

По запросам RPG minigame / dialogue / NPC schedule / quest state machine /
rhythm / stealth / escort отобраны соответствующие строки таблицы. Поиск escort
не дал основания подключать отдельный большой framework: следование реализовано
через уже действующий AStar и CharacterBody2D. LLM-миссии и серверные диалоги
не подходят офлайн-истории, фиксированным последствиям и воспроизводимым сейвам.

Новые зависимости: нет. Совместимость проверялась именно на локальном Godot
4.7.2, а не предполагалась по названию найденного проекта. Прежние лицензии
и исходники основы сохранены. Таблица описывает идеи и адаптацию, не заявляет
дословное заимствование исходного кода перечисленных авторов.

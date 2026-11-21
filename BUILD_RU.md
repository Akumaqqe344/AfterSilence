# Сборка After Silence для Windows и Linux

Нужны редактор **Godot 4.7.2 Standard**, официальный комплект **Export Templates** той же версии и Python 3.10+. Установите шаблоны в Godot через **Editor → Manage Export Templates**. Оба пресета уже в корне репозитория.

Из корня проекта:

| Что собрать | Команда |
| --- | --- |
| Windows x64 | `python tools/build_desktop.py windows --godot "C:\Games\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"` |
| Linux x64 | `python3 tools/build_desktop.py linux --godot godot` |
| Обе платформы на одной машине | `python tools/build_desktop.py all --godot /путь/к/godot` |

Если Godot доступен через `PATH` под именем `godot`, параметр `--godot` можно опустить. Windows ZIP появится в `after_silence/build/windows`, Linux tar.gz — в `after_silence/build/linux`. Архив Linux сохраняет право запуска. Пресеты доступны и в **Project → Export**.

Для запуска на Linux без экспортного шаблона соберите пак ресурсов командой `python3 tools/build_desktop.py pack`. Затем запустите его с установленным Godot той же версии:

```sh
godot --main-pack after_silence/build/pack/AfterSilence.pck
```

Пак ресурсов требует Godot на целевой машине. Самостоятельный Linux-бинарник собирает цель `linux`.

[Godot 4.7.2 и шаблоны](https://godotengine.org/download/archive/4.7.2-stable/)

"""Initialize a separate Obsidian vault without overwriting its notes."""
from argparse import ArgumentParser
from pathlib import Path
import json

from build_vault import build_campaign, write_once
from sync_vault import synchronize
from vault_sections import fill_sections

BASE = """filters:
  and:
    - 'file.inFolder("_Generated")'
    - 'task_id != null'
properties:
  note.title:
    displayName: "Задача"
  note.priority:
    displayName: "Приоритет"
  note.status:
    displayName: "Статус"
  note.system:
    displayName: "Система"
views:
  - type: table
    name: "Приоритетная работа"
    filters:
      and:
        - 'status != "Проверено"'
    sort:
      - property: note.priority
        direction: ASC
    order:
      - file.name
      - note.title
      - note.priority
      - note.status
      - note.system
  - type: table
    name: "Проверено"
    filters:
      and:
        - 'status == "Проверено"'
    order:
      - file.name
      - note.title
      - note.priority
      - note.system
  - type: table
    name: "Все задачи"
    groupBy:
      property: note.status
      direction: ASC
    order:
      - file.name
      - note.title
      - note.priority
      - note.status
      - note.system
"""
CORE = ["file-explorer","global-search","switcher","graph","backlink","outgoing-link",
        "tag-pane","page-preview","templates","file-recovery","properties","bases"]


def main():
    args = ArgumentParser(description=__doc__)
    args.add_argument("--repo",required=True,type=Path)
    args.add_argument("--vault",required=True,type=Path)
    args.add_argument("--evidence",type=Path)
    opt = args.parse_args()
    repo,vault = opt.repo.resolve(),opt.vault.resolve()
    if vault.is_relative_to(repo):
        raise ValueError("The vault must be outside the game repository")
    fill_sections(repo,vault,*build_campaign(repo,vault))
    write_once(vault/"06 Задачи/Задачи.base",BASE)
    write_once(vault/".obsidian/app.json",json.dumps({"alwaysUpdateLinks":True,"newLinkFormat":"shortest"},indent=2))
    write_once(vault/".obsidian/core-plugins.json",json.dumps({key:True for key in CORE},indent=2))
    write_once(vault/".obsidian/templates.json",json.dumps({"folder":"_Templates"}))
    write_once(vault/".obsidian/graph.json",json.dumps({
        "collapse-filter":True,"showTags":False,"showAttachments":False,"hideUnresolved":True,
        "colorGroups":[
            {"query":"tag:#chapter","color":{"a":1,"rgb":12955174}},
            {"query":"tag:#character","color":{"a":1,"rgb":7786888}},
            {"query":"tag:#minigame","color":{"a":1,"rgb":8297437}},
            {"query":"tag:#task-record","color":{"a":1,"rgb":14064464}}
        ]
    },ensure_ascii=False,indent=2))
    workspace = {
        "main":{"id":"090-main","type":"split","direction":"vertical","children":[
            {"id":"090-tabs","type":"tabs","children":[
                {"id":"090-dashboard","type":"leaf","state":{"type":"markdown","state":{"file":"00 Главная/Dashboard.md","mode":"preview"},"title":"Dashboard"}}]}]},
        "left":{"id":"090-left","type":"split","direction":"horizontal","width":250,"children":[
            {"id":"090-left-tabs","type":"tabs","children":[{"id":"090-explorer","type":"leaf","state":{"type":"file-explorer","state":{}}}]}]},
        "right":{"id":"090-right","type":"split","direction":"horizontal","width":245,"collapsed":True,"children":[]},
        "active":"090-dashboard"
    }
    write_once(vault/".obsidian/workspace.json",json.dumps(workspace,ensure_ascii=False,indent=2))
    scripts = vault/"05 Разработка"/"Синхронизация"
    for name in ("sync_vault.py","build_vault.py","vault_sections.py"):
        write_once(scripts/name,(Path(__file__).parent/name).read_text(encoding="utf-8"))
    write_once(scripts/"Запуск.md","""# Синхронизация

Требуются Python 3.10+ и Git. Используйте PowerShell из папки этого инструмента.

```powershell
python sync_vault.py --repo "C:\\путь\\AfterSilence" --vault "C:\\путь\\After Silence — Development"
python sync_vault.py --repo "C:\\путь\\AfterSilence" --vault "C:\\путь\\After Silence — Development" --apply
```

Первая команда показывает изменения. Вторая записывает только `_Generated` и резерв изменившихся файлов в `_SyncBackups`. Обычные заметки редактируйте свободно. Параметр `--evidence` принимает JSON со снимком QA для текущего коммита. Отчёты должны лежать рядом с JSON и совпадать по SHA-256. Без доказательств статусы переходят на «Ожидает проверки», если поменялся код.

```json
{"commit":"полный хеш коммита","suites":{"archive":{"report":"archive.json","sha256":"хеш отчёта","passed":173,"failed":0,"summary":"Описание проверки"}}}
```

[[Dashboard]] · [[Журнал синхронизации]]""")
    result = synchronize(repo,vault,opt.evidence,True)
    print(json.dumps({"notes":len(list(vault.rglob("*.md"))), **result},ensure_ascii=False))


if __name__=="__main__": main()

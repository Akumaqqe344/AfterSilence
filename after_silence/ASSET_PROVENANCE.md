# Графика, звук и лицензии

База проекта: Michael Bertocchi / dupot.org, Little Adventure, LGPL-2.1, коммит 37209a3b6a676f7383ca33886e3e8398ba915585. Исходные уведомления, LICENSE, старые сцены и исходники сохранены. Отдельных подтверждений происхождения каждой старой картинки в репозитории нет; это не выдаётся за независимый аудит. В активных картах и персонажах нового эпизода старые изображения заменены.

Новые растровые ассеты созданы встроенным imagegen для этого проекта. CLI/API-ключи не использовались. Они распространяются в составе LGPL-2.1 проекта. Источники и итоговые файлы находятся в after_silence/assets; pack_hero.ps1 и pack_world.ps1 выполняют техническую нарезку, нормализацию размера, ближайшую выборку и квантование палитры. Для их воспроизведения используйте Windows PowerShell 5.1 (powershell.exe): в PowerShell 7 System.Drawing требует другую ссылку сборки.

| Файл | Назначение | Источник |
|---|---|---|
| vera-source.png → vera.png | 4 направления × 4 кадра Веры, 32×48 | imagegen, exec-a323d9ce-05b1-49b3-8067-7b83fdea6581 |
| npc-source.png → nadia/lev/mara/pavel/sonya.png | пять человеческих NPC, по 4 кадра | imagegen, exec-699bf161-a855-4503-939a-9e89a5027650 |
| environment-source.png → cottage/townhouse/library/well/oak/fir/flowers/rock.png | единый набор окружения | imagegen, exec-34b06259-7bca-4342-8582-0951880ae620 |
| world/prop.gd, ground_detail.gd | книги, реле, часы, следы, вода, пол | собственная процедурная графика |
| core/audio_manager.gd | фон и короткие звуковые сигналы | собственный синтез PCM, внешних сэмплов нет |
| интерфейс | Segoe UI / DejaVu Sans через SystemFont | установленный системный шрифт, файлы не распространяются |

Godot 4.7.2: MIT, GODOT_LICENSE.txt и GODOT_COPYRIGHT.txt в third_party. Сохранившийся исходный Pixel Operator: Jayvee Enaguas, CC0, common/themes/fonts/LICENSE-PixelOperator-CC0.txt. Ресурсы Witch's Heart и других коммерческих игр не использовались.

## Промпт Веры

Production sprite sheet for an original cozy mysterious RPG AFTER SILENCE. Exact 4x4 same young adult woman. Vera: short dark aubergine bob, coral red scarf, midnight blue investigator coat, cream shirt, charcoal trousers, brown boots, brass key brooch. Rows DOWN, UP, LEFT, RIGHT; columns neutral, left foot, neutral, right foot. Transparent background, 32x48 logical pixel frames, 16 colors, hard one-pixel outlines, no labels, shadows or scenery. Consistent identity, size and foot baseline.

## Промпт NPC

Create ONE production pixel-art sprite atlas for original mystery RPG AFTER SILENCE. TRANSPARENT background. Exact regular grid FIVE columns and FOUR rows, 20 isolated full body HUMAN sprites. Columns are five different named characters; rows are four front-facing walk cycle frames (neutral, left step, neutral, right step). Column1 Nadia middle-aged female physician with silver hair bun, sage coat cream apron small burgundy medical bag. Column2 Lev middle-aged sturdy male mechanic brown hair mustache ochre work jacket navy trousers toolbelt. Column3 Mara elderly female archivist spectacles gray braid plum cardigan teal skirt book tucked under arm. Column4 Pavel middle-aged male mayor slick brown hair charcoal waistcoat cream shirt maroon tie dark trousers. Column5 Sonya young adult woman pale ash blonde short hair muted lavender hooded raincoat brown boots. All ordinary humans, no animal features, no hats or weapons. Same proportions and grounded detailed pixel style as an original 32x48 logical-pixel overhead RPG sprite: full figure fits 28x40 logical pixels, dark one pixel outline, 16 color shared restrained palette sage charcoal cream aubergine muted coral, expressive large readable faces, three-quarter overhead slight visible head top. Identical standing height and foot baseline within all cells; equal generous transparent cell padding. Strict sharp pixel clusters, NO antialiasing, NO gradients, NO text, labels, gridlines, background, cast shadows. Each column must keep identity and clothing exactly identical in all four rows. Atlas aspect5:4. This is a coherent game-ready character animation sprite sheet, not an illustration.

## Промпт окружения

ONE game-ready environment sprite ATLAS for original 2D overhead mystery RPG AFTER SILENCE. Exact FOUR columns TWO rows = EIGHT assets each centered alone in equal cells, generous transparent padding, no overlapping. Row1 columns1-4: 1 cozy plaster and dark timber cottage sage green tiled pitched roof front door golden windows stone foundation; 2 same architectural village style but burgundy tiled roof two story cottage; 3 abandoned village library building teal slate roof tall arched front door book sign no readable text; 4 old sandstone well with copper canopy and small hand crank. Row2 columns1-4: 1 broad lush sage-green oak with gnarled brown trunk; 2 tall dark teal fir with readable layered boughs; 3 small patch of fern shrubs and white flowers; 4 mossy gray rock formation. All objects seen in a consistent three-quarter overhead orthographic top-down RPG perspective, like 16-bit handcrafted premium indie pixel art, NOT isometric. Clearly defined chunky pixel clusters, one logical pixel dark outlines, restrained sage olive muted ochre cream aubergine palette, warm mysterious cozy mood. Roof tiles, timber beams and stonework carefully readable; trees organic shape. No ground bases, NO background, no scenery, NO characters, NO labels, NO gridlines, NO text. Genuine alpha transparency. Match 32x48-pixel human sprites: houses about 160x144 logical pixels, trees about64x96, props smaller. Atlas square cells, overall aspect2:1, consistent hard nearest-neighbor pixels no smooth gradients or antialiasing.

## 0.29.0 • Панорама и новые атласы

- `dusk.png` — оригинальная иллюстрация ImageGen для заставки, приведённая к 640×360.
- `vera_idle.png` — новые фазы покоя на основе игрового спрайта Веры. Восемь листов NPC выпечены из `npc_appearance.gd`.
- Фонарь, флажки, детали земли, мощение, лабиринт и преследователь собраны из новых пиксельных рисунков. Нативные `SpriteFrames` задают кадры и их длительность.
- Демонстрации Skeleton2D, GDbot, Pixel Cutout Rig, PixelLight, TweenFX, Tween Composer, Weather FX Free, SpriteVFX, Cozy Pixel и Pixelorama изучены как технические примеры. В сборке использованы собственные ресурсы.

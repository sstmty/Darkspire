# Darkspire

Пиксельная сюжетная стратегия в духе классических «Героев»: карта мира, пошаговые
тактические битвы, найм войск, диалоги и сохранения. Мрачное феодальное фэнтези
о войне великих домов за трон королевства Эйрвальд. Мир, персонажи и графика
оригинальные.

**Глава I: Пепел Сокола.** Дом Карр вероломно взял Соколиный Утёс. Юный Кайрен Вейл
собирает верных людей, освобождает Ольховку и сира Бренну, прорывается через
Серую реку и штурмует крепость Чёрный Брод.

## Что внутри

| Папка | Что там |
| --- | --- |
| `game/` | Проект Godot 4.5 (GDScript). Открывается в редакторе Godot как обычный проект. |
| `game/scripts/screens/` | Экраны: меню, заставка, карта мира, битва, финал. |
| `game/scripts/data.gd` | Юниты, армии врагов, события карты и все тексты сюжета. |
| `game/data/chapter1.txt` | Карта главы I в виде ASCII (легенда в `tools/gen_map.py`). |
| `game/assets/` | Спрайты, тайлы, портреты, фоны битв. Всё сгенерировано скриптами из `tools/`. |
| `tools/` | Python-генераторы пиксельной графики и карты. |

Графика рисуется кодом (`tools/gen_units.py`, `tools/gen_world.py`), поэтому любой юнит
можно перекрасить или перерисовать и пересобрать за секунду:

```bash
pip install pillow
python3 tools/gen_units.py   # 9 юнитов × 5 анимаций: покой, ходьба, атака, ранение, смерть
python3 tools/gen_world.py   # тайлы, замки, деревья, портреты, фоны битв, иконки
python3 tools/gen_map.py     # карта главы I + проверка достижимости
```

Звуки и музыка синтезируются при запуске (`game/scripts/sfx.gd`), отдельных аудиофайлов нет.

## Сборка

Нужен [Godot 4.5](https://godotengine.org/download) и шаблоны экспорта
(в редакторе: Editor → Manage Export Templates).

```bash
cd game
godot --headless --import
godot --headless --export-release "Windows" ../build/windows/Darkspire.exe
godot --headless --export-release "Linux"   ../build/linux/Darkspire.x86_64
```

Ресурсы вшиваются в исполняемый файл, поэтому игра это один файл плюс README.

Автосборка: при пуше тега `v*` (например `git tag v0.1.0 && git push --tags`)
GitHub Actions соберёт zip для Windows и Linux и приложит их к релизу
(`.github/workflows/build.yml`).

## Раздача со своего сервера

1. Положите `Darkspire-<версия>-windows.zip` и `-linux.zip` в папку, которую отдаёт веб-сервер
   (например `/var/www/darkspire/`).
2. Торрент с вашим сервером в роли вечного сида через веб-сид (BEP 19):

   ```bash
   sudo apt install mktorrent
   mktorrent -a udp://tracker.opentrackr.org:1337/announce \
             -w https://ВАШ-ДОМЕН/darkspire/Darkspire-0.1.0-windows.zip \
             -o Darkspire-0.1.0-windows.torrent Darkspire-0.1.0-windows.zip
   ```

   Клиенты будут качать с вашего сервера по HTTP, даже если других раздающих нет.
3. Рядом выложите `SHA256SUMS.txt`, чтобы игроки могли проверить архив.

## Отладка

* `godot -- --autotest` прогоняет главу ботом: он ходит по карте, сражается в автобою
  и печатает итог каждой битвы.
* `godot -- --shot battle out.png bridge 5` делает скриншот битвы через 5 секунд.

## Лицензии

Шрифты Press Start 2P и Tiny5 распространяются по SIL Open Font License 1.1.
Движок Godot распространяется по лицензии MIT.

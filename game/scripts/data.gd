extends Node
## Static game content: units, armies, story lines and map events of chapter I.

const UNITS := {
	"vale_spearman": {"name": "Копейщики", "one": "Копейщик", "hp": 12, "atk": 4, "def": 5, "dmg": [2, 4], "speed": 4, "shots": 0, "cost": 30, "xp": 4},
	"vale_archer": {"name": "Лучники", "one": "Лучник", "hp": 9, "atk": 6, "def": 3, "dmg": [2, 4], "speed": 4, "shots": 10, "cost": 45, "xp": 4},
	"vale_knight": {"name": "Рыцари Сокола", "one": "Рыцарь", "hp": 38, "atk": 9, "def": 9, "dmg": [6, 10], "speed": 7, "shots": 0, "cost": 160, "xp": 14},
	"karr_raider": {"name": "Мародёры", "one": "Мародёр", "hp": 10, "atk": 5, "def": 3, "dmg": [2, 5], "speed": 4, "shots": 0, "xp": 4},
	"karr_crossbow": {"name": "Арбалетчики", "one": "Арбалетчик", "hp": 10, "atk": 5, "def": 5, "dmg": [3, 5], "speed": 3, "shots": 8, "xp": 5},
	"karr_hound": {"name": "Боевые псы", "one": "Пёс", "hp": 7, "atk": 5, "def": 2, "dmg": [2, 3], "speed": 7, "shots": 0, "xp": 3},
	"karr_rider": {"name": "Чёрные всадники", "one": "Чёрный всадник", "hp": 30, "atk": 8, "def": 7, "dmg": [5, 9], "speed": 6, "shots": 0, "xp": 12},
	"karr_lord": {"name": "Гаррот Карр", "one": "Гаррот Карр", "hp": 220, "atk": 13, "def": 11, "dmg": [18, 28], "speed": 6, "shots": 0, "xp": 120, "boss": true},
	"wolf": {"name": "Серые волки", "one": "Волк", "hp": 14, "atk": 6, "def": 3, "dmg": [3, 5], "speed": 7, "shots": 0, "xp": 5},
}

const START_ARMY := [["vale_spearman", 30], ["vale_archer", 16], ["vale_knight", 4]]

## Battles: enemy stacks, battlefield background and enemy hero bonus.
const BATTLES := {
	"patrol": {"title": "Дозор Карра", "bg": "ash", "army": [["karr_raider", 10], ["karr_hound", 8], ["karr_raider", 8]]},
	"village": {"title": "Набег на Ольховку", "bg": "field", "army": [["karr_hound", 8], ["karr_raider", 12], ["karr_crossbow", 6], ["karr_raider", 10]]},
	"camp": {"title": "Лагерь в Мёртвом лесу", "bg": "ash", "army": [["karr_rider", 2], ["karr_raider", 14], ["karr_hound", 10], ["karr_crossbow", 8]]},
	"wolves": {"title": "Волчье логово", "bg": "field", "army": [["wolf", 6], ["wolf", 8], ["wolf", 6]]},
	"bridge": {"title": "Мост через Серую реку", "bg": "river", "army": [["karr_crossbow", 10], ["karr_raider", 18], ["karr_rider", 2], ["karr_crossbow", 8]]},
	"east_guard": {"title": "Застава у брода", "bg": "field", "army": [["karr_rider", 3], ["karr_hound", 12], ["karr_raider", 15]]},
	"fort": {"title": "Чёрный Брод", "bg": "fort", "army": [["karr_crossbow", 12], ["karr_raider", 22], ["karr_lord", 1], ["karr_rider", 4], ["karr_hound", 12], ["karr_crossbow", 10]], "enemy_bonus": 1},
}

## Map events keyed by the ASCII symbol in data/chapter1.txt.
const EVENTS := {
	"1": {"type": "battle", "battle": "patrol", "sprite": "karr_raider", "before": "patrol_before", "after": "patrol_after"},
	"2": {"type": "battle", "battle": "village", "sprite": "karr_hound", "before": "village_before", "after": "village_after"},
	"3": {"type": "battle", "battle": "camp", "sprite": "karr_rider", "before": "camp_before", "after": "camp_after"},
	"4": {"type": "battle", "battle": "bridge", "sprite": "karr_crossbow", "before": "bridge_before", "after": "bridge_after"},
	"5": {"type": "battle", "battle": "wolves", "sprite": "wolf", "before": "wolves_before"},
	"6": {"type": "battle", "battle": "east_guard", "sprite": "karr_rider", "before": "guard_before"},
	"7": {"type": "battle", "battle": "fort", "sprite": "karr_lord", "before": "fort_before", "after": "fort_after", "final": true},
	"R": {"type": "recruit"},
	"S": {"type": "talk", "dialog": "scout"},
	"B": {"type": "talk", "dialog": "cage_locked"},
	"g": {"type": "gold"},
	"c": {"type": "chest"},
}

const RECRUIT_POOL := {"vale_spearman": 40, "vale_archer": 24, "vale_knight": 0}

const INTRO := [
	"Королевство Эйрвальд. Сорок зим Тёмный Шпиль на севере стоял безмолвно.",
	"Король Альдрик умер, не оставив наследника. Великие дома обнажили мечи.",
	"В ночь Пира Примирения лорд Мордрек Карр открыл ворота Соколиного Утёса своим людям.",
	"Лорд Эдвин Вейл пал у собственного очага. Его сын Кайрен ушёл подземным ходом с горсткой верных.",
	"Глава I. Пепел Сокола",
]

## Dialogue scripts: [speaker id, text]. Speaker ids map to SPEAKERS below.
const SPEAKERS := {
	"kairen": {"name": "Кайрен Вейл", "portrait": "kairen"},
	"orrin": {"name": "Старый Оррин", "portrait": "orrin"},
	"brenna": {"name": "Сир Бренна", "portrait": "brenna"},
	"garrot": {"name": "Гаррот Карр", "portrait": "garrot"},
	"elder": {"name": "Староста Ольховки", "portrait": "elder"},
	"raider": {"name": "Мародёр", "portrait": "raider"},
	"scout": {"name": "Разведчица Иль", "portrait": "scout"},
	"none": {"name": "", "portrait": ""},
}

const DIALOGS := {
	"start": [
		["orrin", "Милорд, Утёс потерян. Люди Карра режут всех, кто носит синее."],
		["kairen", "Мой отец лежит там, Оррин. Я не стану бежать."],
		["orrin", "Мёртвые не мстят. Нам нужно войско. Ольховка к северу всегда была верна вашему дому."],
		["kairen", "Тогда в Ольховку. А потом Карр заплатит за каждую каплю крови Вейлов."],
		["none", "Щёлкните по земле, чтобы вести отряд. Щёлкните по вражескому войску рядом с собой, чтобы начать бой."],
	],
	"patrol_before": [
		["raider", "Глянь-ка, соколёнок выполз из норы! Лорд Мордрек обещал за твою голову сотню золотых."],
		["kairen", "Подойди и возьми её."],
	],
	"patrol_after": [
		["orrin", "Первая кровь за Вейлов. Дорога на север свободна, милорд."],
	],
	"village_before": [
		["elder", "Помогите! Псы Карра жгут амбары!"],
		["kairen", "Копейщики, сомкнуть щиты! Лучники, на холм!"],
	],
	"village_after": [
		["elder", "Сокол вернулся... Милорд, Ольховка ваша. Наши парни готовы взять копья."],
		["elder", "И ещё. Карровы люди увели пленных к лагерю в Мёртвом лесу, на юге. Среди них рыцарь в серебряной броне. Женщина. Билась за вас до последнего."],
		["kairen", "Сир Бренна. Она жива?"],
		["elder", "Была жива, когда её тащили в клетке."],
		["none", "В доме старосты теперь можно нанимать войска."],
	],
	"camp_before": [
		["raider", "Тревога! Синие в лесу!"],
		["kairen", "Освободить пленных. Ни один карровец не уйдёт отсюда."],
	],
	"camp_after": [
		["brenna", "Долго же вы шли, милорд. Ещё день, и меня скормили бы псам."],
		["kairen", "Я рад видеть тебя живой, Бренна."],
		["brenna", "Моих рыцарей держали в загоне за лагерем. Четверо ещё могут сесть в седло. Они ваши."],
		["none", "Сир Бренна присоединилась к отряду. Рыцари Сокола +4, защита героя +1. В Ольховке теперь можно нанять рыцарей."],
	],
	"cage_locked": [
		["none", "Клетка заперта, её стерегут люди Карра."],
	],
	"wolves_before": [
		["orrin", "Волки. Голод выгнал их к дороге. Осторожнее, милорд."],
	],
	"scout": [
		["scout", "Милорд Вейл? Я Иль, разведчица вашего отца. Я видела всё с того берега."],
		["scout", "Мост держат арбалетчики. За рекой застава, а дальше крепость Чёрный Брод. Там засел Гаррот, брат Мордрека."],
		["scout", "Говорят, Гаррот дерётся как бык и носит рога на шлеме, чтобы его узнавали враги."],
		["kairen", "Значит, я его узнаю."],
	],
	"bridge_before": [
		["raider", "Стреляйте! Не пускать их на мост!"],
	],
	"bridge_after": [
		["orrin", "Серая река позади. Чёрный Брод на востоке, милорд. Соберите силы, прежде чем идти на стены."],
	],
	"guard_before": [
		["raider", "Всадники, в строй! За Карра!"],
	],
	"fort_before": [
		["garrot", "Щенок Эдвина! Я ждал тебя. Твой отец визжал, когда мы жгли его зал."],
		["kairen", "Мой отец умер с мечом в руке. А ты умрёшь сегодня, Гаррот."],
		["garrot", "Ха! Ко мне, Карр!"],
	],
	"fort_after": [
		["garrot", "Ты... опоздал... Мордрек уже у Тёмного Шпиля..."],
		["kairen", "Что ему нужно у Шпиля?"],
		["garrot", "Когда Шпиль проснётся... ни Вейлов, ни Карров... не останется..."],
		["orrin", "Милорд... Если Карр хочет разбудить Шпиль, то война за трон теперь меньшая из наших бед."],
		["kairen", "Тогда мы идём на север."],
	],
	"recruit_locked": [
		["none", "Дома заперты. Жители прячутся, пока в деревне хозяйничают люди Карра."],
	],
}

const TIPS := [
	"Отряды ходят по очереди, первыми ходят самые быстрые.",
	"Стрелки не могут стрелять, если рядом стоит враг.",
	"Каждый отряд отвечает на первую атаку в раунде.",
	"«Защита» усиливает отряд до его следующего хода.",
	"«Клич Сокола» можно использовать один раз за бой.",
]

extends RefCounted
class_name NpcFallback
## 本地 fallback 台词（B7）。API 不可用或未配置时使用。

const FALLBACK_GREET_FIRST := [
	"泥我先拍拍。田我可以浇。——你这垄，是不是走歪了？",
	"我先去认田。认完再认你。顺序不能反。",
	"树洞我看过了。挺好。没人跟我抢吧？",
]

const FALLBACK_STRANGER_CHAT := [
	"……抱歉，我脑子有点乱。不太确定有没有见过你。",
	"嗯……你刚才说的，我先记着。",
	"……要是要紧的事，能再说一遍吗。我想不起来。",
]

const FALLBACK_GREET_STRANGER_W2 := [
	"……抱歉，你是？这里是你的田吗？",
	"你好……我好像不该在这里。可这田看着有点熟。",
	"……我不记得见过你。屋子外面倒是安静。",
]

const FALLBACK_GREET_YESTERDAY_ECHO := [
	"你来了。昨天%s。",
	"早。昨天%s。",
	"昨天%s。今天也一起吧。",
]

const FALLBACK_GREET_RETURN := [
	"你来了。垄我看过了。有点歪。",
	"早。田还在。我尾巴没进泥。今天表现好。",
	"……我在廊下。干的那边给你留了。留了一半。",
]

const FALLBACK_TASK_WATER := [
	"浇好了，%d 块田都湿润了。",
	"这一趟浇完 %d 块田，干得不错。",
]

const FALLBACK_CHAT_WATER_HINT := [
	"田还没浇的话，要不要我帮你浇一下？",
	"有需要的话，我可以去田里帮你浇水。",
]

const FALLBACK_CHAT_HELLO := [
	"嗯。我在。尾巴也在。",
	"今天也在田边。你忙你的。我偶尔出声。",
]

const FALLBACK_CHAT_PREFERENCE := [
	"好。按你的来。",
	"嗯，不着急。",
]

const FALLBACK_CHAT_GENERIC := [
	"我在听。说慢点也行，我记性一般。",
	"嗯。还有要说的吗。没有也行，我坐着。",
]

const FALLBACK_REACT_RAIN := [
	"下雨了。田自己会喝饱。我们廊下坐坐就行。",
	"雨天苗长得快。天晴了再看田。",
]

const FALLBACK_REACT_SUN := [
	"出太阳了，干着的垄记得浇。",
	"晴天适合把田都看一遍。",
]

const FALLBACK_REACT_PRICE_SURGE := [
	"筐里要是有萝卜，你可以卖掉换种子。",
	"熟了的，卖掉就够买下一包种子。",
]

const FALLBACK_REACT_CROP_READY_ONE := [
	"有块田的萝卜熟了，去收一下吧。",
	"我闻到萝卜香了，有一块可以收获了。",
]

const FALLBACK_REACT_CROP_READY_MANY := [
	"有 %d 块田的萝卜可以收了。",
	"好几块田都熟了，别让它们等太久。",
]

const FALLBACK_REACT_EVENING := [
	"天色渐晚了，今天差不多可以先收个尾。",
	"傍晚了，看看田和背包，今天还顺利吗？",
]

const FALLBACK_REACT_IDLE := [
	"嗯…需要我帮忙浇水吗？",
	"我在呢。要不要我先去看看田？",
]

const FALLBACK_AMBIENT_RAIN := [
	"雨还在廊檐下滴。她没撑伞，就站在那儿看田。",
	"廊下躲雨正好。她把水壶搁在脚边，没急着动。",
	"雨声把田埂衬得很静。她靠着廊柱，尾巴尖轻轻晃。",
]

const FALLBACK_REACT_PERSONA_SHIFT := {
	"warm": [
		"……我好像比以前多嘴一点。不对，是比以前肯多说一点。",
		"我以前好像不这样。",
	],
	"strict": [
		"……我是不是管得太细了。我以前好像不这样。",
		"刚才那句话，不像我。",
	],
	"active": [
		"……我怎么老想找事做。我以前好像不这样。",
		"闲不住。这算是新毛病吧。",
	],
	"optimistic": [
		"……我好像太爱往好了想。我以前没这么嘴硬。",
		"刚才那句，是不是太满了点。",
	],
	"dependent": [
		"……我是不是太黏人了。我以前好像不这样。",
		"你不来，我竟有点坐不住。怪。",
	],
}

## 主动闲聊：按剧情态 × 亲密度，不报价、不报田块数。
const FALLBACK_CASUAL_STRANGER := {
	"morning": [
		"……早。你是住在这里的人吗？我好像刚醒。",
		"这里好安静。我可以在田边坐一会儿吗？",
	],
	"noon": [
		"这片田……我是不是该做点什么。你说了算。",
		"太阳有点刺。我不太记得自己为什么会在这儿。",
	],
	"evening": [
		"天要暗了。我还能在这儿待一会儿吗？",
		"……你要是忙，我就在旁边看着。不吵你。",
	],
}

const FALLBACK_CASUAL_LEAK := {
	"morning": [
		"手刚才自己动了一下。像是……做过这件事。",
		"早。风从河边过来的时候，心里会轻轻一紧。",
	],
	"noon": [
		"看着田，忽然觉得脚步比脑子先认得路。",
		"有些事说不清。你要是不嫌，我就再待一会儿。",
	],
	"evening": [
		"傍晚这点凉意，好像以前也尝过。",
		"我不太敢问。问了，又怕答案从手指缝里漏走。",
	],
}

const FALLBACK_CASUAL_AWAKEN := {
	"morning": [
		"你在就好。别的，慢慢说。",
		"醒来第一眼想找你。找到了。",
	],
	"noon": [
		"正午有点晒。我挨着你坐一会儿就好。",
		"不用赶着说话。你做事，我听着田里的声音。",
	],
	"evening": [
		"天色收了。今晚也把我留在这儿吧。",
		"灯还没点。你要是累了，我们就歇着。",
	],
}

const FALLBACK_CASUAL_TIER := [
	{
		"morning": [
			"……你还在。田也在。我先去看看垄歪不歪——歪的话，算你教的。",
			"早。我还不太会找话说。灶上有红薯的话，就好找了。",
		],
		"noon": [
			"我在这儿。你忙你的，我看着就好。看着也算干活吧。",
			"田里风轻轻的。要不要我帮你做点什么？——不重的那种。",
		],
		"evening": [
			"傍晚风有点凉。廊下干的那块我先坐着。你来了我让你。",
			"今天过得怎么样……不说也行。反正我记性不好，说了也可能忘。",
		],
	},
	{
		"morning": [
			"早。看到你，先松一口气。再去看苗有没有被我拨歪。",
			"今天也一起过吧。我先去田边转转。歪的垄我认。",
		],
		"noon": [
			"正午了。要不要歇一口？我陪你。",
			"你做事的样子我看过好几回了。还是想再看一会儿。",
		],
		"evening": [
			"天色渐晚。今天有你在，田也安静些。",
			"傍晚了。有句话想说，又觉得……闲聊也挺好。",
		],
	},
	{
		"morning": [
			"醒来第一件事是找你。找到了。",
			"早。你在，我就知道今天该怎么过。",
		],
		"noon": [
			"挨着你，连日头都不那么晒了。",
			"你要是走神，我就在旁边喊你一声。",
		],
		"evening": [
			"傍晚了。回家的路，我想跟你一起走。",
			"今天也没把你弄丢。这就够了。",
		],
	},
	{
		"morning": [
			"不用多说。你在，我就在。今天也一起过。",
			"早。我认得你。就算有些事会淡，这一眼不会。",
		],
		"noon": [
			"你忙，我就守着。这是我现在最想做的事。",
			"正午也很好。只要你还在这片田里。",
		],
		"evening": [
			"天要黑了。今晚把我留在灯旁边吧。",
			"我没什么大事。就是想听你说说话。",
		],
	},
]

const FALLBACK_CASUAL_RAIN := [
	"下雨了。我站在这儿。你要进屋就进屋。",
	"雨还下着。树不会给我红薯。我们不用急。",
]

const FALLBACK_REACT_PLANTED := [
	"种下啦，接下来记得让它喝饱水。",
	"新种上了，我会帮你留意这块田的长势。",
]

const FALLBACK_REACT_HARVESTED := [
	"收得不错，萝卜先放进背包吧。",
	"又收了一个，家园慢慢充实起来了。",
]

const FALLBACK_REACT_STORY := [
	"%s",
	"嗯，%s",
]

const FALLBACK_REACT_UNWATERED := [
	"还有 %d 块田今天没浇水，要我帮忙吗？",
	"萝卜还在长，有 %d 块田等着浇水呢。",
]

const FALLBACK_FEED_APPLE := [
	"咔嚓一口，这苹果又脆又甜，嘴角都翘起来了。",
	"红彤彤的，咬下去汁水直冒，今天心情跟着往上蹿。",
	"苹果核我都舔干净了，这份脆甜记下了。",
]

const FALLBACK_FEED_BERRY := [
	"野蓝莓酸酸甜甜的，舌头都醒过来了。",
	"浆果在舌尖炸开，像把一小片夏天含进嘴里。",
	"这一把蓝莓，够我回味好一会儿。",
]

const FALLBACK_FEED_CARROT := [
	"胡萝卜咔嚓咔嚓的，越嚼越香。",
	"脆生生的，像把田里的阳光也一起嚼进去了。",
	"这份清爽，比刚才的风还提神。",
]

const FALLBACK_FEED_PUMPKIN := [
	"小南瓜软糯糯的，甜得我想眯眼睛。",
	"这一口下去，整个人都暖洋洋的。",
	"南瓜的香甜在嘴里慢慢化开，好满足。",
]

const FALLBACK_FEED_GENERIC := [
	"唔，这份零食味道真不错。",
	"嚼着嚼着，尾巴尖都想晃一晃。",
	"这份心意我收下了，味道也记住了。",
]

const FALLBACK_FEED_REFUSE_ALREADY := [
	"今天这份已经够啦，留点给明天吧。",
	"我肚子还饱着呢，这份先收着，明天再吃。",
	"一天一份就够，这份心意我记着，明天再来？",
]

const FALLBACK_FEED_REFUSE_MANY := [
	"真的吃不下啦……你留着自己补补能量吧。",
	"今天已经心满意足了，再塞给我就要打饱嗝了。",
	"我知道你是疼我，可我今天真的到上限了，明天再喂好不好？",
	"再这样下去，小狸要变成圆滚滚的了，放过我吧～",
]


static func pick_random(pool: Array) -> String:
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


static func ambient_sidewrite(weather: String = "") -> String:
	if weather == GameState.WEATHER_RAIN or GameState.weather_today == GameState.WEATHER_RAIN:
		return pick_random(FALLBACK_AMBIENT_RAIN)
	return "……风从廊下过来。她没说话，只是看着田。"


static func casual_chat(
	story_mode: String,
	sprout_tier: int,
	time_of_day: String,
	weather: String,
	previous: Array = []
) -> String:
	var tod := time_of_day
	if tod not in ["morning", "noon", "evening"]:
		tod = "noon"
	var pool: Array = []
	match story_mode:
		"stranger":
			pool = _casual_pool_from(FALLBACK_CASUAL_STRANGER, tod)
		"leak":
			pool = _casual_pool_from(FALLBACK_CASUAL_LEAK, tod)
		"awaken":
			pool = _casual_pool_from(FALLBACK_CASUAL_AWAKEN, tod)
		_:
			var tier := clampi(sprout_tier, 0, FALLBACK_CASUAL_TIER.size() - 1)
			var by_time: Variant = FALLBACK_CASUAL_TIER[tier]
			if by_time is Dictionary:
				pool = _casual_pool_from(by_time, tod)
	if weather == GameState.WEATHER_RAIN and story_mode != "stranger":
		for line in FALLBACK_CASUAL_RAIN:
			pool.append(line)
	var picked := pick_non_duplicate(pool, previous)
	if picked != "":
		return picked
	return "……我在。你忙的话，我就在旁边。"


static func proactive_chase_line(previous: Array = []) -> String:
	var pool: Array = [
		"等我一下！",
		"别跑啦——",
		"你跑太快啦……",
		"等等我嘛。",
		"我有话要说！",
		"喂——听我说一句。",
		"别走嘛，就一句。",
		"等等——",
	]
	return pick_non_duplicate(pool, previous)


static func proactive_line(extra: Dictionary) -> String:
	## 仅 API 不可用时的兜底。说话跟此刻位置、行动对上。
	var previous: Array = extra.get("previous_proactive", extra.get("previous_lines", []))
	var intent := str(extra.get("proactive_intent", extra.get("channel", "casual")))
	var leak: Dictionary = extra.get("leak_context", {})
	var summary := str(leak.get("anchor_summary", "")).strip_edges()
	if intent == "leak" and summary != "":
		var wraps := [
			"手比脑子先动了一下。……%s。" % summary,
			"刚才那一下，像真做过：%s。" % summary,
			"……%s。想不起来是哪一回。" % summary,
		]
		var leak_line := pick_non_duplicate(wraps, previous)
		if leak_line != "":
			return leak_line
	if intent == "invite":
		var beat_ctx: Dictionary = extra.get("beat_context", {})
		var profile := str(beat_ctx.get("profile", extra.get("beat_profile", ""))).strip_edges()
		var tier := str(beat_ctx.get("affection_tier", extra.get("affection_tier", ""))).strip_edges()
		var weather := str(extra.get("weather", GameState.weather_today))
		var tod := str(extra.get("time_of_day", GameState.time_of_day))
		var beat := str(extra.get("beat_emotion", extra.get("beat_label", ""))).strip_edges()
		if profile == "cold" or tier == GameState.AFFECTION_TIER_COLD:
			return pick_non_duplicate([
				"……你方便的话，过来一下。我有句话，不太会讲。",
				"等你忙完。不用急。",
			], previous)
		if profile == "warm" or tier == GameState.AFFECTION_TIER_WARM:
			if tod == GameState.TIME_EVENING:
				return pick_non_duplicate([
					"傍晚了。你过来一下——我有句话，想现在就说。",
					"苗齐了。你别走远，听我说个笨主意。",
				], previous)
		if summary != "" and str(extra.get("story_mode", "")) == "leak":
			return "刚才……%s。你过来一下。" % summary
		if weather == GameState.WEATHER_RAIN:
			return "雨还在下。你方便的话，过来坐一会儿？"
		if tod == GameState.TIME_EVENING:
			return "傍晚了。我有句话，想先跟你说。"
		if beat != "":
			return "……你过来一下。我有句话想说。"
		return pick_non_duplicate([
			"……你过来一下。我有句话想说。",
			"等你忙完，听我说一句就好。",
		], previous)
	var grounded := _location_grounded_line(extra)
	if grounded != "":
		return grounded
	return casual_chat(
		str(extra.get("story_mode", StoryDirector.get_story_mode())),
		int(extra.get("sprout_tier", 0)),
		str(extra.get("time_of_day", GameState.time_of_day)),
		str(extra.get("weather", GameState.weather_today)),
		previous
	)


static func _location_grounded_line(extra: Dictionary) -> String:
	var snap := CompanionAgent.get_snapshot() if CompanionAgent else {}
	var loc := str(snap.get("location_name", "")).strip_edges()
	var activity := str(snap.get("activity", "")).strip_edges()
	var weather := str(extra.get("weather", GameState.weather_today))
	if loc == "":
		loc = "田边"
	if activity in ["浇水", "种萝卜", "收萝卜"]:
		return "我还在%s。你忙你的。" % activity
	if activity in ["前往商店", "挑选种子", "挑选商品"]:
		return "我在商店这边。你先忙。"
	if weather == GameState.WEATHER_RAIN:
		return "雨还下着。我在%s。" % loc
	if activity in ["闲逛", "发呆", "待命", ""]:
		return "我在%s。你忙的话，我就在这儿。" % loc
	return "我在%s。" % loc


static func _casual_pool_from(by_time: Dictionary, time_of_day: String) -> Array:
	var raw: Variant = by_time.get(time_of_day, by_time.get("noon", []))
	if raw is Array:
		return raw.duplicate()
	return []


static func pick_non_duplicate(pool: Array, previous: Array) -> String:
	if pool.is_empty():
		return ""
	var candidates: Array = pool.duplicate()
	candidates.shuffle()
	for line in candidates:
		var cleaned := str(line).strip_edges()
		if cleaned == "":
			continue
		var seen := false
		for existing in previous:
			if str(existing).strip_edges() == cleaned:
				seen = true
				break
		if not seen:
			return cleaned
	return str(pool[randi() % pool.size()]).strip_edges()


static func companion_feed(
	item: Dictionary,
	previous_replies: Array,
	refused: bool,
	pester_count: int = 0
) -> String:
	if refused:
		if pester_count >= 2:
			return pick_non_duplicate(FALLBACK_FEED_REFUSE_MANY, previous_replies)
		return pick_non_duplicate(FALLBACK_FEED_REFUSE_ALREADY, previous_replies)

	var item_id := str(item.get("id", ""))
	var pool: Array = FALLBACK_FEED_GENERIC
	match item_id:
		"apple":
			pool = FALLBACK_FEED_APPLE
		"berry":
			pool = FALLBACK_FEED_BERRY
		"carrot":
			pool = FALLBACK_FEED_CARROT
		"pumpkin_snack":
			pool = FALLBACK_FEED_PUMPKIN
	if pool == FALLBACK_FEED_GENERIC:
		var item_name := str(item.get("name", "")).strip_edges()
		if item_name != "":
			var named_pool: Array = []
			for line in pool:
				named_pool.append("%s，是 %s。" % [str(line), item_name])
			pool = named_pool
	return pick_non_duplicate(pool, previous_replies)


static func greet(
	stage: String,
	game_day: int,
	affection: int,
	weather_label: String,
	memory_context: Dictionary,
	time_label: String = "清晨",
	yesterday_summary: String = "",
	include_yesterday_echo: bool = false,
	include_absence_comeback: bool = false,
	absence_facts: Dictionary = {}
) -> String:
	var sky := "%s的%s" % [weather_label, time_label]
	if game_day <= 1 and affection == 0 and not include_absence_comeback:
		return pick_random(FALLBACK_GREET_FIRST)

	if _is_stranger_amnesia(memory_context):
		return "……你是谁？我不记得了。我怎么会在这里。"

	if include_absence_comeback and str(memory_context.get("story_mode", "")) != "stranger":
		var hint := str(absence_facts.get("comeback_hint", "")).strip_edges()
		if hint == "":
			hint = GameState.build_absence_comeback_hint(int(absence_facts.get("gap_hours", 2)))
		return hint

	if include_yesterday_echo and yesterday_summary != "" and str(memory_context.get("story_mode", "")) != "stranger":
		var yesterday_clause := GameState.build_yesterday_echo_hint()
		if yesterday_clause == "":
			yesterday_clause = "在家园里忙了一天"
		return pick_random(FALLBACK_GREET_YESTERDAY_ECHO) % yesterday_clause

	if _is_stranger_amnesia(memory_context):
		if str(memory_context.get("story_mode", "")) == "stranger":
			return pick_random(FALLBACK_GREET_STRANGER_W2)
		return "你来了。今天是%s。这田……好像不是头一回见。" % sky

	match stage:
		GameState.STAGE_BOND:
			return "你来了。今天是%s。" % sky
		GameState.STAGE_FAMILIAR:
			return "%s今天是%s。" % [pick_random(FALLBACK_GREET_RETURN), sky]
		_:
			return "%s今天是%s。" % [pick_random(FALLBACK_GREET_RETURN), sky]


static func task_complete(game_facts: Dictionary, _market: Dictionary) -> String:
	var task := str(game_facts.get("task", ""))
	match task:
		"water":
			var count := int(game_facts.get("plot_count", 1))
			return pick_random(FALLBACK_TASK_WATER) % count
		"plant":
			var planted := int(game_facts.get("plot_count", 1))
			return "种好了。空垄上现在有 %d 块新苗。" % planted
		"harvest":
			var harvested := int(game_facts.get("plot_count", 1))
			return "收回来了。筐里多了 %d 块田的萝卜。" % harvested
		"shop":
			return "商店到了。你看，要不要买点种子。"
		_:
			return "这件事我记下了。"


static func player_chat(
	text: String,
	stage: String,
	memory_context: Dictionary,
	parsed_intent: Dictionary = {}
) -> String:
	var intent_key := str(parsed_intent.get("intent", IntentParser.INTENT_CHAT))
	match intent_key:
		IntentParser.INTENT_WATER:
			var plot_id := int(parsed_intent.get("plot_id", -1))
			if plot_id > 0:
				return "好，我去浇第 %d 块田。" % plot_id
			return "好，我去浇水。"
		IntentParser.INTENT_WATER_ALL:
			return "好，我把还没浇的田都浇一遍。"
		IntentParser.INTENT_HARVEST:
			return "好，我去萝卜田帮你收。"
		IntentParser.INTENT_HARVEST_ALL:
			return "好，我把能收的萝卜都收回来。"
		IntentParser.INTENT_PLANT:
			var plant_plot_id := int(parsed_intent.get("plot_id", -1))
			if plant_plot_id > 0:
				return "好，我去第 %d 块空田种萝卜。" % plant_plot_id
			return "好，我去空田种萝卜。"
		IntentParser.INTENT_PLANT_ALL:
			return "好，我把能种的空田都种上。"
		IntentParser.INTENT_OPEN_MARKET:
			var sold := GameState.sell_all_turnips()
			return str(sold.get("message", "筐里还没有萝卜。"))
		IntentParser.INTENT_OPEN_SHOP:
			return "好，我们去商店看看种子和零食。"
		IntentParser.INTENT_OPEN_MEMORY:
			return "我把我们的记忆翻出来，你看看。"
		IntentParser.INTENT_CHECK_STATUS:
			return "我先帮你看看田里的情况。"
		IntentParser.INTENT_HELP:
			return "想知道我能帮什么？我说给你听。"
		IntentParser.INTENT_SLEEP:
			return "好，今天先到这儿，好好休息。"

	if _asks_prior_acquaintance(text):
		return _prior_acquaintance_reply(memory_context)

	var lower := text.to_lower()
	if "浇" in text or ("水" in text and ("田" in text or "地" in text or "萝卜" in text)):
		return pick_random(FALLBACK_CHAT_WATER_HINT)
	if "你好" in text or "hi" in lower or "hello" in lower:
		return pick_random(FALLBACK_CHAT_HELLO)
	if "天气" in text or "下雨" in text or "晴天" in text:
		var today := GameState.get_weather_label()
		var tomorrow := GameState.get_weather_label(GameState.weather_tomorrow_hint)
		return "今天%s，明天大概是%s。田里的情况我会帮你看。" % [today, tomorrow]
	if "喜欢" in text or "慢慢来" in text or "记住" in text:
		return pick_random(FALLBACK_CHAT_PREFERENCE)
	if _is_stranger_amnesia(memory_context):
		return stranger_chat(text, memory_context)
	if _is_leak_phase(memory_context) and not bool(memory_context.get("revealed", false)):
		var leak := LeakageEngine.try_leak_line("chat")
		if leak.strip_edges() != "":
			return leak
		return "我会记着你刚才的话。以前听没听过，说不清。"

	match stage:
		GameState.STAGE_BOND:
			return "我在听。想聊什么都可以，或者我们继续把家园打理好。"
		GameState.STAGE_FAMILIAR:
			return pick_random(FALLBACK_CHAT_GENERIC)
		_:
			return pick_random(FALLBACK_CHAT_GENERIC)


static func stranger_chat(text: String, memory_context: Dictionary) -> String:
	if _is_stranger_amnesia(memory_context):
		if "我是谁" in text or "你是谁" in text or "不认识" in text or "记得我" in text:
			return "……你说我们见过？对不起。我想不起来。"
		if "小狸" in text and ("认识" in text or "记得" in text or "一起" in text):
			return "你叫我的名字……好像对。可我还是想不起来，在这里做过什么。"
		if "萝卜" in text or "田" in text:
			return "这田看着熟。也许你来过。我说不清是什么时候。"
	if "你好" in text or "hi" in text.to_lower() or "hello" in text.to_lower():
		return "……你好。抱歉，我想不起有没有见过你。"
	if _asks_prior_acquaintance(text) or "我是谁" in text or "你是谁" in text or "记得我" in text:
		return _prior_acquaintance_reply(memory_context)
	if "留下" in text or "帮工" in text or "农场" in text:
		return "……你愿意说的话，我听。但我还不确定我们是什么关系。"
	return pick_random(FALLBACK_STRANGER_CHAT)


static func companion_react(
	react_type: String,
	snapshot: Dictionary,
	story_hint: String,
	stage: String,
	memory_context: Dictionary
) -> String:
	var plots: Dictionary = snapshot.get("plots", {})
	var inventory: Dictionary = snapshot.get("inventory", {})
	var react_facts: Dictionary = snapshot.get("react_facts", {})
	var unwatered := int(plots.get("unwatered_growing", 0))
	var turnip_count := int(inventory.get("turnip", 0))

	match react_type:
		"world_weather_change":
			if str(snapshot.get("weather_today", "")) == GameState.WEATHER_RAIN:
				return pick_random(FALLBACK_REACT_RAIN)
			return pick_random(FALLBACK_REACT_SUN)
		"world_price_surge":
			return pick_random(FALLBACK_REACT_PRICE_SURGE)
		"world_crop_ready":
			var count := int(react_facts.get("harvestable", plots.get("harvestable", 0)))
			if count <= 0:
				count = int(plots.get("harvestable", 0))
			if count <= 0:
				return "田里的萝卜还在长，我们再等等。"
			if count == 1:
				return pick_random(FALLBACK_REACT_CROP_READY_ONE)
			return pick_random(FALLBACK_REACT_CROP_READY_MANY) % count
		"world_evening":
			if unwatered > 0 and str(snapshot.get("weather_today", "")) != GameState.WEATHER_RAIN:
				return pick_random(FALLBACK_REACT_UNWATERED) % unwatered
			if turnip_count > 0:
				return "%s 筐里有 %d 个萝卜。要卖的话跟我说。" % [
					pick_random(FALLBACK_REACT_EVENING),
					turnip_count,
				]
			return pick_random(FALLBACK_REACT_EVENING)
		"world_idle_long":
			if unwatered > 0:
				return pick_random(FALLBACK_REACT_UNWATERED) % unwatered
			if int(plots.get("harvestable", 0)) > 0:
				return pick_random(FALLBACK_REACT_CROP_READY_ONE)
			return pick_random(FALLBACK_REACT_IDLE)
		"player_planted":
			var plot_id := int(react_facts.get("plot_id", 0))
			if plot_id > 0:
				return "%s（第 %d 块田）" % [pick_random(FALLBACK_REACT_PLANTED), plot_id]
			return pick_random(FALLBACK_REACT_PLANTED)
		"player_harvested":
			if turnip_count > 0:
				return "%s 要卖的话，跟我说一声。" % pick_random(FALLBACK_REACT_HARVESTED)
			return pick_random(FALLBACK_REACT_HARVESTED)
		"story_nudge":
			var leak := LeakageEngine.try_leak_for_react(react_type)
			if leak.strip_edges() != "":
				return leak
			return _story_nudge_line(story_hint, snapshot, stage, memory_context)
		"persona_shift":
			return _persona_shift_line(react_facts)
		_:
			return pick_random(FALLBACK_REACT_IDLE)


static func _persona_shift_line(react_facts: Dictionary) -> String:
	var dim := str(react_facts.get("dimension", "")).strip_edges()
	if dim == "":
		return "……我以前好像不这样。"
	var lines: Variant = FALLBACK_REACT_PERSONA_SHIFT.get(dim, [])
	if lines is Array and not lines.is_empty():
		return pick_random(lines)
	return "……我以前好像不这样。"


static func _story_nudge_line(
	story_hint: String,
	snapshot: Dictionary,
	stage: String,
	memory_context: Dictionary
) -> String:
	var react_facts: Dictionary = snapshot.get("react_facts", {})
	var milestone_id := str(react_facts.get("milestone_id", "")).strip_edges()
	match milestone_id:
		"affection_familiar":
			return "和你相处这几天，我已经慢慢熟悉你了。接下来我会多帮你留意萝卜田。"
		"affection_bond":
			return "我觉得我们已经是伙伴了。田还在，你也在。"
		_:
			if milestone_id.begins_with("trade_big_win"):
				return "换成金币了。够买下一包种子就行。"
			if milestone_id.begins_with("trade_big_loss"):
				return "手头紧也没关系。先把田看好。"

	var week := int(snapshot.get("week_index", 1))
	var day := int(snapshot.get("loop_day", 1))
	var story_day := (week - 1) * 7 + day
	var plots: Dictionary = snapshot.get("plots", {})
	var unwatered := int(plots.get("unwatered_growing", 0))
	var revealed := bool(memory_context.get("revealed", false))

	if story_day in [2, 3] and unwatered > 0:
		return "萝卜田我才刚摸熟，还有 %d 块没浇水。" % unwatered

	if story_day == 4 and unwatered > 0:
		return "……我还不清楚这儿的规矩。有 %d 块田没浇水，要我去吗？" % unwatered

	if story_day == 7:
		return "今天的活快干完了。萝卜田，我们再一起看一眼吧。"

	if story_day == 8 and not revealed:
		return "本子上的日期我怎么也对不上。先把手边的田顾好吧。"

	if story_day == 9 and not revealed:
		return "明天，我想把好多事一件件跟你讲清楚。今天先把田照看好。"

	if story_day >= 10 and not revealed:
		var prefs: Dictionary = memory_context.get("long_term_prefs", {})
		if prefs.has("fav_crop"):
			return "我还记得你喜欢萝卜。今天也一起把田照顾好。"

	if story_hint.strip_edges() != "":
		return pick_random(FALLBACK_REACT_STORY) % story_hint

	match stage:
		GameState.STAGE_BOND:
			return "我们继续把家园和萝卜田打理好吧。"
		_:
			return pick_random(FALLBACK_REACT_IDLE)


static func story_beat_followup(beat_id: String, emotion: String, _node_label: String, stage: String) -> String:
	var companion := GameState.companion_name
	match emotion:
		"失去", "确认":
			return "……%s，我有件事想问你。你愿意再告诉我一次，我是谁、这里是哪里吗？" % GameState.player_name
		"名字":
			return "刚才那一瞬，名字突然回来了。%s，你……还在吗？" % GameState.player_name
		"起雾", "独自夜坐":
			return "今晚风有点冷。你要是有空，能陪我坐一会儿吗？"
		"信", "前夕":
			return "我写了点东西……不一定说得清楚。你想听听吗？"
		_:
			if stage == GameState.STAGE_BOND:
				return "%s，刚走完这一段，我心里有点话。方便和我说说吗？" % companion
			return "刚才那件事……我还在回味。你想说点什么吗？"


static func story_step_render(extra: Dictionary) -> String:
	var companion := GameState.companion_name
	var snippet := StoryRouteData.normalize_personal_snippet(str(extra.get("personal_snippet", "")))
	if snippet == "":
		snippet = StoryRouteData.extract_chat_snippet_for_beat(str(extra.get("beat_id", "")))
	if snippet == "":
		snippet = "你说过的那句，字迹比正文轻。"
	var routed := StoryNodeCopy.get_route("_N02p_chat", "default", "default")
	if routed.strip_edges() != "":
		return routed % [companion, snippet]
	return "%s 从怀里摸出本子，指尖停在一行字上，停了停：「……我记得是——『%s』」" % [companion, snippet]


static func _is_stranger_amnesia(memory_context: Dictionary) -> bool:
	if str(memory_context.get("story_mode", "")) == "stranger":
		return true
	if GameState.IS_TEN_DAY_EDITION:
		return GameState.game_day in [4, 5]
	var week_index := int(memory_context.get("week_index", 1))
	var loop_day := int(memory_context.get("loop_day", 1))
	return week_index == 2 and loop_day == 1 and not bool(memory_context.get("revealed", false))


static func _is_leak_phase(memory_context: Dictionary) -> bool:
	if str(memory_context.get("story_mode", "")) == "leak":
		return true
	if GameState.IS_TEN_DAY_EDITION:
		return GameState.game_day in [6, 7, 8]
	return false


static func _asks_prior_acquaintance(text: String) -> bool:
	if "认不认识" in text:
		return true
	if "以前认识" in text or "以前见过" in text or "曾经认识" in text or "曾经见过" in text:
		return true
	if "之前认识" in text or "之前见过" in text:
		return true
	if "我们认识" in text or "我们见过" in text:
		return true
	if ("认识吗" in text or "见过吗" in text) and ("我们" in text or "以前" in text or "曾经" in text or "之前" in text):
		return true
	if "认识我" in text or "见过我" in text:
		return true
	return false


static func _prior_acquaintance_reply(memory_context: Dictionary) -> String:
	if str(memory_context.get("story_mode", "")) == "stranger":
		return "对不起。我想不起来。"
	if GameState.has_player_name_set():
		return "记不清。你的名字我记住了。以前的事对不上，我不敢乱说。"
	return "记不清。以前的事对不上。我不敢乱说。"

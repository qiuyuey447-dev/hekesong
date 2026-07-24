extends RefCounted
class_name NpcFallback
## 本地 fallback 台词（B7）。API 不可用或未配置时使用。

const FALLBACK_GREET_FIRST := [
	"你好，我是小狸。想让我帮忙浇田、种萝卜，直接跟我说就行。",
	"初次见面，请多关照。田上的事，你吩咐我就好。",
]

const FALLBACK_STRANGER_CHAT := [
	"……抱歉，我脑子有点乱，不太确定是否见过你。",
	"嗯……你刚才说的，我先记着。这里的事我还不太熟。",
	"……如果是重要的事，可以再说一遍吗？我暂时想不起来。",
]

const FALLBACK_GREET_STRANGER_W2 := [
	"……抱歉，你是？这里是你的农场吗？",
	"你好……我好像不该在这里，但这片田看着有点熟悉。",
	"……我不记得见过你。不过，这屋子外面倒是挺安静的。",
]

const FALLBACK_GREET_YESTERDAY_ECHO := [
	"你来了。我还记得昨天%s。",
	"早。昨天%s。",
	"昨天%s——今天也一起吧。",
]

const FALLBACK_GREET_RETURN := [
	"欢迎回来，今天想先做点什么？",
	"你来了，田和水都等着呢。",
	"早上好，要我先去浇水吗？",
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
	"你好呀，今天也要一起把家园打理好吗？",
	"嗯，我在。今天想从哪件事开始？",
]

const FALLBACK_CHAT_PREFERENCE := [
	"我记住了，我们按你的节奏来。",
	"好，我记着，不着急。",
]

const FALLBACK_CHAT_GENERIC := [
	"我在听。想让我帮忙，直接说就好。",
	"嗯，还有什么想说的吗？",
]

const FALLBACK_REACT_RAIN := [
	"下雨了，田会自己喝饱水。我们今天就稍微缓一缓。",
	"雨天萝卜长得快一些，等天晴了再看看行情。",
]

const FALLBACK_REACT_SUN := [
	"出太阳了，记得给还没浇的田补水。",
	"晴天适合把萝卜田都照顾一遍。",
]

const FALLBACK_REACT_PRICE_SURGE := [
	"今天的萝卜售价是 %d 金，挺划算的。有货的话可以去大盘看看。",
	"行情不错，萝卜能卖 %d 金。要不要先收一收再卖？",
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
		return "%s 今天是%s。先看看萝卜和行情吧。" % [pick_random(FALLBACK_GREET_FIRST), sky]

	var week_index := int(memory_context.get("week_index", 1))
	var loop_day := int(memory_context.get("loop_day", 1))
	if week_index == 2 and loop_day == 1 and not bool(memory_context.get("revealed", false)):
		return "……你是谁？抱歉，我不记得了。我怎么会在这里？……这是你的农场吗？"

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

	if week_index >= 2 and not bool(memory_context.get("revealed", false)):
		if str(memory_context.get("story_mode", "")) == "stranger":
			return pick_random(FALLBACK_GREET_STRANGER_W2)
		return "欢迎回来。今天是%s，我总觉得我们不是第一次一起看这片萝卜田。" % sky

	match stage:
		GameState.STAGE_BOND:
			return "欢迎回来，今天是%s。我们接着把家园和萝卜田打理好吧。" % sky
		GameState.STAGE_FAMILIAR:
			return "%s 今天是%s。" % [pick_random(FALLBACK_GREET_RETURN), sky]
		_:
			return "%s 今天是%s。" % [pick_random(FALLBACK_GREET_RETURN), sky]


static func task_complete(game_facts: Dictionary, _market: Dictionary) -> String:
	var task := str(game_facts.get("task", ""))
	match task:
		"water":
			var count := int(game_facts.get("plot_count", 1))
			return pick_random(FALLBACK_TASK_WATER) % count
		_:
			return "任务完成了。"


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
			var price := GameState.get_turnip_sell_price()
			return "我帮你打开大盘。今天萝卜售价 %d 金。" % price
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

	var lower := text.to_lower()
	if "浇" in text or ("水" in text and ("田" in text or "地" in text or "萝卜" in text)):
		return pick_random(FALLBACK_CHAT_WATER_HINT)
	if "你好" in text or "hi" in lower or "hello" in lower:
		return pick_random(FALLBACK_CHAT_HELLO)
	if "喜欢" in text or "慢慢来" in text or "记住" in text:
		return pick_random(FALLBACK_CHAT_PREFERENCE)
	if str(memory_context.get("story_mode", "")) == "stranger":
		return stranger_chat(text, memory_context)
	var week_index := int(memory_context.get("week_index", 1))
	var loop_day := int(memory_context.get("loop_day", 1))
	if week_index == 2 and loop_day == 1 and not bool(memory_context.get("revealed", false)):
		if "我是谁" in text or "不认识" in text or "记得我" in text:
			return "……你说我们见过？对不起，我脑子里有些画面，但拼不起来。"
		if "小狸" in text and ("认识" in text or "记得" in text or "一起" in text):
			return "你叫我的名字……好像是对的。可我还是想不起来，在这里做过什么。"
		if "萝卜" in text or "田" in text:
			return "这片萝卜田……看着是熟悉的。也许你来过，但我说不清是什么时候。"
	if week_index >= 3 and not bool(memory_context.get("revealed", false)):
		var leak := LeakageEngine.try_leak_line("chat")
		if leak.strip_edges() != "":
			return leak
		return "我会记着你刚才的话。虽然说不清，但有些感觉像是以前也听过。"

	match stage:
		GameState.STAGE_BOND:
			return "我在听。想聊什么都可以，或者我们继续把家园打理好。"
		GameState.STAGE_FAMILIAR:
			return pick_random(FALLBACK_CHAT_GENERIC)
		_:
			return pick_random(FALLBACK_CHAT_GENERIC)


static func stranger_chat(text: String, memory_context: Dictionary) -> String:
	var week_index := int(memory_context.get("week_index", 1))
	var loop_day := int(memory_context.get("loop_day", 1))
	if week_index == 2 and loop_day == 1 and not bool(memory_context.get("revealed", false)):
		if "我是谁" in text or "不认识" in text or "记得我" in text:
			return "……你说我们见过？对不起，我脑子里有些画面，但拼不起来。"
		if "小狸" in text and ("认识" in text or "记得" in text or "一起" in text):
			return "你叫我的名字……好像是对的。可我还是想不起来，在这里做过什么。"
		if "萝卜" in text or "田" in text:
			return "这片萝卜田……看着是熟悉的。也许你来过，但我说不清是什么时候。"
	if "你好" in text or "hi" in text.to_lower() or "hello" in text.to_lower():
		return "……你好。抱歉，我一时想不起是否见过你。"
	if "我是谁" in text or "认识我" in text or "记得我" in text:
		return "……你问我认不认识你？老实说，我脑子里只有一些很模糊的画面。"
	if "留下" in text or "帮工" in text or "农场" in text:
		return "……如果你愿意说明一下，我可以听听。但我还不确定我们是什么关系。"
	return pick_random(FALLBACK_STRANGER_CHAT)


static func companion_react(
	react_type: String,
	snapshot: Dictionary,
	story_hint: String,
	stage: String,
	memory_context: Dictionary
) -> String:
	var market: Dictionary = snapshot.get("market", {})
	var plots: Dictionary = snapshot.get("plots", {})
	var inventory: Dictionary = snapshot.get("inventory", {})
	var react_facts: Dictionary = snapshot.get("react_facts", {})
	var sell_price := int(market.get("turnip_sell_price", 12))
	var unwatered := int(plots.get("unwatered_growing", 0))
	var turnip_count := int(inventory.get("turnip", 0))

	match react_type:
		"world_weather_change":
			if str(snapshot.get("weather_today", "")) == GameState.WEATHER_RAIN:
				return pick_random(FALLBACK_REACT_RAIN)
			return pick_random(FALLBACK_REACT_SUN)
		"world_price_surge":
			return pick_random(FALLBACK_REACT_PRICE_SURGE) % sell_price
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
			if turnip_count > 0 and sell_price >= 14:
				return "%s 背包里有 %d 个萝卜，今天卖 %d 金挺合适。" % [
					pick_random(FALLBACK_REACT_EVENING),
					turnip_count,
					sell_price,
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
			if turnip_count > 0 and sell_price >= 14:
				return "%s 现在卖的话能到 %d 金。" % [pick_random(FALLBACK_REACT_HARVESTED), sell_price]
			return pick_random(FALLBACK_REACT_HARVESTED)
		"story_nudge":
			var leak := LeakageEngine.try_leak_for_react(react_type)
			if leak.strip_edges() != "":
				return leak
			return _story_nudge_line(story_hint, snapshot, stage, memory_context)
		_:
			return pick_random(FALLBACK_REACT_IDLE)


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
			return "我觉得我们已经是伙伴了。以后不管行情怎样，一起把家园守好吧。"
		_:
			if milestone_id.begins_with("trade_big_win"):
				var price := int(react_facts.get("price", snapshot.get("market", {}).get("turnip_sell_price", 0)))
				return "刚才卖得真不错！%d 金一笔，这行情很难得。" % price
			if milestone_id.begins_with("trade_big_loss"):
				return "手头有点紧也没关系，咱们慢慢来。先把田照顾好，萝卜会帮我们的。"

	var week := int(snapshot.get("week_index", 1))
	var day := int(snapshot.get("loop_day", 1))
	var plots: Dictionary = snapshot.get("plots", {})
	var unwatered := int(plots.get("unwatered_growing", 0))

	if week == 1 and day in [2, 3, 4] and unwatered > 0:
		return "这周还在熟悉萝卜田，有 %d 块田还没浇水。" % unwatered

	if week == 1 and day == 7:
		return "今天是这周的最后一天了，我们把萝卜田和这一周的收成都看看吧。"

	if week == 2 and day == 1 and not bool(memory_context.get("revealed", false)):
		return "……抱歉，我还在想你是谁。先把手边的田顾好吧。"

	if week == 2 and day == 2 and not bool(memory_context.get("revealed", false)):
		return "又是新的一周…看见你和这片田，我心里总有点熟悉的感觉。"

	if week >= 3 and not bool(memory_context.get("revealed", false)):
		var prefs: Dictionary = memory_context.get("long_term_prefs", {})
		if prefs.has("fav_crop"):
			return "我还记得你喜欢萝卜。这周也一起把田照顾好。"

	if week == 5 and day == 1:
		return "新的一周开始了。有很多话想说，但先把手边的田顾好吧。"

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

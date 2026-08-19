class_name ShopDelegate
extends RefCounted

const CN_NUMBERS := {
	"一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
	"六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
}


static func parse_quantity(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return -1

	var regex := RegEx.new()
	regex.compile("(\\d+)\\s*包")
	var match_result := regex.search(trimmed)
	if match_result:
		return maxi(int(match_result.get_string(1)), 0)

	regex.compile("^(\\d+)$")
	match_result = regex.search(trimmed)
	if match_result:
		return maxi(int(match_result.get_string(1)), 0)

	regex.compile("(\\d+)")
	match_result = regex.search(trimmed)
	if match_result:
		return maxi(int(match_result.get_string(1)), 0)

	for cn in CN_NUMBERS.keys():
		if ("%s包" % cn) in trimmed or ("买%s" % cn) in trimmed:
			return int(CN_NUMBERS[cn])

	if trimmed in CN_NUMBERS:
		return int(CN_NUMBERS[trimmed])

	return -1


static func parse_seed_purchase_quantity(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return -1
	if trimmed.contains("买点") and not trimmed.contains("包"):
		var bare := parse_quantity(trimmed)
		if bare > 0:
			return bare
		return -1
	return parse_quantity(trimmed)


static func looks_like_plant_now(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty() or looks_like_plant_declined(normalized):
		return false
	return normalized.contains("种") and not normalized.contains("种子") and not normalized.contains("买")


static func is_quantity_reply(text: String) -> bool:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return false
	if parse_quantity(trimmed) > 0:
		return true
	return trimmed.is_valid_int() or trimmed in CN_NUMBERS.keys()


static func is_affirmative_reply(text: String) -> bool:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return false
	if is_negative_reply(trimmed):
		return false
	if trimmed in [
		"好", "好的", "好啊", "好呀", "好哦", "行", "行啊", "可以", "可以的",
		"要", "要的", "嗯", "嗯嗯", "帮吧", "浇吧", "种吧", "买吧", "收吧",
		"去吧", "麻烦你了", "拜托了", "拜托", "那就麻烦你了",
	]:
		return true
	return false


static func is_negative_reply(text: String) -> bool:
	var trimmed := text.strip_edges()
	if trimmed in [
		"不用", "不要", "不用了", "算了", "不用谢", "我自己来",
		"我自己浇", "我自己种", "我自己买", "先不用", "别", "先别",
		"不用浇", "不用种", "不用买", "不用收", "别浇了", "别种了", "别买了",
	]:
		return true
	return looks_like_chore_declined(trimmed)


static func looks_like_chore_declined(text: String) -> bool:
	return (
		looks_like_water_declined(text)
		or looks_like_plant_declined(text)
		or looks_like_harvest_declined(text)
		or looks_like_shop_declined(text)
	)


static func looks_like_water_declined(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "")
	for phrase in ["别浇", "不用浇", "先别浇", "不要浇", "别去浇", "先别去浇"]:
		if phrase in compact:
			return true
	return false


static func looks_like_plant_declined(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "")
	for phrase in ["别种", "不用种", "先别种", "不要种", "雨停再种", "别去种"]:
		if phrase in compact:
			return true
	return false


static func looks_like_harvest_declined(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "")
	for phrase in ["别收", "不用收", "先别收", "不要收", "别去收"]:
		if phrase in compact:
			return true
	return false


static func looks_like_shop_declined(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "")
	for phrase in ["别买", "不用买", "先别买", "不要买", "别买了", "不用买了"]:
		if phrase in compact:
			return true
	return false


static func looks_like_plant_commitment(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty() or looks_like_plant_declined(normalized):
		return false
	for phrase in [
		"我现在就去种", "这就去种", "马上去种", "去田里种", "去种上", "帮你种上",
		"把空田种", "空田种上", "种到空田", "种上去", "种萝卜", "去帮你种", "我去种",
		"我这就去种", "这就帮你种", "先帮你种", "帮你把空田种",
	]:
		if phrase in normalized:
			return true
	return looks_like_plant_now(normalized)


static func looks_like_shop_seed_commitment(text: String) -> bool:
	## 小狸口头答应去买萝卜种子（未必带「商店」二字）。
	var normalized := text.strip_edges()
	if normalized.is_empty() or looks_like_shop_declined(normalized):
		return false
	if not ("种子" in normalized and "买" in normalized):
		return false
	## 已声称买成：不算「去买」承诺，交由幻觉清洗处理。
	if looks_like_completed_shop_claim(normalized):
		return false
	for phrase in [
		"去买", "先买", "我去买", "我先买", "帮你买", "买几包", "买点", "买点儿",
		"买萝卜种子", "买种子", "去商店", "到商店", "先去买", "这就去买", "马上去买",
		"替你买", "代买",
	]:
		if phrase in normalized:
			return true
	return false


static func looks_like_shop_seed_offer(text: String) -> bool:
	## 小狸在征求：要不要代买种子。
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	if not ("种子" in normalized and "买" in normalized):
		return false
	return _looks_like_offer_question(normalized)


static func looks_like_shop_offer(text: String) -> bool:
	## 小狸在征求：要不要去商店/代买（LLM 常只说「去商店」不说「种子」）。
	if looks_like_shop_seed_offer(text):
		return true
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	return "商店" in normalized and _looks_like_offer_question(normalized)


static func looks_like_plant_offer(text: String) -> bool:
	## 小狸在征求：要不要代种空田。买种子邀约优先归 shop offer。
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	if looks_like_shop_seed_offer(normalized) or looks_like_shop_offer(normalized):
		return false
	if not ("种" in normalized):
		return false
	## 「买种子」问句不算种植邀约。
	if "种子" in normalized and "买" in normalized:
		return false
	if not _looks_like_offer_question(normalized):
		return false
	return (
		"种上" in normalized
		or "空田" in normalized
		or "种萝卜" in normalized
		or "帮你种" in normalized
		or "去种" in normalized
		or "先种" in normalized
		or "种点" in normalized
		or "种些" in normalized
		or "种下" in normalized
	)


static func looks_like_water_offer(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	if not ("浇" in normalized):
		return false
	if _looks_like_offer_question(normalized):
		return true
	return "你说一声" in normalized or "你吩咐" in normalized or "要浇" in normalized


static func looks_like_water_commitment(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty() or looks_like_water_declined(normalized):
		return false
	for phrase in [
		"我现在就去浇", "这就去浇", "马上去浇", "去浇田", "去浇地", "帮你浇",
		"帮你们浇", "我去浇", "去帮你浇", "把田都浇", "都浇一遍", "还没浇的",
		"我去给它们浇", "我去给它们浇点", "把它们都浇", "把水浇上", "这就去把水",
		"我这就去浇", "去把水浇",
	]:
		if phrase in normalized:
			return true
	if not normalized.contains("浇"):
		return false
	return (
		normalized.contains("还没")
		or normalized.contains("尚未")
		or normalized.contains("没浇")
		or normalized.contains("浇上")
	)


static func looks_like_harvest_offer(text: String) -> bool:
	## 小狸在征求：要不要代收熟萝卜。
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	if looks_like_shop_offer(normalized) or looks_like_plant_offer(normalized) or looks_like_water_offer(normalized):
		return false
	if not ("收" in normalized or "摘" in normalized):
		return false
	if not _looks_like_offer_question(normalized):
		return false
	return (
		"帮忙收" in normalized
		or "帮你收" in normalized
		or "帮你摘" in normalized
		or "我去收" in normalized
		or "去收" in normalized
		or "要不要" in normalized
		or "先把" in normalized
		or "能收" in normalized
	)


static func looks_like_harvest_commitment(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty() or looks_like_harvest_declined(normalized):
		return false
	for phrase in [
		"我现在就去收", "这就去收", "马上去收", "去收萝卜", "帮你收", "我去收",
		"去帮你收", "把萝卜都收", "都收一遍", "帮你摘", "我去摘", "去摘萝卜",
		"我这就去收", "这就帮你收", "去收吧", "收吧",
	]:
		if phrase in normalized:
			return true
	return false


static func looks_like_market_commitment(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	for phrase in [
		"帮你卖掉", "去出售", "我去卖萝卜", "帮你卖萝卜",
		"这就去卖", "去把萝卜卖掉",
	]:
		if phrase in normalized:
			return true
	return false


static func looks_like_sleep_commitment(text: String) -> bool:
	## 严格匹配「推进下一天」类承诺，避免闲聊「睡得好吗」误触。
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	for phrase in [
		"去睡觉", "该睡觉了", "该睡了", "我们去睡", "一起休息吧", "进入下一天",
		"帮你睡", "收工睡觉", "今天就到这", "今天就到这儿", "该歇了", "去休息吧",
		"睡觉吧", "去睡吧", "我们睡觉", "先进屋", "进屋歇", "歇着吧", "歇会儿吧",
		"你先进屋", "今天先到这儿", "今天也累得", "熄了那盏灯", "熄了灯",
	]:
		if phrase in normalized:
			return true
	if normalized.ends_with("歇着吧") or normalized.ends_with("休息吧"):
		return true
	return false


static func looks_like_completed_water_claim(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty() or not ("浇" in normalized) or looks_like_water_declined(normalized):
		return false
	for phrase in [
		"浇完了", "已经浇", "刚浇完", "浇好了", "都浇过了", "已经帮你浇",
	]:
		if phrase in normalized:
			return true
	return false


static func looks_like_completed_plant_claim(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty() or looks_like_plant_declined(normalized):
		return false
	for phrase in [
		"种完了", "已经种", "刚种完", "种好了", "都种上了", "已经帮你种",
	]:
		if phrase in normalized:
			return true
	return false


static func looks_like_completed_shop_claim(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty() or looks_like_shop_declined(normalized):
		return false
	for phrase in [
		"买好了", "已经买", "已购买", "帮你买了", "种子买好", "刚买好",
		"花了一", "花了两", "花了三", "花了点金币", "花了金币",
	]:
		if phrase in normalized:
			return true
	return false


static func looks_like_completed_harvest_claim(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty() or looks_like_harvest_declined(normalized):
		return false
	for phrase in [
		"收完了", "已经收", "刚收完", "都收好了", "已经帮你收", "摘完了",
	]:
		if phrase in normalized:
			return true
	return false


static func _looks_like_offer_question(normalized: String) -> bool:
	return (
		"要不要" in normalized
		or "好不好" in normalized
		or "可以吗" in normalized
		or "行不行" in normalized
		or "能不能" in normalized
		or "可不可以" in normalized
		or normalized.ends_with("？")
		or normalized.ends_with("?")
		or normalized.ends_with("吗")
		or normalized.ends_with("嘛")
	)

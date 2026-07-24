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
	if normalized.is_empty():
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
	if trimmed in ["好", "好的", "好啊", "好呀", "好哦", "行", "行啊", "可以", "可以的", "要", "要的", "嗯", "嗯嗯", "帮吧", "浇吧", "去吧", "麻烦你了", "拜托了", "拜托", "那就麻烦你了"]:
		return true
	return false


static func is_negative_reply(text: String) -> bool:
	var trimmed := text.strip_edges()
	return trimmed in ["不用", "不要", "不用了", "算了", "不用谢", "我自己来", "我自己浇", "先不用"]


static func looks_like_plant_commitment(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	for phrase in [
		"我现在就去种", "这就去种", "马上去种", "去田里种", "去种上", "帮你种上",
		"把空田种", "空田种上", "种上去", "种萝卜", "去帮你种", "我去种",
	]:
		if phrase in normalized:
			return true
	return looks_like_plant_now(normalized)


static func looks_like_water_commitment(text: String) -> bool:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return false
	for phrase in [
		"我现在就去浇", "这就去浇", "马上去浇", "去浇田", "去浇地", "帮你浇",
		"帮你们浇", "我去浇", "去帮你浇", "把田都浇", "都浇一遍", "还没浇的",
		"我去给它们浇", "我去给它们浇点", "把它们都浇",
	]:
		if phrase in normalized:
			return true
	if not normalized.contains("浇"):
		return false
	return (
		normalized.contains("还没")
		or normalized.contains("尚未")
		or normalized.contains("没浇")
	)

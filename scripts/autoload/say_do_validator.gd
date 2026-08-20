extends Node
## Say-Do 一致：口头承诺须对应已启动的 chore。

const COMMITMENT_PATTERNS := {
	"water_all": [
		"我去浇", "这就去浇", "马上去浇", "帮你浇", "把田都浇", "浇一遍", "拿壶", "去浇",
	],
	"harvest_all": [
		"我去收", "这就去收", "帮你收", "去收萝卜", "顺手收", "收掉",
	],
	"plant_all": [
		"我去种", "这就去种", "帮你种", "种上", "种萝卜",
	],
	"sell_turnips": [
		"我去卖", "帮你卖", "卖掉", "出售",
	],
	"shop_buy_seeds": [
		"去买种子", "买种子", "去商店", "帮你买",
	],
}


func implied_steps_from_reply(reply: String) -> Array:
	var normalized := reply.strip_edges()
	if normalized.is_empty():
		return []
	var steps: Array = []
	for step_key in COMMITMENT_PATTERNS.keys():
		for phrase in COMMITMENT_PATTERNS[step_key]:
			if phrase in normalized:
				if step_key not in steps:
					steps.append(step_key)
				break
	if ShopDelegate.looks_like_water_commitment(normalized) and "water_all" not in steps:
		steps.append("water_all")
	if ShopDelegate.looks_like_harvest_commitment(normalized) and "harvest_all" not in steps:
		steps.append("harvest_all")
	if ShopDelegate.looks_like_plant_commitment(normalized) and "plant_all" not in steps:
		steps.append("plant_all")
	if ShopDelegate.looks_like_market_commitment(normalized) and "sell_turnips" not in steps:
		steps.append("sell_turnips")
	if ShopDelegate.looks_like_shop_seed_commitment(normalized) and "shop_buy_seeds" not in steps:
		steps.append("shop_buy_seeds")
	return steps


func enforce(reply: String, executed_steps: Array, _player_text: String = "") -> String:
	var cleaned := reply.strip_edges()
	if cleaned.is_empty():
		return cleaned
	var implied := implied_steps_from_reply(cleaned)
	if implied.is_empty():
		return cleaned
	var missing: Array = []
	for step_key in implied:
		if step_key not in executed_steps:
			missing.append(step_key)
	if missing.is_empty():
		return cleaned
	# 口头承诺但未执行：改口并补做由调用方处理；这里只去掉虚假完成声称
	if ShopDelegate.looks_like_completed_water_claim(cleaned) and "water_all" in missing:
		return PersonaGuard.reply_when_cannot_water() if _field_empty() else "还没浇呢，我这就去。"
	if ShopDelegate.looks_like_completed_harvest_claim(cleaned) and "harvest_all" in missing:
		return PersonaGuard.reply_when_cannot_harvest()
	if ShopDelegate.looks_like_completed_shop_claim(cleaned) and "sell_turnips" in missing:
		return PersonaGuard.reply_when_shop_not_done()
	if "water_all" in missing:
		return "好，我这就去浇。"
	if "harvest_all" in missing:
		return "好，我这就去收。"
	if "sell_turnips" in missing:
		return "好，我这就帮你卖萝卜。"
	if "shop_buy_seeds" in missing:
		return "好，我先去商店买种子。"
	if "plant_all" in missing:
		return "好，我这就去种。"
	return cleaned


func should_skip_repetitive_fallback(player_text: String) -> bool:
	if PendingOfferStore.is_confirmable_player(player_text):
		return true
	var compact := player_text.strip_edges().replace(" ", "")
	for marker in ["浇吧", "种吧", "收吧", "买吧", "卖吧", "去吧", "好的", "好", "行"]:
		if compact == marker:
			return true
	return false


func _field_empty() -> bool:
	var summary := GameState.get_plot_summary()
	return int(summary.get("growing", 0)) <= 0 and int(summary.get("harvestable", 0)) <= 0

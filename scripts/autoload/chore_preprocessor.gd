extends Node
## 多步农务指令拆分 + 纠错/反问识别。

const STEP_ALIASES := {
	"harvest_all": ["harvest_all", "harvest"],
	"sell_turnips": ["sell_turnips", "open_market", "market", "sell"],
	"shop_buy_seeds": ["shop_buy_seeds", "open_shop", "shop", "buy_seeds"],
	"plant_all": ["plant_all", "plant"],
	"water_all": ["water_all", "water"],
	"sleep": ["sleep"],
}

const SEGMENT_MARKERS := ["然后", "再", "顺便", "接着", "之后", "并且", "，再", "。再", "；"]

const MAX_GOLD_MARKERS := [
	"剩下的钱", "全部用来买", "全买", "钱都用来", "尽量多买",
	"有多少买多少", "能买多少买多少", "钱全用来", "金币全买", "钱都买",
]

const SELL_COMPLETION_PHRASES := [
	"卖完了", "都卖完", "已经卖了", "刚卖完", "卖光了", "都卖光了",
]


func parse_plan(text: String) -> Array:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return []
	var segments := _split_segments(trimmed)
	var steps: Array = []
	for segment in segments:
		var step := segment_to_step(str(segment))
		if step.is_empty():
			continue
		if not steps.is_empty() and steps[steps.size() - 1] == step:
			continue
		steps.append(step)
	return steps


func segment_to_step(segment: String) -> Dictionary:
	var seg := segment.strip_edges()
	if seg.is_empty():
		return {}
	return enrich_step_metadata(_segment_to_step_core(seg), seg)


func _segment_to_step_core(seg: String) -> Dictionary:
	var compact := seg.replace(" ", "").replace("　", "")
	var max_gold := looks_like_max_gold_seed_buy(seg)
	var intent := IntentParser.parse(seg)
	var key := str(intent.get("intent", IntentParser.INTENT_CHAT))
	if IntentParser.is_action_intent(intent):
		var mapped := _map_intent_to_step(key)
		if mapped != "":
			var step := {"step": mapped, "raw_text": seg}
			if mapped == "shop_buy_seeds":
				step["max_gold"] = max_gold or bool(intent.get("max_gold", false))
			return step
	if looks_like_sell_all_command(seg):
		return {"step": "sell_turnips", "raw_text": seg}
	if compact.contains("买") and compact.contains("种子"):
		return {"step": "shop_buy_seeds", "raw_text": seg, "max_gold": max_gold}
	if compact.contains("收") or compact.contains("摘"):
		return {"step": "harvest_all", "raw_text": seg}
	if compact.contains("种") and not compact.contains("种子"):
		return {"step": "plant_all", "raw_text": seg}
	if compact.contains("浇"):
		return {"step": "water_all", "raw_text": seg}
	return {}


func looks_like_max_gold_seed_buy(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	if compact.is_empty():
		return false
	for marker in MAX_GOLD_MARKERS:
		if marker in compact:
			return true
	if compact.contains("买") and (
		_compact_has_any(compact, ["全", "都", "所有", "统统", "全部", "尽量"])
	):
		return compact.contains("种子") or compact.contains("全买")
	return false


func looks_like_sell_all_command(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	if compact.is_empty() or not compact.contains("卖"):
		return false
	if looks_like_sell_completion_statement(text):
		return false
	if _compact_has_any(compact, ["全卖", "都卖", "全部卖", "统统卖", "卖光", "卖完"]):
		return not looks_like_sell_completion_statement(text)
	if _compact_has_any(compact, ["全", "都", "所有", "统统", "全部"]) and compact.contains("卖"):
		return true
	if compact.contains("萝卜") or compact.contains("筐"):
		return true
	return false


func looks_like_sell_completion_statement(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	if compact.is_empty():
		return false
	for phrase in SELL_COMPLETION_PHRASES:
		if phrase in compact:
			return true
	if compact.ends_with("全卖了") or compact.ends_with("都卖了"):
		return not looks_like_explicit_delegate(text)
	return false


func looks_like_bare_farm_command(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	return compact in [
		"浇", "浇水", "去浇", "去浇水", "浇一下", "浇田",
		"种", "去种", "去种上",
		"收", "去收", "去收萝卜",
		"买种子", "去买种子",
	]


func looks_like_explicit_delegate(text: String) -> bool:
	var compact := text.replace(" ", "").replace("　", "")
	for cue in IntentParser.DELEGATE_CUES:
		if str(cue) in compact:
			return true
	return false


func should_auto_start_single_plan(text: String, plan: Array) -> bool:
	if plan.size() != 1:
		return false
	if looks_like_explicit_delegate(text):
		return true
	if looks_like_bare_farm_command(text):
		return true
	var step: Dictionary = plan[0]
	if not step is Dictionary:
		return false
	var step_key := str(step.get("step", ""))
	if step_key == "shop_buy_seeds" and bool(step.get("max_gold", false)):
		return true
	if step_key == "sell_turnips" and looks_like_sell_all_command(text):
		return true
	return false


func enrich_step_metadata(step: Dictionary, raw_text: String = "") -> Dictionary:
	if step.is_empty():
		return {}
	var copy: Dictionary = step.duplicate(true)
	var step_key := str(copy.get("step", "")).strip_edges()
	var raw := str(copy.get("raw_text", raw_text)).strip_edges()
	if raw != "":
		copy["raw_text"] = raw
	if step_key == "shop_buy_seeds" and not bool(copy.get("max_gold", false)):
		copy["max_gold"] = looks_like_max_gold_seed_buy(raw if raw != "" else raw_text)
	return copy


func normalize_plan_steps(raw_steps: Variant, fallback_text: String = "") -> Array:
	var out: Array = []
	if raw_steps is Array:
		for item in raw_steps:
			if item is Dictionary:
				var step_key := str(item.get("step", "")).strip_edges()
				var mapped := _normalize_step_key(step_key)
				if mapped != "":
					var copy: Dictionary = item.duplicate(true)
					copy["step"] = mapped
					out.append(copy)
				elif step_key != "":
					out.append(item.duplicate(true))
				continue
			var mapped := _normalize_step_key(str(item))
			if mapped != "":
				out.append({"step": mapped, "raw_text": fallback_text})
	elif raw_steps is String:
		var parsed: Variant = JSON.parse_string(raw_steps)
		if parsed is Array:
			return normalize_plan_steps(parsed, fallback_text)
	for i in range(out.size()):
		if out[i] is Dictionary:
			var raw := str(out[i].get("raw_text", fallback_text))
			out[i] = enrich_step_metadata(out[i], raw if raw != "" else fallback_text)
	return out


func _compact_has_any(compact: String, markers: Array) -> bool:
	for marker in markers:
		if str(marker) in compact:
			return true
	return false


func looks_like_player_correction(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	if compact.is_empty():
		return false
	for marker in [
		"为啥", "为什么", "为何", "不是说", "不是说要", "牛头不对马嘴", "搞错", "听错",
		"没听明白", "没听懂", "说错", "答非所问", "张冠李戴", "卖你说收", "收你说卖",
	]:
		if marker in compact:
			return true
	return false


func looks_like_seed_location_inquiry(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	if compact.is_empty():
		return false
	if not compact.contains("种子"):
		return false
	return (
		"在哪" in compact
		or "哪里" in compact
		or "哪儿" in compact
		or compact.ends_with("呢")
		or compact.ends_with("吗")
	)


func should_block_llm_for_busy_farm_chat(text: String) -> bool:
	if not TaskSystem.is_busy():
		return false
	if IntentParser.looks_like_sleep_request(text):
		return false
	if looks_like_player_correction(text):
		return true
	if IntentParser.looks_like_status_inquiry(text):
		return true
	if looks_like_seed_location_inquiry(text):
		return true
	var compact := text.replace(" ", "")
	for marker in ["浇", "收", "种", "卖", "买", "田", "萝卜", "种子", "商店"]:
		if marker in compact:
			return true
	return false


func _split_segments(text: String) -> Array:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return []
	var parts: Array = [normalized]
	for marker in SEGMENT_MARKERS:
		var next: Array = []
		for part in parts:
			var s := str(part)
			var offset := 0
			var found := s.find(marker, offset)
			while found >= 0:
				var head := s.substr(0, found).strip_edges()
				if head != "":
					next.append(head)
				s = s.substr(found + marker.length()).strip_edges()
				found = s.find(marker)
			if s.strip_edges() != "":
				next.append(s.strip_edges())
		if not next.is_empty():
			parts = next
	if parts.size() <= 1:
		return parts
	return parts


func map_intent_to_step(intent_key: String) -> String:
	return _map_intent_to_step(intent_key)


func _map_intent_to_step(intent_key: String) -> String:
	match intent_key:
		IntentParser.INTENT_HARVEST, IntentParser.INTENT_HARVEST_ALL:
			return "harvest_all"
		IntentParser.INTENT_OPEN_MARKET:
			return "sell_turnips"
		IntentParser.INTENT_OPEN_SHOP:
			return "shop_buy_seeds"
		IntentParser.INTENT_PLANT, IntentParser.INTENT_PLANT_ALL:
			return "plant_all"
		IntentParser.INTENT_WATER, IntentParser.INTENT_WATER_ALL:
			return "water_all"
		IntentParser.INTENT_SLEEP:
			return "sleep"
		_:
			return ""


func _normalize_step_key(raw: String) -> String:
	var key := raw.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	for canonical in STEP_ALIASES.keys():
		if key == canonical:
			return canonical
		for alias in STEP_ALIASES[canonical]:
			if key == alias:
				return canonical
	return ""

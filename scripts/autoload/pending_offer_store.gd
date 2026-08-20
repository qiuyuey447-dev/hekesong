extends Node
## 小狸邀约确认：玩家「好/行」时记录 pending，执行由 ChoreOrchestrator 触发。

enum OfferType { NONE, WATER, HARVEST, PLANT, SHOP, MARKET }

var _type := OfferType.NONE
var _source_line := ""


func clear() -> void:
	_type = OfferType.NONE
	_source_line = ""


func has_any() -> bool:
	return _type != OfferType.NONE


func get_type() -> OfferType:
	return _type


func get_source_line() -> String:
	return _source_line.strip_edges()


func arm_from_companion_line(text: String) -> void:
	var normalized := text.strip_edges()
	if normalized.is_empty():
		return
	var has_shop := ShopDelegate.looks_like_shop_offer(normalized)
	var has_plant := (not has_shop) and ShopDelegate.looks_like_plant_offer(normalized)
	var has_water := ShopDelegate.looks_like_water_offer(normalized)
	if not has_water:
		has_water = ShopDelegate.looks_like_water_commitment(normalized)
	var has_harvest := (
		not has_shop and not has_plant and not has_water
		and ShopDelegate.looks_like_harvest_offer(normalized)
	)
	if not (has_shop or has_plant or has_water or has_harvest):
		return
	if has_shop:
		_type = OfferType.SHOP
	elif has_plant:
		_type = OfferType.PLANT
	elif has_water:
		_type = OfferType.WATER
	else:
		_type = OfferType.HARVEST
	_source_line = normalized


func infer_from_recent_companion_lines(lines: Array) -> bool:
	if has_any():
		return true
	for i in range(lines.size() - 1, -1, -1):
		var line := str(lines[i]).strip_edges()
		if line == "":
			continue
		arm_from_companion_line(line)
		if has_any():
			return true
	return infer_from_recent_companion_verbs(lines)


func infer_from_recent_companion_verbs(lines: Array) -> bool:
	## 口语邀请漏检时，按最近一句里的浇/种/收/买补挂 pending。
	if has_any():
		return true
	for i in range(lines.size() - 1, -1, -1):
		var line := str(lines[i]).strip_edges()
		if line == "":
			continue
		if ShopDelegate.looks_like_chore_declined(line):
			continue
		if "浇" in line:
			_type = OfferType.WATER
			_source_line = line
			return true
		if "买" in line and "种子" in line:
			_type = OfferType.SHOP
			_source_line = line
			return true
		if "种" in line and "种子" not in line:
			_type = OfferType.PLANT
			_source_line = line
			return true
		if "收" in line or "摘" in line:
			_type = OfferType.HARVEST
			_source_line = line
			return true
	return false


func is_confirmable_player(text: String) -> bool:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return false
	if ShopDelegate.is_negative_reply(trimmed):
		return has_any()
	return ShopDelegate.is_affirmative_reply(trimmed) or _looks_like_direct_go(trimmed)


func _looks_like_direct_go(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	return compact in ["浇吧", "种吧", "收吧", "买吧", "去吧", "卖吧"]


func recent_companion_lines(limit: int = 4) -> Array:
	var out: Array = []
	for turn in GameState.get_recent_chat_turns(12):
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) != "companion":
			continue
		var line := str(turn.get("text", "")).strip_edges()
		if line != "":
			out.append(line)
	if out.size() <= limit:
		return out
	return out.slice(out.size() - limit, out.size())

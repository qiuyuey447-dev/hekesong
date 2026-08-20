extends Node
## XL-H P2：聊天「过来 / 去地点 / 翻本子」与农事 intent 分轨。
## 每轮最多 1 条；信纸/觉醒/忙碌时丢弃。

const ACTION_FOLLOW := "follow_player"
const ACTION_WALK := "walk_poi"
const ACTION_NOTEBOOK := "open_notebook"
const ACTION_STAY := "stay"

const ALLOWED_POIS := ["porch", "field", "hollow", "shop", "home", "river"]
const POI_ALIASES := {
	"plots": "field",
	"door": "home",
	"yard": "home",
	"house": "home",
}
const POI_LABELS := {
	"porch": "在廊下",
	"field": "在田边",
	"hollow": "在树洞",
	"shop": "在商店",
	"home": "在门口",
	"river": "在河边",
}
const FARM_BODY_BLOCK_INTENTS := [
	"water", "water_all", "plant", "plant_all", "harvest", "harvest_all",
	"open_shop", "open_market", "sleep", "open_memory",
]

const _FOLLOW_PHRASES := [
	"过来", "到这边", "到我这", "到我这儿", "到这儿来", "到这里来",
	"来我这", "来我这儿", "跟我来", "跟着我", "你过来", "来这边",
]
const _NOTEBOOK_PHRASES := [
	"翻本子", "打开本子", "看看本子", "看一下本子", "把本子给我", "给我看本子", "看本子",
]
const _PORCH_COMMIT_PHRASES := [
	"走到廊下", "去廊下", "到廊下", "往廊下", "回廊下",
	"占了廊下", "占廊下", "廊下坐", "廊下躲", "廊下歇",
	"在廊下坐", "在廊下等", "咱们廊下", "我们廊下",
]
const _COMPANION_FOLLOW_PHRASES := [
	"我过来", "我这就来", "我马上过来", "我来找你", "我到你这", "我到你这儿",
	"我去你那边", "我去你这儿", "我过去找你",
]
const _COMPANION_NOTEBOOK_PHRASES := [
	"我翻本子", "我打开本子", "给你看本子", "我把本子", "本子翻给你",
]
const _QUESTION_MARKERS := ["要不要", "要我", "去不去", "好不好", "行不行"]


func sanitize_actions(raw: Variant, intent: String = "chat") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if str(intent) in FARM_BODY_BLOCK_INTENTS:
		return result
	var items: Array = []
	if raw is Dictionary:
		items = [raw]
	elif raw is Array:
		items = raw
	else:
		return result
	for item in items:
		if not item is Dictionary:
			continue
		var action_id := str(item.get("id", item.get("action", ""))).strip_edges()
		if action_id == ACTION_STAY or action_id == "":
			continue
		if action_id == ACTION_FOLLOW:
			result.append({"id": ACTION_FOLLOW})
			break
		if action_id == ACTION_NOTEBOOK:
			if intent == "open_memory":
				continue
			result.append({"id": ACTION_NOTEBOOK})
			break
		if action_id == ACTION_WALK:
			var poi := _normalize_poi(str(item.get("poi", item.get("target", ""))))
			if poi == "":
				continue
			result.append({"id": ACTION_WALK, "poi": poi})
			break
	return result


func infer_from_player(text: String, intent: String = "chat") -> Array[Dictionary]:
	if str(intent) in FARM_BODY_BLOCK_INTENTS:
		return []
	var compact := _compact(text)
	if compact == "":
		return []
	for phrase in _NOTEBOOK_PHRASES:
		if phrase in compact:
			if intent == "open_memory":
				return []
			return [{"id": ACTION_NOTEBOOK}]
	var poi := infer_poi(compact)
	if poi != "":
		if poi == "shop" and ("买" in compact or "种子" in compact or "卖" in compact):
			return []
		return [{"id": ACTION_WALK, "poi": poi}]
	for phrase in _FOLLOW_PHRASES:
		if phrase in compact:
			return [{"id": ACTION_FOLLOW}]
	if "一起走" in compact:
		return [{"id": ACTION_FOLLOW}]
	return []


func infer_from_companion_line(text: String) -> Array[Dictionary]:
	var compact := _compact(text)
	if compact == "":
		return []
	if _looks_like_question(compact):
		return []
	if "你去" in compact and "我去" not in compact and "咱们去" not in compact and "我们去" not in compact:
		return []
	if _is_non_commitment(compact):
		return []
	for phrase in _COMPANION_NOTEBOOK_PHRASES:
		if phrase in compact:
			return [{"id": ACTION_NOTEBOOK}]
	for phrase in _COMPANION_FOLLOW_PHRASES:
		if phrase in compact:
			return [{"id": ACTION_FOLLOW}]
	if _has_move_verb(compact):
		var poi := infer_poi(compact)
		if poi != "":
			if poi == "shop" and ("买" in compact or "种子" in compact or "卖" in compact):
				return []
			if poi == "field" and ("浇" in compact or "种" in compact or "收" in compact):
				return []
			return [{"id": ACTION_WALK, "poi": poi}]
	for phrase in _PORCH_COMMIT_PHRASES:
		if phrase in compact:
			return [{"id": ACTION_WALK, "poi": "porch"}]
	return []


func infer_poi(compact: String) -> String:
	if "廊下" in compact:
		return "porch"
	if "树洞" in compact:
		return "hollow"
	if "河边" in compact or "河沿" in compact:
		return "river"
	if "商店" in compact or "铺子" in compact:
		return "shop"
	if "萝卜田" in compact or "田里" in compact or "田边" in compact or "田埂" in compact:
		return "field"
	if "屋门口" in compact or "门口" in compact or "回家" in compact:
		return "home"
	return ""


func resolve_actions(
	api_actions: Variant,
	player_text: String,
	companion_line: String,
	intent: String = "chat",
	farm_handled: bool = false
) -> Array[Dictionary]:
	if farm_handled:
		return []
	var from_api := sanitize_actions(api_actions, intent)
	if not from_api.is_empty():
		return from_api
	var from_player := infer_from_player(player_text, intent)
	if not from_player.is_empty():
		return from_player
	return infer_from_companion_line(companion_line)


func execute(action: Dictionary) -> Dictionary:
	if action.is_empty():
		return {"executed": false, "reason": "empty"}
	if _should_drop():
		return {"executed": false, "reason": "blocked"}
	if TaskSystem.is_busy():
		return {"executed": false, "reason": "busy"}
	var action_id := str(action.get("id", ""))
	match action_id:
		ACTION_FOLLOW:
			return _execute_follow()
		ACTION_WALK:
			return _execute_walk(str(action.get("poi", "")))
		ACTION_NOTEBOOK:
			return _execute_notebook()
		_:
			return {"executed": false, "reason": "unknown"}


func _execute_follow() -> Dictionary:
	if CompanionAgent.is_proactive_active():
		return {"executed": false, "reason": "already_approaching"}
	CompanionAgent.begin_proactive_approach(func() -> void:
		CompanionAgent.end_proactive_approach()
	)
	return {"executed": true, "id": ACTION_FOLLOW}


func _execute_walk(poi: String) -> Dictionary:
	var normalized := _normalize_poi(poi)
	if normalized == "":
		return {"executed": false, "reason": "bad_poi"}
	if CompanionAgent.is_proactive_active():
		CompanionAgent.end_proactive_approach()
	var label := str(POI_LABELS.get(normalized, ""))
	if not CompanionAgent.go_to_poi(normalized, label):
		return {"executed": false, "reason": "cannot_walk"}
	return {"executed": true, "id": ACTION_WALK, "poi": normalized}


func _execute_notebook() -> Dictionary:
	get_tree().call_group("main_ui", "open_memory_from_companion")
	return {"executed": true, "id": ACTION_NOTEBOOK}


func _should_drop() -> bool:
	var ui := get_tree().get_first_node_in_group("main_ui")
	if ui != null and ui.has_method("blocks_body_actions") and bool(ui.call("blocks_body_actions")):
		return true
	return false


func _normalize_poi(raw: String) -> String:
	var poi := raw.strip_edges().to_lower()
	if poi in POI_ALIASES:
		poi = str(POI_ALIASES[poi])
	if poi in ALLOWED_POIS:
		return poi
	return ""


func _compact(text: String) -> String:
	return text.strip_edges().replace(" ", "").replace("　", "")


func _looks_like_question(compact: String) -> bool:
	if "？" in compact or "?" in compact:
		return true
	if compact.ends_with("吗") or compact.ends_with("么"):
		return true
	for marker in _QUESTION_MARKERS:
		if marker in compact:
			return true
	return false


func _has_move_verb(compact: String) -> bool:
	for verb in ["去", "到", "往", "回", "走过去", "过去"]:
		if verb in compact:
			return true
	return false


func _is_non_commitment(compact: String) -> bool:
	for marker in ["不去", "去不了", "去过", "到过", "没去", "别去"]:
		if marker in compact:
			return true
	return false

extends Node
## 人设与能力边界校验（XL-B4）：拦截越界指令，返回小狸语气的拒答。

const BOND_HARVEST_MIN := 20

var _farm_plot_config: Dictionary = {}
var _farm_plot_config_loaded: bool = false


func check_intent(intent: Dictionary) -> Dictionary:
	if str(intent.get("intent", "")) == IntentParser.INTENT_REFUSE:
		return {
			"blocked": true,
			"reply": _refuse_reply(str(intent.get("refuse_kind", ""))),
		}

	if not IntentParser.is_action_intent(intent):
		return {"blocked": false, "reply": ""}

	if TaskSystem.is_busy():
		return {
			"blocked": true,
			"reply": "……还在忙。等一下。",
		}

	var action := str(intent.get("intent", ""))
	if action in [IntentParser.INTENT_HARVEST, IntentParser.INTENT_HARVEST_ALL]:
		if not can_delegate_harvest():
			return {
				"blocked": true,
				"reply": "萝卜你来收。我馋，规矩不让。",
			}

	if action == IntentParser.INTENT_SLEEP and TaskSystem.is_busy():
		return {
			"blocked": true,
			"reply": "我还在外面。等我回来再睡。",
		}

	return {"blocked": false, "reply": ""}


func check_execution_failure(intent: Dictionary, failure: Dictionary) -> String:
	var reason := str(failure.get("reason", ""))
	match reason:
		"busy":
			return "还在忙。等一下。"
		"no_growing":
			return reply_when_cannot_water()
		"no_plots":
			return reply_when_already_watered()
		"plot_already_watered":
			return "那块今天浇过了。"
		"plot_not_found":
			return "哪一块？说第几块。"
		"plot_not_growing":
			return "那块还没种，或者该收了。"
		"bond_water":
			return "田还干着。要浇你说一声。"
		"bond_harvest":
			return "你来收。我帮你看哪块熟了。"
		"no_harvestable":
			return "还没有能收的。"
		"plot_not_harvestable":
			return "那块还不行。"
		"no_seeds":
			return "没种了。商店在东边。"
		"no_empty_plots":
			return "没空田了。"
		"plot_not_empty":
			return "那块已经有苗了。"
		_:
			return "这个我帮不上。换一句？"


func reply_when_cannot_water() -> String:
	var summary := GameState.get_plot_summary()
	var empty := int(summary.get("empty", 0))
	var seeds := int(GameState.get_item_count("turnip_seed"))
	if empty > 0 and seeds <= 0:
		return "空田在那，种子没了。先去商店。"
	if empty > 0:
		return "还没种呢。空田浇水没用。"
	return "这会儿没什么能浇的。"


func reply_when_already_watered() -> String:
	var summary := GameState.get_plot_summary()
	var harvestable := int(summary.get("harvestable", 0))
	if harvestable > 0:
		return "今天浇过了。有 %d 块能收了。" % harvestable
	return "今天该浇的都浇了。"


func reply_when_cannot_plant() -> String:
	var summary := GameState.get_plot_summary()
	var empty := int(summary.get("empty", 0))
	var seeds := int(GameState.get_item_count("turnip_seed"))
	if empty <= 0:
		return "没空田了。"
	if seeds <= 0:
		return "种子没了。商店在东边。"
	return "这会儿种不了。再说一遍？"


func reply_when_cannot_harvest() -> String:
	if not can_delegate_harvest():
		return "你来收。我望风——不对，我馋。"
	var harvestable := int(GameState.get_plot_summary().get("harvestable", 0))
	if harvestable <= 0:
		return "还没有能收的。"
	return "稍等。我还走不开。"


func farm_reaction_banned_phrase(line: String) -> String:
	_ensure_farm_plot_config()
	for phrase in _farm_plot_config.get("ai_banned", []):
		if str(phrase) in line:
			return str(phrase)
	return ""


func _ensure_farm_plot_config() -> void:
	if _farm_plot_config_loaded:
		return
	_farm_plot_config_loaded = true
	const PATH := "res://config/farm_plot_reactions.json"
	if not FileAccess.file_exists(PATH):
		push_warning("PersonaGuard: missing %s" % PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_farm_plot_config = parsed


func reply_for_plot_click(reason: String) -> String:
	var key := reason
	if reason == "harvest_failed" and not can_delegate_harvest():
		key = "harvest_bond"
	var pool: Array = _plot_click_pool(key)
	if pool.is_empty():
		return ""
	if pool.size() == 1:
		return str(pool[0])
	return NpcFallback.pick_random(pool)


func _plot_click_pool(reason: String) -> Array:
	_ensure_farm_plot_config()
	var tone := _farm_plot_tone()
	var table: Variant = _farm_plot_config.get(tone, {})
	if not table is Dictionary:
		table = _farm_plot_config.get("default", {})
	return (table as Dictionary).get(reason, [])


func _farm_plot_tone() -> String:
	if StoryDirector.is_stranger_mode():
		return "stranger"
	if GameState.IS_TEN_DAY_EDITION and GameState.game_day <= 3:
		return "early"
	return "default"


func reply_when_shop_not_done() -> String:
	var seeds := int(GameState.get_item_count("turnip_seed"))
	if seeds <= 0:
		return "种子还没买。商店在东边。"
	return "种子在篮子里。还没种。"


func can_delegate_water() -> bool:
	return true


func can_delegate_harvest() -> bool:
	return GameState.affection >= BOND_HARVEST_MIN


func _can_delegate_water() -> bool:
	return can_delegate_water()


func _refuse_reply(kind: String) -> String:
	match kind:
		"sell":
			return "好。筐里有的，我去换。"
		_:
			return "这个不行。田的事我还在。"

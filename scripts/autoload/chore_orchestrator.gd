extends Node
## 农务指令编排：多步队列、本地纠错、Say-Do 补执行。

signal plan_step_started(step: Dictionary, index: int)
signal plan_finished(summary: String)

var _queue: Array = []
var _last_player_request := ""
var _last_executed_steps: Array[String] = []
var _player_was_affirmative := false

const OFFER_STEP_MAP := {
	PendingOfferStore.OfferType.WATER: "water_all",
	PendingOfferStore.OfferType.HARVEST: "harvest_all",
	PendingOfferStore.OfferType.PLANT: "plant_all",
	PendingOfferStore.OfferType.SHOP: "shop_buy_seeds",
}


func _ready() -> void:
	TaskSystem.task_completed.connect(_on_task_completed)


func get_chore_facts() -> Dictionary:
	var busy := ""
	if TaskSystem.is_busy():
		match TaskSystem.current_task:
			TaskSystem.TaskType.WATER:
				busy = "water"
			TaskSystem.TaskType.HARVEST:
				busy = "harvest"
			TaskSystem.TaskType.PLANT:
				busy = "plant"
			TaskSystem.TaskType.SHOP:
				busy = "shop"
			_:
				busy = "busy"
	return {
		"last_completed": _last_executed_steps.duplicate(),
		"pending_plan": _queue.duplicate(true),
		"turnip_in_basket": int(GameState.get_item_count("turnip")),
		"seeds_in_inventory": int(GameState.get_item_count("turnip_seed")),
		"gold": int(GameState.coins),
		"companion_busy": busy,
		"last_player_request": _last_player_request,
		"last_task_summary": GameState.last_task_summary,
	}


func handle_player_message(text: String) -> Dictionary:
	## 本地预处理。handled=true 时 skip_llm 决定是否仍请求 LLM。
	_player_was_affirmative = PendingOfferStore.is_confirmable_player(text)
	TaskSystem.reconcile_stale_task()

	if ChorePreprocessor.looks_like_player_correction(text):
		return {"handled": true, "skip_llm": true, "reply": reply_player_correction(text)}

	if ChorePreprocessor.looks_like_seed_location_inquiry(text):
		return {"handled": true, "skip_llm": true, "reply": reply_seed_location()}

	if _try_chore_nudge(text):
		return {"handled": true, "skip_llm": true, "reply": _last_nudge_reply}

	var progress := PersonaGuard.reply_for_chore_progress_inquiry(text)
	if progress.strip_edges() != "":
		return {"handled": true, "skip_llm": true, "reply": progress}

	if ShopDelegate.is_negative_reply(text) and PendingOfferStore.has_any():
		PendingOfferStore.clear()
		return {"handled": true, "skip_llm": true, "reply": "好，那你需要的时候再叫我。"}

	if PendingOfferStore.is_confirmable_player(text):
		var confirm := try_confirm_offer(text)
		if bool(confirm.get("handled", false)):
			return confirm

	if TaskSystem.is_busy() and ChorePreprocessor.should_block_llm_for_busy_farm_chat(text):
		var busy_line := PersonaGuard.reply_for_chore_progress_inquiry(text)
		if busy_line.strip_edges() == "":
			busy_line = "还在忙，稍等一下。"
		return {"handled": true, "skip_llm": true, "reply": busy_line}

	var plan := ChorePreprocessor.parse_plan(text)
	if plan.size() >= 2 or ChorePreprocessor.should_auto_start_single_plan(text, plan):
		_last_player_request = text
		var started := enqueue_and_start(plan, text)
		var reply := str(started.get("reply", "")).strip_edges()
		if reply == "":
			if bool(started.get("executed", false)):
				reply = "好，我这就去。"
			else:
				reply = "这会儿还走不开，稍等我一下。"
		return {
			"handled": true,
			"skip_llm": true,
			"reply": reply,
			"executed": bool(started.get("executed", false)),
		}

	return {"handled": false, "skip_llm": false}


var _last_nudge_reply := ""


func try_confirm_offer(text: String) -> Dictionary:
	if not PendingOfferStore.has_any():
		PendingOfferStore.infer_from_recent_companion_lines(PendingOfferStore.recent_companion_lines(4))
	if not PendingOfferStore.has_any():
		return {"handled": false}

	var step_key: String = OFFER_STEP_MAP.get(PendingOfferStore.get_type(), "")
	var raw := PendingOfferStore.get_source_line()
	if step_key == "":
		PendingOfferStore.clear()
		return {"handled": false}

	var result := execute_step({"step": step_key, "raw_text": raw if raw != "" else text})
	PendingOfferStore.clear()
	var executed := bool(result.get("executed", false))
	var reply := str(result.get("reply", "")).strip_edges()
	if reply == "":
		reply = "好，我这就去。" if executed else "这会儿还走不开，稍等我一下。"
	return {"handled": true, "skip_llm": true, "reply": reply, "executed": executed}


func enqueue_and_start(plan: Array, player_text: String) -> Dictionary:
	_queue.clear()
	for step in plan:
		if step is Dictionary and str(step.get("step", "")) != "":
			_queue.append(step.duplicate(true))
	if _queue.is_empty():
		return {"executed": false, "queued": false}
	_last_player_request = player_text
	return _start_next_step()


func execute_plan_from_api(plan: Array, player_text: String) -> Dictionary:
	var normalized := ChorePreprocessor.normalize_plan_steps(plan, player_text)
	if normalized.is_empty():
		return {"executed": false, "executed_steps": []}
	if TaskSystem.is_busy() and _queue.is_empty():
		_queue = normalized.duplicate(true)
		return {"executed": false, "queued": true, "executed_steps": _last_executed_steps.duplicate()}
	return enqueue_and_start(normalized, player_text)


func execute_reply_followthrough(reply_text: String, api_intent: Dictionary) -> Dictionary:
	var executed: Array[String] = []
	var plan: Variant = api_intent.get("plan", [])
	if plan is Array and not plan.is_empty():
		var batch := execute_plan_from_api(plan, str(api_intent.get("raw_text", "")))
		for step in batch.get("executed_steps", []):
			executed.append(str(step))
		if bool(batch.get("executed", false)) or bool(batch.get("queued", false)):
			return {"executed_steps": executed, "handled": true}

	if not api_intent.is_empty() and IntentParser.is_action_intent(api_intent):
		var guard := PersonaGuard.check_intent(api_intent)
		if not bool(guard.get("blocked", false)):
			var result := ActionExecutor.execute(api_intent)
			if bool(result.get("executed", false)):
				var step := _intent_to_step(str(api_intent.get("intent", "")))
				if step != "":
					_record_step(step)
					executed.append(step)
				return {"executed_steps": executed, "handled": true}

	for step_key in SayDoValidator.implied_steps_from_reply(reply_text):
		var step_result := execute_step({"step": step_key, "raw_text": reply_text})
		if bool(step_result.get("executed", false)):
			_record_step(step_key)
			executed.append(step_key)
			return {"executed_steps": executed, "handled": true}

	return {"executed_steps": executed, "handled": false}


func finalize_reply(reply: String, executed_steps: Array, player_text: String) -> String:
	return SayDoValidator.enforce(reply, executed_steps, player_text)


func execute_step(step: Dictionary) -> Dictionary:
	var step_key := str(step.get("step", "")).strip_edges()
	var raw := str(step.get("raw_text", "")).strip_edges()
	if step_key.is_empty():
		return {"executed": false, "reason": "empty_step"}

	if TaskSystem.is_busy() and step_key in ["harvest_all", "plant_all", "water_all", "shop_buy_seeds"]:
		return {"executed": false, "queued": true, "reply": "还在忙上一件事，做完这个就去。"}

	match step_key:
		"harvest_all":
			if not PersonaGuard.can_delegate_harvest():
				return {"executed": false, "reply": PersonaGuard.reply_when_cannot_harvest()}
			var result := ActionExecutor.execute({
				"intent": IntentParser.INTENT_HARVEST_ALL,
				"plot_id": -1,
				"raw_text": raw,
			})
			if bool(result.get("executed", false)):
				_record_step("harvest_all")
			return result
		"sell_turnips":
			var sold := ActionExecutor.execute({
				"intent": IntentParser.INTENT_OPEN_MARKET,
				"plot_id": -1,
				"raw_text": raw,
			})
			if bool(sold.get("executed", false)):
				_record_step("sell_turnips")
				var extra := str(sold.get("companion_extra", "")).strip_edges()
				return {"executed": true, "reply": extra if extra != "" else GameState.last_task_summary}
			return sold
		"shop_buy_seeds":
			return _execute_buy_seeds(step)
		"plant_all":
			var plant_result := ActionExecutor.execute({
				"intent": IntentParser.INTENT_PLANT_ALL,
				"plot_id": -1,
				"raw_text": raw,
			})
			if bool(plant_result.get("executed", false)):
				_record_step("plant_all")
			return plant_result
		"water_all":
			var water_result := ActionExecutor.execute({
				"intent": IntentParser.INTENT_WATER_ALL,
				"plot_id": -1,
				"raw_text": raw,
			})
			if bool(water_result.get("executed", false)):
				_record_step("water_all")
			return water_result
		"sleep":
			var sleep_result := ActionExecutor.execute({
				"intent": IntentParser.INTENT_SLEEP,
				"plot_id": -1,
				"raw_text": raw,
			})
			return sleep_result
		_:
			return {"executed": false, "reason": "unknown_step"}


func reply_player_correction(text: String) -> String:
	var compact := text.replace(" ", "")
	if compact.contains("卖") and compact.contains("收"):
		if _last_executed_steps.has("sell_turnips"):
			return "你说得对，是卖萝卜。刚才已经卖过了：%s" % GameState.last_task_summary
		if int(GameState.get_item_count("turnip")) > 0:
			var sold := ActionExecutor.execute({
				"intent": IntentParser.INTENT_OPEN_MARKET,
				"plot_id": -1,
				"raw_text": text,
			})
			if bool(sold.get("executed", false)):
				_record_step("sell_turnips")
				return "对不起，刚才搞混了。现在我帮你卖了。"
		return "对不起，刚才搞混了。筐里还没有萝卜可卖。"
	if compact.contains("为啥") or compact.contains("为什么"):
		if compact.contains("卖"):
			if int(GameState.get_item_count("turnip")) <= 0 and "卖" in GameState.last_task_summary:
				return GameState.last_task_summary if GameState.last_task_summary.ends_with("。") else GameState.last_task_summary + "。"
			return "还没卖呢。要我现在帮你卖吗？"
		if compact.contains("浇"):
			var unwatered := GameState.get_unwatered_growing_plot_ids()
			if unwatered.is_empty():
				return PersonaGuard.reply_when_already_watered()
			return "还没浇完。还有 %d 块田等着呢。" % unwatered.size()
	return "对不起，刚才没接对。你再说一次要我做什么？"


func reply_seed_location() -> String:
	var count := int(GameState.get_item_count("turnip_seed"))
	if count <= 0:
		return "背包里还没有种子。要去商店买吗？"
	return "种子在篮子里，现在有 %d 包萝卜种子。" % count


func arm_companion_line(text: String) -> void:
	PendingOfferStore.arm_from_companion_line(text)


func player_was_affirmative() -> bool:
	return _player_was_affirmative


func get_last_executed_steps() -> Array:
	return _last_executed_steps.duplicate()


func buy_seeds_from_text(raw: String, max_gold: bool = false) -> Dictionary:
	return _execute_buy_seeds({
		"step": "shop_buy_seeds",
		"raw_text": raw,
		"max_gold": max_gold or ChorePreprocessor.looks_like_max_gold_seed_buy(raw),
	})


func _execute_buy_seeds(step: Dictionary) -> Dictionary:
	var raw := str(step.get("raw_text", ""))
	var max_gold := bool(step.get("max_gold", false))
	var preset := ShopDelegate.parse_seed_purchase_quantity(raw) if raw != "" else 0
	if preset <= 0 and max_gold:
		var price := GameState.get_seed_buy_price()
		if price <= 0:
			return {"executed": false, "reply": "商店还没开价。"}
		preset = int(GameState.coins / price)
	if preset <= 0:
		if TaskSystem.start_shop_task(true):
			get_tree().call_group("main_ui", "begin_companion_seed_purchase_from_orchestrator", raw)
			_record_step("shop_buy_seeds")
			return {"executed": true, "reply": "好，我先去商店。要买几包？"}
		return {"executed": false, "reply": "这会儿还走不开，稍等我一下。"}
	var bought := GameState.buy_shop_item_count("turnip_seed", preset)
	if bool(bought.get("ok", false)):
		_record_step("shop_buy_seeds")
		return {"executed": true, "reply": str(bought.get("message", "买好了。"))}
	var affordable := int(bought.get("affordable_count", 0))
	if affordable > 0:
		var partial := GameState.buy_shop_item_count("turnip_seed", affordable)
		if bool(partial.get("ok", false)):
			_record_step("shop_buy_seeds")
			return {"executed": true, "reply": str(partial.get("message", "能买的我都买了。"))}
	return {"executed": false, "reply": str(bought.get("message", "金币不够买种子。"))}


func _start_next_step() -> Dictionary:
	if _queue.is_empty():
		return {"executed": false, "queued": false}
	var step: Dictionary = _queue[0]
	var result := execute_step(step)
	if bool(result.get("queued", false)):
		return {"executed": false, "queued": true, "reply": str(result.get("reply", ""))}
	if bool(result.get("executed", false)):
		_queue.remove_at(0)
		plan_step_started.emit(step, 0)
		if _is_sync_step(str(step.get("step", ""))):
			return _continue_after_sync(str(result.get("reply", "")))
		return {"executed": true, "reply": _step_start_reply(str(step.get("step", "")))}
	_queue.remove_at(0)
	return {"executed": false, "reply": str(result.get("reply", ""))}


func _continue_after_sync(prev_reply: String) -> Dictionary:
	if _queue.is_empty():
		plan_finished.emit(prev_reply)
		return {"executed": true, "reply": prev_reply}
	return _start_next_step()


func _on_task_completed(_task_type: int, summary: String, _facts: Dictionary) -> void:
	if _queue.is_empty():
		return
	var next := _start_next_step()
	var reply := str(next.get("reply", "")).strip_edges()
	if reply != "":
		get_tree().call_group("main_ui", "append_companion_line_from_orchestrator", reply)
	elif _queue.is_empty():
		plan_finished.emit(summary)


func _step_start_reply(step_key: String) -> String:
	match step_key:
		"harvest_all":
			return "好，我这就去收。"
		"water_all":
			return "好，我这就去浇。"
		"plant_all":
			return "好，我这就去种。"
		"shop_buy_seeds":
			return "好，我先去商店买种子。"
		_:
			return ""


func _is_sync_step(step_key: String) -> bool:
	return step_key == "sell_turnips"


func _record_step(step_key: String) -> void:
	if step_key == "":
		return
	if step_key not in _last_executed_steps:
		_last_executed_steps.append(step_key)
	if _last_executed_steps.size() > 8:
		_last_executed_steps = _last_executed_steps.slice(_last_executed_steps.size() - 8, _last_executed_steps.size())


func _intent_to_step(intent_key: String) -> String:
	return ChorePreprocessor.map_intent_to_step(intent_key)


func _looks_like_explicit_delegate(text: String) -> bool:
	return ChorePreprocessor.looks_like_explicit_delegate(text)


func _try_chore_nudge(text: String) -> bool:
	_last_nudge_reply = ""
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	if compact == "" or not compact.contains("浇"):
		return false
	var markers := ["不是要", "不是说", "刚刚", "刚才", "怎么还", "怎么没", "说去", "说好了", "我让你", "让你去", "听不懂"]
	var hit := false
	for marker in markers:
		if marker in compact:
			hit = true
			break
	if not hit:
		return false
	TaskSystem.reconcile_stale_task()
	if TaskSystem.is_busy() and TaskSystem.current_task == TaskSystem.TaskType.WATER:
		_last_nudge_reply = "还在浇水呢，马上好。"
		return true
	if GameState.get_unwatered_growing_plot_ids().is_empty():
		_last_nudge_reply = PersonaGuard.reply_when_already_watered()
		return true
	var result := execute_step({"step": "water_all", "raw_text": text})
	if bool(result.get("executed", false)):
		_last_nudge_reply = "对不起，刚才嘴上说了没动身。我这就去浇。"
	else:
		_last_nudge_reply = str(result.get("reply", "这会儿还走不开，稍等我一下。"))
	return true

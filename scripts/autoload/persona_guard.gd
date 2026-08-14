extends Node
## 人设与能力边界校验（XL-B4）：拦截越界指令，返回小狸语气的拒答。

const BOND_HARVEST_MIN := 20


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
			"reply": "我还在忙上一件事，稍等一下再吩咐我。",
		}

	var action := str(intent.get("intent", ""))
	if action in [IntentParser.INTENT_HARVEST, IntentParser.INTENT_HARVEST_ALL]:
		if not can_delegate_harvest():
			return {
				"blocked": true,
				"reply": "萝卜得你来收才踏实。不过我可以帮你看哪块田已经熟了。",
			}

	if action == IntentParser.INTENT_SLEEP and TaskSystem.is_busy():
		return {
			"blocked": true,
			"reply": "我还在外面忙，等我回来再一起休息吧。",
		}

	return {"blocked": false, "reply": ""}


func check_execution_failure(intent: Dictionary, failure: Dictionary) -> String:
	var reason := str(failure.get("reason", ""))
	match reason:
		"busy":
			return "我还在忙，稍等一下。"
		"no_growing":
			return reply_when_cannot_water()
		"no_plots":
			return reply_when_already_watered()
		"plot_already_watered":
			return "那块田今天已经浇过了。"
		"plot_not_found":
			return "我没找到你说那块田……是哪一块？你说第几块，我就去。"
		"plot_not_growing":
			return "那块田还没种下萝卜，或者已经可以收获了。"
		"bond_water":
			return "田里的萝卜好像还没浇呢，要不要我帮你浇一下？"
		"bond_harvest":
			return "萝卜得你来收我才安心。要不要我先帮你看哪块熟了？"
		"no_harvestable":
			return "现在还没有可以收的萝卜。"
		"plot_not_harvestable":
			return "那块田的萝卜还没熟，或者已经收过了。"
		"no_seeds":
			return "背包里没有萝卜种子了，先去商店买点吧。要不要我帮你去买？"
		"no_empty_plots":
			return "现在没有空田可以种。"
		"plot_not_empty":
			return "那块田已经有萝卜了，换一块空田吧。"
		_:
			return "这个我暂时帮不上，我们换个方式试试。"


func reply_when_cannot_water() -> String:
	## 田里没有在长的作物：实话 + 主动要活。
	var summary := GameState.get_plot_summary()
	var empty := int(summary.get("empty", 0))
	var seeds := int(GameState.get_item_count("turnip_seed"))
	if empty > 0 and seeds <= 0:
		return "田里还空着，也没有萝卜种子——浇也浇不到苗上。要不要我去商店买几包，种上再浇？"
	if empty > 0:
		return "田里还没有萝卜呢，空田浇水也没用。要不要我先帮你把空田种上？"
	return "这会儿田里没什么能浇的。要不要我去买种子，还是先歇一会儿？"


func reply_when_already_watered() -> String:
	var summary := GameState.get_plot_summary()
	var harvestable := int(summary.get("harvestable", 0))
	if harvestable > 0:
		return "今天需要浇的田都浇过了。有 %d 块已经能收了，要不要你去看看？" % harvestable
	return "今天需要浇的田都浇过了。还想让我帮你做什么？种田、买种子都可以说。"


func reply_when_cannot_plant() -> String:
	var summary := GameState.get_plot_summary()
	var empty := int(summary.get("empty", 0))
	var seeds := int(GameState.get_item_count("turnip_seed"))
	if empty <= 0:
		return "现在没有空田可以种了。要不要我去浇水，还是先歇一会儿？"
	if seeds <= 0:
		return "空田还有，可背包里没有萝卜种子。要不要我去商店买几包种上？"
	return "这会儿还种不了。你再说一次，我再帮你。"


func reply_when_cannot_harvest() -> String:
	if not can_delegate_harvest():
		return "萝卜得你来收才踏实。不过我可以帮你看哪块田已经熟了。"
	var harvestable := int(GameState.get_plot_summary().get("harvestable", 0))
	if harvestable <= 0:
		return "现在还没有可以收的萝卜。"
	return "这会儿还走不开，稍等我一下再收。"


func reply_when_shop_not_done() -> String:
	var seeds := int(GameState.get_item_count("turnip_seed"))
	if seeds <= 0:
		return "种子还没买呢。要不要我去商店买几包？"
	return "种子还在背包里，还没新买。要不要我现在去种上？"


func can_delegate_water() -> bool:
	return true


func can_delegate_harvest() -> bool:
	return GameState.affection >= BOND_HARVEST_MIN


func _can_delegate_water() -> bool:
	return can_delegate_water()


func _refuse_reply(kind: String) -> String:
	match kind:
		"sell":
			return "好。筐里有的，我帮你换成金币。"
		_:
			return "这件事我帮不了，但田和家园的事我还在。"

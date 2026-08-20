extends Node
## 记忆检索与引用校验（XL-C0～C1）。

signal memory_updated
signal anchor_eviction_pending(candidates: Array)

const MAX_CITABLE := 3
const ANCHOR_CAP := 12
const TEN_DAY_ANCHOR_CAP := 6
const MAX_WEEK_SUMMARIES := 5
const MAX_WEEK_HIGHLIGHTS := 8
const LIFE_PAGE_KINDS := ["task_water", "task_plant", "task_harvest", "day_end", "journal_chat", "gift"]
const CITABLE_EVENTS := [
	"player_chat",
	"task_complete",
	"companion_proactive",
	"companion_casual",
	"morning_sidewrite",
	"session_start",
	"companion_react",
]


func anchor_cap() -> int:
	return TEN_DAY_ANCHOR_CAP if GameState.IS_TEN_DAY_EDITION else ANCHOR_CAP


func notebook_line_of(entry: Dictionary) -> String:
	var line := strip_notebook_meta(str(entry.get("notebook_line", "")).strip_edges())
	if looks_like_system_label(line):
		line = ""
	if line != "":
		return line
	var summary := strip_notebook_meta(str(entry.get("summary", "")).strip_edges())
	if looks_like_system_label(summary):
		return ""
	return summary


func looks_like_system_label(text: String) -> bool:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return true
	if is_generic_farm_log(cleaned):
		return true
	if looks_like_journal_digest(cleaned):
		return true
	if cleaned.begins_with("第") and "天，" in cleaned:
		return true
	if cleaned.begins_with("你说："):
		return true
	if "小狸写进本子" in cleaned:
		return true
	if " · " in cleaned:
		var left := cleaned.get_slice(" · ", 0)
		if left in ["白天", "傍晚", "夜晚", "清晨", "夜里"]:
			return true
	return false


func strip_notebook_meta(text: String) -> String:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return ""
	for tail in [
		"我怕忘，先写在这里。",
		"我怕忘，先写在这里",
		"我先记下。",
		"我先记下",
		"我写下来了。",
		"我写下来了",
		"我怕念错，写在第一页。",
		"我怕念错，写在第一页",
	]:
		if cleaned.ends_with(tail):
			cleaned = cleaned.substr(0, cleaned.length() - tail.length()).strip_edges()
			break
	return cleaned


func looks_like_journal_digest(text: String) -> bool:
	## 日结腰封，不能当她的口头记忆念出来。
	var cleaned := text.strip_edges()
	if cleaned == "":
		return false
	if cleaned.begins_with("你们聊了"):
		return true
	if cleaned.begins_with("你们在") and "聊了" in cleaned:
		return true
	if "聊了几句" in cleaned:
		return true
	if "句，最后提到" in cleaned or "句，小狸" in cleaned:
		return true
	if cleaned.begins_with("刚才那一下，像真做过"):
		return true
	return false


func looks_like_relationship_audit(text: String) -> bool:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return false
	for marker in ["关系仍", "关系还陌生", "对话简短", "亲密度", "关系阶段", "仍很生疏", "还不熟", "关系生疏", "关系疏远"]:
		if marker in cleaned:
			return true
	return false


func player_facing_journal_line(text: String) -> String:
	## 信纸 / 觉醒只留做过的事，去掉「聊天 ·」和关系档评估。
	var cleaned := text.strip_edges()
	while cleaned.begins_with("·"):
		cleaned = cleaned.substr(1).strip_edges()
	for prefix in ["归档 ·", "归档·", "聊天 ·", "聊天·", "主线 ·", "主线·"]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length()).strip_edges()
	cleaned = strip_relationship_audit_sentences(cleaned)
	if cleaned == "" or looks_like_journal_digest(cleaned) or looks_like_system_label(cleaned) or is_generic_farm_log(cleaned):
		return ""
	if looks_like_relationship_audit(cleaned):
		return ""
	return cleaned


func strip_relationship_audit_sentences(text: String) -> String:
	var parts := text.split("。")
	var kept: Array[String] = []
	for part in parts:
		var sentence := part.strip_edges()
		if sentence == "":
			continue
		if looks_like_relationship_audit(sentence):
			continue
		kept.append(sentence)
	if kept.is_empty():
		return ""
	var joined := "。".join(kept)
	if not joined.ends_with("。") and text.ends_with("。"):
		joined += "。"
	return joined


func is_generic_farm_log(text: String) -> bool:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return false
	return cleaned.begins_with("第") and "打理了农场" in cleaned


func eviction_spoken_excerpt(entry: Dictionary) -> String:
	## 只念本子正文。空页或系统摘要保持沉默，避免把「第 N 天，聊天 · …」读出口。
	var line := notebook_line_of(entry)
	if line == "":
		return ""
	if line.length() > 28:
		return line.substr(0, 28) + "…"
	return line


func compose_notebook_line(kind: String, summary: String, facts: Dictionary = {}) -> String:
	match kind:
		"name_set":
			var pname := str(facts.get("player_name", GameState.player_name)).strip_edges()
			if pname == "":
				return ""
			return "你让我叫你「%s」。" % pname
		"promise":
			var promise_text := str(facts.get("promise_summary", "")).strip_edges()
			if promise_text == "":
				promise_text = summary.replace("小狸写进本子：", "").strip_edges()
			if promise_text == "":
				return ""
			return promise_text if promise_text.ends_with("。") else promise_text + "。"
		"promise_done":
			return "约定兑了。萝卜长好了，我们一起看过。"
		"chat":
			var said := str(facts.get("text", "")).strip_edges()
			if said == "":
				said = summary.replace("你说：“", "").replace("你说：「", "").trim_suffix("”").trim_suffix("」").strip_edges()
			if said == "":
				return ""
			if said.length() > 28:
				said = said.substr(0, 28) + "…"
			return "你说「%s」。" % said
		"task_water":
			return "今天把田浇过了。手还记得垄。"
		"task_plant":
			return "今天一起下了种。土还松着。"
		"task_harvest":
			return "萝卜收上来了。你说要一起看的那畦。"
		"journal_chat", "day_end":
			return _life_journal_line(summary, facts)
		"story_beat":
			return ""
		_:
			if looks_like_system_label(summary):
				return ""
			return strip_notebook_meta(summary.strip_edges())


func _life_journal_line(summary: String, facts: Dictionary) -> String:
	var highlights: Variant = facts.get("highlights", [])
	if highlights is Array and highlights.size() > 0:
		var highlight := str(highlights[0]).strip_edges()
		if highlight.begins_with("聊天 ·"):
			highlight = highlight.substr(4).strip_edges()
		if highlight != "" and not looks_like_system_label(highlight):
			if highlight.length() > 36:
				highlight = highlight.substr(0, 36) + "…"
			return "今天：%s。" % highlight.trim_suffix("。")
	var cleaned := summary.strip_edges()
	if cleaned == "" or looks_like_system_label(cleaned):
		return ""
	if cleaned.length() > 36:
		cleaned = cleaned.substr(0, 36) + "…"
	return cleaned


func has_life_page_today() -> bool:
	var day := GameState.game_day
	for raw in GameState.long_term_memory.get("anchors", []):
		if not raw is Dictionary:
			continue
		if int(raw.get("game_day", 0)) != day:
			continue
		if str(raw.get("kind", "")) in LIFE_PAGE_KINDS:
			return true
	return false


func should_promote_to_anchor(kind: String, importance: float, notebook_line: String) -> bool:
	if notebook_line.strip_edges() == "" or looks_like_system_label(notebook_line):
		return false
	if kind == "story_beat":
		return false
	if importance >= 0.75:
		return true
	if not GameState.IS_TEN_DAY_EDITION:
		return false
	if StoryDirector.is_stranger_mode():
		return false
	if kind in LIFE_PAGE_KINDS and not has_life_page_today():
		return true
	return false


func latest_notebook_line_for_day(day: int) -> String:
	var best := ""
	for raw in GameState.long_term_memory.get("anchors", []):
		if not raw is Dictionary:
			continue
		if int(raw.get("game_day", 0)) != day:
			continue
		var line := notebook_line_of(raw)
		if line != "":
			best = line
	return best


func infer_cited_ids_from_reply(reply: String) -> Array[String]:
	var hits: Array[String] = []
	var text := reply.strip_edges()
	if text == "" or StoryDirector.is_stranger_mode():
		return hits
	for entry in get_citable_memories("player_chat", {}):
		var line := notebook_line_of(entry)
		if line.length() < 6:
			continue
		var probe := line.substr(0, mini(10, line.length()))
		if probe in text or line in text:
			hits.append(str(entry.get("id", "")))
	return hits


func reply_already_voices_citation(reply: String, cited_ids: Array) -> bool:
	var text := reply.strip_edges()
	if text == "":
		return false
	for raw_id in cited_ids:
		var line := lookup_memory_summary(str(raw_id))
		if line.length() < 6:
			continue
		var probe := line.substr(0, mini(8, line.length()))
		if probe in text or line in text:
			return true
	return false

var debug_disable_memory := false


func get_context_for_event(event: String, extra: Dictionary = {}) -> Dictionary:
	var story_mode := StoryDirector.get_story_mode()
	var boundaries := get_story_boundaries()
	var base := {
		"week_index": GameState.get_week_index(),
		"loop_day": GameState.get_loop_day(),
		"revealed": GameState.has_revealed_memory(),
		"story_mode": story_mode,
		"story_boundaries": boundaries,
		"persona_vector": GameState.long_term_memory.get("persona", {}).duplicate(true),
		"behavior_inferred": GameState.get_behavior_inferred(),
		"long_term_prefs": _prefs_snapshot(),
		"promise": _promise_snapshot(),
		"citable_memories": [],
		"citable_prompt": "",
		"recent_memories": [],
		"recent_journal": [],
		"cited_memory_ids": [],
	}

	if debug_disable_memory or StoryDirector.is_stranger_mode():
		return base

	var recent := GameState.get_recent_memories(4)
	var citable := get_citable_memories(event, extra)
	var cited_ids: Array[String] = []
	for entry in citable:
		cited_ids.append(str(entry.get("id", "")))

	var journal_slice := GameState.day_journal.slice(
		maxi(0, GameState.day_journal.size() - 3),
		GameState.day_journal.size()
	)
	base["recent_memories"] = recent
	base["recent_journal"] = journal_slice
	base["yesterday_journal"] = GameState.get_yesterday_journal_entry()
	base["pending_absence"] = GameState.get_pending_absence_facts()
	base["citable_memories"] = citable
	base["citable_prompt"] = format_citable_prompt(citable)
	base["cited_memory_ids"] = cited_ids
	return base


func get_story_boundaries() -> Dictionary:
	var mode := StoryDirector.get_story_mode()
	var week := GameState.get_week_index()
	return {
		"story_mode": mode,
		"week_index": week,
		"loop_day": GameState.get_loop_day(),
		"recovery_tier": _recovery_tier(),
		"can_cite_episodic": (
			not StoryDirector.is_stranger_mode()
			if GameState.IS_TEN_DAY_EDITION
			else (not StoryDirector.is_stranger_mode() and week >= 3)
		),
		"can_use_player_name": GameState.companion_can_say_player_name(),
		"forbidden_topics": _forbidden_topics(mode),
	}


func get_citable_memories(event: String, extra: Dictionary = {}) -> Array[Dictionary]:
	if debug_disable_memory or StoryDirector.is_stranger_mode():
		return []
	if str(event) not in CITABLE_EVENTS:
		return []

	var recent: Array = GameState.get_recent_memories(6)
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	var picked: Array[Dictionary] = []
	var seen_ids: Dictionary = {}

	for entry in _pick_relevant_memories(event, extra, recent, anchors):
		var copy := _as_citable(entry)
		if copy.is_empty():
			continue
		var mem_id := str(copy.get("id", ""))
		if mem_id == "" or seen_ids.has(mem_id):
			continue
		seen_ids[mem_id] = true
		picked.append(copy)
		if picked.size() >= MAX_CITABLE:
			break

	if picked.is_empty() and str(event) in CITABLE_EVENTS:
		for entry in anchors.slice(maxi(0, anchors.size() - MAX_CITABLE), anchors.size()):
			var copy := _as_citable(entry)
			if copy.is_empty():
				continue
			var mem_id := str(copy.get("id", ""))
			if mem_id == "" or seen_ids.has(mem_id):
				continue
			seen_ids[mem_id] = true
			picked.append(copy)
			if picked.size() >= MAX_CITABLE:
				break
	return picked


func format_citable_prompt(citable: Array) -> String:
	if citable.is_empty():
		return "（暂无可引用记忆；勿编造共同经历。）"
	var lines: PackedStringArray = []
	for entry in citable:
		if not entry is Dictionary:
			continue
		var mem_id := str(entry.get("id", "")).strip_edges()
		var summary := str(entry.get("summary", "")).strip_edges()
		if mem_id == "" or summary == "":
			continue
		lines.append("#%s %s" % [mem_id, summary])
	return "\n".join(lines)


func validate_citations(cited_ids: Array, story_mode: String = "") -> Dictionary:
	if story_mode == "":
		story_mode = StoryDirector.get_story_mode()
	var invalid: Array[String] = []
	var allowed: Array[String] = []
	if cited_ids.is_empty():
		return {"ok": true, "invalid_ids": invalid, "allowed_ids": allowed}

	for raw_id in cited_ids:
		var mem_id := str(raw_id).strip_edges()
		if mem_id == "":
			continue
		if StoryDirector.is_stranger_mode() or story_mode == "stranger":
			invalid.append(mem_id)
			continue
		if _has_memory_id(mem_id):
			allowed.append(mem_id)
		else:
			invalid.append(mem_id)

	return {
		"ok": invalid.is_empty(),
		"invalid_ids": invalid,
		"allowed_ids": allowed,
	}


func lookup_memory_summary(mem_id: String) -> String:
	var target := str(mem_id).strip_edges()
	if target == "":
		return ""
	for entry in GameState.get_recent_memories(12):
		if entry is Dictionary and str(entry.get("id", "")) == target:
			return notebook_line_of(entry)
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	for entry in anchors:
		if entry is Dictionary and str(entry.get("id", "")) == target:
			return notebook_line_of(entry)
	return ""


func build_citation_feedback(cited_ids: Array) -> String:
	if cited_ids.is_empty() or StoryDirector.is_stranger_mode():
		return ""
	var summaries: Array[String] = []
	for raw_id in cited_ids:
		var summary := lookup_memory_summary(str(raw_id))
		if summary == "":
			continue
		if summary.length() > 28:
			summary = summary.substr(0, 28) + "…"
		summaries.append(summary)
	if summaries.is_empty():
		return ""
	if summaries.size() == 1:
		return "……%s。刚才一下子冒出来。" % summaries[0]
	return "……好几件旧事一下子挤上来。"


func get_debug_snapshot() -> Dictionary:
	return GameState.get_memory_snapshot()


func notify_memory_changed() -> void:
	memory_updated.emit()


func set_debug_disable_memory(disabled: bool) -> void:
	debug_disable_memory = disabled
	memory_updated.emit()


func enforce_anchor_cap() -> void:
	if has_pending_eviction():
		return
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	while anchors.size() > anchor_cap():
		if _try_queue_player_eviction(anchors):
			return
		var idx := _lowest_evictable_index(anchors)
		if idx < 0:
			break
		var evicted: Dictionary = (anchors[idx] as Dictionary).duplicate(true)
		anchors.remove_at(idx)
		_merge_evicted_anchors([evicted])
	GameState.long_term_memory["anchors"] = anchors
	notify_memory_changed()


func has_pending_eviction() -> bool:
	var pending: Variant = GameState.long_term_memory.get("pending_eviction", {})
	if pending is not Dictionary:
		return false
	var ids: Variant = pending.get("candidate_ids", [])
	return ids is Array and ids.size() >= 2


func get_pending_eviction_candidates() -> Array:
	var pending: Variant = GameState.long_term_memory.get("pending_eviction", {})
	if pending is not Dictionary:
		return []
	var ids: Array = []
	var raw_ids: Variant = pending.get("candidate_ids", [])
	if raw_ids is Array:
		ids = raw_ids.duplicate()
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	var out: Array = []
	for raw_id in ids:
		var mem_id := str(raw_id).strip_edges()
		if mem_id == "":
			continue
		for entry in anchors:
			if entry is Dictionary and str(entry.get("id", "")) == mem_id:
				out.append(entry.duplicate(true))
				break
	return out


func resolve_eviction(erase_id: String) -> void:
	erase_id = erase_id.strip_edges()
	if erase_id == "" or not has_pending_eviction():
		return
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	var evicted: Dictionary = {}
	for i in range(anchors.size()):
		if not anchors[i] is Dictionary:
			continue
		if str(anchors[i].get("id", "")) == erase_id:
			evicted = (anchors[i] as Dictionary).duplicate(true)
			anchors.remove_at(i)
			break
	GameState.long_term_memory["anchors"] = anchors
	GameState.long_term_memory["pending_eviction"] = {}
	if not evicted.is_empty():
		_merge_evicted_anchors([evicted])
	notify_memory_changed()
	enforce_anchor_cap()


func is_anchor_pinned(entry: Dictionary) -> bool:
	return bool(entry.get("pinned", false))


func get_anchor_pages() -> Array:
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	var pages: Array = []
	for raw in anchors:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var line := notebook_line_of(entry)
		if line == "" or looks_like_system_label(line):
			continue
		pages.append({
			"id": str(entry.get("id", "")),
			"summary": line,
			"notebook_line": line,
			"game_day": int(entry.get("game_day", 0)),
			"kind": str(entry.get("kind", "")),
			"pinned": is_anchor_pinned(entry),
		})
	return pages


func pin_anchor_by_id(mem_id: String) -> bool:
	mem_id = mem_id.strip_edges()
	if mem_id == "":
		return false
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	var changed := false
	for i in range(anchors.size()):
		if not anchors[i] is Dictionary:
			continue
		if str(anchors[i].get("id", "")) != mem_id:
			continue
		var entry: Dictionary = anchors[i]
		entry["pinned"] = true
		entry["importance"] = 1.0
		anchors[i] = entry
		changed = true
		break
	if not changed:
		return false
	GameState.long_term_memory["anchors"] = anchors
	notify_memory_changed()
	return true


func pin_from_player_chat(text: String) -> Dictionary:
	var summary := _extract_pin_summary(text)
	if summary == "":
		summary = _latest_player_chat_line()
	if summary == "":
		return {"ok": false, "reason": "empty"}
	var mem_id := _find_anchor_id_by_summary(summary)
	if mem_id == "":
		mem_id = _promote_summary_to_anchor(summary)
	elif not _has_anchor_id(mem_id):
		mem_id = _promote_existing_memory_to_anchor(mem_id)
	if mem_id == "":
		return {"ok": false, "reason": "no_anchor"}
	if not pin_anchor_by_id(mem_id):
		return {"ok": false, "reason": "pin_failed"}
	enforce_anchor_cap()
	var line := summary
	for raw in GameState.long_term_memory.get("anchors", []):
		if raw is Dictionary and str(raw.get("id", "")) == mem_id:
			line = notebook_line_of(raw)
			if line == "":
				line = summary
			break
	return {"ok": true, "id": mem_id, "summary": line}


func looks_like_pin_request(text: String) -> bool:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return false
	for cue in ["记住这个", "帮我记住", "写进本子", "记进本子", "记进本子里", "别忘掉", "要记得"]:
		if cue in cleaned:
			return true
	return false


func finalize_week_archive(completed_week: int, journal: Array) -> void:
	if completed_week < 1:
		return
	var entry := _build_week_summary_from_journal(completed_week, journal)
	if entry.is_empty():
		return
	_upsert_week_summary(completed_week, entry)
	notify_memory_changed()


func get_week_summary(week_index: int) -> Dictionary:
	for raw in GameState.get_week_summaries():
		if int(raw.get("week_index", -1)) == week_index:
			return raw.duplicate(true)
	return {}


func anchor_score(entry: Dictionary) -> float:
	if is_anchor_pinned(entry):
		return 999.0
	var score := float(entry.get("importance", 0.5))
	var facts: Dictionary = entry.get("facts", {}) if entry.get("facts", {}) is Dictionary else {}
	if facts.has("chat_salience"):
		score = maxf(score, float(facts.get("chat_salience", 0.0)))
	match str(entry.get("kind", "")):
		"story_beat", "promise", "name_set", "promise_done":
			score += 0.15
		"journal_chat":
			score += 0.05
		"chat":
			score -= 0.05
	var day := int(entry.get("game_day", 1))
	var recency := float(day) / maxf(float(GameState.game_day), 1.0)
	score += recency * 0.08
	return score


func _lowest_anchor_index(anchors: Array) -> int:
	return _lowest_evictable_index(anchors, false)


func _lowest_evictable_index(anchors: Array, prefer_unpinned_only: bool = true) -> int:
	var best_idx := -1
	var best_score := INF
	var best_day := 999999
	var found_unpinned := false
	for i in range(anchors.size()):
		if not anchors[i] is Dictionary:
			continue
		var entry: Dictionary = anchors[i]
		if prefer_unpinned_only and is_anchor_pinned(entry):
			continue
		found_unpinned = true
		var score := anchor_score(entry)
		var day := int(entry.get("game_day", 999999))
		if score < best_score or (is_equal_approx(score, best_score) and day < best_day):
			best_score = score
			best_day = day
			best_idx = i
	if prefer_unpinned_only and not found_unpinned:
		return _lowest_evictable_index(anchors, false)
	return best_idx


func _try_queue_player_eviction(anchors: Array) -> bool:
	if StoryDirector.is_stranger_mode() or GameState.is_story_complete():
		return false
	var candidates := _pick_eviction_candidates(anchors, 2)
	if candidates.size() < 2:
		return false
	var ids: Array[String] = []
	for entry in candidates:
		ids.append(str(entry.get("id", "")))
	GameState.long_term_memory["pending_eviction"] = {
		"candidate_ids": ids,
		"queued_day": GameState.game_day,
	}
	anchor_eviction_pending.emit(candidates.duplicate(true))
	notify_memory_changed()
	return true


func _pick_eviction_candidates(anchors: Array, count: int) -> Array:
	var ranked: Array[Dictionary] = []
	for raw in anchors:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		if is_anchor_pinned(entry):
			continue
		ranked.append(entry)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a := anchor_score(a)
		var score_b := anchor_score(b)
		if not is_equal_approx(score_a, score_b):
			return score_a < score_b
		return int(a.get("game_day", 999999)) < int(b.get("game_day", 999999))
	)
	var out: Array = []
	for i in range(mini(count, ranked.size())):
		out.append(ranked[i].duplicate(true))
	return out


func _extract_pin_summary(text: String) -> String:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return ""
	for prefix in ["帮我记住这个", "帮我记住", "记住这个", "写进本子里", "写进本子", "记进本子里", "记进本子", "要记得", "别忘掉"]:
		var idx := cleaned.find(prefix)
		if idx >= 0:
			cleaned = cleaned.substr(idx + prefix.length()).strip_edges()
			break
	cleaned = cleaned.trim_prefix("：").trim_prefix(":").trim_prefix("，").trim_prefix(",").strip_edges()
	cleaned = cleaned.trim_suffix("。").trim_suffix("！").trim_suffix("!").trim_suffix("？").trim_suffix("?").strip_edges()
	if cleaned.length() > 44:
		cleaned = cleaned.substr(0, 44).strip_edges() + "…"
	return cleaned


func _latest_player_chat_line() -> String:
	for i in range(GameState.get_recent_chat_turns(8).size() - 1, -1, -1):
		var turn: Dictionary = GameState.get_recent_chat_turns(8)[i]
		if str(turn.get("role", "")) != "player":
			continue
		var line := str(turn.get("text", "")).strip_edges()
		if line != "" and not looks_like_pin_request(line):
			return line
	return ""


func _find_anchor_id_by_summary(summary: String) -> String:
	var probe := summary.strip_edges()
	if probe == "":
		return ""
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	for raw in anchors:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var line := notebook_line_of(entry)
		if line == "":
			line = str(entry.get("summary", "")).strip_edges()
		if line == probe or probe in line or line in probe:
			return str(entry.get("id", ""))
	for raw in GameState.get_recent_memories(12):
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var line := notebook_line_of(entry)
		if line == "":
			line = str(entry.get("summary", "")).strip_edges()
		if line == probe or probe in line or line in probe:
			return str(entry.get("id", ""))
	return ""


func _promote_summary_to_anchor(summary: String) -> String:
	var line := summary.strip_edges()
	if line == "":
		return ""
	GameState.record_memory_event("chat", line, 1.0, {
		"pinned_request": true,
		"text": line,
	})
	return _find_anchor_id_by_summary(line)


func _has_anchor_id(mem_id: String) -> bool:
	mem_id = mem_id.strip_edges()
	if mem_id == "":
		return false
	for raw in GameState.long_term_memory.get("anchors", []):
		if raw is Dictionary and str(raw.get("id", "")) == mem_id:
			return true
	return false


func _promote_existing_memory_to_anchor(mem_id: String) -> String:
	mem_id = mem_id.strip_edges()
	if mem_id == "":
		return ""
	for raw in GameState.get_recent_memories(12):
		if not raw is Dictionary:
			continue
		if str(raw.get("id", "")) != mem_id:
			continue
		var entry: Dictionary = raw.duplicate(true)
		entry["importance"] = 1.0
		entry["pinned"] = true
		var anchors: Array = GameState.long_term_memory.get("anchors", [])
		anchors.append(entry)
		GameState.long_term_memory["anchors"] = anchors
		enforce_anchor_cap()
		return mem_id
	return ""


func _merge_evicted_anchors(evicted: Array[Dictionary]) -> void:
	var grouped: Dictionary = {}
	for entry in evicted:
		var week := int(entry.get("week_index", GameState.get_week_index()))
		if not grouped.has(week):
			grouped[week] = []
		(grouped[week] as Array).append(entry)
	for week_key in grouped.keys():
		var week := int(week_key)
		var bucket: Array = grouped[week]
		var merged_highlights: Array[String] = []
		var merged_ids: Array[String] = []
		for entry_variant in bucket:
			if not entry_variant is Dictionary:
				continue
			var entry: Dictionary = entry_variant
			var summary := str(entry.get("summary", "")).strip_edges()
			if summary != "":
				merged_highlights.append("归档 · %s" % summary)
			var mem_id := str(entry.get("id", "")).strip_edges()
			if mem_id != "":
				merged_ids.append(mem_id)
		_upsert_week_summary(week, {
			"merged_highlights": merged_highlights,
			"merged_anchor_ids": merged_ids,
		})


func _build_week_summary_from_journal(completed_week: int, journal: Array) -> Dictionary:
	var highlights: Array[String] = []
	var journal_days := 0
	for raw in journal:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		if int(entry.get("week_index", 0)) != completed_week:
			continue
		journal_days += 1
		var entry_highlights: Variant = entry.get("highlights", [])
		if entry_highlights is Array:
			for highlight in entry_highlights:
				var line := str(highlight).strip_edges()
				if line != "":
					highlights = _append_unique_line(highlights, line)
		if highlights.size() >= MAX_WEEK_HIGHLIGHTS:
			break
		if highlights.size() < MAX_WEEK_HIGHLIGHTS:
			var summary := str(entry.get("summary", "")).strip_edges()
			if summary != "":
				highlights = _append_unique_line(highlights, summary)
	return {
		"week_index": completed_week,
		"summary": _compose_week_summary_text(completed_week, highlights),
		"highlights": highlights.slice(0, MAX_WEEK_HIGHLIGHTS),
		"journal_days": journal_days,
		"archived_at_game_day": GameState.game_day,
		"merged_highlights": [],
		"merged_anchor_ids": [],
	}


func _upsert_week_summary(week_index: int, patch: Dictionary) -> void:
	var summaries: Array = GameState.long_term_memory.get("week_summaries", [])
	if summaries is not Array:
		summaries = []
	var target_idx := -1
	for i in range(summaries.size()):
		if summaries[i] is Dictionary and int((summaries[i] as Dictionary).get("week_index", -1)) == week_index:
			target_idx = i
			break
	var merged := patch.duplicate(true)
	if target_idx >= 0:
		var existing: Dictionary = (summaries[target_idx] as Dictionary).duplicate(true)
		merged = _merge_week_summary(existing, patch)
		summaries[target_idx] = merged
	else:
		if not merged.has("week_index"):
			merged["week_index"] = week_index
		if not merged.has("merged_highlights"):
			merged["merged_highlights"] = []
		if not merged.has("merged_anchor_ids"):
			merged["merged_anchor_ids"] = []
		summaries.append(merged)
	summaries.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int((a as Dictionary).get("week_index", 0)) < int((b as Dictionary).get("week_index", 0))
	)
	while summaries.size() > MAX_WEEK_SUMMARIES:
		summaries.remove_at(0)
	GameState.long_term_memory["week_summaries"] = summaries


func _merge_week_summary(existing: Dictionary, patch: Dictionary) -> Dictionary:
	var result := existing.duplicate(true)
	var highlights: Array[String] = []
	for raw in result.get("highlights", []):
		highlights = _append_unique_line(highlights, str(raw))
	for raw in patch.get("highlights", []):
		highlights = _append_unique_line(highlights, str(raw))
	while highlights.size() > MAX_WEEK_HIGHLIGHTS:
		highlights.pop_back()
	result["highlights"] = highlights

	var merged_highlights: Array[String] = []
	for raw in result.get("merged_highlights", []):
		merged_highlights = _append_unique_line(merged_highlights, str(raw))
	for raw in patch.get("merged_highlights", []):
		merged_highlights = _append_unique_line(merged_highlights, str(raw))
	while merged_highlights.size() > MAX_WEEK_HIGHLIGHTS:
		merged_highlights.pop_back()
	result["merged_highlights"] = merged_highlights

	var merged_ids: Array[String] = []
	for raw in result.get("merged_anchor_ids", []):
		var mem_id := str(raw).strip_edges()
		if mem_id != "" and mem_id not in merged_ids:
			merged_ids.append(mem_id)
	for raw in patch.get("merged_anchor_ids", []):
		var mem_id := str(raw).strip_edges()
		if mem_id != "" and mem_id not in merged_ids:
			merged_ids.append(mem_id)
	result["merged_anchor_ids"] = merged_ids

	if patch.has("journal_days"):
		result["journal_days"] = int(patch.get("journal_days", result.get("journal_days", 0)))
	if patch.has("archived_at_game_day"):
		result["archived_at_game_day"] = int(patch.get("archived_at_game_day", GameState.game_day))
	result["summary"] = _compose_week_summary_text(
		int(result.get("week_index", patch.get("week_index", 1))),
		highlights + merged_highlights
	)
	return result


func _compose_week_summary_text(week_index: int, highlights: Array) -> String:
	var lines: Array[String] = []
	for raw in highlights:
		var line := str(raw).strip_edges()
		if line != "":
			lines.append(line)
	var label := "第 %d 天" % GameState.game_day if GameState.IS_TEN_DAY_EDITION else "第 %d 周" % week_index
	if lines.is_empty():
		return "%s：一起把农场又往前推了一小步。" % label
	var body := "；".join(lines.slice(0, 4))
	return "%s：%s。" % [label, body]


func _append_unique_line(lines: Array[String], line: String) -> Array[String]:
	var cleaned := line.strip_edges()
	if cleaned == "":
		return lines
	var result := lines.duplicate()
	for existing in result:
		if existing == cleaned:
			return result
	result.append(cleaned)
	return result


func _prefs_snapshot() -> Dictionary:
	var prefs: Variant = GameState.long_term_memory.get("prefs", {})
	if prefs is Dictionary:
		return prefs.duplicate(true)
	return {}


func _promise_snapshot() -> Dictionary:
	if StoryDirector.is_stranger_mode():
		return {}
	if not GameState.has_story_promise():
		return {}
	var promise: Variant = GameState.long_term_memory.get("promise", {})
	if promise is Dictionary:
		return promise.duplicate(true)
	return {}


func _recovery_tier() -> String:
	var recovery := GameState.get_memory_recovery()
	if recovery >= 0.85:
		return "high"
	if recovery >= 0.55:
		return "mid"
	return "low"


func _forbidden_topics(mode: String) -> Array[String]:
	var topics: Array[String] = [
		"捏造未发生的约定或礼物",
		"客服腔与网络梗",
		"D35 前直说转世/灵魂/死去宠物",
	]
	match mode:
		"stranger":
			topics.append("亲昵称呼与具体共同回忆")
			topics.append("直接叫玩家名字")
		"leak":
			topics.append("完整连贯回忆（仅允许 vague déjà vu）")
	return topics


func _as_citable(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var mem_id := str(entry.get("id", "")).strip_edges()
	var summary := notebook_line_of(entry)
	if mem_id == "" or summary == "":
		return {}
	return {
		"id": mem_id,
		"kind": str(entry.get("kind", "")),
		"summary": summary,
		"notebook_line": summary,
	}


func _has_memory_id(mem_id: String) -> bool:
	for entry in GameState.get_recent_memories(12):
		if entry is Dictionary and str(entry.get("id", "")) == mem_id:
			return true
	var anchors: Array = GameState.long_term_memory.get("anchors", [])
	for entry in anchors:
		if entry is Dictionary and str(entry.get("id", "")) == mem_id:
			return true
	return false


func _pick_relevant_memories(event: String, extra: Dictionary, recent: Array, anchors: Array) -> Array[Dictionary]:
	var picked: Array[Dictionary] = []
	var player_message := str(extra.get("player_message", ""))
	for entry in recent:
		if entry is Dictionary and _memory_matches_event(entry, event, player_message):
			picked.append(entry)
	for entry in anchors:
		if entry is Dictionary and _memory_matches_event(entry, event, player_message):
			picked.append(entry)
	if picked.is_empty():
		for entry in recent:
			if entry is Dictionary:
				picked.append(entry)
			if picked.size() >= 2:
				break
	return picked


func _memory_matches_event(entry: Dictionary, event: String, player_message: String) -> bool:
	var kind := str(entry.get("kind", ""))
	if kind == "promise" and not GameState.has_story_promise():
		return false
	if kind == "promise_done":
		return false
	var summary := str(entry.get("summary", ""))
	match event:
		"session_start":
			return kind == "day_end" or kind == "promise"
		"task_complete":
			return kind in ["harvest", "trade_sell", "promise_done", "task_water", "day_end"]
		"player_chat":
			if player_message != "" and player_message.length() >= 2:
				var probe := player_message.substr(0, mini(player_message.length(), 4))
				if summary.find(probe) >= 0:
					return true
			return kind in ["chat", "gift", "promise", "harvest", "day_end"]
		"companion_react":
			return kind in ["plant", "harvest", "day_end", "promise", "trade_sell", "task_water"]
		"companion_proactive", "companion_casual", "morning_sidewrite":
			return kind in ["chat", "gift", "promise", "harvest", "day_end", "story_beat"]
		_:
			return false

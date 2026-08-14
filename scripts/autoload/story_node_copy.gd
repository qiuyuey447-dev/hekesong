extends Node
## 剧情节点文案库（config/story_nodes.json）。编辑 JSON 后重启 Godot。

const PATH := "res://config/story_nodes.json"

var _data: Dictionary = {}


func _ready() -> void:
	_load()


func reload() -> void:
	_load()


func get_template(key: String) -> String:
	var templates: Variant = _data.get("templates", {})
	if templates is Dictionary:
		return _resolve_alias(str(templates.get(key, "")))
	return ""


func get_route(suffix: String, tone: String, variant: String = "") -> String:
	var routes: Variant = _data.get("route_by_suffix", {})
	if routes is not Dictionary:
		return ""
	var block: Variant = routes.get(suffix, {})
	if block is not Dictionary:
		return ""
	var route: Dictionary = block
	if variant != "" and route.has(variant):
		return _resolve_alias(str(route[variant]))
	if route.has(tone):
		return _resolve_alias(str(route[tone]))
	return _resolve_alias(str(route.get("default", "")))


func get_fragment(fragment_id: String) -> Dictionary:
	var fragments: Variant = _data.get("fragments", {})
	if fragments is Dictionary and fragments.has(fragment_id):
		var entry: Variant = fragments[fragment_id]
		if entry is Dictionary:
			return entry
	return {}


func get_morning(key: String) -> String:
	return _section_text("morning", key)


func get_invite(key: String) -> String:
	return _section_text("invites", key)


func get_nudge(key: String) -> String:
	return _section_text("nudges", key)


func get_followup(key: String) -> String:
	return _section_text("followups", key)


func get_week_wrap_hint(key: String) -> String:
	return _section_text("week_wrap", key)


func get_deferred_hint(key: String) -> String:
	return _section_text("deferred_hints", key)


func get_render(group: String, tone: String, subkey: String = "") -> String:
	var renders: Variant = _data.get("renders", {})
	if renders is not Dictionary:
		return ""
	var block: Variant = renders.get(group, {})
	if block is not Dictionary:
		return ""
	var render: Dictionary = block
	if subkey != "" and render.has(subkey):
		return _resolve_alias(str(render[subkey]))
	if render.has(tone):
		return _resolve_alias(str(render[tone]))
	return _resolve_alias(str(render.get("default", "")))


func get_choice(key: String) -> String:
	return _section_text("choices", key)


func get_awakening(key: String) -> String:
	return _section_text("awakening", key)


func get_ending(key: String) -> String:
	return _section_text("endings", key)


func get_system(key: String) -> String:
	return _section_text("system", key)


func get_route_shift(key: String) -> String:
	return _section_text("route_shift", key)


func has_template(key: String) -> bool:
	var templates: Variant = _data.get("templates", {})
	return templates is Dictionary and templates.has(key)


func has_route(suffix: String) -> bool:
	var routes: Variant = _data.get("route_by_suffix", {})
	return routes is Dictionary and routes.has(suffix)


func _section_text(section_name: String, key: String) -> String:
	var section: Variant = _data.get(section_name, {})
	if section is Dictionary:
		return str(section.get(key, ""))
	return ""


func _resolve_alias(raw: String) -> String:
	var text := raw.strip_edges()
	if text.begins_with("@"):
		var alias_key := text.substr(1).strip_edges()
		if alias_key != "":
			return get_template(alias_key)
	return text


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		push_warning("StoryNodeCopy: 找不到 %s" % PATH)
		_data = {}
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if not file:
		push_warning("StoryNodeCopy: 无法读取 %s" % PATH)
		_data = {}
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed
	else:
		push_warning("StoryNodeCopy: JSON 解析失败")
		_data = {}

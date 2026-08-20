#!/usr/bin/env python3
"""XL-H P1/P2: isomorphic chat history + body-action whitelist."""
from __future__ import annotations

import json
import sys

TOOLS = __file__.rsplit("\\", 1)[0] if "\\" in __file__ else __file__.rsplit("/", 1)[0]
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)

from local_llm_server import (  # noqa: E402
    _history_messages,
    attach_body_actions,
    coerce_llm_payload,
    infer_body_actions,
    infer_from_companion_line,
    mock_reply,
    parse_llm_json,
    reply_contract_for_history,
    sanitize_body_actions,
)


def test_history_isomorphic() -> None:
    payload = {
        "recent_chat_turns": [
            {"role": "player", "text": "过来"},
            {
                "role": "companion",
                "text": "来了。",
                "reply_contract": {
                    "reply": "来了。",
                    "intent": "chat",
                    "plot_id": -1,
                    "actions": [{"id": "follow_player"}],
                    "cited_memory_ids": [],
                },
            },
            {"role": "companion", "text": "嗯，我在。"},
        ]
    }
    messages = _history_messages(payload)
    assert messages[0] == {"role": "user", "content": "过来"}
    assistant = json.loads(messages[1]["content"])
    assert assistant["reply"] == "来了。"
    assert assistant["actions"] == [{"id": "follow_player"}]
    wrapped = json.loads(messages[2]["content"])
    assert wrapped["reply"] == "嗯，我在。"
    assert wrapped["intent"] == "chat"
    assert wrapped["actions"] == []
    for i in range(12):
        payload["recent_chat_turns"].append({
            "role": "companion",
            "text": f"回{i}",
            "reply_contract": {
                "reply": f"回{i}",
                "intent": "chat",
                "plot_id": -1,
                "actions": [],
                "cited_memory_ids": [],
            },
        })
    later = _history_messages(payload)
    parsed = 0
    for msg in later:
        if msg["role"] != "assistant":
            continue
        data = json.loads(msg["content"])
        assert "reply" in data
        parsed += 1
    assert parsed >= 12
    print("HISTORY: PASS")


def test_parse_fallback_wraps() -> None:
    data = coerce_llm_payload("来了，我在这边。", {"event": "player_chat", "player_message": "过来"})
    assert data["reply"]
    assert data["intent"] == "chat"
    assert data.get("actions") == []
    parsed = parse_llm_json('```json\n{"reply":"好。","intent":"chat","plot_id":-1}\n```')
    assert parsed["reply"] == "好。"
    print("PARSE WRAP: PASS")


def test_body_action_whitelist() -> None:
    assert infer_body_actions("过来一下") == [{"id": "follow_player"}]
    assert infer_body_actions("一起去廊下") == [{"id": "walk_poi", "poi": "porch"}]
    assert infer_body_actions("去树洞") == [{"id": "walk_poi", "poi": "hollow"}]
    assert infer_body_actions("帮我把田浇了", "water_all") == []
    assert infer_body_actions("翻本子看看") == [{"id": "open_notebook"}]
    assert sanitize_body_actions([{"id": "explode"}]) == []
    assert sanitize_body_actions([{"id": "walk_poi", "poi": "plots"}]) == [{"id": "walk_poi", "poi": "field"}]
    assert sanitize_body_actions([{"id": "stay"}]) == []
    assert sanitize_body_actions([{"id": "follow_player"}], "water_all") == []
    mocked = mock_reply({"event": "player_chat", "player_message": "过来"})
    assert mocked.get("actions") == [{"id": "follow_player"}]
    farm = mock_reply({"event": "player_chat", "player_message": "帮我把田都浇了"})
    assert farm.get("intent") in ("water", "water_all", "chat")
    if farm.get("intent") in ("water", "water_all"):
        assert farm.get("actions", []) == []
    filled = attach_body_actions({"reply": "来了。", "intent": "chat"}, {"event": "player_chat", "player_message": "过来"})
    assert filled["actions"] == [{"id": "follow_player"}]
    assert infer_from_companion_line("那我去树洞看看。") == [{"id": "walk_poi", "poi": "hollow"}]
    assert infer_from_companion_line("我过来找你。") == [{"id": "follow_player"}]
    assert infer_from_companion_line("要不要去廊下躲一会儿？") == []
    assert infer_from_companion_line("你去树洞吧，我在这儿。") == []
    assert infer_from_companion_line("好，我去田里浇一遍。") == []
    self_move = attach_body_actions(
        {"reply": "那我去树洞看看。", "intent": "chat"},
        {"event": "player_chat", "player_message": "今天有点闷"},
    )
    assert self_move["actions"] == [{"id": "walk_poi", "poi": "hollow"}]
    contract = reply_contract_for_history({"text": "在。", "role": "companion"})
    assert contract["reply"] == "在。"
    print("BODY ACTIONS: PASS")


def main() -> None:
    test_history_isomorphic()
    test_parse_fallback_wraps()
    test_body_action_whitelist()
    print("XL-H P1/P2: ALL PASS")


if __name__ == "__main__":
    main()

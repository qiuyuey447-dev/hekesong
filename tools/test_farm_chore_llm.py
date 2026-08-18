#!/usr/bin/env python3
"""Farm chore tone sync: config/farm_plot_reactions.json ↔ PersonaGuard ↔ local_llm_server."""
from __future__ import annotations

import json
import sys

TOOLS = __file__.rsplit("\\", 1)[0] if "\\" in __file__ else __file__.rsplit("/", 1)[0]
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)

from local_llm_server import (  # noqa: E402
    _dialogue_rules,
    _farm_plot_tone,
    _load_farm_plot_config,
    _prompt_farm_chore_tone,
    farm_plot_reaction,
    farm_reaction_banned_phrase,
    looks_like_save_bug_worry,
    mock_companion_react_reply,
    mock_reply,
)

ROOT = __file__.rsplit("\\", 1)[0] if "\\" in __file__ else __file__.rsplit("/", 1)[0]
CONFIG_PATH = f"{ROOT}/../config/farm_plot_reactions.json".replace("\\", "/")


def test_config_loads() -> None:
    cfg = _load_farm_plot_config()
    assert cfg.get("early", {}).get("no_seeds"), "early no_seeds missing"
    assert cfg.get("stranger", {}).get("already_watered"), "stranger already_watered missing"
    print("CONFIG: PASS")


def test_tone_tiers() -> None:
    early = {"story_mode": "keep", "relationship": {"game_day": 2}}
    stranger = {"story_mode": "stranger", "relationship": {"game_day": 4}}
    assert _farm_plot_tone(early) == "early"
    assert _farm_plot_tone(stranger) == "stranger"
    print("TONE TIERS: PASS")


def test_reactions_avoid_ai_phrases() -> None:
    payloads = [
        {"story_mode": "keep", "relationship": {"game_day": 2}},
        {"story_mode": "stranger", "relationship": {"game_day": 4}},
        {"story_mode": "leak", "relationship": {"game_day": 7}},
    ]
    reasons = ["no_seeds", "already_watered", "rain", "need_closer", "not_mature"]
    for payload in payloads:
        for reason in reasons:
            line = farm_plot_reaction(reason, payload)
            assert line, f"empty reaction {reason} @ {payload.get('story_mode')}"
            banned = farm_reaction_banned_phrase(line)
            assert not banned, f"AI phrase {banned!r} in {line!r}"
    print("REACTIONS: PASS")


def test_prompt_includes_farm_rules() -> None:
    payload = {"story_mode": "keep", "relationship": {"game_day": 2}}
    block = _prompt_farm_chore_tone(payload)
    assert "田务口吻" in block
    assert "要不要我帮" in block
    rules = _dialogue_rules(story_mode="keep", chat_mode=True)
    assert "菜单腔" in rules or "aside" in rules or "田务" in rules
    print("PROMPT: PASS")


def test_mock_session_and_react() -> None:
    session = mock_reply(
        {"event": "session_start", "story_mode": "keep", "relationship": {"game_day": 2}, "companion_name": "小狸"},
    )
    reply = str(session.get("reply", ""))
    assert "小狸：" not in reply
    assert farm_reaction_banned_phrase(reply) == ""
    assert "帮我看看田" not in reply

    react = mock_reply(
        {
            "event": "companion_react",
            "story_mode": "keep",
            "relationship": {"game_day": 2},
            "world_snapshot": {
                "inventory": {"turnip_seed": 0},
                "plots": {"empty": 1, "harvestable": 0, "unwatered_growing": 0},
            },
        },
    )
    react_line = str(react.get("reply", ""))
    assert react_line
    assert farm_reaction_banned_phrase(react_line) == ""
    assert "要不要" not in react_line
    print("MOCK: PASS")


def test_godot_config_matches_python() -> None:
    with open(CONFIG_PATH, encoding="utf-8") as f:
        disk = json.load(f)
    assert disk == _load_farm_plot_config()
    print("GODOT CONFIG PARITY: PASS")


def test_stranger_save_bug_worry() -> None:
    assert looks_like_save_bug_worry("是不是存档坏了")
    assert looks_like_save_bug_worry("数据丢了")
    assert not looks_like_save_bug_worry("今天天气怎么样")
    payload = {
        "event": "player_chat",
        "story_mode": "stranger",
        "player_message": "是不是存档坏了？",
        "relationship": {"game_day": 4},
    }
    out = mock_reply(payload)
    reply = str(out.get("reply", ""))
    assert "不是坏了" in reply or "没丢" in reply
    assert "欢迎回来" not in reply
    rules = _dialogue_rules(story_mode="stranger", chat_mode=True)
    assert "存档坏了" in rules or "不是坏了" in rules
    print("SAVE BUG WORRY: PASS")


def main() -> None:
    test_config_loads()
    test_tone_tiers()
    test_reactions_avoid_ai_phrases()
    test_prompt_includes_farm_rules()
    test_mock_session_and_react()
    test_godot_config_matches_python()
    test_stranger_save_bug_worry()
    print("=== ALL PASS ===")


if __name__ == "__main__":
    main()

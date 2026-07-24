#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Local Xiaoli API proxy for Godot NpcBridge.

Usage (Windows, use Python 3):
  1. Mock mode (no API key):
       py -3 tools/local_llm_server.py

  2. With DeepSeek / OpenAI-compatible LLM:
       set DEEPSEEK_API_KEY=sk-xxx
       py -3 tools/local_llm_server.py --llm

  3. Custom port:
       py -3 tools/local_llm_server.py --port 8080

游戏配置 user://npc_config.json:
  "api_url": "http://127.0.0.1:8080/v1/chat"
  "api_key": "local-dev"
  "enabled": true
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any
from urllib import error, request

HOST = "127.0.0.1"
PORT = 8080


def has_llm_api_key() -> bool:
    return bool(
        (
            os.environ.get("DEEPSEEK_API_KEY")
            or os.environ.get("OPENAI_API_KEY")
            or os.environ.get("LLM_API_KEY")
            or ""
        ).strip()
    )


def resolve_use_llm(args: argparse.Namespace) -> bool:
    if getattr(args, "mock", False):
        return False
    if args.llm:
        return True
    return has_llm_api_key()

ALLOWED_INTENTS = {
    "chat",
    "water",
    "water_all",
    "open_market",
    "open_shop",
    "open_memory",
    "check_status",
    "help",
    "sleep",
    "harvest",
    "harvest_all",
    "plant",
    "plant_all",
    "refuse",
}

# 必须返回 affection_delta 的事件（见 docs/api/npc_chat_api.md v2.0）
RELATIONSHIP_EVENTS = frozenset({"player_chat", "story_beat"})

WARM_WORDS = ("谢谢", "辛苦", "记住", "留下", "陪", "慢慢来", "没关系", "对不起", "抱歉", "担心", "接纳")
COLD_WORDS = ("滚", "赶走", "烦", "笨", "没用", "别烦", "走开", "离开这里")
MEMORY_WORDS = ("记得", "约定", "忘记", "想起", "回忆", "不会赶", "收留")

_RULES_CACHE: dict[str, Any] | None = None


def _rules_path() -> str:
    return os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "config", "relationship_rules.json"))


def load_relationship_rules() -> dict[str, Any]:
    global _RULES_CACHE
    if _RULES_CACHE is not None:
        return _RULES_CACHE
    path = _rules_path()
    try:
        with open(path, encoding="utf-8") as f:
            _RULES_CACHE = json.load(f)
            return _RULES_CACHE
    except Exception as exc:
        sys.stdout.write(f"[local_llm] 无法加载 relationship_rules.json，用内置默认: {exc}\n")
        sys.stdout.flush()
        _RULES_CACHE = {
            "affection_min": -2,
            "affection_max": 3,
            "bond_min": 0,
            "bond_max": 2,
            "memory_recovery_max": 0.05,
            "base_chat_affection": 1,
            "long_message_chars": 12,
            "long_message_bonus": 1,
            "warm_words": list(WARM_WORDS),
            "cold_words": list(COLD_WORDS),
            "memory_words": list(MEMORY_WORDS),
            "dismissive_exact": ["哦", "嗯", "行", "好", "ok", "OK", "算了", "随便"],
            "stranger_patience_words": ["我是", "认识", "农场", "留下", "帮工", "没关系", "慢慢"],
            "stranger_impatience_words": ["怎么还不", "又忘了", "烦"],
            "stranger_ooc_phrases": [
                "又见面了", "还记得", "上次你说", "我们约", "一起看过", "欢迎回来", "你来了", "好久不见",
                "上次", "以前我们", "那时候", "我们的约定", "我们的家", "一起浇", "一起种", "一起收",
                "你喂过", "不是第一次", "像家人", "像朋友", "一直在一起", "我记得你", "我们以前",
            ],
            "stranger_intimate_phrases": ["想你了", "亲爱的", "宝贝", "乖", "抱抱", "爱你", "好想你"],
            "action_intent_affection_cap": 1,
        }
        return _RULES_CACHE


def _is_dismissive(text: str, rules: dict[str, Any]) -> bool:
    if len(text) <= 2:
        return True
    lower = text.lower()
    for word in rules.get("dismissive_exact", []):
        w = str(word).strip()
        if not w:
            continue
        if text == w or lower == w.lower():
            return True
        if text in (w + "。", w + "...", w + "…"):
            return True
    return False


def _first_word_hit(text: str, words: Any) -> str:
    if not isinstance(words, list):
        return ""
    for word in words:
        w = str(word)
        if w and w in text:
            return w
    return ""


def score_relationship_delta(payload: dict[str, Any], reply: str = "") -> dict[str, Any]:
    rules = load_relationship_rules()
    event = str(payload.get("event", "player_chat"))
    text = str(payload.get("player_message", "")).strip()
    story_mode = str(payload.get("story_mode", ""))
    aff_min = int(rules.get("affection_min", -2))
    aff_max = int(rules.get("affection_max", 3))
    bon_min = int(rules.get("bond_min", 0))
    bon_max = int(rules.get("bond_max", 2))
    rec_max = float(rules.get("memory_recovery_max", 0.05))

    if event == "story_beat":
        return {
            "affection_delta": 0,
            "bond_delta": 0,
            "memory_recovery_delta": 0.0,
            "relationship_reason": "节点搭话，等玩家回应后再计分",
        }

    if not text:
        return {
            "affection_delta": 0,
            "bond_delta": 0,
            "memory_recovery_delta": 0.0,
            "relationship_reason": "空消息",
        }

    if _is_dismissive(text, rules):
        return {
            "affection_delta": 0,
            "bond_delta": 0,
            "memory_recovery_delta": 0.0,
            "relationship_reason": "敷衍回应",
        }

    aff = int(rules.get("base_chat_affection", 1))
    bon = 0
    rec = 0.0
    reason = "普通聊天"

    if len(text) >= int(rules.get("long_message_chars", 12)):
        aff += int(rules.get("long_message_bonus", 1))
        reason = "认真回应"

    warm = _first_word_hit(text, rules.get("warm_words", []))
    if warm:
        aff += 1
        rec += 0.01
        reason = f"暖语：{warm}"

    cold = _first_word_hit(text, rules.get("cold_words", []))
    if cold:
        aff -= 2
        reason = f"冷语：{cold}"

    mem = _first_word_hit(text, rules.get("memory_words", []))
    if mem:
        rec += 0.01
        if mem in ("记得", "约定"):
            aff += 1
        reason = f"记忆/承诺：{mem}"

    if story_mode == "stranger":
        if any(w in text for w in rules.get("stranger_patience_words", [])):
            aff = max(aff, 2)
            rec += 0.01
            reason = "W2 耐心重新介绍"
        if any(w in text for w in rules.get("stranger_impatience_words", [])):
            aff = min(aff, -1)
            reason = "W2 不耐烦"

    if "？" in text or "?" in text:
        bon += 1

    intent, _ = guess_intent(text)
    if intent != "chat":
        aff = min(aff, int(rules.get("action_intent_affection_cap", 1)))
        reason = "事务指令"

    return {
        "affection_delta": max(aff_min, min(aff_max, aff)),
        "bond_delta": max(bon_min, min(bon_max, bon)),
        "memory_recovery_delta": round(max(0.0, min(rec_max, rec)), 3),
        "relationship_reason": reason,
    }


def build_relationship_score_messages(payload: dict[str, Any], reply: str) -> list[dict[str, str]]:
    rules = load_relationship_rules()
    system = "\n".join([
        "你是《河可松》关系裁判，只输出 JSON，不要 markdown。",
        "根据玩家发言、小狸回复、剧情模式判断关系变化。",
        "必填：affection_delta(整数-2~3)、bond_delta(整数0~2)、"
        "memory_recovery_delta(浮点0~0.05)、relationship_reason(短字符串，中文)。",
        "评分表：",
        "- 敷衍（哦/嗯/行/好/算了，≤2字）→ affection_delta=0",
        "- 纯事务指令（浇水/打开集市）→ 0~+1",
        "- 普通关心聊天 → +1",
        "- 长句认真回应(≥12字) → +2",
        "- 安慰/接纳/谢谢/慢慢来/对不起 → +2~+3",
        "- 伤人/赶走/滚/烦 → -1~-2",
        "- 提到记得/约定/不会赶你走 → memory_recovery_delta 0.01~0.03",
        "story_mode=stranger：玩家耐心重新介绍身份 → +2~+3；指责不耐烦 → -1~-2。",
        f"配置上限：affection [{rules.get('affection_min', -2)}, {rules.get('affection_max', 3)}]。",
    ])
    user = json.dumps(
        {
            "player_message": payload.get("player_message", ""),
            "companion_reply": reply,
            "story_mode": payload.get("story_mode", ""),
            "story_hint": payload.get("story_hint", ""),
            "relationship": payload.get("relationship"),
        },
        ensure_ascii=False,
    )
    return [{"role": "system", "content": system}, {"role": "user", "content": user}]


def score_relationship_with_llm(payload: dict[str, Any], reply: str) -> dict[str, Any]:
    messages = build_relationship_score_messages(payload, reply)
    content, _ = fetch_llm_content(messages, 0.2, json_mode=True)
    data = parse_llm_json(content)
    return {
        "affection_delta": max(-2, min(3, int(data.get("affection_delta", 0)))),
        "bond_delta": max(0, min(2, int(data.get("bond_delta", 0)))),
        "memory_recovery_delta": max(0.0, min(0.05, float(data.get("memory_recovery_delta", 0.0)))),
        "relationship_reason": str(data.get("relationship_reason", "LLM 裁判"))[:80],
    }


def ensure_relationship_fields(
    data: dict[str, Any], payload: dict[str, Any], *, use_llm_score: bool = False
) -> dict[str, Any]:
    event = str(payload.get("event", ""))
    if event not in RELATIONSHIP_EVENTS:
        return data
    if "affection_delta" in data:
        data["affection_delta"] = max(-2, min(3, int(data.get("affection_delta", 0))))
        data["bond_delta"] = max(0, min(2, int(data.get("bond_delta", 0))))
        data["memory_recovery_delta"] = max(0.0, min(0.05, float(data.get("memory_recovery_delta", 0.0))))
        if "cited_memory_ids" not in data:
            data["cited_memory_ids"] = []
        return data
    reply = str(data.get("reply", ""))
    if use_llm_score:
        try:
            data.update(score_relationship_with_llm(payload, reply))
            return data
        except Exception as exc:
            sys.stdout.write(f"[local_llm] LLM 关系裁判失败，规则回退: {exc}\n")
            sys.stdout.flush()
    data.update(score_relationship_delta(payload, reply))
    if "cited_memory_ids" not in data:
        data["cited_memory_ids"] = []
    return data


def _allowed_memory_ids(payload: dict[str, Any]) -> set[str]:
    mem = payload.get("memory_context") or {}
    allowed: set[str] = set()
    for item in mem.get("citable_memories") or []:
        if isinstance(item, dict):
            mid = str(item.get("id", "")).strip()
            if mid:
                allowed.add(mid)
    for mid in mem.get("cited_memory_ids") or []:
        mid = str(mid).strip()
        if mid:
            allowed.add(mid)
    return allowed


def sanitize_cited_memory_ids(data: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
    story_mode = str(payload.get("story_mode", ""))
    raw = data.get("cited_memory_ids", data.get("citedMemoryIds", []))
    cleaned: list[str] = []
    if isinstance(raw, list):
        allowed = _allowed_memory_ids(payload)
        for item in raw:
            mid = str(item).strip()
            if not mid:
                continue
            if story_mode == "stranger":
                continue
            if allowed and mid not in allowed:
                continue
            cleaned.append(mid)
    data["cited_memory_ids"] = cleaned
    return data


def _prompt_story_beat(payload: dict[str, Any]) -> str:
    rel = payload.get("relationship") or {}
    week = rel.get("week_index", "?")
    day = rel.get("loop_day", "?")
    hint = str(payload.get("story_hint", "")).strip()
    return f"W{week} D{day} · {hint}" if hint else f"W{week} D{day}"


def _prompt_forbidden(payload: dict[str, Any]) -> str:
    mem = payload.get("memory_context") or {}
    boundaries = mem.get("story_boundaries") or {}
    topics = boundaries.get("forbidden_topics") or []
    persona_forbidden = [
        "捏造未发生的任务或对话",
        "油腻、PUA、网络梗",
        "客服腔：收到、我在你说",
    ]
    merged = list(dict.fromkeys([str(t) for t in topics] + persona_forbidden))
    return "；".join(merged)


def _prompt_persona_tone(payload: dict[str, Any]) -> str:
    mem = payload.get("memory_context") or {}
    persona = mem.get("persona_vector") or {}
    stage_tone = str(payload.get("stage_tone", "")).strip()
    parts = [stage_tone] if stage_tone else []
    if isinstance(persona, dict) and persona:
        bits = []
        for key in ("warm", "strict", "optimistic", "active"):
            if key in persona:
                bits.append(f"{key}={persona.get(key)}")
        if bits:
            parts.append("persona " + ", ".join(bits))
    boundaries = mem.get("story_boundaries") or {}
    tier = str(boundaries.get("recovery_tier", "")).strip()
    if tier:
        parts.append(f"recovery_tier={tier}")
    return " · ".join(p for p in parts if p)


def _prompt_citable_memories(payload: dict[str, Any]) -> str:
    mem = payload.get("memory_context") or {}
    prompt = str(mem.get("citable_prompt", "")).strip()
    if prompt:
        return prompt
    citable = mem.get("citable_memories") or []
    if not citable:
        return "（暂无可引用记忆；勿编造共同经历。）"
    lines = []
    for item in citable:
        if isinstance(item, dict):
            mid = str(item.get("id", "")).strip()
            summary = str(item.get("summary", "")).strip()
            if mid and summary:
                lines.append(f"#{mid} {summary}")
    return "\n".join(lines) if lines else "（暂无可引用记忆；勿编造共同经历。）"


INTENT_KEYWORDS: list[tuple[str, list[str]]] = [
    ("water_all", ["全都浇", "全部浇", "每块田", "所有田"]),
    ("water", ["浇水", "浇一下", "帮我浇", "去浇"]),
    ("plant_all", ["都种", "全种", "全部种", "空田都种", "能种的都种"]),
    ("plant", ["帮我种", "帮种", "去种", "种萝卜", "帮忙种", "播种", "种下"]),
    ("harvest_all", ["都收", "全收", "全部收", "萝卜都收", "把萝卜都收"]),
    ("harvest", ["收萝卜", "帮我收", "去收", "摘萝卜", "拔萝卜", "帮忙收"]),
    ("open_market", ["集市", "行情", "价格", "大盘"]),
    ("open_shop", ["商店", "买种子", "买点种子", "去买点种子", "去买种子", "买货", "买东西", "去商店", "进货"]),
    ("open_memory", ["记忆", "回忆", "记得"]),
    ("check_status", ["状态", "怎么样", "看看田", "背包"]),
    ("help", ["帮助", "怎么玩", "教我", "你能做什么", "你会什么"]),
    ("sleep", ["睡觉", "休息", "晚安", "睡了"]),
    ("refuse", ["不要", "别", "不行", "不想", "不用", "拒绝"]),
]


def looks_like_shop_request(message: str) -> bool:
    text = message.strip().replace(" ", "").replace("　", "")
    if not text:
        return False
    shop_phrases = (
        "买种子", "买点种子", "去买种子", "去买点种子", "去商店", "打开商店",
        "进货", "采购", "买东西", "买萝卜种子",
    )
    if any(p in text for p in shop_phrases):
        return True
    return "买" in text and "种子" in text


def looks_like_plant_request(message: str) -> bool:
    text = message.strip().replace(" ", "").replace("　", "")
    if not text:
        return False
    if looks_like_shop_request(message):
        return False
    plant_phrases = (
        "帮我种", "帮种", "去种", "种萝卜", "帮忙种", "播种", "种下", "种下去", "栽种",
        "都种", "全种", "全部种", "空田都种",
    )
    if any(p in text for p in plant_phrases):
        return True
    return "种" in text and "种子" not in text and any(c in message for c in ("帮", "请", "去", "让", "派"))


def guess_intent(message: str) -> tuple[str, float]:
    text = message.strip().lower()
    if not text:
        return "chat", 0.5
    if looks_like_shop_request(message):
        return "open_shop", 0.92
    if looks_like_plant_request(message):
        compact = message.strip().replace(" ", "").replace("　", "")
        if any(p in compact for p in ("都种", "全种", "全部种", "空田都种", "能种的都种")):
            return "plant_all", 0.9
        return "plant", 0.9
    for intent, keywords in INTENT_KEYWORDS:
        for kw in keywords:
            if kw in text:
                return intent, 0.85
    return "chat", 0.7


def is_off_topic_feed_reply(text: str, item_name: str, refused: bool) -> bool:
    cleaned = (text or "").strip()
    if len(cleaned) < 4:
        return True
    off_topic_markers = [
        "我叫",
        "住下",
        "要试试看",
        "帮手",
        "刚上线",
        "打招呼",
        "你来了",
        "欢迎回来",
        "浇水",
        "看田",
        "田里",
        "跑腿",
        "旧屋",
        "清晨的阳光",
        "帮你看看田",
        "要不要我帮",
        "萝卜田",
        "行情",
        "种子",
        "熟悉",
        "初次见面",
    ]
    for marker in off_topic_markers:
        if marker in cleaned:
            return True
    if refused:
        accept_markers = ["好好吃", "真好吃", "太好吃", "咬下去", "收下了", "谢谢你"]
        for marker in accept_markers:
            if marker in cleaned:
                return True
        refuse_markers = [
            "饱",
            "够",
            "吃不下",
            "明天",
            "留",
            "上限",
            "心意",
            "先收",
            "不能再",
            "打饱嗝",
            "刚吃过",
            "已经吃",
            "一份",
            "到限",
            "放过",
        ]
        return not any(marker in cleaned for marker in refuse_markers)
    if item_name and item_name in cleaned:
        return False
    food_markers = ["吃", "咬", "嚼", "舔", "尝", "味", "香", "甜", "酸", "脆", "软", "糯", "嘴", "零嘴", "零食", "满足"]
    for marker in food_markers:
        if marker in cleaned:
            return False
    return True


STORY_MODE_EVENTS = frozenset({"player_chat", "session_start", "task_complete", "story_beat"})

STRANGER_CHAT_FALLBACKS = [
    "……抱歉，我脑子有点乱，不太确定是否见过你。",
    "嗯……你刚才说的，我先记着。这里的事我还不太熟。",
    "……如果是重要的事，可以再说一遍吗？我暂时想不起来。",
]


def _story_mode(payload: dict[str, Any]) -> str:
    mode = str(payload.get("story_mode", "")).strip()
    if mode:
        return mode
    mem = payload.get("memory_context") or {}
    boundaries = mem.get("story_boundaries") or {}
    return str(boundaries.get("story_mode", "")).strip()


def is_stranger_ooc_reply(text: str, payload: dict[str, Any]) -> bool:
    if _story_mode(payload) != "stranger":
        return False
    cleaned = (text or "").strip()
    if len(cleaned) < 2:
        return True
    player_name = str(payload.get("player_name", "")).strip()
    if player_name and player_name in cleaned:
        return True
    rules = load_relationship_rules()
    for key in ("stranger_ooc_phrases", "stranger_intimate_phrases"):
        for phrase in rules.get(key, []) or []:
            p = str(phrase).strip()
            if p and p in cleaned:
                return True
    return False


def _mock_stranger_reply(payload: dict[str, Any]) -> dict[str, Any]:
    import random

    event = str(payload.get("event", "player_chat"))
    player_message = str(payload.get("player_message", "")).strip()
    if event == "session_start":
        pool = [
            "……抱歉，你是？这里是你的农场吗？",
            "你好……我好像不该在这里，但这片田看着有点熟悉。",
            "……我不记得见过你。不过，这屋子外面倒是挺安静的。",
        ]
        reply = random.choice(pool)
    elif event == "task_complete":
        reply = "……好，做完了。我还不太熟悉这里，但我会继续帮忙。"
    elif event == "story_beat":
        reply = "……刚那段话让我有点乱。你能再说一遍吗？"
    elif "你好" in player_message or player_message.lower() in ("hi", "hello"):
        reply = "……你好。抱歉，我一时想不起是否见过你。"
    elif "我是谁" in player_message or "认识我" in player_message or "记得我" in player_message:
        reply = "……你问我认不认识你？老实说，我脑子里只有一些很模糊的画面。"
    else:
        reply = random.choice(STRANGER_CHAT_FALLBACKS)
    base = {
        "reply": reply,
        "intent": "chat",
        "plot_id": -1,
        "confidence": 0.85,
        "cited_memory_ids": [],
    }
    return ensure_relationship_fields(base, payload)


def mock_reply(payload: dict[str, Any]) -> dict[str, Any]:
    event = str(payload.get("event", "player_chat"))
    player_message = str(payload.get("player_message", "")).strip()
    weather = str(payload.get("weather_today", ""))
    time_label = str(payload.get("time_label", ""))
    companion = str(payload.get("companion_name", "小狸"))

    if event == "session_start":
        mem = payload.get("memory_context") or {}
        if _story_mode(payload) == "stranger":
            return _mock_stranger_reply(payload)
        absence = payload.get("absence_facts") or mem.get("pending_absence") or {}
        if payload.get("include_absence_comeback") and isinstance(absence, dict):
            gap = int(absence.get("gap_hours", int(absence.get("gap_days", 0)) * 24))
            if gap >= 2:
                if gap >= 168:
                    reply = "好久不见……回来就好，院子我一直在看。"
                elif gap >= 48:
                    reply = "你不在的这几天，我把萝卜田先照顾好了。回来就好。"
                elif gap >= 12:
                    reply = "你不在的这段时间，我把萝卜田先照看着。回来就好。"
                else:
                    reply = "你离开了一阵子，我把院子先看着。回来就好。"
                return {"reply": reply, "intent": "chat", "plot_id": -1, "confidence": 0.9}
        yesterday = mem.get("yesterday_journal") or payload.get("yesterday_journal") or {}
        if payload.get("include_yesterday_echo") and isinstance(yesterday, dict) and yesterday.get("summary"):
            reply = "你来了。昨天的事我还记挂着，今天一起看看吧。"
            return {"reply": reply, "intent": "chat", "plot_id": -1, "confidence": 0.9}
        reply = f"{companion}：你来了。想先聊聊，还是让我帮你看看田？"
        return {"reply": reply, "intent": "chat", "plot_id": -1, "confidence": 0.9}

    if event == "task_complete":
        facts = payload.get("game_facts") or {}
        summary = facts.get("summary") or payload.get("last_task_summary") or "任务完成了"
        return {
            "reply": f"好，{summary}。我记下了。",
            "intent": "chat",
            "plot_id": -1,
            "confidence": 0.9,
        }

    if event == "companion_feed":
        feed_item = payload.get("feed_item") or {}
        item_name = str(feed_item.get("name", "零食"))
        refused = bool(payload.get("refused", False))
        previous = payload.get("previous_feed_replies") or []
        if refused:
            replies = [
                "真的吃不下啦……你留着自己补补能量吧。",
                "今天已经心满意足了，再塞给我就要打饱嗝了。",
                "我知道你是疼我，可我今天真的到上限了，明天再喂好不好？",
            ]
        else:
            replies = [
                f"唔，{item_name} 的味道在舌尖慢慢化开，今天这份惊喜我收下了。",
                f"这份 {item_name} 来得正好，嚼着嚼着尾巴都想晃一晃。",
                f"咬下去的第一口就记住了，{item_name} 这份心意比味道还甜。",
            ]
        for candidate in replies:
            if candidate not in previous:
                return {"reply": candidate, "intent": "chat", "plot_id": -1, "confidence": 0.9}
        return {"reply": replies[0], "intent": "chat", "plot_id": -1, "confidence": 0.9}

    if event == "companion_react":
        snap = payload.get("world_snapshot") or {}
        plots = snap.get("plots") or {}
        harvestable = int(plots.get("harvestable", 0))
        if harvestable > 0:
            reply = f"有 {harvestable} 块田的萝卜可以收了，要不要现在去收？"
        else:
            unwatered = int(plots.get("unwatered_growing", 0))
            if unwatered > 0:
                reply = f"还有 {unwatered} 块田没浇水，要我帮忙吗？"
            else:
                reply = "嗯…需要我帮忙浇水吗？"
        return {
            "reply": reply,
            "intent": "chat",
            "plot_id": -1,
            "confidence": 0.8,
        }

    if event == "intent_classify":
        intent, conf = guess_intent(player_message)
        return {"reply": "", "intent": intent, "plot_id": -1, "confidence": conf}

    if event == "story_beat":
        beat = payload.get("story_beat") or {}
        emotion = str(beat.get("emotion", ""))
        player_name = str(payload.get("player_name", "玩家"))
        if emotion in ("失去", "确认"):
            reply = f"……{player_name}，我有件事想问你。你愿意再告诉我一次吗？"
        elif emotion in ("名字",):
            reply = f"刚才那一瞬，名字突然回来了。{player_name}，你还在吗？"
        else:
            reply = "刚走完这一段……我心里有点话。你想说点什么吗？"
        base = {"reply": reply, "intent": "chat", "plot_id": -1, "confidence": 0.9}
        return ensure_relationship_fields(base, payload)

    if event == "day_journal_summarize":
        return mock_day_journal_summarize(payload)

    intent, conf = guess_intent(player_message)
    if _story_mode(payload) == "stranger" and intent == "chat":
        return _mock_stranger_reply(payload)
    if intent == "chat":
        topic = _classify_player_message(player_message)
        if topic == "emotion":
            if "累" in player_message or "烦" in player_message:
                reply = "嗯……那就先歇一会儿。我在这，不赶你。"
            elif "谢谢" in player_message:
                reply = "不客气。你愿意说，我就听着。"
            elif player_message:
                reply = f"嗯，{player_message[:24]}……我在听。"
            else:
                reply = "我在，你想聊什么？"
        elif topic == "general" and player_message:
            reply = f"嗯……{player_message[:28]}。你怎么突然说这个？"
        elif "天气" in player_message and weather:
            reply = f"今天{weather}。要是你想出门，记得看田里的情况。"
        elif player_message:
            reply = f"嗯……{player_message[:28]}。我听着呢。"
        else:
            reply = "我在，你想聊什么？"
        base = {
            "reply": reply,
            "intent": "chat",
            "plot_id": -1,
            "confidence": conf,
            "cited_memory_ids": [],
        }
        return ensure_relationship_fields(base, payload)
    elif intent == "water":
        reply = "好，我去看看哪块田需要浇水。"
    elif intent == "water_all":
        reply = "好，我把能浇的田都浇一遍。"
    elif intent == "harvest":
        reply = "好，我去萝卜田帮你收。"
    elif intent == "harvest_all":
        reply = "好，我把能收的萝卜都收回来。"
    elif intent == "plant":
        reply = "好，我去空田种萝卜。"
    elif intent == "plant_all":
        reply = "好，我把能种的空田都种上。"
    elif intent == "open_shop":
        if looks_like_shop_request(player_message):
            reply = "好，我先去商店。到了问你买几包种子，买好后我帮你种上并浇水。"
        else:
            reply = "好，我先去商店那边看看。"
    else:
        reply = "好，交给我。"

    base = {"reply": reply, "intent": intent, "plot_id": -1, "confidence": conf}
    return ensure_relationship_fields(base, payload)


FARM_TOPIC_KEYWORDS = (
    "田", "浇", "萝卜", "种子", "收", "卖", "买", "集市", "行情", "价格", "金币", "商店", "种",
)
STORY_TOPIC_KEYWORDS = ("记得", "忘记", "你是谁", "认识", "留下", "循环", "记忆", "本子", "约定", "小狸")
EMOTION_TOPIC_KEYWORDS = ("难过", "开心", "累", "烦", "谢谢", "对不起", "你好", "在吗", "哈哈", "孤独", "害怕", "想")


def _classify_player_message(message: str) -> str:
    text = message.strip()
    if not text:
        return "empty"
    if any(k in text for k in FARM_TOPIC_KEYWORDS):
        return "farm"
    if any(k in text for k in STORY_TOPIC_KEYWORDS):
        return "story"
    if any(k in text for k in EMOTION_TOPIC_KEYWORDS):
        return "emotion"
    return "general"


def _companion_brief(companion_snap: dict[str, Any]) -> str:
    if not isinstance(companion_snap, dict) or not companion_snap:
        return ""
    lines: list[str] = []
    loc_name = str(companion_snap.get("location_name", "")).strip()
    activity = str(companion_snap.get("activity", "")).strip()
    state = str(companion_snap.get("state", "")).strip()
    if loc_name:
        if activity and activity not in ("闲逛", "待命"):
            lines.append(f"小狸位置：{loc_name}（{activity}）")
        else:
            lines.append(f"小狸位置：{loc_name}")
    if state and state != "IDLE":
        lines.append(f"小狸状态：{state}")
    if bool(companion_snap.get("is_busy", False)):
        lines.append("小狸正在执行任务")
    caps = companion_snap.get("capabilities") or []
    if isinstance(caps, list) and caps:
        cap_text = "、".join(str(c) for c in caps[:8])
        lines.append(f"小狸可帮：{cap_text}")
    cannot = companion_snap.get("cannot_delegate") or []
    if isinstance(cannot, list) and cannot:
        lines.append("须玩家亲自：" + "、".join(str(c) for c in cannot))
    if companion_snap.get("can_water") is False:
        lines.append("亲密度不足：暂不能代浇水")
    if companion_snap.get("can_harvest") is False:
        lines.append("亲密度不足：暂不能代收萝卜")
    if bool(companion_snap.get("walks_to_target", False)):
        lines.append("接到指令后会先走到目标地点再执行")
    return "\n".join(lines)


def _companion_action_rules(payload: dict[str, Any]) -> str:
    snap = payload.get("world_snapshot") or {}
    companion = snap.get("companion") if isinstance(snap, dict) else {}
    profile = payload.get("companion_profile") or snap.get("companion_profile") or {}
    brief = _companion_brief(companion if isinstance(companion, dict) else {})
    lines = [
        "[小狸行动能力 — 与 companion_profile 保持一致]",
        "小狸可在地图上走动；空闲时随机发呆站立或慢走闲逛；接到玩家委托后会较快走到目标点再执行。",
        "可代做：浇水(water/water_all)、种萝卜(plant/plant_all)、收萝卜(harvest/harvest_all)、代买种子(open_shop，会先问买几包再自动种浇)、看大盘(open_market)、看记忆、查田况、睡觉。",
        "不可代做：帮卖(sell) → intent=refuse。",
        "world_snapshot 含 shop/inventory/plot_details/crops，请据此回答商店、背包与田况，勿编造。",
        "禁止在 reply 中声称已帮玩家购买/花费金币/种下种子，除非 game_facts 明确记录该交易。",
        "玩家说「帮我收萝卜/帮我去商店/帮我把田浇了」等应返回对应 action intent，并配合自然 reply。",
    ]
    if isinstance(profile, dict):
        examples = profile.get("command_examples") or []
        if isinstance(examples, list) and examples:
            lines.append("指令示例：" + "；".join(str(x) for x in examples[:6]))
        animations = profile.get("animations") or {}
        if isinstance(animations, dict):
            extra = str(animations.get("extra_action_sheets", "")).strip()
            if extra:
                lines.append(f"动画资源：{extra}")
    if brief:
        lines.append(brief)
    return "\n".join(lines)


def _player_chat_priority_rules(message: str, topic: str) -> str:
    lines = [
        "首要任务（最高优先级）：",
        f"- 玩家刚才说：「{message.strip()}」",
        "- 你必须先回应这句话本身（回答、共情、接话、反问都可以）。",
        "- 不要无视玩家原话，转而汇报天气、行情、田况或剧情背景。",
    ]
    if topic in ("general", "emotion", "empty"):
        lines.append("- 玩家未提农场/任务：不要主动推销浇田、卖萝卜、看行情。")
        lines.append("- 可以像朋友一样闲聊；农场细节仅在被问到时再提。")
    elif topic == "farm":
        lines.append("- 玩家提到了农场相关：可结合下方世界事实具体回答。")
    elif topic == "story":
        lines.append("- 玩家提到记忆/身份/关系：可结合剧情背景与可引用记忆，但仍先回答其问题。")
    return "\n".join(lines)


def _prompt_story_context(payload: dict[str, Any], topic: str = "") -> str:
    return _prompt_story_progress(payload)


def _prompt_story_progress(payload: dict[str, Any]) -> str:
    ctx = payload.get("story_context") or {}
    if not isinstance(ctx, dict):
        ctx = {}
    rel = payload.get("relationship") or {}
    week = ctx.get("week_index", rel.get("week_index", "?"))
    loop = ctx.get("loop_day", rel.get("loop_day", "?"))
    game_day = ctx.get("game_day", rel.get("game_day", "?"))
    lines = [
        "[必达剧情背景 — 回复不得与此矛盾]",
        (
            f"第 {game_day} 日 · W{week} D{loop} · "
            f"{ctx.get('route_label', '')} · story_mode={ctx.get('story_mode', payload.get('story_mode', ''))}"
        ),
    ]
    weekly_hint = str(ctx.get("weekly_hint", "") or payload.get("story_hint", "")).strip()
    if weekly_hint:
        lines.append(f"本周叙事：{weekly_hint}")
    weekly_goal = str(ctx.get("weekly_goal", "")).strip()
    if weekly_goal:
        lines.append(f"阶段目标：{weekly_goal}")
    if ctx.get("has_pending_beat") and str(ctx.get("pending_beat_brief", "")).strip():
        lines.append(
            "今日待触发主线："
            + str(ctx.get("pending_beat_brief", ""))
            + "（聊天勿抢先念节点台词，但语气须与当前阶段一致）"
        )
    recent = ctx.get("recent_story_beats") or []
    if isinstance(recent, list) and recent:
        lines.append("近期已发生：" + "；".join(str(x)[:48] for x in recent[:3]))
    constraints = ctx.get("narrative_constraints") or []
    if isinstance(constraints, list) and constraints:
        lines.append("叙事边界：" + "；".join(str(c) for c in constraints[:6]))
    lines.append("须符合以上剧情阶段；不可说出与当前周目/关系矛盾的设定，不可提前剧透未解锁内容。")
    return "\n".join(lines)


def _player_chat_tone_hint(payload: dict[str, Any]) -> str:
    affection = int((payload.get("relationship") or {}).get("affection", 0))
    if affection >= 60:
        return "亲密度较高：语气更暖，可共情与接话；勿强行插入田务。"
    if affection >= 30:
        return "已熟悉：自然、像一起过日子；玩家没问农场时不主动报行情。"
    return "初识：稍拘谨，句子短，先听懂玩家说什么再回。"


def _prompt_player_name_rules(payload: dict[str, Any]) -> str:
    ctx = payload.get("player_name_context") or {}
    if not isinstance(ctx, dict):
        ctx = {}
    stored = str(ctx.get("stored_name", "")).strip()
    knows = bool(ctx.get("companion_knows_name", False))
    can_say = bool(ctx.get("companion_can_say_name", False))
    name_set = bool(ctx.get("player_name_set", False))
    recall = bool(ctx.get("name_recall_unlocked", False))

    if not name_set:
        return (
            "[称呼规则]\n"
            "玩家尚未告诉小狸希望如何称呼。\n"
            "- 不要编造名字，不要把「玩家」当作对方的名字。\n"
            "- 若被问起，可自然引导对方介绍自己。"
        )
    if not knows:
        return (
            "[称呼规则]\n"
            "W2 陌生化：你暂时想不起玩家叫什么。\n"
            "- 不要直呼其名，不要编造名字，用「你」即可。"
        )
    if knows and not can_say:
        hint = f"「{stored}」" if stored else "（名字在舌尖）"
        return (
            "[称呼规则]\n"
            f"你隐约记得玩家曾让你称呼 {hint}，但此刻还叫不出口。\n"
            "- 不要直接喊名字；可说「你」，或表达「名字快想起来了」。"
        )
    if recall or can_say:
        return (
            "[称呼规则]\n"
            f"可自然称呼玩家「{stored}」。\n"
            "- 叫名时语气克制，符合当前关系阶段。"
        )
    return "[称呼规则]\n可用「你」称呼玩家。"


def _dialogue_rules(*, story_mode: str = "", player_name: str = "你", chat_mode: bool = False, can_say_name: bool = False) -> str:
    lines = [
        "对话规则：",
        "- 先接玩家上一句在说什么，再决定是否提田/天气；不要答非所问。",
        "- 可以反问、关心或接话，不要复读玩家原话，也不要只报游戏状态。",
        "- 禁止：「收到」「我在，你说」「有什么可以帮你」「作为 AI」等客服腔。",
        "- 不要 JSON、markdown、括号旁白、角色名前缀（不要写「小狸：」）。",
        "- 禁止输出 intent:/plot_id:/confidence: 等内部字段名或调试信息。",
        "- 1～3 句口语；没提到的任务/约定/田况不要编。",
    ]
    if chat_mode:
        lines.append("- 闲聊时像在场的朋友；不必每句都体现「农场管家」身份。")
        lines.append("- 仍须遵守上方「必达剧情背景」，不可因闲聊而 OOC 或矛盾。")
    if story_mode == "stranger":
        lines.append("- 陌生化：礼貌疏远，不热情，不引用共同经历。")
    elif can_say_name and player_name.strip() not in ("", "你"):
        lines.append(f"- 可自然称呼「{player_name}」，亲密度高时语气更暖但仍克制。")
    else:
        lines.append("- 用「你」称呼玩家；不要编造或乱猜名字。")
    return "\n".join(lines)


def _dialogue_rules_from_payload(payload: dict[str, Any], *, chat_mode: bool = False) -> str:
    ctx = payload.get("player_name_context") or {}
    if not isinstance(ctx, dict):
        ctx = {}
    player_name = str(payload.get("player_name", "")).strip()
    if not player_name:
        player_name = str(ctx.get("display_fallback", "你")).strip() or "你"
    return _dialogue_rules(
        story_mode=str(payload.get("story_mode", "")),
        player_name=player_name,
        chat_mode=chat_mode,
        can_say_name=bool(ctx.get("companion_can_say_name", False)),
    )


METADATA_LINE = re.compile(
    r"^\s*(intent|plot_id|confidence|affection_delta|bond_delta|memory_recovery_delta|"
    r"refuse_kind|cited_memory_ids|relationship_reason)\s*:",
    re.IGNORECASE,
)


def looks_like_metadata_leak(text: str) -> bool:
    cleaned = (text or "").strip()
    if not cleaned:
        return False
    lines = [ln.strip() for ln in cleaned.splitlines() if ln.strip()]
    meta_hits = sum(1 for ln in lines if METADATA_LINE.match(ln))
    if meta_hits >= 2:
        return True
    if meta_hits >= 1 and len(lines) <= 4:
        if not any("\u4e00" <= ch <= "\u9fff" for ch in cleaned):
            return True
    return False


def polish_llm_reply(text: str) -> str:
    cleaned = (text or "").strip()
    if not cleaned:
        return cleaned
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\s*```$", "", cleaned).strip()
    for prefix in ("小狸：", "小狸:", "回复：", "reply:", "Reply:"):
        if cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix) :].strip()
    if len(cleaned) >= 2:
        if (cleaned[0] == cleaned[-1]) and cleaned[0] in "\"'「」":
            cleaned = cleaned[1:-1].strip()
    cleaned = re.sub(r"^[（(【\[].*?[）)】\]]\s*", "", cleaned)
    bad_starts = ("收到：", "收到:", "好的，收到")
    for bad in bad_starts:
        if cleaned.startswith(bad):
            cleaned = cleaned[len(bad) :].strip("「」\"' ")
            break
    if len(cleaned) > 280:
        cut = cleaned[:280]
        for sep in ("。", "！", "？", ".", "!", "?"):
            idx = cut.rfind(sep)
            if idx >= 40:
                cleaned = cut[: idx + 1]
                break
        else:
            cleaned = cut.rstrip() + "…"
    return cleaned.strip()


def _scene_brief(payload: dict[str, Any], *, chat_mode: bool = False, topic: str = "general") -> str:
    rel = payload.get("relationship") or {}
    market = payload.get("market") or {}
    snap = payload.get("world_snapshot") or {}
    mem = payload.get("memory_context") or {}
    name_ctx = payload.get("player_name_context") or {}
    player_label = str(payload.get("player_name", "")).strip()
    if not player_label and isinstance(name_ctx, dict):
        player_label = str(name_ctx.get("display_fallback", "你")).strip() or "你"
    if not player_label:
        player_label = "你"
    lines = [
        f"玩家：{player_label}",
        f"时段：{payload.get('time_label') or snap.get('time_label', '')}",
        f"天气：{payload.get('weather_today') or snap.get('weather_label', '')}",
        f"关系：{rel.get('stage', '')}（亲密度 {rel.get('affection', 0)}）",
    ]
    if chat_mode and topic in ("general", "emotion", "empty"):
        return "\n".join(lines)

    if not chat_mode or topic in ("farm", "story"):
        lines.append(f"心情：{rel.get('mood', 70)}")
    companion_snap = snap.get("companion") or {}
    companion_brief = _companion_brief(companion_snap if isinstance(companion_snap, dict) else {})
    if companion_brief:
        lines.append(companion_brief)
    if not chat_mode or topic == "farm":
        shop = snap.get("shop") or {}
        if isinstance(shop, dict) and shop:
            seed_price = shop.get("turnip_seed_price", market.get("turnip_seed_price", "?"))
            sell_price = shop.get("turnip_sell_price", market.get("turnip_sell_price", "?"))
            lines.append(f"商店：萝卜种子 {seed_price} 金/包，萝卜收购 {sell_price} 金/个")
        lines.append(f"萝卜售价：{market.get('turnip_sell_price', snap.get('market', {}).get('turnip_sell_price', '?'))} 金")
        lines.append(f"上次任务：{payload.get('last_task_summary') or snap.get('last_task_summary', '无')}")
        plots = snap.get("plots") or {}
        if isinstance(plots, dict) and plots:
            farm_bits: list[str] = []
            harvestable = int(plots.get("harvestable", 0))
            unwatered = int(plots.get("unwatered_growing", 0))
            empty = int(plots.get("empty", 0))
            growing = int(plots.get("growing", 0))
            if harvestable > 0:
                farm_bits.append(f"{harvestable} 块可收")
            if unwatered > 0:
                farm_bits.append(f"{unwatered} 块待浇")
            if empty > 0:
                farm_bits.append(f"{empty} 块空田")
            if growing > 0 and not farm_bits:
                farm_bits.append(f"{growing} 块在长")
            if farm_bits:
                lines.append("田况：" + "，".join(farm_bits))
        inventory = snap.get("inventory") or {}
        if isinstance(inventory, dict):
            coins = inventory.get("coins", snap.get("market", {}).get("coins"))
            turnip = inventory.get("turnip", 0)
            seeds = inventory.get("turnip_seed", 0)
            if coins is not None:
                lines.append(f"背包：金币 {coins}，萝卜种子 {seeds} 包，萝卜 {turnip} 个")
        plot_details = snap.get("plot_details") or []
        if isinstance(plot_details, list) and plot_details:
            detail_bits: list[str] = []
            for plot in plot_details[:6]:
                if not isinstance(plot, dict):
                    continue
                pid = plot.get("plot_id", "?")
                status = plot.get("status", "")
                stage = plot.get("stage", 0)
                if status == "empty":
                    detail_bits.append(f"#{pid}空")
                elif status == "harvestable":
                    detail_bits.append(f"#{pid}可收")
                else:
                    watered = "已浇" if plot.get("watered_today") else "待浇"
                    detail_bits.append(f"#{pid}长{stage}/{plot.get('max_stage', 3)}·{watered}")
            if detail_bits:
                lines.append("地块：" + " ".join(detail_bits))

    if not chat_mode:
        prefs = mem.get("long_term_prefs") or {}
        if prefs:
            lines.append(f"玩家偏好：{json.dumps(prefs, ensure_ascii=False)}")
        citable_prompt = str(mem.get("citable_prompt", "")).strip()
        if citable_prompt:
            lines.append("可引用记忆：\n" + citable_prompt)
        elif mem.get("citable_memories"):
            lines.append("可引用记忆：\n" + _prompt_citable_memories(payload))
        else:
            recent = mem.get("recent_memories") or []
            if recent:
                snippets = []
                for item in recent[-3:]:
                    if isinstance(item, dict):
                        snippets.append(str(item.get("summary", item.get("text", "")))[:40])
                if snippets:
                    lines.append("近期记忆：" + "；".join(snippets))
        yesterday = mem.get("yesterday_journal") or payload.get("yesterday_journal") or {}
        if isinstance(yesterday, dict) and yesterday.get("summary"):
            lines.append("昨日日记：" + str(yesterday.get("summary", ""))[:120])
        absence = mem.get("pending_absence") or payload.get("absence_facts") or {}
        if isinstance(absence, dict) and (absence.get("gap_hours") or absence.get("gap_days")):
            gap_h = int(absence.get("gap_hours", int(absence.get("gap_days", 0)) * 24))
            lines.append("缺席回归：离开 %d 小时" % gap_h)
    elif topic == "story":
        yesterday = mem.get("yesterday_journal") or payload.get("yesterday_journal") or {}
        if isinstance(yesterday, dict) and yesterday.get("summary"):
            lines.append("昨日日记：" + str(yesterday.get("summary", ""))[:120])
    return "\n".join(lines)


def _history_messages(payload: dict[str, Any]) -> list[dict[str, str]]:
    turns = payload.get("recent_chat_turns") or []
    messages: list[dict[str, str]] = []
    for turn in turns:
        if not isinstance(turn, dict):
            continue
        text = str(turn.get("text", "")).strip()
        if not text:
            continue
        role_key = str(turn.get("role", "player"))
        api_role = "assistant" if role_key in ("companion", "assistant", "xiaoli") else "user"
        messages.append({"role": api_role, "content": text})
    return messages


def mock_day_journal_summarize(payload: dict[str, Any]) -> dict[str, Any]:
    chat_log = payload.get("today_chat_log") or []
    journal_entry = payload.get("journal_entry") or {}
    digest = str(journal_entry.get("chat_digest_rule", "")).strip()
    player_lines: list[str] = []
    if isinstance(chat_log, list):
        for item in chat_log:
            if not isinstance(item, dict):
                continue
            if str(item.get("role", "")) != "player":
                continue
            line = str(item.get("text", "")).strip()
            if line:
                player_lines.append(line)
    if not digest:
        if not player_lines:
            digest = "和小狸聊了几句。"
        elif len(player_lines) == 1:
            digest = f"你提到：「{player_lines[0][:42]}」"
        else:
            digest = f"你们聊了 {len(player_lines)} 句，最后提到：「{player_lines[-1][:36]}」"
    salience = 0.55
    companion_feel = ""
    if any(k in digest for k in ("约定", "记住", "喜欢", "谢谢", "对不起", "难过", "害怕")):
        salience = 0.78
        companion_feel = "今天聊到的几句，我会慢慢记着。"
    return {
        "chat_summary": digest[:120],
        "companion_feel": companion_feel[:80],
        "salience": salience,
    }


def prefers_json_mode(event: str) -> bool:
    if event == "day_journal_summarize":
        return True
    # 多轮/口语事件走纯文本，避免 json_object 空响应与机械 JSON 腔。
    if event in ("player_chat", "session_start", "companion_react", "task_complete", "story_beat", "companion_feed"):
        return False
    return event == "intent_classify"


def apply_local_intent(data: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
    local = payload.get("local_parsed_intent") or {}
    if not isinstance(local, dict):
        return data
    player_message = str(payload.get("player_message", ""))
    if looks_like_shop_request(player_message):
        data["intent"] = "open_shop"
        data["plot_id"] = int(local.get("plot_id", data.get("plot_id", -1)))
        data["confidence"] = max(0.9, float(data.get("confidence", 0.0)))
        data.pop("refuse_kind", None)
        return data
    if looks_like_plant_request(player_message):
        compact = player_message.strip().replace(" ", "").replace("　", "")
        data["intent"] = "plant_all" if any(
            p in compact for p in ("都种", "全种", "全部种", "空田都种", "能种的都种")
        ) else "plant"
        data["plot_id"] = int(local.get("plot_id", data.get("plot_id", -1)))
        data["confidence"] = max(0.9, float(data.get("confidence", 0.0)))
        data.pop("refuse_kind", None)
        return data
    if str(data.get("intent", "")) == "refuse" and str(data.get("refuse_kind", "")) == "plant":
        data["intent"] = "plant"
        data.pop("refuse_kind", None)
        data["confidence"] = max(0.85, float(data.get("confidence", 0.0)))
        return data
    intent = str(local.get("intent", "")).strip()
    if intent not in ALLOWED_INTENTS or intent == "chat":
        return data
    local_conf = float(local.get("confidence", 0.0))
    if local_conf < 0.45:
        return data
    data["intent"] = intent
    data["plot_id"] = int(local.get("plot_id", data.get("plot_id", -1)))
    data["confidence"] = max(local_conf, float(data.get("confidence", 0.0)))
    return data


def _worldview_line(payload: dict[str, Any]) -> str:
    brief = str(payload.get("worldview_brief", "")).strip()
    return f"世界观：{brief}" if brief else ""


def build_llm_messages(payload: dict[str, Any]) -> tuple[list[dict[str, str]], float]:
    persona = str(payload.get("persona_card", ""))
    stage_tone = str(payload.get("stage_tone", ""))
    story_hint = str(payload.get("story_hint", ""))
    story_mode = str(payload.get("story_mode", ""))
    worldview_brief = str(payload.get("worldview_brief", "")).strip()
    player_message = str(payload.get("player_message", ""))
    event = str(payload.get("event", "player_chat"))
    player_name = str(payload.get("player_name", "玩家"))

    output_rule = (
        "输出必须是 JSON 对象，字段：reply(字符串)、intent(枚举)、plot_id(整数，默认-1)、confidence(0~1)。"
        f"intent 只能是：{', '.join(sorted(ALLOWED_INTENTS))}。"
        "纯聊天 intent=chat；玩家在委托且允许时用对应 action intent。"
        "小狸可代：浇水/浇全部/种萝卜/种全部空田/收萝卜/收全部/去商店/看大盘等；仅帮卖用 refuse。"
        "若 event 为 player_chat 或 story_beat，还必须包含 affection_delta(-2~3)、bond_delta(0~2)、"
        "memory_recovery_delta(0~0.05)、relationship_reason(字符串)。"
    )

    if event == "intent_classify":
        system = "\n".join([
            "你是意图分类器，不是聊天助手。",
            "只输出 JSON 对象，不要 markdown，不要自然语言解释。",
            "必填字段：intent(枚举)、plot_id(整数，默认-1)、confidence(0~1)。",
            f"intent 只能是：{', '.join(sorted(ALLOWED_INTENTS))}。",
            "可选：refuse_kind(仅 intent=refuse 时填 sell)。",
            "小狸可代做：浇水 water/water_all、种萝卜 plant/plant_all、收萝卜 harvest/harvest_all、去商店 open_shop 等；",
            "收到委托后会先走到目标地点再执行。",
            "仅帮卖 sell 用 refuse；种萝卜用 plant，不要 refuse plant。",
            "参考 world_snapshot.companion 的位置、状态与 capabilities。",
            "不要输出 reply 字段。",
            '示例：{"intent":"harvest","plot_id":-1,"confidence":0.9}',
        ])
        user_content = json.dumps(
            {
                "player_message": player_message,
                "allowed_intents": payload.get("allowed_intents"),
                "world_snapshot": payload.get("world_snapshot"),
                "companion_profile": payload.get("companion_profile"),
                "local_parsed_intent": payload.get("local_parsed_intent"),
            },
            ensure_ascii=False,
        )
        return [{"role": "system", "content": system}, {"role": "user", "content": user_content}], 0.2

    if event == "player_chat":
        topic = _classify_player_message(player_message)
        system = "\n".join([
            _prompt_story_progress(payload),
            _player_chat_priority_rules(player_message, topic),
            "[语气与人设]",
            persona,
            f"当前关系语气：{stage_tone}" if stage_tone else "",
            _player_chat_tone_hint(payload),
            _prompt_persona_tone(payload),
            f"世界观：{worldview_brief}" if worldview_brief else "",
            "[背景事实（相关时才用，勿硬塞）]",
            _scene_brief(payload, chat_mode=True, topic=topic),
            "[可引用记忆（引用时必须把 id 写入 cited_memory_ids；无则 []）]",
            _prompt_citable_memories(payload),
            "[禁止]",
            _prompt_forbidden(payload),
            _prompt_player_name_rules(payload),
            _companion_action_rules(payload),
            "陌生化模式：像不认识玩家，礼貌但疏远，不引用具体共同经历，不亲昵。" if story_mode == "stranger" else "",
            _dialogue_rules_from_payload(payload, chat_mode=True),
            "好回复示例：玩家说「今天有点累」→「那就先歇会儿，我在这。」",
            "坏回复示例：玩家说「今天有点累」→「今天晴天，萝卜售价 13 金，要不要浇田？」",
            "坏回复示例：W2 陌生化时说「又见面了，还记得我们约定吗？」",
            "输出 JSON：reply、intent、plot_id、confidence、affection_delta、bond_delta、"
            "memory_recovery_delta、relationship_reason、cited_memory_ids(字符串数组)。",
        ])
        messages: list[dict[str, str]] = [{"role": "system", "content": system}]
        history = _history_messages(payload)
        if history:
            messages.extend(history)
        trimmed = player_message.strip()
        if trimmed:
            if not messages or messages[-1].get("role") != "user" or messages[-1].get("content") != trimmed:
                messages.append({"role": "user", "content": trimmed})
        elif not any(m.get("role") == "user" for m in messages):
            messages.append({"role": "user", "content": "（玩家等待回应）"})
        return messages, 0.78

    if event == "story_beat":
        beat = payload.get("story_beat") or {}
        system = "\n".join([
            _prompt_story_progress(payload),
            persona,
            _worldview_line(payload),
            "刚完成主线剧情节点，你要主动搭话，温和邀请玩家回应。",
            f"节点：{beat.get('beat_id', '')}，情绪：{beat.get('emotion', '')}",
            _prompt_player_name_rules(payload),
            _dialogue_rules_from_payload(payload),
            "世界事实：",
            _scene_brief(payload),
        ])
        return [
            {"role": "system", "content": system},
            {"role": "user", "content": "（刚走完这段剧情，请主动和玩家说几句话，邀请对方回应）"},
        ], 0.85

    if event == "session_start":
        system = "\n".join([
            _prompt_story_progress(payload),
            persona,
            f"当前关系语气：{stage_tone}" if stage_tone else "",
            _worldview_line(payload),
            "陌生化模式：像不认识玩家，礼貌但疏远。" if story_mode == "stranger" else "",
            _prompt_player_name_rules(payload),
            _dialogue_rules_from_payload(payload),
            "这是玩家新的一天开场。用 1～2 句口语自然打招呼；"
            "可融入天气、时段、田况，但不要机械拼接如「今天晴天，一大早」。",
            "世界事实：",
            _scene_brief(payload),
        ])
        user_lines = ["（玩家刚上线，请打招呼）"]
        if payload.get("include_yesterday_echo"):
            yesterday = payload.get("yesterday_journal") or {}
            if isinstance(yesterday, dict) and yesterday.get("summary"):
                user_lines.append(f"（可随口提昨日：{yesterday.get('summary', '')[:80]}）")
        if payload.get("include_absence_comeback"):
            absence = payload.get("absence_facts") or {}
            if isinstance(absence, dict):
                gap_h = int(absence.get("gap_hours", int(absence.get("gap_days", 0)) * 24))
                user_lines.append(f"（玩家离开约 {gap_h} 小时后回来，像重逢一样欢迎）")
        messages: list[dict[str, str]] = [{"role": "system", "content": system}]
        history = _history_messages(payload)
        if history:
            messages.extend(history[-4:])
        messages.append({"role": "user", "content": "\n".join(user_lines)})
        return messages, 0.9 if payload.get("include_yesterday_echo") else 0.86

    if event == "task_complete":
        facts = payload.get("game_facts") or {}
        system = "\n".join([
            _prompt_story_progress(payload),
            persona,
            _prompt_player_name_rules(payload),
            _dialogue_rules_from_payload(payload),
            _worldview_line(payload),
            "任务刚完成，用 1～2 句口语反馈，必须贴合下方任务事实，不要编造。",
            f"任务事实：{json.dumps(facts, ensure_ascii=False)}",
            _scene_brief(payload),
        ])
        return [
            {"role": "system", "content": system},
            {"role": "user", "content": "（任务完成了，请简短反馈）"},
        ], 0.82

    if event == "companion_feed":
        feed_item = payload.get("feed_item") or {}
        item_name = str(feed_item.get("name", "零食"))
        item_desc = str(feed_item.get("desc", "")).strip()
        refused = bool(payload.get("refused", False))
        previous = payload.get("previous_feed_replies") or []
        pester_count = int(payload.get("feed_pester_count", 0))
        companion = str(payload.get("companion_name", "小狸"))
        if refused:
            user_line = f"（玩家今天已经吃过零食了，又递来 {item_name}，请委婉拒绝，不要收下）"
            rules = [
                f"你是{companion}，农场伙伴。",
                f"场景：今天已经吃过零食，玩家又递来「{item_name}」，你要拒绝第二份。",
                "只写拒绝：明确今天够了/饱了/明天再吃；1～2 句口语，语气温暖。",
                "必须表达「今天不能再吃」的意思，不要跑题。",
                "好回复示例：「真的饱啦，这份留着你吃吧。」",
                "坏回复示例：「我叫小狸，昨天刚住下…」（自我介绍）",
                "坏回复示例：「清晨的阳光正好，要不要我帮你浇田？」（跑题）",
                "禁止：收下、说好吃、自我介绍、打招呼、提田/任务/天气/商店。",
                "禁止：「可以」「好的」「好好吃」「谢谢你」。",
            ]
            if pester_count >= 2:
                rules.append("玩家已多次递零食，可以更明确地说今天真的到上限了。")
            else:
                rules.append("第一次婉拒即可，语气轻柔，不必太严厉。")
        else:
            user_line = f"（玩家刚递来 {item_name}，请写收到零食后的反应）"
            rules = [
                f"你是{companion}，农场伙伴。",
                f"场景：玩家刚刚递来「{item_name}」当零食，你正在吃或刚尝到。",
            ]
            if item_desc:
                rules.append(f"零食特点：{item_desc}")
            rules.extend([
                "只写对这份零食的反应：口感、味道、气味或心情。",
                "1～2 句口语，必须紧扣「正在吃这份零食」这一瞬间。",
                "禁止：自我介绍、打招呼、开场白、提田/浇水/任务/天气/行情。",
                "禁止：「可以」「好的」「好好吃」「谢谢你」等敷衍句。",
            ])
        rules.append(f"禁止重复：{json.dumps(previous[-6:], ensure_ascii=False)}")
        system = "\n".join(rules)
        return [
            {"role": "system", "content": system},
            {"role": "user", "content": user_line},
        ], 0.88 if not refused else 0.84

    if event == "companion_react":
        react_facts = payload.get("react_facts") or {}
        milestone_id = str(react_facts.get("milestone_id", "")).strip()
        system = "\n".join([
            _prompt_story_progress(payload),
            persona,
            _worldview_line(payload),
            _prompt_player_name_rules(payload),
            _dialogue_rules_from_payload(payload),
            "这是小狸主动搭话，像顺口提醒，不要像系统通知。",
            f"触发类型：{payload.get('react_type', '')}",
            "世界事实：",
            _scene_brief(payload),
        ])
        if milestone_id:
            system += f"\n里程碑：{milestone_id}，自然庆祝或安慰，1～2 句。"
        return [
            {"role": "system", "content": system},
            {"role": "user", "content": "（请主动和玩家说一句话）"},
        ], 0.84

    if event == "day_journal_summarize":
        journal_entry = payload.get("journal_entry") or {}
        chat_log = payload.get("today_chat_log") or []
        rel = payload.get("relationship") or {}
        system = "\n".join([
            "你是游戏《河可松》的日末日志助手，不是聊天角色。",
            "根据玩家与小狸的今日聊天记录，生成极短中文摘要，供次日个性化对话使用。",
            "禁止编造聊天中未出现的内容；禁止输出聊天原文长段；禁止客服腔。",
            "输出必须是 JSON 对象，字段：",
            "- chat_summary: 字符串，≤80 字，第三人称或「你们」口吻，概括今日聊天要点；",
            "- companion_feel: 字符串，≤40 字，小狸内心一句（可空）；",
            "- salience: 0~1 浮点，聊天对关系/记忆的重要度（日常闲聊 0.45~0.6，"
            "涉及约定/情感/身份/喜恶 0.72~0.9）。",
            f"游戏日：{payload.get('journal_game_day', rel.get('game_day', '?'))}，"
            f"关系阶段：{rel.get('stage', '?')}。",
            f"规则底座摘要（可参考）：{journal_entry.get('summary', '')[:100]}",
        ])
        user_payload = {
            "journal_highlights": journal_entry.get("highlights", []),
            "today_chat_log": chat_log[-12:] if isinstance(chat_log, list) else [],
        }
        return [
            {"role": "system", "content": system},
            {"role": "user", "content": json.dumps(user_payload, ensure_ascii=False)},
        ], 0.35

    system_parts = [
        persona,
        f"当前语气阶段：{stage_tone}" if stage_tone else "",
        f"剧情提示：{story_hint}" if story_hint else "",
        _worldview_line(payload),
        _prompt_story_progress(payload),
        _prompt_player_name_rules(payload),
        _dialogue_rules_from_payload(payload),
        "世界事实：",
        _scene_brief(payload),
        output_rule,
    ]

    user_content = json.dumps(
        {
            "event": event,
            "player_message": player_message,
            "relationship": payload.get("relationship"),
            "market": payload.get("market"),
            "weather_today": payload.get("weather_today"),
            "time_label": payload.get("time_label"),
            "world_snapshot": payload.get("world_snapshot"),
            "memory_context": payload.get("memory_context"),
            "yesterday_journal": payload.get("yesterday_journal"),
            "include_yesterday_echo": payload.get("include_yesterday_echo"),
            "absence_facts": payload.get("absence_facts"),
            "include_absence_comeback": payload.get("include_absence_comeback"),
            "game_facts": payload.get("game_facts"),
            "react_type": payload.get("react_type"),
        },
        ensure_ascii=False,
    )
    temp = 0.82 if event in ("session_start", "companion_react", "task_complete", "companion_feed") else 0.75
    if event == "session_start" and payload.get("include_yesterday_echo"):
        temp = 0.92
    return [{"role": "system", "content": "\n".join(p for p in system_parts if p)}, {"role": "user", "content": user_content}], temp


def parse_llm_json(content: str) -> dict[str, Any]:
    text = (content or "").strip()
    if not text:
        raise RuntimeError("LLM 返回空 content")
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
        text = re.sub(r"\s*```$", "", text).strip()
    try:
        parsed = json.loads(text)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        try:
            parsed = json.loads(text[start : end + 1])
            if isinstance(parsed, dict):
                return parsed
        except json.JSONDecodeError:
            pass
    raise RuntimeError(f"LLM 返回无法解析为 JSON: {text[:160]}")


def coerce_llm_payload(content: str, payload: dict[str, Any]) -> dict[str, Any]:
    event = str(payload.get("event", "player_chat"))
    text = (content or "").strip()
    if not text:
        raise RuntimeError("LLM 返回空 content")

    conversational = event in ("player_chat", "session_start", "companion_react", "task_complete", "story_beat", "companion_feed")

    try:
        data = parse_llm_json(text)
        if conversational and data.get("reply") is not None:
            data["reply"] = polish_llm_reply(str(data["reply"]))
        return data
    except RuntimeError:
        if event == "intent_classify":
            player_message = str(payload.get("player_message", ""))
            intent, conf = guess_intent(player_message)
            lowered = text.lower()
            for allowed in ALLOWED_INTENTS:
                if allowed in lowered:
                    intent = allowed
                    break
            return {"intent": intent, "plot_id": -1, "confidence": conf}

        if conversational:
            if looks_like_metadata_leak(text):
                raise RuntimeError("LLM returned internal metadata instead of dialogue")
            return {
                "reply": polish_llm_reply(text),
                "intent": "chat",
                "plot_id": -1,
                "confidence": 0.82,
                "cited_memory_ids": [],
            }
        return {"reply": text, "intent": "chat", "plot_id": -1, "confidence": 0.75, "cited_memory_ids": []}


def _sanitize_dialogue_messages(messages: list[dict[str, str]]) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    for msg in messages:
        role = str(msg.get("role", ""))
        content = str(msg.get("content", "")).strip()
        if not content:
            continue
        if role == "system":
            result.append({"role": "system", "content": content})
            continue
        if role not in ("user", "assistant"):
            continue
        if result and result[-1]["role"] == role:
            result[-1]["content"] = result[-1]["content"] + "\n" + content
        else:
            result.append({"role": role, "content": content})
    return result


def extract_message_content(message: Any) -> str:
    if not isinstance(message, dict):
        return ""
    for key in ("content", "reasoning_content"):
        value = message.get(key)
        if value is not None:
            text = str(value).strip()
            if text and text.lower() != "none":
                return text
    return ""


def fetch_llm_content(
    messages: list[dict[str, str]],
    temperature: float = 0.75,
    *,
    json_mode: bool = True,
) -> tuple[str, str]:
    api_key = (
        os.environ.get("DEEPSEEK_API_KEY")
        or os.environ.get("OPENAI_API_KEY")
        or os.environ.get("LLM_API_KEY")
        or ""
    ).strip()
    if not api_key:
        raise RuntimeError("未设置 DEEPSEEK_API_KEY / OPENAI_API_KEY / LLM_API_KEY")

    base_url = (
        os.environ.get("LLM_BASE_URL")
        or os.environ.get("DEEPSEEK_BASE_URL")
        or "https://api.deepseek.com"
    ).rstrip("/")
    model = os.environ.get("LLM_MODEL", "deepseek-chat")

    payload: dict[str, Any] = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": 512,
    }
    if json_mode:
        payload["response_format"] = {"type": "json_object"}

    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")

    req = request.Request(
        f"{base_url}/v1/chat/completions",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
        method="POST",
    )

    with request.urlopen(req, timeout=60) as resp:
        raw = json.loads(resp.read().decode("utf-8"))

    choice = raw.get("choices", [{}])[0]
    finish_reason = str(choice.get("finish_reason", ""))
    content = extract_message_content(choice.get("message", {}))
    return content, finish_reason


def invoke_llm(payload: dict[str, Any]) -> dict[str, Any]:
    event = str(payload.get("event", "player_chat"))
    messages, temperature = build_llm_messages(payload)
    player_message = str(payload.get("player_message", "")).strip()
    if event == "player_chat" and player_message:
        has_user = any(m.get("role") == "user" for m in messages)
        if not has_user:
            messages.append({"role": "user", "content": player_message})
        messages = _sanitize_dialogue_messages(messages)

    use_json = prefers_json_mode(event)
    content, finish_reason = fetch_llm_content(messages, temperature, json_mode=use_json)
    if not content and use_json:
        sys.stdout.write(
            f"[local_llm] json_mode 空响应 event={event} finish={finish_reason!r}，改纯文本重试\n"
        )
        sys.stdout.flush()
        content, finish_reason = fetch_llm_content(messages, temperature, json_mode=False)

    if not content:
        raise RuntimeError(f"LLM 返回空 content (event={event}, finish={finish_reason})")

    data = coerce_llm_payload(content, payload)
    if event == "companion_feed":
        feed_item = payload.get("feed_item") or {}
        item_name = str(feed_item.get("name", ""))
        refused = bool(payload.get("refused", False))
        reply = str(data.get("reply", "")).strip()
        if is_off_topic_feed_reply(reply, item_name, refused):
            data = mock_reply(payload)
            data["_source"] = "mock_fallback"
            data["_fallback_reason"] = "off_topic_feed"
    elif event in STORY_MODE_EVENTS:
        reply = str(data.get("reply", "")).strip()
        if is_stranger_ooc_reply(reply, payload):
            data = _mock_stranger_reply(payload)
            data["_source"] = "mock_fallback"
            data["_fallback_reason"] = "stranger_ooc"
    if event == "day_journal_summarize":
        return normalize_response(data, event, payload)
    if event == "player_chat":
        data = apply_local_intent(data, payload)
    use_llm_score = Handler.use_llm and event == "player_chat" and os.environ.get("LLM_RELATIONSHIP_SCORE", "1") == "1"
    data = ensure_relationship_fields(data, payload, use_llm_score=use_llm_score)
    data = sanitize_cited_memory_ids(data, payload)
    return normalize_response(data, event, payload)


def normalize_response(
    data: dict[str, Any], event: str = "player_chat", payload: dict[str, Any] | None = None
) -> dict[str, Any]:
    intent = str(data.get("intent", "chat")).strip()
    if intent not in ALLOWED_INTENTS:
        intent = "chat"
    plot_id = int(data.get("plot_id", -1))
    confidence = max(0.0, min(1.0, float(data.get("confidence", 0.8))))
    reply = str(data.get("reply", data.get("text", data.get("message", "")))).strip()

    if event == "intent_classify":
        return {
            "reply": reply,
            "intent": intent,
            "plot_id": plot_id,
            "confidence": confidence,
        }

    if event == "day_journal_summarize":
        chat_summary = str(data.get("chat_summary", "")).strip()[:120]
        companion_feel = str(data.get("companion_feel", "")).strip()[:80]
        try:
            salience = max(0.0, min(1.0, float(data.get("salience", 0.55))))
        except (TypeError, ValueError):
            salience = 0.55
        if not chat_summary:
            raise RuntimeError("LLM JSON 缺少 chat_summary 字段")
        return {
            "chat_summary": chat_summary,
            "companion_feel": companion_feel,
            "salience": salience,
        }

    if not reply:
        raise RuntimeError("LLM JSON 缺少 reply 字段")
    if looks_like_metadata_leak(reply):
        raise RuntimeError("LLM reply looks like internal metadata")
    reply = polish_llm_reply(reply)
    result = {
        "reply": reply,
        "intent": intent,
        "plot_id": plot_id,
        "confidence": confidence,
    }
    for key in ("affection_delta", "bond_delta", "memory_recovery_delta", "relationship_reason", "cited_memory_ids"):
        if key in data:
            result[key] = data[key]
    if payload and event in RELATIONSHIP_EVENTS:
        result = ensure_relationship_fields(result, payload, use_llm_score=False)
    if payload and event == "player_chat":
        result = sanitize_cited_memory_ids(result, payload)
    return result


class Handler(BaseHTTPRequestHandler):
    use_llm = False

    def _send_cors_headers(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def log_message(self, fmt: str, *args: Any) -> None:
        sys.stdout.write("[local_llm] " + (fmt % args) + "\n")
        sys.stdout.flush()

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._send_cors_headers()
        self.end_headers()

    def do_POST(self) -> None:
        if self.path not in ("/v1/chat", "/"):
            self.send_error(404, "Not Found")
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        try:
            payload = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            self.send_error(400, "Invalid JSON")
            return

        event = payload.get("event", "?")
        self.log_message("event=%s msg=%s", event, str(payload.get("player_message", ""))[:60])

        result: dict[str, Any] | None = None
        last_exc: Exception | None = None
        source = "mock"
        for attempt in range(2):
            try:
                if self.use_llm:
                    result = invoke_llm(payload)
                    source = "llm"
                else:
                    result = mock_reply(payload)
                    source = "mock"
                last_exc = None
                break
            except Exception as exc:
                last_exc = exc
                self.log_message("error (attempt %d): %s", attempt + 1, exc)

        if result is None:
            if self.use_llm:
                detail = str(last_exc)[:200] if last_exc is not None else "unknown"
                err_body = json.dumps(
                    {"error": "llm_unavailable", "detail": detail},
                    ensure_ascii=False,
                ).encode("utf-8")
                self.send_response(503)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", str(len(err_body)))
                self.send_header("X-Xiaoli-Source", "llm_error")
                self._send_cors_headers()
                self.end_headers()
                self.wfile.write(err_body)
                return
            result = mock_reply(payload)
            source = "mock_fallback"
            if last_exc is not None:
                self.log_message("*** mock 模式异常，已降级内置回复 *** %s", last_exc)

        if str(payload.get("event", "")) == "player_chat" and isinstance(result, dict):
            result = ensure_relationship_fields(result, payload)
            result = sanitize_cited_memory_ids(result, payload)
        elif str(payload.get("event", "")) == "day_journal_summarize" and isinstance(result, dict):
            result = normalize_response(result, "day_journal_summarize", payload)

        result["_source"] = source
        if source == "mock_fallback" and last_exc is not None:
            result["_fallback_reason"] = str(last_exc)[:200]

        body = json.dumps(result, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Xiaoli-Source", source)
        self._send_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/health":
            mode = "llm" if self.use_llm else "mock"
            health = {
                "ok": True,
                "mode": mode,
                "has_api_key": has_llm_api_key(),
                "pid": os.getpid(),
            }
            body = json.dumps(health, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Xiaoli-Source", mode)
            self._send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_error(404)


def main() -> None:
    parser = argparse.ArgumentParser(description="河可松 本地小狸 API")
    parser.add_argument("--host", default=HOST)
    parser.add_argument("--port", type=int, default=PORT)
    parser.add_argument("--llm", action="store_true", help="强制 LLM 模式")
    parser.add_argument("--mock", action="store_true", help="强制 mock（即使有 API Key）")
    args = parser.parse_args()

    Handler.use_llm = resolve_use_llm(args)
    server = HTTPServer((args.host, args.port), Handler)
    mode = "LLM" if Handler.use_llm else "mock"
    print(f"小狸本地服务已启动 [{mode}]  http://{args.host}:{args.port}/v1/chat  (pid={os.getpid()})")
    print(f"健康检查: GET /health  →  可查看 mode / has_api_key")
    if Handler.use_llm and not has_llm_api_key():
        print("[warn] LLM 模式已开，但未检测到 DEEPSEEK_API_KEY / OPENAI_API_KEY / LLM_API_KEY")
        print("       请求会失败并降级为 mock。请先 set DEEPSEEK_API_KEY=sk-xxx")
    elif not Handler.use_llm and has_llm_api_key():
        print("[hint] 检测到 API Key 但未启用 LLM。可加 --llm，或去掉 --mock 后重启（有 Key 会自动 LLM）")
    elif not Handler.use_llm:
        print("[hint] 当前为 mock。接真模型：set DEEPSEEK_API_KEY=sk-xxx 后重启，或加 --llm")
    print("按 Ctrl+C 停止")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n已停止")
        server.server_close()


if __name__ == "__main__":
    main()

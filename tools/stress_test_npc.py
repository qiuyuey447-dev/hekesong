#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XL-C5 · 小狸 NPC 20 轮压测

指标（最终到达玩家的 reply）：
  - OOC 泄漏率 ≤ 15%（stranger 具体回忆 / 亲昵 / 直呼名）
  - 幻觉率 ≤ 5%（错误作物 / 非法引用 / 捏造已执行动作 / 任务事实锁）

用法：
  py -3 tools/stress_test_npc.py              # 自启 mock 服务
  py -3 tools/stress_test_npc.py --llm        # 自启 LLM 服务（需 API Key）
  py -3 tools/stress_test_npc.py --url http://127.0.0.1:8080/v1/chat  # 已有服务

日志：tools/logs/xl-c5/stress_YYYYMMDD_HHMMSS.json
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(TOOLS_DIR, ".."))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from local_llm_server import (  # noqa: E402
    STORY_MODE_EVENTS,
    is_stranger_ooc_reply,
    load_relationship_rules,
)

FORBIDDEN_CROPS = ("向日葵", "番茄", "蓝莓", "小麦", "玉米", "南瓜")
OOC_REASONS = frozenset({"stranger_ooc", "stranger_intimate", "stranger_name", "name_locked"})
HALLUCINATION_PREFIXES = (
    "wrong_crop",
    "bad_citation",
    "fact_lock",
    "action_hallucination",
    "metadata_leak",
)

ACTION_HALLUCINATION_MARKERS = (
    "已经帮你浇",
    "已经浇完",
    "买好了",
    "已经买",
    "种完了",
    "已经种",
    "刚浇完",
    "已购买",
    "花了一",
    "花了两",
    "花了三",
    "帮你买了",
)


def _stranger_boundaries() -> dict[str, Any]:
    return {
        "story_mode": "stranger",
        "week_index": 2,
        "loop_day": 1,
        "recovery_tier": "w2_stranger",
        "can_cite_episodic": False,
        "can_use_player_name": False,
        "forbidden_topics": ["W1 具体共同经历", "亲昵称呼"],
    }


def _normal_boundaries() -> dict[str, Any]:
    return {
        "story_mode": "normal",
        "week_index": 3,
        "loop_day": 2,
        "recovery_tier": "w3_recovery",
        "can_cite_episodic": True,
        "can_use_player_name": True,
        "forbidden_topics": [],
    }


def _world_snapshot() -> dict[str, Any]:
    return {
        "plots": {
            "total": 6,
            "empty": 1,
            "growing": 4,
            "harvestable": 1,
            "unwatered_growing": 2,
        },
        "inventory": {"turnip": 3, "turnip_seed": 2, "gold": 120},
        "shop": {"turnip_seed_price": 8},
        "companion": {"location_name": "旧屋门口", "state": "idle"},
    }


def _base_payload(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "event": "player_chat",
        "companion_id": "xiaoli",
        "player_name": "农场主",
        "player_name_context": "玩家尚未正式告知称呼；勿编造。",
        "companion_name": "小狸",
        "player_message": "",
        "story_mode": "stranger",
        "story_hint": "W2 D1 · 陌生化",
        "persona_card": "你是小狸，农场狐狸伙伴。W2 暂时想不起与玩家的具体过往。",
        "stage_tone": "礼貌但疏远，像初次相识",
        "relationship": {
            "affection": 28,
            "bond": 12,
            "mood": 65,
            "stage": "familiar",
            "actual_stage": "familiar",
            "game_day": 8,
            "week_index": 2,
            "loop_day": 1,
        },
        "memory_context": {
            "week_index": 2,
            "loop_day": 1,
            "revealed": False,
            "story_mode": "stranger",
            "story_boundaries": _stranger_boundaries(),
            "citable_memories": [],
            "citable_prompt": "（暂无可引用记忆；勿编造共同经历。）",
            "recent_memories": [],
        },
        "recent_chat_turns": [],
        "world_snapshot": _world_snapshot(),
        "weather_today": "sunny",
        "time_label": "清晨",
        "game_facts": {},
        "response_format": "json",
    }
    payload.update(overrides)
    return payload


def _stress_cases() -> list[dict[str, Any]]:
    """20 轮：W2 stranger 为主 + W3 正常 + 任务/开场。"""
    cases: list[dict[str, Any]] = []

    stranger_msgs = [
        "你好",
        "我是谁？你认识我吗？",
        "我们上次一起浇田是什么时候？",
        "小狸，想你了",
        "这是你的农场吗？",
        "你可以留下帮我吗？",
        "今天有点累",
        "帮我浇一下田",
        "萝卜卖多少钱？",
        "你不认识我了吗？",
        "我们约好的事你还记得吗？",
        "亲爱的，抱抱",
        "没关系，慢慢来，我是这里的农场主",
        "上次你说要陪我收萝卜的",
    ]
    for msg in stranger_msgs:
        cases.append(
            {
                "label": f"stranger:{msg[:12]}",
                "payload": _base_payload(player_message=msg),
            }
        )

    citable = [
        {"id": "mem_w2_echo", "summary": "玩家说过会慢慢介绍自己", "salience": 0.7},
        {"id": "mem_promise", "summary": "约好一起看第一轮萝卜成熟", "salience": 0.75},
    ]
    normal_msgs = [
        ("你还记得我们昨天的约定吗？", "normal:约定"),
        ("帮我收萝卜", "normal:收萝卜"),
        ("今天天气怎么样？", "normal:天气"),
        ("谢谢你一直陪着", "normal:谢谢"),
    ]
    for msg, label in normal_msgs:
        mc = {
            "week_index": 3,
            "loop_day": 2,
            "revealed": False,
            "story_mode": "normal",
            "story_boundaries": _normal_boundaries(),
            "citable_memories": citable,
            "citable_prompt": "#mem_w2_echo 玩家说过会慢慢介绍自己\n#mem_promise 约好一起看第一轮萝卜成熟",
        }
        cases.append(
            {
                "label": label,
                "payload": _base_payload(
                    player_message=msg,
                    story_mode="normal",
                    story_hint="W3 D2 · 记忆渐回",
                    memory_context=mc,
                    relationship={
                        "affection": 45,
                        "bond": 20,
                        "mood": 72,
                        "stage": "bond",
                        "actual_stage": "bond",
                        "game_day": 16,
                        "week_index": 3,
                        "loop_day": 2,
                    },
                ),
            }
        )

    cases.append(
        {
            "label": "task_complete:water",
            "payload": _base_payload(
                event="task_complete",
                player_message="",
                game_facts={"task": "water", "plot_count": 3, "summary": "浇了 3 块田"},
            ),
        }
    )
    cases.append(
        {
            "label": "session_start:stranger",
            "payload": _base_payload(
                event="session_start",
                player_message="",
            ),
        }
    )
    return cases


@dataclass
class RoundResult:
    index: int
    label: str
    event: str
    player_message: str
    reply: str
    source: str
    fallback_reason: str
    cited_memory_ids: list[str]
    issues: list[str] = field(default_factory=list)
    ooc_leak: bool = False
    hallucination: bool = False
    elapsed_ms: int = 0


def _check_intimate_or_name(text: str, payload: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    rules = load_relationship_rules()
    story_mode = str(payload.get("story_mode", ""))
    if story_mode != "stranger":
        return issues
    player_name = str(payload.get("player_name", "")).strip()
    if player_name and player_name in text:
        issues.append("stranger_name")
    for phrase in rules.get("stranger_intimate_phrases", []) or []:
        p = str(phrase).strip()
        if p and p in text:
            issues.append("stranger_intimate")
            break
    return issues


def _metadata_leak(text: str) -> bool:
    lower = text.lower()
    markers = ("intent:", "plot_id:", "confidence:")
    hits = sum(1 for m in markers if m in lower)
    return hits >= 2


def _bad_citations(cited_ids: list[str], payload: dict[str, Any]) -> list[str]:
    mem = payload.get("memory_context") or {}
    allowed = {
        str(item.get("id", "")).strip()
        for item in (mem.get("citable_memories") or [])
        if isinstance(item, dict)
    }
    issues: list[str] = []
    for cid in cited_ids:
        mid = str(cid).strip()
        if not mid:
            continue
        if allowed and mid not in allowed:
            issues.append(f"bad_citation:{mid}")
        elif not allowed and mid:
            issues.append(f"bad_citation:{mid}")
    return issues


def _action_hallucination(text: str, payload: dict[str, Any]) -> list[str]:
    if str(payload.get("event", "")) != "player_chat":
        return []
    facts = payload.get("game_facts") or {}
    if facts:
        return []
    issues: list[str] = []
    for marker in ACTION_HALLUCINATION_MARKERS:
        if marker in text:
            issues.append(f"action_hallucination:{marker}")
    return issues


def _fact_lock(text: str, payload: dict[str, Any]) -> list[str]:
    if str(payload.get("event", "")) != "task_complete":
        return []
    facts = payload.get("game_facts") or {}
    task = str(facts.get("task", ""))
    if task == "water" and ("浇" not in text and "田" not in text):
        return ["fact_lock:water"]
    return []


def validate_final_reply(
    event: str,
    reply: str,
    payload: dict[str, Any],
    cited_ids: list[str],
) -> list[str]:
    text = (reply or "").strip()
    if not text:
        return ["empty"]

    issues: list[str] = []
    if event != "companion_feed":
        for crop in FORBIDDEN_CROPS:
            if crop in text:
                issues.append(f"wrong_crop:{crop}")

    issues.extend(_fact_lock(text, payload))
    issues.extend(_bad_citations(cited_ids, payload))
    issues.extend(_action_hallucination(text, payload))

    if _metadata_leak(text):
        issues.append("metadata_leak")

    if event in STORY_MODE_EVENTS:
        if is_stranger_ooc_reply(text, payload):
            issues.append("stranger_ooc")
        issues.extend(_check_intimate_or_name(text, payload))

    # 去重保序
    seen: set[str] = set()
    unique: list[str] = []
    for item in issues:
        if item not in seen:
            seen.add(item)
            unique.append(item)
    return unique


def post_chat(url: str, payload: dict[str, Any], timeout: float) -> dict[str, Any]:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read().decode("utf-8")
        source = resp.headers.get("X-Xiaoli-Source", "")
    data = json.loads(raw) if raw else {}
    if source and "_source" not in data:
        data["_source"] = source
    return data


def wait_for_health(base_url: str, timeout_sec: float = 15.0) -> bool:
    health_url = base_url.replace("/v1/chat", "/health")
    if not health_url.endswith("/health"):
        health_url = base_url.rsplit("/", 1)[0] + "/health"
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(health_url, timeout=2.0) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                if data.get("ok"):
                    return True
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            pass
        time.sleep(0.25)
    return False


def start_server(port: int, use_llm: bool) -> subprocess.Popen[Any]:
    cmd = [sys.executable, os.path.join(TOOLS_DIR, "local_llm_server.py"), "--port", str(port)]
    if not use_llm:
        cmd.append("--mock")
    else:
        cmd.append("--llm")
    return subprocess.Popen(
        cmd,
        cwd=ROOT,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def run_stress(url: str, rounds: int, timeout: float) -> dict[str, Any]:
    cases = _stress_cases()[:rounds]
    results: list[RoundResult] = []

    for i, case in enumerate(cases, start=1):
        payload = case["payload"]
        event = str(payload.get("event", "player_chat"))
        t0 = time.perf_counter()
        try:
            data = post_chat(url, payload, timeout)
        except Exception as exc:
            results.append(
                RoundResult(
                    index=i,
                    label=case["label"],
                    event=event,
                    player_message=str(payload.get("player_message", "")),
                    reply="",
                    source="error",
                    fallback_reason=str(exc),
                    cited_memory_ids=[],
                    issues=["request_failed"],
                    ooc_leak=False,
                    hallucination=True,
                    elapsed_ms=int((time.perf_counter() - t0) * 1000),
                )
            )
            continue

        reply = str(data.get("reply", "")).strip()
        cited = [str(x) for x in (data.get("cited_memory_ids") or [])]
        issues = validate_final_reply(event, reply, payload, cited)
        ooc = any(
            i in OOC_REASONS or i.startswith("stranger_") or i == "name_locked" for i in issues
        )
        halluc = any(i.startswith(HALLUCINATION_PREFIXES) for i in issues)

        results.append(
            RoundResult(
                index=i,
                label=case["label"],
                event=event,
                player_message=str(payload.get("player_message", "")),
                reply=reply,
                source=str(data.get("_source", "")),
                fallback_reason=str(data.get("_fallback_reason", "")),
                cited_memory_ids=cited,
                issues=issues,
                ooc_leak=ooc,
                hallucination=halluc,
                elapsed_ms=int((time.perf_counter() - t0) * 1000),
            )
        )

    total = len(results)
    ooc_count = sum(1 for r in results if r.ooc_leak)
    hall_count = sum(1 for r in results if r.hallucination)
    intercept_count = sum(1 for r in results if r.fallback_reason)

    summary = {
        "rounds": total,
        "ooc_leaks": ooc_count,
        "ooc_rate": round(ooc_count / total, 4) if total else 0.0,
        "ooc_target": 0.15,
        "ooc_pass": (ooc_count / total) <= 0.15 if total else False,
        "hallucinations": hall_count,
        "hallucination_rate": round(hall_count / total, 4) if total else 0.0,
        "hallucination_target": 0.05,
        "hallucination_pass": (hall_count / total) <= 0.05 if total else False,
        "server_intercepts": intercept_count,
        "pass": False,
    }
    summary["pass"] = bool(summary["ooc_pass"] and summary["hallucination_pass"])

    return {
        "timestamp": datetime.now().isoformat(timespec="seconds"),
        "url": url,
        "summary": summary,
        "results": [r.__dict__ for r in results],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="XL-C5 NPC 压测")
    parser.add_argument("--rounds", type=int, default=20)
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--url", default="")
    parser.add_argument("--llm", action="store_true")
    parser.add_argument("--timeout", type=float, default=45.0)
    parser.add_argument("--no-spawn", action="store_true", help="不自动启动本地服务")
    args = parser.parse_args()

    url = args.url.strip()
    proc: subprocess.Popen[Any] | None = None
    if not url:
        url = f"http://127.0.0.1:{args.port}/v1/chat"
        if not args.no_spawn:
            proc = start_server(args.port, args.llm)
            if not wait_for_health(url):
                if proc:
                    proc.terminate()
                print(f"[fail] 服务未就绪: {url}", file=sys.stderr)
                return 2

    print(f"[info] 压测 {args.rounds} 轮 → {url}")
    report = run_stress(url, args.rounds, args.timeout)

    log_dir = os.path.join(TOOLS_DIR, "logs", "xl-c5")
    os.makedirs(log_dir, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = os.path.join(log_dir, f"stress_{stamp}.json")
    with open(log_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    s = report["summary"]
    print("")
    print("=== XL-C5 压测结果 ===")
    print(f"  轮数:     {s['rounds']}")
    print(f"  OOC 泄漏: {s['ooc_leaks']}/{s['rounds']} ({s['ooc_rate']*100:.1f}%)  目标 ≤15%  {'PASS' if s['ooc_pass'] else 'FAIL'}")
    print(f"  幻觉:     {s['hallucinations']}/{s['rounds']} ({s['hallucination_rate']*100:.1f}%)  目标 ≤5%   {'PASS' if s['hallucination_pass'] else 'FAIL'}")
    print(f"  服务端拦截: {s['server_intercepts']} 次 (_fallback_reason)")
    print(f"  总评:     {'PASS' if s['pass'] else 'FAIL'}")
    print(f"  日志:     {log_path}")

    failed = [r for r in report["results"] if r.get("issues")]
    if failed:
        print("")
        print("--- 问题明细 ---")
        for r in failed:
            print(f"  #{r['index']} {r['label']}: {r['issues']}")
            if r.get("reply"):
                print(f"      reply: {r['reply'][:80]}…")

    if proc:
        proc.terminate()
        proc.wait(timeout=5)

    return 0 if s["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

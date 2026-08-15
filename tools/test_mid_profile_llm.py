#!/usr/bin/env python3
"""Quick mid-profile LLM sync smoke test (local _beat_context_line + optional Cloud Run)."""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request

TOOLS = __file__.rsplit("\\", 1)[0] if "\\" in __file__ else __file__.rsplit("/", 1)[0]
if TOOLS not in sys.path:
    sys.path.insert(0, TOOLS)

from local_llm_server import _beat_context_line  # noqa: E402

MID_BEAT_CTX = {
    "beat_id": "P_N02",
    "variant_id": "P_N02_mid",
    "profile": "mid",
    "affection_tier": "mid",
    "emotion": "廊下躲雨",
    "invite_tone": "【廊下·中】让半块干处、红薯推回来；留一步距离，不贴不赶。",
    "invite_goal": "轻轻带到廊下躲雨；铺垫红薯与半块干处，不要念信纸。",
}

BASE_PAYLOAD = {
    "event": "companion_proactive",
    "beat_context": MID_BEAT_CTX,
    "invite_tone": MID_BEAT_CTX["invite_tone"],
    "invite_goal": MID_BEAT_CTX["invite_goal"],
    "proactive_intent": "invite",
    "story_mode": "keep",
    "companion_name": "小狸",
    "player_name": "阿松",
    "relationship": {"affection": 40, "bond": 25, "game_day": 2},
    "time_of_day": "morning",
    "time_label": "清晨",
    "weather_today": "rain",
    "story_context": {"game_day": 2, "story_mode": "keep", "pending_beat_id": "P_N02"},
    "response_format": "json",
    "player_message": "",
    "memory_context": {"story_mode": "keep", "citable_memories": []},
    "world_snapshot": {},
}

WARM_OVERFLOW = ("一起躲雨", "拽进", "尾巴尖碰", "现在有你", "一人一半才像")
COLD_OVERFLOW = ("站远点也淋不到", "公事公办")


def test_local_beat_context() -> None:
    line = _beat_context_line(BASE_PAYLOAD)
    print("LOCAL beat_context_line:")
    print(line)
    assert "分支 profile：mid" in line, "missing mid profile"
    assert "profile 语气" in line and "中：" in line, "missing mid tone hint"
    assert "开口温度" in line and "廊下·中" in line, "missing invite_tone"
    print("LOCAL: PASS")


def test_cloud_invite(url: str) -> None:
    body = json.dumps(BASE_PAYLOAD, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json; charset=utf-8"})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        print(f"CLOUD HTTP {exc.code}: {exc.read().decode('utf-8', errors='replace')[:300]}")
        raise SystemExit(1) from exc
    reply = str(data.get("reply", "")).strip()
    src = str(data.get("_source", ""))
    print(f"CLOUD reply ({src}): {reply}")
    warm = [m for m in WARM_OVERFLOW if m in reply]
    cold = [m for m in COLD_OVERFLOW if m in reply]
    if warm:
        print(f"CLOUD WARN: warm overflow markers: {warm}")
    if cold:
        print(f"CLOUD WARN: cold overflow markers: {cold}")
    if not warm and not cold and reply:
        print("CLOUD: PASS (mid-range tone, no warm/cold overflow)")
    elif not reply:
        print("CLOUD WARN: empty reply")


if __name__ == "__main__":
    test_local_beat_context()
    cloud_url = sys.argv[1] if len(sys.argv) > 1 else (
        "https://xiaoli-api-288258-10-1457975289.sh.run.tcloudbase.com/v1/chat"
    )
    print(f"\nHitting Cloud Run: {cloud_url}")
    test_cloud_invite(cloud_url)

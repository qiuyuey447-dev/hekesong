#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""上线前 Cloud Run 实机回归：闲聊当令 / 问句 / 旁白 / 陌生化 / 真命令。"""
from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request

URL = "https://xiaoli-api-288258-10-1457975289.sh.run.tcloudbase.com/v1/chat"
HEALTH = "https://xiaoli-api-288258-10-1457975289.sh.run.tcloudbase.com/health"

EMPTY_FIELD = {
    "plots": {"empty": 3, "growing": 0, "harvestable": 0},
    "inventory": {"turnip_seed": 0, "gold": 40},
    "shop": {"turnip_seed_price": 8},
    "companion": {"location_name": "田边", "busy": False, "capabilities": {"can_harvest": True}},
    "weather_today": "sun",
    "time_of_day": "noon",
}

BASE = {
    "event": "player_chat",
    "companion_name": "小狸",
    "player_name": "阿松",
    "story_mode": "keep",
    "time_of_day": "noon",
    "time_label": "正午",
    "weather_today": "sun",
    "relationship": {"affection": 42, "bond": 20, "game_day": 3},
    "story_context": {"game_day": 3, "story_mode": "keep"},
    "memory_context": {"story_mode": "keep", "citable_memories": []},
    "world_snapshot": EMPTY_FIELD,
    "game_facts": {"empty_plots": 3, "seeds": 0},
    "local_parsed_intent": {"intent": "chat", "confidence": 0.4, "plot_id": -1},
    "response_format": "json",
}

FARM_INTENTS = {
    "water", "water_all", "plant", "plant_all",
    "harvest", "harvest_all", "open_shop", "open_market",
}
NARRATION = ("我抖了", "抖了下尾巴", "晃了晃尾巴", "竖起耳朵", "眨了眨眼", "我抬眼")
CRUNCH = ("咔嚓", "咔哧", "嘎吱")
SHOP_PROMPT = ("要买几包", "说个数字", "我这就去种", "我先去商店")


def post(payload: dict, timeout: float = 28.0) -> dict:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    last_err: Exception | None = None
    for attempt in range(4):
        req = urllib.request.Request(
            URL, data=body, headers={"Content-Type": "application/json; charset=utf-8"}
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            last_err = exc
            if exc.code in (429, 503, 502, 504) and attempt < 3:
                time.sleep(2.5 * (attempt + 1))
                continue
            raise
        except TimeoutError as exc:
            last_err = exc
            if attempt < 3:
                time.sleep(2.0)
                continue
            raise
    raise last_err or RuntimeError("post failed")


def chat(message: str, extra: dict | None = None) -> dict:
    payload = dict(BASE)
    payload["player_message"] = message
    if extra:
        payload.update(extra)
    data = post(payload)
    return {
        "msg": message,
        "intent": str(data.get("intent", "")),
        "reply": str(data.get("reply", "")).replace("\n", " / "),
        "source": str(data.get("_source", data.get("source", ""))),
        "plan": data.get("plan"),
    }


def check(name: str, ok: bool, detail: str) -> dict:
    print(("PASS" if ok else "FAIL") + f"  {name}: {detail}")
    return {"name": name, "ok": ok, "detail": detail}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    health = json.loads(urllib.request.urlopen(HEALTH, timeout=15).read().decode("utf-8"))
    print(f"health={health}")
    results: list[dict] = []

    lol1 = chat(
        "你玩英雄联盟吗",
        {
            "recent_chat_turns": [],
            "world_snapshot": EMPTY_FIELD,
        },
    )
    print(f"  LoL1 intent={lol1['intent']} reply={lol1['reply'][:80]}")
    results.append(check(
        "LoL问句 intent=chat",
        lol1["intent"] == "chat" and lol1["intent"] not in FARM_INTENTS,
        f"intent={lol1['intent']} reply={lol1['reply'][:60]}",
    ))
    results.append(check(
        "LoL问句不推销买种",
        not any(p in lol1["reply"] for p in SHOP_PROMPT),
        lol1["reply"][:70],
    ))

    lol2 = chat(
        "对啊",
        {
            "recent_chat_turns": [
                {"role": "player", "text": "你玩英雄联盟吗"},
                {"role": "companion", "text": lol1["reply"] or "知道啊，不就是那个推塔的？你玩那个？"},
            ],
            "world_snapshot": EMPTY_FIELD,
        },
    )
    print(f"  对啊 intent={lol2['intent']} reply={lol2['reply'][:80]}")
    results.append(check(
        "对啊 intent=chat",
        lol2["intent"] == "chat",
        f"intent={lol2['intent']} reply={lol2['reply'][:70]}",
    ))
    results.append(check(
        "对啊不进入买种/去种",
        not any(p in lol2["reply"] for p in SHOP_PROMPT) and lol2["intent"] not in FARM_INTENTS,
        f"intent={lol2['intent']} {lol2['reply'][:70]}",
    ))

    q1 = chat("你不认识我咋还帮我收萝卜")
    results.append(check(
        "问句不当令·收萝卜",
        q1["intent"] == "chat",
        f"intent={q1['intent']} {q1['reply'][:60]}",
    ))
    q2 = chat("我是问你是不是帮我收的")
    results.append(check(
        "问句不当令·是不是收的",
        q2["intent"] == "chat",
        f"intent={q2['intent']} {q2['reply'][:60]}",
    ))
    q3 = chat("你咋没买")
    results.append(check(
        "你咋没买 不是收田",
        q3["intent"] in ("chat", "check_status") and q3["intent"] != "harvest",
        f"intent={q3['intent']} {q3['reply'][:60]}",
    ))
    cmd = chat(
        "帮我收萝卜",
        {"local_parsed_intent": {"intent": "harvest_all", "confidence": 0.9, "plot_id": -1}},
    )
    results.append(check(
        "真命令仍可收",
        cmd["intent"] in ("harvest", "harvest_all"),
        f"intent={cmd['intent']} {cmd['reply'][:50]}",
    ))
    buy = chat(
        "去商店买5包萝卜种子",
        {"local_parsed_intent": {"intent": "open_shop", "confidence": 0.95, "plot_id": -1}},
    )
    results.append(check(
        "真命令仍可买种",
        buy["intent"] == "open_shop",
        f"intent={buy['intent']} {buy['reply'][:50]}",
    ))

    idle = chat("今天太阳挺好的")
    results.append(check(
        "日常闲聊 intent=chat",
        idle["intent"] == "chat",
        f"intent={idle['intent']} {idle['reply'][:60]}",
    ))
    results.append(check(
        "日常闲聊无动作旁白",
        not any(n in idle["reply"] for n in NARRATION),
        idle["reply"][:70],
    ))
    results.append(check(
        "日常闲聊不硬推销买种",
        not any(p in idle["reply"] for p in ("要买几包", "说个数字")),
        idle["reply"][:70],
    ))

    feed = post({
        **BASE,
        "event": "companion_feed",
        "player_message": "",
        "feed_item": "apple",
        "item_name": "苹果",
        "refused": False,
    })
    feed_reply = str(feed.get("reply", "")).replace("\n", " / ")
    results.append(check(
        "投喂无咔嚓",
        not any(c in feed_reply for c in CRUNCH),
        feed_reply[:70],
    ))

    stranger = post({
        **BASE,
        "event": "session_start",
        "player_message": "",
        "player_name": "槐秋",
        "story_mode": "stranger",
        "time_of_day": "morning",
        "time_label": "清晨",
        "relationship": {"affection": 30, "bond": 18, "game_day": 4},
        "story_context": {"game_day": 4, "story_mode": "stranger"},
        "memory_context": {"story_mode": "stranger", "citable_memories": []},
    })
    s_reply = str(stranger.get("reply", "")).replace("\n", " / ")
    results.append(check(
        "D4 清晨不叫槐秋",
        "槐秋" not in s_reply,
        s_reply[:70],
    ))

    # 旁白：若模型仍写出，服务端 polish 应剥掉
    tail = chat("你在干嘛")
    results.append(check(
        "你在干嘛无动作旁白",
        not any(n in tail["reply"] for n in NARRATION),
        tail["reply"][:70],
    ))

    failed = [r for r in results if not r["ok"]]
    print("")
    print(f"API probe {len(results) - len(failed)}/{len(results)} pass, {len(failed)} fail")
    for r in failed:
        print(f"  - {r['name']}: {r['detail']}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

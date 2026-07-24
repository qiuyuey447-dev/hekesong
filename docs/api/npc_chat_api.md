# 小狸 NPC Chat API

> 版本 **v2.0** · 与 Godot `NpcBridge` / `IntentBridge` / `ResponseValidator` / `RelationshipDirector` 对齐  
> 本地开发服务器：`tools/local_llm_server.py`

---

## 1. 架构概览

```
Godot 客户端                          本地 / 远程 API
─────────────                         ───────────────
NpcBridge.request_event()  ──POST──►  /v1/chat
IntentBridge.classify_message() ──POST► /v1/chat  (event=intent_classify)
         │                                    │
         ▼                                    ▼
ResponseValidator.validate()          invoke_llm() / mock_reply()
         │                                    │
         ▼                                    ▼
NpcFallback（降级）                   relationship_rules.json 判分
RelationshipDirector.apply_llm_relationship_delta()
MemoryService.validate_citations()
```

**职责划分**

| 层 | 职责 |
|----|------|
| Prompt（服务端） | 五段结构：剧情进度 / 人设语气 / 场景事实 / 可引用记忆 / 禁止项 |
| LLM 输出 | 自然语言 `reply` + 结构化字段（intent / delta / cited_memory_ids） |
| 客户端校验 | 事实锁、记忆引用、stranger OOC、投喂跑题等 |
| 降级 | API 不可用、校验失败、服务端 post-sanitize → `NpcFallback` |

---

## 2. 端点

| 项 | 值 |
|----|-----|
| Method | `POST` |
| URL | `{api_url}`，默认 `http://127.0.0.1:8080/v1/chat` |
| Content-Type | `application/json` |
| 鉴权 | `Authorization: Bearer {api_key}`（可选，空则不带） |
| 响应头 | `X-Xiaoli-Source`: `llm` / `mock` / `mock_fallback` / `llm_error` |

### 健康检查

`GET /health`

```json
{
  "ok": true,
  "mode": "llm",
  "has_api_key": true,
  "pid": 12345
}
```

### LLM 不可用

HTTP **503**，body：

```json
{
  "error": "llm_unavailable",
  "detail": "…"
}
```

Godot 侧视为请求失败，走 `request_failed` + 本地 fallback（部分 event 静默）。

---

## 3. 游戏配置 `npc_config`

**加载顺序**：`user://npc_config.json` 优先，否则 `res://config/npc_config.json`。

示例见 `config/npc_config.example.json`。

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `enabled` | bool | `false` | 是否启用 API；`false` 时全程 `NpcFallback` |
| `api_url` | string | — | POST 地址，须非空且 `enabled=true` 才连 API |
| `api_key` | string | `""` | Bearer token；本地 mock 可填 `local-dev` 或留空 |
| `npc_id` | string | `xiaoli` | 写入 payload 的 `companion_id` |
| `timeout_sec` | float | `15.0` | `NpcBridge` HTTP 超时（秒） |
| `mock_delay_sec` | float | `0.4` | 本地 fallback 模拟延迟（仅无 API 路径） |
| `require_relationship_delta` | bool | `true` | `player_chat` / `story_beat` 缺 delta 时 `push_warning` |
| `intent_fallback_enabled` | bool | `true` | 低置信本地意图时走 `IntentBridge` API 分类 |
| `intent_classify_url` | string | `""` | 意图分类专用 URL；空则复用 `api_url` |
| `intent_timeout_sec` | float | `8.0` | `IntentBridge` HTTP 超时（秒） |

### 本地联调最小配置

```json
{
  "enabled": true,
  "api_url": "http://127.0.0.1:8080/v1/chat",
  "api_key": "",
  "npc_id": "xiaoli",
  "timeout_sec": 20.0,
  "require_relationship_delta": true,
  "intent_fallback_enabled": true
}
```

启动服务：

```bash
# mock（无 Key，规则判分 + 内置台词）
py -3 tools/local_llm_server.py --port 8080

# LLM（对话 + 关系裁判）
set DEEPSEEK_API_KEY=sk-xxx
py -3 tools/local_llm_server.py --llm --port 8080
```

环境变量（LLM 模式）：`DEEPSEEK_API_KEY` / `OPENAI_API_KEY` / `LLM_API_KEY`（OpenAI 兼容）。  
`player_chat` 关系分：`LLM_RELATIONSHIP_SCORE=1`（默认）时第二次短调用裁判；否则走 `relationship_rules.json` 规则。

---

## 4. 请求体（Godot → 服务端）

`NpcBridge._build_payload(event, extra)` 发送完整 JSON。核心字段：

```json
{
  "event": "player_chat",
  "companion_id": "xiaoli",
  "player_name": "农场主",
  "player_name_context": "…",
  "companion_name": "小狸",
  "player_message": "没关系，慢慢来。",
  "story_mode": "stranger",
  "story_hint": "W2 D1 · 陌生化",
  "story_context": "…",
  "worldview_brief": "…",
  "persona_card": "…",
  "stage_tone": "…",
  "relationship": {
    "affection": 32,
    "bond": 18,
    "mood": 70,
    "stage": "familiar",
    "actual_stage": "familiar",
    "game_day": 10,
    "week_index": 2,
    "loop_day": 3
  },
  "memory_context": { "…": "见 §6" },
  "recent_chat_turns": [
    {"role": "player", "text": "…"},
    {"role": "companion", "text": "…"}
  ],
  "world_snapshot": { "…": "…" },
  "companion_profile": { "…": "…" },
  "game_facts": {},
  "weather_today": "sunny",
  "weather_tomorrow_hint": "…",
  "time_of_day": "morning",
  "time_label": "清晨",
  "market": { "…": "…" },
  "response_format": "json",
  "intent_instruction": "…",
  "allowed_intents": ["chat", "water", "…"],
  "local_parsed_intent": {},
  "needs_intent_fallback": false
}
```

### 4.1 event 类型

| event | 说明 | 须返回 affection_delta | 客户端校验 |
|-------|------|------------------------|------------|
| `player_chat` | 玩家对话 | **是** | 引用 / OOC / metadata |
| `story_beat` | 节点后搭话 | **是**（通常 0） | OOC |
| `session_start` | 每日开场 | 否 | OOC |
| `task_complete` | 任务完成反馈 | 否 | 事实锁 + OOC |
| `companion_react` | 世界主动反应（已少用） | 否 | 禁作物名 |
| `companion_feed` | 投喂零食反应 / 婉拒 | 否 | 投喂专用（§8.2） |
| `day_journal_summarize` | 日末聊天摘要 | 否 | 返回 journal JSON |
| `intent_classify` | 意图分类（`IntentBridge`） | 否 | 无 reply |
| `day_end` | 日末告别 | 否 | — |

### 4.2 event 专用 extra 字段

| event | extra → payload 字段 |
|-------|----------------------|
| `player_chat` | `player_message`, `parsed_intent`, `needs_intent_fallback` |
| `story_beat` | `story_beat` `{beat_id, emotion, node_label, …}` |
| `session_start` | `include_yesterday_echo`, `include_absence_comeback`, `absence_facts` |
| `task_complete` | `game_facts` `{task, plot_count, summary, …}` |
| `companion_react` | `react_type`, `react_facts`, `world_snapshot` |
| `companion_feed` | `feed_item`, `refused`, `previous_replies`, `pester_count` |
| `day_journal_summarize` | `today_chat_log`, `journal_entry`, `game_day` |

### 4.3 allowed_intents

```
chat, water, water_all, harvest, harvest_all, plant, plant_all,
open_market, open_shop, open_memory, check_status, help, sleep, refuse
```

- 纯聊天 → `chat`
- 委托做事 → 对应 action intent
- **仅帮卖** → `refuse`（`refuse_kind=sell`）；种萝卜用 `plant`，不要 refuse plant

---

## 5. 响应体（服务端 → Godot）

### 5.1 对话类（含 `reply`）

`player_chat` / `story_beat` / `session_start` / `task_complete` / `companion_react` / `companion_feed`：

```json
{
  "reply": "……嗯，谢谢你愿意再说一次。",
  "intent": "chat",
  "plot_id": -1,
  "confidence": 0.88,
  "affection_delta": 2,
  "bond_delta": 1,
  "memory_recovery_delta": 0.01,
  "relationship_reason": "玩家耐心安慰，W2 重新接纳",
  "cited_memory_ids": ["mem_001"],
  "_source": "llm",
  "_fallback_reason": ""
}
```

| 字段 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `reply` | string | — | 小狸台词；1～3 句口语 |
| `intent` | string | 见 ALLOWED_INTENTS | 动作意图 |
| `plot_id` | int | -1 或田块 id | 单块田委托 |
| `confidence` | float | 0～1 | 意图置信度 |
| `affection_delta` | int | -2～3 | 亲密度变化（关系类 event **必填**） |
| `bond_delta` | int | 0～2 | 默契变化（无则 0） |
| `memory_recovery_delta` | float | 0～0.05 | 记忆恢复微增 |
| `cited_memory_ids` | string[] | — | 仅可引用 payload 内 `#id`；无则 `[]` |
| `relationship_reason` | string | 可选 | 调试：判分理由 |
| `_source` | string | 可选 | `llm` / `mock` / `mock_fallback` |
| `_fallback_reason` | string | 可选 | 降级原因，如 `stranger_ooc` / `off_topic_feed` |

关系类 event 以外可省略 delta 字段，只保留 `reply` + `intent` + `plot_id` + `confidence`。

### 5.2 `intent_classify`

**不要**返回 `reply`：

```json
{
  "intent": "harvest",
  "plot_id": -1,
  "confidence": 0.92,
  "refuse_kind": ""
}
```

### 5.3 `day_journal_summarize`

**不要**返回 `reply`；Godot 期望 JSON 字符串化后由 `reply_ready` 传递：

```json
{
  "chat_summary": "你提到：「今天有点累」",
  "companion_feel": "今天聊到的几句，我会慢慢记着。",
  "salience": 0.78
}
```

| 字段 | 约束 |
|------|------|
| `chat_summary` | 必填，≤120 字 |
| `companion_feel` | 可选，≤80 字 |
| `salience` | 0～1，默认 0.55 |

---

## 6. memory_context

`MemoryService.get_context_for_event()` 装配，写入 payload。

```json
{
  "week_index": 2,
  "loop_day": 1,
  "revealed": false,
  "story_mode": "stranger",
  "story_boundaries": {
    "story_mode": "stranger",
    "week_index": 2,
    "loop_day": 1,
    "recovery_tier": "…",
    "can_cite_episodic": false,
    "can_use_player_name": false,
    "forbidden_topics": ["…"]
  },
  "persona_vector": {},
  "long_term_prefs": {},
  "promise": {},
  "citable_memories": [
    {"id": "mem_001", "summary": "…", "salience": 0.8}
  ],
  "citable_prompt": "#mem_001 …\n#mem_002 …",
  "recent_memories": [],
  "recent_journal": [],
  "yesterday_journal": {},
  "pending_absence": {},
  "cited_memory_ids": []
}
```

**规则**

- W2 `story_mode=stranger`：`citable_memories` 为空，不传 episodic
- W3+ 且非 stranger：`player_chat` / `task_complete` 最多 Top-3 可引用
- LLM 引用时须把 id 写入响应 `cited_memory_ids`；客户端二次校验

---

## 7. 关系判定（affection_delta）

统一配置：`config/relationship_rules.json`（Godot `RelationshipDirector` 与 `local_llm_server.py` 共用）。

### 7.1 通用

| 玩家行为 | delta 建议 |
|----------|------------|
| 纯事务指令（「去浇水」） | 0～+1 |
| 普通聊天、关心 | +1 |
| 安慰、接纳、重新介绍自己 | +2～+3 |
| 冷漠、催促、伤人 | -1～-2 |
| 空消息 / 敷衍（「哦」「嗯」） | 0 |

### 7.2 W2 陌生化（`story_mode == "stranger"`）

- 玩家耐心说明身份 → **+2～+3**
- 玩家指责、不耐烦 → **-1～-2**
- 台词边界：不可具体共同回忆、不可亲昵、不可直呼玩家名（见 §8）

### 7.3 memory_recovery_delta

- 提到「记得」「约定」「慢慢来」「不会赶你走」等 → 0.01～0.03
- 日常闲聊 → 0

### 7.4 story_beat

- 小狸主动搭话；`affection_delta` 通常为 **0**（分数算在玩家下一句 `player_chat`）

---

## 8. 校验与降级

### 8.1 客户端（`ResponseValidator`）

| reason | 触发条件 | 降级行为 |
|--------|----------|----------|
| `stranger_ooc` | stranger 模式下命中 `stranger_ooc_phrases` | `NpcFallback` + `used_fallback=true` |
| `stranger_intimate` | 命中 `stranger_intimate_phrases` | 同上 |
| `stranger_name` | stranger 模式直呼 `player_name` | 同上 |
| `name_locked` | `can_use_player_name=false` 仍叫名 | 同上 |
| `bad_citation` | `cited_memory_ids` 不在允许集 | 同上 |
| `fact_lock` | `task_complete` 未提及任务事实 | LLM 失败提示 |
| `wrong_crop` | 提及非萝卜作物 | LLM 失败提示 |
| `metadata_leak` | reply 像 JSON 元数据 | 尝试恢复 / fallback |
| `bland_feed` / `off_topic_feed` / `duplicate_feed` | 投喂专用 | `NpcFallback.companion_feed` |

stranger 拦截词表见 `relationship_rules.json` → `stranger_ooc_phrases` / `stranger_intimate_phrases`。

### 8.2 投喂（`companion_feed`）

| 场景 | 要求 |
|------|------|
| 首次接受 | 紧扣零食口感/味道；禁打招呼、田况、行情 |
| 婉拒（`refused=true`） | 明确今天够了；禁「好好吃」等接受语气 |
| 重复 | 不得与 `previous_feed_replies` 完全相同 |

服务端 `invoke_llm()` 亦做 post-check；跑题时 `_fallback_reason=off_topic_feed`。

### 8.3 服务端 post-sanitize（`local_llm_server.py`）

| 检查 | 事件 | 降级 |
|------|------|------|
| `is_stranger_ooc_reply()` | story 事件 | `_mock_stranger_reply()` |
| `is_off_topic_feed_reply()` | `companion_feed` | `mock_reply()` |
| `sanitize_cited_memory_ids()` | `player_chat` | 剔除非法 id |

### 8.4 引用反馈（XL-C9）

校验通过后 `NpcBridge.take_cited_memory_ids(request_id)` → UI 显示 subtle 系统行「小狸好像想起了：…」（仅 API 成功且非 fallback）。

---

## 9. Godot 客户端处理

| 步骤 | 模块 |
|------|------|
| 发请求 | `NpcBridge.request_event()` |
| 意图分类 | `IntentBridge.classify_message()` → 同 URL，`event=intent_classify` |
| 解析 reply / intent | `NpcBridge._on_http_completed()` |
| 解析 delta | `NpcBridge.take_relationship_delta()` |
| 缺 delta 补算 | `RelationshipDirector.estimate_local_delta()` |
| 应用 delta | `RelationshipDirector.apply_llm_relationship_delta()` |
| 校验 | `ResponseValidator.validate()` |
| 引用 | `NpcBridge.take_cited_memory_ids()` |
| 响应元数据 | `NpcBridge.take_response_meta()` → `_source` / `_fallback_reason` |

---

## 10. 错误与降级总表

| 情况 | `used_fallback` | 用户可见 |
|------|-----------------|----------|
| API 未启用 | true | `NpcFallback` 台词 |
| HTTP / 503 失败 | false | 「……我刚才没听清…」+ `request_failed` |
| reply 为空 | false | 同上 |
| stranger / citation 校验失败 | true | stranger 专用 fallback |
| feed 校验失败 | true | 投喂 fallback |
| 其它校验失败 | false | LLM 失败提示 |
| 有 reply 但缺 delta | — | 本地补算 + 可选 warning |

---

## 11. 调试清单

1. `GET /health` → `mode=llm` 且 `has_api_key=true`
2. Godot 输出无 `NpcBridge: API 成功但未返回 affection_delta`
3. W2 stranger 聊天不出现「欢迎回来」「上次我们…」
4. 引用记忆时 UI 出现 citation 反馈行
5. 投喂第二份：`refused=true`，物品不消耗
6. **XL-C5 压测**：`py -3 tools/stress_test_npc.py` → OOC ≤15%，幻觉 ≤5%

### 11.1 压测工具（XL-C5）

```bash
py -3 tools/stress_test_npc.py              # mock，自启端口 8765
py -3 tools/stress_test_npc.py --llm        # LLM 真测
py -3 tools/stress_test_npc.py --url http://127.0.0.1:8080/v1/chat --no-spawn
```

| 指标 | 目标 | 检测项 |
|------|------|--------|
| OOC 泄漏 | ≤15% | stranger 具体回忆 / 亲昵 / 直呼名 |
| 幻觉 | ≤5% | 错误作物 / 非法引用 / 捏造已执行动作 / 任务事实锁 |

日志目录：`tools/logs/xl-c5/stress_YYYYMMDD_HHMMSS.json`

---

## 12. 版本历史

| 版本 | 变更 |
|------|------|
| v1.0 | 新增 `affection_delta` / `bond_delta` / `memory_recovery_delta` 必填（关系类 event） |
| v2.0 | 补齐 payload / memory_context / 全 event 表；`companion_feed` / `day_journal_summarize`；`npc_config` 全字段；校验层与 stranger OOC（XL-C2～C3）；引用反馈（XL-C9）；`IntentBridge` 意图分类；响应 `_source` / `_fallback_reason` |
| v2.1 | XL-C5 压测工具 `tools/stress_test_npc.py`；stranger fallback 去 OOC 词 |

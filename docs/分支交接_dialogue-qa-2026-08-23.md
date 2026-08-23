# 分支交接 · `dialogue-qa-2026-08-23`

> 给下一台电脑 / 下一个 Agent。先读本文，再读 [`docs/交接.md`](交接.md) 和策划 **§0.5**。  
> 本文只覆盖 **本分支相对 `master`（`71c4ea5`）多出来的工作**。全局铁律、地图、不要做，仍以总交接为准。

**分支日**：2026-08-23  
**远程**：`https://github.com/qiuyuey447-dev/hekesong.git`  
**分支**：`dialogue-qa-2026-08-23`  
**基线**：`master` @ `71c4ea5`（Fix ten-day playtest leaks and stranger OOC）

换电脑后请对 Agent 说：

```text
先 git checkout dialogue-qa-2026-08-23 并 git pull。
读 docs/分支交接_dialogue-qa-2026-08-23.md，再读 docs/交接.md 和策划 0.5 节。
本分支已合对话校验、剧情 QA、亲密度按内容裁判。Cloud Run 用户自己部署。
不要修 story_test_runner 那 6 个既有失败。不要把 F10 算进 True。不要重跑院子烘培。
```

---

## 1. 本分支解决了什么

从 08-22 空话 / 答非所问一路收到 08-23：指令真执行、剧情问答不误杀、亲密度不再按字数加分。

三块：

1. **对话指令 QA**（`tools/dialogue_qa.tscn`）  
   玩家口吻发令，验小狸是否真浇 / 跟 / 走开。最近一轮 **67 PASS / 0 FAIL**。
2. **十日剧情一致性 QA**（`tools/story_lore_qa.tscn`，新建）  
   D1→D10 收留线，打 Cloud Run，查叫名 / 约定 / 陌生化 / 天气 / 禁第三人 / 留下不改口浇田。  
   首轮 180 PASS / 7 FAIL（多半是校验误杀后掉空话库存）。本分支已收校验 + 就地改口 + 双端提示词。  
   **线上在用户部署 Cloud Run 之前，仍可能复现那 7 条。**
3. **亲密度按内容裁判**  
   不再按句子长短加分。`player_chat` 由云端单独跑关系裁判；回话 JSON 随口带的 `affection_delta` 作废。客户端有云端分就照收，不再用本地托底盖掉。无 API / 空话兜底才走本地内容规则。

顺手清掉已过期的十人/二十画像通关脚本和几份旧测评 markdown（逻辑已迁到上面两个 QA 场景）。

---

## 2. 改了哪些文件

| 区域 | 文件 | 做什么 |
|------|------|--------|
| 校验 | `scripts/autoload/response_validator.gd` | 问约定允许反问；请人去廊下不是她人设错位；渗漏雾口吻放行；留下说「我这就去浇」算硬卖农事；D1 昨天 / D4 复读名字 / 写错约定可 `try_rewrite` |
| 桥 | `scripts/autoload/npc_bridge.gd` | 校验失败先 salvage，再掉空话库存 |
| 兜底 | `scripts/autoload/npc_fallback.gd` | D1「今天才碰上你」；留下→住下；雨天「还在下」 |
| 亲密度 | `scripts/autoload/relationship_director.gd` | 有云端 delta 照收；本地只在无 API 时按内容估；`chat_days` 权重 0.40 |
| 规则 | `config/relationship_rules.json` + 云拷贝 | `chat_days` 0.30→0.40；节点/投喂/农事略降；十日聊天靶仍是 5 天 |
| LLM | `tools/local_llm_server.py` **和** `cloudrun/xiaoli-api/tools/local_llm_server.py` | 关系裁判、D1 禁昨天、陌生期不叫名、留下≠浇田、约定反问、渗漏雾 OK |
| 指令 | `intent_parser.gd` / `chore_*` / `companion_body_action.gd` / `main_ui.gd` | 问句不当令、跟我走、没活不说走不开 |
| QA | `tools/dialogue_qa.*`、`tools/story_lore_qa.*` | 指令 QA + 剧情 QA |
| 其它工具 | `tools/gal_playthrough_dump.*`、`tools/weather_hallucination_repro.*` | 通关转储 / 天气幻觉复现 |
| 测试 | `tools/story_test_runner.gd` | 新断言：约定反问、廊下邀请、渗漏雾、留下硬卖、内容亲密度 |
| 文档 | `docs/交接.md`、`docs/开发日志.md`、`docs/十日版任务清单.md` | 指向新 QA，删旧画像脚本引用 |

**已删除（不要再引用）**：

- `tools/persona10_infiltrate.*`、`tools/persona20_fullplay.*`
- `docs/十人画像渗透实机_2026-08-20.md`、`docs/十人画像渗透测评_2026-08-20.md`
- `docs/十日实机_2026-08-21.md`、`docs/十日实机_2026-08-21-晚.md`
- `docs/局内QA十轮_2026-08-19.md`

08-21 复测仍在：`docs/十日实机_2026-08-21-复测.md`。

---

## 3. 关键设计（不要退回去）

### 3.1 校验误杀

- `premature_promise`：P_N11 之前允许「约什么了」这类反问；仍禁止假装本子上已经写好约定。
- `action_mismatch`：「你就在廊下躲会儿」是请玩家去，不是她报自己位置。
- `literary`：渗漏 / 觉醒 / 陌生 / 收留可以说「像隔着一层」；完整记忆的 `normal` 仍禁文艺腔。
- `farm_hard_sell`：玩家在谈留下/剧情时，「我这就去浇」算硬卖。
- `promise_misquote`：把报名字写成笔记本约定，拦。

### 3.2 亲密度

- 用户明确拒绝「按字数加分」。
- 云端 `ensure_relationship_fields` + `score_relationship_with_llm`：只看意图（留下/关心/约定 vs 浇水空话）。
- 本地 fallback：暖词/关心/剧情词可加；农事上限 +1；敷衍「哦/嗯」不加。「谢谢」两字不算敷衍。
- 每日聊天亲密度上限 18。
- **未部署 Cloud Run 时，线上仍是旧计分。**

### 3.3 结局 / 碎片 / 渗漏（本分支没改规则，只写清楚）

- 策划写「四结局」；代码有 **5 个 id**。D5 赶走 → `ending_bad_early`（D6 短终章）。收留走到 D10：Bad / Normal / Happy / True。
- True 要约定靠 **两天掷骰投喂兑现**（不是收获）、夜里坐、碎片 **F01–F05 ≥ 3**、恢复/互动/聊天门槛。**F10 不算 True。**
- F01–F05 随剧情自动开（D6/D3/D8/D7/D9）；赶走线没有 F01/F05。
- 口头渗漏只在 D6–D8 的 `leak`。只用玩家原话 / 日记 / 约定 / 锚，用过就消耗。入口：D6 信纸 `leak_context`、主动闲聊、投喂 déjà vu、react。D6 信纸摘句 **不消耗** 口头渗漏配额。

---

## 4. 怎么跑

本机 Godot 4.7（当前会话用过 `D:\Godot_v4.7.1-stable_win64_console.exe`）。**不要杀编辑器进程**；QA 卡住只杀残留的 `Godot*console*`。

```text
godot --headless --path <项目根> res://tools/dialogue_qa.tscn
godot --headless --path <项目根> res://tools/story_lore_qa.tscn
godot --headless --path <项目根> res://tools/story_test_runner.tscn
```

| 套件 | 期望 |
|------|------|
| `dialogue_qa` | 应全绿。退出可能挂住，杀 console 即可 |
| `story_lore_qa` | 部署云端前可能再出现空话 / 答非所问。部署后再跑 |
| `story_test_runner` | **不要要求全绿。** 下面 6 条既有失败不要修 |

1. act2 tease after D4 dark line  
2. act2 mutual_forgetting  
3. N16 echoes promise  
4. chat sets chat_promise id  
5. chat promise uses player words  
6. D7 night resumes choice tail  

剧情 QA 会打 Cloud Run，耗时长。用户说「跑 QA」没点名时：lore QA 是最近在写的那套；指令 QA 上一轮已绿。

---

## 5. 还没做 / 用户自己做

1. **重新部署 Cloud Run**（`deploy_cloudrun.bat`）。双端 `local_llm_server.py` 已同步，**云上没部署 = 线上旧提示词 + 旧亲密度**。
2. **T10-M5 / T10-F**：F5 收留通关、赶走短终章、Win/Web 导出、对外文案去 35 日。不要把这些算进本分支已完成。
3. **T10-C6** 三档亲密度仍须手测（warm / mid ~35–50 / cold）。
4. Godot MCP（`user-godot`，端口 6505–6506）本机曾 `ECONNREFUSED`。场景树 / 运行时 MCP 不可用时，用 headless Godot，不要拿 `_console.exe` 当编辑器。

---

## 6. 不要做

- 不要把本分支强推到 `master`，除非用户明确说合并。
- 不要提交 `.godot/`、`build/`、`.env`、真实 API Key、`user://` 存档。
- 不要把 F10 算进 True。
- 不要修那 6 个既有 `story_test_runner` 失败。
- 不要重跑 `yard_bake` / `FarmSetdress.apply()`。院子是静态场景。
- 不要再恢复 `persona10_infiltrate` / `persona20_fullplay`。
- 不要按字数给亲密度。
- 不要在未要求时再改 D6 信纸结构或结局翻转条件。
- 改 LLM 必须双端同步，并提醒用户部署云。

---

## 7. 下一优先

用户只说「继续」时：推进 **T10-M5 / T10-F**（F5 通关、Win/Web、对外文案），遵守总交接「不要做」。

本分支若还要收口：用户部署 Cloud Run 之后，再跑一遍 `story_lore_qa.tscn`，把部署后仍红的剧情问答收掉。

2026-08-23 傍晚补丁（尚未单独再推）：「我还有多少钱」本地先报金币，不再被田况盖掉；删掉「有什么不想忘掉的，跟我说一声。我写进去。」

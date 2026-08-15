# Agent 须知

开始任何工作前，**先读**：

1. [`docs/交接.md`](docs/交接.md) — 进度、铁律、地图约束、下一优先
2. [`docs/十日版策划定稿.md`](docs/十日版策划定稿.md) 第 **0.5** 节 — 叙事最高优先
3. [`docs/十日版任务清单.md`](docs/十日版任务清单.md) — 只做清单内未完成项

用户换电脑后若只说「继续」，默认推进 **T10-C3～C8 → T10-E → T10-F**，并遵守交接文档里的「不要做」。

**剧情搭话**：凡与当日叙事相关的主动开口须走 LLM，且带齐 `beat_context`（见交接铁律 §2-7、策划 §4.5.5）；改变体须双端同步 `local_llm_server.py`。

院子摆设是运行时生成（`scripts/world/farm_setdress.gd`）。用 F5 验收，不要只看 `scenes/farm_map.tscn`。

# itch.io 网页托管指南 · 《去狸的岛》

## 一、准备（一次性）

1. 注册 [itch.io](https://itch.io) 账号
2. Godot：**编辑器 → 管理导出模板** → 下载 **Web** 模板
3. 本项目已含 `export_presets.cfg`，预设路径：`build/web/index.html`

## 二、导出 Web 版

1. Godot 打开 `project.godot`
2. **项目 → 导出** → 选 **Web**
3. 点击 **导出项目** → 输出到 `build/web/index.html`
4. 或双击 `deploy_web.bat`（需改本机 Godot 路径）
5. 打包 zip（PowerShell）：

```powershell
cd E:\hekesong
powershell -ExecutionPolicy Bypass -File tools\package_itch.ps1
```

得到：`export/hekesong-itch.zip`

## 三、上传到 itch.io

1. 登录 itch → **Create new project**
2. **Title**：`去狸的岛`（或 `去狸的岛 · 十日完整故事`）
3. **Kind of project**：`HTML`
4. **Short description / Pitch**：

> 十天里，一只会忘事的狐狸试图记住你——而你会发现，需要被反复认回的也不只是她。

5. **Uploads** → 上传 `export/hekesong-itch.zip`
6. 勾选：**This file will be played in the browser**
7. **Embed options**（建议）：
   - Viewport dimensions：`1280 x 720` 或 `1920 x 1080`
   - 勾选 **Fullscreen button**
8. **Save & view page** → 例如 `https://你的用户名.itch.io/qu-lai-de-dao`

## 四、FAQ（建议写进 itch 页说明）

- **这是完整游戏吗？** 是，十日完整故事，可通关多结局。不是 Demo、不是序章。
- **第四天小狸不认识我了，存档坏了吗？** 不是。这是她的失忆设定；本子上的名字和约定还在。
- **必须联网吗？** 不必须。断网可走固定剧本通关；联网时小狸对话更活。
- **存档在哪？** 每人、每浏览器各自一份（浏览器本地）。换浏览器 / 清缓存 = 新档。

## 五、AI 小狸（可选）

itch **只托管静态网页**，不能跑你电脑上的 `127.0.0.1`。

| 模式 | 做法 |
|------|------|
| **演示够用** | `config/npc_config.json` 里 `enabled: false`，走 fallback 台词 |
| **真 LLM** | 部署 `cloudrun/xiaoli-api` 到 CloudBase Cloud Run，导出前确认 `api_url` 指向公网 |

默认云地址（仓库内 `config/npc_config.json`）：

`https://xiaoli-api-288258-10-1457975289.sh.run.tcloudbase.com/v1/chat`

部署 API 后重新导出 Web 再上传 itch。

> 勿把私人 API Key 写进 Web 导出包；Key 应只放在服务器环境变量里。

## 六、发布检查清单

- [ ] Web 导出无报错
- [ ] itch 页能加载，能点田、聊天
- [ ] 跨天后存档仍在（同浏览器刷新）
- [ ] D4 陌生化能触发；玩家问「存档坏了」应走失忆口径
- [ ] 标题 / 关于 / 致谢均为「去狸的岛」，无「五周 / 35 日 / Demo」话术
- [ ] 若用 API：浏览器 F12 无 CORS 报错

## 七、更新版本

改代码 → Godot 重新导出 Web → 重新 `package_itch.ps1` → itch 上传新 zip 覆盖。

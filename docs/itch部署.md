# itch.io 网页托管指南

## 一、准备（一次性）

1. 注册 [itch.io](https://itch.io) 账号
2. Godot：**编辑器 → 管理导出模板** → 下载 **Web** 模板
3. 本项目已含 `export_presets.cfg`，预设路径：`export/web/index.html`

## 二、导出 Web 版

1. Godot 打开 `project.godot`
2. **项目 → 导出** → 选 **Web**
3. 点击 **导出项目** → 输出到 `export/web/index.html`
4. 打包 zip（PowerShell）：

```powershell
cd E:\hekesong
powershell -ExecutionPolicy Bypass -File tools\package_itch.ps1
```

得到：`export/hekesong-itch.zip`

## 三、上传到 itch.io

1. 登录 itch → **Create new project**
2. **Kind of project**：`HTML`
3. **Uploads** → 上传 `hekesong-itch.zip`
4. 勾选：**This file will be played in the browser**
5. **Embed options**（建议）：
   - Viewport dimensions：`1280 x 720` 或 `1920 x 1080`
   - 勾选 **Fullscreen button**
6. **Save & view page** → 得到链接，例如：  
   `https://你的用户名.itch.io/hekesong`

## 四、存档说明（发给玩家）

- 每人、每浏览器 **各自一份存档**（存在浏览器本地）
- 换浏览器 / 清缓存 = 新档
- 玩法不同 → 小狸记忆不同（千人千面）

## 五、AI 小狸（可选）

itch **只托管静态网页**，不能跑你电脑上的 `127.0.0.1`。

| 模式 | 做法 |
|------|------|
| **演示够用** | 保持 `config/npc_config.json` 里 `enabled: false`，走 fallback 台词 |
| **真 LLM** | 把 `tools/local_llm_server.py` 部署到公网（Railway / Render 等），导出前把 `api_url` 改成 `https://你的域名/v1/chat` |

本地服务已支持 **CORS**，可供 Web 版跨域调用。

部署 API 后，在 `res://config/npc_config.json` 中：

```json
{
  "enabled": true,
  "api_url": "https://你的-api.railway.app/v1/chat",
  "api_key": "公开演示用密钥或留空"
}
```

然后 **重新导出 Web** 再上传 itch。

> 勿把私人 DeepSeek Key 写进 Web 导出包；Key 应只放在服务器环境变量里。

## 六、发布检查清单

- [ ] Web 导出无报错
- [ ] itch 页能加载，能点田、聊天
- [ ] 跨天后存档仍在（同浏览器刷新）
- [ ] 第 8 天 W2 陌生化能触发（可选）
- [ ] 若用 API：浏览器 F12 无 CORS 报错

## 七、更新版本

改代码 → Godot 重新导出 Web → 重新 `package_itch.ps1` → itch 上传新 zip 覆盖。

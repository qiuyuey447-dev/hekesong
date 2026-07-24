# 河可松 · 星露谷风格 Demo

Godot 4.7 · **正交俯视角像素 tile** + Y 轴排序 + 派活 + 聊天。

> 风格参考：星露谷物语 — 正方形地块、俯视角、像素小人，**不是**等距菱形。

## 打开

1. Godot → 导入 `E:\hekesong\project.godot`
2. 打开 `scenes/main.tscn` → **F5**

## 画面

- **32×32 像素 tile**（草地 / 泥土 / 湿润土 / 木地板 / 小路 / 围栏）
- **TileMap** 铺地图
- **像素小狸**（略 3/4 俯视，类似星露谷角色）
- **Y 轴排序**：角色与物体按脚下 Y 值遮挡
- 相机 **1.75×** 放大，更接近像素游戏的观感

## 操作

| 操作 | 效果 |
|------|------|
| 点左上农田 | 浇水 |
| 点右侧「出门」 | 采集 |
| 点小狸 | 聊天 |
| 下一天 | 跨天 |

## 结构

```text
scripts/world/
  tile_factory.gd    # 程序化像素贴图
  stardew_world.gd   # TileMap + 物体布局
```

## 换美术

1. 准备 tileset PNG（32×32 一格，Nearest 过滤）
2. 替换 `TileFactory` 或直接在 TileMap 里换 TileSet
3. 小狸换成 sprite sheet（idle 动画）

## 下一步

- 接 GameNPC
- 换真实像素 asset（itch.io: "stardew like tileset"）

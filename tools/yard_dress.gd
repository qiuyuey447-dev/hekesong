extends Node
## 一次性工具：按「又一次归来」的设计方案重摆院子，结果存回 scenes/farm_map.tscn。
## 跑完院子就是静态场景，之后想微调直接在编辑器里拖，别再跑这个脚本。

const FARM_MAP_PATH := "res://scenes/farm_map.tscn"

const GRASS_SRC := 0
const GRASS_TILE := Vector2i(21, 25)
const GRASS_LAYER := "草地"
const DETAIL_LAYER := "地面细节"
# 只留绿的三个。(22,4) 和 (23,4) 是暗红褐色的菇/枯堆 —— 撒在草地上读成一片污渍，
# 也是上一版幽灵垄看着脏的原因。旧田要的褐色由 RidgeMud* 那几张泥贴图给，不靠这两个。
const TUFTS: Array[Vector2i] = [
	Vector2i(17, 2), Vector2i(19, 4), Vector2i(20, 4),
]
# 上一版撒过的红褐瓦片，重跑时要认得出来才好擦掉
const TUFTS_LEGACY: Array[Vector2i] = [Vector2i(22, 4), Vector2i(23, 4)]

# 当年生成器用 terrain 0 刷「草地」，可那个 terrain 叫 grass_1_to_dirt_1，中心块是米色土，
# 于是院子南半边被刷成一大块沙地。这里把 YARD_CLEAR + PLAZA_CLEAR 范围内所有
# terrain 0 的格子换回普通草块；terrain 1（门前泥地）和 terrain 2（石板路）不动。
const REPAIR_RECT := Rect2i(22, 7, 24, 28)
const TERRAIN_SET_GROUND := 0
const TERRAIN_BEIGE := 0

# 中间那片旧大方田是运行时才清的，烘进场景省得编辑器里看到的和游戏里不一样。
const FIELD_CLEAR_RECT := Rect2i(31, 21, 9, 12)
const FIELD_EXTRA_XS: Array[int] = [54, 56]

const FIELD_LAYER := "田"
const HOME_LAYER := "河流树木家园"

# 围栏里原本是「土垄 46/48/50/52/54/56 + 垄间草 47/49/51/53/55」交替的六垄。
# 后来 52/54/56 的土被删掉（怕玩家以为能种），53/55 的垄间草就孤零零留着没了来由。
# 这里把 53/55 擦掉，并在 52 铺回一条**三格高**的裸土 —— 那就是「空土垄」：
# 策划里 Bad 线的核心意象（小狸不跟你说话，转身去浇那条没种东西的土垄）。
# 故意只做三格、和六格的三垄不对齐，读成「更早、更短的一条」，不像第四块可种田。
# 地图底边原本只到 y=33，可 x22..44 在 y=34 多铺了一行普通草块，于是中段凸出一行、
# 还缺了草穗收边瓦片，远看像块方板子伸进水里。擦掉那行、把 y=33 换成收边瓦片 (21,26)。
# 副作用是好的：相机下边界跟着草地 used_rect 从 1120 收到 1088，不再露出边外的空白。
const BOTTOM_TAB_XS := Vector2i(22, 44)
const BOTTOM_TAB_Y := 34
const BOTTOM_EDGE_Y := 33
const GRASS_EDGE_TILE := Vector2i(21, 26)

const EMPTY_RIDGE_X := 52
const EMPTY_RIDGE_TILES := {23: Vector2i(14, 59), 24: Vector2i(14, 60), 25: Vector2i(14, 61)}
const ORPHAN_BAND_XS: Array[int] = [53, 55]
const ORPHAN_BAND_YS := Vector2i(21, 26)

# 「上一轮的旧田」：三行连成线的杂草，读成塌掉、被草长回去的垄。
# 只铺草簇不铺土 —— 一旦铺成褐色土垄，就等于把当年特意删掉的「中间那片田」
# 又画回来了，玩家会以为那儿能种（铁律：可种田只有右边围栏三垄）。
# 三行**两端对齐**在 30 和 39，只在行内留缺口 —— 人辨认「田」靠的是外框和垄的端点，
# 不是垄的中段；上一版端点参差不齐，所以只读成随机杂草。
const GHOST_ROWS := {
	24: [30, 31, 32, 33, 35, 36, 37, 38, 39],
	26: [30, 31, 33, 34, 35, 36, 38, 39],
	28: [30, 31, 32, 34, 35, 36, 37, 39],
}
# 垄两端的标记改用 Sprite（见 LAYOUT 的 RidgeMark*）。
# 上一版这里画的是瓦片 (44,6)，当时以为是断篱桩，其实图集列 44 的第 3/6/9/12 行
# 是同一个小植物的四种配色，(44,6) 是红粉色 —— 三根「桩」其实是三片红粉叶子。
# 旧桩不用单独清：GHOST_CLEAR 每次整块擦这一层，跑一遍就没了。
# 重跑前要先擦掉的旧草簇范围，免得改了行号还留着上一版
const GHOST_CLEAR := Rect2i(29, 22, 12, 8)

# 大片纯色草地是「太丑」里最实在的一条：开阔处是一整片单一瓦片、零变化，
# 远看就是一块绿板子。这里在草坪上撒几处草簇给地面加质感。
# 三重护栏（草地层是纯草 + 细节层为空 + 树木层和沙地层都为空）挡住路面、水面和
# 底图已有装饰，所以只会落在真正的空草坪上，不会把底图擦坏。
# 目标是让草坪一成半左右的格子带上草簇、且集中成片 —— 铺满会变吵，比纯色更难看。
# [中心x, 中心y, 半径x, 半径y, 中心密度千分比]。椭圆边缘密度递减，才成团不成块。
const MEADOW_BLOBS := [
	# 这三处原来是 [8,7]、[8,13]、[16,14]：新屋盖住了第一处，主街和屋前支路盖住了后两处。
	# 三重护栏会把它们整团挡掉（路面瓦片 != 纯草块），等于白摆，所以挪到旁边真正空的草坪上。
	[4, 19, 5, 3, 800], [16, 19, 5, 4, 820], [24, 10, 4, 3, 780],
	[16, 5, 4, 3, 780], [28, 8, 4, 3, 760], [38, 6, 4, 3, 780],
	[52, 8, 4, 3, 800], [44, 12, 4, 3, 760], [40, 4, 4, 3, 800],
	[20, 9, 4, 3, 780], [50, 24, 4, 3, 780],
	[6, 30, 5, 3, 820], [14, 30, 6, 4, 840], [22, 27, 4, 3, 780],
	[24, 32, 5, 2, 800], [34, 32, 5, 2, 780], [45, 31, 4, 2, 760],
]
const SAND_LAYER := "沙地"

# ————— 主路重修 —————
# 要求是「家→商店→农田→廊下 互通、路偏宽、不要错综复杂」。量完坐标发现根本不用岔道网：
# 商店摊位底边在 world 388、廊下木地顶边在 572，一北一南正好夹住 world y 416~544 这条带。
# 所以主街就走这一条，商店直接开在路北、廊下直接开在路南，只留一条支路拐上西北角的新家。
#
# 旧路网画在**草地层**里（不是河流树木家园层，这点我一开始找错了层）：一大团盘绕的石板
# 迷宫 cells x24~48 / y10~22，外加 x24、x34、x48、row10、row22 那几条一格宽的细岔道。
# 草地层上凡是 atlas_x <= 11 的格子都属于这套路面/土路自动拼接块，纯草块和四周收边瓦片
# 全在 20~22 列 —— 所以「先把 atlas_x<=11 全刷回草块，再画新路」既清得干净，重跑也幂等。
const ROAD_ATLAS_MAX_X := 11
const TERRAIN_ROAD := 2
# 凹角（丁字口内侧）手摆九宫格表达不出来，图集第 4~7 列那几张就是干这个的。
# 别自己算，交给 set_cells_terrain_connect —— 底图那团迷宫当年也是这么刷出来的。
const ROAD_RECTS: Array[Rect2i] = [
	Rect2i(7, 13, 43, 4),   # 主街 world x 224~1600 / y 416~544，四格宽
	Rect2i(7, 9, 4, 4),     # 屋前支路：最上两行藏在房子贴图底下，路口才不露收尾盖
	Rect2i(50, 16, 4, 3),   # 田口落脚坪 —— 原来是块 (20..22,24..26) 硬直角草台
	Rect2i(51, 19, 2, 2),   # 穿过田北围栏 x51~52 那个缺口进田
]

# 新屋落到西北角后，原先散在这一带的底图杂物正好压在屋子、门前路和主街上：硬直角深绿
# 灌木方块 (68..70,22..24)、三个蓝陶罐 (106,27..28)、两根杆子 (108,23..24)、告示牌
# (100..101,26..27)、格子石板庭院 (4,38) 连收边，还有两条断头石板路 (26..28,24..26)。
# 用户说这片「太杂乱」，所以整片清掉，绿化改由 西院 组的树丛重新做。
const HOME_CLEAR_RECTS: Array[Rect2i] = [
	Rect2i(7, 6, 2, 5),     # 旧竖石板断头路 —— 正好在新屋底下
	Rect2i(4, 11, 3, 5),    # 灌木方块 + 告示牌 + 西边那根杆子
	Rect2i(9, 10, 3, 2),    # 三个蓝陶罐（压在门前路上）
	Rect2i(11, 14, 1, 2),   # 东边那根杆子
	Rect2i(12, 10, 5, 6),   # 格子石板庭院及其收边瓦片
	Rect2i(10, 7, 1, 1),
	Rect2i(10, 16, 1, 1),
	Rect2i(12, 16, 2, 3),   # 旧 L 形石板路竖臂
	Rect2i(12, 19, 10, 2),  # 旧 L 形石板路横臂
	# (12..13,57..58) 那块 2×2 亮绿草台，正贴在主街北肩上。它比周围草地亮一截又是方的，
	# 旧路乱的时候混在杂物里看不出来，路一收拾干净就成了全图最显眼的补丁。
	Rect2i(17, 11, 2, 2),
	# 商店东边那片底图砾石院子（cells 45~51 / rows 9~10，西南角还有口井）留着 —— 它紧邻
	# 商店，读成「商店的院子」很合理。但它有条砾石尾巴往南伸到 row 14 就停，而落脚坪从
	# row 16 起：中间 row 15 空一格草，两片石头差一格没接上，是最难看的那种接缝。
	# 尾巴不通向家/商店/田/廊下里的任何一处，属于该砍的岔道，清掉；井和院子不动。
	Rect2i(51, 11, 2, 4),
]

# 老屋搬到西北角。三处必须同步改，缺一处就不一致：
#   这里的 Sprite 位置、场景里的「人」标记（farm_world._player_spawn_position 直接读它
#   当出生点）、以及 farm_setdress.gd 的 POS_HOME 常量 —— companion_agent.gd 建 POI
#   时读的是那个常量而不是标记点，只改标记点小狸眼里的「家」会留在原地。
# 贴图 76×48、scale 3、offset (-38,-42)，所以占 world x 158~386 / y 178~322；
# 「人」仍旧等于贴图位置（屋基上方 18px），出生点的观感和搬家前一致。
const HOUSE_POS := Vector2(272, 304)

# 旧的均匀散布装饰整组拿掉：镜像对（L/R）、平均撒开的花、没来由的石头。
const DROP_NODES: Array[String] = [
	"HousePotL", "HousePotR", "HouseBushW",
	"PorchBushL", "PorchBushR",
	"FieldPot", "FieldBushW", "FieldBarrel", "FieldHay",
	"PathTreeA", "PathBushA", "PathBushB", "PathRockA",
	"YardFill", "YardEdge",
]

const T := "res://Props/"

# 三条硬规矩（第二轮「太丑」返工定下来的）：
#
# 1. **缩放必须是整数**。地面各层是 scale 2，一个源像素正好占 2 个屏幕像素。摆设一旦用
#    2.2 / 2.6 / 3.2 这种非整数，nearest 过滤下同一张贴图里有的源像素占 2 px、有的占 3 px，
#    边缘就是不齐的，整个场景发糊、显廉价。所以这里只允许 1 / 2 / 3，大件用 3 当「近景」。
# 2. **坐标必须是偶数**，这样摆设的像素格和地面的 2px 像素格对得上，不会半像素发虚。
# 3. **不许孤件**。一个桶、一块石、一丛草各自摊在草地上是最容易露馅的摆法；
#    每处至少 2~4 件互相压着、脚位前后错开 8~16px，才读成「有人在这儿活动过」。
#
# [组名, 节点名, 贴图, x, y, 缩放, z]
const LAYOUT := [
	# —— 屋前：房子已挪到西北角（world x 158~386 / y 178~322），门前支路占 x 224~352。
	# 两堆分列路的东西两侧，脚位都压在屋基（y=322）以南，才会 y-sort 到房子前面；不占路心。
	# 东西两侧仍用不同贴图、y 也错开，别成「同一张贴图左右对称各一株」。——
	["屋前", "HouseLogA", "Rocks/Sprites/rock_03.png", 186, 348, 2, 0],
	["屋前", "HouseLogB", "Rocks/Sprites/rock_02.png", 208, 358, 2, 0],
	["屋前", "HouseBushW", "Trees/Sprites/tree_03.png", 166, 366, 2, 0],
	# 东侧这组要**贴着门**（x 346~444）。原来摊到 444，和路北肩那丛口袋树（横跨 404~536）
	# 咬在一起：花盆整个被树冠吃掉，门口还挤成一堵植被墙 —— 用户要的正相反。
	["屋前", "HouseBarrel", "Barrels/Sprites/barrel_02.png", 362, 342, 2, 0],
	["屋前", "HousePotA", "Potted plants/Sprites/potted_plant_06.png", 384, 352, 2, 0],
	["屋前", "HousePotB", "Potted plants/Sprites/potted_plant_01.png", 402, 362, 2, 0],
	["屋前", "HouseBushE", "Trees/Sprites/tree_01.png", 424, 338, 2, 0],
	# 屋后两株：脚位故意埋在屋子贴图里（y-sort 会把它们排到房子后面），树冠从屋脊上探出来，
	# 房子才不像一张贴图糊在空草地上。
	["屋前", "HouseBackTreeW", "Trees/Sprites/tree_02.png", 196, 200, 2, 0],
	["屋前", "HouseBackTreeE", "Trees/Sprites/tree_13.png", 352, 206, 2, 0],

	# —— 廊下：全院唯一有顶的地方，四周留空，只在边沿堆生活痕迹 ——
	["廊下", "PorchLogPile", "Rocks/Sprites/rock_03.png", 890, 672, 2, 0],
	["廊下", "PorchHay", "Generated/hay.png", 872, 702, 1, 0],
	["廊下", "PorchWaterBarrel", "Barrels/Sprites/barrel_04.png", 1192, 660, 2, 0],
	["廊下", "MyNotebook", "Books/Sprites/book_03.png", 1130, 640, 2, 0],
	["廊下", "PorchPuddle", "Generated/mud.png", 1004, 700, 1, -1],
	["廊下", "PorchTuft", "Trees/Sprites/tree_01.png", 1216, 684, 2, 0],

	# —— 情绪落点：唯一一株粉樱。配一块坐石和一丛草，读成「一个能待的地方」，
	# 而不是草地上插了一棵树。——
	# 粉樱是全院唯一的高饱和色，所以旁边这株从原来的柠檬绿 tree_31 换成深绿，别抢它。
	# 整组北移：原来那几件（y 462~480）正好落在新主街的路心上。老屋搬走后，
	# world x 700~950 / y 350~400 这块空出来，既是院子新的几何中心，也需要填。
	["院心", "CherryTree", "Trees/Sprites/tree_32.png", 856, 372, 3, 0],
	["院心", "CherryStone", "Rocks/Sprites/rock_20.png", 888, 380, 2, 0],
	["院心", "CherryBush", "Trees/Sprites/tree_01.png", 822, 382, 2, 0],
	["院心", "YardTree2", "Trees/Sprites/tree_13.png", 700, 366, 2, 0],
	["院心", "YardTree2b", "Trees/Sprites/tree_01.png", 730, 356, 2, 0],

	# —— 树洞：小狸的家。界碑 + 两块苔石 ——
	["树洞", "HollowMarker", "Rocks/Sprites/rock_09.png", 1148, 600, 2, 0],
	["树洞", "HollowMoss", "Rocks/Sprites/rock_31.png", 1248, 596, 2, 0],
	["树洞", "HollowMoss2", "Rocks/Sprites/rock_28.png", 1268, 606, 2, 0],

	# —— 旧田：上一轮的痕迹。倒木堆、丢下的水桶配界石、一小一大两株长回来的树 ——
	["旧田", "RidgeLog", "Rocks/Sprites/rock_03.png", 976, 796, 3, 0],
	["旧田", "RidgeMossSmall", "Rocks/Sprites/rock_28.png", 1008, 806, 2, 0],
	["旧田", "RidgeBucket", "Barrels/Sprites/barrel_02.png", 1080, 756, 2, 0],
	["旧田", "RidgeStone", "Rocks/Sprites/rock_09.png", 1104, 766, 2, 0],
	["旧田", "RidgeMossBig", "Rocks/Sprites/rock_25.png", 1272, 804, 2, 0],
	["旧田", "RidgeSapling", "Trees/Sprites/tree_05.png", 1004, 848, 2, 0],
	["旧田", "RidgeGrown", "Trees/Sprites/tree_13.png", 932, 872, 3, 0],
	["旧田", "RidgeGrownB", "Trees/Sprites/tree_01.png", 964, 882, 2, 0],
	# 垄线上零星露出来的泥，让三条草线读成「垄」而不是随机杂草
	["旧田", "RidgeMud1", "Generated/mud.png", 1000, 792, 1, -1],
	["旧田", "RidgeMud2", "Generated/mud.png", 1128, 792, 1, -1],
	["旧田", "RidgeMud3", "Generated/mud.png", 1224, 792, 1, -1],
	["旧田", "RidgeMud4", "Generated/mud.png", 1064, 856, 1, -1],
	["旧田", "RidgeMud5", "Generated/mud.png", 1192, 856, 1, -1],
	["旧田", "RidgeMud6", "Generated/mud.png", 1256, 856, 1, -1],
	["旧田", "RidgeMud7", "Generated/mud.png", 1032, 920, 1, -1],
	["旧田", "RidgeMud8", "Generated/mud.png", 1160, 920, 1, -1],
	# 三条垄的两端各压一块界石。人辨认「这里曾是一块田」靠外框和垄端，不靠垄的中段。
	["旧田", "RidgeMarkW1", "Rocks/Sprites/rock_09.png", 944, 798, 2, 0],
	["旧田", "RidgeMarkW2", "Rocks/Sprites/rock_09.png", 944, 926, 2, 0],
	["旧田", "RidgeMarkE", "Rocks/Sprites/rock_28.png", 1296, 862, 2, 0],

	# —— 南面草甸：上一版是 18 株等距单排、且深绿/柠檬绿/蓝三个色系混着摆，
	# 既像一排棒棒糖又花。现在两条规矩：
	#   构图 —— 8 处不规则树丛，每丛 1 大（scale 3）压 2 小（scale 2），丛内间距只 30~40px
	#           让树冠大幅重叠成一团，丛间拉到 160~200px；1012~1180 留一处豁口透气。
	#   配色 —— 主色只用深绿家族（01/02/03/13）；蓝只出现在最西边两丛，跟原有的西南蓝绿林接上；
	#           柠檬绿全院只留 ClumpD2 一株当高光。每丛的「大株」轮换 13/02 换剪影，别一个形状重复八次。
	["草甸", "ClumpA1", "Trees/Sprites/tree_11.png", 400, 1032, 3, 0],
	["草甸", "ClumpA2", "Trees/Sprites/tree_01.png", 436, 1050, 2, 0],
	["草甸", "ClumpA3", "Trees/Sprites/tree_12.png", 366, 1052, 2, 0],
	["草甸", "ClumpB1", "Trees/Sprites/tree_13.png", 560, 1046, 3, 0],
	["草甸", "ClumpB2", "Trees/Sprites/tree_01.png", 596, 1024, 2, 0],
	["草甸", "ClumpB3", "Trees/Sprites/tree_11.png", 528, 1056, 2, 0],
	["草甸", "ClumpC1", "Trees/Sprites/tree_02.png", 740, 1040, 3, 0],
	["草甸", "ClumpC2", "Trees/Sprites/tree_03.png", 704, 1056, 2, 0],
	["草甸", "ClumpC3", "Trees/Sprites/tree_01.png", 776, 1022, 2, 0],
	["草甸", "ClumpD1", "Trees/Sprites/tree_13.png", 920, 1050, 3, 0],
	["草甸", "ClumpD2", "Trees/Sprites/tree_31.png", 884, 1028, 2, 0],
	["草甸", "ClumpD3", "Trees/Sprites/tree_01.png", 956, 1058, 2, 0],
	# 豁口：1012 ~ 1180 之间不放树
	["草甸", "ClumpE1", "Trees/Sprites/tree_02.png", 1200, 1042, 3, 0],
	["草甸", "ClumpE2", "Trees/Sprites/tree_03.png", 1164, 1058, 2, 0],
	["草甸", "ClumpE3", "Trees/Sprites/tree_01.png", 1238, 1024, 2, 0],
	["草甸", "ClumpF1", "Trees/Sprites/tree_13.png", 1400, 1046, 3, 0],
	["草甸", "ClumpF2", "Trees/Sprites/tree_01.png", 1364, 1026, 2, 0],
	["草甸", "ClumpF3", "Trees/Sprites/tree_03.png", 1436, 1056, 2, 0],
	["草甸", "ClumpG1", "Trees/Sprites/tree_02.png", 1600, 1044, 3, 0],
	["草甸", "ClumpG2", "Trees/Sprites/tree_13.png", 1564, 1058, 2, 0],
	["草甸", "ClumpG3", "Trees/Sprites/tree_01.png", 1636, 1024, 2, 0],
	["草甸", "ClumpH1", "Trees/Sprites/tree_13.png", 1760, 1048, 3, 0],
	["草甸", "ClumpH2", "Trees/Sprites/tree_03.png", 1724, 1058, 2, 0],
	# 中景几处小丛，把大树和院子之间的空洞打断（不铺满，留呼吸）
	["草甸", "MidWest1", "Trees/Sprites/tree_01.png", 520, 936, 2, 0],
	["草甸", "MidWest2", "Rocks/Sprites/rock_28.png", 548, 944, 2, 0],
	# 西南本来就是一丛蓝绿针叶，这株跟着用蓝，别插一株柠檬绿进去打断色调
	["草甸", "MeadowTreeD", "Trees/Sprites/tree_11.png", 760, 900, 2, 0],
	["草甸", "MeadowBushB", "Trees/Sprites/tree_01.png", 786, 910, 2, 0],
	["草甸", "MeadowLog", "Rocks/Sprites/rock_02.png", 1084, 908, 2, 0],
	["草甸", "MeadowMoss", "Rocks/Sprites/rock_31.png", 1112, 916, 2, 0],
	["草甸", "MeadowBushA", "Trees/Sprites/tree_02.png", 1244, 944, 2, 0],
	["草甸", "MeadowMossE", "Rocks/Sprites/rock_28.png", 1270, 952, 2, 0],
	["草甸", "MidEast1", "Trees/Sprites/tree_01.png", 1520, 948, 2, 0],
	["草甸", "MidEast2", "Rocks/Sprites/rock_28.png", 1548, 956, 2, 0],

	# —— 塘边：水塘四角是硬直角、岸上一件收边植被都没有。
	# 不去重切水形（风险大），改成在四角和岸线压成组植被，直角就读不出来了。——
	["塘边", "PondNW1", "Trees/Sprites/tree_02.png", 120, 668, 2, 0],
	["塘边", "PondNW2", "Trees/Sprites/tree_01.png", 148, 676, 2, 0],
	["塘边", "PondNE1", "Rocks/Sprites/rock_28.png", 318, 668, 2, 0],
	["塘边", "PondNE2", "Trees/Sprites/tree_01.png", 344, 678, 2, 0],
	["塘边", "PondE", "Trees/Sprites/tree_01.png", 368, 736, 2, 0],
	["塘边", "PondSE", "Trees/Sprites/tree_02.png", 372, 856, 2, 0],
	["塘边", "PondS1", "Rocks/Sprites/rock_31.png", 200, 920, 2, 0],
	["塘边", "PondS2", "Trees/Sprites/tree_01.png", 228, 928, 2, 0],

	# —— 田东：擦掉孤立草带后留出的空处，堆点旧料 ——
	["田东", "FieldHayPile", "Generated/hay.png", 1730, 790, 1, 0],
	["田东", "FieldBucket", "Barrels/Sprites/barrel_02.png", 1760, 798, 2, 0],

	# —— 路边与田边：只贴路缘，不占路心。同样两两成组 ——
	# 这四件原来贴着旧路缘（y 428~460），新主街占了 y 416~544，正好压在路心上，所以整组挪：
	# 前两件去老屋空地和商店之间那段空白（路北），后两件贴到商店摊位西侧的门前空带。
	["路边", "PathRock", "Rocks/Sprites/rock_20.png", 1010, 396, 2, 0],
	["路边", "PathRockB", "Rocks/Sprites/rock_28.png", 1032, 404, 2, 0],
	["路边", "ShopFlower", "Potted plants/Sprites/potted_plant_08.png", 1290, 402, 2, 0],
	["路边", "ShopTuft", "Trees/Sprites/tree_01.png", 1268, 410, 2, 0],
	["路边", "PathTuft", "Trees/Sprites/tree_01.png", 1196, 664, 2, 0],
	["路边", "FieldPot", "Potted plants/Sprites/potted_plant_06.png", 1444, 676, 2, 0],
	["路边", "FieldHay", "Generated/hay.png", 1456, 702, 1, 0],
	["路边", "FieldBush", "Trees/Sprites/tree_02.png", 1436, 764, 2, 0],
	["路边", "FieldBushB", "Trees/Sprites/tree_01.png", 1462, 772, 2, 0],

	# —— 廊下到田之间原本空一大块，补一丛把动线两侧填起来 ——
	# 脚位必须压到 y≥676：树按脚底对齐画，tree_13 放大 3 倍树冠有 132px 高，
	# 脚放在原来的 592 树冠就顶到 y 460，整丛盖在主街（y 416~544）路面上，
	# 看着像树从石板缝里长出来，还把刚拓宽的路又挡窄回去。
	["路边", "GapTreeA", "Trees/Sprites/tree_13.png", 1300, 684, 3, 0],
	["路边", "GapBush", "Trees/Sprites/tree_01.png", 1336, 698, 2, 0],
	["路边", "GapBushB", "Trees/Sprites/tree_02.png", 1268, 700, 2, 0],
	["路边", "GapMoss", "Rocks/Sprites/rock_28.png", 1240, 742, 2, 0],
	["路边", "GapTuft", "Trees/Sprites/tree_02.png", 1400, 724, 2, 0],

	# —— 商店上边：北缘树带在 cells 33~43（world 1056~1408）**缺了一段** ——
	# 底图北缘其实有两排树：贴边那排画在 **cell y=-1**（所以按 y≥0 读图会以为没有），
	# 里面那排在 world y 30~190 —— 可它到 world x≈1050 就断了，商店顶上正好露空。
	# 这三丛是把**里面那排**接下去，不是新起一排。脚位 y 136~176：树冠往上和贴边那排
	# 咬住不留草缝，下面又给商店屋顶（y=262 起）留出空带。1290~1330 留豁口。
	# x 不超过 1400 —— 再往东是 cells 44~47 那片底图自带的深色巨石。
	["商店后", "NorthBeltA1", "Trees/Sprites/tree_13.png", 1090, 160, 3, 0],
	["商店后", "NorthBeltA2", "Trees/Sprites/tree_01.png", 1126, 174, 2, 0],
	["商店后", "NorthBeltA3", "Trees/Sprites/tree_03.png", 1056, 176, 2, 0],
	["商店后", "NorthBeltB1", "Trees/Sprites/tree_02.png", 1230, 152, 3, 0],
	["商店后", "NorthBeltB2", "Trees/Sprites/tree_03.png", 1196, 170, 2, 0],
	["商店后", "NorthBeltB3", "Trees/Sprites/tree_01.png", 1264, 138, 2, 0],
	["商店后", "NorthBeltC1", "Trees/Sprites/tree_13.png", 1354, 156, 3, 0],
	["商店后", "NorthBeltC2", "Trees/Sprites/tree_01.png", 1320, 172, 2, 0],
	["商店后", "NorthBeltC3", "Trees/Sprites/tree_03.png", 1388, 140, 2, 0],
	# 商店背面堆货：它是个做买卖的地方，后头本来该有箱有桶，光秃着就不像在营业
	["商店后", "ShopCrateA", "Crates/Sprites/crate_02.png", 1300, 250, 2, 0],
	["商店后", "ShopCrateB", "Crates/Sprites/crate_05.png", 1322, 256, 2, 0],
	["商店后", "ShopBackBarrel", "Barrels/Sprites/barrel_02.png", 1346, 248, 2, 0],
	["商店后", "ShopBackHay", "Generated/hay.png", 1372, 254, 1, 0],
	# 砾石院子的东南角（world 1664,352）本来被那条砾石尾巴挡着，尾巴一清就露成裸直角，
	# 底下 world 1632~1696 / 352~448 也空出一条。用两棵深绿探过院子边压住这个角。
	["商店后", "ShopYardCorner1", "Trees/Sprites/tree_13.png", 1666, 406, 3, 0],
	["商店后", "ShopYardCorner2", "Trees/Sprites/tree_03.png", 1636, 396, 2, 0],

	# —— 西院：上一版这一组全是在给底图那些丑东西「收边」（两条断头石板路的三个断头、
	# 硬直角灌木方块、格子庭院、浅绿草台）。这轮这些东西连根清掉了（见 HOME_CLEAR_RECTS），
	# 收边件也就整组作废，改成正经的取景：用树丛把新屋和三处空档框起来。
	# 这一带偏西，允许出现蓝色接上西南那片蓝绿林；靠房子那侧仍然只用深绿。
	# 房子西边：和西北角那堆底图巨石（world 0~96 / 224~320）之间的空档
	["西院", "WestFrame1", "Trees/Sprites/tree_13.png", 112, 302, 3, 0],
	["西院", "WestFrame2", "Trees/Sprites/tree_01.png", 142, 316, 2, 0],
	["西院", "WestFrame3", "Trees/Sprites/tree_03.png", 92, 338, 2, 0],
	# 主街西端（x=224）以西那片空草坪，往南一直到水塘
	["西院", "WestLawn1", "Trees/Sprites/tree_11.png", 150, 470, 3, 0],
	["西院", "WestLawn2", "Trees/Sprites/tree_01.png", 182, 484, 2, 0],
	["西院", "WestLawn3", "Trees/Sprites/tree_12.png", 118, 490, 2, 0],
	["西院", "WestLawn4", "Trees/Sprites/tree_01.png", 196, 590, 2, 0],
	["西院", "WestLawn5", "Rocks/Sprites/rock_28.png", 222, 600, 2, 0],
	# 门前路以东、主街以北那个口袋（原来是格子庭院、三个蓝陶罐和那块亮绿草台占着，已清）。
	# 主街北肩从门前路一直到商店有 900px 长，全空会很假，所以要一条**断续**的植被带压路缘。
	# 这五件收成一丛（横跨 490~632），不再摊开：摊开就会一头咬住门边那组、一头咬住粉樱，
	# 整条北肩糊成一道连续的绿墙。北肩最终的节奏是
	#   门边组 346~444 | 空 46 | 这丛 490~632 | 空 46 | 粉樱那组 678~910 | 空 85 | 石头对 995~1050
	#   | 空 195 | 商店门前 1245~1305 —— 疏密不等距，才不像等距种树。
	# 脚位一律 ≤400（主街上沿是 416），保证是「贴着路缘往上长」而不是长在石板上。
	["西院", "YardPocket3", "Trees/Sprites/tree_03.png", 516, 392, 2, 0],
	["西院", "YardPocket2", "Trees/Sprites/tree_01.png", 540, 398, 2, 0],
	["西院", "YardPocket1", "Trees/Sprites/tree_13.png", 556, 374, 3, 0],
	["西院", "YardPocket4", "Trees/Sprites/tree_02.png", 588, 390, 2, 0],
	["西院", "YardPocket5", "Rocks/Sprites/rock_28.png", 610, 400, 2, 0],
]

# 重跑时要先整组删掉再重建，否则同名节点会被 Godot 自动改名堆一层
const GROUP_NAMES: Array[String] = [
	"屋前", "廊下", "院心", "树洞", "旧田", "草甸", "路边", "塘边", "田东",
	"商店后", "西院",
]


func _ready() -> void:
	var packed: PackedScene = load(FARM_MAP_PATH)
	if packed == null:
		push_error("[yard_dress] 读不到 %s" % FARM_MAP_PATH)
		return
	var root := packed.instantiate() as Node2D
	add_child(root)

	var repaired := _repair_beige_ground(root)
	var field_cleared := _bake_field_cleanup(root)
	var edge := _straighten_bottom_edge(root)
	# 顺序有讲究：主路要在 _repair_beige_ground 之后画（免得米色修复把新路面当 terrain 0 刷掉），
	# 又要在 _scatter_meadow_tufts 之前画（撒草簇的护栏靠「草地层是纯草块」判空地，
	# 得先看得见新路面才不会把草簇撒到石板上）。
	var road := _rebuild_main_road(root)
	var decluttered := _declutter_home(root)
	var ridge := _paint_empty_ridge(root)
	var bands := _erase_orphan_bands(root)
	var tufts := _paint_ghost_rows(root)
	var meadow := _scatter_meadow_tufts(root)
	var house_moved := _move_house(root)
	var dropped := _drop_old_props(root)
	var added := _add_layout(root)
	var snapped := _snap_sprites(FarmSetdress.ensure_actors(root))

	await get_tree().process_frame
	await get_tree().process_frame

	var owned := _own_all(root, root)
	var out := PackedScene.new()
	var pack_err := out.pack(root)
	if pack_err != OK:
		push_error("[yard_dress] pack 失败: %d" % pack_err)
		return
	var save_err := ResourceSaver.save(out, FARM_MAP_PATH)
	if save_err != OK:
		push_error("[yard_dress] 存场景失败: %d" % save_err)
		return

	print("[yard_dress] DRESSED ok")
	print("[yard_dress]   米色格修回草地=%d  田层残留清掉=%d" % [repaired, field_cleared])
	print("[yard_dress]   底边凸出行收齐=%d  空土垄铺土=%d  孤立草带擦掉=%d" % [edge, ridge, bands])
	print("[yard_dress]   旧路面刷回草=%d  新路面格数=%d" % [road[0], road[1]])
	print("[yard_dress]   西院杂物清掉=%d  老屋搬家=%d" % [decluttered, house_moved])
	print("[yard_dress]   幽灵垄草簇=%d  草坪散簇=%d" % [tufts, meadow])
	print("[yard_dress]   旧装饰删除=%d  新摆设=%d  倍率/偏移收整=%d  打包节点=%d" % [dropped, added, snapped, owned])


func _repair_beige_ground(root: Node2D) -> int:
	var grass := root.get_node_or_null(GRASS_LAYER) as TileMapLayer
	if grass == null or grass.tile_set == null:
		push_error("[yard_dress] 找不到「草地」图层")
		return 0
	var fixed := 0
	for x in range(REPAIR_RECT.position.x, REPAIR_RECT.end.x):
		for y in range(REPAIR_RECT.position.y, REPAIR_RECT.end.y):
			var cell := Vector2i(x, y)
			if _cell_terrain(grass, cell) != TERRAIN_BEIGE:
				continue
			grass.set_cell(cell, GRASS_SRC, GRASS_TILE, 0)
			fixed += 1
	return fixed


func _rebuild_main_road(root: Node2D) -> Array:
	var grass := root.get_node_or_null(GRASS_LAYER) as TileMapLayer
	if grass == null:
		push_error("[yard_dress] 找不到「%s」图层" % GRASS_LAYER)
		return [0, 0]
	# 先整张图把旧路面刷回纯草块。注意只能 set_cell(source 0, (21,25))：
	# terrain 0 叫 grass_1_to_dirt_1，中心块是米色土不是草，拿它刷会又刷出一片沙地。
	var cleared := 0
	for cell in grass.get_used_cells():
		if grass.get_cell_atlas_coords(cell).x > ROAD_ATLAS_MAX_X:
			continue
		grass.set_cell(cell, GRASS_SRC, GRASS_TILE, 0)
		cleared += 1
	var cells: Array[Vector2i] = []
	for rect in ROAD_RECTS:
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				cells.append(Vector2i(x, y))
	if not cells.is_empty():
		grass.set_cells_terrain_connect(cells, TERRAIN_SET_GROUND, TERRAIN_ROAD)
	return [cleared, cells.size()]


func _declutter_home(root: Node2D) -> int:
	var home := root.get_node_or_null(HOME_LAYER) as TileMapLayer
	var detail := root.get_node_or_null(DETAIL_LAYER) as TileMapLayer
	if home == null:
		push_error("[yard_dress] 找不到「%s」图层" % HOME_LAYER)
		return 0
	var erased := 0
	for rect in HOME_CLEAR_RECTS:
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var cell := Vector2i(x, y)
				if home.get_cell_source_id(cell) < 0:
					continue
				home.erase_cell(cell)
				erased += 1
	# 路面底下一律不留装饰：树、石、草簇压在石板上一眼就假。
	# 这一步顺手把 (45,14)/(49,14)/(45,16) 那几件零散小物和田口那块草台一起收掉。
	for rect in ROAD_RECTS:
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				var road_cell := Vector2i(x, y)
				if home.get_cell_source_id(road_cell) >= 0:
					home.erase_cell(road_cell)
					erased += 1
				if detail != null and detail.get_cell_source_id(road_cell) >= 0:
					detail.erase_cell(road_cell)
					erased += 1
	return erased


func _move_house(root: Node2D) -> int:
	var moved := 0
	var house := FarmSetdress.ensure_actors(root).get_node_or_null("OldHouse") as Sprite2D
	if house != null and not house.position.is_equal_approx(HOUSE_POS):
		house.position = HOUSE_POS
		moved += 1
	var marker := root.get_node_or_null("人") as Node2D
	if marker != null and not marker.position.is_equal_approx(HOUSE_POS):
		marker.position = HOUSE_POS
		moved += 1
	return moved


func _cell_terrain(layer: TileMapLayer, cell: Vector2i) -> int:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0:
		return -1
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return -1
	var coords := layer.get_cell_atlas_coords(cell)
	if not source.has_tile(coords):
		return -1
	var data := source.get_tile_data(coords, layer.get_cell_alternative_tile(cell))
	if data == null or data.terrain_set != TERRAIN_SET_GROUND:
		return -1
	return data.terrain


func _bake_field_cleanup(root: Node2D) -> int:
	var field := root.get_node_or_null("田") as TileMapLayer
	if field == null:
		return 0
	var cleared := 0
	for cell in field.get_used_cells():
		var drop := FIELD_CLEAR_RECT.has_point(cell)
		if not drop and cell.x in FIELD_EXTRA_XS and cell.y >= 21 and cell.y <= 26:
			drop = true
		if drop:
			field.erase_cell(cell)
			cleared += 1
	return cleared


func _straighten_bottom_edge(root: Node2D) -> int:
	var grass := root.get_node_or_null(GRASS_LAYER) as TileMapLayer
	if grass == null:
		return 0
	var touched := 0
	for x in range(BOTTOM_TAB_XS.x, BOTTOM_TAB_XS.y + 1):
		var tab := Vector2i(x, BOTTOM_TAB_Y)
		if grass.get_cell_source_id(tab) >= 0:
			grass.erase_cell(tab)
			touched += 1
		var edge_cell := Vector2i(x, BOTTOM_EDGE_Y)
		if grass.get_cell_atlas_coords(edge_cell) != GRASS_EDGE_TILE:
			grass.set_cell(edge_cell, GRASS_SRC, GRASS_EDGE_TILE, 0)
			touched += 1
	return touched


func _paint_empty_ridge(root: Node2D) -> int:
	var field := root.get_node_or_null(FIELD_LAYER) as TileMapLayer
	if field == null:
		push_error("[yard_dress] 找不到「%s」图层" % FIELD_LAYER)
		return 0
	var painted := 0
	for y in EMPTY_RIDGE_TILES:
		field.set_cell(Vector2i(EMPTY_RIDGE_X, int(y)), GRASS_SRC, EMPTY_RIDGE_TILES[y], 0)
		painted += 1
	return painted


func _erase_orphan_bands(root: Node2D) -> int:
	var home := root.get_node_or_null(HOME_LAYER) as TileMapLayer
	if home == null:
		push_error("[yard_dress] 找不到「%s」图层" % HOME_LAYER)
		return 0
	var erased := 0
	for x in ORPHAN_BAND_XS:
		for y in range(ORPHAN_BAND_YS.x, ORPHAN_BAND_YS.y + 1):
			var cell := Vector2i(x, y)
			if home.get_cell_source_id(cell) < 0:
				continue
			home.erase_cell(cell)
			erased += 1
	return erased


func _paint_ghost_rows(root: Node2D) -> int:
	var detail := root.get_node_or_null(DETAIL_LAYER) as TileMapLayer
	if detail == null:
		push_error("[yard_dress] 找不到「%s」图层" % DETAIL_LAYER)
		return 0
	for x in range(GHOST_CLEAR.position.x, GHOST_CLEAR.end.x):
		for y in range(GHOST_CLEAR.position.y, GHOST_CLEAR.end.y):
			detail.erase_cell(Vector2i(x, y))
	var painted := 0
	for row in GHOST_ROWS:
		for x in GHOST_ROWS[row]:
			var cell := Vector2i(int(x), int(row))
			detail.set_cell(cell, GRASS_SRC, TUFTS[_cell_hash(cell) % TUFTS.size()], 0)
			painted += 1
	return painted


func _scatter_meadow_tufts(root: Node2D) -> int:
	var detail := root.get_node_or_null(DETAIL_LAYER) as TileMapLayer
	var grass := root.get_node_or_null(GRASS_LAYER) as TileMapLayer
	var home := root.get_node_or_null(HOME_LAYER) as TileMapLayer
	var sand := root.get_node_or_null(SAND_LAYER) as TileMapLayer
	if detail == null or grass == null or home == null:
		return 0
	var painted := 0
	for blob in MEADOW_BLOBS:
		var center := Vector2(float(blob[0]), float(blob[1]))
		var radius := Vector2(float(blob[2]), float(blob[3]))
		var density := int(blob[4])
		for dx in range(-int(blob[2]), int(blob[2]) + 1):
			for dy in range(-int(blob[3]), int(blob[3]) + 1):
				var cell := Vector2i(int(center.x) + dx, int(center.y) + dy)
				# 幽灵垄那一块由 _paint_ghost_rows 独占重画，别插手
				if GHOST_CLEAR.has_point(cell):
					continue
				# 三重护栏先走：挡掉路面、水面、沙地和底图已有的装饰
				if home.get_cell_source_id(cell) >= 0:
					continue
				if sand != null and sand.get_cell_source_id(cell) >= 0:
					continue
				if grass.get_cell_atlas_coords(cell) != GRASS_TILE:
					continue
				# 护栏之后再擦：能走到这儿的格子上一轮就是我们自己撒的，重跑才幂等
				var here := detail.get_cell_atlas_coords(cell)
				if TUFTS.has(here) or TUFTS_LEGACY.has(here):
					detail.erase_cell(cell)
				if detail.get_cell_source_id(cell) >= 0:
					continue
				# 衰减留个底（0.75 而不是 1.0），边缘也还有两成密度，团的边界才不生硬
				var dist := Vector2(float(dx) / radius.x, float(dy) / radius.y).length()
				var falloff := 1.0 - 0.75 * dist
				if dist > 1.0 or falloff <= 0.0:
					continue
				if _cell_hash(cell) % 1000 >= int(density * falloff):
					continue
				detail.set_cell(cell, GRASS_SRC, TUFTS[_cell_hash(cell) % TUFTS.size()], 0)
				painted += 1
	return painted


func _cell_hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)


func _drop_old_props(root: Node2D) -> int:
	var actors := FarmSetdress.ensure_actors(root)
	var dropped := 0
	for node_name in DROP_NODES + GROUP_NAMES:
		var node := actors.get_node_or_null(node_name)
		if node == null:
			continue
		node.name = node_name + "_dead"
		node.queue_free()
		dropped += 1
	return dropped


func _add_layout(root: Node2D) -> int:
	var actors := FarmSetdress.ensure_actors(root)
	var groups: Dictionary = {}
	var added := 0
	for entry in LAYOUT:
		var group_name: String = entry[0]
		if not groups.has(group_name):
			var group := actors.get_node_or_null(group_name) as Node2D
			if group == null:
				group = Node2D.new()
				group.name = group_name
				actors.add_child(group)
			# 嵌套 y-sort：组内也开，组里的树才会和玩家一起排序，而不是整组沉底。
			group.y_sort_enabled = true
			groups[group_name] = group
		if _add_sprite(groups[group_name], entry) != null:
			added += 1
	return added


func _add_sprite(parent: Node2D, entry: Array) -> Sprite2D:
	var node_name: String = entry[1]
	var tex: Texture2D = load(T + entry[2])
	if tex == null:
		push_error("[yard_dress] 载入不了贴图: %s" % entry[2])
		return null
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	# 统一约定：position 就是「脚」，offset 把贴图往上挪，y-sort 才对得上人。
	# offset 必须取整：贴图宽是奇数时 -w/2 会落在 .5 上，半像素采样直接发虚。
	sprite.offset = Vector2(roundf(tex.get_width() * -0.5), -tex.get_height() + 4.0)
	sprite.scale = Vector2(float(entry[5]), float(entry[5]))
	sprite.position = _snap_even(Vector2(float(entry[3]), float(entry[4])))
	sprite.z_index = int(entry[6])
	parent.add_child(sprite)
	return sprite


func _snap_even(pos: Vector2) -> Vector2:
	# 地面是 scale 2，一个源像素占 2 个屏幕像素。坐标落在偶数上，摆设的像素格才和地面对齐。
	return Vector2(roundi(pos.x / 2.0) * 2, roundi(pos.y / 2.0) * 2)


func _snap_sprites(node: Node) -> int:
	# 连烘进场景的老件一起收拾：老屋原本 scale 3.2、树洞 3.3，非整数倍在 nearest 下
	# 会让同一张贴图里的源像素一会儿占 3px 一会儿占 4px，边缘参差，是「发糊」的主因。
	var fixed := 0
	for child in node.get_children():
		var sprite := child as Sprite2D
		if sprite != null:
			var want_scale := maxf(1.0, roundf(sprite.scale.x))
			var want_offset := sprite.offset.round()
			var want_pos := _snap_even(sprite.position)
			if not is_equal_approx(sprite.scale.x, want_scale) \
					or not sprite.offset.is_equal_approx(want_offset) \
					or not sprite.position.is_equal_approx(want_pos):
				sprite.scale = Vector2(want_scale, want_scale)
				sprite.offset = want_offset
				sprite.position = want_pos
				fixed += 1
		fixed += _snap_sprites(child)
	return fixed


func _own_all(node: Node, owner_node: Node) -> int:
	var count := 0
	for child in node.get_children():
		child.owner = owner_node
		count += 1
		count += _own_all(child, owner_node)
	return count

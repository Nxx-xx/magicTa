# 遗迹分层母版 v02

2026-10-01。imagegen技能＋内置image_gen，实际三张原图均1280×1280真透明PNG。固定石台由生成工具制作，符文/火焰/结果图形为Godot原生可编辑Polygon2D、Line2D与AnimationPlayer轨道。只缩小和定位固定底图，不逐帧重绘底座。三座原生场景512×512，运行帧256×256，锚点(128,224)。

主游戏使用runtime_v02.json；旧manifest.json保留为历史草稿记录。新资源共3张原画、15条时间轴、75个烘焙帧位（含每选项共用的开头/结束），不是75张新原画。R3治疗十字、守御盾形、取金币圆形互斥；R1/R2同样按实际选项播放。idle、resolve、spent的底座位置一致，各帧四边至少4px透明；源文件可编辑，PNG动态资源用于运行时。

已查看R1锋刃、R2锻造、R3防御/治疗联系图，确认轮廓和底座不漂移；程序143项覆盖全部RGBA资源、选项动画、只读播放、重复刷新不重播、读档/回溯静态、减动效、6MiB缓存上限。大场景和目标手机画面仍须单独检查，不声称真人/移动端验收。

原始文件：oath=exec-5198d048-0732-4854-b919-da888336d278.png，forge=exec-ebaa3b3f-9f84-436b-ab53-3911e3be6154.png，sanctuary=exec-22ad0984-7af6-4aa5-8c01-0b696c027805.png。forge、sanctuary以oath为材质参考；全部副本已保存当前目录。

## oath 实际提示词

Use case: stylized-concept. One transparent game environment prop: Oath Ruin, a ruined low stone oath altar from a small fantasy tower library, three prominent carved recesses showing a BROKEN SWORD, a LANTERN, and COINS. Hand-painted polished mobile RPG look, dark desaturated blue-grey carved stone with restrained ancient gold filigree, teal accents. Orthographic slight top-down camera matching a grid dungeon, not isometric diamond. Symmetrical stable stone base, compact chunky readable silhouette at 32px, all three recesses recognizable, no text, no environment, no ground plane, no cast shadow, no loose particles, NO glowing light baked outside the object. The sword/lamp/coins are engraved into stone, NOT floating. Altar complete and centered with wide true transparent margins on every side, square native image at least1024. Intended editable animation uses this invariant base plus separately drawn native rune/light layers.

## forge 实际提示词

Use case: stylized-concept. ONE transparent game environment prop, Oath Forge: broken ring-shaped dark iron anvil on a compact cracked blue-grey stone plinth, a small central cold forge bowl, ancient GOLD edging, a clearly readable anvil silhouette and broken circular ring. Hand-painted polished fantasy RPG prop matching reference's stone and gold material treatment. Orthographic slight top-down camera, no perspective vanishing horizon, compact centred shape readable at 32px. One stable platform, no scenery, no ground shadow, no smoke or light baked outside the prop, NO lit fire (animated teal flame will be added as a separate native layer). No weapons, no text, no people. Full base visible with broad true transparent margins; native1024 or larger square. A different forge silhouette from the three-arch reference shrine, low broad anvil with broken arc over it.

## sanctuary 实际提示词

Use case: stylized-concept. ONE transparent fantasy grid-dungeon game prop: Lantern Sanctuary, a LARGE UNLIT STONE LANTERN on a squat circular stepped blue-grey stone plinth, three shallow channels radiating from its base like paths. Ancient gold rims and small teal inset details, clear open lantern cage with empty dark centre for a separate animated flame layer. Hand-painted detailed RPG material matching reference, but silhouette dominated by one central lantern rather than an anvil/arch. Orthographic slight top-down view, compact chunky silhouette readable at32px. No floating heal crosses or shields, no flames, no baked glow, no text, no characters, no surroundings, no ground shadow, all three channels remain within the same one-tile plinth. Full prop centred with ample true-alpha transparent margins. Native square at least1024. Stable invariant base for editable layered animation.



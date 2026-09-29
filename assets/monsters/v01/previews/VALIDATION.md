# 验证记录 · 2026-09-29

引擎：Godot 4.7.2.stable.official.ed1daf0bf；实际渲染：OpenGL Compatibility / NVIDIA GeForce RTX 5070。

本批六种均为静态可用素材，没有未完成的普通怪 PNG。四方向、动画、精英、Boss 和主游戏集成未实施。

## 已通过

- 六个原始文件已保存；六份最终 PNG 均为 256×256 RGBA，有完全透明、部分透明和不透明像素。
- alpha>0.05 的源主体均不触及源图边缘；保留四源像素抗锯齿余量后等比缩放。最终画布四边所有像素 alpha=0；逐像素结果见 alpha_report.json。
- 六种 Godot 纹理均可导入、尺寸一致，图鉴场景载入并完成两次实际 GPU 截图。
- 人工查看 gallery_dark.png 与 gallery_light.png：无可见白底、白边、裁切或跨格遮挡。绿色胶体、骨白剑盾、红翼、宽灰岩盾壳、深色骑士、窄兜帽余烬轮廓可区分。
- 展示 256px 大图、140px 对照、44px/28px 测试，以及按当前界面公式得到的 46.91px / 26.18px 连格图。26.18px 下只能判断轮廓和材质色块，不能读出面部或盔甲纹理。
- 源图与截图使用 .gdignore 隔离；只有 textures 内六张图作为生产纹理导入。
- 验证使用独立 build/verification/monster_art_v01/appdata 与 localappdata。预览不实例化游戏引擎或访问存档。没有运行或改变怪物投放、战斗或玩家数据。

## 环境信息

每次 Godot 启动均输出 Failed to read the root certificate store。该系统证书告警与本次离线纹理导入及渲染无关；仍如实保留在日志中，不能称为完全无错误日志。所有验证进程退出码为 0，包含 MONSTER_PACK_OK / MONSTER_RENDER_OK 成功标记，无 GDScript 解析错误或运行错误。

日志：build/verification/monster_art_v01/pack.log、import.log、render_dark.log、render_light.log。

## 验证范围限制

当前场景是独立美术预览，不代表素材已接入主游戏。26px 细节损失是缩放的实际限制；集成时仍需保留敌人名称/身份提示并验证角标位置。本批未添加待机动画，避免用简单抖动代替逐帧美术。打包脚本只规范画布与缩放，不生成或替代角色美术。

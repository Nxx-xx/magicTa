# 神秘的老骑士

可编辑 Godot 3D 模型：`source/mysterious_old_knight.tscn`。

模型由命名的独立网格部件构成：白发、眉毛、胡须、胸甲、分层肩甲、护臂、腿甲、旧披风、战袍、盾牌和双手拄剑。钢铁与黄铜使用程序化斑驳材质；胸甲和披风有独立网格几何。`AnimationPlayer` 包含循环 `idle`，控制呼吸、轻微转头和披风摆动。可在 Godot 编辑器中直接调整各部件与动画；这是实际 3D 场景，不是贴图平面。

制作脚本：`tools/build_camp_knight.gd`。用 Godot 4.6.1 或 4.7.2 的 OpenGL Compatibility 模式执行即可重新保存场景及渲染素材。PNG 导入设置开启 mipmaps，重新烘焙后需运行编辑器导入。

游戏使用 8 张 256×256 透明待机帧（4 FPS）及 640×768 对话立绘，均直接由这个模型渲染。运行时 `camp_knight_art.gd` 加载这些 PNG，因此不需要在手机上实时渲染 3D 模型。脚点在帧内 `(128,217.389)`，具体信息记录在 `manifest.json`；改变相机后需同步更新 `camp_knight_art.gd` 的 ANCHOR。

营地与对话页均已接入。减少动效设置启用时固定使用第 0 帧。

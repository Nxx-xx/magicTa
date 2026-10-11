# A 组骑士绘画分层审阅

2026-10-03。原生 3D 模型先续修了头身比、磨损、高光和肩甲，实际烘焙后仍与绘画营地不一致，保留为 `../../source/art_polish_a_native_v02/` 试稿。本稿由内置 image_gen 按原骑士身份和死神绘画材质生成 1254×1254 RGBA 分层原图；完整实际提示词在 PROMPT.md。

原图分出三个原生节点：Head、Cape、BodySwordHandsFeet，含可独立编辑的 .res 图层与 AnimationPlayer。不是完整多关节战斗模型。身体／双手／扶剑／靴子保持一个固定绘画层，保留落地扶剑姿势，头部轻转、披风偏移，继承 8 帧、4 FPS、2 秒循环和原 anchor (128,217.389022827148)。未新增骑士其他朝向或攻击动作；没有减少原有动作。

分层裁切、位置、比例和动画构造完整保存在 `tools/art_polish_a_knight_layer_bake.gd`。烘焙只写 draft。查看逐帧、小尺寸和真正 AnimationPlayer 的 1 倍／0.25 倍有序采样后，使用独立 `tools/art_polish_a_publish.py` 明确指定精确 draft SHA 审批，再单独 publish。visual_review.json 记录原图、模型、图层、帧、原生采样的 SHA，生产写到同版本 textures，不覆盖原骑士。

视觉检查：灰蓝旧钢与低饱和古金轮廓匹配营地；银发、胡须、盾徽仍辨认；手握剑柄没有分离；剑尖与双靴固定；透明边没有碰画布边界。26px 下五官和细刻纹消失，依靠银发／扶剑／盾轮廓识别；小尺寸动态很轻，不把每一帧称为独立原画。

`human_signoff=false`。本审阅是模型观察到的静态与有序样本，未声称连续视频感知、真人手感或微信真机签收。最终集成由统筹完成。

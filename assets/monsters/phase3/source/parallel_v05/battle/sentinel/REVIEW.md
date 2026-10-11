# 石壳卫兵战斗 v05 · draft

2026-10-01。内置 imagegen 新增一张真实透明组件原图，未修改像素绘制；实际提示词在 PROMPTS.md。原图与正式旧造型均保留。17 个节点含16个绘制层和 shield_grip，壳/核心/双肩肘/髋膝踝独立绑定。Godot 原生 AnimationPlayer 场景可重载，源 JSON 可编辑，全部 Godot 调用经 MagicTa_Phase3_Parallel_Godot mutex 与 base_b 隔离存档。

战斗朝左，512母版→256运行帧，锚点(128,224)，固定根节点。idle 4/6 循环；attack 6/12，命中帧3，末帧5→0显式回位hold；hit 2/12；defeat 6/10，帧2壳体解体、帧5落地。18帧位中17个动作内非hold姿态；不宣称18幅新原画。地图动作由地图组独立制作，本目录无地图资源。攻击核心微光为独立RGBA效果帧，关闭效果仍保留实体核心与全部动作。

实际 agent 静态视觉审阅：看过修正版四条联系图的全部18帧位、独立效果合成和26/33/47px全部姿态。肩肘拳击预备→朝左伸拳→回收可读；盾握点稳定；受击躯干与头部回弹；退场多个石块分别塌落。修正首次浮颈：头层下移18母版像素、略扩大。失败联系图保留在 build/verification/phase3/08-parallel/base_b/iteration01。最终无边界裁切。

尚未批准发布：CUA 打开 file:// 本地HTML被浏览器URL安全策略拒绝，且该策略禁止绕过。已生成原速与0.25倍无损WebP和可逐帧HTML，但本线程未实际看过动态播放，不能将静态审阅冒充原速/慢速自然度签收。sentinel_publish_review.json 绑定最终身体及效果SHA256，static_visual_decision=accepted，decision=pending_motion_review，human_signoff=false。交统筹完成独立播放审阅后显式发布。

预览 sentinel_review.html；证据 build/verification/phase3/08-parallel/base_b/sentinel_*。小尺寸下保留拳/盾和石色轮廓，26px不要求读出胸纹。画风比旧静态更细长、关节更机械；真人最终美术自然度仍待签收。

作者/来源：OpenAI built-in imagegen 原画，本次 Codex 原生关节装配与动画；无第三方下载素材，未另行赋予第三方许可证。

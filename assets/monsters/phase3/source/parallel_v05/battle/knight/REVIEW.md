# 空心骑士战斗 v05 · draft

2026-10-01。内置 imagegen 新增一张透明组件原图，完整实际提示词在 PROMPTS.md，项目内原图保存。21节点含16绘制层与 weapon_grip、shield_grip、cape_joint、双踝接触节点；剑臂肩肘/腕握点、两段披风和前裙独立。小腿与靴共用绘制层，踝为接触节点，此限制不冒充独立靴原画。Godot 原生 AnimationPlayer 场景可重载，源 JSON 可编辑；所有调用使用共享mutex与base_b隔离存档。

战斗朝左，512母版→256运行帧，锚点(128,224)。idle 4/6循环；attack 6/12，命中帧3，回位5→0显式hold；hit 2/12；defeat 6/10，帧2松剑、帧5落地跪伏。18帧位中17个动作内非hold姿态，非18幅新原画。地图由另一组独立制作，本目录无地图动作。剑弧为可关闭独立效果，身体与装备不依赖效果。

实际 agent 静态视觉审阅：全部四条联系图、18帧位及26/33/47px姿态。首轮蓄力剑尖错误指下，现增加独立腕旋转轨迹使剑尖上举后向左斩出，握点仍固定在近手；后披风上下层延迟摆动，受击盾手跟随，退场剑独立落在左侧。失败联系图保留在 build/verification/phase3/08-parallel/base_b/iteration01。最终无边界裁切。小尺寸下剑盾及披风轮廓可辨，细金纹不作为26px识别条件。

尚未批准发布：浏览器工具拒绝本地file协议且禁止绕过，本线程未完成原速/0.25倍实际交互播放审阅。已提供 knight_review.html 与各动作原速/.25无损WebP。knight_publish_review.json 精确绑定最终身体和效果哈希，static_visual_decision=accepted，decision=pending_motion_review，human_signoff=false。统筹须独立审阅动态自然度后显式发布。

作者/来源：OpenAI built-in imagegen 原画，本次 Codex 原生关节装配与动画；无第三方下载素材，未另行赋予第三方许可证。

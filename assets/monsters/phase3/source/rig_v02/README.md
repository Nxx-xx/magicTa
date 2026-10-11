# 史莱姆与牛头可编辑绑定样板 v02（draft）

参考为本工程批准旧静态图；来源/实际提示词见 `docs/phase3/ANIMATION_BALANCE_PROMPTS.md`。本目录有`.gdignore`，不进入正式美术导入范围。旧51帧草稿与正式manifest均未覆盖。

`slime_rig.json`（512画布）/`minotaur_rig.json`（768画布）是规范源；同名`*_editable_draft.tscn`是可编辑Godot Node2D关节、Sprite2D图层、AnimationPlayer工程，已实际重载校验。`*_layers`包含透明PNG与原生RES；`*_frames`是256/384烘焙草稿；`*_review.html`支持原速/慢速/逐帧及47/33/26px审查。

史莱姆3层：外膜、内部核心、表情，另有6张重绘外膜轮廓作为离散shape轨道；attack不是整张静态图缩放。idle4、attack6、hit2，共12帧位；退场未做。攻击峰值为源帧3，因此草稿事件hit=3（旧设计示例4不机械照抄）。修复了表情脱出胶膜、核心露出外膜、底行邻帧碎片。**胶体体量/接触与循环连续性、透明边细节及退场仍未正式验收**。

牛头9层：头角、胸、近/远腿、上臂、前臂、远臂、斧、怒纹。肩/肘/武器绑定可编辑，独立怒纹可关。idle6、attack8、hit3、rage6，共23帧位；退场10未做。已固定全套构图并缩短整套斧尺度以消除越界（不同动作不改变武器体量）。重绘已将肘端圆面改为毛发、去掉胸层重复肩甲；前臂/怒纹裁切去掉了邻格边缘，枢轴偏移同步调整以保持原定位。**关节遮挡、远腿方向、胸头视角一致性与下肢完整膝踝绑定仍需修订；当前主要是上肢剪纸动作，不能冒充完整正式Boss动画**。

JSON `r/p/a/shape`分别是角度、局部位移、独立层透明度、形状索引。`shape_layers`保留源图矩形和原单元偏移，非逐帧重心对齐；各帧共享根锚点。全部动作仍draft，不能把50个三角色总烘焙帧位计成50张独立原画或236帧预算已验收部分。

编辑JSON后执行 `tests/phase3_animation_balance_verify.ps1 -BakeRigs`。只有需要重建初始JSON才执行 `tools/phase3_build_rig_sources.py`；它会覆盖手改JSON。直接修改tscn请另存版本，以免后续烘焙覆盖。无需采购外部骨骼软件。

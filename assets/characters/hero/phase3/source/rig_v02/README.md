# 公主可编辑绑定样板 v02（draft）

本目录不是正式运行资源。身份参考/实际工具提示词见 `docs/phase3/ANIMATION_BALANCE_PROMPTS.md`。公主原组件1280×1280，修正远侧靴向后切为14个命名图层。没有把整张旧静态图当作动画形变。

- `hero_rig.json`：可直接编辑的规范源，768画布，根锚点(384,696)；每层有parent、枢轴、原图裁切、贴图枢轴、固定缩放及层级。
- `hero_editable_draft.tscn`：Godot原生场景，真实Node2D关节层级、Sprite2D图层和AnimationPlayer时间轴，可在编辑器手动打开；已验证保存后可重载并保留动作。
- `hero_layers/`：透明PNG与无需导入的原生纹理RES。
- `hero_frames/`：384运行尺寸草稿，idle4、attack8、hit3。首尾回位有重复姿态；15是时间轴帧位数，不是15张新原画，不能填入正式帧预算。
- `hero_review.html`：原速、0.25倍速、暂停、逐帧、47/33/26px审查。

JSON姿态字段：`r`为关节相对休止位的角度，`p`为局部位置偏移，`a`为独立层透明度；动作的fps/loop/events是可编辑数据。整套姿态使用固定0.8构图缩放，不逐帧重新居中。武器随右前臂，灯随左前臂。

编辑JSON后，执行 `tests/phase3_animation_balance_verify.ps1 -BakeRigs` 重建原生场景及运行帧。`tools/phase3_build_rig_sources.py` 用于重建初始JSON，会覆盖手改JSON；不要在保留手改源时运行。若直接编辑tscn，请另存版本，避免被烘焙器覆盖。

已修：远侧靴朝向、武器越界；所有烘焙帧外缘≥4透明像素。未通过：四向独立模型/行走、脚部IK与接触、灯与后手遮挡细修、头发细分层、全身蓄力/回收力度、其余战斗动作。程序边界通过不能替代原速动作与画风人工验收；正式manifest仍为空。

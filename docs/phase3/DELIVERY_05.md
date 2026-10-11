# ⑤ 引导与动画交付

当前状态：**模块完成待集成**。2026-10-01。

此状态指三个独立程序模块及专项验证已完成；**主角逐帧美术、分层绑定母版和整阶段验收未完成**。三轮新图均为草稿/拒收记录，正式 manifest 不引用它们。既有 hero_walk、floating_joystick、主角 README、map_screen、grid_board、旧演出与存档入口均未修改。无提交、推送、重置、全项目 import 或导出。

## 已实现清单

- 八节点纯教程状态机：操作证据驱动；shown/deferred/completed/dismissed/skipped分离；跳过全部/重置；版本化偏好读入/快照；高级弹层暂缓；无比较目标延后；试炼不承诺灵魂。独立提示组件不抢焦点、不捕获取消键，按钮44px。
- 动画目录：18动作、91帧位规格表；版本/帧数/FPS/loop/尺寸/锚点/事件/来源审查/路径校验；原始PNG和导入纹理加载；物理尺寸、alpha、相同像素不同文件名检查；时间取帧、末帧停留、loop、减动效、SpriteFrames适配；有界LRU缓存。
- 只读战报播放器：保存成功门槛；深拷贝输入；末回合、首次效果、狂怒/石甲优先，最多6个真实回合（普通最多5）；省略机制摘要与完整可滚动战报；蓄力→帧3命中→护符→反击→反伤；反伤击杀无虚构下一剑；跳过、关闭、减动效、暂停/失焦；结束信号幂等。
- 独立Godot UI预览、四档截图；原始图格的四向/攻击/受击原速、慢速、暂停、逐帧HTML预览及47/33/26px显示。

## 公开接口

### 教程 scripts/ui/phase3_tutorial.gd

RefCounted，纯静态状态接口：

```gdscript
var state = Tutorial.initial_state()
var restored = Tutorial.restore(saved_preferences) # {ok,error,state}
var result = Tutorial.reduce(state, event, context) # {ok,error,state,prompt}
state = result.state
view.set_prompt(result.prompt)
var preferences = Tutorial.snapshot(state)          # 由设置事务保存
var view = Tutorial.create_prompt(result.prompt)    # PanelContainer
# view.dismissed(id) -> reduce(state,{type:"dismiss",id:id},context)
# view.skip_requested -> reduce(state,{type:"skip_all"},context)
```

状态为 `version:1,enabled:bool,active:String,nodes:{T01…T08:{status,triggered}}`。snapshot清active；restore把shown转deferred，由当前context重选。不触碰run/meta。关闭提示只记dismissed，之后真实操作仍可完成节点。偏好保存失败时保留会话state，宿主显示重试；模块不写盘。

| 节点 | 触发event.type与额外字段 | 完成证据event.type与字段 |
| --- | --- | --- |
| T01 | floor_entered：floor=1,new_run=true | move_succeeded：committed=true |
| T02 | enemy_viewed | enemy_preview_closed/confirmed：viewed_full=true |
| T03 | equipment_received：committed=true | comparison_viewed：discovered=true,same_enemy=true |
| T04 | door_viewed | door_opened：committed=true；或door_explanation_closed |
| T05 | potion_viewed | potion_used：committed=true；或potion_retained |
| T06 | ruin_viewed：ruin_id=p3_oath_ruin | ruin_claimed：同ID,committed=true；或ruin_left：同ID |
| T07 | enemy_viewed：floor=1,enemy_id=knight,lethal=true；false则跳过 | target_marked/target_mark_declined（宿主仅为当前教学骑士派发） |
| T08 | result_viewed | camp_embers_viewed/result_hint_closed |

context布尔字段：save_error、lethal_confirmation、combat_modal、reward_modal、story、story_queued任一为真即暂缓；comparison_available、full_hp、trial提供条件。弹层变更派发`{type:"context_changed"}`，重置`{type:"reset"}`仅影响教程。成功事件必须来自实际已提交事务，不能由按钮点击伪造。

### 目录 scripts/ui/phase3_animation_catalog.gd

RefCounted。静态`read_manifest(path=DEFAULT_MANIFEST)`、`validate(data,require_complete=false,check_files=true)`、`specifications()`；实例`configure(data)`、`frame_at(action_id,seconds,reduced=false)`、`sprite_frames(action_id)`、`clear_cache()`。

动作ID：`map_<idle|walk|interact>_<down|left|up|right>`、`combat_<idle|attack|guard|hit|victory|defeat>`。

每动作字段：`status:"accepted",frames:[res://assets/characters/hero/phase3/textures/*.png],fps,loop,size:[w,h],anchor:[x,y],events:{hit:3},source,review`；attack命中必须3。顶层version=1、handedness=right_sword_left_lantern、mirrored=false。当前actions为空；非严格模式允许部分交付，严格模式明确拒绝当前不完整资源。

frame_at返回`ok,error,texture,frame,anchor,fallback,label`。缺动作/帧时读取旧已批准同向idle，战斗默认right，返回fallback=true及可见文案；无替换旧行走的隐式行为。sprite_frames回退只能产生一帧，不伪造walk。缓存默认24MiB；4向fallback实测262144字节（0.25MiB）。这不等于全进程或外部持有SpriteFrames的驻留实测；整批48MiB目标尚未验证。

### 演出 scripts/ui/phase3_combat_player.gd

独立Control。静态`validate_report(report)`、`choose_turns(report,limit=6)`、`build_plan(report,rank="normal",reduced=false)`、`final_result(report)`、`report_text(report)`；实例`configure(report,committed,options={rank,reduce_motion})`、`advance(delta)`、`skip()`、`close()`、`set_paused(bool)`、`set_reduce_motion(bool)`、`full_report()`。

```gdscript
# 同一战斗事务保存成功后：
var replay = preload("res://scripts/ui/phase3_combat_player.gd").new()
var checked = replay.configure(committed_report, true, {
    "rank": enemy.rank, "reduce_motion": settings.reduce_motion
})
if checked.ok:
    modal_host.add_child(replay)
    replay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    replay.dismissed.connect(on_replay_closed)
```

信号cue_presented(cue)供音效适配；playback_finished(result)仅通知显示完成；dismissed幂等通知关闭。**这些信号都不是扣血、领奖或保存入口**。每实例只接受一次configure。消费协议已有字段/effect_events，支持③真实输出与旧兼容字段。不导入模拟器、奖励、保存，不消耗RNG。

普通1.2～2.7秒、精英≤3.68秒、Boss≤4.1秒（当前编排）；减动效0秒。完整战报按钮不改变时间线与结果。背景地图禁用、总焦点/取消键路由由宿主接线负责。

## 修改文件

- scripts/ui/phase3_tutorial.gd
- scripts/ui/phase3_animation_catalog.gd
- scripts/ui/phase3_combat_player.gd
- assets/characters/hero/phase3/manifest.json
- assets/characters/hero/phase3/source/{.gdignore,PROVENANCE.md,prompts.md,三个PNG草稿}
- assets/characters/hero/phase3/textures/_verification/.gdignore（测试临时诊断图隔离；结束移除生成PNG，不是人物资源）
- tests/phase3_animation_{fixture,test_runner,preview,art_review}.gd
- tests/phase3_animation_verify.ps1
- 本DELIVERY；证据统一在build/verification/phase3/05-animation/。

## 测试命令与实际结果

```powershell
& ./tests/phase3_animation_verify.ps1
& ./tests/phase3_animation_verify.ps1 -Capture
& ./tests/phase3_animation_verify.ps1 -ArtReview
& ./tests/phase3_animation_verify.ps1 -Preview # 人工交互，关闭窗口退出
```

前3条已真实运行。Godot 4.7.2.stable.official.ed1daf0bf：**88通过，0失败，无脚本解析/运行错误**。启动器同时检查退出码与SCRIPT ERROR，避免脚本异常仍退出0的假阳性。APPDATA/LOCALAPPDATA隔离并finally恢复；未读取玩家存档。截图：OpenGL Compatibility / NVIDIA GeForce RTX 5070。

覆盖八节点、收起≠完成、保存失败、优先级、跳过/重置、无目标延后、试炼文案；manifest错误、同像素假多帧、原始PNG解码/帧率/循环/末帧/回退/缓存；真实回合取样、超量机制摘要、帧3命中、时长、反伤末击、暂停/跳过/关闭幂等、深拷贝。③源码出现后追加6能力真实报告和真实单回合反伤击杀，均通过；模拟器仅由测试读取，演出模块无模拟依赖。

证据：validation.json、tests.log、preview.log、四档combat_*.png与tutorial_*.png、static_fallback.png、art_review.html、art_metrics.json、41个原始图格。已目视检查四档战报、最小教程与静态回退；按钮/底栏在画面内，完整战报可滚动。预览关闭工程自动缩放，使用320×640、360×640、540×960、900×960实际像素；明确标注协议夹具，不冒充主游戏集成截图。

Godot有已有系统根证书库读取告警；任务离线，不影响脚本、PNG解码与截图。未做目标机性能结论。

## 图/动画来源与实显检查

内置imagegen三轮，完整提示词、实际尺寸、来源、失败原因在source/PROVENANCE.md和source/prompts.md。新24四向图格、6侧向修订图格、11攻击/受击图格；这是审查图格数，**正式通过0帧**。

四向/侧向步态未证明相反腿接触；战斗有不同动作姿势，但图格跨界/脚底裁切，未获得固定根与正式锚点。按原图切格保留漂移，无强制对齐掩盖问题。所有源图有真实alpha；最初依据缩略图对背景的疑虑已由像素检验纠正。HTML展示原图格及小尺寸，不是假静态变形。

AN-05程序门禁、AN-06夹具/真实战报、AN-07独立组件验证通过；AN-01～04正式角色帧、完整实机动画视频、模型绑定未通过/未完成。UX-01/02仅独立组件尺寸检查，不等于主游戏模态/移动输入验收；UX-03存档事务与UX-05新玩家试玩须集成后验证。

## 统筹接入需求

1. 成功事务后派发上表事件；会话持有state，偏好写presentation.cfg版本化分组。失败留会话state并可重试，不阻断玩法；设置重置仅影响教程。
2. 高级弹层填context；地图输入、取消键、剧情队列由宿主管理。教程view放非模态区域，不作全屏遮罩。
3. ③战报保存成功再configure(...,true)；失败不创建演出。结束/关闭只导航，不再次结算。音效可订阅cue_presented并尊重既有设置，零收益机制不夸大音效。
4. 保留现有hero_walk。当前manifest为空，不能以草稿替换正式主角。美术验收后才填accepted；未来PNG由统筹串行import/export；source与验证夹具保持忽略。
5. 公共战报接口足够；教程事件、偏好schema、committed门槛见本文，建议统筹冻结到INTERFACES后接线，无需修改③输出。

## 未完成内容

- 可编辑分层模型、四向独立绑定/枢轴、合格24行走帧与11战斗样板帧；其余56帧位也未制作验收。生成图不能替代这些交付。
- 主游戏接线、真实地图动态小格验收、正式动画原速/慢速录屏、敌方牛头/史莱姆配合样板（③负责）、音效接入。
- 主流程存档失败/切后台/剧情排队集成回归、模态焦点、整批48MiB驻留与目标设备帧时、人工教学试玩。

因此仅记作独立程序模块完成待集成，不能将⑤完整美术范围、S3-C或第三阶段标记完成。


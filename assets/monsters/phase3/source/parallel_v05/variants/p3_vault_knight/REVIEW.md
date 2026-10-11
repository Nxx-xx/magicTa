# p3_vault_knight variant battle draft review

2026-10-02. Built-in imagegen 新增 1 张透明附件原画；完整实际提示词在 PROMPTS.md。四个基础动作只读复用已稳定的基础制作源，在本目录保存带哈希的组件快照。base_provenance.json 记录依赖路径与实际 SHA256。

战斗母版512×512，运行256×256，锚点(128,224)，朝左偏侧镜头。idle 4/6、attack 6/12、hit 2/12、defeat 6/10、threat 4/8，共22帧位。idle循环，其余非循环。动作是分层绑定源，22帧位并非22幅新增原画。

本次含 19 个绘制层及 5 个关节/握点。原生 p3_vault_knight_editable_draft.tscn 含 AnimationPlayer 可编辑轨道，JSON保留关节、枢轴与动作姿态。根节点固定，不用整幅角色拉伸或旋转替代动作。

本线程实际看过全部动作联系图、全部帧位、浏览器原速/0.25倍的画面与帧号变化、暂停和逐帧关键姿态、26/33/47px及效果开关。最终修正后重新查看完整联系图和原速/慢速/峰值/退场末帧。技术检查与画面决定分离，烘焙/预览工具不会生成批准记录。

- `idle`：Independent three-key crown, lock pauldron and vault shield retain identity with glints disabled; cape/cloth secondary movement. Events={}; pose_holds={}.
- `attack`：Shoulder/elbow and sword wrist raise then strike left at 3; crown/lock shoulder follow; final frame 5 to 0 return hold declared. Events={"hit": 3.0}; pose_holds={"5": 0.0}.
- `hit`：Helmet/chest recoil and recover while crown and lock shoulder remain attached. Events={"recoil": 0.0}; pose_holds={}.
- `defeat`：Body kneels and sword lowers/releases at 2, ground 5; crown/lock shoulder and vault shield persist without clipping. Events={"ground": 5.0, "release": 2.0}; pose_holds={}.
- `threat`：Sword arm folds then presents raised threat posture at 2; head inclines and cape counter-swings; independent gold glint optional. Events={"threat_peak": 2.0}; pose_holds={}.

身体与独立特效均为真实RGBA透明帧，效果开关后塔盾/炉环/钥匙冠等实体轮廓仍在。硬件原画的金属高光、晶石暖色属于实体表面；可关闭的是动态焰光/符纹/剑光，未把实体宝石本身删除。

修正记录：盾壳最初等分格切掉肩板、盾握柄并混入邻件，改按实际完整物件边界提取；guard初版盾面偏右，改肩肘两段求解，取消装备相对握点滑移。蓄焰三叉底座/炉环因等分格被裁切，改实际边界；charge双焰改单焰。被拒绝切片帧保留在相关实体 rejected_grid_crops_frames 与 rejected_grid_crops_rig.json；蓄焰双焰另有明确标记 reconstructed 的 rejected_double_flame_rig.json 及原生重建帧，均不在批准清单。

预览和证据：build/verification/phase3/08-parallel/variants/variants_review.html（自包含原图，可离线打开）；每动作 *_draft_contact.png、*_small_contact.png、*_original.webp、*_quarter.webp；每实体 *_all_actions_contact.png；包装器日志/启动证据/退出码及 variants_technical_checks.json。Godot调用全部经共享命名mutex包装器并隔离APPDATA/LOCALAPPDATA。

精确批准：p3_vault_knight_publish_review.json 绑定本次身体、效果、组合帧SHA256以及源/场景/清单SHA256。仅本次agent视觉审阅accepted；源仍draft，由统筹独立二次复查后发布。human_signoff=false。

地图动作 map_idle 由独立地图组制作，镜头为轻俯视正面；已向地图组发送原图和附件身份规范，不把本战斗帧缩小替代地图。

限制：26px可读主要轮廓与方向，细金纹、钥匙齿内部细节不可承诺逐个辨识；本批未进行真人自然度签收、正式生产接入、真实战斗回放或Windows/微信客户端和性能预算验收。数值/奖励/交易/玩家存档不在本线程修改范围。

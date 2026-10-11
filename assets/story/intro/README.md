# 开场剧情背景 v01

`tower_entrance_v01.png` 是塔外入口背景，供 `intro` 和 `retry` 剧情使用。
背景不含角色、对白、按钮或文字；角色复用现有透明立绘，界面由 Godot 实时绘制。
其他楼层与终章继续使用各自原有的剧情展示，避免把塔外场景用于塔内对白。

生成方式：内置 image_gen，参考用户确认的竖屏开场界面设计稿。
未覆盖已有美术资源。完整生成提示词见 `generation_prompt.txt`。

接入：`scripts/ui/story_intro_stage.gd`、`scripts/ui/map_screen.gd`、`scripts/ui/campaign_panels.gd`。
验证：`tests/story_intro_ui_test_runner.gd` 覆盖 320×640、360×640、540×960、900×960，
检查对白推进、跳过、旁白与角色切换、长文本滚动、普通面板恢复及终章展示隔离。
实际运行截图输出至 `build/verification/story-intro/`。

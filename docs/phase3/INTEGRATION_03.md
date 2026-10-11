# ③ 独立生产集成测试

> 统筹续接更新（2026-10-01）：本聊天的集成轮因用量限制中断，以下“进行中”为当时记录。统筹已完成程序接线与验证，实际结果、截图和剩余美术范围见 [INTEGRATION_RESULTS.md](INTEGRATION_RESULTS.md)。

当前状态：进行中，2026-10-01。仅新增 `tests/phase3_integration*`、本报告与独立证据；不改生产文件。

## 范围与安全边界

复用旧 campaign_test_runner / campaign_journey_capture 的真实移动、战斗、奖励、楼梯路线；零火种起点，不通过改state或玩家属性伪造通关。先种子42，再0..99三策略。APPDATA/LOCALAPPDATA与user://保存仅在 `build/verification/phase3/03-combat/integration/`。

## 接口现状

首次读取时 `campaign_engine.gd` 尚无 start_phase3 / is_phase3 / choose_ruin；root正在接线。测试将检测缺失接口并写明失败原因，不在本聊天代改。

## 测试结果

待实现并实际运行。

## 问题与复现

待首轮结果。

## 未完成

100种子×三参考策略、持久化重进/失败重试/结算防重、遗迹回访、旧模式回归与集成审查。

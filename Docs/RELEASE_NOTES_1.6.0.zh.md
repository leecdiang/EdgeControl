# EdgeControl 1.6.0

新增自定义磨砂菜单栏弹窗、分组式设置窗口及 System/Classic/Aurora 三档 HUD 配色，并保留 1.5.1 的全部可靠性修复。

## 界面

- 约 304pt 的窗口式菜单集中显示实时状态、左右边缘卡片、触觉/HUD/登录启动快捷开关、设置与退出。
- 设置窗口按 Controls、Feedback、Devices、About 分组，使用紧凑的系统渲染卡片。
- 设置窗口使用稳定的初始与最小尺寸，不再随当前标签内容自动变化。

## HUD 配色

- System 为中性黑白，Classic 使用系统蓝/橙，Aurora 使用系统紫/青绿。
- 仅进度填充条使用明显颜色，玻璃、文字、图标及未填充轨道保持中性。
- 旧 `colorfulHUD` 会迁移为 System/Classic，并存入新的 `hudColorStyle`。

## 验证

- 源码共 61 项 XCTest。
- 源码侧仓库验证已通过。
- 发布前请在 macOS 执行 `OPENCLAW_VALIDATE_1.6.0.md`。

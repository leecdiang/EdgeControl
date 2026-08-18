[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文版**](#zh)

# EdgeControl 1.6.0

A visual refinement release with a compact custom menu, reorganized Settings, and three HUD color styles. It includes all reliability fixes from 1.5.1.

## New interface

- The plain system menu is replaced by a lightweight 304-point frosted popover with live touch status, a master switch, two edge-action cards, Haptic/HUD/Login quick toggles, Settings, and Quit.
- Settings is reorganized into Controls, Feedback, Devices, and About with compact grouped cards, clearer hierarchy, stable window sizing, and a dedicated warning surface.
- No image bundle or third-party UI dependency was added; the interface remains system-rendered and follows light/dark appearance.

## HUD palettes

- HUD color is now a three-level setting: System, Classic, or Aurora.
- System keeps the progress indicator neutral. Classic uses dynamic system blue for volume and orange for brightness. Aurora uses dynamic system purple and teal.
- Color is concentrated in the internal progress indicator. Icons, text, track, and glass remain neutral, preserving the compact frosted appearance.
- The former Colorful HUD preference migrates safely: off becomes System and on becomes Classic.

## Reliability inherited from 1.5.1

- Committed-direction zero-cross protection closes the gradual deadband bypass.
- Pending Strong secondary pulses are cancelled on gesture end and wake reset.
- Multi-display DDC writes target the connection that answered the initial session read.
- Bundle build metadata follows `CURRENT_PROJECT_VERSION`; this release is 1.6.0 (3).

## Tests and validation

- The source contains 61 XCTest methods, including HUD preference migration and the 1.5.1 reliability regressions.
- Repository structure, invariants, privacy, shell syntax, and whitespace checks pass in this source package.
- Xcode build/tests, menu/Settings appearance, Universal 2 inspection, physical haptics, and real DDC hardware remain required on macOS before publishing.

---

<h2 id="zh">中文版</h2>

# EdgeControl 1.6.0

本版本重点优化视觉体验：新增精简自定义菜单、重新组织设置窗口，并提供三档 HUD 配色；同时完整继承 1.5.1 的可靠性修复。

## 全新界面

- 原生纯文字菜单改为约 304pt 的轻量磨砂弹窗，集中显示触控状态、总开关、左右边缘卡片、触觉/HUD/登录启动快捷开关、设置与退出。
- 设置窗口重新分为 Controls、Feedback、Devices 与 About，使用紧凑分组卡片、稳定窗口尺寸及独立警告区域。
- 不增加图片包或第三方 UI 依赖，继续使用系统渲染并自动适配深色/浅色外观。

## HUD 三档配色

- HUD 配色改为 System、Classic、Aurora 三档。
- System 使用系统黑白；Classic 为音量动态蓝色、亮度动态橙色；Aurora 为音量动态紫色、亮度动态青绿色。
- 颜色主要集中在内部指示条；图标、文字、未填充轨道和玻璃底板保持中性，避免破坏磨砂层次。
- 旧版 Colorful HUD 设置会安全迁移：关闭对应 System，开启对应 Classic。

## 继承 1.5.1 的可靠性修复

- 激活方向锁定，修复渐进反向借死区绕过过零取消。
- 手势结束或唤醒复位时取消 Strong 尚未触发的第二次脉冲。
- 多显示器 DDC 写入固定到初始读取成功的连接。
- Bundle 构建号读取 `CURRENT_PROJECT_VERSION`；本版本为 1.6.0（3）。

## 测试与验证

- 源码共 61 项 XCTest，包含 HUD 设置迁移及全部 1.5.1 可靠性回归。
- 本源码包通过仓库结构、关键不变量、隐私、Shell 语法与空白检查。
- 发布前仍须在 macOS 完成 Xcode 测试、菜单/设置视觉检查、Universal 2 检查、触觉真机与真实 DDC 验证。

SHA-256: `9f5c50ae127da75aea10e12a4d6aeaf2b23fab0539047930315d5e950669f62f`

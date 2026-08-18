[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文版**](#zh)

# EdgeControl 1.5.1

A focused reliability update for edge gestures, Strong haptics, and multi-display DDC.

## Fixed

- Zero-cross protection now remembers the direction that activated the gesture. A slow reversal can no longer pass through the 0.5% noise deadband and continue in the opposite direction.
- A pending second Strong haptic pulse is cancelled when the gesture ends or the app resets after wake, preventing delayed feedback after the interaction has stopped.
- External DDC writes now target the same monitor that answered the session's initial brightness read instead of always writing to the first enumerated display.
- The Haptic feedback switch now sits beside Haptic strength in Controls, so the disabled state is immediately understandable.
- `CFBundleVersion` is now sourced from `CURRENT_PROJECT_VERSION`; this release uses marketing version 1.5.1 and build 2.

## Tests and validation

- Four regressions cover gradual zero crossing, Strong-pulse cancellation on end/wake, and responsive DDC connection selection. The source suite contains 60 XCTest methods.
- Repository structure, invariant, privacy, shell-syntax, and whitespace checks pass in this source package.
- Xcode build/tests, Universal 2 inspection, physical haptic feel, and real multi-monitor DDC remain required on macOS before publishing.

---

<h2 id="zh">中文版</h2>

# EdgeControl 1.5.1

本版本集中修复边缘手势、强档触觉反馈与多显示器 DDC 的可靠性问题。

## 修复

- 过零保护现在会记住触发激活的方向；缓慢反向时无法再借 0.5% 噪声死区绕过取消逻辑。
- 手势结束或睡眠唤醒复位时，会取消强档尚未触发的第二次脉冲，避免操作停止后仍出现延迟震动。
- 外接 DDC 写入会固定到本次会话中成功返回初始亮度的显示器，不再一律写向枚举列表中的第一台显示器。
- “触觉反馈”总开关移到 Controls 并与“触觉强度”相邻，禁用状态更易理解。
- `CFBundleVersion` 改为读取 `CURRENT_PROJECT_VERSION`；本版本号为 1.5.1，构建号为 2。

## 测试与验证

- 新增 4 项回归，覆盖渐进过零、结束/唤醒时取消强档尾随脉冲，以及 DDC 响应连接选择；源码共 60 项 XCTest。
- 本源码包已通过仓库结构、关键不变量、隐私、Shell 语法与空白检查。
- 发布前仍须由 OpenClaw 在 macOS 完成 Xcode 测试、Universal 2 检查、触觉真机检查及真实多显示器 DDC 验证。

SHA-256: `3551d542e43c2a8f0ce7022224d653841f414039b94a5ec0b8a6a43afdbee3ac`

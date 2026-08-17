[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文版**](#zh)

# EdgeControl 1.5.0

Three haptic-strength profiles and a denser, genuinely frosted compact HUD.

## New

- Haptic feedback now offers Light, Standard, and Strong. Standard preserves the original 2% alignment feel, Light uses subtler 4% ticks, and Strong uses the firmer public AppKit generic pattern at 2%.
- Existing installs keep their haptic on/off preference and default to Standard. The selected profile is pinned for each gesture.
- The unsupported private actuator remains disabled; no new permission is required.

## HUD

- The HUD is reduced to 144×40 (212×40 for errors).
- A capsule-clipped active `.hudWindow` visual-effect view supplies real blur, with a 52% semantic veil, subtle tint, highlight border, and tuned shadow.
- Dual AppKit/SwiftUI clipping prevents rectangular backdrop leakage. Reduce Transparency and Reduce Motion remain supported.

## Validation status

- Repository guards, shell syntax, and diff checks pass; the source suite contains 55 XCTest methods.
- Xcode build/tests and physical comparison of all three haptic profiles and the HUD over light/dark content remain required before publishing.
- AppKit exposes feedback patterns rather than numeric amplitude, so physical feel may vary by trackpad.

---

<h2 id="zh">中文版</h2>

# EdgeControl 1.5.0

新增三档触觉反馈，并将精简 HUD 改为更凝实的真实磨砂效果。

## 新功能

- 触觉反馈新增轻、标准、强三档：标准档保留原有每 2% 一次的 alignment 手感，轻档改为更稀疏的 4% 轻震，强档使用每 2% 一次、体感更强的公开 AppKit generic 模式。
- 升级用户保留原有触觉开关，档位默认标准；每次手势激活时锁定档位。
- 未验证的私有触控板执行器继续禁用，不增加任何权限。

## HUD

- 正常 HUD 缩小到 144×40，错误状态为 212×40。
- 使用严格裁切在胶囊内的 `.hudWindow` 系统模糊层，再叠加 52% 动态雾面遮罩、轻微色调、高光描边和重新调整的阴影。
- AppKit 与 SwiftUI 双重裁切避免矩形底板泄漏；继续支持“降低透明度”和“减少动态效果”。

## 验证状态

- 仓库检查、Shell 语法和 diff 检查已通过；源码共 55 项 XCTest。
- 发布前仍须在 macOS 完成 Xcode 构建/测试，并分别检查三档触感及 HUD 在明暗背景上的效果。
- AppKit 只提供反馈模式而非数字振幅，因此不同触控板的体感可能不同。

SHA-256: `839368c254462d9826329d8bf8304b014eff255eb83f65b3b0d4d6766873392b`

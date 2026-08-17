[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文版**](#zh)

# EdgeControl 1.3.1

Brightness-backend reliability fix for MacBooks without an external display.

## Fixed

- A transient built-in display enumeration failure no longer routes brightness control to External DDC when DDC is disabled or unavailable.
- Failed CoreGraphics display-list queries preserve the last known built-in display ID; a successful external-only list still clears it for clamshell mode.
- Each brightness gesture pins the backend selected at activation, preventing display notifications from switching a gesture between the built-in panel and DDC.
- Display reconfiguration and DDC setting changes safely end an in-flight brightness session before refreshing backends; volume gestures are unaffected.
- Gesture start retries built-in display discovery before considering the explicitly enabled DDC fallback.
- A built-in-only Mac no longer reports `No external DDC display is available`, even if the experimental toggle was previously enabled but no DDC connection exists.

## Tests and documentation

- Five brightness-routing regressions cover disabled-DDC isolation, built-in refresh recovery, valid DDC fallback, per-gesture backend pinning, and transient display-list failure retention.
- The source suite now contains 40 XCTest methods.
- Release validation instructions and a separate static bug audit are included in the source package.

## Validation status

- Source-side repository guards, shell syntax, and diff checks pass. Xcode tests, Release/Universal 2 builds, and physical brightness regression remain to be run on macOS before publishing.
- External Magic Trackpad, external DDC, Intel runtime, Developer ID signing, and notarization remain unverified. External DDC is still experimental and disabled by default.

---

<h2 id="zh">中文版</h2>
# EdgeControl 1.3.1

修复没有外接显示器时偶发的亮度后端路由错误。

## 已修复

- 内屏枚举瞬时失败时，不再在 DDC 未启用或不可用的情况下错误调用 External DDC。
- CoreGraphics 显示器列表查询失败时保留最后一次有效的内屏 ID；若查询成功且确实只有外屏，则仍会为合盖模式正确清空。
- 每次亮度手势锁定激活时选中的后端，防止显示器通知让同一手势在内屏与 DDC 之间切换。
- 显示器重配置或修改 DDC 开关前会先安全结束当前亮度会话，再刷新后端；音量手势不受影响。
- 手势开始时会重新尝试发现内屏，之后才考虑用户明确开启的 DDC 回退。
- 仅使用内屏时不再错误显示 `No external DDC display is available`；即使实验性开关曾开启，只要没有真实 DDC 连接也不会误报。

## 测试与文档

- 新增 5 项亮度路由回归测试：DDC 关闭隔离、内屏刷新恢复、合法 DDC 回退、单手势后端锁定及瞬时显示列表失败保留。
- 当前源码共包含 40 项 XCTest。
- 源码包已加入发布验证说明和独立静态 bug 审计。

## 验证状态

- 源码侧仓库守卫、Shell 语法和 diff 检查已通过；发布前仍须在 macOS 上运行 Xcode 测试、Release / Universal 2 构建及亮度真机回归。
- 外接 Magic Trackpad、外接 DDC、Intel 真机、Developer ID 签名与公证仍未验证。外接 DDC 仍为默认关闭的实验性功能。

SHA-256: `8fe3915117a989421f2f03e9985f6f2a4d60d5b1654fbf80ddb22da793136050`

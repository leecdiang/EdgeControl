[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文版**](#zh)

# EdgeControl 1.4.0

Independent adjustment speed and privacy-preserving false-touch protection.

## New

- Adjustment speed is now an independent three-level setting: Precise (`0.50×`), Standard (`0.70×`), or Fast (`0.95×`). It affects only post-activation value gain.
- False-touch protection is independently selectable as Strong, Standard, or Light. The profiles combine 600/350/200ms typing windows with narrow/standard/wide physical edge-birth ranges.
- Strong uses 0.6%/1.2% left/right entry strips, Standard preserves 0.8%/1.5%, and Light uses 1.0%/1.9%. The measured left/right asymmetry is retained.
- Existing continuous-sensitivity preferences migrate to the nearest adjustment-speed preset.
- EdgeControl queries only the elapsed time since the last Quartz key-down event. It does not install a keyboard event tap, inspect key values, or store keyboard activity.
- Recent typing rejects idle or pre-activation edge contacts until every finger lifts, preventing a resting palm from activating after the timer expires.
- Active volume or brightness gestures are never interrupted by the typing guard.
- Adjustment speed is pinned when a gesture activates, preventing a settings change from causing a mid-gesture value jump. Changing admission settings while a finger is down discards that lifecycle until lift.
- The existing optional lower-half filter remains independent.

## Reliability

- Includes the 1.3.1 built-in-brightness routing fix: a transient panel-enumeration failure no longer sends a built-in-only Mac to External DDC.
- Brightness gestures pin their activation backend; display changes and DDC setting changes safely end only an in-flight brightness session before refresh.

## Tests and documentation

- Twelve new regressions cover typing rejection/latching, Active continuity, three protection boundaries, asymmetric edge-profile admission, hard-rule invariance, speed gain, legacy migration, invalid preferences, and invalid elapsed-time handling.
- The source suite now contains 52 XCTest methods.
- Release validation instructions and a static audit are included in the source package.

## Validation status

- Source-side repository guards, shell syntax, and diff checks pass. Xcode tests, Release/Universal 2 builds, physical typing regression, and clean-account permission checks remain required before publishing.
- External Magic Trackpad, external DDC, Intel runtime, Developer ID signing, and notarization remain unverified. External DDC is still experimental and disabled by default.

---

<h2 id="zh">中文版</h2>
# EdgeControl 1.4.0

新增彼此独立的调节速度与隐私型误触保护。

## 新功能

- 调节速度改为独立三档：精细（`0.50×`）、标准（`0.70×`）、快速（`0.95×`），只影响激活后的数值增益。
- 误触保护独立分为强、标准、轻，分别组合 600/350/200ms 打字窗口与窄/标准/宽物理边缘出生范围。
- 强保护左右范围为 0.6%/1.2%，标准保留 0.8%/1.5%，轻保护为 1.0%/1.9%；继续保留真机测得的左右差异。
- 旧版连续灵敏度自动迁移到最接近的调节速度档。
- EdgeControl 只查询距离最近一次 Quartz 按键按下事件经过了多久；不会安装键盘事件监听器、读取具体按键或保存键盘活动。
- 最近打字会拒绝空闲或激活前的边缘触点，并锁存到所有手指抬起，避免手掌停留到计时结束后突然激活。
- 已经激活的音量或亮度手势不会被打字保护中断。
- 手势激活时锁定调节速度，设置变化不会造成中途数值跳变；有手指按下时修改准入设置，该触点会一直丢弃到抬手。
- 原有“仅从下半部分开始”仍可独立选择。

## 可靠性

- 包含 1.3.1 的内屏亮度路由修复：内屏枚举瞬时失败时，仅使用内屏的 Mac 不再被错误路由到 External DDC。
- 亮度手势锁定激活时后端；显示器变化或 DDC 设置变化时，只安全结束正在进行的亮度会话，再刷新后端。

## 测试与文档

- 新增 12 项回归，覆盖打字拒绝与锁存、Active 连续性、三档保护边界、左右边缘档位准入、硬规则不变性、速度增益、旧值迁移、异常偏好及无效时间处理。
- 当前源码共包含 52 项 XCTest。
- 源码包已加入发布验证说明和静态审计。

## 验证状态

- 源码侧仓库守卫、Shell 语法和 diff 检查通过；发布前仍须完成 Xcode 测试、Release / Universal 2 构建、打字真机回归和干净账户权限检查。
- 外接 Magic Trackpad、外接 DDC、Intel 真机、Developer ID 签名与公证仍未验证。外接 DDC 仍为默认关闭的实验性功能。

SHA-256: `OPENCLAW_REPLACE_WITH_FINAL_DMG_SHA256`

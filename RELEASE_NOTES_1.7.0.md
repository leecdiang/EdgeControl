[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文版**](#zh)

# EdgeControl 1.7.0

Adds a frosted-glass Settings window that matches the menu-bar popover, slightly wider edge entry strips for more forgiving activation, a new Morandi (muted slate blue) HUD palette, and a Homebrew cask so the app can be installed with `brew install`.

## Added

- **Frosted Settings window.** The Settings window now uses the same full-window material as the first-level menu-bar popover: a transparent title bar over a `popover`-material backdrop with translucent cards. The window stays resizable and movable, and it respects the Reduce Transparency accessibility setting automatically.
- **Morandi HUD palette.** A fourth color style under Settings > Feedback > HUD: muted slate blues — a dusty blue for volume, a misty light blue for brightness — keeping the glass neutral like the other palettes.
- **Homebrew install.** The app is published as a cask in the `leecdiang/edgecontrol` tap:

  ```
  brew tap leecdiang/edgecontrol
  brew install --cask edgecontrol
  ```

  Because EdgeControl is ad-hoc signed and not notarized, Gatekeeper will quarantine the first launch; use `brew install --cask --no-quarantine leecdiang/edgecontrol/edgecontrol` or right-click > Open on the first run.

## Changed

- **Slightly wider edge entry strips.** All three false-touch-protection presets widen the physical birth range a little so deliberate edge ingresses trigger more reliably:

  | Preset | Left strip | Right strip |
  |---|---|---|
  | Strong | 0.6% → 0.7% | 1.2% → 1.4% |
  | Standard | 0.8% → 0.9% | 1.5% → 1.7% |
  | Light | 1.0% → 1.2% | 1.9% → 2.1% |

  The asymmetry between left and right (and the palm-rejection rules: directionality, zero-cross cancellation, typing suppression) is unchanged.

## Tests

- 68 XCTest methods (67 carried over plus a new Morandi palette persistence test; the false-touch strip assertions were updated to the new widths).

## Known limitations (unchanged)

- External DDC remains experimental and off by default; it must not be treated as a formally supported feature.
- If the default audio output device changes mid-gesture, volume changes can still be applied relative to the old device's initial value.
- External Magic Trackpad selection, Intel runtime, other macOS versions, and clean-machine Gatekeeper remain hardware/environment dependent.

SHA-256: `2a7dd2b5c9416432f5aeb7aedde0cf85eca0eeb6832dddbe4ce101606bfd6ffb`

---

<h2 id="zh">中文版</h2>

# EdgeControl 1.7.0

设置窗口改为与菜单栏一级弹窗一致的磨砂玻璃效果；两侧边缘出生条略微放宽，激活更宽容；新增莫兰迪蓝 HUD 配色；并发布 Homebrew cask，支持 `brew install` 安装。

## 新增

- **磨砂玻璃设置窗口。** 设置窗口现在使用与菜单栏一级弹窗相同的整窗材质：透明标题栏 + `popover` 材质背景 + 半透明卡片。窗口仍可缩放、可拖动，并自动跟随系统「减弱透明度」辅助功能设置。
- **莫兰迪蓝 HUD 配色。** 设置 > 反馈 > HUD 新增第四档配色：低饱和灰蓝系——音量用灰蓝、亮度用雾蓝，玻璃与文字保持中性，与其他配色一致。
- **Homebrew 安装。** 应用以 cask 形式发布在 `leecdiang/edgecontrol` tap 中：

  ```
  brew tap leecdiang/edgecontrol
  brew install --cask edgecontrol
  ```

  由于 EdgeControl 是 ad-hoc 签名且未公证，Gatekeeper 会隔离首次启动；可用 `brew install --cask --no-quarantine leecdiang/edgecontrol/edgecontrol`，或首次运行时右键 > 打开。

## 变更

- **两侧入口条略微放宽。** 三档误触保护的物理出生范围都放宽了一点点，让有意的边缘手势更容易触发：

  | 档位 | 左入口条 | 右入口条 |
  |---|---|---|
  | 强保护 | 0.6% → 0.7% | 1.2% → 1.4% |
  | 标准 | 0.8% → 0.9% | 1.5% → 1.7% |
  | 轻保护 | 1.0% → 1.2% | 1.9% → 2.1% |

  左右不对称（以及防误触规则：方向一致性、过零取消、打字抑制）保持不变。

## 测试

- 68 项 XCTest（67 项延续 + 新增莫兰迪配色持久化测试；入口条宽度断言已更新为新值）。

## 已知限制（不变）

- 外接 DDC 仍为实验性且默认关闭，不应视为正式支持的功能。
- 手势中途切换默认音频输出设备时，音量仍可能按旧设备起始值应用。
- 外接 Magic Trackpad 选择、Intel 运行时、其他 macOS 版本与干净环境 Gatekeeper 仍依赖硬件/环境验证。

SHA-256: `2a7dd2b5c9416432f5aeb7aedde0cf85eca0eeb6832dddbe4ce101606bfd6ffb`

[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文版**](#zh)

# EdgeControl 1.7.1

A follow-up polish release on top of 1.7.0: it fixes the frosted Settings window (the glass now renders as the window's real background instead of showing through as transparent), widens the edge entry strips further, and lightens the Morandi volume color to a soft baby blue.

## Fixed

- **Frosted Settings window renders correctly.** The 1.7.0 window could show a fully transparent background because the visual effect lived inside SwiftUI's `.background`, which does not paint reliably in a transparent titled window. The glass is now the window's actual base content view (an `NSVisualEffectView` with `popover` material behind the SwiftUI content), matching the menu-bar popover.

## Changed

- **Edge entry strips widened further.** All three false-touch-protection presets get a larger birth range so deliberate edge ingresses trigger reliably:

  | Preset | Left strip | Right strip |
  |---|---|---|
  | Strong | 0.7% → 1.0% | 1.4% → 1.8% |
  | Standard | 0.9% → 1.2% | 1.7% → 2.2% |
  | Light | 1.2% → 1.5% | 2.1% → 2.6% |

- **Morandi volume color lightened.** The volume accent in the Morandi palette is now a soft baby blue (`#A3C1DE`) instead of the darker dusty slate blue.

## Tests

- 68 XCTest methods; false-touch strip assertions updated to the new widths and boundary cases.

## Known limitations (unchanged)

- External DDC remains experimental and off by default; it must not be treated as a formally supported feature.
- If the default audio output device changes mid-gesture, volume changes can still be applied relative to the old device's initial value.
- External Magic Trackpad selection, Intel runtime, other macOS versions, and clean-machine Gatekeeper remain hardware/environment dependent.

SHA-256: `e584594553e20770994246368599e5b25102d305ddfeebef173337d8224959b8`

---

<h2 id="zh">中文版</h2>

# EdgeControl 1.7.1

1.7.0 的跟进打磨版：修复磨砂设置窗口（玻璃现在作为窗口真实背景渲染，不再透底变透明）、进一步放宽边缘入口条、并把莫兰迪配色的音量色提亮为柔和的婴儿蓝。

## 修复

- **磨砂设置窗口正常渲染。** 1.7.0 中窗口可能整体透底变透明：原因是视觉效果放在 SwiftUI 的 `.background` 里，在透明标题窗口中渲染不可靠。现在玻璃是窗口真正的底层内容视图（`popover` 材质的 `NSVisualEffectView` 垫在 SwiftUI 内容后面），与菜单栏弹窗一致。

## 变更

- **边缘入口条进一步放宽。** 三档误触保护的出生范围再次加大，让有意的边缘手势更可靠地触发：

  | 档位 | 左入口条 | 右入口条 |
  |---|---|---|
  | 强保护 | 0.7% → 1.0% | 1.4% → 1.8% |
  | 标准 | 0.9% → 1.2% | 1.7% → 2.2% |
  | 轻保护 | 1.2% → 1.5% | 2.1% → 2.6% |

- **莫兰迪音量色提亮。** 莫兰迪配色的音量强调色从偏深的灰蓝改为柔和的婴儿蓝（`#A3C1DE`）。

## 测试

- 68 项 XCTest；入口条断言已按新宽度与边界用例更新。

## 已知限制（不变）

- 外接 DDC 仍为实验性且默认关闭，不应视为正式支持的功能。
- 手势中途切换默认音频输出设备时，音量仍可能按旧设备起始值应用。
- 外接 Magic Trackpad 选择、Intel 运行时、其他 macOS 版本与干净环境 Gatekeeper 仍依赖硬件/环境验证。

SHA-256: `e584594553e20770994246368599e5b25102d305ddfeebef173337d8224959b8`

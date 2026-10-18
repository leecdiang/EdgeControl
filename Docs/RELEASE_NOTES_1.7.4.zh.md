# EdgeControl 1.7.4

以登录项、HUD 定位和更新偏好为主的可靠性版本。手势、触感、亮度与 DDC 行为未有意改动。

## 修复

- **登录项待审批。** 已注册但仍在系统设置中等待批准的登录项，不再被当作未注册。开关保持开启，关闭时正确注销；待审批时设置页显示「Open Login Items」直达入口。
- **登录项状态过期。** App 回到前台时重新读取服务状态，系统设置中的外部改动无需重启即可反映。
- **显示器变化后的 HUD 定位。** 当前显示器可用区域变化时会重新定位，而不只比较显示器 ID。
- **强制自动更新检查。** 不再每次启动设置 `automaticallyChecksForUpdates = true`；首次运行沿用 Info.plist 默认值，之后尊重用户在 Sparkle 中的选择。

## 测试

- 76 项 XCTest 全部通过。
- 仓库校验与 Universal 2 Release 构建通过。
- ad-hoc bundle 签名通过 `codesign --verify --deep --strict`。

## 已知限制（未变）

- 外部 DDC 为实验性功能，默认关闭。
- Intel 运行时、外接触控板、其他 macOS 版本、睡眠/唤醒、Sparkle 重启和全新机器 Gatekeeper 行为仍未验证。
- ad-hoc 签名，未公证。

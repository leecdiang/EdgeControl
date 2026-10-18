# EdgeControl 1.7.4

[English](#english) | [中文](#中文)

## English

### Reliability

- **Launch at login approval is handled correctly.** If the login item is registered but waiting for approval in System Settings, the switch now stays on instead of silently snapping back, and turning it off unregisters it properly. Settings shows a direct "Open Login Items" action when approval is pending.
- **Login item state stays current.** EdgeControl re-reads the service status whenever the app becomes active, so changes made in System Settings are reflected without a relaunch.
- **HUD placement follows display changes.** The overlay repositions when the usable area of the current display changes (resolution, arrangement, menu-bar or Dock changes), not only when the display ID changes.
- **Automatic update checks respect your choice.** The updater no longer forces automatic checks on at every launch; the Info.plist default still applies on first run.

### Verification

- 76/76 XCTest methods pass on the validation Mac.
- Repository validation and the Universal 2 Release build pass.
- The Release bundle contains `arm64` and `x86_64` slices and passes deep, strict ad-hoc signature verification.

### Downloads

- [EdgeControl-1.7.4-macOS.dmg](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.4/EdgeControl-1.7.4-macOS.dmg)
  SHA-256: `7236cc9efdf0ad4c23e291c19d3ae0bd95014db8e8403ac11ead2720cc32015a`
- [EdgeControl-1.7.4-macOS.zip](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.4/EdgeControl-1.7.4-macOS.zip)
  SHA-256: `d21829151dc8aa413984f9d0134c91b7ef60ea4f61444106d738ce0ed0e7c779`
- [appcast.xml](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.4/appcast.xml)
  SHA-256: `7a4ad9eb447331de313e6ad7cf89929fa23fd8eba67564b75742cf1b4457342e`

### Known limitations

- External DDC remains experimental and off by default.
- Physical audio-device switching, Sparkle relaunch, sleep/wake, and the full light/dark visual matrix still require local hardware or workflow validation.
- External trackpads, Intel runtime, other macOS versions, and clean-machine Gatekeeper behavior remain unverified.
- This build is ad-hoc signed. No Developer ID signature or notarization is claimed.

## 中文

### 可靠性

- **登录项待审批状态处理正确。** 当登录项已注册但还在「系统设置」中等待批准时，开关会保持开启，不再静默弹回；关闭时也能正确注销。待审批时设置页会显示「Open Login Items」直达按钮。
- **登录项状态保持最新。** App 每次回到前台都会重新读取服务状态，在系统设置里做的改动无需重启即可反映。
- **HUD 跟随显示器变化重新定位。** 当前显示器可用区域变化时（分辨率、排列、菜单栏或 Dock 变化）会重新定位，而不只比较显示器 ID。
- **自动更新检查尊重用户选择。** 不再每次启动强制开启自动检查；首次运行的默认值仍由 Info.plist 提供。

### 验证

- 验证机上 76/76 项 XCTest 全部通过。
- 仓库校验与 Universal 2 Release 构建通过。
- Release 包含 `arm64` 与 `x86_64` 切片，并通过 deep、strict 的 ad-hoc 签名校验。

### 下载

- [EdgeControl-1.7.4-macOS.dmg](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.4/EdgeControl-1.7.4-macOS.dmg)
  SHA-256: `7236cc9efdf0ad4c23e291c19d3ae0bd95014db8e8403ac11ead2720cc32015a`
- [EdgeControl-1.7.4-macOS.zip](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.4/EdgeControl-1.7.4-macOS.zip)
  SHA-256: `d21829151dc8aa413984f9d0134c91b7ef60ea4f61444106d738ce0ed0e7c779`
- [appcast.xml](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.4/appcast.xml)
  SHA-256: `7a4ad9eb447331de313e6ad7cf89929fa23fd8eba67564b75742cf1b4457342e`

### 已知限制

- 外部显示器 DDC 仍为实验性功能，默认关闭。
- 物理音频设备切换、Sparkle 重启、睡眠/唤醒以及完整明暗外观矩阵仍需本地硬件或流程验证。
- 外接触控板、Intel 运行时、其他 macOS 版本和全新机器上的 Gatekeeper 行为仍未验证。
- 本构建为 ad-hoc 签名，不声称 Developer ID 签名或公证。

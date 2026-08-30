# EdgeControl 1.7.3

[English](#english) | [中文](#中文)

## English

### UI stability

- Continuous gesture updates now reuse the current HUD presentation instead of repeatedly resizing, repositioning, and bringing the panel forward. This reduces visible tint and brightness jumps.
- HUD colors, the menu accent, and the Settings preview now use the same palette definitions.
- Settings keeps the native popover glass and adds a light neutral scrim to make the material more consistent across backgrounds.

### Reliability

- A user-level process lock ensures that only one EdgeControl instance owns the trackpad and related services. Duplicate launches exit quietly without interrupting the primary instance.
- A volume gesture now stays pinned to the output device on which it started. If that device disappears, the gesture ends instead of writing a value derived from the old device to a replacement device.

### Verification

- 76/76 XCTest methods pass on the validation Mac.
- Repository validation and the Universal 2 Release build pass.
- The Release bundle contains `arm64` and `x86_64` slices and passes deep, strict ad-hoc signature verification.
- Ten rapid launches and a second app copy with the same bundle identifier both leave the original instance running as the sole service owner.

### Downloads

- [EdgeControl-1.7.3-macOS.dmg](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.3/EdgeControl-1.7.3-macOS.dmg)
  SHA-256: `52f70ba2f019313f3116270a1b5d8ef96d3b6344ad7d88a381a670fdf0d6abcb`
- [EdgeControl-1.7.3-macOS.zip](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.3/EdgeControl-1.7.3-macOS.zip)
  SHA-256: `45055b6eb3e7a69381c563642da5cde570e8a202179a6946a0ea5674bbd507b8`
- [appcast.xml](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.3/appcast.xml)
  SHA-256: `6f678dbe2b88dbd363e3faeab0961ae20f3e2c0a56dfc2b4094b1bd0576d8ab1`

### Known limitations

- External DDC remains experimental and off by default.
- Physical audio-device switching, Launch at Login races, Sparkle relaunch, sleep/wake, and the full light/dark visual matrix still require local hardware or workflow validation.
- External trackpads, Intel runtime, other macOS versions, and clean-machine Gatekeeper behavior remain unverified.
- This build is ad-hoc signed. No Developer ID signature or notarization is claimed.

## 中文

### 界面稳定性

- 连续手势期间会复用当前 HUD，不再随每一帧重复调整尺寸、位置和窗口层级，减少颜色与明暗跳变。
- HUD 配色、菜单强调色和设置预览统一使用同一套颜色定义。
- 设置窗口保留原生 popover 磨砂材质，并加入轻量中性遮罩，让不同背景下的玻璃效果更稳定。

### 可靠性

- 新增用户级进程锁，只允许一个 EdgeControl 实例占用触控板和相关服务。重复启动会安静退出，不影响已经运行的主实例。
- 音量手势会固定使用开始时的输出设备。如果该设备中途消失，本次手势会结束，不会把基于旧设备计算的音量写入替代设备。

### 验证

- 验证机上 76/76 个 XCTest 方法全部通过。
- 仓库检查和 Universal 2 Release 构建通过。
- Release 包含 `arm64` 与 `x86_64`，并通过完整、严格的 ad-hoc 签名校验。
- 连续快速启动十次，以及从另一份相同 Bundle ID 的应用副本启动，最终都只保留原主实例占用服务。

### 下载

- [EdgeControl-1.7.3-macOS.dmg](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.3/EdgeControl-1.7.3-macOS.dmg)
  SHA-256：`52f70ba2f019313f3116270a1b5d8ef96d3b6344ad7d88a381a670fdf0d6abcb`
- [EdgeControl-1.7.3-macOS.zip](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.3/EdgeControl-1.7.3-macOS.zip)
  SHA-256：`45055b6eb3e7a69381c563642da5cde570e8a202179a6946a0ea5674bbd507b8`
- [appcast.xml](https://github.com/leecdiang/EdgeControl/releases/download/v1.7.3/appcast.xml)
  SHA-256：`6f678dbe2b88dbd363e3faeab0961ae20f3e2c0a56dfc2b4094b1bd0576d8ab1`

### 已知限制

- 外接显示器 DDC 仍为实验功能，默认关闭。
- 物理音频设备切换、登录项并发启动、Sparkle 重启、睡眠唤醒，以及完整的浅色/深色视觉矩阵仍需本地硬件或流程验证。
- 外接触控板、Intel、其他 macOS 版本和全新机器上的 Gatekeeper 行为尚未验证。
- 本版本使用 ad-hoc 签名，不宣称 Developer ID 签名或公证。

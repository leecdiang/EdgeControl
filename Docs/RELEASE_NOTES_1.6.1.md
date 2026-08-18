[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**中文版**](#zh)

# EdgeControl 1.6.1

A small reliability patch on top of 1.6.0: it fixes the experimental DDC brightness reply parsing, adds a complete ad-hoc bundle signature, guards stale touch frames across trackpad restarts, and syncs the documentation.

## Fixed

- DDC/CI Get VCP Feature replies for brightness are now parsed with the correct field offsets (`maximum` at +4/+5, `current` at +6/+7 relative to the `0x02` command byte, per the VESA layout). The previous code read one byte late, which could corrupt the brightness range or current value on external monitors. The parser now also validates the result code and the message checksum, and a leading destination byte is still accepted.
- The Release app now carries a complete ad-hoc bundle signature: both `arm64` and `x86_64` slices are signed and `_CodeSignature/CodeResources` is present. `Scripts/build_release.sh` re-signs the built app with `codesign --force --sign -` when no `DEVELOPMENT_TEAM` is configured.
- Touch frames queued before a trackpad stop/rescan/wake are dropped after the restart: each frame batch is tagged with a generation that is invalidated when the source is reopened, so stale frames can no longer enter a freshly reset gesture recognizer.
- Docs: Settings > System references updated to Settings > Devices, menu width updated to 304 pt, and released-version wording replaces pre-release wording.

## Tests

- Six new byte-fixture tests cover the standard reply layout, a leading destination byte, non-zero result codes, corrupt checksums, wrong VCP codes, and truncated replies. The suite contains 67 XCTest methods.

## Known limitations (unchanged)

- External DDC remains experimental and off by default; it must not be treated as a formally supported feature.
- If the default audio output device changes mid-gesture, volume changes can still be applied relative to the old device's initial value.
- External Magic Trackpad selection, Intel runtime, other macOS versions, and clean-machine Gatekeeper remain hardware/environment dependent.

SHA-256: `b087b4768c1cc6f5c3f67fdf66af0dde6d90095bca4bf2cd23756c6a3d55df07`

---

<h2 id="zh">中文版</h2>

# EdgeControl 1.6.1

1.6.0 之上的小型可靠性补丁：修复实验性 DDC 亮度应答解析、补完整 ad-hoc bundle 签名、在触控板重启后丢弃过期触摸帧，并同步文档。

## 修复

- DDC/CI 亮度（VCP 0x10）应答按正确字段偏移解析（相对 `0x02` 命令字节，maximum 在 +4/+5、current 在 +6/+7，符合 VESA 布局）。旧代码整体偏一字节，可能导致外接显示器亮度范围或当前值解析错误。解析器同时校验结果码与消息校验和，仍兼容可选的前导目标地址字节。
- Release 应用现在带完整 ad-hoc bundle 签名：`arm64` 与 `x86_64` 两个 slice 均签名，且存在 `_CodeSignature/CodeResources`。`Scripts/build_release.sh` 在未配置 `DEVELOPMENT_TEAM` 时会对构建产物执行 `codesign --force --sign -` 重签。
- 触控板停止/重扫/唤醒前排队的触摸帧，在重启后会被丢弃：每批帧带代数标记，源重新打开时代数失效，过期帧不再进入新识别的识别器。
- 文档：Settings > System 更新为 Settings > Devices，菜单宽度更新为 304 pt，“发布前”措辞改为已发布状态。

## 测试

- 新增 6 项字节级测试，覆盖标准应答布局、前导目标字节、非零结果码、校验和损坏、VCP 码不符与截断应答。测试集共 67 项 XCTest。

## 已知限制（不变）

- 外接 DDC 仍为实验性且默认关闭，不应视为正式支持的功能。
- 手势中途切换默认音频输出设备时，音量仍可能按旧设备起始值应用。
- 外接 Magic Trackpad 选择、Intel 运行时、其他 macOS 版本与干净环境 Gatekeeper 仍依赖硬件/环境验证。

SHA-256: `b087b4768c1cc6f5c3f67fdf66af0dde6d90095bca4bf2cd23756c6a3d55df07`

# EdgeControl

> 两个边缘，两种控制，仅此而已。

[![Downloads](https://img.shields.io/github/downloads/leecdiang/EdgeControl/total?style=flat-square&label=Downloads&color=2ea44f)](https://github.com/leecdiang/EdgeControl/releases) · [**English**](README.md)

<img src="assets/icon-512.png" alt="EdgeControl 图标" width="128" height="128" align="left" style="margin-right: 16px;">

EdgeControl 是一个开源、完全离线的 macOS 菜单栏应用：把 MacBook 触控板上**从机身滑入边缘**的刻意手势，映射为连续的音量 / 亮度调节。

## 用法

**手势从机身开始，而不是从触控板上开始。**

1. 用一根手指，**从 MacBook 机身边缘（触控板外侧）滑入触控板的左边缘或右边缘**——手指从触控板外部进入
2. 滑入后**立即沿着边缘向上或向下滑动**
3. 左边缘和右边缘可独立设置：关闭 / 音量 / 亮度
4. 手指**先在触控板内部落下**的，永远不触发——即使之后滑到边缘也一样

这不是普通的"碰到边缘再上下滑动"：contact 必须**出生在极窄的边缘入口条内**（只有从机身滑入才可能），并在短时间内建立明确的纵向意图。内部出生的 contact 在整个生命周期内被永久拒绝；任何多指帧都会拒绝整个生命周期，直到所有手指抬起。

## 状态

2026-08-16/17 在 macOS 26.5（Apple Silicon MacBook Air）上完成真机验证。逐项 PASS/FAIL 矩阵见 [BUILD_REPORT.md](BUILD_REPORT.md)，识别器调参依据见 [Docs/GestureTuning.md](Docs/GestureTuning.md)。

手势识别、数值映射、档位与设置层由 26 个单元测试覆盖。依赖未公开 macOS ABI 的代码全部通过 `dlopen`/`dlsym` 动态加载，符号缺失时优雅降级（该功能不可用，应用照常运行），而不是启动崩溃。

## 功能

- 物理左 / 右边缘滑入识别
- 左右边缘独立分配：关闭 / 音量 / 亮度
- 主开关、音量、亮度、触觉反馈、HUD、灵敏度、登录启动、外接显示器 DDC 等设置
- 从手势激活值开始的连续数值映射（触控板全高对应 0–100% 全范围）
- CoreAudio 音量控制（默认输出设备变化自动重解析、不支持设备有处理）
- 运行时动态加载 DisplayServices 控制内屏亮度
- 可选、隔离的 DDC/CI VCP `0x10` 外接显示器后端（实验性，默认关闭）
- 激活震动 + 5% 档位轻震（迟滞 + 频率限制）
- 仅在手势进入 `Active` 后冻结指针；应用退出时系统自动恢复指针关联
- 自定义非激活型 AppKit/SwiftUI HUD
- `LSUIElement` 菜单栏应用，无 Dock 图标
- 合成手势测试；识别器测试无需真实触控板
- 无账号、无网络、无分析、无遥测、无后端

## 环境要求

- 已在 macOS 26.5（Apple Silicon MacBook Air）验证。其他 macOS 版本与 Intel 未测试——视为实验性。
- 验证使用 Xcode 26.x；项目也可用 Xcode 15+ 构建（部署目标 macOS 13）。
- 需要内置 Force Touch 触控板才能获得预期体验。

私有接口可能随系统版本与硬件而变化。外接显示器 DDC 支持为实验性，默认关闭。

## 构建

```bash
./Scripts/build_release.sh test
./Scripts/build_release.sh build
```

本地编译时若没有 `DEVELOPMENT_TEAM`，脚本会关闭代码签名。本机（无 Developer ID 证书）为 ad-hoc 签名；正式发布路径见 [Docs/NOTARIZATION.md](Docs/NOTARIZATION.md)。

## 打包拖拽安装 DMG

```bash
./Scripts/package_dmg.sh \
  ./build/DerivedData/Build/Products/Release/EdgeControl.app \
  ./dist/EdgeControl-1.1.0-macOS.dmg
```

脚本只使用 macOS 自带工具（`hdiutil`、Finder/AppleScript、`codesign`、`xcrun`）。左侧 `EdgeControl.app`、右侧 `Applications` 软链，随后转换为压缩只读 DMG。已验证布局：App 在 (145,175)、Applications 在 (410,175)、图标 104px。

## 手势模型

已调优参数（依据见 [Docs/GestureTuning.md](Docs/GestureTuning.md)）：

| 参数 | 值 | 说明 |
| --- | ---: | --- |
| 入口条（左缘） | 0.8% | 出生点必须在此；内部出生永久拒绝 |
| 入口条（右缘） | 1.5% | 本机右缘出生点实测 x≈0.985–1.0 |
| 控制走廊 | 8% | 离开走廊即取消手势 |
| 最小纵向行程 | 1.5% | 需在入口时限内出现 |
| 方向一致性 | 0.75 | 排除打字时手掌的抖动+漂移模式 |
| 入口时限 | 800 ms | 为"先停靠再发力"的真实滑入调优；超过即不触发 |
| 过零反向取消 | — | 会话漂回起点（净位移变号）时取消，往返/微调不受影响 |

状态机：`idle → entryCandidate → entryConfirmed → active`。内部出生、错误初始方向、超时、身份变化、离开走廊、多指都会产生当前生命周期的终态拒绝；`multiTouchRejected` 在手指从两根变一根后保持锁存，直到出现空帧才复位。

## 权限

本机已验证：**不需要任何 TCC 权限**（无需辅助功能、输入监控、屏幕录制、完全磁盘访问）——以 `LSUIElement` 菜单栏应用运行时实测。其他 macOS 版本需重新验证。

## 隐私与联网

EdgeControl 没有任何联网代码、遥测、分析、账号体系或后端，不会持久化触摸轨迹。Debug 配置定义了 `EDGE_DEBUG_LOGGING` 会打印触点诊断；Release 不定义该宏（已通过二进制检查确认）。

## 私有 API 与分发

EdgeControl 使用未公开/私有的 macOS 接口，不适合上架 Mac App Store，预期分发渠道是签名并公证的 GitHub Release DMG。私有框架通过 `dlopen`/`dlsym` 打开，缺失符号视为功能不可用而非致命错误。

EdgeControl 与 Apple Inc. 无关。

## 干净室声明

本实现为独立编写。未复制 Verge、Slidr、EdgeBar、Sleight、MonitorControl 或任何 GPL 代码。提及产品名称仅为生态背景。见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 许可证

MIT。见 [LICENSE](LICENSE)。

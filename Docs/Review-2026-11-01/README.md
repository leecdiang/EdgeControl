# EdgeControl 1.7.5 完整代码审查

审查日期：2026-11-01（Asia/Shanghai）。结论：**发现 5 项 P2 功能问题、1 项 P3 文案问题；未发现已证实的 P0/P1 问题。** “未发现”不等于不存在；本次没有完成全部硬件与系统组合的动态验证。

## 基线与覆盖

- GitHub main：`da3030a4172a9df3a21f1560bdd074e3b4258968`。
- 本地审查起点：`bac4327`；两者 tree 均为 `780e2625382e290c44833ecde8a9dcfb77bc268e`。
- 已安装：`/Applications/EdgeControl.app`，1.7.5 / build 11；本轮 `codesign --verify --deep --strict` 通过。
- 全部应用代码：27 个 Swift 文件、1 个 C 文件、2 个头文件。另检查 6 个测试文件、构建/打包/发布/安装脚本、Xcode 项目、scheme、依赖锁定、Info.plist、entitlements 和 CI。共 48 个代码/配置文件、7,976 行，逐文件 SHA-256 见 [coverage.json](coverage.json)。
- 另外比对架构、隐私、发布验证与公证文档；第三方 Sparkle 仅审查集成、公开接口契约与锁定版本，未声称完整审计其全部实现。图标和历史版本说明不属于业务代码审查范围。
- 采用调用链追踪、状态生命周期检查、边界值与故障注入、C 静态分析、实际源码隔离探针。没有为了审查而触发物理亮度、音量、震动或光标锁定。

## F1 · P2：排队的旧触控帧仍会执行硬件控制

**位置：** [EdgeControlAppModel.swift:269](https://github.com/leecdiang/EdgeControl/blob/da3030a4172a9df3a21f1560bdd074e3b4258968/EdgeControl/App/EdgeControlAppModel.swift#L269)，同文件 291–304、376–378；`TrackpadManager.swift` 的 receive/deliver。

每帧先进入串行处理队列，再创建独立 MainActor Task；没有有界缓冲或过期淘汰。`consume` 把 `lastTouchFrameUptime` 更新为**消费时刻**，没有记录或检查回调收到该帧的时刻。看门狗也在 MainActor 上运行。

**触发条件：** 主线程被 UI 或同步系统调用阻塞，或输入消费速率低于产生速率。恢复后旧帧仍可能触发新会话和数值写入；手指已经抬起，但对应 lift 尚在队列后方时尤其明显。同步 DDC I/O 也是这条路径的一部分。不能据此断言用户已经遇到该现象。

**复现：** 对实际 AppModel 源码只开放 `consume` 访问权限并添加只读观测属性，将硬件依赖替换为记录器；输入相对当前 uptime 已过去约 5 秒的 birth / activation / movement，仍写出 `0.542` 并保留 session。该探针验证“旧帧被接受”，没有假称测量了真机队列积压概率或持续时间。

**修复方向：** 在回调入口附加独立的单调接收时间和序号，按实际年龄拒绝过期帧；使用有界、有序的消费机制。淘汰帧时必须保留或显式重建多指、lift 和取消边界，不能直接只保留最后一个触点。把可能阻塞的设备 I/O 移出主线程，并以会话代号阻止取消后的写入。

## F2 · P2：关闭总开关不能立即结束静止手势，光标可能继续锁定

**位置：** [EdgeControlAppModel.swift:392](https://github.com/leecdiang/EdgeControl/blob/da3030a4172a9df3a21f1560bdd074e3b4258968/EdgeControl/App/EdgeControlAppModel.swift#L392)，同文件 468–471；`AppSettings.swift:154`、`GestureEngine.swift:307`、两处 UI 的 masterEnabled 直接绑定。

总开关只在 `beginSession` 和 `changeSession` 中检查，设置变化没有立即调用 `finishSession`。1.7.5 正确地忽略了横向/静止输入的 changed 事件，但这也意味着：活动手势中关闭总开关，然后手指保持相同 y，session 和光标锁定会一直保留。持续触控回调仍刷新看门狗时间，因此 750ms 看门狗不会补救。

**复现：** 激活会话后设置 `masterEnabled=false`，送入 120 个相同 y 的触点帧，输出 `session=true cursorFrozen=true`。正常 lift、下一次纵向移动或真正的回调静默仍能结束会话；不是声称永久无法恢复。

**修复方向：** 将总开关及当前动作禁用纳入统一设置变更处理，立即结束会话、恢复光标、取消待发震动；重新启用时要求已有触点抬起，避免中途恢复控制。HUD 关闭也应立即调用已有的 `hideImmediately`。

## F3 · P2：DDC 回包校验使用错误的消息边界，正确包被拒绝

**位置：** [ECPrivateAPIBridge.c:810](https://github.com/leecdiang/EdgeControl/blob/da3030a4172a9df3a21f1560bdd074e3b4258968/EdgeControl/PrivateFrameworks/ECPrivateAPIBridge.c#L810)，`EdgeControlTests/SettingsTests.swift:443–459`。

解析器从 `0x02` 命令字节开始只计算 9 字节 XOR，接受结果 0，或额外 XOR `0x6F` 后为 0。正常 DDC/CI 回复包含 source 和 length，并采用虚拟主机地址 `0x50` 参与校验；现有算法遗漏了这些字段。现有测试也构造了相同的简化校验，因而测试全部通过仍无法保证真实设备兼容性。

**实际 C 源码复现：**

```text
正确完整回复：6e 88 02 00 10 00 00 64 00 32 f2
结果：accepted=0；应返回 brightness 50/100
仅把末字节改为错误的 44：accepted=1；应拒绝
```

测试直接编译仓库完整 C 桥接文件，只调用纯解析函数，没有进行 I2C 操作。

**影响范围：** 用户主动启用实验性外接 DDC、且系统能打开该显示器 I2C 通道时；内置 DisplayServices 亮度不经过这段代码。

**修复方向：** 按完整报文长度、地址、类型、VCP 和实际接收字节数解析并验签（此处为协议 checksum，不是加密签名）；以独立协议样本替换自洽但错误的测试构造器。不要继续扫描任意位置的 opcode 猜包。

**交叉核验：** [ddcctl 的 DDCRead 实现](https://github.com/kfix/ddcctl/blob/06c7ab6eba5b1c903678f8113a92cef990acaf90/src/DDC.c) 使用 11 字节回复并纳入头部。其 `replyAddress ^ replySubAddress` 即 `0x6F ^ 0x51 = 0x3E`，等价于回复地址字段 `0x6E` 与虚拟主机 `0x50` 的 XOR；不是本项目使用的 `0` 或 `0x6F`。

## F4 · P2：分声道音量控制会重置左右平衡

**位置：** [VolumeController.swift:45](https://github.com/leecdiang/EdgeControl/blob/da3030a4172a9df3a21f1560bdd074e3b4258968/EdgeControl/Actions/VolumeController.swift#L45)，同文件 62–75、volumeElements。

**触发条件：** 输出设备没有可用的 master scalar，采用左右声道标量，且左右原值不相等。读取把两声道取平均，写入却给两个声道同一个 scalar。微小的总体音量调整因此会覆盖用户的声道平衡。

**复现：** 实际 VolumeController 代码仅将四个 CoreAudio API 调用替换为内存驱动：`L=0.2, R=0.8`，读取 initial=0.5；目标增加 0.01 后得到 `L=0.51, R=0.51`。无需连接或修改真实声卡。

**修复方向：** 会话保存通道布局与比例，以统一增益缩放各通道并定义饱和/全零时的策略；同时处理部分通道写失败，避免无意改变平衡。需增加非对称通道回归测试；当前 FakeVolumeBackend 只覆盖设备 ID 固定，不覆盖声道语义。

## F5 · P2：音量路径未拒绝非有限值，异常读取被转换成极值写入

**位置：** [VolumeController.swift:15](https://github.com/leecdiang/EdgeControl/blob/da3030a4172a9df3a21f1560bdd074e3b4258968/EdgeControl/Actions/VolumeController.swift#L15)，同文件 45–53、62，`ContinuousValueMapper.swift:12–13`。

亮度 session 已有 finite 校验，但音量 session 直接接受驱动读值。驱动返回 NaN 时，映射函数会把 NaN 经 min/max 转换为 0，后续把 0 写回设备；正无穷可映射为 1。

**复现：** 内存 CoreAudio 驱动返回两个 NaN，实际代码输出 `initial=nan mappedTarget=0.0 L=0.0 R=0.0`。

**条件与边界：** 这是异常驱动返回值的故障注入结果，未观察到用户当前输出设备返回 NaN，也不是对正常 CoreAudio 驱动行为的断言。

**修复方向：** 在音量读值聚合、session 初值与写入口验证 finite，非法值返回错误并结束手势，不能先 clamp 再验证。补 NaN/±∞、部分声道读取失败以及非法值不写硬件的测试。

## F6 · P3：“No network”承诺与已启用更新器不一致

**位置：** [SettingsView.swift:385](https://github.com/leecdiang/EdgeControl/blob/da3030a4172a9df3a21f1560bdd074e3b4258968/EdgeControl/UI/SettingsView.swift#L385)，`Docs/SECURITY_AND_PRIVACY.md:11`，`UpdateController.swift:18`，`Info.plist` 的 SUFeedURL/SUEnableAutomaticChecks。

About 仍写 “No network”，隐私文档还称没有 updater，但应用已经集成 Sparkle、默认启用自动检查，并通过 GitHub feed 更新。中英文 README 已正确描述更新联网，三处表述不一致。

**验证：** 静态调用链和随包 Sparkle 2.9.6 的 `SPUUpdater.h` 接口说明；本轮没有抓包，因此不声称观察到了某次网络请求或触控数据外传。

**修复方向：** 统一为“无账号、无遥测；仅更新检查联网”，设置页直接显示 Sparkle 保存的自动更新偏好。仓库校验脚本的字符串扫描也不能再把“offline-runtime guard passed”解释为没有网络依赖。

## 已检查但未升级为确定缺陷的事项

- 原 Control Center 故障：未找到可将其 12Hz 循环归因于 EdgeControl 的证据。绝对亮度写入没有合成亮度键，也没有本应用定时器重复写入端点。退出 EdgeControl 后仍发生，只能排除其持续运行是必要条件，不能独立证明此前从未触发系统异常。
- 震动冷却修复：重新编译实际 HapticEngine/DetentTracker，0/10/40/80ms 对应请求累计 1/1/2/2；新 activation 绕过 cooldown 为第 3 次。系统实际是否执行物理震动仍不在这个探针的可观测范围内。
- 显示器 session、float 精度亮度去重、失败写重试、非有限触点处理、候选/多指拒绝、光标恢复路径、通知生命周期、单实例锁、登录项状态、HUD 生命周期均已逐段检查。
- C 桥接依赖未公开 ABI；空 contacts 配正 count、未知 stride、缺失 unregister 符号和迟到旧设备回调等仍是硬件兼容性加固点，缺少真实回调证据，未混入本轮确定问题数量。
- DDC 的同步 I/O、总线选择和 ARM 时间单位仍需设备实测；本轮只确认 F3 的纯协议解析错误。
- 设置迁移通过“值是否等于注册默认值”推断是否持久化不严谨。多 AppSettings 实例且旧 sensitivity 残留时可能污染恢复结果；当前正式启动只有一个实例，因此列为测试/迁移加固建议，不宣称是日常启动必现 bug。
- 发布/安装已使用系统临时目录并分别验证 SHA-256、Ed25519、深度 codesign，成功安装也已核对。仍可改善失败后 staging 清理和中断恢复；本轮未发现足以否定已安装包完整性的问题。
- ad-hoc 签名和未公证属于既有发布限制，不因 `codesign --verify` 通过而变成 Developer ID/公证通过。

## 验证记录与限制

| 检查 | 本轮结果 |
|---|---|
| 仓库结构与原有校验脚本 | 通过；其输出统计为 90 个 XCTest 方法 |
| 已安装 app 版本与深度签名 | 1.7.5 / 11；通过 |
| C 桥接 `clang --analyze` | 退出 0，无分析器诊断；不是对私有 ABI 的证明 |
| AppModel 隔离探针 | F1/F2 均复现 |
| CoreAudio 内存驱动探针 | F4/F5 均复现 |
| 实际 C DDC 解析函数 | F3 正确帧拒绝、错误帧接受均复现 |
| 实际震动代码探针 | 冷却补偿与下一次激活回归通过 |
| 全应用 Swift 类型检查 | 被本环境 SwiftUI 宏插件 sandbox 错误阻断，见 typecheck.log；不归类为产品编译错误 |
| 90 项完整 XCTest / Universal2 打包 | 引用先前 CI run 41281336655 的通过结果；本轮没有重新完成全部 XCTest |

上述独立 Swift 探针编译时也输出了宏插件 sandbox 警告，但编译和运行均退出 0；音量探针的单线程全局模拟状态触发了一条 StrictConcurrency 警告，属于审查桩，未计为产品并发缺陷。保留完整输出，没有隐藏这些诊断。

[原始探针输出](results.txt) · [覆盖清单](coverage.json) · [原有 CI](https://github.com/leecdiang/EdgeControl/actions/runs/41281336655)

复现命令（Mac + Xcode；只在 build 下生成程序，依赖以记录器替换）：

```bash
python3 Docs/Review-2026-11-01/run_probes.py
```

该脚本的 bug 断言描述**审查基线的实际错误行为**，不是最终回归测试的正确预期。修复后应翻转预期并纳入正式 XCTest。AppModel 探针仅改变方法可见性、加入只读观测；音量探针只重命名四个 API 调用以接入内存驱动；DDC 与震动业务源文件原样编译。

建议修复顺序：先 F1/F2 的输入与会话生命周期，再 F5/F4 的音量边界，随后 F3 的实验性 DDC 与 F6 文案。每项应各自补充行为测试，之后跑完整 CI，再发布补丁版。本次审查未修改应用实现或已发布的 1.7.5 资产。

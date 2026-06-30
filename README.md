# ChargeHub

ChargeHub 是一个用 SwiftUI 编写的低频设备补电提醒应用，适合管理备用手机、相机、手柄、充电宝等不常用但需要定期补电的设备，避免长期闲置导致电池亏电。

项目同时包含：

- 主应用 `ChargeHub`
- 小组件扩展 `ChargeHubWidget`
- 共享模型与存储模块 `ChargeHubShared`

## 功能特性

- 记录设备名称、类型、上次充电日期、上次充电百分比、提醒周期、备注
- 按“已到期 / 即将到期 / 安全周期内”分类展示设备状态
- 支持一键记录今天已充电
- 支持本地通知提醒
- 支持 Widget 展示待补电设备
- 支持设备归档
- 支持设备库导入、导出、快速分享 JSON
- 支持通过 Deep Link 从 Widget 跳转到指定设备
- 日期展示和日期选择对中文更友好
- macOS 下提供菜单栏入口

## 技术栈

- Swift 5
- SwiftUI
- WidgetKit
- UserNotifications
- App Group 共享存储

## 项目结构

```text
ChargeHub/
├── ChargeHub/                # 主应用代码
│   ├── Models/
│   ├── Services/
│   ├── Store/
│   └── Views/
├── ChargeHubShared/          # 共享模型、Deep Link、存储
├── ChargeHubWidget/          # Widget 扩展
├── tools/                    # 项目辅助脚本
└── ChargeHub.xcodeproj       # Xcode 工程
```

## 运行环境

- Xcode 26+
- iOS Simulator SDK: `iphonesimulator26.2`（当前本地构建环境）
- macOS 开发环境

> 说明：项目使用 SwiftUI、WidgetKit 和本地通知能力，建议直接用最新稳定版 Xcode 打开。

## 本地运行

1. 克隆仓库

```bash
git clone https://github.com/jicklin/ChargeHub.git
cd ChargeHub
```

2. 用 Xcode 打开工程

```text
ChargeHub.xcodeproj
```

3. 选择 `ChargeHub` target 运行主应用
4. 如需调试小组件，选择 `ChargeHubWidget` target

## 数据存储

设备数据以 JSON 形式保存。

优先使用 App Group 容器：

- `group.lin.ChargeHub.shared`

如果 App Group 容器不可用，则回退到本地 `Application Support/ChargeHub/devices.json`。

## 通知机制

- 应用会在设备达到提醒周期后安排本地通知
- 到期当天开始提醒
- 若用户仍未记录充电，会继续安排后续补提醒
- 当前实现默认在上午 `09:00` 触发提醒

## 导入导出

在“设置”页可以：

- 导出设备库 JSON
- 导入设备库 JSON
- 通过系统分享面板快速分享设备库

导入支持两种模式：

- 替换当前数据
- 按设备 ID 合并导入

## Widget 与共享数据

Widget 会从共享存储读取设备数据，并展示：

- 已到期设备
- 即将到期设备
- 点击条目后通过 Deep Link 打开主应用对应设备详情

## Git 分支约定

当前仓库主分支为：

- `main`

## 开发说明

- 项目已包含 `.gitignore`，会忽略 Xcode 用户配置和构建产物
- 本地用户目录如 `xcuserdata/` 不会被提交
- 构建产物目录 `build/` 不会被提交

## 已验证命令

```bash
xcodebuild -project ChargeHub.xcodeproj -target ChargeHub -configuration Debug -sdk iphonesimulator build
```

## License

当前仓库未声明开源许可证。如需开源，建议补充 `LICENSE` 文件。

# Widget Extension 配置指南

本文档详细说明如何在 Xcode 中配置 Widget Extension Target、App Group、URL Scheme 和 App Intents。

---

## 1. 添加 Widget Extension Target

### 步骤

1. 在 Xcode 菜单栏选择 **File → New → Target…**
2. 在模板选择界面，选择 **Application Extension → Widget Extension**
3. 点击 **Next**
4. 填写配置：
   - **Product Name**: `ComicReaderWidget`
   - **Team**: 选择你的开发者团队
   - **Bundle Identifier**: 自动生成，应为 `com.comicreader.ComicReaderWidget`（主 App bundle id + `.Widget`）
   - **Language**: Swift
   - **Include Configuration App Intent**: **取消勾选**（我们的小组件不需要配置意图）
   - **Next**
5. 弹出 "Activate scheme?" 对话框时，选择 **Cancel**（不需要切换到 Widget scheme）

### 注意事项

- Widget Extension 有自己的 `@main` 入口（`ComicReaderWidgetBundle.swift`），与主 App 的 `@main`（`ComicReaderApp`）互不冲突
- Widget Extension 最低系统要求：iOS 14+（本项目部署目标 iOS 17+）

---

## 2. 配置 App Group

App Group 用于主 App 和 Widget Extension 之间共享 UserDefaults 和文件数据。

### 主 App Target 配置

1. 在 Xcode 左侧导航器中点击项目根节点
2. 选择主 App Target（`ComicReader`）
3. 切换到 **Signing & Capabilities** 标签页
4. 点击 **+ Capability** 按钮
5. 搜索并选择 **App Groups**
6. 点击 App Groups 下方的 **+** 按钮
7. 添加：`group.com.comicreader.shared`
8. 勾选该 App Group

### Widget Extension Target 配置

1. 选择 `ComicReaderWidget` Target
2. 切换到 **Signing & Capabilities** 标签页
3. 点击 **+ Capability** → **App Groups**
4. 同样添加并勾选：`group.com.comicreader.shared`

### 验证

- 两个 Target 都必须勾选同一个 App Group
- 如果使用自动签名，Xcode 会自动处理 entitlements
- 如果手动签名，需确保 entitlements 文件中包含 App Group

---

## 3. 将源文件添加到对应 Target

### 文件分配表

| 文件路径 | 主 App Target | Widget Extension Target |
|---|:---:|:---:|
| `Widget/ComicReaderWidgetBundle.swift` | ❌ | ✅ |
| `Widget/Shared/WidgetDataModel.swift` | ✅ | ✅ |
| `Widget/Shared/AppGroupData.swift` | ✅ | ✅ |
| `Widget/Shared/WidgetSyncManager.swift` | ✅ | ❌ |
| `Widget/ContinueReading/ContinueReadingWidget.swift` | ❌ | ✅ |
| `Widget/ContinueReading/ContinueReadingProvider.swift` | ❌ | ✅ |
| `Widget/ContinueReading/ContinueReadingView.swift` | ❌ | ✅ |
| `Widget/Stats/ReadingStatsWidget.swift` | ❌ | ✅ |
| `Widget/Stats/ReadingStatsProvider.swift` | ❌ | ✅ |
| `Widget/Stats/ReadingStatsView.swift` | ❌ | ✅ |
| `AppIntents/` 目录下所有文件 | ✅ | ❌ |
| `Services/AppIconManager.swift` | ✅ | ❌ |
| `ComicReaderApp.swift` | ✅ | ❌ |

### 操作方法

1. 在 Xcode 项目导航器中选中文件
2. 打开右侧 File Inspector（Utilities 面板）
3. 在 **Target Membership** 区域勾选对应 Target

### 重要提示

- `Shared/` 目录下的文件（`WidgetDataModel.swift`、`AppGroupData.swift`）必须同时勾选两个 Target
- `ComicReaderWidgetBundle.swift` 只属于 Widget Extension，**不要**勾选主 App Target
- `WidgetSyncManager.swift` 只属于主 App Target（它依赖 SwiftData）
- Widget Extension 中 **不要 import SwiftData**，所有数据通过 Codable 结构体传递

---

## 4. 配置 URL Scheme

URL Scheme 用于 Widget 点击和 Siri 快捷指令的深度链接跳转。

### 步骤

1. 选择主 App Target（`ComicReader`）
2. 切换到 **Info** 标签页
3. 找到 **URL Types** 区域（如果没有，右键 → Add URL Type）
4. 点击 **+** 添加：
   - **Identifier**: `com.comicreader.urlscheme`
   - **URL Schemes**: `comicreader`
   - **Icon**: 留空
   - **Role**: `Editor`

### 支持的深度链接格式

| URL | 作用 |
|---|---|
| `comicreader://continue` | 打开最近阅读的漫画 |
| `comicreader://comic/{uuid}` | 打开指定 ID 的漫画 |
| `comicreader://stats` | 打开阅读统计页 |

---

## 5. Info.plist 相关配置

### Widget 相关

Widget Extension 自身的 `Info.plist` 由 Xcode 自动生成，通常不需要手动修改。

### App Intents 相关

App Intents **不需要额外的 Info.plist 配置**。只要文件在主 App Target 中编译，系统会自动发现 `AppShortcutsProvider` 子类。

### 自定义图标相关

参考 `Resources/Info-Icons.plist` 文件，将 `CFBundleIcons` 配置合并到主 App 的 `Info.plist` 中。

---

## 6. App Intents 配置说明

App Intents **无需额外 Target**，直接在主 App Target 中编译即可。

### 已实现的 Intents

| Intent | 短语示例 | 说明 |
|---|---|---|
| `ContinueReadingIntent` | "继续阅读漫画" | 打开最近阅读的漫画 |
| `OpenComicIntent` | "打开漫画《XXX》" | 打开指定漫画（带参数选择） |
| `ShowReadingStatsIntent` | "阅读统计" | 显示今日阅读时长和连续天数 |

### 集成要点

1. `ComicReaderApp.modelContainer` 静态属性在 `init()` 中赋值，App 启动后即可用
2. App Intent 的 `perform()` 方法通过 `NotificationCenter` 通知主界面打开漫画
3. LibraryView 需监听 `Notification.Name.openComicFromIntent` 通知（见 `ComicReaderApp.swift` 中的注释说明）
4. `AppShortcutsProvider` 子类无需手动调用，系统自动注册

---

## 7. 自定义 App 图标配置步骤

### 7.1 创建图标资源

1. 打开 `Assets.xcassets`
2. 为每套备选图标创建 App Icon 集合：
   - `AppIcon-Dark`（深色版）
   - `AppIcon-Manga`（漫画风）
   - `AppIcon-Minimal`（简约风）
3. 每个集合中拖入 1024×1024 的 PNG 图标（生成方法见 `Resources/AppIcons/AppIconGeneration.md`）

### 7.2 配置 Info.plist

将 `Resources/Info-Icons.plist` 中的 `CFBundleIcons` 节点合并到主 App `Info.plist`。

### 7.3 集成设置入口

参考 `Resources/AppIconSettingsSnippet.md`，将代码片段添加到 `SettingsView.swift` 中（由 Organizer 统一接入）。

### 7.4 运行时切换

调用 `AppIconManager.shared.setIcon(option)` 即可切换图标，无需重启 App。

---

## 8. 常见问题排查

### Widget 不显示数据

1. 检查 App Group 是否在两个 Target 中都正确配置
2. 确认 `WidgetSyncManager.syncWidgetData()` 被调用（App 进入后台时自动调用）
3. 检查 `UserDefaults(suiteName:)` 的 group id 是否一致
4. Widget Extension 控制台日志：在 Widget scheme 下运行 Console 查看

### Widget 点击不跳转

1. 确认 URL Scheme 已配置（`comicreader`）
2. 检查 `widgetURL(_:)` 修饰符是否正确添加
3. 确认主 App 的 `onOpenURL` 已正确处理

### Siri 快捷指令不出现

1. 确认 `AppShortcutsProvider` 子类已编译到主 App Target
2. 重启设备或重新安装 App（系统缓存快捷指令）
3. 打开 Settings → Siri & Search → 检查 App 是否允许 Siri

### 图标切换失败

1. 检查 Info.plist 中 `CFBundleAlternateIcons` 的 key 名称是否与代码一致
2. 确认 Assets.xcassets 中的 App Icon 集合已正确命名
3. 备选图标名称不能为 nil（nil 表示恢复默认图标）

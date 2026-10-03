# 灵动岛与实时活动配置指南

## 功能说明

阅读漫画时，在灵动岛（Dynamic Island）和锁屏上显示：
- 漫画标题
- 当前页码 / 总页数
- 阅读进度条
- 已阅读时长
- 点击灵动岛可快速回到阅读器

## 配置步骤

### 1. Info.plist 配置

在主 App Target 的 Info.plist 中添加：

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

或在 Xcode 中：Target → Info → 添加 `NSSupportsLiveActivities` = `YES`

### 2. 添加 Widget Extension（如尚未添加）

实时活动的 UI 定义在 Widget Extension 中：

1. Xcode → File → New → Target → Widget Extension
2. 命名为 `ComicReaderWidget`，勾选 Include Configuration App Intent（可选）
3. 将以下文件加入 Widget Target：
   - `LiveActivity/ReadingActivityAttributes.swift`
   - `LiveActivity/ReadingActivityWidget.swift`
4. 在 Widget Bundle 中注册：

```swift
@main
struct ComicReaderWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 已有的 ContinueReadingWidget、ReadingStatsWidget
        if #available(iOS 16.1, *) {
            ReadingActivityWidget()
        }
    }
}
```

### 3. 确保 App Group 配置

Widget Extension 和主 App 使用同一个 App Group（如 `group.com.comicreader.shared`），在两个 Target 的 Signing & Capabilities 中均添加 App Groups 能力。

### 4. 最低系统版本

实时活动需要 iOS 16.1+，灵动岛需要 iPhone 14 Pro 及以上机型。不支持的设备上设置页会显示提示，功能自动禁用。

## 文件说明

| 文件 | 所属 Target | 说明 |
|------|------------|------|
| `ReadingActivityAttributes.swift` | 主 App + Widget | ActivityAttributes 定义，需同时加入两个 Target |
| `ReadingActivityWidget.swift` | Widget Extension | 灵动岛和锁屏 UI |
| `LiveActivityManager.swift` | 主 App | 活动生命周期管理（启动/更新/结束/暂停/恢复） |

## 工作原理

1. 进入阅读器 → `LiveActivityManager.startActivity()` 启动实时活动
2. 翻页 → `updateActivity()` 更新页码和进度
3. 每 30 秒自动更新阅读时长
4. 退出阅读器 → `endActivity()` 结束活动
5. 切后台 → `pause()` 暂停计时；回前台 → `resume()` 恢复
6. 设置页可开关实时活动功能

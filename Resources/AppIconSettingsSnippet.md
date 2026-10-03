# SettingsView App 图标 Section 代码片段

> **注意**：此代码片段不直接修改 `SettingsView.swift`，由 Organizer 统一接入。
> 将以下代码添加到 SettingsView 的 Form 中，放在合适的 Section 位置。

## 需要在 SettingsView 中添加的 @State 属性

```swift
// 在 SettingsView 的 @State 属性区添加
@StateObject private var iconManager = AppIconManager.shared
@State private var showIconError = false
@State private var iconErrorMessage = ""
```

## Section 代码（添加到 Form 中）

```swift
// MARK: - App 图标

Section {
    ForEach(iconManager.availableIcons) { option in
        Button {
            Task {
                do {
                    try await iconManager.setIcon(option)
                } catch {
                    iconErrorMessage = error.localizedDescription
                    showIconError = true
                }
            }
        } label: {
            HStack(spacing: 12) {
                // 图标预览（圆角矩形 + SF Symbol 占位）
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: option.previewSymbol)
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                    )

                // 图标名称和描述
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.name)
                        .foregroundColor(.primary)
                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 当前选中标记
                if iconManager.currentIconName == option.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
    }
} header: {
    Text("App 图标")
} footer: {
    Text("选择你喜欢的应用图标样式")
}
.alert("切换图标失败", isPresented: $showIconError) {
    Button("确定", role: .cancel) {}
} message: {
    Text(iconErrorMessage)
}
```

## 集成说明

1. 将上述 `@StateObject` 属性添加到 `SettingsView` 的属性区
2. 将 Section 代码块插入到 `Form { ... }` 中的合适位置（建议放在"关于"或"外观"相关 Section 附近）
3. 确保 `AppIconManager.swift` 已加入主 App target
4. 确保 `Info.plist` 已正确配置 `CFBundleAlternateIcons`（参考 `Info-Icons.plist`）
5. 确保 `Assets.xcassets` 中已创建对应的 App Icon 集合

## 效果预览

```
┌─────────────────────────────────┐
│ App 图标                        │
├─────────────────────────────────┤
│ [📖] 默认            蓝色渐变 ✓   │
│      蓝色渐变背景 + 白色书本     │
│                                 │
│ [📖] 深色版          黑色背景    │
│      纯黑背景 + 白色书本         │
│                                 │
│ [💬] 漫画风          网点纹理    │
│      网点纹理背景 + 对话气泡     │
│                                 │
│ [📖] 简约风          纯白背景    │
│      纯白背景 + 黑色线条书本    │
│                                 │
│ 选择你喜欢的应用图标样式         │
└─────────────────────────────────┘
```

# App 图标生成指南

本文档说明如何使用 SwiftUI 代码生成 4 套 App 图标（1024×1024 PNG），以及如何配置到 Xcode 项目中。

## 快速生成步骤

1. 创建一个临时 iOS App 项目（或在现有项目中新建一个 SwiftUI View）
2. 将下方对应的 SwiftUI 代码粘贴到 View 中
3. 在 Canvas 中选中该 View，右键 → "Convert to Image"（或使用 Xcode 15+ 的 View Editor 导出）
4. 导出为 1024×1024 PNG 格式
5. 将导出的 PNG 拖入 Assets.xcassets 中对应的 App Icon 集合

## 图标尺寸要求

- **主图标（默认）**：1024×1024，放入 `AppIcon` 集合
- **备选图标**：每个 alternate icon 也需要 1024×1024 PNG，放入单独的 App Icon 集合（如 `AppIcon-Dark`、`AppIcon-Manga`、`AppIcon-Minimal`）
- 无需制作 @2x/@3x，Xcode 会自动缩放
- 不要有透明背景（iOS 会自动遮罩）

---

## 1. 默认图标（蓝色渐变 + 白色书本）

```swift
import SwiftUI

struct DefaultIconPreview: View {
    var body: some View {
        ZStack {
            // 蓝色渐变背景
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                         Color(red: 0.1, green: 0.3, blue: 0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 白色书本 SF Symbol
            Image(systemName: "book.fill")
                .font(.system(size: 400))
                .foregroundColor(.white)
        }
        .frame(width: 1024, height: 1024)
    }
}
```

## 2. 深色版图标（黑色背景 + 白色书本）

```swift
import SwiftUI

struct DarkIconPreview: View {
    var body: some View {
        ZStack {
            // 纯黑背景
            Color.black

            // 白色书本 SF Symbol
            Image(systemName: "book.fill")
                .font(.system(size: 400))
                .foregroundColor(.white)
        }
        .frame(width: 1024, height: 1024)
    }
}
```

## 3. 漫画风图标（网点纹理 + 对话气泡）

```swift
import SwiftUI

struct MangaIconPreview: View {
    var body: some View {
        ZStack {
            // 米白背景
            Color(red: 0.96, green: 0.96, blue: 0.94)

            // 网点纹理（用循环绘制小圆点）
            Canvas { context, size in
                let dotRadius: CGFloat = 6
                let spacing: CGFloat = 28
                let cols = Int(size.width / spacing)
                let rows = Int(size.height / spacing)
                for row in 0...rows {
                    for col in 0...cols {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                         width: dotRadius * 2, height: dotRadius * 2)
                        context.fill(Path(ellipseIn: rect),
                                    with: .color(Color.black.opacity(0.08)))
                    }
                }
            }

            // 对话气泡
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 360))
                .foregroundColor(.black)
                .offset(y: -40)

            // 气泡尾巴装饰
            Circle()
                .fill(Color.black)
                .frame(width: 60, height: 60)
                .offset(x: -80, y: 180)
        }
        .frame(width: 1024, height: 1024)
    }
}
```

## 4. 简约风图标（纯白背景 + 黑色线条书本）

```swift
import SwiftUI

struct MinimalIconPreview: View {
    var body: some View {
        ZStack {
            // 纯白背景
            Color.white

            // 黑色线条书本
            Image(systemName: "book")
                .font(.system(size: 400, weight: .ultraLight))
                .foregroundColor(.black)
        }
        .frame(width: 1024, height: 1024)
    }
}
```

---

## 在 Xcode 中配置备选图标

### 步骤 1：创建 App Icon 集合

1. 打开 `Assets.xcassets`
2. 点击左下角 "+" → "New App Icon"
3. 命名为 `AppIcon-Dark`、`AppIcon-Manga`、`AppIcon-Minimal`
4. 将生成的 1024×1024 PNG 拖入对应的集合中

### 步骤 2：配置 Info.plist

在主 `Info.plist` 中添加 `CFBundleIcons` → `CFBundleAlternateIcons` 节点（参考 `Info-Icons.plist` 文件）。

### 步骤 3：Xcode Target 设置

1. 选中项目 Target → General → App Icons and Launch Screen
2. "App Icon" 下拉选择主图标集合 `AppIcon`
3. 备选图标不需要在这里选择，运行时通过 `AppIconManager` 动态切换

### 注意事项

- `setAlternateIconName(_:)` 调用时，传入的字符串必须与 Info.plist 中 `CFBundleAlternateIcons` 的 key 完全一致
- 切换图标时 iOS 不会显示 alert（iOS 10.3+ 已移除用户确认弹窗），但会触发系统通知
- 每次调用切换 API 都会有轻微的性能开销（系统会渲染图标），不建议频繁调用
- 模拟器上可以测试图标切换功能

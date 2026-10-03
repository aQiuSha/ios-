# 导出功能 - LibraryView 上下文菜单代码片段

> 以下代码片段需由 Organizer 统一接入到 `LibraryView.swift` 的漫画上下文菜单中。
> 本文件仅提供参考，不直接修改 LibraryView.swift。

---

## 1. 漫画上下文菜单中添加「导出为 CBZ」

在 `LibraryView.swift` 中漫画项的 `.contextMenu` 中，在现有按钮之后、`Divider()` 或删除按钮之前，添加：

```swift
// MARK: - 导出

Button {
    Task {
        do {
            let cbzURL = try ExportService.shared.exportComicAsCBZ(comic)
            ExportService.shared.shareFile(cbzURL)
        } catch {
            // 可选：通过 ViewModel 或 Alert 展示错误
            print("导出 CBZ 失败：\(error.localizedDescription)")
        }
    }
} label: {
    Label("导出为 CBZ", systemImage: "square.and.arrow.up")
}
```

---

## 2. 导入文件时的格式转换选项（ComicImportService / 导入流程）

当用户导入 PDF 文件时，可在导入完成后或导入选项中提供「导出为 CBZ」「导出为图片包」的入口：

```swift
// 导入完成后，可在 Sheet / Alert 中提供导出选项
// 假设当前有一个已导入的 PDF 源文件 pdfURL

// 导出为 CBZ
Button {
    Task {
        do {
            let cbzURL = try await ExportService.shared.exportPDFAsCBZ(pdfURL)
            ExportService.shared.shareFile(cbzURL)
        } catch {
            print("PDF 转 CBZ 失败：\(error.localizedDescription)")
        }
    }
} label: {
    Label("PDF 转 CBZ", systemImage: "doc.zipper")
}

// 导出为图片包
Button {
    Task {
        do {
            let zipURL = try await ExportService.shared.exportPDFAsImagePackage(pdfURL)
            ExportService.shared.shareFile(zipURL)
        } catch {
            print("PDF 转图片包失败：\(error.localizedDescription)")
        }
    }
} label: {
    Label("PDF 转图片包", systemImage: "photo.on.rectangle")
}
```

---

## 3. CBR 导入失败时的错误引导

当导入 CBR 文件失败时，利用 `convertCBRToCBZ` 的错误信息展示给用户：

```swift
// 导入 CBR 文件失败后调用
do {
    _ = try ExportService.shared.convertCBRToCBZ(from: sourceURL)
} catch let error as ComicError {
    // 展示 error.errorDescription（包含清晰的用户引导文案）
    // 例如在 Alert 中：
    showAlert(title: "无法导入 CBR", message: error.errorDescription ?? "未知错误")
}
```

---

## 4. SettingsView / 设置页中的导出入口（可选）

如果需要在设置页提供「导出所有漫画」或批量导出功能，可参考：

```swift
// 设置页中的批量导出（示例，需结合 ViewModel 中的漫画列表）
Button {
    Task {
        do {
            // 遍历所有漫画逐一导出
            for comic in comics {
                let cbzURL = try ExportService.shared.exportComicAsCBZ(comic)
                // 逐个分享或合并为多个文件
                ExportService.shared.shareFile(cbzURL)
            }
        } catch {
            print("批量导出失败：\(error.localizedDescription)")
        }
    }
} label: {
    Label("导出漫画为 CBZ", systemImage: "square.and.arrow.up.on.square")
}
```

---

## 5. SwiftUI 便捷修饰器用法

`ExportService.swift` 中提供了 `.shareSheet(isPresented:url:)` 修饰器，可在 SwiftUI 视图中直接使用：

```swift
struct SomeView: View {
    @State private var showShare = false
    @State private var shareURL: URL?

    var body: some View {
        Button("导出漫画") {
            do {
                let cbzURL = try ExportService.shared.exportComicAsCBZ(comic)
                shareURL = cbzURL
                showShare = true
            } catch {
                // 处理错误
            }
        }
        .shareSheet(isPresented: $showShare, url: shareURL ?? URL(fileURLWithPath: ""))
    }
}
```

---

## 接入注意事项

1. **后台执行**：`exportComicAsCBZ` 和 `createCBZ` 是同步操作，图片较多时会占用主线程。建议在 `Task.detached` 中调用，或确保在 `Task` 的后台上下文中执行。
2. **临时文件**：导出的 CBZ 文件位于 `temporaryDirectory`，系统会在适当时机自动清理。通过 `UIActivityViewController` 分享后，用户可选择「存储到文件」将其保存到本地。
3. **错误处理**：所有方法都 throws，调用方需 catch 并通过 UI（Alert / Toast）展示 `ComicError.errorDescription`。
4. **iPad 适配**：`shareFile` 已自动处理 popoverPresentationController，无需额外配置。

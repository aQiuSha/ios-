import WidgetKit
import SwiftUI

/// 「继续阅读」桌面小组件定义
/// 支持 systemSmall 和 systemMedium 两种尺寸
struct ContinueReadingWidget: Widget {
    let kind: String = "ContinueReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ContinueReadingProvider()) { entry in
            ContinueReadingView(entry: entry)
        }
        .configurationDisplayName("继续阅读")
        .description("快速继续上次的阅读进度")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

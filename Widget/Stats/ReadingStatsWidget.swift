import WidgetKit
import SwiftUI

/// 「阅读统计」桌面小组件定义
/// 支持 systemSmall 和 systemMedium 两种尺寸
struct ReadingStatsWidget: Widget {
    let kind: String = "ReadingStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingStatsProvider()) { entry in
            ReadingStatsView(entry: entry)
        }
        .configurationDisplayName("阅读统计")
        .description("查看今日阅读时长和连续阅读天数")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

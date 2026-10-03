import WidgetKit
import SwiftUI

/// Widget Extension 的入口点
/// 注意：这个 @main 属于 Widget Extension target，和主 App 的 @main（ComicReaderApp）不冲突
/// 在 Xcode 中添加 Widget Extension Target 后，此文件应仅属于 Widget Extension target
@main
struct ComicReaderWidgetBundle: WidgetBundle {
    var body: some Widget {
        // 继续阅读小组件
        ContinueReadingWidget()
        // 阅读统计小组件
        ReadingStatsWidget()
    }
}

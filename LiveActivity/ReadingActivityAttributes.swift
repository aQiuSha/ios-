import ActivityKit
import Foundation

/// 阅读实时活动的 Attributes 定义
struct ReadingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 漫画标题
        var comicTitle: String
        /// 当前页码（0-based）
        var currentPage: Int
        /// 总页数
        var totalPages: Int
        /// 阅读进度 0-1
        var progress: Double
        /// 已阅读时长（秒）
        var readingDuration: TimeInterval
    }

    /// 漫画唯一标识
    var comicID: String
    /// 漫画标题（静态部分）
    var comicTitle: String
}

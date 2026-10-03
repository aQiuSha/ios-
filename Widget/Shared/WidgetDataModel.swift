import Foundation
import WidgetKit

/// 小组件使用的漫画数据模型（不依赖 SwiftData，纯 Codable）
struct WidgetComicInfo: Codable, Identifiable {
    /// 漫画唯一标识（对应 Comic.id 的 uuidString）
    let id: String
    /// 漫画标题
    let title: String
    /// 封面文件名（在共享容器中）
    let coverFileName: String
    /// 当前阅读页码
    let currentPage: Int
    /// 总页数
    let pageCount: Int
    /// 阅读进度（0.0 ~ 1.0）
    let progress: Double

    /// 进度百分比文本
    var progressText: String {
        "\(Int(progress * 100))%"
    }
}

/// 小组件使用的阅读统计数据模型
struct WidgetStatsInfo: Codable {
    /// 今日阅读分钟数
    let todayMinutes: Int
    /// 连续阅读天数
    let currentStreak: Int
    /// 数据最后更新时间
    let lastUpdate: Date
}

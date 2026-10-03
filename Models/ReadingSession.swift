import Foundation
import SwiftData

@Model
final class ReadingSession {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var duration: TimeInterval  // 秒
    var comic: Comic?

    init(startTime: Date, endTime: Date, duration: TimeInterval, comic: Comic? = nil) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.comic = comic
    }
}

/// 阅读统计汇总结构
struct ReadingStats {
    var todayDuration: TimeInterval = 0
    var weekDuration: TimeInterval = 0
    var monthDuration: TimeInterval = 0
    var totalDuration: TimeInterval = 0
    var totalSessions: Int = 0
    var readingDays: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var dailyData: [DailyReading] = []  // 最近7天
    var comicRankings: [ComicRanking] = []
}

struct DailyReading: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE"  // 周几
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

struct ComicRanking: Identifiable {
    let id = UUID()
    let comic: Comic
    let duration: TimeInterval
    let sessions: Int
}

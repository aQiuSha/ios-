import AppIntents
import SwiftData
import UIKit

/// 「阅读统计」Siri 快捷指令
/// 用户通过 Siri 询问阅读统计，返回今日阅读时长和连续天数
struct ShowReadingStatsIntent: AppIntent {

    static var title: LocalizedStringResource = "阅读统计"
    static var description = IntentDescription("显示今日阅读统计")
    static var openAppWhenRun: Bool = true

    // MARK: - 执行逻辑

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let container = ComicReaderApp.modelContainer else {
            return .result(value: "无法获取阅读统计")
        }

        let context = container.mainContext
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // 查询今日阅读会话
        var descriptor = FetchDescriptor<ReadingSession>()
        descriptor.predicate = #Predicate<ReadingSession> { session in
            session.startTime >= todayStart
        }

        let todaySessions = (try? context.fetch(descriptor)) ?? []
        let todayTotalSeconds = todaySessions.reduce(0.0) { $0 + $1.duration }
        let todayMinutes = Int(todayTotalSeconds / 60)

        // 计算连续阅读天数
        let streak = calculateCurrentStreak(context: context, calendar: calendar, today: todayStart)

        // 格式化返回文本
        let timeText: String
        if todayMinutes < 60 {
            timeText = "\(todayMinutes) 分钟"
        } else {
            let hours = todayMinutes / 60
            let mins = todayMinutes % 60
            timeText = mins == 0 ? "\(hours) 小时" : "\(hours) 小时 \(mins) 分钟"
        }

        return .result(value: "今日阅读 \(timeText)，已连续阅读 \(streak) 天")
    }

    /// 计算连续阅读天数
    private func calculateCurrentStreak(context: ModelContext, calendar: Calendar, today: Date) -> Int {
        let descriptor = FetchDescriptor<ReadingSession>()
        guard let allSessions = try? context.fetch(descriptor) else { return 0 }

        var dayBuckets: Set<Date> = []
        for session in allSessions {
            let day = calendar.startOfDay(for: session.startTime)
            dayBuckets.insert(day)
        }

        var streak = 0
        var current = today
        if !dayBuckets.contains(today) {
            current = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        }
        while dayBuckets.contains(current) {
            streak += 1
            current = calendar.date(byAdding: .day, value: -1, to: current) ?? current
        }
        return streak
    }
}

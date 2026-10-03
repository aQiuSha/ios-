import Foundation
import SwiftData

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var stats = ReadingStats()
    @Published var isLoading = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadStats() {
        isLoading = true
        defer { isLoading = false }

        let descriptor = FetchDescriptor<ReadingSession>(sortBy: [SortDescriptor(\.startTime, order: .reverse)])
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        var stats = ReadingStats()
        stats.totalSessions = sessions.count

        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // 本周起始（周一）
        var weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        // 调整为周一
        let weekday = calendar.component(.weekday, from: now)
        let daysToSubtract = (weekday + 5) % 7  // 周一=0
        weekStart = calendar.date(byAdding: .day, value: -daysToSubtract, to: todayStart)!

        // 本月起始
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        // 按天聚合
        var dayBuckets: [Date: TimeInterval] = [:]
        var comicBuckets: [PersistentIdentifier: (duration: TimeInterval, sessions: Int, comic: Comic?)] = [:]

        for session in sessions {
            stats.totalDuration += session.duration

            if session.startTime >= todayStart {
                stats.todayDuration += session.duration
            }
            if session.startTime >= weekStart {
                stats.weekDuration += session.duration
            }
            if session.startTime >= monthStart {
                stats.monthDuration += session.duration
            }

            // 按天聚合
            let day = calendar.startOfDay(for: session.startTime)
            dayBuckets[day, default: 0] += session.duration

            // 按漫画聚合
            if let comic = session.comic {
                let id = comic.persistentModelID
                var existing = comicBuckets[id] ?? (0, 0, nil)
                existing.duration += session.duration
                existing.sessions += 1
                existing.comic = comic
                comicBuckets[id] = existing
            }
        }

        stats.readingDays = dayBuckets.count

        // 最近7天数据
        for i in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: -(6 - i), to: todayStart) {
                let duration = dayBuckets[date] ?? 0
                stats.dailyData.append(DailyReading(date: date, duration: duration))
            }
        }

        // 连续阅读天数
        stats.currentStreak = calculateCurrentStreak(dayBuckets: dayBuckets, calendar: calendar, today: todayStart)
        stats.longestStreak = calculateLongestStreak(dayBuckets: dayBuckets, calendar: calendar)

        // 漫画排行（未解锁隐私文件夹时，排除隐私文件夹内的漫画）
        let isUnlocked = PrivacyAuthService.shared.isUnlocked
        stats.comicRankings = comicBuckets.values
            .compactMap { value -> ComicRanking? in
                guard let comic = value.comic else { return nil }
                // 未解锁时跳过隐私文件夹内的漫画
                if !isUnlocked, comic.folder?.isPrivate == true { return nil }
                return ComicRanking(comic: comic, duration: value.duration, sessions: value.sessions)
            }
            .sorted { $0.duration > $1.duration }

        self.stats = stats

        // 检测成就
        let totalMinutes = Int(stats.totalDuration / 60)
        let finishedCount = (try? modelContext.fetch(FetchDescriptor<Comic>(
            predicate: #Predicate { $0.readStatus == "finished" }
        )))?.count ?? 0
        let favoriteCount = (try? modelContext.fetch(FetchDescriptor<Comic>(
            predicate: #Predicate { $0.isFavorite == true }
        )))?.count ?? 0
        let comicCount = (try? modelContext.fetchCount(FetchDescriptor<Comic>())) ?? 0
        AchievementService.shared.checkAchievements(
            totalMinutes: totalMinutes,
            streak: stats.currentStreak,
            finishedCount: finishedCount,
            favoriteCount: favoriteCount,
            comicCount: comicCount
        )
    }

    private func calculateCurrentStreak(dayBuckets: [Date: TimeInterval], calendar: Calendar, today: Date) -> Int {
        var streak = 0
        var current = today
        // 如果今天没读，从昨天开始算
        if dayBuckets[today] == nil {
            current = calendar.date(byAdding: .day, value: -1, to: today)!
        }
        while dayBuckets[current] != nil {
            streak += 1
            current = calendar.date(byAdding: .day, value: -1, to: current)!
        }
        return streak
    }

    private func calculateLongestStreak(dayBuckets: [Date: TimeInterval], calendar: Calendar) -> Int {
        let sortedDays = dayBuckets.keys.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDays.count {
            let prev = sortedDays[i - 1]
            let curr = sortedDays[i]
            if let diff = calendar.dateComponents([.day], from: prev, to: curr).day, diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    /// 格式化时长为可读字符串
    static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        if totalMinutes < 60 {
            return "\(totalMinutes) 分钟"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if minutes == 0 {
            return "\(hours) 小时"
        }
        return "\(hours) 小时 \(minutes) 分"
    }

    static func formatDurationShort(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

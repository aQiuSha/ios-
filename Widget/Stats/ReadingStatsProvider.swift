import WidgetKit
import SwiftUI

/// 统计小组件时间线条目
struct ReadingStatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetStatsInfo
}

/// 「阅读统计」小组件的 TimelineProvider
struct ReadingStatsProvider: TimelineProvider {

    func placeholder(in context: Context) -> ReadingStatsEntry {
        ReadingStatsEntry(
            date: Date(),
            stats: WidgetStatsInfo(todayMinutes: 45, currentStreak: 7, lastUpdate: Date())
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingStatsEntry) -> Void) {
        let stats = AppGroupData.loadStats()
        let entry = ReadingStatsEntry(date: Date(), stats: stats)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingStatsEntry>) -> Void) {
        let stats = AppGroupData.loadStats()
        let entry = ReadingStatsEntry(date: Date(), stats: stats)

        // 每小时刷新
        let nextUpdate = Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

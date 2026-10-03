import Foundation
import SwiftData
import WidgetKit

/// Widget 数据同步管理器（主 App 侧使用）
/// 负责将 App 内的阅读数据同步到 App Group 共享容器，供小组件读取
/// 单例模式，在阅读进度更新、App 进入后台时调用 syncWidgetData()
@MainActor
final class WidgetSyncManager {

    /// 共享单例
    static let shared = WidgetSyncManager()
    private init() {}

    /// 同步 Widget 所需的全部数据
    /// 在以下时机调用：
    /// 1. 阅读进度更新后（ReaderViewModel 翻页时）
    /// 2. App 进入后台（scenePhase 变为 .background）
    /// 3. 导入新漫画 / 删除漫画后
    /// - Parameter modelContext: SwiftData 上下文，用于查询最近阅读的漫画和统计数据
    func syncWidgetData(modelContext: ModelContext) {
        syncLatestComic(modelContext: modelContext)
        syncStats(modelContext: modelContext)

        // 主动触发 Widget 刷新
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - 私有方法

    /// 同步最近阅读的漫画信息
    private func syncLatestComic(modelContext: ModelContext) {
        // 查询有阅读进度且未读完的漫画，按 lastOpened 降序排列
        var descriptor = FetchDescriptor<Comic>(
            sortBy: [SortDescriptor(\.lastOpened, order: .reverse)]
        )
        descriptor.predicate = #Predicate<Comic> { comic in
            comic.currentPage > 0
        }

        guard let comics = try? modelContext.fetch(descriptor),
              let latestComic = comics.first(where: { !$0.isFinished }) else {
            // 没有进行中的阅读，清除 Widget 数据
            AppGroupData.clearLatestComic()
            return
        }

        AppGroupData.saveLatestComic(
            id: latestComic.id,
            title: latestComic.title,
            coverPath: latestComic.coverPath,
            currentPage: latestComic.currentPage,
            pageCount: latestComic.pageCount,
            progress: latestComic.progress
        )
    }

    /// 同步阅读统计数据
    private func syncStats(modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)

        // 查询今日阅读会话
        var descriptor = FetchDescriptor<ReadingSession>()
        descriptor.predicate = #Predicate<ReadingSession> { session in
            session.startTime >= todayStart
        }

        let todaySessions = (try? modelContext.fetch(descriptor)) ?? []
        let todayTotalSeconds = todaySessions.reduce(0.0) { $0 + $1.duration }
        let todayMinutes = Int(todayTotalSeconds / 60)

        // 计算连续阅读天数
        let streak = calculateCurrentStreak(modelContext: modelContext, calendar: calendar, today: todayStart)

        AppGroupData.saveStats(todayMinutes: todayMinutes, streak: streak)
    }

    /// 计算连续阅读天数（与 StatsViewModel 逻辑一致）
    private func calculateCurrentStreak(modelContext: ModelContext, calendar: Calendar, today: Date) -> Int {
        // 查询所有阅读会话，按天聚合
        let descriptor = FetchDescriptor<ReadingSession>()
        guard let allSessions = try? modelContext.fetch(descriptor) else {
            return 0
        }

        var dayBuckets: Set<Date> = []
        for session in allSessions {
            let day = calendar.startOfDay(for: session.startTime)
            dayBuckets.insert(day)
        }

        var streak = 0
        var current = today
        // 如果今天没读，从昨天开始算
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

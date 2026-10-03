import Foundation
import UIKit

/// App Group 数据共享工具
/// 主 App 和 Widget Extension 通过 App Group 共享 UserDefaults 和文件容器
/// 注意：此文件同时被主 App 和 Widget Extension target 编译，不要 import SwiftData
final class AppGroupData {

    // MARK: - 常量

    /// App Group 标识符
    static let appGroupID = "group.com.comicreader.shared"

    /// 共享 UserDefaults 的 Key
    private enum Key {
        static let latestComic = "widget_latest_comic"
        static let stats = "widget_stats"
    }

    /// 共享容器中封面图的文件名
    static let latestCoverFileName = "latest_cover.jpg"

    // MARK: - 共享容器访问

    /// 共享 UserDefaults（主 App 和 Widget 均可读写）
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// App Group 共享文件容器 URL
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// 共享容器中封面图的完整 URL
    static var latestCoverURL: URL? {
        sharedContainerURL?.appendingPathComponent(latestCoverFileName)
    }

    // MARK: - 最近阅读漫画 写入

    /// 将最近阅读的漫画信息写入共享数据
    /// - Parameters:
    ///   - comic: 漫画对象（主 App 中为 Comic 类型，此处用基础参数避免依赖 SwiftData）
    ///   - coverPath: 封面图在 App 沙盒中的路径（可为 nil）
    static func saveLatestComic(id: UUID, title: String, coverPath: String?, currentPage: Int, pageCount: Int, progress: Double) {
        let info = WidgetComicInfo(
            id: id.uuidString,
            title: title,
            coverFileName: latestCoverFileName,
            currentPage: currentPage,
            pageCount: pageCount,
            progress: progress
        )

        // 写入 UserDefaults
        if let data = try? JSONEncoder().encode(info) {
            sharedDefaults?.set(data, forKey: Key.latestComic)
        }

        // 复制封面图到共享容器
        if let coverPath,
           let coverURL = latestCoverURL {
            let sourceURL = URL(fileURLWithPath: coverPath)
            do {
                // 先删除旧封面
                try? FileManager.default.removeItem(at: coverURL)
                try FileManager.default.copyItem(at: sourceURL, to: coverURL)
            } catch {
                print("⚠️ 复制封面到共享容器失败: \(error.localizedDescription)")
            }
        }
    }

    /// 清除最近阅读漫画数据（当所有漫画都读完或删除时调用）
    static func clearLatestComic() {
        sharedDefaults?.removeObject(forKey: Key.latestComic)
        if let coverURL = latestCoverURL {
            try? FileManager.default.removeItem(at: coverURL)
        }
    }

    // MARK: - 阅读统计 写入

    /// 将阅读统计数据写入共享容器
    /// - Parameters:
    ///   - todayMinutes: 今日阅读分钟数
    ///   - streak: 连续阅读天数
    static func saveStats(todayMinutes: Int, streak: Int) {
        let stats = WidgetStatsInfo(
            todayMinutes: todayMinutes,
            currentStreak: streak,
            lastUpdate: Date()
        )
        if let data = try? JSONEncoder().encode(stats) {
            sharedDefaults?.set(data, forKey: Key.stats)
        }
    }

    // MARK: - 读取（Widget 侧使用）

    /// 从共享数据读取最近阅读的漫画
    static func loadLatestComic() -> WidgetComicInfo? {
        guard let data = sharedDefaults?.data(forKey: Key.latestComic),
              let info = try? JSONDecoder().decode(WidgetComicInfo.self, from: data) else {
            return nil
        }
        return info
    }

    /// 从共享数据读取阅读统计
    static func loadStats() -> WidgetStatsInfo {
        guard let data = sharedDefaults?.data(forKey: Key.stats),
              let stats = try? JSONDecoder().decode(WidgetStatsInfo.self, from: data) else {
            return WidgetStatsInfo(todayMinutes: 0, currentStreak: 0, lastUpdate: Date())
        }
        return stats
    }

    /// 从共享容器加载封面图（Widget 侧使用）
    static func loadSharedCoverImage() -> UIImage? {
        guard let url = latestCoverURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

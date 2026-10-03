import WidgetKit
import SwiftUI

/// 小组件时间线条目：携带漫画数据和时间戳
struct ContinueReadingEntry: TimelineEntry {
    let date: Date
    let comic: WidgetComicInfo?
    let coverImage: UIImage?
}

/// 「继续阅读」小组件的 TimelineProvider
/// 负责从 App Group 读取数据并生成时间线
struct ContinueReadingProvider: TimelineProvider {

    /// 占位视图（Widget 加载中显示）
    func placeholder(in context: Context) -> ContinueReadingEntry {
        ContinueReadingEntry(
            date: Date(),
            comic: nil,
            coverImage: nil
        )
    }

    /// 快照：用于 Widget Gallery 预览和实时刷新
    func getSnapshot(in context: Context, completion: @escaping (ContinueReadingEntry) -> Void) {
        let comic = AppGroupData.loadLatestComic()
        let cover = AppGroupData.loadSharedCoverImage()
        let entry = ContinueReadingEntry(date: Date(), comic: comic, coverImage: cover)
        completion(entry)
    }

    /// 生成时间线：每小时自动刷新一次
    /// 主 App 在阅读进度更新时会主动调用 WidgetCenter.reloadAllTimeLines()
    func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueReadingEntry>) -> Void) {
        let comic = AppGroupData.loadLatestComic()
        let cover = AppGroupData.loadSharedCoverImage()
        let entry = ContinueReadingEntry(date: Date(), comic: comic, coverImage: cover)

        // 1 小时后自动刷新
        let nextUpdate = Date().addingTimeInterval(3600)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

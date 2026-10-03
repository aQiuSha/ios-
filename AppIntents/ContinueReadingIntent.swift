import AppIntents
import SwiftData
import UIKit

/// 「继续阅读」Siri 快捷指令
/// 用户可以通过 Siri 或 Shortcuts App 触发："继续阅读漫画"
/// 自动打开上次正在阅读的漫画
struct ContinueReadingIntent: AppIntent {

    /// 快捷指令标题（Siri 中显示）
    static var title: LocalizedStringResource = "继续阅读"

    /// 快捷指令描述
    static var description = IntentDescription("继续阅读上次的漫画")

    /// 运行时是否打开 App
    static var openAppWhenRun: Bool = true

    // MARK: - 执行逻辑

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let container = ComicReaderApp.modelContainer else {
            return .result(value: "无法打开漫画书架")
        }

        let context = container.mainContext

        // 查询有阅读进度且未读完的漫画，按 lastOpened 降序
        var descriptor = FetchDescriptor<Comic>(
            sortBy: [SortDescriptor(\.lastOpened, order: .reverse)]
        )
        descriptor.predicate = #Predicate<Comic> { comic in
            comic.currentPage > 0
        }

        guard let comics = try? context.fetch(descriptor),
              let latestComic = comics.first(where: { !$0.isFinished }) else {
            return .result(value: "没有正在阅读的漫画")
        }

        // 通过 NotificationCenter 通知主界面打开漫画
        // LibraryView 监听此通知并设置 selectedComic 触发 fullScreenCover
        NotificationCenter.default.post(
            name: .openComicFromIntent,
            object: nil,
            userInfo: ["comicID": latestComic.id]
        )

        return .result(value: "正在继续阅读「\(latestComic.title)」")
    }
}

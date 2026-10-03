import AppIntents
import SwiftData
import UIKit

/// 「打开漫画」Siri 快捷指令
/// 用户可以指定一本漫画，通过 Siri 或 Shortcuts 直接打开
struct OpenComicIntent: AppIntent {

    /// 漫画参数（用户在 Siri/Shortcuts 中选择）
    @Parameter(title: "漫画", description: "选择要打开的漫画")
    var comic: ComicEntity

    static var title: LocalizedStringResource = "打开漫画"
    static var description = IntentDescription("打开指定的漫画")
    static var openAppWhenRun: Bool = true

    // MARK: - 执行逻辑

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 通过 NotificationCenter 通知主界面打开指定漫画
        NotificationCenter.default.post(
            name: .openComicFromIntent,
            object: nil,
            userInfo: ["comicID": comic.id]
        )

        return .result(value: "正在打开「\(comic.title)」")
    }
}

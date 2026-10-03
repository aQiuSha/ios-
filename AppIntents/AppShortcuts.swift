import AppIntents
import UIKit

/// Siri 快捷指令提供程序
/// 系统会自动注册这些快捷指令，用户可以在 Shortcuts App 中找到并添加到 Siri
/// App Shortcuts Provider 无需手动调用，系统在 App 启动时自动发现
@available(iOS 16.0, *)
struct ComicReaderAppShortcuts: AppShortcutsProvider {

    /// 注册所有 App 快捷指令
    static var appShortcuts: [AppShortcut] {
        // 1. 继续阅读
        AppShortcut(
            intent: ContinueReadingIntent(),
            phrases: [
                "继续阅读\(.applicationName)",
                "继续看漫画",
                "打开上次看的漫画"
            ],
            shortTitle: "继续阅读",
            systemImageName: "book.fill"
        )

        // 2. 打开漫画（带参数选择）
        AppShortcut(
            intent: OpenComicIntent(),
            phrases: [
                "打开\(.applicationName)中的漫画",
                "打开漫画\(\.$comic)",
                "用\(.applicationName)看漫画"
            ],
            shortTitle: "打开漫画",
            systemImageName: "book.closed"
        )

        // 3. 阅读统计
        AppShortcut(
            intent: ShowReadingStatsIntent(),
            phrases: [
                "\(.applicationName)阅读统计",
                "今天看了多久漫画",
                "阅读天数统计"
            ],
            shortTitle: "阅读统计",
            systemImageName: "chart.bar.fill"
        )
    }

    /// 快捷指令在 Shortcuts App 中的显示颜色
    static var shortcutTileColor: ShortcutTileColor = .blue
}

import Foundation

/// 深度链接 / App Intent 打开漫画相关的通知名称扩展
///
/// 使用方式：
/// - Widget 点击 / URL Scheme 打开 → 发送此通知
/// - LibraryView 监听此通知，收到后设置 selectedComic 触发 fullScreenCover
extension Notification.Name {
    /// 通过 App Intent 或深度链接请求打开指定漫画
    /// userInfo: ["comicID": UUID]
    static let openComicFromIntent = Notification.Name("comicreader.openComicFromIntent")

    /// 通过深度链接打开统计页
    static let showStatsFromDeepLink = Notification.Name("comicreader.showStatsFromDeepLink")
}

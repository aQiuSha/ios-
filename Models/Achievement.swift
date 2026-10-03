import Foundation
import SwiftUI

// MARK: - 成就定义

/// 阅读成就
enum Achievement: String, Codable, CaseIterable, Identifiable {
    case firstComic          // 第一本漫画
    case firstBookmark       // 第一个书签
    case readerFor1Hour      // 阅读1小时
    case readerFor5Hours     // 阅读5小时
    case readerFor20Hours    // 阅读20小时
    case streak3             // 连续3天
    case streak7             // 连续7天
    case streak30            // 连续30天
    case finish1Comic        // 读完1本
    case finish5Comics       // 读完5本
    case finish20Comics      // 读完20本
    case nightOwl            // 夜猫子（凌晨阅读）
    case earlyBird           // 早起阅读（6点前）
    case marathon            // 单次阅读超过1小时
    case collector10         // 收藏10本
    case collector50         // 收藏50本
    case allTopics           // 体验所有阅读主题
    case aiEnhancer          // 使用AI画质增强
    case wifiTransfer        // 使用WiFi传书
    case customizer          // 自定义App图标

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstComic: return "初入江湖"
        case .firstBookmark: return "到此一游"
        case .readerFor1Hour: return "渐入佳境"
        case .readerFor5Hours: return "手不释卷"
        case .readerFor20Hours: return "读书破万卷"
        case .streak3: return "三日不辍"
        case .streak7: return "一周坚持"
        case .streak30: return "月度达人"
        case .finish1Comic: return "圆满收官"
        case .finish5Comics: return "博览群书"
        case .finish20Comics: return "漫画大师"
        case .nightOwl: return "夜猫子"
        case .earlyBird: return "早起的鸟儿"
        case .marathon: return "阅读马拉松"
        case .collector10: return "小有收藏"
        case .collector50: return "藏书家"
        case .allTopics: return "百变星君"
        case .aiEnhancer: return "画质达人"
        case .wifiTransfer: return "无线传书"
        case .customizer: return "个性十足"
        }
    }

    var description: String {
        switch self {
        case .firstComic: return "导入第一本漫画"
        case .firstBookmark: return "添加第一个书签"
        case .readerFor1Hour: return "累计阅读1小时"
        case .readerFor5Hours: return "累计阅读5小时"
        case .readerFor20Hours: return "累计阅读20小时"
        case .streak3: return "连续阅读3天"
        case .streak7: return "连续阅读7天"
        case .streak30: return "连续阅读30天"
        case .finish1Comic: return "读完第一本漫画"
        case .finish5Comics: return "读完5本漫画"
        case .finish20Comics: return "读完20本漫画"
        case .nightOwl: return "在凌晨0-5点阅读"
        case .earlyBird: return "在早上5-6点阅读"
        case .marathon: return "单次阅读超过1小时"
        case .collector10: return "收藏10本漫画"
        case .collector50: return "收藏50本漫画"
        case .allTopics: return "使用过所有阅读主题"
        case .aiEnhancer: return "使用AI画质增强"
        case .wifiTransfer: return "使用WiFi传书"
        case .customizer: return "更换App图标"
        }
    }

    var icon: String {
        switch self {
        case .firstComic: return "book"
        case .firstBookmark: return "bookmark"
        case .readerFor1Hour: return "clock"
        case .readerFor5Hours: return "clock.fill"
        case .readerFor20Hours: return "hourglass"
        case .streak3: return "flame"
        case .streak7: return "flame.fill"
        case .streak30: return "trophy"
        case .finish1Comic: return "checkmark.circle"
        case .finish5Comics: return "checkmark.circle.fill"
        case .finish20Comics: return "crown"
        case .nightOwl: return "moon"
        case .earlyBird: return "sunrise"
        case .marathon: return "figure.run"
        case .collector10: return "star"
        case .collector50: return "star.fill"
        case .allTopics: return "paintpalette"
        case .aiEnhancer: return "sparkles"
        case .wifiTransfer: return "wifi"
        case .customizer: return "app"
        }
    }

    var color: Color {
        switch self {
        case .firstComic, .firstBookmark: return .blue
        case .readerFor1Hour, .readerFor5Hours, .readerFor20Hours: return .green
        case .streak3, .streak7, .streak30: return .orange
        case .finish1Comic, .finish5Comics, .finish20Comics: return .purple
        case .nightOwl: return .indigo
        case .earlyBird: return .yellow
        case .marathon: return .red
        case .collector10, .collector50: return .pink
        case .allTopics, .customizer: return .teal
        case .aiEnhancer: return .cyan
        case .wifiTransfer: return .mint
        }
    }
}

// MARK: - 成就管理器

/// 成就管理服务：检测并解锁成就
final class AchievementService {
    static let shared = AchievementService()
    private init() {}

    private let defaults = UserDefaults.standard
    private let unlockedKey = "unlockedAchievements"
    private let sessionStartKey = "currentSessionStart"
    private let usedTopicsKey = "usedReaderThemes"

    /// 已解锁的成就
    var unlockedAchievements: Set<Achievement> {
        get {
            guard let data = defaults.data(forKey: unlockedKey),
                  let arr = try? JSONDecoder().decode([Achievement].self, from: data) else {
                return []
            }
            return Set(arr)
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue)) {
                defaults.set(data, forKey: unlockedKey)
            }
        }
    }

    /// 解锁成就，返回是否是新解锁
    @discardableResult
    func unlock(_ achievement: Achievement) -> Bool {
        var unlocked = unlockedAchievements
        if unlocked.contains(achievement) { return false }
        unlocked.insert(achievement)
        unlockedAchievements = unlocked
        return true
    }

    /// 检查是否已解锁
    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlockedAchievements.contains(achievement)
    }

    /// 记录使用过的主题
    func trackThemeUsed(_ theme: ReaderTheme) {
        var used = Set((defaults.array(forKey: usedTopicsKey) as? [String]) ?? [])
        used.insert(theme.rawValue)
        defaults.set(Array(used), forKey: usedTopicsKey)
        if used.count >= ReaderTheme.allCases.filter({ $0 != .custom }).count {
            unlock(.allTopics)
        }
    }

    /// 开始阅读会话
    func startSession() {
        defaults.set(Date(), forKey: sessionStartKey)
    }

    /// 结束阅读会话，检测相关成就
    func endSession() {
        guard let start = defaults.object(forKey: sessionStartKey) as? Date else { return }
        let duration = Date().timeIntervalSince(start)
        if duration >= 3600 {
            unlock(.marathon)
        }
        // 夜猫子/早起鸟
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 0 && hour < 5 { unlock(.nightOwl) }
        if hour >= 5 && hour < 6 { unlock(.earlyBird) }
        defaults.removeObject(forKey: sessionStartKey)
    }

    /// 根据统计数据批量检测成就
    func checkAchievements(totalMinutes: Int, streak: Int, finishedCount: Int, favoriteCount: Int, comicCount: Int) {
        if comicCount >= 1 { unlock(.firstComic) }
        if totalMinutes >= 60 { unlock(.readerFor1Hour) }
        if totalMinutes >= 300 { unlock(.readerFor5Hours) }
        if totalMinutes >= 1200 { unlock(.readerFor20Hours) }
        if streak >= 3 { unlock(.streak3) }
        if streak >= 7 { unlock(.streak7) }
        if streak >= 30 { unlock(.streak30) }
        if finishedCount >= 1 { unlock(.finish1Comic) }
        if finishedCount >= 5 { unlock(.finish5Comics) }
        if finishedCount >= 20 { unlock(.finish20Comics) }
        if favoriteCount >= 10 { unlock(.collector10) }
        if favoriteCount >= 50 { unlock(.collector50) }
    }

    /// 解锁进度（已解锁/总数）
    var progress: (unlocked: Int, total: Int) {
        (unlockedAchievements.count, Achievement.allCases.count)
    }
}

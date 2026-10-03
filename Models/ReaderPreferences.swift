import SwiftUI
import UIKit

// MARK: - 阅读主题

/// 阅读器背景主题
enum ReaderTheme: String, Codable, CaseIterable {
    case white
    case darkGray
    case pureBlack
    case eyeGreen
    case darkBrown
    case custom

    var displayName: String {
        switch self {
        case .white: return "白底"
        case .darkGray: return "深灰"
        case .pureBlack: return "纯黑"
        case .eyeGreen: return "护眼绿"
        case .darkBrown: return "深色棕"
        case .custom: return "自定义图片"
        }
    }

    /// 背景色（自定义主题返回深灰作为占位，实际由图片覆盖）
    var background: Color {
        switch self {
        case .white: return .white
        case .darkGray: return Color(white: 0.15)
        case .pureBlack: return .black
        case .eyeGreen: return Color(red: 0.86, green: 0.93, blue: 0.82)
        case .darkBrown: return Color(red: 0.22, green: 0.18, blue: 0.14)
        case .custom: return Color(white: 0.1)
        }
    }

    /// 是否为自定义图片背景
    var isCustomBackground: Bool {
        self == .custom
    }

    /// 主要 UI 前景色
    var uiForeground: Color {
        switch self {
        case .white, .eyeGreen: return .black
        case .darkGray, .pureBlack, .darkBrown, .custom: return .white
        }
    }

    /// 次要 UI 颜色
    var uiSecondary: Color {
        switch self {
        case .white, .eyeGreen, .darkGray, .pureBlack, .darkBrown, .custom: return .gray
        }
    }

    /// 顶/底栏渐变起始色
    var overlayGradient: [Color] {
        switch self {
        case .white: return [Color.black.opacity(0.15), .clear]
        case .eyeGreen: return [Color.black.opacity(0.12), .clear]
        case .darkGray, .pureBlack, .darkBrown, .custom: return [Color.black.opacity(0.8), .clear]
        }
    }
}

// MARK: - 翻页动画

/// 翻页过渡效果
enum PageTransition: String, Codable, CaseIterable {
    case slide
    case fade
    case none

    var displayName: String {
        switch self {
        case .slide: return "滑动"
        case .fade: return "淡入淡出"
        case .none: return "无动画"
        }
    }
}

// MARK: - 手势操作

/// 点击区域可执行的操作
enum TapAction: String, Codable, CaseIterable {
    case prevPage
    case nextPage
    case toggleMenu
    case none

    var displayName: String {
        switch self {
        case .prevPage: return "上一页"
        case .nextPage: return "下一页"
        case .toggleMenu: return "显示/隐藏菜单"
        case .none: return "无"
        }
    }
}

/// 滑动方向可执行的操作
enum SwipeAction: String, Codable, CaseIterable {
    case prevPage
    case nextPage
    case none

    var displayName: String {
        switch self {
        case .prevPage: return "上一页"
        case .nextPage: return "下一页"
        case .none: return "无"
        }
    }
}

/// 手势配置结构体（用于持久化 JSON）
struct GestureConfig: Codable, Equatable {
    var leftTap: TapAction
    var centerTap: TapAction
    var rightTap: TapAction
    var swipeLeft: SwipeAction
    var swipeRight: SwipeAction

    static let `default` = GestureConfig(
        leftTap: .prevPage,
        centerTap: .toggleMenu,
        rightTap: .nextPage,
        swipeLeft: .nextPage,
        swipeRight: .prevPage
    )
}

// MARK: - 强调色

/// UI 强调色主题（影响按钮、进度条、选中态等）
enum AccentColor: String, Codable, CaseIterable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal

    var displayName: String {
        switch self {
        case .blue: return "蓝色"
        case .purple: return "紫色"
        case .pink: return "粉色"
        case .red: return "红色"
        case .orange: return "橙色"
        case .yellow: return "黄色"
        case .green: return "绿色"
        case .teal: return "青色"
        }
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .teal: return .teal
        }
    }

    var previewColor: Color {
        color
    }
}

// MARK: - AI 画质增强

/// AI 画质增强级别
enum ImageEnhanceLevel: String, Codable, CaseIterable {
    case off
    case light
    case medium
    case strong

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .light: return "轻度"
        case .medium: return "标准"
        case .strong: return "强力"
        }
    }

    var description: String {
        switch self {
        case .off: return "不做增强"
        case .light: return "轻度降噪+锐化，速度快"
        case .medium: return "AI 增强+降噪+锐化，推荐"
        case .strong: return "AI 增强+超分+强力优化，较慢"
        }
    }

    /// 是否启用 AI 增强
    var usesAI: Bool {
        switch self {
        case .off, .light: return false
        case .medium, .strong: return true
        }
    }

    /// 是否启用超分辨率放大
    var usesSuperResolution: Bool {
        self == .strong
    }
}

// MARK: - 阅读布局

/// 阅读器布局模式
enum ReaderLayout: String, Codable, CaseIterable {
    case paged      // 分页翻页（传统漫画）
    case webtoon    // 条漫模式（长图连续滚动）

    var displayName: String {
        switch self {
        case .paged: return "分页模式"
        case .webtoon: return "条漫模式"
        }
    }

    var description: String {
        switch self {
        case .paged: return "左右翻页，适合传统漫画"
        case .webtoon: return "上下连续滚动，适合条漫/长图"
        }
    }
}

// MARK: - 自动翻页

/// 自动翻页速度
enum AutoFlipSpeed: String, Codable, CaseIterable {
    case off
    case slow
    case normal
    case fast

    var displayName: String {
        switch self {
        case .off: return "关闭"
        case .slow: return "慢速（15秒）"
        case .normal: return "正常（10秒）"
        case .fast: return "快速（5秒）"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .off: return nil
        case .slow: return 15
        case .normal: return 10
        case .fast: return 5
        }
    }
}

import SwiftUI
import UIKit

/// App 图标选项数据结构
struct AppIconOption: Identifiable {
    /// alternateIconName（"default" 表示使用主图标）
    let id: String
    /// 显示名称
    let name: String
    /// 预览用的 SF Symbol 标识
    let previewSymbol: String
    /// 描述文字
    let description: String

    var isDefault: Bool { id == "default" }
}

/// 自定义 App 图标管理器
/// 负责管理和切换 App 的 alternate icons
/// 使用方法：
///   1. 在 SettingsView 中展示 availableIcons
///   2. 用户选择后调用 setIcon(_:)
///   3. currentIconName 会自动更新，UI 响应刷新
@MainActor
final class AppIconManager: ObservableObject {

    /// 共享单例
    static let shared = AppIconManager()
    private init() {
        refreshCurrentIcon()
    }

    /// 当前使用的图标名称（nil 或 "default" 表示使用主图标）
    @Published private(set) var currentIconName: String?

    /// 所有可用的图标选项
    let availableIcons: [AppIconOption] = [
        AppIconOption(
            id: "default",
            name: "默认",
            previewSymbol: "book.fill",
            description: "蓝色渐变背景 + 白色书本"
        ),
        AppIconOption(
            id: "dark",
            name: "深色版",
            previewSymbol: "book.fill",
            description: "纯黑背景 + 白色书本"
        ),
        AppIconOption(
            id: "manga",
            name: "漫画风",
            previewSymbol: "text.bubble.fill",
            description: "网点纹理背景 + 对话气泡"
        ),
        AppIconOption(
            id: "minimal",
            name: "简约风",
            previewSymbol: "book",
            description: "纯白背景 + 黑色线条书本"
        )
    ]

    /// 当前选中的图标选项
    var currentOption: AppIconOption {
        let name = currentIconName ?? "default"
        return availableIcons.first { $0.id == name } ?? availableIcons[0]
    }

    /// 切换 App 图标
    /// - Parameter option: 目标图标选项
    /// - Throws: 当图标切换失败时抛出错误
    func setIcon(_ option: AppIconOption) async throws {
        // 如果已经是当前图标，无需切换
        guard currentIconName != option.id else { return }

        // "default" 对应 nil（恢复主图标）
        let targetName: String? = option.id == "default" ? nil : option.id

        // 检查系统是否支持 alternate icons
        guard UIApplication.shared.supportsAlternateIcons else {
            throw AppIconError.notSupported
        }

        do {
            try await UIApplication.shared.setAlternateIconName(targetName)
            refreshCurrentIcon()
        } catch {
            print("⚠️ 切换 App 图标失败: \(error.localizedDescription)")
            throw error
        }
    }

    /// 从系统读取当前图标状态
    func refreshCurrentIcon() {
        currentIconName = UIApplication.shared.alternateIconName ?? "default"
    }
}

/// 图标切换错误类型
enum AppIconError: Error, LocalizedError {
    case notSupported

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "当前设备不支持更换 App 图标"
        }
    }
}

import AppIntents
import SwiftData
import UIKit

/// 漫画实体，用于 Siri 快捷指令中的参数选择
/// AppEntity 让 Siri/Shortcuts 可以展示可选的漫画列表供用户选择
struct ComicEntity: AppEntity, Identifiable {

    /// 对应 Comic.id
    let id: UUID

    /// 在 Siri 界面中显示的标题
    var displayString: String { title }

    /// 漫画标题
    let title: String

    /// 进度文本
    let progressText: String

    // MARK: - AppEntity 协议要求

    /// Siri 中显示的类型名称
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "漫画")

    /// 默认查询（用于根据 ID 查找实体）
    static var defaultQuery = ComicEntityQuery()

    /// 展示样式（列表中显示标题 + 副标题）
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(progressText)")
    }
}

// MARK: - 实体查询

/// 漫画实体查询：负责从 SwiftData 中获取漫画列表供 Siri 选择
struct ComicEntityQuery: EntityQuery {

    /// 根据标识符列表查找漫画实体
    /// - Parameter identifiers: 漫画 UUID 列表
    /// - Returns: 匹配的 ComicEntity 列表
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [ComicEntity] {
        guard let container = ComicReaderApp.modelContainer else { return [] }
        let context = container.mainContext

        var descriptor = FetchDescriptor<Comic>()
        let comics = (try? context.fetch(descriptor)) ?? []
        return comics
            .filter { identifiers.contains($0.id) }
            .map { ComicEntity(from: $0) }
    }

    /// Siri 建议的实体列表（最近添加的 10 本漫画）
    @MainActor
    func suggestedEntities() async throws -> [ComicEntity] {
        guard let container = ComicReaderApp.modelContainer else { return [] }
        let context = container.mainContext

        // 按 dateAdded 降序，取最近 10 本
        var descriptor = FetchDescriptor<Comic>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        descriptor.fetchLimit = 10

        let comics = (try? context.fetch(descriptor)) ?? []
        return comics.map { ComicEntity(from: $0) }
    }
}

// MARK: - 便利初始化

extension ComicEntity {
    /// 从 SwiftData Comic 模型创建 ComicEntity
    @MainActor
    init(from comic: Comic) {
        self.id = comic.id
        self.title = comic.title
        let progressPercent = Int(comic.progress * 100)
        self.progressText = "\(progressPercent)% · 第 \(comic.currentPage + 1) 页"
    }
}

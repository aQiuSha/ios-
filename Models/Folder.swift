import Foundation
import SwiftData
import UIKit

@Model
final class Folder {
    var id: UUID
    var name: String
    var iconName: String
    var colorData: Data?
    var createdAt: Date
    /// 是否为隐私文件夹（默认 false，带默认值的字段为 SwiftData 轻量迁移兼容）
    var isPrivate: Bool = false

    @Relationship(deleteRule: .nullify)
    var comics: [Comic]?

    init(
        name: String,
        iconName: String = "folder.fill",
        colorData: Data? = nil,
        isPrivate: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorData = colorData
        self.createdAt = Date()
        self.isPrivate = isPrivate
        self.comics = []
    }

    /// 从 colorData 解码 UIColor，默认蓝色
    var color: UIColor {
        guard let colorData else { return .systemBlue }
        return (try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData)) ?? .systemBlue
    }
}

import Foundation
import SwiftData
import UIKit

@Model
final class Comic {
    var id: UUID
    var title: String
    var coverPath: String?
    var pageCount: Int
    var currentPage: Int
    var dateAdded: Date
    var lastOpened: Date?
    var folderName: String
    var readingDirection: ReadingDirection.RawValue
    var pageMode: PageMode.RawValue
    var isFavorite: Bool
    var readingStatus: ReadingStatus.RawValue

    @Relationship(deleteRule: .nullify, inverse: \Folder.comics)
    var folder: Folder?

    init(
        title: String,
        coverPath: String? = nil,
        pageCount: Int,
        folderName: String
    ) {
        self.id = UUID()
        self.title = title
        self.coverPath = coverPath
        self.pageCount = pageCount
        self.currentPage = 0
        self.dateAdded = Date()
        self.lastOpened = nil
        self.folderName = folderName
        self.readingDirection = ReadingDirection.leftToRight.rawValue
        self.pageMode = PageMode.single.rawValue
        self.isFavorite = false
        self.readingStatus = ReadingStatus.unread.rawValue
    }

    var progress: Double {
        guard pageCount > 0 else { return 0 }
        return Double(currentPage) / Double(pageCount)
    }

    var isFinished: Bool {
        currentPage >= pageCount - 1
    }

    /// 自动推断阅读状态：手动设置优先，否则根据阅读进度推断
    var effectiveReadingStatus: ReadingStatus {
        if isFinished {
            return .finished
        }
        if currentPage == 0 {
            return .unread
        }
        return ReadingStatus(rawValue: readingStatus) ?? .reading
    }
}

enum ReadingDirection: String, Codable, CaseIterable {
    case leftToRight = "leftToRight"
    case rightToLeft = "rightToLeft"

    var displayName: String {
        switch self {
        case .leftToRight: return "从左到右"
        case .rightToLeft: return "从右到左（日漫）"
        }
    }
}

enum PageMode: String, Codable, CaseIterable {
    case single = "single"
    case double = "double"

    var displayName: String {
        switch self {
        case .single: return "单页"
        case .double: return "双页"
        }
    }
}

enum ReadingStatus: String, Codable, CaseIterable {
    case unread = "unread"
    case reading = "reading"
    case finished = "finished"
    case dropped = "dropped"

    var displayName: String {
        switch self {
        case .unread: return "待看"
        case .reading: return "在读"
        case .finished: return "已读完"
        case .dropped: return "弃坑"
        }
    }

    var color: UIColor {
        switch self {
        case .unread: return .gray
        case .reading: return .systemBlue
        case .finished: return .systemGreen
        case .dropped: return .systemRed
        }
    }
}

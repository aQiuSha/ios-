import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID
    var page: Int
    var createdAt: Date
    var note: String?
    var comic: Comic?

    init(page: Int, note: String? = nil, comic: Comic? = nil) {
        self.id = UUID()
        self.page = page
        self.createdAt = Date()
        self.note = note
        self.comic = comic
    }

    var pageDisplay: String {
        "第 \(page + 1) 页"
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

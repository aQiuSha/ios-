import SwiftUI
import SwiftData

/// 书签列表页面
struct BookmarksView: View {
    let comic: Comic?  // nil 表示查看全部书签
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var bookmarks: [Bookmark] = []
    @State private var showAddNote = false
    @State private var selectedBookmark: Bookmark?
    @State private var noteText = ""
    var onJumpToPage: ((Int) -> Void)?  // 从阅读器打开时用于跳转

    var body: some View {
        NavigationStack {
            Group {
                if bookmarks.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(bookmarks) { bookmark in
                            bookmarkRow(bookmark)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let onJumpToPage {
                                        onJumpToPage(bookmark.page)
                                        dismiss()
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        selectedBookmark = bookmark
                                        noteText = bookmark.note ?? ""
                                        showAddNote = true
                                    } label: {
                                        Label("编辑备注", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        deleteBookmark(bookmark)
                                    } label: {
                                        Label("删除书签", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                deleteBookmark(bookmarks[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle(comic == nil ? "全部书签" : "书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("编辑备注", isPresented: $showAddNote) {
                TextField("备注（可选）", text: $noteText)
                Button("取消", role: .cancel) {}
                Button("保存") {
                    if let bookmark = selectedBookmark {
                        bookmark.note = noteText.isEmpty ? nil : noteText
                        try? modelContext.save()
                        loadBookmarks()
                    }
                }
            }
            .onAppear {
                loadBookmarks()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("还没有书签")
                .font(.headline)
            Text("阅读时点击右上角书签按钮添加")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        HStack(spacing: 14) {
            // 页码标签
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 56, height: 56)
                VStack(spacing: 0) {
                    Text("\(bookmark.page + 1)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                    Text("页")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let comicTitle = bookmark.comic?.title {
                    Text(comicTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                if let note = bookmark.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                } else {
                    Text("无备注")
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
                Text(bookmark.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.tertiary)
            }

            Spacer()

            if onJumpToPage != nil {
                Image(systemName: "chevron.right")
                    .foregroundColor(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private func loadBookmarks() {
        let descriptor = FetchDescriptor<Bookmark>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        var all = (try? modelContext.fetch(descriptor)) ?? []
        if let comic {
            all = all.filter { $0.comic?.persistentModelID == comic.persistentModelID }
        }
        bookmarks = all
    }

    private func deleteBookmark(_ bookmark: Bookmark) {
        modelContext.delete(bookmark)
        try? modelContext.save()
        loadBookmarks()
    }
}

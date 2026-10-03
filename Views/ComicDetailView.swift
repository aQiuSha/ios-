import SwiftUI
import SwiftData

/// 漫画详情页：展示信息、章节、阅读历史
struct ComicDetailView: View {
    let comic: Comic
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showReader = false
    @State private var readingSessions: [ReadingSession] = []
    @State private var bookmarks: [Bookmark] = []

    var body: some View {
        List {
            // 封面 + 基本信息
            Section {
                HStack(alignment: .top, spacing: 16) {
                    // 封面
                    Group {
                        if let coverPath = comic.coverPath,
                           let image = UIImage(contentsOfFile: coverPath) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(Image(systemName: "book").font(.largeTitle).foregroundColor(.gray))
                        }
                    }
                    .frame(width: 100, height: 150)
                    .cornerRadius(8)
                    .clipped()

                    VStack(alignment: .leading, spacing: 6) {
                        Text(comic.title)
                            .font(.headline)
                            .lineLimit(3)

                        Text("共 \(comic.pageCount) 页")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // 阅读进度
                        if comic.pageCount > 0 {
                            ProgressView(value: Double(comic.currentPage + 1) / Double(comic.pageCount))
                            Text("已读 \(comic.currentPage + 1) / \(comic.pageCount) 页")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // 阅读状态
                        Text(comic.effectiveReadingStatus.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(uiColor: comic.effectiveReadingStatus.color).opacity(0.2))
                            .foregroundColor(Color(uiColor: comic.effectiveReadingStatus.color))
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, 8)
            }

            // 操作按钮
            Section {
                Button {
                    showReader = true
                } label: {
                    HStack {
                        Image(systemName: comic.currentPage > 0 ? "play.fill" : "book")
                        Text(comic.currentPage > 0 ? "继续阅读（第 \(comic.currentPage + 1) 页）" : "开始阅读")
                    }
                }

                NavigationLink {
                    BookmarksView(comic: comic, modelContext: modelContext)
                } label: {
                    HStack {
                        Image(systemName: "bookmark")
                        Text("书签（\(bookmarks.count)）")
                    }
                }
            }

            // 元信息
            Section("信息") {
                LabeledContent("添加时间", value: formattedDate(comic.dateAdded))
                LabeledContent("最后阅读", value: comic.lastOpened.map { formattedDate($0) } ?? "从未")
                LabeledContent("文件夹", value: comic.folder?.name ?? "未分类")
                LabeledContent("收藏", value: comic.isFavorite ? "已收藏" : "未收藏")
            }

            // 阅读历史
            if !readingSessions.isEmpty {
                Section("阅读历史") {
                    ForEach(Array(readingSessions.prefix(20))) { session in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(formattedDate(session.startTime))
                                    .font(.subheadline)
                                Text("阅读 \(formatDuration(session.duration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showReader) {
            ReaderView(comic: comic, modelContext: modelContext)
        }
        .onAppear(perform: loadData)
    }

    private func loadData() {
        let comicID = comic.id
        // 加载阅读历史
        let descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate { $0.comic?.id == comicID },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        readingSessions = (try? modelContext.fetch(descriptor)) ?? []

        // 加载书签
        let bookmarkDescriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { $0.comic?.id == comicID },
            sortBy: [SortDescriptor(\.page)]
        )
        bookmarks = (try? modelContext.fetch(bookmarkDescriptor)) ?? []
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins < 60 { return "\(mins) 分钟" }
        return "\(mins / 60) 小时 \(mins % 60) 分"
    }
}

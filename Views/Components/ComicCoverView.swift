import SwiftUI

/// 漫画封面卡片视图
struct ComicCoverView: View {
    let comic: Comic
    var isSelected: Bool = false
    var isMultiSelectMode: Bool = false
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 210)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 150, height: 210)
                        .overlay(
                            Image(systemName: "book")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }

                // 阅读进度条
                if comic.progress > 0 && !comic.isFinished {
                    VStack {
                        Spacer()
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.blue.opacity(0.8))
                                .frame(width: geo.size.width * comic.progress, height: 4)
                        }
                        .frame(height: 4)
                    }
                }

                // 已读完标记（多选模式下不显示）
                if comic.isFinished && !isMultiSelectMode {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .padding(6)
                        }
                        Spacer()
                    }
                }

                // 阅读状态标签（封面底部小胶囊）
                VStack {
                    Spacer()
                    HStack {
                        statusCapsule
                        Spacer()
                    }
                    .padding(6)
                }
            }
            .frame(width: 150, height: 210)
            .overlay(alignment: .topLeading) {
                // 多选模式下的选中圆圈
                if isMultiSelectMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : .white)
                        .background(Circle().fill(isSelected ? Color.clear : Color.black.opacity(0.3)))
                        .padding(6)
                }
            }
            .overlay(alignment: .topTrailing) {
                // 收藏爱心角标
                if comic.isFavorite && !isMultiSelectMode {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .padding(6)
                }
            }

            Text(comic.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 150, alignment: .leading)

            Text("\(comic.pageCount) 页")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .onAppear {
            thumbnail = FileStorageService.shared.loadThumbnail(path: comic.coverPath)
        }
    }

    // MARK: - 状态胶囊标签

    private var statusCapsule: some View {
        let status = comic.effectiveReadingStatus
        return Text(status.displayName)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(status.color).opacity(0.9))
            .cornerRadius(4)
    }
}

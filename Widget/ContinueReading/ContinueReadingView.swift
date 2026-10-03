import WidgetKit
import SwiftUI

/// 「继续阅读」小组件视图
/// 根据 widgetFamily 自动适配小尺寸和中尺寸
struct ContinueReadingView: View {
    var entry: ContinueReadingProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        default:
            smallLayout
        }
    }

    // MARK: - 小尺寸布局

    /// 小尺寸：封面 + 标题 + 进度百分比
    private var smallLayout: some View {
        ZStack {
            if let comic = entry.comic {
                VStack(spacing: 6) {
                    // 封面图
                    coverImageView
                        .frame(width: 80, height: 110)
                        .cornerRadius(8)

                    // 标题（最多 2 行）
                    Text(comic.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)

                    // 进度百分比
                    Text(comic.progressText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
            } else {
                // 无数据时的占位视图
                placeholderView
            }
        }
        .widgetURL(URL(string: "comicreader://continue"))
    }

    // MARK: - 中尺寸布局

    /// 中尺寸：封面 + 标题 + 进度条 + "继续阅读"
    private var mediumLayout: some View {
        HStack(spacing: 14) {
            if let comic = entry.comic {
                // 左侧封面
                coverImageView
                    .frame(width: 100, height: 140)
                    .cornerRadius(10)

                // 右侧信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(comic.title)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text("第 \(comic.currentPage + 1) 页 / 共 \(comic.pageCount) 页")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // 进度条
                    ProgressView(value: comic.progress)
                        .tint(.blue)

                    HStack(spacing: 4) {
                        Image(systemName: "book.fill")
                            .font(.caption)
                        Text("继续阅读")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.vertical, 8)
            } else {
                placeholderView
            }
        }
        .padding(16)
        .widgetURL(URL(string: "comicreader://continue"))
    }

    // MARK: - 子视图

    /// 封面图（有图显示图片，无图显示占位 SF Symbol）
    @ViewBuilder
    private var coverImageView: some View {
        if let image = entry.coverImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay(
                    Image(systemName: "book.closed.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                )
        }
    }

    /// 无数据占位视图
    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "book")
                .font(.system(size: 36))
                .foregroundColor(.gray)
            Text("暂无阅读记录")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

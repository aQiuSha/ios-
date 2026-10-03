import ActivityKit
import SwiftUI

/// 阅读实时活动的 Widget 视图（锁屏 + 灵动岛）
///
/// 使用说明：
/// 1. 在 Xcode 中添加 Widget Extension Target
/// 2. 将此文件加入 Widget Target
/// 3. 在 Widget Bundle 中注册 ReadingActivityWidget
/// 4. 主 App Info.plist 添加 NSSupportsLiveActivities = YES
@available(iOS 16.1, *)
struct ReadingActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingActivityAttributes.self) { context in
            // 锁屏实时活动视图
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开状态
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.fill")
                            .foregroundColor(.blue)
                        Text(context.state.comicTitle)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.currentPage + 1)/\(context.state.totalPages)")
                        .font(.caption2)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(formatDuration(context.state.readingDuration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                // 紧凑状态左侧
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
            } compactTrailing: {
                // 紧凑状态右侧
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                // 最小状态（多个活动同时存在时）
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
            }
        }
    }

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) 分钟"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// 锁屏实时活动视图
@available(iOS 16.1, *)
private struct LockScreenLiveActivityView: View {
    let context: ActivityView.Context<ReadingActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                Text(context.state.comicTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(context.state.currentPage + 1) / \(context.state.totalPages)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            ProgressView(value: context.state.progress)
                .progressViewStyle(.linear)
                .tint(.blue)

            HStack {
                Label(formatDuration(context.state.readingDuration), systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("已读 \(Int(context.state.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) 分钟"
        }
        return "\(minutes / 60) 小时 \(minutes % 60) 分"
    }
}

import WidgetKit
import SwiftUI

/// 「阅读统计」小组件视图
/// 根据尺寸自适应布局
struct ReadingStatsView: View {
    var entry: ReadingStatsProvider.Entry
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

    /// 小尺寸：两个数字上下排列
    private var smallLayout: some View {
        VStack(spacing: 12) {
            // 今日阅读时长
            VStack(spacing: 2) {
                Text(timeDisplayText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                Text("今日阅读")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // 连续阅读天数
            VStack(spacing: 2) {
                Text("\(entry.stats.currentStreak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                Text("连续天数")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "comicreader://stats"))
    }

    // MARK: - 中尺寸布局

    /// 中尺寸：横向排列，带图标和说明文字
    private var mediumLayout: some View {
        HStack(spacing: 0) {
            // 左侧：今日阅读时长
            statsColumn(
                icon: "clock.fill",
                iconColor: .blue,
                value: timeDisplayText,
                label: "今日阅读"
            )

            Divider()
                .padding(.horizontal, 16)

            // 右侧：连续阅读天数
            statsColumn(
                icon: "flame.fill",
                iconColor: .orange,
                value: "\(entry.stats.currentStreak) 天",
                label: "连续阅读"
            )
        }
        .padding(16)
        .widgetURL(URL(string: "comicreader://stats"))
    }

    // MARK: - 子视图

    /// 统计列（图标 + 数值 + 标签）
    private func statsColumn(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(iconColor)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 时间显示文本（分钟 < 60 显示分钟，否则显示小时+分钟）
    private var timeDisplayText: String {
        let minutes = entry.stats.todayMinutes
        if minutes < 60 {
            return "\(minutes)分"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if mins == 0 {
            return "\(hours)时"
        }
        return "\(hours)时\(mins)分"
    }
}

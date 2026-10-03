import SwiftUI
import SwiftData

/// 阅读统计页面
struct StatsView: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: StatsViewModel

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = StateObject(wrappedValue: StatsViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 今日概览大卡片
                    todayCard

                    // 数据指标网格
                    metricsGrid

                    // 最近7天柱状图
                    weeklyChartCard

                    // 漫画阅读排行
                    if !viewModel.stats.comicRankings.isEmpty {
                        comicRankingCard
                    }
                }
                .padding(16)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("阅读统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                viewModel.loadStats()
            }
            .refreshable {
                viewModel.loadStats()
            }
        }
    }

    // MARK: - 今日卡片

    private var todayCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.white)
                Text("今日阅读")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text("\(hoursFromDuration(viewModel.stats.todayDuration))")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
                Text("小时")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 8)
                Text(" \(minutesFromDuration(viewModel.stats.todayDuration))")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
                Text("分钟")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                statMini(label: "本周", value: StatsViewModel.formatDurationShort(viewModel.stats.weekDuration))
                Divider().background(Color.white.opacity(0.3))
                statMini(label: "本月", value: StatsViewModel.formatDurationShort(viewModel.stats.monthDuration))
                Divider().background(Color.white.opacity(0.3))
                statMini(label: "累计", value: StatsViewModel.formatDurationShort(viewModel.stats.totalDuration))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.45, blue: 0.95), Color(red: 0.15, green: 0.30, blue: 0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }

    private func statMini(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 指标网格

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            metricCard(icon: "flame.fill", iconColor: .orange, title: "连续阅读", value: "\(viewModel.stats.currentStreak)", unit: "天")
            metricCard(icon: "trophy.fill", iconColor: .yellow, title: "最长连续", value: "\(viewModel.stats.longestStreak)", unit: "天")
            metricCard(icon: "calendar", iconColor: .green, title: "阅读天数", value: "\(viewModel.stats.readingDays)", unit: "天")
            metricCard(icon: "book.fill", iconColor: .purple, title: "阅读次数", value: "\(viewModel.stats.totalSessions)", unit: "次")
        }
    }

    private func metricCard(icon: String, iconColor: Color, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - 周柱状图

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近 7 天")
                .font(.headline)

            if viewModel.stats.dailyData.allSatisfy({ $0.duration == 0 }) {
                Text("暂无数据")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else {
                let maxDuration = max(viewModel.stats.dailyData.map { $0.duration }.max() ?? 1, 1)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(viewModel.stats.dailyData) { day in
                        VStack(spacing: 6) {
                            Text(StatsViewModel.formatDurationShort(day.duration))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(height: 14)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(day.duration > 0 ? Color.blue : Color.gray.opacity(0.2))
                                .frame(height: max(4, CGFloat(day.duration / maxDuration) * 100))
                            Text(day.dayLabel)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 150)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - 漫画排行

    private var comicRankingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("阅读时长排行")
                .font(.headline)

            ForEach(Array(viewModel.stats.comicRankings.prefix(10).enumerated()), id: \.element.id) { index, ranking in
                HStack(spacing: 12) {
                    // 排名
                    ZStack {
                        Circle()
                            .fill(rankColor(index))
                            .frame(width: 28, height: 28)
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ranking.comic.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text("\(ranking.sessions) 次阅读")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(StatsViewModel.formatDurationShort(ranking.duration))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 4)

                if index < min(viewModel.stats.comicRankings.count, 10) - 1 {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 2: return Color(red: 0.80, green: 0.55, blue: 0.35)
        default: return .gray.opacity(0.5)
        }
    }

    // MARK: - 辅助

    private func hoursFromDuration(_ duration: TimeInterval) -> Int {
        Int(duration / 3600)
    }

    private func minutesFromDuration(_ duration: TimeInterval) -> Int {
        Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
    }
}

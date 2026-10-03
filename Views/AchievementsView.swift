import SwiftUI

/// 成就展示页
struct AchievementsView: View {
    @State private var unlocked: Set<Achievement> = []

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ScrollView {
            // 进度概览
            VStack(spacing: 8) {
                Text("\(unlocked.count) / \(Achievement.allCases.count)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("已解锁成就")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ProgressView(value: Double(unlocked.count) / Double(Achievement.allCases.count))
                    .padding(.horizontal, 40)
            }
            .padding(.vertical, 24)

            // 成就网格
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Achievement.allCases) { achievement in
                    AchievementCard(achievement: achievement, unlocked: unlocked.contains(achievement))
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("成就")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            unlocked = AchievementService.shared.unlockedAchievements
        }
    }
}

/// 单个成就卡片
struct AchievementCard: View {
    let achievement: Achievement
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? achievement.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: achievement.icon)
                    .font(.title2)
                    .foregroundColor(unlocked ? achievement.color : .gray)
                    .opacity(unlocked ? 1.0 : 0.4)
            }

            Text(achievement.title)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(unlocked ? .primary : .secondary)

            Text(achievement.description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(unlocked ? achievement.color.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
        )
        .opacity(unlocked ? 1.0 : 0.6)
    }
}

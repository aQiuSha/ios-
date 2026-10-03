import ActivityKit
import Foundation
import UIKit

/// 管理阅读实时活动（灵动岛 + 锁屏）
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<ReadingActivityAttributes>?
    private var startTime: Date?
    private var accumulatedDuration: TimeInterval = 0
    private var durationTimer: Timer?

    /// 是否启用实时活动
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "liveActivityEnabled")
            if !isEnabled {
                endActivity()
            }
        }
    }

    private init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "liveActivityEnabled")
        // 默认开启
        if !UserDefaults.standard.bool(forKey: "liveActivityEnabled_initialized") {
            self.isEnabled = true
            UserDefaults.standard.set(true, forKey: "liveActivityEnabled_initialized")
        }
    }

    /// 检查设备是否支持实时活动
    var isSupported: Bool {
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        return false
    }

    // MARK: - 活动生命周期

    /// 开始阅读活动
    func startActivity(comicID: String, title: String, currentPage: Int, totalPages: Int) {
        guard isEnabled, isSupported else { return }
        guard #available(iOS 16.1, *) else { return }

        // 如果已有活动，先结束
        endActivity()

        startTime = Date()
        accumulatedDuration = 0

        let attributes = ReadingActivityAttributes(
            comicID: comicID,
            comicTitle: title
        )
        let state = ReadingActivityAttributes.ContentState(
            comicTitle: title,
            currentPage: currentPage,
            totalPages: totalPages,
            progress: totalPages > 0 ? Double(currentPage + 1) / Double(totalPages) : 0,
            readingDuration: 0
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            startDurationTimer()
        } catch {
            print("Failed to start live activity: \(error)")
        }
    }

    /// 更新当前页码
    func updateActivity(currentPage: Int, totalPages: Int) {
        guard isEnabled, let activity = currentActivity else { return }
        guard #available(iOS 16.1, *) else { return }

        let duration = currentDuration
        let state = ReadingActivityAttributes.ContentState(
            comicTitle: activity.attributes.comicTitle,
            currentPage: currentPage,
            totalPages: totalPages,
            progress: totalPages > 0 ? Double(currentPage + 1) / Double(totalPages) : 0,
            readingDuration: duration
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    /// 结束阅读活动
    func endActivity() {
        guard #available(iOS 16.1, *) else { return }
        stopDurationTimer()

        guard let activity = currentActivity else { return }

        let finalState = ReadingActivityAttributes.ContentState(
            comicTitle: activity.attributes.comicTitle,
            currentPage: activity.content.state.currentPage,
            totalPages: activity.content.state.totalPages,
            progress: activity.content.state.progress,
            readingDuration: currentDuration
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        currentActivity = nil
        startTime = nil
        accumulatedDuration = 0
    }

    /// 暂停计时（进入后台）
    func pause() {
        guard let start = startTime else { return }
        accumulatedDuration += Date().timeIntervalSince(start)
        startTime = nil
        stopDurationTimer()
    }

    /// 恢复计时（回到前台）
    func resume() {
        guard startTime == nil else { return }
        startTime = Date()
        startDurationTimer()
    }

    // MARK: - 计时

    private var currentDuration: TimeInterval {
        var duration = accumulatedDuration
        if let start = startTime {
            duration += Date().timeIntervalSince(start)
        }
        return duration
    }

    private func startDurationTimer() {
        stopDurationTimer()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickDuration()
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func tickDuration() {
        guard let activity = currentActivity else { return }
        let duration = currentDuration
        let state = ReadingActivityAttributes.ContentState(
            comicTitle: activity.attributes.comicTitle,
            currentPage: activity.content.state.currentPage,
            totalPages: activity.content.state.totalPages,
            progress: activity.content.state.progress,
            readingDuration: duration
        )
        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }
}

import Foundation

/// iCloud 同步服务：多设备同步阅读进度
///
/// 使用 NSUbiquitousKeyValueStore（iCloud KV），无需额外配置 CloudKit，
/// 只需在 Xcode → Signing & Capabilities 添加 iCloud → Key-value storage。
/// 同步内容：每本漫画的阅读进度、阅读时长、收藏状态。
final class ICloudSyncService {
    static let shared = ICloudSyncService()
    private init() {}

    private let store = NSUbiquitousKeyValueStore.default
    private let progressPrefix = "comic_progress_"
    private let totalMinutesKey = "sync_total_reading_minutes"
    private let enabledKey = "iCloudSyncEnabled"

    /// 是否启用 iCloud 同步
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if newValue {
                store.synchronize()
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(storeDidChange),
                    name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                    object: store
                )
            } else {
                NotificationCenter.default.removeObserver(self, name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
            }
        }
    }

    /// iCloud 是否可用
    var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - 阅读进度同步

    /// 同步某本漫画的阅读进度
    func syncProgress(comicID: String, page: Int, totalPages: Int) {
        guard isEnabled else { return }
        let key = progressPrefix + comicID
        let data: [String: Any] = [
            "page": page,
            "totalPages": totalPages,
            "timestamp": Date().timeIntervalSince1970
        ]
        store.set(data, forKey: key)
        store.synchronize()
    }

    /// 获取某本漫画的云端阅读进度
    func remoteProgress(for comicID: String) -> (page: Int, totalPages: Int, date: Date)? {
        let key = progressPrefix + comicID
        guard let data = store.dictionary(forKey: key),
              let page = data["page"] as? Int,
              let totalPages = data["totalPages"] as? Int,
              let timestamp = data["timestamp"] as? TimeInterval else {
            return nil
        }
        return (page, totalPages, Date(timeIntervalSince1970: timestamp))
    }

    /// 同步总阅读时长
    func syncTotalMinutes(_ minutes: Int) {
        guard isEnabled else { return }
        store.set(minutes, forKey: totalMinutesKey)
        store.synchronize()
    }

    /// 获取云端总阅读时长
    var remoteTotalMinutes: Int {
        store.longLong(forKey: totalMinutesKey)
    }

    // MARK: - 冲突解决

    /// 比较本地和云端进度，返回较新的一方
    /// - Returns: (page, shouldUseRemote)
    func resolveProgress(comicID: String, localPage: Int, localDate: Date) -> (page: Int, useRemote: Bool) {
        guard let remote = remoteProgress(for: comicID) else {
            return (localPage, false)
        }
        if remote.date > localDate {
            return (remote.page, true)
        }
        return (localPage, false)
    }

    // MARK: - 外部变更通知

    @objc private func storeDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        // 发送通知，让 UI 层决定是否刷新
        NotificationCenter.default.post(name: .iCloudSyncDidUpdate, object: nil, userInfo: ["keys": keys])
    }

    /// 手动同步
    func synchronize() {
        store.synchronize()
    }
}

extension Notification.Name {
    static let iCloudSyncDidUpdate = Notification.Name("iCloudSyncDidUpdate")
}

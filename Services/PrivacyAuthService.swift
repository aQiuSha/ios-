import Foundation
import LocalAuthentication
import Combine

/// 隐私文件夹身份验证服务
/// 使用 LocalAuthentication 框架进行生物识别（Face ID / Touch ID）验证，
/// 验证失败时回退到设备密码。解锁后 5 分钟无操作自动重新锁定。
final class PrivacyAuthService: ObservableObject {
    static let shared = PrivacyAuthService()
    private init() {}

    /// 解锁状态（外部只读）
    @Published private(set) var isUnlocked: Bool = false

    /// 最近一次解锁时间戳
    private var unlockTime: Date?

    /// 自动锁定时长（秒）：5 分钟
    private let lockTimeout: TimeInterval = 300

    /// 生物识别策略：生物识别+设备密码
    private let policy: LAPolicy = .deviceOwnerAuthentication

    // MARK: - 公开方法

    /// 进行身份验证，成功后解锁隐私文件夹
    /// - Parameter reason: 验证提示文案
    /// - Returns: 验证是否成功
    func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?

        // 检查设备是否支持生物识别或密码验证
        guard context.canEvaluatePolicy(policy, error: &error) else {
            return false
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, _ in
                if success {
                    self?.isUnlocked = true
                    self?.unlockTime = Date()
                }
                continuation.resume(returning: success)
            }
        }
    }

    /// 检查锁定状态：如果解锁时间超过 5 分钟，自动重新锁定
    /// 每次访问隐私内容前应调用此方法
    func checkLockStatus() {
        guard isUnlocked, let unlockTime else { return }
        if Date().timeIntervalSince(unlockTime) > lockTimeout {
            lock()
        }
    }

    /// 手动锁定隐私文件夹
    func lock() {
        isUnlocked = false
        unlockTime = nil
    }
}

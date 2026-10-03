import Foundation
import LocalAuthentication

/// App 密码锁服务：启动时验证身份
final class AppLockService {
    static let shared = AppLockService()
    private init() {}

    private let defaults = UserDefaults.standard
    private let enabledKey = "appLockEnabled"
    private let pinKey = "appLockPIN"
    private let biometricKey = "appLockBiometric"
    private let lastUnlockKey = "lastUnlockTime"
    private let gracePeriod: TimeInterval = 30 // 30秒内重新打开不需要验证

    /// 是否启用密码锁
    var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set { defaults.set(newValue, forKey: enabledKey) }
    }

    /// 是否启用生物识别（Face ID/Touch ID）
    var biometricEnabled: Bool {
        get { defaults.bool(forKey: biometricKey) }
        set { defaults.set(newValue, forKey: biometricKey) }
    }

    /// 是否已设置 PIN
    var hasPIN: Bool {
        defaults.string(forKey: pinKey) != nil
    }

    /// 设置 PIN
    func setPIN(_ pin: String) {
        defaults.set(pin, forKey: pinKey)
    }

    /// 清除 PIN 和密码锁设置
    func clearLock() {
        defaults.removeObject(forKey: pinKey)
        defaults.removeObject(forKey: enabledKey)
        defaults.removeObject(forKey: biometricKey)
    }

    /// 验证 PIN
    func verifyPIN(_ pin: String) -> Bool {
        pin == defaults.string(forKey: pinKey)
    }

    /// 是否需要验证（考虑宽限期）
    var needsAuthentication: Bool {
        guard isEnabled else { return false }
        guard hasPIN else { return false }
        if let last = defaults.object(forKey: lastUnlockKey) as? Date,
           Date().timeIntervalSince(last) < gracePeriod {
            return false
        }
        return true
    }

    /// 记录解锁时间
    func markUnlocked() {
        defaults.set(Date(), forKey: lastUnlockKey)
    }

    /// 生物识别验证
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void) {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success { self.markUnlocked() }
                completion(success, error)
            }
        }
    }

    /// 生物识别类型
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    var biometricTypeName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .none: return "无"
        case .opticID: return "Optic ID"
        @unknown default: return "生物识别"
        }
    }
}

import Foundation
import UIKit
import MediaPlayer

/// 音量键翻页服务
///
/// 通过监听系统音量变化来实现音量键翻页。
/// 使用 MPVolumeView 隐藏系统音量 HUD，监听 AVSystemController 音量变化通知。
final class VolumeKeyService {
    static let shared = VolumeKeyService()
    private init() {}

    private let defaults = UserDefaults.standard
    private let enabledKey = "volumeKeyFlipEnabled"
    private var volumeView: MPVolumeView?
    private var originalVolume: Float = 0.5
    private var isListening = false

    /// 翻页回调
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?

    /// 是否启用音量键翻页
    var isEnabled: Bool {
        get { defaults.bool(forKey: enabledKey) }
        set {
            defaults.set(newValue, forKey: enabledKey)
            if newValue { startListening() } else { stopListening() }
        }
    }

    /// 开始监听音量键
    func startListening() {
        guard !isListening else { return }
        isListening = true

        // 保存当前音量
        originalVolume = AVAudioSession.sharedInstance().outputVolume

        // 创建隐藏的 MPVolumeView 来抑制系统音量 HUD
        let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 100, height: 100))
        volumeView.alpha = 0.01
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first(where: { $0.isKeyWindow }) {
            window.addSubview(volumeView)
        }
        self.volumeView = volumeView

        // 监听音量变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeChanged),
            name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )

        // 激活音频会话
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// 停止监听
    func stopListening() {
        guard isListening else { return }
        isListening = false
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
        volumeView?.removeFromSuperview()
        volumeView = nil
    }

    @objc private func volumeChanged(_ notification: Notification) {
        guard isEnabled else { return }
        guard let userInfo = notification.userInfo,
              let reason = userInfo["AVSystemController_AudioVolumeChangeReasonNotificationParameter"] as? String,
              reason == "ExplicitVolumeChange" else { return }

        let currentVolume = AVAudioSession.sharedInstance().outputVolume

        if currentVolume > originalVolume {
            onVolumeUp?()
        } else if currentVolume < originalVolume {
            onVolumeDown?()
        }

        // 将音量重置回原始值，避免实际改变系统音量
        originalVolume = currentVolume
        DispatchQueue.main.async {
            self.resetVolume()
        }
    }

    private func resetVolume() {
        // 通过 MPVolumeView 的 slider 重置音量
        guard let volumeView = volumeView else { return }
        for subview in volumeView.subviews {
            if let slider = subview as? UISlider {
                slider.value = originalVolume
                slider.sendActions(for: .valueChanged)
                break
            }
        }
    }
}

import SwiftUI
import LocalAuthentication

/// App 密码锁验证页
struct AppLockView: View {
    let onUnlock: () -> Void
    @State private var pin = ""
    @State private var shake = false
    @State private var errorMessage = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.bottom, 10)

            Text("漫画阅读器已锁定")
                .font(.title2)
                .fontWeight(.semibold)

            Text("请输入 PIN 码解锁")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // PIN 输入显示
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            }
            .modifier(ShakeEffect(animatableData: shake ? 1 : 0))

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // 隐藏的输入框
            SecureField("", text: $pin)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 0, height: 0)
                .onChange(of: pin) { _, newValue in
                    if newValue.count >= 4 {
                        verifyPin(newValue)
                    }
                }

            Spacer()

            // 生物识别按钮
            if AppLockService.shared.biometricEnabled &&
               AppLockService.shared.biometricType != .none {
                Button {
                    authenticateBiometric()
                } label: {
                    HStack {
                        Image(systemName: biometricIcon)
                        Text("使用\(AppLockService.shared.biometricTypeName)解锁")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
        }
        .padding()
        .onAppear {
            isFocused = true
            // 自动尝试生物识别
            if AppLockService.shared.biometricEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateBiometric()
                }
            }
        }
    }

    private var biometricIcon: String {
        switch AppLockService.shared.biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        default: return "lock"
        }
    }

    private func verifyPin(_ input: String) {
        if AppLockService.shared.verifyPIN(input) {
            AppLockService.shared.markUnlocked()
            onUnlock()
        } else {
            errorMessage = "PIN 码错误"
            withAnimation(.default) { shake = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shake = false
                pin = ""
            }
        }
    }

    private func authenticateBiometric() {
        AppLockService.shared.authenticateWithBiometrics(reason: "解锁漫画阅读器") { success, _ in
            if success { onUnlock() }
        }
    }
}

/// 抖动动画效果
struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 6) * 8, y: 0))
    }
}

// MARK: - 设置 PIN 码页

/// 设置/修改 PIN 码页
struct SetPINView: View {
    let onComplete: () -> Void
    @State private var phase: PINPhase = .enter
    @State private var firstPIN = ""
    @State private var secondPIN = ""
    @FocusState private var isFocused: Bool

    enum PINPhase {
        case enter
        case confirm
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.rectangle.stack")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text(phase == .enter ? "设置 4 位 PIN 码" : "再次输入 PIN 码")
                .font(.title3)
                .fontWeight(.semibold)

            Text(phase == .enter ? "用于解锁 App，请牢记" : "请再次输入以确认")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < currentPIN.count ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 16, height: 16)
                }
            }

            SecureField("", text: currentBinding)
                .keyboardType(.numberPad)
                .focused($isFocused)
                .opacity(0)
                .frame(width: 0, height: 0)

            Spacer()

            if phase == .confirm {
                Button("重新设置") {
                    phase = .enter
                    firstPIN = ""
                    secondPIN = ""
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .navigationTitle("设置 PIN 码")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { isFocused = true }
        .onChange(of: firstPIN) { _, newValue in
            if phase == .enter && newValue.count >= 4 {
                phase = .confirm
            }
        }
        .onChange(of: secondPIN) { _, newValue in
            if phase == .confirm && newValue.count >= 4 {
                if newValue == firstPIN {
                    AppLockService.shared.setPIN(newValue)
                    AppLockService.shared.isEnabled = true
                    onComplete()
                } else {
                    // 不匹配，重置
                    firstPIN = ""
                    secondPIN = ""
                    phase = .enter
                }
            }
        }
    }

    private var currentPIN: String {
        phase == .enter ? firstPIN : secondPIN
    }

    private var currentBinding: Binding<String> {
        Binding(
            get: { phase == .enter ? firstPIN : secondPIN },
            set: { newValue in
                if phase == .enter { firstPIN = String(newValue.prefix(4)) }
                else { secondPIN = String(newValue.prefix(4)) }
            }
        )
    }
}

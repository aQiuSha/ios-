import SwiftUI
import SwiftData
import PhotosUI

/// 设置页面
struct SettingsView: View {
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultReadingDirection") private var defaultDirection: String = ReadingDirection.leftToRight.rawValue
    @AppStorage("defaultPageMode") private var defaultPageMode: String = PageMode.single.rawValue

    // 阅读主题
    @AppStorage("readerTheme") private var readerThemeRaw = ReaderTheme.pureBlack.rawValue
    @AppStorage("autoNightMode") private var autoNightMode = false

    // 翻页动画
    @AppStorage("pageTransition") private var pageTransitionRaw = PageTransition.slide.rawValue

    // 阅读布局 / 自动翻页 / 音量键
    @AppStorage("readerLayout") private var readerLayoutRaw = ReaderLayout.paged.rawValue
    @AppStorage("autoFlipSpeed") private var autoFlipSpeedRaw = AutoFlipSpeed.off.rawValue
    @AppStorage("volumeKeyFlip") private var volumeKeyFlip = false

    // App 密码锁
    @State private var showSetPIN = false
    @State private var showDisableLockConfirmation = false

    // iCloud 同步
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false

    // 图片预处理
    @AppStorage("autoCropWhiteBorder") private var autoCropWhiteBorder = false
    @AppStorage("enhanceContrast") private var enhanceContrast = false
    @AppStorage("grayscaleMode") private var grayscaleMode = false

    // AI 画质增强
    @AppStorage("imageEnhanceLevel") private var imageEnhanceLevelRaw = ImageEnhanceLevel.off.rawValue
    private var imageEnhanceLevel: ImageEnhanceLevel {
        ImageEnhanceLevel(rawValue: imageEnhanceLevelRaw) ?? .off
    }

    // 手势自定义
    @AppStorage("tapLeftAction") private var tapLeftRaw = TapAction.prevPage.rawValue
    @AppStorage("tapCenterAction") private var tapCenterRaw = TapAction.toggleMenu.rawValue
    @AppStorage("tapRightAction") private var tapRightRaw = TapAction.nextPage.rawValue
    @AppStorage("swipeLeftAction") private var swipeLeftRaw = SwipeAction.nextPage.rawValue
    @AppStorage("swipeRightAction") private var swipeRightRaw = SwipeAction.prevPage.rawValue

    // 自定义背景
    @AppStorage("customBackgroundBlur") private var customBackgroundBlur: Double = 20
    @AppStorage("customBackgroundOpacity") private var customBackgroundOpacity: Double = 0.3
    @State private var backgroundPickerItem: PhotosPickerItem?
    @State private var hasCustomBackground = false

    // 强调色
    @AppStorage("accentColor") private var accentColorRaw = AccentColor.blue.rawValue

    // 实时活动
    @StateObject private var liveActivityManager = LiveActivityManager.shared

    @State private var totalStorageSize: String = "计算中..."
    @State private var cacheSize: String = "计算中..."
    @State private var showWiFiTransfer = false
    @State private var showClearCacheConfirmation = false
    @StateObject private var privacyAuthService = PrivacyAuthService.shared
    @StateObject private var iconManager = AppIconManager.shared
    @State private var showIconError = false
    @State private var iconErrorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("阅读偏好") {
                    Picker("默认阅读方向", selection: $defaultDirection) {
                        ForEach(ReadingDirection.allCases, id: \.self) { dir in
                            Text(dir.displayName).tag(dir.rawValue)
                        }
                    }

                    Picker("默认页面模式", selection: $defaultPageMode) {
                        ForEach(PageMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }

                    Picker("阅读布局", selection: $readerLayoutRaw) {
                        ForEach(ReaderLayout.allCases, id: \.self) { layout in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(layout.displayName)
                                Text(layout.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .tag(layout.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("自动翻页", selection: $autoFlipSpeedRaw) {
                        ForEach(AutoFlipSpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName).tag(speed.rawValue)
                        }
                    }

                    Toggle("音量键翻页", isOn: $volumeKeyFlip)
                    if volumeKeyFlip {
                        Text("按音量+下一页，音量-上一页。系统音量不会改变。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - 阅读主题
                Section("阅读主题") {
                    Picker("背景主题", selection: $readerThemeRaw) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            if theme == .custom && !hasCustomBackground {
                                // 自定义主题仅在有背景图片时可选
                                EmptyView()
                            } else {
                                HStack(spacing: 8) {
                                    if theme == .custom, let bg = FileStorageService.shared.loadCustomBackground() {
                                        Image(uiImage: bg)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 20, height: 20)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(theme.background)
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Circle().stroke(Color.secondary, lineWidth: 0.5)
                                            )
                                    }
                                    Text(theme.displayName)
                                }
                                .tag(theme.rawValue)
                            }
                        }
                    }
                    Toggle("夜间自动切换（18:00-06:00）", isOn: $autoNightMode)
                }

                // MARK: - 自定义背景
                Section("自定义背景") {
                    HStack {
                        Text("背景图片")
                        Spacer()
                        PhotosPicker(selection: $backgroundPickerItem, matching: .images) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle")
                                Text(hasCustomBackground ? "更换" : "选择图片")
                            }
                            .foregroundColor(.blue)
                        }
                        if hasCustomBackground {
                            Button(role: .destructive) {
                                FileStorageService.shared.removeCustomBackground()
                                hasCustomBackground = false
                                if readerThemeRaw == ReaderTheme.custom.rawValue {
                                    readerThemeRaw = ReaderTheme.pureBlack.rawValue
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .padding(.leading, 8)
                        }
                    }

                    if hasCustomBackground {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("模糊程度")
                                Spacer()
                                Text("\(Int(customBackgroundBlur))")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $customBackgroundBlur, in: 0...50, step: 1)
                                .tint(.blue)

                            HStack {
                                Text("图片透明度")
                                Spacer()
                                Text("\(Int(customBackgroundOpacity * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $customBackgroundOpacity, in: 0.1...0.8, step: 0.05)
                                .tint(.blue)

                            Button {
                                readerThemeRaw = ReaderTheme.custom.rawValue
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(readerThemeRaw == ReaderTheme.custom.rawValue ? .blue : .gray)
                                    Text("应用自定义背景")
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }

                    Text("从相册选择图片作为阅读背景，可调节模糊和透明度。选择后在「背景主题」中选「自定义图片」生效。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - 强调色
                Section("强调色") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(AccentColor.allCases, id: \.self) { accent in
                                Button {
                                    accentColorRaw = accent.rawValue
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(accent.color)
                                            .frame(width: 36, height: 36)
                                        if accentColorRaw == accent.rawValue {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    Text("影响按钮、进度条、选中态等 UI 元素的颜色")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - 翻页动画
                Section("翻页动画") {
                    Picker("效果", selection: $pageTransitionRaw) {
                        ForEach(PageTransition.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t.rawValue)
                        }
                    }
                }

                // MARK: - 图片预处理
                Section("图片预处理") {
                    Toggle("自动裁剪白边", isOn: $autoCropWhiteBorder)
                    Toggle("增强对比度", isOn: $enhanceContrast)
                    Toggle("灰度模式", isOn: $grayscaleMode)
                }

                // MARK: - AI 画质增强
                Section {
                    Picker("增强级别", selection: $imageEnhanceLevelRaw) {
                        ForEach(ImageEnhanceLevel.allCases, id: \.self) { level in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.displayName)
                                Text(level.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .tag(level.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    if imageEnhanceLevel != .off {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                            Text("AI 增强利用 Apple Neural Engine 本地推理，完全免费、离线运行，不消耗流量。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("AI 画质增强")
                } footer: {
                    Text("针对老漫画和扫描版优化：去网点降噪、智能锐化、提升清晰度。标准及以上启用 Vision AI 增强，强力模式额外超分辨率放大。首次处理每页需 0.2-1 秒，之后缓存。")
                }

                // MARK: - 手势自定义
                Section("手势自定义") {
                    Picker("左侧点击", selection: $tapLeftRaw) {
                        ForEach(TapAction.allCases, id: \.self) { a in
                            Text(a.displayName).tag(a.rawValue)
                        }
                    }
                    Picker("中间点击", selection: $tapCenterRaw) {
                        ForEach(TapAction.allCases, id: \.self) { a in
                            Text(a.displayName).tag(a.rawValue)
                        }
                    }
                    Picker("右侧点击", selection: $tapRightRaw) {
                        ForEach(TapAction.allCases, id: \.self) { a in
                            Text(a.displayName).tag(a.rawValue)
                        }
                    }
                    Picker("左滑", selection: $swipeLeftRaw) {
                        ForEach(SwipeAction.allCases, id: \.self) { a in
                            Text(a.displayName).tag(a.rawValue)
                        }
                    }
                    Picker("右滑", selection: $swipeRightRaw) {
                        ForEach(SwipeAction.allCases, id: \.self) { a in
                            Text(a.displayName).tag(a.rawValue)
                        }
                    }
                }

                // MARK: - 隐私与安全
                Section("隐私与安全") {
                    Button {
                        Task {
                            await privacyAuthService.authenticate(reason: "验证身份以显示隐私文件夹")
                        }
                    } label: {
                        HStack {
                            Label("显示隐私文件夹", systemImage: "lock.open")
                            Spacer()
                            if privacyAuthService.isUnlocked {
                                Text("已解锁")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .disabled(privacyAuthService.isUnlocked)

                    if privacyAuthService.isUnlocked {
                        Button(role: .destructive) {
                            privacyAuthService.lock()
                        } label: {
                            Label("立即锁定", systemImage: "lock")
                        }
                    }

                    Text("隐私文件夹及其内漫画在验证前隐藏，5 分钟无操作自动锁定。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - App 密码锁
                Section("App 密码锁") {
                    if AppLockService.shared.isEnabled && AppLockService.shared.hasPIN {
                        Toggle("启用密码锁", isOn: Binding(
                            get: { AppLockService.shared.isEnabled },
                            set: { AppLockService.shared.isEnabled = $0 }
                        ))
                        Toggle("生物识别解锁（\(AppLockService.shared.biometricTypeName)）", isOn: Binding(
                            get: { AppLockService.shared.biometricEnabled },
                            set: { AppLockService.shared.biometricEnabled = $0 }
                        ))
                        .disabled(AppLockService.shared.biometricType == .none)
                        Button(role: .destructive) {
                            showDisableLockConfirmation = true
                        } label: {
                            Label("关闭密码锁", systemImage: "lock.slash")
                        }
                    } else {
                        Button {
                            showSetPIN = true
                        } label: {
                            Label("设置 PIN 码密码锁", systemImage: "lock")
                        }
                    }
                    Text("启用后每次打开 App 需输入 PIN 码或生物识别验证，30 秒内重新打开无需重复验证。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .alert("关闭密码锁", isPresented: $showDisableLockConfirmation) {
                    Button("取消", role: .cancel) {}
                    Button("关闭", role: .destructive) {
                        AppLockService.shared.clearLock()
                    }
                } message: {
                    Text("确定要关闭 App 密码锁吗？PIN 码将被清除。")
                }

                // MARK: - iCloud 同步
                Section("iCloud 同步") {
                    Toggle("启用 iCloud 同步", isOn: Binding(
                        get: { iCloudSyncEnabled },
                        set: {
                            iCloudSyncEnabled = $0
                            ICloudSyncService.shared.isEnabled = $0
                        }
                    ))
                    .disabled(!ICloudSyncService.shared.isAvailable)
                    if !ICloudSyncService.shared.isAvailable {
                        Text("当前未登录 iCloud 或未启用 iCloud 功能。请在系统设置中登录 iCloud。")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Text("同步阅读进度到 iCloud，多设备间自动同步。仅同步进度数据，不同步漫画文件。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - 灵动岛与实时活动
                Section("灵动岛与锁屏") {
                    Toggle("启用实时活动", isOn: $liveActivityManager.isEnabled)
                    if !liveActivityManager.isSupported {
                        Text("当前设备或系统版本不支持实时活动（需 iOS 16.1+ 及支持灵动岛的设备）")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Text("阅读时在灵动岛和锁屏显示漫画进度、页码和阅读时长，点击可快速回到阅读器。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - 存储与缓存
                Section("存储与缓存") {
                    HStack {
                        Text("漫画源文件")
                        Spacer()
                        Text(totalStorageSize)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("缓存")
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.secondary)
                    }
                    Button(role: .destructive) {
                        showClearCacheConfirmation = true
                    } label: {
                        Text("清理缓存")
                    }
                    Text("清理缩略图缓存和 WiFi 传书临时文件，不影响漫画源文件。清理后封面缩略图将在下次打开时重新生成。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("传输") {
                    Button {
                        showWiFiTransfer = true
                    } label: {
                        HStack {
                            Label("WiFi 传书", systemImage: "wifi")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // MARK: - App 图标
                Section {
                    ForEach(iconManager.availableIcons) { option in
                        Button {
                            Task {
                                do {
                                    try await iconManager.setIcon(option)
                                } catch {
                                    iconErrorMessage = error.localizedDescription
                                    showIconError = true
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 48, height: 48)
                                    .overlay(
                                        Image(systemName: option.previewSymbol)
                                            .font(.system(size: 22))
                                            .foregroundColor(.primary)
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.name)
                                        .foregroundColor(.primary)
                                    Text(option.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if iconManager.currentIconName == option.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("App 图标")
                } footer: {
                    Text("选择你喜欢的应用图标样式")
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("支持格式")
                        Spacer()
                        Text("CBZ, ZIP, CBR, PDF, JPG, PNG, WebP")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Link(destination: URL(string: "https://github.com/weichsel/ZIPFoundation")!) {
                        HStack {
                            Text("ZIPFoundation")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("开源依赖")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onAppear {
                calculateStorageSize()
                calculateCacheSize()
                hasCustomBackground = FileStorageService.shared.loadCustomBackground() != nil
            }
            .onChange(of: backgroundPickerItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        if FileStorageService.shared.saveCustomBackground(image) {
                            hasCustomBackground = true
                            readerThemeRaw = ReaderTheme.custom.rawValue
                        }
                    }
                    backgroundPickerItem = nil
                }
            }
            .confirmationDialog("清理缓存", isPresented: $showClearCacheConfirmation, titleVisibility: .visible) {
                Button("清理缓存", role: .destructive) {
                    FileStorageService.shared.clearCache()
                    calculateCacheSize()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将清理缩略图缓存和 WiFi 传书临时文件，不影响漫画源文件。")
            }
            .alert("切换图标失败", isPresented: $showIconError) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(iconErrorMessage)
            }
            .sheet(isPresented: $showWiFiTransfer) {
                WiFiTransferView(modelContext: modelContext)
            }
            .sheet(isPresented: $showSetPIN) {
                NavigationStack {
                    SetPINView {
                        showSetPIN = false
                    }
                }
            }
        }
    }

    private func calculateStorageSize() {
        let dir = FileStorageService.shared.comicsDirectory
        var totalSize: Int64 = 0
        let enumerator = FileManager.default.enumerator(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        totalStorageSize = formatter.string(fromByteCount: totalSize)
    }

    private func calculateCacheSize() {
        let size = FileStorageService.shared.cacheSize
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        cacheSize = formatter.string(fromByteCount: size)
    }
}

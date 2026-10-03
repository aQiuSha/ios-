import SwiftUI
import SwiftData

/// 漫画阅读器主视图
struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    private let comic: Comic

    @State private var showBookmarks = false
    @State private var isCurrentPageBookmarked = false
    @State private var showBookmarkToast = false
    @State private var bookmarkToastText = ""

    // 阅读时长记录
    @State private var sessionStartTime: Date?
    @State private var accumulatedDuration: TimeInterval = 0

    // 自定义背景
    @State private var customBackgroundImage: UIImage?
    @AppStorage("customBackgroundBlur") private var customBackgroundBlur: Double = 20
    @AppStorage("customBackgroundOpacity") private var customBackgroundOpacity: Double = 0.3

    // 强调色
    @AppStorage("accentColor") private var accentColorRaw = AccentColor.blue.rawValue
    private var accentColor: Color {
        AccentColor(rawValue: accentColorRaw)?.color ?? .blue
    }

    // MARK: - 偏好设置（@AppStorage 持久化）

    @AppStorage("orientationLock") private var orientationLock = false
    @AppStorage("readerTheme") private var readerThemeRaw = ReaderTheme.pureBlack.rawValue
    @AppStorage("autoNightMode") private var autoNightMode = false
    @AppStorage("pageTransition") private var pageTransitionRaw = PageTransition.slide.rawValue
    @AppStorage("readerBrightness") private var readerBrightness: Double = 0.5
    @AppStorage("readerLayout") private var readerLayoutRaw = ReaderLayout.paged.rawValue
    @AppStorage("autoFlipSpeed") private var autoFlipSpeedRaw = AutoFlipSpeed.off.rawValue
    @AppStorage("volumeKeyFlip") private var volumeKeyFlip = false

    // 手势自定义
    @AppStorage("tapLeftAction") private var tapLeftRaw = TapAction.prevPage.rawValue
    @AppStorage("tapCenterAction") private var tapCenterRaw = TapAction.toggleMenu.rawValue
    @AppStorage("tapRightAction") private var tapRightRaw = TapAction.nextPage.rawValue
    @AppStorage("swipeLeftAction") private var swipeLeftRaw = SwipeAction.nextPage.rawValue
    @AppStorage("swipeRightAction") private var swipeRightRaw = SwipeAction.prevPage.rawValue

    // MARK: - 亮度指示器状态
    @State private var showBrightnessHUD = false
    @State private var brightnessLevel: Double = UIScreen.main.brightness
    @State private var brightnessWorkItem: DispatchWorkItem?

    // MARK: - 长按设为封面
    @State private var showCoverActionSheet = false
    @State private var coverSourceImage: UIImage?

    init(comic: Comic, modelContext: ModelContext) {
        self.comic = comic
        _viewModel = StateObject(wrappedValue: ReaderViewModel(comic: comic, modelContext: modelContext))
    }

    // MARK: - 计算属性

    /// 实际生效主题（夜间模式自动覆盖为纯黑）
    private var effectiveTheme: ReaderTheme {
        if autoNightMode && isNightTime() {
            return .pureBlack
        }
        return ReaderTheme(rawValue: readerThemeRaw) ?? .pureBlack
    }

    /// 背景层：纯色或自定义图片
    @ViewBuilder
    private var backgroundLayer: some View {
        if effectiveTheme.isCustomBackground, let bgImage = customBackgroundImage {
            ZStack {
                Image(uiImage: bgImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: customBackgroundBlur)
                    .opacity(customBackgroundOpacity)
                Color.black.opacity(0.5)
            }
        } else {
            effectiveTheme.background
        }
    }

    private var pageTransition: PageTransition {
        PageTransition(rawValue: pageTransitionRaw) ?? .slide
    }

    private var tapLeft: TapAction { TapAction(rawValue: tapLeftRaw) ?? .prevPage }
    private var tapCenter: TapAction { TapAction(rawValue: tapCenterRaw) ?? .toggleMenu }
    private var tapRight: TapAction { TapAction(rawValue: tapRightRaw) ?? .nextPage }
    private var swipeLeft: SwipeAction { SwipeAction(rawValue: swipeLeftRaw) ?? .nextPage }
    private var swipeRight: SwipeAction { SwipeAction(rawValue: swipeRightRaw) ?? .prevPage }

    private var readerLayout: ReaderLayout { ReaderLayout(rawValue: readerLayoutRaw) ?? .paged }
    private var autoFlipSpeed: AutoFlipSpeed { AutoFlipSpeed(rawValue: autoFlipSpeedRaw) ?? .off }
    @State private var autoFlipTimer: Timer?

    private func isNightTime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 18 || hour < 6
    }

    var body: some View {
        ZStack {
            // 背景层
            backgroundLayer.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("加载中...")
                    .foregroundColor(effectiveTheme.uiForeground)
            } else if viewModel.totalPages == 0 {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(effectiveTheme.uiSecondary)
                    Text("未找到漫画页面")
                        .foregroundColor(effectiveTheme.uiSecondary)
                    Button("返回") { dismiss() }
                        .buttonStyle(.bordered)
                }
            } else {
                readerContent
            }

            // 亮度 HUD
            if showBrightnessHUD {
                brightnessHUD
                    .transition(.opacity)
            }

            // 顶部和底部工具栏
            if viewModel.showUI && !viewModel.isLoading {
                overlayUI
            }

            // 书签提示 Toast
            if showBookmarkToast {
                VStack {
                    Spacer()
                    Text(bookmarkToastText)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            viewModel.loadPages()
            startReadingSession()
            checkBookmarkStatus()
            applyOrientationLock()
            // 恢复上次亮度
            if readerBrightness > 0 {
                brightnessLevel = readerBrightness
                UIScreen.main.brightness = readerBrightness
            } else {
                brightnessLevel = UIScreen.main.brightness
            }
            // 加载自定义背景
            customBackgroundImage = FileStorageService.shared.loadCustomBackground()
            // 启动自动翻页
            startAutoFlip()
            // 启动音量键翻页
            if volumeKeyFlip {
                VolumeKeyService.shared.isEnabled = true
                VolumeKeyService.shared.onVolumeUp = { viewModel.goToNextPage() }
                VolumeKeyService.shared.onVolumeDown = { viewModel.goToPreviousPage() }
            }
            // 成就：记录主题使用
            AchievementService.shared.trackThemeUsed(effectiveTheme)
        }
        .onDisappear {
            endReadingSession()
            stopAutoFlip()
            VolumeKeyService.shared.isEnabled = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            endReadingSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            startReadingSession()
        }
        .onChange(of: viewModel.currentPage) { _, _ in
            checkBookmarkStatus()
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksView(comic: comic, modelContext: modelContext) { page in
                viewModel.goToPage(page)
            }
        }
        .confirmationDialog("操作", isPresented: $showCoverActionSheet, titleVisibility: .visible) {
            Button("设为封面") {
                setAsCover()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将当前页设为漫画封面？")
        }
        .statusBarHidden(viewModel.showUI ? false : true)
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
    }

    // MARK: - 阅读内容

    @ViewBuilder
    private var readerContent: some View {
        GeometryReader { geo in
            ZStack {
                if readerLayout == .webtoon {
                    webtoonView
                } else if viewModel.pageMode == .double {
                    doublePageView
                } else {
                    singlePageView
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            // 点击区域（条漫模式下也支持点击翻页）
            .onTapGesture { location in
                handleTap(at: location, in: geo.size)
            }
            // 左侧边缘亮度调节
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        guard value.startLocation.x < 40 else { return }
                        let delta = -value.translation.height / 600.0
                        brightnessLevel = min(max(brightnessLevel + delta, 0.05), 1.0)
                        UIScreen.main.brightness = brightnessLevel
                        readerBrightness = brightnessLevel
                        showBrightnessOverlay()
                    }
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - 条漫模式（长图连续滚动）

    @ViewBuilder
    private var webtoonView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(0..<viewModel.totalPages, id: \.self) { index in
                        if let image = viewModel.image(at: index) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .id(index)
                                .onAppear {
                                    // 滚动到该页时更新当前页
                                    if viewModel.currentPage != index {
                                        viewModel.goToPage(index)
                                    }
                                }
                                .onLongPressGesture {
                                    coverSourceImage = image
                                    showCoverActionSheet = true
                                }
                        }
                    }
                }
            }
            .onAppear {
                // 跳转到上次阅读位置
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    proxy.scrollTo(viewModel.currentPage, anchor: .top)
                }
            }
            .onChange(of: viewModel.currentPage) { _, newPage in
                // 非用户滚动导致的翻页（如点击翻页、自动翻页）时滚动到目标页
                withAnimation {
                    proxy.scrollTo(newPage, anchor: .top)
                }
            }
        }
    }

    // MARK: - 单页模式

    @ViewBuilder
    private var singlePageView: some View {
        switch pageTransition {
        case .slide:
            TabView(selection: Binding(
                get: { viewModel.currentPage },
                set: { viewModel.goToPage($0) }
            )) {
                ForEach(0..<viewModel.totalPages, id: \.self) { index in
                    if let image = viewModel.image(at: index) {
                        PageImageView(image: image, onLongPress: {
                            coverSourceImage = image
                            showCoverActionSheet = true
                        })
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

        case .fade, .none:
            let index = viewModel.currentPage
            Group {
                if let image = viewModel.image(at: index) {
                    PageImageView(image: image, onLongPress: {
                        coverSourceImage = image
                        showCoverActionSheet = true
                    })
                    .id(index)
                    .transition(.opacity)
                }
            }
            .animation(pageTransition == .fade ? .easeInOut(duration: 0.25) : nil, value: viewModel.currentPage)
            .gesture(swipeGesture)
        }
    }

    // MARK: - 双页模式

    @ViewBuilder
    private var doublePageView: some View {
        let layout = viewModel.doublePageLayout(for: viewModel.currentPage)
        Group {
            if let leftIdx = layout.left, let leftImg = viewModel.image(at: leftIdx) {
                HStack(spacing: 0) {
                    PageImageView(image: leftImg, onLongPress: {
                        coverSourceImage = leftImg
                        showCoverActionSheet = true
                    })
                    .frame(maxWidth: .infinity)
                    if let rightIdx = layout.right, let rightImg = viewModel.image(at: rightIdx) {
                        PageImageView(image: rightImg, onLongPress: {
                            coverSourceImage = rightImg
                            showCoverActionSheet = true
                        })
                        .frame(maxWidth: .infinity)
                    }
                }
            } else if let rightIdx = layout.right, let rightImg = viewModel.image(at: rightIdx) {
                // 封面单独占满
                PageImageView(image: rightImg, onLongPress: {
                    coverSourceImage = rightImg
                    showCoverActionSheet = true
                })
            }
        }
        .id(viewModel.currentPage)
        .transition(.opacity)
        .animation(pageTransition == .fade ? .easeInOut(duration: 0.25) : nil, value: viewModel.currentPage)
        .gesture(swipeGesture)
    }

    /// 水平滑动手势（用于非 TabView 模式）
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                guard abs(h) > 50, abs(h) > abs(v) * 1.5 else { return }
                if h < 0 {
                    executeSwipeAction(swipeLeft)
                } else {
                    executeSwipeAction(swipeRight)
                }
            }
    }

    // MARK: - 手势处理

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let third = size.width / 3
        let action: TapAction
        if location.x < third {
            action = tapLeft
        } else if location.x > third * 2 {
            action = tapRight
        } else {
            action = tapCenter
        }
        executeTapAction(action)
    }

    private func executeTapAction(_ action: TapAction) {
        switch action {
        case .prevPage: viewModel.goToPreviousPage()
        case .nextPage: viewModel.goToNextPage()
        case .toggleMenu: viewModel.toggleUI()
        case .none: break
        }
    }

    private func executeSwipeAction(_ action: SwipeAction) {
        switch action {
        case .prevPage: viewModel.goToPreviousPage()
        case .nextPage: viewModel.goToNextPage()
        case .none: break
        }
    }

    // MARK: - 方向锁定

    private func applyOrientationLock() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        if orientationLock {
            let current = scene.effectiveGeometry.interfaceOrientation
            var mask: UIInterfaceOrientationMask = .portrait
            switch current {
            case .landscapeLeft: mask = .landscapeLeft
            case .landscapeRight: mask = .landscapeRight
            case .portrait: mask = .portrait
            case .portraitUpsideDown: mask = .portraitUpsideDown
            default: mask = .portrait
            }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        } else {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .allButUpsideDown))
        }
    }

    private func toggleOrientationLock() {
        orientationLock.toggle()
        applyOrientationLock()
    }

    // MARK: - 亮度 HUD

    private var brightnessHUD: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "sun.min")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                ProgressView(value: brightnessLevel)
                    .progressViewStyle(.linear)
                    .frame(width: 160)
                    .tint(.white)
                Image(systemName: "sun.max")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.top, 60)
            Spacer()
        }
    }

    private func showBrightnessOverlay() {
        brightnessWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            showBrightnessHUD = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.3)) {
                showBrightnessHUD = false
            }
        }
        brightnessWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    // MARK: - 覆盖 UI

    private var overlayUI: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomBar
        }
        .transition(.opacity)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(effectiveTheme.uiForeground)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.progressText)
                    .font(.subheadline)
                    .foregroundColor(effectiveTheme.uiForeground)
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(effectiveTheme.uiSecondary)
            }

            Spacer()

            HStack(spacing: 0) {
                // 方向锁定按钮
                Button {
                    toggleOrientationLock()
                } label: {
                    Image(systemName: orientationLock ? "lock" : "lock.open")
                        .font(.title3)
                        .foregroundColor(orientationLock ? .orange : effectiveTheme.uiForeground)
                        .frame(width: 44, height: 44)
                }

                // 书签按钮
                Button {
                    toggleBookmark()
                } label: {
                    Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.title3)
                        .foregroundColor(isCurrentPageBookmarked ? .orange : effectiveTheme.uiForeground)
                        .frame(width: 44, height: 44)
                }

                // 书签列表
                Button {
                    showBookmarks = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .foregroundColor(effectiveTheme.uiForeground)
                        .frame(width: 44, height: 44)
                }

                Menu {
                    Button {
                        viewModel.toggleReadingDirection()
                    } label: {
                        Label(viewModel.readingDirection.displayName, systemImage: "arrow.left.arrow.right")
                    }

                    Button {
                        viewModel.togglePageMode()
                    } label: {
                        Label(viewModel.pageMode.displayName, systemImage: "rectangle.split.2x1")
                    }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.goToPage(0)
                    } label: {
                        Label("从头开始", systemImage: "backward.end.fill")
                    }

                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundColor(effectiveTheme.uiForeground)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: effectiveTheme.overlayGradient,
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("\(viewModel.currentPage + 1)")
                    .font(.caption)
                    .foregroundColor(effectiveTheme.uiForeground)
                    .frame(width: 40, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { Double(viewModel.currentPage) },
                        set: { viewModel.goToPage(Int($0)) }
                    ),
                    in: 0...Double(max(viewModel.totalPages - 1, 0))
                )
                .tint(accentColor)
                Text("\(viewModel.totalPages)")
                    .font(.caption)
                    .foregroundColor(effectiveTheme.uiForeground)
                    .frame(width: 40, alignment: .leading)
            }

            HStack {
                Image(systemName: "arrowtriangle.left.fill")
                    .foregroundColor(effectiveTheme.uiSecondary)
                Text(viewModel.readingDirection == .leftToRight ? "左滑 / 点右侧翻下一页" : "右滑 / 点左侧翻下一页（日漫模式）")
                    .font(.caption2)
                    .foregroundColor(effectiveTheme.uiSecondary)
                Image(systemName: "arrowtriangle.right.fill")
                    .foregroundColor(effectiveTheme.uiSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: Array(effectiveTheme.overlayGradient.reversed()),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - 书签操作

    private func checkBookmarkStatus() {
        let page = viewModel.currentPage
        let descriptor = FetchDescriptor<Bookmark>(
            predicate: #Predicate { bookmark in
                bookmark.page == page
            }
        )
        let allMatches = (try? modelContext.fetch(descriptor)) ?? []
        isCurrentPageBookmarked = allMatches.contains { $0.comic?.id == comic.id }
    }

    private func toggleBookmark() {
        if isCurrentPageBookmarked {
            // 删除当前页书签
            let page = viewModel.currentPage
            let descriptor = FetchDescriptor<Bookmark>(
                predicate: #Predicate { bookmark in
                    bookmark.page == page
                }
            )
            if let bookmarks = try? modelContext.fetch(descriptor) {
                for b in bookmarks where b.comic?.id == comic.id {
                    modelContext.delete(b)
                }
                try? modelContext.save()
            }
            showToast("已移除书签")
        } else {
            // 添加书签
            let bookmark = Bookmark(page: viewModel.currentPage, comic: comic)
            modelContext.insert(bookmark)
            try? modelContext.save()
            showToast("已添加书签 · 第 \(viewModel.currentPage + 1) 页")
            AchievementService.shared.unlock(.firstBookmark)
        }
        checkBookmarkStatus()
    }

    // MARK: - 设为封面

    private func setAsCover() {
        guard let image = coverSourceImage else { return }
        if let newPath = FileStorageService.shared.saveThumbnail(for: comic.folderName, image: image) {
            comic.coverPath = newPath
            try? modelContext.save()
            showToast("封面已更新")
        } else {
            showToast("封面设置失败")
        }
    }

    private func showToast(_ text: String) {
        bookmarkToastText = text
        withAnimation {
            showBookmarkToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showBookmarkToast = false
            }
        }
    }

    // MARK: - 阅读时长记录

    private func startReadingSession() {
        guard sessionStartTime == nil else { return }
        sessionStartTime = Date()
    }

    private func endReadingSession() {
        guard let start = sessionStartTime else { return }
        let end = Date()
        let duration = end.timeIntervalSince(start)

        // 至少阅读 5 秒才记录
        if duration >= 5 {
            let session = ReadingSession(
                startTime: start,
                endTime: end,
                duration: duration,
                comic: comic
            )
            modelContext.insert(session)
            try? modelContext.save()
            accumulatedDuration += duration
        }
        sessionStartTime = nil
    }

    // MARK: - 自动翻页

    private func startAutoFlip() {
        stopAutoFlip()
        guard let interval = autoFlipSpeed.interval else { return }
        autoFlipTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            DispatchQueue.main.async {
                if viewModel.currentPage < viewModel.totalPages - 1 {
                    viewModel.goToNextPage()
                } else {
                    stopAutoFlip()
                }
            }
        }
    }

    private func stopAutoFlip() {
        autoFlipTimer?.invalidate()
        autoFlipTimer = nil
    }
}

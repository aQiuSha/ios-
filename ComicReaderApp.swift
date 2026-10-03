import SwiftUI
import SwiftData
import WidgetKit

@main
struct ComicReaderApp: App {

    // MARK: - 静态 ModelContainer（供 App Intent 访问）

    /// 全局静态 ModelContainer 引用
    /// AppIntent 运行时通过此属性访问 SwiftData 上下文
    /// 在 init() 中赋值，App 启动后立即可用
    static var modelContainer: ModelContainer?

    // MARK: - 存储属性

    let container: ModelContainer

    /// App 生命周期状态（用于在后台时同步 Widget 数据）
    @Environment(\.scenePhase) private var scenePhase

    /// 是否需要密码锁验证
    @State private var showAppLock = false

    /// 全局强调色（从 UserDefaults 读取）
    private var accentColor: Color {
        let raw = UserDefaults.standard.string(forKey: "accentColor") ?? AccentColor.blue.rawValue
        return AccentColor(rawValue: raw)?.color ?? .blue
    }

    // MARK: - 初始化

    init() {
        do {
            let container = try ModelContainer(for: Comic.self, Folder.self, Bookmark.self, ReadingSession.self)
            self.container = container
            // 赋值给静态属性，供 AppIntents 访问
            ComicReaderApp.modelContainer = container
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    // MARK: - 视图构建

    var body: some Scene {
        WindowGroup {
            ZStack {
                LibraryView(modelContext: ModelContext(container))
                    // 全局强调色
                    .tint(accentColor)
                    // 处理 URL Scheme 深度链接
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }
                    .onAppear {
                        checkAppLock()
                    }

                // App 密码锁覆盖层
                if showAppLock {
                    AppLockView {
                        showAppLock = false
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: showAppLock)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            // App 进入后台时同步 Widget 数据
            if newPhase == .background {
                syncWidgetData()
            }
            // App 回到前台时检查是否需要密码锁
            if newPhase == .active {
                syncWidgetData()
                checkAppLock()
            }
        }
    }

    /// 检查是否需要显示密码锁
    @MainActor
    private func checkAppLock() {
        if AppLockService.shared.needsAuthentication {
            showAppLock = true
        }
    }

    // MARK: - 深度链接处理

    /// 处理 App URL Scheme 深度链接
    /// 支持的格式：
    /// - comicreader://continue → 继续阅读最近的漫画
    /// - comicreader://comic/{uuid} → 打开指定漫画
    /// - comicreader://stats → 打开统计页
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "comicreader" else { return }

        switch url.host {
        case "continue":
            openContinueReading()

        case "comic":
            // 路径格式：/comic/{uuid}
            let comicIDString = url.pathComponents.last ?? ""
            if let uuid = UUID(uuidString: comicIDString) {
                postOpenComicNotification(comicID: uuid)
            }

        case "stats":
            NotificationCenter.default.post(name: .showStatsFromDeepLink, object: nil)

        default:
            break
        }
    }

    /// 打开最近阅读的漫画（comicreader://continue）
    @MainActor
    private func openContinueReading() {
        let context = container.mainContext

        // 查询有阅读进度且未读完的漫画，按 lastOpened 降序
        var descriptor = FetchDescriptor<Comic>(
            sortBy: [SortDescriptor(\.lastOpened, order: .reverse)]
        )
        descriptor.predicate = #Predicate<Comic> { comic in
            comic.currentPage > 0
        }

        if let comics = try? context.fetch(descriptor),
           let latestComic = comics.first(where: { !$0.isFinished }) {
            postOpenComicNotification(comicID: latestComic.id)
        }
    }

    /// 发送打开漫画的通知（LibraryView 监听后设置 selectedComic）
    /// - Parameter comicID: 漫画 UUID
    private func postOpenComicNotification(comicID: UUID) {
        NotificationCenter.default.post(
            name: .openComicFromIntent,
            object: nil,
            userInfo: ["comicID": comicID]
        )
    }

    // MARK: - Widget 数据同步

    /// 同步 Widget 所需数据到 App Group 共享容器
    @MainActor
    private func syncWidgetData() {
        let context = container.mainContext
        WidgetSyncManager.shared.syncWidgetData(modelContext: context)
    }
}

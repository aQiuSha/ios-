import SwiftUI
import SwiftData

@main
struct ComicReaderApp: App {

    let container: ModelContainer

    /// App 生命周期状态
    @Environment(\.scenePhase) private var scenePhase

    /// 是否需要密码锁验证
    @State private var showAppLock = false

    /// 全局强调色（从 UserDefaults 读取）
    private var accentColor: Color {
        let raw = UserDefaults.standard.string(forKey: "accentColor") ?? AccentColor.blue.rawValue
        return AccentColor(rawValue: raw)?.color ?? .blue
    }

    init() {
        do {
            let container = try ModelContainer(for: Comic.self, Folder.self, Bookmark.self, ReadingSession.self)
            self.container = container
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                LibraryView(modelContext: ModelContext(container))
                    .tint(accentColor)
                    .onAppear {
                        checkAppLock()
                    }

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
            if newPhase == .active {
                checkAppLock()
            }
        }
    }

    @MainActor
    private func checkAppLock() {
        if AppLockService.shared.needsAuthentication {
            showAppLock = true
        }
    }
}

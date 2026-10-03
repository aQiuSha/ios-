import Foundation
import SwiftData
import Combine
import UIKit

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var comics: [Comic] = []
    @Published var folders: [Folder] = []
    @Published var isImporting = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var sortOption: SortOption = .dateAdded

    // 筛选状态
    @Published var selectedFolder: Folder?
    @Published var showUncategorizedOnly = false
    @Published var showFavoritesOnly = false
    @Published var statusFilter: ReadingStatus?

    // 多选模式
    @Published var isMultiSelectMode = false
    @Published var selectedComics: Set<UUID> = []

    // 隐私文件夹解锁状态
    @Published var isPrivateUnlocked: Bool = false

    enum SortOption: String, CaseIterable {
        case dateAdded = "最近添加"
        case lastOpened = "最近阅读"
        case title = "标题"
        case progress = "阅读进度"
    }

    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // 从 PrivacyAuthService 同步解锁状态
        self.isPrivateUnlocked = PrivacyAuthService.shared.isUnlocked
        PrivacyAuthService.shared.$isUnlocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] unlocked in
                self?.isPrivateUnlocked = unlocked
            }
            .store(in: &cancellables)
        loadComics()
        loadFolders()
    }

    // MARK: - 加载数据

    func loadComics() {
        let descriptor = FetchDescriptor<Comic>()
        comics = (try? modelContext.fetch(descriptor)) ?? []
        sortComics()
    }

    func loadFolders() {
        let descriptor = FetchDescriptor<Folder>(sortBy: [SortDescriptor(\.createdAt)])
        folders = (try? modelContext.fetch(descriptor)) ?? []
    }

    /// 在文件夹筛选栏中可见的文件夹（未解锁时隐藏隐私文件夹）
    var visibleFolders: [Folder] {
        PrivacyAuthService.shared.checkLockStatus()
        return folders.filter { isPrivateUnlocked || !$0.isPrivate }
    }

    func sortComics() {
        switch sortOption {
        case .dateAdded:
            comics.sort { $0.dateAdded > $1.dateAdded }
        case .lastOpened:
            comics.sort { ($0.lastOpened ?? .distantPast) > ($1.lastOpened ?? .distantPast) }
        case .title:
            comics.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .progress:
            comics.sort { $0.progress > $1.progress }
        }
    }

    // MARK: - 筛选

    var filteredComics: [Comic] {
        // 每次访问前检查自动锁定状态
        PrivacyAuthService.shared.checkLockStatus()

        var result = comics

        // 未解锁时过滤掉隐私文件夹内的漫画
        if !isPrivateUnlocked {
            result = result.filter { $0.folder?.isPrivate != true }
        }

        // 文件夹筛选
        if showUncategorizedOnly {
            result = result.filter { $0.folder == nil }
        } else if let folder = selectedFolder {
            result = result.filter { $0.folder?.id == folder.id }
        }

        // 收藏筛选
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }

        // 阅读状态筛选
        if let status = statusFilter {
            result = result.filter { $0.effectiveReadingStatus == status }
        }

        // 搜索
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return result
    }

    var continueReadingComics: [Comic] {
        PrivacyAuthService.shared.checkLockStatus()
        return comics
            .filter { $0.currentPage > 0 && !$0.isFinished }
            .filter { isPrivateUnlocked || $0.folder?.isPrivate != true }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - 隐私文件夹

    /// 对隐私文件夹进行生物识别验证
    func authenticateForPrivate() async {
        let success = await PrivacyAuthService.shared.authenticate(reason: "验证身份以显示隐私文件夹")
        if success {
            isPrivateUnlocked = true
        }
    }

    /// 手动锁定隐私文件夹
    func lockPrivate() {
        PrivacyAuthService.shared.lock()
        isPrivateUnlocked = false
    }

    // MARK: - 删除 / 重置

    func deleteComic(_ comic: Comic) {
        FileStorageService.shared.deleteComic(
            folderName: comic.folderName,
            thumbnailPath: comic.coverPath
        )
        modelContext.delete(comic)
        try? modelContext.save()
        loadComics()
    }

    func resetProgress(_ comic: Comic) {
        comic.currentPage = 0
        try? modelContext.save()
        loadComics()
    }

    // MARK: - 导入

    func importComic(from url: URL) async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            _ = try await ComicImportService.shared.importComic(from: url, modelContext: modelContext)
            loadComics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importImages(_ urls: [URL], title: String) async {
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }

        do {
            _ = try await ComicImportService.shared.importComic(
                from: urls,
                title: title,
                modelContext: modelContext
            )
            loadComics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 文件夹管理

    func createFolder(name: String, isPrivate: Bool = false) {
        let colorData = try? NSKeyedArchiver.archivedData(
            withRootObject: UIColor.systemBlue,
            requiringSecureCoding: true
        )
        let folder = Folder(name: name, colorData: colorData, isPrivate: isPrivate)
        modelContext.insert(folder)
        try? modelContext.save()
        loadFolders()
    }

    /// 切换文件夹的隐私状态
    func toggleFolderPrivate(_ folder: Folder) {
        folder.isPrivate.toggle()
        try? modelContext.save()
        loadFolders()
        loadComics()
    }

    func renameFolder(_ folder: Folder, newName: String) {
        folder.name = newName
        try? modelContext.save()
        loadFolders()
    }

    func deleteFolder(_ folder: Folder) {
        // 删除文件夹，漫画不删除，folder 置 nil（nullify 自动处理）
        modelContext.delete(folder)
        try? modelContext.save()
        loadFolders()
        loadComics()
        if selectedFolder?.id == folder.id {
            selectedFolder = nil
            showUncategorizedOnly = false
        }
    }

    func moveComicsToFolder(comics: [Comic], folder: Folder?) {
        for comic in comics {
            comic.folder = folder
        }
        try? modelContext.save()
        loadComics()
    }

    // MARK: - 收藏

    func toggleFavorite(_ comic: Comic) {
        comic.isFavorite.toggle()
        try? modelContext.save()
        loadComics()
    }

    func setFavorites(_ comics: [Comic], favorite: Bool) {
        for comic in comics {
            comic.isFavorite = favorite
        }
        try? modelContext.save()
        loadComics()
    }

    // MARK: - 阅读状态

    func setReadingStatus(_ comic: Comic, status: ReadingStatus) {
        comic.readingStatus = status.rawValue
        try? modelContext.save()
        loadComics()
    }

    // MARK: - 多选模式

    func enterMultiSelectMode() {
        isMultiSelectMode = true
        selectedComics = []
    }

    func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedComics = []
    }

    func toggleSelectComic(_ comic: Comic) {
        if selectedComics.contains(comic.id) {
            selectedComics.remove(comic.id)
        } else {
            selectedComics.insert(comic.id)
        }
    }

    func selectAll() {
        selectedComics = Set(filteredComics.map { $0.id })
    }

    func deselectAll() {
        selectedComics = []
    }

    var selectedComicObjects: [Comic] {
        comics.filter { selectedComics.contains($0.id) }
    }

    // MARK: - 批量操作

    func batchDelete() {
        let toDelete = selectedComicObjects
        for comic in toDelete {
            FileStorageService.shared.deleteComic(
                folderName: comic.folderName,
                thumbnailPath: comic.coverPath
            )
            modelContext.delete(comic)
        }
        try? modelContext.save()
        exitMultiSelectMode()
        loadComics()
    }

    func batchMove(to folder: Folder?) {
        moveComicsToFolder(comics: selectedComicObjects, folder: folder)
        exitMultiSelectMode()
    }

    func batchSetFavorite(_ favorite: Bool) {
        setFavorites(selectedComicObjects, favorite: favorite)
        exitMultiSelectMode()
    }

    // MARK: - 更换封面

    func updateCover(for comic: Comic, image: UIImage) {
        if let newPath = FileStorageService.shared.saveThumbnail(for: comic.folderName, image: image) {
            comic.coverPath = newPath
            try? modelContext.save()
            loadComics()
        }
    }
}

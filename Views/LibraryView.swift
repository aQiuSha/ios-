import SwiftUI
import SwiftData

/// 漫画书架首页
struct LibraryView: View {
    let modelContext: ModelContext
    @StateObject private var viewModel: LibraryViewModel

    // 导入 / 页面跳转
    @State private var showFilePicker = false
    @State private var showImagePicker = false
    @State private var showWiFiTransfer = false
    @State private var showSettings = false
    @State private var showStats = false
    @State private var showAllBookmarks = false
    @State private var bookmarksComic: Comic?
    @State private var selectedComic: Comic?

    // 单个漫画删除
    @State private var showDeleteConfirmation = false
    @State private var comicToDelete: Comic?

    // 新建文件夹
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var newFolderIsPrivate = false

    // 重命名文件夹
    @State private var showRenameFolderAlert = false
    @State private var folderToRename: Folder?
    @State private var renameFolderText = ""

    // 删除文件夹
    @State private var showDeleteFolderConfirmation = false
    @State private var folderToDelete: Folder?

    // 移动漫画到文件夹（单个）
    @State private var showMoveComicSheet = false
    @State private var comicToMove: Comic?

    // 更换封面
    @State private var showPhotoPicker = false
    @State private var comicToChangeCover: Comic?

    // 批量移动到文件夹
    @State private var showBatchMoveSheet = false

    // 批量删除确认
    @State private var showBatchDeleteConfirmation = false

    // 收藏筛选持久化
    @AppStorage("showFavoritesOnly") private var showFavoritesOnly = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        _viewModel = StateObject(wrappedValue: LibraryViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    folderFilterBar
                        .padding(.top, 8)

                    statusFilterMenu
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)

                    if viewModel.filteredComics.isEmpty && viewModel.continueReadingComics.isEmpty {
                        emptyStateView
                    } else {
                        libraryContent
                    }
                }
            }
            .navigationTitle("我的漫画")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Button {
                            showStats = true
                        } label: {
                            Image(systemName: "chart.bar.fill")
                        }
                        Button {
                            showAllBookmarks = true
                        } label: {
                            Image(systemName: "bookmark.fill")
                        }
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // 只看收藏
                    Button {
                        showFavoritesOnly.toggle()
                        viewModel.showFavoritesOnly = showFavoritesOnly
                    } label: {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundColor(showFavoritesOnly ? .red : nil)
                    }

                    // 新建文件夹
                    Button {
                        newFolderName = ""
                        newFolderIsPrivate = false
                        showNewFolderAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }

                    // 编辑 / 完成
                    Button {
                        if viewModel.isMultiSelectMode {
                            viewModel.exitMultiSelectMode()
                        } else {
                            viewModel.enterMultiSelectMode()
                        }
                    } label: {
                        Text(viewModel.isMultiSelectMode ? "完成" : "编辑")
                    }

                    // 导入菜单
                    Menu {
                        Button {
                            showFilePicker = true
                        } label: {
                            Label("导入漫画文件", systemImage: "doc.zipper")
                        }
                        Button {
                            showImagePicker = true
                        } label: {
                            Label("导入图片", systemImage: "photo.on.rectangle")
                        }
                        Button {
                            showWiFiTransfer = true
                        } label: {
                            Label("WiFi 传书", systemImage: "wifi")
                        }
                        Divider()
                        Menu {
                            ForEach(LibraryViewModel.SortOption.allCases, id: \.self) { option in
                                Button {
                                    viewModel.sortOption = option
                                    viewModel.sortComics()
                                } label: {
                                    if viewModel.sortOption == option {
                                        Label(option.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(option.rawValue)
                                    }
                                }
                            }
                        } label: {
                            Label("排序方式", systemImage: "arrow.up.arrow.down")
                        }
                        Divider()
                        Button {
                            showSettings = true
                        } label: {
                            Label("设置", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "搜索漫画")
            .onAppear {
                viewModel.showFavoritesOnly = showFavoritesOnly
            }
            // 深度链接 / Widget / App Intent 打开漫画
            .onReceive(NotificationCenter.default.publisher(for: .openComicFromIntent)) { note in
                guard let comicID = note.userInfo?["comicID"] as? UUID else { return }
                if let comic = viewModel.comics.first(where: { $0.id == comicID }) {
                    selectedComic = comic
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showStatsFromDeepLink)) { _ in
                showStats = true
            }
            // Sheets
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView { url in
                    Task {
                        await viewModel.importComic(from: url)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView { urls, title in
                    Task {
                        await viewModel.importImages(urls, title: title)
                    }
                }
            }
            .sheet(isPresented: $showWiFiTransfer) {
                WiFiTransferView(modelContext: modelContext)
            }
            .sheet(isPresented: $showStats) {
                StatsView(modelContext: modelContext)
            }
            .sheet(isPresented: $showAllBookmarks) {
                BookmarksView(comic: nil, modelContext: modelContext)
            }
            .sheet(item: $bookmarksComic) { comic in
                BookmarksView(comic: comic, modelContext: modelContext)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(modelContext: modelContext)
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoLibraryPickerView { image in
                    if let comic = comicToChangeCover {
                        viewModel.updateCover(for: comic, image: image)
                    }
                }
            }
            .sheet(isPresented: $showMoveComicSheet) {
                FolderPickerSheet(selectedFolder: comicToMove?.folder) { folder in
                    if let comic = comicToMove {
                        viewModel.moveComicsToFolder(comics: [comic], folder: folder)
                    }
                }
            }
            .sheet(isPresented: $showBatchMoveSheet) {
                FolderPickerSheet(selectedFolder: nil) { folder in
                    viewModel.batchMove(to: folder)
                }
            }
            // Alerts
            .alert("新建文件夹", isPresented: $showNewFolderAlert) {
                TextField("文件夹名称", text: $newFolderName)
                Toggle("设为隐私文件夹", isOn: $newFolderIsPrivate)
                Button("取消", role: .cancel) {}
                Button("创建") {
                    let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        viewModel.createFolder(name: name, isPrivate: newFolderIsPrivate)
                    }
                }
            } message: {
                Text("输入文件夹名称，隐私文件夹需验证后才能查看")
            }
            .alert("重命名文件夹", isPresented: $showRenameFolderAlert) {
                TextField("文件夹名称", text: $renameFolderText)
                Button("取消", role: .cancel) {}
                Button("保存") {
                    if let folder = folderToRename {
                        let name = renameFolderText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty {
                            viewModel.renameFolder(folder, newName: name)
                        }
                    }
                }
            } message: {
                Text("输入新的文件夹名称")
            }
            // 单个删除确认
            .alert("删除漫画", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let comic = comicToDelete {
                        viewModel.deleteComic(comic)
                    }
                }
            } message: {
                Text("确定要删除「\(comicToDelete?.title ?? "")」吗？此操作不可撤销。")
            }
            // 删除文件夹确认
            .alert("删除文件夹", isPresented: $showDeleteFolderConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let folder = folderToDelete {
                        viewModel.deleteFolder(folder)
                    }
                }
            } message: {
                Text("文件夹「\(folderToDelete?.name ?? "")」将被删除，其中的漫画不会被删除，会移至未分类。")
            }
            // 批量删除确认
            .alert("批量删除", isPresented: $showBatchDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    viewModel.batchDelete()
                }
            } message: {
                Text("确定要删除选中的 \(viewModel.selectedComics.count) 部漫画吗？此操作不可撤销。")
            }
            .overlay {
                if viewModel.isImporting {
                    ProgressView("正在导入...")
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
            .alert("导入失败", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("确定", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.isMultiSelectMode {
                    multiSelectToolbar
                }
            }
        }
    }

    // MARK: - 文件夹筛选栏

    private var folderFilterBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // 全部
                    folderChip(title: "全部", icon: "square.grid.2x3.fill", isSelected: viewModel.selectedFolder == nil && !viewModel.showUncategorizedOnly) {
                        viewModel.selectedFolder = nil
                        viewModel.showUncategorizedOnly = false
                    }
                    // 未分类
                    folderChip(title: "未分类", icon: "tray", isSelected: viewModel.showUncategorizedOnly) {
                        viewModel.selectedFolder = nil
                        viewModel.showUncategorizedOnly = true
                    }
                    // 各文件夹（未解锁时隐藏隐私文件夹）
                    ForEach(viewModel.visibleFolders, id: \.id) { folder in
                        folderChip(
                            title: folder.name,
                            icon: folder.iconName,
                            color: Color(folder.color),
                            isSelected: viewModel.selectedFolder?.id == folder.id,
                            showLock: folder.isPrivate && viewModel.isPrivateUnlocked
                        ) {
                            viewModel.selectedFolder = folder
                            viewModel.showUncategorizedOnly = false
                        }
                        .contextMenu {
                            Button {
                                folderToRename = folder
                                renameFolderText = folder.name
                                showRenameFolderAlert = true
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            // 隐私切换
                            Button {
                                viewModel.toggleFolderPrivate(folder)
                            } label: {
                                if folder.isPrivate {
                                    Label("取消隐私", systemImage: "lock.open")
                                } else {
                                    Label("设为隐私", systemImage: "lock")
                                }
                            }
                            Button(role: .destructive) {
                                folderToDelete = folder
                                showDeleteFolderConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // 隐私文件夹快捷解锁/锁定按钮
            Button {
                Task {
                    if viewModel.isPrivateUnlocked {
                        viewModel.lockPrivate()
                    } else {
                        await viewModel.authenticateForPrivate()
                    }
                }
            } label: {
                Image(systemName: viewModel.isPrivateUnlocked ? "lock.fill" : "lock")
                    .foregroundColor(viewModel.isPrivateUnlocked ? .orange : .secondary)
            }
            .padding(.trailing, 12)
        }
    }

    private func folderChip(title: String, icon: String, color: Color = .blue, isSelected: Bool, showLock: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : color)
                Text(title)
                    .font(.subheadline)
                if showLock {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white : .orange)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color.gray.opacity(0.15))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 状态筛选

    private var statusFilterMenu: some View {
        HStack {
            Menu {
                Button {
                    viewModel.statusFilter = nil
                } label: {
                    if viewModel.statusFilter == nil {
                        Label("全部状态", systemImage: "checkmark")
                    } else {
                        Text("全部状态")
                    }
                }
                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    Button {
                        viewModel.statusFilter = status
                    } label: {
                        if viewModel.statusFilter == status {
                            Label(status.displayName, systemImage: "checkmark")
                        } else {
                            Text(status.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(viewModel.statusFilter?.displayName ?? "全部状态")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("书架空空如也")
                .font(.title2)
                .fontWeight(.semibold)
            Text("导入漫画文件（CBZ/CBR/CB7/CBT/ePub/PDF/图片）开始阅读")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button {
                showFilePicker = true
            } label: {
                Label("导入漫画", systemImage: "doc.zipper")
                    .font(.headline)
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    // MARK: - 书架内容

    private var libraryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 继续阅读
                if !viewModel.continueReadingComics.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("继续阅读")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.continueReadingComics) { comic in
                                    Button {
                                        if viewModel.isMultiSelectMode {
                                            viewModel.toggleSelectComic(comic)
                                        } else {
                                            selectedComic = comic
                                        }
                                    } label: {
                                        ComicCoverView(
                                            comic: comic,
                                            isSelected: viewModel.selectedComics.contains(comic.id),
                                            isMultiSelectMode: viewModel.isMultiSelectMode
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                // 全部漫画
                VStack(alignment: .leading, spacing: 12) {
                    Text("全部漫画 (\(viewModel.filteredComics.count))")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150), spacing: 16)
                    ], spacing: 16) {
                        ForEach(viewModel.filteredComics) { comic in
                            Button {
                                if viewModel.isMultiSelectMode {
                                    viewModel.toggleSelectComic(comic)
                                } else {
                                    selectedComic = comic
                                }
                            } label: {
                                ComicCoverView(
                                    comic: comic,
                                    isSelected: viewModel.selectedComics.contains(comic.id),
                                    isMultiSelectMode: viewModel.isMultiSelectMode
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if !viewModel.isMultiSelectMode {
                                    Button {
                                        selectedComic = comic
                                    } label: {
                                        Label("阅读", systemImage: "book")
                                    }
                                    Button {
                                        bookmarksComic = comic
                                    } label: {
                                        Label("查看书签", systemImage: "bookmark")
                                    }
                                    Divider()
                                    // 收藏 / 取消收藏
                                    Button {
                                        viewModel.toggleFavorite(comic)
                                    } label: {
                                        if comic.isFavorite {
                                            Label("取消收藏", systemImage: "heart.slash")
                                        } else {
                                            Label("收藏", systemImage: "heart")
                                        }
                                    }
                                    // 更换封面
                                    Button {
                                        comicToChangeCover = comic
                                        showPhotoPicker = true
                                    } label: {
                                        Label("更换封面", systemImage: "photo")
                                    }
                                    // 移动到文件夹
                                    Button {
                                        comicToMove = comic
                                        showMoveComicSheet = true
                                    } label: {
                                        Label("移动到文件夹", systemImage: "folder")
                                    }
                                    // 设置阅读状态
                                    Menu {
                                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                                            Button {
                                                viewModel.setReadingStatus(comic, status: status)
                                            } label: {
                                                if comic.effectiveReadingStatus == status {
                                                    Label(status.displayName, systemImage: "checkmark")
                                                } else {
                                                    Text(status.displayName)
                                                }
                                            }
                                        }
                                    } label: {
                                        Label("设置状态", systemImage: "flag")
                                    }
                                    Button {
                                        viewModel.resetProgress(comic)
                                    } label: {
                                        Label("重置进度", systemImage: "arrow.counterclockwise")
                                    }
                                    // 导出为 CBZ
                                    Button {
                                        Task {
                                            do {
                                                let cbzURL = try ExportService.shared.exportComicAsCBZ(comic)
                                                ExportService.shared.shareFile(cbzURL)
                                            } catch {
                                                print("导出 CBZ 失败：\(error.localizedDescription)")
                                            }
                                        }
                                    } label: {
                                        Label("导出为 CBZ", systemImage: "square.and.arrow.up")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        comicToDelete = comic
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
        .fullScreenCover(item: $selectedComic) { comic in
            ReaderView(comic: comic, modelContext: modelContext)
        }
    }

    // MARK: - 多选底部工具栏

    private var multiSelectToolbar: some View {
        HStack {
            // 全选 / 取消全选
            Button {
                if viewModel.selectedComics.count == viewModel.filteredComics.count {
                    viewModel.deselectAll()
                } else {
                    viewModel.selectAll()
                }
            } label: {
                Text(viewModel.selectedComics.count == viewModel.filteredComics.count ? "取消全选" : "全选")
                    .font(.subheadline)
            }

            Spacer()

            // 移动到文件夹
            Button {
                showBatchMoveSheet = true
            } label: {
                Image(systemName: "folder")
            }
            .disabled(viewModel.selectedComics.isEmpty)

            // 收藏
            Button {
                viewModel.batchSetFavorite(true)
            } label: {
                Image(systemName: "heart.fill")
            }
            .disabled(viewModel.selectedComics.isEmpty)

            // 取消收藏
            Button {
                viewModel.batchSetFavorite(false)
            } label: {
                Image(systemName: "heart.slash")
            }
            .disabled(viewModel.selectedComics.isEmpty)

            // 删除
            Button(role: .destructive) {
                showBatchDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
            }
            .disabled(viewModel.selectedComics.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 文件夹选择 Sheet

struct FolderPickerSheet: View {
    let selectedFolder: Folder?
    let onSelect: (Folder?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Folder.createdAt) private var allFolders: [Folder]
    @StateObject private var authService = PrivacyAuthService.shared

    /// 未解锁时隐藏隐私文件夹
    private var folders: [Folder] {
        authService.checkLockStatus()
        return allFolders.filter { authService.isUnlocked || !$0.isPrivate }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    onSelect(nil)
                    dismiss()
                } label: {
                    HStack {
                        Label("未分类", systemImage: "tray")
                        Spacer()
                        if selectedFolder == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                ForEach(folders, id: \.id) { folder in
                    Button {
                        onSelect(folder)
                        dismiss()
                    } label: {
                        HStack {
                            Label(folder.name, systemImage: folder.iconName)
                                .foregroundColor(Color(folder.color))
                            if folder.isPrivate {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            if selectedFolder?.id == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择文件夹")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

import Foundation
import UIKit
import SwiftData

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var pages: [UIImage] = []
    @Published var isLoading = true
    @Published var showUI = true
    @Published var readingDirection: ReadingDirection = .leftToRight
    @Published var pageMode: PageMode = .single

    private let comic: Comic
    private let modelContext: ModelContext
    private var pageURLs: [URL] = []

    // MARK: - 图片缓存

    /// 原始图片缓存（磁盘解码后），key 为页码
    private let rawCache = NSCache<NSNumber, UIImage>()
    /// 预处理后图片缓存，key 为 "页码_设置标识"
    private let processedCache = NSCache<NSString, UIImage>()
    /// 后台预加载队列
    private let preloadQueue = DispatchQueue(label: "com.comicreader.preload", qos: .utility)

    init(comic: Comic, modelContext: ModelContext) {
        self.comic = comic
        self.modelContext = modelContext
        self.currentPage = comic.currentPage
        self.readingDirection = ReadingDirection(rawValue: comic.readingDirection) ?? .leftToRight
        self.pageMode = PageMode(rawValue: comic.pageMode) ?? .single

        rawCache.countLimit = 12
        processedCache.countLimit = 12
    }

    var totalPages: Int {
        pageURLs.count
    }

    var progressText: String {
        "\(currentPage + 1) / \(totalPages)"
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage + 1) / Double(totalPages)
    }

    func loadPages() {
        isLoading = true
        pageURLs = FileStorageService.shared.pages(for: comic.folderName)
        comic.lastOpened = Date()
        try? modelContext.save()
        isLoading = false
        preloadImages(around: currentPage)
    }

    // MARK: - 图片加载与缓存

    /// 获取指定页图片（优先缓存，未命中则加载磁盘并应用预处理）
    func image(at index: Int) -> UIImage? {
        guard index >= 0, index < pageURLs.count else { return nil }

        // 预处理缓存 key 包含设置标识，设置变更后自动失效旧缓存
        let procKey = "\(index)_\(ImagePreprocessor.shared.settingsKey)" as NSString
        if let cached = processedCache.object(forKey: procKey) {
            return cached
        }

        let numKey = NSNumber(value: index)
        let rawImage: UIImage
        if let cached = rawCache.object(forKey: numKey) {
            rawImage = cached
        } else {
            guard let loaded = UIImage(contentsOfFile: pageURLs[index].path) else { return nil }
            rawCache.setObject(loaded, forKey: numKey)
            rawImage = loaded
        }

        // 应用预处理（缓存命中后开销很小）
        let processed = ImagePreprocessor.shared.process(rawImage)
        processedCache.setObject(processed, forKey: procKey)

        return processed
    }

    /// 后台异步预加载 currentPage ±1、±2 的原始图片到缓存
    func preloadImages(around page: Int) {
        let candidates = [page - 2, page - 1, page + 1, page + 2]
        for idx in candidates {
            guard idx >= 0, idx < pageURLs.count else { continue }
            let numKey = NSNumber(value: idx)
            if rawCache.object(forKey: numKey) != nil { continue }
            let url = pageURLs[idx]
            preloadQueue.async {
                // 在后台解码图片
                if let image = UIImage(contentsOfFile: url.path) {
                    // NSCache 线程安全，可直接写入
                    rawCache.setObject(image, forKey: numKey)
                }
            }
        }
    }

    // MARK: - 翻页导航

    func goToNextPage() {
        if pageMode == .double {
            if currentPage == 0 {
                goToPage(1)
            } else {
                goToPage(currentPage + 2)
            }
        } else {
            let step = readingDirection == .leftToRight ? 1 : -1
            goToPage(currentPage + step)
        }
    }

    func goToPreviousPage() {
        if pageMode == .double {
            if currentPage == 0 { return }
            goToPage(currentPage - 2)
        } else {
            let step = readingDirection == .leftToRight ? -1 : 1
            goToPage(currentPage + step)
        }
    }

    func goToPage(_ page: Int) {
        var target = max(0, min(page, totalPages - 1))
        // 双页模式下吸附到对页起始（奇数页：1, 3, 5...），封面 0 单独
        if pageMode == .double, target > 0 {
            target = 1 + ((target - 1) / 2) * 2
        }
        currentPage = target
        comic.currentPage = target
        try? modelContext.save()
        preloadImages(around: target)
    }

    func toggleReadingDirection() {
        readingDirection = (readingDirection == .leftToRight) ? .rightToLeft : .leftToRight
        comic.readingDirection = readingDirection.rawValue
        try? modelContext.save()
    }

    func togglePageMode() {
        pageMode = (pageMode == .single) ? .double : .single
        comic.pageMode = pageMode.rawValue
        try? modelContext.save()
    }

    func toggleUI() {
        showUI.toggle()
    }

    // MARK: - 双页布局

    /// 双页模式下计算指定页应显示的左右页码
    /// - Parameter page: 当前页码
    /// - Returns: (left, right)。left 为 nil 表示封面页单独占满整屏，right 为封面索引
    ///
    /// 布局规则：
    /// - page == 0：封面单独显示 (nil, 0)
    /// - LTR：左页=奇数起始，右页=左+1
    /// - RTL（日漫）：右页=当前（奇数起始），左页=当前+1
    func doublePageLayout(for page: Int) -> (left: Int?, right: Int?) {
        guard pageMode == .double else { return (nil, nil) }

        // 封面单独占满
        if page == 0 {
            return (nil, 0)
        }

        // 对页起始：1, 3, 5, ...
        let spreadStart = 1 + ((page - 1) / 2) * 2

        switch readingDirection {
        case .leftToRight:
            return (spreadStart, min(spreadStart + 1, totalPages - 1))
        case .rightToLeft:
            // 右页=当前（spreadStart），左页=下一页（spreadStart+1）
            return (min(spreadStart + 1, totalPages - 1), spreadStart)
        }
    }

    /// 双页模式下获取当前显示的两页图片（兼容旧调用）
    func doublePageImages() -> (left: UIImage?, right: UIImage?) {
        let layout = doublePageLayout(for: currentPage)
        return (
            layout.left.flatMap { image(at: $0) },
            layout.right.flatMap { image(at: $0) }
        )
    }
}

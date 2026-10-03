import Foundation
import ZIPFoundation

/// 负责解压全格式漫画压缩包
///
/// 基于 iOS 系统自带的 libarchive，支持几乎所有压缩格式：
/// - CBZ / ZIP（Deflate, Store, BZIP2, LZMA, ...）
/// - CBR / RAR（RAR4 + RAR5）
/// - CB7 / 7-Zip
/// - CBT / TAR（含 GZIP/BZIP2/XZ 压缩的 TAR）
/// - 以及其他 libarchive 支持的格式
///
/// 同时保留 ZIPFoundation 用于创建 CBZ 文件。
final class ArchiveService {
    static let shared = ArchiveService()
    private init() {}

    // MARK: - 格式检测

    /// 漫画压缩包扩展名集合
    static let archiveExtensions: Set<String> = [
        "cbz", "zip",
        "cbr", "rar",
        "cb7", "7z", "7zip",
        "cbt", "tar",
        "gz", "tgz",
        "bz2", "tbz",
        "xz", "txz"
    ]

    /// 检测文件是否为支持的压缩包格式
    func isArchiveFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ArchiveService.archiveExtensions.contains(ext)
    }

    // MARK: - 统一解压入口

    /// 解压漫画压缩包到指定目录（自动识别格式：CBZ/CBR/CB7/CBT/ZIP/RAR/7z/TAR 等）
    /// - Parameters:
    ///   - sourceURL: 源文件 URL
    ///   - destinationURL: 目标目录 URL
    /// - Returns: 解压后的图片文件路径数组（已排序）
    func extractComic(from sourceURL: URL, to destinationURL: URL) throws -> [URL] {
        let fileManager = FileManager.default

        // 清理目标目录
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // 使用 libarchive 解压（自动识别所有格式）
        try extractWithLibarchive(from: sourceURL, to: destinationURL)

        // 收集图片
        let imageURLs = try collectImageFiles(in: destinationURL)
        return imageURLs
    }

    // MARK: - libarchive 解压核心

    /// 使用 libarchive 解压文件（自动识别格式）
    private func extractWithLibarchive(from sourceURL: URL, to destinationURL: URL) throws {
        let path = sourceURL.path

        // 创建 archive 读取器
        guard let archive = archive_read_new() else {
            throw ComicError.importFailed("无法初始化 libarchive")
        }
        defer {
            archive_read_close(archive)
            archive_read_free(archive)
        }

        // 启用所有过滤器和格式支持
        archive_read_support_filter_all(archive)
        archive_read_support_format_all(archive)

        // 打开文件（10KB 缓冲区）
        let openResult = archive_read_open_filename(archive, path, 10240)
        guard openResult == ARCHIVE_OK else {
            let errorStr = String(cString: archive_error_string(archive))
            throw ComicError.importFailed("无法打开压缩包：\(errorStr)")
        }

        let fileManager = FileManager.default
        var entry: OpaquePointer? = nil

        // 遍历所有条目
        while archive_read_next_header(archive, &entry) == ARCHIVE_OK {
            guard let entryPtr = entry else { continue }

            let entryPath = String(cString: archive_entry_pathname(entryPtr))

            // 跳过 macOS 元数据目录和隐藏文件
            if entryPath.hasPrefix("__MACOSX") ||
               entryPath.contains("/.") ||
               entryPath.hasPrefix(".") {
                archive_read_data_skip(archive)
                continue
            }

            // 获取文件类型
            let fileType = archive_entry_filetype(entryPtr)
            let destURL = destinationURL.appendingPathComponent(entryPath)

            if fileType == AE_IFDIR {
                // 目录：创建
                try? fileManager.createDirectory(at: destURL, withIntermediateDirectories: true)
                archive_read_data_skip(archive)
                continue
            }

            if fileType != AE_IFREG {
                // 符号链接等非普通文件：跳过
                archive_read_data_skip(archive)
                continue
            }

            // 普通文件：确保父目录存在
            let parentDir = destURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try? fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            // 读取数据并写入文件
            let data = try readEntryData(from: archive)
            try data.write(to: destURL)
        }

        // 检查是否正常结束
        let finalResult = archive_read_next_header(archive, &entry)
        if finalResult != ARCHIVE_EOF && finalResult != ARCHIVE_OK {
            // 某些格式可能在末尾有非致命警告，不视为失败
        }
    }

    /// 从当前 archive entry 读取全部数据
    private func readEntryData(from archive: OpaquePointer) throws -> Data {
        var data = Data()
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let bytesRead = archive_read_data(archive, buffer, bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else if bytesRead == 0 {
                break
            } else if bytesRead < 0 {
                // 非致命错误（如某些 RAR 分卷信息），尝试继续
                break
            }
        }
        return data
    }

    // MARK: - ePub 支持

    /// 解压 ePub 漫画并按阅读顺序提取图片
    ///
    /// ePub 本质是 ZIP，包含特定结构。此方法：
    /// 1. 解压全部文件
    /// 2. 解析 META-INF/container.xml 找到 OPF 文件
    /// 3. 解析 OPF 的 spine 获取阅读顺序
    /// 4. 按 spine 顺序提取图片（XHTML 页面解析 img 标签）
    func extractEPub(from sourceURL: URL, to destinationURL: URL) throws -> [URL] {
        // 第一步：用 libarchive 解压（ePub 是 ZIP）
        let tempDir = destinationURL.appendingPathComponent("_epub_raw", isDirectory: true)
        try extractWithLibarchive(from: sourceURL, to: tempDir)

        // 第二步：解析 container.xml 找到 OPF 路径
        let containerURL = tempDir.appendingPathComponent("META-INF/container.xml")
        var opfPath: String?
        if let containerData = try? Data(contentsOf: containerURL),
           let containerStr = String(data: containerData, encoding: .utf8) {
            // 简单解析 full-path 属性
            if let range = containerStr.range(of: "full-path=\"") {
                let rest = containerStr[range.upperBound...]
                if let endRange = rest.range(of: "\"") {
                    opfPath = String(rest[..<endRange.lowerBound])
                }
            }
        }

        // 第三步：解析 OPF 获取 spine 顺序
        var orderedImagePaths: [String] = []
        if let opfPath = opfPath {
            let opfURL = tempDir.appendingPathComponent(opfPath)
            if let opfData = try? Data(contentsOf: opfURL),
               let opfStr = String(data: opfData, encoding: .utf8) {
                orderedImagePaths = parseEPubSpine(opfContent: opfStr, opfBasePath: (opfPath as NSString).deletingLastPathComponent, tempDir: tempDir)
            }
        }

        // 第四步：如果 spine 解析失败，回退到自然排序所有图片
        let allImages = try collectImageFiles(in: tempDir)
        var resultImages: [URL] = []

        if !orderedImagePaths.isEmpty {
            // 按 spine 顺序收集
            let fileManager = FileManager.default
            for imgPath in orderedImagePaths {
                let fullPath = tempDir.appendingPathComponent(imgPath).standardizedFileURL
                if fileManager.fileExists(atPath: fullPath.path) {
                    resultImages.append(fullPath)
                }
            }
        }

        // 如果 spine 没找到图片，用全部图片自然排序
        if resultImages.isEmpty {
            resultImages = allImages
        }

        // 第五步：将图片复制到目标目录根下，按顺序重命名
        let fileManager = FileManager.default
        var finalImages: [URL] = []
        for (index, imgURL) in resultImages.enumerated() {
            let ext = imgURL.pathExtension
            let fileName = String(format: "page_%04d.%@", index + 1, ext)
            let destURL = destinationURL.appendingPathComponent(fileName)
            do {
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                try fileManager.copyItem(at: imgURL, to: destURL)
                finalImages.append(destURL)
            } catch {
                continue
            }
        }

        // 清理临时解压目录
        try? fileManager.removeItem(at: tempDir)

        return finalImages
    }

    /// 解析 ePub OPF 文件的 spine，返回按阅读顺序排列的图片相对路径
    private func parseEPubSpine(opfContent: String, opfBasePath: String, tempDir: URL) -> [String] {
        var imagePaths: [String] = []

        // 解析 manifest：id → href 映射
        var manifest: [String: String] = [:]
        if let manifestRange = opfContent.range(of: "<manifest"),
           let manifestEnd = opfContent.range(of: "</manifest>") {
            let manifestContent = opfContent[manifestRange.lowerBound..<manifestEnd.upperBound]
            // 匹配 <item id="xxx" href="yyy" media-type="zzz"/>
            let itemPattern = "<item[^>]*id=\"([^\"]+)\"[^>]*href=\"([^\"]+)\"[^>]*>"
            if let regex = try? NSRegularExpression(pattern: itemPattern, options: []) {
                let nsRange = NSRange(manifestContent.startIndex..., in: opfContent)
                regex.enumerateMatches(in: opfContent, range: nsRange) { match, _, _ in
                    guard let match = match,
                          let idRange = Range(match.range(at: 1), in: opfContent),
                          let hrefRange = Range(match.range(at: 2), in: opfContent) else { return }
                    let id = String(opfContent[idRange])
                    let href = String(opfContent[hrefRange])
                    manifest[id] = href
                }
            }
        }

        // 解析 spine：按顺序获取 idref
        var spineIds: [String] = []
        if let spineRange = opfContent.range(of: "<spine"),
           let spineEnd = opfContent.range(of: "</spine>") {
            let spineContent = opfContent[spineRange.lowerBound..<spineEnd.upperBound]
            let idrefPattern = "idref=\"([^\"]+)\""
            if let regex = try? NSRegularExpression(pattern: idrefPattern, options: []) {
                let nsRange = NSRange(spineContent.startIndex..., in: opfContent)
                regex.enumerateMatches(in: opfContent, range: nsRange) { match, _, _ in
                    guard let match = match,
                          let range = Range(match.range(at: 1), in: opfContent) else { return }
                    spineIds.append(String(opfContent[range]))
                }
            }
        }

        // 按 spine 顺序解析每个条目对应的图片
        for idref in spineIds {
            guard let href = manifest[idref] else { continue }
            let fullHref = (opfBasePath as NSString).appendingPathComponent(href)
            let ext = (href as NSString).pathExtension.lowercased()

            if isImageExtension(ext) {
                // 直接是图片
                imagePaths.append(fullHref)
            } else if ext == "xhtml" || ext == "html" || ext == "htm" {
                // XHTML 页面：解析其中的 img 标签
                let xhtmlURL = tempDir.appendingPathComponent(fullHref)
                if let xhtmlData = try? Data(contentsOf: xhtmlURL),
                   let xhtmlStr = String(data: xhtmlData, encoding: .utf8) {
                    let imgPaths = parseImagesFromXHTML(xhtmlStr, basePath: (fullHref as NSString).deletingLastPathComponent)
                    imagePaths.append(contentsOf: imgPaths)
                }
            }
        }

        return imagePaths
    }

    /// 从 XHTML 内容中解析 img 标签的 src
    private func parseImagesFromXHTML(_ content: String, basePath: String) -> [String] {
        var paths: [String] = []
        let imgPattern = "<img[^>]*src=\"([^\"]+)\"[^>]*>"
        if let regex = try? NSRegularExpression(pattern: imgPattern, options: []) {
            let nsRange = NSRange(content.startIndex..., in: content)
            regex.enumerateMatches(in: content, range: nsRange) { match, _, _ in
                guard let match = match,
                      let range = Range(match.range(at: 1), in: content) else { return }
                let src = String(content[range])
                // 拼接相对路径
                let fullPath = (basePath as NSString).appendingPathComponent(src)
                paths.append(fullPath)
            }
        }
        return paths
    }

    private func isImageExtension(_ ext: String) -> Bool {
        ["jpg", "jpeg", "png", "webp", "gif", "bmp", "tiff", "heic", "avif"].contains(ext)
    }

    // MARK: - 图片收集

    /// 递归收集目录中的所有图片文件并按自然顺序排序
    func collectImageFiles(in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "bmp", "tiff", "heic", "avif"]

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var imageURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(ext) {
                imageURLs.append(fileURL)
            }
        }

        // 自然排序
        imageURLs.sort { url1, url2 in
            let name1 = url1.deletingPathExtension().lastPathComponent
            let name2 = url2.deletingPathExtension().lastPathComponent
            return name1.localizedStandardCompare(name2) == .orderedAscending
        }

        return imageURLs
    }

    // MARK: - 创建 CBZ

    /// 将图片文件打包为 CBZ（ZIP）文件
    func createCBZ(from imageURLs: [URL], to destinationURL: URL) throws {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        guard let archive = Archive(url: destinationURL, accessMode: .create) else {
            throw ComicError.importFailed("无法创建 CBZ 文件")
        }

        for imageURL in imageURLs {
            let fileName = imageURL.lastPathComponent
            let data = try Data(contentsOf: imageURL)

            try archive.addEntry(
                with: fileName,
                type: .file,
                uncompressedSize: UInt32(data.count),
                provider: { position, size in
                    data.subdata(in: position..<(position + size))
                }
            )
        }
    }
}

// MARK: - 错误类型

enum ComicError: LocalizedError {
    case invalidArchive
    case noImagesFound
    case importFailed(String)
    case invalidPDF
    case emptyPDF

    var errorDescription: String? {
        switch self {
        case .invalidArchive:
            return "无法解析漫画文件，文件可能已损坏"
        case .noImagesFound:
            return "压缩包中未找到图片文件"
        case .importFailed(let message):
            return "导入失败：\(message)"
        case .invalidPDF:
            return "无法打开 PDF 文件，文件可能已损坏或受密码保护"
        case .emptyPDF:
            return "PDF 文件为空，没有可渲染的页面"
        }
    }
}

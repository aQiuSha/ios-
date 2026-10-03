import Foundation
import UIKit
import SwiftData

/// 处理漫画导入流程：解压 → 存储 → 生成封面 → 入库
final class ComicImportService {
    static let shared = ComicImportService()
    private init() {}

    /// 支持的文件扩展名
    static let supportedExtensions: Set<String> = [
        // 压缩包格式（libarchive 全支持）
        "cbz", "zip",
        "cbr", "rar",
        "cb7", "7z",
        "cbt", "tar",
        "gz", "tgz",
        "bz2", "tbz",
        "xz", "txz",
        // 电子书
        "epub",
        // PDF
        "pdf",
        // 图片
        "jpg", "jpeg", "png", "webp", "gif", "bmp", "tiff", "heic", "avif"
    ]

    /// 从文件 URL 导入漫画（支持全格式）
    @MainActor
    func importComic(from url: URL, modelContext: ModelContext) async throws -> Comic {
        let title = url.deletingPathExtension().lastPathComponent
        let folderName = FileStorageService.shared.generateFolderName(for: title)
        let destinationDir = FileStorageService.shared.comicDirectory(for: folderName)

        let ext = url.pathExtension.lowercased()
        var pageURLs: [URL] = []

        if ext == "epub" {
            // ePub：解析 spine 按阅读顺序提取图片
            pageURLs = try ArchiveService.shared.extractEPub(from: url, to: destinationDir)
        } else if ext == "pdf" {
            // PDF：逐页渲染为图片
            pageURLs = try await Task.detached(priority: .userInitiated) {
                try PDFService.shared.convertPDFToImages(from: url, to: destinationDir)
            }.value
        } else if ArchiveService.archiveExtensions.contains(ext) {
            // 所有压缩包格式：CBZ/CBR/CB7/CBT/ZIP/RAR/7z/TAR/GZ/BZ2/XZ 等
            // libarchive 自动识别格式，无需按扩展名分发
            pageURLs = try ArchiveService.shared.extractComic(from: url, to: destinationDir)
        } else if isImageExtension(ext) {
            // 单张图片：复制到目录
            try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
            let destURL = destinationDir.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.copyItem(at: url, to: destURL)
            pageURLs = [destURL]
        } else {
            throw ComicError.importFailed("不支持的文件格式：.\(ext)")
        }

        guard !pageURLs.isEmpty else {
            try? FileManager.default.removeItem(at: destinationDir)
            throw ComicError.noImagesFound
        }

        // 生成封面缩略图
        var coverPath: String? = nil
        if let firstImage = UIImage(contentsOfFile: pageURLs[0].path) {
            coverPath = FileStorageService.shared.saveThumbnail(for: folderName, image: firstImage)
        }

        // 创建数据库记录
        let comic = Comic(
            title: title,
            coverPath: coverPath,
            pageCount: pageURLs.count,
            folderName: folderName
        )
        modelContext.insert(comic)
        try modelContext.save()

        return comic
    }

    /// 从图片数组导入（多张图片选择）
    @MainActor
    func importComic(from imageURLs: [URL], title: String, modelContext: ModelContext) async throws -> Comic {
        guard !imageURLs.isEmpty else {
            throw ComicError.noImagesFound
        }

        let folderName = FileStorageService.shared.generateFolderName(for: title)
        let destinationDir = FileStorageService.shared.comicDirectory(for: folderName)
        try FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        var pageURLs: [URL] = []
        for (index, url) in imageURLs.enumerated() {
            let ext = url.pathExtension
            let fileName = String(format: "page_%04d.%@", index + 1, ext)
            let destURL = destinationDir.appendingPathComponent(fileName)
            try FileManager.default.copyItem(at: url, to: destURL)
            pageURLs.append(destURL)
        }

        // 生成封面
        var coverPath: String? = nil
        if let firstImage = UIImage(contentsOfFile: pageURLs[0].path) {
            coverPath = FileStorageService.shared.saveThumbnail(for: folderName, image: firstImage)
        }

        let comic = Comic(
            title: title,
            coverPath: coverPath,
            pageCount: pageURLs.count,
            folderName: folderName
        )
        modelContext.insert(comic)
        try modelContext.save()

        return comic
    }

    private func isImageExtension(_ ext: String) -> Bool {
        ["jpg", "jpeg", "png", "webp", "gif", "bmp", "tiff", "heic", "avif"].contains(ext)
    }
}

import Foundation
import UIKit

/// 管理漫画文件在 App 沙盒中的存储
final class FileStorageService {
    static let shared = FileStorageService()
    private init() {}

    /// 漫画存储根目录
    var comicsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Comics", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 缩略图缓存目录
    var thumbnailsDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("Thumbnails", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// WiFi 传书临时文件目录
    var wifiTempDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("WiFiUploads", isDirectory: true)
    }

    /// 自定义背景图片存储路径
    var customBackgroundURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("customReaderBackground.jpg")
    }

    /// 保存自定义阅读背景图片
    func saveCustomBackground(_ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }
        do {
            if FileManager.default.fileExists(atPath: customBackgroundURL.path) {
                try FileManager.default.removeItem(at: customBackgroundURL)
            }
            try data.write(to: customBackgroundURL)
            return true
        } catch {
            return false
        }
    }

    /// 加载自定义阅读背景图片
    func loadCustomBackground() -> UIImage? {
        guard FileManager.default.fileExists(atPath: customBackgroundURL.path) else { return nil }
        return UIImage(contentsOfFile: customBackgroundURL.path)
    }

    /// 删除自定义背景图片
    func removeCustomBackground() {
        try? FileManager.default.removeItem(at: customBackgroundURL)
    }

    /// 为漫画创建唯一的存储文件夹名
    func generateFolderName(for title: String) -> String {
        let safeTitle = title
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(safeTitle)_\(timestamp)"
    }

    /// 获取漫画文件夹的完整路径
    func comicDirectory(for folderName: String) -> URL {
        comicsDirectory.appendingPathComponent(folderName, isDirectory: true)
    }

    /// 获取漫画所有页面图片
    func pages(for folderName: String) -> [URL] {
        let dir = comicDirectory(for: folderName)
        return (try? ArchiveService.shared.collectImageFiles(in: dir)) ?? []
    }

    /// 获取指定页的图片
    func pageImage(for folderName: String, at index: Int) -> UIImage? {
        let pages = self.pages(for: folderName)
        guard index >= 0, index < pages.count else { return nil }
        return UIImage(contentsOfFile: pages[index].path)
    }

    /// 生成并保存封面缩略图
    func saveThumbnail(for folderName: String, image: UIImage) -> String? {
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent("\(folderName).jpg")
        // 缩放至合适尺寸
        let size = CGSize(width: 300, height: 420)
        let scaled = image.resized(to: size)
        guard let data = scaled.jpegData(compressionQuality: 0.7) else { return nil }
        do {
            try data.write(to: thumbnailURL)
            return thumbnailURL.path
        } catch {
            return nil
        }
    }

    /// 加载封面缩略图
    func loadThumbnail(path: String?) -> UIImage? {
        guard let path else { return nil }
        return UIImage(contentsOfFile: path)
    }

    /// 删除漫画及其所有文件
    func deleteComic(folderName: String, thumbnailPath: String?) {
        let dir = comicDirectory(for: folderName)
        try? FileManager.default.removeItem(at: dir)
        if let thumbnailPath {
            try? FileManager.default.removeItem(atPath: thumbnailPath)
        }
    }

    /// 计算漫画文件夹大小（字节）
    func folderSize(for folderName: String) -> Int64 {
        let dir = comicDirectory(for: folderName)
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
        return totalSize
    }

    // MARK: - 缓存管理

    /// 缓存总大小（字节）：缩略图 + WiFi 传书临时文件
    var cacheSize: Int64 {
        thumbnailsSize + wifiTempSize
    }

    /// 缩略图缓存大小
    private var thumbnailsSize: Int64 {
        directorySize(at: thumbnailsDirectory)
    }

    /// WiFi 传书临时文件大小
    private var wifiTempSize: Int64 {
        directorySize(at: wifiTempDirectory)
    }

    /// 计算指定目录大小
    private func directorySize(at url: URL) -> Int64 {
        var totalSize: Int64 = 0
        let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        while let fileURL = enumerator?.nextObject() as? URL {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }

    /// 清理全部缓存（缩略图 + WiFi 临时文件），不删除目录本身
    func clearCache() {
        clearThumbnails()
        clearWiFiTemp()
    }

    /// 仅清理缩略图缓存（已导入漫画的封面缩略图将被删除，下次打开时重新生成）
    func clearThumbnails() {
        clearContents(of: thumbnailsDirectory)
    }

    /// 仅清理 WiFi 传书临时文件
    func clearWiFiTemp() {
        clearContents(of: wifiTempDirectory)
    }

    /// 清空指定目录下的所有文件和子目录，但保留目录本身
    private func clearContents(of directory: URL) {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
    }
}

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, UIScreen.main.scale)
        draw(in: CGRect(origin: .zero, size: scaledSize))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaled ?? self
    }
}

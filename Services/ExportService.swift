import Foundation
import UIKit

/// 负责漫画格式转换与文件导出功能
///
/// 支持：
/// - 将已导入的漫画重新打包为 CBZ 并分享
/// - 将 PDF 逐页渲染后导出为 CBZ
/// - 将 PDF 转换为图片包（ZIP）
/// - 通过系统分享面板（UIActivityViewController）分享文件
/// - CBR 格式检测与用户引导
final class ExportService {
    static let shared = ExportService()
    private init() {}

    // MARK: - 导出为 CBZ（已导入漫画）

    /// 将已导入的漫画重新打包为 CBZ 文件并导出
    ///
    /// 适用于任何已导入的漫画（无论原始格式是 CBZ/ZIP/PDF/图片），
    /// 直接从沙盒中的页面图片重新打包为标准 CBZ。
    ///
    /// - Parameter comic: 要导出的漫画
    /// - Returns: 生成的 CBZ 文件临时 URL
    /// - Throws: 图片读取或打包错误
    func exportComicAsCBZ(_ comic: Comic) throws -> URL {
        // 获取漫画所有页面图片（已排序）
        let imageURLs = FileStorageService.shared.pages(for: comic.folderName)
        guard !imageURLs.isEmpty else {
            throw ComicError.noImagesFound
        }

        // 输出到临时目录
        let fileName = "\(comic.title).cbz"
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)

        try ArchiveService.shared.createCBZ(from: imageURLs, to: destinationURL)
        return destinationURL
    }

    // MARK: - PDF 转 CBZ

    /// 将 PDF 文件转换为 CBZ（逐页渲染后打包）
    ///
    /// 流程：PDF → 逐页渲染为 JPG → 打包为 CBZ
    /// 渲染为同步操作，内部已切换到后台队列执行。
    ///
    /// - Parameter pdfURL: 源 PDF 文件 URL
    /// - Returns: 生成的 CBZ 文件临时 URL
    /// - Throws: PDF 打开、渲染或打包错误
    func exportPDFAsCBZ(_ pdfURL: URL) async throws -> URL {
        // 创建临时渲染目录
        let tempRenderDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFRender_\(UUID().uuidString)")

        defer {
            // 清理中间临时目录
            try? FileManager.default.removeItem(at: tempRenderDir)
        }

        // PDFService.convertPDFToImages 为同步阻塞操作，放到后台执行
        let imageURLs: [URL] = try await Task.detached(priority: .userInitiated) {
            try PDFService.shared.convertPDFToImages(from: pdfURL, to: tempRenderDir)
        }.value

        guard !imageURLs.isEmpty else {
            throw ComicError.noImagesFound
        }

        // 输出 CBZ 到临时目录
        let pdfFileName = pdfURL.deletingPathExtension().lastPathComponent
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(pdfFileName).cbz")

        try ArchiveService.shared.createCBZ(from: imageURLs, to: destinationURL)
        return destinationURL
    }

    // MARK: - PDF 转图片包

    /// 将 PDF 转换为图片包（导出为包含图片的 ZIP）
    ///
    /// 与 exportPDFAsCBZ 本质相同（ZIP 打包图片），提供语义区分，
    /// 方便调用方在 UI 上展示「导出为图片包」的选项。
    ///
    /// - Parameter pdfURL: 源 PDF 文件 URL
    /// - Returns: 生成的 ZIP 文件临时 URL
    /// - Throws: PDF 打开、渲染或打包错误
    func exportPDFAsImagePackage(_ pdfURL: URL) async throws -> URL {
        // 创建临时渲染目录
        let tempRenderDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PDFImagePackage_\(UUID().uuidString)")

        defer {
            // 清理中间临时目录
            try? FileManager.default.removeItem(at: tempRenderDir)
        }

        // 后台渲染 PDF 为图片
        let imageURLs: [URL] = try await Task.detached(priority: .userInitiated) {
            try PDFService.shared.convertPDFToImages(from: pdfURL, to: tempRenderDir)
        }.value

        guard !imageURLs.isEmpty else {
            throw ComicError.noImagesFound
        }

        // 打包为 ZIP（图片包）
        let pdfFileName = pdfURL.deletingPathExtension().lastPathComponent
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(pdfFileName)_图片包.zip")

        try ArchiveService.shared.createCBZ(from: imageURLs, to: destinationURL)
        return destinationURL
    }

    // MARK: - 文件分享

    /// 通过 UIActivityViewController 分享/保存文件
    ///
    /// 自动获取当前 keyWindow 并在主线程弹出分享面板。
    ///
    /// - Parameters:
    ///   - url: 要分享的文件 URL
    ///   - viewController: 来源 UIViewController（用于 iPad popover 定位）；传 nil 时自动获取 keyWindow
    func shareFile(_ url: URL, from viewController: UIViewController? = nil) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        // iPad 适配：设置 popover 锚点
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController?.view
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        // 在主线程 present
        DispatchQueue.main.async {
            let presentingVC = viewController ?? self.currentKeyWindowViewController()
            presentingVC?.present(activityVC, animated: true)
        }
    }

    /// 自动获取当前 keyWindow 上最顶层的 ViewController
    ///
    /// - Returns: 最顶层的 UIViewController，用于 present 分享面板
    private func currentKeyWindowViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        var topVC = keyWindow.rootViewController
        while let presentedVC = topVC?.presentedViewController {
            topVC = presentedVC
        }
        return topVC
    }

    // MARK: - 全格式转换为 CBZ

    /// 将任意支持的压缩包格式转换为 CBZ
    ///
    /// 利用 libarchive 解压源文件（支持 CBR/RAR/CB7/7z/CBT/TAR/ZIP 等），
    /// 再用 ZIPFoundation 重新打包为标准 CBZ。
    ///
    /// - Parameter sourceURL: 源压缩包文件 URL
    /// - Returns: 生成的 CBZ 文件 URL（位于临时目录）
    func convertArchiveToCBZ(from sourceURL: URL) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("convert_\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // 用 libarchive 解压（自动识别所有格式）
        let imageURLs = try ArchiveService.shared.extractComic(from: sourceURL, to: tempDir)
        guard !imageURLs.isEmpty else {
            throw ComicError.noImagesFound
        }

        // 打包为 CBZ
        let cbzURL = tempDir.deletingLastPathComponent()
            .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("cbz")
        try ArchiveService.shared.createCBZ(from: imageURLs, to: cbzURL)

        return cbzURL
    }
}

// MARK: - SwiftUI 便捷分享修饰器

import SwiftUI

/// 用于在 SwiftUI 视图中弹出系统分享面板的 ViewModifier
///
/// 用法示例：
/// ```swift
/// .shareSheet(isPresented: $showShare, url: shareURL)
/// ```
struct ShareSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let url: URL

    func body(content: Content) -> some View {
        content
            .background(
                ShareSheetPresenter(isPresented: $isPresented, url: url)
            )
    }
}

/// 内部 UIViewControllerRepresentable，负责实际弹出 UIActivityViewController
private struct ShareSheetPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let url: URL

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = uiViewController.view
                popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX, y: uiViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            uiViewController.present(activityVC, animated: true) {
                isPresented = false
            }
        }
    }
}

extension View {
    /// 在 SwiftUI 视图中弹出系统分享面板
    ///
    /// - Parameters:
    ///   - isPresented: 控制分享面板是否弹出的 Binding
    ///   - url: 要分享的文件 URL
    func shareSheet(isPresented: Binding<Bool>, url: URL) -> some View {
        modifier(ShareSheetModifier(isPresented: isPresented, url: url))
    }
}

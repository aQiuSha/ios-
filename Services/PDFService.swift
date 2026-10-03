import Foundation
import UIKit
import PDFKit

/// 负责将 PDF 文件逐页渲染为 JPG 图片，供漫画阅读器使用
final class PDFService {
    static let shared = PDFService()
    private init() {}

    /// 渲染目标宽度（约屏幕宽度 2 倍，保证清晰度）
    private let targetRenderWidth: CGFloat = 1500

    /// 将 PDF 每一页渲染为 JPG 图片并保存到指定目录
    /// - Parameters:
    ///   - pdfURL: PDF 文件 URL
    ///   - destinationDir: 图片输出目录
    /// - Returns: 渲染后的图片 URL 数组（按页码排序）
    func convertPDFToImages(from pdfURL: URL, to destinationDir: URL) throws -> [URL] {
        let fileManager = FileManager.default

        // 如果目标目录已存在，先删除
        if fileManager.fileExists(atPath: destinationDir.path) {
            try fileManager.removeItem(at: destinationDir)
        }
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        // 打开 PDF 文档
        guard let document = PDFDocument(url: pdfURL) else {
            throw ComicError.invalidPDF
        }

        let pageCount = document.pageCount
        guard pageCount > 0 else {
            // 加密/空 PDF 会导致 pageCount 为 0
            throw ComicError.emptyPDF
        }

        var imageURLs: [URL] = []
        for i in 0..<pageCount {
            guard let page = document.page(at: i) else { continue }

            // 渲染页面为 UIImage
            guard let image = renderPage(page, targetWidth: targetRenderWidth) else { continue }

            // 保存为 page_0001.jpg 格式
            let fileName = String(format: "page_%04d.jpg", i + 1)
            let fileURL = destinationDir.appendingPathComponent(fileName)

            guard let data = image.jpegData(compressionQuality: 0.85) else { continue }
            try data.write(to: fileURL)
            imageURLs.append(fileURL)
        }

        guard !imageURLs.isEmpty else {
            throw ComicError.noImagesFound
        }

        return imageURLs
    }

    /// 将单个 PDFPage 渲染为指定宽度的 UIImage
    private func renderPage(_ page: PDFPage, targetWidth: CGFloat) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = targetWidth / bounds.width
        let scaledSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { context in
            // 白色背景（PDF 透明区域需填充白色）
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))

            // 应用缩放变换并绘制 PDF 页面
            let cgContext = context.cgContext
            cgContext.translateBy(x: 0, y: scaledSize.height)
            cgContext.scaleBy(x: scale, y: -scale)
            cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)

            page.draw(with: .mediaBox, to: cgContext)
        }
    }
}

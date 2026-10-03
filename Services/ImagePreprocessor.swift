import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// 图片预处理工具：自动裁白边、增强对比度、灰度化
final class ImagePreprocessor {
    static let shared = ImagePreprocessor()
    private init() {}

    private let ciContext = CIContext()

    /// 当前预处理设置的标识串（用于缓存 key 区分不同设置）
    var settingsKey: String {
        let d = UserDefaults.standard
        let crop = d.bool(forKey: "autoCropWhiteBorder")
        let contrast = d.bool(forKey: "enhanceContrast")
        let gray = d.bool(forKey: "grayscaleMode")
        let enhance = d.string(forKey: "imageEnhanceLevel") ?? "off"
        return "c\(crop ? 1 : 0)_t\(contrast ? 1 : 0)_g\(gray ? 1 : 0)_e\(enhance)"
    }

    /// 根据当前开关应用全部启用的预处理
    func process(_ image: UIImage) -> UIImage {
        let d = UserDefaults.standard
        var result = image
        if d.bool(forKey: "grayscaleMode") {
            result = applyGrayscale(result)
        }
        if d.bool(forKey: "enhanceContrast") {
            result = applyContrast(result)
        }
        // AI 画质增强（在裁白边之前应用，避免增强干扰边缘检测）
        result = ImageEnhancerService.shared.enhance(result)
        if d.bool(forKey: "autoCropWhiteBorder") {
            result = cropWhiteBorder(result)
        }
        return result
    }

    // MARK: - 灰度

    func applyGrayscale(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.saturation = 0
        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent)
        else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - 增强对比度

    func applyContrast(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.contrast = 1.3
        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent)
        else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - 自动裁剪白边

    /// 扫描图片边缘像素，找到非白色内容的边界，裁掉四周白边
    func cropWhiteBorder(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 20, height > 20 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 亮度阈值：RGB 平均值低于此值视为内容像素
        let threshold: UInt8 = 242

        func isContent(_ offset: Int) -> Bool {
            let r = pixelData[offset]
            let g = pixelData[offset + 1]
            let b = pixelData[offset + 2]
            return r < threshold || g < threshold || b < threshold
        }

        // 扫描步长（采样而非逐像素，提升性能）
        let xStep = max(2, width / 200)
        let yStep = max(2, height / 200)

        // 上边
        var top = 0
        outerTop: for y in stride(from: 0, to: height, by: yStep) {
            let row = y * bytesPerRow
            for x in stride(from: 0, to: width, by: xStep) {
                if isContent(row + x * bytesPerPixel) {
                    top = y
                    break outerTop
                }
            }
        }

        // 下边
        var bottom = height - 1
        outerBottom: for y in stride(from: height - 1, through: 0, by: -yStep) {
            let row = y * bytesPerRow
            for x in stride(from: 0, to: width, by: xStep) {
                if isContent(row + x * bytesPerPixel) {
                    bottom = y
                    break outerBottom
                }
            }
        }

        // 左边
        var left = 0
        outerLeft: for x in stride(from: 0, to: width, by: xStep) {
            for y in stride(from: 0, to: height, by: yStep) {
                if isContent(y * bytesPerRow + x * bytesPerPixel) {
                    left = x
                    break outerLeft
                }
            }
        }

        // 右边
        var right = width - 1
        outerRight: for x in stride(from: width - 1, through: 0, by: -xStep) {
            for y in stride(from: 0, to: height, by: yStep) {
                if isContent(y * bytesPerRow + x * bytesPerPixel) {
                    right = x
                    break outerRight
                }
            }
        }

        guard right > left, bottom > top else { return image }

        var cropRect = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)

        // 保留少量边距
        let pad: CGFloat = 2
        cropRect = cropRect.insetBy(dx: -pad, dy: -pad)
        cropRect = cropRect.intersection(CGRect(x: 0, y: 0, width: width, height: height))

        // 裁剪后太小则放弃
        guard cropRect.width > 20, cropRect.height > 20 else { return image }

        if let cropped = cgImage.cropping(to: cropRect) {
            return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }
}

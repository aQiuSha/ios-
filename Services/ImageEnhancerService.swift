import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

/// AI 画质增强服务
///
/// 完全免费、离线运行，利用苹果原生框架：
/// - Vision 框架 `VNGenerateImageEnhancementRequest`：系统级 AI 图像增强（Apple Neural Engine 本地推理）
/// - Core Image：漫画专用优化管线（去网点降噪、智能锐化、对比度、超分辨率）
///
/// 针对漫画/扫描件优化：
/// - 去除印刷网点和扫描噪点
/// - 增强线条锐度
/// - 提升黑白对比度
/// - 可选超分辨率放大
final class ImageEnhancerService {
    static let shared = ImageEnhancerService()
    private init() {}

    private let ciContext = CIContext()

    /// 当前增强级别（从 UserDefaults 读取）
    private var currentLevel: ImageEnhanceLevel {
        let raw = UserDefaults.standard.string(forKey: "imageEnhanceLevel") ?? ImageEnhanceLevel.off.rawValue
        return ImageEnhanceLevel(rawValue: raw) ?? .off
    }

    /// 对图片应用 AI 画质增强
    /// - Parameter image: 原始图片
    /// - Returns: 增强后的图片（如果级别为 off 则返回原图）
    func enhance(_ image: UIImage) -> UIImage {
        let level = currentLevel
        guard level != .off else { return image }

        // 成就：使用 AI 画质增强
        if level.usesAI {
            AchievementService.shared.unlock(.aiEnhancer)
        }

        var result = image

        // 第一步：Core Image 漫画优化管线（所有非 off 级别都应用，参数按级别递增）
        result = applyComicPipeline(result, level: level)

        // 第二步：Vision AI 增强（medium 及以上）
        if level.usesAI {
            result = applyVisionAIEnhancement(result) ?? result
        }

        // 第三步：超分辨率（仅 strong）
        if level.usesSuperResolution {
            result = applySuperResolution(result)
        }

        return result
    }

    // MARK: - Core Image 漫画优化管线

    /// 漫画专用优化：去网点降噪 → 智能锐化 → 对比度提升
    private func applyComicPipeline(_ image: UIImage, level: ImageEnhanceLevel) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        var workingImage = ciImage

        // 1. 降噪（去印刷网点/扫描噪点）
        let noiseAmount: Float
        switch level {
        case .light: noiseAmount = 0.02
        case .medium: noiseAmount = 0.04
        case .strong: noiseAmount = 0.06
        default: noiseAmount = 0
        }
        if noiseAmount > 0 {
            let noiseFilter = CIFilter.noiseReduction()
            noiseFilter.inputImage = workingImage
            noiseFilter.noiseLevel = noiseAmount
            noiseFilter.sharpness = 0.5
            if let output = noiseFilter.outputImage {
                workingImage = output
            }
        }

        // 2. 智能锐化（Unsharp Mask，比普通锐化更自然）
        let sharpenIntensity: Float
        let sharpenRadius: Double
        switch level {
        case .light:
            sharpenIntensity = 0.5
            sharpenRadius = 1.5
        case .medium:
            sharpenIntensity = 0.8
            sharpenRadius = 2.0
        case .strong:
            sharpenIntensity = 1.2
            sharpenRadius = 2.5
        default:
            sharpenIntensity = 0
            sharpenRadius = 0
        }
        if sharpenIntensity > 0 {
            let sharpenFilter = CIFilter.unsharpMask()
            sharpenFilter.inputImage = workingImage
            sharpenFilter.intensity = sharpenIntensity
            sharpenFilter.radius = sharpenRadius
            if let output = sharpenFilter.outputImage {
                workingImage = output
            }
        }

        // 3. 对比度+亮度微调（让黑白更分明，线条更清晰）
        let contrast: Float
        let brightness: Float
        switch level {
        case .light:
            contrast = 1.1
            brightness = 0
        case .medium:
            contrast = 1.18
            brightness = 0.01
        case .strong:
            contrast = 1.25
            brightness = 0.02
        default:
            contrast = 1.0
            brightness = 0
        }
        if contrast != 1.0 || brightness != 0 {
            let colorFilter = CIFilter.colorControls()
            colorFilter.inputImage = workingImage
            colorFilter.contrast = contrast
            colorFilter.brightness = brightness
            colorFilter.saturation = 1.0
            if let output = colorFilter.outputImage {
                workingImage = output
            }
        }

        // 渲染回 UIImage
        guard let cgImage = ciContext.createCGImage(workingImage, from: ciImage.extent) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Vision AI 增强

    /// 使用 Vision 框架的 AI 图像增强
    /// 利用 Apple Neural Engine 本地推理，自动优化亮度、对比度、降噪、细节
    private func applyVisionAIEnhancement(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNGenerateImageEnhancementRequest()
        // 使用 balanced 级别，在质量和速度间平衡
        request.level = .balanced

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            // observation.image 是 CIImage 格式
            let enhancedCIImage = observation.image
            guard let enhancedCGImage = ciContext.createCGImage(enhancedCIImage, from: enhancedCIImage.extent) else {
                return nil
            }
            return UIImage(cgImage: enhancedCGImage, scale: image.scale, orientation: image.imageOrientation)
        } catch {
            print("Vision AI enhancement failed: \(error)")
            return nil
        }
    }

    // MARK: - 超分辨率

    /// 超分辨率放大：使用 Lanczos 重采样提升分辨率
    /// 对于低分辨率漫画（宽度 < 1000px）放大 1.5 倍
    private func applySuperResolution(_ image: UIImage) -> UIImage {
        let targetScale: CGFloat = 1.5
        let newSize = CGSize(
            width: image.size.width * targetScale,
            height: image.size.height * targetScale
        )

        // 只有小图才放大，避免大图无谓的内存开销
        guard image.size.width < 1200 else { return image }

        guard let ciImage = CIImage(image: image) else { return image }

        let filter = CIFilter.lanczosScaleTransform()
        filter.inputImage = ciImage
        filter.scale = Float(targetScale)
        filter.aspectRatio = 1.0

        guard let output = filter.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent)
        else { return image }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

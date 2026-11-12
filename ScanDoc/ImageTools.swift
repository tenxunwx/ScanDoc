import UIKit
import CoreImage

enum ImageTools {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// 把相机/相册带回的方向信息「烤」进像素，后续处理就不必关心 orientation。
    static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// 按模式渲染扫描效果。原图直接返回，避免无谓的重编码。
    static func render(_ image: UIImage, mode: EnhanceMode) -> UIImage {
        guard mode != .original else { return image }

        let base = normalized(image)
        guard let cgImage = base.cgImage else { return base }
        var output = CIImage(cgImage: cgImage)
        let extent = output.extent

        switch mode {
        case .enhanced:
            output = output.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputShadowAmount": 0.45,
                "inputHighlightAmount": 0.9
            ])
            output = output.applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.10,
                kCIInputBrightnessKey: 0.02,
                kCIInputSaturationKey: 1.05
            ])

        case .grayscale:
            output = output.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.18
            ])
            output = output.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.5,
                kCIInputIntensityKey: 0.4
            ])

        case .blackWhite:
            output = output.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,
                kCIInputContrastKey: 1.55,
                kCIInputBrightnessKey: 0.06
            ])
            output = output.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: 0.15
            ])
            output = output.applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 2.0,
                kCIInputIntensityKey: 0.5
            ])

        case .original:
            return base
        }

        guard let result = ciContext.createCGImage(output, from: extent) else { return base }
        return UIImage(cgImage: result, scale: base.scale, orientation: .up)
    }

    static func thumbnail(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        guard scale < 1 else { return image }

        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

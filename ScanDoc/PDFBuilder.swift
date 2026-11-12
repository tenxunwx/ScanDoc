import UIKit

enum PDFBuilder {
    /// A4 尺寸（72 dpi）
    static let a4 = CGSize(width: 595.2, height: 841.8)

    /// 把多张图按顺序排成一份 A4 PDF，页面居中、等比缩放。
    static func makePDF(pages: [UIImage], title: String) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "ScanDoc"
        ]

        let bounds = CGRect(origin: .zero, size: a4)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        return renderer.pdfData { context in
            for image in pages {
                context.beginPage()
                draw(image: image, pageRect: bounds)
            }
        }
    }

    private static func draw(image: UIImage, pageRect: CGRect) {
        let normalized = ImageTools.normalized(image)
        let size = normalized.size
        guard size.width > 0, size.height > 0 else { return }

        UIColor.white.setFill()
        UIRectFill(pageRect)

        let inset: CGFloat = 12
        let box = pageRect.insetBy(dx: inset, dy: inset)
        let scale = min(box.width / size.width, box.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let rect = CGRect(x: (pageRect.width - drawSize.width) / 2,
                          y: (pageRect.height - drawSize.height) / 2,
                          width: drawSize.width,
                          height: drawSize.height)
        normalized.draw(in: rect)
    }
}

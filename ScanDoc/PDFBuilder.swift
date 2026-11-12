import UIKit

enum PDFBuilder {
    /// A4 尺寸（72 dpi）
    static let a4Width: CGFloat = 595.2
    static let a4Height: CGFloat = 841.8

    struct Page {
        var image: UIImage
        var lines: [OCRLine]
    }

    static func makePDF(pages: [Page], title: String, options: ExportOptions) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "ScanDoc"
        ]

        let firstPage = pageRect(for: pages.first?.image, options: options)
        let renderer = UIGraphicsPDFRenderer(bounds: firstPage, format: format)

        return renderer.pdfData { context in
            for (index, page) in pages.enumerated() {
                let rect = pageRect(for: page.image, options: options)
                if index == 0 {
                    context.beginPage()
                } else {
                    context.beginPage(withBounds: rect, pageInfo: [:])
                }
                draw(page: page, in: rect, options: options)
            }
        }
    }

    // MARK: - 私有

    private static func pageRect(for image: UIImage?, options: ExportOptions) -> CGRect {
        switch options.pageSize {
        case .a4:
            return CGRect(x: 0, y: 0, width: a4Width, height: a4Height)
        case .fitImage:
            guard let size = image?.size, size.width > 0 else {
                return CGRect(x: 0, y: 0, width: a4Width, height: a4Height)
            }
            let height = a4Width * size.height / size.width
            return CGRect(x: 0, y: 0, width: a4Width, height: max(height, 200))
        }
    }

    private static func draw(page: Page, in pageRect: CGRect, options: ExportOptions) {
        let image = ImageTools.normalized(page.image)
        let size = image.size
        guard size.width > 0, size.height > 0 else { return }

        UIColor.white.setFill()
        UIRectFill(pageRect)

        let inset: CGFloat = options.pageSize == .a4 ? 12 : 0
        let box = pageRect.insetBy(dx: inset, dy: inset)
        let scale = min(box.width / size.width, box.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let imageRect = CGRect(x: pageRect.midX - drawSize.width / 2,
                               y: pageRect.midY - drawSize.height / 2,
                               width: drawSize.width,
                               height: drawSize.height)
        image.draw(in: imageRect)

        if options.embedTextLayer, !page.lines.isEmpty {
            drawTextLayer(page.lines, in: imageRect)
        }
    }

    /// 在图片位置上铺一层「隐形文字」，PDF 可搜索、可选中，但肉眼看不见。
    private static func drawTextLayer(_ lines: [OCRLine], in imageRect: CGRect) {
        for line in lines {
            let height = imageRect.height * CGFloat(line.height)
            guard height >= 2 else { continue }

            let fontSize = max(height * 0.82, 4)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize),
                .foregroundColor: UIColor.clear
            ]
            let text = NSAttributedString(string: line.text, attributes: attributes)
            let origin = CGPoint(x: imageRect.minX + imageRect.width * CGFloat(line.x),
                                 y: imageRect.minY + imageRect.height * CGFloat(line.y))
            text.draw(at: origin)
        }
    }
}

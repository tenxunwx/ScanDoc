import Foundation

/// 图像处理模式。扫描页始终保存原图，显示与导出时按模式实时渲染。
enum EnhanceMode: String, Codable, CaseIterable, Identifiable {
    case original
    case enhanced
    case grayscale
    case blackWhite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "原图"
        case .enhanced:
            return "增强"
        case .grayscale:
            return "灰度"
        case .blackWhite:
            return "黑白"
        }
    }
}

/// OCR 识别出的一行，坐标是相对整张图的归一化值，左上角为原点。
struct OCRLine: Codable, Hashable, Identifiable {
    var id = UUID()
    var text: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct ScannedPage: Identifiable, Codable, Hashable {
    var id = UUID()
    var imageName: String
    var enhance: EnhanceMode = .enhanced
    /// 顺时针旋转角度，取值 0 / 90 / 180 / 270
    var rotation: Int = 0
    var ocrText: String?
    var ocrLines: [OCRLine]?

    init(id: UUID = UUID(),
         imageName: String,
         enhance: EnhanceMode = .enhanced,
         rotation: Int = 0,
         ocrText: String? = nil,
         ocrLines: [OCRLine]? = nil) {
        self.id = id
        self.imageName = imageName
        self.enhance = enhance
        self.rotation = rotation
        self.ocrText = ocrText
        self.ocrLines = ocrLines
    }

    enum CodingKeys: String, CodingKey {
        case id, imageName, enhance, rotation, ocrText, ocrLines
    }

    /// 手写解码：老版本的 index.json 没有 rotation / ocrLines 字段，缺省补默认值，避免升级后文档库丢失。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        imageName = try container.decode(String.self, forKey: .imageName)
        enhance = try container.decodeIfPresent(EnhanceMode.self, forKey: .enhance) ?? .enhanced
        rotation = try container.decodeIfPresent(Int.self, forKey: .rotation) ?? 0
        ocrText = try container.decodeIfPresent(String.self, forKey: .ocrText)
        ocrLines = try container.decodeIfPresent([OCRLine].self, forKey: .ocrLines)
    }

    var hasOCR: Bool {
        if let text = ocrText, !text.isEmpty { return true }
        return false
    }
}

struct ScanDocument: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var pages: [ScannedPage] = []

    var pageCount: Int { pages.count }

    var subtitle: String {
        let date = createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(pageCount) 页 · \(date)"
    }

    func matches(_ keyword: String) -> Bool {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return true }
        if title.localizedCaseInsensitiveContains(key) { return true }
        return pages.contains { page in
            guard let text = page.ocrText else { return false }
            return text.localizedCaseInsensitiveContains(key)
        }
    }
}

/// 导出 PDF 的参数
struct ExportOptions {
    enum PageSize: String, CaseIterable, Identifiable {
        case a4
        case fitImage

        var id: String { rawValue }

        var title: String {
            switch self {
            case .a4:
                return "A4 纸张"
            case .fitImage:
                return "按图片比例"
            }
        }

        var detail: String {
            switch self {
            case .a4:
                return "统一排版，打印友好"
            case .fitImage:
                return "页面宽度同 A4，高度随图"
            }
        }
    }

    var pageSize: PageSize = .a4
    var embedTextLayer: Bool = true
}

/// 页面跳转用的轻量标识，避免文档内页序变化导致引用失效。
struct PageRef: Hashable {
    let documentID: UUID
    let pageID: UUID
}

struct ShareFile: Identifiable {
    let id = UUID()
    let url: URL
}

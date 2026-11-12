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

struct ScannedPage: Identifiable, Codable, Hashable {
    var id = UUID()
    var imageName: String
    var enhance: EnhanceMode = .enhanced
    var ocrText: String?
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

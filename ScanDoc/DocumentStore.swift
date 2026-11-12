import Foundation
import UIKit
import Combine

final class DocumentStore: ObservableObject {
    @Published private(set) var documents: [ScanDocument] = []

    let rootURL: URL
    private let imagesURL: URL
    private let fileManager = FileManager.default

    private var indexURL: URL { rootURL.appendingPathComponent("index.json") }
    private let thumbCache = NSCache<NSString, UIImage>()

    init() {
        let base = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        rootURL = base.appendingPathComponent("ScanDoc", isDirectory: true)
        imagesURL = rootURL.appendingPathComponent("Images", isDirectory: true)
        try? fileManager.createDirectory(at: imagesURL, withIntermediateDirectories: true)
        thumbCache.countLimit = 120
        load()
    }

    // MARK: - 持久化

    func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? JSONDecoder().decode([ScanDocument].self, from: data) else {
            documents = []
            return
        }
        documents = list
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(documents)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("索引保存失败: \(error)")
        }
    }

    // MARK: - 查询

    func document(id: UUID) -> ScanDocument? {
        documents.first { $0.id == id }
    }

    func pageImage(_ page: ScannedPage) -> UIImage? {
        let url = imagesURL.appendingPathComponent(page.imageName)
        return UIImage(contentsOfFile: url.path)
    }

    func processedImage(_ page: ScannedPage, mode: EnhanceMode? = nil) -> UIImage? {
        guard let raw = pageImage(page) else { return nil }
        return ImageTools.render(raw, mode: mode ?? page.enhance, rotation: page.rotation)
    }

    /// 同步缩略图（带缓存），用于列表与网格。
    func thumbnail(_ page: ScannedPage, maxSide: CGFloat = 480) -> UIImage? {
        let key = "\(page.imageName)-\(page.enhance.rawValue)-\(page.rotation)-\(Int(maxSide))" as NSString
        if let cached = thumbCache.object(forKey: key) { return cached }
        guard let image = processedImage(page) else { return nil }
        let thumb = ImageTools.thumbnail(image, maxSide: maxSide)
        thumbCache.setObject(thumb, forKey: key)
        return thumb
    }

    // MARK: - 写入

    @discardableResult
    func addDocument(images: [UIImage], title: String? = nil) -> ScanDocument? {
        let pages = savePages(images)
        guard !pages.isEmpty else { return nil }
        let doc = ScanDocument(title: title ?? Self.defaultTitle(), pages: pages)
        documents.insert(doc, at: 0)
        persist()
        return doc
    }

    @discardableResult
    func appendPages(documentID: UUID, images: [UIImage]) -> Int {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return 0 }
        let pages = savePages(images)
        guard !pages.isEmpty else { return 0 }
        documents[index].pages.append(contentsOf: pages)
        persist()
        return pages.count
    }

    func rename(documentID: UUID, title: String) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        documents[index].title = trimmed.isEmpty ? Self.defaultTitle() : trimmed
        persist()
    }

    func setEnhanceMode(_ mode: EnhanceMode, documentID: UUID, pageID: UUID) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentID }),
              let pageIndex = documents[docIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }
        documents[docIndex].pages[pageIndex].enhance = mode
        persist()
    }

    func setOCRText(_ text: String, documentID: UUID, pageID: UUID) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentID }),
              let pageIndex = documents[docIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }
        documents[docIndex].pages[pageIndex].ocrText = text
        persist()
    }

    func setOCR(_ result: OCRResult, documentID: UUID, pageID: UUID) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentID }),
              let pageIndex = documents[docIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }
        documents[docIndex].pages[pageIndex].ocrText = result.text
        documents[docIndex].pages[pageIndex].ocrLines = result.lines
        persist()
    }

    /// 顺时针旋转页面。同时把已有的 OCR 坐标一起旋转，免得用户还要重新识别。
    func rotatePage(documentID: UUID, pageID: UUID, by degrees: Int) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentID }),
              let pageIndex = documents[docIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }

        let delta = ((degrees % 360) + 360) % 360
        guard delta != 0 else { return }

        var page = documents[docIndex].pages[pageIndex]
        page.rotation = (page.rotation + delta) % 360
        if let lines = page.ocrLines {
            page.ocrLines = Self.rotateLines(lines, by: delta)
        }
        documents[docIndex].pages[pageIndex] = page
        thumbCache.removeAllObjects()
        persist()
    }

    /// 在文档内上下移动页面。
    func movePage(documentID: UUID, pageID: UUID, offset: Int) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentID }),
              let index = documents[docIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }
        let target = index + offset
        guard target >= 0, target < documents[docIndex].pages.count else { return }
        let page = documents[docIndex].pages.remove(at: index)
        documents[docIndex].pages.insert(page, at: target)
        persist()
    }

    /// 依次识别文档内所有页面，返回（成功数, 失败数）。
    func recognizeAllPages(documentID: UUID,
                           progress: (@MainActor (Int, Int) -> Void)? = nil) async -> (done: Int, failed: Int) {
        guard let doc = document(id: documentID) else { return (0, 0) }
        let pages = doc.pages
        var done = 0
        var failed = 0

        for (index, page) in pages.enumerated() {
            if let image = processedImage(page),
               let result = try? await OCRService.recognize(image) {
                setOCR(result, documentID: documentID, pageID: page.id)
                done += 1
            } else {
                failed += 1
            }
            await progress?(index + 1, pages.count)
        }
        return (done, failed)
    }

    private static func rotateLines(_ lines: [OCRLine], by degrees: Int) -> [OCRLine] {
        let angle = ((degrees % 360) + 360) % 360
        guard angle != 0 else { return lines }

        return lines.map { line in
            switch angle {
            case 90:
                return OCRLine(text: line.text,
                               x: 1 - line.y - line.height,
                               y: line.x,
                               width: line.height,
                               height: line.width)
            case 180:
                return OCRLine(text: line.text,
                               x: 1 - line.x - line.width,
                               y: 1 - line.y - line.height,
                               width: line.width,
                               height: line.height)
            case 270:
                return OCRLine(text: line.text,
                               x: line.y,
                               y: 1 - line.x - line.width,
                               width: line.height,
                               height: line.width)
            default:
                return line
            }
        }
    }

    func deletePage(documentID: UUID, pageID: UUID) {
        guard let docIndex = documents.firstIndex(where: { $0.id == documentID }),
              let pageIndex = documents[docIndex].pages.firstIndex(where: { $0.id == pageID }) else { return }
        let page = documents[docIndex].pages[pageIndex]
        try? fileManager.removeItem(at: imagesURL.appendingPathComponent(page.imageName))
        documents[docIndex].pages.remove(at: pageIndex)
        if documents[docIndex].pages.isEmpty {
            documents.remove(at: docIndex)
        }
        persist()
    }

    func delete(documentID: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        for page in documents[index].pages {
            try? fileManager.removeItem(at: imagesURL.appendingPathComponent(page.imageName))
        }
        documents.remove(at: index)
        persist()
    }

    // MARK: - 导出

    func exportPDF(documentID: UUID, options: ExportOptions = ExportOptions()) throws -> URL {
        guard let doc = document(id: documentID) else {
            throw ExportError.documentMissing
        }
        let pages: [PDFBuilder.Page] = doc.pages.compactMap { page in
            guard let image = processedImage(page) else { return nil }
            return PDFBuilder.Page(image: image, lines: page.ocrLines ?? [])
        }
        guard !pages.isEmpty else { throw ExportError.emptyDocument }

        let data = PDFBuilder.makePDF(pages: pages, title: doc.title, options: options)
        let safeName = doc.title.replacingOccurrences(of: "/", with: "-")
        let url = fileManager.temporaryDirectory.appendingPathComponent("\(safeName).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }

    func exportImagePage(documentID: UUID, pageID: UUID) throws -> URL {
        guard let doc = document(id: documentID),
              let page = doc.pages.first(where: { $0.id == pageID }),
              let image = processedImage(page) else {
            throw ExportError.emptyDocument
        }
        guard let data = image.jpegData(compressionQuality: 0.95) else {
            throw ExportError.emptyDocument
        }
        let url = fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    enum ExportError: LocalizedError {
        case documentMissing
        case emptyDocument

        var errorDescription: String? {
            switch self {
            case .documentMissing:
                return "找不到这个文档"
            case .emptyDocument:
                return "文档里没有可导出的页面"
            }
        }
    }

    // MARK: - 私有

    private func savePages(_ images: [UIImage]) -> [ScannedPage] {
        var pages: [ScannedPage] = []
        for image in images {
            let name = UUID().uuidString + ".jpg"
            let url = imagesURL.appendingPathComponent(name)
            guard let data = image.jpegData(compressionQuality: 0.9) else { continue }
            do {
                try data.write(to: url, options: .atomic)
                pages.append(ScannedPage(imageName: name))
            } catch {
                print("写入页面失败: \(error)")
            }
        }
        return pages
    }

    private static func defaultTitle() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return "扫描件 " + formatter.string(from: Date())
    }
}

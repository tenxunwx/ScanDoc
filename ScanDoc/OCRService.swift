import Foundation
import UIKit
import Vision

struct OCRResult {
    var text: String
    var lines: [OCRLine]
}

enum OCRService {
    enum OCRError: LocalizedError {
        case invalidImage
        case noTextFound
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .invalidImage:
                return "图片无法读取"
            case .noTextFound:
                return "没有识别到文字"
            case .failed(let reason):
                return "识别失败：\(reason)"
            }
        }
    }

    /// 使用系统 Vision 框架做离线文字识别，中英文混排可用，不上传任何数据。
    /// 返回的文字行带有归一化坐标，导出 PDF 时会据此生成隐形文字层。
    static func recognize(_ image: UIImage,
                          languages: [String] = ["zh-Hans", "en-US"]) async throws -> OCRResult {
        let normalized = ImageTools.normalized(image)
        guard let cgImage = normalized.cgImage else { throw OCRError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let supported = (try? request.supportedRecognitionLanguages()) ?? []
                let usable = languages.filter { supported.contains($0) }
                if !usable.isEmpty {
                    request.recognitionLanguages = usable
                }

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let observations = request.results ?? []

                    var lines: [OCRLine] = []
                    for observation in observations {
                        guard let candidate = observation.topCandidates(1).first else { continue }
                        let box = observation.boundingBox
                        lines.append(OCRLine(
                            text: candidate.string,
                            x: Double(box.origin.x),
                            y: Double(1 - box.origin.y - box.height),
                            width: Double(box.width),
                            height: Double(box.height)
                        ))
                    }

                    if lines.isEmpty {
                        continuation.resume(throwing: OCRError.noTextFound)
                        return
                    }

                    lines.sort { lhs, rhs in
                        if abs(lhs.y - rhs.y) > 1.0 / 400.0 {
                            return lhs.y < rhs.y
                        }
                        return lhs.x < rhs.x
                    }

                    let text = lines.map { $0.text }.joined(separator: "\n")
                    continuation.resume(returning: OCRResult(text: text, lines: lines))
                } catch {
                    continuation.resume(throwing: OCRError.failed(error.localizedDescription))
                }
            }
        }
    }
}

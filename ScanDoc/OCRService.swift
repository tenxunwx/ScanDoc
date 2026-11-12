import Foundation
import UIKit
import Vision

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
    static func recognize(_ image: UIImage, languages: [String] = ["zh-Hans", "en-US"]) async throws -> String {
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
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    if lines.isEmpty {
                        continuation.resume(throwing: OCRError.noTextFound)
                    } else {
                        continuation.resume(returning: lines.joined(separator: "\n"))
                    }
                } catch {
                    continuation.resume(throwing: OCRError.failed(error.localizedDescription))
                }
            }
        }
    }
}
